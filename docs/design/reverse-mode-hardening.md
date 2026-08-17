# Reverse-mode hardening: specification and handoff

**Read this first, build in the order given, and do not reorder without reading the gates.**

The reverse-mode census gradient is correct where it answers and has fourteen known defects. All
fourteen are root-caused and each one's reachability is measured — #14 was found by refereeing a row
nothing tested, which is the case for §5's table being part of the specification rather than beside
it. This document is the specification
for closing them and the handoff for the session that does it.

Every number here was measured rather than argued, unless marked *(corpus)* — meaning it comes from
`docs/reports/00`–`09` or `plant/notes/gradient-development-record.md`. Figures from before the work
below were taken at `plant` `cdf3f0c9`.

**§0 is the work list. Read it first and it will send you to the rest.** §3 is what each phase did
and — as important — what it deliberately did not do; §4 the specifications; §10 the two open
derivations and why they were decided the way they were.

**Twelve of the fourteen defects are closed, one is open (#13), and two are not this work's (#11
upstream, #12 another branch).** The gradient answers on **every driver tried** — interior, both pins,
the crossings near a bound, both shut branches, and now the light floor as well. `plant` is on
`ad/v3-forward`, `phylloptim` at `e522ef0`; **nothing is pushed.**

**One thing to hold before starting, and it is the shape three findings here share.** A clamp, a
guard and a fold all produce the same thing — a finite number with no reading attached — and this
document has twice recorded a guard as the model's boundary when it was only the guard's. What
separates them is *counting on the differentiated path*, and until this session **no counter observed
that path at all**: `rebind_from` drops the tally and the block discards the per-unit copy it lands in.
Every incidence figure taken before was the forward run's, on a different set of solves.

**Every run that answered before still answers, bit-identically, and no forward number has moved at
any point.**

---

## 0. Do these, in this order

Everything below is committed on `ad/v3-forward` and unpushed. Each item names what to change, and
what has to be true before it counts.

### A — ~~fold the verification strategy into report 08~~ **DONE**

Report 08 now carries it: a third reference class and a **locality axis** (§5A) for refereeing one
supplied row against a difference of its own defining relation; the requirement that every invariant
name what it is blind to (§2 item 2); incidence as the acceptance criterion for a change that narrows
what the gradient answers (§2 item 6); degenerate fixtures asserted rather than avoided (§6); a guard
census beside the zero census (§7); measured incidence beside every refusal claim (§8); and the
correction that a coverage check is not an acceptance gate while a branch is refused rather than
answered (§9).

### B — ~~finish the pinned branch~~ **DONE**, and not by the six steps below

A pinned operating point now answers. What it took was not B1–B6, and the reason is a measurement
this document had wrong.

**⚠️ THE §10 TABLE WAS TAKEN AT A WET PIN AND DOES NOT HOLD AT A DRY ONE.** It records `root_b` and
`root_c` as the only driven traits whose finite-difference arm crosses the feasible interval. At a
**dry** pin — which is where every pin measured in production sits — **five of the six cross**:

| at a dry pin, `fit_step` = 1e-3 | up arm | down arm |
|---|---|---|
| `stem_c` | **crosses** | ok |
| `stem_b` | ok | **crosses** |
| `psi_crit` | ok | **crosses** |
| `root_c` | ok | **crosses** |
| `root_b` | **crosses** | ok |
| `root_psi_crit` | ok | ok |

So B1's two extra bound reads would not have been enough: it is the *frozen* profit and uptake
partials that cannot be centred, not only the bound.

**What replaced it: follow the bound.** Each differenced arm is taken at the **perturbed bound plus
the step-in the solve leaves between the bound and the collar**. The difference is then the TOTAL
derivative directly, it is feasible by construction, and the family needs no collar term at all.
Measured against re-solving the leaf, all twelve arms agree to **1.00000**.

**The step-in is load-bearing, not a detail.** At the wet bound total uptake is exactly zero, so
evaluating at the bare bound is a degenerate point: omitting the offset read **268.561** for a
derivative that is **−0.0814**.

So the families split by how they are READ rather than by what they are:

| read | at a pin |
|---|---|
| differenced — the four curve traits, `psi_crit`, `root_psi_crit`, kmax | arms follow the bound; the collar term is **0** |
| analytic — soil layers, layer carbon | the matching `bound_row` entry, plus `ν·∂B/∂u` on carbon's profit row |
| light | exactly **0** — neither bound reads radiation |
| the eight closed-form traits | exactly **0** — neither residual reads them |

B3, B5 and B6 landed as written. B4 turned out to be one family, not three: kmax and the traits get
the bound's movement from following it, so only the layer carbon adds `ν·∂B/∂u` by hand.

**And one thing outside B had to move with it.** An **interior** point can sit within a trait-step of
a bound, and there the step is *reduced* rather than the point refused: the margin is strictly
positive and the bound's movement is proportional to the step, so a small enough step always exists.
Bounded at `fit_step/100` — two decades, between the step chosen for conditioning and the step where
a difference stops moving total uptake above the solve's own floor — and it still refuses below that.
Without this the pinned branch is unreachable on a stand, because a crossing at an interior point
refuses first.

**Acceptance, measured against a build without the change:**

| driver | before | after |
|---|---|---|
| `rain 2.00, L=10` (100% interior) | answered | answered, **bit-identical** |
| `rain 0.28, L=10` | answered | answered, **bit-identical** |
| `rain 0.27, L=10` | answered | answered, **bit-identical** |
| `rain 0.26, L=10` | **refused** | **answered** |

**And `rain 0.26` provably reaches the pinned branch**, which is what makes the other three
bit-identity rather than an untested claim: a probe that refuses on the pinned branch refuses that
run and leaves `0.27` and `0.28` answering. `rain 0.25, L=10` — the driver this section originally
named — still refuses, on a crossing the step reduction cannot close.

Gradient ladder **465/465**. Non-ladder **3244 pass with the same 13 pre-existing problems in the
same six files**.

**⚠️ The operating-point counters do not measure this.** They count forward solves; the gradient path
visits only the recorded steps. `rain 0.30, L=10` reports 172 `pinned-dry-root-crit` and answered
*before* this change, because none of those pins is on the gradient path. A run's pinned count is
therefore not a prediction of whether its gradient needs the pinned branch, and report 08 §7's guard
census cannot be built from these counters — a counter on the strategy is lost anyway, because a
block copies the strategy per unit and discards it.

### C — ~~the crossing at an interior point~~ **DONE**

**The room, not the classification, is what decides this.** The refusal now reports both: at the
point that blocked `rain 0.25` the collar sat **1.1e-05 MPa** inside the dry bound while classified
**interior**, so no usable step is small enough. A leaf-level fixture cannot reproduce it — there the
solve pins as soon as it gets that close, and the margin jumps from 2.856e-03 straight to zero.

**The collar's response was never the problem.** The interior formula `−dR/du / curvature` is correct
at such a point; what breaks is the *frozen-collar difference*, which needs the held collar to be
feasible in the perturbed state. So only the arms changed:

1. **Centred** wherever both sides stay inside — almost everywhere, and the branch every already-answering run takes.
2. **One-sided, second order**, on the side that stays inside. One extra evaluation, same order, and it never asks the profit algebra for a point below the wet bound.
3. **Then** reduce the step, floored at `fit_step/100`.
4. Refuse.

**The order matters and it is not the obvious one.** Shrinking is *last*, because the reads carry the
solve's own floor: dividing them by a step two decades smaller costs more than the one-sided formula's
truncation.

**Why second order is worth the extra evaluation, measured on the leaf:**

| | worst over the four driven traits |
|---|---|
| one-sided **second** order vs centred | **1.6e-05** |
| one-sided **first** order vs centred | **2.4e-03** |

and the first-order error carries a **sign that follows the side**, so the row would depend on which
bound the point drifted toward rather than on the trait. The second-order form gives the same answer
from either side to six digits, which is what `test-fixed-collar.R` asserts.

**The centred branch is written out rather than run through the weights.** `(a − b)/(2h)` and
`0.5/h·a − 0.5/h·b` differ in the last bit.

**Acceptance, measured against a build carrying neither B nor C:**

| driver | before | after | pins |
|---|---|---|---|
| `rain 2.00, L=10` | answered | answered, **bit-identical** | 0 |
| `rain 0.28, L=10` | answered | answered, **bit-identical** | — |
| `rain 0.27, L=10` | answered | answered, **bit-identical** | — |
| `rain 0.26, L=10` | refused | **answered** | — |
| **`rain 0.25, L=10`** | refused | **answered** | 629 of 216,014 (**0.29%**) |
| **`rain 0.28, L=20`** | refused | **answered** | 99,645 of 363,767 (**27.4%**) |

Ladder **466/466**. Non-ladder **3244 pass, the same 13 pre-existing problems in the same six files**.

**One test had to change, and it is report 08 §9's ruling in practice.**
`test-gradient-incidence.R` asserted that `rain 0.25` comes back **refused**. That was the gap
recorded as a gate; it now asserts the run answers, and the incidence is what the answer rests on
rather than what it costs.

### C2 — ~~the parity gate~~ **DONE**

*For every state the forward model returns a number for, the reverse returns a row or names a violated
constraint.* **Read as written this is satisfied by a sweep that refuses everything**, so it is built
as two checks, in `test-gradient-parity.R`:

- **the gate** — nothing escapes unnamed: no raw error, every status in the declared set, answered
  rows finite, refused entries `NA` so an undefined metric cannot read as a zero one, and the
  refusal's location wholly present or wholly absent.
- **the coverage** — a named list of branches that have never answered. A regime that *stops*
  answering and one that never did both come back `refused`; only the name separates them, so the
  name is what is asserted.

**Swept over seventeen drivers, and it found two causes.** One was the sweep's own to close: **root
carbon was the last differenced family still holding the base collar**, and it is the family a drying
stand crosses on.

| driver | before | after | pins |
|---|---|---|---|
| `rain 0.20, L=10` | refused | **answered** | 24,744 |
| `rain 0.15, L=10` | refused | **answered** | 48,554 |
| `rain 0.10, L=10` | refused | **answered** | 95,975 |
| `rain 0.05, L=10` | refused | **answered** | 151,935 — **62.7% of solves** |

**Fifteen of seventeen answer.** Both `L=20` runs (137,814 and 99,645 pins) and the seasonal driver at
full amplitude (118,847 pins, 304 shutdowns) are among them. `rain 2.00 / 0.28 / 0.27` stay
**bit-identical** to a build carrying none of this work.

**The two that refuse are `shade-death`**, at `k_I` 20 and 40 — 30,509 and 44,741 incidences. It is
governed by light rather than water, so no rainfall sweep reaches it and the shaded driver is its only
evidence. §4.4 now carries what its rows are, and they are **not** the "exactly zero" the corpus
assumed.

**And a second finding, asserted rather than fixed: that refusal is UNLOCATED.** It is raised while
forming the census seeds — inside `set_recorded_state`, where there is no node loop to be caught in —
so species, node and step range are all sentinels, where a refusal from the sweep carries all four.
The gate requires the location to be wholly present or wholly absent, because a half-filled one is the
shape that reads as an answer. **Answering `shade-death` removes this instance**; the seeding path
keeps the shortcoming for whatever refuses there next.

### D — ~~shade death and hydraulic shutdown~~ **DONE**

The last branches with no rows. A shut point is not an argmax, so it gets its own function rather than
a branch inside the interior derivation, with which it shares nothing — no curvature, no envelope
step, no bound, no collar.

**Every row is a difference of the solve itself**, which is what makes one piece of code right for two
kinds that carry opposite rows (§4.4). Three things are declared instead, each for a reason that is
not economy:

- **radiation and the maximum conductance** — neither appears in the profit on this branch. Radiation
  decides *which* branch, and that is a kink rather than a derivative.
- **the assimilation-side traits** — gross assimilation is identically zero, so they reach nothing;
  and a step in one moves `assim_max_`, the quantity *deciding* the branch. Differencing them refused
  at a boundary their own row does not depend on, which is what a shaded stand refused on first.

**Respiration is the case that needs both.** `R_d_25` is live here *and* sits against the boundary,
because `assim_max_` is net of it — so the arms are centred where both stay on the branch and
one-sided second order where one does not, the same arrangement §0's C already uses.

*Refereed at the leaf:* a shaded leaf's soil rows are `−C'(B)·∂B_wet/∂ψ_j`, and against a difference of
the profit at a **re-solved** point the composition agrees to **3.6e-07**. Both factors already had
their own referee, so a disagreement would have been the product's.

| driver | before | after |
|---|---|---|
| `k_I 20, L=5` | refused | **answered** — 91,463 shade-death points |
| seasonal `L=5` | answered | answered, now over its 6 hydraulic-shutdown points too |

**What still refuses is the LIGHT FLOOR at `k_I` 40** — a guard rather than a regime, and one this
document listed as *implemented and never fired*. **It has now fired**, which closes that entry of
report 08 §7's guard census.

**And three ladder checks had to be re-pointed**, the same shape as C2's: `test-gradient-ladder-sweep.R`
asserted that a shutdown fixture *refuses*. That was the gap recorded as a gate. They now assert it
answers with finite rows — and say what is still **not** discharged: the two output kinds are still not
separable, because the fixture that would separate them is a fold and nothing here reaches one.

### E — ~~the light floor~~ **DONE**, and it was two sites rather than one

The recommendation was taken — declare the zero, count it — but the reasoning it rested on was wrong
in two places, and both had to be fixed before the declaration meant anything.

**⚠️ THE FLOOR IS TWO SITES AT TWO DEPTHS AND THE UNINSTRUMENTED ONE BINDS FIRST.**
`compute_average_light_environment` applies the **same `1e-4`** to *each quadrature point* of the
mean-light integrand, with no counter and no refusal, and it is on the **shipped** shading model
(`MeanLight`). `radiation_at` then floors the mean those points make. Since the crown shape integrates
to one, a floored point cannot pull the mean below the floor, so the instrumented site was seeing a
remnant of the severance rather than the severance:

| `k_I` | solves | `light_floor` | `light_floor_crown` |
|---|---|---|---|
| 0.5 (shipped), 5, 20 | 226–288k | 0 | 0 |
| **40** | 298,513 | 8,422 — 2.8% | **1,262,666** |
| **80** | 294,061 | 23,782 — 8.1% | **3,426,598** |

A factor of **150**, and per quadrature point it binds about four times per solve. So the shipped model
**was already severing the light coupling silently on the gradient path** while a guard one level down
refused loudly for the same reason. Refusing at one depth and declaring at the other is not a position
that can be held; that is what settled the decision rather than a preference.

**⚠️ AND THE COUNTER THAT DISCHARGED THE OBJECTION COULD NOT SEE THE DIFFERENTIATED PATH.** The
recommendation rested on "the clamp counter is the measurement, and it exists now". It did not measure
this: `rebind_from` carries no tally and the block copies its strategy per unit and discards it, so
every clamp the *sweep* hit landed in a temporary. `census_clamp_counts_tf24` reported the forward run
only — the same defect this document already records for the operating-point counters, inherited by
adjacency. Fixed by holding the differentiated half behind a `shared_ptr` the rebind copies, with the
two paths kept as separate lanes so they cannot be conflated.

**The referee, and what it does and does not establish.** Report 08 §5's completeness reference at
`k_I` 40 — a whole-run rebuild difference, which re-runs the forward model and so carries the *same*
clamp:

| column | sweep | ratio at rel 1e-6 / 1e-5 / **1e-4** / 1e-3 |
|---|---|---|
| `a_l1` | −0.14112536 | 1.000014 / 1.000001 / **0.999999** / 0.999995 |
| `lma` | −0.12862541 | 0.998725 / 0.999929 / **0.999997** / 0.999995 |
| `k_I` | −4.8228e−07 | 1.175752 / 0.992945 / **1.002680** / 1.004531 |

Agreement to **one part in a million** on the two well-conditioned columns; `k_I`'s own value is 5e−07,
near the reference's floor, so it holds 0.3% and its 1e-6 reading is off the plateau's fine end —
report 08 §5A.3's first failure mode, showing up where that section says to expect it.

**Be precise about what this proves.** The reference differences the *clamped* census, so agreement is
not evidence the clamp is harmless. It is evidence of the two things E needed: the census **is**
differentiable here — stable across three decades of step, so there is no kink at the stand's scale
even though each cohort's radiation has one — and the sweep returns that derivative. Refusing would
have been right only if the derivative did not exist.

`k_I` 40 and 80 now answer: **135 answered, 3 zero-slack, 3 zero-structural, 0 refused, 0 undeclared**,
carrying 7,145 + 1,052,596 declared severances the run reports. `parity_known_gaps` is empty and its
non-vacuity check is re-pointed: the `clamped` driver must now answer **and report a severance**, since
an answered gradient carrying a declared zero and one carrying no clamp at all are the same numbers.

**The counter-argument stands unchanged and is not closed by any of this.** A trait search walking
`k_I` up is told the light sensitivity is zero where the *unclamped* model has some. Removing the floor
is a forward-model change needing a `scientific_version` bump and a re-bless, so it is not a gradient
change at all — but it is now *visible*, which it was not before.

### F — ~~#2, the amplification ceiling~~ **DONE**, and the ceiling guards a state nothing reaches

Both halves landed, and each overturned something this document asserted.

**F1's stated obstacle does not exist.** This document recorded that "the refusal is raised while the
block is being recorded, which happens before any output adjoint is applied — so no seed can reach a
decision already taken". The seeds are in fact fully assembled at `patch.h:1862-1872`, **immediately
before** the recording, and the water-coupled outputs are a contiguous known range. Only **two** things
are grafted at all — `leaf_profit_` and `leaf_soil_consumption_[i]`, one call each — and `curvature`
feeds *only* the uptake block; the profit block is the envelope theorem's and reads no curvature. So
five guards were already uptake-only in substance and merely refused everything.

What it took: the leaf now **records** that its water rows do not exist rather than throwing, leaves
them off the tape, and the block loop asks each metric's own seed whether it reads an uptake output.
Refusal became per-metric data on the patch instead of an exception that ends the sweep for every
metric. Converted: the curvature guard, the per-layer branch kink, no-layer's-root-carbon, the water
response's first coefficient, and `dR_dlight`. **Four others are genuinely fused** — `kmax`, the driven
leaf traits, the hydraulic-cost traits and the photosynthesis traits each guard a profit half and an
uptake half in one test — and still refuse the whole leaf. Splitting those means splitting the guard,
not the plumbing.

**⚠️ AND IT INTRODUCED A DEFECT THAT HAD TO BE CAUGHT: a probe returned the severed rows as ZEROS.**
With the guard no longer throwing, `ladder_rhs_adjoint_tf24` handed back zeroed water rows and said
nothing — a severed row and an answer as the same number, which is the one failure the status channel
exists to prevent. It now reports `refused` with the reason **and** returns NaN, so a caller ignoring
the flag still cannot read a severance as an answer. **Any consumer of a single-seed adjoint has to be
checked for this**, and there was exactly one.

**⚠️ REPORT 08 §8's PREMISE HAS NO INSTANCE IN THIS CENSUS.** *"A metric seeded only on size states
survives a fold that kills a water-coupled one"* — the separation is real and demonstrated at **one
right-hand-side evaluation**, where a seed on `height` or `mass_heartwood` answers while a seed on a
soil layer refuses by name. Over a whole trajectory it saves **nothing**: all three metrics refuse,
because all three are size moments but growth reads water, so sweeping backwards gives every metric a
non-zero soil adjoint within a step or two of the census. **TF24's census contains no
water-independent metric.** Asserted rather than noted, so adding one shows up there.

**F2's ceiling exists and guards a state no solved operating point reaches.** Swept over 5,625 solved
leaf states — `stem_c` 0.4–2.68, `stem_b` 2.5–6.0, `beta2` 0.5–3.0, radiation 15–2000, soil potentials
0.1–5.5, uniform and graded profiles:

| | |
|---|---|
| interior with a finite curvature | **1,351 — every one strictly negative, none non-negative** |
| min \|Π_pp\| | **0.0623** (1% 0.285, median 1.79, max 7.38) |
| the other 4,274 | 2,885 pinned-dry, 1,125 shade-death, 156 pinned-wet, 108 solver-refused |

It reproduces §7 where §7 measured — at shipped `stem_c` the interval's min \|Π_pp\| is **0.672**
against §7's 0.67, and at `stem_c` 0.6 the non-concave share is **11.2%** against §7's 8.7%. But the
conclusion inverts: **the folds are real and the solve never lands on one.** At `stem_c` 0.4, 40% of
the feasible interval has `Π_pp ≥ 0` and the operating point is still strictly concave — because where
the interval goes non-concave the solve **pins**, and at a pin the curvature is never computed. §6.1
said a sample about solved points cannot falsify a fold; the reason turns out to be structural rather
than a sampling limit.

So the floor is set from measurement at **1e-3**, sixty times below the observed minimum, and it lives
on `Control` as `gradient_curvature_floor` — in `gradient_control()`, because it moves no forward number
and still decides which rows exist. **The instrument matters more than the number**: a guard that held
and a guard nothing reached report the same green, so `census_curvature_margin_tf24` carries out the
smallest curvature the sweep met. Production margins:

| driver | wet | drought | very-dry | seasonal | shaded | clamped | long |
|---|---|---|---|---|---|---|---|
| min \|Π_pp\| met | 2.51 | 0.731 | 0.726 | 0.740 | **0.119** | 0.158 | 2.17 |

The tightest is **119× the floor**. And because nothing reaches the guard, **F1's separation could only
be tested by injection** — raising the floor above every curvature the model produces, which is what
`ladder_patch_fold` does and why it says so in its own comment.

### G — ~~the remaining clamp sites~~ **DONE for plant's own; phylloptim's are a different category**

**There are eleven, not fifteen**, and the corpus's list was both over- and under-counted. The enum,
the names and the counter now live in `plant/inst/include/plant/clamp_sites.h`, reachable from the
strategy *and* the environment, because the sites live in two objects and a tally should read the same
however a site is reached. Names come from the enum, so a site cannot be counted under its neighbour's.

**The census, over seven drivers — all seven answer:**

| site | differentiated | forward | reading |
|---|---|---|---|
| **`rooting_depth`** | **1,295,396** | 1,671,760 | every driver, **including the wet control** |
| `light_floor_crown` | 1,052,596 | 1,262,666 | `clamped` only |
| **`storage_floor`** | **194,571** | 307,480 | every driver **except** wet |
| `light_floor` | 7,145 | 8,422 | `clamped` only |
| `reserve_ceiling` | 32 | 111 | |
| `soil_moisture_floor` | 0 | 12 | forward only — never on a swept step |
| `soil_potential_ceiling` | 0 | 13 | forward only |
| `soil_conductivity` | 0 | 24 | forward only |
| `soil_positivity` | 0 | 0 | never binds on any driver |
| `rainfall` | 0 | 0 | never binds |
| `infiltration` | 0 | 0 | never binds |

**⚠️ THE THREE-WAY TEST'S FIRST CASE SPLITS IN TWO, and reading the code does not reveal it.** The
table in the old §0 offered "masks a channel the model means to have" — and the largest site in the
model does not *mask* anything. `min(height, rooting_depth_max)` **is** the model saying roots stop at
a maximum depth, so its zero is the model's own. The light floor's zero is a numerical guard's. Both
are declared zeros; only the second is a candidate for removal, and only by changing the forward
model. The classification therefore has four outcomes:

| the clamp | the row |
|---|---|
| **is** a modelling statement | declared zero, and **not** a candidate for removal — `rooting_depth` |
| is a numerical guard, census bit-identical either side | declared zero, removable by a forward-model change — the light floors, `storage_floor`, `reserve_ceiling` |
| binds forward but never on a swept step | counted, and kept **separate from "never"**: the guard is reachable, so a longer run or a finer schedule could put it on a recorded step |
| never binds on any driver | counted, and reported as never having fired — the only thing separating a guard that held from one nothing reached |

**Two sites were not on the corpus's list and one of them is the largest severance in the model.**
`rooting_depth` fires 1.3 million times on the differentiated path *including on the wet driver* — the
fixture the corpus uses as its clean regression control — and where it binds the entire root profile
stops depending on height. Nothing was counting it. `storage_floor` is a genuine **guard** severance
carried silently on every drought driver, and report 08 §9 lists "the absorbing reserve region" among
what nothing referees; this is it, now counted.

The classification is asserted in `test-gradient-incidence.R` as data, because a document cannot fail.

**phylloptim's clamps are NOT instrumented, and that is a decision rather than a remainder.** They were
investigated to root cause and the answer is that counting them would buy less than the measurement
already does. Four reasons, each read off the code:

- **They already carry matching derivative kills.** `root_vuln_integral_deriv_at` returns zero exactly
  where `root_vuln_integral_at` returns the cap — *"because there the value no longer depends on psi"* —
  and the leaf-temperature clamp pairs the same way (`*dT_dE = (clamped == Tleaf) ? … : 0.0`). So these
  yield a **correct declared zero**, not a wrong row. This is the treatment §0's E had to be argued
  into; phylloptim had it already.
- **The trait row survives the cap by construction.** `root_vuln_integral_droot_b`'s own comment: past
  the ceiling `G` is the complete-gamma limit `(root_b/root_c)·Γ(1/root_c)`, **linear in `root_b`**, with
  `dG/dψ` zero — so the Euler identity returns that limit's own derivative. Value, state row and trait
  row are consistent under the clamp.
- **The thresholds are not reached on any driver measured — but ⚠️ THE MARGIN IS THIN IN THE STATE
  VARIABLE AND WIDE ONLY IN THE POTENTIAL.** Max layer potential over recorded steps, rainfall 2.00 down
  to **0.01** and lifetimes to 20, is **4.5877 MPa** against 6.8229 (the curve's last knot) and 7.3132
  (the integral's ceiling) — **zero** layer-steps over either, and no layer reaching `psi_crit` 5.87. But
  the retention curve is steep, and in moisture those same numbers are **θ 0.12949 measured against
  0.12062 at the cap: a margin of 0.0089, under 7%**, with the wilt point itself at 0.12472. So the
  reassurance is "no driver dries a layer that far", not "the cap is far away".

  What holds it back is a **feedback rather than a coincidence**, which is the part that makes it
  durable: the **aridest** driver reaches a *lower* maximum than the moderate ones (4.11 against 4.59),
  because an arid stand carries less biomass and so transpires less. Drying is limited by the vegetation,
  so a harsher rainfall driver does not erase the margin — but a change that lets a layer dry while the
  plant lives would, and 7% of θ is not much room.
- **Two are off the path outright.** `profit_at_collar_psi` — the collar clamp, defect #1's site — is
  called only from `tf24f_strategy.h`, never from TF24's; §4.1's `profit_at_fixed_collar` replaced it and
  refuses rather than clamping, and TF24f is instantiated at `double` only, so the tape link is cut
  regardless. And the leaf-temperature clamp is behind a flag that is **off**:
  `use_energy_balance = 0.0` (`tf24_strategy.h:148`), so `Tleaf` is just the environment's 25 °C and the
  whole energy-balance path — clamp included — is dead.

**A counter here would read zero forever, which is weaker than the margin.** It would say the guard did
not fire; it would not say why it cannot. So what is asserted instead is the **distance**, in
`test-gradient-incidence.R`, over the recorded steps rather than at a terminal state — a layer that
dried and rewetted is exactly the state a terminal reading misses.

**And the cost of instrumenting them is the build loop, not the code — which is #13 in practice.** A
phylloptim header edit needs a phylloptim reinstall, which needs a near-full `plant` recompile because
the headers are inline, with the odelia clobber risk on each pass. A threshold on a readable quantity
does not need any of that.

*What would change this:* a driver that dries a layer past 5.87 MPa while the wettest stays below it —
0.0089 of θ away, so not far — or `use_energy_balance` being switched on. Neither is reachable by
rainfall alone, on the evidence above.

**Two findings from that investigation are worth more than the decision, and neither is about counting.**

**⚠️ THE LEAF-TEMPERATURE CLAMP CARRIES A LATENT WRONG ROW, BEHIND THE FLAG.** Its own kill
(`*dT_dE = (clamped == Tleaf) ? … : 0.0`) is honoured by both *marginal* consumers, so the analytic path
stays consistent. What is not guarded is plant's **differenced radiation row** (`marginal_at` at
`radiation·(1 ± 1e-6)`): with both arms on the clamp, `dR_dlight` silently loses the thermal channel and
keeps only the electron-transport one, and `crossed` never fires because both reads are finite and
feasible. Reachable at PPFD 2000 with low wind and a large leaf dimension — about 87 °C against the 70 °C
ceiling. **So switching `use_energy_balance` on is not a forward-only change; it opens a gradient defect
this document has not costed.** That is the thing to know before anyone enables it.

**And plant's branch-kink guards at the uptake sign splits are OVER-conservative.** The
`T_src_min`/`T_src_max` and `T_pos_lo`/`T_neg_hi` pairs are integration-range **splits**, not clamps, and
the kinks are **removable**: `span/integral = Δ/ΔG = 1/⟨f_r⟩`, an analytic function of Δ through zero,
with the signs cancelling — so `r_R`, and hence `E_i`, is smooth across the split and its Δ→0 limit is
exactly the special-case branch. The ψ = 0 split is dead anyway, because `psi_soil ≥ 0` is validated and
the collar is bounded below by the wettest layer. So the two "sits on a branch kink" refusals lose rows
for a function that **is** differentiable there. That costs **availability, not correctness** — which
makes it the opposite of every other item in this document, and the one place where a guard could be
removed rather than added.

### What is left, and it is smaller than what was closed

Nothing in §0 remains. What the work opened rather than closed:

1. **phylloptim's clamps** — a category rather than a remainder, spelled out at the end of G. They
   distort a *supplied* row rather than severing an AD one, so they need a phylloptim-side tally and a
   test about arm feasibility.
2. **The four fused guards** in `record_leaf_outputs` — `kmax`, the driven leaf traits, the
   hydraulic-cost traits, the photosynthesis traits. Each tests a profit half and an uptake half
   together, so each still refuses the whole leaf. The plumbing to split them exists; what does not is
   a reason to, since nothing reaches them either.
3. **A water-independent census metric**, if one is ever wanted. F1's separation is built and correct
   and buys nothing until such a metric exists — see §0's F.
4. **#13, build provenance** — the one defect still open, and now root-caused. It is **two mechanisms
   with one shape: the build reports success without saying what it built.**

   *A header edit across a package boundary is invisible.* `plant` compiles `phylloptim`'s headers from
   the **installed** library via `LinkingTo`, not from the working tree, and editing them moves no
   `.cpp` timestamp in `plant` — so `make` finds nothing to do, the build succeeds, and the `.so` runs
   the old model. There is no error and no warning; the only symptom is numbers that do not match what
   was just written.

   *And a resolving installer replaces the fork.* `phylloptim/DESCRIPTION` carries
   `Remotes: traitecoevo/odelia@v0.2.1`, so `install.packages(".")` or `devtools::install()` fetches
   **upstream** odelia over the local fork — and upstream's lacks the `Replayable` concept `plant`'s
   `store_trajectory` static-asserts on, surfacing as an error in `scm.h` in a session that never
   touched odelia. `R CMD INSTALL` does not resolve `Remotes` and is therefore the safe form. Six
   occurrences across three sessions, one of them this one.

   **The storage-class half of this is NOT a live defect, and it is worth saying so before someone
   "fixes" it.** `plant/src/Makevars` and `odelia/src/Makevars` both set `-DXAD_NO_THREADLOCAL
   -DXAD_USE_STRONG_INLINE` and each comments that they must match the other exactly, because a
   storage-class mismatch **does not change the mangled name** and so cannot be caught by the linker.
   `phylloptim/src/Makevars` sets neither — and is exempt, because phylloptim uses `xad::fwd` only and
   never references `Tape` or `xad::adj`. Forward mode is tapeless, so its `.so` never touches the
   `__thread` variable the flags govern. **That exemption is silent and would break the moment
   phylloptim gained a reverse-mode path**, which is the same defect again: a pairing requirement with
   no mechanism.

   *A real fix is packaging work, not gradient work*: a stamp comparing the installed phylloptim's
   header hash against the working tree's, refused at configure time. Until then the mitigation is the
   procedure in §8 — and the `grep -c "concept Replayable"` check is the only thing that reports the
   second mechanism at all.
5. **The cost figure**, still 14.6× and now measured on a gradient that answers strictly more than the
   one that figure was taken on.

### Standing, and not to be lost

- **Two guards are implemented and have never fired**: the graft's input finiteness test, and the
  **curvature floor** — the second measured rather than assumed, over 5625 solved states, and its
  distance from firing is now reported per run by `census_curvature_margin_tf24`. Three clamp sites
  have also never fired on any driver (`soil_positivity`, `rainfall`, `infiltration`) and three more
  fire forward but never on a swept step, which is a **weaker** claim and kept separate.
- **A COUNTER ON A REBOUND OBJECT MEASURES NOTHING unless its storage is shared.** `rebind_from`
  copies values, and the block copies its strategy and environment per unit and discards them — so a
  plain member counts the sweep's severances into a temporary and reports zero. This is why the light
  floor read 0 on the differentiated path while firing a million times. Both `clamp_counter` and
  `curvature_margin` hold their differentiated half behind a `shared_ptr` the rebind copies; anything
  new that counts on that path must do the same.
- **A guard converted from a throw to a marker leaves every consumer of that path returning ZEROS.**
  Removing a `throw` does not remove the obligation to say the row is gone: the tape returns zeros for
  rows never recorded, and a zero row and a severed one are the same number. One consumer
  (`ladder_rhs_adjoint_tf24`) needed the report added and its numbers turned to NaN. Grep for callers
  before converting another guard.
- **`root_psi_crit` never binds at shipped defaults**, so `bound_row(DryRootPsiCrit)` is unreachable
  without a deliberately-lowered fixture. §5's non-vacuity requirement is not optional.
- **The operating-point counters do NOT measure the gradient path.** They count forward solves; the
  sweep visits only the recorded steps. A run reporting 172 pinned points answered *before* the pinned
  branch was built, because none of them was on the sweep's path. To find out whether a driver reaches
  a branch, put a temporary `throw` on it and see which drivers refuse — that is how B was shown to
  work at all.
- **`R CMD INSTALL --no-multiarch --preclean odelia` before every `plant` build.** Installing or even
  `compile_dll`-ing `phylloptim` can replace the fork `odelia` with upstream's; it happened three times
  in one session and twice more in the next, each time surfacing as `'Replayable' is not a member of
  'odelia::ode'` pointing at `scm.h`.
- **Absolute paths in every build command.** The shell's working directory persists between calls, so
  `R CMD INSTALL phylloptim` after a `cd` into it silently installs nothing and the next build runs the
  old headers.

### How to accept a change here, because the pattern is now settled

Three measurements, in this order. Every item from B onwards was accepted this way.

1. **Bit-identity for what already answered.** Build *without* the change, fingerprint the drivers in
   hex, rebuild *with* it, diff. Not "close" — identical. This is what catches an arithmetic
   rearrangement dressed as a refactor, and it caught two: `(a − b)/(2h)` against `0.5/h·a − 0.5/h·b`,
   and `−x/c` against `(−1/c)·x`.
2. **Before-and-after incidence for what did not.** Which drivers went refused → answered, and how
   many operating points of the named kind they contain (report 08 §2 item 6).
3. **A referee for any new row**, against a difference of the relation that *defines* it — report 08
   §5A. A row that is only checked through what consumes it is not checked.

And two habits worth keeping.

**When a test fails after a branch starts answering, read it before fixing it.** Several checks have now
asserted a refusal that was the gap rather than a gate — the incidence test, three in the sweep ladder,
and the parity gate's whole non-vacuity clause, which existed to keep the known-gap list tested and
became meaningless when the list emptied. Each had to be re-pointed at what it now measures, not
relaxed. The parity gate's replacement is worth copying: it asserts the `rooting_depth` severance,
which fires on **every** driver including the control, so a build that has lost the counter fails
rather than reading as a cleaner stand.

**A test written against a list of two does not survive the list growing to eleven.** Three of this
session's own new checks failed on `all(counts > 0)` and `all(counts == 0)` the moment more sites
existed — the assertions were about the sites that happened to be there. Index clamp checks **by name**,
and assert the sites the block is about rather than the whole vector.

---

## 1. State of the tree

| | |
|---|---|
| what works | one species or many, birth-date coordinate, **every operating-point kind a driver has reached**: interior, pinned wet, pinned dry, hydraulic shutdown, shade death |
| cost | **14.6× the forward run** *(measured before the branches below were opened; a shut or pinned point costs more arms than an interior one and this has not been re-measured)* |
| where it stops | **nothing found.** Every driver tried answers, `k_I` 40 and 80 included |
| what a refusal is | metric-level, *returned* rather than thrown, named, and located. **Per metric where the missing row is located to the water outputs** — but see §0's F: on this census that spares no metric, because all three read water |
| what is silent | nothing known. Eleven clamp sites are counted on both paths and classified; the curvature guard reports its margin |

**The parity sweep is the summary. Over the seven drivers of the clamp census — rainfall 2.00 down to
0.05, lifetimes 5 to 20, a seasonal driver at full amplitude and `k_I` up to 40 — all seven answer**,
and the five standing drivers in `test-gradient-parity.R` carry that as a check. What the sweep now
reports beside "answered" is the **severance count**, because a gradient carrying a declared zero and
one carrying no clamp at all are the same numbers.

**Build with the working tree, never the installed package.** The installed `plant` segfaults inside
`census_trait_gradient_tf24`. Load with `library(odelia)` then `pkgload::load_all("plant")`.

---

## 2. The thirteen defects

Ordered by severity, which is not the order of the work — see §3 for that.

**Status** is against the committed tree. Unmarked means open.

| # | defect | status | root cause | reachable at | silent |
|---|---|---|---|---|---|
| 1 | FD probe crosses a feasibility boundary | **closed** — refused, then differenced from inside | one entry point serves two consumers; `evaluate_root_collar_psi` clamps by design for the acclimating FD, wrongly for a frozen-collar partial | **production drought** — guaranteed at any pin | yes |
| 2 | no amplification ceiling | **closed** — guarded on magnitude, and the guard is measured to be unreachable | the guard tested the curvature's **sign**; the divergence is in its **magnitude** | **nothing reaches it**: over 5625 solved states every interior point is strictly concave, min \|Π_pp\| 0.0623 against a floor of 1e-3. Where the interval folds the solve PINS, and a pin computes no curvature | no — the margin is reported |
| 3 | forward tangent non-finite | **closed** | boundary node carries `log(birth_rate·pr_estab) = −Inf`; the tangent works in `ℓ` where the sweep works in `n` | any stand where establishment fails | yes |
| 4 | clamp severs a row | **closed** — declared zero, counted on the path it severs on, and eleven sites rather than one | the floor clamps at the **read**; the field stores values to 1e-117 underneath. And the floor is **two sites**, of which the shipped path's was uncounted and bound 150× more often | `rooting_depth` on **every** driver including the control (1.3M); the light floors at `k_I` 40 (1.06M); `storage_floor` on every drought driver (195k) | no — counted, both paths apart |
| 5 | ambiguous exact zeros | **closed** | three correct zeros, three different causes, no way to say which | every run | yes |
| 6 | non-finite input poisons the value | **closed** | the graft guards its derivatives, not its inputs | latent; widens with the pinned branch | yes |
| 7 | ghost cohort | **closed** | `check_birth_dates_distinct()` is called on the seeding path, never the scheduled one | any duplicated schedule time | yes |
| 8 | refusal misnamed | **closed** | one tag covers a dry plant and a broken parameterisation; `GSS_tol_abs` has two defaults | `root_psi_crit` below `root_zero_E` | partly |
| 9 | pinned refusal | **closed** — the stand follows the bound and answers | the bounds are locals, discarded; `PinnedDry` never said which arm | **production drought** | no |
| 10 | raw error escapes | **closed** | no refusal channel exists in C++ | every failure above | wrongly |
| 11 | forward run dies | upstream | real, and **already largely fixed** upstream *(corpus: #599 went 17/40 → 5/40)* | did not fire in 14 runs | no |
| 12 | resource | other branch | the forward `O(K·N)` field build, inherited by the sweep's replay | every multi-species run | no |
| 13 | build provenance | open — root-caused below, and it is packaging rather than model | a header change moves no `.cpp` timestamp, so `make` builds nothing and the `.so` runs the old model with no error; and `phylloptim`'s `Remotes: traitecoevo/odelia@v0.2.1` lets a resolving installer replace the local fork | **every** rebuild that crosses a package boundary — six occurrences in three sessions | **wrongly**: it reports success |
| 14 | pinned profit rows priced by the interior condition | **closed** | `marginal_price_water` is `λκf(p)/S`, which is `∂Π/∂E_up` **only once `∂Π/∂p = 0`** — the first-order condition is inside the expression rather than beside it | every pinned point | yes |

**#14 was not in this list and was found by refereeing a row nothing tested.** The pinned rows landed
with no test and no R binding; against a central difference of the profit at a **re-solved** operating
point they read **1.08** of it at a wet pin and **0.85** and **0.53** at two dry ones. The fix is to
take the price from `dmarginal_profit_duptake_slope`, which builds `∂Π/∂E_up` from the cost and
assimilation kernels with no stationarity in it at all — so it is the frozen-collar price wherever the
point sits. The interior branch keeps the interior price: the two agree there by the condition, differ
in the last bits, and a gradient that already answers must not move.

⚠️ **A wet pin cannot referee it.** The wet residual is total uptake alone, so `∂B/∂ψ_j` is exactly
`−(∂E_up/∂ψ_j)/S` and the bound term cancels the whole difference between the two prices — the
interior formula lands on the right answer there whichever price is used. **Only a dry pin is
evidence**, and `test-profit-env-row.R` asserts that blindness as a measured ratio rather than
describing it.

**Two of these need no work here.** #11 is upstream and mostly closed. #12 is a forward-model cost shape
with the running-sums reduction already in flight on another branch — the reverse RHS is *sub*-linear in
species (0.0130 / 0.0232 / 0.0352 s at 1/2/3 species).

---

## 3. Build order

**Each phase makes the next observable. The gates are not optional.**

### Phase 0 — unconditional, no design needed — **LANDED** (`plant` b7876f03, `phylloptim` 44dad1b)

All four are in the working tree of `plant` and `phylloptim`. No regression: the same 7 pre-existing
failures before and after, every pass count identical, and the gradient structure tier clean at 165
assertions. Each was checked live rather than assumed.

1. **Call `check_birth_dates_distinct()` on the scheduled path.** Done — `patch.h`,
   `introduce_new_nodes`. The guard's message now names the repeated time. Fixes #7.
   *Live:* a schedule carrying 0.5 twice now stops, naming `0.500000`, where the same schedule with
   distinct times runs. That it was **silent** before is not re-measured here — it rests on the two
   pre-existing call sites both being seeding/resume paths, and on §7's bit-identity measurement.
2. **Test the graft's inputs for finiteness** in `record_with_derivatives`, beside the existing
   derivative test. Done — `tf24_strategy.h`. Fixes #6.
   **No liveness evidence.** Nothing in the suite reaches a non-finite graft *input*; the defect was
   found by reading, and the containment that has kept it latent is a Boost throw one level down,
   which is defect #10. Treat this as an unexercised guard until Phase 2's counters can say otherwise.
3. **Split `GSS_tol_abs`** into a solver tolerance and a degeneracy threshold. Done —
   `phylloptim::Leaf` now carries `collar_interval_min_width` for `prepare_collar_solve`'s
   interval-collapsed test, and `GSS_tol_abs` keeps only the off-path single-layer optimisers.
   Half of #8. **The split is behaviour-preserving on purpose** — the full constructor initialises
   the new member from the old argument, so all 576 golden operating points are bit-identical, and
   **the value is a Phase 2/3 decision, not a Phase 0 one** (§6.4).
   *Also removed:* `TF24_Strategy`'s five dead tolerance members — `newton_tol_abs`, `GSS_tol_abs`,
   `vulnerability_curve_ncontrol`, `ci_abs_tol`, `ci_niter`. Every one was declared, copied through
   the rebind, and never read; four shadowed a `control.*` of the same name that *is* read, at a
   different default (`ci_abs_tol` 1e-6 against the control's 1e-3, `GSS_tol_abs` 1e-3 against 1e-1).
   A reader would take the tighter number for the one in force. `newton_tol_abs` had no live
   counterpart anywhere in the package.
4. **Seed the forward tangent in `n`, not `ℓ`,** at the boundary node. Done —
   `node.h`, `compute_initial_conditions`. Fixes #3 — and this **restores the reference** in the only
   regime where nothing can currently check the sweep.
   *Live, and it reproduces §7's figure:* at a boundary density of exactly zero the forward RHS
   Jacobian was **594/1089 = 54.5% non-finite** and is now **0/1089**, with the log density's value
   unchanged at −Inf either way. The mechanism is that `log()` reaches −Inf from an exact zero
   through 0/0, so it recorded a NaN derivative beside a correct value.

### Phase 1 — the status channel — **LANDED** (`plant` b7876f03)

```
census_trait_gradient  ->  { gradient[m][t], status[m][t], refusal[m] }

status := answered
        | zero(slack | structural | UNDECLARED)
        | refused(reason, species, node, step_first, step_last)
```

Fixes #5 and #10. Built as `plant/inst/include/plant/gradient_status.h` — `gradient_status`,
`gradient_refusal` and `census_gradient`, the last being the pair the sweep returns so that a bare
row of numbers is not expressible.

**A fourth zero kind, `zero-undeclared`, is not in the original grammar and is the point of the
change.** An exact zero is the signature of a missing accumulator far more often than of a true
insensitivity, so resolving every zero into *slack* or *structural* would replace one ambiguity with a
confident wrong answer. A zero with no declared reason is marked as a finding instead.

**How refusal travels.** The fifteen `util::stop("TF24 gradient: …")` sites throw `gradient_refusal`
instead. The block loop in `patch.h` catches it to attach the species and node — the leaf knows the
reason and not which plant — and `census_trait_gradient` catches it to attach the recorded-step range
and turn it into a status. `util::stop` is kept for a *caller* error (an unknown metric index, the
wrong coordinate): those are not refusals and must still be errors.

**A refusal ends the arithmetic and not the loop.** The narrowing the sweep does per segment is
bookkeeping the width restoration at the tail depends on, so it runs on every segment whether or not
there is still a gradient to compute. Returning early there leaves the patch narrowed and the object
no longer repeatable.

**The declaration is keyed by name, not by position.** `ad_parameter_zero_classes()` derives from
`ad_parameter_names()` by name, so it cannot become a third positional list of 47 paired by index with
no guard. It is consulted only where the number is exactly zero, which is what keeps it honest as the
census grows: a parameter that becomes live stops being zero and its declaration is never read.

*Live, all four measured on a run:*

| | |
|---|---|
| wet stand | every entry `answered`, no refusal |
| drought (constant rain 0.25, L = 10) | every entry `refused` and `NaN`, naming **species 1, node 79, steps 283–305** — where before a raw error reached the R prompt with no localisation at all |
| zeros at shipped defaults | 132 answered, 6 `zero-slack` (`psi_crit`, `root_psi_crit`), 3 `zero-structural` (`a_f3`), **0 undeclared** — exactly §7's three columns and no others |
| `rooting_depth_max` = 10 m | that column goes exactly zero and comes back **`zero-undeclared`**, so the state-dependent zero is visible rather than passing as an answer |

**One finding, and it is now guarded.** The ladder already carried an R-side declared-zero taxonomy
with the same two classes and the same members. Two statements of one list is the drift shape this
corpus keeps finding defects in, so `test-gradient-ladder-declared-zero.R` now requires the shipped
C++ declaration and the fixture's list to agree in both directions. **Fault-injected:** removing
`a_f3`'s declaration in C++ takes `zero-structural` from 6 to 0 and fails three assertions.

### Phase 2 — detectors, which are also the instruments — **PART LANDED**

**Landed: the instruments and their two numbers. Not landed: items 5 and 6, the two detectors that
change which states answer.**

The counters live on `TF24_Strategy` and are read off the *live* system, never `r_patch()` — that is a
snapshot the run copies out. They are deliberately outside `rebind_from`, because a block copies the
strategy per unit and discards it, so carrying the tally across would count the sweep's copies as well
as the run. R reads them with `census_operating_point_counts_tf24()`, `census_clamp_counts_tf24()` and
their `_names_` / `_clear_` companions; `test-gradient-incidence.R` pins both.

**§6.3 is measured. The classification tally, per run:**

| driver | solves | interior | pinned-dry-root-crit | gradient |
|---|---|---|---|---|
| default, lifetime 60 | 1,309,513 | **100%** | 0 | answered |
| constant rain 2.0, L = 10 | 361,220 | **100%** | 0 | answered |
| constant rain 0.25, L = 10 | 216,014 | 99.71% | **629 — 0.29%** | **refused** |

**Read the last row as the case for Phase 3.** Three tenths of one percent of the operating points
make every metric's gradient undefined, because refusal is metric-level and total. It also bounds
§6.2 from the other side: the cost of answering the pinned branch is that fraction times one analytic
bound row with no re-solve, so the rise §6.2 warns of is real in sign and very small in size.

**And it is not recoverable any other way.** The refusal message names the *first* non-interior point
and nothing about how many followed it, so before this counter there was no route to the share at all.

**§4's clamp incidence, for the one site instrumented — the light floor, which is defect #4's own
site.** Swept against `k_I`, holding everything else:

| `k_I` | 0.5 (shipped) | 5 | 20 | 40 | 80 |
|---|---|---|---|---|---|
| light floor fires | **0%** | 0% | 0% | **7.5%** | 11.5% |

That reproduces §7's "binds at `k_I ≈ 40`, 80× shipped" from an instrument rather than from a probe,
and both halves are asserted: a counter that never fires and one that always fires are equally
uninformative.

**What is left in Phase 2, and why it was not taken here.**

- **Item 5 (#1, FD arm branch-crossing)** and **item 6 (#2, the amplification ceiling)** both *add
  refusals*, so they narrow the answered set. **Both have LANDED, and neither narrowed anything**:
  the crossing detection refuses no driver that previously answered, and the ceiling is measured to be
  unreachable. That is the before/after incidence the counters were built to make measurable, and the
  answer was "no change" — which is only worth anything because it was measured rather than hoped.
- **Item 6's structural half — LANDED, and its stated obstacle was not real.** See §0's F: the seeds
  are assembled one frame above the recording and immediately before it, so nothing had to move. What
  it needed was a channel from the leaf to that frame.
- **Item 7 is one clamp site of fifteen.** — **LANDED, and the count was wrong in both directions.**
  There are **eleven** on plant's differentiated path, not fifteen; the enum, names and counter moved
  to `plant/inst/include/plant/clamp_sites.h` so the environment can reach them too. Two sites the
  original list did not have (`rooting_depth`, and the *crown* light floor) turned out to be the two
  largest severances in the model. What the list counted that is not here: phylloptim's clamps, which
  distort a supplied row rather than severing an AD one — see §0's G.
- **Item 8 (#8's cause and arm split) — LANDED.** `PinnedDry` is now `PinnedDryRootCrit` and
  `PinnedDryRootPsiCrit`, decided by a `DryBoundArm` recorded **where the `min` is taken**, because a
  `min` is the one operation that destroys what the consumer needs afterwards. The inverted-interval
  exit is now `InfeasibleBracket` rather than `HydraulicShutdown`: that is reporting the branch taken,
  which is free at the point of decision and unrecoverable after it — whether it is a dry soil or a
  parameterisation the model cannot represent is now a question the counter can answer instead of one
  the tag has to assume. The arm is reset beside the classification at the top of
  `prepare_collar_solve`, because it is written *later* than the kind is and would otherwise leave the
  previous plant's arm beside this plant's kind.

  *Measured, and it settles which bound row Phase 3 actually needs:* on the refusing run **all 629 dry
  pins are `pinned-dry-root-crit` and none is on the constant arm**. That confirms §7's "#9 — the
  arms" on a larger sample and with an independent instrument, and it means `bound_row(DryRootCrit)`
  is the one that matters while `DryRootPsiCrit`'s trivial `−1` row is **unreachable at shipped
  defaults** — so §5's demand for a deliberately-lowered fixture is not optional, it is the only way
  that arm is ever exercised. The 576-point golden grid agrees: zero on that arm at both
  temperatures, and bit-identical through the split.

#### Phase 2, as originally specified

5. **#1 detection:** compare `operating_point_kind()` and the returned collar across each FD arm; on a
   change, `refused(branch_crossed, …)`.
6. **#2:** the amplification ceiling on `|s|/|Π_pp|` — refuse the uptake rows, **emit the profit row
   regardless**, it is valid at a fold.
7. **#4:** an incidence counter at each of the fifteen clamp sites.
8. **#8, second half:** widen `OperatingPointKind` so X splits by cause and K splits by arm.

> **GATE.** Do not start Phase 3 until the Phase-2 counters have run on a production trajectory. They
> produce the three numbers §6 lists as unknown, and two Phase-3 decisions depend on them.

### Phase 3 — answer the pinned branch

9. **`profit_at_fixed_collar`** (§4.1). **This is item zero of Phase 3 and nothing else in it is safe
   first.** — **LANDED**, and it closed #1 with it.

   `Leaf::profit_at_fixed_collar(collar)` returns `{profit, uptake, feasible}` with no clamp and no
   projection, and **does not evaluate** an infeasible collar. `seat_at` in `record_leaf_outputs` now
   goes through it, so **the feasibility flag is the detection** — which is a better instrument than
   Phase 2 item 5's proposed comparison of `operating_point_kind()` across arms, because it is the
   condition itself rather than a proxy for it.

   *Measured, and it reproduces §7's figure to four significant figures.* At ψ_soil 5.0 the collar is
   held 2.6e-07 off the wet bound while a 1e-3 step in `root_b` moves that bound by 2.3e-06 — so one
   arm crosses. The clamped route silently reseats and returns `dprofit/droot_b` = **184.699**, against
   **0.00564** for the same difference well inside the interval. Both finite; a factor of 33,000 apart.

   *Incidence of the change:* no new refusals on either run that previously answered. The refusing
   drought run now stops at the crossing (node 78) rather than at the interior gate (node 79).
10. **Euler-derived accessors** (§4.2), checked by the identity in §5. — **LANDED.**
    `Leaf::stem_curve_integral_dstem_b(psi)` returns `(G − ψG′)/b` with **no spline rebuild**, and is
    bound to R alongside `stem_curve_integral` and `_deriv` so the homogeneity it rests on can be
    refereed from outside C++. `phylloptim/tests/testthat/test-stem-curve.R` (92 assertions) carries
    three checks at scales 0.75, 1.0 and 1.4: a scaled spline reproduces a **rebuilt** one to 4.4e-16
    in value, the Euler identity holds to **1.9e-16**, and the row agrees with a **rebuilt central
    difference** to **6.7e-09**. `stem_c` is untouched and keeps rebuild-and-difference.
11. **`bound_row(Wet)`**, then **`bound_row(DryRootCrit)`** (§4.3). — **LANDED, and consumed by §0's
    B and D.** All three arms are built: `Leaf::bound_row(WhichBound)` returns the row, the residual
    slope and where it was taken. `dR/dstem_b` comes from item 10's identity rather than a rebuild.

    **No `d_dstem_c` field, deliberately.** `stem_c` reshapes the curve rather than scaling it, so it
    has no identity and its row needs the grid rebuilt; a field for it here would invite reading a
    number nothing filled. A consumer takes it from the rebuild path that already exists.

    *Refereed against a central difference of `find_root_psi`, which shares no code with the rows:*
    worst **3.6e-07** on a mild soil gradient and **4.4e-05** on a strong one, for both the wet and the
    dry arm. The `DryRootPsiCrit` arm is exact by inspection — `−1` in its own direction, zero
    everywhere else.

    ⚠️ **A uniform soil profile cannot referee the wet bound**, and this is a property of that bound
    rather than of the fixture. It is where the per-layer fluxes *sum to zero*, which on a uniform
    profile lands on top of every layer's own potential — exactly where each layer's span `|x − ψ_j|`
    has its kink. The central difference straddles the kink while the row takes the side the model is
    on, and they disagree by **5.5e-02** with neither being wrong. The dry bound is unaffected, which
    is what identifies the cause. `test-bound-row.R` asserts the degeneracy rather than avoiding it.

    **Consumed since.** §0's B takes the soil and layer-carbon entries at a pin; §0's D takes the wet
    arm's for a shaded leaf. The `root_c` gap this item left open never had to be filled: B's arms
    follow the bound rather than reading it, so no `d_droot_c` field was needed.
12. **The `proportion_of_conductivity_kernel` overload** (§4.4), closing the zero-flux pieces. —
    **LANDED.** The kernel took only `psi` as its scalar argument and read `stem_b`/`stem_c` off the
    object, so forward mode reached `d/dpsi` and nothing else. The overload takes them as arguments,
    and `Leaf::hydraulic_cost_row(psi_stem)` returns
    `dC/d(psi_stem, stem_b, stem_c, beta2, cost_scale)`.

    A zero-flux point pays only respiration and this cost — `profit = −R_d − C(psi_crit)`, reading
    neither soil nor light — so **these five numbers are the whole of its trait row** and every
    environment row there is exactly zero.

    *Refereed against a rebuilt difference of the curve in every direction: worst **9.6e-10**.*
    `d(cost)/d(stem_c)` **changes sign** across the curve's inflexion (−0.556 at ψ 3, +0.720 at ψ 5),
    which the test pins — a row taking its sign from the value rather than the derivative would not.
13. **The branch-dependent graft mask** (§4.5), then `Determined`. — **LANDED as part of §0's B**,
    which is where the measurements are. `Determined` remains unreached: it has zero incidence on the
    576-point golden grid and none has been seen on any driver. Three parts, as they were planned:

    a. ~~**`profit_env_derivatives` must stop returning `usable = false` at a pin**~~ — **DONE.** It
       supplies `∂Π/∂u + ν·∂B/∂u` for the soil rows, selecting the arm from the classification, and
       reports `pinned` so a caller cannot read a bound-following row as an envelope row. The light
       row gains nothing: neither bound reads radiation, so `∂B/∂light` is exactly zero.

       ⚠️ **And the price it used was wrong**, which §0's B found and defect #14 records: it was the
       interior price, which carries the very condition a pin violates. Everything after the
       environment rows was then the interior derivation, and the substitution planned here —
       `dcollar_d<family> = −dR_d<family>/curvature` at **ten sites** becoming the
       matching `bound_row` entry, `dcollar_dlight` becoming exactly zero, and the profit rows for the
       families other than soil need their own `ν·∂B/∂u` term. That is the remaining work, and it
       changes production numbers, so it wants the before/after incidence and a reference at a pinned
       state — neither of which exists yet.
    b. **The multiplier is already computed and thrown away.** `marginal` at `tf24_strategy.h:1013`,
       discarded at 1338. `w = λ_Π·marginal + s` is what the pinned branch needs it for.
    c. **`lt_zero_at_interior` becomes a function of the classification** (§4.5's table). `psi_crit` and
       `root_psi_crit` are slack at an interior point and **live at a pin** — that is the whole reason
       their zero is declared `zero-slack` rather than structural, and answering a pin without lifting
       the mask returns two zeros that are no longer correct.

    **Measure the incidence before and after.** The counters exist; a refusing drought run is
    99.71% interior and 0.29% pinned-dry-root-crit, so this should convert a total refusal into an
    answer while leaving every run that already answered bit-identical. If a previously-answering run
    moves, the mask is wrong rather than the rows.
14. **The parity test** (§5) as the acceptance gate. *For every state the forward model returns a
    number for, the reverse returns a row or names a violated constraint.* Not before 13 — until the
    pinned rows are consumed the test measures the gap rather than gating it.

### Do not

- **Do not delete the interior gate** at `gradient.hpp:1162` yet. §4.1 has landed, so the FD probes no
  longer depend on it — a crossing arm now refuses on its own. But the gate is still what keeps the
  interior formula off a pinned point, and until item 13 supplies the pinned rows, deleting it would
  answer a pin with the wrong theory rather than refusing it.
- ~~**Do not answer `HydraulicShutdown` before #8's cause split.**~~ **Discharged:** the inverted
  interval is now `InfeasibleBracket`, so what remains under `HydraulicShutdown` is the three exits
  that are one ecological statement. The counter reports them apart, so whether the split matters in
  production is now measurable rather than assumed — and it has zero incidence on every driver run
  so far.
- **Do not mollify the feasibility branches.** They are model, not artefact *(corpus: report 06 §7 —
  a pinned plant is drought; report 05 §5.3 — mollifying establishment would be actively harmful)*.
- **Do not keep `SolverRefused` or `NonFiniteGradient` answerable.** No plant is described.

---

## 4. Specifications

### 4.1 `profit_at_fixed_collar` — required before any pinned work

Each FD arm in `record_leaf_outputs:1236–1258` reads back three quantities after `seat_at`:

```cpp
seat_at(radiation_value, psi_value, kmax_value);
  p_up    = leaf.profit_;                            // frozen-collar PROFIT partial
  m_up    = leaf.dprofit_droot_collar_psi(collar);   // ARGMAX channel
  u_up[i] = leaf.soil_consumption_[i];               // frozen-collar UPTAKE partial
```

`seat_at` calls `evaluate_root_collar_psi`, which re-runs `prepare_collar_solve` at the perturbed state
and clamps: `opt_root_psi = min(max(target, bound_a), bound_b)` (`leaf_model.hpp:2279`). The bound rows
of §4.3 replace only the **middle** read. The other two still clamp — and at a pin the collar *is* the
bound, so the clamp fires on essentially every arm.

Split the two consumers:

```cpp
// Unchanged. Re-runs feasibility and CLAMPS. For the acclimating variant's own centred difference.
double evaluate_root_collar_psi(double target);

// New. Caller has established feasibility and wants a partial at a FROZEN collar.
// No clamp, no projection.
struct FixedCollarEval { double profit; std::vector<double> uptake; bool feasible; };
FixedCollarEval profit_at_fixed_collar(double collar) const;
```

`feasible = false` when the held collar lies outside the perturbed `[bound_a, bound_b]`. **Do not
evaluate anyway** — below the wet bound the profit algebra runs on a negative conductance and returns a
plausible number. The caller refuses the row when either arm reports infeasible.

### 4.2 The stem curve: one identity, two accessors

`eval_stem_curve` returns `scale · Ĝ(u/scale)` with `scale = stem_b / stem_b_spline_`. So with `s` the
scale and `Ĝ` the base spline:

```
G(ψ; b) = s·Ĝ(ψ/s)          homogeneous of degree 1 in (ψ, b)
```

Two exact consequences:

```
∂G/∂ψ = Ĝ'(ψ/s)            == stem_curve_integral_deriv(ψ)          [leaf_model.hpp:598]
∂G/∂b = (G(ψ) − ψ·G'(ψ))/b  Euler — needs NO spline rebuild
```

`stem_curve_integral_deriv` returns `Ĝ'(ψ/s)` with no visible `1/s`. That is correct: differentiating
`s·Ĝ(ψ/s)` gives `s·Ĝ'·(1/s)`. **`stem_c` has no such identity** — the header refuses it at
`perturb_stem_b` — so `stem_c` keeps the rebuild-and-difference treatment, which is also what report 05
§7.6 requires.

### 4.3 The bound rows

Both bounds are roots of residuals the leaf already evaluates:

```
bound_a = root_zero_E : root of  E_column_zero(x, ψ)                  [leaf_model.hpp:922]
root_crit             : root of  E_column(x, ψ, psi_crit)             [leaf_model.hpp:921]
                                 = E_up(x,ψ) − κ·[G(psi_crit) − G(x)]
```

`∂bound/∂u = −(∂R/∂u)/(∂R/∂x)`. For `root_crit`:

| term | expression | source |
|---|---|---|
| `∂R/∂x` | `∂E_up/∂x + κ·G'(x)` | `dE_from_soil_dpsi_collar:872` + §4.2 |
| `∂R/∂ψ_j` | `∂E_up/∂ψ_j` | `dE_from_soil_dpsi_soil:901` |
| `∂R/∂rc_k` | `Σ_i ∂E_i/∂rc_k` | `duptake_droot_carbon`, `roots.hpp:756` |
| `∂R/∂κ` | `−[G(psi_crit) − G(x)]` | `stem_curve_integral` |
| `∂R/∂psi_crit` | `−κ·G'(psi_crit)` | §4.2 |
| `∂R/∂stem_b` | `−κ·[∂G/∂b(psi_crit) − ∂G/∂b(x)]` | Euler |
| `∂R/∂stem_c` | differenced with rebuild | no identity |

`bound_a` is the same on `R₀(x) = E_up(x,ψ)`, with `∂R₀/∂x = ∂E_up/∂x` and **no stem terms at all.**

```cpp
struct BoundRow {                      // leaf's declared input order, name-driven
  double d_dpsi_soil[L], d_droot_carbon[L];
  double d_dkappa, d_dpsi_crit, d_dstem_b, d_dstem_c;
  double residual_slope;               // ∂R/∂x — the IFT denominator AND the guard
  bool   finite;
};
BoundRow bound_row(WhichBound) const;  // Wet | DryRootCrit | DryRootPsiCrit
```

`DryRootPsiCrit` is zeros except its own parameter `= −1` and `residual_slope = 1`.

**`∂R/∂x = ∂E_up/∂x + κ·G'(x)` is a sum of two strictly positive terms**, so the denominator cannot
change sign. It can approach zero in deep drought, so guard on the amplification, not the sign — the
same ruling as #2, one level down. `residual_slope` is returned so the consumer can do this without
recomputing.

**Convention, enforced on the producing side.** Name-driven from the leaf's own input list, with a hard
stop on a name that cannot be mapped — never positional. Units are the leaf's: ψ in positive MPa, uptake
in mol, flux derivatives in kg, so the caller applies the existing `to_mol_flux` exactly where it does
today. Intensive, per unit leaf area; the leaf cannot check this, so assert it caller-side.

### 4.4 The seven pieces

| piece | operating point defined by | rows |
|---|---|---|
| Interior | `∂Π/∂p = 0` | envelope + IFT — **already built** |
| PinnedWet | `p = bound_a` | `∂bound_a/∂u` |
| `PinnedDryRootPsiCrit` | `p = root_psi_crit` | exactly `(0,…,0,−1)` — **unreachable at shipped defaults** |
| `PinnedDryRootCrit` | `p = root_crit` | `∂root_crit/∂u` — **every dry pin measured is this one** |
| Determined | `p = ½(bound_a + bound_b)` | ½ of both, then `find_psi_stem_from_psi_root` (§4.6) |
| HydraulicShutdown | stem held at `psi_crit`, every layer zeroed | env and uptake rows **exactly zero** — **ANSWERED** |
| ShadeDeath | gross assimilation below `R_d` at `ci = ca` | env rows **through the wet bound**, uptake non-zero — **ANSWERED** |
| *(Prescribed — TF24f)* | an ODE state | free from the adjoint |
| SolverRefused, NonFiniteGradient | no plant described | **refuse** |

Pinned rows: `w = λ_Π·marginal + s`, `ū = v̄ᵀ∂f/∂u + w·∂B/∂u`. The multiplier `marginal` is already
computed at `tf24_strategy.h:1013` and discarded at 1338.

**⚠️ ZERO FLUX IS NOT ZERO ROWS — for ONE of the two.** This table said it was for both, and that is
right for `HydraulicShutdown`: `set_shutdown_state` holds the stem at `psi_crit` whatever collar it is
handed, and fills `soil_consumption_` with zeros. It is wrong for `ShadeDeath`, which seats **both**
potentials at `root_zero_E` — the collar at which uptake is zero, which **is the wet bound** — and
sets `profit = −R_d − C(root_zero_E)`. So that profit reads the soil, through the bound, and the rows
are

```
dProfit/du = −C'(B_wet) · dB_wet/du          for every u the wet bound reads
dProfit/d(light) = 0                          the wet bound does not read radiation
dProfit/d(R_d_25) = −dR_d/dR_d_25
```

with `C'` and the four cost-trait rows from `hydraulic_cost_row(B_wet)` and `dB_wet/du` from
`bound_row(Wet)` — **both already built and refereed**. `psi_crit` and `root_psi_crit` are the ones
that ARE exactly zero here, because the wet bound does not read them.

**The uptake rows are not zero either.** `E_up` is zero at that collar; the per-layer consumptions are
not — they sum to zero, so some layers take up while others release — and each carries
`∂E_i/∂u|_B + (∂E_i/∂p)·∂B_wet/∂u`.

`∂C/∂psi_crit` needs no derivation — `hydraulic_cost_TF_kernel` is
scalar-templated (`leaf_model.hpp:1039`) and the file already does this at four sites:

```cpp
AD ps_ad = psi_crit;  xad::derivative(ps_ad) = 1.0;
const double C_prime = xad::derivative(hydraulic_cost_TF_kernel(ps_ad));
```

For `stem_b`/`stem_c` through `C`, add the overload the file's own precedent uses
(`assim_colimited_kernel(T ci, T vcmax, …)`):

```cpp
template <typename T> T proportion_of_conductivity_kernel(T psi, T b, T c) const;
```

### 4.5 The graft mask is branch-dependent

`lt_zero_at_interior` (`tf24_strategy.h:1208`) becomes a function of the classification:

| piece | `psi_crit` | `root_psi_crit` | env rows | uptake rows |
|---|---|---|---|---|
| Interior | 0 (slack) | 0 (slack) | envelope | IFT on `∂Π/∂p` |
| PinnedWet | 0 | 0 (slack) | `∂Π/∂u + ν·∂B/∂u` | `∂E/∂u\|_p + (∂E/∂p)·∂B/∂u` |
| `PinnedDryRootCrit` | **live** `−κG'(psi_crit)/R_x` | 0 | as above | as above |
| `PinnedDryRootPsiCrit` | 0 | **live** `−1` | as above | as above |
| Determined | live via both | live via `bound_b` | via `∂p/∂u` | via `∂p/∂u` |
| Shutdown / ShadeDeath | **live** `−C'(psi_crit)` | 0 | **exactly 0** | **exactly 0** |

### 4.6 `find_psi_stem_from_psi_root`, needed by `Determined`

`ψ_stem = G⁻¹(w)`, `w = E_up(p,ψ)/κ + G(p)`:

```
∂ψ_stem/∂• = stem_curve_integral_inverse_deriv(w) · ∂w/∂•
∂w/∂p = (1/κ)·∂E_up/∂p + G'(p)      ∂w/∂ψ_j = (1/κ)·∂E_up/∂ψ_j
∂w/∂κ = −E_up/κ²                     ∂w/∂b   = ∂G/∂b(p)
```

This chain is already assembled inline at `leaf_model.hpp:2405–2406`. Lift it to an accessor.

---

## 5. Verification

**Four rungs, ordered by what each can fail without a reference gradient.**

1. **Euler.** `ψ·G'(ψ) + b·∂G/∂b = G(ψ)` to round-off, everywhere on the spline's domain. An identity —
   fails only if the scaling convention is misread, which is the plausible mistake.
2. **Transpose identity.** `⟨v, Ju⟩ = ⟨Jᵀv, u⟩` over the bound rows for random `v, u`. No reference, no
   differencing. It already holds to `1.4e-14` over 294 operating points for the existing node.
3. **IFT vs rebuilt difference.** Per input family, against a central difference of `find_root_psi` with
   the strategy rebuilt at `fit_step = 1e-3`. The only check that can referee `stem_c`.
4. **Parity — the acceptance gate.** *For every state the forward model returns a number for, the
   reverse returns a row or names a violated constraint.* Sweep a driver across the regimes; require
   `stand_gradient` to answer wherever `run_scm` answered.

**What is refereed now, and against what.** Each row added in this work has a check whose reference is
a difference of the relation that *defines* it — report 08 §5A's locality axis:

| row | referee | worst |
|---|---|---|
| the bound row's soil half | a differenced `find_root_psi` | 3.6e-07 mild, 4.4e-05 strong |
| its `kappa`, `psi_crit`, `stem_b` half | a rebuilt difference of the bound | 1e-4 |
| its `root_b` entry | a rebuilt difference, both bounds | 1.69e-05 |
| **its root-carbon half** | a **rebuilt network** and a re-solved bound | 3.0e-06 wet, 5.5e-04 dry |
| **that a bound row moves no output** | `E_up_`, uptake, collar, `psi_stem`, profit, kind | **bit-identical** |
| the hydraulic cost row | a rebuilt difference of the curve | 9.6e-10 |
| the stem curve's `stem_b` row | Euler, then a rebuilt difference at three scales | 6.7e-09 |
| **the root curve's `root_b` row** | Euler (**0.00e+00**), then a rebuilt difference | 2.8e-06 |
| **the pinned profit environment rows** | a **re-solved** profit difference | 4.8e-08 wet, 3.1e-04 dry |
| **the light floor's declared zero** | a **whole-run rebuild difference** at `k_I` 40 (report 08 §5) | 1e-06 on `a_l1` and `lma`, 0.3% on `k_I` |
| **the profit curvature's own range** | 5625 solved leaf states, the interval swept at 240 points | min \|Π_pp\| 0.0623 interior, 0 in the interval at `stem_c` 0.4 |

**One residual is open and is recorded rather than absorbed.** The dry pin's environment rows sit at
**2e-04 to 3e-04** where the wet pin sits at 4.8e-08. `λ`, `f`, `ν`, `S` and `∂E_up/∂ψ_j` were each
refereed separately and are good to **2e-05 or better**, so it is in the composition rather than in a
factor. The measurable symptom: at the dry bound `psi_stem` **overshoots `psi_crit` by 3e-04 to
7e-04**, where the bound is *defined* as the collar at which the two are equal.

**Fault injections, each of which must be caught:**

| injection | expected | run? |
|---|---|---|
| drop `κ·G'(x)` from `∂R/∂x` | rung 3 fails, rung 1 passes | not yet |
| swap the two dry arms | rung 3 fails on the constant arm | not yet |
| omit the `1/b` in Euler | rung 1 fails immediately | **run — rung 1 goes to 1.8–4.2 relative** |
| return `Ĝ'(ψ/s)·(1/s)` for `∂G/∂ψ` | ~~rung 1 fails~~ **rung 1 is exactly blind; rung 3 catches it at 40–47×, and only at a non-unit scale** | **run** |

**The last row was wrong in the specification, in two ways, and both matter.**

*Rung 1 cannot see it.* `∂G/∂b` is built from `G'`, so an error in `G'` cancels out of
`ψG' + b·(G − ψG')/b = G`. Injected, rung 1 reads **exactly 0.00e+00** while rung 3 reads **47×**.
An identity assembled from the quantity it is meant to check is not a check on it.

*And it is unreachable on a fresh leaf.* `stem_b == stem_b_spline_` on any newly built leaf, so the
scale is exactly 1.0 and dividing by it is the identity — the misreading is **invisible** until
something has moved `stem_b` without rebuilding. Injected, the same fault reads 3.4e-09 (clean) at
scale 1.000 and 47× at scale 0.750. **Every fixture testing the stem curve must perturb `stem_b`
first**, and `phylloptim/tests/testthat/test-stem-curve.R` does.

**Non-vacuity.** A fixture must be asserted to pin, and to pin on the arm under test. `root_crit` binds
100% of production states, so the default fixture tests only that arm — **a second fixture with
`root_psi_crit` deliberately lowered is required** to exercise the constant arm at all.

---

## 6. Unknown — measure, do not assume

Four numbers gate decisions and none is derivable.

1. ~~**The amplification ceiling's value** (#2).~~ **MEASURED, and the question was the wrong one.**
   The advice here — sweep `p` across the interval rather than sampling solved points — was right and
   was followed, over 5625 solved states and 240 interval points each. It found folds in the interval
   (40% of it at `stem_c` 0.4) and **not one solved operating point on a fold**: where the interval
   folds, the solve pins, and a pin computes no curvature. So the ceiling is set from the interior
   range's own floor — min `|Π_pp|` **0.0623**, ceiling **1e-3** — and the number that matters is not
   the ceiling but the **margin**, now reported per run. See §0's F.
2. **Cost after Phase 3.** It will **rise**, not fall: pinned points are not differenced today, they
   throw, so answering them adds work. Bounded by (pinned fraction) × (one analytic bound row, no
   re-solve) against a 14.6× baseline. This is a kill condition for the phase. **The pinned fraction
   is now measured at 0.29% on a refusing run**, so the bound is small — but the *ceiling* still has
   to be checked against a run, because that fraction is one driver's.
3. ~~**Clamp and classification incidence.**~~ **Measured — see Phase 2 above.** **#4's refusal now
   goes with its counting**, on the differentiated path alone: a compile-time choice, because which
   path this is is a property of the scalar rather than of the state. The forward model is untouched —
   at `k_I` = 40 the census is still 0.2206 while the gradient refuses.

   ⚠️ **That reading was taken with the only instrument that could not see the answer.** The paragraph
   this replaces said the light floor's refusal was "implemented and unexercised" and that a gate
   refused first and won the race. Both halves came from a counter that measures the forward run: on the
   differentiated path the *crown* floor was firing about a million times per shaded driver, uncounted
   and unrefused, while the instrumented site downstream saw a remnant. Eleven sites now carry counters
   on **both** paths, kept apart, and the classification is in
   `test-gradient-incidence.R`. Classification of the operating points is unchanged and still worth
   keeping: a run that used to refuse is **99.71% interior and 0.29% pinned-dry**, and that 0.29% cost
   the whole gradient before §0's B.
4. **What `collar_interval_min_width` should be.** Phase 0 split the name; the value is still the
   `1e-1` `plant::Control` delivers. Below that width `prepare_collar_solve` stops optimising and
   substitutes the interval's midpoint, which is what decides whether a state is reported as
   `Determined` rather than optimised — a classification decision taken on a width, which is the same
   hazard as classifying on a residual, one level out.

   **`Determined` has zero incidence on `phylloptim`'s 576-point golden grid**, at either leaf
   temperature: 198 interior / 42 pinned (24 wet, 18 dry) / 48 shutdown at 25 °C, and 160 / 80 (all
   wet) / 48 at 40 °C. So that grid cannot referee this threshold at all, and warming moves points
   between branches without ever producing one. A production trajectory is the only instrument.

   **Measured, at the leaf's default traits over a uniform soil profile:** the feasible interval's
   width falls monotonically as the soil dries — 3.30 at 0.01 MPa, 2.58 at 1, 1.26 at 3, 0.261 at 5 —
   crosses **1e-1 at ψ_soil = 5.50**, and is still **3.1e-3 at 5.84**, against the plant's own limit
   of 5.870. So the two candidate values disagree over roughly **the last 0.37 MPa before hydraulic
   shutdown**, 18 of 43 states sampled in that band. That is precisely the regime Phase 3 exists to
   open, so **do not set this before Phase 2's counters run**: tightening it moves states out of
   `Determined` and into the optimised branch, which changes results and needs a
   `scientific_version` bump and a re-bless.

---

## 7. Evidence

Compressed to what justifies a decision. Each is reproducible by §8.

**#1 — the FD probe.** Perturbing `root_b` by 1e-3 and holding the collar, exactly as the sweep does:
`dprofit/droot_b` reads **184.7** at ψ_soil 3.96 against 0.003 at both neighbours, and
`184.7 × 2h = 1.440` — exactly the feasibility discontinuity `leaf_model.hpp:2162` documents. At a pin
the collar is `bound_a + 1e-6·width` while a 1e-3 trait step moves the bound by 1.3e-4: a ratio of
**159–197**, so clamping is structural, not incidental.

**#2 — the fold.** Sweeping `p` across the whole interval at 240 points: `Π_pp` strictly negative at
every soil potential 0.5–5.5 with min abs 0.67, and strictly negative across `beta2` 0.2–6 and `stem_b`
3.9–10. At **`stem_c` = 0.6**, 8.7% of the interval has `Π_pp ≥ 0` and min abs = 0. `stem_c ≥ 5` and
`stem_b ≤ 2` fail the solve outright.

**#3 — the tangent.** `pr_estab == 0` ⟺ boundary `log_density = −Inf` ⟺ **50.2% of the forward RHS
Jacobian non-finite**, 6 configurations of 6, no exceptions. Every rate reading the light field is
non-finite; every rate not reading it is clean. Blocks, field values, field slopes and the reduction
adjoint are all finite. Not light: `k_I = 1.5` gives minimum light **0.054**, three times darker than a
failing case, with zero non-finite entries.

**#4 — the floor.** Binds at `k_I ≈ 40`; the field then stores 1.1e-17 and, denser, **5.1e-117**, while
the read clamps at 1e-4. **And it is two reads, not one** — see §0's E for the 150× the crown site
binds by, and for the reason the instrumented one under-reported.

**#2 — the fold, re-measured, and the reading has inverted.** §7's own sweep of the *interval* is
reproduced exactly (min \|Π_pp\| 0.672 at shipped `stem_c`, 11.2% non-concave at `stem_c` 0.6 against
the 8.7% recorded). What it did not ask is where the *operating point* sits. Over 5625 solved states,
all 1351 interior ones are strictly concave with min \|Π_pp\| **0.0623**, and at `stem_c` 0.4 — where
40% of the interval has `Π_pp ≥ 0` — the point is still concave at −0.33. **Where the interval folds,
the solve pins**, and a pin computes no curvature at all. So the ceiling is real, correct, and
unreachable, which is a guard-census entry rather than a coverage loss.

**#5 — the zeros.** Three per species. `a_f3` occurs only in `fecundity_dt`'s denominator and no census
metric reads fecundity; `psi_crit`/`root_psi_crit` are complementary slackness;
`rooting_depth_max` is zero at 0.30 m (saturated) and 10 m (non-binding), live between.

**#7 — the ghost.** A duplicated schedule time adds a node whose census, offspring, all 65 field knots
and soil state are **bit-identical** to the clean run, where a genuinely distinct extra node moves them
by ~3e-07.

**#9 — the arms.** `root_crit` binds **100% of 297 recorded states** across three drivers spanning
ψ_soil 0.01–4.23 MPa. `root_psi_crit` never binds at shipped defaults.

**#12 — the scaling.** Reverse RHS at 1/2/3 species: 0.0130 / 0.0232 / 0.0352 s — sub-linear.
`boundary_condition_adjoint` is 25–32% of it at every species count.

**Regime boundary — and this reading is now historical.** It recorded that the gradient refused from
ψ_soil ≈ 4 MPa under constant forcing, and that a seasonal driver at amplitude 1.0 refused while
finishing *saturated* at 0.17 MPa, because the pin happened in a trough the run recovered from. Both
now answer, and the seasonal driver is in the parity gate for exactly the reason this paragraph gives.

**What survives it is the general statement, and it is why the parity gate exists at all: nothing
about a completed run predicts whether its gradient exists.** A terminal state says nothing about the
branches a trajectory passed through, so coverage has to be swept rather than inferred.

---

## 8. Reproducing the measurements

```r
library(odelia); pkgload::load_all("plant")     # never the installed package

p <- scm_base_parameters("TF24"); p$max_patch_lifetime <- 10
tr <- c(lma=0.0825, hmat=5.13, k_I=0.5, a_l1=5.44, a_l2=0.306)
p <- add_strategies(p, trait_matrix(unname(tr), names(tr)),
                    hyperpar = TF24_hyperpar, birth_rate = list(1.10))
env <- Environment("TF24"); env$set_soil_water_state(rep(0.428*0.5, 5))
env$extrinsic_drivers_set_constant("rainfall", 0.25)      # refuses at L=10
scm <- run_scm(p, env, ctrl = Control(node_density_in_birth_date = TRUE))
stand_gradient(scm)
```

- **Soil potential from moisture:** `psi = 1.78e3 * (max(theta,1e-2)/0.428)^(-6.57) / 1e6`. The header
  comments these constants "not currently being used"; they are — `psi_from_soil_moist` and its inverse
  both read them. Ceiling `soil_psi_max_ = 1e3` MPa binds nowhere in range.
- **Leaf-level probes:** `leaf_model(traits=)`, `set_drivers`, `find_root_psi(wettest, psi, 0|1)`,
  `evaluate_root_collar_psi`, `dprofit_droot_collar_psi`. Trait fields are `stem_b`/`stem_c`, **not**
  `b`/`c` — R's partial matching silently resolves `tr$b` to `beta2`.
- **Ladder instruments:** `ladder_rhs_state_jacobian_forward_tf24`,
  `ladder_block_jacobian_forward_tf24`, `ladder_field_knots_tf24`,
  `ladder_light_reduction_adjoint_tf24`, `ladder_trajectory_tangent_tf24` (returns
  `list(value, tangent)`), `ladder_rhs_adjoint_timing_tf24` (per-phase breakdown).
- **Patch state layout:** 8 rows per node — `height, mortality, fecundity, area_hw, mass_hw, storage,
  offspring, log_density` — then 9 environment rows: 5 soil layers, then cumulative rain, infiltration,
  drainage, uptake.
- **Classification is not exposed to R.** Read it from the refusal message, which names the kind. That
  is why Phase 2's counters are the only route to incidence.

### The two instruments this work is accepted with

**A hex fingerprint, for bit-identity.** Print the census and a reduction of the gradient with `%a`, on
each driver, and diff it against the same script run on a build without the change. `%a` round-trips a
double, so a diff is a bit-difference and not a formatting one.

```r
v <- unlist(g$gradient); v <- v[is.finite(v)]
cat(sprintf("%a %a %a %a\n", sum(v), sum(abs(v)), v[1], v[length(v)]))
```

**A parity sweep, for coverage.** `plant/tests/testthat/test-gradient-parity.R` carries five drivers as
a standing check; the full seventeen-driver sweep is the same `parity_case` shape over rainfall 2.00 to
0.05, `L` 5/10/20, `k_I` 5/20/40 and a seasonal driver. Each case is ~40 s, so the whole sweep is
about twelve minutes — run it in the background, not in a tool call with a ten-minute ceiling.

**⚠️ Read the counters correctly.** `census_operating_point_counts_tf24` accumulates over whatever has
run since the last clear. Read it **after `scm$run()` and before `stand_gradient`** for the forward
tally, or after both for forward-plus-sweep — and say which. Two figures in this document differ only
because of that.

**The clamp counters do not have that hazard and the reason is worth copying.** `clamp_counts_tf24` is
the forward lane and `clamp_counts_differentiated_tf24` the sweep's, and they are separate storage
rather than one tally read at two times — so neither can be mistaken for the other and the sweep's is
readable only after `stand_gradient`. **The differentiated lane is the one that matters**: a clamp
severs a row on that path and nowhere else, and the two lanes differ by about 15% because the sweep
visits the recorded steps rather than every solve.

**A third instrument, and it answers a question a count cannot.** `census_curvature_margin_tf24` gives
the smallest profit curvature the sweep met, or −1 if it never reached the interior branch. A count says
whether a guard fired; this says how close it came, which is the only way to tell a guard that held from
a guard nothing approached. Set `Control$gradient_curvature_floor` above it to make the guard fire on
demand — that is how F1's separation is tested at all, and there is no fixture that reaches it
otherwise.

### The build and test loop, as it actually behaves here

- **Rebuild at `-O2` explicitly.** `pkgbuild::compile_dll()` appends `-O0` after any user flags.
  `R_MAKEVARS_USER=<file> Rscript -e 'pkgbuild::compile_dll(".", debug = FALSE)'` with the file holding
  `CXX20FLAGS = -O2 -DNDEBUG -g0`. Confirm one compile line ends at `-O2` with no trailing `-O0`.
- **A `phylloptim` header edit is invisible to `plant` until `phylloptim` is reinstalled.** `plant`
  compiles against the *installed* library's headers via `LinkingTo`, not against the working tree, and
  no `.cpp` timestamp moves — so the build succeeds and runs the old model. `rm -f src/*.o src/*.so` in
  both, reinstall `phylloptim`, then rebuild `plant`. This is defect #13 met in practice.
- **⚠️ Installing `phylloptim` can silently break `plant`, and the error names neither.** Its
  `DESCRIPTION` carries `LinkingTo: odelia` with `Remotes: traitecoevo/odelia`, so
  `install.packages(".")` may replace the locally built fork `odelia` with one fetched from
  **upstream** — and upstream's lacks the `Replayable` concept `plant`'s `store_trajectory`
  static-asserts on. The build then fails with `'Replayable' is not a member of 'odelia::ode'`,
  pointing at `scm.h` in a session that never touched `odelia`. Hit once here, mid-session, after
  several successful builds.

  **The fix, and it is worth running unconditionally after any `phylloptim` install:**
  `R CMD INSTALL --no-multiarch odelia` from the superproject root, which takes the pinned worktree
  and resolves no dependencies. Confirm with
  `grep -c "concept Replayable" $(Rscript -e 'cat(find.package("odelia"))')/include/odelia/ode_interface.hpp`
  — it must be 1.
- **`phylloptim`'s C++ suite needs `make -C tests/cpp CXX=g++`** — the Makefile's default reaches for a
  `clang++-12` that is not installed here.
- **The pre-existing failure baseline, re-measured repeatedly this session and stable throughout.**
  Anything outside these is a signal; anything in them is not.

  | suite | pass | problems |
  |---|---|---|
  | `plant` gradient ladder | **570** | **0** |
  | `plant`, everything else | **3244** | **13**, in six files: `test-leaf.r` (5), `test-mutant.R` (2 errors), `test-stochastic-patch.R` (3 errors), `test-stochastic-patch-runner.R` (1), `test-strategy-tf24.R` (1), `test-strategy-tf24f.R` (1) |
  | `phylloptim` R | **1437** | **3**: `test-gradient.R` (1 fail, 1 error), `test-surface.R` (1 fail) |

  The gradient family gained 75 assertions (495 → 570) and the non-ladder count is **unchanged at
  3244**, because every check added is in that family. The same **13 problems in the same six files**
  remain — the figure to attribute against. `phylloptim` is unchanged **by construction**: nothing in it
  was touched, so its numbers are carried rather than re-measured, and `git status` on it is the
  evidence.

  **Two of this session's own changes broke a non-ladder test each, and both were the same shape.**
  Adding a `Control` field broke `test-control.R`'s default list and `test-census.R`'s
  `gradient_control` names — tests that pin a list, correctly, and have to be extended when the list
  is. Neither was a regression; both are named here because a reader re-measuring the baseline needs to
  know they are expected to be at 3 and 27 rather than 2 and 25.

  **Run the ladder fanned out over disjoint file sets rather than with `Config/testthat/parallel`.** The
  runner dies inside its own queue poll on these files, but the files themselves are independent, so N
  background `Rscript` processes over an `NR%N` split give the same speedup without it — the whole
  ladder in about 35 s of wall against 1130 s of CPU. The fast structural tier
  (`injection|rung3|factorisation|declared-zero`) is a few seconds and belongs in every build.

  `phylloptim`'s C++ `test_leaf` also aborts at HEAD, on a single-potential series resistance of zero —
  which stops `make -C tests/cpp` before `test_golden` runs. **Run `./test_golden --cross-platform`
  directly**: on this platform the file is NOT bit-exact (it was generated on macOS/arm64) and the
  correct reading is the summary line, worst 1.82e-07 profit and 1.4e-04 argmax against tolerances of
  1e-05 and 5e-03.
- **The parallel test runner crashes on the ladder.** Run the files in a loop with
  `TESTTHAT_PARALLEL=false`; `test_dir(filter = "gradient")` dies inside the queue poll and the
  traceback names `cli::cli_abort`, which looks like a test failure and is not.
- **When attributing a failure, stash with `git -C <repo> stash`.** The shell's working directory
  persists between commands, so a bare `cd repo && git stash` followed by another `git stash` stashes
  the *first* repo twice and leaves the second untouched — which produces a "baseline" that still
  carries the change under test, and it agrees with itself perfectly.

---

## 9. Corpus corrections

Carry these forward; they change what a reader would do.

- **Report 09 §10's "first segment is never swept" does not reproduce at `cdf3f0c9`.** Sweep and
  trajectory tangent agree to ≤2.7e-09 with first introductions at 0.0 through 1.0, including 104
  recorded steps below the first event. The structural point survives: nothing asserts the segment
  ranges partition the recording.
- **Report 09 §12's inverted cost premise is stale.** 14.6× flat, not 162×.
- **The parameter count is 47, not the 44 every report states** *(report 09 §12 already flags this)*.
- **The development record's mode-3 discriminator is wrong.** It says "the rates that read `growth`";
  the soil rows are non-finite and read no growth. The discriminator is the light field.
- **`tf24_environment.h:62–63`** annotates `a_psi`/`n_psi` as "not currently being used". They are.
- **Report 08 §8's independence requirement has no instance in TF24's census, and the report is not
  wrong to state it.** *"A metric seeded only on size states survives a fold that kills a
  water-coupled one"* is a correct design requirement and the separation now exists — demonstrated at
  one right-hand-side evaluation. But **all three census metrics read water**: they are size moments,
  growth reads water, and sweeping backwards gives every one of them a non-zero soil adjoint within a
  step or two of the census. So the separation saves no metric until a water-independent metric exists.
  The disagreement is between the report's *design* claim and this *census*, not between the report and
  the code — which is why it is recorded here rather than by editing the report.
- **Report 08 §7's guard census needs a fourth class, and the largest clamp in the model is in it.**
  §0's G's table splits the "masks a channel" case: a clamp that **is** a modelling statement
  (`min(height, rooting_depth_max)`) yields a zero that is the model's own and is not a candidate for
  removal, where a numerical floor's zero is. Reading the code does not distinguish them — both are a
  `min` — and filing them together would invite someone to "fix" the model by removing its own
  boundary.
- **`compute_average_light_environment`'s comment says the floor's "original rationale was never
  recorded".** Still true, and now it matters more: this is the site that binds, 150× more often than
  the one the corpus calls the light floor.

---

## 10. What "finish the pinned branch" turned out to require

The substitution is mechanical and the obstacle is not where it looked. Measured at a pinned state
(soil profile 2.6–3.4 MPa scaled to a pin, margin 5.07e-07):

| driven trait | does it move the wet bound? | both FD arms feasible? | has a row now? |
|---|---|---|---|
| `stem_c`, `stem_b`, `psi_crit`, `root_psi_crit` | **no — exactly 0** | yes | n/a |
| `root_b` | −1.6e-05 / +1.6e-05 | **no**, the down arm crosses | **yes — closed form** |
| `root_c` | −5.9e-07 / +5.9e-07 | **no**, the down arm crosses | no — needs a rebuild |

**⚠️ THIS TABLE IS A WET PIN'S, AND §0's B RECORDS WHAT IT MISSES.** At a dry pin — every pin measured
in production — five of the six cross, not two. What follows is still the right reading of the wet
arm and the wrong basis for a plan.

**Ten of the twelve arms are fine. Exactly two cross, and only on one side.** They are the two root
vulnerability parameters, and they cross for the reason the table gives: they are the only driven
traits that enter the wet bound's residual at all, so they are the only ones that move the bound out
from under a held collar.

**So the remaining gap is two traits, not the whole branch** — and it is the same gap twice over:
`BoundRow` has no `d_droot_c` / `d_droot_b` entry, and the frozen-collar partial for those two cannot
be centred because one arm is infeasible.

**Option 3 was taken, and it closed `root_b`.** The root vulnerability curve is built by the **same**
Weibull routine as the stem's, so it has the same homogeneity: `G` is homogeneous of degree one in
`(ψ, root_b)`, and Euler gives `∂G/∂root_b = (G − ψ·G′)/root_b` with **no rebuild**. `root_b` reaches
uptake through exactly one quantity — the layer mean-conductivity integral — so `duptake_droot_b` is
the quotient rule with a single moving part, and it reaches **both** bounds by that route because the
stem half of the dry residual does not read it.

*Refereed against a rebuilt difference at **1.69e-05**, worst over both bounds and two soil profiles.*

⚠️ **The step is the finding, not a detail.** A rebuild in `root_b` moves the curve's own knot grid,
so a differenced row carries a discrete artefact the analytic one cannot. At the wet bound the ratio
reads **1.20 at 1e-8, 0.998 at 1e-6, and 1.0000 across 1e-5 to 1e-3** — my first measurement used 1e-6
and read a 0.17% error that was the referee's, not the row's. This is §4.7's fifth trap, and the only
way to see it is to take the difference at several steps and say which end the plateau is at.

**What is left is `root_c` alone**, and it is the same object as `stem_c`: both are curve *steepness*
parameters, both reshape rather than scale, so neither has an identity and both need the grid rebuilt.
That symmetry is worth keeping — the two curve *positions* now have closed forms and the two
*steepnesses* do not, which is a statement about the Weibull family rather than about this code.

**Decision: difference both steepnesses by rebuild.** Not a shortcut — it is the *correct* treatment,
and the closed form is the one that would be wrong here.

**Why.** Report 05 §7.6's ruling: *differentiate the model being evaluated, not the model it
approximates.* The forward solve reads a **spline**, so the derivative belonging on the tape is the
spline's. Substituting the closed form for the derivative alone gives the more accurate derivative of
a **different function** — a systematic disagreement of parts in a thousand that no invariant can
attribute, because both routes are internally consistent and neither referees the other. A rebuilt
difference of the spline *is* the spline's derivative, so it is faithful by construction.

**And this is why the position rows are not an inconsistency.** `∂G/∂b` for both curves is Euler
applied to `G` and `G′` **as the splines return them**, so it too is the table's derivative rather
than the continuum's. Position is closed-form because the *identity* holds on the tabulated function;
steepness is differenced because no identity does.

**Measured plateau, so the step is chosen rather than inherited** (soil profile 3.12–4.08 MPa):

| | 1e-7 | 1e-6 | 1e-5 | 1e-4 | 1e-3 | 1e-2 |
|---|---|---|---|---|---|---|
| wet, `∂B/∂root_c` | −4.051512e-04 | −4.051512e-04 | −4.051512e-04 | −4.051577e-04 | −4.051512e-04 | −4.051521e-04 |
| dry, `∂B/∂stem_c` | −0.22113536 | −0.22113532 | −0.22113535 | −0.22113535 | −0.22113532 | −0.22113163 |
| dry, `∂B/∂root_c` | −2.404843e-04 | −2.404835e-04 | −2.404834e-04 | −2.404834e-04 | −2.404834e-04 | −2.404828e-04 |

**`∂B/∂stem_c` at the wet bound is exactly 0.0 at every step** — its residual is total uptake and does
not read the stem curve, the same reason `∂B/∂stem_b` is zero there.

**Take 1e-4.** The plateau is broad — unlike `root_b`, where 1e-6 was already off the edge — and the
only degradation is `stem_c` at 1e-2.

**⚠️ Where the code can go, which is not where it looks.** `set_traits` **does not preserve the supply
state**: after it, `find_root_psi` returns the wettest layer rather than the bound (3.12 against
3.4252, measured). So a rebuild-difference **cannot** be taken in place on a seated leaf, and
`bound_row` must not grow one. It has to live where the drivers are re-supplied — plant's driven-trait
loop in `record_leaf_outputs`, which already differences these four traits through `drive()` for the
marginal. Reading the bound in the same arms is a two-line addition **to that loop**, so it lands with
the substitution rather than before it.

**The closed form, kept because it is the route not taken and the reason matters.** With `a = 1/c`,
`X = (m/b)^c` and `γ(a,x) = x^a e^{−x} Σ(a,x)`:

```
∂γ/∂a = log(x)·γ(a,x) + x^a e^{−x} · Σ_n ( −t_n · Σ_{l=0..n} 1/(a+l) ),   t_n = x^n / [a(a+1)···(a+n)]
∂G/∂c = −(b/c²)·γ  +  (b/c)·( X·log(m/b)·∂γ/∂x  −  (1/c²)·∂γ/∂a )
```

**Only the steepness reaches `∂γ/∂a`**; position needs `∂γ/∂x` alone, which is elementary. The series
argument is bounded by construction — `X = log(1/fraction)` identically, so `x ≤ 4.61` wherever this
integral is evaluated — and the calculus is verified to better than 1e-23 against an independent
high-precision integral.

**It becomes the right route the moment the forward model stops reading a table.** Report 05 §7.6
calls that a change to the *forward* model, made once and re-blessed once, after which the value and
the derivative describe the same function. Until then it would be more accurate about the wrong
thing.

Everything else for the pinned branch is ready: the bound rows are refereed in all three arms and both
halves, `root_b` included; `profit_env_derivatives` supplies the case-K profit rows; and the ten
`dcollar_d<family>` sites are a direct substitution once `root_c` has a row.
