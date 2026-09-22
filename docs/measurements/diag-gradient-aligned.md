# The gradient on knot-aligned time grids

TF24 SCM, one species, `lma = 0.0825`, `max_patch_lifetime = 5`, forcing
`mixed-ordinary`, optimised `-O2` build, `TESTTHAT_PARALLEL = false`, serial
inside each run and two to four at a time on four cores.
`J = sum(scm$offspring_production)`.

Every "aligned" run forces an ODE stop at each of the 412 times where the
rainfall interpolant's curvature jumps, by the mechanism
`diag-knot-alignment.md` established:
`events(events_default(p), rainfall_pulse(time = knots, depth = 0))`.

**No code under `plant/` or `odelia/` was changed.** Both trees are clean at
`claude/trusting-curie-4i9n3l` (`5321593a` / `be3e2cb`), so the `make test-cpp`
/ plant fast-sweep guard did not apply and nothing was committed or pushed.
Everything below is scripts in this directory: `ga_common.R`, `ga_probe.R`,
`ga_fd.R`, `ga_fdshow.R`, `ga_fd2.R`, `ga_order.R`, `ga_order2.R`,
`ga_adjoint.R`, `ga_coord.R`.

---

## The six answers

**1. The plateau.** At the shipped `ode_tol = 1e-4`, aligned: **none**, over six
decades of `d`. Alignment cuts the step-placement residue in `J` from 0.44 to
0.00018 — three and a half orders — and a central difference still divides that
by `2d` and loses. **Two more decades of ODE tolerance on top of alignment buys
a plateau one and a half decades wide** (`d` = 1e-3 … 3.16e-5, flat to 0.63%,
3510 steps), which a pinned union program does not beat (one decade, 7771
steps). The two agree on `dJ/dlma = -3.281e-09` to 0.06%.

**2a. Order of `J`:** **~1.9**, aligned adaptive, readable over 12 → 45 nodes
and nowhere above 88. Reproduces the prior pinned-grid series to 0.2% at every
level, at a quarter of the ODE steps.

**2b. Order of `dJ/dlma`:** **not estimable on aligned adaptive grids at the
shipped tolerance.** The level-to-level scatter is 21% at `d = 1e-3`, larger
than the node error at the coarsest level. Two decades of extra tolerance cuts
that scatter to 0.5% and two windows become readable; the pinned union program
*with* the knots forced gives the same, and stops the ladder stalling past 45
nodes as well.

**3. Does the half-order loss survive?** **Yes, at the same size, on three
time-grid treatments that share no step placement.** Value order against
gradient order over the two coarse windows: pinned union with no knots (the
prior arm) 1.82 against 1.26, **gap 0.56**; pinned union + 412 knots 2.06
against 1.57, **gap 0.49**; aligned adaptive at `ode_tol = 1e-6` 1.91 against
1.47, **gap 0.44**. Alignment lifts both orders by ~0.2 and leaves the gap. The
finding does not relocate. What this design *cannot* say is whether the gap is
an asymptotic order difference or a coarse-end error constant — the value's
per-window orders are stable in every arm and the gradient's are not, and the
two aligned arms put the lag in opposite windows.

**4. The adjoint.** Reachable on aligned grids for all three census metrics and
all three traits, and **it shows no order loss at all**: the three `d/dhmat`
gradients converge at 1.29 / 1.57 against 1.31 / 1.66 for `J` and 1.61 / 1.37,
1.79 / 1.94 for the values. `d/drho` has the wrong sign at 12 nodes and no
order — the conditioning `diag-wrong-sign.md` found, untouched by alignment.
Still no seed for `sum(offspring_production)`.

**5. `hydraulic-shutdown`.** **Not zero on aligned adaptive grids at any cohort
level** — 0.0371 / 0.0285 / 0.0358 / 0.0268 / 0.0134 / 0.0103 / 0.0148 percent
at 12 … 697 nodes, against 0.4008% unaligned. **Exactly zero at every level of a
pinned program** — 12 through 175 nodes, measured here with the knots forced;
`diag-knot-alignment.md` found the same at 88 nodes without them. So it is
mostly, but not entirely, an artefact of step placement: forcing the knots
removes 93–97% of it, two more decades of `ode_tol` take another factor of
10–25 (down to 0.0006% at 697 nodes), and replaying a pinned program removes it
outright.

**6. What a percent of `J` is worth.** The two size-density coordinates give
stands within 20% of each other and offspring integrals **284 times apart**
(§6). Everything above is a real, repeatable statement about the discretisation
and none of it is something an optimiser on this fixture would act on.

---
## 1. The finite-difference stencil on the aligned configuration

Central difference in a relative step,
`(J(lma0(1+d)) - J(lma0(1-d))) / (2 d lma0)`, at the default 88-node schedule,
`d` swept from 1e-3 to 1e-9 in half-decade steps — thirteen steps, 81 runs
(`ga_fd.R`, height coordinate). Three arms: aligned at the shipped tolerance,
aligned four decades coarser, and unaligned at the shipped tolerance as the
control.

| `d` | aligned `ode_tol = 1e-4` | aligned `1e-2` | unaligned `1e-4` |
|---|---|---|---|
| 1e-3 | -3.168335e-09 | -3.289988e-09 | -2.883876e-08 |
| 3.16e-4 | **-3.216626e-09** (+1.52%) | -2.574527e-09 (-21.7%) | +1.608348e-07 (-658%) |
| 1e-4 | -5.481187e-09 (+70.4%) | -6.888444e-10 (-73.2%) | +1.214330e-06 (+655%) |
| 3.16e-5 | -4.333604e-09 | -6.723492e-09 | -1.437233e-07 |
| 1e-5 | -1.217422e-08 | -1.089546e-08 | +7.047971e-06 |
| 3.16e-6 | -1.031103e-08 | -6.175909e-09 | +2.176385e-04 |
| 1e-6 | +2.624657e-07 | +4.029384e-07 | +4.767542e-04 |
| 3.16e-7 | +3.666081e-07 | -7.742269e-07 | -4.145481e-04 |
| 1e-7 | -1.787850e-08 | -4.186334e-06 | -1.295953e-04 |
| 3.16e-8 | +3.970127e-06 | -1.089165e-06 | -1.696392e-02 |
| 1e-8 | -1.246774e-06 | +3.258517e-06 | -6.892912e-02 |
| 3.16e-9 | -4.930865e-06 | +5.824526e-06 | -2.033580e-01 |
| 1e-9 | +8.053776e-05 | -7.664751e-06 | +6.966492e-01 |

**No plateau on any of these three arms.** The widest run of consecutive steps
agreeing to within 1% per half-decade is zero steps long in all three. On the
aligned shipped-tolerance arm only the two widest steps are anywhere near each
other (1.52% apart), and §1.1 shows that agreement is inside their own scatter.

The `d = 1e-2` arm settles the brief's cost argument. Alignment makes `J`
correct to 0.1% at `ode_tol = 1e-2` with 1375 steps, so a whole stencil there is
cheaper than one unaligned run — **and the stencil it buys is unusable.** Its
two widest steps disagree by 21.7% and the value they extrapolate to,
-2.50e-09, is 24% from the converged -3.28e-09 of §1.2. A tolerance good enough
for the value is not good enough for a difference of it.

### 1.1 What sets the floor

Take the limit the two widest steps extrapolate to and read off what each pair
of runs got wrong. `(J+ - J-)` should be `2 d lma0 g`; the residue is the
step-placement move that changing `lma` caused, as a share of `J`:

| arm | median residue, `d <= 1e-4` | worst | elasticity `dlnJ/dln lma` |
|---|---|---|---|
| aligned `ode_tol = 1e-4` | **1.8e-4** | 6.0e-4 | -3.61 |
| aligned `ode_tol = 1e-2` | 1.9e-4 | 9.4e-4 | -2.80 |
| unaligned `ode_tol = 1e-4` | **4.4e-1** | 6.5e-1 | +84.7 |

Alignment buys **three and a half orders of magnitude** on that residue: 0.44 of
`J` down to 0.00018 of `J`. That is the value measurement's fix, seen through
the difference, and it is the single most useful number here. The unaligned
control's residue is 0.44 of `J` — a central difference there is not wrong by a
few percent but wrong by a factor, sign included, at every step from 1e-3 to
1e-9.

0.00018 is still not small enough at `ode_tol = 1e-4`, for an arithmetic reason.
A central difference divides the residue by `2 d`, so the relative error it puts
on the gradient is `residue / (2 d x 3.61)`: **2.5% at `d = 1e-3`, 8% at
`3.16e-4`, 25% at `1e-4`.** The observed 1.52% between the two widest steps is
*inside* that band — two draws from one scatter, not a plateau. Truncation moves
the other way (`O(d^2)`, about 1.7% at `d = 1e-3` from the same pair), so the
two curves cross without either becoming small.

### 1.2 The floor is the ODE tolerance, and two decades of it opens a plateau

That diagnosis makes a prediction: the residue is the adaptive controller's
sub-step placement *between* the forced knots, so tightening the tolerance
should lower it, and replaying a pinned program should remove it. Both, at
88 nodes (`ga_fd2.R`):

| `d` | aligned `ode_tol = 1e-6` (3510 steps) | pinned union + knots, `1e-4` (7771 steps) |
|---|---|---|
| 1e-3 | -3.267689e-09 | -3.279434e-09 |
| 3.16e-4 | -3.283819e-09 (+0.49%) | -3.280743e-09 (+0.04%) |
| 1e-4 | **-3.282522e-09** (-0.04%) | **-3.257973e-09** (-0.69%) |
| 3.16e-5 | -3.263219e-09 (-0.59%) | -3.372338e-09 (+3.51%) |
| 1e-5 | -2.002556e-09 (-38.6%) | -3.261522e-09 (-3.29%) |

**Aligned at `ode_tol = 1e-6` there is a plateau one and a half decades wide** —
`d` from 1e-3 to 3.16e-5, every step within 0.6% of the last, total spread
0.63%. The difference itself scales linearly with `d` over exactly that range
(`(J+-J-)/J0` = -7.318e-3, -2.326e-3, -7.351e-4, -2.311e-4: ratios 3.15, 3.16,
3.18 against the 3.162 a derivative demands) and breaks at `d = 1e-5`. The
residue there is **3.7e-5** of `J`, five times lower than at `ode_tol = 1e-4`.

**The pinned program gives a narrower plateau at more than twice the cost** —
one decade, 1e-3 to 1e-4, flat to 0.7% — and the two arms agree on the answer to
**0.06%**: -3.2825e-09 against -3.2807e-09. Two time-grid treatments that share
no step placement, one adaptive and one replayed, land on the same gradient.

So the answer to "is the plateau wider or the floor lower" is: at the shipped
tolerance, neither — there is no plateau at all. **Two decades of extra ODE
tolerance on top of alignment buys a 1.5-decade plateau and a floor of 3.7e-5,
for 1.9x the steps; the pinned union program buys one decade for 4.3x the
steps.** Tolerance is the cheaper knob, and on this fixture
`dJ/dlma = -3.281e-09` at 88 nodes.

---

## 2. The convergence order, every level aligned to the same 412 knots

Node levels 12, 23, 45, 88, 175, 349, 697 — three coarsenings of the default
schedule and three refinements, nested, as `diag-gradient-error.md` established
is necessary (refining alone leaves no error to halve). Every level adaptive at
`ode_tol = 1e-4` with the same 412 knots forced as step boundaries; 49 runs
(`ga_order.R`, height coordinate).

### `J`

| nodes | steps | `J` | error vs 697 | falls by |
|---|---|---|---|---|
| 12 | 1678 | 8.061603229e-11 | **+9.586%** | — |
| 23 | 1716 | 7.548012861e-11 | **+2.605%** | 3.68 |
| 45 | 1762 | 7.411314837e-11 | **+0.747%** | 3.49 |
| 88 | 1825 | 7.363213776e-11 | **+0.093%** | 8.04 |
| 175 | 1913 | 7.369501529e-11 | +0.178% | 0.52 |
| 349 | 2064 | 7.358997765e-11 | +0.036% | 4.96 |
| 697 | 2395 | 7.356384906e-11 | 0 | — |

**Order ~1.9, readable over 12 → 45 and nowhere above 88 nodes.** The first two
halvings give 3.68 and 3.49 (orders 1.88, 1.80); from 88 nodes the series is
non-monotone and its moves (0.09%, 0.18%, 0.04%) are the size of the aligned
time grid's own residue, which `diag-knot-alignment.md` measured at 0.06–0.21%.

This reproduces the prior pinned-grid value series — 8.044e-11, 7.539e-11,
7.397e-11, 7.362e-11, 7.356e-11, 7.344e-11, orders 1.83 / 2.04 — to within
**0.22% at all six shared levels**. **Alignment alone recovers the shared-grid
measurement of the value**, at 1825 steps instead of the union program's 7359.

### `dJ/dlma`

| nodes | `d = 1e-3` | `d = 3.16e-4` | `d = 1e-4` |
|---|---|---|---|
| 12 | -3.09110e-09 | -3.08296e-09 | -1.50391e-08 |
| 23 | -3.51866e-09 | -3.61873e-09 | -3.53379e-09 |
| 45 | -3.09836e-09 | -3.61761e-09 | -3.14956e-09 |
| 88 | -3.16833e-09 | -3.32437e-09 | -5.48119e-09 |
| 175 | -3.81544e-09 | -3.86228e-09 | -3.43068e-09 |
| 349 | -3.39819e-09 | -3.38652e-09 | -2.82293e-09 |
| 697 | -3.63164e-09 | -3.74293e-09 | -3.82106e-09 |

**No order is estimable, and no line should be fitted to this.** The spread
across levels is **21.4%** at `d = 1e-3` and **22.1%** at `3.16e-4`; the spread
across the three difference steps at one level runs from 2.8% (23 nodes) to 169%
(12 nodes). The sequence changes direction at four of the six steps. The node
error this was meant to resolve — read off the prior pinned ladder — is 8.9% at
12 nodes and 1.4% by 45, so **the scatter is larger than the signal at every
level, including the coarsest.**

This is §1.1's arithmetic playing out along the ladder instead of along `d`:
each level chooses its own sub-steps between the forced knots, each level's `+`
and `-` runs move them differently, and the residue is ~2e-4 of `J` whichever
level you are on. It is not a property of the node grid and refining does not
help.

### The same ladder at `ode_tol = 1e-6`

§1.2 says the residue is the tolerance, so the ladder was re-run two decades
tighter — same 412 knots, same seven levels, 35 runs, 3182–6714 steps
(`ga_order.R 1e-6`). Errors against the 697-node value:

| nodes | `J` | order | `dJ/dlma` (`d = 1e-3`) | order |
|---|---|---|---|---|
| 12 | +9.535% | — | +9.431% | — |
| 23 | +2.649% | **1.85** | +2.782% | **1.76** |
| 45 | +0.681% | **1.96** | +1.236% | **1.17** |
| 88 | +0.223% | 1.61 | -0.055% | — |
| 175 | +0.159% | 0.49 | +0.192% | — |
| 349 | -0.004% | — | -0.547% | — |

Tightening turns the gradient's 21% level-to-level scatter into **0.5%**, and
with it two readable windows appear. It does not produce a clean sequence: from
88 nodes on the gradient still changes direction at every step, at a few tenths
of a percent — §1.2's 3.7e-5 residue, divided by `2d`. **Two decades of extra
tolerance buys two windows of order, not a converged ladder.**

---

## 3. Does the half-order loss survive alignment?

Not answerable from §2 — on aligned adaptive grids `dJ/dlma` has no order to
compare. So the question was re-asked on the configuration the prior finding
used, plus the one thing this measurement adds: **the union program replayed at
every level with the 412 knots forced on top of it** (`ga_order2.R`, 25 runs,
levels 12–175, 7700–7855 steps each, every level's introductions present in the
program). Errors are against each series' own order-2 Richardson limit from its
last two levels, so the final column is 4.00 by construction and is not read.

| | 12 | 23 | 45 | 88 | orders |
|---|---|---|---|---|---|
| **pinned + knots** `J` | +9.366% | +2.499% | +0.569% | +0.102% | **1.91, 2.13**, 2.48 |
| **pinned + knots** `dJ/dlma` | +6.853% | +3.283% | +0.836% | +0.246% | **1.06, 1.97**, 1.77 |
| *pinned, no knots* `J` | +9.585% | +2.703% | +0.769% | +0.299% | *1.83, 1.81*, 1.36, 0.46 |
| *pinned, no knots* `dJ/dlma` | +9.180% | +3.792% | +1.611% | +1.252% | *1.28, 1.24*, 0.36, 0.47 |

**The half-order loss survives.** Over the two windows that are clean on both
arms, the value averages 2.02 aligned against 1.82 unaligned, and the gradient
1.52 against 1.26 — **alignment lifts both by about 0.2 of an order and leaves
the gap between them at 0.50, against 0.56 before.**

The gap is not an artefact of the reference. Re-reading every arm against its
own finest level instead of a Richardson limit moves each order by up to 0.1 and
leaves the same picture, and it lets the `ode_tol = 1e-6` ladder of §2 — which
has no pinned program in it at all — into the comparison. Orders over the two
coarse windows:

| arm | steps at 88 nodes | `J` order | `dJ/dlma` order | **gap** |
|---|---|---|---|---|
| pinned union, no knots (prior) | 7278 | 1.83, 1.81 → 1.82 | 1.28, 1.24 → 1.26 | **0.56** |
| pinned union + 412 knots | 7771 | 1.92, 2.19 → 2.06 | 1.08, 2.06 → 1.57 | **0.49** |
| aligned adaptive, `ode_tol = 1e-6` | 3510 | 1.85, 1.96 → 1.91 | 1.76, 1.17 → 1.47 | **0.44** |

**0.56, 0.49, 0.44** — from a replayed program, a replayed program with the
knots, and an adaptive grid with the knots and a tighter tolerance, which share
no step placement with one another. The finding does not relocate.

Two things alignment does change, and they are worth more than the unchanged
gap:

- **It stops the ladder stalling.** Unaligned, both series quit converging after
  45 nodes: `J` falls by 2.57 then 1.37 per halving and the gradient by 1.29
  then 1.38, where 4 is the second-order rate. Aligned, they keep going — `J`
  5.57, gradient 3.40 over 45 → 88. The prior note's "the ratios past 45 nodes
  are not trustworthy" was the time grid, and alignment removes it.
- **It gives the difference a plateau to stand on.** Across the two difference
  steps at each level, the pinned+knots gradients agree to **0.042%, 0.420%,
  0.117%, 0.040%** at 12, 23, 45, 88 nodes, against 2.8–169% on the aligned
  adaptive ladder. (At 175 nodes the two steps disagree by 9.4% — one of those
  four runs took a different branch; that level is why the 45 → 88 order above
  is quoted but the 88 → 175 one is not.)

**What the measurement cannot settle.** The gap is solid in the mean and absent
in any single window. The value's two per-window orders are stable in every arm
(1.83/1.81, 1.92/2.19, 1.85/1.96); the gradient's are not (1.28/1.24,
**1.08/2.06**, **1.76/1.17**) — and the two aligned arms put the lag in opposite
windows. So the scatter of a single order estimate is larger than the half-order
being estimated, and **this design cannot say whether the gap is an asymptotic
order difference or a larger error constant at the coarse end.** It can say the
gap is there, is about half an order, and does not depend on which of three
time-grid treatments produced it. Separating the two explanations needs a level
below 12 nodes, or the adjoint (§4), which needs no difference step at all.

---

## 4. The adjoint

`stand_gradient()` answers on aligned grids without complaint, for all three
registered census metrics and all three traits, at every level tried
(`ga_adjoint.R`, six levels, `node_density_in_birth_date = TRUE`, aligned,
`ode_tol = 1e-4`). No finite difference anywhere in it. It remains unreachable
for `J = sum(offspring_production)` — unchanged from `diag-gradient-error.md`,
and no code was written here to change it.

| quantity | 12 | 23 | 45 | 88 | 175 | 349 | orders |
|---|---|---|---|---|---|---|---|
| `J` (offspring) | 1.202278e-08 | 1.781878e-08 | 2.015577e-08 | 2.089300e-08 | 2.098137e-08 | 2.106893e-08 | **1.31, 1.66**, 3.06, 0.01 |
| `leaf_area` | 1.6117484 | 1.6015998 | 1.5982652 | 1.5969751 | 1.5982949 | 1.5969099 | **1.61, 1.37**, -0.03, -0.07 |
| `d/dhmat` | 4.071578e-08 | 6.032994e-08 | 6.835717e-08 | 7.105188e-08 | 7.109054e-08 | 7.147145e-08 | **1.29, 1.57**, 6.12, -3.30 |
| `mass_above_ground` | 2.7552990 | 2.7486445 | 2.7506965 | 2.7547506 | 2.7513730 | 2.7523060 | non-monotone throughout |
| `d/dhmat` | 9.251377e-08 | 1.390403e-07 | 1.581115e-07 | 1.643894e-07 | 1.646678e-07 | 1.655020e-07 | **1.29, 1.60**, 4.49, -1.58 |
| `area_stem` | 5.002100e-04 | 4.966351e-04 | 4.956017e-04 | 4.953322e-04 | 4.955645e-04 | 4.952247e-04 | **1.79, 1.94**, 0.21, -0.55 |
| `d/dhmat` | 1.029682e-11 | 1.526039e-11 | 1.729202e-11 | 1.797648e-11 | 1.798337e-11 | 1.807978e-11 | **1.29, 1.57**, 6.63, -3.81 |

**Here the gradient converges at the value's order, with no half-order gap.**
The three `d/dhmat` sequences give 1.29 and 1.57 — the same two numbers to two
decimals, because `hmat` reaches all three metrics by the same path — against
1.31 / 1.66 for `J`, 1.61 / 1.37 for `leaf_area` and 1.79 / 1.94 for `area_stem`.
The `lma` gradients carry one readable window each and agree with it:
`d(leaf_area)/dlma` 1.83 and `d(area_stem)/dlma` 1.91 over 23 → 45 → 88 (their
12-node values are 23% and 18% off, and the 5.65 / 4.80 that window produces is
not an order).

**The `rho` gradients carry none.** `d(leaf_area)/drho` and `d(area_stem)/drho`
have the **wrong sign at 12 nodes** (+1.267e-04 against -4.79e-04; +2.379e-08
against -1.29e-07) and scatter by ~2% thereafter without decaying — the
conditioning `diag-wrong-sign.md` measured, untouched by alignment.

**Where the adjoint stops.** Every sequence flattens at 88 nodes and then
scatters: the values by 0.08% per level and the gradients by 0.2–0.35%. That is
the aligned adaptive time grid's residue again — §1.1's floor, seen without a
finite difference — and the gradients sit 3–4x above the values on it. Refining
the node grid past 88 buys nothing on this configuration; tightening `ode_tol`
(§1.2) is what would.

**Read §4 against §3 with care.** The adjoint runs on the birth-date coordinate
and the finite differences on the height coordinate, and §6 shows those are two
stands whose `J` differs by a factor of 284. The two sections are two
measurements of the same question, not a cross-check of the same numbers.

---
## 5. Operating-point shares at every cohort level

`operating_point_counts` (`tf24_strategy.h:1354`), cleared at the start of each
run and read at the end, as a share of all leaf solves. Aligned adaptive,
`ode_tol = 1e-4`, height coordinate:

| nodes | solves | interior | boundary-crit | boundary-root-crit | determined | **hydraulic-shutdown** |
|---|---|---|---|---|---|---|
| 12 | 312 652 | 92.386% | 7.574% | 0.00064% | 0.00160% | **0.0371%** |
| 23 | 583 291 | 91.103% | 8.867% | 0.00034% | 0.00154% | **0.0285%** |
| 45 | 1 126 508 | 89.478% | 10.485% | 0.00036% | 0.00160% | **0.0358%** |
| 88 | 2 253 892 | 88.211% | 11.761% | 0.00018% | 0.00169% | **0.0268%** |
| 175 | 4 560 880 | 88.192% | 11.793% | 0.00013% | 0.00156% | **0.0134%** |
| 349 | 9 449 691 | 88.187% | 11.801% | 0.00008% | 0.00150% | **0.0103%** |
| 697 | 20 666 562 | 87.460% | 12.524% | 0.00015% | 0.00134% | **0.0148%** |
| *88, unaligned* | *2 220 774* | *86.035%* | *13.515%* | *0.00081%* | *0.0484%* | ***0.4008%*** |

**Aligned grids do not show zero shutdown at any level.** The answer to the
question as posed is no. What they show is 0.010–0.037% against the unaligned
0.4008% — **11 to 40 times lower, never zero**, and drifting down with
refinement (0.037% at 12 nodes, 0.010–0.015% at 349–697) without reaching it.
`boundary-root-crit` and `determined` behave the same way: cut by 4–30x, not
removed.

The same ladder on the birth-date coordinate (`ga_adjoint.R`) says the same
thing with different numbers: 0.0830, 0.0604, 0.0598, 0.0396, 0.0231, 0.0185
percent at 12 … 349 nodes.

Tightening the tolerance attacks it as well, and harder than refining the nodes
does. Aligned adaptive at `ode_tol = 1e-6` (`ga_order.R 1e-6`):

| nodes | 12 | 23 | 45 | 88 | 175 | 349 | 697 |
|---|---|---|---|---|---|---|---|
| **hydraulic-shutdown** | 0.0037% | 0.0027% | 0.0021% | 0.0015% | 0.0012% | 0.0009% | **0.0006%** |
| `boundary-root-crit` | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| `interior` | 94.07% | 93.15% | 92.26% | 89.59% | 82.29% | 68.70% | 52.17% |

Two decades of tolerance take another factor of 10–25 out of it and drive
`boundary-root-crit` to exactly zero at every level. Three knobs move the same
branch in the same direction — the knots, the tolerance, and replaying a
program — which is what a step-placement artefact looks like and not what a
property of the stand looks like.

The `interior` column is a separate effect and not a diagnostic of anything
wrong: as cohorts multiply, a growing share of solves sit against the
`psi_crit` bound, 94% interior at 12 nodes falling to 52% at 697. That is the
stand being resolved, not the grid failing.

The pinned union program **with** the knots forced (`ga_order2.R`, §3) settles
which half of that is the grid. At every one of its five levels:

| nodes | solves | interior | boundary-crit | boundary-root-crit | determined | **hydraulic-shutdown** |
|---|---|---|---|---|---|---|
| 12 | 1 097 510 | 89.012% | 10.988% | **0** | **0** | **0** |
| 23 | 2 007 324 | 88.341% | 11.659% | **0** | **0** | **0** |
| 45 | 3 800 870 | 88.000% | 12.000% | **0** | **0** | **0** |
| 88 | 7 437 051 | 87.847% | 12.153% | **0** | **0** | **0** |
| 175 | 14 807 660 | 87.853% | 12.147% | **0** | **0** | **0** |

**Exactly zero at every cohort level** — `hydraulic-shutdown`,
`boundary-root-crit` and `determined` together, and over 28 million leaf solves.
So `hydraulic-shutdown` is **mostly, but not entirely, an artefact of step
placement.** Forcing the knots removes 93–97% of it, two more decades of
tolerance take another 10–25x, and replaying a pinned program removes it
outright at every node count from 12 to 175. What survives alignment is the
adaptive controller's own sub-step placement between the knots — the same
residue every other measurement in this note runs into.

---

## 6. Two size-density coordinates, two answers for `J`

The brief's setup specifies `node_density_in_birth_date = TRUE`, which the
adjoint requires; every prior measurement in this workspace ran on the height
coordinate. They are not comparable, and the size of the gap is worth recording.
Same aligned grid, same 88-node schedule, same tolerance, one run each
(`ga_coord.R`):

| | steps | `J` | `leaf_area` | `mass_above_ground` | `area_stem` |
|---|---|---|---|---|---|
| height | 1825 | 7.36321378e-11 | 1.9419496 | 3.1626395 | 6.1014506e-04 |
| birth date | 1758 | 2.08930014e-08 | 1.5969751 | 2.7547506 | 4.9533216e-04 |
| ratio | | **283.75** | 0.822 | 0.871 | 0.812 |

**The two stands are within 20% of each other and their offspring integrals are
284 times apart.** Both are converged in the node grid on their own ladder — the
height series is flat to 0.09% by 88 nodes (§2), the birth-date series to 0.4%
by 175 (§4) — so this is not one of them being unresolved.

That single line is the honest scale for everything else in this note: **a 13–19%
difference in standing biomass moves `J` by two and a half orders of
magnitude.** A 140% error in `J` from step placement, or a 2% error in
`dJ/dlma`, is a real and deterministic statement about the discretisation and
nothing an optimiser would act on, because `J` on this fixture is ten orders
short of a self-replacing stand and exponentially sensitive to everything.
`max_patch_lifetime = 5` is what makes that true, not the forcing and not the
integrator.

---

## 7. Is a relative change on `J ~ 1e-10` meaningful?

**As discretisation, yes, and it is deterministic.** Every number here
reproduces: the aligned 88-node `J = 7.36321378e-11` came back identically from
`ga_probe.R`, `ga_fd.R` and `ga_order.R` in three separate process invocations,
and the unaligned `1.77114282e-10` matches `diag-knot-alignment.md` to every
digit printed. The "scatter" in §1 and §2 is not randomness — it is a
deterministic, piecewise-smooth-with-jumps dependence of `J` on `lma`, and it
repeats exactly.

**As anything an optimiser would act on, no**, for the reason §6 measures. Both
statements have to be made together; either alone misleads.

---

## What is missing

- **One forcing record and one trait point.** Everything is `mixed-ordinary`
  and `lma`. `dJ/drho` and `dJ/dhmat` were not swept; the other four records
  were not run. The stencil's floor (§1.1) is a property of this record's knot
  structure and should not be assumed elsewhere.
- **The birth-date ladder carries the adjoint only.** No finite-difference
  order ladder was run on the birth-date coordinate, so §2's "not estimable" is
  a height-coordinate statement. Given §6 the two should not be assumed to share
  it.
- **The adjoint ladder stops at 349 nodes**, not 697, and it is one tolerance.
  Its floor at 88+ nodes is attributed to the aligned time grid on the strength
  of §1.1's residue and §1.2's tolerance sweep, not measured directly by
  re-running the adjoint ladder at `ode_tol = 1e-6` — which §2 shows would move
  it, and which is the obvious next run.
- **The pinned+knots ladder stops at 175 nodes** and one of its four runs there
  took a different branch (the two difference steps disagree by 9.4% at that
  level alone), so §3 rests on four levels, not five.
- **Every order in §3 is a mean of two windows.** Two windows cannot separate an
  asymptotic order from an error constant, and the per-window estimates disagree
  by up to 0.9 within one arm. The three arms agreeing on the *mean* gap is the
  evidence; no single window is.
- **No `J` seed for the adjoint.** Unchanged. `offspring_produced_survival_weighted`
  is an ODE state and `Patch::offspring_production` is a linear functional of the
  terminal state, so only the seed is missing — and it is the one change that
  would remove the finite difference from §2 entirely.
- **Wall times are contended**: two other sessions shared the four cores for
  most of this measurement. Step counts, node counts, `J` and gradients are
  exact; seconds are not.

## Scripts

| file | what |
|---|---|
| `ga_common.R` | aligned SCM construction, the node ladder, the adjoint call, branch shares |
| `ga_probe.R` | sizing: both coordinates, four tolerances, one adjoint |
| `ga_fd.R` / `ga_fdshow.R` | the 13-step stencil, three arms (§1) |
| `ga_fd2.R` | the stencil on a pinned program and at a tighter tolerance (§1.2) |
| `ga_order.R` | the seven-level aligned adaptive ladder, at `ode_tol` 1e-4 and 1e-6 (§2, §3, §5) |
| `ga_order2.R` | the same levels on the union program with the knots forced (§3) |
| `ga_adjoint.R` | the reverse-mode ladder, census metrics (§4) |
| `ga_coord.R` | the two coordinates side by side (§6) |
