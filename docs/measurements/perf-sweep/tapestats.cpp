// LD_PRELOAD shim over the XAD tape odelia.so compiles, which plant.so reaches
// through the dynamic linker. Per recording it writes the tape's size at the
// sweep (statements, operations, bytes), the wall time spent recording, in the
// outer reverse sweep, in clearAll, between recordings, and in the local
// sweeps implicit_value and preaccumulate run inside the recording.
//   SP_ODELIA_SO=<odelia.so> SP_TAPESTATS=<out.tsv> LD_PRELOAD=tapestats.so R ...
#include <dlfcn.h>
#include <time.h>
#include <cstddef>
#include <cstdio>
#include <cstdlib>

namespace {

void* odelia() {
  static void* h = nullptr;
  if (h == nullptr) {
    const char* p = std::getenv("SP_ODELIA_SO");
    if (p == nullptr) {
      std::fprintf(stderr, "tapestats: SP_ODELIA_SO unset\n");
      std::abort();
    }
    h = dlopen(p, RTLD_NOW | RTLD_NOLOAD);
    if (h == nullptr) h = dlopen(p, RTLD_NOW | RTLD_GLOBAL);
    if (h == nullptr) {
      std::fprintf(stderr, "tapestats: cannot open %s: %s\n", p, dlerror());
      std::abort();
    }
  }
  return h;
}

template <class F>
F real(const char* sym) {
  void* f = dlsym(odelia(), sym);
  if (f == nullptr) {
    std::fprintf(stderr, "tapestats: no symbol %s\n", sym);
    std::abort();
  }
  return reinterpret_cast<F>(f);
}

double wall() {
  timespec t;
  clock_gettime(CLOCK_MONOTONIC, &t);
  return t.tv_sec + 1e-9 * t.tv_nsec;
}
double cpu() {
  timespec t;
  clock_gettime(CLOCK_PROCESS_CPUTIME_ID, &t);
  return t.tv_sec + 1e-9 * t.tv_nsec;
}

using fn_void = void (*)(void*);
using fn_uint = void (*)(void*, unsigned);
using fn_cuint = unsigned (*)(const void*);
using fn_csize = std::size_t (*)(const void*);
using fn_ctor = void (*)(void*, bool);

const char* S_NEWREC = "_ZN3xad4TapeIdLm1EE12newRecordingEv";
const char* S_ADJ = "_ZN3xad4TapeIdLm1EE15computeAdjointsEv";
const char* S_ADJTO = "_ZN3xad4TapeIdLm1EE17computeAdjointsToEj";
const char* S_CLEAR = "_ZN3xad4TapeIdLm1EE8clearAllEv";
const char* S_CTOR = "_ZN3xad4TapeIdLm1EEC1Eb";
const char* S_DTOR = "_ZN3xad4TapeIdLm1EED1Ev";
const char* S_NVAR = "_ZNK3xad4TapeIdLm1EE15getNumVariablesEv";
const char* S_NOPS = "_ZNK3xad4TapeIdLm1EE16getNumOperationsEv";
const char* S_NSTM = "_ZNK3xad4TapeIdLm1EE16getNumStatementsEv";
const char* S_MEM = "_ZNK3xad4TapeIdLm1EE9getMemoryEv";

FILE* out() {
  static FILE* f = nullptr;
  if (f == nullptr) {
    const char* p = std::getenv("SP_TAPESTATS");
    f = std::fopen(p != nullptr ? p : "/dev/null", "a");
    std::fprintf(f, "kind\ttape\tseq\tinputs\tstatements\toperations\tbytes\tseeds\t"
                    "rec_s\tsweep_s\tclear_s\tgap_s\tlocal_n\tlocal_stmts\tlocal_s\n");
  }
  return f;
}

// One recording's accumulators, reset at clearAll.
struct recording {
  long seq = 0;
  unsigned inputs = 0;
  unsigned statements = 0, operations = 0;
  std::size_t bytes = 0;
  int seeds = 0;
  double t_rec0 = 0, rec_s = 0, sweep_s = 0, clear_s = 0, gap_s = 0;
  long local_n = 0;
  double local_stmts = 0, local_s = 0;
  bool open = false;
};

recording cur;
long tape_id = 0;
long seq = 0;
bool outer = false;
double t_last = 0;
double tape_wall0 = 0, tape_cpu0 = 0;

void flush(void* tape) {
  if (!cur.open) return;
  std::fprintf(out(), "rec\t%ld\t%ld\t%u\t%u\t%u\t%zu\t%d\t%.9f\t%.9f\t%.9f\t%.9f\t%ld\t%.0f\t%.9f\n",
               tape_id, cur.seq, cur.inputs, cur.statements, cur.operations, cur.bytes,
               cur.seeds, cur.rec_s, cur.sweep_s, cur.clear_s, cur.gap_s, cur.local_n,
               cur.local_stmts, cur.local_s);
  cur.open = false;
  (void)tape;
}

}  // namespace

namespace xad {
template <class T, std::size_t N> class Tape;
}

extern "C" {

// xad::Tape<double,1>::Tape(bool)
void _ZN3xad4TapeIdLm1EEC1Eb(void* self, bool activate) {
  static fn_ctor f = real<fn_ctor>(S_CTOR);
  f(self, activate);
  ++tape_id;
  tape_wall0 = wall();
  tape_cpu0 = cpu();
  t_last = tape_wall0;
}

// xad::Tape<double,1>::~Tape()
void _ZN3xad4TapeIdLm1EED1Ev(void* self) {
  static fn_void f = real<fn_void>(S_DTOR);
  flush(self);
  std::fprintf(out(), "tape\t%ld\t%ld\t0\t0\t0\t0\t0\t%.9f\t%.9f\t0\t0\t0\t0\t0\n",
               tape_id, seq, wall() - tape_wall0, cpu() - tape_cpu0);
  std::fflush(out());
  f(self);
}

// xad::Tape<double,1>::clearAll()
void _ZN3xad4TapeIdLm1EE8clearAllEv(void* self) {
  static fn_void f = real<fn_void>(S_CLEAR);
  const double t0 = wall();
  flush(self);
  cur = recording();
  cur.open = true;
  cur.seq = ++seq;
  cur.gap_s = t0 - t_last;
  f(self);
  cur.clear_s = wall() - t0;
}

// xad::Tape<double,1>::newRecording()
void _ZN3xad4TapeIdLm1EE12newRecordingEv(void* self) {
  static fn_void f = real<fn_void>(S_NEWREC);
  static fn_cuint nvar = real<fn_cuint>(S_NVAR);
  f(self);
  cur.inputs = nvar(self);
  cur.t_rec0 = wall();
}

// xad::Tape<double,1>::computeAdjoints()
void _ZN3xad4TapeIdLm1EE15computeAdjointsEv(void* self) {
  static fn_void f = real<fn_void>(S_ADJ);
  static fn_cuint nstm = real<fn_cuint>(S_NSTM);
  static fn_cuint nops = real<fn_cuint>(S_NOPS);
  static fn_csize mem = real<fn_csize>(S_MEM);
  const double t0 = wall();
  if (cur.seeds == 0) {
    cur.rec_s = t0 - cur.t_rec0;
    cur.statements = nstm(self);
    cur.operations = nops(self);
    cur.bytes = mem(self);
  }
  ++cur.seeds;
  outer = true;
  f(self);
  outer = false;
  const double t1 = wall();
  cur.sweep_s += t1 - t0;
  t_last = t1;
}

// xad::Tape<double,1>::computeAdjointsTo(unsigned)
void _ZN3xad4TapeIdLm1EE17computeAdjointsToEj(void* self, unsigned pos) {
  static fn_uint f = real<fn_uint>(S_ADJTO);
  static fn_cuint nstm = real<fn_cuint>(S_NSTM);
  if (outer) {
    f(self, pos);
    return;
  }
  const double t0 = wall();
  const unsigned n = nstm(self);
  f(self, pos);
  cur.local_s += wall() - t0;
  ++cur.local_n;
  cur.local_stmts += static_cast<double>(n) - static_cast<double>(pos);
}

}  // extern "C"
