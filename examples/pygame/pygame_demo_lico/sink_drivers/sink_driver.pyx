from libc.stdint cimport uint8_t

cdef class SinkDriver():
    cdef void run(self, uint8_t *outBuf, size_t outBufLen) except *:
        raise NotImplementedError()

    cdef void exit_handler(self, int exitStatus) except *:
        raise NotImplementedError()
