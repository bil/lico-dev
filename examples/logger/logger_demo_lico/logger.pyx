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


cdef pid_t pid, ppid
cdef sigset_t exitMask
cdef char pathName[MAX_PATH_LEN]

cdef size_t shmSize
cdef uint8_t *pmem
cdef int64_t *pNumTicks
cdef uint64_t time_tick = <uint64_t>NULL
cdef double time_system
cdef timespec *pClockTime
cdef sem_t *pSinkUpSem
cdef sem_t *pSinkDownSem
cdef sem_t *pSigSems[NUM_SEM_SIGS]
cdef char semNameBuf[SEM_NAME_LEN]
cdef uint32_t *pBufVars
cdef uint32_t *vector_intsBufVars
cdef int16_t *vector_intsStrtPtr
cdef int16_t *vector_intsEndPtr
cdef uint32_t *scalar_outBufVars
cdef int8_t *scalar_outStrtPtr
cdef int8_t *scalar_outEndPtr
cdef uint32_t *vector_floatsBufVars
cdef double *vector_floatsStrtPtr
cdef double *vector_floatsEndPtr
cdef uint32_t *matrix_outBufVars
cdef double *matrix_outStrtPtr
cdef double *matrix_outEndPtr




# track start and end vars (BufVars[8] and [9]) for each tick to flush
ctypedef struct asyncBufTickInfo:
  uint32_t vector_intsStrtOffsetSamples  # buffered vector_intsBufVars[0] values
  uint32_t vector_intsStrtOffset  # buffered vector_intsBufVars[8] values
  uint32_t vector_intsEndOffset  # buffered vector_intsBufVars[9] values
  uint32_t vector_intsLen  # buffered vector_intsLen values
  uint32_t scalar_outStrtOffsetSamples  # buffered scalar_outBufVars[0] values
  uint32_t scalar_outStrtOffset  # buffered scalar_outBufVars[8] values
  uint32_t scalar_outEndOffset  # buffered scalar_outBufVars[9] values
  uint32_t scalar_outLen  # buffered scalar_outLen values
  uint32_t vector_floatsStrtOffsetSamples  # buffered vector_floatsBufVars[0] values
  uint32_t vector_floatsStrtOffset  # buffered vector_floatsBufVars[8] values
  uint32_t vector_floatsEndOffset  # buffered vector_floatsBufVars[9] values
  uint32_t vector_floatsLen  # buffered vector_floatsLen values
  uint32_t matrix_outStrtOffsetSamples  # buffered matrix_outBufVars[0] values
  uint32_t matrix_outStrtOffset  # buffered matrix_outBufVars[8] values
  uint32_t matrix_outEndOffset  # buffered matrix_outBufVars[9] values
  uint32_t matrix_outLen  # buffered matrix_outLen values

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

cdef void handle_exit(int exitStatus):
  global retVal, tid, radio, context, s, shmSize, pmem, pSinkUpSem, pSinkDownSem, pSigSems

  munmap(pmem, shmSize)
  munlockall()

  if (sem_close(pSinkUpSem) == -1):
    printf("Could not close sink up semaphore. \n")
  if (sem_close(pSinkDownSem) == -1):
    printf("Could not close sink down semaphore. \n")

  shm_unlink("/async_mem_logger")
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
pClockTime = <timespec *>(pmem + CLOCK_TIME_OFFSET)
pBufVars = <uint32_t *>(pmem + BUF_VARS_OFFSET)
vector_intsBufVars = pBufVars + 16

scalar_outBufVars = pBufVars + 0

vector_floatsBufVars = pBufVars + 32

matrix_outBufVars = pBufVars + 48

pSinkUpSem = sem_open("/sink_up_sem_0", 0)
pSinkDownSem = sem_open("/sink_down_sem_0", 0)
snprintf(semNameBuf, SEM_NAME_LEN, "/sig_sem_%d", 1)
pSigSems[1] = sem_open(semNameBuf, 0)
snprintf(semNameBuf, SEM_NAME_LEN, "/sig_sem_%d", 0)
pSigSems[0] = sem_open(semNameBuf, 0)
snprintf(semNameBuf, SEM_NAME_LEN, "/sig_sem_%d", 2)
pSigSems[2] = sem_open(semNameBuf, 0)
snprintf(semNameBuf, SEM_NAME_LEN, "/sig_sem_%d", 3)
pSigSems[3] = sem_open(semNameBuf, 0)
# put buffer flush tracking variables in shared memory between
asyncShmSize = ROUND_UP(sizeof(asyncBufTickInfo) * ASYNC_BUF_LEN, PAGESIZE)

open_shared_mem(
  &pAsyncMem,
  "/async_mem_logger",
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
  sem_wait(pSinkUpSem)
  sem_wait(pSigSems[1])
  sem_wait(pSigSems[0])
  sem_wait(pSigSems[2])
  sem_wait(pSigSems[3])

  time_system = pClockTime[0].tv_sec + pClockTime[0].tv_nsec / 1.0e9
  time_tick = pNumTicks[0]

  
  # async main process updates buffer flush end variable
  if ((pAsyncFlushIndexEnd[0] + 1) == pAsyncFlushIndexStrt[0]) or (
    (pAsyncFlushIndexEnd[0] == ASYNC_BUF_LEN) and
    (pAsyncFlushIndexStrt[0] == 0)
  ):
    die("Async buffer overrun. Consider increasing signal history sizes.")
  
  pAsyncBufInfo[pAsyncFlushIndexEnd[0]].vector_intsStrtOffsetSamples = vector_intsBufVars[0]
  pAsyncBufInfo[pAsyncFlushIndexEnd[0]].vector_intsStrtOffset = vector_intsBufVars[8]
  pAsyncBufInfo[pAsyncFlushIndexEnd[0]].vector_intsEndOffset =vector_intsBufVars[9]
  pAsyncBufInfo[pAsyncFlushIndexEnd[0]].vector_intsLen = vector_intsBufVars[1] - vector_intsBufVars[0]
  
  pAsyncBufInfo[pAsyncFlushIndexEnd[0]].scalar_outStrtOffsetSamples = scalar_outBufVars[0]
  pAsyncBufInfo[pAsyncFlushIndexEnd[0]].scalar_outStrtOffset = scalar_outBufVars[8]
  pAsyncBufInfo[pAsyncFlushIndexEnd[0]].scalar_outEndOffset =scalar_outBufVars[9]
  pAsyncBufInfo[pAsyncFlushIndexEnd[0]].scalar_outLen = scalar_outBufVars[1] - scalar_outBufVars[0]
  
  pAsyncBufInfo[pAsyncFlushIndexEnd[0]].vector_floatsStrtOffsetSamples = vector_floatsBufVars[0]
  pAsyncBufInfo[pAsyncFlushIndexEnd[0]].vector_floatsStrtOffset = vector_floatsBufVars[8]
  pAsyncBufInfo[pAsyncFlushIndexEnd[0]].vector_floatsEndOffset =vector_floatsBufVars[9]
  pAsyncBufInfo[pAsyncFlushIndexEnd[0]].vector_floatsLen = vector_floatsBufVars[1] - vector_floatsBufVars[0]
  
  pAsyncBufInfo[pAsyncFlushIndexEnd[0]].matrix_outStrtOffsetSamples = matrix_outBufVars[0]
  pAsyncBufInfo[pAsyncFlushIndexEnd[0]].matrix_outStrtOffset = matrix_outBufVars[8]
  pAsyncBufInfo[pAsyncFlushIndexEnd[0]].matrix_outEndOffset =matrix_outBufVars[9]
  pAsyncBufInfo[pAsyncFlushIndexEnd[0]].matrix_outLen = matrix_outBufVars[1] - matrix_outBufVars[0]
  
  pAsyncFlushIndexEnd[0] += 1
  if pAsyncFlushIndexEnd[0] >= ASYNC_BUF_LEN:
    pAsyncFlushIndexEnd[0] = 0
  
  sem_post(pSinkDownSem)