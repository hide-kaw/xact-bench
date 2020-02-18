#include <ctype.h>
#include <pthread.h>
#include <sched.h>
#include <stdlib.h>
#include <string.h>
#include <sys/syscall.h>
#include <sys/time.h>
#include <sys/types.h>
#include <unistd.h>
#include <algorithm>
#include <cctype>
#include <cstdlib>
#include <iostream>
#include <sstream>
#include <iomanip>

#define GLOBAL_VALUE_DEFINE


#include "include/atomic_tool.hh"
#include "include/common.hh"
#include "include/transaction.hh"
LOG_MANAGER *LogManager;

#include "../include/atomic_wrapper.hh"
#include "../include/backoff.hh"
#include "../include/cpu.hh"
#include "../include/debug.hh"
#include "../include/fileio.hh"
#include "../include/masstree_wrapper.hh"
#include "../include/random.hh"
#include "../include/result.hh"
#include "../include/tsc.hh"
#include "../include/util.hh"
#include "../include/zipf.hh"


using namespace std;

extern void chkArg(const int argc, char* argv[]);
extern bool chkClkSpan(const uint64_t start, const uint64_t stop,
                       const uint64_t threshold);
extern bool chkEpochLoaded();
extern void displayParameter();
extern void isReady(const std::vector<char>& readys);
extern void leaderWork(uint64_t& epoch_timer_start, uint64_t& epoch_timer_stop);
extern void displayDB();
extern void displayPRO();
extern void genLogFile(std::string& logpath, const int thid);
extern void makeDB();
extern void waitForReady(const std::vector<char>& readys);
extern void sleepMs(size_t ms);

void worker(size_t thid, char& ready, const bool& start, const bool& quit,
            std::vector<Result>& res) {
  Result& myres = std::ref(res[thid]);
  Xoroshiro128Plus rnd;
  rnd.init();
  TxnExecutor trans(thid, (Result*)&myres);
  FastZipf zipf(&rnd, ZIPF_SKEW, TUPLE_NUM);
  uint64_t epoch_timer_start, epoch_timer_stop;
  Backoff backoff(CLOCKS_PER_US);

  #ifdef WAL_SYNC
  char path[BUFSIZ];
  bzero(path, BUFSIZ);
  sprintf(path, "/home/guest/pmem/log/%d", thid);
  trans.logfile_.open(path, O_CREAT|O_TRUNC | O_WRONLY|O_APPEND, 0644);
  #endif
  
#if MASSTREE_USE
  MasstreeWrapper<Tuple>::thread_init(int(thid));
#endif

#ifdef Linux
  setThreadAffinity(thid);
  // printf("Thread #%d: on CPU %d\n", res.thid_, sched_getcpu());
  // printf("sysconf(_SC_NPROCESSORS_CONF) %d\n",
  // sysconf(_SC_NPROCESSORS_CONF));
#endif

  storeRelease(ready, 1);
  while (!loadAcquire(start)) _mm_pause();
  if (thid == 0) epoch_timer_start = rdtscp();
  while (!loadAcquire(quit)) {
#if PARTITION_TABLE
    makeProcedure(trans.pro_set_, rnd, zipf, TUPLE_NUM, MAX_OPE, THREAD_NUM,
                  RRATIO, RMW, YCSB, true, thid, res);
#else
    makeProcedure(trans.pro_set_, rnd, zipf, TUPLE_NUM, MAX_OPE, THREAD_NUM,
                  RRATIO, RMW, YCSB, false, thid, myres);
#endif

#if PROCEDURE_SORT
    sort(trans.pro_set_.begin(), trans.pro_set_.end());
#endif

  RETRY:
    if (thid == 0) {
      leaderWork(epoch_timer_start, epoch_timer_stop);
      leaderBackoffWork(backoff, res);
      // printf("Thread #%d: on CPU %d\n", thid, sched_getcpu());
    }

    if (loadAcquire(quit)) break;

    trans.begin();
    for (auto itr = trans.pro_set_.begin(); itr != trans.pro_set_.end();
         ++itr) {
      if ((*itr).ope_ == Ope::READ) {
        trans.read((*itr).key_);
      } else if ((*itr).ope_ == Ope::WRITE) {
        trans.write((*itr).key_);
      } else if ((*itr).ope_ == Ope::READ_MODIFY_WRITE) {
        trans.read((*itr).key_);
        trans.write((*itr).key_);
      } else {
        ERR;
      }
    }

    if (trans.validationPhase()) {
      trans.writePhase();
      ++myres.local_commit_counts_;
    } else {
      trans.abort();
      ++myres.local_abort_counts_;
      goto RETRY;
    }
  }

  return;
}

void *
logger(void *arg)
{
  arg = NULL; // just to make compiler quiet

  // open log file (river)
  for (uint thid = 0; thid < THREAD_NUM; thid++) {
    std::ostringstream oss;	oss << thid;
    std::string logpath = "/home/guest/nvme/log/log-" + oss.str();
    //std::cout << logpath << std::endl;
    genLogFile(logpath, thid);
    LogManager[thid].logfile_.open(logpath, O_TRUNC | O_WRONLY, 0644);
  }
  //trans.logfile.ftruncate(10^9);
  
  while (true) {
    for (uint i = 0; i < THREAD_NUM; i++) {
      if (LogManager[i].cur_log_ == 1) { // 1 is used for workers, My Log ID = 2
        pthread_mutex_lock(&LogManager[i].lck_log_2_);
        // prepare write header
        LogManager[i].latest_log_header_2_.convertChkSumIntoComplementOnTwo();
        // write header
        LogManager[i].logfile_.write((void *)&LogManager[i].latest_log_header_2_, sizeof(LogHeader));
        // write log record
        LogManager[i].logfile_.write((void *)&(LogManager[i].log_set_2_[0]),
                                     sizeof(LogRecord) * LogManager[i].latest_log_header_2_.logRecNum);
        // sync
        LogManager[i].logfile_.fdatasync();
        // clear for next transactions.
        LogManager[i].latest_log_header_2_.init();
        LogManager[i].log_set_2_.clear();
        pthread_mutex_unlock(&LogManager[i].lck_log_2_);
      } else { // My Log ID = 1
        pthread_mutex_lock(&LogManager[i].lck_log_1_);
        // prepare write header
        LogManager[i].latest_log_header_1_.convertChkSumIntoComplementOnTwo();
        // write header
        LogManager[i].logfile_.write((void *)&LogManager[i].latest_log_header_1_, sizeof(LogHeader));
        // write log record
        LogManager[i].logfile_.write((void *)&(LogManager[i].log_set_1_[0]),
                                     sizeof(LogRecord) * LogManager[i].latest_log_header_1_.logRecNum);
        // sync
        LogManager[i].logfile_.fdatasync();
        // clear for next transactions.
        LogManager[i].latest_log_header_1_.init();
        LogManager[i].log_set_1_.clear();
        pthread_mutex_unlock(&LogManager[i].lck_log_1_);
      }
    }
  }
}

void
initLog(void)
{
  LogManager = new LOG_MANAGER[THREAD_NUM];
  for (uint i = 0; i < THREAD_NUM; i++) {
    LogManager[i].cur_log_ = 1;
    pthread_mutex_init(&LogManager[i].lck_log_1_, NULL);
    pthread_mutex_init(&LogManager[i].lck_log_2_, NULL);
  }

  #ifdef WAL_ASYNC
  //pthread_t thread;
  //pthread_create(&thread, NULL, logger, NULL);
  #endif
}

int main(int argc, char* argv[]) try {
  chkArg(argc, argv);
  //displayParameter();
  makeDB();
  initLog();
  
  alignas(CACHE_LINE_SIZE) bool start = false;
  alignas(CACHE_LINE_SIZE) bool quit = false;
  alignas(CACHE_LINE_SIZE) std::vector<Result> res(THREAD_NUM);
  std::vector<char> readys(THREAD_NUM);
  std::vector<std::thread> thv;
  for (size_t i = 0; i < THREAD_NUM; ++i)
    thv.emplace_back(worker, i, std::ref(readys[i]), std::ref(start),
                     std::ref(quit), std::ref(res));
  waitForReady(readys);
  storeRelease(start, true);
  for (size_t i = 0; i < EXTIME; ++i) {
    sleepMs(1000);
  }
  storeRelease(quit, true);
  for (auto& th : thv) th.join();

  for (unsigned int i = 0; i < THREAD_NUM; ++i) {
    res[0].addLocalAllResult(res[i]);
  }
  res[0].displayAllResult(CLOCKS_PER_US, EXTIME, THREAD_NUM);

  return 0;
} catch (bad_alloc) {
  ERR;
}
