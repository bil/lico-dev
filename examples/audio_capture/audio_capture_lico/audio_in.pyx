# declare jinja variables


# cimport C libraries
from libc.stdio cimport printf, stdout, fflush
from libc.stdlib cimport exit, malloc, free, calloc, EXIT_SUCCESS, EXIT_FAILURE
from libc.stdint cimport int8_t, uint8_t, int16_t, uint16_t, int32_t, uint32_t, int64_t, uint64_t
from libc.signal cimport SIGINT, SIGUSR1, SIGALRM, SIGBUS, SIGSEGV, SIGQUIT, SIGUSR2
from libc.string cimport memset, memcpy
from libc.errno cimport errno, EINTR, EPIPE, EAGAIN
from posix.signal cimport kill, sigaction, sigaction_t, sigset_t, sigemptyset, sigaddset, sigfillset
from posix.unistd cimport getppid, pause, close, getpid, read, sleep
from posix.mman cimport shm_open, mmap, munmap, PROT_READ, PROT_WRITE, MAP_SHARED, mlockall, MCL_CURRENT, MCL_FUTURE, munlockall
from posix.types cimport pid_t
from posix.fcntl cimport O_RDWR, open, fcntl, O_RDONLY, F_SETFL, O_NONBLOCK
from posix.ioctl cimport ioctl
from posix.time cimport clock_gettime, CLOCK_MONOTONIC_RAW, timespec

# import Python libraries
import sys
import os
import SharedArray as sa

# cimport key Python libraries
import numpy as np
cimport numpy as np
cimport cython

# import driver
from .source_drivers.audio_in_line cimport LineSourceDriver

cdef extern from "<sys/socket.h>":
  ctypedef uint32_t socklen_t

# headers for all sources
cdef extern from "semaphore.h" nogil:
  cdef union sem_union:
    pass
  ctypedef sem_union sem_t
  int sem_init(sem_t *sem, int pshared, unsigned int value)
  int sem_wait(sem_t *)
  int sem_post(sem_t *)
  int sem_destroy(sem_t *sem)

cdef extern from "utilityFunctions.h":
  void init_utils(void (*pHandleExit)(int exitStatus), sigset_t *pExitMask)
  void die(char *errorStr)
  void open_shared_mem(uint8_t **ppmem, const char *pName, int numBytes, int shm_flags, int mmap_flags)
  void set_sighandler(int signum, void *psh, sigset_t *block_mask)
  void make_realtime()

cdef extern from "constants.h":
  enum: NUM_CHANNELSf
  enum: MAX_PATH_LEN
  enum: PAGESIZE
  enum: INIT_BUFFER_TICKS
  enum: BYTES_PER_FRAME
  const char *SMEM0_PATHNAME
  enum: NUM_NON_SOURCES
  enum: NUM_SEM_SIGS
  enum: NUM_INTERNAL_SIGS
  size_t ROUND_UP(int X, int Y)
  enum: BUF_VARS_LEN

# cdef variables
cdef pid_t ppid
cdef sigset_t exitMask
cdef char pathName[MAX_PATH_LEN]
cdef socklen_t recvLen
cdef char *outbuf
cdef int parse_idx

cdef size_t shm_size
cdef uint8_t *pmem
cdef int64_t *pNumTicks
cdef sem_t *pSourceUpSem
cdef sem_t *pSourceDownSem
cdef uint32_t *pBufVars
# 0: tick start
# 1: tick end
# 2: next data location
# 3: num samples received this tick
# 4: buffer end offset (samples)
# 5: packet size (bytes)
# 6: max samples per tick (samples)
# 7: buffer size offset (samples)
cdef unsigned long packetNum = 0
cdef unsigned long numDropped = 0
cdef int i

cdef uint32_t packetSize = 17640 * sizeof(int16_t)
cdef int16_t *bufStrtPtr
cdef int16_t *bufEndPtr
cdef int16_t *bufCurPtr # declare signal BufVars pointers (to point into pBufVars)
cdef uint32_t *audio_signal_sourceBufVars
cdef int16_t *audio_signal_sourceStrtPtr

# python variables
parentSetup = True

# declare output signals
out_sigs = {} # output packing is handled by parser code
out_sig = None

# function to close the source
cdef void handle_exit(int exitStatus):
  global pmem, shm_size, pNumTicks, numDropped, udpReadThread, exitMutex, exitRoutine
  

# delete the signal's shared memory array
  sa_names = [sig.name for sig in sa.list()]
  if b"audio_signal_source" in sa_names:
    sa.delete("shm://audio_signal_source")
  else:
    printf("Could not delete shared array audio_signal_source.\n")

  driver.exit_handler(exitStatus)

  munmap(pmem, shm_size)
  munlockall()
  exit(exitStatus)


cdef void int_handler(int signum):
  pass

cdef void exit_handler(int signum):
  printf("EXIT HANDLER for audio_in\n")
  handle_exit(0)

cdef void bus_handler(int signum):
  printf("Bus Error\n")
  handle_exit(1)

cdef void segv_handler(int signum):
  printf("Seg Fault\n")
  handle_exit(1)

# sources respond to SIGALRM 
cdef void alrm_handler(int signum):
  global parentSetup, read_source_input
  if (parentSetup):
    parentSetup = False

  # some are triggered to read based on SIGALRM
  driver.alrm_handler()

cdef void usr2_handler(int signum):
  pass

# main
sigfillset(&exitMask)
init_utils(&handle_exit, &exitMask)

cdef int pid = getpid()
ppid = getppid()

set_sighandler(SIGALRM, &alrm_handler, NULL)
set_sighandler(SIGINT, &int_handler, &exitMask)
set_sighandler(SIGUSR1, &exit_handler, &exitMask)
set_sighandler(SIGBUS, &bus_handler, &exitMask)
set_sighandler(SIGSEGV, &segv_handler, &exitMask)
set_sighandler(SIGUSR2, &usr2_handler, NULL)

shm_size = sizeof(uint64_t) + (sizeof(sem_t) * (1 + NUM_NON_SOURCES + NUM_SEM_SIGS)) + (sizeof(uint32_t) * BUF_VARS_LEN * NUM_INTERNAL_SIGS)
shm_size = ROUND_UP(shm_size, PAGESIZE)
open_shared_mem(&pmem, SMEM0_PATHNAME, shm_size, O_RDWR, PROT_READ | PROT_WRITE)
pNumTicks = <int64_t *>(pmem)
pSourceUpSem = <sem_t *>(pmem + sizeof(uint64_t))
pSourceDownSem = <sem_t *>(pmem + sizeof(uint64_t) + sizeof(sem_t))
pBufVars = <uint32_t *>(pmem + sizeof(uint64_t) + 2 * sizeof(sem_t) + (2 * NUM_NON_SOURCES * sizeof(sem_t)) + NUM_SEM_SIGS * sizeof(sem_t))

created_mem = sa.list()

if any([b'audio_signal_source' == x[0] for x in created_mem]):
  sa.delete("shm://audio_signal_source")
  printf("Numpy signal audio_signal_source already created. Overwriting\n")

dtype = np.int16
out_sigs['audio_signal_source'] = sa.create("shm://audio_signal_source", (14999,8820), dtype=dtype)
audio_signal_source = out_sigs['audio_signal_source']
audio_signal_sourceStrtPtr = <int16_t *><long>out_sigs['audio_signal_source'].__array_interface__['data'][0]
out_sig = out_sigs['audio_signal_source']

audio_signal_sourceBufVars = pBufVars + (0)
audio_signal_sourceBufVars[7] = 132291180

# TODO put sigBufVars in struct to support parser
driver = LineSourceDriver(out_sig)
bufStrtPtr = <int16_t *><long>out_sig.__array_interface__['data'][0]   
bufCurPtr = bufStrtPtr
bufEndPtr = bufStrtPtr + audio_signal_sourceBufVars[7]
# bufEndPtr = bufStrtPtr + packetSize





  

make_realtime()
fflush(stdout)
kill(ppid, SIGUSR2) # this source is initialized

pause()
#start the asychronous read thread if signal type is udp

while(True):
  bufCurPtr = bufStrtPtr + audio_signal_sourceBufVars[2]

  driver.run()

  if (parentSetup):
    continue
  # sempahore needs to be before parser (unfortunately includes memcpy) so that interrupt doesn't happen between 
  # when BufVars[2] is read by the parser and when it is updated below.
  sem_wait(pSourceUpSem) 

#
  # memcpy(audio_signal_sourceStrtPtr + audio_signal_sourceBufVars[2], bufStrtPtr, packetSize)
  # TODO figure out how to step through data for something like line (artificial data packaging per tick)
  # print "source: {0} {1} {2} {3} {4} {5} {6} {7}".format(audio_signal_sourceBufVars[0],audio_signal_sourceBufVars[1],audio_signal_sourceBufVars[2],audio_signal_sourceBufVars[3],audio_signal_sourceBufVars[4],audio_signal_sourceBufVars[5],audio_signal_sourceBufVars[6],audio_signal_sourceBufVars[7])

  #driver.run_update(audio_signal_sourceBufVars, bufCurPtr)

  # print "audio_signal_source source: {0} {1} {2} {3} {4} {5} {6} {7}".format(audio_signal_sourceBufVars[0],audio_signal_sourceBufVars[1],audio_signal_sourceBufVars[2],audio_signal_sourceBufVars[3],audio_signal_sourceBufVars[4],audio_signal_sourceBufVars[5],audio_signal_sourceBufVars[6],audio_signal_sourceBufVars[7])

  sem_post(pSourceDownSem)