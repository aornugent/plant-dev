# What the tests cost, and why

A companion to `catalog.md`, which holds what must be fixed before submitting.
This holds what was measured about the suite this branch adds: why it costs what
it costs, one defect found while measuring it, and which of the remaining levers
belong to a maintainer rather than to the branch.

Every number here was taken on this tree at `-O2`. Where a figure is a property
of one fixture it says which.

---

## 1. The defect to fix first

⚠️ **The census seed and an exact derivative of the same reduction disagree by a
uniform scalar, and `test-census.R`'s G3 passes because its tolerance absorbs
it.** Reproducible in **0.7 s**:

```
ONE object, 79 nodes, t = 1.00
  value       R 3.817229507972155e-01   C++ 3.817229507972155e-01   rel 1.45e-16
  derivative  R 1.644376194611845e-06   C++ 1.644376184529206e-06   rel 6.13e-09
```

`stand_census` and the R reduction agree bit for bit. `stand_census_state_adjoint`
and the closed-form derivative of that same reduction do not.

What is established:

- **Uniform.** Every interior node reads the same relative gap — 6.13e-09 on a
  seeded stand, 8.63e-05 on a grown one at a lifetime of 12. The boundary node
  reads O(1), which is the reference's own weight formula giving the closing
  interval only its lower half.
- **It grows with patch age.** 6.13e-09 at t = 1, 8.63e-05 at t = 12.
- **It is not a step size.** Identical to four figures at
  `node_gradient_eps` = 1e-6, 1e-8 and 1e-10.
- **It is not patch survival.** `pr_patch_survival_at_birth` is exactly 1.0 on
  both fixtures.

A uniform relative offset at every node is a missing scalar rather than an
accuracy loss, and three candidates for it are refused above. Which side is wrong
is open: the closed form agrees with a central difference of the R reduction to
1.05e-07 on the grown stand, which establishes it as a correct derivative of
*that reduction*, and not that the reduction is what the C++ census reduces.

⚠️ **THE TOLERANCE IS NOT BOUNDING WHAT IT APPEARS TO.** G3 asserts
`seed vs finite difference < 1e-4`, and which term dominates that comparison
changes with the fixture:

| fixture | seed vs closed form | difference vs closed form | what G3 measures there |
|---|---|---|---|
| seeded, lifetime 1 | 6.13e-09 | 3.44e-06 | the difference's truncation |
| grown, lifetime 12 | 8.63e-05 | 1.05e-07 | the seed gap |

So the same assertion measures two different quantities on two fixtures, and the
lifetime it was tuned to is where both happen to fit under one round number.

**Why this is worth doing before anything else.** The omission grows with run
length. At a longer lifetime G3 fails, and the failure reads as a gradient defect
while being a reference defect — which is the shape this suite exists to prevent,
sitting inside the suite.

---

## 2. Why the suite costs what it costs

Measured end to end, one process:

| | cost | result |
|---|---|---|
| the ladder, 14 files | **63 s** | 615 pass, 0 fail, 0 skip |
| `test-census.R` | 259 s | 27 pass |
| `test-mutant.R` | 648 s | 21 pass, 2 fail |
| `test-gradient-incidence.R` | 542 s | 60 pass, 6 fail |
| `test-gradient-parity.R` | 329 s | 55 pass, 3 fail |

`tests/testthat.R` is `test_check("plant")`, so all of it runs under `R CMD check`
on three operating systems. The nine failures are A1's, not this document's.

### Two mechanisms, and a third that is neither

**TF24 crosses a stiffness cliff just past a patch lifetime of 3.** Default
schedule, single-trait recipe:

| lifetime | introductions | steps | seconds | steps per introduction |
|---|---|---|---|---|
| 0.5 | 71 | 94 | 0.39 | 1.3 |
| 1 | 76 | 122 | 0.62 | 1.6 |
| 2 | 81 | 172 | 0.97 | 2.1 |
| 3 | 84 | 193 | 1.08 | 2.3 |
| **5** | 88 | **7991** | **99.89** | **90.8** |

Between 3 and 5 the introduction count rises 5% while the step count rises 41×.

**The sweep is linear in recorded steps, and about four times the run.** Five-trait
recipe:

| rain | lifetime | steps | run | sweep |
|---|---|---|---|---|
| 2.00 | 3 | 319 | 1.96 s | 7.62 s |
| 2.00 | 5 | 422 | 2.86 s | 10.55 s |
| 0.10 | 3 | 346 | 1.66 s | 7.19 s |
| 0.10 | 5 | **2415** | 11.63 s | **51.34 s** |

Seven times the steps, 7.1 times the sweep. So the cliff multiplies the dominant
term rather than adding to it.

**And the recipe matters more than the horizon.** Same lifetime, same node count:

| recipe | lifetime | steps | nodes | seconds |
|---|---|---|---|---|
| `trait_matrix(0.0825, "lma")` | 5 | 7991 | 88 | 101.49 |
| five traits through `TF24_hyperpar` | 5 | 233 | 88 | **1.49** |
| `trait_matrix(0.0825, "lma")` | 12 | 15599 | 94 | 205.72 |
| five traits through `TF24_hyperpar` | 12 | 1091 | 94 | **12.13** |

Setting one trait leaves the rest at defaults, which is a strategy the
hyperparameter function would never produce — stiffer by 14× in steps, and less
representative of anything the package generates.

### ⚠️ A correction AGENTS.md needs

Its introductions table states *"the cliff is between 44 and 88 [introductions]"*.
That table was measured entirely at a lifetime of 5, where every point is already
past the cliff, so it measured a confound. Truncating that schedule:

| introductions at lifetime 5 | 10 | 25 | 44 | 60 | 88 |
|---|---|---|---|---|---|
| steps | 1241 | 4007 | 6052 | 7064 | 7991 |
| seconds | 2.03 | 15.11 | 39.45 | 61.83 | 99.89 |

Ten introductions at a lifetime of 5 cost 1241 steps; eighty-four at a lifetime of
3 cost 193. The schedule was never the variable. The same file's patch-lifetime
table has it right, and two tables in one document disagreeing is what makes this
worth correcting rather than leaving.

---

## 3. Construct, or grow

The suite has two idioms and the cost tracks them exactly.

**The ladder constructs its states.** `ladder_patch_fold()` forces a curvature fold
by setting the floor; `ladder_patch_shutdown()` reaches a genuine hydraulic
shutdown by drying the soil; `ladder_patch_uniform_drying()` places a drying
profile. Each elicits a specific leaf behaviour in milliseconds, and
`test-gradient-ladder-sweep.R` asserts refusal, finiteness and both output kinds
on them. Fourteen files, 615 assertions, 63 s.

**The surface tier grows to them**, asserting comparable per-state properties by
running a stand until the model arrives at that state. Four files, 1778 s.

Three measured instances of a per-state claim paying for a trajectory:

| claim | what it asserts | cost |
|---|---|---|
| `test-census.R` G3 | the seed equals the census's derivative at one node | 251 s |
| incidence, *"the light floor is counted on both paths"* | that two counters read **zero** at the shipped value, then that the crown site dominates by a ratio the block's own comment derives from the shading geometry | 251 s of 542 |
| parity's gate, *"nothing escapes unnamed"* | already tested per-state on constructed patches by `ladder_rhs_adjoint_tf24` | part of 329 s |

**The underlying pattern is that a fixture gets calibrated to a weak reference.**
G3's 1e-4 is its difference's truncation, so the fixture was tuned until the
reference was accurate enough — which is why every attempt to move the fixture
broke the reference rather than the claim, and why the move that works is the one
that replaces the reference.

Coverage does not require the stiff regime. Kinds and clamp sites reached:

| rain | lifetime 2 | lifetime 3 | lifetime 5 |
|---|---|---|---|
| 2.00 | interior; rooting_depth | same | same |
| 0.10 | interior, boundary-crit; reserve_ceiling, rooting_depth | **+ storage_floor** | same |

⚠️ **This is narrower than the analysis already in D**, which ran all five named
regimes and records that a lifetime of 3 loses `light_floor` and
`light_floor_crown` — the two sites incidence's most expensive block exists to
reach. D's answer is a lifetime of 4, and it stands.

---

## 4. What is available

**Verified and unblocked.** G3 holds on the seeded distribution with better
margins than it has now, at 0.7 s against 251:

| fixture | non-vacuity, floor 1 | seed vs difference, tolerance 1e-4 | seconds |
|---|---|---|---|
| seeded, lifetime 1 | **27.60×** | **3.43e-06** | 0.7 |
| grown, lifetime 12 | 7.40× | 8.62e-05 | 251 |

⚠️ **Sequenced after section 1, deliberately.** Moving G3 there makes it pass more
comfortably while the 6e-09 disagreement stays unexplained, and a speed change
that quietly widens the margin on an open numerical question is how the question
stops being asked. Resolve the scalar, then move the fixture.

**Untested.** `test-mutant.R` runs its TF24 identity at a lifetime of 6 — 12,714
replayed steps agreeing to 8.06e-13 against a tolerance of 1e-3. The cliff is at
3.1, so 4 is the first lifetime that still exercises the stiff regime. Whether the
identity survives a shorter recording has not been measured.

**D's, and it stays there.** Recalibrating incidence and parity to a lifetime of 4
is already quantified in D at 25% of CPU, and their per-trajectory pins are the
evidence for the A1 decision — so retuning them now would tangle a fixture change
with the decision it is meant to inform. The one thing that would move it out of D
is a fixture that elicits the same guarantees without a trajectory, which sections
3 and 4 suggest is available for the per-state half of each file and not for the
incidence half.

---

## What did not survive measurement

Kept so nobody re-opens them.

- **The schedule as the cost driver.** Refused by the truncation table above.
- **`TF24_hyperpar` as a cheaper fixture for G3.** 17× cheaper at the same node
  count, and G3 fails on it at 4.13e-04 against a tolerance of 1e-4.
- **`node_gradient_eps` as the source of the 6e-09.** Invariant across four
  decades.
- **Patch survival as the source.** Exactly 1.0 on both fixtures.
- **Caching as parity's lever.** It already caches in process and on disk, keyed
  by the compiled object's checksum, and forks across regimes, so it costs its
  slowest regime rather than their sum.
- **`swept` as a redundant cache key in incidence.** A swept object cannot answer
  for the run, because the sweep adds to the tallies the run leaves.
