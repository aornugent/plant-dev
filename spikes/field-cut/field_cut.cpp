// A toy stand whose cohorts shade and drink from one shared field, recorded once
// and swept twice: with the field responding (F_theta) and with every edge into
// the field cut (the selection gradient g), checked against an invader that reads
// the recorded field as doubles.
#include "toy.hpp"

#include <cstdio>

#ifndef FD_H
#define FD_H 1e-7
#endif

int main() {
  const Setup c;
  const Inputs<double> x0 = {1.2, 0.8, 0.3, 1.5, std::log(2.0)};
  const std::vector<Inputs<double>> stand0 = {x0};
  const int repeats = 5;
  auto no_field = [](const auto&) {};

  // Resident in doubles, keeping the field at every rate evaluation.
  std::vector<Field<double>> fields;
  std::vector<std::vector<double>> states;
  double t_resident_double = 1e300;
  double F_double = 0.0;
  for (int r = 0; r < repeats; ++r) {
    fields.clear();
    states.clear();
    const auto t0 = Clock::now();
    F_double = resident(c, stand0, [&](const Field<double>& f) { fields.push_back(f); },
                        &states)[0];
    t_resident_double = std::min(t_resident_double, seconds_since(t0));
  }

  // One recording of the whole resident; pass 1 keeps the field, pass 2 cuts it.
  std::array<double, N_INPUT> F_theta{}, g_cut{}, g_naive{};
  std::vector<double> field_adjoint_cut;
  double F_ad = 0.0, t_record = 1e300, t_pass1 = 1e300, t_pass2 = 1e300;
  std::size_t statements = 0, n_marks = 0;
  for (int r = 0; r < repeats + 1; ++r) {
    const bool naive = r == repeats;  // pass 2 without truncation, for contrast
    Tape tape;
    std::vector<Inputs<AD>> stand(1);
    Inputs<AD>& p = stand[0];
    for (int i = 0; i < N_INPUT; ++i) p[i] = x0[i];
    for (AD& v : p) tape.registerInput(v);
    tape.newRecording();
    std::vector<Mark> marks;
    auto t0 = Clock::now();
    AD F = resident(c, stand, [&](const Field<AD>& f) {
      marks.push_back(mark_field(tape, f));
    })[0];
    tape.registerOutput(F);
    if (!naive) t_record = std::min(t_record, seconds_since(t0));
    statements = tape.getNumStatements();
    n_marks = marks.size();
    F_ad = xad::value(F);

    t0 = Clock::now();
    tape.clearDerivatives();
    xad::derivative(F) = 1.0;
    tape.computeAdjoints();
    if (!naive) t_pass1 = std::min(t_pass1, seconds_since(t0));
    for (int i = 0; i < N_INPUT; ++i) F_theta[i] = xad::derivative(p[i]);

    t0 = Clock::now();
    tape.clearDerivatives();
    xad::derivative(F) = 1.0;
    std::vector<double> held;
    sweep_field_cut(tape, marks, !naive, naive ? nullptr : &held);
    if (!naive) t_pass2 = std::min(t_pass2, seconds_since(t0));
    auto& into = naive ? g_naive : g_cut;
    for (int i = 0; i < N_INPUT; ++i) into[i] = xad::derivative(p[i]);
    if (!naive) field_adjoint_cut = std::move(held);
  }

  // The invader route: record the invader standing in the stored field, sweep it.
  std::array<double, N_TRAIT> g_inv{};
  double lnR_inv = 0.0, t_inv_record = 1e300, t_inv_sweep = 1e300;
  for (int r = 0; r < repeats; ++r) {
    Tape tape;
    Inputs<AD> p;
    for (int i = 0; i < N_INPUT; ++i) p[i] = x0[i];
    for (int i = 0; i < N_TRAIT; ++i) tape.registerInput(p[i]);
    tape.newRecording();
    auto t0 = Clock::now();
    AD lnR = invader(c, p, fields);
    tape.registerOutput(lnR);
    t_inv_record = std::min(t_inv_record, seconds_since(t0));
    t0 = Clock::now();
    xad::derivative(lnR) = 1.0;
    tape.computeAdjoints();
    t_inv_sweep = std::min(t_inv_sweep, seconds_since(t0));
    for (int i = 0; i < N_TRAIT; ++i) g_inv[i] = xad::derivative(p[i]);
    lnR_inv = xad::value(lnR);
  }

  // The same invader with its field active, for the field's own adjoints. The
  // marks were swept last to first, so they are reversed here to match.
  std::vector<double> field_adjoint_inv;
  {
    Tape tape;
    Inputs<AD> p;
    for (int i = 0; i < N_INPUT; ++i) p[i] = x0[i];
    std::vector<Field<AD>> active_fields(fields.size());
    for (std::size_t s = 0; s < fields.size(); ++s) {
      Field<AD>& a = active_fields[s];
      a.D.assign(fields[s].D.begin(), fields[s].D.end());
      a.H.assign(fields[s].H.begin(), fields[s].H.end());
      a.W = fields[s].W;
      for (AD& v : a.D) tape.registerInput(v);
      for (AD& v : a.H) tape.registerInput(v);
      tape.registerInput(a.W);
    }
    tape.newRecording();
    AD lnR = invader(c, p, active_fields);
    tape.registerOutput(lnR);
    xad::derivative(lnR) = 1.0;
    tape.computeAdjoints();
    for (auto f = active_fields.rbegin(); f != active_fields.rend(); ++f) {
      for (const AD& v : f->D) field_adjoint_inv.push_back(xad::derivative(v));
      for (const AD& v : f->H) field_adjoint_inv.push_back(xad::derivative(v));
      field_adjoint_inv.push_back(xad::derivative(f->W));
    }
  }

  // Step by step, as odelia sweeps: one recording per step from the stored state,
  // two adjoints carried down, the field-cut sweep last on each recording.
  std::array<double, N_INPUT> F_step{}, g_step{};
  std::array<double, 3> t_step = {1e300, 1e300, 1e300};  // record, pass 1, pass 2
  for (int r = 0; r < repeats; ++r) {
    std::array<double, 3> spent{};
    std::vector<double> lam_keep(c.width(), 0.0), lam_cut;
    double J = 0.0;
    for (int j = 0; j < c.n; ++j) J += c.weight(j) * states.back()[3 * j + 2];
    for (int j = 0; j < c.n; ++j) lam_keep[3 * j + 2] = c.weight(j) / J;
    lam_cut = lam_keep;
    F_step.fill(0.0);
    g_step.fill(0.0);
    Tape tape;
    for (int k = c.steps - 1; k >= 0; --k) {
      auto t0 = Clock::now();
      tape.clearAll();
      std::vector<AD> y(states[k].begin(), states[k].end()), y1;
      std::vector<Inputs<AD>> stand(1);
      Inputs<AD>& p = stand[0];
      for (int i = 0; i < N_INPUT; ++i) p[i] = x0[i];
      tape.registerInputs(y);
      for (AD& v : p) tape.registerInput(v);
      tape.newRecording();
      std::vector<Mark> marks;
      resident_step(c, stand, k, y, y1,
                    [&](const Field<AD>& f) { marks.push_back(mark_field(tape, f)); });
      tape.registerOutputs(y1);
      spent[0] += seconds_since(t0);

      t0 = Clock::now();
      tape.clearDerivatives();
      for (std::size_t i = 0; i < y1.size(); ++i) xad::derivative(y1[i]) = lam_keep[i];
      tape.computeAdjoints();
      for (std::size_t i = 0; i < y.size(); ++i) lam_keep[i] = xad::derivative(y[i]);
      for (int i = 0; i < N_INPUT; ++i) F_step[i] += xad::derivative(p[i]);
      spent[1] += seconds_since(t0);

      t0 = Clock::now();
      tape.clearDerivatives();
      for (std::size_t i = 0; i < y1.size(); ++i) xad::derivative(y1[i]) = lam_cut[i];
      sweep_field_cut(tape, marks, true);
      for (std::size_t i = 0; i < y.size(); ++i) lam_cut[i] = xad::derivative(y[i]);
      for (int i = 0; i < N_INPUT; ++i) g_step[i] += xad::derivative(p[i]);
      spent[2] += seconds_since(t0);
    }
    for (int i = 0; i < 3; ++i) t_step[i] = std::min(t_step[i], spent[i]);
  }

  // Central differences of the resident (field responding) and of the invader.
  std::array<double, N_INPUT> F_fd{}, g_fd{};
  for (int i = 0; i < N_INPUT; ++i) {
    const double h = FD_H * std::max(1.0, std::abs(x0[i]));
    Inputs<double> up = x0, dn = x0;
    up[i] += h;
    dn[i] -= h;
    F_fd[i] = (resident(c, std::vector{up}, no_field)[0] -
               resident(c, std::vector{dn}, no_field)[0]) / (2 * h);
    if (i < N_TRAIT) g_fd[i] = (invader(c, up, fields) - invader(c, dn, fields)) / (2 * h);
  }

  std::printf("cohorts %d, steps %d, rate evaluations %zu, tape statements %zu\n\n",
              c.n, c.steps, n_marks, statements);
  std::printf("F = ln J - ln b: double %.17g, active %.17g\n", F_double, F_ad);
  std::printf("ln R' (invader at theta' = theta) %.17g, rel diff to F %.2e\n\n",
              lnR_inv, rel(lnR_inv, F_double));

  std::printf("%-16s %13s %9s %13s %13s %9s %9s %13s %9s %9s\n", "input",
              "F_theta pass1", "vs FD", "g pass2 cut", "g invader", "cut-inv",
              "inv vs FD", "commons F-g", "step F", "step g");
  for (int i = 0; i < N_INPUT; ++i) {
    const bool trait = i < N_TRAIT;
    std::printf("%-16s %13.6e %9.1e %13.6e ", input_name[i], F_theta[i],
                rel(F_theta[i], F_fd[i]), g_cut[i]);
    if (trait) {
      std::printf("%13.6e %9.1e %9.1e ", g_inv[i], rel(g_cut[i], g_inv[i]),
                  rel(g_inv[i], g_fd[i]));
    } else {
      std::printf("%13s %9s %9s ", "-", "-", "-");
    }
    std::printf("%13.6e %9.1e %9.1e\n", F_theta[i] - g_cut[i], rel(F_step[i], F_theta[i]),
                rel(g_step[i], g_cut[i]));
  }

  double worst_field = 0.0, biggest = 0.0;
  std::size_t compared = 0;
  for (double v : field_adjoint_inv) biggest = std::max(biggest, std::abs(v));
  for (std::size_t s = 0; s < field_adjoint_inv.size(); ++s) {
    if (std::isnan(field_adjoint_cut.at(s))) continue;
    ++compared;
    worst_field = std::max(worst_field,
                           std::abs(field_adjoint_cut[s] - field_adjoint_inv[s]) / biggest);
  }
  std::printf("\nfield adjoints zeroed in pass 2 vs invader's d ln R'/d field: %zu values, "
              "max |diff| / max|adjoint| %.1e\n",
              compared, worst_field);
  std::printf("pass 2 without truncation (rewalks swept statements):");
  for (int i = 0; i < N_TRAIT; ++i) std::printf(" %.3e", g_naive[i]);
  std::printf("  (g per trait; wrong)\n\n");

  const double t_inv = t_resident_double + t_inv_record + t_inv_sweep;
  std::printf("timings (min of %d), seconds:\n", repeats);
  std::printf("  resident record          %.4f\n", t_record);
  std::printf("  pass 1 (field kept)      %.4f\n", t_pass1);
  std::printf("  pass 2 (field cut)       %.4f   = %.2f x pass 1\n", t_pass2, t_pass2 / t_pass1);
  std::printf("  invader route            %.4f   = %.2f x pass 2  (double resident %.4f + "
              "record %.4f + sweep %.4f)\n",
              t_inv, t_inv / t_pass2, t_resident_double, t_inv_record, t_inv_sweep);
  std::printf("  invader record + sweep   %.4f   = %.2f x pass 2\n",
              t_inv_record + t_inv_sweep, (t_inv_record + t_inv_sweep) / t_pass2);
  std::printf("  step by step: record %.4f, pass 1 %.4f, pass 2 %.4f = %.2f x pass 1\n",
              t_step[0], t_step[1], t_step[2], t_step[2] / t_step[1]);
  return 0;
}
