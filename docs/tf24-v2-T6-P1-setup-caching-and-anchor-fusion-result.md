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

## 4. The fix, and why it needs no caching machinery

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

*(gate: `scripts/tf24-benchmarks/anchor_fusion_gate.R` — filled in below once run)*

## 6. What this changes for the plan

- **P2 as written in the handoff is superseded.** It proposed fusing the anchor capture with the
  slow advance's first stage for 4 → 3 sweeps (~25%). The actual redundancy is 2 of 4 sweeps,
  affecting *both* sub-intervals, so the win is **4 → 2 (50%)** and it needs no fusion of differing
  quantities — only not recomputing.
- **The setup cache is demoted, not dead.** At 37–47% of a sweep it is the largest remaining
  per-sweep item, but it can only be shared where cohorts are frozen — i.e. across mid-subcycle
  re-expansions, measured at 0/leg in benign regimes and 0.36/leg at amp=0.9. It is worth building
  only if a later change (P4's adaptive H, or a coarser trust tol) raises the re-expansion rate.
- **Stop quoting `cheap/expensive` as the cost metric.** Once the duplicates are gone the
  denominator is ~0 and the ratio is meaningless. The scaling quantity is **member sweeps per leg**.
