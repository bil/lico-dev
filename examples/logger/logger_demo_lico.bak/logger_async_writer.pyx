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
cdef uint32_t *vector_floatsBufVars
cdef double *vector_floatsStrtPtr
cdef double *vector_floatsEndPtr
cdef uint32_t *vector_intsBufVars
cdef int16_t *vector_intsStrtPtr
cdef int16_t *vector_intsEndPtr
cdef uint32_t *matrix_outBufVars
cdef double *matrix_outStrtPtr
cdef double *matrix_outEndPtr
cdef uint32_t *scalar_outBufVars
cdef int8_t *scalar_outStrtPtr
cdef int8_t *scalar_outEndPtr

cdef uint32_t packetSize = 355000 * sizeof(uint8_t)
cdef uint8_t *outBufStrt
cdef uint8_t *outBufEnd
cdef uint8_t *outBuf
cdef size_t outBufLen


# track start and end vars (BufVars[8] and [9]) for each tick to flush
ctypedef struct asyncBufTickInfo:
  uint32_t vector_floatsStrtOffsetSamples  # buffered vector_floatsBufVars[0] values
  uint32_t vector_floatsStrtOffset  # buffered vector_floatsBufVars[8] values
  uint32_t vector_floatsEndOffset  # buffered vector_floatsBufVars[9] values
  uint32_t vector_floatsLen  # buffered vector_floatsLen values
  uint32_t vector_intsStrtOffsetSamples  # buffered vector_intsBufVars[0] values
  uint32_t vector_intsStrtOffset  # buffered vector_intsBufVars[8] values
  uint32_t vector_intsEndOffset  # buffered vector_intsBufVars[9] values
  uint32_t vector_intsLen  # buffered vector_intsLen values
  uint32_t matrix_outStrtOffsetSamples  # buffered matrix_outBufVars[0] values
  uint32_t matrix_outStrtOffset  # buffered matrix_outBufVars[8] values
  uint32_t matrix_outEndOffset  # buffered matrix_outBufVars[9] values
  uint32_t matrix_outLen  # buffered matrix_outLen values
  uint32_t scalar_outStrtOffsetSamples  # buffered scalar_outBufVars[0] values
  uint32_t scalar_outStrtOffset  # buffered scalar_outBufVars[8] values
  uint32_t scalar_outEndOffset  # buffered scalar_outBufVars[9] values
  uint32_t scalar_outLen  # buffered scalar_outLen values

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
vector_floatsBufVars = pBufVars + 32

vector_intsBufVars = pBufVars + 16

matrix_outBufVars = pBufVars + 48

scalar_outBufVars = pBufVars + 0

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


  
in_sigs["vector_floats"] = sa.attach("shm://vector_floats")
vector_floatsRaw = in_sigs["vector_floats"]
vector_floats = vector_floatsRaw[vector_floatsBufVars[8]]
    
vector_floatsStrtPtr = <double *><long>in_sigs["vector_floats"].__array_interface__["data"][0]
vector_floatsEndPtr = vector_floatsStrtPtr + len(in_sigs["vector_floats"])
    
    
  
in_sigs["vector_ints"] = sa.attach("shm://vector_ints")
vector_intsRaw = in_sigs["vector_ints"]
vector_ints = vector_intsRaw[vector_intsBufVars[8]]
    
vector_intsStrtPtr = <int16_t *><long>in_sigs["vector_ints"].__array_interface__["data"][0]
vector_intsEndPtr = vector_intsStrtPtr + len(in_sigs["vector_ints"])
    
    
  
in_sigs["matrix_out"] = sa.attach("shm://matrix_out")
matrix_outRaw = in_sigs["matrix_out"]
matrix_out = matrix_outRaw[matrix_outBufVars[8]]
    
matrix_outStrtPtr = <double *><long>in_sigs["matrix_out"].__array_interface__["data"][0]
matrix_outEndPtr = matrix_outStrtPtr + len(in_sigs["matrix_out"])
    
    
  
in_sigs["scalar_out"] = sa.attach("shm://scalar_out")
scalar_outRaw = in_sigs["scalar_out"]
scalar_out = scalar_outRaw[scalar_outBufVars[8]]
    
scalar_outStrtPtr = <int8_t *><long>in_sigs["scalar_out"].__array_interface__["data"][0]
scalar_outEndPtr = scalar_outStrtPtr + len(in_sigs["scalar_out"])
    
    
  

driver = disk.DiskSinkDriver()


outBufStrt = <uint8_t *>malloc(packetSize)
outBuf = outBufStrt
outBufEnd = outBufStrt + packetSize
outBufLen = outBufEnd - outBufStrt





kill(ppid,SIGUSR1)

while(True):

  # async buffering and parser logic

  # async writer udpates buffer flush start variable
  if pAsyncFlushIndexStrt[0] == pAsyncFlushIndexEnd[0]:
    if (shouldExit) and (pAsyncFlushIndexStrt[0] == pAsyncFlushIndexEnd[0]):
      handle_exit(0)
    # wait for half a tick if there is no data
    time.sleep(1000 / (2. * 1e6))
    continue

    
  asyncStrtOffset = pAsyncBufInfo[pAsyncFlushIndexStrt[0]].vector_floatsStrtOffset
  asyncEndOffset = pAsyncBufInfo[pAsyncFlushIndexStrt[0]].vector_floatsEndOffset
  if asyncEndOffset - asyncStrtOffset == 1:
    vector_floats = vector_floatsRaw[asyncStrtOffset]
  else:
    vector_floats = vector_floatsRaw[asyncStrtOffset:asyncEndOffset]
  in_sig_lens["vector_floats"] = pAsyncBufInfo[pAsyncFlushIndexStrt[0]].vector_floatsLen
  vector_floatsLen = in_sig_lens["vector_floats"]
    
  asyncStrtOffset = pAsyncBufInfo[pAsyncFlushIndexStrt[0]].vector_intsStrtOffset
  asyncEndOffset = pAsyncBufInfo[pAsyncFlushIndexStrt[0]].vector_intsEndOffset
  if asyncEndOffset - asyncStrtOffset == 1:
    vector_ints = vector_intsRaw[asyncStrtOffset]
  else:
    vector_ints = vector_intsRaw[asyncStrtOffset:asyncEndOffset]
  in_sig_lens["vector_ints"] = pAsyncBufInfo[pAsyncFlushIndexStrt[0]].vector_intsLen
  vector_intsLen = in_sig_lens["vector_ints"]
    
  asyncStrtOffset = pAsyncBufInfo[pAsyncFlushIndexStrt[0]].matrix_outStrtOffset
  asyncEndOffset = pAsyncBufInfo[pAsyncFlushIndexStrt[0]].matrix_outEndOffset
  if asyncEndOffset - asyncStrtOffset == 1:
    matrix_out = matrix_outRaw[asyncStrtOffset]
  else:
    matrix_out = matrix_outRaw[asyncStrtOffset:asyncEndOffset]
  in_sig_lens["matrix_out"] = pAsyncBufInfo[pAsyncFlushIndexStrt[0]].matrix_outLen
  matrix_outLen = in_sig_lens["matrix_out"]
    
  asyncStrtOffset = pAsyncBufInfo[pAsyncFlushIndexStrt[0]].scalar_outStrtOffset
  asyncEndOffset = pAsyncBufInfo[pAsyncFlushIndexStrt[0]].scalar_outEndOffset
  if asyncEndOffset - asyncStrtOffset == 1:
    scalar_out = scalar_outRaw[asyncStrtOffset]
  else:
    scalar_out = scalar_outRaw[asyncStrtOffset:asyncEndOffset]
  in_sig_lens["scalar_out"] = pAsyncBufInfo[pAsyncFlushIndexStrt[0]].scalar_outLen
  scalar_outLen = in_sig_lens["scalar_out"]
    
  pAsyncFlushIndexStrt[0] += 1
  if pAsyncFlushIndexStrt[0] >= ASYNC_BUF_LEN:
    pAsyncFlushIndexStrt[0] = 0

  


  driver.run(<uint8_t *>outBuf, outBufLen, in_sigs, in_sig_lens)
  if (shouldExit) and (pAsyncFlushIndexStrt[0] == pAsyncFlushIndexEnd[0]):
    handle_exit(0)