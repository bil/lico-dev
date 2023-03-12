# cimport C libraries
from posix.fcntl cimport O_CREAT, O_RDWR, O_TRUNC, O_WRONLY, open
from posix.mman cimport (
    MAP_SHARED,
    MCL_CURRENT,
    MCL_FUTURE,
    PROT_READ,
    PROT_WRITE,
    mlockall,
    mmap,
    munlockall,
    munmap,
    shm_open,
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
from posix.time cimport CLOCK_MONOTONIC_RAW, clock_gettime, timespec
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

DEF SIG_BLOCK = 1

# import Python libraries

import time

import numpy as np


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
  enum: NUM_NON_SOURCES
  enum: NUM_SEM_SIGS
  enum: NUM_INTERNAL_SIGS
  size_t ROUND_UP(int X, int Y)
  enum: BUF_VARS_LEN
  enum: SHM_SIZE
  enum: NUM_TICKS_OFFSET
  enum: BUF_VARS_OFFSET
  enum: ASYNC_WRITER_MUTEXES_OFFSET
  enum: SEM_NAME_LEN
cdef extern from "<pthread.h>" nogil:
  struct sched_param:
    int sched_priority

# cdef variables
cdef pid_t pid, ppid
cdef sigset_t exitMask
cdef char pathName[MAX_PATH_LEN]

cdef size_t shmSize
cdef uint8_t *pmem
cdef int64_t *pNumTicks
cdef sem_t *pTickUpSem
cdef sem_t *pTickDownSem
cdef sem_t *pSigSems[NUM_SEM_SIGS]
cdef char semNameBuf[SEM_NAME_LEN]
cdef uint32_t *pBufVars
cdef uint32_t *uint64_signalBufVars
cdef uint64_t *uint64_signalStrtPtr
cdef uint64_t *uint64_signalEndPtr




# track start and end vars (BufVars[8] and [9]) for each tick to flush
ctypedef struct asyncBufTickInfo:
  uint32_t uint64_signalStrtOffsetSamples  # buffered uint64_signalBufVars[0] values
  uint32_t uint64_signalStrtOffset  # buffered uint64_signalBufVars[8] values
  uint32_t uint64_signalEndOffset  # buffered uint64_signalBufVars[9] values
  uint32_t uint64_signalLen  # buffered uint64_signalLen values

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
in_sig = None

cdef void handle_exit(int exitStatus):
  global retVal, tid, radio, context, s, shmSize, pmem, pTickUpSem, pTickDownSem, pSigSems

  munmap(pmem, shmSize)
  munlockall()

  if (sem_close(pTickUpSem) == -1):
    printf("Could not close sink up semaphore. \n")
  if (sem_close(pTickDownSem) == -1):
    printf("Could not close sink down semaphore. \n")

  shm_unlink("/async_mem_shared_array_out")
  exit(exitStatus)

cdef void int_handler(int signum):
  pass

cdef void exit_handler(int signum):
  global shouldExit
  handle_exit(0)

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
pBufVars = <uint32_t *>(pmem + BUF_VARS_OFFSET)
uint64_signalBufVars = pBufVars + 0

pTickUpSem = sem_open("/tick_up_sem_0", 0)
pTickDownSem = sem_open("/tick_down_sem_0", 0)
snprintf(semNameBuf, SEM_NAME_LEN, "/sig_sem_%d", 0)
pSigSems[0] = sem_open(semNameBuf, 0)
# put buffer flush tracking variables in shared memory between
asyncShmSize = ROUND_UP(sizeof(asyncBufTickInfo) * ASYNC_BUF_LEN, PAGESIZE)

open_shared_mem(
  &pAsyncMem,
  "/async_mem_shared_array_out",
  asyncShmSize,
  O_TRUNC | O_CREAT | O_RDWR,
  PROT_READ | PROT_WRITE
)

pAsyncFlushIndexStrt = <uint32_t *>pAsyncMem
pAsyncFlushIndexEnd = <uint32_t *>(pAsyncMem + sizeof(uint32_t))
pAsyncBufInfo = <asyncBufTickInfo *>(pAsyncMem + 2 * sizeof(uint32_t))
pAsyncFlushIndexStrt[0] = 0
pAsyncFlushIndexEnd[0] = 0









kill(ppid,SIGUSR1)

while(True):
  sem_wait(pTickUpSem)
  sem_wait(pSigSems[0])
  
  # async main process updates buffer flush end variable
  if ((pAsyncFlushIndexEnd[0] + 1) == pAsyncFlushIndexStrt[0]) or (
    (pAsyncFlushIndexEnd[0] == ASYNC_BUF_LEN) and
    (pAsyncFlushIndexStrt[0] == 0)
  ):
    die("Async buffer overrun. Consider increasing signal history sizes.")
  
  pAsyncBufInfo[pAsyncFlushIndexEnd[0]].uint64_signalStrtOffsetSamples = uint64_signalBufVars[0]
  pAsyncBufInfo[pAsyncFlushIndexEnd[0]].uint64_signalStrtOffset = uint64_signalBufVars[8]
  pAsyncBufInfo[pAsyncFlushIndexEnd[0]].uint64_signalEndOffset =uint64_signalBufVars[9]
  pAsyncBufInfo[pAsyncFlushIndexEnd[0]].uint64_signalLen = uint64_signalBufVars[1] - uint64_signalBufVars[0]
  
  pAsyncFlushIndexEnd[0] += 1
  if pAsyncFlushIndexEnd[0] >= ASYNC_BUF_LEN:
    pAsyncFlushIndexEnd[0] = 0
  
  sem_post(pTickDownSem)