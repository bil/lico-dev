
# cimport C libraries
cimport posix.stat
from posix.fcntl cimport O_CREAT, O_RDWR, O_TRUNC
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
from posix.time cimport clock_gettime, timespec
from posix.types cimport pid_t
from posix.unistd cimport close, getpid, getppid, pause

from libc.signal cimport SIGALRM, SIGBUS, SIGINT, SIGQUIT, SIGSEGV, SIGUSR1
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
from libc.stdio cimport fflush, printf, snprintf, stdout
from libc.stdlib cimport atoi, exit
from libc.string cimport memcpy, memset, strcpy
from libcpp cimport bool

import signal
import sys

import SharedArray as sa

from cpython.exc cimport PyErr_CheckSignals

import math
import random as random
import time

import numpy as np
import posix_ipc

# import LiCoRICE utils
from module_utils import create_shared_array


cdef extern from "semaphore.h":
  enum: __SIZEOF_SEM_T
  cdef union sem_union:
    char __size[__SIZEOF_SEM_T]
    long int __align
  ctypedef sem_union sem_t
  sem_t *sem_open(const char *name, int oflag)
  int sem_wait(sem_t *)
  int sem_post(sem_t *)
  int sem_close(sem_t *sem)
  int sem_getvalue(sem_t *sem, int *val)
#not used yet, just seeing if it would work
cdef extern from "unistd.h":
  int getpagesize()
cdef extern from "stdatomic.h":
  enum memory_order:
    memory_order_relaxed,
    memory_order_consume,
    memory_order_acquire,
    memory_order_release,
    memory_order_acq_rel,
    memory_order_seq_cst
  void atomic_thread_fence(memory_order)

cdef extern from "utilityFunctions.h":
  void init_utils(void (*pHandleExit)(int exitStatus), sigset_t *pExitMask)
  void die(char *errorStr)
  void open_shared_mem(uint8_t **ppmem, const char *pName, int numBytes, int shm_flags, int mmap_flags)
  void set_sighandler(int signum, void *psh, sigset_t *block_mask)
  void make_realtime()

import numpy as np

cimport cython
cimport numpy as np


cdef extern from "constants.h":
  enum: NUM_PAGES_IN_GB
  enum: MAX_PATH_LEN
  enum: NUM_CHILDREN
  enum: BYTES_IN_GB
  cdef const char *SMEM0_PATHNAME
  enum: PAGESIZE
  enum: LATENCY
  enum: NUM_SEM_SIGS
  enum: NUM_INTERNAL_SIGS
  size_t ROUND_UP(int X, int Y)
  enum: BUF_VARS_LEN
  enum: SHM_SIZE
  enum: NUM_TICKS_OFFSET
  enum: CLOCK_TIME_OFFSET
  enum: BUF_VARS_OFFSET
  enum: SEM_NAME_LEN

cdef pid_t pid
cdef pid_t ppid
cdef char pathName[MAX_PATH_LEN]
cdef public sigset_t exitMask

# shared memory vars
cdef size_t shm_size
cdef uint8_t *pmem
cdef int64_t *pNumTicks
cdef uint64_t time_tick = <uint64_t>NULL
cdef double time_system
cdef timespec *pClockTime
cdef sem_t *pModUpSem
cdef sem_t *pModDownSem
cdef sem_t *pSigSems[NUM_SEM_SIGS]
cdef char semNameBuf[SEM_NAME_LEN]
cdef uint32_t *pBufVars
cdef uint32_t *vector_floatsBufVars

cdef uint32_t *vector_intsBufVars

cdef uint32_t *matrix_outBufVars

cdef uint32_t *scalar_outBufVars






cdef void handle_exit(int exitStatus):
  global pmem, shm_size, pModUpSem, pModDownSem, pSigSems
  
  sa.delete("shm://vector_floats")
  sa.delete("shm://vector_ints")
  sa.delete("shm://matrix_out")
  sa.delete("shm://scalar_out")
  munmap(pmem, shm_size)
  munlockall()

  if (sem_close(pModUpSem) == -1):
    printf("Could not close source up semaphore. \n")
  if (sem_close(pModDownSem) == -1):
    printf("Could not close source down semaphore. \n")
  if (sem_close(pSigSems[0]) == -1):
    printf("Could not close signal semaphore. \n")
  if (sem_close(pSigSems[1]) == -1):
    printf("Could not close signal semaphore. \n")
  if (sem_close(pSigSems[2]) == -1):
    printf("Could not close signal semaphore. \n")
  if (sem_close(pSigSems[3]) == -1):
    printf("Could not close signal semaphore. \n")

  exit(exitStatus)

cdef void int_handler(int signum):
  pass

cdef void exit_handler(int signum):
  printf("EXIT HANDLER for logger_sigout\n")
  handle_exit(0)

cdef void mem_error_handler(int signum):
  printf("Child memory error: signum %d\n", signum)
  printf("Child ID: %d\n", 0)
  handle_exit(1)

# runtime code
# intialize utilityFunctions
sigfillset(&exitMask)
init_utils(&handle_exit, &exitMask)
ppid = getppid()
pid = getpid()
printf("child %d id: %d\n", 0, pid)

# open and map shared parent memory
shm_size = ROUND_UP(SHM_SIZE, PAGESIZE)
open_shared_mem(
  &pmem, SMEM0_PATHNAME, shm_size, O_RDWR, PROT_READ | PROT_WRITE
)
pNumTicks = <int64_t *>(pmem + NUM_TICKS_OFFSET)
pClockTime = <timespec *>(pmem + CLOCK_TIME_OFFSET)
pBufVars = <uint32_t *>(pmem + BUF_VARS_OFFSET)

pModUpSem = sem_open("/mod_up_sem_0", 0)
pModDownSem = sem_open("/mod_down_sem_0", 0)
snprintf(semNameBuf, SEM_NAME_LEN, "/sig_sem_%d", 0)
pSigSems[0] = sem_open(semNameBuf, 0)
snprintf(semNameBuf, SEM_NAME_LEN, "/sig_sem_%d", 1)
pSigSems[1] = sem_open(semNameBuf, 0)
snprintf(semNameBuf, SEM_NAME_LEN, "/sig_sem_%d", 2)
pSigSems[2] = sem_open(semNameBuf, 0)
snprintf(semNameBuf, SEM_NAME_LEN, "/sig_sem_%d", 3)
pSigSems[3] = sem_open(semNameBuf, 0)


in_sigs = {}

out_sigs = {}

out_sigs["vector_floats"] = create_shared_array(
  "shm://vector_floats", (5000,4), dtype=np.double
)
# make sure SharedArray==2.0.4 -> try to transfer to 3.0.0
out_sigs["vector_floats"].base.mlock()
vector_floatsRaw = out_sigs["vector_floats"]
vector_floatsBufVars = pBufVars + 32
vector_floats = vector_floatsRaw[vector_floatsBufVars[8]]
vector_floatsBufVars[5] = 4
vector_floatsBufVars[6] = 4
vector_floatsBufVars[7] = 20000

out_sigs["vector_ints"] = create_shared_array(
  "shm://vector_ints", (5000,3), dtype=np.int16
)
# make sure SharedArray==2.0.4 -> try to transfer to 3.0.0
out_sigs["vector_ints"].base.mlock()
vector_intsRaw = out_sigs["vector_ints"]
vector_intsBufVars = pBufVars + 16
vector_ints = vector_intsRaw[vector_intsBufVars[8]]
vector_intsBufVars[5] = 3
vector_intsBufVars[6] = 3
vector_intsBufVars[7] = 15000

out_sigs["matrix_out"] = create_shared_array(
  "shm://matrix_out", (5000,2,2), dtype=np.double
)
# make sure SharedArray==2.0.4 -> try to transfer to 3.0.0
out_sigs["matrix_out"].base.mlock()
matrix_outRaw = out_sigs["matrix_out"]
matrix_outBufVars = pBufVars + 48
matrix_out = matrix_outRaw[matrix_outBufVars[8]]
matrix_outBufVars[5] = 4
matrix_outBufVars[6] = 4
matrix_outBufVars[7] = 20000

out_sigs["scalar_out"] = create_shared_array(
  "shm://scalar_out", (5000,1), dtype=np.int8
)
# make sure SharedArray==2.0.4 -> try to transfer to 3.0.0
out_sigs["scalar_out"].base.mlock()
scalar_outRaw = out_sigs["scalar_out"]
scalar_outBufVars = pBufVars + 0
scalar_out = scalar_outRaw[scalar_outBufVars[8]]
scalar_outBufVars[5] = 1
scalar_outBufVars[6] = 1
scalar_outBufVars[7] = 5000


# set signal mask
sigfillset(&exitMask)
# handle signals
set_sighandler(SIGINT, &int_handler, &exitMask)
set_sighandler(SIGUSR1, &exit_handler, &exitMask)
set_sighandler(SIGBUS, &mem_error_handler, &exitMask)
set_sighandler(SIGSEGV, &mem_error_handler, &exitMask)





# the constructor here is initializing some internal/persistent variables (only available to this module)

scalar = np.array(1, dtype="int8")
vector_i = np.array([1, 1, 1], dtype="int16")
vector_f = np.array([1, 1, 1, 1], dtype="double")
matrix = np.array([[1, 1], [1, 1]], dtype="double")

kill(ppid,SIGUSR1)

cdef int semVal
while(True):
  sem_wait(pModUpSem)


  time_system = pClockTime[0].tv_sec + pClockTime[0].tv_nsec / 1.0e9
  if pNumTicks[0] >= 0:
    time_tick = pNumTicks[0]



  vector_floats = vector_floatsRaw[vector_floatsBufVars[10]]

  vector_ints = vector_intsRaw[vector_intsBufVars[10]]

  matrix_out = matrix_outRaw[matrix_outBufVars[10]]

  scalar_out = scalar_outRaw[scalar_outBufVars[10]]

  # update internal/persistent variables
  
  if scalar <= 127:
      scalar += 1
  else:
      scalar = -128
  
  if vector_i[0] < 0:
      vector_i[:] += 5
  else:
      vector_i[0] = -32767
      vector_i[1] = -20000
      vector_i[2] = -10000
  
  if vector_f[0] < 1e9:
      vector_f[:] *= 2
  else:
      vector_f[:] = [1, 2, 3, 4]
  
  if matrix[0, 0] < 1e10:
      matrix *= 3
  else:
      matrix[:, :] = [[1, 2], [3, 4]]
  
  
  # write to outputs
  scalar_out[:] = scalar
  vector_ints[:] = vector_i
  vector_floats[:] = vector_f
  matrix_out[:, :] = matrix
  


  # printf("module 1 : %u %u %u %u %u %u %u %u  \n", scalar_outBufVars[0], scalar_outBufVars[1], scalar_outBufVars[2], scalar_outBufVars[3], scalar_outBufVars[4], scalar_outBufVars[5], scalar_outBufVars[6], scalar_outBufVars[7])
  scalar_outBufVars[2] += scalar_outBufVars[5]
  scalar_outBufVars[10] += 1
  if (scalar_outBufVars[7] <= (scalar_outBufVars[2] + scalar_outBufVars[6])):
    scalar_outBufVars[4] = scalar_outBufVars[2]
    scalar_outBufVars[12] = scalar_outBufVars[10]
  elif (scalar_outBufVars[2] > scalar_outBufVars[4]):
    scalar_outBufVars[4] = scalar_outBufVars[2] 
    scalar_outBufVars[12] = scalar_outBufVars[10]
  scalar_outBufVars[3] += scalar_outBufVars[5]
  scalar_outBufVars[11] += 1
  # printf("module 2 : %u %u %u %u %u %u %u %u  \n", scalar_outBufVars[0], scalar_outBufVars[1], scalar_outBufVars[2], scalar_outBufVars[3], scalar_outBufVars[4], scalar_outBufVars[5], scalar_outBufVars[6], scalar_outBufVars[7])

  # update bufVars
  scalar_outBufVars[1] = scalar_outBufVars[2]
  scalar_outBufVars[9] = scalar_outBufVars[10]
  scalar_outBufVars[0] = scalar_outBufVars[1] - scalar_outBufVars[3]
  scalar_outBufVars[8] = scalar_outBufVars[9] - scalar_outBufVars[11]
  if (scalar_outBufVars[7] < (scalar_outBufVars[2] + scalar_outBufVars[6])):
    scalar_outBufVars[2] = 0
    scalar_outBufVars[10] = 0
  scalar_outBufVars[3] = 0
  scalar_outBufVars[11] = 0  
  # printf("module 3 : %u %u %u %u %u %u %u %u  \n", scalar_outBufVars[0], scalar_outBufVars[1], scalar_outBufVars[2], scalar_outBufVars[3], scalar_outBufVars[4], scalar_outBufVars[5], scalar_outBufVars[6], scalar_outBufVars[7])

  if pNumTicks[0] >= 0:
  
    sem_post(pSigSems[0])
  # printf("module 1 : %u %u %u %u %u %u %u %u  \n", vector_intsBufVars[0], vector_intsBufVars[1], vector_intsBufVars[2], vector_intsBufVars[3], vector_intsBufVars[4], vector_intsBufVars[5], vector_intsBufVars[6], vector_intsBufVars[7])
  vector_intsBufVars[2] += vector_intsBufVars[5]
  vector_intsBufVars[10] += 1
  if (vector_intsBufVars[7] <= (vector_intsBufVars[2] + vector_intsBufVars[6])):
    vector_intsBufVars[4] = vector_intsBufVars[2]
    vector_intsBufVars[12] = vector_intsBufVars[10]
  elif (vector_intsBufVars[2] > vector_intsBufVars[4]):
    vector_intsBufVars[4] = vector_intsBufVars[2] 
    vector_intsBufVars[12] = vector_intsBufVars[10]
  vector_intsBufVars[3] += vector_intsBufVars[5]
  vector_intsBufVars[11] += 1
  # printf("module 2 : %u %u %u %u %u %u %u %u  \n", vector_intsBufVars[0], vector_intsBufVars[1], vector_intsBufVars[2], vector_intsBufVars[3], vector_intsBufVars[4], vector_intsBufVars[5], vector_intsBufVars[6], vector_intsBufVars[7])

  # update bufVars
  vector_intsBufVars[1] = vector_intsBufVars[2]
  vector_intsBufVars[9] = vector_intsBufVars[10]
  vector_intsBufVars[0] = vector_intsBufVars[1] - vector_intsBufVars[3]
  vector_intsBufVars[8] = vector_intsBufVars[9] - vector_intsBufVars[11]
  if (vector_intsBufVars[7] < (vector_intsBufVars[2] + vector_intsBufVars[6])):
    vector_intsBufVars[2] = 0
    vector_intsBufVars[10] = 0
  vector_intsBufVars[3] = 0
  vector_intsBufVars[11] = 0  
  # printf("module 3 : %u %u %u %u %u %u %u %u  \n", vector_intsBufVars[0], vector_intsBufVars[1], vector_intsBufVars[2], vector_intsBufVars[3], vector_intsBufVars[4], vector_intsBufVars[5], vector_intsBufVars[6], vector_intsBufVars[7])

  if pNumTicks[0] >= 0:
  
    sem_post(pSigSems[1])
  # printf("module 1 : %u %u %u %u %u %u %u %u  \n", vector_floatsBufVars[0], vector_floatsBufVars[1], vector_floatsBufVars[2], vector_floatsBufVars[3], vector_floatsBufVars[4], vector_floatsBufVars[5], vector_floatsBufVars[6], vector_floatsBufVars[7])
  vector_floatsBufVars[2] += vector_floatsBufVars[5]
  vector_floatsBufVars[10] += 1
  if (vector_floatsBufVars[7] <= (vector_floatsBufVars[2] + vector_floatsBufVars[6])):
    vector_floatsBufVars[4] = vector_floatsBufVars[2]
    vector_floatsBufVars[12] = vector_floatsBufVars[10]
  elif (vector_floatsBufVars[2] > vector_floatsBufVars[4]):
    vector_floatsBufVars[4] = vector_floatsBufVars[2] 
    vector_floatsBufVars[12] = vector_floatsBufVars[10]
  vector_floatsBufVars[3] += vector_floatsBufVars[5]
  vector_floatsBufVars[11] += 1
  # printf("module 2 : %u %u %u %u %u %u %u %u  \n", vector_floatsBufVars[0], vector_floatsBufVars[1], vector_floatsBufVars[2], vector_floatsBufVars[3], vector_floatsBufVars[4], vector_floatsBufVars[5], vector_floatsBufVars[6], vector_floatsBufVars[7])

  # update bufVars
  vector_floatsBufVars[1] = vector_floatsBufVars[2]
  vector_floatsBufVars[9] = vector_floatsBufVars[10]
  vector_floatsBufVars[0] = vector_floatsBufVars[1] - vector_floatsBufVars[3]
  vector_floatsBufVars[8] = vector_floatsBufVars[9] - vector_floatsBufVars[11]
  if (vector_floatsBufVars[7] < (vector_floatsBufVars[2] + vector_floatsBufVars[6])):
    vector_floatsBufVars[2] = 0
    vector_floatsBufVars[10] = 0
  vector_floatsBufVars[3] = 0
  vector_floatsBufVars[11] = 0  
  # printf("module 3 : %u %u %u %u %u %u %u %u  \n", vector_floatsBufVars[0], vector_floatsBufVars[1], vector_floatsBufVars[2], vector_floatsBufVars[3], vector_floatsBufVars[4], vector_floatsBufVars[5], vector_floatsBufVars[6], vector_floatsBufVars[7])

  if pNumTicks[0] >= 0:
  
    sem_post(pSigSems[2])
  # printf("module 1 : %u %u %u %u %u %u %u %u  \n", matrix_outBufVars[0], matrix_outBufVars[1], matrix_outBufVars[2], matrix_outBufVars[3], matrix_outBufVars[4], matrix_outBufVars[5], matrix_outBufVars[6], matrix_outBufVars[7])
  matrix_outBufVars[2] += matrix_outBufVars[5]
  matrix_outBufVars[10] += 1
  if (matrix_outBufVars[7] <= (matrix_outBufVars[2] + matrix_outBufVars[6])):
    matrix_outBufVars[4] = matrix_outBufVars[2]
    matrix_outBufVars[12] = matrix_outBufVars[10]
  elif (matrix_outBufVars[2] > matrix_outBufVars[4]):
    matrix_outBufVars[4] = matrix_outBufVars[2] 
    matrix_outBufVars[12] = matrix_outBufVars[10]
  matrix_outBufVars[3] += matrix_outBufVars[5]
  matrix_outBufVars[11] += 1
  # printf("module 2 : %u %u %u %u %u %u %u %u  \n", matrix_outBufVars[0], matrix_outBufVars[1], matrix_outBufVars[2], matrix_outBufVars[3], matrix_outBufVars[4], matrix_outBufVars[5], matrix_outBufVars[6], matrix_outBufVars[7])

  # update bufVars
  matrix_outBufVars[1] = matrix_outBufVars[2]
  matrix_outBufVars[9] = matrix_outBufVars[10]
  matrix_outBufVars[0] = matrix_outBufVars[1] - matrix_outBufVars[3]
  matrix_outBufVars[8] = matrix_outBufVars[9] - matrix_outBufVars[11]
  if (matrix_outBufVars[7] < (matrix_outBufVars[2] + matrix_outBufVars[6])):
    matrix_outBufVars[2] = 0
    matrix_outBufVars[10] = 0
  matrix_outBufVars[3] = 0
  matrix_outBufVars[11] = 0  
  # printf("module 3 : %u %u %u %u %u %u %u %u  \n", matrix_outBufVars[0], matrix_outBufVars[1], matrix_outBufVars[2], matrix_outBufVars[3], matrix_outBufVars[4], matrix_outBufVars[5], matrix_outBufVars[6], matrix_outBufVars[7])

  if pNumTicks[0] >= 0:
  
    sem_post(pSigSems[3])

  atomic_thread_fence(memory_order_seq_cst)
  sem_post(pModDownSem)

