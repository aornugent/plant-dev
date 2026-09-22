# Neither: the gradient's lost half order is the trait-derivative of a 0.1% step in the objective

TF24 SCM, one species, `lma = 0.0825`, `max_patch_lifetime = 5`, forcing
`mixed-ordinary`, `node_density_in_birth_date = TRUE`, optimised `-O2` build,
`TESTTHAT_PARALLEL = false`, serial inside each run and four runs at a time.
`J = sum(scm$offspring_production)`.

**Every run is on an aligned time grid** -- zero-depth rainfall pulses at the 412
active knots, `events(events_default(p), rainfall_pulse(time = knots, depth = 0))`
-- because unaligned grids give answers 140% apart on step placement alone
(`diag-knot-alignment.md`). Aligned runs hold at `ode_tol = 1e-2`, so the level
sequence is cheap: **12, 23, 45, 88, 175, 349** introductions, the default 88-node
dyadic schedule coarsened three times and bisected twice. `h` below is the node
spacing in units of the default schedule's, so `h = 1` is 88 nodes.

Scripts in the scratchpad: `jf_common.R`, `jf_probe.R`, `jf_levels.R`,
`jf_levels_h.R`, `jf_scan.R`, `jf_report2.R`, `jf_split.R`, `jf_fit.R`,
`jf_tolreport.R`, `jf_compare.R`, `jf_hreport.R`, `jf_fastsweep.R`,
`jf_settol.sh`, `jf_allarms.sh`, `jf_tail.sh`, `jf_verify.R`. They build on
`ka_common.R` / `ge_common.R` from the two earlier notes.

---

## Verdict

**Mechanism (i) is refuted, decisively.** The `find_root_psi` bracket tolerance
was swept over four decades -- 1e-2, 1e-4 (shipped), 1e-6, 1e-8 -- and the thing
that stops the convergence does not move: the objective's departure from a smooth
trait curve is **0.0908%, 0.1071%, 0.1099%, 0.1098%** of `J` at the four
tolerances, and the *pattern* of that departure across 25 trait points correlates
**0.989** between 1e-4 and 1e-8. Going from the shipped 1e-4 to 1e-6 moves
`dJ/dlma` by **0.053%**, against a floor of 3%; going on to 1e-8 moves it by a
further **0.009%**, and moves `J` by 1e-9 to 1e-8 relative at 22 of the 25 trait
points -- five orders of magnitude under the floor. **There is a bracket floor and it is already 100x below the binding one
at the shipped 1e-4.**

And the experiment the brief called decisive answers the same way. The whole
six-level sequence, re-run at 1e-6 and at 1e-8: the value's order from consecutive
differences reads 0.938 / 1.399 / 3.656 / 0.437 at the shipped tolerance and
0.940 / 1.398 / 3.661 / 0.453 at both tightened ones; the gradient's reads
3.883 / 0.116 / 1.105 / 0.762 against 3.881 / 0.113 / 1.098 / 0.617 at 1e-6 and
3.881 / 0.113 / 1.099 / 0.612 at 1e-8. The two tightened arms agree with each
other to three decimals everywhere but the last entry, where they differ by
0.005, so the bracket's contribution is converged two decades below what ships;
**the order does not recover, it does not move.**

**Mechanism (ii) is refuted too, in the form stated.** A first-order trapezium
term at a switching front would be *localised in birth date* and would *shrink as
O(db)*. Measured per cohort, the derivative's error against the finest level is
neither: it is a **uniform multiplicative offset across every birth date**, equal
to four significant figures at the earliest cohort and at the latest, and it does
not shrink -- -12.3%, -17.5%, -2.65%, +3.03%, -3.42% at 12, 23, 45, 88, 175 nodes.
No `C1 db` coefficient survives a fit: the three-parameter model
`Q = Q* + C2 h^2 + C1 h` is rejected at chi-squared per degree of freedom of
28 to 220 on every window tried, weighting each level by the measured floor.

**Stated with the limit it deserves:** a floor cannot prove the absence of a term
underneath it. What this fixture shows is that any `C1 db` in the gradient is
**below 1-3% of the gradient at the default 88-node schedule** -- smaller than the
floor sitting on top of it, and therefore not what costs the order. Refining the
grid cannot reach it, which is the practical form of the same statement.

**What is actually there.** One floor, in the forward solution, of **0.1% rms
(0.27% peak) in `J`**, which the finite difference divides by the trait step and
hands to the gradient as **3%**. The objective is not smooth in `lma` at the 0.1%
level: a 25-point scan at 45 nodes shows a smooth trend with two step
discontinuities of 0.3-0.4% in it, and the step sits where the population of
constrained solves reorganises (the non-interior share moves in blocks of
0.4-0.5 percentage points between trait points 0.25% apart). The gradient is the
trait-derivative of that step, so it inherits the step divided by the trait
window: with `dln J / dln lma = -2.88` and a floor `eps ~ 0.25%` whose own
variation across the difference window is `d eps / d ln lma ~ 0.09`, the predicted
relative error in `dJ/dlma` is `(d eps / d ln lma) / 2.88 = 3.1%`. **Measured:
2.7-3.4%.**

So the gradient's order is not lower than the value's by half an order. On this
fixture the gradient has **no order at all past 23 nodes** -- its error stops
falling and alternates in sign, which is the brief's RANDOM-FLOOR signature, and
not the JUMP signature the stable 1.34 was read as. The 1.34 was measured on
*unaligned* grids in the *height* coordinate; see *Where 1.87 / 1.34 came from*.

**In what proportion, since the brief asks.** Of the gradient's ~3% error at the
default schedule: the inner bracket accounts for **0.05%** (what 1e-4 -> 1e-6
moves it, and 1e-6 -> 1e-8 adds 0.009% more), so **under 2% of the total**; no
`C1 db` jump term is detectable at all, and any that exists is under 1-3%, which
is to say under the floor; and the remaining ~98% is the trait-discontinuity
below, which no knob tried moves. On this fixture the two candidate mechanisms
together explain at most a fiftieth of what is there.

**Remedy.** Neither "tighten an inner tolerance" nor "refine the cohort grid".
Both are answers to questions this fixture does not ask. What limits the gradient
is a 0.1% discontinuity of `J` in the trait, and the two things that would move it
are (a) removing the discrete branch that makes it -- `hydraulic-shutdown` is the
only operating point that clamps state rather than moving it continuously, and it
is still firing on 0.16-0.63% of solves -- and (b) not taking the gradient by
finite differences, which is what multiplies 0.1% into 3%.

---

## 1. The level sequence, and the order read two ways

Six levels, aligned grids, `ode_tol = 1e-2`. `dJ/dlma` is a least-squares cubic
through five trait points (`lma0`, `lma0(1 +/- 0.01)`, `lma0(1 +/- 0.03)`); see
*The finite-difference step has to clear the floor* for why the 1e-3 and 1e-4
steps the earlier note used cannot be read here.

| nodes | h | `J` | err vs 349 | ord(diff) | ord(ref) | `dJ/dlma` | err vs 349 | ord(diff) | ord(ref) |
|---|---|---|---|---|---|---|---|---|---|
| 12 | 7.909 | 1.35316311e-08 | -7.456e-09 (35.5%) | 0.94 | 1.26 | -1.19054093e-06 | -4.982e-07 (72.0%) | 3.88 | 5.84 |
| 23 | 3.955 | 1.78776653e-08 | -3.110e-09 (14.8%) | 1.40 | 1.88 | -6.83688448e-07 | +8.693e-09 (1.26%) | 0.12 | -1.56 |
| 45 | 1.977 | 2.01456304e-08 | -8.423e-10 (4.01%) | 3.66 | 5.56 | -7.18040744e-07 | -2.566e-08 (3.71%) | 1.11 | 2.09 |
| 88 | 1.000 | 2.10058065e-08 | +1.783e-11 (0.085%) | 0.44 | -1.50 | -6.86333890e-07 | +6.047e-09 (0.87%) | 0.76 | -0.52 |
| 175 | 0.500 | 2.09375715e-08 | -5.041e-11 (0.240%) | | | -7.01071033e-07 | -8.690e-09 (1.26%) | | |
| 349 | 0.250 | 2.09879780e-08 | 0 | | | -6.92381264e-07 | 0 | | |

**The value.** Its error falls by **2.40, 3.69, 47** -- an order climbing toward 2
as the asymptotic regime is entered, which is the shape a second-order trapezium
has on a non-uniform grid -- and then stops at **0.085-0.24% of `J`**, where it
changes sign between levels. The "5.56" and "-1.50" in the last column are that
floor, not a method.

**The gradient.** Its error falls by 57 on the first refinement and then **does
not fall again**: 1.26%, 3.71%, 0.87%, 1.26% of the gradient, alternating in sign.
There is no window of two consecutive halvings over which it decays, and **only
one level (12 nodes) sits above the floor at all**.

This is the brief's second discriminator, not the third. A monotone slide from 2
toward 1 that then holds is not present. Neither is a constant floor's signature
(order from differences holding at `p` while order against a fixed reference
slides toward 0) -- against the finest level the value reads 1.26, 1.88, 5.56,
-1.50, which is a rise and then a sign change, not a slide. What is present is the
**random floor**: the order from differences turns erratic as soon as the
level-to-level change approaches the floor's scatter. For the gradient that
happens at the first refinement, because the floor reaches it multiplied by 11.6.

### The fit, and why no coefficient survives

`Q(h) = Q* + C2 h^2 + C1 h`, weighted least squares with each level's uncertainty
set to the floor the trait scan measured (0.107% of `J`; the gradient's is that
divided by the difference window):

| sequence | levels | `C2` | `C1` | chi2/dof | chi2/dof, `C2` alone |
|---|---|---|---|---|---|
| `J` | all six | -4.46e-11 (2.3e-11) | -6.45e-10 (1.9e-10) | **220** | 802 |
| `J` | 12-88 | -7.57e-12 (1.4e-11) | -1.02e-09 (1.3e-10) | **40** | 1342 |
| `dJ/dlma` | all six | -1.51e-08 (2.9e-09) | +6.19e-08 (2.5e-08) | **28** | 66 |
| `dJ/dlma` | 12-88 | -1.80e-08 (5.7e-09) | +9.10e-08 (5.3e-08) | **55** | 107 |

A chi-squared per degree of freedom of 28 to 220 says the three-term model is
rejected on every window (and 66 to 1342 says the same of the two-term one), so
the standard errors beside the coefficients are not standard errors of anything.
Read literally the fit wants a large `C1` and a small `C2` -- but that is an
artefact of including `h = 7.9`, where the expansion does not hold: the *observed*
error ratios climb toward 4 (order 2), which is the opposite of what a dominant
`C1 h` would do. **Neither `C2` nor `C1` is estimable on this fixture**, because
there is no window where a power law holds: the coarse levels are pre-asymptotic
and the fine levels are floored, with at most one level between.

## 2. Splitting the derivative

### What could not be done

**The gradient cannot be restricted to constrained-branch cohorts.**
`operating_point_counts` (`tf24_strategy.h:1354`) is a run-level tally indexed by
the enum -- one vector of counts per strategy, cleared per run -- so it says how
many leaf solves landed on each branch and nothing about which cohort or which
instant. Nothing else in the R surface carries a per-cohort branch record: the
aux vector (`aux_names()`, `tf24_strategy.h:820`) carries `opt_psi_stem`,
`opt_root_psi`, `transpiration` and `profit` per cohort at the current time, but
not the classification, and a cohort's branch over its whole life is not recorded
anywhere. Exposing it is a small change (the tally is already per-solve at
`tf24_strategy.h:2456`) and would make this decomposition direct.

### What was done instead, and it is enough to decide

`J` is `util::trapezium` over the birth dates of
`fecundity_i * patch_density(t_i) * S_D * birth_rate(t_i)` (`patch.h:917`), and
the three weights are functions of the birth date alone, so the per-cohort
integrand `g_i` reconstructs `J` to 3e-16 relative. Levels are nested bisections,
so every coarse level's birth dates are a subset of the finest level's and `g_i`
and `dg_i/dlma` can be compared **at the same birth date across levels**. That
separates the quadrature from the trajectory: a trapezium error lives in the
weights, a trajectory error lives in `g_i` itself.

Relative error of the per-cohort integrand against the 349-node level:

| nodes | value `g_i`: median / p90 / max | derivative `dg_i/dlma`: median / p90 / max |
|---|---|---|
| 12 | 44.8% / 71.1% / 99.2% | 12.5% / 30.8% / 63.9% |
| 23 | 18.1% / 24.0% / 28.9% | 17.6% / 21.4% / 26.0% |
| 45 | **5.02%** / 6.41% / 9.16% | **2.68%** / 3.56% / 12.9% |
| 88 | **0.170%** / 0.588% / 12.6% | **3.03%** / 4.84% / 22.7% |
| 175 | **0.296%** / 0.323% / 0.471% | **3.42%** / 3.88% / 13.2% |

**The value integrand converges and the derivative integrand does not.** And the
error is not localised: at 88 nodes the first four cohorts carry -0.00159,
-0.00159, -0.00159, -0.00159 on the value and +0.0303, +0.0303, +0.0303, +0.0303
on the derivative -- the same relative offset to four significant figures at birth
dates a whole quarter-year apart -- and the median over all 82 shared cohorts is
0.0017 and 0.0303. It is a **uniform multiplicative offset on the whole field**,
which is what a shift in the shared canopy does (every cohort reads the same
light) and is not what a jump at a switching front does.

The trapezium contributions by birth-date band say the same thing from the other
side. At every level **97-100% of `dJ/dlma` comes from birth dates in [0, 0.25]**
(the stand is ten orders short of self-replacing at lifetime 5, so only the
earliest cohorts reproduce); the band errors against the finest level are
-2.1e-8, +1.0e-7, +1.9e-8, -2.1e-8, +2.4e-8 for that band -- sign-alternating, not
decaying -- and the per-band "orders" are 0.58, 1.02, -0.17, 0.90.

### The arithmetic that ties the two floors together

Write the level-`h` solution as `g_h(theta) = g_*(theta) (1 + eps_h(theta))`. Then

```
relative error in dg/dtheta  =  eps_h  -  (d eps_h / d ln lma) / (d ln g / d ln lma)
```

with `d ln g / d ln lma = -2.88` (measured: `dJ/dlma = -7.07e-07`, `J = 2.01e-08`,
`lma = 0.0825`). Solving for `d eps / d ln lma` from the measured pairs gives
**-0.092 at 88 nodes and +0.090 at 175 nodes** -- so `eps` swings by 0.0055 across
the 0.06 of `ln lma` the difference spans, against an `eps` of only 0.002-0.003
itself. That is exactly the 25-point trait scan's picture: a floor that is not a
constant offset but a rapidly varying, sign-changing function of the trait at the
0.1-0.3% scale. **The gradient's 3% floor is the value's 0.25% floor
differentiated, and nothing else.**

## 3. The floor, measured directly: 25 trait points at one grid

Levels differ in grid, so an error against a reference conflates the floor with
the refinement. The floor on its own is read at **one fixed grid** (45 nodes) from
`J` at 25 values of `lma` spanning `+/- 3%`, as the scatter about a smooth trait
curve (a cubic; a quintic gives 0.091%).

- **rms residual 0.1071% of `J`, peak 0.267%.**
- Not white: lag-1 autocorrelation **0.46**, and the residual is a smooth drift
  broken by two steps -- `+1.78e-3 -> -2.19e-3` between `lma0(1-0.0075)` and
  `lma0(1-0.0050)`, and `-2.34e-3 -> -3.04e-4` between `lma0` and
  `lma0(1+0.0025)`. **`J` has step discontinuities in the trait of 0.3-0.4%.**
- The non-interior share of leaf solves moves in blocks over the same scan --
  12.64, 12.16, 12.17, 12.17, 12.59, 12.60, 12.55, 12.42, 12.65, 12.10, 12.07 %
  -- jumping 0.4-0.5 percentage points between trait points 0.25% apart, and the
  accepted step count moves with it (1238, 1229, 1230, 1229, 1234, 1235, 1238).
  The stand reorganises discretely under a trait perturbation far smaller than the
  reorganisation.

**It is not the ODE tolerance.** The same 25-point scan at `ode_tol = 1e-3`
(ten times tighter, same aligned grid) gives **0.1030%** rms -- unchanged -- even
though the individual values move by up to 0.4%. This reproduces
`diag-knot-alignment.md`'s finding that an aligned run is at its floor by
`ode_tol = 1e-2` and does not improve over five further decades, and extends it:
the floor is not merely a level, it is a *non-smoothness in the trait*.

### The finite-difference step has to clear the floor

With `dln J/dln lma = -2.88`, a relative trait step `d` moves `J` by `2.88 d`.
The floor is 0.1%, so `d = 1e-3` gives a signal of 0.29% against 0.1% of scatter
and `d = 3e-4` gives 0.09% against 0.1% -- **the step sizes the earlier note used
are at or under the noise here**. Measured, at 349 nodes: `d = 1e-3` returns
-1.84e-06 and `d = 3e-4` returns -7.40e-07, a factor of 2.5 apart, and the
`d = 1e-3` sequence across levels is -7.98e-7, -6.20e-7, -7.23e-7, -3.19e-7,
-6.97e-7, -1.84e-6 -- noise. At `d = 0.03` the signal is 8.7% and the sequence is
readable. Everything above uses the wide-step estimator.

## 4. The decisive experiment: four decades of the inner bracket

`find_root_psi` (`phylloptim/inst/include/phylloptim/leaf_model.hpp`, the two
`uniroot_smooth` calls at lines 3173 and 3186) passes a hard-coded
`1e-4` as **both** absolute and relative tolerance to `internals::uniroot_tol`
(`uniroot.hpp:15`), so TOMS748 stops when the bracket is narrower than
`1e-4 + 1e-4 |x|` and the returned root is the bracket midpoint
(`uniroot.hpp:81`). Over the collar's operating range (`psi_crit = 5.91988`,
`root_psi_crit = 5.870283` MPa) that is a half-width of 1e-4 to 3e-4 MPa, i.e. a
relative precision of about 5e-5 in the collar. Both ends of the feasible interval
come from it: `bound_a = root_zero_E = find_root_psi(..., 0)` and
`bound_b = min(root_crit, root_psi_crit)` with
`root_crit = find_root_psi(..., 1)` (`leaf_model.hpp:3349-3360`). On the interior
branch the optimum is refined inside `[lo, hi]` at `collar_root_tol = 1e-12`
(`leaf_model.hpp:395, 3737`) and the bound drops out; on `boundary-crit` and
`boundary-soil` the answer **is** the bound. So the brief's description of the
mechanism is accurate in every detail. It is simply not what limits the gradient
at the tolerance that ships.

**How it was swept.** The literal was replaced by a file-local
`collar_bracket_tol()` reading `PHYLLOPTIM_COLLAR_BRACKET_TOL` once per process
and defaulting to 1e-4, so one rebuild covers every tolerance
(`plant` compiles against `phylloptim`'s *installed* headers and `pkgbuild`
tracks no dependency on them, so each literal change would otherwise cost a full
`rm src/*.o` rebuild). **The hook is inert at the default**: 45 nodes with the
variable unset gives `J = 2.014563038988e-08` against the pre-change build's
`2.014563038988340e-08`, and the same operating-point shares to five decimals.
The change is reverted; see *Guards and what was left behind*.

The 25-point trait scan at 45 nodes, repeated at each bracket tolerance:

| bracket tolerance | rms resid / `J` | peak resid / `J` | `dJ/dlma` | mean non-interior |
|---|---|---|---|---|
| 1e-2 (loosened 100x) | **0.0908%** | 0.238% | -6.85992e-07 | 11.948% |
| **1e-4 (shipped)** | **0.1071%** | 0.267% | -7.06749e-07 | 12.224% |
| 1e-6 (tightened 100x) | **0.1099%** | 0.254% | -7.07124e-07 | 12.202% |
| 1e-8 (tightened 10000x) | **0.1098%** | 0.254% | -7.07190e-07 | 12.202% |

**The floor does not move.** Four decades, and the scatter is flat within its own
sampling error -- it is if anything *smaller* at the loosened 1e-2, which is the
opposite of a bracket-midpoint floor. The residual *pattern* across the 25 trait
points correlates **0.989** between 1e-4 and 1e-8: the two arms are floored by the
same object, at the same trait points, by the same amount. (At 1e-2 the
correlation falls to 0.37 and `dJ/dlma` moves 2.9%, so the bracket is a real
source -- it is just already 100x under the floor two decades earlier, at the
tolerance that ships.)

Point by point, `J` at 1e-6 against `J` at 1e-8 agrees to **1e-8 relative** at 22
of the 25 trait points. `J` at 1e-4 against 1e-8 differs by 1e-6 typically and by
5e-4 at four points -- the four nearest the step. So the shipped bracket does
occasionally tip a switch, and tightening it moves *which* trait points step
without changing how big the steps are or how many there are.

### The level sequence, re-run at 1e-6 and 1e-8

The whole six-level sweep, repeated at each tolerance. This is the experiment the
brief asked for, and it answers in one line: **the order does not move.**

| | 12 | 23 | 45 | 88 | 175 | 349 |
|---|---|---|---|---|---|---|
| `J`, bracket 1e-4 | 1.35316311e-08 | 1.78776653e-08 | 2.01456304e-08 | 2.10058065e-08 | 2.09375715e-08 | 2.09879780e-08 |
| `J`, bracket 1e-6 | 1.35322535e-08 | 1.78792919e-08 | 2.01454916e-08 | 2.10055254e-08 | 2.09375391e-08 | 2.09871997e-08 |
| `J`, bracket 1e-8 | 1.35322545e-08 | 1.78792909e-08 | 2.01454917e-08 | 2.10055255e-08 | 2.09375391e-08 | 2.09871889e-08 |
| `dJ/dlma`, 1e-4 | -1.19054093e-06 | -6.83688448e-07 | -7.18040744e-07 | -6.86333890e-07 | -7.01071033e-07 | -6.92381264e-07 |
| `dJ/dlma`, 1e-6 | -1.19051083e-06 | -6.83686398e-07 | -7.18083261e-07 | -6.86274159e-07 | -7.01131384e-07 | -6.91443406e-07 |
| `dJ/dlma`, 1e-8 | -1.19051112e-06 | -6.83686432e-07 | -7.18085579e-07 | -6.86287533e-07 | -7.01131394e-07 | -6.91420896e-07 |

Order from consecutive differences (each arm against its own sequence):

| | 12-23-45 | 23-45-88 | 45-88-175 | 88-175-349 |
|---|---|---|---|---|
| `J`, 1e-4 | 0.938 | 1.399 | 3.656 | 0.437 |
| `J`, 1e-6 | 0.940 | 1.398 | 3.661 | 0.453 |
| `J`, 1e-8 | 0.940 | 1.398 | 3.661 | 0.453 |
| `dJ/dlma`, 1e-4 | 3.883 | 0.116 | 1.105 | 0.762 |
| `dJ/dlma`, 1e-6 | 3.881 | 0.113 | 1.098 | 0.617 |
| `dJ/dlma`, 1e-8 | 3.881 | 0.113 | 1.099 | 0.612 |

Order against each arm's own finest level:

| | 12 | 23 | 45 | 88 |
|---|---|---|---|---|
| `J`, 1e-4 / 1e-6 / 1e-8 | 1.261 / 1.262 / 1.262 | 1.885 / 1.885 / 1.885 | 5.562 / 5.521 / 5.521 | -1.499 / -1.438 / -1.437 |
| `dJ/dlma`, 1e-4 / 1e-6 / 1e-8 | 5.841 / 6.008 / 6.012 | -1.562 / -1.780 / -1.786 | 2.085 / 2.366 / 2.377 | -0.523 / -0.906 / -0.920 |

**1e-6 and 1e-8 agree to three decimals in every order but one (0.617 against
0.612)**, so the bracket's own
contribution is fully converged two decades below the shipped value; and both
differ from 1e-4 by under 0.02 in the value's order and under 0.15 in the
gradient's -- and in the direction of slightly *lower*, not higher. The gradient's
error stays at **1.13%, 3.86%, 0.75%, 1.40%** of the gradient at 1e-8, against
1.26%, 3.71%, 0.87%, 1.26% at 1e-4.

**It was not the floor in the sense mechanism (i) means. Tightening the bracket
recovers nothing.**

## 5. Where 1.87 / 1.34 came from, and why they are not here

The stated measurement -- `J` at ~1.87 and `dJ/dtheta` at ~1.34 -- is from
`diag-gradient-error.md`'s coarsened-schedule study on `mixed-ordinary`. It was
taken on the **height** size-density coordinate and on a union-of-adaptive-programs
time grid that was **not knot-aligned**, and it rests on two decay ratios (3.60
and 3.70 for the value, 2.51 and 2.58 for the gradient) at `d = 1e-3`. On the
aligned birth-date fixture the brief specifies, `d = 1e-3` is under the floor
(*section 3*) and neither number reproduces: the value's order climbs 0.94, 1.40
rather than sitting at 1.87, and the gradient has no order at all.

Two things differ and both matter, so this note does not claim the earlier
numbers were wrong -- it claims they are a different measurement:

- **The coordinate.** `node_density_in_birth_date = TRUE` makes the birth date the
  abscissa of *both* trapezia -- the fitness integral (`patch.h:903`) and the
  competition reduction that builds the canopy (`species.h:632`, via
  `abscissa_of`, `species.h:326`) -- so refining the schedule refines the
  environment quadrature too. On the height coordinate the competition abscissa is
  the moving height and the two are not the same grid. `J` differs by a factor of
  285 between the coordinates on this fixture (2.10e-08 against 7.36e-11), so they
  are not two estimates of one number.
- **The grid.** Unaligned, the same model at the same cohort count gives answers
  140% apart on step placement alone.

**The height arm, run here for the comparison** (same aligned grids, same levels,
same wide-step estimator, `node_density_in_birth_date = FALSE`):

| nodes | 12 | 23 | 45 | 88 | 175 | 349 |
|---|---|---|---|---|---|---|
| `J` | 7.99905615e-11 | 9.08583551e-11 | 7.42256856e-11 | 7.36054141e-11 | 7.35860287e-11 | 7.40627459e-11 |
| `dJ/dlma` | -3.59156591e-09 | **+2.52974835e-09** | -3.30068144e-09 | -3.28413021e-09 | -3.42100622e-09 | -3.50156627e-09 |

`J` at 88 nodes is `7.3605e-11`, which is `diag-knot-alignment.md`'s aligned
answer to three digits, so the fixture is the same one. And the picture is the
same as the birth-date arm, only worse: the gradient's error against the finest
level is 2.57%, **172%** (the sign flips at 23 nodes), 5.74%, 6.21%, 2.30% -- a
floor of 2-6% with an outright sign reversal in it. **Neither 1.87 nor 1.34
reproduces on either coordinate once the grid is aligned**, and on neither
coordinate does the gradient have an order.

## 6. What the floor is made of, as far as this fixture can say

Not the bracket (*section 4*) and not the ODE tolerance (*section 3*). What is
left, and what the evidence points at without pinning:

**A discrete branch is still firing.** Of the operating points, `boundary-crit`
and `boundary-soil` are *continuous* constraints -- the optimum slides onto the
bound and off it without the answer jumping -- but `hydraulic-shutdown`
(`leaf_model.hpp:3241`) clamps the stem at `psi_crit`, sets transpiration and
stomatal conductance to zero and pays `no_flow_profit`. It is a genuine
discontinuity in the leaf's output as a function of its input. Aligned, at
`ode_tol = 1e-2`, its share falls with refinement but does not vanish:

| nodes | interior | boundary-crit | determined | **hydraulic-shutdown** |
|---|---|---|---|---|
| 12 | 91.098% | 8.066% | 0.204% | **0.6277%** |
| 23 | 90.335% | 9.000% | 0.218% | **0.4463%** |
| 45 | 87.353% | 12.148% | 0.164% | **0.3339%** |
| 88 | 86.803% | 12.814% | 0.171% | **0.2117%** |
| 175 | 85.428% | 14.216% | 0.157% | **0.1980%** |
| 349 | 86.006% | 13.695% | 0.136% | **0.1624%** |

(`boundary-root-crit` is 6.5e-4 to 4.1e-3 % throughout; `unsolved`,
`boundary-soil`, `shade-death`, `prescribed`, `solver-refused` and
`non-finite-gradient` are exactly zero at every level.) The
brief's "14% of member-instants constrained" is the non-interior share at the fine
levels -- 14.0% at 349 nodes -- and it is `boundary-crit` almost entirely.

**The step in `J` and the branch census move together, but not proportionally.**
Over the 25-point trait scan the non-interior share swings 11.67% to 12.65% in
discrete blocks and the shutdown share 0.324% to 0.334%; the correlation of the
residual with the non-interior share is -0.28 and with the accepted step count
-0.45, so the census is reorganising on the same trait scale as the step but no
single scalar predicts it. What this fixture can say is that the reorganisation is
**discrete** and **not caused by either tolerance tested**.

**What would settle it.** A per-cohort, per-instant branch record (the tally at
`tf24_strategy.h:2456` already has the information at the point of the solve)
would let the trait scan be differenced branch by branch and say directly whether
the step is a shutdown flipping. Failing that, forcing `hydraulic-shutdown` never
to fire -- on this fixture it is under 0.2% of solves at the fine levels, so the
run is nearly reachable without it -- and re-running the scan would decide it in
one measurement.

## 7. Is 0.1% on `J ~ 2e-08` worth chasing?

**As a statement about the gradient, yes**, because the finite difference
multiplies it by 11.6 and the answer an optimiser gets is then 3% wrong however
fine the cohort grid. **As a statement about the model, no** -- `J << 1`
everywhere on this fixture, the stand is orders short of self-replacing, and that
is `max_patch_lifetime = 5` under a record with a 130-day dry run, not the
integrator. Nothing measured here is a viable stand. What makes it worth reporting
is that the same 0.1% trait-discontinuity would floor a gradient on a fixture
where `J` does matter, and it is invisible to every knob tried: cohort count, ODE
tolerance, and the inner bracket.

## 8. Method notes worth carrying forward

**The reverse-mode adjoint does not answer on this fixture.** `stand_gradient(scm)`
runs and refuses all three census metrics with
`[phylloptim:infeasible:stem_curve_domain] cumulative_vulnerability_integral_derivatives_at:
(psi/b)^c = 2863022.99 is past the vulnerability curve's domain (4.605170)`. So
every gradient here is a finite difference, as in `diag-gradient-error.md`, and
the 11.6x amplification of the value's floor is not avoidable by taking a
different estimator of the same difference. It would be avoidable by an adjoint,
which is the strongest argument in this note for making one reach `J`.

**`J` reconstructs from its per-node parts exactly**, which is what makes the
birth-date decomposition trustworthy:
`sum(trapezium_weights * fecundity_i * patch_density(t_i) * S_D)` against
`sum(scm$offspring_production)` agrees to **3.2e-16** relative. `birth_rate` is
the constant 1.0 at TF24's defaults (`strategy.h:95`) and `S_D = 0.25`;
`patch_density` comes from `scm$patch$density(t)`.

**Levels.** The default 88-node schedule is a dyadic staircase
(`scm_utils.cpp:6`). Coarsening takes every other introduction and keeps the
endpoint (88 -> 45 -> 23 -> 12); refining bisects every interval (88 -> 175 ->
349). The levels are nested, which is what lets a per-cohort quantity be compared
at the same birth date across levels.

**Cost.** On the aligned grid at `ode_tol = 1e-2`, one run is 5 s at 12 nodes and
100 s at 349; a whole six-level sweep with five trait points per level is about
four minutes on four cores. That is cheap enough to repeat per tolerance, which is
what made the bracket sweep affordable.

## What is missing

- **A per-cohort branch record.** The one decomposition the brief asked for and
  this note could not do (*section 2*). The information exists at the point of the
  solve; the tally throws away everything but the count.
- **One forcing, one trait.** `mixed-ordinary` and `lma` at 0.0825 throughout
  (both coordinates were run). Whether the 0.1% trait-step is the same size on
  `moist-drizzle` (2.6% non-interior) or `constant 3.0` (0%) is the obvious next
  measurement and the cheapest one left: it would say directly whether the floor
  scales with switching activity, which is the one prediction mechanism (ii)
  makes that this note has not tested.
- **No adjoint.** `stand_gradient` refuses on this fixture, so every gradient here
  carries the 11.6x amplification. If the sweep answered, the floor's effect on
  the gradient would be `eps` rather than `eps / (0.03 * 2.88)`, which is the
  difference between 0.25% and 3%.
- **`hydraulic-shutdown` is named as the suspect but not convicted.** It is the
  only discontinuous branch still firing and its share tracks the refinement, but
  no measurement here shows a specific step in `J` coinciding with a specific
  shutdown flipping.

## Guards, and what was left behind

**The change.** `phylloptim/inst/include/phylloptim/leaf_model.hpp` only, the two
`find_root_psi` tolerance literals, replaced by a file-local
`collar_bracket_tol()` reading `PHYLLOPTIM_COLLAR_BRACKET_TOL` and defaulting to
1e-4, plus `#include <cstdlib>`. Reinstalled `phylloptim`, then rebuilt `plant`
with `rm -f src/*.o` first, because `plant` compiles against `phylloptim`'s
installed headers (`-I/usr/local/lib/R/site-library/phylloptim/include`) and
`pkgbuild::compile_dll` tracks no dependency on them -- without clearing the
objects, `make` reports success and the .so still carries the old tolerance.
Clearing the objects is not enough either: with `src/plant.so` still in place and
no source under `plant/src` newer than it, `compile_dll` decides there is nothing
to do and exits 0 having compiled nothing. Either delete the .so as well, or call
`pkgbuild::compile_dll(".", force = TRUE, compile_attributes = FALSE, debug =
FALSE)`, which is what the revert used so a valid library stayed in place for the
other work on the machine until the relink.

**Inert at the default**, checked before anything was measured on it: 45 nodes
with the variable unset gives `J = 2.014563038988e-08` against the pre-change
build's `2.014563038988340e-08`, the same accepted step count, and the same
operating-point shares to five decimals; and the 25-point trait scan at the
default reproduces the pre-change build's rms residual to four digits (0.1071%).

**The change is reverted**: `git checkout` on the one header, `phylloptim`
reinstalled from the reverted source (the installed copy no longer contains
`collar_bracket_tol`), and `plant` rebuilt against it. Nothing was committed and
nothing was pushed, to any remote. `odelia` and `plant` were not edited at any
point; both stay clean at `claude/trusting-curie-4i9n3l` (`be3e2cb` /
`5321593a`), and `phylloptim` is clean again at `378b083`. The reverted build
reproduces the pre-change number **bit for bit**: 45 nodes gives
`J = 2.014563038988340e-08` against the same, 1235 accepted steps against 1235,
and an identical operating-point tally. The relinked `plant.so` is also the
original's size to the byte (108 186 328, against the hook build's 108 186 472).

**Guard runs.**

- `odelia`: `make test-cpp` -- **all checks passed**.
- `odelia`: `tests/testthat/test-implicit-value.R` -- **1 passed, 5 errors**, the
  documented pre-existing `sourceCpp` failures, unchanged.
- `plant` fast sweep, the 39 files outside the three heavies -- **no failures and
  no errors in any file**, 12 tests skipped across 8 files (the `*-ad` kernels,
  the demo and gateway files, `test-model-version.R`), which is the sweep's
  ordinary shape. `test-strategy-ff16.R` and
  `test-strategy-ff16-reference-comparison.R`, the bit-identity tripwire, pass.
- The two known `test-mutant.R` failures and the TF24 heavies were not run: the
  measurement changed no shipped number (the hook is inert at the default), and
  the machine was shared with other work throughout.

**No reference test moved**, which is the expected result of an inert hook rather
than evidence about the tolerance. A permanent 1e-6 would move numbers -- `J` at
45 nodes goes from `2.01456304e-08` to `2.01454916e-08`, 6.9e-6 relative -- so
`plant`'s TF24 reference comparisons would need re-baselining if it were adopted.
**It should not be adopted on this evidence**: it buys 0.05% on `dJ/dlma` against
a floor 60x larger, at 2-4 extra `E_from_Soil` evaluations per collar solve on a
path `plant` runs millions of times.

**A note on the machine.** Two other measurements (`ga_order.R`, `ld_ladder2.R`)
were running in this workspace throughout, at a load average of 10-13 on four
cores. They share `plant`'s `.so`, so the rebuild had to be inert for their sake
as well as this note's, which it is; the only cost here was wall time.
