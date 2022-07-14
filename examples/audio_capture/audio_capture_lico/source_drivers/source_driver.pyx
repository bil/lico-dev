from libc.stdint cimport uint32_t

cdef class SourceDriver():
    cdef void run(self) except *:
        raise NotImplementedError()

    cdef void run_update(self, uint32_t *bufVars, void *bufCurPtr) except *:
        raise NotImplementedError()

    cdef void exit_handler(self, int exitStatus) except *:
        raise NotImplementedError()

    cdef void alrm_handler(self) except *:
        pass
