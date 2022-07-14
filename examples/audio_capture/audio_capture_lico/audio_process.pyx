
from libc.stdlib cimport atoi, exit
from libc.stdio cimport printf, fflush, stdout
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

cdef extern from "semaphore.h":
  enum: __SIZEOF_SEM_T
  cdef union sem_union:
    char __size[__SIZEOF_SEM_T]
    long int __align
  ctypedef sem_union sem_t
  int sem_wait(sem_t *)
  int sem_post(sem_t *)
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

cdef pid_t pid
cdef pid_t ppid
cdef char pathName[MAX_PATH_LEN]
cdef public sigset_t exitMask


# shared memory vars
cdef size_t shm_size

cdef uint8_t *pmem
cdef int64_t *pNumTicks
cdef sem_t *pTickUpSems
cdef sem_t *pTickDownSems
cdef sem_t *pSigSems
cdef uint32_t *pBufVars
cdef uint32_t *audio_signal_sinkBufVars

cdef uint32_t *audio_signal_sourceBufVars






cdef void handle_exit(int exitStatus):
  global pmem, shm_size
  
  sa_names = [sig.name for sig in sa.list()]
  if b"audio_signal_sink" in sa_names:
    sa.delete("shm://audio_signal_sink")
  else:
    printf("Could not delete shared array audio_signal_sink.\n")
  munmap(pmem, shm_size)
  
  munlockall()
  exit(exitStatus)

cdef void int_handler(int signum):
  pass

cdef void exit_handler(int signum):
  printf("EXIT HANDLER for audio_process\n")
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
shm_size = sizeof(uint64_t) + (sizeof(sem_t) * (1 + NUM_NON_SOURCES + NUM_SEM_SIGS)) + (sizeof(uint32_t) * BUF_VARS_LEN * NUM_INTERNAL_SIGS)
shm_size = ROUND_UP(shm_size, PAGESIZE)
open_shared_mem(&pmem, SMEM0_PATHNAME, shm_size, O_RDWR, PROT_READ | PROT_WRITE)
pNumTicks = <int64_t *>(pmem)
pTickUpSems = <sem_t *>(pmem + sizeof(uint64_t) + 2 * sizeof(sem_t))
pTickDownSems = <sem_t *>(pmem + sizeof(uint64_t) + 2 * sizeof(sem_t) + (NUM_NON_SOURCES * sizeof(sem_t)))
pSigSems = <sem_t *>(pmem + sizeof(uint64_t) + 2 * sizeof(sem_t) + (2 * NUM_NON_SOURCES * sizeof(sem_t)))
pBufVars = <uint32_t *>(pmem + sizeof(uint64_t) + 2 * sizeof(sem_t) + (2 * NUM_NON_SOURCES * sizeof(sem_t)) + NUM_SEM_SIGS * sizeof(sem_t))



created_mem = sa.list()
in_sigs = {}

if any([b'audio_signal_source' == x[0] for x in created_mem]):
  in_sigs["audio_signal_source"] = sa.attach("shm://audio_signal_source")
  audio_signal_sourceRaw = in_sigs["audio_signal_source"]
  audio_signal_sourceBufVars = pBufVars + 0
  audio_signal_source = audio_signal_sourceRaw[audio_signal_sourceBufVars[0]//8820]
else:
  print("audio_signal_source not created")
  die("signal not created")
out_sigs = {}

if any([b'audio_signal_sink' == x[0] for x in created_mem]):
  sa.delete("shm://audio_signal_sink")
  die("numpy signal audio_signal_sink already created")
else:
  out_sigs["audio_signal_sink"] = sa.create("shm://audio_signal_sink", (5999,8820), dtype=np.int16)
  # make sure SharedArray==2.0.4 -> try to transfer to 3.0.0
  out_sigs["audio_signal_sink"].base.mlock()

  ################################################################################
  
  ################################################################################

  audio_signal_sinkRaw = out_sigs["audio_signal_sink"]
  audio_signal_sinkBufVars = pBufVars + 16
  audio_signal_sink = audio_signal_sinkRaw[audio_signal_sinkBufVars[8]]
  audio_signal_sinkBufVars[7] = 52911180
  audio_signal_sinkBufVars[6] = 8820
  audio_signal_sinkBufVars[5] = 8820


###########################################
#attach to shared arrays


###########################################

# set signal mask
sigfillset(&exitMask)
# handle signals
set_sighandler(SIGINT, &int_handler, &exitMask)
set_sighandler(SIGUSR1, &exit_handler, &exitMask)
set_sighandler(SIGBUS, &mem_error_handler, &exitMask)
set_sighandler(SIGSEGV, &mem_error_handler, &exitMask)





from scipy import signal
import pygame
import pygame.midi
import time
from pedalboard import Pedalboard, Distortion, Reverb, Gain, Phaser, Bitcrush, PitchShift
import sys
np.set_printoptions(threshold=sys.maxsize)

pygame.midi.init()
print(flush=True)

midi_avail = True
if pygame.midi.get_count() < 3:
    print('External MIDI board not found! Disabling FX.\n', flush=True)
    midi_avail = False

if midi_avail:
    midi_input_device = 3
    mIn = pygame.midi.Input(midi_input_device)

sample_rate = 44100

# gain
gain_min = -30
gain_max = 5
gain_boards = [Pedalboard([Gain(gain_db=(gain_max - gain_min) * (i / 127.) + gain_min)]) for i in range(128)]
gain_board = gain_boards[len(gain_boards)//2]

# distortion
clip_ratio = .2
# distortion_board = Pedalboard([Distortion()])

# reverb
reverb_board = Pedalboard([Reverb(room_size=.5)])

# phaser
phaser_boards = [Pedalboard([Phaser(rate_hz=i+1, feedback=0.2, centre_frequency_hz=800.)]) for i in range(128)]
phaser_board = phaser_boards[64]

# bitcrush
bitcrush_board = Pedalboard([Bitcrush(bit_depth=8)])

# ptich shift
pitch_shift_min = -12
pitch_shift_max = 12
pitch_shift_boards = [Pedalboard([PitchShift(semitones=(pitch_shift_max - pitch_shift_min) * (i / 127.) + pitch_shift_min)]) for i in range(128)]
pitch_shift_board = pitch_shift_boards[64]

# lowpass filter
low_pass_min = 60
low_pass_max = 5000
low_filter_params_list = []
for i in range(128):
    lp_val = (low_pass_max - low_pass_min) * (i / 127.) + low_pass_min
    low_filter_params_list.append(signal.butter(3, lp_val, 'low', fs=sample_rate))
low_filter_params = low_filter_params_list[64]
low_z = signal.lfilter_zi(*low_filter_params)


# highpass filter
high_pass_min = 60
high_pass_max = 5000
high_filter_params_list = []
for i in range(128):
    lp_val = (high_pass_max - high_pass_min) * (i / 127.) + high_pass_min
    high_filter_params_list.append(signal.butter(3, lp_val, 'high', fs=sample_rate))
high_filter_params = high_filter_params_list[64]
high_z = signal.lfilter_zi(*high_filter_params)

enable_distortion = False
enable_bitcrush = False
enable_pitch_shift = False
enable_reverb = False
enable_phaser = False
enable_lowpass = False
enable_highpass = False
power_off = False
channel_select = -1


make_realtime()

kill(ppid,SIGUSR1)


while(True):
  sem_wait(&pTickUpSems[1])
  #clock_gettime(CLOCK_MONOTONIC_RAW, &ts)
  #printf("tick %lu, module audio_process triggered at %f.\n", pNumTicks[0], ts.tv_nsec/1000000.)

#  clock_gettime(CLOCK_MONOTONIC_RAW, &ts)
#  printf("\ttick %lu, module audio_process deps ready at %f.\n", pNumTicks[0], ts.tv_nsec/1000000.)

  
  # maybe don't do a divide in the future
  audio_signal_source = audio_signal_sourceRaw[audio_signal_sourceBufVars[0]//8820]
  
  
  audio_signal_sourceLen = audio_signal_sourceBufVars[1] - audio_signal_sourceBufVars[0]


  audio_signal_sink = audio_signal_sinkRaw[audio_signal_sinkBufVars[10]]

  # play noise
  # audio_signal_sink = np.random.random(audio_signal_source.shape)
  
  # print(f"bv0: {audio_signal_sourceBufVars[0]}, bv1: {audio_signal_sourceBufVars[1]}", flush=True)
  # print(flush=True)
  if midi_avail:
      while mIn.poll() :
          event = mIn.read(1)[0]
          ev_data = event[0]
          # print(event, flush=True)
  
          area = ev_data[0]
          control = ev_data[1] #which button
          value = ev_data[2] #value
  
          if area == 153: # pad pressed
              if control == 36: # pad 1
                  enable_lowpass = not enable_lowpass
                  print(f"lowpass: {enable_lowpass}", flush=True)
              if control == 37: # pad 2
                  enable_highpass = not enable_highpass
                  print(f"highpass: {enable_highpass}", flush=True)
              if control == 38: # pad 3
                  enable_distortion = not enable_distortion
                  print(f"distortion: {enable_distortion}", flush=True)
              if control == 39: # pad 4
                  enable_phaser = not enable_phaser
                  print(f"phaser: {enable_phaser}", flush=True)
              if control == 40: # pad 5
                  enable_pitch_shift = not enable_pitch_shift
                  print(f"pitch_shift: {enable_pitch_shift}", flush=True)
              if control == 41: # pad 6
                  channel_select += 1
                  if channel_select == 2:
                      channel_select = -1
                  print(f"channel_select: {channel_select}", flush=True)
              if control == 42: # pad 7
                  enable_reverb = not enable_reverb
                  print(f"reverb: {enable_reverb}", flush=True)
              if control == 43: # pad 5
                  enable_bitcrush = not enable_bitcrush
                  print(f"bitcrush: {enable_bitcrush}", flush=True)
              if control == 51: # pad 16
                  power_off = not power_off
                  print(f"power_off: {power_off}", flush=True)
  
          if area == 176: # knob turned
              if control == 3: # knob 1
                  low_filter_params = low_filter_params_list[value]
                  print(f"lowpass cutoff: {(low_pass_max - low_pass_min) * (value / 127.) + low_pass_min}", flush=True)
  
              if control == 9: # knob 2
                  high_filter_params = high_filter_params_list[value]
                  print(f"highpass cutoff: {(high_pass_max - high_pass_min) * (value / 127.) + high_pass_min}", flush=True)
  
  
              if control == 12: # knob 3
                  clip_ratio = 0.85 * (value / 127.) + 0.1
                  print(f"distortion clip: {clip_ratio}", flush=True)
  
              if control == 13: # knob 4
                  phaser_board = phaser_boards[value]
                  print(f"phaser rate: {value+1}", flush=True)
  
              if control == 14: # knob 5
                  pitch_shift_board = pitch_shift_boards[value]
                  print(f"pitch_shift value: {(pitch_shift_max - pitch_shift_min) * (value / 127.) + pitch_shift_min }", flush=True)
  
              if control == 15: # knob 6
                  gain_board = gain_boards[value]
                  print(f"gain: {(gain_max - gain_min) * (value / 127.) + gain_min}db", flush=True)
  
  
  res = audio_signal_source[:]
  
  # weird noise
  # max_val = np.max(res)
  # res = (res / max_val) * np.iinfo(np.int16).max / 2
  
  # gain
  res = gain_board(res, sample_rate)
  
  # distortion
  if enable_distortion:
      mean = int(np.mean(res))
      res -= mean
      clip_val = np.max(res) * clip_ratio
      np.clip(res, -1. * clip_val, clip_val, res)
      res += mean
      # res = distortion_board(res[:].astype(np.float32), sample_rate) 
  
  # reverb
  if enable_reverb:
      res = reverb_board(res, sample_rate)
  
  # phaser
  if enable_phaser:
      res = phaser_board(res, sample_rate)
  
  # bitcrush
  if enable_bitcrush:
      res = bitcrush_board(res, sample_rate)
  
  if enable_pitch_shift:
      res = pitch_shift_board(res, sample_rate)
  
  # filtering
  
  # lowpass
  if enable_lowpass:
      res, low_z = signal.lfilter(
          low_filter_params[0], low_filter_params[1], res, zi=low_z
      )
  
  # highpass
  if enable_highpass:
      res, high_z = signal.lfilter(
          high_filter_params[0], high_filter_params[1], res, zi=high_z
      )
  
  # channel select
  if channel_select >= 0:
      for i in range(res.size):
          if i % 2 == channel_select: # 0 for right; 1 for left
              res[i] = 0
  
  # poweroff
  if power_off:
      res = np.zeros(res.shape)
  
  
  # res = np.random.random(res.shape) * 1000
  # res = np.zeros(res.shape)
  audio_signal_sink[:] = res
  # audio_signal_sink[:] = audio_signal_source[:]
  
  # print(res.shape, flush=True)
  # print(np.count_nonzero(res), flush=True)
  # print(res[:], flush=True)
  

####################################################################


###################################################################


  # printf("module 1 : %u %u %u %u %u %u %u %u  \n", audio_signal_sinkBufVars[0], audio_signal_sinkBufVars[1], audio_signal_sinkBufVars[2], audio_signal_sinkBufVars[3], audio_signal_sinkBufVars[4], audio_signal_sinkBufVars[5], audio_signal_sinkBufVars[6], audio_signal_sinkBufVars[7])
  audio_signal_sinkBufVars[2] += audio_signal_sinkBufVars[5]
  audio_signal_sinkBufVars[10] += 1
  if (audio_signal_sinkBufVars[7] <= (audio_signal_sinkBufVars[2] + audio_signal_sinkBufVars[6])):
    audio_signal_sinkBufVars[4] = audio_signal_sinkBufVars[2]
    audio_signal_sinkBufVars[12] = audio_signal_sinkBufVars[10]
  elif (audio_signal_sinkBufVars[2] > audio_signal_sinkBufVars[4]):
    audio_signal_sinkBufVars[4] = audio_signal_sinkBufVars[2] 
    audio_signal_sinkBufVars[12] = audio_signal_sinkBufVars[10]
  audio_signal_sinkBufVars[3] += audio_signal_sinkBufVars[5]
  audio_signal_sinkBufVars[11] += 1
  # printf("module 2 : %u %u %u %u %u %u %u %u  \n", audio_signal_sinkBufVars[0], audio_signal_sinkBufVars[1], audio_signal_sinkBufVars[2], audio_signal_sinkBufVars[3], audio_signal_sinkBufVars[4], audio_signal_sinkBufVars[5], audio_signal_sinkBufVars[6], audio_signal_sinkBufVars[7])

  # update bufVars
  audio_signal_sinkBufVars[1] = audio_signal_sinkBufVars[2]
  audio_signal_sinkBufVars[9] = audio_signal_sinkBufVars[10]
  audio_signal_sinkBufVars[0] = audio_signal_sinkBufVars[1] - audio_signal_sinkBufVars[3]
  audio_signal_sinkBufVars[8] = audio_signal_sinkBufVars[9] - audio_signal_sinkBufVars[11]
  if (audio_signal_sinkBufVars[7] < (audio_signal_sinkBufVars[2] + audio_signal_sinkBufVars[6])):
    audio_signal_sinkBufVars[2] = 0
    audio_signal_sinkBufVars[10] = 0
  audio_signal_sinkBufVars[3] = 0
  audio_signal_sinkBufVars[11] = 0  
  # printf("module 3 : %u %u %u %u %u %u %u %u  \n", audio_signal_sinkBufVars[0], audio_signal_sinkBufVars[1], audio_signal_sinkBufVars[2], audio_signal_sinkBufVars[3], audio_signal_sinkBufVars[4], audio_signal_sinkBufVars[5], audio_signal_sinkBufVars[6], audio_signal_sinkBufVars[7])


  sem_post(&pSigSems[0])


  atomic_thread_fence(memory_order_seq_cst)
  sem_post(&pTickDownSems[1])
  #clock_gettime(CLOCK_MONOTONIC_RAW, &ts)
  #printf("tick %lu, module audio_process done at %f.\n", pNumTicks[0], ts.tv_nsec/1000000.)

