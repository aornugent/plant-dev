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

### The margin: how dry before the guard fires

At `lifetime = 3` (points are affordable there; the default-rainfall shape is the same as at 20):

| rainfall | min θ | as multiple of θ_r | layer-steps at guard | near guard | wall clock |
|---|---|---|---|---|---|
| 1 (default) | 0.1804 | **18×** | 0 | 0 | 8 s |
| 0.5 | 0.1310 | **13.1×** | 0 | 0 | 6 s |
| 0.2 | 0.1276 | **12.8×** | 0 | 0 | 114 s |
| 0.1 | 0.1296 | **13.0×** | 0 | 0 | 268 s |
| 0.05 | 0.1307 | **13.1×** | 0 | 0 | 385 s |
| **0** | — | — | — | — | **throws** (see below) |

**min θ plateaus rather than marching toward the guard** — a 10× rainfall reduction (1 → 0.1) moves it
only 18× → 13.0× θ_r, and from 0.5 down it is flat at **12.8–13.1×** and not even monotone.

### Why: BOTH water sinks shut off at ~12.5× θ_r, so the guard is structurally unreachable

The plateau's cause is not a lucky trajectory. It is arithmetic in the parameters, and the
discriminating number is where the root vulnerability curve hits `root_psi_crit` (5% conductivity,
`tf24_strategy.h:439-441`):

| θ | × θ_r | ψ_soil (MPa) | root conductivity | drainage K (m/yr) |
|---|---|---|---|---|
| 0.1804 (rain 1) | 18.0× | 0.519 | **0.996** | 1.4e-4 |
| 0.1310 (rain 0.5 **and** 0.05) | 13.1× | 4.25 | 0.283 | 8.2e-7 |
| 0.1296 (rain 0.1) | 13.0× | 4.56 | 0.218 | 6.9e-7 |
| 0.1276 (rain 0.2) | 12.8× | 5.05 | 0.135 | 5.4e-7 |
| **0.1247 = `root_psi_crit`** | **12.5×** | **5.87** | **0.05** | 3.7e-7 |
| 0.05 | 5.0× | 2 381 | **0** | 1.4e-13 |
| θ_r = 0.01 | 1.0× | 9.3e7 | **0** | 7.6e-25 |

**Every measured min θ sits immediately above 12.5× θ_r, the θ at which roots stop extracting.** Both
sinks vanish long before the guard: uptake because `root_conductivity → 0`, and drainage because
`K ∝ θ^(2n+3) = θ^16.14` collapses 9 orders of magnitude. The retention exponent `n_psi = 6.57` makes
ψ explode — 5.87 MPa at 12.5× θ_r against **9.3e7 MPa** at θ_r — so nothing can push the layer down
there. Re-run: the arithmetic is `a_psi=1.78e3, n_psi=6.57, θ_sat=0.428, K_sat=163.04`
(`tf24_environment.h:88-92`) and `root_b=3.898245, root_c=2.680147` (`tf24_strategy.h:439-441`).

**Consequence: the drying guard at `:335` does not fire anywhere the model runs, and needs no
smoothing.** The sweep covers rainfall **1 → 0.05**, a 20× reduction, with the guard untouched and
min θ flat at 12.8–13.1× θ_r throughout — and the endpoint is now explained rather than assumed:

| fact | detail |
|---|---|
| **Rainfall exactly 0 throws, and NOT on anything soil-related** | `Non-finite cohort density in the SCM size-density (characteristic) equations: species 1 has a node with density=inf (log_density=58514.5, height=2.11) at time=1.25` |
| What that is | plant's **own** guard: at zero rainfall growth falls steeply with size, so the density derivative `-d(growth)/d(height) - mortality` grows without bound and overflows. Its message advises a shorter lifetime or less extreme drivers |

**This closes the question in the same direction:** under extreme drought the **plants** fail first —
the characteristic equation overflows at t ≈ 1.25 — while the soil is still ~13× θ_r. Rainfall 0 is
outside the model's valid operating range by its own guard, so "does not fire anywhere the model runs"
is literally accurate rather than a hedge.

**A bound worth knowing for any drought study:** an FD or a gradient taken *across* a rainfall
gradient cannot include rainfall 0 — the forward model throws there before any derivative is at issue.
**What would change that** (the kill condition for this conclusion): a materially flatter retention
curve (smaller `n_psi`), a much larger `root_psi_crit`, or any new sink that drains a layer without
going through root conductivity or `soil_K`. Re-derive the 12.5× if any of those three move.
Extreme-drought points (0.1 / 0.05 / 0) are **still open** (task #38).

**Cost note, and it is why this took three attempts:** drier drivers are drastically slower — 6 s at
rainfall 0.5 against **114 s** at 0.2, same lifetime. Run points one at a time.

**Two mechanical traps that cost two runs here, both mine:** do not pipe the driver through `tail`
(the buffer means a timeout discards every point already computed — one attempt died at its 3000 s
timeout having emitted nothing); and `pkill -f <pattern>` **matches its own bash wrapper's command
line**, so it killed the shell before the heredoc that was to write the next script, leaving a stale
same-named file from an earlier session to run instead.

## 3c. What one unit costs in plant — the design's absolute wall clock

The design's headline is "a flat **4.2×** the whole-run reverse pass", which is a *ratio* measured on
an odelia toy at ~22 µs/unit. Nobody had measured the absolute, and the toy's restore is
`set_ode_state` over a handful of doubles where plant's reinstalls the light spline and re-runs
`compute_environment` **and** `compute_rates` over every cohort. Measured in double, at the widest
segment each lifetime reaches; `Rscript docs/reference/unit-cost-probe.R`:

| | cohorts | copy | **restore** | advance / step | one-step unit | restore share |
|---|---|---|---|---|---|---|
| FF16 life 10 | 92 | 109 µs | 318 µs | 1 648 µs | 2 075 µs | 15.3% |
| FF16 life 20 | 97 | 30 µs | 221 µs | 1 677 µs | 1 928 µs | 11.4% |
| TF24 life 10 | 92 | 89 µs | 2 825 µs | 15 600 µs | 18 515 µs | 15.3% |
| TF24 life 20 | 97 | 91 µs | 2 928 µs | 17 712 µs | 20 731 µs | 14.1% |

**The restore is NOT the bottleneck — 11–15% of a unit.** That was the worry (2 598 restores each
rebuilding the environment over 987 cohorts) and it is refuted: the rate evaluation dominates, as it
does in the forward pass.

**What it implies for production.** **CORRECTED** — the first version of this row scaled 97 → 987
"cohorts" and reported ~9 minutes in double and ~40 minutes per gradient. That was wrong by ≈7×:
**987 is node *states*, not cohorts.** TF24 carries **7 ODE components per node** ((688−9)/97 = 7.0
measured by this probe), so 987 node states is **141 cohorts** — which is exactly the 141 introductions
in §1. The extrapolation from 97 cohorts is therefore **1.45×, not 10×**:

| | per sweep, double | at the measured 4.2× AD factor |
|---|---|---|
| FF16 | ~0.5 s | ~2 s |
| **TF24** | **~78 s** | **~5.5 min per gradient** |

**Independently corroborated by the develop benchmark below:** a whole TF24 forward run is 50 s over
2 599 steps (19.4 ms/step averaged across growing width, against this probe's 17.7 ms/step at 97
cohorts — so per-step cost is roughly flat, as the tape is). A sweep re-runs each unit once
(recompute factor 1) plus restores at 11–15%, so ≈58 s in double and ≈4 min per gradient by that
route. Two independent estimates landing at 4–6 minutes.

**Caveats that remain:** double not active; the probed segment is the most step-dense in the run, so
`advance/step` may be pessimistic.

### The develop baseline — is the branch slower than the forward model it started from?

Owner's ask, session 22: *"run a TF24 benchmark on develop before continuing. I think the default run
used to be < 60%"* — read as wall-clock seconds.

| | wall clock | ODE steps | per step |
|---|---|---|---|
| `develop` (plant 141dc8df + odelia master) | **49.57 s** | 2 621 | 18.91 ms |
| this branch | **50.31 s** | 2 599 | 19.36 ms |

**No regression: +1.5% wall clock, +2.4% per step**, and **both under 60 s**, so the recollection holds.
The AD work has not slowed the forward model, which means the memory and time projections above rest
on a sound baseline. Re-run: `./docs/reference/tf24-develop-benchmark.sh` (~15 min — two package installs) — and note **develop's plant has
`LinkingTo: odelia`**, so the benchmark installs odelia@master *and* plant@develop into a **separate
library** via git worktrees. Installing either into the default library would clobber the plant that
this branch's odelia links against.

## 4. Replay: what reproduces and what does not

| fact | number | re-run |
|---|---|---|
| An adaptive node set is **bit-identical** built plain or active, nothing recorded | 149 nodes, 0 mismatches, `max_abs_diff` **exactly 0** | `test-ad-adaptive-structure.R` (27 assertions) |
| Refining through a plain-valued predictor | **5.89×** leaner (304 320 → 51 652 B), same nodes, bit-identical value | same |
| **A segment re-run from a whole patch copy is exact — K93, FF16** | `max_abs` **0.00e+00** at every probed segment | `Rscript docs/reference/segment-rerecord-probe.R` |
| **…but NOT for TF24** | **1.84e-13 / 4.99e-11 / 1.30e-08** at segments 20 / 40 / 60; worst component **`fecundity`** (20, 40) and **`area_heartwood`** (60) | `Rscript docs/reference/leaf-staleness-probe.R` |
| **CAUSE CONFIRMED — it is stale shared `Leaf` state, and nothing else** | replaying a segment **inline** (before the forward pass advances past it, so the leaf holds that segment's own state) is **exactly 0.00e+00** at segments 20 / 40 / 60, where the **deferred** replay of the identical segment against the identical reference gives 1.84e-13 / 4.99e-11 / 1.30e-08 | same |
| The controls behave as they must | FF16 and K93 — no leaf — are **exactly 0 in both columns**, all three segments | same |
| Rebuilt from `ode_state` alone, all models drift | K93 to **1.46e-05**, FF16 to 2.21e-22; error **exclusively** in `offspring_produced_survival_weighted` | same |
| The competition source weight is read **one stage stale** | settling twice makes FF16 *worse*: 1e-35 → 1e-14 at segment 20, 2e-22 → 1e-6 at 80. TF24 barely moves | same, `settle_twice = TRUE` |
| **L0 ⊆ L1** — every introduction time lies on the ODE grid | 141/141, 233/233, 161/161, and for TF24 141/141 | inline R over `ode_times` / `node_schedule$all_times` |
| **Steps per introduction segment** | K93 **1.23**, FF16 **1.87**, **TF24 18.43** (2 598 steps / 141 introductions) | same |

### 4b. The restore path — what `r_set_state` drops, and how bad the drift really is

**The two columns of `segment-rerecord-probe` are two different storage models, and only one is the
design's.** `from_copy_abs` stores a whole `Patch` per unit; `rebuilt_abs` stores plain values and
restores — and the design stores plain values (`unit-cost-probe`'s unit is `Patch unit = mould;`
then `r_set_state`). So **the exactness facts above belong to the copy path, and the design runs on
the drifting one.** Anyone quoting "K93 replays bit-exactly" for the sweep is quoting the wrong
column.

**How bad is it? Far less than the raw columns suggest — read the reference magnitude, not the
error.** `Rscript docs/reference/restore-stamp-probe.R` reports the forward value at the
worst-absolute component:

| model | segment | worst-abs error | reference there | what it means |
|---|---|---|---|---|
| TF24 | 90 | **5.47** (`log_density`) | **−328** | density e^−328 ≈ **1e-143** — a numerically extinct cohort |
| TF24 | 80 | 3.45e-05 (`log_density`) | 1.71 | **a live cohort: ~2e-5 relative. This is the honest worst case** |
| TF24 | 10–70 | ≤1.46e-07 | 3.20 | ~5e-8 relative |
| K93 / FF16 | ≤90 | ≤1.65e-15 | 1e-20 … 1e-11 | on vanishing quantities |

So the alarming headline figures — an absolute **5.47** and a **45% relative** — live entirely on
dead cohorts, and the relative column is inflated wherever the reference is ~1e-27. **The design's
restore path is good to ~2e-5 relative on live state.** That is not bit-exactness, so the closing FD
gate needs a stated tolerance rather than an equality; it is nowhere near a sinking error.

**Confirmed contributor: `r_set_state` silently drops the birth stamps.** It restores the ODE state,
the per-species node counts and the light spline, and **nothing else** (`patch.h:832-847`). Each node
also carries three birth stamps (introduction time, patch density at birth,
`pr_patch_survival_at_birth`); the fecundity rate divides by the last, and patch survival decays with
patch age, so the cost grows with segment index — which is exactly the observed shape, landing exactly
in `offspring_produced_survival_weighted`. Restoring them via `Species::set_birth_state` improves the
relative error **~10× (FF16: 1.62e-01 → 2.01e-02 at segment 90)** and **~17× (TF24: 4.50e-01 →
2.69e-02)**, and leaves the absolute untouched (the absolute worst is the dead cohort, which no stamp
affects). Same probe.

| fact | number | re-run |
|---|---|---|
| **There is NO public API to restore the birth stamps** | `Patch::at_species()` is const-only and `species` is private; `set_birth_state` exists on `Species` but is unreachable from outside. The probe `const_cast`s | `restore-stamp-probe.cpp` header |
| **The aux lag needs NO per-step storage — settle exactly once** | double-settling makes FF16 **worse by 10 orders** (1.50e-36 → 1.61e-15 at segment 10; 1.65e-15 → 1.91e-05 at 90) and does not rescue TF24 (5.47 → 3.70e-01, still the dead cohort) | `segment-rerecord-probe`, `settle_twice = TRUE` |

**Consequence for the design:** the stored unit's requirement list is now *measured*, not assumed —
state, per-species counts, light spline, **and the three birth stamps** — and the last of those needs
a plant API that does not exist yet. The aux question that `v3-control-flow.md` left open ("check on
TF24 first") is **closed: one settle, no aux storage.**

### 4c. Two species — and the hard constraint the separable field turns out to carry

Every other number in this file was measured with **exactly one species**. Three things fall out;
`NOT_CRAN=true Rscript docs/reference/two-species-probe.R`.

**(A) THE SEPARABLE FIELD IS ONLY VALID IF ALL SPECIES SHARE `eta`. This is a constraint, not a
tolerance.** The rank-3 factorisation is exact by algebra — query factors `{1, −2z^η, z^2η}` dotted
with source factors `{1, H^−η, H^−2η}` give `(1−(z/H)^η)²` — **but only when the same η appears in
both** (`canopy_shape.h:198-211`). `Patch::assemble_competition_field` builds source factors from each
species' own canopy inside its per-species loop (`patch.h:698`) and then takes the query factors from
**species 0's canopy alone** (`patch.h:757-759`, commented "any cohort's canopy (shared shape)"). With
two species of different η the mixture does not merely lose accuracy, **it diverges**:

| η_query | η_source | exact `Q` at z=9, H=10 | what the field computes | abs error |
|---|---|---|---|---|
| 12 | 12 | — | — | **0** — exact, as designed |
| 12 | 10 | 0.4242 | **742.2** | 7.4e+02 |
| 12 | 8 | 0.3244 | **7.97e+06** | 7.97e+06 |
| 12 | 4 | 0.1183 | **7.98e+14** | 7.98e+14 |

A shading factor must lie in [0,1]; these are 1e+14. "Shared shape" is an **assumption written as a
comment**, and η is a per-strategy trait carried as `S` *and a differentiation target*. Either the
design states "one η per community" as a precondition enforced by structure, or the field needs one
query-factor block per distinct η (rank 3 → 3×n_η). **Do not build multi-species on the field before
choosing.** Note this is measured against the exact kernel with no SCM run, deliberately: a
two-species FF16 SCM is too fragile to carry the test (η=2, and η=4 at `birth_rate` 20 over a 20-year
lifetime, both trip plant's own non-finite-density guard, and at 12 steps the field is still exactly
1.0 everywhere so the comparison is vacuous).

**(B) Tie-break determinism holds across a rebuild — the worry was unfounded.** Sources merge in
descending height with ties broken on the flat concatenated index (`patch.h:741-748`), and that index
is a function of species order and per-species counts, both restored. Measured on two K93 species
(differing in `b_0`, so no η problem): `copy_abs` is **exactly 0.00e+00 at every probed segment**, and
`rebuilt_abs` matches the one-species figures (7.68e-18 → 1.71e-05, the `r_set_state` stamp drift of
§4b). **Two species add no new replay error.** Caveat, and it is a real gap: both species are
introduced on the same schedule, so their widths were **equal at every segment** (10/10 … 90/90) — the
differing-width case is still untested.

**(C) An empty first species is latent UB, not yet witnessed.** The per-species loop skips empty
species (`m == 0`) and the function early-returns only when the **total** source count is zero, so
species 0 empty with species 1 non-empty reaches `patch.h:758` and calls `node_begin()->individual` on
an empty vector. Measured reachability on an ordinary two-species run: **0 segments**. So it is
unreachable *on this schedule*, and undefended in general — the probe counts the state and never
dereferences it.

### 4d. The first plant witness of a unit under AD — and what decides adjoint accumulation

Every exactness/peak/time number for the sweep had been an **odelia toy**; this is a unit running
under the active scalar **in plant**, FD-verified. K93, 2 and 4 units from segment 40, trajectory
frozen (units restored from stored plain values, so the state entering is a tape constant and the
**trait channel alone** is measured; the FD reference perturbs the same trait and re-runs the same
units from the same stored states, so AD and FD are the same functional).
`NOT_CRAN=true Rscript docs/reference/unit-adjoint-probe.R`

**The accumulation worry resolves into a CONDITIONAL, and ownership decides it.** `Individual` holds
`strategy_type_ptr` = **`std::shared_ptr`** (`k93_strategy.h:68`), and `Species::ad_parameters()`
returns `strategy->field_ptrs()` (`species.h:141-142`) — pointers into that one shared Strategy's
`pars`. Measured by pointer identity:

| arrangement | shares the seeded address? | consequence |
|---|---|---|
| **Patch COPY** (what the design does — copy the mould) | **YES** | one AD input; **adjoints accumulate automatically** |
| Patch built fresh from `Parameters` (Leaf-fix candidate 1's shape) | **no** | a **distinct** input per unit; one read = one unit |

| quantity | 2 units | 4 units |
|---|---|---|
| value | 166.0586674 | 340.138723 |
| shared-Strategy adjoint | 0.1621656777 | 0.4181440068 |
| **sum of per-unit adjoints** | 0.1621656777 | 0.4181440068 |
| rel \|sum − shared\| | **0.00e+00** | **1.33e-16** |
| rel \|AD − FD\| | **3.37e-09** (at `d_rel` 1e-3) | 1.2e-06 at 1e-6 |
| **one unit's adjoint alone, as % of the total** | **50.6%** | **41.1%** |
| **tape per unit, restore included** | **956 350 B / 43 864 ops** | 980 044 B / 44 938 ops |

**So the hazard is not present in the design as written — and Leaf-fix candidate 1 would CREATE it.**
That couples #37 and #40 by a mechanism rather than a suspicion: if units get their own Strategy, the
sweep must sum the trait adjoints over every unit, and omitting that returns **~41–51% of the right
answer with the right sign and nothing thrown**.

**The FD reference was verified before the ratio was trusted** (the Part 1 rule). Its error is
**roundoff-dominated**, so it improves as δ *grows*: 3.37e-09 at `d_rel` 1e-3, 1.6e-07 at 1e-5,
1.14e-05 at 1e-7, 2.56e-04 at 1e-8. The 1e-06 first seen at `d_rel` 1e-6 was the FD's noise floor,
not an AD error.

**Per-unit tape, which the ~89 MB estimate omitted (`#42`): ~0.96 MB for K93 at ~40 cohorts, and it
barely moves with unit count** (956 kB → 980 kB from 2 to 4 units), i.e. it is per-unit as the design
assumes rather than accumulating. This is K93, not TF24, so it bounds the shape of the cost, not its
production magnitude.

## 5. plant surface facts that cost time to find

| fact | where |
|---|---|
| `pr_patch_survival_at_birth` is **not** in `ode_state` and **divides the fecundity rate** | `node.h:74` says so; `node.h:217` does it |
| `patch_density_at_birth` and `node_introduction_time` feed **only** `weighted_fecundity` — so **census gradients do not need them** | `node.h:87`; only readers are `species.h:422,587` |
| `Individual` holds a **pointer** to the Strategy, so a Patch copy shares one `Leaf` | `individual.h:23` — the cause of TF24's inexact re-run |
| **`SpeciesBase` holds the one `shared_ptr`; every Node holds a copy of it** | `species.h:31,158`; `strategy.h:20` — so re-seating a per-unit Strategy copy must reach the Species **and every Node**, and `Individual`'s only entry point is its constructor. A half-re-seated patch is a silently mixed state |
| **`field_ptrs()` returns pointers INTO the Strategy instance** | `species.h:142`, `strategy.h:141-142` — so a per-unit Strategy copy means each unit seeds a *different* set of AD inputs, and trait adjoints must be **accumulated across units** rather than read once at the end. The copy and the accumulation are **one decision, not two**: getting it wrong yields a gradient that is silently only the last unit's contribution |
| **`Leaf` has no structural boundary between parameters and per-solve scratch** | `leaf_model.h:139-200` — ~30 loose `double`s, 5 `std::vector<double>` and 4 `Interpolator`s interleaved, with nothing marking which are transient. This is *why* the "audit every cache" option decays, and it is an independent argument for the copy |
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
