# Bracketing the establishment edges removes the non-convergence, leaves a floor at 1.5e-4 per doubling, and only works with the edges placed on the stand being run

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
| **Half the hypothesis holds** | **The non-convergence was straddled-edge error.** With edges bracketed and the fill halving, `J` moves −6.8e-03, −2.1e-03, −1.9e-03 (edges placed on the stand being run; 499 → 2539 nodes) where the uniform ladder moved +0.036, +0.943, −0.188 and turned; a matched-cost uniform control with no edge information turns too (−0.077, +0.016). **The second-order claim fails.** `J`'s own quadrature converges at order 2–4, but the total stops shrinking at **1.5e-04 relative per doubling** on both edge sets, and the residual is not the edges' panels, not `ode_tol`, and not fill on ramps. It is the stand's integrand — first order in the first drought, sign-changing in the first three years — plus the integrator stops that introductions impose. **Its cause was not found** (§2, §5). |
| **The value** | **`J` = 12.417 ± 0.006**: placement converged to 4e-04, `ode_tol` to 1e-04, the error bar the fill's unconverged, one-signed tail; **12.40–12.42** allowing for the ramp interior. **The operating 108-node value is 3.0% low; uniform 429 and 857 are 4.9% and 3.4% high.** |
| **Where the edges are is the largest term** | The roots located on the default schedule's stand are up to **3.9 days** off on a resolving mesh. Re-placing the bracket on the mesh's own gate moves `J` by **+1.15%**; a second pass moves the roots ≤0.37 d and `J` by +0.055%, **21× less**. The Oracle's edge-location term prices the first shift at 0.0016; it is **0.141**, because a misplaced root node is a live cohort whose weight spans a dead band, and it thickens the canopy. |
| **Bracketing is the only placement that works** | At one fill, `J` = **12.285 (bracket)**, 12.516 (the crossing alone), 10.983 (the ramp's midpoint), 10.870 (past the ramp's top). The midpoint and past-the-top placements are **−11% and −12%**; the crossing alone is +1.9% at this fill and falls **2.2× per doubling** — first order — its own panel under-reading by 0.08 and a thinner canopy over-reading by 0.31. Every failing placement fails mostly **through the canopy**: the integrand moves 2–18% at every birth date, including `b < 1`, where there is no edge. |
| **The gradient** | By the adjoint: **no refusal** on any metric, but on the build measured (`5321593a`) `J` is not a census metric, so **`dJ/dθ` has no adjoint path there**; the `plant` branch `offspring-adjoint` (`bb1d8a8a`) adds that row. By central difference on a bracket that follows the edges: **−169.57 / −169.81 / −169.77**, settled to 0.03% past 793 nodes, **`dJ/dlma` = −169.8 ± 1.1** with the error the time grid's. A fixed-schedule difference converges to **−172.9, 1.8% off** (2.3% at 498 nodes), and the default schedule's −155.6 is **8.4% shallow**. |

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
there, and the edge treatment is identical at every rung by construction — as
long as the roots are where the gate really closes, which §5 shows they were not
on the reference edges. The 36 intervals total 3.7098 yr of the 22.

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

## 2. The ladder converges, to a floor at 1e-4 per level

Variant A with the edge set fixed at the reference roots, fill 1/16 → 1/128:

| fill | 1/16 | 1/32 | 1/64 | 1/128 |
|---|---|---|---|---|
| nodes | 498 | 793 | 1378 | 2542 |
| `J` | 12.284868878 | 12.276775477 | 12.275416201 | 12.274025087 |
| difference | — | **−8.093e-03** | **−1.359e-03** | **−1.391e-03** |
| ratio | — | — | **5.954** | **0.977** |
| `log2` ratio | — | — | **2.574** | −0.033 |
| steps | 10 723 | 10 918 | 11 213 | 12 066 |
| wall | 495.2 s | 792.9 s | 1377.0 s | 2673.2 s |

Against the uniform ladder of `diag-nested-grid.md` §5 at `ode_tol = 1e-3`:

| nodes | 108 | 215 | 429 | 857 |
|---|---|---|---|---|
| `J` | 12.0526222 | 12.0888310 | 13.0315024 | 12.8432659 |
| difference | — | +0.0362088 | **+0.9426714** | **−0.1882365** |
| ratio | — | — | 0.038 | −5.008 |

**The first three rungs converge and the fourth does not shrink.** The first
difference is 116× smaller than the uniform ladder's at a comparable count and
the first ratio is 5.95; then the third difference is the same size as the
second. At 1e-4 relative per rung this is not the uniform ladder's failure — the
whole four-rung sequence spans 0.088%, where the uniform one spans 7.8% — but it
is not second order either, and it had to be taken apart before anything could be
claimed. (The same bracket with its edges re-placed on the stand being run is
§5's ladder; its differences are −6.8e-03 and −2.1e-03.)

### Taking the last rung apart

Every schedule here is nested in the next (all 498, 793 and 1378 abscissae of
each coarser rung are in the finer), so a level-to-level change splits exactly.
Three channels, each isolated by a run:

| | 1/16 → 1/32 | 1/32 → 1/64 | 1/64 → 1/128 |
|---|---|---|---|
| total | −8.093e-03 | −1.359e-03 | −1.391e-03 |
| **time grid**: the coarser schedule run with zero-depth stops at the finer one's added birth dates, no cohorts there (`em_restart.R`) | — | **+2.008e-04** | **−5.303e-04** |
| **quadrature**: the added abscissae, at the finer run's integrand | −3.763e-03 | **−1.029e-03** | **−6.718e-05** |
| **integrand**: the stand re-solved with the added cohorts, read at the coarser abscissae | −4.330e-03 | **−5.307e-04** | **−7.936e-04** |
| `ode_tol` 1e-3 → 1e-4 on the same schedule | — | +7.8e-05 at 1/64 | −3.1e-05 at 1/128 |

(In the last two columns the quadrature and integrand rows are taken from the
stop-matched run, so they sum with the time-grid row to the total; the `ode_tol`
row is separate.)

- **`J`'s own quadrature converges at better than second order**: −3.76e-03,
  −1.03e-03, −6.7e-05, ratios 3.7 and 15.3.
- **The time grid is not the tolerance.** Adding 1164 zero-depth stops moves `J`
  by −5.3e-04, 7 to 17 times what a decade of `ode_tol` moves it on either
  schedule, and a run of the 1/128 pair at `ode_tol = 1e-4` reproduces the step
  (−1.50e-03 against −1.39e-03). Every introduction is a time the integrator must
  land on whatever is born there, and doubling the cohorts doubles those stops.
- **The integrand converges at first order where it is largest.** With the time
  grid matched it is −5.3e-04 and then −7.9e-04 in total, but by window of `b`:

  | window | 1/32 → 1/64 | 1/64 → 1/128 | ratio |
  |---|---|---|---|
  | `[0, 1/16)` | +1.2e-04 | −0.7e-05 | — |
  | `[1/16, 1)` | +7.3e-04 | −1.1e-04 | — |
  | `[1, 3.5)` | −2.7e-04 | −1.5e-04 | **1.8** |
  | `[3.5, 6)` | −0.9e-04 | −0.5e-04 | 1.8 |
  | **`[6, 10)`** | **−9.3e-04** | **−4.6e-04** | **2.0** |
  | `[10, 22)` | −1.0e-04 | −0.2e-04 | 6.0 |

  The first drought, `[6, 10)`, carries most of it and halves per level; the
  first year changes sign between steps and has no rate.

**So the residual is two things, neither of them the establishment edges' own
panels:** the integrator stops that introductions impose, which do not shrink
with the fill (+2.0e-04, then −5.3e-04) and survive a decade of `ode_tol`; and the stand's integrand in the
drought window, converging at first order while `J`'s quadrature over it
converges at second or better. Together they are 1.1e-4 relative per level,
about 700 times below the uniform ladder's largest step (7.8%).

What the second of those is, is **not settled here**. One candidate was tested
and eliminated. The reference roots sit up to 3.9 days from where this mesh's
gate closes (§5), so as the fill refines it lands on true ramps — **0, 1, 4 and
7 fill nodes** at the four rungs, all at `b` = 14.5–18.4: the edge treatment the
brief asked to hold constant was not quite constant on this ladder. The
re-located ladder of §5 has no fill node on a ramp at any rung **and stops
shrinking at the same rung by the same amount** (−1.9e-03), so that leak is not
the floor.

### The two channels at the first step

The 1/16 schedule is a strict subset of the 1/32 one, so the first step splits
without a stop-matched run as well: the integrand moved **−4.33e-03** at the
shared abscissae and the added abscissae resolved **−3.76e-03**, with `|dw|/w`
at the 469 shared live nodes a median **2.57e-03** (q90 5.45e-03). Both
channels are small. On the uniform ladder `diag-nested-grid.md` §7 found them at
12.76%.

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

B and C are run as the brief states them: one node per edge, on the ramp, and no
node at the root. With the band's interior excluded from the fill, each dead band
is then bounded by the variant's own two nodes, which read near the plateau. The
brief's gloss on C — "the zero band is bounded by nodes that read zero" — needs a
node at or inside the band as well; with the band interior empty that node is the
root, and C plus a root node is A.

**Bracket wins.** B's and C's own panels over the band-and-ramp intervals
misread, by the sign and size that bounding a dead band with near-plateau nodes
gives:

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
`b < 1`; no stand-leaf-area census was taken to confirm it — see *What was not
reached*.)*

### The crossing alone: a first-order panel, and a canopy term 3.8× larger

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


**Measured on re-placed edges, D converges at first order.** With both D and the
bracket put on the pass-1 roots of §5 (`em_placeV.R`), D's excess over the
bracket at the same fill is **+0.2340 at 1/16 and +0.1083 at 1/32 — ratio 2.16**.
The crossing alone is an `O(Δ)` placement, as the brief said, and the thing that
halves is mostly the canopy term, not the panel.

---

## 4. Against the control at the same node count

The control carries the same frozen head and tail as the edge mesh and spends
the same node count on a uniform fill over `[1/16, 22]` with no edge
information — no edge nodes, no band exclusion. It is the placement-at-fixed-cost
comparison the uniform ladder is not, because the default generator's grading
(half-year to two-year spacing past `b = 3`) differs from a uniform fill as well
as in knowing nothing of the edges.

| nodes | control `J` | reference-edge bracket `J` | control − bracket | control fill | wall, control / bracket |
|---|---|---|---|---|---|
| 498 | 12.431803971 | 12.284868878 | **+0.1469** | 1/19.7 yr | 497.6 / 495.2 s |
| 793 | 12.354741710 | 12.276775477 | **+0.0780** | 1/35.9 yr | 823.1 / 792.9 s |
| 1378 | 12.370418604 | 12.275416201 | **+0.0950** | 1/62.5 yr | 1455.8 / 1377.0 s |
| differences | −0.0771, **+0.0157** | −0.0081, −0.0014 | | | |

**The control ladder turns** — down 0.077, then up 0.016, ratio −4.9 — at the
same cost, the same head and tail and nearly the same step count as the bracket.
Uniform fill with no knowledge of the edges reproduces the uniform ladder's
pathology; neither bracket ladder has it. 64 of the control's 498 nodes sit
inside a dead band on the reference gate and 12 on a ramp; its integrand at the
66 abscissae the two share (head and tail) is 0.76% above the reference-edge
bracket's — the same canopy channel as §3.

Against 12.4222, the 2539-node re-located value with the second placement pass
added (§5):

| nodes | control | bracket, re-located edges | bracket, reference edges |
|---|---|---|---|
| ~498 | **+0.077%** | +0.031% (pass 1), +0.086% (pass 2) | −1.11% |
| 793 | **−0.543%** | −0.023% | −1.17% |
| ~1378 | **−0.417%** | −0.040% | −1.18% |
| ~2540 | — | −0.055% | −1.19% |

The control's 0.08% at 498 nodes is where a turning sequence happened to cross
the answer, not accuracy it can be relied on for: one doubling later it is 0.54%
off. **The reference-edge bracket converges to a value 1.2% low** — §5 is why.
The re-located bracket is within 0.02–0.09% at every count; those figures carry
the reference's own uncertainty (§5: the limit is estimated 0.005 lower), which is
why the table does not rank them against each other.

---

## 5. Where the edges are: the placement has to be solved on the mesh being run

§2's ladder holds the edge set fixed at the roots `diag-establishment-ramp.md`
located on the **default 108-node** run's environment. The resolving mesh runs a
different stand, so those roots are not where its gate closes. That turned out to
be the largest single term in the value — though not, as the re-located ladder
below shows, the cause of §2's floor.

### The reference roots are up to four days off, and it costs 1.15% of `J`

The roots were re-located on the 498-node bracket mesh's own environment
(`em_scan.R`, `em_scan2.R`: windows of 41 stops across ±8 half-widths of each
current root, the newborn's carbon read off the recorded rows, 72 of 72 found at
every pass), and the bracket re-placed on them with the fill kept out of the new
band-and-ramp intervals (`em_reloc.R`, `em_place.R`). Iterating that is the
Oracle's §2(c) construction run to its fixed point:

| placement pass | roots moved, max | median | `J` at 1/16 | shift in `J` |
|---|---|---|---|---|
| 0 — reference roots (108-node run) | — | — | 12.284868878 | — |
| 1 — re-located on the 498-node mesh | **3.935 d** | 0.017 d | **12.426116763** | **+0.141248** |
| 2 — re-located again on pass 1's mesh | **0.372 d** | 0.002 d | **12.432969083** | **+0.006852** |

**The iteration contracts 10× in root position and 21× in `J` per pass.** A
geometric tail at that rate leaves about 3e-04 beyond pass 2, so the placement is
converged to **±4e-04** at the second pass.

The roots that move are closing ones. A closing edge's slope is 31× gentler than
an opening edge's, so the same change in the newborn's carbon moves it 31×
further; all 16 moves of more than a day (1.2–3.9 d) are closing edges at
`b` = 9.9–19.7, where the
108-node schedule's two-year spacing gives a stand whose water draw differs most
from a resolved one.

**The direct cost of a misplaced edge is small; the canopy cost is not.** The
Oracle's §2(a) guarantee prices edge-location error as `sum g(β) δ`. Evaluated
on the pass-1 shifts with each edge's own envelope, that term is **+0.0016**. The
measured shift is **+0.1412 — 88× larger**. A reference root that is really on
the live side reads a live cohort (the q90 root reading is 0.35 of its plateau)
whose trapezium weight spans the dead band: the B/C mechanism of §3 at a few
edges. Its spurious area in `J` is only 0.0131, but it is leaf area in the canopy,
and the integrand rises **+0.8% to +5.4% in every window of `b` below 17** once
it is removed, including `b < 1/16` (+0.79%); it falls 0.43% on `[17, 22)`.

| | reference roots | pass 1 | pass 2 |
|---|---|---|---|
| root nodes reading `w` exactly 0 | 28 of 72 | 11 of 72 | 34 of 72 |
| root reading / ramp-top reading, q90 | 0.352 | 0.113 | — |
| spurious dead-band area | **0.01306** | **0.00044** | **0.00000** |

### The fill leak, and why it is not the floor

With the edges misplaced, the band-and-ramp intervals the fill avoids are not the
true ones, so as the fill refines it starts landing on true ramps:

| fill | 1/16 | 1/32 | 1/64 | 1/128 |
|---|---|---|---|---|
| reference-edge ladder: fill nodes on a true ramp | 0 | 1 | 4 | **7** |
| re-located ladder: the same | 0 | 0 | 0 | 0 |

Each such node is a live cohort standing on a ramp that the bracket treats as
plateau — A3's interior nodes by accident — so the reference-edge ladder did not
hold its edge treatment exactly constant. The re-located ladder does, and it is
the experiment the brief specified.

### The re-located ladder has the same floor

Pass-1 roots held fixed, fill halving:

| fill | 1/16 | 1/32 | 1/64 | 1/128 |
|---|---|---|---|---|
| nodes | 499 | 793 | 1375 | 2539 |
| `J` | 12.426116763 | 12.419360085 | 12.417291960 | 12.415374954 |
| difference | — | **−6.757e-03** | **−2.068e-03** | **−1.917e-03** |
| ratio | — | — | 3.267 | **1.079** |
| `log2` ratio | — | — | 1.708 | 0.109 |
| steps | 10 721 | 10 919 | 11 219 | 12 066 |

No fill node sits on a true ramp at any rung of this ladder, and **it stops
converging at the same place and by the same amount as the reference-edge
ladder** (−1.9e-03 against −1.4e-03 at the last step). So the fill nodes leaking
onto misplaced ramps are not the floor. Split the same way as §2:

| | 1/16 → 1/32 | 1/32 → 1/64 | 1/64 → 1/128 |
|---|---|---|---|
| quadrature (the added abscissae) | −3.776e-03 | −1.015e-03 | **−6.2e-05** |
| integrand and time grid together | −2.981e-03 | −1.053e-03 | **−1.855e-03** |
| of which `b` in `[6, 10)` | −2.0e-03 | −9.9e-04 | −4.2e-04 |
| of which `b` in `[1/16, 3.5)` | −4.2e-04 | +5.4e-04 | −1.6e-03 |

`J`'s own quadrature converges at better than second order on this ladder too
(ratios 3.7 and 16). The first drought's integrand halves per level — first
order. The first three years' integrand changes sign and has no rate. The time
grid was not separated on this ladder; on the reference ladder it was a third of
the last step (§2).

**So the residual non-convergence has a cause this measurement did not find.**
It is 1.5e-04 relative per doubling, about 500× below the uniform ladder's
largest step, and it is
not the establishment edges' own panels, not `ode_tol`, and not fill landing on
ramps. Two candidates fit what was measured and neither was tested: a second
non-smooth feature in `b` that the canopy integral sees and `J`'s trapezium does
not — cohorts that die, or cohorts that cross in height, both of which TF24's
reserve-gated growth permits, would put a moving front into the competition
integrand at fixed `t` — and the integrator stops at each introduction, which
grow with the node count by construction.

### The value

| | |
|---|---|
| the re-located ladder at 2539 nodes | 12.415375 |
| the second placement pass, measured at 1/16 | **+0.006852** |
| placement tail beyond pass 2, at the 21× contraction | +3e-04 |
| the fill: last step −1.9e-03 and not shrinking | **−0.002 to −0.01**, see below |
| `ode_tol` 1e-3 → 1e-4 | +7.8e-05 at 1/64, −3.1e-05 at 1/128 (reference edges) |
| the ramp interior, A3 on the reference edges | −0.012, not repeated on re-placed ones |

The fill term is the one that cannot be closed, and it is one-signed: every
step of both ladders is negative. If the first-drought part keeps
halving and the rest stops, the tail is about −0.002; if the whole step stayed at
−0.002 for five more doublings — to 80 000 nodes — it would be −0.01. From
12.4225 (2539 nodes, both placement passes and the tail beyond them) that gives

**`J` = 12.417 ± 0.006** at the bracket's ramp treatment — placement converged to
4e-04, `ode_tol` to 1e-04, and the fill's unconverged tail the whole of the error
bar — and **12.40 to 12.42** allowing for the ramp interior, which A3 moved by
−0.012 on the reference edges. The comparisons in §4 and §6 are against 12.4222,
the 2539-node value with the second pass added, the top of that interval; every
rung of the uniform ladder is 0.33 to 0.61 away from it, and the operating
108-node value is **3.0% low** (2.9% against 12.417).

### The ramp interior: what a bracket under-reads, and what splitting it moves

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
and why variant B is not the "effective jump" its name suggests. Weighted by the
envelope at each edge the bracket's deficit is **0.0125 — 0.10% of `J`**, and it
predicts A3 − A = +0.0110.

Run, on the reference edges:

| | 1/16 | 1/32 |
|---|---|---|
| A (bracket) | 12.284868878 (498) | 12.276775477 (793) |
| A3 (closing ramp split at `u = 1, 3`) | 12.270302764 (570) | 12.264585195 (865) |
| A3 − A | **−0.0145661** | **−0.0121903** |

A is a strict subset of A3, so the exact split applies: **quadrature +0.0058,
integrand −0.0204.** The direct term has the predicted sign and is within a factor
1.9 of the arithmetic; resolving the ramp also resolves the leaf area standing on
it, the integrand falls 0.25%, and the total has the opposite sign to the
prediction. The canopy again, at 3.5× the direct term.

---

## 6. Cost

`sum over steps of M` is `diag-nested-grid.md` §2's member-evaluation count, and
this fixture reproduces its 956 923 at the default schedule exactly. Error is
against 12.4222 (§5), the top of the interval the limit is estimated in.

| schedule | nodes | steps | `sum M` | wall | `J` | from 12.4222 |
|---|---|---|---|---|---|---|
| the default | 108 | 9 931 | 956 923 | 130.5 s | 12.0526222 | **−2.98%** |
| uniform ×2 | 215 | 10 174 | — | — | 12.0888310 | −2.68% |
| uniform ×4 | 429 | 10 816 | — | — | 13.0315024 | **+4.91%** |
| uniform ×8 | 857 | 11 351 | — | 1028 s | 12.8432659 | **+3.39%** |
| control | 498 | 10 822 | 3 894 655 | 497.6 s | 12.4318040 | +0.08% |
| control | 793 | 11 037 | 6 210 432 | 823.1 s | 12.3547417 | −0.54% |
| control | 1378 | 11 544 | 11 074 012 | 1455.8 s | 12.3704186 | −0.42% |
| A, reference edges, 1/16 | 498 | 10 723 | 3 886 852 | 495.2 s | 12.2848689 | −1.11% |
| A, reference edges, 1/32 | 793 | 10 918 | 6 194 396 | 792.9 s | 12.2767755 | −1.17% |
| A, reference edges, 1/64 | 1378 | 11 213 | 10 884 751 | 1377.0 s | 12.2754162 | −1.18% |
| A, reference edges, 1/128 | 2542 | 12 066 | 21 060 488 | 2673.2 s | 12.2740251 | −1.19% |
| **A, re-located once, 1/16** | **499** | 10 721 | 3 891 721 | **497.9 s** | 12.4261168 | **+0.031%** |
| **A, re-located once, 1/32** | **793** | 10 919 | 6 191 853 | **815.5 s** | 12.4193601 | **−0.023%** |
| **A, re-located once, 1/64** | **1375** | 11 219 | 10 869 098 | **1414.8 s** | 12.4172920 | **−0.040%** |
| **A, re-located once, 1/128** | **2539** | 12 066 | 21 040 316 | **2711.5 s** | 12.4153750 | **−0.055%** |
| **A, re-located twice, 1/16** | **499** | 10 735 | — | **494.8 s** | 12.4329691 | **+0.086%** |
| A3, reference edges, 1/16 | 570 | 10 778 | 4 437 611 | 566.7 s | 12.2703028 | −1.22% |
| A3, reference edges, 1/32 | 865 | 10 973 | 6 758 462 | 856.2 s | 12.2645852 | −1.27% |
| B, 1/16 | 426 | 10 687 | 3 338 588 | 432.7 s | 10.9833846 | −11.6% |
| C, 1/16 | 426 | 10 733 | 3 350 430 | 431.9 s | 10.8700030 | −12.5% |
| D, reference edges, 1/16 | 426 | 10 670 | 3 335 919 | 425.0 s | 12.5159818 | +0.76% |
| D, re-located edges, 1/16 | 427 | 10 667 | 3 343 527 | 444.7 s | 12.6601405 | +1.92% |
| D, re-located edges, 1/32 | 721 | 10 897 | 5 641 316 | 729.9 s | 12.5276424 | +0.85% |

(The uniform ladder's `sum M` at 215/429/857 was not taken; its 108-node value
and its 857-node wall clock are `diag-nested-grid.md`'s, on the same machine —
that note reads 136 s at 108 nodes where this one reads 130.5 s. Runs after
10:25 UTC shared the machine with a build and test of a separate copy of
`plant` started outside this measurement (§8), so their wall clocks are high by
up to about 10%; the steps and `sum M` are unaffected.)

Wall clock is close to linear in the node count and almost flat in the steps —
**1.00 s per node** across the A ladder against the default's 1.21, because the
default spends 56 of its 108 cohorts below `b = 1/16`, where a cohort sits in the
member loop of every remaining step. Steps rise 21% from 9931 to 12 066 across a
23.5× change in node count. The re-located bracket costs what the reference one
does: placement is free once the roots are known, and knowing them costs one
windowed run and a scan (590–685 s, `em_scan*.R`) per pass.

**Accuracy per unit cost**, against 12.4222:

| | error | cost | |
|---|---|---|---|
| uniform, 857 nodes | 3.39% | 1028 s | |
| **bracket, placed twice, 499 nodes** | **0.086%** | **495 s solve + two placement passes (≈1275 s)** | **39× more accurate at 0.48× the solve, 1.7× with the placement** |
| bracket, placed once, 1375 nodes | 0.040% | 1415 s + one pass (≈685 s) | 85× more accurate at 2.0× the cost |
| the default, 108 nodes | 2.98% | 130.5 s | |

The ratios lean on a reference that is itself 0.005 above the estimated limit,
so the re-placed bracket's errors below 0.1% are read as "within the reference's
uncertainty",
and the robust statement is the other one: **the uniform ladder is 3–5% off at
every rung it reached, and every re-placed bracket is inside 0.1%.** The
374-node figure `diag-establishment-ramp.md` §5 priced is 499 here, because the
bracket wants two nodes at each edge rather than one and because the frozen head
and tail are counted in. It remains below the 857-node rung the uniform ladder
had already paid for — provided the edges are placed on the mesh being run.
Placed on the default schedule's stand, the same 498 nodes are 1.1% off and
converge to 1.2% off.

---

## 7. The gradient

### By the adjoint: it answers, and it answers a different question

`stand_gradient` on the 498-node bracket mesh (`em_run.R A 16 grad`):

| metric | value at `t = 40` | `d/dlma` | `d/drho` | `d/dhmat` |
|---|---|---|---|---|
| `leaf_area` | 0.8255477402 | −3.127144574 | −2.497602e-04 | 1.313618e-03 |
| `mass_above_ground` | 1.8399257615 | −7.430527726 | 1.575136e-03 | 2.306837e-02 |
| `area_stem` | 2.837613e-04 | −9.79473e-04 | −1.811906e-08 | 1.654675e-07 |

**No refusal on any metric**, all 48 trait columns finite, `J` and the step count
reproduced to every digit from the forward-only run (12.284868878, 10 723
steps), at **2637 s — 5.3× the forward solve**, peak resident 1.06 GB. The
refusal the brief anticipated does not occur on this mesh.

**But on the build measured, `J` is not a census metric.** There `census_metric_names_tf24()` is `leaf_area`,
`mass_above_ground`, `area_stem`: per-individual quantities integrated over the
size distribution *at the end of the run*. `J = sum(offspring_production)` is a
quadrature over birth dates of each cohort's lifetime output, and nothing in the
sweep is seeded on it. **`dJ/dθ` is not available by the adjoint on this build**;
what follows takes it by central difference. The `plant` branch
`offspring-adjoint` (`bb1d8a8a`) makes `offspring_production` a census row with
its own seed.

The adjoint was not laddered: at 5.3× the forward cost the 793-node level is
about 70 minutes, which the budget did not hold alongside the value ladder.

### By central difference on a fixed schedule: it converges, one order behind the value

Central differences in `lma` at `d = 1e-3` — inside the plateau
`diag-long-horizon-remeasure.md` §6 measured, 3e-2 to 1e-5 — on each rung's
schedule held fixed at the base trait, all nine runs aligned and at
`ode_tol = 1e-3` (`em_fd.R`, `em_fd1.R`, `em_gradrep.R`):

| fill | `J(0.319)` | `J(0.32)` | `J(0.321)` | backward | forward | **central** | `J''` |
|---|---|---|---|---|---|---|---|
| 1/16 | 12.454057925 | 12.284868878 | 12.107002683 | −169.1890 | −177.8662 | **−173.52762** | −8677 |
| 1/32 | 12.446151876 | 12.276775477 | 12.099941755 | −169.3764 | −176.8337 | **−173.10506** | −7457 |
| 1/64 | 12.444637710 | 12.275416201 | 12.098724810 | −169.2215 | −176.6914 | **−172.95645** | −7470 |

| | derivative | value, same rungs |
|---|---|---|
| differences | **+0.42256, +0.14861** | −8.093e-03, −1.359e-03 |
| ratio | **2.843** | 5.954 |
| `log2` ratio | **1.508** | 2.574 |
| per-level relative change | 0.24%, 0.086% | 0.066%, 0.011% |
| Richardson, measured `p` | **−172.876** | 12.27514 |
| Richardson, `p = 2` | −172.907 | 12.27496 |

**On the reference-edge bracket the derivative converges at about one order
less than the value** — 1.51 against 2.57 on the same three meshes — to
−172.9 ± 0.1. That is the derivative of a functional whose edges are misplaced by
an amount that depends on `lma`, and the next three subsections show it is 1.8%
off converged (2.3% at 498 nodes).

Its `J''` reads −7457 and −7470 at 1/32 and 1/64, 0.2% apart, so the
forward/backward asymmetry of 7.5 is converged in the fill — and it is not the
functional's curvature (below).

### What a fixed bracket cannot see: the edges move with the trait

With the schedule fixed, a bracketed edge that moves does not change `J_N` to
first order: the root node reads zero on either side of a small shift and the
ramp-top node stays on the plateau, so the trapezium over the ramp panel is the
same number. The continuum `J` does change, by `∓ E(β) dβ/dθ` at each edge. So
the fixed-schedule derivative is the derivative *minus the transport term* the
Oracle's §3(a) names.

The roots were re-located on the bracket mesh's own environment at `lma = 0.319`
and `0.321` (`em_scan.R`: windows of 41 stops across ±8 half-widths of each
reference root, the gate read off the recorded rows, 72 of 72 roots found at
both):

| | closing edges | opening edges |
|---|---|---|
| `dβ/dlma`, median | **+0.1009 yr per unit `lma`** | +0.0008 |
| as days per 0.001 of `lma` | **+0.037** | +0.000 |
| largest | 0.643 d per 0.001 | — |
| transport term, `−sum(side * E * dβ/dlma)` | **+0.2902** | −0.0035 |

**`T = +0.287`**, and one edge carries two thirds of it: the first closing edge,
`b = 3.560`, contributes +0.189 because it sits where the envelope is still large.
Closing roots move later as `lma` rises — the live stretch before each dry band
lengthens — so `T` opposes the main effect. Read as a correction to the fixed
bracket it is **0.17%** of `dJ/dlma`. The next subsection runs the edge motion
instead of pricing it, and the priced term turns out to be the small part.

### Moving the bracket with the trait: the canopy carries the transport term

The direct term above treats each edge as a panel of `J` alone. §3 showed that
where a cohort sits near an edge moves the whole stand through the canopy, so the
edge motion was also measured by running it. `em_place.R` puts the 144 edge
nodes at each trait value's own scanned roots, keeps the fill out of those
roots' band-and-ramp intervals, and runs at that trait value:

| | `J(0.319)` | `J(0.320)` | `J(0.321)` | backward | forward | **central** | `J''` |
|---|---|---|---|---|---|---|---|
| fixed bracket, reference roots | 12.454057925 | 12.284868878 | 12.107002683 | −169.189 | −177.866 | **−173.528** | −8677 |
| **bracket following the edges** | **12.595978640** | **12.426116763** | **12.256830190** | −169.862 | −169.287 | **−169.574** | **+575** |
| following − fixed | +0.141921 | +0.141248 | +0.149828 | | | **+3.953** | |

(`J(0.320)` on the following bracket is `reloc_A_16`, whose roots are the mean
of the two scans; §5.)

**Following the edges moves the derivative by +3.95 — 2.3% — which is 14× the
direct transport term of +0.287.** It also removes almost all of the fixed
bracket's curvature: the forward and backward differences agree to 0.58 instead
of 8.68, and `J''` goes from −8677 to +575. That curvature was not the
functional's. The reference roots sit up to 4 days from the roots of the stand
actually being run (§5), by an amount that depends on `lma`, and a mislocated
edge acts on the canopy the way B's and C's placements did in §3. The offset
between the two brackets is +0.1419, +0.1412, +0.1498 at the three trait values:
nearly constant, which is why the value's error from it is a bias (§5), and not
constant, which is why the derivative's error from it is 2.3%. The misplacement
is not what curves it: the same bracket held fixed at well-placed roots is more
curved (below).

### Holding the bracket fixed at the reference trait's own roots

The pass-1 bracket of §5 (`reloc_A_16`, 499 nodes), run unchanged at the two
trait values (`em_place.R em/run_reloc_A_16.rds 16 fixc_m 0.319` and
`fixc_p 0.321`; the realised schedule and roots are identical to `reloc_A_16`'s):

| | `J(0.319)` | `J(0.320)` | `J(0.321)` | backward | forward | **central** | `J''` |
|---|---|---|---|---|---|---|---|
| bracket following the edges | 12.595978640 | 12.426116763 | 12.256830190 | −169.862 | −169.287 | **−169.574** | +575 |
| **fixed at the reference trait's own roots** | **12.596709460** | 12.426116763 | **12.244756343** | **−170.593** | **−181.360** | **−175.977** | **−10 768** |
| fixed at the default schedule's roots | 12.454057925 | 12.284868878 | 12.107002683 | −169.189 | −177.866 | −173.528 | −8677 |

**Placed well and held fixed, the bracket's derivative is 3.8% off — further than
the misplaced bracket's 2.3%.** Its `J` differs from the following bracket's by
**+0.00073 at the lower trait and −0.01207 at the higher**. Raising `lma` moves
the closing roots later (§7, `dβ/dlma` median +0.037 d per 0.001), past root nodes
that then sit on the live side, read a positive gate, and carry a trapezium weight
across the dead band: the B/C mechanism of §3, switched on by the trait. Lowering
`lma` moves the roots earlier, the root nodes fall inside the band, and nothing
changes. So the fixed-schedule functional is curved **19×** the functional's own
curvature (−10 768 against +575), on one side of the reference: over 0.001 of
`lma` its derivative moves 6.1%, where the functional's moves 0.34%. The error of
a schedule held fixed across `θ` is that curvature, not an offset, and it grows
with the distance from the trait the schedule was placed at. Whether the local
derivative at `lma = 0.320` — what an adjoint on this schedule returns — sits
nearer the backward or the central value is not separated at `d = 1e-3`. At the
reference trait 61 of the 72 root nodes already read a positive gate, since the
pass-1 roots are up to 0.37 d from the pass-1 mesh's own (§5).

### The derivative on the edge-following ladder

The same construction at every rung — each side's edges at its own scanned
roots, the centre at the pass-1 roots of §5, all run at their own trait value:

| fill | `J(0.319)` | `J(0.320)` | `J(0.321)` | backward | forward | **central** | `J''` |
|---|---|---|---|---|---|---|---|
| 1/16 | 12.595978640 | 12.426116763 | 12.256830190 | −169.862 | −169.287 | **−169.5742** | +575 |
| 1/32 | 12.589570447 | 12.419360085 | 12.249948419 | −170.210 | −169.412 | **−169.8110** | +799 |
| 1/64 | 12.587556021 | 12.417291960 | 12.248023514 | −170.264 | −169.268 | **−169.7663** | +996 |

| | derivative | value, same rungs |
|---|---|---|
| differences | −0.2368, **+0.0448** | −6.757e-03, −2.068e-03 |
| ratio | −5.29 | 3.267 |
| `log2` ratio | — (the sequence turns) | 1.708 |
| last step, relative | **0.026%** | 0.017% |

**The derivative settles with the value, and no rate can be read from it.** The
two steps are 0.14% and 0.026% of `dJ/dlma` and the second has the opposite
sign; both are below the 1.08 by which the time grid alone moves the derivative
at this tolerance, so the fill's contribution is under the integrator's floor
from the second rung on. The value on the same meshes converges monotonically at
order 1.71. What is established is the size, not the rate: **the fill moves the
edge-following derivative by less than 0.05 past 793 nodes.**

### Where the derivative's error is

| | shift in `dJ/dlma` | fraction |
|---|---|---|
| the fill, past 793 nodes (edge-following ladder, last step) | 0.045 | 0.03% |
| the placement tail after one pass, estimated from the value's 21× contraction per pass | ~0.2 | ~0.1% |
| the direct transport term, `−sum(side * E * dβ/dlma)` | 0.287 | 0.17% |
| the time grid: the same traits with the scans' 2952 extra window stops | **1.082** | **0.62%** |
| the edges following the trait, through the canopy (fixed − following at 1/16) | **3.953** | **2.28%** |

**`dJ/dlma` = −169.8 ± 1.1** on an edge-resolving mesh whose edges follow the
trait, with the error bar the time-grid term at `ode_tol = 1e-3`. The two
instruments that miss the edge motion are off by more than that: the fixed
reference-edge bracket by 1.8% converged (−172.9) and 2.3% at 498 nodes (−173.5),
and the
default 108-node schedule's −155.6 (`diag-long-horizon-remeasure.md` §6) by
**8.4% shallow**, against its value's 3.0% low.

**This is the criterion the campaign is for, and it is met in the sense that
matters and missed in one it did not expect.** A mesh that respects the edges
gives a derivative that stops moving with the fill — but only if the edges are
re-placed at each trait value, and a finite difference across a fixed schedule,
however fine, converges to a derivative 1.8% off. On the build measured the
adjoint cannot supply `dJ/dθ`; an adjoint of `J` on a fixed schedule, which
`offspring-adjoint` provides, differentiates the same fixed-node functional as
the fixed-schedule difference and carries the same 1.8%.

---

## 8. Scripts, and the build they ran against

All in the session scratchpad, all `Rscript <file> [args]`, all reading `plant`
through `pkgload::load_all` and `odelia` through `library`. `ld_common.R`,
`lh_common.R` and `rw_common.R` are sourced unchanged; the `em_*` scripts are
new and sit beside them. Results are in `em/`.

| file | what |
|---|---|
| `em_common.R` | sources `lh_common.R`; the edge set read from `rw/edges_final.rds`, the band-and-ramp intervals, the variants, the schedule builder, the matched-count control and the one-run harness with its schedule read-back |
| `em_repro.R` | the reproduction check, and `sum M` at the default schedule |
| `em_shape.R` | builds every schedule and prints its counts and the nodes around one edge; runs nothing |
| `em_run.R` | one schedule, one run: `<variant> <fill denominator>` or `ctrl <node count>`; `grad` adds `stand_gradient` |
| `em_tol.R` | one schedule a decade tighter in `ode_tol` |
| `em_restart.R` | a coarser schedule with zero-depth stops at a finer one's added birth dates |
| `em_scan.R`, `em_scan2.R` | the gate's roots on a mesh's own environment at one trait value, from windows of stops around each current root |
| `em_reloc.R`, `em_place.R`, `em_placeV.R` | the bracket (or a variant) with its edge nodes at a scanned root set; `em_place.R` runs at a given trait value |
| `em_fd.R`, `em_fd1.R` | `dJ/dlma` by central difference on a fixed schedule |
| `em_fdmove.R` | **superseded**: moves the edges but runs both sides at the base trait, so it measures placement sensitivity, not a derivative; its two runs are not used |
| `em_report.R`, `em_channel.R`, `em_edgecheck.R`, `em_gradrep.R` | analysis only |
| `em_queue.sh`, `em_chain.sh`, `em_master*.sh` | the queue, three R workers at a time |

**`plant/src/plant.so` was read at the head and foot of every script's own log
and never moved:** `2026-09-22 12:52:40.069214118 +0000` throughout, and on
direct `stat` before and after each batch. Nothing under `plant/`, `odelia/` or
`phylloptim/` was written, and nothing was compiled or committed by this
measurement.

**A build that was not this measurement's.** From about 10:25 UTC a process
outside this measurement built and tested a separate copy of `plant`
(`scratchpad/plant-adj`) into a temporary library. It never wrote
`plant/src/plant.so` (re-checked after it started and at every batch since), and
no `em_*` run loaded anything from it. It shared the four cores with up to three
`em_*` workers, so wall clocks of runs after 10:25 are high by up to about 10%;
steps, `sum M` and every `J` are unaffected.

---

## What was not reached

- **What the last 1.5e-4 per doubling is.** Both bracket ladders stop shrinking
  at their fourth rung (−1.4e-03 and −1.9e-03). On the reference-edge ladder it
  was split: about a third is the integrator stops introductions impose, which
  the fill does not reduce and a decade of `ode_tol` does not remove, and the rest is the
  integrand — halving per level in the first drought, sign-changing in the first
  three years. The re-located ladder has the same floor with no fill on any ramp,
  so the fill leak is eliminated. A second non-smooth feature in the competition
  integrand (cohorts dying, or crossing in height) and the stops are the two
  candidates left; neither was tested, and the time grid was not separated on the
  re-located ladder.
- **The ramp interior on re-placed edges.** A3 (closing ramps split at `u = 1,
  3`) moved the value by −0.012 on the reference edges and was not repeated on
  re-placed ones, so the ±0.006 on `J` = 12.417 is for the bracket's ramp
  treatment and 12.40–12.42 is the honest interval.
- **The canopy reading is inference.** That every failing placement acts
  through the environment is read off the integrand at birth dates far from any
  edge and the exact subset decompositions; no stand leaf-area or light census
  was taken to show the canopy itself moving.
- **Only A was laddered on both edge sets.** B and C were run at one fill each
  and D at two on the re-placed edges, where its excess over the bracket falls
  2.16× per level — first order, measured over one step only.
- **The derivative's rate.** The edge-following derivative's two steps are below
  the time grid's own effect on it, so it has a size (0.03% past 793 nodes) and no
  order. A rate needs `ode_tol` tightened on all nine runs; not run. The adjoint
  was taken at one level only (2637 s at 498 nodes, 5.3× the forward solve), and
  on the reference edges.
- **Above `b = 22` nothing is resolved.** The 40 edges there lie under the
  default generator's two-year tail. It carries 8.8e-05 of `J` on the reference
  run and is frozen, so it cancels in every difference; it is not zero in the
  value.
- **One trait, one record, one coordinate, one tolerance.** `lma = 0.32` on
  `long-drought`, `node_density_in_birth_date = TRUE`, `ode_tol = 1e-3`
  throughout except the two 1e-4 runs of §2. The placement result says a scan
  has to be taken on the mesh being run, at the trait being run; how far that
  transfers across `θ` beyond the ±0.001 of §7 is untested.
