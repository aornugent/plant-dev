# B: the tangent–sweep disagreement on trait columns at an introduction

**Verdict: B has no fix outstanding. Its root cause is the defect closed by
`plant` commit `7015a1c9`, "Re-derive the seed's dependent aux where its height is
written", and every figure B was specified from is a pre-`7015a1c9` figure.** What
B needs is its measurements retired and its coverage gap closed, and neither is a
change to the sweep.

The specification's own lead — the newcomer's initial reserve, `r_0 = a_st3 · S_max`
— is wrong, and the measurement that rules it out is one the ladder already had.

---

## 1. What B is, reproduced

At `ec8e59f1`, the tip B was written against. One species (`ladder_traits()$fast`,
birth rate 1.10), `node_density_in_birth_date = TRUE`, the `omega` column of the
leaf-area census, ratios against a rebuilding reference at `rel = 1e-4`.

| lifetime | introductions | sweep/ref | tangent/ref | gap |
|---|---|---|---|---|
| 1.0 | 1 | 0.990298 | 0.990298 | 5.06e-07 |
| 2.0 | 1 | 0.839430 | 0.839433 | 3.72e-06 |
| 3.0 | 1 | 0.379625 | 0.379636 | 2.81e-05 |
| 1.0 | 2 | 0.992121 | 0.989269 | 2.87e-03 |
| 2.0 | 2 | 0.959246 | 0.954567 | 4.88e-03 |
| 3.0 | 2 | 0.532741 | 0.528294 | 8.35e-03 |

This reproduces B's structure and its magnitude at lifetime 2 — 0.49 points of a
percent against the specification's 0.50 — but not its ratios at lifetimes 1 and 3,
where the specification reads 0.07 points and 0.6837/0.6788 against 0.29 points and
0.5327/0.5283 here. So the specification's table was taken at a slightly different tip
or fixture than `ec8e59f1`. Nothing below turns on the difference: every conclusion is
drawn from the channel set and the scaling, both of which reproduce.

**One correction to the specification at the outset: the single-introduction gap is
not zero and not bit-identical.** It runs 5.1e-07 to 2.8e-05 and grows with run
length. The widening raises it by three to four orders; it does not switch it on.
The distinction matters, because a defect that is *absent* without a widening and one
that is *amplified* by a widening point at different code.

**And "one introduction" is one widening, not none.** The founding cohort at `t = 0`
is introduced into an empty patch after the first state is recorded — segment 0 holds
the environment and no cohort, at width 9 against the populated 17 — so a run with `N`
scheduled introductions has `N` boundaries and the sweep's segment loop runs `N` times.
B's real statement is therefore: *the founding widening carries a residual three orders
above round-off, and a widening into an already-populated patch carries one four orders
larger again.*

## 2. Which channel carries it

Every column of the same stand, sweep against tangent, worst row, at `ec8e59f1`
with one widening beyond the founding one:

| trait | residual | | trait | residual |
|---|---|---|---|---|
| omega | 2.87e-03 | | a_st3 | **3.47e-09** |
| a_r1 | 1.42e-03 | | a_d0 | **1.13e-06** |
| a_l2 | 2.16e-04 | | recruitment_decay | **1.26e-06** |
| theta | 2.37e-04 | | k_I | **6.92e-10** |
| a_b1 | 1.98e-04 | | | |
| lma | 1.64e-04 | | | |
| rho | 1.26e-04 | | | |
| a_l1 | 1.12e-04 | | | |

The left column is `ladder_birth_size_parameters()` exactly — all eight of the
parameters that reach the census through the seed's own size — and the right column
is every other channel the boundary has.

**This is what rules out the initial reserve.** `a_st3` *is* the single-channel probe
for that route (report 08 §4.6 lists it as such, and rung 5 takes it by name): it
reaches the census through the newcomer's initial reserve and through nothing else.
It reads 3.47e-09 while the gap it was proposed to explain is 2.87e-03, and it is
**bit-for-bit unchanged** by the commit that closes B. The two constants of the inflow
condition itself, `a_d0` and `recruitment_decay`, are likewise untouched, as is the
field-borne `k_I`.

So the channel is the seed's **size**, not its provisioning. The reserve appears in
B's story only because `S_max` is a function of the seed's height and leaf area, so
the reserve is downstream of the defect rather than being it.

## 3. Count against duration, which report 04 §6.3 asks for and nobody had run

Same column, same fixture, at `ec8e59f1`:

| lifetime | 1 intro | 2 | 3 | 4 |
|---|---|---|---|---|
| 1.0 | 5.06e-07 | 2.87e-03 | 2.74e-03 | 2.69e-03 |
| 2.0 | — | 4.88e-03 | 5.75e-03 | — |

**It scales with duration and is flat-to-falling in introduction count.** Report 04
§6.3 names this as the experiment that distinguishes "a production schedule's error is
set by the schedule" from "set by run length": the answer is run length. The falsifier
in report 04 §8, "the introduction onset scales with introduction count", is answered
in the negative.

This also re-reads one earlier elimination. The `ladder_introduction_residual` note
excludes the size-distribution's interior interval on the grounds that moving the
second introduction from 0.02 to 0.38 of a four-tenths run made the residual *fall*.
Moving that introduction later also shortens the time after it, so that experiment
varied two things at once, and the duration scaling above is what the fall tracks.

## 4. What was eliminated, and how

- **The linearisation point is shared.** The tangent's replayed census matches the
  run's to **zero bits** on five of six fixtures (4.3e-16 on the sixth), and a
  plain-double replay from the sweep's reconstructed widened base state reproduces the
  run's census to **zero bits** as well. So neither path is differentiating a
  different trajectory, and the reading in the `ladder_introduction_residual` note —
  "a linearisation taken at a point the two do not share" — is not what is happening.
- **Forward propagation of a state perturbation carries no error of B's size.** The
  tangent's `∂C/∂y` at the widened segment base agrees with a difference of the double
  replay in the same direction to 2.0e-05 at lifetime 1 and 2.5e-04 at lifetime 2, on the
  newcomer's height and on the older cohort's height and reserve alike. *These two
  figures were not step-stabilised, so read them as an upper bound on the propagation's
  disagreement rather than as a floor* — which is all this elimination needs, since the
  channel it would have to explain is 2.9e-03 at the same lifetime.
- **The step range at a boundary is right.** `solve_adjoint(states, λ, b, upper)`
  sweeps `states[k-1]` for `k` from `upper` down to `b+1`, so `λ` returns as the
  adjoint of the *widened* segment base, which is what the introduction's
  vector–Jacobian product must be seeded with. No off-by-one.
- **The two boundary-node evaluations are one function.**
  `Species::compute_boundary_node` calls the same `compute_initial_conditions` that
  `compute_rates` does, so the map's reconstruction and the run's push are the same
  evaluation at the same state and time.

## 5. Why the introduction map's own check could not see it

Report 08 §4.6 records the introduction map's Jacobian as agreeing forward against
reverse to 7.5e-16 over all 3729 cells, and rung 5 runs that comparison at `ec8e59f1`
— where the map's `omega` column was wrong, since the map reaches the newcomer's state
through the same `set_initial_states` the defect was in.

Both sides of it go through `introduce_over`, so both inherit whatever
`set_initial_states` declares — including, before `7015a1c9`, an aux leaf area
carrying no derivative. **This is report 08 §4.8's mechanism — "a term both paths
multiply by the same wrong factor agrees between them and is wrong in both" — and it
is worth recording as that section's first instance.** The map was a correct transpose
of the wrong function, and the reference that disagreed was the one that never forms
the product: a rebuilding difference. *(Read from the code rather than re-measured: the
7.5e-16 figure was not re-taken at `ec8e59f1`. The claim needing no measurement is the
structural one — the object and its reference share `introduce_over`, so they share its
declarations, which is report 08 §1's "disjointness of code is not disjointness of
assumptions".)*

## 6. Why the suite was green

Across the whole ladder, the per-column sweep-against-tangent comparison covers
`ladder_shortlist()` = `k_I`, `eta`, `a_l1`, `a_l2`, `a_st3`, `recruitment_decay` at
rung 4, and `1.a_l1`, `1.a_l2`, `1.k_I`, `2.k_I` at rung 5. **Of the birth-size eight,
only `a_l1` and `a_l2` are ever compared as columns** — `omega`, `lma`, `rho`,
`theta`, `a_b1` and `a_r1` are not compared against a tangent anywhere.

And the two that are compared are held to `ladder_introduction_residual()` = 4e-03,
not to `ladder_trajectory_agreement()` = 3e-04 — a bound widened for this very
disagreement. Rung 4's contraction, which does include every column, is held to
`3 × ladder_introduction_residual()` = 1.2e-02 and sums 88 columns into one number.

So the defect sat inside a tolerance that had been loosened around it, on the only two
columns of its class that were checked, and diluted below the one check that saw them
all. B was found from outside the ladder, and that is the finding about the ladder.

## 7. After `7015a1c9`

Same fixtures, same columns, same instruments.

| lifetime | introductions | sweep/ref | tangent/ref | gap | was |
|---|---|---|---|---|---|
| 1.0 | 1 | 0.999983 | 0.999983 | 1.48e-10 | 0.9903, 5.06e-07 |
| 2.0 | 1 | 0.999966 | 0.999966 | 2.39e-09 | 0.8394, 3.72e-06 |
| 3.0 | 1 | 0.999922 | 0.999922 | 2.22e-09 | 0.3796, 2.81e-05 |
| 1.0 | 2 | 0.999988 | 0.999988 | 1.04e-10 | 0.9921/0.9893, 2.87e-03 |
| 2.0 | 2 | 1.000019 | 1.000019 | 3.74e-09 | 0.9592/0.9546, 4.88e-03 |
| 3.0 | 2 | 1.000019 | 1.000019 | 3.68e-09 | 0.5327/0.5283, 8.35e-03 |

**Every cell of B's table is now within 8e-05 of the rebuilding reference and within
4e-09 of the other differentiated path.** The lifetime-3 column was 62 per cent short of
the reference before the change.

All twelve probed columns at lifetime 1 with one widening beyond the founding one:
omega 1.04e-10, lma 3.20e-10, rho 6.65e-11, a_l1 8.47e-11, a_l2 9.96e-11, theta
7.18e-11, a_b1 2.50e-10, a_r1 3.51e-09 — with `a_st3` 3.47e-09, `a_d0` 1.13e-06,
`recruitment_decay` 1.26e-06 and `k_I` 6.91e-10 unmoved, as a channel the defect
never touched should be.

And the residual after the widening, with the introduction fixed at 0.29 and the run
stopped just past it: 3.0e-13 at 0.01 of a year after, 1.9e-13 at 0.03, 1.3e-13 at
0.07.

**Two things this closes beyond B.** The birth-size eight now agree with the
*rebuilding* reference too — omega moves from 0.9903 to 0.999983 at one introduction —
so the same change closes a shortfall on the completeness axis, not only an agreement
between two differentiated paths. That is the measurement report 08 §10 wants placed in
the change that closes it.

Quote that agreement as **"within the reference's own step-stability"** rather than as
1.7e-05: measured on this fixture, `ladder_run_difference_stable` spreads 1.04e-03 over
steps `1e-5` to `1e-3`, so the rebuild holds about three figures and cannot referee
more. The pre-change deficit of one percent was an order outside that spread, which is
why it was a finding; the post-change agreement is at the floor, which is all a
three-figure reference can say. The seed-height slope is 2923 on the same run, so the
channel being priced is live rather than absent.

The largest sweep-against-tangent residual on this fixture is now `a_d0` at 1.13e-06,
two orders inside the declared 3e-04. That is the new ceiling and it is not this
defect: `a_d0` is bit-for-bit unchanged across the commit.

**Neither path was the right one.** Before the change, both were about one percent
below the rebuilding reference and additionally disagreed with each other by three to
eight parts in a thousand. B is stated as a disagreement, which invites the question of
which path to trust; the answer is that a row missing from a lifetime *both* paths
inherit was absorbed differently by each. Fixing the row moved both onto the reference.

### 7.1 It closes the documented `a_l1`/`a_l2` introduction residual as well

On `ladder_stand_introductions()` — two species, three introductions, the fixture the
4e-03 bound was measured on:

| column | residual | checked by the ladder? |
|---|---|---|
| `1.a_l1` | **2.21e-09** | yes, against 4e-03 |
| `1.a_l2` | **1.10e-08** | yes, against 4e-03 |
| `1.k_I` | 3.30e-07 | yes, against 3e-04 |
| `2.k_I` | 9.55e-09 | yes, against 3e-04 |
| `1.lma` | 3.63e-08 | no |
| `1.rho` | 1.97e-08 | no |
| `1.omega` | 3.01e-08 | no |
| `1.theta` | 1.31e-08 | no |
| `1.a_r1` | 3.66e-07 | no |
| `1.a_b1` | 8.79e-08 | no |
| `1.a_st3` | 8.49e-07 | no |
| `1.a_d0` | 3.76e-05 | no |
| `1.recruitment_decay` | 4.42e-05 | no |

with the replay floor at 1.01e-12 against its 1e-9 bound. The largest residual anywhere
in the set is now `recruitment_decay` at 4.4e-05, inside the 3e-04 bound by most of an
order, and the birth-size eight sit between 2.2e-09 and 3.7e-07.

`ladder_introduction_residual()`'s own note records that residual at 3.4e-03 and calls
it "an open defect rather than a floor", after some twenty recorded eliminations. **It
now measures six orders below its bound, and `k_I` — which shares the field reduction
and was never implicated — is unmoved at the 3.3e-07 that note quotes.** So B and that
residual were one defect, and `omega` was the sharper probe of it: report 08 §4.7 is
right that one introduction makes a parameter a single-channel probe, and the parameter
it makes one of is the seed mass.

## 8. What was changed, and what it was validated against

Items 1 to 4 below are **made**. None is a change to the sweep; all four are a check
or a record.

**The single bound.** `ladder_introduction_residual()` (4e-03) and
`ladder_introduction_borne_traits()` are deleted, along with the 133-line note
documenting the defect they were widened around, and `ladder_trajectory_agreement()`
(3e-04) now holds every column. Rung 4's contraction moves from
`3 × ladder_introduction_residual()` = 1.2e-02 to `3 × ladder_trajectory_agreement()`
= 9e-04.

**The class, not the pair.** `ladder_shortlist()` unions the reduction-borne six with
`ladder_birth_size_parameters()`, so rung 4's column loop runs 22 columns rather than
10, and rung 5's runs the field-borne pair plus the birth-size eight for both species,
18 rather than 4. Both loops assert the class is present rather than trusting a count
alone, because a shortlist that silently lost a name would read as a shorter loop.

Measured on rung 4's own fixture with the extended loop, every column against the
single 3e-04 bound:

| | worst column | margin |
|---|---|---|
| all 22 columns | `1.recruitment_decay` 4.40e-05 | 15 per cent of budget |
| birth-size eight, both species | `2.a_r1` 3.27e-06 | 1 per cent |
| the contraction | 2.09e-05 against 9.00e-04 | 2 per cent |
| the replay floor | 5.97e-13 against 1e-09 | 0.1 per cent |

and on rung 5's fixture the two columns the retired bound existed for read 2.21e-09
and 1.10e-08 — **0.000 of a budget that was 4e-03**, which is the whole argument for
retiring it.

**What it costs.** Rung 4 goes from 13 tangent replays to 25 and rung 5 from 6 to 20,
and a tangent on these fixtures is a whole replay of the run. That is the price of
refereeing a class rather than two of its members, and it is worth recording rather
than discovering: if the wall clock becomes the binding constraint, the six added
columns are cheaper to keep on rung 5 — whose fixture is the one whose subject is
widenings — than on both.

**The record.** Report 04 §6.3 carries the count-against-duration answer and §8's
falsifier is marked run and measured false; report 08 §4.8 carries the worked instance
of two paths sharing a multiplier.

## 9. What is left, which is one measurement and not a fix

**Re-check that `a_st3` is not being flattered.** It reads 3.47e-09 before and after,
   which is what an untouched channel should do — but report 08 §6 records the run
   fixtures sitting at a gate slope of 0.04 to 0.12 against a declared floor of 0.4, and
   the initial reserve is the channel that damping most directly suppresses. The
   specification's own note is right that a magnitude taken here is fixture-specific.
   What that qualification cannot do is revive the reserve as B's cause, since the eight
columns that moved and the one that did not were measured on the *same* fixture at the
same gate slope.

The fixtures the changes above are validated on sit at a gate slope of 0.040 against
report 08 §6's declared floor of 0.4, which those runs report and do not enforce. So
every margin quoted here is taken at about a tenth of the sensitivity the vacuity guard
asks for, and that qualification travels with the numbers rather than with the defect.

---

### Provenance

Measured in an isolated worktree at `ec8e59f1` and `7015a1c9`, with nothing edited in
the object under test. Compiled with `pkgbuild::compile_dll(debug = FALSE)` under
`CXX20FLAGS = -O2 -DNDEBUG -g0` and then loaded with `pkgload::load_all`, which
recompiles on its own terms; every figure quoted here is a ratio or a relative
residual, so the optimisation level does not enter. Instruments used: `stand_gradient`,
`ladder_trajectory_tangent`, `ladder_run_difference`, and the state-propagation
probes `ladder_segment_base_state_tf24`,
`ladder_census_initial_state_tangent_tf24` and
`ladder_census_initial_state_replay_tf24` that `7015a1c9` itself adds.
