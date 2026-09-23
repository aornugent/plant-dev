# Re-measuring the short-fixture findings at a 40-year horizon

TF24 SCM, one species, `max_patch_lifetime = 40`, `node_density_in_birth_date = TRUE`,
forcing `long-drought` except where a section says otherwise, optimised `-O2` build
(`plant/src/plant.so`, already current), `TESTTHAT_PARALLEL = false`, three runs at a
time on four cores. `J = sum(scm$offspring_production)`; the TF24 default birth rate
is 1, so `J` is the net reproduction ratio and `J = 1` is exactly self-replacing.

The fixture is `diag-long-drought.md`'s: `ld_common.R` unchanged, at `lma = 0.32`,
where `J = 12.08` on a converged aligned grid. Nine findings in
`docs/oracle-consultation-gradient-control.md` were taken at `max_patch_lifetime = 5`,
where `J` is 1e-7 to 1e-11 and the stand is ten orders of magnitude short of
self-replacing. This asks which of them are properties of the solver and which are
properties of that horizon.

**No code under `plant/`, `odelia/` or `phylloptim/` was changed, and nothing was
compiled.** Everything below is scripts in the scratchpad: `lh_common.R`,
`lh_probe.R`, `jf_scan40.R`, `ka_controls40.R`, `ka_frag40.R`, `ws_life40.R`,
`ws_shape.R`, `quad40.R`, `ga_fd40.R`, `ge_level40.R`. Each is the short-fixture
script it is named after with the horizon moved; the originals are untouched beside
them.

**`plant/src/plant.so` mtime, checked before and after every measurement block:**
`2026-09-22 12:52:40.069214118 +0000` throughout. Another agent was working the
rainfall driver in this tree for the whole session; the mtime is recorded per block
in each section and never moved, so no batch here spans a rebuild.

---

## Triage, written before anything was run

Nine findings, the script that produced each, what the horizon changes, and the
prediction. Sections below report what happened.

| | note and scripts | what moves at lifetime 40 | prediction |
|---|---|---|---|
| **M1** `J` is a step function in `θ` | `diag-jump-vs-floor.md`; `jf_common.R`, `jf_scan.R` — 25-point ±3% `lma` scan, aligned, 88 nodes | `J` 1e-10 → 12; 412 active knots → 2931; scan centred on `lma = 0.32` | **survives.** The steps come from the inner problem's classification reorganising, which is per-solve and horizon-blind. The branch shares at lifetime 40 (`boundary-crit` 4–13%, shutdown 0.025%) sit within 10% of lifetime 5's. Size is the open question, and `dlnJ/dln lma` must be re-derived. |
| **M2** step placement dominates | `diag-knot-alignment.md`; `ka_align.R`, `ka_coarse.R`, `ka_sham.R`, `ka_near.R`, `ka_frag.R` | the headline is already long-horizon in `diag-long-drought.md` (−35.4%, two aligned arms agreeing to 0.023%). Unmeasured at 40: the sham control, the near-miss control, one-extra-stop fragility | **headline survives, fragility is the doubtful half.** `diag-long-drought.md` already found the long-horizon error signed and systematic where the short one was one draw from a spread, so a single extra stop should move `J` by percent, not by a factor of three. |
| **M5** a sign-wrong gradient | `diag-wrong-sign.md`; `ws_common.R`, `ws_repro.R`, `ws_arith.R`, `ws_rho.R` | the note's own lifetime axis reads `|direct|/|total|` = 3.0 / 11.3 / **282** / 13.8 / 2.2 at lifetime 4 / 4.5 / **5** / 5.5 / 6 | **evaporates.** Lifetime 5 is the zero crossing of `d(mass_above_ground)/d rho`. What survives is the amplification identity and the reporting lesson. |
| **M6** the finite-difference plateau | `diag-gradient-aligned.md` §1; `ga_fd.R`, `ga_fd2.R` | whether a plateau exists turns on the aligned residue in `J` against `2d·J`. Aligned at lifetime 40 that residue is 0.03% from `ode_tol = 1e-4` down, against 0.00018% at lifetime 5 | **survives in form, moves in number.** A larger residue should push the plateau further out in `d`, or remove it. |
| **M7** two order ladders disagree | `diag-gradient-aligned.md` §2–§4, `diag-jump-vs-floor.md`; `ga_order.R`, `ga_order2.R`, `jf_levels.R` | a node ladder at lifetime 40 costs ~19 min at 429 nodes alone | **survives; the mechanism is instrument, not horizon.** Differencing a step function is horizon-blind. |
| **M8** orders need coarsening | `diag-gradient-aligned.md` §2; `ga_order2.R` | same ladder | **survives**, same reason. |
| **M9** a step program does not transfer across creation-grid levels | `diag-gradient-error.md` designs 2 and 3; `ge_level.R`, `ge_level2.R`, `ge_level3.R` | capture at one level, replay at another | **most likely to change.** At lifetime 5 the 18% and 11% are draws from the same spread of flips M2's fragility arm measures; if that spread collapses, so do they. |
| **M10** a captured grid holds a wide `θ` box | `spike-fixed-grid.md`; `fg_common.R`, `m1_fidelity.R`–`m5_supp.R` | a ±2× box in six parameters | **box survives, the rest is untested.** The box statement rests on `h·|λ|` on the chain, which is local and horizon-blind. |
| **M11** the reported error is a cancellation | `diag-quadrature-order.md`; `quad_common.R`, `quad_rules.R`, `quad_analysis.R`, `quad_smooth.R` | both terms are `O(Δb²)` on a schedule that now spans 40 years | **ratio survives, percentages do not.** The ratio was −0.582 in birth date, −0.248 in height and −0.59 on a smooth node ladder, so it is stable at a level but fixture-dependent at the second digit. |

Two corrections to the mapping the brief supplied, checked against each note's own
text. **M9 is `diag-gradient-error.md`** (`ge_*`), not `spike-fixed-grid.md`: the 18%
and 11% are that note's designs 2 and 3, and the union program at 2.5–4.5× the steps
is its design 3. `spike-fixed-grid.md` (`fg_*`, `m1_`–`m5_`) carries **M10** alone.
And **M5 is not measured on `J`**: it is the trait gradient of the census metric
`mass_above_ground`, which reads 9.67 at lifetime 5, so its percentages were never
against 1e-10. What was against 1e-10 is M1, M2, M6, M7, M8 and M9.
