#include <pthread.h>
#include <stdint.h>
#include <time.h>

#ifndef _CONSTANTS_
#define _CONSTANTS_ 
/************************************
* Basic user configurable constants *
*************************************/
/*
 * Number of ticks for LiCoRICE to run. The default value (-1) indicates
 * that LiCORICE will run until it is stopped by an interrupt or exception.
 */
#define NUM_TICKS -1
/*
 * The offset from which to run the child processes, zero-indexed. Usually 
 * the first (CPU 0) is for the parent timer process itself, the second
 * is for Redis, the third is the network process (CPU 2), and the last is
 * for the logger process (CPU 3). So, this should be a minimum of 4.
 * MODULES CURRENTLY RUNNING ON CPUS 1 -> NUM_CORES-1. 
 */
#define CPU_OFFSET 2
/*
 * The processor number on which to run the networking process, which is receiving
 * packets from the Cerberus system. NETWORK CURRENTLY RUNNING  ON ALL MODULE CORES. 
 * (nothing special about network)
 */
#define NETWORK_CPU 2
/*
 * The processor number on which to run the data logging process. LOGGER CURRENTLY RUNNING 
 * ON ALL MODULE CORES. (nothing special about logger)
 */
#define LOGGER_CPU 1

/* 
 * TODO Make this configurable?
 * Number of tables in SQLite database
 */
#define NUM_TABLES 1

/*
 * Name of file for where data for the experiment should be stored.  48 character limit.
 * DO NOT add .db to the end.
 * TODO this has been removed. add above to YAML config documentation
 */
#define DATALOGGER_FILENAME ""

/*
 * Table name for NumPy SharedArray signals table.  Make sure this name complies 
 * with SQL syntax, since it is simply spliced into SQL command without any error checking.
 */
#define DATALOGGER_SIGNALS_TABLE_NAME "signals"

/*
 * How often sql flushes
 *
 */
#define SQL_LOGGER_FLUSH 1000

/*
 * Time (ticks) until a new SQL database is created.
 */
#define NEW_DB_NUM_TICKS 6000

/*
 * Pad length for the database index to be added to the end of each database filename.
 * Must be at least 1.
 * For example, a pad length of 3 would permit filenames from <filename>_000 to <filename>_999
 */
#define DB_INDEX_PAD_LENGTH 4

/*
 * Maximum number of characters for a module name
 */
#define MAX_MODULE_NAME_LEN 64

/***************************************
* Advanced user configurable constants *
***************************************/

/*
 * Max size of file pathname for child process execution.  The timer
 * parent runs proceses containing a max of MAX_PATH_LEN characters,
 * including the null terminator.
 */
#define MAX_PATH_LEN 16

/*
 * The number of ticks at the beginning of execution during which
 * module and sink processes do not run. Defaults to 100.
 */
#define SOURCE_INIT_TICKS 100

/*
 * The number of ticks after SOURCE_INIT_TICKS during which sink processes do
 * not run, but module processes do. Defaults to 0.
 */
#define MODULE_INIT_TICKS 0

/*******************
* Global constants *
********************/
// Number of async reader processes
#define NUM_ASYNC_READERS 0

// Number of async writer processes
#define NUM_ASYNC_WRITERS 0

// Number of signals that are internal and not generated by sources
#define NUM_SEM_SIGS 0

// Number of internal signals
#define NUM_INTERNAL_SIGS 0

// Number of source signals
#define NUM_SOURCE_SIGS 0

// Number of of microseconds for the timer interrupt (1 ms resolution)
#define TICK_LEN_NS 10000000

// Number of seconds for the timer interrupt
#define TICK_LEN_S 0

// Process priority (1 (low) to 99 (high))
// Don't set to 99, or else process cannot be killed
#define PRIORITY 95

// Used to prefault the stack
#define MAX_SAFE_STACK (8*1024*1024)

// Main shared memory pathname 
#define SMEM0_PATHNAME "/smem0"

// Page size in bytes
#define PAGESIZE 4096

// Number of 4kB pages in a gB
#define NUM_PAGES_IN_GB 262144

// Number of bytes in a gigabyte
#define BYTES_IN_GB (1 << 30)

// Number of bytes in alsa frame
#define BYTES_PER_FRAME 4 /* 2 bytes/sample, 2 channels */

// Number of samples in a millisecond 
#define NUM_SAMPLES_PER_MS (SAMPLING_RATE / 1000)

// Macro to round X up to nearest multiple of Y
#define ROUND_UP(X, Y) ((((X) + (Y) - 1) / (Y)) * (Y))

// Number of extra ticks-worth of padding required in circular buffers to maintain desired amount of history
#define HISTORY_PAD_LENGTH {history_pad_length}

// Number of elements in each bufVars array
// Set in template_funcs.py
/*
  0: tick start
  1: tick end
  2: next data location
  3: num samples received this tick
  4: buffer end offset (samples)
  5: packet size (samples)
  6: max samples per tick (samples)
  7: buffer size offset (samples)
  8: current data nd index start
  9: current data nd index end
  10: next data nd index
  11: num packets received this tick (nd index)
  12: nd 0 axis end offset
  13: none
  14: none
  15: none
*/
#define BUF_VARS_LEN 16

/*
 * Shared memory constants
 */

// Each section of shared memory's size is defined here:
#define NUM_TICKS_SIZE sizeof(int64_t)
#define CLOCK_TIME_SIZE sizeof(struct timespec)
#define BUF_VARS_SIZE (sizeof(uint32_t) * BUF_VARS_LEN * NUM_INTERNAL_SIGS)
#define ASYNC_READER_MUTEXES_SIZE (sizeof(pthread_mutex_t) * NUM_ASYNC_READERS)

// Each section of shared memory's byte off set is then calculatd
#define NUM_TICKS_OFFSET 0
#define CLOCK_TIME_OFFSET (NUM_TICKS_OFFSET + NUM_TICKS_SIZE)
#define BUF_VARS_OFFSET (CLOCK_TIME_OFFSET + CLOCK_TIME_SIZE)
#define ASYNC_READER_MUTEXES_OFFSET (BUF_VARS_OFFSET + BUF_VARS_SIZE)

// Results in a simple total size calculation
#define SHM_SIZE (NUM_TICKS_SIZE + CLOCK_TIME_SIZE + BUF_VARS_SIZE + ASYNC_READER_MUTEXES_SIZE)

// Named sempahore name buffer length.
#define SEM_NAME_LEN 32

#endif