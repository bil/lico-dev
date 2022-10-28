#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <inttypes.h> // includes <stdint.h>
#include <pthread.h>
#include <sched.h>
#include <semaphore.h>
#include <signal.h>
#include <stdatomic.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#ifdef __APPLE__
  #include <sys/uio.h>
#else
  #include <sys/io.h>
#endif
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <sys/resource.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

#include "constants.h"
#include "utilityFunctions.h"

#define TOPO_HEIGHT 0
#define NUM_SOURCES 0
#define NUM_SINKS 1
#define NUM_MODULES 0



// process IDs for each child numbered according to the index of the child's
// name in moduleProcnames
static pid_t ch_pids[NUM_MODULES] = {};
static char nonSourceProcnames[NUM_NON_SOURCES][MAX_MODULE_NAME_LEN] = {"pygame_demo"};
static int nonSourceModuleCheck[NUM_NON_SOURCES] = {0};

// child process IDs
static pid_t so_pids[NUM_SOURCES];
static pid_t ar_pids[NUM_ASYNC_READERS];
static pid_t si_pids[NUM_SINKS];
// numbered according to the index of the child's name in moduleProcnames
static pid_t ch_pids[NUM_MODULES];

// pointer to start of shared memory
static size_t shm_size;
static uint8_t *pmem;
// global tick counter
static int64_t *pNumTicks = NULL;
// TODO figure out better synch
// source buffer offset update synchronization semaphore
static sem_t *pSourceUpSems[NUM_SOURCES];
static sem_t *pSourceDownSems[NUM_SOURCES];
// per-process tick start semaphore
// timer signals each proces by upping this semaphore
static sem_t *pTickUpSems[NUM_NON_SOURCES];
// per-process computation end semaphore
// porcess signals timer by upping this semaphore
static sem_t *pTickDownSems[NUM_NON_SOURCES];
// signal semaphores. synchronizes process hierarchy during runtime 
static sem_t *pSigSems[NUM_SEM_SIGS];
// buffer for creating named semaphore names
char semNameBuf[SEM_NAME_LEN];

static uint32_t *pBufVars;

sigset_t exitMask;
static sigset_t alrmMask;

static int sigalrm_recv;
static int sigexit_recv;
static int sigchld_recv;

// static int num_cores = 12;
static size_t ex_i, al_i, de_i, m_i;

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
    if (si_pids[ex_i] && si_pids[ex_i] != -1) {
      printf("Killing sink: %d\n", si_pids[ex_i]);
      kill(si_pids[ex_i], SIGUSR1); // children already receive SIGUSR1
      while (waitpid(si_pids[ex_i], 0, WNOHANG) > 0);
    }
  }
  printf("Killing modules...\n");
  for (ex_i = 0; ex_i < NUM_MODULES; ex_i++) {
    if (ch_pids[ex_i] && ch_pids[ex_i] != -1) {
      printf("Killing module: %d\n", ch_pids[ex_i]);
      kill(ch_pids[ex_i], SIGUSR1); // children already receive SIGUSR1
      while (waitpid(ch_pids[ex_i], 0, WNOHANG) > 0);
    }
  }
  printf("Killing sources...\n");
  for (ex_i = 0; ex_i < NUM_SOURCES; ex_i++) {
    if (so_pids[ex_i] && so_pids[ex_i] != -1) {
      printf("Killing source: %d\n", so_pids[ex_i]);
      kill(so_pids[ex_i], SIGUSR1); // children already receive SIGUSR1
      while(waitpid(so_pids[ex_i], 0, WNOHANG) > 0){
        printf("waiting for pid: %d\n", so_pids[ex_i]);
        fflush(stdout);
      }
    }
  }
  printf("Killing async readers...\n");
  fflush(stdout);
  for (ex_i = 0; ex_i < NUM_ASYNC_READERS; ex_i++) {
    if (ar_pids[ex_i] != -1) {
      printf("Killing async reader: %d\n", ar_pids[ex_i]);
      fflush(stdout);
      kill(ar_pids[ex_i], SIGINT);
      kill(ar_pids[ex_i], SIGUSR1); // children already receive SIGUSR1
      while(waitpid(ar_pids[ex_i], 0, WNOHANG) > 0){
        printf("waiting for pid: %d\n", ar_pids[ex_i]);
        fflush(stdout);
      }
    }
  }

  if (pNumTicks == NULL) {
    printf("LiCoRICE ran for %" PRId64 " ticks.\n", (long long)(-1 * INIT_BUFFER_TICKS));
  }
  else {
    printf("LiCoRICE ran for %" PRId64 " ticks.\n", (*pNumTicks)+1);
  }

  printf("Unmapping shared memory...\n");

  // close shared memory
  munmap(pmem, shm_size);
  shm_unlink(SMEM0_PATHNAME);
  munlockall();

  printf("Closing and unlinking semaphores...\n");
  // close source semaphores
  for (ex_i = 0; ex_i < NUM_SOURCES; ex_i++) {
    sem_close(pSourceUpSems[ex_i]);
    snprintf(semNameBuf, SEM_NAME_LEN, "/source_up_sem%lu", ex_i);
    sem_unlink(semNameBuf);

    sem_close(pSourceDownSems[ex_i]);
    snprintf(semNameBuf, SEM_NAME_LEN, "/source_down_sem%lu", ex_i);
    sem_unlink(semNameBuf);
  }

  // close up tick semaphores
  for (ex_i = 0; ex_i < NUM_NON_SOURCES; ex_i++) {
    sem_close(pTickUpSems[ex_i]);
    snprintf(semNameBuf, SEM_NAME_LEN, "/tick_up_sem_%lu", ex_i);
    sem_unlink(semNameBuf);
  }

  // close down tick semaphores
  for (ex_i = 0; ex_i < NUM_NON_SOURCES; ex_i++) {
    sem_close(pTickDownSems[ex_i]);
    snprintf(semNameBuf, SEM_NAME_LEN, "/tick_down_sem_%lu", ex_i);
    sem_unlink(semNameBuf);
  }

  // close signal semaphores
  for (ex_i = 0; ex_i < NUM_SEM_SIGS; ex_i++) {
    sem_close(pSigSems[ex_i]);
    snprintf(semNameBuf, SEM_NAME_LEN, "/sig_sem_%lu", ex_i);
    sem_unlink(semNameBuf);
  }

  exit(exitStatus);
}

/*
 * set scheduler to SCHED_FIFO with the given priority
 */
void set_sched_prior(int priority) {
  struct sched_param param;
  param.sched_priority = priority;
  if (pthread_setschedparam(pthread_self(), SCHED_FIFO, &param) == -1) {
    die("pthread_setschedparam failed.\n");
  }
}

/*
 * set scheduler to SCHED_OTHER with the given priority
 */
void set_sched_prior_low(int priority) {
  struct sched_param param;
  param.sched_priority = priority;
  if (pthread_setschedparam(pthread_self(), SCHED_OTHER, &param) == -1) {
    die("pthread_setschedparam failed.\n");
  }
}


static void check_children() {
  
  if ((sigalrm_recv > 1))
    die("Timer missed a tick. (>1 unhandled sigalrms)");
  
  // increment SIGALRM counter
  (*pNumTicks)++;

  // only trigger sources on first iterations
  if (*pNumTicks < 0) {
    for (al_i = 0; al_i < NUM_SOURCES; al_i++) {
      sem_post(pSourceUpSems[al_i]);
    }
  }
  
  // normal behavior on subsequent iterations
  else {
    // check if modules have finished execution in allotted time (could just check last round, but need to properly figure val topo stuff again)
    for (al_i = 0; al_i < NUM_NON_SOURCES; al_i++) {
      if (sem_trywait(pTickDownSems[al_i])) {
        if (nonSourceModuleCheck[al_i]) {
          printf("Module timing violation on tick: %" PRId64 " from module %s\n", *pNumTicks, nonSourceProcnames[al_i]);
          die("Module timing violation.\n");
        }
        else {
          printf("Sink timing violation on tick: %" PRId64 " from sink %s\n", *pNumTicks, nonSourceProcnames[al_i]);
        }
      } 
    }

    for (al_i = 0; al_i < NUM_SOURCES; al_i++) {
      sem_post(pSourceUpSems[al_i]);
    }
    // trigger all non-source processes
    for (al_i = 0; al_i < NUM_NON_SOURCES; al_i++) {
      sem_post(pTickUpSems[al_i]);
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

  // TODO pmem offsets should be constants, or store in struct
  shm_size = ROUND_UP(SHM_SIZE, PAGESIZE);
  open_shared_mem(
    &pmem,
    SMEM0_PATHNAME,
    shm_size,
    O_TRUNC | O_CREAT | O_RDWR,
    PROT_READ | PROT_WRITE
  );
  pNumTicks = (int64_t *)(pmem + NUM_TICKS_OFFSET);
  pBufVars = (uint32_t *)(pmem + BUF_VARS_OFFSET);
  *pNumTicks = -1 * INIT_BUFFER_TICKS;

  // initialize source semaphores
  for (m_i = 0; m_i < NUM_SOURCES; m_i++) {
    snprintf(semNameBuf, SEM_NAME_LEN, "/source_up_sem_%lu", m_i);
    pSourceUpSems[m_i] = create_semaphore(&semNameBuf, 0);

    snprintf(semNameBuf, SEM_NAME_LEN, "/source_down_sem_%lu", m_i);
    pSourceDownSems[m_i] = create_semaphore(&semNameBuf, 1);
  }

  // initialize up tick semaphores
  for (m_i = 0; m_i < NUM_NON_SOURCES; m_i++) {
    snprintf(semNameBuf, SEM_NAME_LEN, "/tick_up_sem_%lu", m_i);
    pTickUpSems[m_i] = create_semaphore(&semNameBuf, 0);
  }

  // initialize down tick semaphores
  for (m_i = 0; m_i < NUM_NON_SOURCES; m_i++) {
    snprintf(semNameBuf, SEM_NAME_LEN, "/tick_down_sem_%lu", m_i);
    pTickDownSems[m_i] = create_semaphore(&semNameBuf, 1);
  }

  // initialize signal semaphores
  for (m_i = 0; m_i < NUM_SEM_SIGS; m_i++) {
    snprintf(semNameBuf, SEM_NAME_LEN, "/sig_sem_%lu", m_i);
    pSigSems[m_i] = create_semaphore(&semNameBuf, 0);
  }

  printf("Memory mapped.\nForking children...\n");
  
  // set priority
  set_sched_prior(PRIORITY);
  //cpu_set_t mask;
  //CPU_ZERO(&mask);
  //CPU_SET(1, &mask);
  //sched_setaffinity(0, sizeof(cpu_set_t), &mask);



  printf("Sources ready.\n");







// TODO write this loop in C
  // fork and exec data logger process
  if ((si_pids[0] = fork()) == -1) {
    die("fork failed \n");
  }
  if (si_pids[0] == 0) { // only runs for logger process
    // cpu_set_t mask;
    // for (int i = 1; i < num_cores - 1; i++) { // leave one core for system (core num_cores-1)
    //   CPU_SET(i, &mask);
    // }
    //CPU_ZERO(&mask);
    //CPU_SET(LOGGER_CPU, &mask);
    //sched_setaffinity(0, sizeof(cpu_set_t), &mask);
    setpriority(PRIO_PROCESS, 0, -2);
    set_sched_prior_low(0);
    char* argv[2] = {"./pygame_demo", NULL};
    
    // execute sink process
    // signal handlers and mmap are not preserved on exec
    execvp(argv[0],argv);
    printf("logger exec error. %s \n", strerror(errno));
    exit(1);
    //in case execvp fails
  }
  pause();
  printf("Sinks ready.\n");
printf("pygame_demo: %d\n", si_pids[0]);


  for (m_i = 0; m_i < NUM_ASYNC_READERS; m_i++) {
    kill(ar_pids[m_i], SIGUSR2);
  }
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