// M2. CanopyShape<S>: the scalar's placement, bit-identity, and the forward cost.
//
//   scripts/m2_canopy_shape.sh          (extracts both headers, builds, runs)
//
// The plan takes CanopyShape<S> from the AD branch as one file (build-plan
// section 3). It is the smallest test of section 2.1's decision -- the scalar
// lives with the type that owns the parameter -- because CanopyShape owns eta,
// and eta is read in three places on the gradient path: the crown quadrature
// weight q, the crown-shape constant eta_c, and the field's shading kernel Q.
//
//   B1  bit-identity at S = double, against develop's own CanopyShape, over the
//       eta-specialised multiply chains and the general pow fallback.
//   B2  the eta channel at an active S. The branch templates the profile methods
//       on the POSITION scalar Z separately from S, so a caller can reach them
//       with a double position while eta is active -- which is exactly what the
//       field build does, since P2.1 makes the knot positions run-constant
//       doubles. Q(double) declares its return type as the position scalar, so
//       the question is whether the eta derivative survives that, fails to
//       compile, or is silently truncated.
//   B3  forward cost at S = double, against develop: the switch on a stored kind
//       replaces a function-pointer call, and the profile is on two hot paths.
//
// CONFIGURATION. develop 141dc8df's canopy_shape.h against plant
// claude/odelia-ad-tape-reverse-496fuf's, both extracted to separate include
// roots so one translation unit holds both. odelia at the branch tip, XAD
// vendored. -O2. eta over {1, 2, 4, 8, 10, 12} (every specialised chain) plus
// 7.5 and 12.000001 (the general pow), heights 0.3442, 2, 8, 17.9429, and 64
// positions per height.
//
// RESULTS.
//   B1  bit-identical. 0 differences over 2 048 (height, position) pairs for
//       each of q, Q, leaf_area_above and Qp, at all eight etas -- so replacing
//       the function-pointer dispatch with a switch on a stored kind costs no
//       digits, on the specialised chains and on the general pow alike. Not
//       covered: the branch's separable-field methods, which develop has no
//       counterpart for.
//   B2  the eta channel is live and right. d(Q)/d(eta) matches the central
//       difference at 6 of 8 states to 7-9 digits. The two exceptions are the
//       reference's floor, not the adjoint's: at (eta 12, u 0.1) u^eta is 1e-12
//       so FD reports exactly 0 against AD's 4.60517019e-12, and at (7.5, 0.1)
//       1.45628263e-07 against 1.45661261e-07, 2e-4 relative.
//   B2b the double-position call does NOT compile: XAD's pow expression will not
//       convert to the declared double return type. So a caller cannot silently
//       drop the eta derivative -- but it also means every gradient-path caller
//       must reach the profile with an S-valued position, including the field
//       build, whose knot positions are run-constant doubles under P2.1. That is
//       the same conclusion M1 reaches from the other side: on the gradient path
//       the position carries S, passive-valued or not.
//   B3  no forward cost, and at production eta it is cheaper: 59.8 ms against
//       develop's 88.3 ms for 12.8 M q+Q evaluations at eta = 12 (ratio 0.677),
//       and 564.1 against 587.6 at eta = 7.5 (0.960). Read as an upper bound on
//       the risk rather than as the model's number -- the object is a local
//       constant here, so the compiler sees more than it does in plant, and
//       P1.2's whole-run benchmark is still the gate. The general pow costs ~7x
//       the eta = 12 chain, which is a reason to keep production on a
//       specialised value rather than a reason about templating.

#include <chrono>   // before XAD: chrono_io does not parse after its operators
#include <XAD/XAD.hpp>

#include <array>
#include <cmath>
#include <cstdio>
#include <stdexcept>
#include <string>
#include <type_traits>
#include <vector>
#include <odelia/ode_util.hpp>

#include <plant/canopy_shape.h>       // develop's
#include <plant_ad/canopy_shape.h>    // the branch's, in namespace ad_branch

namespace {

using ad = xad::adj<double>;
using AD = ad::active_type;

using Dev = plant::CanopyShape;
template <class S> using Br = ad_branch::plant::CanopyShape<S>;

const double etas[8] = {1.0, 2.0, 4.0, 8.0, 10.0, 12.0, 7.5, 12.000001};
const double heights[4] = {0.3442, 2.0, 8.0, 17.9429};
constexpr int n_pos = 64;

// B1: every profile method both classes expose, at S = double.
void bit_identity() {
  std::printf("B1  bit-identity at S = double, %d (eta, height, position) triples "
              "per method\n", 8 * 4 * n_pos);
  std::printf("%12s %10s %10s %10s %10s\n", "eta", "q", "Q", "leaf_above", "Qp");
  for (double eta : etas) {
    Dev d(eta); Br<double> b(eta);
    long nq = 0, nQ = 0, nl = 0, np = 0;
    for (double h : heights) {
      for (int i = 1; i <= n_pos; ++i) {
        const double z = h * double(i) / n_pos;
        const double u = z / h;
        if (d.q(u, z) != b.q(u, z)) ++nq;
        if (d.Q(u) != b.Q(u)) ++nQ;
        if (d.leaf_area_above(u) != b.leaf_area_above(u)) ++nl;
        const double x = double(i) / (n_pos + 1);
        if (d.Qp(x, h) != b.Qp(x, h)) ++np;
      }
    }
    std::printf("%12.6f %10ld %10ld %10ld %10ld\n", eta, nq, nQ, nl, np);
  }
  std::printf("    counts are DIFFERENCES; zero everywhere is the pass\n\n");
}

// B2: d(Q)/d(eta) with the position active, and with the position a double.
void eta_channel() {
  std::printf("B2  d(Q)/d(eta) at u = z/height, reverse mode against a central "
              "difference\n");
  std::printf("%8s %8s %16s %16s %16s\n", "eta", "u", "FD", "AD active pos",
              "AD double pos");
  const double us[4] = {0.1, 0.5, 0.9, 0.99};
  for (double eta : {12.0, 7.5}) {
    for (double u : us) {
      const double step = 1e-6;
      auto value = [&](double e) { Br<double> b(e); return b.Q(u); };
      const double fd = (value(eta + step) - value(eta - step)) / (2 * step);

      double d_active = 0.0;
      {
        ad::tape_type tape;
        AD e = eta; tape.registerInput(e); tape.newRecording();
        Br<AD> b(e);
        AD uu = u;                       // the position on the tape too
        AD out = b.Q(uu);
        tape.registerOutput(out);
        xad::derivative(out) = 1.0; tape.computeAdjoints();
        d_active = xad::derivative(e);
      }
#ifdef M2_DOUBLE_POSITION
      // A double position, as the field build has under P2.1: the knot positions
      // are run-constant doubles while eta is active. Q's return type is the
      // position scalar, so this is where the eta derivative would be lost. The
      // .sh compiles this branch on its own and reports whether it builds.
      {
        ad::tape_type tape;
        AD e = eta; tape.registerInput(e); tape.newRecording();
        Br<AD> b(e);
        AD out = AD(b.template Q<double>(u));
        tape.registerOutput(out);
        xad::derivative(out) = 1.0; tape.computeAdjoints();
        std::printf("%8.3f %8.2f %16.8e %16.8e %16.8e\n", eta, u, fd, d_active,
                    xad::derivative(e));
      }
#else
      std::printf("%8.3f %8.2f %16.8e %16.8e %16s\n", eta, u, fd, d_active,
                  "see the .sh");
#endif
    }
  }
  std::printf("    the double-position column is the measurement, and it is a\n"
              "    compile question rather than a number -- see the .sh\n\n");
}

// B3: the profile's forward cost, develop against the templated form at double.
void forward_cost() {
  const int reps = 200000;
  std::printf("B3  forward cost at S = double, %d x %d q+Q evaluations\n", reps,
              n_pos);
  std::printf("%12s %14s %14s %10s\n", "eta", "develop (ms)", "branch (ms)", "ratio");
  for (double eta : {12.0, 7.5}) {
    Dev d(eta); Br<double> b(eta);
    double sink = 0.0;
    auto t0 = std::chrono::steady_clock::now();
    for (int r = 0; r < reps; ++r)
      for (int i = 1; i <= n_pos; ++i) {
        const double u = double(i) / n_pos;
        sink += d.q(u, u * 8.0) + d.Q(u);
      }
    auto t1 = std::chrono::steady_clock::now();
    for (int r = 0; r < reps; ++r)
      for (int i = 1; i <= n_pos; ++i) {
        const double u = double(i) / n_pos;
        sink += b.q(u, u * 8.0) + b.Q(u);
      }
    auto t2 = std::chrono::steady_clock::now();
    const double ms_d = std::chrono::duration<double, std::milli>(t1 - t0).count();
    const double ms_b = std::chrono::duration<double, std::milli>(t2 - t1).count();
    std::printf("%12.6f %14.1f %14.1f %10.3f   (sink %.6g)\n", eta, ms_d, ms_b,
                ms_b / ms_d, sink);
  }
}

}  // namespace

int main() {
  bit_identity();
  eta_channel();
  forward_cost();
  return 0;
}
