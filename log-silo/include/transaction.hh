#pragma once

#include <iostream>
#include <set>
#include <vector>

#include "../../include/fileio.hh"
#include "../../include/procedure.hh"
#include "../../include/result.hh"
#include "../../include/string.hh"
#include "common.hh"
#include "log.hh"
#include "silo_op_element.hh"
#include "tuple.hh"

#define LOGSET_SIZE (128 * 1024)
using namespace std;

enum class TransactionStatus : uint8_t {
  kInFlight,
  kCommitted,
  kAborted,
};

class LOG_MANAGER {
 public:
  // Logging objects
  vector<LogRecord> log_set_1_;
	vector<LogRecord> log_set_2_;
  LogHeader latest_log_header_1_;
	LogHeader latest_log_header_2_;
	pthread_mutex_t lck_log_1_;
	pthread_mutex_t lck_log_2_;
	unsigned int cur_log_;
  File logfile_;
};

class TxnExecutor {
 public:
  vector<ReadElement<Tuple>> read_set_;
  vector<WriteElement<Tuple>> write_set_;
  vector<Procedure> pro_set_;

#ifdef WAL_SYNC  
  vector<LogRecord> log_set_;
  LogHeader latest_log_header_;
  File logfile_;
#endif
  
  TransactionStatus status_;
  unsigned int thid_;
  unsigned int lock_num_;

  /* lock_num_ ...
   * the number of locks in local write set.
   */
  Result* sres_;

  Tidword mrctid_;
  Tidword max_rset_, max_wset_;

  char write_val_[VAL_SIZE];
  char return_val_[VAL_SIZE];

  TxnExecutor(int thid, Result* sres) : thid_(thid), sres_(sres) {
    read_set_.reserve(MAX_OPE);
    write_set_.reserve(MAX_OPE);
    pro_set_.reserve(MAX_OPE);
    // log_set_.reserve(LOGSET_SIZE);
    // latest_log_header_.init();

    lock_num_ = 0;
    max_rset_.obj_ = 0;
    max_wset_.obj_ = 0;

    genStringRepeatedNumber(write_val_, VAL_SIZE, thid);
  }

  void displayWriteSet();
  void begin();
  void read(uint64_t key);
  void write(uint64_t key);
  bool validationPhase();
  void abort();
  void writePhase();
  void wal(uint64_t ctid);
  void lockWriteSet();
  void unlockWriteSet();
  ReadElement<Tuple>* searchReadSet(uint64_t key);
  WriteElement<Tuple>* searchWriteSet(uint64_t key);

  Tuple* get_tuple(Tuple* table, uint64_t key) { return &table[key]; }
};
