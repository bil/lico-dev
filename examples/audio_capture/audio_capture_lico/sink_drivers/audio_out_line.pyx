from libc.stdio cimport printf
from libc.stdlib cimport malloc, free, EXIT_SUCCESS, EXIT_FAILURE
from libc.stdint cimport int8_t, uint8_t, int16_t, uint16_t, int32_t, uint32_t, int64_t, uint64_t
from posix.signal cimport sigset_t, sigfillset
from libc.string cimport memcpy
from libcpp cimport bool

from .sink_driver cimport SinkDriver

# TODO can we remove this?
# cdef extern from "<pthread.h>":
#   struct sched_param:
#     int sched_priority

cdef extern from "../utilityFunctions.h":
  void die(char *errorStr)

cdef extern from "semaphore.h" nogil:
  int sem_init(sem_t *sem, int pshared, unsigned int value)
  int sem_wait(sem_t *)
  int sem_post(sem_t *)
  int sem_destroy(sem_t *sem)

cdef extern from "<sched.h>":
    enum: SCHED_FIFO
    ctypedef struct cpu_set_t:
        pass
    void CPU_ZERO(cpu_set_t *set)
    void CPU_SET(int cpu, cpu_set_t *set)

cdef extern from "<sys/types.h>":
    ctypedef struct pthread_attr_t:
        pass

cdef extern from "<pthread.h>" nogil:
    struct sched_param:
        int sched_priority
    int pthread_create(pthread_t *thread, pthread_attr_t *attr, void *(*start_routine) (void *), void *arg)
    void pthread_exit(void *retval)
    int pthread_sigmask(int how, sigset_t *set, sigset_t *oldset)
    int pthread_join(pthread_t thread, void **retval)
    int pthread_setaffinity_np(pthread_t thread, size_t cpusetsize, cpu_set_t *cpuset)
    int pthread_setschedparam(pthread_t thread, int policy, sched_param *param)
    pthread_t pthread_self()

cdef extern from "<alsa/asoundlib.h>" nogil:
    ctypedef long snd_pcm_sframes_t
    void snd_pcm_hw_params_alloca(void *ptr)
    void snd_pcm_sw_params_alloca(void *ptr)   
    snd_pcm_sframes_t snd_pcm_bytes_to_frames (snd_pcm_t *pcm, ssize_t bytes)
    const char * snd_strerror (int errnum)
    int snd_pcm_prepare(snd_pcm_t* pcm) 
    int snd_pcm_recover (snd_pcm_t *pcm, int err, int silent)

cdef extern from "../lineUtilities.h" nogil:
    int pcm_init_playback(snd_pcm_t **pHandle, snd_pcm_hw_params_t *hwparams, snd_pcm_sw_params_t *swparams)
    void pcm_close(snd_pcm_t *handle, int exitStatus)
    int pcm_write_buffer(snd_pcm_t *handle, uint8_t *ptr, int cptr)
    snd_pcm_sframes_t pcm_get_period_size_bytes()

DEF SIG_BLOCK = 1
DEF LINE_BUFFER_PERIODS = 4 # TODO figure out where constants live now

cdef class LineSinkDriver(SinkDriver):
    def __init__(self):
        cdef int rc

        self.shouldDie = False
        self.lineWriteOffset = 0
        # initiliaze line in
        snd_pcm_hw_params_alloca(&self.play_hwparams)
        snd_pcm_sw_params_alloca(&self.play_swparams)
        pcm_init_playback(&self.play_handle, self.play_hwparams, self.play_swparams)
        sem_init(&self.lineSem, 0, 0) 
        self.linePeriodSizeBytes = pcm_get_period_size_bytes()
        self.linePeriodSizeFrames = snd_pcm_bytes_to_frames(self.play_handle, self.linePeriodSizeBytes)
        self.lineOutBufSize = LINE_BUFFER_PERIODS * self.linePeriodSizeBytes
        self.pLineOutBuf = <uint8_t *>malloc(self.lineOutBufSize)
        self.pLineOutBufWrite = self.pLineOutBuf
        self.pLineOutBufRead = self.pLineOutBuf
        self.lineBufferedPeriods = 0
        snd_pcm_prepare(self.play_handle)

        sigfillset(&self.threadMask)

        rc = pthread_create(&self.tid, NULL, <void *(*)(void *) nogil>&self.processRequests, NULL)
        if (rc): die("pthread_create failed")

        cdef sched_param param
        param.sched_priority = 39
        pthread_setschedparam(self.tid, SCHED_FIFO, &param)
        cdef cpu_set_t mask
        # cdef pthread_t maint = pthread_self()
        # CPU_ZERO(&mask)
        # CPU_SET(3, &mask)
        # pthread_setaffinity_np(maint, sizeof(cpu_set_t), &mask)
        CPU_ZERO(&mask)
        CPU_SET(4, &mask)
        pthread_setaffinity_np(self.tid, sizeof(cpu_set_t), &mask)

    cdef void run(self, uint8_t *outBuf, size_t outBufLen) except *:
        self.lineBytesWrapped = (self.pLineOutBufWrite - self.pLineOutBuf) + outBufLen - self.lineOutBufSize
        self.linePeriodsWritten = 0
        if (self.lineBytesWrapped > 0):
            memcpy(self.pLineOutBufWrite, outBuf, outBufLen - self.lineBytesWrapped)
            memcpy(self.pLineOutBuf, outBuf + outBufLen - self.lineBytesWrapped, self.lineBytesWrapped)

            self.linePeriodsWritten = ((((self.pLineOutBufWrite - self.pLineOutBuf) + outBufLen) // self.linePeriodSizeBytes) - ((self.pLineOutBufWrite - self.pLineOutBuf) // self.linePeriodSizeBytes))
            self.lineBufferedPeriods += self.linePeriodsWritten 

            self.pLineOutBufWrite = self.pLineOutBuf + self.lineBytesWrapped
        else:
            memcpy(self.pLineOutBufWrite, outBuf, outBufLen)
            self.linePeriodsWritten = ((((self.pLineOutBufWrite - self.pLineOutBuf) + outBufLen) // self.linePeriodSizeBytes) - ((self.pLineOutBufWrite - self.pLineOutBuf) // self.linePeriodSizeBytes))
            self.lineBufferedPeriods += self.linePeriodsWritten
            self.pLineOutBufWrite += outBufLen

        for i in range(self.linePeriodsWritten):
            sem_post(&self.lineSem)
        self.linePeriodsWritten = 0

    cdef void exit_handler(self, int exitStatus) except *:
        self.shouldDie = True
        sem_post(&self.lineSem)
        pthread_join(self.tid, &self.retVal)
        free(self.pLineOutBuf)
        sem_destroy(&self.lineSem)
        pcm_close(self.play_handle, exitStatus)


    cdef void* processRequests(self, void *arg) nogil:
        global ret
        pthread_sigmask(SIG_BLOCK, &self.threadMask, NULL)
        cdef snd_pcm_sframes_t pcm_ret
        cdef int *retVal
        cdef char *zErrMsg = <char *>0

        while (True):
            sem_wait(&self.lineSem)

            if (self.shouldDie):
                retVal[0] = EXIT_SUCCESS
                pthread_exit(&retVal)

            pcm_ret = pcm_write_buffer(self.play_handle, self.pLineOutBufRead, self.linePeriodSizeFrames)
            if (pcm_ret < 0):
                printf("pcm_write_buffer failed.\n")
                retVal[0] = EXIT_FAILURE
                pthread_exit(&retVal)

            self.pLineOutBufRead += self.linePeriodSizeBytes
            if (self.pLineOutBufRead >= self.pLineOutBuf + self.lineOutBufSize):
                self.pLineOutBufRead = self.pLineOutBuf