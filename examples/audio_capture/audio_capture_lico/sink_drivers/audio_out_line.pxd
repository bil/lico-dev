from posix.signal cimport sigset_t

from libc.stdint cimport uint8_t, uint32_t

from .sink_driver cimport SinkDriver


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

cdef extern from "../lineUtilities.h" nogil:
  ctypedef struct pcm_values_t:
    const char *device
    int mode
    snd_pcm_access_t access
    snd_pcm_format_t format
    unsigned int channels
    int rate
    unsigned int buffer_time
    unsigned int period_time
    int periods
    snd_pcm_sframes_t buffer_size
    snd_pcm_sframes_t period_size

cdef class LineSinkDriver(SinkDriver):
    cdef snd_pcm_t *play_handle
    cdef snd_pcm_hw_params_t *play_hwparams
    cdef snd_pcm_sw_params_t *play_swparams
    cdef {{out_dtype}} *pLineOutBuf
    cdef {{out_dtype}} *pLineOutBufWrite
    cdef {{out_dtype}} *pLineOutBufRead
    cdef ssize_t linePeriodSizeBytes
    cdef ssize_t linePeriodSizeSamples
    cdef snd_pcm_uframes_t linePeriodSizeFrames
    cdef ssize_t lineOutBufSizeBytes
    cdef ssize_t lineOutBufSizeSamples
    cdef long int lineSamplesWrapped
    cdef pcm_values_t play_values

    cdef void run(self, uint8_t *outBuf, size_t outBufLen) except *
    cdef void exit_handler(self, int exitStatus) except *
    cdef void* processRequests(self, void *arg) nogil
