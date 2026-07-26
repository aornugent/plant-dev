// [[Rcpp::plugins(cpp20)]]
// Attribute the FF16 crown integral's recorded tape between the light-field read
// and the rest of the integrand, and price boundary A against it -- on tape size
// AND on every gradient channel the integrand carries. Op counts do not depend on
// the numeric values, so the field here is plausible rather than a real stand.
#include <Rcpp.h>
#include <plant/models/ff16_strategy.h>
#include <plant/models/ff16_environment.h>
#include <plant/canopy_shape.h>
#include <odelia/preaccumulate.hpp>
#include <odelia/ode_util.hpp>
#include <vector>
#include <array>

using namespace plant;
using S = xad::adj<double>::active_type;
using tape_type = xad::adj<double>::tape_type;

namespace {

constexpr std::size_t NNODE = 21;

// A fixed 21-node rule: positions affine in the bound, weights constant doubles.
// Only the shape of the recorded work matters here, not the rule's accuracy.
struct rule {
  std::array<double, NNODE> x, w;
  rule() {
    for (std::size_t j = 0; j < NNODE; ++j) {
      x[j] = -1.0 + 2.0 * (static_cast<double>(j) + 0.5) / NNODE;
      w[j] = 2.0 / NNODE;
    }
  }
};

struct counts {
  std::size_t ops, stmts, bytes;
};
counts read_counts(tape_type& t) {
  return {t.getNumOperations(), t.getNumStatements(), t.getMemory()};
}

// Every active input the crown integrand can reach, registered before the
// recording starts so each channel's adjoint is readable.
struct inputs {
  std::vector<S> sources;  // the stand's per-cohort source weights
  S h, eta, a_p1, a_p2;
  std::vector<double> heights;

  void register_all(tape_type& tape, std::size_t n_src, double h_top,
                    double height) {
    sources.resize(n_src);
    heights.resize(n_src);
    for (std::size_t j = 0; j < n_src; ++j) {
      heights[j] = h_top * (1.0 - static_cast<double>(j) / n_src);  // descending
      sources[j] = S(1e-3);
      tape.registerInput(sources[j]);
    }
    h = S(height);
    eta = S(12.0);
    a_p1 = S(151.177775377968);
    a_p2 = S(0.204716322142829);
    tape.registerInput(h);
    tape.registerInput(eta);
    tape.registerInput(a_p1);
    tape.registerInput(a_p2);
    tape.newRecording();
  }

  // The competition field the cohorts read, assembled as Patch does.
  FF16_Environment_<S> environment(const CanopyShape<S>& canopy) const {
    FF16_Environment_<S> env;
    std::array<std::vector<S>, 3> sw;
    for (std::size_t j = 0; j < sources.size(); ++j) {
      const auto b = canopy.template shading_source_factors<S>(S(heights[j]));
      for (std::size_t p = 0; p < 3; ++p) sw[p].push_back(sources[j] * b[p]);
    }
    env.assemble_competition_field(sw, heights, canopy);
    return env;
  }
};

Rcpp::List report(const char* name, counts a, counts b, const S& A,
                  const inputs& in) {
  return Rcpp::List::create(
      Rcpp::Named("variant") = std::string(name),
      Rcpp::Named("ops") = static_cast<double>(b.ops - a.ops),
      Rcpp::Named("stmts") = static_cast<double>(b.stmts - a.stmts),
      Rcpp::Named("bytes") = static_cast<double>(b.bytes - a.bytes),
      Rcpp::Named("value") = xad::value(A),
      Rcpp::Named("d_h") = xad::derivative(in.h),
      Rcpp::Named("d_eta") = xad::derivative(in.eta),
      Rcpp::Named("d_a_p1") = xad::derivative(in.a_p1),
      Rcpp::Named("d_a_p2") = xad::derivative(in.a_p2),
      Rcpp::Named("d_src0") = xad::derivative(in.sources.front()),
      Rcpp::Named("d_src_mid") =
          xad::derivative(in.sources[in.sources.size() / 2]));
}

}  // namespace

// [[Rcpp::export]]
Rcpp::List crown_probe(double height = 10.0, int n_src = 400,
                       double h_top = 20.0) {
  const rule R;
  const std::size_t ns = static_cast<std::size_t>(n_src);
  Rcpp::List out;

  // ---- V_full: the crown integral as FF16 records it today -----------------
  {
    tape_type tape;
    inputs in;
    in.register_all(tape, ns, h_top, height);
    CanopyShape<S> shape(in.eta);
    auto env = in.environment(shape);
    const counts before = read_counts(tape);
    const double top = env.max_environment_height();
    const S hinv = 1.0 / in.h;
    const S centre = 0.5 * in.h, half = 0.5 * in.h;
    S A(0.0);
    for (std::size_t j = 0; j < NNODE; ++j) {
      const S z = centre + half * R.x[j];
      const S L = env.get_environment_at_height(z, S(top));
      A += R.w[j] * ((in.a_p1 * L / (L + in.a_p2)) *
                     shape.template q<S>(z * hinv, z));
    }
    A *= half;
    const counts after = read_counts(tape);
    tape.registerOutput(A);
    xad::derivative(A) = 1.0;
    tape.computeAdjoints();
    out.push_back(report("full", before, after, A, in));
  }

  // ---- V_field: the field reads alone (what boundary A leaves behind) ------
  {
    tape_type tape;
    inputs in;
    in.register_all(tape, ns, h_top, height);
    CanopyShape<S> shape(in.eta);
    auto env = in.environment(shape);
    const counts before = read_counts(tape);
    const double top = env.max_environment_height();
    const S centre = 0.5 * in.h, half = 0.5 * in.h;
    S A(0.0);
    for (std::size_t j = 0; j < NNODE; ++j) {
      const S z = centre + half * R.x[j];
      A += R.w[j] * env.get_environment_at_height(z, S(top));
    }
    A *= half;
    const counts after = read_counts(tape);
    tape.registerOutput(A);
    xad::derivative(A) = 1.0;
    tape.computeAdjoints();
    out.push_back(report("field_only", before, after, A, in));
  }

  // ---- V_A: boundary A -- lights on the run tape, the rest preaccumulated --
  {
    tape_type tape;
    inputs in;
    in.register_all(tape, ns, h_top, height);
    CanopyShape<S> shape(in.eta);
    auto env = in.environment(shape);
    const counts before = read_counts(tape);
    const double top = env.max_environment_height();
    const S centre = 0.5 * in.h, half = 0.5 * in.h;
    std::vector<S> x;
    x.reserve(NNODE + 4);
    for (std::size_t j = 0; j < NNODE; ++j) {
      const S z = centre + half * R.x[j];
      x.push_back(env.get_environment_at_height(z, S(top)));
    }
    x.push_back(in.h);
    x.push_back(in.eta);
    x.push_back(in.a_p1);
    x.push_back(in.a_p2);
    S A = odelia::preaccumulate<S>(x, [&R](const std::vector<S>& v) -> S {
      const S hh = v[NNODE], a_p1 = v[NNODE + 2], a_p2 = v[NNODE + 3];
      CanopyShape<S> shape_in(v[NNODE + 1]);
      const S hinv = 1.0 / hh;
      const S centre = 0.5 * hh, half = 0.5 * hh;
      S acc(0.0);
      for (std::size_t j = 0; j < NNODE; ++j) {
        const S z = centre + half * R.x[j];
        const S L = v[j];
        acc += R.w[j] * ((a_p1 * L / (L + a_p2)) *
                         shape_in.template q<S>(z * hinv, z));
      }
      return acc * half;
    });
    const counts after = read_counts(tape);
    tape.registerOutput(A);
    xad::derivative(A) = 1.0;
    tape.computeAdjoints();
    out.push_back(report("boundary_A", before, after, A, in));
  }

  // ---- V_D: the whole crown, field read included, as one declared block -----
  // The field read is a frozen-structure linear functional of the cumulative
  // source weights the query's rank selects, so those cumulatives ARE the
  // block's declared inputs: 3 per node, plus the bound and the traits.
  {
    tape_type tape;
    inputs in;
    in.register_all(tape, ns, h_top, height);
    CanopyShape<S> shape(in.eta);
    auto env = in.environment(shape);
    const counts before = read_counts(tape);
    const S centre = 0.5 * in.h, half = 0.5 * in.h;

    // The same cumulative sums the field holds, recomputed here so the probe can
    // declare them without reaching into odelia's private state.
    std::array<std::vector<S>, 3> cum;
    {
      for (std::size_t p = 0; p < 3; ++p) {
        cum[p].resize(ns);
        S run(0.0);
        for (std::size_t j = 0; j < ns; ++j) {
          const auto b = shape.template shading_source_factors<S>(S(in.heights[j]));
          run += in.sources[j] * b[p];
          cum[p][j] = run;
        }
      }
    }
    const counts after_cum = read_counts(tape);

    std::vector<S> x;
    std::array<std::size_t, NNODE> rank;
    for (std::size_t j = 0; j < NNODE; ++j) {
      const double z = xad::value(centre) + xad::value(half) * R.x[j];
      const std::size_t k = env.n_sources_at_least(z);
      rank[j] = (k == 0) ? 0 : k - 1;
      for (std::size_t p = 0; p < 3; ++p) x.push_back(cum[p][rank[j]]);
    }
    x.push_back(in.h);
    x.push_back(in.eta);
    x.push_back(in.a_p1);
    x.push_back(in.a_p2);
    const std::size_t nc = 3 * NNODE;
    S A = odelia::preaccumulate<S>(x, [&R, nc](const std::vector<S>& v) -> S {
      const S hh = v[nc], a_p1 = v[nc + 2], a_p2 = v[nc + 3];
      CanopyShape<S> shape_in(v[nc + 1]);
      const S hinv = 1.0 / hh;
      const S centre = 0.5 * hh, half = 0.5 * hh;
      S acc(0.0);
      for (std::size_t j = 0; j < NNODE; ++j) {
        const S z = centre + half * R.x[j];
        // The field read, reconstructed from the declared cumulatives.
        const auto a = shape_in.template shading_query_factors<S>(z);
        S opt(0.0);
        for (std::size_t p = 0; p < 3; ++p) opt += a[p] * v[3 * j + p];
        const S L = exp(-opt);
        acc += R.w[j] * ((a_p1 * L / (L + a_p2)) *
                         shape_in.template q<S>(z * hinv, z));
      }
      return acc * half;
    });
    const counts after = read_counts(tape);
    tape.registerOutput(A);
    xad::derivative(A) = 1.0;
    tape.computeAdjoints();
    Rcpp::List d = report("boundary_D", before, after, A, in);
    d["cum_bytes"] = static_cast<double>(after_cum.bytes - before.bytes);
    out.push_back(d);
  }

  return out;
}
