#define _GNU_SOURCE
#include <limits.h>
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
#ifdef __APPLE__
#include "darwin_compat/clock_nanosleep.h"
#endif


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
static pid_t aw_pids[NUM_ASYNC_WRITERS];
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

static int running = true;
static int sigchld_recv;

// static int num_cores = 12;
static size_t ex_i, al_i, de_i, m_i;

struct period_info {
  struct timespec next_period;
  long period_ns;
  long period_s;
  int parportfd;
  int parportRet;
  unsigned char outVal;
};

static void timer_init(struct period_info *pinfo) {
  /* for simplicity, hardcoding a 1ms period */
  pinfo->period_ns = TICK_LEN_NS;
  pinfo->period_s = TICK_LEN_S;

  pinfo->outVal = 0b00000001;

  clock_gettime(CLOCK_MONOTONIC, &(pinfo->next_period));
}

void handle_exit(int exitStatus) {

  printf("exiting...\n");
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
  printf("Killing async writers...\n");
  fflush(stdout);
  for (ex_i = 0; ex_i < NUM_ASYNC_WRITERS; ex_i++) {
    if (aw_pids[ex_i] != -1) {
      printf("Killing async writer: %d\n", aw_pids[ex_i]);
      fflush(stdout);
      kill(aw_pids[ex_i], SIGINT);
      kill(aw_pids[ex_i], SIGUSR1); // children already receive SIGUSR1
      while(waitpid(aw_pids[ex_i], 0, WNOHANG) > 0){
        printf("waiting for pid: %d\n", aw_pids[ex_i]);
        fflush(stdout);
      }
    }
  }
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

  if (pNumTicks == NULL) {
    printf("LiCoRICE ran for %" PRId64 " ticks.\n", (int64_t)(-1 * INIT_BUFFER_TICKS));
  }
  else {
    printf("LiCoRICE ran for %" PRId64 " ticks.\n", (int64_t)(*pNumTicks)+1);
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

static void timer_cleanup(struct period_info *pinfo) {
}

#ifndef __APPLE__
/*
 * set scheduler to SCHED_FIFO with the given priority
 */
void set_sched_prior(int priority) {
  struct sched_param param;
  param.sched_priority = priority;
  if (sched_setscheduler(0, SCHED_FIFO, &param) == -1) {
    die("pthread_setschedparam failed.\n");
  }
}
#endif

static void check_children(struct period_info *pinfo) {

  // if ((sigalrm_recv > 1))
  //   die("Timer missed a tick. (>1 unhandled sigalrms)");

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
          fflush(stdout);
          running = 0;
          return;
        }
        else {
          printf("Sink timing violation on tick: %" PRId64 " from sink %s\n", *pNumTicks, nonSourceProcnames[al_i]);
          fflush(stdout);
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
}


void exit_handler(int signum) {
  running = false;
}


void chld_handler(int signum) {
  sigchld_recv++;
  running = false;
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
  for (de_i = 0; de_i < NUM_MODULES; de_i++) {
    if (ch_pids[de_i] == dead_pid) {
      ch_pids[de_i] = -1;
    }
  }
  for (de_i = 0; de_i < NUM_SOURCES; de_i++) {
    if (so_pids[de_i] == dead_pid) {
      so_pids[de_i] = -1;
    }
  }

  errno = saved_errno;

  printf("I have lost a child :( \n");
  running = 0;
  return;
}


static void wait_rest_of_period(struct period_info *pinfo) {
  pinfo->next_period.tv_nsec += pinfo->period_ns;
  pinfo->next_period.tv_sec += pinfo->period_s;

  while (pinfo->next_period.tv_nsec >= 1000000000) {
    /* timespec nsec overflow */
    pinfo->next_period.tv_sec++;
    pinfo->next_period.tv_nsec -= 1000000000;
  }

  /* for simplicity, ignoring possibilities of signal wakes */
  clock_nanosleep(CLOCK_MONOTONIC, TIMER_ABSTIME, &pinfo->next_period, NULL);
}


void *timer_task(void *data) {
  struct period_info pinfo;

  timer_init(&pinfo);


  while (running) {
    check_children(&pinfo);
    wait_rest_of_period(&pinfo);
  }

  if (sigchld_recv) {
    dead_child();
  }

  timer_cleanup(&pinfo);

  return NULL;
}


/*
 * Timer parent main
 */
int main(int argc, char* argv[]) {

  struct sched_param param;
  pthread_attr_t attr;
  pthread_t thread;

  // set signal masks
  sigemptyset(&exitMask);

  // initialize utilityFunctions
  init_utils(&handle_exit, &exitMask);

  // set signal handlers
  set_sighandler(SIGINT, &exit_handler, &exitMask);
  set_sighandler(SIGUSR1, &usr1_handler, NULL);
  set_sighandler(SIGUSR2, &usr2_handler, NULL);
  set_sighandler(SIGCHLD, &chld_handler, NULL);
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
    pSourceUpSems[m_i] = create_semaphore(semNameBuf, 0);

    snprintf(semNameBuf, SEM_NAME_LEN, "/source_down_sem_%lu", m_i);
    pSourceDownSems[m_i] = create_semaphore(semNameBuf, 1);
  }

  // initialize up tick semaphores
  for (m_i = 0; m_i < NUM_NON_SOURCES; m_i++) {
    snprintf(semNameBuf, SEM_NAME_LEN, "/tick_up_sem_%lu", m_i);
    pTickUpSems[m_i] = create_semaphore(semNameBuf, 0);
  }

  // initialize down tick semaphores
  for (m_i = 0; m_i < NUM_NON_SOURCES; m_i++) {
    snprintf(semNameBuf, SEM_NAME_LEN, "/tick_down_sem_%lu", m_i);
    pTickDownSems[m_i] = create_semaphore(semNameBuf, 1);
  }

  // initialize signal semaphores
  for (m_i = 0; m_i < NUM_SEM_SIGS; m_i++) {
    snprintf(semNameBuf, SEM_NAME_LEN, "/sig_sem_%lu", m_i);
    pSigSems[m_i] = create_semaphore(semNameBuf, 0);
  }

  printf("Memory mapped.\nForking children...\n");


  printf("Sources ready.\n");







// TODO write this loop in C
  // fork and exec data logger process
  if ((si_pids[0] = fork()) == -1) {
    die("fork failed \n");
  }
  if (si_pids[0] == 0) { // only runs for logger process
#ifndef __APPLE__
    // cpu_set_t mask;
    // for (int i = 1; i < num_cores - 1; i++) { // leave one core for system (core num_cores-1)
    //   CPU_SET(i, &mask);
    // }
    //CPU_ZERO(&mask);
    //CPU_SET(LOGGER_CPU, &mask);
    //sched_setaffinity(0, sizeof(cpu_set_t), &mask);
    setpriority(PRIO_PROCESS, 0, -2);
    set_sched_prior(PRIORITY-1);
#else
    // TODO implement Darwin CPU affinity
    // TODO implement Darwin priority
#endif
    char* argv[2] = {"./pygame_demo", NULL};

    // execute sink process
    // signal handlers and mmap are not preserved on exec
    execvp(argv[0],argv);
    printf("sink exec error. %s \n", strerror(errno));
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
  printf("Starting timer thread...\n");
  fflush(stdout);

  /* Initialize pthread attributes (default values) */
  if (pthread_attr_init(&attr)) {
    die("init pthread attributes failed\n");
  }

  // TODO: https://rt.wiki.kernel.org/index.php/Threaded_RT-application_with_memory_locking_and_stack_handling_example
  /* Set a specific stack size  */
  if (pthread_attr_setstacksize(&attr, PTHREAD_STACK_MIN)) {
    die("pthread setstacksize failed\n");
  }

  /* Set scheduler policy and priority of pthread */
  if (pthread_attr_setschedpolicy(&attr, SCHED_FIFO)) {
    die("pthread setschedpolicy failed\n");
  }

  param.sched_priority = PRIORITY;
  if (pthread_attr_setschedparam(&attr, &param)) {
    die("pthread setschedparam failed\n");
  }

  if (pthread_attr_setinheritsched(&attr, PTHREAD_EXPLICIT_SCHED)) {
    die("pthread setinheritsched failed\n");
  }

  /* Set affinity mask to include CPUs 1. */
  // TODO expose this as config var
#ifndef __APPLE__
  cpu_set_t cpuset;
  CPU_ZERO(&cpuset);
  CPU_SET(1, &cpuset);

  if (pthread_attr_setaffinity_np(&attr, sizeof(cpuset), &cpuset)) {
    die("pthread setaffinity_np failed\n");
  }
#endif

  //  /* Check the actual affinity mask assigned to the thread. */
  // if (pthread_attr_getaffinity_np(&attr, sizeof(cpuset), &cpuset)) {
  //   die("pthread getaffinity_np failed\n");
  // }

  // printf("Set returned by pthread_getaffinity_np() contained:\n");
  // for (int j = 0; j < 4; j++) {
  //   if (CPU_ISSET(j, &cpuset)) {
  //     printf("    CPU %d\n", j);
  //     fflush(stdout);
  //   }
  // }

  if (pthread_create(&thread, &attr, timer_task, NULL)) {
    perror("Error: ");
    die("create pthread failed\n");
  }

  if (pthread_join(thread, NULL)) {
    die("join pthread failed\n");
  }

  handle_exit(0);
}