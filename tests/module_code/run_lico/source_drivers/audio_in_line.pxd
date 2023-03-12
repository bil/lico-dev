from posix.signal cimport sigset_t

from libc.stdint cimport uint8_t, uint32_t

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

    cdef uint8_t *outBuf
    cdef size_t outBufLen

    cdef ssize_t linePeriodSizeBytes
    cdef ssize_t lineBufferSizeBytes
    cdef snd_pcm_uframes_t lineBufferSizeFrames
    cdef snd_pcm_uframes_t linePeriodSizeFrames
    cdef ssize_t lineOutBufSize
    cdef long int lineBytesWrapped

    cdef void run(self, uint8_t *inBuf) except *  #, size_t inBufLen) except *
    cdef void exit_handler(self, int exitStatus) except *


