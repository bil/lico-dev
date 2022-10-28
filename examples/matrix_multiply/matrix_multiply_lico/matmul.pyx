
# cimport C libraries
from libc.stdlib cimport atoi, exit
from libc.stdio cimport printf, snprintf, fflush, stdout
from libc.string cimport strcpy, memset, memcpy
from libc.signal cimport SIGINT, SIGUSR1, SIGALRM, SIGBUS, SIGSEGV, SIGQUIT
from libc.stdint cimport int8_t, uint8_t, int16_t, uint16_t, int32_t, uint32_t, int64_t, uint64_t
from posix.signal cimport kill, sigaction, sigaction_t, sigset_t, sigemptyset, sigaddset, sigfillset
from posix.unistd cimport getppid, pause, close, getpid
from posix.mman cimport shm_open, mmap, munmap, PROT_READ, PROT_WRITE, MAP_SHARED, mlockall, MCL_CURRENT, MCL_FUTURE, munlockall, shm_unlink
from posix.types cimport pid_t
cimport posix.stat 
from posix.fcntl cimport O_RDWR, O_CREAT, O_TRUNC
from libcpp cimport bool
from posix.time cimport clock_gettime, CLOCK_MONOTONIC_RAW, timespec, nanosleep

import sys, signal
import SharedArray as sa
from cpython.exc cimport PyErr_CheckSignals
import random as random
import math
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
cimport numpy as np
cimport cython

cdef extern from "constants.h":
  enum: NUM_PAGES_IN_GB
  enum: MAX_PATH_LEN
  enum: NUM_CHILDREN
  enum: BYTES_IN_GB
  cdef const char *SMEM0_PATHNAME
  enum: PAGESIZE
  enum: LATENCY
  enum: NUM_NON_SOURCES
  enum: NUM_SEM_SIGS
  enum: NUM_INTERNAL_SIGS
  size_t ROUND_UP(int X, int Y)
  enum: BUF_VARS_LEN
  enum: SHM_SIZE
  enum: NUM_TICKS_OFFSET
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
cdef sem_t *pTickUpSem
cdef sem_t *pTickDownSem
cdef sem_t *pSigSems[NUM_SEM_SIGS]
cdef char semNameBuf[SEM_NAME_LEN]
cdef uint32_t *pBufVars
cdef uint32_t *matmul_outBufVars

cdef uint32_t *m2BufVars

cdef uint32_t *m1BufVars






cdef void handle_exit(int exitStatus):
  global pmem, shm_size, pTickUpSem, pTickDownSem, pSigSems
  
  sa.delete("shm://matmul_out")
  munmap(pmem, shm_size)
  
  munlockall()

  if (sem_close(pTickUpSem) == -1):
    printf("Could not close source up semaphore. \n")
  if (sem_close(pTickDownSem) == -1):
    printf("Could not close source down semaphore. \n")
  if (sem_close(pSigSems[0]) == -1):
    printf("Could not close source down semaphore. \n")
  if (sem_close(pSigSems[1]) == -1):
    printf("Could not close source down semaphore. \n")
  if (sem_close(pSigSems[2]) == -1):
    printf("Could not close source down semaphore. \n")

  exit(exitStatus)

cdef void int_handler(int signum):
  pass

cdef void exit_handler(int signum):
  printf("EXIT HANDLER for matmul\n")
  handle_exit(0)

cdef void mem_error_handler(int signum):
  printf("Child memory error: signum %d\n", signum)
  printf("Child ID: %d\n", 1)
  handle_exit(1)

# runtime code
# intialize utilityFunctions
sigfillset(&exitMask)
init_utils(&handle_exit, &exitMask)
ppid = getppid()
pid = getpid()
printf("child %d id: %d\n", 1, pid)

# open and map shared parent memory
shm_size = ROUND_UP(SHM_SIZE, PAGESIZE)
open_shared_mem(
  &pmem, SMEM0_PATHNAME, shm_size, O_RDWR, PROT_READ | PROT_WRITE
)
pNumTicks = <int64_t *>(pmem + NUM_TICKS_OFFSET)
pBufVars = <uint32_t *>(pmem + BUF_VARS_OFFSET)

pTickUpSem = sem_open("/tick_up_sem_1", 0)
pTickDownSem = sem_open("/tick_down_sem_1", 0)
snprintf(semNameBuf, SEM_NAME_LEN, "/sig_sem_%d", 0)
pSigSems[0] = sem_open(semNameBuf, 0)
snprintf(semNameBuf, SEM_NAME_LEN, "/sig_sem_%d", 1)
pSigSems[1] = sem_open(semNameBuf, 0)
snprintf(semNameBuf, SEM_NAME_LEN, "/sig_sem_%d", 2)
pSigSems[2] = sem_open(semNameBuf, 0)




in_sigs = {}
in_sigs["m2"] = sa.attach("shm://m2")
m2Raw = in_sigs["m2"]
m2BufVars = pBufVars + 16
m2 = m2Raw[m2BufVars[8]]
in_sigs["m1"] = sa.attach("shm://m1")
m1Raw = in_sigs["m1"]
m1BufVars = pBufVars + 0
m1 = m1Raw[m1BufVars[8]]

out_sigs = {}

out_sigs["matmul_out"] = create_shared_array(
  "shm://matmul_out", (5000,4, 4), dtype=np.float64
)
# make sure SharedArray==2.0.4 -> try to transfer to 3.0.0
out_sigs["matmul_out"].base.mlock()
matmul_outRaw = out_sigs["matmul_out"]
matmul_outBufVars = pBufVars + 32
matmul_out = matmul_outRaw[matmul_outBufVars[8]]
matmul_outBufVars[5] = 16
matmul_outBufVars[6] = 16
matmul_outBufVars[7] = 80000


# set signal mask
sigfillset(&exitMask)
# handle signals
set_sighandler(SIGINT, &int_handler, &exitMask)
set_sighandler(SIGUSR1, &exit_handler, &exitMask)
set_sighandler(SIGBUS, &mem_error_handler, &exitMask)
set_sighandler(SIGSEGV, &mem_error_handler, &exitMask)



# Numba constructor
import numba_matmul
numba_matmul.numba_matmul(np.zeros((4, 4), dtype='float64'),np.zeros((4, 4), dtype='float64'),np.zeros((4, 4), dtype='float64'))



kill(ppid,SIGUSR1)


while(True):
  sem_wait(pTickUpSem)
  #clock_gettime(CLOCK_MONOTONIC_RAW, &ts)
  #printf("tick %lu, module matmul triggered at %f.\n", pNumTicks[0], ts.tv_nsec/1000000.)

  sem_wait(pSigSems[0])

  sem_wait(pSigSems[1])

#  clock_gettime(CLOCK_MONOTONIC_RAW, &ts)
#  printf("\ttick %lu, module matmul deps ready at %f.\n", pNumTicks[0], ts.tv_nsec/1000000.)

  m2 = m2Raw[m2BufVars[8]]
  m2Len = m2BufVars[1] - m2BufVars[0]

  m1 = m1Raw[m1BufVars[8]]
  m1Len = m1BufVars[1] - m1BufVars[0]


  matmul_out = matmul_outRaw[matmul_outBufVars[10]]

  numba_matmul.numba_matmul(m1,m2,matmul_out)



  # printf("module 1 : %u %u %u %u %u %u %u %u  \n", matmul_outBufVars[0], matmul_outBufVars[1], matmul_outBufVars[2], matmul_outBufVars[3], matmul_outBufVars[4], matmul_outBufVars[5], matmul_outBufVars[6], matmul_outBufVars[7])
  matmul_outBufVars[2] += matmul_outBufVars[5]
  matmul_outBufVars[10] += 1
  if (matmul_outBufVars[7] <= (matmul_outBufVars[2] + matmul_outBufVars[6])):
    matmul_outBufVars[4] = matmul_outBufVars[2]
    matmul_outBufVars[12] = matmul_outBufVars[10]
  elif (matmul_outBufVars[2] > matmul_outBufVars[4]):
    matmul_outBufVars[4] = matmul_outBufVars[2] 
    matmul_outBufVars[12] = matmul_outBufVars[10]
  matmul_outBufVars[3] += matmul_outBufVars[5]
  matmul_outBufVars[11] += 1
  # printf("module 2 : %u %u %u %u %u %u %u %u  \n", matmul_outBufVars[0], matmul_outBufVars[1], matmul_outBufVars[2], matmul_outBufVars[3], matmul_outBufVars[4], matmul_outBufVars[5], matmul_outBufVars[6], matmul_outBufVars[7])

  # update bufVars
  matmul_outBufVars[1] = matmul_outBufVars[2]
  matmul_outBufVars[9] = matmul_outBufVars[10]
  matmul_outBufVars[0] = matmul_outBufVars[1] - matmul_outBufVars[3]
  matmul_outBufVars[8] = matmul_outBufVars[9] - matmul_outBufVars[11]
  if (matmul_outBufVars[7] < (matmul_outBufVars[2] + matmul_outBufVars[6])):
    matmul_outBufVars[2] = 0
    matmul_outBufVars[10] = 0
  matmul_outBufVars[3] = 0
  matmul_outBufVars[11] = 0  
  # printf("module 3 : %u %u %u %u %u %u %u %u  \n", matmul_outBufVars[0], matmul_outBufVars[1], matmul_outBufVars[2], matmul_outBufVars[3], matmul_outBufVars[4], matmul_outBufVars[5], matmul_outBufVars[6], matmul_outBufVars[7])


  sem_post(pSigSems[2])


  atomic_thread_fence(memory_order_seq_cst)
  sem_post(pTickDownSem)
  #clock_gettime(CLOCK_MONOTONIC_RAW, &ts)
  #printf("tick %lu, module matmul done at %f.\n", pNumTicks[0], ts.tv_nsec/1000000.)

