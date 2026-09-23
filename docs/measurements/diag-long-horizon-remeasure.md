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
compiled.** Everything below is scripts in the scratchpad, listed in §9. Each is
the short-fixture script it is named after with the horizon moved; the originals
are untouched beside them.

**`plant/src/plant.so` mtime, checked before and after every measurement block:**
`2026-09-22 12:52:40.069214118 +0000` throughout. Another agent was working the
rainfall driver in this tree for the whole session; the mtime is recorded per block
in each section and never moved, so no batch here spans a rebuild.

---

## What the horizon changed

| | at `max_patch_lifetime = 5` | at 40 | |
|---|---|---|---|
| **M1** `J` a step function in `θ` | 0.107% rms, two 0.3–0.4% steps, lag-1 acf 0.60 | **0.031% rms, lag-1 acf 0.09**, one 0.44% departure that `ode_tol` removes | **gone** |
| **M2** alignment collapses the error | +140.6% → −0.057% | −35.4% → +0.08% | holds |
| **M2** sham control (stops in quiet spans) | one +92.6% excursion | **−37.9%, −14.5%, +0.04%**, branch share never falls | **sharper** |
| **M2** near-miss control | 2.6% against the knots' 0.21% | **0.32% against the knots' 0.31%** | **gone** |
| **M2** one extra stop | factor of 3, straddling the answer | **factor of 1.44, all 16 low by 18–43%** | **reversed** |
| **M5** sign-wrong gradient, condition number ~100 | `\|direct\|/\|total\|` = 63, sign wrong | **0.2, both paths the same sign** | **gone** |
| **M6** no difference plateau at the shipped tolerance | none at any `d` | **3.5 decades wide, flat to 4.6%** | **reversed** |
| **M8** orders readable only below the operating count | error ~1% at 88, 0.27% one bisection down | **value 3.1% and derivative 5.2% per doubling at 108→215** | **inverted** |
| **M9** a bit-identical time grid still gives 11% | 11% at the coarsest level | **0.019%**; the coarse-captured arm keeps its −11.0% | **half gone** |
| **M11** two `O(Δb²)` terms cancel, ratio −0.582 | −0.617% and +0.359%, total −0.259% | **−0.334% and −0.086%, total −0.420%** | **reversed** |

Of the nine, **two are gone outright** (M1, M5), **two reverse** (M6, M11), one
inverts (M8), one loses half of itself (M9), one holds with half its mechanism
refuted (M2), and two were not reached (M7, M10).

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

---

## 1. The fixture

`ld_common.R` at `lma = 0.32`, unchanged: 40-year horizon, a 41-year daily
rainfall record from a seasonal Markov-chain gamma generator with interannual
multipliers (1095 mm/yr, 9.5% wet days, three multi-year droughts, driest year
182 mm, longest dry run 191 days), 108 creation times in the default schedule,
2931 active knots among 14 599 daily control points. Aligned runs force a
zero-depth rainfall pulse at each of the 2931 knots.

The reproduction check, run first and against `diag-long-drought.md`'s ladder:
aligned, `ode_tol = 1e-3`, 108 nodes gives `J = 12.0526222` and 9931 steps,
against that note's `12.05262216` and 9931. Every digit, and the same step count.
`plant/src/plant.so` read `2026-09-22 12:52:40.069214118 +0000` before and after.

## 2. M5 — the sign-wrong gradient is the horizon

`d(mass_above_ground)/d rho` by reverse-mode sweep, constant rainfall 3.0,
`ode_tol = 1e-4`, `node_density_in_birth_date = TRUE`, the default schedule for
each lifetime (`ws_life40.R`). `direct` is the census's own reading of the traits
at the final state; `swept` is what `solve_adjoint` adds to it; the condition
number is `|direct| / |total|`.

| lifetime | nodes | `mass_above_ground` | `d/drho` | direct | swept | `\|direct\|/\|total\|` |
|---|---|---|---|---|---|---|
| **5** | **88** | 9.66994728 | **+1.97574677e-04** | +1.24480825e-02 | −1.22505078e-02 | **63.0** |
| **40** | **108** | 48.1690732 | **+5.52879564e-02** | +1.25878446e-02 | +4.27001118e-02 | **0.2** |

and down a coarsened ladder at one level below the default, which is what makes
the trend legible:

| lifetime | nodes | `d/drho` | direct elasticity | swept elasticity | total elasticity | `\|direct\|/\|total\|` |
|---|---|---|---|---|---|---|
| 5 | 45 | +1.21077768e-03 | +0.78260 | −0.70645 | +0.076 | 10.3 |
| 10 | 47 | +3.86357879e-03 | +0.54647 | −0.39814 | +0.148 | 3.7 |
| 20 | 50 | +2.45809772e-02 | +0.29711 | **+0.20332** | +0.500 | 0.6 |
| 40 | 55 | +5.71790707e-02 | +0.15537 | **+0.52352** | +0.679 | 0.2 |

**The two paths stop opposing each other between lifetime 10 and 20.** At the
40-year horizon the direct elasticity is +0.159 and the swept +0.539 — the same
sign — and the total, +0.698, is larger than either. There is no cancellation, no
condition number of 100, and no sign at risk. The lifetime-5 reading reproduces
bit for bit at both node counts (`+1.97574677e-04` at 88, `+1.21077768e-03` at
45), so nothing about the measurement changed; the operating point did.

The reason is in the metric. `mass_above_ground` is `mass_leaf + mass_bark +
mass_sapwood + mass_heartwood`, and only bark and sapwood carry `rho` explicitly,
so the direct term's elasticity **is** the bark-plus-sapwood share of above-ground
mass. That share falls from 0.78 to 0.16 as the stand ages into heartwood, which
is why the direct term shrinks while the stand-size response grows and turns.
`max_patch_lifetime = 5` sits on the zero crossing of the sum;
`diag-wrong-sign.md` found the crossing and said so, and its lifetime axis
(`|direct|/|total|` = 3.0 / 11.3 / **282** / 13.8 / 2.2 at 4 / 4.5 / 5 / 5.5 / 6)
already predicted this before the 40-year run.

**Verdict: the finding is a property of `max_patch_lifetime = 5`.** What survives
is the identity it was built on — `err(total) = (|direct|/|total|)·err(direct) +
(|swept|/|total|)·err(swept)`, which holds at any conditioning — and the
recommendation that follows from it: `stand_gradient` forms both terms and
discards the split, and returning `|direct|/|total|` beside the gradient costs
nothing and names an ill-conditioned column at the call site.

## 3. M1 — `J` stops being a step function in `θ`

`jf_scan.R`'s design, moved: 25 trait points spanning ±3% in `lma` about 0.32,
aligned on the 2931 active knots, the node schedule fixed at the base trait's
default 108 so the grid does not depend on `θ`, `ode_tol = 1e-3`, birth-date
coordinate (`jf_scan40.R`, `jf_fit40.R`, `jf_fit_cmp.R`). `J` runs from 13.631
down to 10.585 across the scan; `dlnJ/dln lma = −4.13`.

The same fit applied to both scans, so the comparison is like for like
(`jf_fit_cmp.R` reads the lifetime-5 scan off `jfscan_base_L3_t1e-02.rds`):

| | cubic rms | cubic peak | lag-1 acf | quintic rms | drop the single worst point |
|---|---|---|---|---|---|
| lifetime 5, `lma = 0.0825` | 0.1066% | 0.2660% | **0.604** | 0.0902% | rms 0.0797%, peak 0.2146% |
| **lifetime 40, `lma = 0.32`** | 0.0977% | 0.4152% | **0.086** | 0.0870% | **rms 0.0311%, peak 0.0695%** |

The two rms figures are nearly equal and mean opposite things. Dropping one
point of 25 takes the lifetime-40 residual from 0.087% to **0.031%** and the peak
from 0.370% to 0.070%; it moves the lifetime-5 residual by a tenth. The residual
sequences say why. At lifetime 5 the cubic residual, in units of 1e-4 of `J`,
runs

```
-5.4 -2.1 -0.9 -0.2  1.2  5.1  8.2 12.1 13.3 17.8 | -21.9 -26.6 -23.4 | -3.0
 0.2  0.4  5.6  7.7  5.7  7.7  5.8  4.4  1.6 -5.6 -7.9
```

— a level shift of 0.4% across one trait gap, held for three points, then
released. At lifetime 40 it runs

```
-4.1  7.0  0.2 -0.7 -2.3 -3.7 -1.7  5.8  3.3  0.3 -1.9 -3.9 -4.6 -2.6  6.0
 6.8  4.1  3.9  4.9 | -37.0 |  9.1  8.9  5.7  0.4 -3.8
```

— one point, and a return. Lag-1 autocorrelation 0.086 against 0.604 is the same
fact in one number.

**The branch census stops reorganising too.** The non-interior share of leaf
solves across the scan:

| | range over the scan | largest move between adjacent trait points |
|---|---|---|
| lifetime 5 | 11.67 – 12.65% (0.98 points) | **0.671 points** |
| lifetime 40 | 9.53 – 9.73% (**0.195 points**) | **0.099 points** |

and at lifetime 40 the correlation between that share and the fit residual is
**−0.033**. The mechanism M1 named — steps sitting where the inner problem's
classification reorganises — is not visible at this horizon, because the
classification barely moves: `hydraulic-shutdown` holds at 0.0789–0.0826% and
`boundary-crit` at 9.32–9.51% across a 29% change in `J`.

A central difference on this scan reads the cubic's slope to under 1%:
−1.5611e+02, −1.5405e+02, −1.5531e+02, −1.5663e+02 at `d` = 0.25, 0.5, 0.75 and
1.0%, against the cubic's −1.5559e+02 — within ±1.0%. At lifetime 5 the same
instrument put a 0.29% signal inside 0.1% of scatter.

**The one departure is time integration.** The scan's outlier and its two
neighbours, re-run at tighter tolerance (`jf_outlier40.R`):

| `ode_tol` | `J` at `fr` +0.0150 | +0.0175 | +0.0200 | middle point against the chord |
|---|---|---|---|---|
| 1e-3 | 11.315681852 | 11.146924403 | 11.077158319 | **−0.4420%** |
| 1e-4 | 11.344911395 | 11.220959678 | 11.098212255 | **−0.0054%** |
| 1e-5 | 11.331639137 | 11.208862172 | 11.085809738 | **+0.0012%** |

One decade of tolerance removes it by a factor of 80 and the next takes it to
zero within the scan's own resolution. Nothing about the model is discontinuous
there.

**Verdict: the finding does not survive the horizon.** At a stand twelve times
self-replacing, `J` is smooth in `lma` to 0.031% rms and 0.070% peak over ±3%,
the branch census does not reorganise across the scan, and the single 0.44%
departure is removable with `ode_tol`. The lifetime-5 steps were real and
reproduce; they are a property of a stand at 1e-10, where the inner problem's
classification swings 0.67 points between trait values 0.25% apart.

## 4. M2 — placement still decides the answer; the breakpoints stop mattering

`diag-long-drought.md` already carried the headline to this horizon: unaligned is
−35.4% at the shipped tolerance and the two aligned arms agree to 0.023%. What
was short-fixture-only is the pair of controls that say *why*, and they run here
with the same 2931 stops in every arm, differing only in where those stops go
(`ka_controls40.R`).

- **sham** — 2931 stops drawn evenly from the 11 668 daily control points that
  are *not* active knots, so every one falls in a span where the reconstruction
  is identically zero. None coincides with an active knot.
- **near-miss** — the 2931 active knots shifted a quarter of a day and half a
  day, so the stops land inside the rain-event stretches without landing on a
  breakpoint.

Relative error against the aligned answer at `ode_tol = 1e-5`, `J = 12.0779933`
— which reproduces `diag-long-drought.md`'s ladder to every digit:

| arm | `ode_tol` 1e-2 | 1e-3 | 1e-4 | worst |
|---|---|---|---|---|
| unaligned | **−69.376%** | **−56.538%** | **−35.376%** | 69.4% |
| 2931 stops, quiet spans (sham) | **−37.872%** | **−14.508%** | +0.036% | **37.9%** |
| 2931 stops, +0.25 d off each knot | +3.331% | −0.205% | +0.008% | 3.3% |
| 2931 stops, +0.5 d off each knot | −0.054% | −0.317% | −0.048% | **0.32%** |
| **2931 active knots** | +0.309% | −0.210% | +0.078% | **0.31%** |

and the steps and branch census behind it:

| arm | steps at 1e-2 / 1e-3 / 1e-4 | `hydraulic-shutdown` % at the same three |
|---|---|---|
| unaligned | 6 900 / 8 522 / 11 320 | 0.590 / 0.356 / 0.379 |
| sham | 9 264 / 10 803 / 13 499 | 0.490 / 0.420 / **0.392** |
| +0.25 d | 8 655 / 10 291 / 13 223 | 0.141 / 0.049 / **0.0072** |
| +0.5 d | 8 599 / 10 353 / 13 373 | 0.104 / 0.048 / 0.0117 |
| aligned | 8 683 / 9 931 / 12 226 | 0.144 / 0.081 / 0.0253 |

**The first half of the mechanism holds and is sharper here.** At `ode_tol = 1e-2`
the sham arm takes **9264** steps and is **37.9%** low; the aligned arm takes
**8683** — fewer — and is 0.3% high. Stops in the dry spans buy step count and
nothing else. The sham's `J` lands within 0.04% at `ode_tol = 1e-4`, exactly the
coincidence the short fixture hit at one tolerance, and the branch census convicts
it: its `hydraulic-shutdown` share is 0.392% there against the aligned arm's
0.0253%, and it does not respond to tolerance (0.490, 0.420, 0.392 across three
decades) any more than the unaligned arm's does. Its right answer is an endpoint
coincidence over a trajectory that disagrees.

**The second half does not hold.** At lifetime 5, stops a quarter or half day off
each knot held the answer to 2.6–2.8% while the knots themselves held it to
0.21% — a 13-fold gap, and the only part of that measurement specific to the
interpolant's `C¹` structure. At lifetime 40 the half-day near-miss holds to
**0.32%** and the knots to **0.31%**: no gap. The near-miss arms even reach a
*lower* shutdown share than the aligned arm at every tolerance. Over 2931 knots
in 40 years, being in the right stretch is the whole of it, and exact breakpoint
alignment adds nothing measurable.

**And the tolerance response changes shape.** At lifetime 5 the unaligned error
was flat and non-monotone across three decades (+117.7, +64.8, +121.1, +132.4,
+140.4%) and then fell 300× in one half-decade. At lifetime 40 it is signed,
monotone and slow: −69.4%, −56.5%, −35.4%, reaching −22% at `ode_tol = 1e-5`
with 61% more steps than the aligned run needs. It is a bias that tolerance
erodes, not a flip.

**One extra stop no longer straddles the answer.** Sixteen runs, unaligned,
`ode_tol = 1e-4`, 108 nodes, one extra forced stop and nothing else changed
(`ka_frag40.R`; the no-stop run is `J = 7.80523085`, the aligned reference
12.0779933):

```
 1.60  8.148 (-32.5%)   4.05  9.890 (-18.1%)   6.51  7.474 (-38.1%)   8.96  7.461 (-38.2%)
11.41  7.868 (-34.9%)  13.87  6.871 (-43.1%)  16.32  7.531 (-37.6%)  18.77  7.393 (-38.8%)
21.23  7.362 (-39.0%)  23.68  7.840 (-35.1%)  26.13  7.823 (-35.2%)  28.59  7.810 (-35.3%)
31.04  7.808 (-35.3%)  33.49  7.804 (-35.4%)  35.95  7.805 (-35.4%)  38.40  7.805 (-35.4%)
```

`J` spans 6.871 to 9.890 — a factor of **1.44**, against the short fixture's
**3.0** — and **all sixteen** land 18% to 43% below the converged value. At
lifetime 5 five of sixteen fell below the converged answer and ten above, with
the truth inside the spread and matched by none of them; here the truth is
outside the spread in one direction. A second structure appears with it: a stop
after `t = 23.7` moves `J` by under 0.5%, while one at `t = 4.05` moves it 26.7%
and one at `t = 13.87` by −12.0%. The sensitivity lives where the creations are
dense.

**Verdict: the finding survives, with one of its two mechanisms refuted and its
fragility arm reversed.** Placement decides the answer and the sham control is
what proves it. Exact breakpoint alignment is no better than being half a day
off. And the short fixture's "one extra stop moves the functional by a factor of
three, straddling the converged value in both directions" describes a spread of
discrete flips that a 40-year record does not have: 2931 individual
mis-integrations accumulate into a one-sided bias no single stop can undo.

## 5. M11 — the two terms stop cancelling

`quad_smooth.R`'s design, moved: constant rainfall 3.0 mm/day so the record stays
smooth, `lma = 0.32`, `ode_tol = 1e-6`, birth-date coordinate, the default
creation schedule bisected three times — 108, 215, 429, 857 nodes. The reference
is the densest samples under a local quintic; three high-order rules on them
agree to 1.7e-4 (`quad40.R`, `quad40_show.R`).

`ode_tol` is not the floor. The 108- and 215-node cells re-run at `1e-7` return
`J = 288.528924` and `289.9734041` against `288.5289228` and `289.973403` at
`1e-6` — nine digits, moves of 0.0000% (`quad40_tol.R`). Everything below is the
creation grid alone.

| nodes | model's own trapezium | high-order on its own samples | trapezium on the converged integrand | `J` |
|---|---|---|---|---|
| **108** | **−0.4198%** | **−0.3341%** | +0.4740% | 288.52892 |
| 215 | +0.0787% | +0.0544% | +0.1791% | 289.97340 |
| 429 | −0.0234% | −0.0299% | −0.0447% | 289.67760 |
| 857 | +0.0016% | 0 | +0.0016% | 289.75013 |

**At the operating point the two terms have the same sign.** The reported error at
108 nodes is −0.4198%, of which the creation-count term is **−0.3341%** and the
trapezium's own error on those same samples is **−0.0857%**. They add. At
lifetime 5 they were −0.617% and +0.359%, and the reported −0.259% was smaller
than either — the cancellation the finding is named for. Here the total is
*larger* than either term, and raising the output rule's order takes the answer
from −0.4198% to −0.3341%: **1.26× better, against 2.4× worse at lifetime 5.**

The stable ratio goes with it. `J` converges at second order — level-to-level
changes +1.4445, −0.2958, +0.0725, ratios 4.88 and 4.08, `log₂` 2.29 and 2.03 —
but with **alternating sign**, so the creation-count term reads −0.334%, +0.054%,
−0.030% and no ratio between the two terms can be stable. The lifetime-5 figures
−0.582 / −0.581 / −0.580 have no counterpart here.

The trapezium's own error behaves itself throughout: **−0.0857%, +0.0243%,
+0.0065%** at 108 / 215 / 429 nodes, falling by about 3.5× per bisection. It is
the second-order term the finding says it is. What it is not is a cancelling
partner.

**Verdict: the finding reverses.** Two `O(Δb²)` terms are present, and at a
40-year horizon they reinforce. A higher-order output rule is a small improvement
where the short fixture said it was a 2.4× regression.

## 6. M6 — a plateau appears at the operating tolerance

Central differences in `lma` on the aligned grid at `ode_tol = 1e-3`, the
creation schedule fixed at the base trait. Two sources, one instrument: the
±3% trait scan of §3 supplies `d` from 3e-2 down to 2.5e-3 at its own spacing,
and a dedicated ladder supplies 1e-3 down to 1e-7 (`ga_fd40.R`,
`ga_fdshow40.R`). The cubic through the scan gives `dJ/dlma = −155.59`.

| `d` | 3e-2 | 1e-2 | 5e-3 | 2.5e-3 | 1e-3 | 3.16e-4 | 1e-4 | 3.16e-5 | 1e-5 | 1e-6 | 1e-7 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `dJ/dlma` | −158.66 | −156.63 | −154.05 | −156.11 | −151.65 | −153.40 | −154.12 | −153.25 | −151.67 | **−143.45** | **−187.79** |

**The plateau runs from `d` = 3e-2 to 1e-5 — three and a half decades — flat to
5.3%**, or to **4.6%** with the one pair that contains §3's time-tolerance
outlier set aside (`d` = 1.75e-2, reading −159.67). Its flattest two decades,
1e-3 to 1e-5, are flat to **1.6%**. Below 1e-5 it goes: −8.1% at 1e-6, +20.3% at
1e-7.

At lifetime 5 this instrument had **no plateau at any `d`** from 1e-3 to 1e-9 at
the operating tolerance, and needed two further decades of `ode_tol` to buy one
1.5 decades wide, flat to 0.63%. Here the operating tolerance carries one
outright — wider and coarser. What sets the 1.6–4.6% floor, and whether tighter
`ode_tol` narrows it the way it did at lifetime 5, is not measured.

**Verdict: the finding reverses.** The finite-difference plateau is not a
property of the instrument alone; at a viable stand the instrument works at the
shipped tolerance.

## 7. M8 — the operating creation count moves to the other side of the problem

The node ladder that came with §2's sweep, at lifetime 40 (`ws_life40.R` at four
levels around the default):

| members | 28 | 55 | 108 | 215 |
|---|---|---|---|---|
| `mass_above_ground` | 48.4972141 | 51.2080464 | 48.1690732 | 46.6814602 |
| `d/drho` | 5.71911659e-02 | 5.71790707e-02 | 5.52879564e-02 | 5.24425607e-02 |

The last doubling moves the value **3.09%** and the derivative **5.15%**, and
neither sequence is monotone across the first two levels. At lifetime 5 the
operating count of 88 sat above the noise floor with a ~1% error that one
bisection took to 0.27%, and orders were readable only four halvings below it.
At lifetime 40 the same default schedule spreads 108 members over eight times
the span and sits below convergence instead. A refinement sequence here has to
run *upward*, and 215 members is not yet far enough.

## 8. M9 — a program captured at the finer level transfers; one captured at the coarser does not

`ge_level2.R`'s designs 1 and 2 on `J` alone, two creation levels — 108 and 215
members, the coarse set nested in the fine one — on the smooth record the short
fixture used (constant 3.0) and again on the intermittent record with the knots
forced (`ge_level40c.R`, `ge_level40.R`, `ode_tol = 1e-4`):

| | smooth record | intermittent, aligned |
|---|---|---|
| adaptive, 108 members | 288.528955 (3973 steps) | 12.0873665 (12 226 steps) |
| adaptive, 215 members | 289.973412 (4341 steps) | 12.1083840 (12 486 steps) |
| the 215-member program replayed at 108 | **288.473541** (4341 steps) | **12.1009109** (12 225 steps) |
| the 108-member program replayed at 215 | **258.193090** (4080 steps) | 12.1114671 (12 489 steps) |

**Design 2 — capture at the finer level, replay at the coarser — transfers.** The
replayed run walks the 215-member program's 4341 times at 108 members and returns
288.4735 against that level's own adaptive 288.5290: **−0.019%**, against the
short fixture's **11%**. On the aligned intermittent record it is +0.112%. Read
the other way, the same time grid at 108 and at 215 members gives 288.4735 and
289.9734 — **0.52%** — which is what §5's second-order creation-grid sequence
predicts for that bisection (+1.4445 on 288.53, 0.50%). The pure creation-grid
effect is the quadrature effect and nothing more.

**Design 1 — capture at the coarser level, replay at the finer — does not, and
the reason is M2.** The 108-member program does not contain the 215-member
level's 107 extra creation times, so H2 inserts them: the replayed run takes
**4080** steps against the captured program's 3973, exactly 107 more, and returns
258.193 against 289.973 — **−11.0%**, the same order as the short fixture's 18%.
107 forced stops landing where the record did not ask for them is the
one-extra-stop experiment of §4 run 107 times over.

**Verdict: half the finding evaporates, and the surviving half is M2.** The claim
the consult leans on — that a bit-identical time grid gives a different answer
when the creation grid beneath it changes — is 0.02% here, not 11%. Derivatives
were not re-measured, and two levels are not four.

## 9. Scripts, and the build they ran against

All in the scratchpad, all `Rscript <file> [args]`, all reading `plant` through
`pkgload::load_all` and `odelia` through `library`. Each is the short-fixture
script it is named after with the horizon moved; the originals sit beside them
untouched.

| file | what |
|---|---|
| `lh_common.R` | sources `ld_common.R`, adds the active-knot set, the quiet-span set, the node ladder and the `.so` mtime reader |
| `lh_probe.R` | the reproduction check of §1 |
| `ws_life40.R`, `ws_shape.R` | §2 and §7: `d(mass_above_ground)/d rho` by reverse sweep down a lifetime axis and a node ladder |
| `jf_scan40.R`, `jf_fit40.R`, `jf_fit_cmp.R`, `jf_outlier40.R` | §3: the 25-point trait scan, its residual analysis against the lifetime-5 scan, and the outlier's tolerance ladder |
| `ka_controls40.R`, `ka_frag40.R` | §4: the sham and near-miss controls across three tolerances, and the one-extra-stop arm |
| `quad40.R`, `quad40_tol.R`, `quad40_show.R` | §5: the creation-grid ladder under constant forcing, its tolerance check, and the decomposition |
| `ga_fd40.R`, `ga_fdshow40.R` | §6: the difference-step ladder, combined with the trait scan's own large-`d` points |
| `ge_level40.R`, `ge_level40c.R` | §8: capture and replay across two creation levels, aligned and on the smooth record |
| `lh_extras.R`, `lh_legs.R` | the step-attempt census, the knot-against-program counts and the leg statistics the consult quotes |

**`plant/src/plant.so` was read before and after every block and never moved:**
`2026-09-22 12:52:40.069214118 +0000` at the start of the session and at the end
of the last batch, and at the head and foot of every script's own log. Another
agent held `plant` for the whole session and rebuilt nothing in it. No file under
`plant/`, `odelia/` or `phylloptim/` was written by this work.

## What is missing

- **M7 and M10.** No order ladder and no `θ`-box sweep at lifetime 40. §7 is the
  reason to expect M7 to read differently: the sequence the ladders would read
  has not reached its asymptotic regime by 215 members, where lifetime 5 had
  reached it by 88.
- **Derivatives in §8.** M9's sign-flipped derivatives and its union-program arm
  are untested here; only `J` was compared, at two creation levels against the
  short fixture's four.
- **Two tables in the consult's configuration sections.** Which component attains
  `r_max` over every accepted step needs the `error_index` instrumentation
  exposed, which would mean a rebuild; the `h·|λ|` stability-boundary sweep was
  not repeated. Both remain lifetime-5 readings.
- **What sets §6's 1.6–5.3% plateau floor.** The lifetime-5 plateau tightened to
  0.63% with two further decades of `ode_tol`; whether this one does is unrun.
- **One trait and one record.** Everything is `lma` about 0.32 on `long-drought`,
  except §5 and §8's smooth arm on constant 3.0. `long-wet` exists in
  `ld_common.R` and was not used, and no other trait was scanned.
- **§5's alternating creation-grid sequence.** `J` converges at second order with
  the sign flipping level to level, and the reason is measured rather than
  explained.
