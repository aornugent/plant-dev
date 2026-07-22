# T6 Slice 3b-i — stand ∂a/∂u (uptake Jacobian) as a gated member-loop byproduct: BUILT + VALIDATED

*2026-07-22. Aggregates the validated per-leaf uptake Jacobian (Slice 3a) over the
cohort distribution into the stand coupling Jacobian ∂a/∂θ the multirate macro-step
refresh needs. plant `Patch::assemble_duptake_jacobian`, filled per-cohort in
`TF24_Strategy::compute_rates` behind `control.compute_uptake_jacobian`. Gated
analytic-vs-central-difference of the stand aggregate `a` across a wet→dry bank.*

## What was built (mirrors the `consumption_rate` chain 1:1)

Stand `a_i = (1/area) Σ_species trapezium_ρ(cohort consumption_rate[i])`
(`Patch::assemble_resource_depletion`). The Jacobian follows the same chain:

- **Storage (generic):** `Internals::duptake_jacobian`, row-major `i*ns+k` =
  d(consumption_rate[i])/d(θ_k), already in soil-moisture (ODE-state) space.
  Empty unless the gated fill runs → **zero overhead, bit-identical when off**.
- **Fill (TF24, gated):** in `compute_rates`, right after `set_consumption_rate`,
  the leaf is at its operating point (the collar solve ran in `net_mass_production_dt`),
  so `leaf.compute_duptake_dpsi_soil()` (Slice 3a) reuses it — no re-solve. Store
  `d(consumption_rate[i])/d(θ_k) = leaf.duptake_dpsi_soil_[i*ns+k] · ret_k · area_leaf · W`,
  with the **same weight** `W = 60·60·12·365/1000·kg_per_mol_h2o` and `area_leaf`
  that `set_consumption_rate` applies, and the **retention chain** `ret_k` folded in
  so all aggregation above stays env-agnostic. Shut-down cohorts (`E_up_==0`) keep a
  zero row (they also drop out of `consumption_rate`).
- **Retention (TF24 env):** `duptake_retention_factor(k) = d(ψ_inverted_k)/d(θ_k) =
  +n_ψ·ψ_mag/θ` (interior; 0 where the retention curve is floored at residual or
  capped at `soil_psi_max_`). Verified **exact** against a numerical dψ/dθ of
  `psi_from_soil_moist` at wet/mid/dry (0.12531 = 0.12531 wet, to full precision).
- **Aggregate (generic):** `Patch::assemble_duptake_jacobian` = density-weighted
  trapezium (`Species::duptake_jacobian_rate`) summed over species / area — the exact
  structure of `assemble_resource_depletion`. `ns` is inferred from the stored
  per-cohort vector (env-agnostic; the method compiles for the FF16/K93 patches too
  and returns empty there).

Nothing on the production path reads the field; `control.compute_uptake_jacobian`
defaults false. **Bit-identical verified**: SCM offspring OFF == ON to the last bit
(20.74297971123531, abs diff 0.0). All TF24/leaf/patch/species/node/scm suites green.

## Gate: analytic stand ∂a/∂θ vs central-difference of stand `a`

Script `scripts/tf24-benchmarks/duptake_stand_gate.R`. Realistic frozen cohort
distribution (~103 nodes from a 30-yr SCM run), 33 non-shutdown soil states swept
wet→dry (θ ∈ [0.05, 0.39], θ_sat=0.428), tight inner tol (GSS/ci 1e-12). The stand
`a` (`Patch::resource_depletion`, R-exposed) is central-differenced w.r.t. each soil
slot with **adaptive per-column step** (Richardson plateau) because the true coupling
spans ~3 orders of magnitude (retention huge near dry, ~0 near saturation) — no single
FD step clears the solve-noise floor in wet while resolving the strong dry curvature.

| cut | rel(max-entry) |
|---|---|
| **DRY tercile** (θ < 0.162; strong coupling, P2's predictable regime) | med **1.0e-5**, p90 5.6e-5, max **1.9e-3** |
| **FD-trustworthy** (fd_floor < 1e-2, i.e. FD actually resolved it; 14/33) | med **1.8e-5**, max 1.4e-2 |
| **abs error / global scale** (global_scale=30.8, the dry-dominant coupling) | med **1.2e-4**, p90 1.3e-3, max **2.3e-3** |

Meets the ~1e-3 target across the bank. Every high per-state *relative* error is a
**wet** state where `relmax ≲ fd_floor` — the FD reference is noise-limited (there the
true coupling scale is ~0.03 vs 30.8 dry), not the analytic Jacobian. An h-sweep
confirms it: as the step grows out of the noise floor, the wet FD **converges to** the
analytic value (relmax 0.89 → 0.047), so D_analytic is correct there too.

## The debugging that mattered (recorded so it isn't repeated)

- First gate (fixed small h, default tol): uniform ~5% error. **Not** a real failure —
  the operating-point re-solve at default tol ~1e-6 swamps the weakly-coupled
  off-diagonal response of the dominant layer-1 uptake at h~1e-6. Tightening inner tol
  to 1e-12 fixed the dry/mid tercile (→1e-5) and exposed the wet regime as genuinely
  FD-hard (tiny signal), not wrong.
- Wet "100% error" was the FD reference collapsing into noise (non-symmetric,
  sign-flipping columns) while the analytic Jacobian stayed symmetric and correct.
  Diagnosed by an h-sweep (FD → analytic as h clears noise) and by an **exact** check
  of the retention factor. Lesson: when a gradient gate fails only where the true
  gradient is near zero, suspect the FD reference's noise floor before the analytic
  side — confirm with an h-sweep and an independent check of each chain factor.

## Caveats / carried forward
- The fill runs `compute_duptake_dpsi_soil` per cohort → expensive when the flag is on;
  it is an offline-gating / macro-step tool, not for production hot loops. Slice 3b-iii
  moves the trigger into the frozen macro-step context (the field/accessors are
  unchanged; only the trigger moves).
- Wet-window coupling is genuinely tiny (retention → 0 as soil saturates); the refresh
  error it contributes is negligible in absolute terms next to the dry-limit coupling.
- Interior↔boundary per-leaf kinks (Slice 3a) still apply per cohort; the macro-step
  trust monitor (3b-ii/iii) guards windows that straddle them.

## Next (Slice 3b-ii)
The **offline macro-step falsifier** (R, no engine): freeze cohorts, sub-cycle the
5-layer soil with the refreshed `a ≈ a₀ + (∂a/∂u)(u−u₀)`, compare the soil trajectory
AND offspring to the true coupled solve over a real weekly window; measure the
2nd-order trust-monitor re-expansion rate. This sets the realised speedup and the
trust rate BEFORE any engine code — reusing `sweep_soil`/`overwrite_cached_soil` and
the now-exposed `assemble_duptake_jacobian`/`resource_depletion`.
