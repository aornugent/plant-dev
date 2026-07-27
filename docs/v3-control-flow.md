# Proposed control flow, and the memory profile it implies

Answers two questions (owner, session 22): the adaptive → fixed → reverse control flow for FF16 and
TF24, and whether there is enough measured to profile the proposed TF24 solution. There is.

**Settled going in:** `Replayable` is retired (its structure role has no witness; its value role is
the out-of-scope mutant path). TF24 gains the separable light field. Soil is ODE state and needs no
replay concept. The leaf solve stays a clean `implicit_value`, called many times. A unit is restored
with plant's existing setters.

---

## The one measurement that changes the design

Steps per introduction segment, at production lifetime (`life = 105.32`, one species,
`birth_rate = 20`):

| | node states | ODE steps | introductions | **steps/segment** |
|---|---|---|---|---|
| K93 | — | 173 | 141 | **1.23** |
| FF16 | 987 | 264 | 141 | **1.87** |
| **TF24** | 987 (+9 soil) | **2 598** | 141 | **18.43** |

TF24 takes **ten times as many ODE steps as FF16 for the same schedule of introductions** — the
rainfall transient the multirate work found. So the event segment, which is a fine unit for K93 and
FF16 and needs no new plant surface, **is not a viable unit for TF24**: a segment holds 18 steps and
peak tape scales with it.

**This is the kill condition in `v3-engine-design.md` firing, quantitatively.** It said: *if a
schedule policy pushes steps/segment high, the unit must become the step, and that is the one change
requiring surgery inside `SCM::run_next_impl` to split `advance_fixed(e.times)` into its steps.*
TF24 triggers it. Since one mechanism should serve all three, **build the step unit.**

---

## FF16: adaptive → fixed → reverse

```
PASS 1  adaptive, plain scalar          -- discover the schedule
  scm.refine_schedule()
  schedule = scm.recorded_steps()                     // L1, the single source of the grid

PASS 2  fixed, plain scalar             -- record the trajectory
  for each ODE step k on `schedule`:
    store  y[k]                                       // the state entering step k
    store  species counts entering k                  // widths; derivable, stored for speed
    store  introduced[k]                              // which species open step k (empty for most)
  per cohort, once at its birth:
    store  pr_patch_survival_at_birth                 // divides the fecundity rate
    store  node_introduction_time, patch_density_at_birth   // ONLY if the functional is R0

PASS 3  reverse, one step at a time     -- the sweep
  lambda = d(functional)/d(final state)               // one row per output
  for k = last step .. 0:
    fresh tape                                        // NOT a rewound one: see below
    register the stored state and the seeded traits as inputs
    patch.r_set_state(t[k], y[k], counts[k], light_state)    // existing setter
    species.set_birth_state(times, density, pr_survival)     // existing setter
    patch.introduce_new_nodes(introduced[k])           // ON TAPE, so a coupled IC carries its adjoint
    solver.advance_fixed({t[k], t[k+1]})               // exactly one step
    seed the output adjoints from lambda; sweep once per output row
    lambda = the entering-state adjoints; accumulate the trait adjoints
```

Notes that are measured rather than assumed:

- **A fresh tape per unit, not a rewound one.** `resetTo` keeps the gradient exact but does not
  release: peak grew 48 kB → 742 kB over 60 → 960 units against a flat 6 560 B, and its time
  advantage reversed. The per-unit tape construction is the price of the bound.
- **The structural change goes inside the unit.** Placed between units, a stand-dependent newborn
  loses its adjoint silently — 19% error, right sign, and no constant-IC toy can detect it.
- **`r_set_state` alone is not enough.** It restores state, widths and the spline, but not
  `pr_patch_survival_at_birth`, which `Node::compute_rates` divides the fecundity rate by. Omitting
  it puts the error in `offspring_produced_survival_weighted` exclusively — measured, every segment,
  both models.
- **Several output rows come off one recording.** Record the unit once, `clearDerivatives`, sweep per
  row. A census 3-vector costs a scalar's tape and three sweeps.

FF16 could ship on the **segment** unit instead (1.87 steps), which needs no new plant surface at
all — `SCM::run_next()` already does one segment. That is a legitimate staging step and a cheaper
first witness.

---

## TF24: the same flow, with three differences and none of them new machinery

```
PASS 1, PASS 2, PASS 3 exactly as above, plus:

  the state vector now carries soil water            -- 9 extra entries, part of y
  the light field's source weight is a leaf-solve output, read from an aux slot
  each rate evaluation instantiates 2-3 implicit_value nodes per cohort
```

**1. Soil is ODE state, so it needs nothing.** `TF24_Environment::ode_size() > 0` (9 entries against
FF16's 0), so soil water sits in `y`, is stored and restored by the same `set_ode_state`, and its
derivative is carried by the sweep with no recording and no freezing decision. Treating it as a
background would be strictly worse — it would drop the depletion feedback that makes a water-limited
model mean anything.

**2. The leaf solve is a clean IFT called many times, and the count is the whole memory story.**
`implicit_value` bounds each call exactly — ~1.6k ops per solve, *independent of solver iterations*,
against ~26× for a naive on-tape solve. What it cannot bound is that the node sits inside
`ode_rates`, so it is instantiated `cohorts × stages × nodes` times per step. **No improvement to the
inversion touches that; only bounding the run does.** Which is what PASS 3 above is.

**3. The source weight is read one stage stale, and this is the open item.** Inside `set_ode_state`,
`compute_environment()` runs *before* `compute_rates()`, and the competition source weight comes from
an aux slot the latter writes — so the field at RK stage *s* is built from aux written at stage
*s−1*. **The environment is therefore not a pure function of `y`.** Settling a restored patch twice
(refreshing aux) makes the FF16 match *worse* — 1e-35 → 1e-14 at segment 20, 2e-22 → 1e-6 at 80 —
because the forward pass genuinely uses the lagged value.

For FF16 a single settle happened to reproduce it to 1e-22. **For TF24 the aux is a leaf-solve output
rather than a closed form, so whether a single settle reproduces it is the first thing to check** —
before trusting any TF24 gradient from this flow. If it does not, the aux entering each unit joins
the stored trajectory (a few kB per step).

---

## Memory profile of the proposed TF24 solution

Built from the **marginal** per-step tape cost, read off the measured TAPE_STATS curve rather than
extrapolated from an average. Each row is a step increment at nearly-fixed width:

| lifetime span | Δ steps | width (states) | Δ tape | **per step** | per state-step |
|---|---|---|---|---|---|
| 1 → 1.5 | 24 | ~543 | 1.150 GB | **47.9 MB** | 88 kB |
| 1.5 → 2 | 13 | ~560 | 0.754 GB | **58.0 MB** | 104 kB |
| 2 → 2.5 | 11 | ~574 | 0.678 GB | **61.6 MB** | 107 kB |

At production width (**987** node states + 9 soil), one TF24 ODE step costs:

- **~104 MB** if the per-state cost stays constant (`105 kB × 987`);
- **~180 MB** if it grows linearly in width, which the three rows above weakly suggest
  (88 → 107 kB as width goes 543 → 574).

**So the honest peak estimate for the proposed TF24 solution is 100–200 MB**, and the uncertainty is
the per-state scaling, not the method.

Against what it replaces:

| | whole-run tape at `life = 105.32` | proposed peak | factor |
|---|---|---|---|
| **TF24, step unit** | ~105 kB × 987 × 2 598 ≈ **269 GB** | **100–200 MB** | **~2 600×** |
| TF24, *segment* unit | same | 1.9–3.7 GB | ~140× — **fails, hence the step unit** |
| FF16, segment unit | ~55 kB × 987 × 264 ≈ **14 GB** | ~100 MB | ~140× |

The reduction factor is simply **the number of units**, which is the design's whole claim: peak =
whole ÷ units. And it is why TF24 gains more than FF16 — it has 2 598 units, not 141.

**Plus the stored trajectory, which is not the constraint:**

| | steps × states × 8 B | |
|---|---|---|
| TF24 | 2 598 × 996 × 8 | **20.7 MB** |
| FF16 | 264 × 987 × 8 | **2.1 MB** |

Per-cohort birth stamps are stored once per cohort, not per step: 3 doubles × 141 cohorts ≈ 3.4 kB.

**Total proposed TF24 footprint: ~125–220 MB at production lifetime**, against a 269 GB whole-run
tape that OOMs the machine. Wall clock: a flat **4.2×** the whole-run reverse pass, measured on the
spike and constant in run length.

### What would invalidate this profile

- **Per-state cost growing faster than linearly in width.** The three marginals span only
  543 → 574 states; production is 987. Measuring one more point at `life = 4` would tighten it, and
  that is now the cheapest useful measurement left.
- **The aux lag needing per-step storage.** Adds a few kB per step — irrelevant to the total, but it
  would mean the environment is not restorable from `y` and the *design* changes, not the arithmetic.
