from libc.stdint cimport uint8_t


cdef class SourceDriver():
    cdef void run(self, uint8_t **inBuf, size_t *inBufLen, object *out_sigs, object *out_sig_lens) except *
    cdef void exit_handler(self, int exitStatus) except *
