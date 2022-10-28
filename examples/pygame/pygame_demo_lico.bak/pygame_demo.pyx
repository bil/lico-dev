from libc.stdio cimport printf, stdout, fflush, remove
from libc.stdio cimport printf, snprintf, stdout, fflush, remove
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

from .sink_drivers.pygame_demo_vis_pygame cimport Vis_pygameSinkDriver

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
  enum: SEM_NAME_LEN

cdef pid_t ppid
cdef sigset_t exitMask
cdef char pathName[MAX_PATH_LEN]
#cdef struct timespec tickTimer

cdef int sigalrm_recv = 0

cdef size_t shm_size
cdef uint8_t *pmem
cdef int64_t *pNumTicks
cdef sem_t *pTickUpSem
cdef sem_t *pTickDownSem
cdef sem_t *pSigSems[NUM_SEM_SIGS]
cdef char semNameBuf[SEM_NAME_LEN]
cdef uint32_t *pBufVars
cdef uint8_t *outBuf
cdef size_t outBufLen
lastVal = 1

in_sigs = {}

cdef void handle_exit(int exitStatus):
  global retVal, tid, radio, context, s, shm_size, pmem, pTickUpSem, pTickDownSem, pSigSems

  pygame.quit()
  

  driver.exit_handler(exitStatus)

  munmap(pmem, shm_size)
  munlockall()

  sem_close

  if (sem_close(pTickUpSem) == -1):
    printf("Could not close source up semaphore. \n")
  if (sem_close(pTickDownSem) == -1):
    printf("Could not close source down semaphore. \n")

  exit(exitStatus)

cdef void int_handler(int signum):
  pass

cdef void exit_handler(int signum):
  printf("EXIT HANDLER for pygame_demo\n")
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

shm_size = ROUND_UP(SHM_SIZE, PAGESIZE)
open_shared_mem(&pmem, SMEM0_PATHNAME, shm_size, O_RDWR, PROT_READ | PROT_WRITE)
pNumTicks = <int64_t *>(pmem + NUM_TICKS_OFFSET)
pBufVars = <uint32_t *>(pmem + BUF_VARS_OFFSET)

pTickUpSem = sem_open("/tick_up_sem_0", 0)
pTickDownSem = sem_open("/tick_down_sem_0", 0)
  

driver = Vis_pygameSinkDriver()


import math

import pygame

pygame.display.init()


class Circle(pygame.sprite.Sprite):
    def __init__(self, color, radius, pos):
        pygame.sprite.Sprite.__init__(self)
        self.radius = radius
        self.color = color

        self.image = pygame.Surface([radius * 2, radius * 2]).convert_alpha()
        self.draw()

        self.rect = self.image.get_rect()
        self.rect.x, self.rect.y = pos

    def set_color(self, color):
        self.color = color
        self.draw()

    def get_pos(self):
        return (self.rect.x, self.rect.y)

    def set_pos(self, pos):
        self.rect.x, self.rect.y = pos

    def set_size(self, radius):
        cur_pos = self.rect.x, self.rect.y
        self.radius = radius
        self.image = pygame.Surface(
            [self.radius * 2, self.radius * 2]
        ).convert_alpha()
        self.rect = self.image.get_rect()
        self.rect.x, self.rect.y = cur_pos
        self.draw()

    def draw(self):
        self.image.fill((0, 0, 0, 0))
        pygame.draw.circle(
            self.image, self.color, (self.radius, self.radius), self.radius
        )


black = (0, 0, 0)
screen_width = 1280
screen_height = 1024
screen = pygame.display.set_mode((screen_width, screen_height))
screen.fill(black)

# used in both pygame_demo and cursor_track
color = [200, 200, 0]
pos = [0, 0]
circle_size = 30

# these variables only used for pygame demo
r = 200
theta = 0
offset = [500, 500]

vel_scale = 10

cir1 = Circle(color, circle_size, pos)

sprites = pygame.sprite.Group(cir1)

refresh_rate = 2  # ticks (10 ms)

kill(ppid,SIGUSR1)

while(True):
  sem_wait(pTickUpSem)



  if not pNumTicks[0] % refresh_rate:
  
      theta += math.pi / 64
  
      pos = (
          r * math.cos(theta) + offset[0],
          r * math.sin(2 * theta) + offset[1],
      )
      cir1.set_pos(pos)
  
      screen.fill(black)
      sprites.draw(screen)
      pygame.display.flip()
  
  
  driver.run(outBuf, outBufLen)

  sem_post(pTickDownSem)
  sigalrm_recv -= 1