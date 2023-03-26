from libc.stdio cimport fflush, printf, stdout
from libc.stdlib cimport exit, free, malloc
from libc.string cimport memcpy, strcat, strcpy, strlen


cdef extern from "../../utilityFunctions.h" nogil:
  enum: __GNU_SOURCE
  void die(char *errorStr)

cdef extern from "<msgpack.h>" nogil:
  void msgpack_sbuffer_destroy(msgpack_sbuffer* sbuf)
  void msgpack_sbuffer_clear(msgpack_sbuffer* sbuf)
  int msgpack_sbuffer_write(void* data, const char* buf, size_t len)
  void msgpack_sbuffer_init(msgpack_sbuffer* sbuf)
  int msgpack_pack_array(msgpack_packer* pk, size_t n)
  void msgpack_packer_init(msgpack_packer* pk, void* data, msgpack_packer_write callback)
  int msgpack_pack_uint8(msgpack_packer* pk, uint8_t d)
  int msgpack_pack_uint16(msgpack_packer* pk, uint16_t d)
  int msgpack_pack_uint32(msgpack_packer* pk, uint32_t d)
  int msgpack_pack_uint64(msgpack_packer* pk, uint64_t d)
  int msgpack_pack_int8(msgpack_packer* pk, int8_t d)
  int msgpack_pack_int16(msgpack_packer* pk, int16_t d)
  int msgpack_pack_int32(msgpack_packer* pk, int32_t d)
  int msgpack_pack_int64(msgpack_packer* pk, int64_t d)
  int msgpack_pack_float(msgpack_packer* pk, float d)
  int msgpack_pack_double(msgpack_packer* pk, double d)

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
  ctypedef struct sqlite3_blob:
    pass
  int sqlite3_close(sqlite3 *)
  int sqlite3_exec(
    sqlite3*,                                  
    const char *sql,                           
    int (*callback)(void*,int,char**,char**),  
    void *,                                    
    char **errmsg                              
  )
  void sqlite3_free(void*)
  enum: SQLITE_OK
  ctypedef void (*destructor)(void*)
  destructor SQLITE_STATIC
  enum: SQLITE_OPEN_READWRITE
  int sqlite3_open_v2(
    const char *filename,   
    sqlite3 **ppDb,         
    int flags,              
    const char *zVfs        
  )

cdef extern from "sqlite3async.h" nogil:
  void sqlite3async_shutdown()
  void sqlite3async_run()
  int sqlite3async_initialize(const char *zParent, int isDefault)
  int sqlite3async_control(int op, ...)
  enum: SQLITEASYNC_HALT
  enum: SQLITEASYNC_HALT_IDLE

cdef extern from "sqlHelpers.h" nogil:
  void sql_bind_int(sqlite3_stmt *stmt, int index, const char* dtype, const void* value)
  void sql_bind_int64(sqlite3_stmt *stmt, int index, const void* value)
  void sql_bind_double(sqlite3_stmt *stmt, int index,  const char* dtype, const void* value)
  void sql_bind_text(sqlite3_stmt *stmt, int index, const void* value, int numBytes, destructor destruct)
  void sql_bind_blob(sqlite3_stmt *stmt, int index, const void* value, int numBytes, destructor destruct)
  void sql_prepare(sqlite3 *db, const char *zSql, int nByte, sqlite3_stmt **ppStmt, const char **pzTail)
  void sql_step(sqlite3_stmt *stmt)
  void sql_finalize(sqlite3_stmt *stmt)
  void openDatabase(sqlite3 **db, char *startName, int db_index, char* newNameLocation)
  void createTables(sqlite3 *db, SQLTable* databaseArr)
  enum: NUM_BUF_S
  enum: NUM_MS_IN_S # TODO replace ms with ticks or just remove
  cdef const char *INSERT_STR
  cdef const char *VALUES_STR
  cdef const char *OPEN_BRACE
  cdef const char *QUESTION
  cdef const char *CLOSE_BRACE_SEMI
  cdef const char *CLOSE_BRACE
  cdef const char *COMMA


cdef extern from "stdatomic.h":
  enum memory_order:
    memory_order_relaxed,
    memory_order_consume,
    memory_order_acquire,
    memory_order_release,
    memory_order_acq_rel,
    memory_order_seq_cst
  void atomic_thread_fence(memory_order)

cdef extern from "../../constants.h":
  cdef const char *DATALOGGER_SIGNALS_TABLE_NAME
  enum: NEW_DB_NUM_TICKS
  enum: SQL_LOGGER_FLUSH

cdef class DiskSinkDriver(sink_driver.SinkDriver):
  def __cinit__(self):
    self.newDB = False
    self.db_index = 0
    self.num_extra_cols = 0
    self.tick_count = 0
    self.ticks_written = 0

    # initialize sqlite3async
    if (sqlite3async_initialize(NULL, 1) != SQLITE_OK):
      die("sqlite3async init failed\n")

    # control sqlite3async: set attributes
    self.eNewHalt = SQLITEASYNC_HALT_IDLE
    if (sqlite3async_control(SQLITEASYNC_HALT, self.eNewHalt) != SQLITE_OK):
      die("sqlite3async control failed\n")

    # create numpy signals table sql insert queries
    # TODO support 4 = 0
    self.queryLen = (
      strlen(INSERT_STR) + strlen(DATALOGGER_SIGNALS_TABLE_NAME) +
      strlen(VALUES_STR) + strlen(OPEN_BRACE) +
      (strlen(QUESTION) + strlen(COMMA)) * 4 - strlen(COMMA) +
      (strlen(COMMA) + strlen(QUESTION)) * 5 +
      strlen(CLOSE_BRACE_SEMI)
    )
    self.signalsQuery = <char *> malloc(self.queryLen + 1)
    strcpy(self.signalsQuery, INSERT_STR)
    strcat(self.signalsQuery, DATALOGGER_SIGNALS_TABLE_NAME)
    strcat(self.signalsQuery, VALUES_STR)
    strcat(self.signalsQuery, OPEN_BRACE)
    strcat(self.signalsQuery, QUESTION)
    strcat(self.signalsQuery, COMMA)
    strcat(self.signalsQuery, QUESTION)
    strcat(self.signalsQuery, COMMA)
    strcat(self.signalsQuery, QUESTION)
    strcat(self.signalsQuery, COMMA)
    strcat(self.signalsQuery, QUESTION)
    # extra columns for vector signals
    strcat(self.signalsQuery, COMMA)
    strcat(self.signalsQuery, QUESTION)
    strcat(self.signalsQuery, COMMA)
    strcat(self.signalsQuery, QUESTION)
    strcat(self.signalsQuery, COMMA)
    strcat(self.signalsQuery, QUESTION)
    strcat(self.signalsQuery, COMMA)
    strcat(self.signalsQuery, QUESTION)
    strcat(self.signalsQuery, COMMA)
    strcat(self.signalsQuery, QUESTION)
    strcat(self.signalsQuery, CLOSE_BRACE_SEMI)
    # signals buffer
    self.signalsBufSize = NUM_BUF_S * NUM_MS_IN_S # TODO this should be signal size
    self.signalsBufSizeBytes = (sizeof(signalsTickData) * self.signalsBufSize)
    self.signalsBufStrt = <signalsTickData *>malloc(self.signalsBufSizeBytes)
    self.signalsBufEnd = self.signalsBufStrt + self.signalsBufSize
    self.pSignalsStructCur = self.signalsBufStrt
    self.pSignalsStructStart = self.signalsBufStrt

    printf("%s\n", self.signalsQuery)
    fflush(stdout)

    openDatabase(&self.db, "./data", self.db_index, self.currDbName)
    sqlite3_exec(self.db, "PRAGMA journal_mode = MEMORY", NULL, NULL, &self.zErrMsg)

    # prepare SQL database table
    self.num_extra_cols = 0 # counter for number of extra added columns
    # self.signalsTableArr[0].type = "uint64_t"
    # self.signalsTableArr[0].number = 4
    # self.signalsTableArr[0].unit = "TODO"
    # self.signalsTableArr[0].data = NULL
      # vector sigs
    curr_index = 0 # if suffixes specified
    self.signalsTableArr[curr_index + self.num_extra_cols].colName = "v_f8_vector_floats_x"
    if 'int' in 'double':
      self.signalsTableArr[curr_index + self.num_extra_cols].SQLtype = "INTEGER"
    else: # float
      self.signalsTableArr[curr_index + self.num_extra_cols].SQLtype = "REAL"

    self.num_extra_cols += 1 # if suffixes specified
    self.signalsTableArr[curr_index + self.num_extra_cols].colName = "v_f8_vector_floats_y"
    if 'int' in 'double':
      self.signalsTableArr[curr_index + self.num_extra_cols].SQLtype = "INTEGER"
    else: # float
      self.signalsTableArr[curr_index + self.num_extra_cols].SQLtype = "REAL"

    self.num_extra_cols += 1 # if suffixes specified
    self.signalsTableArr[curr_index + self.num_extra_cols].colName = "v_f8_vector_floats_z"
    if 'int' in 'double':
      self.signalsTableArr[curr_index + self.num_extra_cols].SQLtype = "INTEGER"
    else: # float
      self.signalsTableArr[curr_index + self.num_extra_cols].SQLtype = "REAL"

    self.num_extra_cols += 1 # if suffixes specified
    self.signalsTableArr[curr_index + self.num_extra_cols].colName = "v_f8_vector_floats_z2"
    if 'int' in 'double':
      self.signalsTableArr[curr_index + self.num_extra_cols].SQLtype = "INTEGER"
    else: # float
      self.signalsTableArr[curr_index + self.num_extra_cols].SQLtype = "REAL"

    self.num_extra_cols += 1
    self.num_extra_cols -= 1 # only count *extra* added cols
    # self.signalsTableArr[1].type = "uint64_t"
    # self.signalsTableArr[1].number = 3
    # self.signalsTableArr[1].unit = "TODO"
    # self.signalsTableArr[1].data = NULL
      # vector sigs
    curr_index = 1
    self.signalsTableArr[curr_index + self.num_extra_cols].colName = "v_i2_vector_ints_0"
    if 'int' in 'int16':
      self.signalsTableArr[curr_index + self.num_extra_cols].SQLtype = "INTEGER"
    else: # float
      self.signalsTableArr[curr_index + self.num_extra_cols].SQLtype = "REAL"

    self.num_extra_cols += 1
    self.signalsTableArr[curr_index + self.num_extra_cols].colName = "v_i2_vector_ints_1"
    if 'int' in 'int16':
      self.signalsTableArr[curr_index + self.num_extra_cols].SQLtype = "INTEGER"
    else: # float
      self.signalsTableArr[curr_index + self.num_extra_cols].SQLtype = "REAL"

    self.num_extra_cols += 1
    self.signalsTableArr[curr_index + self.num_extra_cols].colName = "v_i2_vector_ints_2"
    if 'int' in 'int16':
      self.signalsTableArr[curr_index + self.num_extra_cols].SQLtype = "INTEGER"
    else: # float
      self.signalsTableArr[curr_index + self.num_extra_cols].SQLtype = "REAL"

    self.num_extra_cols += 1
    self.num_extra_cols -= 1 # only count *extra* added cols
    # self.signalsTableArr[2].type = "uint64_t"
    # self.signalsTableArr[2].number = 4
    # self.signalsTableArr[2].unit = "TODO"
    # self.signalsTableArr[2].data = NULL
      # msgpack sigs
    self.signalsTableArr[2 + self.num_extra_cols].colName = "m_f8_matrix_out"
    self.signalsTableArr[2 + self.num_extra_cols].SQLtype = "BLOB"
    # self.signalsTableArr[3].type = "uint64_t"
    # self.signalsTableArr[3].number = 1
    # self.signalsTableArr[3].unit = "TODO"
    # self.signalsTableArr[3].data = NULL

      # raw number sigs
    self.signalsTableArr[3 + self.num_extra_cols].colName = "r_i1_scalar_out"
    if 'int' in 'int8':
      self.signalsTableArr[3 + self.num_extra_cols].SQLtype = "INTEGER"
    else: # float
      self.signalsTableArr[3 + self.num_extra_cols].SQLtype = "REAL"
    self.databaseArray[0].tableName = DATALOGGER_SIGNALS_TABLE_NAME
    self.databaseArray[0].numCol = 4 + 5
    self.databaseArray[0].columns = self.signalsTableArr
    createTables(self.db, self.databaseArray)

    # flush sqlite buffer before execution start
    sqlite3async_run()


    # initialize message pack for numpy signals
    msgpack_sbuffer_init(&self.mpSignalsMatrix_outBuf)
    msgpack_packer_init(&self.mpSignalsMatrix_outPk, &self.mpSignalsMatrix_outBuf, msgpack_sbuffer_write)
    # enlarge buffer before main execution
    msgpack_pack_array(&self.mpSignalsMatrix_outPk, 4)
    for i in range(4):
      msgpack_pack_double(&self.mpSignalsMatrix_outPk, 0)


  cdef void run(self, uint8_t *outBuf, size_t outBufLen, object in_sigs, object in_sig_lens) except *:
    # for now we assume signals are synchronous and we get one signal each
    # tick. signals can be put in separate tables if needed for multiple async.
    # sufficient ticks must be buffered for async to work. error handling??
    # parsing happens on async side, so need previous tick signals exposed here
    self.bufferSignals(in_sigs, in_sig_lens)


    # after SQL_LOGGER_FLUSH ticks, flush buffered data to DB
    # TODO this has to be a different var since numTicks is not accurate for async
    self.tick_count += 1
    if (self.tick_count % SQL_LOGGER_FLUSH == 0):
      self.pSignalsStructEnd = self.pSignalsStructStart + SQL_LOGGER_FLUSH
      self.flushToDisk()




  cdef void exit_handler(self, int exitStatus) except *:
    global signalsBufStrt, tick_count, pNumTicks, pSignalsStructStart, pSignalsStructEnd # TODO add msgpack Buf vars

    # perform final flush of buffered data
    self.pSignalsStructEnd = self.pSignalsStructCur
    self.flushToDisk()

    free(self.signalsBufStrt)

    # destroy msgpack signals
  
    msgpack_sbuffer_destroy(&self.mpSignalsMatrix_outBuf)

    # clean up sqlite db
    sqlite3_close(self.db)
    sqlite3async_shutdown()

  #all the memcpys happen here now
  cdef void* bufferSignals(self, object in_sigs, object in_sig_lens):
    # for each tick buffered, copy each signal from buffer into pSignalsStructCur
    # TODO this logic should have some validation
    # in the case of max_packets_per_tick != 1, must be saved as a blob or be in its own table
    memcpy(self.pSignalsStructCur.vector_floats, <uint8_t *><long>(in_sigs["vector_floats"].__array_interface__["data"][0]), in_sig_lens["vector_floats"] * sizeof(double))
    # pSignalsStructCur.vector_floatsNumSamplesRecvd = in_sig_lens["vector_floats"]
    # TODO this logic should have some validation
    # in the case of max_packets_per_tick != 1, must be saved as a blob or be in its own table
    memcpy(self.pSignalsStructCur.vector_ints, <uint8_t *><long>(in_sigs["vector_ints"].__array_interface__["data"][0]), in_sig_lens["vector_ints"] * sizeof(int16_t))
    # pSignalsStructCur.vector_intsNumSamplesRecvd = in_sig_lens["vector_ints"]
    # TODO this logic should have some validation
    # in the case of max_packets_per_tick != 1, must be saved as a blob or be in its own table
    memcpy(self.pSignalsStructCur.matrix_out, <uint8_t *><long>(in_sigs["matrix_out"].__array_interface__["data"][0]), in_sig_lens["matrix_out"] * sizeof(double))
    # pSignalsStructCur.matrix_outNumSamplesRecvd = in_sig_lens["matrix_out"]
    # TODO this logic should have some validation
    # in the case of max_packets_per_tick != 1, must be saved as a blob or be in its own table
    memcpy(self.pSignalsStructCur.scalar_out, <uint8_t *><long>(in_sigs["scalar_out"].__array_interface__["data"][0]), in_sig_lens["scalar_out"] * sizeof(int8_t))
    # pSignalsStructCur.scalar_outNumSamplesRecvd = in_sig_lens["scalar_out"]

    atomic_thread_fence(memory_order_seq_cst)

    #increment in values buffer
    self.pSignalsStructCur += 1
    if (self.pSignalsStructCur == self.signalsBufEnd):
      self.pSignalsStructCur = self.signalsBufStrt

  cdef bint flushToDisk(self, bint newDB=False) nogil:
    complete = True

    # create new database if time limit reached
    if (newDB):
      self.ticks_written = 0
      self.db_index += 1
      openDatabase(&self.db, "./data", self.db_index, self.currDbName)
      sqlite3_exec(self.db, "PRAGMA journal_mode = MEMORY", NULL, NULL, &self.zErrMsg)
      createTables(self.db, self.databaseArray)

    if (sqlite3_exec(self.db, "BEGIN TRANSACTION", NULL, NULL, &self.zErrMsg) != SQLITE_OK):
      # print sql error msg
      sqlite3_free(self.zErrMsg)
      die("SQL error")

    while (self.pSignalsStructStart != self.pSignalsStructEnd):
      sql_prepare(self.db, self.signalsQuery, -1, &self.signalsStmt, NULL)

      self.num_extra_cols = 0 # restart counter for each row logged
      # vector signal
      for i in range(4):
        if "int" in 'double':
          if "64" in 'double':
            sql_bind_int64(self.signalsStmt, 1 + self.num_extra_cols, &(self.pSignalsStructStart.vector_floats[i]))
          else:
            sql_bind_int(self.signalsStmt, 1 + self.num_extra_cols, "double", &(self.pSignalsStructStart.vector_floats[i]))
        else: # float
          sql_bind_double(self.signalsStmt, 1 + self.num_extra_cols, "double", &(self.pSignalsStructStart.vector_floats[i]))
        self.num_extra_cols += 1
      self.num_extra_cols -= 1
      # vector signal
      for i in range(3):
        if "int" in 'int16':
          if "64" in 'int16':
            sql_bind_int64(self.signalsStmt, 2 + self.num_extra_cols, &(self.pSignalsStructStart.vector_ints[i]))
          else:
            sql_bind_int(self.signalsStmt, 2 + self.num_extra_cols, "int16", &(self.pSignalsStructStart.vector_ints[i]))
        else: # float
          sql_bind_double(self.signalsStmt, 2 + self.num_extra_cols, "int16", &(self.pSignalsStructStart.vector_ints[i]))
        self.num_extra_cols += 1
      self.num_extra_cols -= 1
      # msgpack signal
      msgpack_sbuffer_clear(&self.mpSignalsMatrix_outBuf)
      msgpack_pack_array(&self.mpSignalsMatrix_outPk, 4)
      for i in range(4):
        msgpack_pack_double(&self.mpSignalsMatrix_outPk, self.pSignalsStructStart.matrix_out[i])
      sql_bind_blob(self.signalsStmt, 3 + self.num_extra_cols, self.mpSignalsMatrix_outBuf.data, self.mpSignalsMatrix_outBuf.size, SQLITE_STATIC)
      # raw number signal
      if "int" in "int8":
        if "64" in "int8":
          sql_bind_int64(self.signalsStmt, 4 + self.num_extra_cols, self.pSignalsStructStart.scalar_out)
        else:
          sql_bind_int(self.signalsStmt, 4 + self.num_extra_cols, "int8", self.pSignalsStructStart.scalar_out)
      else: # float
        sql_bind_double(self.signalsStmt, 4 + self.num_extra_cols, "int8", self.pSignalsStructStart.scalar_out)

      sql_step(self.signalsStmt)
      sql_finalize(self.signalsStmt)

      self.pSignalsStructStart += 1
      if (self.pSignalsStructStart == self.signalsBufEnd):
        self.pSignalsStructStart = self.signalsBufStrt

      self.ticks_written += 1
      if (self.ticks_written % NEW_DB_NUM_TICKS == 0):
        complete = False
        break


    if (sqlite3_exec(self.db, "END TRANSACTION", NULL, NULL, &self.zErrMsg) != SQLITE_OK):
      # print sql error msg
      sqlite3_free(self.zErrMsg)
      die("SQL error")

    sqlite3async_run()

    if not complete:
      self.flushToDisk(newDB=True)
