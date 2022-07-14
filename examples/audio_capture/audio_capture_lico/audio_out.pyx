from libc.stdio cimport printf, stdout, fflush, remove
from libc.stdlib cimport exit, malloc, free, EXIT_SUCCESS, EXIT_FAILURE
from libc.stdint cimport int8_t, uint8_t, int16_t, uint16_t, int32_t, uint32_t, int64_t, uint64_t
from libc.signal cimport SIGINT, SIGUSR1, SIGALRM, SIGBUS, SIGSEGV, SIGQUIT, SIGUSR2
from posix.signal cimport kill, sigaction, sigaction_t, sigset_t, sigemptyset, sigaddset, sigfillset
from posix.unistd cimport getppid, pause, close, getpid, write
from posix.mman cimport shm_open, shm_unlink, mmap, munmap, PROT_READ, PROT_WRITE, MAP_SHARED, mlockall, MCL_CURRENT, MCL_FUTURE, munlockall
from posix.fcntl cimport O_RDWR, O_WRONLY, O_CREAT, O_TRUNC, open
from posix.types cimport pid_t
from libc.errno cimport errno, EINTR, EPIPE
from libc.string cimport memset, strcpy, strcat, strlen, memcpy
from posix.time cimport clock_gettime, CLOCK_MONOTONIC_RAW, timespec
DEF SIG_BLOCK = 1

import SharedArray as sa
import numpy as np
cimport numpy as np
cimport cython
import time

from .sink_drivers.audio_out_line cimport LineSinkDriver

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
  int sem_init(sem_t *sem, int pshared, unsigned int value)
  int sem_wait(sem_t *)
  int sem_post(sem_t *)
  int sem_destroy(sem_t *sem)

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
  enum: NUM_TABLES
  cdef const char *DATALOGGER_SIGNALS_TABLE_NAME
  cdef const char *DATALOGGER_FILENAME
  enum: NEW_DB_NUM_S
  enum: BUF_VARS_LEN
  enum: SQL_LOGGER_FLUSH



cdef pid_t ppid
cdef sigset_t exitMask
cdef char pathName[MAX_PATH_LEN]
#cdef struct timespec tickTimer

cdef int sigalrm_recv = 0

cdef size_t shm_size
cdef uint8_t *pmem
cdef int64_t *pNumTicks
cdef sem_t *pTickUpSems
cdef sem_t *pTickDownSems
cdef sem_t *pSigSems
cdef uint32_t *pBufVars
cdef uint8_t *outBuf
cdef size_t outBufLen
lastVal = 1

in_sigs = {}
in_sig = None
in_sigs['audio_signal_sink'] = None
cdef uint32_t *audio_signal_sinkBufVars
cdef int16_t *audio_signal_sinkStrtPtr
cdef int16_t *audio_signal_sinkEndPtr

cdef void handle_exit(int exitStatus):
  global retVal, tid, radio, context, s, shm_size, pmem

  

  driver.exit_handler(exitStatus)

  munmap(pmem, shm_size)
  munlockall()
  exit(exitStatus)

cdef void int_handler(int signum):
  pass

cdef void exit_handler(int signum):
  printf("EXIT HANDLER for audio_out\n")
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

cdef int pid = getpid()
ppid = getppid()

set_sighandler(SIGINT, &int_handler, &exitMask)
set_sighandler(SIGUSR1, &exit_handler, &exitMask)
set_sighandler(SIGBUS, &bus_handler, &exitMask)
set_sighandler(SIGSEGV, &segv_handler, &exitMask)
set_sighandler(SIGUSR2, &usr2_handler, NULL)

# open and map shared parent memory

shm_size = sizeof(uint64_t) + (sizeof(sem_t) * (1 + NUM_NON_SOURCES + NUM_SEM_SIGS)) + (sizeof(uint32_t) * BUF_VARS_LEN * NUM_INTERNAL_SIGS)
shm_size = ROUND_UP(shm_size, PAGESIZE)
open_shared_mem(&pmem, SMEM0_PATHNAME, shm_size, O_RDWR, PROT_READ | PROT_WRITE)
pNumTicks = <int64_t *>(pmem)
pTickUpSems = <sem_t *>(pmem +  sizeof(uint64_t) + 2 * sizeof(sem_t))
pTickDownSems = <sem_t *>(pmem + sizeof(uint64_t) + 2 * sizeof(sem_t) + (NUM_NON_SOURCES * sizeof(sem_t)))
pSigSems = <sem_t *>(pmem + sizeof(uint64_t) + 2 * sizeof(sem_t) + (2 * NUM_NON_SOURCES * sizeof(sem_t)))
pBufVars = <uint32_t *>(pmem + sizeof(uint64_t) + 2 * sizeof(sem_t) + (2 * NUM_NON_SOURCES * sizeof(sem_t)) + NUM_SEM_SIGS * sizeof(sem_t))

created_mem = sa.list()

if any([b'audio_signal_sink' == x[0] for x in created_mem]):
  in_sigs['audio_signal_sink'] = sa.attach("shm://audio_signal_sink")
  audio_signal_sinkRaw = in_sigs['audio_signal_sink']
  audio_signal_sinkBufVars = pBufVars + 16
  audio_signal_sink = audio_signal_sinkRaw[audio_signal_sinkBufVars[8]]
else:
  die("numpy signal not created\n")

audio_signal_sinkStrtPtr = <int16_t *><long>in_sigs['audio_signal_sink'].__array_interface__['data'][0] 
audio_signal_sinkEndPtr = audio_signal_sinkStrtPtr + len(in_sigs['audio_signal_sink'])



driver = LineSinkDriver()




make_realtime()

kill(ppid,SIGUSR1)

while(True):
  sem_wait(&pTickUpSems[0])
  sem_wait(&pSigSems[0])


  
  audio_signal_sink = audio_signal_sinkRaw[audio_signal_sinkBufVars[8]]
  
  audio_signal_sinkLen = audio_signal_sinkBufVars[1] - audio_signal_sinkBufVars[0]


  
  # TODO move to individual or pass as args?
  outBuf = <uint8_t *>(audio_signal_sinkStrtPtr + audio_signal_sinkBufVars[0])
  outBufLen = (audio_signal_sinkBufVars[1] - audio_signal_sinkBufVars[0]) * sizeof(audio_signal_sinkStrtPtr[0])
  
  driver.run(outBuf, outBufLen)

  sem_post(&pTickDownSems[0])
  sigalrm_recv -= 1