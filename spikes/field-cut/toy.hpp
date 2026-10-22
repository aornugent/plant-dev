// A toy stand of m species whose cohorts shade and drink from one shared field,
// and the reverse pass that holds that field fixed.
#pragma once
#include <XAD/XAD.hpp>

#include <algorithm>
#include <array>
#include <chrono>
#include <cmath>
#include <vector>

using AD = xad::AReal<double>;
using Tape = xad::Tape<double>;

enum { GROWTH, SHADE, REPRO, LEAF, LNB, N_INPUT };
inline const char* input_name[N_INPUT] = {"growth", "shade_mortality", "alloc_repro",
                                          "leaf_area", "ln_b"};
constexpr int N_TRAIT = LNB;

struct Setup {
  int species = 1;
  int n = 24;  // cohorts per species
  int steps = 480;
  int intro_every = 12;
  double t_end = 40.0;
  double k = 0.6, eps = 0.25, mu0 = 0.04, h0 = 0.3, cu = 0.05, rw = 0.4, w0 = 1.0;
  double leaf_cost = 0.0;  // photosynthesis falls as exp(-leaf_cost * leaf area trait)

  double dt() const { return t_end / steps; }
  int active_at(int step) const { return std::min(n, step / intro_every + 1); }
  double establishment(int j) const { return std::exp(-0.03 * j * intro_every * dt()); }
  double weight(int j) const { return establishment(j) * intro_every * dt(); }
  int cohorts() const { return species * n; }
  std::size_t width() const { return 3 * cohorts() + 1; }  // (h, m, phi) per cohort, then W
};

template <class T> using Inputs = std::array<T, N_INPUT>;

// What a cohort's rates read and other cohorts make: each source's shading density
// and height, species by species, and the soil water.
template <class F>
struct Field {
  std::vector<F> D, H;
  F W;
};

template <class T, class F>
T light(const Setup& c, const Field<F>& f, const T& z) {
  T tau = 0.0;
  for (std::size_t j = 0; j < f.D.size(); ++j) {
    tau += f.D[j] / (1.0 + exp((z - f.H[j]) / c.eps));
  }
  return exp(-c.k * tau);
}

template <class T, class F>
void cohort_rates(const Setup& c, const Inputs<T>& p, const Field<F>& f,
                  const T* y, T* dy) {
  const T a = p[LEAF] * y[0];
  const T L = light(c, f, y[0]);
  T P = L * a / (1.0 + a);
  if (c.leaf_cost > 0.0) P *= exp(-c.leaf_cost * p[LEAF]);
  dy[0] = p[GROWTH] * (1.0 - p[REPRO]) * P;
  dy[1] = -(c.mu0 + p[SHADE] * (1.0 - L));
  dy[2] = p[REPRO] * P * exp(y[1]) * f.W / (f.W + 0.5);
}

template <class T>
Field<T> build_field(const Setup& c, const std::vector<Inputs<T>>& p,
                     const std::vector<T>& y, int active) {
  Field<T> f;
  f.D.resize(c.species * active);
  f.H.resize(c.species * active);
  for (int s = 0; s < c.species; ++s) {
    const T b = exp(p[s][LNB]);
    for (int j = 0; j < active; ++j) {
      const int at = 3 * (s * c.n + j);
      f.D[s * active + j] = b * c.establishment(j) * exp(y[at + 1]) * p[s][LEAF] * y[at];
      f.H[s * active + j] = y[at];
    }
  }
  f.W = y[3 * c.cohorts()];
  return f;
}

template <class T, class Rates>
void rk4_step(const std::vector<T>& y0, double h, std::vector<T>& y1, Rates&& rates) {
  const std::size_t n = y0.size();
  std::vector<T> k1(n), k2(n), k3(n), k4(n), s(n);
  rates(y0, k1);
  for (std::size_t i = 0; i < n; ++i) s[i] = y0[i] + 0.5 * h * k1[i];
  rates(s, k2);
  for (std::size_t i = 0; i < n; ++i) s[i] = y0[i] + 0.5 * h * k2[i];
  rates(s, k3);
  for (std::size_t i = 0; i < n; ++i) s[i] = y0[i] + h * k3[i];
  rates(s, k4);
  y1.resize(n);
  for (std::size_t i = 0; i < n; ++i) {
    y1[i] = y0[i] + h / 6.0 * (k1[i] + 2.0 * k2[i] + 2.0 * k3[i] + k4[i]);
  }
}

// `cohorts` cohorts at their initial height, then soil water if `water`.
template <class T>
std::vector<T> initial_state(const Setup& c, int cohorts, bool water) {
  std::vector<T> y(3 * cohorts + (water ? 1 : 0), T(0.0));
  for (int j = 0; j < cohorts; ++j) y[3 * j] = c.h0;
  if (water) y[3 * cohorts] = c.w0;
  return y;
}

// ln of offspring per arriving seed of the species whose cohorts start at `first`.
template <class T>
T log_offspring(const Setup& c, const std::vector<T>& y, int first = 0) {
  T J = 0.0;
  for (int j = 0; j < c.n; ++j) J += c.weight(j) * y[3 * (first + j) + 2];
  return log(J);
}

// One resident step. `on_field` sees each field as it is built, before any cohort
// reads it.
template <class T, class OnField>
void resident_step(const Setup& c, const std::vector<Inputs<T>>& p, int step,
                   const std::vector<T>& y0, std::vector<T>& y1, OnField&& on_field) {
  const int active = c.active_at(step);
  const int water = 3 * c.cohorts();
  rk4_step(y0, c.dt(), y1, [&](const std::vector<T>& y, std::vector<T>& dy) {
    const Field<T> f = build_field(c, p, y, active);
    on_field(f);
    for (int s = 0; s < c.species; ++s) {
      for (int i = 0; i < c.n; ++i) {
        const int at = 3 * (s * c.n + i);
        if (i < active) {
          cohort_rates(c, p[s], f, &y[at], &dy[at]);
        } else {
          dy[at] = dy[at + 1] = dy[at + 2] = 0.0;
        }
      }
    }
    T uptake = 0.0;
    for (const T& d : f.D) uptake += d;
    dy[water] = c.rw * (1.0 - y[water]) - c.cu * y[water] * uptake;
  });
}

// F_s = ln J_s - ln b_s for every species, with the state at every step boundary,
// the last included, in `states` if asked.
template <class T, class OnField>
std::vector<T> resident(const Setup& c, const std::vector<Inputs<T>>& p, OnField&& on_field,
                        std::vector<std::vector<double>>* states = nullptr) {
  std::vector<T> y = initial_state<T>(c, c.cohorts(), true), y1;
  auto keep = [&] {
    if (!states) return;
    states->emplace_back();
    for (const T& v : y) states->back().push_back(xad::value(v));
  };
  for (int k = 0; k < c.steps; ++k) {
    keep();
    resident_step(c, p, k, y, y1, on_field);
    std::swap(y, y1);
  }
  keep();
  std::vector<T> F;
  for (int s = 0; s < c.species; ++s) F.push_back(log_offspring(c, y, s * c.n));
  return F;
}

// ln R' of a rare invader standing in the recorded field, one per rate evaluation.
// F is double for the invader plant runs today, and active to read the field's
// adjoints.
template <class T, class F>
T invader(const Setup& c, const Inputs<T>& p, const std::vector<Field<F>>& fields) {
  std::vector<T> y = initial_state<T>(c, c.n, false), y1;
  std::size_t at = 0;
  for (int k = 0; k < c.steps; ++k) {
    const int active = c.active_at(k);
    rk4_step(y, c.dt(), y1, [&](const std::vector<T>& s, std::vector<T>& ds) {
      const Field<F>& f = fields.at(at++);
      for (int i = 0; i < c.n; ++i) {
        if (i < active) {
          cohort_rates(c, p, f, &s[3 * i], &ds[3 * i]);
        } else {
          ds[3 * i] = ds[3 * i + 1] = ds[3 * i + 2] = 0.0;
        }
      }
    });
    std::swap(y, y1);
  }
  return log_offspring(c, y);
}

// Where a field was built on the tape, and the slots it was built into. A field
// value no input reaches has no slot and is listed as INVALID_SLOT.
struct Mark {
  Tape::position_type at;
  std::vector<Tape::slot_type> slots;
};

inline Mark mark_field(const Tape& tape, const Field<AD>& f) {
  Mark m{tape.getPosition(), {}};
  auto add = [&](const AD& x) { m.slots.push_back(x.getSlot()); };
  for (const AD& x : f.D) add(x);
  for (const AD& x : f.H) add(x);
  add(f.W);
  return m;
}

// The reverse pass with every field held fixed: sweep down to each field's mark,
// zero its adjoints before the statements that built it are reached, and truncate
// there. Without the truncation the next computeAdjointsTo rewalks the swept
// statements from the end, and a slot one of them reassigned now holds an adjoint
// for an earlier value, which it would propagate a second time. The recording is
// consumed, so this is the last sweep a recording gets. `held` receives the
// adjoint each field slot had when zeroed: the invader's field sensitivity.
inline void sweep_field_cut(Tape& tape, const std::vector<Mark>& marks, bool truncate,
                            std::vector<double>* held = nullptr) {
  for (auto m = marks.rbegin(); m != marks.rend(); ++m) {
    tape.computeAdjointsTo(m->at);
    for (Tape::slot_type s : m->slots) {
      const bool on_tape = s != AD::INVALID_SLOT;
      if (held) held->push_back(on_tape ? tape.derivative(s) : std::nan(""));
      if (on_tape) tape.derivative(s) = 0.0;
    }
    if (truncate) tape.resetTo(m->at);
  }
  tape.computeAdjoints();
}

using Clock = std::chrono::steady_clock;
inline double seconds_since(Clock::time_point t0) {
  return std::chrono::duration<double>(Clock::now() - t0).count();
}

inline double rel(double a, double b) {
  return std::abs(a - b) / std::max({std::abs(a), std::abs(b), 1e-300});
}
