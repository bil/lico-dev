
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
cdef uint32_t *m2BufVars

cdef uint32_t *m1BufVars






cdef void handle_exit(int exitStatus):
  global pmem, shm_size, pTickUpSem, pTickDownSem, pSigSems
  
  sa.delete("shm://m2")
  sa.delete("shm://m1")
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

  exit(exitStatus)

cdef void int_handler(int signum):
  pass

cdef void exit_handler(int signum):
  printf("EXIT HANDLER for matmul_init\n")
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
pBufVars = <uint32_t *>(pmem + BUF_VARS_OFFSET)

pTickUpSem = sem_open("/tick_up_sem_0", 0)
pTickDownSem = sem_open("/tick_down_sem_0", 0)
snprintf(semNameBuf, SEM_NAME_LEN, "/sig_sem_%d", 0)
pSigSems[0] = sem_open(semNameBuf, 0)
snprintf(semNameBuf, SEM_NAME_LEN, "/sig_sem_%d", 1)
pSigSems[1] = sem_open(semNameBuf, 0)




in_sigs = {}

out_sigs = {}

out_sigs["m2"] = create_shared_array(
  "shm://m2", (5000,4, 4), dtype=np.float64
)
# make sure SharedArray==2.0.4 -> try to transfer to 3.0.0
out_sigs["m2"].base.mlock()
m2Raw = out_sigs["m2"]
m2BufVars = pBufVars + 16
m2 = m2Raw[m2BufVars[8]]
m2BufVars[5] = 16
m2BufVars[6] = 16
m2BufVars[7] = 80000

out_sigs["m1"] = create_shared_array(
  "shm://m1", (5000,4, 4), dtype=np.float64
)
# make sure SharedArray==2.0.4 -> try to transfer to 3.0.0
out_sigs["m1"].base.mlock()
m1Raw = out_sigs["m1"]
m1BufVars = pBufVars + 0
m1 = m1Raw[m1BufVars[8]]
m1BufVars[5] = 16
m1BufVars[6] = 16
m1BufVars[7] = 80000


# set signal mask
sigfillset(&exitMask)
# handle signals
set_sighandler(SIGINT, &int_handler, &exitMask)
set_sighandler(SIGUSR1, &exit_handler, &exitMask)
set_sighandler(SIGBUS, &mem_error_handler, &exitMask)
set_sighandler(SIGSEGV, &mem_error_handler, &exitMask)





# import numpy as np # numpy already imported in module template

m1_init = np.random.rand(4, 4)
m2_init = np.random.rand(4, 4)

kill(ppid,SIGUSR1)


while(True):
  sem_wait(pTickUpSem)
  #clock_gettime(CLOCK_MONOTONIC_RAW, &ts)
  #printf("tick %lu, module matmul_init triggered at %f.\n", pNumTicks[0], ts.tv_nsec/1000000.)

#  clock_gettime(CLOCK_MONOTONIC_RAW, &ts)
#  printf("\ttick %lu, module matmul_init deps ready at %f.\n", pNumTicks[0], ts.tv_nsec/1000000.)


  m2 = m2Raw[m2BufVars[10]]

  m1 = m1Raw[m1BufVars[10]]

  # if init only happens on first tick, only writes to first slot in history
  m1[:, :] = m1_init[:, :]
  m2[:, :] = m2_init[:, :]
  


  # printf("module 1 : %u %u %u %u %u %u %u %u  \n", m1BufVars[0], m1BufVars[1], m1BufVars[2], m1BufVars[3], m1BufVars[4], m1BufVars[5], m1BufVars[6], m1BufVars[7])
  m1BufVars[2] += m1BufVars[5]
  m1BufVars[10] += 1
  if (m1BufVars[7] <= (m1BufVars[2] + m1BufVars[6])):
    m1BufVars[4] = m1BufVars[2]
    m1BufVars[12] = m1BufVars[10]
  elif (m1BufVars[2] > m1BufVars[4]):
    m1BufVars[4] = m1BufVars[2] 
    m1BufVars[12] = m1BufVars[10]
  m1BufVars[3] += m1BufVars[5]
  m1BufVars[11] += 1
  # printf("module 2 : %u %u %u %u %u %u %u %u  \n", m1BufVars[0], m1BufVars[1], m1BufVars[2], m1BufVars[3], m1BufVars[4], m1BufVars[5], m1BufVars[6], m1BufVars[7])

  # update bufVars
  m1BufVars[1] = m1BufVars[2]
  m1BufVars[9] = m1BufVars[10]
  m1BufVars[0] = m1BufVars[1] - m1BufVars[3]
  m1BufVars[8] = m1BufVars[9] - m1BufVars[11]
  if (m1BufVars[7] < (m1BufVars[2] + m1BufVars[6])):
    m1BufVars[2] = 0
    m1BufVars[10] = 0
  m1BufVars[3] = 0
  m1BufVars[11] = 0  
  # printf("module 3 : %u %u %u %u %u %u %u %u  \n", m1BufVars[0], m1BufVars[1], m1BufVars[2], m1BufVars[3], m1BufVars[4], m1BufVars[5], m1BufVars[6], m1BufVars[7])


  sem_post(pSigSems[0])


  # printf("module 1 : %u %u %u %u %u %u %u %u  \n", m2BufVars[0], m2BufVars[1], m2BufVars[2], m2BufVars[3], m2BufVars[4], m2BufVars[5], m2BufVars[6], m2BufVars[7])
  m2BufVars[2] += m2BufVars[5]
  m2BufVars[10] += 1
  if (m2BufVars[7] <= (m2BufVars[2] + m2BufVars[6])):
    m2BufVars[4] = m2BufVars[2]
    m2BufVars[12] = m2BufVars[10]
  elif (m2BufVars[2] > m2BufVars[4]):
    m2BufVars[4] = m2BufVars[2] 
    m2BufVars[12] = m2BufVars[10]
  m2BufVars[3] += m2BufVars[5]
  m2BufVars[11] += 1
  # printf("module 2 : %u %u %u %u %u %u %u %u  \n", m2BufVars[0], m2BufVars[1], m2BufVars[2], m2BufVars[3], m2BufVars[4], m2BufVars[5], m2BufVars[6], m2BufVars[7])

  # update bufVars
  m2BufVars[1] = m2BufVars[2]
  m2BufVars[9] = m2BufVars[10]
  m2BufVars[0] = m2BufVars[1] - m2BufVars[3]
  m2BufVars[8] = m2BufVars[9] - m2BufVars[11]
  if (m2BufVars[7] < (m2BufVars[2] + m2BufVars[6])):
    m2BufVars[2] = 0
    m2BufVars[10] = 0
  m2BufVars[3] = 0
  m2BufVars[11] = 0  
  # printf("module 3 : %u %u %u %u %u %u %u %u  \n", m2BufVars[0], m2BufVars[1], m2BufVars[2], m2BufVars[3], m2BufVars[4], m2BufVars[5], m2BufVars[6], m2BufVars[7])


  sem_post(pSigSems[1])


  atomic_thread_fence(memory_order_seq_cst)
  sem_post(pTickDownSem)
  #clock_gettime(CLOCK_MONOTONIC_RAW, &ts)
  #printf("tick %lu, module matmul_init done at %f.\n", pNumTicks[0], ts.tv_nsec/1000000.)

