from libc.stdio cimport printf
from libc.stdlib cimport malloc, free, EXIT_SUCCESS, EXIT_FAILURE
from libc.stdint cimport int8_t, uint8_t, int16_t, uint16_t, int32_t, uint32_t, int64_t, uint64_t
from posix.signal cimport sigset_t, sigfillset
from libc.string cimport memcpy

from .source_driver cimport SourceDriver

# TODO add parent path to gcc lib or similar: https://stackoverflow.com/questions/15120330/include-parent-directorys-file
cdef extern from "../utilityFunctions.h":
  void die(char *errorStr)

cdef extern from "<sys/types.h>":
    ctypedef struct pthread_mutex_t:
        pass
    ctypedef struct pthread_mutexattr_t:
        pass
    ctypedef struct pthread_attr_t:
        pass

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

cdef extern from "<pthread.h>" nogil:
    struct sched_param:
        int sched_priority
    int pthread_join(pthread_t, void **retValue)
    int pthread_mutex_init(pthread_mutex_t *, const pthread_mutexattr_t *)
    int pthread_mutex_lock(pthread_mutex_t *)
    int pthread_mutex_unlock(pthread_mutex_t *)
    int pthread_create(pthread_t *thread, const pthread_attr_t *attr, void *(*start_routine)(void*), void *arg)
    int pthread_setaffinity_np(pthread_t thread, size_t cpusetsize, cpu_set_t *cpuset)
    int pthread_setschedparam(pthread_t thread, int policy, sched_param *param)
    void pthread_exit(void *retval)
    int pthread_sigmask(int how, sigset_t *set, sigset_t *oldset)

cdef extern from "<alsa/asoundlib.h>":
    ctypedef long snd_pcm_sframes_t
    void snd_pcm_hw_params_alloca(void *ptr)
    void snd_pcm_sw_params_alloca(void *ptr)
    snd_pcm_sframes_t snd_pcm_bytes_to_frames (snd_pcm_t *pcm, ssize_t bytes)
    const char * snd_strerror (int errnum)   
    int snd_pcm_prepare(snd_pcm_t* pcm) 
    int snd_pcm_recover (snd_pcm_t *pcm, int err, int silent)

# TODO move lineUtilities? or come up with scheme to include utils for drivers
cdef extern from "../lineUtilities.h" nogil:
    int pcm_init_capture(snd_pcm_t **pHandle, snd_pcm_hw_params_t *hwparams, snd_pcm_sw_params_t *swparams)
    void pcm_close(snd_pcm_t *handle, int exitStatus)
    int pcm_read_buffer(snd_pcm_t *handle, uint8_t *ptr, int cptr);
    snd_pcm_sframes_t pcm_get_period_size_bytes()

DEF SIG_BLOCK = 1
DEF LINE_BUFFER_PERIODS = 100

cdef class LineSourceDriver(SourceDriver):
    def __init__(self, bufVars):
        cdef int rc
        cdef sched_param param
        cdef cpu_set_t mask

        self.NPERIODS = 2
        self.shouldDie = False
        self.lineWriteOffset = 0

        # initiliaze line in 
        snd_pcm_hw_params_alloca(&self.cap_hwparams)
        snd_pcm_sw_params_alloca(&self.cap_swparams)
        pcm_init_capture(&self.cap_handle, self.cap_hwparams, self.cap_swparams)
        sem_init(&self.lineSem, 0, 0)
        self.linePeriodSizeBytes = pcm_get_period_size_bytes()
        self.linePeriodSizeFrames = snd_pcm_bytes_to_frames(self.cap_handle, self.linePeriodSizeBytes)
        self.lineBufferSizeBytes = self.linePeriodSizeBytes * self.NPERIODS
        self.lineBufferSizeFrames = snd_pcm_bytes_to_frames(self.cap_handle, self.lineBufferSizeBytes)

        self.lineOutBufSize = LINE_BUFFER_PERIODS * self.lineBufferSizeBytes
        self.pLineOutBuf = <uint8_t *>malloc(self.lineOutBufSize)
        self.pLineOutBufWrite = self.pLineOutBuf
        self.pLineOutBufRead = self.pLineOutBuf
        self.lineBufferedPeriods = 0
        snd_pcm_prepare(self.cap_handle)

        sigfillset(&self.threadMask)

        rc = pthread_create(&self.tid, NULL, <void *(*)(void *) nogil>&self.processRequests, NULL)
        if (rc): die("pthread_create failed")

        param.sched_priority = 39
        pthread_setschedparam(self.tid, SCHED_FIFO, &param)
        CPU_ZERO(&mask)
        CPU_SET(2, &mask)
        pthread_setaffinity_np(self.tid, sizeof(cpu_set_t), &mask)

        # TODO recvLen was never set
        recvLen = 0
        bufVars[6] = recvLen // sizeof(int16_t) * 2
        bufVars[5] = recvLen // sizeof(int16_t)
        bufVars[0] = 0

    
    cdef void run_read(self) except *:
        global parentSetup

        if (parentSetup):
            pass
            # self.pLineOutBufRead = pLineOutBufWrite


    cdef void run_update(self, uint32_t *bufVars, void *bufCurPtr) except *:
        sem_wait(&self.lineSem)
        # print(bufVars[7], flush=True)
        # print(bufCurPtr - bufStrtPtr, flush=True)
        # print(self.pLineOutBufRead - pLineOutBuf, flush=True)

        # print(linePeriodSizeBytes, flush=True)
        # print(lineOutBufSize, flush=True)
        memcpy(bufCurPtr, self.pLineOutBufRead, self.linePeriodSizeBytes)
        
        # print(flush=True)
        self.pLineOutBufRead += self.linePeriodSizeBytes

        if (self.pLineOutBufRead >= self.pLineOutBuf + self.lineOutBufSize):
            self.pLineOutBufRead = self.pLineOutBuf

        # print(self.pLineOutBufRead - pLineOutBuf, flush=True)

        bufVars[2] += self.linePeriodSizeFrames * 2 # TODO should be channel number
        bufVars[10] += 1
        if (bufVars[7] <= bufVars[2] + bufVars[6]):
            bufVars[4] = bufVars[2]
            bufVars[12] = bufVars[10]
        elif (bufVars[2] > bufVars[4]):
            bufVars[4] = bufVars[2] 
            bufVars[12] = bufVars[10]
        # Somehow when there is no active streaming data, this number just runs upwards
        bufVars[3] = self.linePeriodSizeFrames * 2 # TODO should be channel number
        bufVars[11] = 1
        # print(bufVars[2], flush=True)
        # print(bufVars[3], flush=True)
        # print(flush=True)


    cdef void exit_handler(self, int exitStatus) except *:
        self.shouldDie = True
        pthread_join(self.tid, &self.retVal)
        free(self.pLineOutBuf)
        sem_destroy(&self.lineSem)
        pcm_close(self.cap_handle, exitStatus)

    cdef void* processRequests(self, void *arg) nogil:
        pthread_sigmask(SIG_BLOCK, &self.threadMask, NULL)
        cdef snd_pcm_sframes_t pcm_ret
        cdef int *retVal
        cdef char *zErrMsg = <char *>0
        cdef int i = 0

        while (True):
            if (self.shouldDie):
                retVal[0] = EXIT_SUCCESS
                pthread_exit(&retVal)

            # printf("write 1: %lu, %lu %lu\n", pLineOutBufWrite - pLineOutBuf, lineBufferSizeFrames, lineBufferSizeBytes)
            # fflush(stdout)
            pcm_ret = pcm_read_buffer(self.cap_handle, self.pLineOutBufWrite, self.lineBufferSizeFrames)

            if (pcm_ret < 0):
                printf("pcm_write_buffer failed.\n")
                retVal[0] = EXIT_FAILURE
                pthread_exit(&retVal)

            # i = 0
            # while (i < lineBufferSizeFrames):
            #   printf("%d ", (<int16_t *>pLineOutBufWrite)[i])
            #   i += 1
            # printf("\n")
            # fflush(stdout)

            self.pLineOutBufWrite += self.lineBufferSizeBytes
            if (self.pLineOutBufWrite >= self.pLineOutBuf + self.lineOutBufSize):
                self.pLineOutBufWrite = self.pLineOutBuf
            # printf("write 2: %lu\n", pLineOutBufWrite - pLineOutBuf)
            # fflush(stdout)

            i = 0
            while (i < self.NPERIODS):
                sem_post(&self.lineSem)
                i += 1
