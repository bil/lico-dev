from libc.stdint cimport (
    int8_t,
    int16_t,
    int32_t,
    int64_t,
    uint8_t,
    uint16_t,
    uint32_t,
    uint64_t,
)
from sink_drivers cimport sink_driver


cdef extern from "<msgpack.h>" nogil:
    ctypedef int (*msgpack_packer_write)(void* data, const char* buf, size_t len)
    ctypedef struct msgpack_sbuffer:
        size_t size
        char* data
        size_t alloc
    ctypedef struct msgpack_packer:
        void* data
        msgpack_packer_write callback

cdef extern from "loggingStruct.h" nogil:
    ctypedef struct SQLTableElement:
        char *colName
        char *type
        short number
        char *unit
        void *data
        char *SQLtype

    ctypedef struct SQLTable:
        char* tableName
        short numCol
        SQLTableElement *columns

cdef extern from "<sqlite3.h>" nogil:
  ctypedef struct sqlite3:
    pass
  ctypedef struct sqlite3_stmt:
    pass

cdef extern from "../../constants.h":
    enum: NUM_TABLES

ctypedef struct signalsTickData:
    int8_t int8_signal[1]

cdef class DiskSinkDriver(sink_driver.SinkDriver):
    cdef bint newDB
    cdef char currDbName[32]
    # worker thread vars
    cdef char *zErrMsg
    cdef void * retVal
    # numpy signal data structs to hold one tick of data
    cdef signalsTickData *pSignalsStructCur
    cdef signalsTickData *pSignalsStructStart
    cdef signalsTickData *pSignalsStructEnd
    # tick buffers to enable batching
    cdef signalsTickData *signalsBufStrt
    cdef signalsTickData *signalsBufEnd
    # size of intermediary logging buffer in blocks of signalMsData
    cdef int signalsBufSize
    cdef int signalsBufSizeBytes

    # sqlite variables
    cdef sqlite3 *db
    cdef sqlite3_stmt *contStmt
    cdef sqlite3_stmt *signalsStmt
    cdef SQLTable databaseArray[NUM_TABLES]
    cdef SQLTableElement signalsTableArr[1 + 0]

    # sqlite variables
    cdef int eNewHalt
    cdef int queryLen
    cdef char *signalsQuery

    # message pack

    cdef int db_index
    cdef int num_extra_cols # counter for extra columns added to db
    cdef uint64_t tick_count
    cdef uint64_t ticks_written

    cdef void run(self, uint8_t *outBuf, size_t outBufLen, object in_sigs, object in_sig_lens) except *
    cdef void exit_handler(self, int exitStatus) except *

    cdef void* bufferSignals(self, object in_sigs, object in_sig_lens)
    cdef bint flushToDisk(self, bint newDB=*) nogil