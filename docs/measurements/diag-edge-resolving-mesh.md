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

## 5. The converged value, and the two biases the bracket leaves

Richardson on the last two rungs of the A ladder:

| | |
|---|---|
| at the measured `p = 2.574` | **`J` = 12.2751418**, remainder 2.74e-04 |
| at `p = 2` | `J` = 12.2749631, remainder 4.53e-04 |
| at `p = 3` | `J` = 12.2752220 |

The three agree to 2.6e-04, so the fill's own limit is **`J` = 12.2751 ± 0.0003**
at this edge treatment, tolerance and horizon. Two things sit between that and
the continuum, and both were measured rather than assumed.

### The edge locations transfer, and their error is a constant

The 112 roots were located on the *default 108-node* run's environment
(`diag-establishment-ramp.md` §3). Run with 498 and 793 cohorts the canopy is not
the same, so a node at a nominal root need not read a closed gate:

| | 1/16 (498 nodes) | 1/32 (793 nodes) |
|---|---|---|
| root nodes reading `w` exactly 0 | **28 of 72** | **28 of 72** |
| root reading as a fraction of the same edge's ramp-top reading | median **2.3e-04**, q90 0.35, max 0.92 | — |
| spurious dead-band area, `sum(band * (w_close + w_open)/2)` | **0.013055** | **0.013074** |

Fewer than half the root nodes land on the closed side, but the median root node
reads **2.3e-04** of its own plateau, so the gate is shut to four digits at most
of them and the whole spurious area is **0.0131 — 0.107% of `J`**. It is the
same to three digits at both levels, so it **biases the limit and cannot break
the convergence**, which is what the ladder shows.

### A bracketed ramp under-reads its own panel, by a computable amount

With `u = |P|/A` the gate is `u^2/(1 + u^2)` and `P` is linear across its own
ramp to 0.6–8% (`diag-establishment-ramp.md` §3), so a ramp's area in units of
`half = A/|dP/db|` is `[u − atan u]` and the trapezium over one panel from the
root to the 99% point is exact arithmetic:

| nodes across the ramp, in `u` | trapezium | true | deficit |
|---|---|---|---|
| `{0, 9.95}` — the bracket | 4.9252 | 8.4793 | **3.5541** |
| `{0, 1, 3, 9.95}` — A3 | 8.2177 | 8.4793 | **0.2616** |
| 8 equal panels | — | — | 0.0200 |

A ramp is also *exactly* equivalent to a jump displaced `atan(u_max) ≈ pi/2`
half-widths onto the live side — **15.95% of the way up the 1%–99% ramp, not
50%** — which is why the ramp's midpoint reads 0.962 of the plateau and not 0.5,
and why variant B is not the "effective jump" its name suggests.

Weighted by variant A's own envelope at each edge, the bracket's deficit is
**0.01248 — 0.102% of `J`** (0.01184 on the closing edges, 0.00064 on the
opening ones), and it predicts **A3 − A = +0.01097**.

### Run rather than predicted: the edge treatment is worth −0.12%

| | 1/16 | 1/32 |
|---|---|---|
| A (bracket) | 12.284868878 (498) | 12.276775477 (793) |
| A3 (closing ramp split at `u = 1, 3`) | 12.270302764 (570) | 12.264585195 (865) |
| A3 − A | **−0.0145661** | **−0.0121903** |

A is a strict subset of A3, so the same exact split applies:

| | |
|---|---|
| A3 − A at 1/16, total | **−0.0145661** |
| quadrature (the 72 added ramp-interior nodes) | **+0.0058232** |
| integrand (the stand re-solved with them) | **−0.0203893** |
| predicted quadrature term | +0.0109663 |

**The sign of the total is the opposite of the prediction, and the canopy is
why.** The direct term is positive, as the arithmetic says, and lands within a
factor 1.9 of it — the gap is that the realised gate is offset from the nominal
root at the edges where only 28 of 72 roots read zero, so a node placed one
`half` from the nominal root is not one `half` from the realised one. But
resolving the ramp also resolves the leaf area standing on it, the canopy closes
slightly, and the integrand falls 0.25% (0.16% at `b < 1`) — 3.5× the direct
term.

Extrapolating A3 at the A ladder's own `p = 2.574` gives **`J` = 12.26343**, so
**refining the edge treatment once moves the converged value by −0.0117
(−0.095%)**, and the edge treatment is not itself laddered here.

**The answer.** `J` = **12.275 ± 0.0003** for the bracket edge treatment;
**12.263** once the closing ramps are split; **12.26 to 12.28** as the honest
interval, converged in the fill to 3e-04 and in the edge treatment to about
1.2e-02. Every rung of the uniform ladder is 0.19 to 0.76 away from that
interval — 15 to 62 times its width.

---

## 6. Cost

`sum over steps of M` is `diag-nested-grid.md` §2's member-evaluation count, and
this fixture reproduces its 956 923 at the default schedule exactly.

| schedule | nodes | steps | `sum M` | leaf solves | wall | `J` | from 12.2751 |
|---|---|---|---|---|---|---|---|
| the default | 108 | 9 931 | 956 923 | 7 769 166 | 130.5 s | 12.0526222 | −1.81% |
| uniform ×2 | 215 | 10 174 | — | — | — | 12.0888310 | −1.52% |
| uniform ×4 | 429 | 10 816 | — | — | — | 13.0315024 | **+6.16%** |
| uniform ×8 | 857 | 11 351 | — | — | 1028 s | 12.8432659 | **+4.63%** |
| **A, 1/16** | **498** | 10 723 | 3 886 852 | 31 107 428 | **495.2 s** | 12.2848689 | **+0.079%** |
| **A, 1/32** | **793** | 10 918 | 6 194 396 | 49 498 014 | **792.9 s** | 12.2767755 | **+0.013%** |
| **A, 1/64** | **1378** | 11 213 | 10 884 751 | 86 994 033 | **1377.0 s** | 12.2754162 | **+0.0022%** |
| A3, 1/16 | 570 | 10 778 | 4 437 611 | 35 513 124 | 566.7 s | 12.2703028 | −0.039% |
| A3, 1/32 | 865 | 10 973 | 6 758 462 | 54 004 790 | 856.2 s | 12.2645852 | −0.086% |
| B, 1/16 | 426 | 10 687 | 3 338 588 | 26 764 996 | 432.7 s | 10.9833846 | −10.5% |
| C, 1/16 | 426 | 10 733 | 3 350 430 | 26 928 598 | 431.9 s | 10.8700030 | −11.4% |
| D, 1/16 | 426 | 10 670 | 3 335 919 | 26 755 793 | 425.0 s | 12.5159818 | +1.96% |

(The uniform ladder's `sum M` at 215/429/857 was not taken; its 108-node value
and its 857-node wall clock are `diag-nested-grid.md`'s, on the same machine —
that note reads 136 s at 108 nodes where this one reads 130.5 s.)

Wall clock is close to linear in the node count and almost flat in the steps:
**1.00 s per node** across the A ladder against the default's 1.21, because the
edge mesh spends its extra nodes where cohorts arrive late and live briefly,
while the default spends 56 of its 108 below `b = 1/16` where a cohort sits in
the member loop of every remaining step. Steps rise only 8% from 9931 to 11 213
across a 12.8× change in node count.

**Accuracy per unit cost.**

| | |
|---|---|
| A at 498 nodes against uniform at 429 | **78× more accurate** for 16% more nodes |
| A at 498 nodes against uniform at 857 | **58× more accurate** at **0.48×** the wall clock |
| accuracy per second, A 1/16 against uniform 857 | **121×** |
| accuracy per member-evaluation, A 1/16 against the default 108 | 22.9× the error removed per 4.1× the cost |

The 374-node figure `diag-establishment-ramp.md` §5 priced is 498 here, because
the bracket wants two nodes at each edge rather than one and because the frozen
head and tail are counted in. It remains **below the 857-node rung the uniform
ladder had already paid for**, and 58× more accurate than it.

---

<!-- SECTIONS 4, 7-9 PENDING: control, gradient, scripts, not-reached -->
