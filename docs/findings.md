# What the trusting-curie measurements found

**Status.** A digest of the measured findings from the long-lived branch, so they need not be
measured again. The raw runs, logs and scripts stay on the tag. Every claim is *measured*
unless marked *derived* (arithmetic or theory on measured numbers) or *estimated*.

**Sources.** Paths like `measurements/...`, `report/...` and `review/lateral-games.md` are on
the tag `archive/trusting-curie`, under `docs/`:
<https://github.com/aornugent/plant-dev/tree/archive/trusting-curie/docs>. Dates are each
source's last commit on the tag. `schedule/...`, `review/eeo-derivatives.md`,
`review/site-selection.md` and `review/theory.md` are in this repo's `docs/`.

**Numbering.** E1–E8 here are the regnans roadtest's experiments, as cited by
`review/eeo-derivatives.md`, `review/site-selection.md` and `schedule/refine.md` (§ Next).
`schedule/refine.md`'s "evidence E1, R4, …" are a different set:
`measurements/schedule-search/rootcause/evidence/`.

**The fixture,** unless stated: TF24, one species at `lma = 0.32`, a 40-year patch, the
long-drought record (seed 31), birth-date coordinate. Costs are in *forwards*, one plain
forward run on the same grid and tolerance.

**ε.** ε_q is a tenth of quantity q's standard deviation across eight long-drought rainfall
seeds, never under 0.01 (`measurements/eps-spread.md`, 2026-10-03; values in
`../harness/schedule/data/eps.csv`). For `ln J` it is 0.0252. For the invader's `lma`
elasticity it is 0.198, the "ε ≈ 0.20" of the roadtest.

## E1–E8: the regnans roadtest's root-cause experiments

In `measurements/regnans-roadtest/rootcause/`. The scripts are `e1_tol.R` … `e8_cliff.R`, the
numbers are in `results.txt`, and the reading is in `README.md` (2026-10-21). All ran on long
drought at its b* = 4.676, on uniform introductions, with relative tolerance 1e-4 and absolute
1e-8 unless stated.

| | What was measured | Headline |
|---|---|---|
| **E1** | A forward on 201 introductions: absolute tolerance, step cap | 77 s, 8549 steps. At absolute tolerance 1e-4: 48 s, 5157 steps, and `ln J` moves 0.02ε. The 15-day cap binds on 0.04% of steps, and removing it changes nothing |
| **E2** | Node count 54/108/201/402: `ln J`, the invader's `d ln R′/d ln lma`, and `ln R′` at lma × 0.95 | The invader's gradient converges more slowly than `ln J`. At 108 it is 5.4ε off while `ln J` is 0.3ε off; at 201 they are 0.19ε and 0.01ε. Steps grow only 8223 → 9024 from 108 to 402, so cost is about linear in introductions. Three invaders cost 1.9× one resident (148 s against 77 s) |
| **E3** | The invader's gradient at θ′ = θ, three ways (201) | Sweep and tangent give −23.78595, and two invaders at e^{±0.001} give −23.78594. In forwards: invader plus sweep 0.64 + 2.05, invader plus tangent 0.64 + 1.31, two invaders 1.24 |
| **E4** | Other climates on 201 even introductions | Seasonal takes 8691 steps. Constant takes 3221 steps (median step 3.3 d against 1.1–1.2 d with daily rain), but its J is 2.8e-10: even spacing misses its short establishment window |
| **E5** | The selection gradient g against ln b, at ln b* ± 0.03 and ± 0.1 | dg/d ln b = −5.99 and dF/d ln b = −1.75, with F = ln J − ln b. g's error is 3.4·\|F\|, so \|F\| < 0.06 holds g within ε. At the resident's traits ln R′ = F to every digit printed |
| **E6** | E2's ladder (108/201/402) at absolute tolerance 1e-4 | The same convergence. At 201, g = −23.763 against −23.753 at 402, and the resident run takes 52 s against 77 s |
| **E7** | Cost per pass, 201 introductions, 51 trait columns | Against a plain forward: recorded 0.99, resident sweep 2.14, invader 0.61, invader sweep 1.94, two-invader difference 1.21. At absolute tolerance 1e-4 the plain forward is 49 s and the ratios barely move (2.13, 1.90). F_θ along the trade-off is −5.91 |
| **E8** | Constant rain's jump, b* = 45.06, rebuilt 257-introduction schedule: offspring by introduction for invaders at lma × (1 − 1e-4, 1, 1 + 1e-4) | ln R′ = +2.44, −1.5e-6 and −5.60. The change sits in introduction 1 (birth date 0): its offspring per seed go 1.9e5 / 1.6e4 / 60. One founding cohort wins or loses the canopy |

## Cost

- **Headline.** J and its 49 elasticities on long drought take 209 s with the branch's parts
  on, against 886 s by brute force. Brute force is 215 introductions at 1e-5 with parts 4–7
  off. On plant `develop` the cost would be about 3.7 h (*derived*: 134 s per run × 100 runs
  of differences). Episodic has the same ratio, 0.24 (128 s against 536 s), with all 50
  quantities within 0.40ε of brute force. `report/deck.tex`, `measurements/headline/`
  (2026-10-08).
- **Waterfall.** Going from 215 to 108 introductions saves 408 of brute force's 850 s and
  carries all the remaining error. The cut, the preset, the soil stepped alone and the window
  save 52, 86, 96 and 32 s. The pilot adds 39 s. At 108 introductions the median elasticity
  stays 0.50–0.51ε from converged at every step. `report/deck.tex`,
  `measurements/waterfall/` (2026-10-08).
- **108 introductions are too few on long drought.** Against the 108/215 extrapolation,
  215 introductions match brute force (median elasticity 0.13ε against 0.12ε) at 0.43 of its
  time. At 108 the median is 0.50ε, the largest 2.1ε, at 0.24 of the time. `report/deck.tex`
  (2026-10-08). E2 says about 200 for the invader's gradient (2026-10-21).
- **A sweep costs 2.1–2.9 forwards. Latest: 2.14 for the resident and 1.94 for the invader**
  (E7, 2026-10-21). Earlier figures on older builds and tolerances:
  - 2.51–2.66, flat from 108 to 857 introductions (`measurements/perf-adjoint.md`,
    2026-09-24);
  - 2.70 at 1e-3, and 2.52–2.63 at 3e-5 (`measurements/perf-sweep.md`, 2026-10-05);
  - 2.88 at b* (`measurements/equilibrium.md`, 2026-10-05).
- **Recording is free in CPU, not in memory.** A recorded forward costs 0.96–0.99× a plain
  one. Memory is 184–198 bytes per live node per step: peak 297 MiB at 108 introductions and
  1423 MiB at 857, against 155 MiB unrecorded. `measurements/perf-adjoint.md` (2026-09-24).
- **Why a sweep costs about 2.7 forwards.** It makes 0.83 as many member evaluations per row,
  and each costs 3.26× as much (43.0 µs against 13.2 µs): 0.83 × 3.26 = 2.70. Of the 43 µs,
  32.2 µs is taping the member at its recorded point. The leaf is never re-searched. The
  implicit-function solves are 37% of the sweep's instructions. `measurements/perf-sweep.md`
  (2026-10-05).
- **The forward is the leaf.** The leaf solve is 84.9% of instructions. Soil rates are
  0.04%, and the solver and controller 0.25%. 17% of member evaluations are in rejected
  attempts. MRI and IMEX as built were 6–50× slower than Cash–Karp.
  `measurements/perf-rhs-profile.md` (2026-09-23, older build; the shape holds).
- **Daily rain sets the steps.** About 8500 steps of about a day on long drought or seasonal,
  against 3221 on constant (E1, E4). Cost ≈ steps × introductions alive × about 13 µs per
  evaluation.
- **Invaders share no work.** Nine together cost nine times one: 818 s against 92 s. Five
  together cost 5.0 walks. Roadtest §2 (2026-10-21); `measurements/equilibrium.md`
  (2026-10-05).
- **The roadtest's hour.** 4752 s on long drought:
  - a quarter was checks regnans would not run (landscape, differences, back invasion);
  - Newton paid a full sweep per run for one slope;
  - one evolutionary step cost 9.4 forwards, against 2.2–3.2 for the same answers matched to
    regnans (*estimated* from measured pieces).

  Roadtest §1, §4 (2026-10-21).

## Gradient accuracy

- **Adjoints are exact for their map.** Sweep, forward tangent and difference agree to 1e-6
  relative at the resident (E3). Node adjoints match finite differences to about 2e-4
  (`measurements/perf-adjoint.md`). Episodic, dry-flat and the other smooth climates match
  central differences to 1e-6 (roadtest §8).
- **The invader is the resident at θ′ = θ.** J′ = J to the last bit on eight seeds
  (`measurements/eps-spread.md`, 2026-10-03), and R′ = 1 to 1e-12 (roadtest §3). With splits
  on, a walk differs by −7.6e-5 (0.003ε), because walks do not split
  (`measurements/equilibrium.md` P12, 2026-10-05).
- **The invader's gradient is not under the node guarantees** (E2): 5.4ε at 108 introductions
  where `ln J` is 0.3ε. Its elasticities are 2.7–4.5× the resident's
  (`measurements/eps-spread.md`).
- **Elasticities in `lma` alone and along the trade-off differ by about 1.5×.**
  `TF24_hyperpar` moves `r_l` and `k_l` with `lma`.
  - The smoke test's `1.lma` column gives −122.5 against −79.5 along the trade-off
    (`measurements/regnans-smoke/README.md`, 2026-10-20).
  - At b*, the stand's −9.96 and the invader's −37.1 (`measurements/equilibrium.md`) are the
    partials. The roadtest's −5.9 and −23.8 are along the trade-off.
- **Field adjoints map where the node error is made.** Field adjoints contracted with each
  panel's drop defect predict J's field part at 1.000×, 0.991× and 0.996×, and the invader's
  at 0.986× and 0.94×. J's field error is soil water; the invader's is light. It costs +12%
  of a sweep. Interpolated virtual cohorts fail (0.63–1.18×).
  `measurements/field-adjoint-map.md` (2026-10-02).
- **The tolerance check across records,** at 3e-5 on 108 introductions:
  - it passes on episodic;
  - it fails on dry (21 of 49 resident quantities);
  - it fails on the constant record's invader (43 of 49);
  - `ln J` moves ≤ 1e-3ε everywhere;
  - 54 introductions fail the node check on every record.

  `measurements/spot-check.md` (2026-10-03). Superseded as a method by the refine loop
  (`schedule/refine.md`).

## Non-smoothness

- **TF24 has 26 non-smooth points:** 3 jumps, 13 kinks, 4 C1 and 6 narrow smooth. Two are
  handled: the split at net production's sign change and the rain knots. The leaf's arm switch
  (Interior ↔ BoundaryCrit) makes 14 728 sign changes in 234 of 4786 steps on dry.
  `measurements/kinks/inventory.md` (2026-10-16).
- **Gradients jitter with the controller.** A ±5% tolerance nudge moves the elasticities
  0.048ε rms on dry at 3e-4. Ending steps at each switch cluster's ends takes it to 0.002ε for
  +12.8% rows. Restricting the stops to h ≥ 0.25 d and b < 25 gives 0.0027ε for +3.6%.
  `measurements/deep-search-nonsmooth/lean/results.md` (2026-10-16).
- **Stopping removes jitter, not error.** About 0.02ε remains at 3e-4, set by the tolerance.
  Resolving the clusters does not let a looser tolerance buy accuracy: stopped 1e-3 is 0.047ε
  against unstopped 1e-4's 0.013ε. Same source.
- **Collapsed-bracket jumps are rare.** "Determined" collars fall in exactly one step per
  record (t ≈ 35–39), inside split substeps, never at a stage.
  `measurements/kinks/jump-census/results2.md` (2026-10-16).
- **Hydraulic shutdown is a birth transient.** Converged, it is 0.002% of leaf solves on long
  drought. Unaligned steps are −35% to −40% off and do not wash out with refinement.
  `measurements/diag-long-drought.md` (2026-09-22), reproduced to every digit.
- **Constant rain has no gradient at the resident** (E8, roadtest §8).
  - ln R′ is +8.78, +7.40, 0, −39.85 and −44.95 at lma × 0.85, 0.95, 1, 1.05 and 1.2.
  - The central difference is −40 197 at h = 1e-4 and −8 161 at h = 1e-3. The sweep says
    −6.3 million.
  - *Derived* mechanism (`review/lateral-games.md` §3.1, summarised in
    `review/eeo-derivatives.md` §4): the tie term is Lazear–Rosen's prize spread × tie
    density. For one deterministic cohort the density is a Dirac, so g does not exist. With a
    height spread σ, |g| ∝ 1/σ.
- **The constant record's founders arrive in 23 days.** Establishment closes at day 23.5, so
  uniform introductions lump the founders into the first one. Resolved, J is 288–292.
  `measurements/traits/results.txt` (2026-10-11); `measurements/spot-check.md`.

## Equilibrium and the loop

- **A secant in ln b finds b* in 6 runs.** b* = 4.659 at 108 introductions, from b = 1, to
  \|F\| = 5.4e-8. regnans's nleqslv and dfsane take 12 runs each. Iterating b ← J(b) contracts
  by 0.76 a run, about 47 runs to 1e-5. `measurements/equilibrium.md` (2026-10-05). On 201
  introductions b* = 4.676 (E1, 2026-10-21).
- **The birth-rate slope.** d ln J/d ln b = −0.75 to −0.76 at b*, so ∂F/∂ ln b = −1.75 (E5,
  `measurements/equilibrium.md`). The secant through the last two runs matches the sweep's
  column: −0.7457 against −0.7525 (roadtest §3).
- **The implicit-function warm start lands next to the curve.**
  - Moving lma 1% with ln b moved by d ln b*/d ln lma leaves \|F\| = 0.0025, against 0.10
    with b held (`measurements/equilibrium.md`).
  - On the roadtest's step uphill it predicted b* = 5.56 against a true 5.48, leaving
    \|F\| = 0.026. That keeps g within 0.4ε by E5 (roadtest §7).
- **A pinned replay costs 0.82 of the adaptive forward** and reproduces J to 12 digits. At
  lma × 1.01 the two differ by 1.4e-5 in `ln J`. `measurements/equilibrium.md`.
- **The loop's budget, *estimated*.** About 18 forwards find and classify a one-trait singular
  strategy, against about 84 for the nested loop. One step costs 2.2 forwards for one trait
  and 6.0 for every trait. Roadtest §7 (2026-10-21).
- **Two near-identical species make the community's Newton ill-posed.** Undamped, it sent a
  birth rate to 1e74. Mutual invasibility settles it instead: one equilibrium and one
  invasion. `measurements/regnans-smoke/README.md` (2026-10-20).

## Unbuilt levers

- **The sweep can halve.** Three changes take 47–51%, about 2×:
  - identity insertion rows not splitting the descent, −19%;
  - the crown's light quadrature off the tape, −20–24%;
  - the collar's slope stored, −8.5%.

  `measurements/perf-sweep.md` §4 (2026-10-05).
- **A second reverse pass for g.** The roadtest *estimates* it at about 0.3 forwards over the
  resident's tape, instead of an invader run and its sweep (roadtest §7).
- **Invader sweeps without the leaf's implicit terms.** If the envelope result holds
  (`review/theory.md` C.4, *derived*, untested), the invader's g needs none of the
  implicit-function solves, 37% of a sweep's instructions (above).
- **Adjoint rows.** Keeping the costate at every row costs +1.3–1.4% of a sweep and +35 MB,
  and is bit-identical when off. The invader's mortality identity holds to 7.6e-14. The sum
  rule reproduces the gradient to a median 0.26–0.78%. Spike only.
  `measurements/adjoint-rows/README.md` (2026-10-21).
- **The soil stepped alone.** It cuts rows 38–41% on long drought, 38–45% on episodic and
  46–64% on constant, with J within 7.4e-5 relative. With the coupling judged at the members'
  weight, every elasticity is within 0.11ε. The error floors at about 0.001ε below 3e-5.
  `measurements/soil-alone/report.log` (2026-10-07); `measurements/pathfinders/README.md`.
  plant#115's substeps took its place.
- **Thinned invaders.** Dropping an invader's members by their share of J′, emulated exactly,
  saves a median 16.5–46.6% of rows across five rules, at a largest `ln J′` error of
  0.047–0.165ε. The selection gradient's error is unmeasured.
  `measurements/pathfinders/README.md` (2026-10-04).
- **A schedule built at θ0 holds across θ.** A lean fixed schedule stays within 2.8e-3
  relative over lma × 0.7–1.2, hmat × 0.8–1.1 and stem_P50 × 0.9–1.25. Rebuilding it at
  each θ is worse. The default 108 schedule is off by −9.3% to +12.0%.
  `measurements/perf-across-theta.md` (2026-09-24, older build).

## Open bugs and unknowns

- **The sweep after a walk of several invaders raised `Incorrect length
  node_schedule_times`.** The cause: `run_mutant` replaced the patch's strategies but not its
  parameters. The fix is `measurements/equilibrium/walked_patch_fix.patch` (2026-10-05).
  **It has landed.** On aornugent/plant `develop` and `PLANT-117`, `SCM::run_mutant` calls
  `Patch::overwrite_parameters` (checked 2026-10-22). The patch's regression test is not in
  `develop`'s `test-scm.R` under its name.
- **The absolute tolerance's effect on gradients** is barely measured. E1 measured only
  `ln J` (0.02ε at 1e-4). E6 and E7 show the invader's g moving about 0.023 (about 0.1ε) at
  1e-4 (*derived* from their numbers; the roadtest calls it unmeasured). Nothing checks every
  elasticity there.
- **E8's cause is not confirmed.** The roadtest's three candidates were:
  - a real priority effect;
  - a jump in the leaf model;
  - crowns tying in the light field.

  E8 places the jump in the first introduction. The tie-density reading is *derived*, not
  tested. The constant climate's b* also moved from 24.5 to 45.1 when its schedule was
  rebuilt.
- **Not shown for the loop:** the \|F\| tolerance on climates other than long drought; the
  predictor over a sequence of steps or on constant rain; the secant's iteration count to a
  real singular strategy (roadtest §7).

## What was overturned

Every `measurements/diag-*.md` note except `diag-long-drought.md` was measured with a 5-year
patch, where the stand is near extinction (J ≈ 1e-7 to 1e-11). The verdicts at 40 years are
from `measurements/diag-long-horizon-remeasure.md` and `measurements/README.md` (2026-09-23
and 2026-10-07).

| Note (2026-09-22) | At 5 years | At 40 years |
|---|---|---|
| `diag-quadrature-order.md` | The error is a cancellation of two O(Δb²) terms; a higher-order output rule is 2.4× worse | **Overturned:** the terms share a sign, and the higher-order rule is 1.26× better |
| `diag-wrong-sign.md` | A sign-wrong gradient is two paths cancelling at condition number about 100 | **The cancellation was the horizon:** \|direct\|/\|total\| is 10.3, 3.7, 0.6 and 0.2 at 5, 10, 20 and 40 years. The amplification identity holds |
| `diag-jump-vs-floor.md` | J is a step function in θ at 0.1% rms | **Overturned:** 0.031% rms, and the one 0.44% departure goes at tolerance 1e-4 |
| `diag-gradient-aligned.md` | A finite-difference plateau needs tolerance 1e-6 | **Overturned:** a plateau exists at 1e-3, 3.5 decades wide, flat to 4.6% |
| `diag-gradient-error.md` | Gradient orders 1.8 and 1.34 | The orders were measured on unaligned grids and are contaminated; the attribution to the time grid holds |
| `diag-knot-alignment.md` | Aligning steps to the rain knots collapses a 140% gap | **Half confirmed:** the sham control holds (37.9% low against +0.3%); the near-miss does not |
| `diag-error-norm.md`, `diag-rejections.md`, `diag-schedule-refinement.md` | The environment sets 69–84% of steps; 19–28% of attempts are rejected; `schedule_eps` never fires | Hold. At 40 years 15.2% and 28.6% of attempts are rejected |

The half-order loss of gradients against values was never settled at 40 years: no order
ladder was run there.
