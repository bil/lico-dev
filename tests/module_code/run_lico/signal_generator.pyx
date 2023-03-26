
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
cdef uint32_t *int8_signalBufVars






cdef void handle_exit(int exitStatus):
  global pmem, shm_size, pModUpSem, pModDownSem, pSigSems
  
  sa.delete("shm://int8_signal")
  munmap(pmem, shm_size)
  munlockall()

  if (sem_close(pModUpSem) == -1):
    printf("Could not close source up semaphore. \n")
  if (sem_close(pModDownSem) == -1):
    printf("Could not close source down semaphore. \n")
  if (sem_close(pSigSems[0]) == -1):
    printf("Could not close signal semaphore. \n")

  exit(exitStatus)

cdef void int_handler(int signum):
  pass

cdef void exit_handler(int signum):
  printf("EXIT HANDLER for signal_generator\n")
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


in_sigs = {}

out_sigs = {}

out_sigs["int8_signal"] = create_shared_array(
  "shm://int8_signal", (5000,1), dtype=np.int8
)
# make sure SharedArray==2.0.4 -> try to transfer to 3.0.0
out_sigs["int8_signal"].base.mlock()
int8_signalRaw = out_sigs["int8_signal"]
int8_signalBufVars = pBufVars + 0
int8_signal = int8_signalRaw[int8_signalBufVars[8]]
int8_signalBufVars[5] = 1
int8_signalBufVars[6] = 1
int8_signalBufVars[7] = 5000


# set signal mask
sigfillset(&exitMask)
# handle signals
set_sighandler(SIGINT, &int_handler, &exitMask)
set_sighandler(SIGUSR1, &exit_handler, &exitMask)
set_sighandler(SIGBUS, &mem_error_handler, &exitMask)
set_sighandler(SIGSEGV, &mem_error_handler, &exitMask)






generated_int8_signal = np.array(0, dtype=np.int8)


kill(ppid,SIGUSR1)

cdef int semVal
while(True):
  sem_wait(pModUpSem)


  time_system = pClockTime[0].tv_sec + pClockTime[0].tv_nsec / 1.0e9
  if pNumTicks[0] >= 0:
    time_tick = pNumTicks[0]



  int8_signal = int8_signalRaw[int8_signalBufVars[10]]

  
  if generated_int8_signal < 100:
      generated_int8_signal = np.add(
          generated_int8_signal, 1, dtype=np.int8
      )
  else:
      generated_int8_signal = np.array(1, dtype=np.int8)
  
  # write to outputs
      
  int8_signal[:] = generated_int8_signal
      
  
  


  # printf("module 1 : %u %u %u %u %u %u %u %u  \n", int8_signalBufVars[0], int8_signalBufVars[1], int8_signalBufVars[2], int8_signalBufVars[3], int8_signalBufVars[4], int8_signalBufVars[5], int8_signalBufVars[6], int8_signalBufVars[7])
  int8_signalBufVars[2] += int8_signalBufVars[5]
  int8_signalBufVars[10] += 1
  if (int8_signalBufVars[7] <= (int8_signalBufVars[2] + int8_signalBufVars[6])):
    int8_signalBufVars[4] = int8_signalBufVars[2]
    int8_signalBufVars[12] = int8_signalBufVars[10]
  elif (int8_signalBufVars[2] > int8_signalBufVars[4]):
    int8_signalBufVars[4] = int8_signalBufVars[2] 
    int8_signalBufVars[12] = int8_signalBufVars[10]
  int8_signalBufVars[3] += int8_signalBufVars[5]
  int8_signalBufVars[11] += 1
  # printf("module 2 : %u %u %u %u %u %u %u %u  \n", int8_signalBufVars[0], int8_signalBufVars[1], int8_signalBufVars[2], int8_signalBufVars[3], int8_signalBufVars[4], int8_signalBufVars[5], int8_signalBufVars[6], int8_signalBufVars[7])

  # update bufVars
  int8_signalBufVars[1] = int8_signalBufVars[2]
  int8_signalBufVars[9] = int8_signalBufVars[10]
  int8_signalBufVars[0] = int8_signalBufVars[1] - int8_signalBufVars[3]
  int8_signalBufVars[8] = int8_signalBufVars[9] - int8_signalBufVars[11]
  if (int8_signalBufVars[7] < (int8_signalBufVars[2] + int8_signalBufVars[6])):
    int8_signalBufVars[2] = 0
    int8_signalBufVars[10] = 0
  int8_signalBufVars[3] = 0
  int8_signalBufVars[11] = 0  
  # printf("module 3 : %u %u %u %u %u %u %u %u  \n", int8_signalBufVars[0], int8_signalBufVars[1], int8_signalBufVars[2], int8_signalBufVars[3], int8_signalBufVars[4], int8_signalBufVars[5], int8_signalBufVars[6], int8_signalBufVars[7])

  if pNumTicks[0] >= 0:
  
    sem_post(pSigSems[0])

  atomic_thread_fence(memory_order_seq_cst)
  sem_post(pModDownSem)

