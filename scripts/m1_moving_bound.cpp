// M1. Does a block close around a moving integration bound?
//
//   g++ -std=c++20 -O2 -w -I odelia/inst/include \
//       -I $(Rscript -e 'cat(system.file("include", package="Rcpp"))') \
//       -I /usr/share/R/include -o /tmp/m1 \
//       scripts/m1_moving_bound.cpp odelia/src/Tape.cpp \
//       -L/usr/lib/R/lib -lR \
//       $(Rscript -e 'cat(system.file("libs/Rcpp.so", package="Rcpp"))')
//   LD_LIBRARY_PATH=/usr/lib/R/lib /tmp/m1
//
// Tape.cpp defines XAD's active_tape_; ode_util.hpp pulls in Rcpp for util::stop,
// which is what the R includes and the two libraries are for.
//
// The crown integral is the structure the cohort block rests on: a cohort reads
// the light field over [0, height] with height an ODE state, so the integration
// bound is a differentiation input. Substituting z = height * xi collapses the
// Yokozawa weight to a function of xi alone --
//
//   q(z, h) dz = 2 eta (1 - xi^eta) xi^(eta-1) dxi,     u = z/h = xi
//
// -- so every route from height into the integral runs through the field query
// position v_j = height * xi_j / height_max, and nothing else. That makes the
// test sharp rather than statistical: if the query is indexed at a passive
// position, d(I)/d(height) is not a fraction of the truth, it is zero.
//
// odelia's hermite_interpolator::eval takes `double u`, which is right for a
// field query at a fixed knot fraction and wrong here. So the probe runs the
// integral three ways -- frozen at the position's value, with the span
// polynomial re-evaluated on the tape, and with the value+slope graft odelia's
// older Interpolator already owns as eval_with_query_derivative -- against a
// central difference of the double computation.
//
// CONFIGURATION. odelia at the branch tip carrying hermite_interpolator, XAD
// vendored at odelia/inst/include/XAD, -O2. 65 knots equally spaced on
// v in [0, 1]; knot values L_k = exp(-A_k) for a monotone A with A(0) = 1.797,
// which is the production maximum from report 00 section 8 item 2; knot slopes
// m_k = -L_k s_k with s_k the summed slope kernel, matching build-plan
// section 2.3's link. height_max = 17.9429 and eta = 12, both production values.
// Gauss-Legendre 15 in xi. Heights 0.3442 (the birth height), 2, 8 and 17.9429.
//
// RESULTS.
//   The bound closes. Both active reads match the central difference to 1.2e-11,
//   9.5e-11, 6.1e-11 and 7.4e-10 at heights 8, 2, 17.9429 and 0.3442, and they
//   agree with each other to every printed digit -- so the graft, which is one
//   line over hermite's existing value_and_slope, is sufficient and the span
//   re-evaluation buys nothing.
//   The frozen read gives d(I)/d(height) = 0.00000000e+00 at 4 of 4. Not a
//   fraction of the truth and not a sign error: the height channel is severed
//   outright, because after the substitution the query position is height's only
//   route into the integral.
//   The knot-value channel is carried by every read. d(I)/dy_0 at the birth
//   height matches the difference to 8 digits (4.77494993e-03 against
//   4.77494988e-03); at taller heights the crown weight xi^(eta-1) at eta = 12
//   makes the ground knot's influence 1e-13 and below, which the difference
//   cannot resolve and reports as 0 -- so read those rows as AD below the
//   reference's floor, not as disagreement.

#include <XAD/XAD.hpp>
#include <odelia/hermite_interpolator.hpp>

#include <cmath>
#include <cstdio>
#include <vector>

namespace {

using ad = xad::adj<double>;
using AD = ad::active_type;

constexpr int    n_knots   = 65;
constexpr double height_max = 17.9429;
constexpr double eta       = 12.0;

// Gauss-Legendre 15 on [-1, 1].
const double gl_x[15] = {
  -0.9879925180204854, -0.9372733924007060, -0.8482065834104272,
  -0.7244177313601701, -0.5709721726085388, -0.3941513470775634,
  -0.2011940939974345,  0.0,                 0.2011940939974345,
   0.3941513470775634,  0.5709721726085388,  0.7244177313601701,
   0.8482065834104272,  0.9372733924007060,  0.9879925180204854};
const double gl_w[15] = {
  0.0307532419961173, 0.0703660474881081, 0.1071592204671719,
  0.1395706779261543, 0.1662692058169939, 0.1861610000155622,
  0.1984314853271116, 0.2025782419255613, 0.1984314853271116,
  0.1861610000155622, 0.1662692058169939, 0.1395706779261543,
  0.1071592204671719, 0.0703660474881081, 0.0307532419961173};

// The knot positions, and the field's data as a function of its own inputs.
std::vector<double> knot_positions() {
  std::vector<double> x(n_knots);
  for (int k = 0; k < n_knots; ++k) x[k] = double(k) / (n_knots - 1);
  return x;
}

// Cumulative leaf area above v, and its slope. Shape only: monotone decreasing
// in v, A(0) = 1.797, A(1) = 0.
double area_above(double v) { return 1.797 * (1.0 - v) * (1.0 - v); }
double area_above_slope(double v) { return -2.0 * 1.797 * (1.0 - v); }

// The integrand's weight: 2 eta (1 - xi^eta) xi^(eta-1), which carries no height.
double kernel(double xi) {
  const double xe = std::pow(xi, eta);
  return 2.0 * eta * (1.0 - xe) * xe / xi;
}

// One span's cubic, evaluated at an ACTIVE position. This is what
// hermite_interpolator::eval would have to become to serve a moving bound: the
// span is chosen at the position's value, and the polynomial is evaluated in the
// working scalar so the position is on the tape.
template <typename S>
S eval_active(const std::vector<double>& x, const std::vector<S>& y,
              const std::vector<S>& m, const S& v) {
  const double vv = xad::value(v);
  const std::size_t ns = x.size() - 1;
  if (vv <= x.front()) return y.front() + m.front() * (v - x.front());
  if (vv >= x.back())  return y.back()  + m.back()  * (v - x.back());
  std::size_t k = std::size_t((vv - x.front()) * (ns));
  if (k >= ns) k = ns - 1;
  const double h = x[k + 1] - x[k];
  const S a = y[k], b = y[k + 1];
  const S sa = m[k] * h, sb = m[k + 1] * h;
  const S c1 = sa;
  const S c2 = 3.0 * (b - a) - 2.0 * sa - sb;
  const S c3 = 2.0 * (a - b) + sa + sb;
  const S t = (v - x[k]) / h;
  return a + t * (c1 + t * (c2 + t * c3));
}

// How the field is read at the quadrature abscissa.
//   frozen  odelia's hermite_interpolator::eval, indexed at a double
//   span    the span polynomial re-evaluated with the position on the tape
//   graft   value + slope * (v - value_of_v), which is what odelia's older
//           Interpolator::eval_with_query_derivative already does, and what
//           hermite's value_and_slope makes a one-line addition
enum class Read { frozen, span, graft };

template <typename S>
S crown_integral(const std::vector<double>& x, const std::vector<S>& y,
                 const std::vector<S>& m, const S& height, Read read) {
  odelia::interpolator::hermite_interpolator<S> field;
  field.init(x, y, m);
  S total = 0.0;
  for (int j = 0; j < 15; ++j) {
    const double xi = 0.5 * (gl_x[j] + 1.0);
    const double w  = 0.5 * gl_w[j];
    const S v = height * xi / height_max;
    const double vv = xad::value(v);
    S L;
    switch (read) {
      case Read::frozen: L = field.eval(vv); break;
      case Read::span:   L = eval_active(x, y, m, v); break;
      case Read::graft: {
        S value, slope;
        field.value_and_slope(vv, value, slope);
        L = value + slope * (v - vv);
        break;
      }
    }
    total += w * L * kernel(xi);
  }
  return total;
}

struct Result { double value, d_height, d_y0, d_y32; };

Result differentiate(double height, Read read) {
  const std::vector<double> x = knot_positions();
  ad::tape_type tape;

  std::vector<AD> y(n_knots), m(n_knots);
  AD h = height;
  for (int k = 0; k < n_knots; ++k) {
    y[k] = std::exp(-area_above(x[k]));
    m[k] = -xad::value(y[k]) * area_above_slope(x[k]);
  }
  tape.registerInput(h);
  for (int k = 0; k < n_knots; ++k) { tape.registerInput(y[k]); tape.registerInput(m[k]); }
  tape.newRecording();

  AD I = crown_integral(x, y, m, h, read);
  tape.registerOutput(I);
  xad::derivative(I) = 1.0;
  tape.computeAdjoints();

  return {xad::value(I), xad::derivative(h), xad::derivative(y[0]),
          xad::derivative(y[32])};
}

// The same integral in double, for the reference difference.
double value_at(double height, int bump_knot = -1, double delta = 0.0) {
  const std::vector<double> x = knot_positions();
  std::vector<double> y(n_knots), m(n_knots);
  for (int k = 0; k < n_knots; ++k) {
    y[k] = std::exp(-area_above(x[k]));
    m[k] = -y[k] * area_above_slope(x[k]);
  }
  if (bump_knot >= 0) y[bump_knot] += delta;
  return crown_integral(x, y, m, height, Read::span);
}

}  // namespace

int main() {
  std::printf("M1  crown integral over [0, height], 65 knots, eta = 12, "
              "height_max = %.4f\n", height_max);
  std::printf("    d/d(height): AD against a central difference of the same "
              "integral\n\n");
  std::printf("%9s %14s %15s %15s %15s %15s\n", "height", "I", "FD",
              "AD span", "AD graft", "AD frozen");

  const double heights[4] = {0.3442, 2.0, 8.0, 17.9429};
  for (double hh : heights) {
    const double step = 1e-6 * hh;
    const double fd = (value_at(hh + step) - value_at(hh - step)) / (2 * step);
    const Result a = differentiate(hh, Read::span);
    const Result g = differentiate(hh, Read::graft);
    const Result p = differentiate(hh, Read::frozen);
    std::printf("%9.4f %14.9f %15.8e %15.8e %15.8e %15.8e\n", hh, a.value, fd,
                a.d_height, g.d_height, p.d_height);
    std::printf("%9s %14s %15s %15.2e %15.2e %15s   <- rel err vs FD\n", "", "", "",
                std::abs(a.d_height - fd) / std::abs(fd),
                std::abs(g.d_height - fd) / std::abs(fd), "severed");
  }

  std::printf("\n    the knot-data channel, which neither variant should lose\n");
  std::printf("%9s %15s %15s %15s %15s\n", "height", "FD d/dy_0",
              "AD d/dy_0", "FD d/dy_32", "AD d/dy_32");
  for (double hh : heights) {
    const double d = 1e-7;
    const double f0 = (value_at(hh, 0, d) - value_at(hh, 0, -d)) / (2 * d);
    const double f32 = (value_at(hh, 32, d) - value_at(hh, 32, -d)) / (2 * d);
    const Result a = differentiate(hh, Read::span);
    std::printf("%9.4f %15.8e %15.8e %15.8e %15.8e\n", hh, f0, a.d_y0, f32,
                a.d_y32);
  }
  return 0;
}
