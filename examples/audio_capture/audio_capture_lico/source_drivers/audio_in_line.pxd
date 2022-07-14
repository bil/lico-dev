from libc.stdint cimport uint8_t, uint32_t
from posix.signal cimport sigset_t

from .source_driver cimport SourceDriver

cdef extern from "<sys/types.h>":
    ctypedef int pthread_t

cdef extern from "semaphore.h" nogil:
  cdef union sem_union:
    pass
  ctypedef sem_union sem_t

cdef extern from "<alsa/asoundlib.h>":
    struct _snd_pcm:
        pass
    ctypedef _snd_pcm snd_pcm_t
    struct _snd_pcm_hw_params:
        pass
    ctypedef _snd_pcm_hw_params snd_pcm_hw_params_t
    struct _snd_pcm_sw_params:
        pass 
    ctypedef _snd_pcm_sw_params snd_pcm_sw_params_t 
    ctypedef unsigned long snd_pcm_uframes_t

cdef class LineSourceDriver(SourceDriver):
    cdef int NPERIODS
    cdef snd_pcm_t *cap_handle
    cdef snd_pcm_hw_params_t *cap_hwparams
    cdef snd_pcm_sw_params_t *cap_swparams

    cdef int ret

    cdef uint8_t *pLineOutBuf
    cdef uint8_t *pLineOutBufWrite
    cdef uint8_t *pLineOutBufRead
    cdef ssize_t linePeriodSizeBytes
    cdef ssize_t lineBufferSizeBytes
    cdef snd_pcm_uframes_t lineBufferSizeFrames
    cdef snd_pcm_uframes_t linePeriodSizeFrames
    cdef ssize_t lineOutBufSize
    cdef long int lineBytesWrapped
    # threading variables
    cdef pthread_t tid
    cdef sem_t lineSem
    cdef bint shouldDie
    cdef sigset_t threadMask
    # worker thread vars
    cdef void *retVal
    cdef uint32_t lineWriteOffset
    cdef bint lineWrapped

    cdef void run_read(self) except *
    cdef void run_update(self, uint32_t *bufVars, void *bufCurPtr) except *
    cdef void exit_handler(self, int exitStatus) except *
    cdef void* processRequests(self, void *arg) nogil

