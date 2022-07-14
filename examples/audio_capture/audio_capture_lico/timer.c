#define _GNU_SOURCE
#include <stdio.h>
#include <signal.h>
#include <sys/time.h>
#include <string.h>
#include <stdlib.h>
#include <sys/io.h>
#include <unistd.h>
#include <sched.h>
#include <sys/mman.h>
#include <sys/resource.h>
#include <fcntl.h>
#include <errno.h>
#include <stdbool.h>
#include <sys/types.h>
#include <stdint.h>
#include <semaphore.h>
#include <sys/wait.h>
#include <stdatomic.h>
#include <time.h>
#include <stdlib.h>
#include "constants.h"
#include "utilityFunctions.h"

#define TOPO_HEIGHT 1
#define NUM_SOURCES 1
#define NUM_SINKS 1
#define NUM_MODULES 1

//////////////////////////////////////////////////////////////
#define NUM_NON_REAL_TIME_SOURCES 0
//////////////////////////////////////////////////////////////

#define NUM_TICKS_OFFSET 0
#define SOURCE_SEM_OFFSET 0
#define TICK_SEMS_OFFSET 0
#define SIG_SEMS_OFFSET 0
#define BUF_VARS_OFFSET 0



// process IDs for each child numbered according to the index of the child's name
// in moduleProcnames
static pid_t ch_pids[NUM_MODULES];
static char moduleProcnames[NUM_MODULES][MAX_MODULE_NAME_LEN] = {"audio_process"};
static char nonSourceProcnames[NUM_NON_SOURCES][MAX_MODULE_NAME_LEN] = {"audio_out", "audio_process"};
static int moduleTopoLens[TOPO_HEIGHT] = {1};
static int moduleTopoOrder[TOPO_HEIGHT][1];
static int sourceOutSigNums[NUM_SOURCE_SIGS] = {0};
static int nonSourceModuleCheck[NUM_NON_SOURCES] = {0, 1};
// network pid
static pid_t so_pids[NUM_SOURCES];
// logger pid
static pid_t si_pids[NUM_SINKS];


// pointer to start of shared memory
static size_t shm_size;
static uint8_t *pmem;
// global tick counter
static int64_t *pNumTicks;
// TODO figure out better synch
// source buffer offset update synchronization semaphore
static sem_t *pSourceUpSem;
static sem_t *pSourceDownSem;
// per-process tick start semaphore
// timer signals each proces by upping this semaphore
static sem_t *pTickUpSems;
// per-process computation end semaphore
// porcess signals timer by upping this semaphore
static sem_t *pTickDownSems;
// signal semaphores. synchronizes process hierarchy during runtime 
static sem_t *pSigSems;

static uint32_t *pBufVars;
static uint32_t *pCurBufVars;

sigset_t exitMask;
static sigset_t alrmMask;

static int sigalrm_recv;
static int sigexit_recv;
static int sigchld_recv;

////////////////////////////////////////////////
static pid_t nrtSource_pids[NUM_NON_REAL_TIME_SOURCES];
////////////////////////////////////////////////

// static int num_cores = 4;
static size_t ex_i, al_i, de_i, m_i;static int m_j;

static struct itimerval rtTimer;

// INSERTED
//static struct timespec record_timer;
//static long curTime;
//static time_t curSec;
//static FILE *f;

void handle_exit(int exitStatus) {
  rtTimer.it_value.tv_sec = 0;
  rtTimer.it_value.tv_usec = 0;
  rtTimer.it_interval.tv_sec = 0;
  rtTimer.it_interval.tv_usec = 0;
  setitimer(ITIMER_REAL, &rtTimer, NULL);
  printf("exiting...\n");
  printf("Killing sinks...\n");
  for (ex_i = 0; ex_i < NUM_SINKS; ex_i++) {
    if (si_pids[ex_i] != -1) {
      printf("Killing sink: %d\n", si_pids[ex_i]);
      kill(si_pids[ex_i], SIGUSR1); // children already receive SIGUSR1
      while (waitpid(si_pids[ex_i], 0, WNOHANG) > 0);
    }
  }
  printf("Killing modules...\n");
  for (ex_i = 0; ex_i < NUM_MODULES; ex_i++) {
    if (ch_pids[ex_i] != -1) {
      printf("Killing module: %d\n", ch_pids[ex_i]);
      kill(ch_pids[ex_i], SIGUSR1); // children already receive SIGUSR1
      while (waitpid(ch_pids[ex_i], 0, WNOHANG) > 0);
    }
  }
  printf("Killing sources...\n");
  for (ex_i = 0; ex_i < NUM_SOURCES; ex_i++) {
    if (so_pids[ex_i] != -1) {
      printf("Killing source: %d\n", so_pids[ex_i]);
      kill(so_pids[ex_i], SIGUSR1); // children already receive SIGUSR1
      //while (waitpid(so_pids[ex_i], 0, WNOHANG) > 0);
      while(waitpid(-1, 0, WNOHANG) > 0){
        printf("waiting for pid: %d\n", so_pids[ex_i]);
        fflush(stdout);
      }
    }
  }

 ////////////////////////////////////////////////
  for(ex_i = 0; ex_i < NUM_NON_REAL_TIME_SOURCES; ex_i++){
    if(nrtSource_pids[ex_i] != -1){
      printf("Killing non-real-time source: %d\n", nrtSource_pids[ex_i]);
      kill(nrtSource_pids[ex_i], SIGUSR1); 
      while(waitpid(-1, 0, WNOHANG) > 0){
        printf("waiting for pid: %d\n", nrtSource_pids[ex_i]);
        fflush(stdout);
      }
    }
  }
  ////////////////////////////////////////////////

  printf("Unmapping shared memory...\n");
  printf("LiCoRICE ran for %ld ticks.\n", *pNumTicks);
  // close shared memory
  munmap(pmem, shm_size);
  shm_unlink(SMEM0_PATHNAME);
  munlockall();
  exit(exitStatus);
}

void set_sched_prior(int priority) {
  struct sched_param param;
  param.sched_priority = priority;
  if (sched_setscheduler(0, SCHED_FIFO, &param) == -1) {
    die("sched_setscheduler failed.\n");
  }
}

void set_sched_prior_low(int priority) {
  struct sched_param param;
  param.sched_priority = priority;
  if (sched_setscheduler(0, SCHED_OTHER, &param) == -1) {
    die("sched_setscheduler failed.\n");
  }
}


static void check_children() {
  
  // printf("TIMER tick %ld\n", *pNumTicks);
  if ((sigalrm_recv > 1))
    die("Timer missed a tick. (>1 unhandled sigalrms)");
  
  // increment SIGALRM counter
  (*pNumTicks)++;
  
  // only trigger sources on first iterations
  if (*pNumTicks < 0) {
    for (al_i = 0; al_i < NUM_SOURCES; al_i++) 
      sem_wait(pSourceDownSem);

    atomic_thread_fence(memory_order_seq_cst);
    // printf("Number of internal signals: %d", NUM_INTERNAL_SIGS);
    for (al_i = 0; al_i < NUM_INTERNAL_SIGS; al_i++) {
      pCurBufVars = pBufVars + (BUF_VARS_LEN * al_i);
      // NON-LATENCY-DEPENDENT BUFFER UPDATE
      *(pCurBufVars + 1) = *(pCurBufVars + 2);
      // *(pCurBufVars + 9) = *(pCurBufVars + 10);
      *(pCurBufVars + 0) = *(pCurBufVars + 1) - *(pCurBufVars + 3);
      // printf("%u\n", pCurBufVars[0]);
      // *(pCurBufVars + 8) = *(pCurBufVars + 9) - *(pCurBufVars + 11);
      if ((*(pCurBufVars + 7) < *(pCurBufVars + 2)) + *(pCurBufVars + 6)) {
        *(pCurBufVars + 2) = 0;
        *(pCurBufVars + 10) = 0;
        // *(pCurBufVars + 8) = 0;
      }
      *(pCurBufVars + 3) = 0;
      *(pCurBufVars + 11) = 0;
    }
    atomic_thread_fence(memory_order_release);
    for (al_i = 0; al_i < NUM_SOURCES; al_i++)
      sem_post(pSourceUpSem);    

    for (al_i = 0; al_i < NUM_SOURCES; al_i++)
      kill(so_pids[al_i], SIGALRM);
  }
  
  // normal behavior on subsequent iterations
  else {
    // check if modules have finished execution in allotted time (could just check last round, but need to properly figure val topo stuff again)
    for (al_i = 0; al_i < NUM_NON_SOURCES; al_i++) {
      if (sem_trywait(pTickDownSems + al_i)) {
        if (nonSourceModuleCheck[al_i]) {
          printf("Module timing violation on ms: %lu from module %s\n", *pNumTicks, nonSourceProcnames[al_i]);
          die("Module timing violation.\n");
        }
        else {
          printf("Sink timing violation on ms: %lu from sink %s\n", *pNumTicks, nonSourceProcnames[al_i]);
        }
      } 
    }

    for (al_i = 0; al_i < NUM_SOURCES; al_i++)
      sem_wait(pSourceDownSem);
  
    // TODO does this need to be sequentially consistent?
    atomic_thread_fence(memory_order_seq_cst);


    for (al_i = 0; al_i < NUM_SOURCE_SIGS; al_i++) {
      pCurBufVars = pBufVars + (BUF_VARS_LEN * sourceOutSigNums[al_i]);

      // 0: tick start
      // 1: tick end
      // 2: next data location
      // 3: num samples received this tick
      // 4: buffer end offset (samples)
      // 5: source output signal packet size (post parser per signal)/module output tick data size (samples)
      // 6: max samples per tick (same as 5 for module ouputs) (samples)
      // 7: buffer size offset (samples)

      // 8: current data nd index start
      // 9: current data nd index end
      // 10: next data nd index
      // 11: num packets received this tick (nd index) # don't use this for now. TODO: for 'fixed' sources (e.g., parallel, usb), set this to a constant value
      // 12: nd 0 axis end offset
      // 13: none
      // 14: none
      // 15: none

      // printf("timer 1: %u %u %u %u %u \n", *(pCurBufVars + 0),*(pCurBufVars + 1),*(pCurBufVars + 2),*(pCurBufVars + 6),*(pCurBufVars + 7));
      *(pCurBufVars + 1) = *(pCurBufVars + 2);
      
      // *(pCurBufVars + 9) = *(pCurBufVars + 10);
      *(pCurBufVars + 0) = *(pCurBufVars + 1) - *(pCurBufVars + 3);
      // *(pCurBufVars + 8) = *(pCurBufVars + 9) - *(pCurBufVars + 11);
      if (*(pCurBufVars + 7) < *(pCurBufVars + 2) + *(pCurBufVars + 6)) {
        *(pCurBufVars + 2) = 0;
        *(pCurBufVars + 10) = 0;
        // *(pCurBufVars + 8) = 0;
      }
      *(pCurBufVars + 3) = 0;
      // *((uint32_t**)(pCurBufVars + 8)) += 1472;
      *(pCurBufVars + 11) = 0;
      // printf("timer 2: %u %u %u %u %u \n", *(pCurBufVars + 0),*(pCurBufVars + 1),*(pCurBufVars + 2),*(pCurBufVars + 6),*(pCurBufVars + 7));
      // if (*(pCurBufVars + 2) == 0) {
      //   *(pCurBufVars + 1) = *(pCurBufVars + 4);
      //   *(pCurBufVars + 0) = *(pCurBufVars + 4) - *(pCurBufVars + 3);
      // }
      // else {
      //   *(pCurBufVars + 1) = *(pCurBufVars + 2);
      //   *(pCurBufVars + 0) = (*(pCurBufVars + 1) - *(pCurBufVars + 3));
      // }
      // *(pCurBufVars + 3) = 0;

   }

    atomic_thread_fence(memory_order_release);
    for (al_i = 0; al_i < NUM_SOURCES; al_i++)
      sem_post(pSourceUpSem);
    
    // trigger sources
    for (al_i = 0; al_i < NUM_SOURCES; al_i++) {
      kill(so_pids[al_i], SIGALRM);
    }
    // trigger all non-source processes
    for (al_i = 0; al_i < NUM_NON_SOURCES; al_i++) {
      sem_post(pTickUpSems + al_i);
    }
  }

  sigalrm_recv--;
}

// Handle SIGALRM on tick start
void event_handler(int signum) {
  sigalrm_recv++;
}

void exit_handler(int signum) {
  sigexit_recv++;
}

void usr1_handler(int signum) {
  //do nothing, this sig is just used for communication
}

void usr2_handler(int signum) {
  //do nothing, this sig is just used for communication
}

void dead_child() {
  --sigchld_recv;
  int saved_errno = errno;
  int dead_pid;
  while ((dead_pid = waitpid((pid_t)(-1), 0, WNOHANG)) == 0);
  printf("dead pid: %d \n", dead_pid);
  for (de_i = 0; de_i < NUM_SINKS; de_i++) {   
    if (si_pids[de_i] == dead_pid) {
      si_pids[de_i] = -1;
    }
  }
  for (de_i = 0; de_i < NUM_SINKS; de_i++) {   
    if (so_pids[de_i] == dead_pid) {
      so_pids[de_i] = -1;
    }
  }
  for (de_i = 0; de_i < NUM_MODULES; de_i++) {
    if (ch_pids[de_i] == dead_pid) {
      ch_pids[de_i] = -1;
    }
  }

  ////////////////////////////////////////////////
  for (de_i = 0; de_i < NUM_NON_REAL_TIME_SOURCES; de_i++) {
    if (nrtSource_pids[de_i] == dead_pid) {
      nrtSource_pids[de_i] = -1;
    }
  }
  ////////////////////////////////////////////////

  errno = saved_errno;
  die("I have lost a child :( \n");
}

void chld_handler(int sig) {
  sigchld_recv++;
}

void interrupt_handler(int sig){
  printf("received interrupted system call error\n");
}

/*
 * Timer parent main
 */
int main(int argc, char* argv[]) {

  // set signal masks
  sigemptyset(&exitMask);
  sigaddset(&exitMask, SIGALRM);  
  sigfillset(&alrmMask);
  // sigdelset(&alrmMask, SIGINT);
  // initialize utilityFunctions
  init_utils(&handle_exit, &exitMask);

  // set signal handlers
  set_sighandler(SIGINT, &exit_handler, &exitMask);
  set_sighandler(SIGALRM, &event_handler, &alrmMask);
  set_sighandler(SIGUSR1, &usr1_handler, NULL);
  set_sighandler(SIGUSR2, &usr2_handler, NULL);
  set_sighandler(SIGCHLD, &chld_handler, NULL);
  // set_sighandler(SIGINT, interrupt_handler, NULL);
  printf("Handlers installed.\n");

  // create shared memory and map it
  printf("Mapping memory...\n");

  // TODO pmem offsets should be constants
  shm_size = sizeof(uint64_t) + (sizeof(sem_t) * (1 + NUM_NON_SOURCES + NUM_SEM_SIGS)) + (sizeof(uint32_t) * BUF_VARS_LEN * NUM_INTERNAL_SIGS);
  shm_size = ROUND_UP(shm_size, PAGESIZE);
  open_shared_mem(&pmem, SMEM0_PATHNAME, shm_size, O_TRUNC | O_CREAT | O_RDWR, PROT_READ | PROT_WRITE);
  pNumTicks = (int64_t *)(pmem);
  pSourceUpSem = (sem_t *)(pmem + sizeof(uint64_t));
  pSourceDownSem = (sem_t *)(pmem + sizeof(uint64_t) + sizeof(sem_t));
  pTickUpSems = (sem_t *)(pmem + sizeof(uint64_t) + 2 * sizeof(sem_t));
  pTickDownSems = (sem_t *)(pmem + sizeof(uint64_t) + 2 * sizeof(sem_t) + (NUM_NON_SOURCES * sizeof(sem_t)));
  pSigSems = (sem_t *)(pmem + sizeof(uint64_t) +  2 * sizeof(sem_t) + (2 * NUM_NON_SOURCES * sizeof(sem_t)));
  pBufVars = (uint32_t *)(pmem + sizeof(uint64_t) + 2 * sizeof(sem_t) + (2 * NUM_NON_SOURCES * sizeof(sem_t)) + NUM_SEM_SIGS * sizeof(sem_t));

  *pNumTicks = -1 * INIT_BUFFER_TICKS;

  // initialize source semaphore
  sem_init(pSourceUpSem, 1, 0);
  sem_init(pSourceDownSem, 1, NUM_SOURCES); 

  // initialize up tick semaphores
  for (m_i = 0; m_i < NUM_NON_SOURCES; m_i++) {
    sem_init(pTickUpSems + m_i, 1, 0);
  }

  // initialize down tick semaphores
  for (m_i = 0; m_i < NUM_NON_SOURCES; m_i++) {
    sem_init(pTickDownSems + m_i, 1, 1);
  }

  // initialize signal semaphores
  for (m_i = 0; m_i < NUM_SEM_SIGS; m_i++) {
    sem_init(pSigSems + m_i, 1, 0);
  }

  printf("Memory mapped.\nForking children...\n");
  
  // set priority
  set_sched_prior(PRIORITY);
  //cpu_set_t mask;
  //CPU_ZERO(&mask);
  //CPU_SET(1, &mask);
  //sched_setaffinity(0, sizeof(cpu_set_t), &mask);

////////////////////////////////////////////////

////////////////////////////////////////////////

// TODO write this loop in C
  // fork and exec network process
  if ((so_pids[0] = fork()) == -1) {
    die("fork failed \n");
  }
  if (so_pids[0] == 0) { // only runs for network process
    cpu_set_t mask;
    // for (int i = 2; i < num_cores - 1; i++) { // leave one core for system (core num_cores-1)
    //   CPU_SET(i, &mask);
    // }
    printf("Source: audio_in\n");
    CPU_ZERO(&mask);
    CPU_SET(NETWORK_CPU, &mask);
    sched_setaffinity(0, sizeof(cpu_set_t), &mask);
    setpriority(PRIO_PROCESS, 0, -19);
    set_sched_prior(PRIORITY);
    char* argv[2] = {"./audio_in", NULL};
    
    // execute network process
    // signal handlers and mmap are not preserved on exec
    execvp(argv[0],argv);
    printf("network exec error. %s \n", strerror(errno));
    exit(1);
    //in case execvp fails
  }
  pause();
  printf("Sources ready.\n");
  printf("audio_in: %d\n", so_pids[0]);



  // fork and exec child processes
  moduleTopoOrder[0][0] = 0;
  
  for (m_i = 0; m_i < TOPO_HEIGHT; m_i++) {
    for (m_j = 0; m_j < moduleTopoLens[m_i]; m_j++) {
      int childNum = moduleTopoOrder[m_i][m_j];
      if ((ch_pids[childNum] = fork()) == -1) {
        die("fork failed\n");
      }
      if (ch_pids[childNum] == 0) {  // only runs for child processes
        //cpu_set_t mask;
        //CPU_ZERO(&mask);
        //CPU_SET(m_j + CPU_OFFSET, &mask);
        //sched_setaffinity(0, sizeof(cpu_set_t), &mask);
        setpriority(PRIO_PROCESS, 0, -19);
        set_sched_prior(PRIORITY);
        char procBuf[64];
        sprintf(procBuf, "./%s", moduleProcnames[childNum]);
        char* argv[2] = {procBuf, NULL};

        // execute child process
        // signal handlers and mmap are not preserved on exec
        execvp(argv[0],argv);
        printf("child exec error. %s \n", strerror(errno));
        exit(1);
        //in case execvp fails
      }
      pause();
    }
  }
  printf("Internal modules ready.\n");

for (m_i = 0; m_i < TOPO_HEIGHT; m_i++) {
  printf("%s: %d\n", moduleProcnames[m_i], ch_pids[m_i]);
}

// TODO write this loop in C
  // fork and exec data logger process
  if ((si_pids[0] = fork()) == -1) {
    die("fork failed \n");
  }
  if (si_pids[0] == 0) { // only runs for logger process
    //cpu_set_t mask;
    // for (int i = 1; i < num_cores - 1; i++) { // leave one core for system (core num_cores-1)
    //   CPU_SET(i, &mask);
    // }
    //CPU_ZERO(&mask);
    //CPU_SET(LOGGER_CPU, &mask);
    //sched_setaffinity(0, sizeof(cpu_set_t), &mask);
    setpriority(PRIO_PROCESS, 0, -2);
    set_sched_prior_low(0);
    char* argv[2] = {"./audio_out", NULL};
    
    // execute sink process
    // signal handlers and mmap are not preserved on exec
    execvp(argv[0],argv);
    printf("logger exec error. %s \n", strerror(errno));
    exit(1);
    //in case execvp fails
  }
  pause();
  printf("Sinks ready.\n");
printf("audio_out: %d\n", si_pids[0]);


  make_realtime();

  for (m_i = 0; m_i < NUM_SOURCES; m_i++) {
    kill(so_pids[m_i], SIGUSR2);
  }
  printf("Sources signaled.\n");

  // set up timer
  printf("Setting up timer...\n");
  fflush(stdout);

  rtTimer.it_value.tv_sec = SECREQ;
  rtTimer.it_value.tv_usec = USECREQ;
  rtTimer.it_interval.tv_sec = SECREQ;
  rtTimer.it_interval.tv_usec = USECREQ;
  setitimer(ITIMER_REAL, &rtTimer, NULL);

  while(1) {
    if (sigexit_recv)
      handle_exit(0);
    if (sigchld_recv)
      dead_child();
    if (sigalrm_recv)
      check_children();
    pause();
  }
}