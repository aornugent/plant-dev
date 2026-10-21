#include "../vec/tape_local.inc"
#include <cstdio>
#include <vector>
using A = xad::AReal<double>;
// Two statements an iteration, the crown's shape: a read and an accumulate.
__attribute__((noinline)) A record(std::vector<A>& x, const A& a, const A& b, const A& h) {
  A acc = 0.0;
  for (std::size_t i = 0; i < x.size(); ++i) {
    const A E = x[i] * h + a;                // stands in for the light read
    acc += 0.37 * (a * E / (E + b));         // the accumulate
  }
  return acc;
}
int main() {
  xad::Tape<double> tape;
  A a = 1.3, b = 0.2, h = 0.9;
  std::vector<A> x(200000);
  for (std::size_t i = 0; i < x.size(); ++i) x[i] = 0.001 * double(i);
  tape.registerInput(a); tape.registerInput(b); tape.registerInput(h);
  tape.registerInputs(x);
  tape.newRecording();
  A y = record(x, a, b, h);
  tape.registerOutput(y);
  xad::derivative(y) = 1.0;
  tape.computeAdjoints();
  std::printf("statements %zu operations %zu da %g\n", tape.getNumStatements(), tape.getNumOperations(), xad::derivative(a));
}
