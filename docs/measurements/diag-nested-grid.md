# One grid with two kinds of point: what a creation costs, what the refinement indicator reads, and where the quadrature error actually is

TF24 SCM, one species, `lma = 0.32`, `max_patch_lifetime = 40`,
`node_density_in_birth_date = TRUE`, forcing `long-drought` (the 41-year daily
seasonal Markov-chain gamma record of `diag-long-drought.md`, 14 599 daily
control points in range, 1095 mm/yr, 9.5% wet days, three multi-year droughts,
driest year 182 mm), 108 creations in the default schedule, `ode_tol_rel =
ode_tol_abs = 1e-3`, aligned — a zero-depth rainfall pulse at each of the 2931
active knots, which is what keeps the forcing quadrature out of the answer
(`diag-unaligned-refusals.md`). `J = sum(scm$offspring_production)`; the TF24
default birth rate is 1, so `J` is the net reproduction ratio.

Reproduction check, run first: `J = 12.0526222` at 9931 steps, against
`diag-long-drought.md`'s and `diag-long-horizon-remeasure.md`'s `12.05262216`
at 9931. Every digit and the same step count.

**No code under `plant/`, `odelia/` or `phylloptim/` was changed and nothing was
compiled.** `plant/src/plant.so` read `2026-09-22 12:52:40.069214118 +0000`
before and after every measurement block and never moved. This note was asked
for uncommitted and the work described here ran no `git commit` and no
`git push`; it was nonetheless committed and pushed as `f8b035f` to
`origin/claude/trusting-curie-4i9n3l` by another actor at 04:42 while it was
still being written, as happened to `diag-unaligned-refusals.md`. The §5
tolerance ladder and this paragraph postdate that commit and are uncommitted. Everything below is
scripts in the scratchpad, listed in §10. `ld_common.R` and `lh_common.R` are
sourced unchanged and every original beside them is untouched.

---

## The six numbers

| | |
|---|---|
| **Where the quadrature error is** | The drop-one error on `J` totals **17.27% of `J`** at the default 108 nodes. **2.05% of it** sits at `b < 1`, where **76 of the 108 nodes** are. **14.2%** sits on four nodes, `b = 7, 8, 9, 10`. |
| **What the integrand does** | It is **discontinuous**. `w(b)` is exactly **0** wherever a seedling born at `b` cannot make carbon — `establishment_probability` returns a hard zero there — and the bands where that happens are **23 days to 6 months wide**, set by the rain in the preceding month (median 0.00 mm at the failures against 59.88 at the survivors, `p = 6.5e-8`). Across the widest one `w` runs `0.388 → 0 (half a year) → 1.561`, its largest value past `b = 1`. |
| **What that costs the grid** | At the same creation count, **205 nodes placed at 1/16-year spacing over `[5, 11]` give `J = 12.606` against 215 uniformly bisected nodes' `12.089`** — 4.3% apart, and four fifths of the way to the 429-node answer. Placement, not count. |
| **Which term flags** | The competition (`area_leaf`) term sets the indicator's max on **106 of 106** finite nodes. The reproduction (`seed_rain`) term — the one that reads `J`'s own quadrature — sets it on **none**, and alone would flag 3 nodes where the combined indicator flags 17. |
| **Cost against position** | Run cost is 956 923 member-evaluations. The **44 cohorts born below `b = 0.01`** — 0.025% of the horizon — carry **45.5%** of it and **1.35%** of `J`. A creation at `b ≈ 0` costs **367×** what a forced stop at the same time costs; at `b = 38`, 5×. Deleting 54 of the 108 creations, all below `b = 0.1`, runs **2.09× faster** and moves `J` by **+0.0032%**. |
| **Step insertion** | Not the story. Capturing a step program at 429 creations and replaying it at 108 holds the time grid bit-identical: the creation grid then moves `J` **+7.95%** while the time grid alone moves it **+0.16%**. The 17 stops the loop's first bisection would force, inserted alone, move `J` **+0.0050%** against the bisection's **+0.368%**. |

---

## 1. The machinery, read off the source

### The generator

`node_schedule_times_default(max_time)` (`plant/src/scm_utils.cpp`) walks a clock:
`dt = exp2(floor(log2(0.2 t)))` clamped to `[1e-5, 2]`, starting at `t = 0`, one
time per step, the last dropped. At `max_time = 40` it returns **108 times**, the
last at `t = 38`. The spacing doubles every five legs — 19 distinct `dt` values,
five legs each except eight at the `1e-5` clamp and fourteen at the `2.0` clamp.

It is a function of the clock and of nothing else. It does not read the forcing,
the strategy, or any previous run.

| | count | span |
|---|---|---|
| creations with `b < 0.01` | 44 (40.7%) | 0.025% of the horizon |
| `b < 0.1` | 60 (55.6%) | 0.25% |
| `b < 0.2` | 65 (60.2%) | 0.50% |
| `b < 1` | 76 (70.4%) | 2.5% |
| `b >= 4` | 22 (20.4%) | 90% |

That is the lifetime-40 form of the handover's "48 of the default schedule's 88
legs exist only to resolve the early transient, spanning 0.43% of the horizon
between them": here it is 65 of 108 below `b = 0.2`, spanning 0.5%.

### The refinement loop

`SCM::refine_schedule()` (`plant/inst/include/plant/scm.h`) is the whole of it:

```
collect_refinement_errors = true
repeat up to control.schedule_nsteps (20) times:
    run()                                        # resets, then runs
    e = refinement_error_by_node()
    split = e > control.schedule_eps             # 2e-2
    if no split: break
    times = bisect_flagged_intervals(times, split)
    node_schedule.set_times(times)
parameters.node_schedule_times = node_schedule.get_times()
parameters.ode_times / ode_step_sizes = solver.schedule()
```

`bisect_flagged_intervals` inserts the midpoint of `(t[j-1], t[j])` for each
flagged `j >= 1` and sorts. Insertion only, so **every level is a strict superset
of the one before and the levels are nested**. This matches the vignette's "a new
cohort is introduced immediately prior to any cohort failing these tests".

There is no logging call anywhere in the loop. `control$schedule_verbose` is
declared, defaulted, bound and read by nothing, so the loop's per-iteration
behaviour is unobservable from R — which is why this note reproduces the loop in
R rather than calling it.

### What the indicator estimates

`Patch::refinement_error_by_node()` is the **element-wise max of two different
per-node vectors**, compared against one threshold.

**Reproduction (`seed_rain_error`).** `Patch::net_reproduction_ratio_errors()` is

```
local_error_integration( species.node_times(),
                         species.net_reproduction_ratio_by_node_weighted(),
                         total_offspring_production() )
```

`util::local_error_integration(x, y, scal)` (`plant/src/util.cpp`) is the
drop-one-point Richardson estimate of the composite trapezium: for each interior
`i`, `|0.5*(y[i-1]+y[i+1])*(x[i+1]-x[i-1]) - (trap(i-1,i) + trap(i,i+1))| / scal`,
with `NA` at both ends — **so the first and last nodes can never be flagged.**
Its abscissa is `node_times()`, the introduction times, **unconditionally**. Its
scale is `J` itself. It is computed once, from the end-of-run state.

**Competition (`area_leaf_error`).** `Species::r_compute_competition_effect_by_nodes_error()`
is the same drop-one estimate over `quadrature_abscissae()` — i.e. over
`Species::abscissa_of`, which **is** the coordinate flag:

```cpp
static double abscissa_of(const node_type& n, bool birth_date) {
  return birth_date ? to_passive(n.introduction_time()) : -to_passive(n.height());
}
```

Its integrand is each node's contribution to stand leaf area,
`node.compute_competition(0.0)`, and its scale is the stand total at that moment.
`Patch::collect_competition_errors()` samples it **once per introduction** during
the run and keeps a running element-wise max, so it is a max over ~108 readings
taken at different times, against the reproduction term's single reading at `T`.

### What assembles `J`

`Patch::offspring_production()` is

```
trapezium( species.node_times(),
           weighted_fecundity_j * birth_rate(node_times_j) )
```

with `weighted_fecundity = offspring_produced_survival_weighted *
patch_density_at_birth * S_D`. Measured: `trapezium(b, w)` reproduces
`sum(scm$offspring_production)` to **relative 0** (`12.0526221587` both ways), and
`net_reproduction_ratio_errors` reproduces `local_error_integration(b, w, J)` to
**exactly 0**, against a discrepancy of 0.0676 when the same estimate is taken
over `-height`. So both the functional and its own error term live in birth date.

### The premise in the brief is half right, and the half that is wrong matters

The brief says the two error functions are integrated over the size-density
distribution "whose abscissa is whatever `abscissa_of` returns", so that with
`node_density_in_birth_date = FALSE` the knobs are birth times while the error
minimised lives in height.

**Confirmed for `area_leaf_error`. Overturned for `seed_rain_error` and for `J`.**
`net_reproduction_ratio_errors` and `offspring_production` both call
`species.node_times()` directly and never touch `abscissa_of`. The consequence is
sharper than the brief's version:

- In **birth date** the two indicator terms share one abscissa, which is also the
  knob and also `J`'s. The map from knobs to abscissae is the identity, fixed for
  all time.
- In **height** the loop compares two drop-one estimates taken over **two
  different abscissae** — competition over `-height`, reproduction over `b` —
  by an element-wise max against one threshold, and the functional being
  refined for is on the second of them.

A second asymmetry follows from the same reading and is **not measured here**
(this fixture is birth-date only). The live competition walk,
`Species::compute_competition_and_slope_split`, sorts by abscissa
(`ascending_by_abscissa()`) whenever the heights are not known to be decreasing,
because TF24's reserve-gated growth lets two cohorts cross. The diagnostic that
feeds the indicator, `r_compute_competition_effect_by_nodes_error`, passes
`quadrature_abscissae()` **unsorted**. On the height coordinate, after any
crossing, the indicator's competition term is therefore a trapezium estimate over
a non-monotone `x`, while the quantity it claims to estimate the error of is
taken over the sorted one.

---

## 2. Cost against position

Run cost is `Σ over steps of M(t)`, the member loop being ~86% of a rate
evaluation and `O(M)`. Both that sum and its two marginal derivatives are exact
functions of one run's step program and its creation schedule, so no extra runs
are needed (`ng_cost.R`, reading the 108-node aligned run at `ode_tol = 1e-3`:
9931 program times, 9930 steps, all 108 creations on the program).

```
Σ over steps of M  =  956 923 member-evaluations   (96.37 per step, M_final = 108)
```

### Where the cost is, against where the horizon is

| window | steps | mean `M` | share of steps | share of cost |
|---|---|---|---|---|
| `[0, 4]` | 1240 | 75.4 | 12.5% | 9.8% |
| `(4, 8]` | 1102 | 89.2 | 11.1% | 10.3% |
| `(8, 12]` | 680 | 93.4 | 6.8% | 6.6% |
| `(12, 16]` | 1067 | 95.4 | 10.7% | 10.6% |
| `(16, 20]` | 862 | 97.5 | 8.7% | 8.8% |
| `(20, 24]` | 1008 | 99.6 | 10.2% | 10.5% |
| `(24, 28]` | 1018 | 101.5 | 10.3% | 10.8% |
| `(28, 32]` | 919 | 103.5 | 9.3% | 9.9% |
| `(32, 36]` | 820 | 105.6 | 8.3% | 9.0% |
| `(36, 40]` | 1214 | 107.4 | 12.2% | 13.6% |

`M` is 75 in the first decile and 107 in the last — because 70% of the creations
have already happened by `b = 1`. Cost tracks steps almost exactly after the
first decile, which is the point: **the steps do not know where the cohorts are,
and by `t = 4` almost all the cohorts exist.**

### The early transient

| cut | cohorts | share of the horizon | share of cost those cohorts carry | steps taken inside | cost of those steps | share of `J` |
|---|---|---|---|---|---|---|
| `b < 0.01` | 44 (40.7%) | 0.025% | **45.5%** | 49 | 0.11% | **1.35%** |
| `b < 0.1` | 60 (55.6%) | 0.25% | **62.0%** | 142 | 0.65% | 12.2% |
| `b < 0.2` | 65 (60.2%) | 0.50% | **67.1%** | 199 | 1.02% | 23.1% |
| `b < 0.5` | 71 (65.7%) | 1.25% | 73.2% | 320 | 1.88% | 45.4% |
| `b < 1` | 76 (70.4%) | 2.5% | 78.2% | 411 | 2.59% | 67.2% |
| `b < 4` | 86 (79.6%) | 10% | 87.9% | 1239 | 9.76% | 85.6% |

Read the first row. The 44 creations in the first 0.025% of the horizon — the
eight legs at the `1e-5` clamp and the first doublings above them — sit in the
member loop of essentially every one of the 9930 steps, and so carry **45.5% of
the whole run's member-loop work**. They contribute **1.35% of `J`**, because the
trapezium weight of a node whose neighbours are `1e-5` away is `1e-5`. The 42
cohorts from `b = 0.01` to `b = 4` carry 42.4% of the cost and 84.2% of `J`; the
22 from `b >= 4` carry 12.1% of the cost and 14.4% of `J`.

The steps *taken inside* the transient are not the expense — 199 steps, 1.02% of
cost, for the whole of `[0, 0.2)`. The expense is that the cohorts created there
never leave.

### The marginal cost of one more point

`cohort` is the member-loop work a new creation at `b` adds over the rest of the
run; `stop` is the work one extra forced step boundary at the same `b` adds,
which is one pass over the members alive there.

| `b` | cohort (member-evals) | % of run | forced stop | % of run | ratio |
|---|---|---|---|---|---|
| 0.001 | 9900 | 1.035% | 27 | 0.0028% | **367** |
| 0.01 | 9881 | 1.033% | 44 | 0.0046% | 225 |
| 0.1 | 9788 | 1.023% | 60 | 0.0063% | 163 |
| 1 | 9519 | 0.995% | 76 | 0.0079% | 125 |
| 4 | 8691 | 0.908% | 86 | 0.0090% | 101 |
| 10 | 7345 | 0.768% | 93 | 0.0097% | 79 |
| 20 | 4979 | 0.520% | 98 | 0.0102% | 51 |
| 30 | 2454 | 0.256% | 103 | 0.0108% | 24 |
| 38 | 529 | 0.055% | 107 | 0.0112% | 5 |

The two kinds of point have opposite cost gradients in `b`. A creation is most
expensive at the start and nearly free at the end; a forced stop is cheapest at
the start and most expensive at the end, and is between 5× and 367× cheaper than
a creation everywhere. **A bisection buys a quadrature abscissa at the price of a
state variable and gets the forced stop thrown in; the forced stop is the cheap
part of what it does, and §3 shows it is not the small part of what it changes.**

---

## 3. The integrand, measured

`J = trapezium(b, w)` exactly, with `w(b) = offspring_produced_survival_weighted
* patch_density(b) * S_D`, so `w` is one number per node and needs no
reconstruction (`ng_prof.R`, `ng_rain.R`, `ng_ind.R`, on the 108-node aligned run
at `ode_tol = 1e-3`).

### The shape

`w` at every node from `b = 1`, with its trapezium weight and what it contributes:

| `b` | `w(b)` | weight | contribution | % of `J` | that year's rain |
|---|---|---|---|---|---|
| 1 | 3.2176 | 0.125 | 0.4022 | 3.34% | |
| 1.5 | 1.4043 | 0.25 | 0.3511 | 2.91% | |
| 2 | 0.6358 | 0.25 | 0.1589 | 1.32% | |
| 3 | 0.1500 | 0.5 | 0.0750 | 0.62% | |
| 4 | 0.1306 | 0.5 | 0.0653 | 0.54% | 2166 |
| 5 | 0.0502 | 0.75 | 0.0377 | 0.31% | 1155 |
| 6 | 0.0664 | 1 | 0.0664 | 0.55% | 969 |
| 7 | 0.2081 | 1 | 0.2081 | 1.73% | **573** |
| **8** | **1.0331** | 1 | **1.0331** | **8.57%** | **366** |
| 9 | 0.1792 | 1 | 0.1792 | 1.49% | **182** |
| **10** | **0** | 1.5 | **0** | **0.00%** | 936 |
| 12 | 0.0260 | 2 | 0.0520 | 0.43% | 2234 |
| 14 | 0.0200 | 2 | 0.0399 | 0.33% | 1055 |
| 16 | 6.17e-3 | 2 | 0.0123 | 0.10% | 840 |
| 20 | 9.85e-4 | 2 | 1.97e-3 | 0.016% | 390 |
| 24 | 3.61e-5 | 2 | 7.21e-5 | 0.0006% | 1521 |
| 28 | 1.88e-8 | 2 | 3.75e-8 | ~0 | 1587 |
| 32 | 2.22e-14 | 2 | 4.44e-14 | ~0 | 397 |
| 38 | 1.52e-24 | 1 | 1.52e-24 | ~0 | 1172 |

Below `b = 1` it is flat and large: `w` spans **15.1013 to 15.2454** across the
44 nodes with `b < 0.01` — a 0.95% spread over 40% of the grid — and falls
smoothly to 3.22 at `b = 1`.

**It is not smooth, not unimodal, and not monotone.** It falls by a factor of
304 from `b = 0` to `b = 5`, **rises twentyfold between `b = 6` and `b = 8`**,
falls sixfold to `b = 9`, is **exactly zero at `b = 10`**, rises again at
`b = 12`, and then decays super-exponentially — 48 natural-log units between
`b = 22` and `b = 38`, against 4.6 between `b = 5` and `b = 22`.

### The feature is the drought

The `b = 6 … 10` structure sits on the record's first multi-year drought. The
fixture's annual multipliers put the drought at years 8–10, which is model time
`[7, 10)`:

| model year | `[4,5)` | `[5,6)` | `[6,7)` | `[7,8)` | `[8,9)` | `[9,10)` | `[10,11)` | `[12,13)` |
|---|---|---|---|---|---|---|---|---|
| rain | 2166 | 1155 | 969 | **573** | **366** | **182** | 936 | 2234 |
| `w(b)` at `b = year` | 0.131 | 0.050 | 0.066 | **0.208** | **1.033** | **0.179** | **0** | 0.026 |

`w` peaks at `b = 8`, inside the driest two years the record contains, at 20× its
value one year earlier and 5.8× one year later; and the node born at the
drought's end, `b = 10`, returns **exactly zero** lifetime offspring. One node,
`b = 8`, carries **8.57% of `J`**.

`w(10) = 0` is exact, not small, and §5 says what it is: the cohort born there
failed to establish. The 20-fold peak beside it is the other half of the same
mechanism — the birth dates immediately before `b = 8` are a half-year band in
which no cohort establishes at all, and the first one that does inherits the gap.
What this section establishes on its own is only the **sampling** statement, and
that needs no mechanism.

A feature twenty times its background, one to two years
wide, sits in a region where the dyadic generator places **one node per year**
from `b = 6` to `b = 10` and **one per two years** after. `dt = exp2(floor(log2(0.2
t)))` is a function of the clock alone; the drought is a property of the record.
**The generator cannot see this feature, and at 108 nodes it samples the peak of
it exactly once.**

### Where the quadrature error is, and where the indicator puts nodes

The drop-one estimate on `J` itself — `local_error_integration(b, w, 1)`,
unnormalised — totals **2.0814, i.e. 17.27% of `J`**. It is an absolute-value sum
of signed local errors, so it is an upper bound the realised error does not
approach: the same run's `J` is within 0.08% of the converged value
(`diag-long-drought.md`'s 12.0779933). What it locates, it locates correctly.

| `b` | drop-one error | % of `J` | flagged at 2e-2? | which term set the indicator |
|---|---|---|---|---|
| 8 | 0.8394 | **6.97%** | yes | competition |
| 7 | 0.3416 | 2.83% | yes | competition |
| 9 | 0.3374 | 2.80% | yes | competition |
| 10 | 0.1922 | 1.60% | yes | competition |
| 6 | 0.0628 | 0.52% | yes | competition |
| 12 | 0.0321 | 0.27% | yes | competition |
| 1.5 | 0.0301 | 0.25% | **no** | competition |
| 3 | 0.0264 | 0.22% | **no** | competition |
| 4 | 0.0204 | 0.17% | **no** | competition |

**2.05% of the total drop-one error on `J` lives at `b < 1`, where 76 of the 108
nodes are.** The remaining 97.95% is on the 32 nodes from `b = 1` up, and 14.2%
of `J` is on four of them.

At the shipped `schedule_eps = 2e-2` the combined indicator flags **17 nodes, all
with `b >= 6`**, and not one below `b = 1`. That is the right region. But the term
that put them there is the wrong one:

- The **competition** term sets the max on **106 of 106** nodes with a finite
  indicator.
- The **reproduction** term — the drop-one estimate of `J`'s own trapezium — sets
  it on **none**, and on its own would flag exactly **three** nodes, `b = 7, 8, 9`.
- Nine of the 17 flags are at `b >= 16`, where `w` is between `6e-3` and
  `2.7e-18` and the nodes' combined contribution to `J` is under 0.2%. `b = 30` is
  flagged at an indicator of 0.2005 while contributing `2.7e-10` to a `J` of
  12.05; `b = 34` at 0.0686 while contributing `5.4e-18`.

The competition term is normalised by stand leaf area at its sampling time and
the reproduction term by `J`, and they are combined by an element-wise max against
one threshold. Leaf area is still O(1) at `b = 30` when reproductive output is
1e-10, so the loop keeps bisecting a region that the functional it is being run
for has left entirely.

---

## 4. Does step insertion explain the refinement loop's behaviour? No — it is 2% of it

`𝒢_b ⊂ 𝒢_t` structurally, so a bisection inserts a forced stop as well as a
creation, and the indicator reports a quadrature improvement while the answer
moves for two reasons. The instrument that separates them is the one the brief
names: capture a step program at the **finest** creation level and replay it at
the coarser ones. The levels here are nested bisections of the default schedule
(`ng_fixed.R ladder 2`, 108 / 215 / 429, each a strict superset of the last;
checked, and all 108 and all 215 creations are on the 429-node run's program, so
the replayed grid is bit-identical).

`ode_tol = 1e-3`, aligned, `lma = 0.32`.

| creations | adaptive `J` | its steps | `J` on the 429-node program | its steps | time grid alone |
|---|---|---|---|---|---|
| 108 | 12.0526222 | 9931 | **12.0721683** | 10816 | +0.162% |
| 215 | 12.0888310 | 10174 | **12.1032671** | 10816 | +0.119% |
| 429 | 13.0315024 | 10816 | 13.0315024 | 10816 | 0 |

Read the two channels off it.

- **Time grid, creations held fixed**: +0.162% at 108 members and +0.119% at 215.
  That is the whole effect of replacing the controller's own grid with one 885
  steps finer that also carries 321 forced stops the 108-node run never took.
- **Creation grid, time grid held bit-identical**: 12.0721683 → 12.1032671 →
  13.0315024, i.e. **+0.258%** then **+7.669%**, against the adaptive arm's
  +0.300% and +7.798%.

**Step insertion is 14% of the first bisection's movement and 1.7% of the
second's; over the two levels together it is 2.0% and the creation grid is
98.0%.** The premise in the brief — that the refinement loop's `J` moves largely
because each bisection forces stops into the time grid — does not hold on this
fixture. On an aligned grid at a viable operating point the movement belongs to
the creation grid, and §7 splits *that* into an abscissa part and a
state-dimension part which turn out to be of opposite sign.

This is consistent with `diag-long-horizon-remeasure.md` §8, which found the
bit-identical-grid claim worth 0.019% on a smooth record and 0.112% on this one
at 108 ↔ 215; it is the same statement carried one bisection further, where the
creation grid turns out to be moving `J` by 8%.

### The indicator is as insensitive to the time grid as `J` is

The same replay reports the indicator, which is what the loop's stopping rule
reads:

| level | max indicator, adaptive → fixed grid | nodes over `2e-2` | sum over nodes |
|---|---|---|---|
| 108 | 0.31627 → 0.31530 | 17 → 17 | 1.8253 → 1.8239 |
| 215 | 0.16569 → 0.16458 | 23 → 23 | 1.6206 → 1.6184 |
| 429 | 0.085816 (identical) | 28 | 1.7261 |

Holding the time grid bit-identical moves the indicator by **0.3% at most** and
changes **no** flag decision at either level. And the non-monotonicity the
consult reports is present on the fixed grid too: the summed indicator reads
**1.8239 → 1.6184 → 1.7261**, rising at the second bisection with the time grid
held exactly. **That is not a step-insertion artefact.**

### A third instrument, at the same 17 points

The loop's first pass flags 17 nodes and would insert the midpoints
`5.5, 6.5, 7.5, 8.5, 9.5, 11, 13, …, 33`. Run the same 108-node schedule with a
**zero-depth rainfall pulse at each of those 17 times** and nothing else: that
arm takes the forced stops without the cohorts (`ng_split.R`).

| arm | nodes | steps | `J` | vs base |
|---|---|---|---|---|
| the schedule as generated | 108 | 9931 | 12.0526222 | — |
| + the 17 stops, no new cohorts | 108 | 9941 | 12.0532277 | **+0.0050%** |
| the loop's actual bisection | 125 | 10064 | 12.0969385 | **+0.3677%** |

**Step insertion is 1.4% of what the bisection does; the cohorts are the other
98.6%.** The indicator moves from 0.31627 to 0.31604 and flags the same 17 nodes.

Two details worth keeping. The 17 stops on their own add **10** steps, not 17 —
seven of those times were already step boundaries. The bisection adds **133**,
which is 17 forced stops plus 116 steps the controller chose because the
trajectory changed. So even the step-count growth under refinement is mostly a
consequence of the new cohorts rather than of the stops they force.

### Verdict on the brief's highest-value item

Four independent instruments — capture-at-finest replay on the bisection ladder,
the same replay on the refinement loop's own eight levels (§8), the indicator on
a bit-identical grid, and a stops-only control at the loop's own bisection
points — agree: **on an aligned grid at a viable operating point, step insertion accounts
for 1–2% of what refinement does to `J` and for none of the indicator's
behaviour.** The premise is wrong, and what needs explaining is the creation
grid. §5 says what that is and §7 splits it in two.

Two caveats on the scope of that. The measurement is **aligned** throughout; the
brief's own constraint requires it, and `diag-long-horizon-remeasure.md` §8 shows
the coarse-captured replay costs 11.0% on a *smooth* record and +0.025% on this
aligned one, so the inserted-stop channel is a property of grids where the
forcing quadrature is still in play. And the fixed-grid arm walks its times
through `step_to`, which takes one RK step per supplied time with no error
control, so it is the same instrument `diag-gradient-error.md` used, with the
same meaning.

---

## 5. What is actually moving `J`: the integrand is discontinuous in `b`, and the discontinuity is set by the record

### The node ladder says the creation grid is nowhere near converged

Adaptive, aligned, `ode_tol = 1e-3`:

| creations | 108 | 215 | 429 |
|---|---|---|---|
| `J` | 12.0526222 | 12.0888310 | **13.0315024** |
| against the level below | — | +0.300% | **+7.798%** |
| steps | 9931 | 10174 | 10816 |

The last doubling moves `J` by 7.8% after the one before it moved it by 0.3%.
That is not a converging second-order sequence, and `diag-long-horizon-remeasure.md`
§7's reading — that at lifetime 40 the operating count of 108 sits *below*
convergence rather than above it — understates the case at one bisection further
out.

It is not the time integration. The whole ladder, run again a decade tighter
(`ng_tol429.R`, `ng_tol.R`):

| creations | `J` at `ode_tol = 1e-3` | steps | `J` at `1e-4` | steps | tolerance moves it |
|---|---|---|---|---|---|
| 108 | 12.0526222 | 9931 | 12.0873665 | 12 226 | +0.288% |
| 215 | 12.0888310 | 10 174 | 12.1083840 | 12 486 | +0.162% |
| 429 | 13.0315024 | 10 816 | 13.0342392 | 13 131 | **+0.021%** |

The doubling reads **+7.65%** at the tighter tolerance against +7.80% at the
looser, so the 7.8% belongs to the creation grid and the tolerance channel
*shrinks* as the creation grid refines. The two 1e-4 entries at 108 and 215 also
reproduce `diag-long-horizon-remeasure.md` §8's aligned intermittent arm —
12.0873665 and 12.108384 — to every digit, independently of this note's own
reproduction check.

### Why: `w(b)` is exactly zero on a set of birth dates, and the set is the record

`TF24_Strategy::establishment_probability` (`tf24_strategy.h`) is

```cpp
if (net_mass_production_dt_ > 0) {
  const S tmp = pars.a_d0 * seed_geometry().area_leaf / net_mass_production_dt_;
  return 1.0 / (tmp * tmp + 1.0) * decay_over_time;
} else {
  return 0.0;                      // exactly zero
}
```

and `Node::compute_initial_conditions` puts a cohort whose establishment
probability is zero at `establishment_failure_hazard`, which `node.h`'s own
comment records as the finite stand-in for `-Inf`. Measured at those nodes:
`log_density = -744` to `-750` against `-8` to `-11` at their neighbours, `w = 0`
exactly, and their contribution to stand leaf area is `0` exactly.

**A cohort whose seedling has non-positive net carbon gain at the instant of its
birth contributes exactly nothing, and the birth dates at which that happens are
decided by the forcing.** Over the 120 nodes with `b` in `(1, 36)` on the
429-node run, 18 are at the floor. The rain in the 30 days before birth has
median **0.00** at the failures and **59.88** at the survivors
(Wilcoxon `p = 6.5e-8`); at 90 days, 55.2 against 229.9 (`p = 4.6e-5`); at 180
days the two are indistinguishable (`p = 0.27`). The deciding variable is soil
moisture at the birth instant, which no single window reproduces — `b = 8.5`
establishes with zero rain in the preceding 90 days — but the association with
the record at the month scale is not in doubt.

The failure set grows as the grid refines, which is what a set of positive
measure in `b` does when you sample it more densely:

| creations | 108 | 215 | 429 |
|---|---|---|---|
| nodes with `w = 0` exactly | 1 (0.9%) | 3 (1.4%) | **18 (4.2%)** |
| the first of them | `b = 10` | `b = 6.5` | `b = 3.625` |

and at 429 nodes they arrive in **adjacent pairs** — `6.5, 6.75` and
`7.5, 7.75` — so the failing set is intervals, not isolated points.

Here is the integrand across the first drought at 429 nodes, with the rain in
the preceding 30 days:

| `b` | 7.0 | 7.25 | 7.5 | 7.75 | 8.0 | 8.25 | 8.5 | 8.75 | 9.0 |
|---|---|---|---|---|---|---|---|---|---|
| `w(b)` | 0.246 | 0.352 | **0** | **0** | **1.431** | 0.981 | 0.642 | 0.442 | 0.295 |
| rain, 30 d before | 192.5 | 23.5 | **0.0** | **0.0** | 111.2 | 58.1 | 0.0 | 3.5 | 93.9 |

`w` goes from 0 to 1.431 across one quarter-year interval. At 108 nodes that
whole structure is three samples — `0.208, 1.033, 0.179` at `b = 7, 8, 9` — and
`w` at `b = 8` reads 1.033 rather than the 1.431 it reads when the stand is run
with 429 cohorts.

**So `w(b)` is not a smooth integrand being under-resolved. It is a positive
O(0.1–1) envelope multiplied by the indicator of a record-determined set, with an
exact jump at the set's boundary.** A composite trapezium across a jump is
first-order, not second, which is why the node ladder is not behaving like the
`O(Δb²)` sequence `diag-quadrature-order.md` and `diag-long-horizon-remeasure.md`
§5 fitted, and why it alternates.

### How wide the failure bands are: 1/16 of a year across the first drought

`ng_fine.R` keeps the default schedule everywhere and adds creations at 1/16-year
spacing on `[5, 11]` only — 97 extra cohorts in a six-year window, 205 in all.
Of the 103 nodes in `[4.9, 11.1]`, **23 (22.3%) are at the establishment floor**,
and they arrive in **ten runs** of consecutive nodes:

| run | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 |
|---|---|---|---|---|---|---|---|---|---|---|
| nodes | 1 | 1 | 1 | 1 | 1 | 3 | 2 | **8** | 3 | 2 |
| width (yr) | 0.062 | 0.062 | 0.062 | 0.062 | 0.062 | 0.188 | 0.125 | **0.500** | 0.188 | 0.125 |

The bands are **23 days to 6 months wide**. The longest, `b ∈ [7.375, 7.8125]`,
is half a year of birth dates inside the drought at which a seedling cannot make
carbon, with `rain-30d = 0.00` on seven of its eight nodes.

Either side of it the integrand is **smooth**:

```
b      7.250  7.3125 | 7.375 ... 7.8125 | 7.875  7.9375  8.000  8.0625  8.125  8.1875
w      0.326  0.388  |    0 (8 nodes)   | 1.561  1.437   1.317  1.204   1.096  0.994
```

`w` runs 0.326 → 0.388, drops to exactly 0 for half a year, reappears at **1.561**
— its largest value anywhere past `b = 1` — and then decays smoothly by 8% per
sixteenth of a year. **The integrand is piecewise smooth with jumps, and the
jumps are where the record stops a seedling making carbon.**

Association with the forcing is strong but not a function of any one window:
`b = 8.375` to `8.6875` have `rain-30d = 0.00` and establish (`w` 0.73 to 0.44),
and `b = 6.6875` is a lone survivor between failures on both sides. Soil moisture
at the birth instant is the deciding state, and it carries the canopy's draw as
well as the rain.

### Resolving that one window is most of the 8%

| schedule | creations | `J` | steps |
|---|---|---|---|
| the default | 108 | 12.0526222 | 9931 |
| uniform bisection | 215 | 12.0888310 | 10174 |
| **default + 1/16-year on `[5, 11]` only** | **205** | **12.6061233** | 10226 |
| uniform bisection twice | 429 | 13.0315024 | 10816 |

**At effectively the same creation count — 205 against 215 — putting the extra
cohorts in the six years around the first drought rather than spreading them
uniformly moves `J` by 4.3%, and four fifths of the way from the 108-node answer
to the 429-node one.** The grid's shape matters far more than its size, and the
shape that matters is fixed by the record.

The 429-node run is **not** a converged reference for that comparison and the
4.3% is not an error against it: it carries twice the cohorts of either 205-node
schedule, so it differs from them through the state-dimension channel of §7 as
well as through placement. What the comparison establishes is the size of the
placement effect at fixed count, not which of the three is right.

---

## 6. What the early transient costs, run rather than counted

§2 counts the transient's share of the member loop. This runs it: keep every
`k`-th creation below a cut-off and every creation above it, change nothing else
(`ng_trans.R`, aligned, `ode_tol = 1e-3`, three at a time on four cores).

| arm | creations | below `b = 0.1` | steps | wall | `J` | `ΔJ` | member-evals | `Δcost` |
|---|---|---|---|---|---|---|---|---|
| the schedule as generated | 108 | 60 | 9931 | 136 s | 12.0526222 | — | 956 923 | — |
| every 2nd below `b = 0.01` | 86 | 38 | 9908 | 108 s | 12.0526305 | **+0.0000%** | 738 671 | −22.8% |
| every 4th below `b = 0.01` | 75 | 27 | 9897 | 95 s | 12.0525318 | **−0.0008%** | 629 795 | −34.2% |
| every 11th below `b = 0.01` | 68 | 20 | 9891 | 85 s | 12.0526173 | **−0.0000%** | 560 622 | −41.4% |
| every 4th below `b = 0.1` | 63 | 15 | 9888 | 77 s | 12.0526893 | **+0.0006%** | 511 471 | −46.6% |
| every 10th below `b = 0.1` | 54 | 6 | 9880 | 65 s | 12.0530037 | **+0.0032%** | 422 620 | −55.8% |

**Half the run's cost buys three parts in a hundred thousand of the answer.**
Dropping 54 of the 108 creations — all of them below `b = 0.1` — runs **2.09×
faster** in wall clock, takes 51 fewer steps, and moves `J` by **+0.0032%**,
which is a hundredth of the 0.3% the first bisection of the *whole* schedule
moves it and a two-thousandth of the 7.8% the second does.

The steps barely notice (9931 → 9880, −0.5%), which confirms §2's accounting: the
transient is not expensive because the integrator works hard there. It is
expensive because 44 cohorts introduced in the first 0.025% of the horizon sit in
the member loop of every one of the remaining 9900 steps.

This is the handover's "48 of the default schedule's 88 legs exist only to
resolve the early transient" measured rather than counted, and the answer is that
they do not resolve anything `J` can see.

It also bounds §7's second channel where it matters. Halving the creation count
by dropping early cohorts changes the integrand by **0.003%**; halving it by
coarsening everywhere changes it by **12.76%**. The state-dimension channel is
not a property of the number of cohorts — it is a property of the cohorts near
`b = 5` to `b = 13`.

---

## 7. Separating the abscissa from the state dimension, and what a standard rule would need

### The creation grid's two roles pull in opposite directions

H3 says the creation grid is the quadrature abscissa and the state dimension at
once. On the birth-date coordinate the two can be separated arithmetically,
because the 108 default abscissae are an exact subset of the 429-node grid
(checked: maximum mismatch **0**), so the coarse rule can be applied to the fine
run's own integrand with no interpolation anywhere (`ng_quad.R`):

Take the three runs on the **429-node time grid**, so the time channel of §4 is
out of it:

| | `J` | against 13.0315024 |
|---|---|---|
| fine integrand, fine abscissae — the model at 429 members | 13.0315024 | — |
| **fine integrand, the 108 default abscissae** | **13.8379498** | **+6.188%** |
| the model at 108 members, same time grid | 12.0721683 | −7.361% |

So of the creation grid's effect at 108 members against 429:

- **abscissa placement alone: +6.19%** — what the coarse node set does to the
  trapezium over one fixed integrand, with no interpolation and no re-run;
- **the integrand's own dependence on the node set: −12.76%** — what running the
  stand with 108 cohorts instead of 429 does to `w` at those same birth dates;
- **together: −7.36%**, and the product is exact.

The two are of the same order and opposite sign, and the second is the larger.
This is the instrument the consult's question 2(b) asks for, and the answer it
gives is that the quadrature is **not** the dominant half of what a bisection
does. (With the adaptive 108-node run in the last row instead, the same split
reads +6.19% and −12.90% for −7.51%; the 0.15% difference is §4's time channel.)

### The default abscissae, judged as a quadrature rule

Taking the 429-node `w` as samples of one function and interpolating it with the
same shape-preserving Fritsch–Carlson construction the model uses for its drivers
(the interpolant's own integral is within `2.0e-4` of the fine trapezium), the
default placement is a **poor** rule for its size:

| rule, 108 nodes | relative error |
|---|---|
| the dyadic generator's 108 abscissae | **6.21e-2** (6.19e-2 on the samples themselves) |
| 108 uniform nodes | 3.51e-3 (**17.7× better**) |
| 108 nodes graded on `\|w''\|^(1/2)` | 1.30e-3 (**48× better**) |

and to reach the dyadic 108's accuracy:

| scheme | nodes / evaluations to match 6.19e-2 |
|---|---|
| graded mesh equidistributing the trapezium's error density | **17 nodes** |
| uniform on `[0, 12]`, which carries 99.5% of `J` | **15 nodes** (4.69e-2) |
| adaptive Gauss–Kronrod (QAGS/GK21, `integrate`) | its coarsest call, **189 evaluations**, already reaches 1.28e-3 — 48× past the target |
| adaptive Simpson | 549 evaluations for 9.7e-3 |

The same statement from the error density. The drop-one error per unit width,
`err/h³` — which is `|w''|/6` up to the rule's constant — reads **1195** at
`b = 0.037` and **15.0** at `b = 8`, a ratio of 79. The trapezium-optimal spacing
goes as `|w''|^(-1/3)`, so the mesh at `b = 0.04` should be `79^(-1/3) = 0.23` of
the mesh at `b = 8` — about **4× finer**. The generator makes it **256× finer**
(`h = 0.00098` against `0.25`). **It over-refines the transient by a factor of
about 60 on its own error measure**, which §6 confirms by deleting the cohorts
and losing 0.003%.

### Three reasons not to read "17 nodes would do" as a recommendation

1. **`w` is not a fixed function of `b`.** The −12.76% above is exactly the
   dependence of the integrand on the node set. A 17-node schedule would be run
   on a 17-cohort stand, whose `w` is a different function; nothing here says
   what it would be.
2. **The interpolant cannot see below the 429-node spacing.** §5's establishment
   jumps are exact discontinuities, and the 1/16-year window run says how wide
   they are; every rule above is being scored on an integrand that has been
   smoothed to a quarter-year resolution. Across a genuine jump, all of them fall
   to first order and the counts are optimistic.
3. **The target is weak.** 6.19% is the current placement's own error, which is
   why every scheme tried clears it so easily.

What survives all three is the comparison at fixed node count: **uniform is 18×
better and graded 48× better than the dyadic generator at 108 nodes on the same
integrand.** The placement, not the count, is what is wrong.

---

## 8. The refinement loop, one iteration at a time

`SCM::refine_schedule()` has no logging, so this is its R transcription
(`ng_refine.R`: run with `collect_refinement_errors` set, flag `> schedule_eps`,
insert the midpoint below each flagged node, repeat), at the **shipped**
`schedule_eps = 2e-2`, aligned, `ode_tol = 1e-3`.

First correction to the consult's account: on this record **the loop fires at the
shipped threshold.** The consult records that on a smooth record the largest
indicator reaches 0.0099 so refinement never runs; here the first pass reads
**0.31627** and flags 17 of 108 nodes.

| iteration | creations | steps | `J` | vs previous | max indicator | flagged | wall |
|---|---|---|---|---|---|---|---|
| 0 | 108 | 9931 | 12.0526222 | — | 0.31627 | 17 | 130 s |
| 1 | 125 | 10064 | 12.0969385 | ×1.0037 | 0.16625 | 24 | 145 s |
| 2 | 149 | 10364 | 12.8505764 | ×1.0623 | 0.090236 | 29 | 163 s |
| 3 | 178 | 10497 | 12.7590002 | ×0.9929 | 0.081178 | 18 | 184 s |
| 4 | 196 | 10534 | 12.7206857 | ×0.9970 | 0.040239 | 8 | 196 s |
| 5 | 204 | 10573 | 12.6307947 | ×0.9929 | 0.032484 | **1** | 200 s |
| 6 | 205 | 10570 | 12.6308579 | ×1.0000 | 0.031788 | **1** | 198 s |
| 7 | 206 | 10574 | 12.6308272 | ×1.0000 | **0.019654** | **0** | 201 s |

**It converges**, at iteration 7, on 206 creations, at `J = 12.6308272` — 8 full
model runs and 1417 s of wall clock. Four things to read off it.

**The stopping rule certifies an answer 3.1% from what more nodes give.** The
loop stops at 206 creations and 12.6308; the uniform ladder at 429 reads
13.0315. Its own indicator went from 0.316 to 0.0197, a factor of 16, while `J`
moved +4.8% and is still moving.

**`J` moves by percent per iteration, not by factors.** The consult records the
loop reporting convergence while `J` still moves by factors of **3.0–4.3**
between iterations. Here the iteration-to-iteration moves are **+0.368%,
+6.230%, −0.713%, −0.300%, −0.707%, +0.001%, −0.000%** — non-monotone, one of
them 6%, and nothing like a factor of three. That part of the consult is a
lifetime-5 property. The shape of the complaint survives: the indicator falls
monotonically by a factor of 16 while `J` wanders 6% and ends 4.8% up, so the two
are not measuring the same thing.

**The loop does find the feature.** At iteration 0 it flags 17 nodes, all at
`b >= 6`, whose midpoints include `5.5, 6.5, 7.5, 8.5, 9.5`; by iteration 4 one
of its eight flags is `b = 7.875`, the node on the far side of §5's half-year
establishment gap and the largest value `w` takes past `b = 1`. Two schedules of
the same size that both refine that region agree: the loop's converged 206-node
answer is **12.6308** and §5's 205-node window schedule is **12.6061**, **0.20%
apart**, while 215 uniformly bisected nodes read 12.0888 — **4.3% away from
both.**

**And it spends its last three runs on a node worth a billionth of `J`.**
Iterations 5, 6 and 7 flag one node each, twice `b = 29.75`, where `w = 6.40e-10`
and the node contributes **9.4e-10 of `J`**. Every node past `b = 25` contributes
**0.00017%** of `J` between them. At iteration 4 the flagged set is

| `b` | 7.875 | 14.5 | 18.75 | 20.75 | 26.5 | 26.625 | 26.75 | 29.75 |
|---|---|---|---|---|---|---|---|---|
| indicator | 0.038 | 0.025 | 0.040 | 0.022 | 0.028 | 0.023 | 0.023 | 0.034 |
| `w` | **1.5645** | 0 | 0.011 | 0 | 0 | 4.5e-6 | 0 | 6.4e-10 |
| % of `J` | **1.15%** | 0 | 0.016% | 0 | 0 | 4e-6% | 0 | 9e-10% |

Four of the eight are nodes where `w` is exactly zero — cohorts that failed to
establish, whose neighbours' leaf-area profile has a jump at their edge that the
competition term reads and `J` cannot use. Iterations 5 and 6 flag `b = 29.75`
and nothing else, so **the last two of the loop's eight runs — 399 s of its
1417 — exist only to bisect around a node worth nine parts in ten billion of
`J`.**

### The same two-channel split on the loop's own levels

The loop's eight schedules are nested by construction (insertion only), so §4's
instrument applies directly: capture the step program of the converged 206-node
run and replay every earlier level on it (`ng_fixed.R eps2e2`; all eight levels'
creations are on that program, checked).

| iteration | creations | adaptive `J` | `J` on the 206-node program | step insertion |
|---|---|---|---|---|
| 0 | 108 | 12.0526222 | 12.0719059 | −0.160% |
| 1 | 125 | 12.0969385 | 12.1131293 | −0.134% |
| 2 | 149 | 12.8505764 | 12.8461028 | +0.035% |
| 3 | 178 | 12.7590002 | 12.7598191 | −0.006% |
| 4 | 196 | 12.7206857 | 12.7182006 | +0.020% |
| 5 | 204 | 12.6307947 | 12.6307946 | +0.000% |
| 6 | 205 | 12.6308579 | 12.6308608 | −0.000% |
| 7 | 206 | 12.6308272 | 12.6308272 | 0 (the reference) |

and the level-to-level moves, which is what the loop is doing:

| | 0→1 | 1→2 | 2→3 | 3→4 | 4→5 | 5→6 | 6→7 |
|---|---|---|---|---|---|---|---|
| adaptive | +0.3677% | **+6.2300%** | −0.7126% | −0.3003% | −0.7067% | +0.0005% | −0.0002% |
| time grid held bit-identical | +0.3415% | **+6.0511%** | −0.6717% | −0.3262% | −0.6873% | +0.0005% | −0.0003% |

Every move the loop makes survives pinning the time grid, to within a few
hundredths of a percentage point. **The loop's whole trajectory — including the
6.2% jump at its second bisection and the three negative moves after it — is the
creation grid.**

The exhaustion path was not taken here, so the handover's silent-inconsistency
bug (`refine_schedule` bisects *after* its run, so exhausting `schedule_nsteps`
installs a schedule that was never run) did not fire. Nothing in the loop logs
anything either way: `control$schedule_verbose` is declared, defaulted, bound and
asserted in `test-control.R`, and read by nothing, which is why this section is
an R transcription rather than a log.

---

## 9. Is the birth-date coordinate a well-posed adaptive quadrature solved with the wrong heuristic?

Separating what was measured from what follows from it.

**Measured.** The coordinate does make the placement question well posed.
`abscissa_of` on the birth-date branch returns `introduction_time()` — the knob
itself, fixed at birth for all time — and both `J` and its own drop-one error
term read `node_times()` regardless of the flag, so knob, abscissa and the
functional's integration variable are one object. The 108 default abscissae are
an exact subset of the 429-node grid, which is why §7's arithmetic separation is
possible at all. On the height branch none of that holds: the competition term
reads `-height`, the reproduction term still reads `b`, and the two are combined
by an element-wise max.

**Measured.** The object being integrated is not a fixed function of that
abscissa, for two separate reasons, both quantified.

- It depends on the node set. At 108 members against 429 on one time grid, the
  abscissa channel is **+6.19%** and the integrand's own dependence on the node
  set is **−12.76%** — opposite signs, the second larger.
- It is discontinuous. `establishment_probability` returns an exact zero wherever
  a seedling's net carbon gain is non-positive at the birth instant, and the set
  where that happens is fixed by the forcing (rain in the preceding 30 days:
  median 0.00 at the failures against 59.88 at the survivors, `p = 6.5e-8`).

**Inference.** So it is not an adaptive quadrature. It is an equidistribution
problem for a mesh that is simultaneously the discretisation of the density
equation — the moving-mesh shape, not the Gauss–Kronrod shape — over an integrand
with jumps at locations the record determines and a reference run can find. A
Gauss–Kronrod or adaptive-Simpson treatment of `J` alone answers a question the
solver is not asking, which is why §7's node counts should be read as a scoring
of the current placement and not as a proposal.

**Inference.** What is genuinely mismatched is narrower than "the wrong kind of
algorithm", and it is three things that can be named:

1. **The starting grid knows only the clock.** `dt = exp2(floor(log2(0.2 t)))`
   cannot see a drought, and §5's largest feature in the integrand is one. On its
   own error measure it over-refines the transient by about 60× (§7), and §6
   confirms that by deleting half the creations for 0.003% of `J`.
2. **The monitor function is the wrong one for the functional.** The competition
   term sets the flag on 106 of 106 nodes, normalised by stand leaf area, which
   stays O(1) long after `w` has fallen through 1e-10 — hence flags at `b = 30`
   and `b = 34`. If the loop is meant to certify `J`, the reproduction term is the
   one that reads `J`, and it is never the binding one. (If the loop is instead
   meant to certify the competition coupling — which is defensible, since that is
   the channel §7 measures at −12.76% — then it should say so, and `J` needs its
   own stopping rule beside it.)
3. **The stopping rule is a per-node threshold on an absolute-value sum of signed
   local errors.** At 108 nodes that sum is 17.27% of `J` while `J` itself is
   within 0.08% of its tolerance-converged value: it is an upper bound the answer
   does not approach, so the threshold cannot be read as an error budget in either
   direction.

**Measured, and it is the one encouraging result.** Two 205/206-node schedules
built by different means — the loop's own converged refinement and §5's
hand-placed 1/16-year window over `[5, 11]` — agree to **0.20%**, while 215
uniformly bisected nodes sit **4.3%** from both. Where the nodes go is
reproducible across methods that both find the drought; how many there are is
not what separates the answers.

**Not measured, and it is the load-bearing gap.** Whether a grid placed by the
error density *alone* — not by bisecting an existing one — reaches the same `J`,
and what the creation-converged value actually is. The ladder is still moving
7.8% per doubling at 429, the state-dimension channel is larger than the
abscissa channel and of opposite sign, and nothing here pins either down.

---

## 10. Scripts, and the build they ran against

All in the session scratchpad, all `Rscript <file> [args]`, all reading `plant`
through `pkgload::load_all` and `odelia` through `library`. `ld_common.R` and
`lh_common.R` are sourced unchanged; the `ng_*` scripts are new and sit beside
them.

| file | what |
|---|---|
| `ng_common.R` | sources `lh_common.R`; adds the replayed-program builder, the per-node readout of `w`, the two indicator components, and the R transcription of `bisect_flagged_intervals` |
| `ng_probe.R`, `ng_sd.R`, `ng_smoke.R` | the generator's shape, the `S_D` path, and §1's three identity checks |
| `ng_ind.R`, `ng_prof.R`, `ng_rain.R` | §3: the indicator decomposition, the integrand profile, the record by year |
| `ng_cost.R` | §2: `Σ M` over the step program and its two marginals |
| `ng_fixed.R` | §4: capture at the finest level, replay at the coarser ones |
| `ng_split.R` | §4: the stops-only control at the loop's own 17 bisection points |
| `ng_refine.R` | §8: the refinement loop, one iteration at a time |
| `ng_integrand.R`, `ng_zeros.R`, `ng_zcheck.R`, `ng_estab.R` | §5: the fine-level integrand, its exact zeros, and what sets them |
| `ng_fine.R` | §5: 1/16-year creations on `[5, 11]` |
| `ng_trans.R` | §6: thinning the transient |
| `ng_quad.R` | §7: the abscissa/state-dimension split and the alternative rules |
| `ng_tol429.R`, `ng_tol.R` | §5's tolerance ladder at 108 / 215 / 429, and the 858-node level (left running) |
| `ng_one.R` | a position-resolved rerun of `ng_split.R`; **stopped part-way** to free cores, and nothing here rests on it |
| `ng_queue.sh`, `ng_queue2.sh`, `ng_queue3.sh` | batch ordering and the `.so` mtime record between batches (`ng_queue_mtimes.log`) |

**`plant/src/plant.so` was read before and after every block and never moved:**
`2026-09-22 12:52:40.069214118 +0000` at the head and foot of every script's own
log, and in `ng_queue_mtimes.log` between batches. Nothing under `plant/`,
`odelia/` or `phylloptim/` was written, and nothing was compiled or committed.

---

## What was not reached

- **A creation-count-converged reference.** The ladder stops at 429, where `J` is
  still moving 7.8% per doubling. That doubling is not time integration — the
  429-node schedule holds to 0.021% over a decade of `ode_tol` — but nothing here
  says where the sequence is going, so every "against converged" statement in this
  note is against the *tolerance*-converged 108-node value of
  `diag-long-drought.md`, not against a creation-converged one. The 1e-4 tolerance
  arm at 108 / 215 / 429 finished and is in §5; the **858-node level was still
  running** when this was written, and its result lands in `ng_tol.log` and
  `ng_tol/n858_t1e-3.rds` in the scratchpad. It is the first thing a next session
  should read: it says whether the sequence 12.053 / 12.089 / 13.032 is going
  anywhere.
- **One trait, one record, one coordinate.** `lma = 0.32` on `long-drought`,
  `node_density_in_birth_date = TRUE` throughout, as the brief scoped it. §1's
  two-abscissae reading of the height branch, and the unsorted-abscissa
  observation beside it, are from the source and are **not measured**.
- **Derivatives.** Everything here is `J`. Whether the establishment jumps of §5
  are what the finite-difference scatter in `diag-jump-vs-floor.md` was
  differencing, and what they do to `dJ/dθ`, is untested — and it is the obvious
  next question, because a jump whose location moves with `θ` is a term the
  adjoint does not carry (H1).
- **Where the jumps are, exactly.** §5 locates them to 1/16 of a year on `[5, 11]`
  by running that window. Locating them from a reference trajectory — the
  establishment test is a pointwise function of the environment, so a root-find on
  a recorded run would place every boundary in the whole record for the cost of
  one solve — was not done.
- **A non-nested placement.** Every schedule here is the default grid plus
  bisections or a window. No grid placed directly by an error density was run, so
  §7's "17 graded nodes" is a statement about the rule and not about the solver.
