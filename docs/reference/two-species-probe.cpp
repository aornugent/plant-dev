/* Every number in v3-facts.md was measured with EXACTLY ONE species. What breaks with two?
 *
 * (A) THE SEPARABLE FIELD CARRIES ONE eta, AND TWO SPECIES MAY NOT SHARE IT.
 *     The rank-3 factorisation is exact by algebra: query factors {1, -2 z^eta, z^2eta}
 *     dotted with source factors {1, H^-eta, H^-2eta} is (1 - (z/H)^eta)^2 -- but ONLY
 *     when the same eta appears in both (canopy_shape.h:198-211). The field is assembled
 *     with a SINGLE canopy, taken from species 0:
 *
 *         // Query factors come from any cohort's canopy (shared shape); use species 0's.
 *         CanopyShape<value_type> canopy = species[0].node_begin()->individual...
 *         environment.assemble_competition_field(sw_sorted, heights_d, canopy);
 *                                                                  -- patch.h:757-759
 *
 *     "shared shape" is an ASSUMPTION, not a fact: `eta` is a per-strategy trait carried
 *     as S, and a differentiation target. With two species of different eta, every source
 *     from species 1 is read through species 0's query factors. This probe measures the
 *     resulting shading error directly against the exact kernel. It needs no SCM run,
 *     which is what makes it decisive -- a two-species FF16 SCM is fragile (see the .R:
 *     eta=2, and eta=4 at birth_rate 20, both trip plant's non-finite-density guard).
 *
 * (B) TIE-BREAK DETERMINISM ACROSS A REBUILD. The sources are merged in descending
 *     height with ties broken on the flat concatenated index (patch.h:741-748). That
 *     index is a function of species order and per-species node counts -- both restored
 *     by r_set_state -- so replay SHOULD add the same terms in the same order. Measured
 *     on K93, which has two species without the eta problem above.
 *
 * (C) AN EMPTY FIRST SPECIES IS UNDEFINED BEHAVIOUR. The per-species loop skips empty
 *     species (`m == 0`) and the function early-returns only when the TOTAL source count
 *     is zero. So species 0 empty + species 1 non-empty reaches line 758 and calls
 *     `node_begin()->individual` on an empty vector. This probe COUNTS whether that state
 *     occurs on an ordinary run; it never dereferences it.
 *
 * Everything here is double. Run from /home/user/plant-dev via
 * docs/reference/two-species-probe.R.
 */

// [[Rcpp::depends(Rcpp, odelia, plant)]]
// [[Rcpp::plugins(cpp20)]]

#include <Rcpp.h>
#include <plant.h>
#include <plant/canopy_shape.h>
#include <plant/models/k93_strategy.h>
#include <plant/scm.h>
#include <odelia/ode_solver.hpp>

#include <cmath>
#include <vector>

using namespace Rcpp;

// (A) With one shared query-factor set, how wrong is a source of a different eta?
// Compares the exact kernel Q(z,H) = (1-(z/H)^eta_src)^2 against the rank-3 value the
// field actually computes: species 0's query factors dotted with the source's factors.
// [[Rcpp::export]]
Rcpp::List canopy_mixed_eta_probe(double eta_query = 12.0, double eta_source = 10.0,
                                  double height = 10.0) {
  plant::CanopyShape<double> cq(eta_query), cs(eta_source);
  std::vector<double> zs, exact, rank3, err;
  for (double frac = 0.1; frac <= 0.95; frac += 0.1) {
    const double z = frac * height;
    const auto a = cq.shading_query_factors<double>(z);      // species 0's canopy
    const auto b = cs.shading_source_factors<double>(height); // the other species'
    double q = 0.0;
    for (int p = 0; p < 3; ++p) q += a[p] * b[p];
    const double u = std::pow(z / height, eta_source);
    const double ex = (1.0 - u) * (1.0 - u);
    zs.push_back(z);
    exact.push_back(ex);
    rank3.push_back(q);
    err.push_back(std::fabs(q - ex));
  }
  double worst = 0.0;
  for (double e : err) worst = std::max(worst, e);
  return Rcpp::List::create(
      Rcpp::Named("z") = zs, Rcpp::Named("exact") = exact,
      Rcpp::Named("rank3") = rank3, Rcpp::Named("abs_err") = err,
      Rcpp::Named("worst_abs") = worst);
}

// (B) two-species replay, and (C) empty-first-species reachability. K93: robust, and its
// two species differ in a growth trait rather than in eta.
// [[Rcpp::export]]
Rcpp::List two_species_replay_probe(double scale_b = 1.15, double birth_rate = 10.0,
                                    double lifetime = 20.0, int probe_every = 10) {
  using Strat = plant::K93_Strategy;
  using Env = Strat::environment_type;
  using Patch = plant::Patch<Strat, Env>;

  plant::Control ctrl;
  Env env;
  plant::Parameters<Strat, Env> p;
  for (int i = 0; i < 2; ++i) {
    Strat s;
    s.is_variable_birth_rate = false;
    s.birth_rate_y = {birth_rate};
    if (i == 1) s.pars.b_0 *= scale_b;   // a genuinely different species, same canopy
    p.strategies.push_back(s);
  }
  p.max_patch_lifetime = lifetime;
  p.validate();

  plant::SCM<Strat, Env> sched(p, env, ctrl);
  sched.refine_schedule();
  const std::vector<double> schedule = sched.recorded_steps();

  plant::SCM<Strat, Env> fwd(p, env, ctrl);
  fwd.set_schedule(schedule);

  std::vector<std::vector<double>> entering, leaving, light_state;
  std::vector<std::vector<std::size_t>> counts, added;
  std::vector<Patch> entering_patch;
  std::vector<double> t_in, t_out;
  int empty_first_species = 0;   // (C)

  while (!fwd.complete()) {
    const Patch& pk = fwd.r_patch();
    std::vector<double> y(pk.ode_size());
    pk.ode_state(y.begin());
    entering.push_back(y);
    entering_patch.push_back(pk);
    std::vector<std::size_t> c;
    for (std::size_t i = 0; i < pk.size(); ++i) c.push_back(pk.at_species(i).size());
    if (c.size() > 1 && c[0] == 0) {
      bool other = false;
      for (std::size_t i = 1; i < c.size(); ++i) other = other || c[i] > 0;
      if (other) empty_first_species++;
    }
    counts.push_back(c);
    const Rcpp::NumericMatrix m = pk.r_environment().light_availability.r_get_state();
    light_state.push_back(std::vector<double>(m.begin(), m.end()));
    t_in.push_back(fwd.time());

    added.push_back(fwd.run_next());

    const Patch& pk2 = fwd.r_patch();
    std::vector<double> y2(pk2.ode_size());
    pk2.ode_state(y2.begin());
    leaving.push_back(y2);
    t_out.push_back(fwd.time());
  }

  std::vector<int> probed, width_a, width_b;
  std::vector<double> rebuilt_abs, copy_abs;

  for (std::size_t k = 0; k < entering.size();
       k += static_cast<std::size_t>(probe_every)) {
    std::vector<double> times;
    for (double t : schedule)
      if (t >= t_in[k] - 1e-12 && t <= t_out[k] + 1e-12) times.push_back(t);
    if (times.size() < 2) continue;
    times.front() = t_in[k];
    times.back() = t_out[k];

    std::vector<double> light = light_state[k];
    if (light.size() < 6) light = {0.0, 0.5, 1.0, 1.0, 1.0, 1.0};

    auto advance = [&](Patch u) {
      u.introduce_new_nodes(added[k]);
      odelia::ode::Solver<Patch> s(u, plant::make_ode_control(ctrl));
      s.set_collect(false);
      s.set_state_from_system();
      s.advance_fixed(times);
      const Patch& d = s.get_system_ref();
      std::vector<double> y(d.ode_size());
      d.ode_state(y.begin());
      double ma = NA_REAL;
      if (y.size() == leaving[k].size()) {
        ma = 0.0;
        for (std::size_t i = 0; i < y.size(); ++i)
          ma = std::max(ma, std::fabs(y[i] - leaving[k][i]));
      }
      return ma;
    };

    Patch unit(p, env, ctrl);
    unit.r_set_state(t_in[k], entering[k], counts[k], light);
    rebuilt_abs.push_back(advance(unit));
    copy_abs.push_back(advance(entering_patch[k]));
    probed.push_back(static_cast<int>(k));
    width_a.push_back(static_cast<int>(counts[k][0]));
    width_b.push_back(static_cast<int>(counts[k][1]));
  }

  return Rcpp::List::create(
      Rcpp::Named("probed") = probed,
      Rcpp::Named("segments") = static_cast<int>(entering.size()),
      Rcpp::Named("ode_steps") = static_cast<int>(schedule.size() - 1),
      Rcpp::Named("width_sp0") = width_a,
      Rcpp::Named("width_sp1") = width_b,
      Rcpp::Named("rebuilt_abs") = rebuilt_abs,
      Rcpp::Named("copy_abs") = copy_abs,
      Rcpp::Named("empty_first_species_segments") = empty_first_species);
}
