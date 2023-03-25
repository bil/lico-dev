from libc.stdint cimport uint8_t
from sink_drivers cimport sink_driver


cdef class VisPygameSinkDriver(sink_driver.SinkDriver):
    cdef void run(self, uint8_t *outBuf, size_t outBufLen) except *:
        pass

    cdef void exit_handler(self, int exitStatus) except *:
        pass
