// [[Rcpp::plugins(cpp20)]]
// [[Rcpp::depends(plant, odelia, phylloptim, BH)]]
#include <Rcpp.h>
#include <sstream>
#include <map>
#include <set>
#include <array>
#include <memory>
#include <functional>
#include <span>
#include <optional>
#include <variant>
#include <numeric>
#include <algorithm>
#include <set>
#define private public
#include <boost/math/tools/roots.hpp>
#include <XAD/XAD.hpp>
#include <plant.h>
#undef private
#include <chrono>

using A = xad::AReal<double>;
using Tape = xad::Tape<double>;
using PatchD = plant::Patch<plant::FF16_Strategy<double>, plant::FF16_Environment<double>>;

struct mark {
  std::size_t st, op;
};
static mark at(const Tape& t) { return {t.getNumStatements(), t.getNumOperations()}; }

// Statements in [a, b): pure copies (one operand, multiplier 1), constants (no
// operand), and the rest.
static std::vector<double> classify(const Tape& t, mark a, mark b) {
  double copies = 0, constants = 0, other = 0;
  for (std::size_t i = a.st; i < b.st; ++i) {
    const std::size_t end = t.statement_[i].first;
    const std::size_t begin = i == 0 ? 0 : t.statement_[i - 1].first;
    const std::size_t n = end - begin;
    if (n == 0) ++constants;
    else if (n == 1 && t.operations_[begin].first == 1.0) ++copies;
    else ++other;
  }
  return {copies, constants, other};
}

// One rate evaluation of a real patch state on the tape, split into the field
// build and the rates; and the number of crown integrals the rates took.
// [[Rcpp::export]]
Rcpp::List probe_regions(SEXP patch_sexp, int reps) {
  PatchD patch = Rcpp::as<PatchD>(patch_sexp);
  std::vector<double> y(patch.ode_size());
  patch.ode_state(y.begin());
  const double time = patch.ode_time();

  Tape tape;
  auto active = patch.template rebind_from<A>();
  for (A* p : active.ad_parameters()) tape.registerInput(*p);
  std::vector<A> ya(y.begin(), y.end());
  tape.registerInputs(ya);
  tape.newRecording();

  const mark m0 = at(tape);
  active.set_ode_state(ya.begin(), time);
  const mark m1 = at(tape);
  active.compute_boundary_nodes();
  const mark m2 = at(tape);
  std::vector<A> dydt(y.size());
  active.ode_rates(dydt.begin());
  const mark m3 = at(tape);

  {
    std::vector<A> moved(ya.size());
    for (std::size_t i = 0; i < ya.size(); ++i) moved[i] = ya[i] * 1.0;
    const mark q0 = at(tape);
    active.set_ode_state(std::make_move_iterator(moved.begin()), time);
    const mark q1 = at(tape);
    active.compute_environment();
    const mark q2 = at(tape);
    const auto c = classify(tape, q0, q1);
    const auto cf = classify(tape, q1, q2);
    {
      auto& nd = active.species[0].nodes[3];
      std::vector<A> v(nd.ode_size());
      for (std::size_t i = 0; i < v.size(); ++i) v[i] = ya[i] * 1.0;
      const mark z0 = at(tape);
      nd.set_ode_state(std::make_move_iterator(v.begin()));
      const mark z1 = at(tape);
      const auto cz = classify(tape, z0, z1);
      Rcpp::Rcout << "one node by move: " << (z1.st - z0.st) << " stmts, copies " << cz[0]
                  << " of " << v.size() << " values\n";
    }
    Rcpp::Rcout << "load by move (incl. field): " << (q1.st - q0.st) << " stmts, copies " << c[0]
                << "; field alone " << (q2.st - q1.st) << " copies " << cf[0] << "\n";
  }
  // The same pieces once more, each on its own: the field alone (state already
  // loaded), the rates alone, and the write-out of the rates.
  const mark e0 = at(tape);
  active.compute_environment();
  const mark e1 = at(tape);
  active.compute_rates();
  const mark e2 = at(tape);
  std::vector<A> dydt2(y.size());
  active.ode_rates(dydt2.begin());
  const mark e3 = at(tape);
  Rcpp::Rcout << "field alone   " << (e1.st - e0.st) << " stmts; copies/const/other " << classify(tape, e0, e1)[0] << "/" << classify(tape, e0, e1)[1] << "/" << classify(tape, e0, e1)[2] << "\n";
  Rcpp::Rcout << "load state    " << ((m1.st - m0.st) - (e1.st - e0.st)) << " stmts (set_ode_state minus the field)\n";
  Rcpp::Rcout << "compute_rates " << (e2.st - e1.st) << " stmts; copies/const/other " << classify(tape, e1, e2)[0] << "/" << classify(tape, e1, e2)[1] << "/" << classify(tape, e1, e2)[2] << "\n";
  Rcpp::Rcout << "ode_rates     " << (e3.st - e2.st) << " stmts; copies/const/other " << classify(tape, e2, e3)[0] << "/" << classify(tape, e2, e3)[1] << "/" << classify(tape, e2, e3)[2] << "\n";
  {
    auto& sp = active.species[0];
    auto& node = sp.nodes[sp.nodes.size() / 2];
    auto& ind = node.individual;
    auto& strat = *ind.strategy;
    const auto& env = active.environment;
    auto show = [&](const char* what, mark a, mark b) {
      const auto c = classify(tape, a, b);
      Rcpp::Rcout << "  " << what << ": " << (b.st - a.st) << " stmts, " << (b.op - a.op)
                  << " ops; copies/const/other " << c[0] << "/" << c[1] << "/" << c[2] << "\n";
    };
    mark n0 = at(tape);
    node.compute_rates(env, 1.0);
    mark n1 = at(tape);
    ind.compute_rates(env);
    mark n2 = at(tape);
    const A h = ind.vars.state(plant::HEIGHT_INDEX);
    mark n3 = at(tape);
    A asw, msw;
    A npp = strat.net_mass_production_dt(env, h, ind.vars.aux(strat.COMPETITION_EFFECT_AUX_INDEX),
                                         ind.vars.aux(strat.HEIGHT_INVERSE_AUX_INDEX), asw, msw);
    mark n4 = at(tape);
    A asim = strat.assimilation(env, h, ind.vars.aux(strat.COMPETITION_EFFECT_AUX_INDEX),
                                ind.vars.aux(strat.HEIGHT_INVERSE_AUX_INDEX));
    mark n5 = at(tape);
    // The field's pieces: the competition reduction at the knots, and the
    // spline built from knot values the reduction would hand it.
    {
      const A hmax = active.height_max();
      const std::vector<double>& fr = active.environment.light_availability.knot_fractions_;
      std::vector<A> x(fr.size());
      for (size_t k = 0; k < fr.size(); ++k) x[k] = fr[k] * hmax;
      std::vector<typename std::decay_t<decltype(sp)>::competition_split> out;
      mark f0 = at(tape);
      sp.field_splits(x, out);
      mark f1 = at(tape);
      show("field_splits (65 knots)", f0, f1);
      {
        const A& z = x[40];
        std::array<A, 3> w, ws;
        mark g0 = at(tape);
        strat.canopy_shape.height_weights(z, w);
        mark g1 = at(tape);
        strat.canopy_shape.height_weight_slopes(z, ws);
        mark g2 = at(tape);
        auto fsn = sp.nodes[5].compute_competition_and_slope(z);
        mark g3 = at(tape);
        strat.canopy_shape.crown_moments(A(1.0) / sp.nodes[5].height(), w);
        mark g4 = at(tape);
        show("  height_weights", g0, g1);
        show("  height_weight_slopes", g1, g2);
        show("  Node::compute_competition_and_slope", g2, g3);
        show("  crown_moments (+1/H)", g3, g4);
      }
      mark f2 = at(tape);
      std::vector<A> yy(fr.size()), mm(fr.size());
      for (size_t k = 0; k < fr.size(); ++k) { yy[k] = out[k].sum.value * 1.0; mm[k] = out[k].sum.slope * 1.0; }
      mark f3 = at(tape);
      active.environment.light_availability.spline.set_data(yy, mm);
      mark f4 = at(tape);
      show("(probe's own y/m fill)", f2, f3);
      show("spline.set_data", f3, f4);
      std::vector<typename std::decay_t<decltype(sp)>::competition_split> closed;
      mark f5 = at(tape);
      for (size_t k = 0; k < fr.size(); ++k) {
        auto fs = sp.close_competition_and_slope(out[k], x[k]);
        (void)fs;
      }
      mark f6 = at(tape);
      show("close_competition_and_slope x65", f5, f6);
    }
    // Preaccumulating one crown: inputs found from the block's own operands.
    {
      const A& al = ind.vars.aux(strat.COMPETITION_EFFECT_AUX_INDEX);
      const A& hi = ind.vars.aux(strat.HEIGHT_INVERSE_AUX_INDEX);
      using clk = std::chrono::steady_clock;
      const int R = 2000;
      // Inline: record, then sweep the block alone.
      double t_rec_inline = 0, t_sweep_inline = 0;
      std::vector<std::pair<unsigned, double>> rows_inline;
      const auto p0 = tape.getPosition();
      for (int r = 0; r < R; ++r) {
        auto a = clk::now();
        A out = strat.assimilation(env, h, al, hi);
        auto b = clk::now();
        xad::derivative(out) = 1.0;
        tape.computeAdjointsTo(p0);
        auto c = clk::now();
        t_rec_inline += std::chrono::duration<double>(b - a).count();
        t_sweep_inline += std::chrono::duration<double>(c - b).count();
        if (r == 0) {
          // rows: adjoints on slots that predate the block
          const std::size_t op0 = tape.statement_[p0].first;
          std::set<unsigned> defined, seen;
          for (std::size_t i = p0 + 1; i < tape.statement_.size(); ++i) {
            const std::size_t b0 = tape.statement_[i - 1].first, e0 = tape.statement_[i].first;
            for (std::size_t o = b0; o < e0; ++o) {
              const unsigned sl = tape.operations_[o].second;
              if (!defined.count(sl) && seen.insert(sl).second)
                rows_inline.push_back({sl, tape.derivative(sl)});
            }
            defined.insert(tape.statement_[i].second);
          }
          (void)op0;
        }
        for (auto& rw : rows_inline) tape.derivative(rw.first) = 0.0;
        tape.resetTo(p0);
        tape.clearDerivativesAfter(p0);
      }
      // Preaccumulated: record, find inputs, sweep locally, rewind, push one.
      double t_pre = 0, t_sweep_pre = 0;
      std::vector<unsigned> in;
      std::vector<double> rows;
      std::size_t n_rows = 0;
      double worst = 0;
      for (int r = 0; r < R; ++r) {
        auto a = clk::now();
        A out;
        {
          const unsigned first_slot = tape.currentRec_->iDerivative_;
          A blk = strat.assimilation(env, h, al, hi);
          xad::derivative(blk) = 1.0;
          tape.computeAdjointsTo(p0);
          // Every operand issued before the block is an input; reading its
          // adjoint zeroes it, so a repeated operand yields no second row.
          in.clear(); rows.clear();
          const std::size_t ob = tape.statement_[p0].first, oe = tape.operations_.size();
          for (std::size_t o = ob; o < oe; ++o) {
            const unsigned sl = tape.operations_[o].second;
            if (sl < first_slot) {
              double& d = tape.derivative(sl);
              if (d != 0.0) { in.push_back(sl); rows.push_back(d); d = 0.0; }
            }
          }
          const double v = xad::value(blk);
          tape.resetTo(p0);
          tape.clearDerivativesAfter(p0);
          out = v;
          tape.pushAll(rows.data(), in.data(), unsigned(in.size()));
          n_rows = in.size();
          if (r == 0) {
            for (std::size_t i = 0; i < in.size(); ++i)
              for (auto& rw : rows_inline)
                if (rw.first == in[i]) worst = std::max(worst, std::abs(rw.second - rows[i]) / std::max(1e-300, std::abs(rw.second)));
          }
          tape.registerOutput(out);
          n_rows = in.size();
          if (r == 0) {
            for (std::size_t i = 0; i < in.size(); ++i)
              for (auto& rw : rows_inline)
                if (rw.first == in[i]) worst = std::max(worst, std::abs(rw.second - rows[i]) / std::max(1e-300, std::abs(rw.second)));
          }
        }
        auto b = clk::now();
        xad::derivative(out) = 1.0;
        tape.computeAdjointsTo(p0);
        auto c = clk::now();
        t_pre += std::chrono::duration<double>(b - a).count();
        t_sweep_pre += std::chrono::duration<double>(c - b).count();
        for (unsigned sl : in) tape.derivative(sl) = 0.0;
        tape.resetTo(p0);
        tape.clearDerivativesAfter(p0);
      }
      Rcpp::Rcout << "crown inline:         record " << 1e9 * t_rec_inline / R << " ns, sweep " << 1e9 * t_sweep_inline / R << " ns\n";
      Rcpp::Rcout << "crown preaccumulated: record " << 1e9 * t_pre / R << " ns, sweep " << 1e9 * t_sweep_pre / R << " ns, rows " << n_rows << ", worst row rel diff " << worst << "\n";
    }
    {
      mark h0 = at(tape);
      node.compute_rates(env, 1.0);
      mark h1 = at(tape);
      std::map<std::size_t, int> hist;
      for (std::size_t i = h0.st; i < h1.st; ++i) {
        const std::size_t n = tape.statement_[i].first - (i == 0 ? 0 : tape.statement_[i - 1].first);
        ++hist[n];
      }
      Rcpp::Rcout << "node statements by operand count:";
      for (auto& kv : hist) Rcpp::Rcout << " " << kv.first << ":" << kv.second;
      Rcpp::Rcout << "\n";
    }
    Rcpp::Rcout << "one node:\n";
    show("Node::compute_rates", n0, n1);
    show("Individual::compute_rates", n1, n2);
    show("net_mass_production_dt", n3, n4);
    show("assimilation (crown)", n4, n5);
  }
  {
    double zero = 0, total = 0;
    for (std::size_t o = tape.statement_[0].first; o < tape.operations_.size(); ++o) {
      ++total;
      if (tape.operations_[o].first == 0.0) ++zero;
    }
    Rcpp::Rcout << "operations with an exactly-zero multiplier: " << zero << " of " << total << "\n";
  }
  const std::vector<double> c_field = classify(tape, m0, m1);
  const std::vector<double> c_rates = classify(tape, m2, m3);
  // Wall clock of the same three pieces, re-recorded from one position.
  const auto pos = tape.getPosition();
  double t_env = 0, t_rates = 0, t_sweep = 0;
  for (int r = 0; r < reps; ++r) {
    tape.resetTo(pos);
    auto a = std::chrono::steady_clock::now();
    active.set_ode_state(ya.begin(), time);
    active.compute_boundary_nodes();
    auto b = std::chrono::steady_clock::now();
    active.ode_rates(dydt.begin());
    auto c = std::chrono::steady_clock::now();
    t_env += std::chrono::duration<double>(b - a).count();
    t_rates += std::chrono::duration<double>(c - b).count();
  }
  // One sweep of the whole evaluation, seeded on every rate.
  {
    tape.clearDerivatives();
    for (auto& d : dydt) xad::derivative(d) = 1.0;
    auto a = std::chrono::steady_clock::now();
    tape.computeAdjoints();
    t_sweep = std::chrono::duration<double>(std::chrono::steady_clock::now() - a).count();
  }
  // The same evaluation at double.
  double t_double = 0;
  for (int r = 0; r < reps; ++r) {
    auto a = std::chrono::steady_clock::now();
    patch.set_ode_state(y.begin(), time);
    patch.compute_boundary_nodes();
    std::vector<double> d(y.size());
    patch.ode_rates(d.begin());
    t_double += std::chrono::duration<double>(std::chrono::steady_clock::now() - a).count();
  }
  std::size_t nodes = 0;
  for (size_t i = 0; i < patch.size(); ++i) nodes += patch.at_species(i).size();
  return Rcpp::List::create(
      Rcpp::_["nodes"] = (double)nodes, Rcpp::_["ode_size"] = (double)y.size(),
      Rcpp::_["field_copy_const_other"] = c_field, Rcpp::_["rates_copy_const_other"] = c_rates,
      Rcpp::_["field_statements"] = (double)(m1.st - m0.st),
      Rcpp::_["field_operations"] = (double)(m1.op - m0.op),
      Rcpp::_["boundary_statements"] = (double)(m2.st - m1.st),
      Rcpp::_["rates_statements"] = (double)(m3.st - m2.st),
      Rcpp::_["rates_operations"] = (double)(m3.op - m2.op),
      Rcpp::_["us_field"] = 1e6 * t_env / reps, Rcpp::_["us_rates"] = 1e6 * t_rates / reps,
      Rcpp::_["us_sweep_once"] = 1e6 * t_sweep, Rcpp::_["us_double"] = 1e6 * t_double / reps);
}
