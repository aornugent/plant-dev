# Measured facts, with how to re-run them

**This is the anti-rediscovery document. Read it before designing anything.** Session 22 spent most
of a session re-deriving conclusions `deepenings/deepening-6-light-coupling.md` had already reached,
because nothing surfaced what was already settled. Every row below is a number someone measured and
a command that reproduces it.

**Rules for this file.** A row earns its place by being *measured*, never argued. Every row cites how
to re-run it. If you re-measure and get something different, **edit the row** — do not add a second
one. Estimates belong in the design doc, not here; the triage rule in
[`v3-evidence-triage.md`](./v3-evidence-triage.md) says why that distinction is load-bearing.

Build/test mechanics are in [`HANDOFF.md`](./HANDOFF.md) Part 1. **The two packages need opposite
invocations:** install odelia (`library()`, never `load_all`), `load_all` plant.

---

## 1. Memory: where the tape actually goes

| fact | number | re-run |
|---|---|---|
| TF24 tape at short lifetimes | life 1 / 1.5 / 2 / 2.5 / 3 / 3.5 → **3.22 / 4.37 / 5.12 / 5.80 / 6.76 / 11.15 GB** | `PLANT_TAPE_STATS=1` + `tf24_scm_gradient` |
| Steps and width alongside | 129 / 153 / 166 / 177 / 194 / 278 steps; 532 / 553 / 567 / 581 / 595 / 616 states | same |
| **Per-state-step cost is flat in width** | 88.0 / 104 / 107 / 96.6 / **86.2** kB over widths 543 → 606; the last averages **84** steps and is the reliable one | marginals of the row above |
| Per-step tape | **47.9 / 58.0 / 61.6 / 56.8 / 52.2 MB** at those widths | same |
| TF24 production shape | `life = 105.32`: **987** node states + 9 soil, **2 598** ODE steps | `run_scm` forward, no AD |
| FF16 production shape | **987** node states, **264** ODE steps | same |
| **Component leanness cannot close the gap** | crown boundary A **1.49×**, boundary D **3.7×**, `pow` hoist **1.24×**, interpolator **5.89×** — the last moved TF24's total by **0.018%** | probes in §3 |

**Consequence, not a fact but it follows:** cost is per-cohort-step × steps × cohorts, so only
bounding the run helps.

## 2. The step-local sweep

All from `cd odelia && make test` → `test-ad-step-local.R` (57 assertions).

| fact | number |
|---|---|
| Exact against a whole-run tape, an FD and a closed form | reld **1e-15 … 1e-14**; **exactly 0** for a coupled IC with an implicit rate |
| **Peak tape flat in run length** | **6 560 B** from 30 to 480 units, while whole-run grows 91 636 → 1 438 036 B; ratio **14× → 219×**, linear in the run |
| An `implicit_value` node in the rates re-records exactly | reld **0.0** (coupled IC), **1.1e-15** (constant) |
| **Several Jacobian rows come off one recording** | both rows exact; peak unchanged, so a census 3-vector costs a scalar's tape |
| Time cost is a flat multiple | **4.15 / 4.37 / 4.30 / 4.15 / 4.19×** at 60 → 960 units |
| A structural change placed **between** units loses the newborn adjoint | **19%**, silent, right sign; a constant-IC toy cannot detect it |
| **Rewinding one tape does not bound peak** | gradient stays exact (1.8e-15) but peak grows **48 kB → 742 kB** over 60 → 960 units vs a flat 6 560 B; time reverses 1.48× → 8.42× |

## 3. Light: field versus spline

| fact | number | re-run |
|---|---|---|
| **The spline cannot carry `d(light)/dz`** | at plant's production tol 1e-4, **mean** relative error **950%** (fit to light) / **227%** (fit to optical depth) | `Rscript docs/reference/spline-tangent-probe.R` |
| Fitting to optical depth is better but not enough | consistently **2-4×** better; mean under 1% needs **311-511 nodes** (tol 1e-6) and max is still 42% | same |
| Spline **values** are fine | value error tracks the fitting tolerance | same |
| The field read is **66%** of the FF16 crown tape | boundary A **1.49×**, boundary D **3.7×** | `Rscript docs/reference/crown-preaccum-probe.R` |
| FF16's crown reads the field with an **active** query height | not `get_value_at_height_frozen_query` | same probe; `ff16_environment.h` |
| The XAD tape byte model is exact | `12·ops + 8·stmts + 8·slots` reproduces 12 764 B to the byte | same |
| **All three strategies share one kernel** | TF24's `k_I·area_leaf(H)·(1−(z/H)^η)²` = `{1, −2z^η, z^{2η}}·{amp, amp·H^−η, amp·H^−2η}` = `CanopyShape`'s pair | algebra, checked against `canopy_shape.h:196-211` |
| Only the **Deep** profile is separable | Box/SoftBox keep the interpolator | `canopy_shape.h` comment + `shading_rank` |

## 3b. The field composed over a leaf solve, and the soil clamps

The composition `separable_field` **over `implicit_value` source weights** — TF24's shape, which
K93's and FF16's closed-form sources never exercise. This was the design's largest unwitnessed claim.

| fact | number | re-run |
|---|---|---|
| **A field assembled over IFT source weights differentiates exactly** | all 5 channels FD-exact at **6.9e-11 … 3.3e-9** | `test-ad-field-over-implicit.R` (52 assertions) |
| The field *assembly* is pinned independently of any FD | the `amp` channel matches the analytic identity `dA/damp = A/amp` at **2.2e-16** | same |
| Exactness does not degrade with population size | worst reld **1.6e-8 → 8.5e-10** over 2 → 40 sources (it *improves*) | same |
| …nor in the stiff soil regime | `dJ/dtheta` reld **2.1e-9 … 6.0e-10** over θ = 0.5 → 0.05, where the functional moves 4.85 → 29.4 | same |
| **The witness is not vacuous** — severing the solve collapses exactly the coupled channels | `to_passive(u)` zeroes `dJ/dk`, `dJ/dθ`, `dJ/dn` to **exactly 0** while `amp` and `eta` stay **bit-identical** | same |
| The active and plain paths agree exactly | `identical(value, value_double)` — `implicit_value` returns y* with no shift | same |

**Consequence:** the field's cumulative sums thread IFT-derived derivatives correctly, and the shared
soil scalar reaching every source is differentiated correctly through all of them. The composition is
no longer the risk; the `Leaf`-ownership blocker is.

### The soil clamps: four non-smooth constructs, one that matters

| construct | `tf24_environment.h` | class |
|---|---|---|
| runoff floor `runoff_factor > 0 ? · : 0` | :303 | **kink** — rate continuous, slope jumps |
| conductivity floor `theta > 0 ? · : 0` | :354 | **kink**, and only at θ<0, an RK-stage artefact |
| retention floor `theta > theta_r ? · : theta_r` | :365 | **kink** |
| **drying guard** `theta <= theta_r && rate < 0 → rate = 0` | :335 | **SEVERANCE** |

The guard is the only dangerous one, and the reason is not smoothness: on the clamped side
`d(rate)/d(theta)` **and** `d(rate)/d(resource_depletion)` are both zero, so the whole plant→soil
uptake channel is cut on a set of positive measure. That is the same severance class as the a1–a4
fixes, not a kink.

| fact | number | re-run |
|---|---|---|
| **At the default rainfall no clamp is visited** | min θ is **18–21× θ_r** (θ_r = 0.01) per layer; max θ **0.3106** vs θ_sat **0.428**; min `runoff_factor` **0.9231**; 0 layer-steps at the guard, 0 near it, 0 negative | `Rscript docs/reference/soil-clamp-probe.R` |

So `tf24_environment.h`'s own claim — "well below any realistic operating moisture, so it does not
perturb non-drought runs" — is **confirmed for the default driver**. The margin under a dried driver
is a separate question and is where the guard would bite.

## 4. Replay: what reproduces and what does not

| fact | number | re-run |
|---|---|---|
| An adaptive node set is **bit-identical** built plain or active, nothing recorded | 149 nodes, 0 mismatches, `max_abs_diff` **exactly 0** | `test-ad-adaptive-structure.R` (27 assertions) |
| Refining through a plain-valued predictor | **5.89×** leaner (304 320 → 51 652 B), same nodes, bit-identical value | same |
| **A segment re-run from a whole patch copy is exact — K93, FF16** | `max_abs` **0.00e+00** at every probed segment | `Rscript docs/reference/segment-rerecord-probe.R` |
| **…but NOT for TF24** | **1.84e-13 / 4.99e-11 / 1.30e-08** at segments 20 / 40 / 60; error in **`log_density`** | same |
| Rebuilt from `ode_state` alone, all models drift | K93 to **1.46e-05**, FF16 to 2.21e-22; error **exclusively** in `offspring_produced_survival_weighted` | same |
| The competition source weight is read **one stage stale** | settling twice makes FF16 *worse*: 1e-35 → 1e-14 at segment 20, 2e-22 → 1e-6 at 80. TF24 barely moves | same, `settle_twice = TRUE` |
| **L0 ⊆ L1** — every introduction time lies on the ODE grid | 141/141, 233/233, 161/161, and for TF24 141/141 | inline R over `ode_times` / `node_schedule$all_times` |
| **Steps per introduction segment** | K93 **1.23**, FF16 **1.87**, **TF24 18.43** (2 598 steps / 141 introductions) | same |

## 5. plant surface facts that cost time to find

| fact | where |
|---|---|
| `pr_patch_survival_at_birth` is **not** in `ode_state` and **divides the fecundity rate** | `node.h:74` says so; `node.h:217` does it |
| `patch_density_at_birth` and `node_introduction_time` feed **only** `weighted_fecundity` — so **census gradients do not need them** | `node.h:87`; only readers are `species.h:422,587` |
| `Individual` holds a **pointer** to the Strategy, so a Patch copy shares one `Leaf` | `individual.h:23` — the cause of TF24's inexact re-run |
| `Patch::r_set_state(time, state, counts, light)` is the whole restore | `patch.h:836-846`: reset, introduce per species, `set_ode_state`, install spline |
| `Species::set_birth_state(times, density, pr_survival)` exists, reached via `Parameters::initial_*` | `species.h:132`; `patch.h:386-400` |
| `set_state_from_system` already refreshes `dydt_in` from the system | `ode_solver_internal.hpp:160-166` — why a stale-first-stage fix was inert |
| `compute_environment` runs **before** `compute_rates` inside `set_ode_state` | `patch.h:884-889` — the source of the aux lag |
| `quadrature::QK` nodes are a **fixed** rule affinely mapped | `qk.h:81-84` — no adaptive structure in the crown integral |
| `Patch::r_at` **does not compile** (calls a nonexistent `at`) | `patch.h:179` — latent; nothing has instantiated it |
| `smooth_positive` used **3× in `ff16_strategy.h`, 0× in `tf24_environment.h`** | the soil clamps are unsmoothed; the runoff floor is a boundary a real trajectory crosses |

## 6. Suite state

| fact | number | re-run |
|---|---|---|
| odelia green | **0 fail / 535 pass / 5 skip** | `cd odelia && make test` |
| plant focused set | **524 pass / 2 fail / 1 error** — all pre-existing | install odelia, `load_all` plant, `test_file` per file |
| The 2 plant failures are **stale blessings** | `16.88946` blessed 2026-06-25; the shading model changed 2026-07-18/19/20 | `git log -S"16.88946"` |
| odelia surface after deletions | **19 headers** (was 23); 697 lines and 4 names removed | `ls odelia/inst/include/odelia/` |
| plant touches this many odelia names | **34** | `grep -rhoE "odelia::(ode::)?[A-Za-z_]*" plant/inst plant/src` |
