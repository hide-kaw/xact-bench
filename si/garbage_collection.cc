
#include <algorithm>
#include <iostream>

#include "../include/debug.hh"
#include "../include/result.hh"
#include "../include/util.hh"
#include "include/common.hh"
#include "include/garbage_collection.hh"
#include "include/transaction.hh"
#include "include/version.hh"

using std::cout, std::endl;

// start, for leader thread.
bool GarbageCollection::chkSecondRange() {
  TransactionTable *tmt;

  smin_ = UINT32_MAX;
  smax_ = 0;
  for (unsigned int i = 0; i < THREAD_NUM; ++i) {
    tmt = __atomic_load_n(&TMT[i], __ATOMIC_ACQUIRE);
    uint32_t tmptxid = tmt->txid_.load(std::memory_order_acquire);
    smin_ = std::min(smin_, tmptxid);
    smax_ = std::max(smax_, tmptxid);
  }

  // cout << "fmin_, fmax_ : " << fmin_ << ", " << fmax_ << endl;
  // cout << "smin_, smax_ : " << smin_ << ", " << smax_ << endl;

  if (fmax_ < smin_)
    return true;
  else
    return false;
}

void GarbageCollection::decideFirstRange() {
  TransactionTable *tmt;

  fmin_ = fmax_ = 0;
  for (unsigned int i = 0; i < THREAD_NUM; ++i) {
    tmt = __atomic_load_n(&TMT[i], __ATOMIC_ACQUIRE);
    uint32_t tmptxid = tmt->txid_.load(std::memory_order_acquire);
    fmin_ = std::min(fmin_, tmptxid);
    fmax_ = std::max(fmax_, tmptxid);
  }

  return;
}
// end, for leader thread.

// for worker thread
void GarbageCollection::gcVersion([[maybe_unused]] Result *sres_) {
  uint32_t threshold = getGcThreshold();

  // my customized Rapid garbage collection inspired from Cicada (sigmod 2017).
  while (!gcq_for_versions_.empty()) {
    if (gcq_for_versions_.front().cstamp_ >= threshold) break;

    // (a) acquiring the garbage collection lock succeeds
    uint8_t zero = 0;
    uint8_t one = 1;
    Tuple *tuple = gcq_for_versions_.front().rcdptr_;
    if (!tuple->g_clock_.compare_exchange_strong(
            zero, one, std::memory_order_acq_rel, std::memory_order_acquire)) {
      // fail acquiring the lock
      gcq_for_versions_.pop_front();
      continue;
    }

    // (b) v.cstamp_ > record.min_cstamp_
    // If not satisfy this condition, (cstamp_ <= min_cstamp_)
    // the version was cleaned by other threads
    if (gcq_for_versions_.front().cstamp_ <= tuple->min_cstamp_) {
      // releases the lock
      tuple->g_clock_.store(0, std::memory_order_release);
      gcq_for_versions_.pop_front();
      continue;
    }
    // this pointer may be dangling.

    Version *delTarget = gcq_for_versions_.front().ver_->committed_prev_;
    if (delTarget == nullptr) {
      tuple->g_clock_.store(0, std::memory_order_release);
      gcq_for_versions_.pop_front();
      continue;
    }
    delTarget = delTarget->prev_;
    if (delTarget == nullptr) {
      tuple->g_clock_.store(0, std::memory_order_release);
      gcq_for_versions_.pop_front();
      continue;
    }

    // the thread detaches the rest of the version list from v
    gcq_for_versions_.front().ver_->committed_prev_->prev_ = nullptr;
    // updates record.min_wts
    tuple->min_cstamp_.store(
        gcq_for_versions_.front().ver_->committed_prev_->cstamp_,
        std::memory_order_release);

    while (delTarget != nullptr) {
      // next pointer escape
      Version *tmp = delTarget->prev_;
      reuse_version_from_gc_.emplace_back(delTarget);
      delTarget = tmp;
#if ADD_ANALYSIS
      ++sres_->local_gc_version_counts_;
#endif
    }

    // releases the lock
    tuple->g_clock_.store(0, std::memory_order_release);
    gcq_for_versions_.pop_front();
  }

  return;
}

#ifdef CCTR_ON
void GarbageCollection::gcTMTElements([[maybe_unused]] Result *sres_) {
  uint32_t threshold = getGcThreshold();

  for (;;) {
    TransactionTable *tmt = gcq_for_TMT_.front();
    if (tmt == nullptr) {
      return;
    }
    if (tmt->txid_ < threshold) {
      gcq_for_TMT_.pop_front();
      reuse_TMT_element_from_gc_.emplace_back(tmt);
#if ADD_ANALYSIS
      ++sres_->local_gc_TMT_elements_counts_;
#endif
    } else
      break;
  }

  return;
}
#endif  // CCTR_ON
