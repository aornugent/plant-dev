#include "../vec/tape_local.inc"
#include <cstdio>
#include <vector>
using A = xad::AReal<double>;
__attribute__((noinline)) A record(std::vector<A>& x, const A& a, const A& b, const A& h) {
  A acc = 0.0;
  for (std::size_t i = 0; i < x.size(); ++i) {
    const A E = x[i] * h + a;
    acc += 0.37 * (a * E / (E + b));
  }
  return acc;
}
__attribute__((noinline)) A passive_run(std::vector<A>& x, const A& a, const A& b, const A& h) {
  return record(x, a, b, h);
}
int main(int argc, char**) {
  A a = 1.3, b = 0.2, h = 0.9;
  std::vector<A> x(200000);
  for (std::size_t i = 0; i < x.size(); ++i) x[i] = 0.001 * double(i);
  if (argc > 1) {  // no tape at all: the same AReal arithmetic, passive
    A y = passive_run(x, a, b, h);
    std::printf("passive %g\n", xad::value(y));
    return 0;
  }
  xad::Tape<double> tape;
  tape.registerInput(a); tape.registerInput(b); tape.registerInput(h);
  tape.registerInputs(x);
  tape.newRecording();
  A y = record(x, a, b, h);
  std::printf("taped %g statements %zu\n", xad::value(y), tape.getNumStatements());
}
