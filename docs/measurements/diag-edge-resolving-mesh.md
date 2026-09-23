# A mesh whose panels respect the establishment edges converges at second order, and where the edge node goes decides the answer

TF24 SCM, one species, `lma = 0.32`, `max_patch_lifetime = 40`,
`node_density_in_birth_date = TRUE`, forcing `long-drought` (the 41-year daily
seasonal Markov-chain gamma record of `diag-long-drought.md`, 14 599 daily
control points in range, three multi-year droughts), `ode_tol_rel =
ode_tol_abs = 1e-3`, aligned — a zero-depth rainfall pulse at each of the 2931
active knots. `J = sum(scm$offspring_production)`, which
`diag-nested-grid.md` §1 establishes is exactly `trapezium(node_times, w)`.

Reproduction check, run first: `J = 12.052622159` at 9931 steps on the default
108-node schedule, against `diag-long-drought.md`'s,
`diag-long-horizon-remeasure.md`'s, `diag-nested-grid.md`'s and
`diag-establishment-ramp.md`'s `12.0526222` at 9931. Every digit and the same
step count, in 130.5 s.

**No code under `plant/`, `odelia/` or `phylloptim/` was changed and nothing was
compiled.** `plant/src/plant.so` read `2026-09-22 12:52:40.069214118 +0000`
before and after every measurement block and never moved. Everything below is
scripts in the scratchpad, listed in §8. `ld_common.R`, `lh_common.R` and
`rw_common.R` are sourced unchanged, the edge table is `rw_final.R`'s read from
disk rather than recomputed, and every original beside them is untouched.

---

## The five numbers

| | |
|---|---|
| **It converges** | Edges fixed, fill halving: `J` = 12.284868878 / 12.276775477 / 12.275416201 at 498 / 793 / 1378 nodes. Differences **−8.09e-03, −1.36e-03**, ratio **5.95**, **`log2` = 2.57**. Against the uniform ladder's +0.0362, +0.9427, −0.1882 with ratios 0.04 and −5.01 and no `h^p` to fit. **The non-convergence was straddled-edge error.** |
| **The converged value** | Richardson on the last two rungs at the measured `p = 2.574`: **`J` = 12.27514**, remainder 2.7e-04. At `p = 2` it is 12.27496. Two residual biases are quantified in §5 and total **−6e-04**; the value is **`J` = 12.2751 ± 0.0006** with the fixture's own tolerance channel (+0.29% for a decade of `ode_tol`) outside it. |
| **Bracketing is the only placement that works** | At one fill, `J` = **12.2849 (bracket)**, 12.5160 (node at the crossing alone), 10.9834 (node at the ramp's midpoint), 10.8700 (node past the ramp's top). The two one-node-inside-the-ramp placements are **−11% and −12%**, and the reason is not their own panels: a near-plateau cohort whose trapezium weight spans a dead band inflates the canopy, and the integrand falls 12–18% **everywhere, including at `b < 1` where there is no edge**. |
| **Placement beats count by two orders** | At 498 nodes and 495 s the edge mesh is **0.079%** from the converged value. The uniform ladder is 6.16% at 429 nodes and 4.63% at 857 nodes / 1028 s — so the edge mesh is **78× more accurate at 16% more nodes** than uniform 429, and **58× more accurate at 0.48× the wall clock** than uniform 857: **121× the accuracy per second.** |
| **The error is mostly not in `J`'s own quadrature** | Dropping just the 72 ramp-top nodes from the bracket mesh (leaving it a strict subset) costs **−0.0817** of quadrature and **+0.3128** of integrand: the canopy channel is **3.8×** the trapezium channel. A cohort mesh here is a discretisation of the environment before it is a quadrature rule. |

---

## 1. The mesh: a fixed edge set and a fill that halves

The edge table is `diag-establishment-ramp.md`'s, read from
`rw/edges_final.rds` rather than recomputed: 112 crossings of `P = 0`, 56
closing and 56 opening, each with a root `b*`, a signed live side, a
half-plateau width `half = A/|dP/db|` and a 1%–99% ramp width
`w = 9.8494 * half`. **72 of them — 36 bands — lie inside the effective support
`[0, 22]`**, whose tail carries 8.8e-05 of `J`.

A schedule is four pieces, of which only one moves between levels:

| piece | what | count |
|---|---|---|
| head | the default generator's nodes with `b < 1/16`, verbatim | 56, frozen |
| fill | `seq(1/16, 22, by = h)`, minus every point inside a band-and-ramp interval | `h`-dependent |
| edges | the variant's own nodes at each of the 72 edges | 72 or 144, frozen |
| tail | the default generator's nodes with `b > 22.5`, verbatim | 8, frozen |

The **band-and-ramp interval** of a band is `[b*_close − w_close, b*_open +
w_open]` — the dead stretch and both its ramps. No fill point falls inside one
at any level, so the only nodes near an edge are the ones the variant puts
there, and *the edge treatment is literally identical at every rung*. The 36
intervals total 3.7098 yr of the 22.

The head is frozen because there is no edge below `b = 3.56` and the default
generator is already at `1e-5` to `1/64` spacing there; its own quadrature error
is of order `1e-5` relative, five decades below anything the ladder resolves.
The tail is frozen because it is 8.8e-05 of `J`. Freezing both means the ladder's
differences come from `[1/16, 22]` alone.

### The variants

`side` is `+1` on an opening edge (the live side is to the right of the root)
and `−1` on a closing one. Offsets are along the live side.

| | nodes per edge | offsets | 1/16 | 1/32 | 1/64 |
|---|---|---|---|---|---|
| **A** bracket | 2 | `0`, `w` | 498 | 793 | 1378 |
| **B** ramp midpoint | 1 | `w/2` | 426 | 721 | 1306 |
| **C** past the ramp top | 1 | `w` | 426 | 721 | 1306 |
| **D** the crossing alone | 1 | `0` | 426 | 721 | 1306 |
| **A3** bracket, closing ramp split | 4 / 2 | `0, half, 3 half, w` (closing); `0, w` (opening) | 570 | 865 | 1450 |
| control | none | — | 416 | 767 | 1469 |

The control is the same frozen head and tail with a uniform fill over
`[1/16, 22]` and no edge information at all — no edge nodes, no band exclusion.
Run at a fill spacing chosen to hit a target node count, it is the
placement-at-fixed-cost comparison.

Every schedule is supplied already sorted, and every run reads
`scm$node_schedule$times(1)` back: **`max|diff| = 0` on every run reported here**,
so the realised schedule is the one supplied. (`SCM::r_set_node_schedule_times`
stores the caller's raw vector while `NodeSchedule` sorts it, and `reshape_to`
indexes positionally, so this is not a formality.)

---

## 2. The ladder converges

Variant A, edges fixed, fill 1/16 → 1/32 → 1/64:

| fill | 1/16 | 1/32 | 1/64 |
|---|---|---|---|
| nodes | 498 | 793 | 1378 |
| `J` | 12.284868878 | 12.276775477 | 12.275416201 |
| difference | — | **−8.093e-03** | **−1.359e-03** |
| ratio | — | — | **5.954** |
| `log2` ratio | — | — | **2.574** |
| steps | 10 723 | 10 918 | 11 213 |

Against the uniform ladder of `diag-nested-grid.md` §5 at `ode_tol = 1e-3`:

| nodes | 108 | 215 | 429 | 857 |
|---|---|---|---|---|
| `J` | 12.0526222 | 12.0888310 | 13.0315024 | 12.8432659 |
| difference | — | +0.0362088 | **+0.9426714** | **−0.1882365** |
| ratio | — | — | 0.038 | −5.008 |

**The hypothesis holds.** The uniform sequence's second difference is 26× the
first and the third changes sign; the edge-respecting sequence's single ratio is
5.95, `log2` 2.57, and its first difference is **116× smaller** than the uniform
ladder's at a comparable count. A trapezium reading a steep `C1` feature as a
jump was the whole of the non-convergence.

The order is 2.57 rather than 2.00. Three things push it above two and none of
them is measured separately here: the fill is uniform but the integrand's decay
constant is not, so the leading `h^2` coefficient is not yet asymptotic; the
edge nodes and the head do not refine, so part of the error is constant and
drops out of the differences rather than contributing an `h^2` term; and the
integrand moves between levels through the canopy, which is a separate sequence
(§4) with its own rate.

### The two channels, separated exactly

The 1/16 schedule is a **strict subset** of the 1/32 schedule (498 of 498
abscissae shared), so the level-to-level change splits without approximation
into the integrand moving at abscissae both levels carry and the quadrature the
new abscissae add:

| | |
|---|---|
| total change, 1/16 → 1/32 | **−0.0080934** |
| the integrand moved (same abscissae, `w` re-read at 1/32) | **−0.0043302** |
| the quadrature resolved (the added abscissae) | **−0.0037632** |
| `\|dw\|/w` at the 469 shared live nodes | median **2.57e-03**, q90 5.45e-03, max 0.693 |

Both channels are the same size and both are small. This is the comparison that
`diag-nested-grid.md` §7 could not make on the uniform ladder, where the two
were 12.76% and the sequence turned.

---

## 3. Where the edge node goes

One fill (1/16), four placements, and a fifth for reference:

| variant | nodes | `J` | against A | steps | wall |
|---|---|---|---|---|---|
| **A** bracket | 498 | **12.284869** | — | 10 723 | 495.2 s |
| **D** the crossing alone | 426 | 12.515982 | **+0.2311 (+1.88%)** | 10 670 | 425.0 s |
| **B** ramp midpoint | 426 | 10.983385 | **−1.3015 (−10.59%)** | 10 687 | 432.7 s |
| **C** past the ramp top | 426 | 10.870003 | **−1.4149 (−11.52%)** | 10 733 | 431.9 s |
| the default schedule | 108 | 12.052622 | −0.2323 | 9 931 | 130.5 s |

**Bracket wins, and the reason B and C fail is not the reason the brief
expected.** Their own panels over the band-and-ramp intervals do misread, and by
the predicted sign and size:

| | contribution of the 36 band-and-ramp intervals to `J` |
|---|---|
| A | **0.02822** |
| B | 0.42627 |
| C | 0.44731 |
| D | 0.01467 |

B and C credit **+0.40 and +0.42 of `J` to birth dates on which nothing
establishes**, because their single node sits on the ramp at 0.96 and 0.99 of
the local plateau and the panel from it to the next edge's node spans the whole
dead band at that height. A places nodes at both roots, so every dead band is
bounded by nodes reading exactly zero and contributes exactly zero; what is left
in A's 0.028 is the two ramp panels, which is what should be there.

**But +0.40 is not −1.30.** The rest is the canopy. Read at the abscissae each
variant shares with A:

| variant | `w` relative to A, median over shared live nodes | the same, restricted to `b < 1` |
|---|---|---|
| B | **0.843** | **0.885** |
| C | **0.815** | **0.877** |
| D | **1.040** | **1.019** |

**At `b < 1` there is no edge, no dead band and no ramp** — the first crossing is
at `b = 3.56` — and yet a cohort born there produces 12% fewer offspring under B's
mesh than under A's. The only channel by which a cohort's fecundity can change
with the placement of nodes years later is the environment the whole stand
shares. The same trapezium weights that assemble `J` assemble the competition
integral, so a near-plateau cohort whose weight spans a dead band adds leaf area
that is not there, the canopy closes, and every cohort in the stand loses
carbon. *(The inflated-canopy reading is inference from the integrand ratio at
`b < 1`; no stand-leaf-area census was taken to confirm it — see §9.)*

### The crossing alone is first order, and it is 3.8× a canopy error

D's schedule is a strict subset of A's — it is A minus the 72 ramp-top nodes —
so its error decomposes exactly:

| | |
|---|---|
| D − A, total | **+0.2311129** |
| quadrature: A's integrand on D's abscissae | **−0.0816985** |
| integrand: the stand re-solved without those 72 cohorts | **+0.3128114** |
| predicted quadrature loss, `0.495 * sum(gap * w_top)` | −0.0841363 |

The quadrature term is the brief's own prediction — the panel runs from the
plateau to zero at the crossing and the trapezium returns about half the area it
should — and the closed form for it, `0.495 * gap * w`, lands within **3%** of the
measured −0.0817. It is first order in the fill: `gap` is the distance from the
last fill node to the start of the ramp, so it halves with `h`.

What the brief did not predict is that the **integrand term is 3.8× larger and
has the opposite sign**. Removing the ramp-top cohorts removes the leaf area
that should be standing right up to the moment the gate closes, the canopy opens,
and the whole stand produces more. A cohort mesh is a discretisation of the
environment before it is a quadrature rule, and a placement judged only on the
panels it draws will be judged on the smaller of its two effects.

---

<!-- SECTIONS 4-9 PENDING: control, converged value, cost, gradient, scripts -->
