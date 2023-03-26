# cimport C libraries
from posix.fcntl cimport O_CREAT, O_RDWR, O_TRUNC, O_WRONLY, open
from posix.mman cimport (
    MAP_SHARED,
    MCL_CURRENT,
    MCL_FUTURE,
    PROT_READ,
    PROT_WRITE,
    mlockall,
    munlockall,
    munmap,
    shm_unlink,
)
from posix.signal cimport (
    kill,
    sigaction,
    sigaction_t,
    sigaddset,
    sigemptyset,
    sigfillset,
    sigset_t,
)
from posix.time cimport clock_gettime, timespec
from posix.types cimport pid_t
from posix.unistd cimport close, getpid, getppid, pause, write

cimport cython
cimport numpy as np
from libc.errno cimport EINTR, EPIPE, errno
from libc.signal cimport SIGALRM, SIGBUS, SIGINT, SIGQUIT, SIGSEGV, SIGUSR1, SIGUSR2
from libc.stdint cimport (
    int8_t,
    int16_t,
    int32_t,
    int64_t,
    uint8_t,
    uint16_t,
    uint32_t,
    uint64_t,
)
from libc.stdio cimport fflush, printf, remove, snprintf, stdout
from libc.stdlib cimport EXIT_FAILURE, EXIT_SUCCESS, exit, free, malloc
from libc.string cimport memcpy, memset, strcat, strcpy, strlen

# import Python libraries

import time

import numpy as np
import SharedArray as sa

cimport sink_drivers.disk.disk as disk

import sink_drivers.disk.disk as disk


# headers for all sinks
cdef extern from "utilityFunctions.h" nogil:
  enum: __GNU_SOURCE
  void die(char *errorStr)
  void open_shared_mem(uint8_t **ppmem, const char *pName, int numBytes, int shm_flags, int mmap_flags)
  void set_sighandler(int signum, void *psh, sigset_t *block_mask)
  void make_realtime()

cdef extern from "utilityFunctions.h":
  void init_utils(void (*pHandleExit)(int exitStatus), sigset_t *pExitMask)

cdef extern from "semaphore.h" nogil:
  cdef union sem_union:
    pass
  ctypedef sem_union sem_t
  sem_t *sem_open(const char *name, int oflag)
  int sem_wait(sem_t *)
  int sem_post(sem_t *)
  int sem_close(sem_t *sem)

cdef extern from "constants.h":
  enum: NUM_CHANNELS
  enum: MAX_PATH_LEN
  enum: NUM_CHILDREN
  enum: PAGESIZE
  enum: SMEM0_HEADER_LEN
  cdef const char *SMEM0_PATHNAME
  cdef const char *SMEMSIG_PATHNAME
  enum: NUM_SEM_SIGS
  enum: NUM_INTERNAL_SIGS
  size_t ROUND_UP(int X, int Y)
  enum: BUF_VARS_LEN
  enum: SHM_SIZE
  enum: NUM_TICKS_OFFSET
  enum: CLOCK_TIME_OFFSET
  enum: BUF_VARS_OFFSET
  enum: ASYNC_WRITER_MUTEXES_OFFSET
  enum: SEM_NAME_LEN
cdef extern from "<pthread.h>" nogil:
  struct sched_param:
    int sched_priority

# cdef variables
# driver
cdef disk.DiskSinkDriver driver

cdef pid_t pid, ppid
cdef sigset_t exitMask
cdef char pathName[MAX_PATH_LEN]

cdef size_t shmSize
cdef uint8_t *pmem
cdef int64_t *pNumTicks
cdef uint64_t time_tick = <uint64_t>NULL
cdef double time_system
cdef timespec *pClockTime

cdef uint32_t *pBufVars
cdef uint32_t *int8_signalBufVars
cdef int8_t *int8_signalStrtPtr
cdef int8_t *int8_signalEndPtr

cdef uint32_t packetSize = 5000 * sizeof(int8_t)
cdef int8_t *outBufStrt
cdef int8_t *outBufEnd
cdef int8_t *outBuf
cdef size_t outBufLen


# track start and end vars (BufVars[8] and [9]) for each tick to flush
ctypedef struct asyncBufTickInfo:
  uint32_t int8_signalStrtOffsetSamples  # buffered int8_signalBufVars[0] values
  uint32_t int8_signalStrtOffset  # buffered int8_signalBufVars[8] values
  uint32_t int8_signalEndOffset  # buffered int8_signalBufVars[9] values
  uint32_t int8_signalLen  # buffered int8_signalLen values

cdef uint32_t asyncStrtOffset
cdef uint32_t asyncEndOffset
cdef uint32_t *pAsyncFlushIndexStrt
cdef uint32_t *pAsyncFlushIndexEnd
cdef asyncBufTickInfo *pAsyncBufInfo
cdef uint8_t *pAsyncMem
cdef size_t asyncShmSize
ASYNC_BUF_LEN = 5000


# python variables
lastVal = 1
in_sigs = {}
in_sig_lens = {}
in_sig = None
shouldExit = False

cdef void handle_exit(int exitStatus):
  global retVal, tid, radio, context, s, shmSize, pmem, pSinkUpSem, pSinkDownSem, pSigSems

  

  driver.exit_handler(exitStatus)

  munmap(pmem, shmSize)
  munlockall()
  exit(exitStatus)

cdef void int_handler(int signum):
  pass

cdef void exit_handler(int signum):
  global shouldExit
  shouldExit = True

cdef void bus_handler(int signum):
  printf("Bus Error\n")
  handle_exit(1)

cdef void segv_handler(int signum):
  printf("Seg Fault\n")
  handle_exit(1)

cdef void usr2_handler(int signum):
  pass

# main
sigemptyset(&exitMask)
sigaddset(&exitMask, SIGALRM)
init_utils(&handle_exit, &exitMask)

pid = getpid()
ppid = getppid()

set_sighandler(SIGINT, &int_handler, &exitMask)
set_sighandler(SIGUSR1, &exit_handler, &exitMask)
set_sighandler(SIGBUS, &bus_handler, &exitMask)
set_sighandler(SIGSEGV, &segv_handler, &exitMask)
set_sighandler(SIGUSR2, &usr2_handler, NULL)

# open and map shared memory
shmSize = ROUND_UP(SHM_SIZE, PAGESIZE)
open_shared_mem(&pmem, SMEM0_PATHNAME, shmSize, O_RDWR, PROT_READ | PROT_WRITE)
pNumTicks = <int64_t *>(pmem + NUM_TICKS_OFFSET)
pClockTime = <timespec *>(pmem + CLOCK_TIME_OFFSET)
pBufVars = <uint32_t *>(pmem + BUF_VARS_OFFSET)
int8_signalBufVars = pBufVars + 0

# put buffer flush tracking variables in shared memory between
asyncShmSize = ROUND_UP(sizeof(asyncBufTickInfo) * ASYNC_BUF_LEN, PAGESIZE)

open_shared_mem(
  &pAsyncMem,
  "/async_mem_logger",
  asyncShmSize,
  O_RDWR,
  PROT_READ | PROT_WRITE
)

pAsyncFlushIndexStrt = <uint32_t *>pAsyncMem
pAsyncFlushIndexEnd = <uint32_t *>(pAsyncMem + sizeof(uint32_t))
pAsyncBufInfo = <asyncBufTickInfo *>(pAsyncMem + 2 * sizeof(uint32_t))
pAsyncFlushIndexStrt[0] = 0
pAsyncFlushIndexEnd[0] = 0


  
in_sigs["int8_signal"] = sa.attach("shm://int8_signal")
int8_signalRaw = in_sigs["int8_signal"]
int8_signal = int8_signalRaw[int8_signalBufVars[8]]
    
int8_signalStrtPtr = <int8_t *><long>in_sigs["int8_signal"].__array_interface__["data"][0]
int8_signalEndPtr = int8_signalStrtPtr + len(in_sigs["int8_signal"])
    
    
in_sig = in_sigs["int8_signal"]
  

driver = disk.DiskSinkDriver()


outBufStrt = <int8_t *><long>in_sig.__array_interface__["data"][0]
outBuf = outBufStrt
outBufEnd = outBufStrt + int8_signalBufVars[7]
outBufLen = outBufEnd - outBufStrt





kill(ppid,SIGUSR1)

while(True):

  # async buffering and parser logic

  # async writer udpates buffer flush start variable
  if pAsyncFlushIndexStrt[0] == pAsyncFlushIndexEnd[0]:
    if (shouldExit) and (pAsyncFlushIndexStrt[0] == pAsyncFlushIndexEnd[0]):
      handle_exit(0)
    # wait for half a tick if there is no data
    time.sleep(10000 / (2. * 1e6))
    continue

    
  asyncStrtOffset = pAsyncBufInfo[pAsyncFlushIndexStrt[0]].int8_signalStrtOffset
  asyncEndOffset = pAsyncBufInfo[pAsyncFlushIndexStrt[0]].int8_signalEndOffset
  if asyncEndOffset - asyncStrtOffset == 1:
    int8_signal = int8_signalRaw[asyncStrtOffset]
  else:
    int8_signal = int8_signalRaw[asyncStrtOffset:asyncEndOffset]
  in_sig_lens["int8_signal"] = pAsyncBufInfo[pAsyncFlushIndexStrt[0]].int8_signalLen
  int8_signalLen = in_sig_lens["int8_signal"]
    

  outBuf = outBufStrt + pAsyncBufInfo[pAsyncFlushIndexStrt[0]].int8_signalStrtOffsetSamples
  outBufLen = pAsyncBufInfo[pAsyncFlushIndexStrt[0]].int8_signalLen
    
  pAsyncFlushIndexStrt[0] += 1
  if pAsyncFlushIndexStrt[0] >= ASYNC_BUF_LEN:
    pAsyncFlushIndexStrt[0] = 0

  


  driver.run(<uint8_t *>outBuf, outBufLen, in_sigs, in_sig_lens)
  if (shouldExit) and (pAsyncFlushIndexStrt[0] == pAsyncFlushIndexEnd[0]):
    handle_exit(0)