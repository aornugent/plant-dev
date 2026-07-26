# P1 — the setup-caching contradiction, resolved; and the duplicate anchor sweep it exposed

*2026-07-26. P1 was scheduled as a pure measurement: our record contradicted itself about
whether the ~11-unit per-member setup is `u`-independent and cacheable per macro interval. The
measurement settled that question — and then made it largely irrelevant, by exposing a bigger and
simpler saving in the same place.*

## 1. The contradiction, and the answer

**The setup IS `u`-independent.** Read off the source first, so the measurement could falsify rather
than confirm: `Leaf::set_physiology` takes `psi_soil` as an argument but only *stores* it. Every
expensive line in it — the per-layer root resistance network (`r_R_H_min`, `r_R_V`, `r_R_V_sum`,
`c_r_*`), `grav_head_z_`, the Arrhenius temperature block, electron transport — is a function of
`mass_root_prop` / `dz` / temperature. The `u`-dependent soil-side caches (`psi_soil_inverted_`,
`root_vuln_integral_soil_`) are built one level down, in `prepare_collar_solve`, inside the solve.

Measured (`scripts/tf24-benchmarks/setup_cache_probe.R`, production tolerances `GSS_tol_abs` /
`ci_abs_tol` = 1e-6, not the 1e-12 gate tolerances — the argmax cost scales with the tolerance, so
measuring at 1e-12 would have overstated the solve and flattered the "setup is negligible" answer):

| soil state | setup µs | solve µs | setup share | cached path | cached == fresh |
|---|---|---|---|---|---|
| wet (ψ 0.05) | 12.5 | 19.9 | 38.5% | 1.30× | bit-identical |
| mid (ψ 0.8) | 12.8 | 20.2 | 38.9% | 1.29× | bit-identical |
| dry (ψ 1.6) | 18.6 | 20.8 | 47.3% | 1.27× | bit-identical |
| graded (0.1→1.9) | 11.9 | 20.4 | 36.8% | 1.31× | bit-identical |

So: **the setup is 37–47% of a member sweep, and reusing it across soil states is bit-identical in
every state tested.** The earlier claim was right and the later one was wrong.

Two caveats on the numbers. The share counts `Leaf::set_physiology` only; the allocation/geometry
block in `TF24_Strategy::net_mass_production_dt` (masses, the `Q()` root distribution, `kmax`) is
also `u`-independent but is not separately timeable from R, so 37–47% is a **lower bound**. And the
1.27–1.31× "cached path" carries R-side field-assignment overhead a C++ implementation would not
pay; removing the setup entirely is 1.66× per sweep.

## 2. Why the answer does not buy what the old claim promised

The projected win was "cache the setup across all four sweeps of a leg ⇒ up to half the member-loop
cost". **That does not follow, because the four sweeps do not differ by `u` — they differ by cohort
state.** From `mri_macro_step` (odelia `mri.hpp:424-444`), a leg with the 3-node kutta3 coupling runs:

```
F[0] = slow_rates(x0, u0)                        <- member sweep 1
freeze_slow(x0); subcycle(u0) -> refresh_anchor  <- member sweep 2, at (x0, u0)
x0 -> x1
F[1] = slow_rates(x1, u1)                        <- member sweep 3
freeze_slow(x1); subcycle(u1) -> refresh_anchor  <- member sweep 4, at (x1, u1)
```

`x` is advanced between stages, so `area_leaf`, `mass_root_prop` and `kmax` all move: the setup is
not shareable between sweep 1 and sweep 3. The setup cache is only available where cohorts are
frozen and `u` alone moves — i.e. across mid-subcycle re-expansions, which §3 shows are **zero** in
every benign regime. The cacheable case is real but almost never exercised.

## 3. What the measurement actually found: half the sweeps are exact duplicates

Sweeps 2 and 4 evaluate the member loop at exactly the `(x, u)` their immediately preceding
`slow_rates` just evaluated it at. And `slow_rates` already computes both anchor quantities:
`compute_rates()` → `compute_species_rates()` + `assemble_resource_depletion()` *is* `a₀`, and with
`control.compute_uptake_jacobian` on, the per-cohort Jacobians are already filled so
`assemble_duptake_jacobian()` is pure aggregation (25 accumulations over M cohorts, no leaf solves —
`patch.h:1036`). **The anchor sweep is a full duplicate of a sweep that just ran.**

Counter arithmetic confirms it with no instrumentation, on the 30-yr constant-rainfall gate:
`fast_rate_calls 132320 / (40 nmicro × 2 subcycles) = 1654 legs`, and
`coupling_evals = 3308 = 2 × 1654` **exactly** — two captures per leg, one per subcycle start, zero
residue. Across the survivable dynamic regime
(`scripts/tf24-benchmarks/anchor_redundancy_probe.R`, life=40, birth=20, weekly leg):

| rainfall amp | offspring | legs | captures | duplicates | genuine | genuine/leg | duplicate share |
|---|---|---|---|---|---|---|---|
| 0.0 | 45.13 | 2179 | 4358 | 4358 | 0 | 0.000 | **100.0%** |
| 0.3 | 35.12 | 2179 | 4358 | 4358 | 0 | 0.000 | **100.0%** |
| 0.6 | 0.658 | 2179 | 4358 | 4358 | 0 | 0.000 | **100.0%** |
| 0.9 | 0.0185 | 2179 | 5140 | 4358 | 782 | 0.359 | 84.8% |

Genuine re-expansions appear only at amp=0.9, where the stand is collapsing toward extinction
(offspring 0.018 — the lesson-#4 regime). Everywhere the model is alive, **every single O(M) anchor
sweep is redundant work.**

## 3a. ⚠ The "duplicate" reading is WRONG — the fix was built, measured, and REVERTED

**The counters in §3 prove the two sweeps happen at the same call sites with the same nominal
`(x, u)`. They do not prove the two sweeps compute the same values, and I inferred that they did
without measuring it. They do not.**

Built anyway (`slow_rates` publishes; `refresh_anchor` returns early on a bitwise theta match) and
gated. Mechanically it worked exactly as predicted:

| metric | before | after |
|---|---|---|
| anchor captures (amp 0/0.3/0.6) | 4358 | **0** |
| member sweeps / leg | 4.00 | **2.00** |
| wall-clock (amp=0.3) | 124 s | **81 s (1.53×)** |
| genuine captures at amp=0.9 | 782 predicted | **783 actual** |

**But J moved:** 35.1212 → 34.5828 at amp=0.3 (1.5e-2), ~4× the weekly-leg error the scheme was
being trusted at. The skip was supposed to be exact by construction, so any drift falsifies the
premise. A direct diagnostic (`anchor_skip_diag.R`: on a matched theta, sweep anyway and compare
published vs swept) measured the discrepancy rather than arguing about it:

```
amp=0.0  skips=1208  max_rel_diff=3.487e-05
amp=0.3  skips=1208  max_rel_diff=2.454e-02
```

**So the anchor published by `slow_rates` and the anchor `refresh_anchor` computes are genuinely
different values, at the same nominal `(x, u)`.** The subcycle-start capture is *not* redundant
work; it evaluates uptake in a context that differs materially from the one the slow stage saw. The
change is reverted; `patch.h` is back at the pre-session baseline.

**Why the error survived to a build.** Two compounding mistakes, both worth naming:
1. I inferred the capture site from a nearby code path instead of reading it. The capture at
   `mri.hpp:325` is **unconditional** ("mandatory leg-start capture"), not monitor-gated — so the
   first version of the change did nothing at all.
2. From that misreading I constructed a "free bit-identity proof via the trust monitor", which made
   the change appear *self*-validating and removed the very check that would have caught the
   problem. **An argument that proves your change is exact is worth as much as a reference that
   flatters your method** (cf. hard-won lesson #7) — both suppress the instinct to measure.

**The open question this leaves, which is worth more than the fusion was.** Two evaluations of the
member loop at the same cohort state and the same soil state differ by up to 2.4e-2. The only
asymmetry visible in the source is that `slow_rates` calls `compute_environment(true)` and then
`freeze_slow(x)` calls it *again* before the subcycle sweeps — but `rescale_spline` with an
unchanged `height_max` maps knots to themselves, so that *should* be idempotent. Either it is not,
or something else in the sweep carries state across calls. Either way it means **the light field the
cohorts see depends on how many times `compute_environment` has been called, not only on the
state** — a hidden path-dependence in the model, not the solver.

**Next step, and a trap in it.** The test is: hold the patch state fixed, call `compute_environment`
repeatedly, read `resource_depletion` after each, and see whether reading 2 differs from reading 1.
**The trap:** `Patch::r_compute_environment` (the R-exposed one) hardcodes `compute_environment(false)`
— the `construct_spline` branch — whereas `slow_rates` and `freeze_slow` both pass `true`, the
`rescale_spline` branch. A test written against the R hook as it stands would exercise the wrong
branch and return a falsely reassuring "idempotent". The test needs a temporary R hook taking the
`rescale` flag. (A script doing it the wrong way was written and deleted rather than committed.)

Also note the amplitude dependence in the diagnostic: 3.5e-5 at amp=0 versus 2.454e-02 at amp=0.3.
The discrepancy grows with *rainfall* forcing, which drives the soil, not the light field — so the
`compute_environment` explanation above is a hypothesis with a fact already sitting awkwardly beside
it, and the idempotence test should be treated as a falsifier rather than a confirmation.

**Do not attempt the fusion again until this is understood.**

## 4. The fix as designed (reverted — kept for the record)

`Patch::slow_rates` publishes the anchor it has already computed (`publish_anchor`, three
assignments plus a guard); the subcycle then opens with `trust_excursion == 0` and does not
re-capture. **A leg costs 2 member sweeps instead of 4.** No cache, no epoch counter, no
invalidation protocol, no new control key, no odelia change.

Safety rests on what an anchor *is*: **a linearization point, not a cached truth.** The trust
monitor measures excursion from the anchor's own θ and re-captures when it grows, so a
badly-placed anchor cannot corrupt the trajectory — it can only cost the refresh we were trying to
avoid. The one thing the monitor does not police is `x`-staleness, which rests on `mri_macro_step`
calling `freeze_slow(x)` with the same `x` it just passed to `slow_rates` — one ordering, in one
five-line function, documented at the publish site. If an adaptive-H schedule ever decouples slow
stages from sub-intervals (P4), the publish must be keyed on the slow state instead.

**The bit-identity check comes free from the same mechanism.** If the published anchor differed at
all from what `refresh_anchor` would have computed, the excursion at the first micro-step would be
nonzero and the monitor would re-capture. So in the regimes measured to have zero genuine
re-expansions, a post-change count of **exactly 0** proves the values are identical — a stronger
statement than comparing printed offspring digits.

## 5. Result

**Cost mechanism: works (2.00 sweeps/leg, 1.53× wall-clock). Accuracy: FAILS (J moves 1.5e-2).
Reverted.** See §3a. What survives from this session is the P1 measurement (§1–2), the
duplicate/genuine capture decomposition (§3, which is a correct *call-site* accounting), the
re-established gate headline (2.42e-3 at 40×), and a sharp new open question about
`compute_environment` path-dependence.

## 6. What this changes for the plan

- **P2 is BLOCKED, not superseded, and not by its arithmetic.** The handoff proposed fusing the
  anchor capture with the slow advance's first stage (4 → 3 sweeps, ~25%). The sweep counting says
  the ceiling is really 4 → 2, and the machinery to claim it is trivial — but §3a shows the two
  sweeps do not produce the same values, so *any* fusion (P2's or mine) changes results until the
  2.4e-2 discrepancy is explained. **Do not re-attempt P2 before running the idempotence test.**
- **The setup cache is demoted, not dead.** At 37–47% of a sweep it is the largest remaining
  per-sweep item, but it can only be shared where cohorts are frozen — i.e. across mid-subcycle
  re-expansions, measured at 0/leg in benign regimes and 0.36/leg at amp=0.9. It is worth building
  only if a later change (P4's adaptive H, or a coarser trust tol) raises the re-expansion rate.
- **Stop quoting `cheap/expensive` as the cost metric.** Once the duplicates are gone the
  denominator is ~0 and the ratio is meaningless. The scaling quantity is **member sweeps per leg**.
