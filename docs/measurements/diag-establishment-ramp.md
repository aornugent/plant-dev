# The establishment gate, measured: how wide the ramp is, and whether any mesh has ever landed on one

TF24 SCM, one species, `lma = 0.32`, `max_patch_lifetime = 40`,
`node_density_in_birth_date = TRUE`, forcing `long-drought` (the 41-year daily
seasonal Markov-chain gamma record of `diag-long-drought.md`, 14 599 daily
control points in range, three multi-year droughts), 108 creations in the
default schedule, `ode_tol_rel = ode_tol_abs = 1e-3`, aligned — a zero-depth
rainfall pulse at each of the 2931 active knots.
`J = sum(scm$offspring_production)`.

Reproduction check, run first: `J = 12.052622159` at 9931 steps, against
`diag-long-drought.md`'s, `diag-long-horizon-remeasure.md`'s and
`diag-nested-grid.md`'s `12.0526222` at 9931. Every digit and the same step
count.

**No code under `plant/`, `odelia/` or `phylloptim/` was changed and nothing was
compiled.** `plant/src/plant.so` read `2026-09-22 12:52:40.069214118 +0000`
before and after every measurement block and never moved. Everything below is
scripts in the scratchpad, listed in §7. `ld_common.R` and `lh_common.R` are
sourced unchanged and every original beside them is untouched.

---

## The five numbers

| | |
|---|---|
| **The gate's scale** | `A = a_d0 * seed area_leaf = 0.1 * 8.793079e-05 = `**`8.793079e-06 kg/yr`**. `recruitment_decay` is **0** for this strategy, so the time factor is exactly 1 over the whole horizon and `P_est = P^2/(A^2 + P^2)` alone. A newborn's carbon runs `-27.9 A` to `+22.0 A` over the horizon, so on a live birth date the plateau is **0.996**, not 1. |
| **The ramps are two populations, not one** | 112 crossings of `P = 0`: **56 closing** and **56 opening**. A **closing** edge (`P` falling into a dead band) runs 1% to 99% of its plateau over **1.7 to 9.0 days, median 5.5**. An **opening** edge (`P` rising out of one, after rain) over **0.071 to 0.71 days, median 0.18** — 31× steeper at the median. The Oracle's "of order per-day" for the wet edges is right and if anything generous. |
| **The dead set is 15% of the horizon** | `P <= 0` on **5.88 yr of 40 (14.7%)**, in **56 bands**, root to root **0.8 d to 170 d, median 22.6 d**. The first is at `b = 3.56` and there is none below `b = 3`. Fourteen of the 56 are in `(5, 10]`, the first drought. |
| **No schedule in use lands on a ramp** | Nodes with `0 < P_est < 0.99 * local plateau`: **0 of 108, 0 of 215, 2 of 429, 3 of 857**. Nodes reading an exact zero: 1, 3, 19, 38. The ramp set is **2.23% of the horizon**, so the counts are what the placement gives, not bad luck — but the answer at the operating count is zero, and every schedule yet run has sampled the gate as a two-valued function. |
| **A resolving mesh is cheaper than the ladder rung already paid for** | Over the effective support `[0, 22]` — the tail from there on carries `8.8e-05` of `J` — **374 nodes** (1/16-year fill on the live part plus one node at each of the 72 edges there) or **662** (five across each ramp), against the **108** in use and the **857** of the ladder's last rung. |

Separately and analytically (§6): the real-axis stability boundary of the
Cash-Karp **fifth-order** increment is **`beta = 3.7344`**, and the crossing is
at `R(z) = +1`, not `-1`.

---

## 1. The route: the gate is pointwise, and it can be read off one run

`TF24_Strategy::establishment_probability(environment)`
(`plant/inst/include/plant/models/tf24_strategy.h`) evaluates
`net_mass_production_dt` at `seed_geometry()`'s height and leaf area against the
environment it is handed, and reads nothing else. Its inputs are the soil-water
potentials, the light at the seed's height, the atmospheric constants and
`environment.time`; the newborn side of it is the same three numbers at every
birth date.

Three bindings make a scan possible with no rebuild:

- `Individual<TF24>::establishment_probability(environment)` and
  `Individual<TF24>::net_mass_production_dt(environment)` are both exposed
  (`inst/RcppR6_classes.yml`), and a freshly constructed `Individual` sits at
  `initial_height() = height_0`, with `competition_effect = area_leaf_0` — the
  same pair `seed_geometry()` returns.
- `Patch::set_ode_state(values, time)` loads a flat state (all nodes, then the
  environment), sets `environment.time`, and calls `compute_environment()`,
  which rebuilds the light field from the node heights and densities it was just
  given.
- `SCM::store_trajectory()` with `record_trajectory = TRUE` hands back every
  accepted step and every event row: time, step size, and the full state.

So one run gives the environment at every recorded row, and the scan is a walk:
introduce nodes until the count matches the row's state length, load the state,
ask a birth-size individual for its carbon. **1.0 ms a point.**

### It reproduces the run's own reading exactly

`Node::compute_initial_conditions` writes `-log(pr_estab)` into the newborn's
`mortality` state (or `establishment_failure_hazard` on the zero arm), so the
run records its own gate reading at each of the 108 introductions. Against the
replay:

| | |
|---|---|
| worst relative disagreement over the 107 live nodes | **1.4e-11** |
| nodes the run put at the floor | 1 (`b = 10`), replay `P = -1.956e-04` |
| `P_est` computed in R from `P` against C++'s `establishment_probability` | **identical to the last bit at all 108** |

The last line is why the scan reads `net_mass_production_dt` and not
`establishment_probability`: one leaf solve a point instead of two, and the gate
is then an algebraic function of `P` in R.

### Four time grids, one gate

The stop set changes the time grid and moves `J` within its own tolerance
channel; it does not move the gate.

| run | stops | steps | `J` | rows | scan |
|---|---|---|---|---|---|
| the fixture | 2931 active knots | 9931 | 12.052622159 | 12 970 | 15 s |
| + every quiet knot | 14 599 daily | 19 221 | 12.085620229 | 33 928 | 33 s |
| + sub-daily at each edge | 6513 | 13 348 | 12.073321463 | 19 969 | 9 s |
| + a tight window at each edge | 6528 | 13 429 | 12.041475419 | 20 065 | 8 s |

`J` spans 0.37% across the four, inside the +0.288% that a decade of `ode_tol`
moves this schedule (`diag-nested-grid.md` §5). **All four find the same 112
crossings and the same 56 dead bands.** The fixture run and the every-quiet-knot
run agree on the opening slopes to four digits at the median and on the closing
slopes to 10%; the two windowed runs agree on the closing slopes to 0.3% at the
median and move each crossing by a median of 0.007 days.

---

## 2. `A`, from the parameters

| | |
|---|---|
| `a_d0` | 0.1 |
| seed height, `height_0` | 0.3122526 m |
| seed leaf area, `area_leaf_0` | 8.793079e-05 m² |
| **`A = a_d0 * area_leaf_0`** | **8.793079e-06 kg/yr** |
| `recruitment_decay` | **0** |

`recruitment_decay = 0` removes `exp(-recruitment_decay * time)` entirely, so
the gate is a function of `P` alone and nothing about it drifts over the 40-year
horizon. `P_est = P^2/(A^2 + P^2)`: half its ceiling at `P = A`, 1% of it at
`P = 0.1005 A` and 99% at `P = 9.95 A`. It is `C1` and no better at the join —
value and first derivative are 0 on both arms, the second derivative is `2/A^2`
on one and 0 on the other — so `w(b)` is `C1` wherever `dP/db` is nonzero at a
root, which it is at all 112 of them.

The plateau it actually reaches is **not** 1. `P` at `b = 0` is
`1.863e-04 = 21.2 A`, giving `P_est = 0.9978`, and across the live stretches the
plateau runs **0.9076 / 0.9934 / 0.9965 / 0.9972 / 0.9979** (min, q25, median,
q75, max): one short stretch never gets `P` above `3.1 A` at all, so the gate
there never opens fully. At a plateau of 0.9977 the 1% and 99% points sit at
`0.1004 A` and `8.97 A`.

---

## 3. `P(b)` on a fine scan, and the two kinds of edge

`P` over the whole horizon runs `-2.454e-04` to `+1.937e-04`, i.e. `-27.9 A`
to `+22.0 A`. It is not a near-miss quantity anywhere: it is 20× the gate scale
on live birth dates and as much as 28× negative on dead ones, and the whole of
the structure is in the crossings.

### The dead set

| | |
|---|---|
| `P <= 0` | **5.875 yr of 40 — 14.69% of the horizon** |
| bands | **56** |
| band width, root to root | 0.8 d / 10.0 d / **22.6 d** / 59.4 d / 169.6 d (min, q25, median, q75, max) |
| bands narrower than 1/16 yr (22.8 d) | 28 of 56 |
| first band | `b = 3.56`; **none below `b = 3`** |
| bands by five-year window | 3, 14, 7, 9, 7, 5, 7, 4 from `[0,5)` to `[35,40)` |

This is `diag-nested-grid.md` §5's window extended to the whole record for the
cost of one run. Where that note ran 1/16-year creations over `[5, 11]` and
found **ten** runs of failing nodes, the scan finds **sixteen** bands
overlapping `[4.9, 11.1]`: the six it missed are 0.8 d to 6.7 d wide, all
narrower than the 22.8 d mesh it was sampled with. Its longest, "half a year,
eight nodes, `[7.375, 7.8125]`", is the band `[7.3635, 7.8282]` — **169.6
days** — located here to the hour.

### The ramps

Each edge taken to the finest window it was given: for 109 of 112, a stop set
whose brackets are 5 to 45 minutes and which puts **19 to 43 scan points inside
an opening ramp and 126 to 303 inside a closing one**. Over those windows the
quadratic term is **8% of the linear at the median for opening edges and 0.6%
for closing ones**, so `P` is linear across its own ramp and a secant slope is
the derivative.

| | min | q25 | **median** | q75 | max |
|---|---|---|---|---|---|
| **opening** (`P` rising, leaving a band) | | | | | |
| `\|dP/db\|` (kg/yr per yr) | 0.0213 | 0.110 | **0.150** | 0.219 | 0.389 |
| `A/\|dP/db\|` (days) | 0.0083 | 0.0147 | **0.0214** | 0.0291 | 0.151 |
| 1%–99% ramp (days) | 0.071 | 0.125 | **0.178** | 0.224 | 0.714 |
| ramp / (1/16 yr) | 0.0031 | 0.0055 | **0.0078** | 0.0098 | 0.031 |
| **closing** (`P` falling, entering a band) | | | | | |
| `\|dP/db\|` (kg/yr per yr) | 0.00301 | 0.00382 | **0.00483** | 0.00579 | 0.00723 |
| `A/\|dP/db\|` (days) | 0.444 | 0.554 | **0.664** | 0.839 | 1.068 |
| 1%–99% ramp (days) | 1.71 | 4.04 | **5.54** | 7.29 | 9.04 |
| ramp / (1/16 yr) | 0.075 | 0.177 | **0.243** | 0.320 | 0.396 |

**The gate closes gently and opens abruptly.** The median opening edge is 31×
steeper than the median closing edge, and the two width distributions do not
overlap: the widest opening ramp (0.71 d) is narrower than the narrowest closing
one (1.71 d).

Summed over all 112 edges the ramp set is **0.8915 yr, 2.23% of the horizon** —
and it is almost all closing: **0.861 yr on the 56 closing edges against 0.031
yr (11 days in total) on the 56 opening ones.**

### One edge, at two resolutions

The band `diag-nested-grid.md` ran at 1/16 year, `b in [7.375, 7.8125]`, where
`w` reads `0.388 -> 0 (eight nodes) -> 1.561`:

| | closing edge | opening edge |
|---|---|---|
| root | `b = 7.36345` | `b = 7.82821` |
| `P` at the daily samples either side | `+1.08e-05`, `-5.56e-06` | `-2.164e-04`, `+1.867e-04` |
| `\|dP/db\|` from the daily secant | 5.96e-03 | 1.47e-01 |
| `\|dP/db\|` from a 5-minute bracket | (not refined) | **3.89e-01** |
| 1%–99% ramp | 4.52 d | **0.0735 d — 1 h 46 min** |

The opening edge moves `P` by `4.03e-04` — 46 gate widths — between two
consecutive daily samples, and the daily secant under-reads its slope by
**2.6×**. It is the steepest of the 56, and its ramp is within 4% of the
narrowest (0.0707 d, at `b = 5.899`): `w` goes from 0 to its largest value past
`b = 1` across **one hour and three quarters** of birth dates. This is the
feature that motivated the measurement, and at 1/16-year spacing it is 0.3% of
one mesh interval.

The premise this measurement was set to test — that the ramp is narrower than 23
days and has never been resolved — is **confirmed for the opening edges and
overturned for the closing ones**. An opening ramp is 0.3% to 3% of one
1/16-year interval. A closing ramp is 8% to 40% of one, which is narrower than
the interval but the same order, not a different one.

---

## 4. Does anything land on a ramp?

A node is on a ramp when `0 < P_est < 0.99 * plateau` for the plateau of the
live stretch it sits in. The ladder is the nested bisection of the default
schedule (`lh_common.R`'s `bisect_all`), and the gate is the one measured above,
read at each node's birth date.

| creations | 108 | 215 | 429 | 857 |
|---|---|---|---|---|
| nodes in a dead band (`P_est = 0`) | **1** | **3** | **19** | **38** |
| nodes **on a ramp** | **0** | **0** | **2** | **3** |
| nodes on a plateau | 107 | 212 | 408 | 816 |
| expected on a ramp, nodes above `b = 1` placed uniformly | 0.7 | 1.4 | 2.9 | 5.7 |

**At the operating count of 108 nodes, not one node lands on a ramp, and the
same holds after the first bisection. The first appears at 429.**

The counts are close to what the ramp measure gives for a uniform placement, so
this is not a mesh landing unluckily: it is a mesh with 70% of its nodes below
`b = 1`, where no dead band exists, and 32 nodes spread over the 39 years where
they all do. The consequence stands either way — **every creation schedule so
far run has read `w(b)` as a two-valued function, `0` or its plateau, and the
`C1` ramp between them has never entered any of those answers.**

### The gate transfers across the ladder

Read off the *reference* run's environment and evaluated at the *ladder's*
birth dates, the scan predicts each level's floor count before that level is
run:

| creations | predicted dead nodes | the record |
|---|---|---|
| 108 | 1, first at `b = 10.0000` | 1, at `b = 10` (`diag-nested-grid.md` §3, §5) |
| 215 | 3, first at `b = 6.5` | 3, first at `b = 6.5` (§5) |
| 429 | 19 of 120 in `(1, 36)`, first at `b = 3.625` | 18 of 120, first at `b = 3.625` (§5) |

One node out of 120 at the third level, from a single run's trajectory. The
canopy feedback that the extra cohorts exert on the gate moves it by less than
one node in 120, which is what makes a pre-run scan a usable mesh-design
instrument.

---

## 5. What a resolving mesh costs

The effective support is where the integrand still carries `J`. From the
reference run's own per-node `w` and trapezium weights (which reproduce
`sum(scm$offspring_production)` to the last digit):

| tail from | carries |
|---|---|
| `b = 10` on | 9.6e-03 of `J` |
| `b = 18` on | 9.8e-04 |
| **`b = 22` on** | **8.8e-05** |

Take `[0, 22]`. Inside it there are **36 dead bands and 72 edges**, and the live
part is **18.82 yr**.

The support's own requirement is the smooth decay: `w` falls by 8% per
sixteenth of a year past `b = 7.9` (`diag-nested-grid.md` §5), i.e.
`tau = 0.75 yr`, and by a factor 4.2–5.1 a year over `[0, 3]` as well, so
`tau ~ 0.6-0.75` throughout. A trapezium panel of width `D` on `exp(-b/tau)`
carries `D^2/(12 tau^2)` relative, so 1/16 yr gives 5.8e-04 and 1/8 yr 2.3e-03.

| fill on the live support | fill | + one node at each edge | + 3 across each ramp | + 5 across each ramp |
|---|---|---|---|---|
| 1/8 yr | 151 | 223 | 367 | 511 |
| **1/16 yr** | 302 | **374** | 518 | **662** |
| 1/32 yr | 603 | 675 | 819 | 963 |

**Against the 108 in use and the 857 of the ladder's last rung.** A mesh that
puts a node on every edge and resolves the support to 0.06% is **374 nodes —
3.5× the operating count and 44% of the ladder rung already paid for**. Putting
five nodes across every ramp as well is 662, still below 857.

That is the headline, and the qualification is what five-across means on an
opening edge:

| | five across the ramp is a spacing of |
|---|---|
| median closing ramp (5.54 d) | 1.39 days |
| median opening ramp (0.178 d) | **64 minutes** |
| narrowest opening ramp (0.071 d) | **25 minutes** |

Cohorts born 25 minutes apart are not a mesh anyone will build. The measured
asymmetry says which half of the Oracle's §3(a) to take: **a closing edge is at
least sampled by a 1/64-year mesh (5.7 d against a 5.5 d median ramp) and
resolved by a 1/256-year one; an opening edge is not resolvable as a ramp by any
mesh, so it has to be treated as an edge** — panel boundaries
on them (§3(a)(i)/(2a)) or given a declared width (§3(a)(ii), `tau_g` of weeks,
which is exactly the "wet edges have `|d_b G|` of order per-day and give
needlessly narrow ramps" case). The opening ramps carry 11 days of birth dates
in total across 40 years; placing a node on each of the 36 opening edges inside
the support and calling the rest a jump costs, at worst, the `w+ D/2` term the
Oracle already prices.

---

## 6. `beta`, analytically

From the tableau in `odelia/inst/include/odelia/ode_step.hpp` (`ah`, `b21`,
`b3`–`b6`, `c1/c3/c4/c6`), with
`R(z) = 1 + sum_k z^k b' A^(k-1) e`:

| | `z^0` | `z^1` | `z^2` | `z^3` | `z^4` | `z^5` | `z^6` |
|---|---|---|---|---|---|---|---|
| fifth order (propagating) | 1 | 1 | 1/2 | 1/6 | 1/24 | 1/120 | **1/800** |
| `k!` × coefficient | 1 | 1 | 1 | 1 | 1 | 1 | **0.9** |
| fourth order (embedded) | 1 | 1 | 1/2 | 1/6 | 1/24 | 10517/1228800 | 1771/1638400 |

Five order conditions met, the sixth coefficient `0.9/6!` rather than `1/6!`.

| | real stability interval | crossing at | min `\|R\|` on it |
|---|---|---|---|
| **fifth order** | **`[-3.7343596, 0]`** | **`R(z) = +1`** | 0.132 at `z = -2.30` |
| fourth order (embedded) | `[-4.2078273, 0]` | `R(z) = +1` | 0.069 at `z = -2.73` |

The crossing is at `+1` and not `-1`: the `z^6` coefficient is positive, so
`R(z) -> +inf` as `z -> -inf`, `R` dips to 0.13 near `z = -2.3` and climbs back
through 1 without ever going negative. There is no second crossing.

**`beta = 3.7344`.** The Oracle's "about 3 for a fifth-order six-stage tableau"
is 25% low; 2.5 with margin sits a factor 1.49 inside the true boundary, which
is a sound choice, but it is being justified against the wrong number.

### Against the measured `h*|lambda|`

The 3.5–5.3 band is `spike-fixed-grid.md` §(2), not `diag-error-norm.md`, and it
is reported there as **`max h*|lambda|` over 12 samples per point**, at
`max_patch_lifetime = 5`, `lma = 0.0825`, `tol = 1e-8`. Amplification at those
values:

| `h\|lambda\|` | 3.51 | 3.734 | 4.12 | 4.63 | 5.04 | 5.26 | 8.63 | 16.16 |
|---|---|---|---|---|---|---|---|---|
| fifth order `R(z)` | 0.665 | **1.000** | 1.94 | 4.28 | **7.60** | 10.1 | 271 | 15 331 |

So the band straddles the boundary rather than sitting above "about 3": its low
end is inside, and its high end would amplify a real mode by 7.6 a step.

**Which of the two is wrong.** `beta` is arithmetic and is not in doubt, so the
question is what the 3.5–5.3 is a measurement of. Two candidates, and this
fixture closes one of them and answers the other. Taking `lambda` exactly as
that note does — the largest eigenvalue magnitude of the 5 soil-moisture states,
by central differences on `patch$derivs` — at 50 accepted steps of the reference
run:

| | |
|---|---|
| eigenvalues | **all five real and negative at every one of the 50 samples** (`max \|arg\| = pi` exactly) |
| `\|lambda\|` | 0.57 to 1.64e+04 |
| `h` | 1e-06 to 0.1376 yr |
| **`h*\|lambda\|`** | 0.033 / 0.93 / **1.86** / 2.30 / **4.61** (min after the first step, q25, median, q75, max) |
| samples above `beta = 3.7344` | **1 of 50**; above 2.5, 8 of 50 |

The eigenvalues are real and negative, so the escape that the relevant `z` sits
off the negative real axis — where the region is wider — is closed: the real
interval is the right bound. And the maximum here, 4.61, is inside
`spike-fixed-grid.md`'s 3.5–5.3, so the two agree on the statistic they share —
a maximum — across two fixtures five decades of tolerance and eight times the
horizon apart.

What does not survive is the *inference* drawn from it — "the adaptive
controller sits on the explicit stability boundary … pinned". **The median
accepted step runs at `h*|lambda| = 1.86`, half the boundary, and within 20% of
the `z = -2.30` where `|R|` is smallest.** One sampled step in fifty sat 23%
past `beta`; those are the domain throws and rejections `diag-rejections.md`
already counts, not the operating point. A maximum over a dozen samples of a
quantity whose median is half as large is not a pin.

The design consequence follows. At `m = 1` and `Lambda = |lambda|(t)`, a fill at
`h = 2.5/(m Lambda)` is **1.34× coarser than the step the controller typically
takes**, and 8 of the 50 sampled steps are already past it. So what makes the
designed grid finer than the adaptive one is the safety multiplier `m` and the
envelope over the box, not `beta` — and `beta` is 3.7344, not 3.

---

## 7. Scripts, and the build they ran against

All in the session scratchpad, all `Rscript <file> [args]`, all reading `plant`
through `pkgload::load_all` and `odelia` through `library`. `ld_common.R` and
`lh_common.R` are sourced unchanged; the `rw_*` scripts are new and sit beside
them.

| file | what |
|---|---|
| `rw_common.R` | sources `lh_common.R`; adds the trajectory capture, the patch replayer and the gate algebra |
| `rw_smoke.R`, `rw_probe.R` | §1: the route exists, and it reproduces the run's own 108 readings |
| `rw_scan.R` | §3: capture and scan a whole run (`ak` = the fixture, `days` = every quiet knot as well) |
| `rw_edges.R`, `rw_bands.R` | §3: crossings, slopes, widths, bands |
| `rw_fine.R`, `rw_fine2.R` | §3: two rounds of sub-daily windows at each edge |
| `rw_report.R`, `rw_mesh.R`, `rw_final.R` | §4, §5: the ramp measure, the ladder counts, the mesh cost |
| `rw_stab.R` | §6: the stability polynomials and the real-axis boundary |
| `rw_lam.R` | §6: the soil block's eigenvalues at the step sizes the run used |

**`plant/src/plant.so` was read at the head and foot of every script's own log
and never moved:** `2026-09-22 12:52:40.069214118 +0000` throughout. Nothing
under `plant/`, `odelia/` or `phylloptim/` was written, and nothing was compiled
or committed.

---

## What was not reached

- **One trait, one record, one coordinate.** `lma = 0.32` on `long-drought`,
  `node_density_in_birth_date = TRUE`. The band structure is a property of the
  record and of the stand's own water draw; nothing here says how it moves with
  `lma`, and that movement is exactly the transport term `dJ/dtheta` is missing
  (Oracle §3(a)). The instrument for it is already here — one run per `theta`,
  then a scan — but it was not run.
- **The gate on the ladder's own environment.** §4 reads the reference run's
  gate at the ladder's birth dates. The check against the record puts the error
  at one node in 120 at 429 creations, but the 857-node row is unchecked and the
  2 and 3 on-ramp counts are single nodes, where one node of slippage matters.
- **What the ramp is worth in `J`.** Every number here is geometry: where the
  edges are, how steep, what a mesh would have to be. No run was made with a
  mesh that resolves them, so the 7.8%-per-doubling non-convergence of
  `diag-nested-grid.md` §5 is *consistent with* a straddled-edge error but is
  not shown to be one. The 374-node mesh of §5 is the experiment that would
  settle it, and it has not been run.
- **The closing edges' mechanism.** The opening edges follow rain; the closing
  ones are the stand drying down and are 31× gentler, which is the timescale
  difference between an infiltration front and a depletion. That reading is not
  measured here — only the slopes are.
- **`beta` off the real axis.** §6 establishes the real interval and that the
  soil eigenvalues are real, on this fixture. A record or a `theta` that puts a
  complex pair in the soil block would need the region's boundary, not the
  interval, and the same is true of any fast mode outside the soil block —
  `spike-fixed-grid.md`'s caveat (ii) about leaf hydraulics and the storage pool
  applies here unchanged.
