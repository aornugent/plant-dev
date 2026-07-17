# tf24-multirate — prototype scaffolding (⚠ SAFE TO DELETE ON COMPLETION)

**Status: throwaway prototypes / early WIP.** Everything in this directory is the investigation and
validation scaffolding behind the TF24 multirate engine design. It exists to (a) make every claim in
[`docs/tf24-multirate-engine-port-spec.md`](../../docs/tf24-multirate-engine-port-spec.md) reproducible
and (b) seed the C++ port. **Once the odelia engine port lands and its own tests reproduce these results,
this whole directory can be deleted** — the durable record is the `docs/tf24-multirate-*.md` +
`docs/oracle-consultation-*.md` set and aornugent/odelia#43. Nothing in production should depend on it.

A couple of files are **reuse candidates** (closest to port-ready), flagged ★ below — lift the logic,
don't ship the file.

## What each artifact is, and which spec claim/section it backs

**MRI core & method validation**
- ★ `mri_core.hpp` — generic MRI-GARK macro step + coupling tables (`c`, `Γ^{(k)}`). *Reuse candidate for spec §4.1.*
- `test_mri.cpp` — collapse identities (f^F≡0→base ERK 1e-16; f^S≡0→inner 1e-13) + coupling order 1/2/2/3. (§4.1 gate)
- `multirate_runner.cpp` (`global_run`/`multirate_run`/`mri_run`) + `mri_soil_test.R` — MRI vs Lie split (Kutta3 156×). (§3, §4.1)
- `mri_stability.R` — forward stability drought→monsoon. (§7)
- `soil_runner.cpp`, `bench_main.R`, `diagnostic.R`, `cost_sweep.R`, `desolve_check.R`, `figs.R`, `gen_rainfall.R` — the original RODAS-vs-multirate evidence (accuracy-limited; O(N³)). (aornugent/odelia#43 OP)
- `tf24_forward_runner.cpp` + `tf24_forward_test.R` — TF24-structure surrogate (nested collar solve, divergent ψ). (early)

**Reverse mode**
- ★ `mri_ad.hpp` + `mri_ad_runner.cpp` + `mri_ad_test.R` — two-level record→replay reverse mode on the MRI surrogate (48/48 grads = FD 2e-9). *Reuse candidate for spec §4.6.*

**Real-patch benchmark (needs plant built)**
- `real_patch_probe.R` — ~300× timescale separation; ode-state layout. (§7 premise)
- `bench_real_patch.R` — global RK45 vs multirate on the real patch; refresh-cadence sweep; the plateau. (§3, §7)

**Cost decomposition / factoring probes**
- `factor_probe.R` — physiology dominates, light field cheap/flat. (§7)
- `factor_probe2.R`, `factor_probe3.R` — surrogate-in-u refuted (linear, separable). (§3, §7)
- `e1_setup_decomp.R`, `e1_cost_decomp.R` — setup cacheable; dispatch overhead. (§5-E1, §6 setup-cache seam)
- `e1_continuation.R` — optimise vs evaluate; warm-Newton fragility. (§5, §3)

**Collocation & tracked control (needs plant built)**
- `e2_collocation.R` — aggregate O(m⁻²), m≈15–20 → <0.5%. (§4.4, §7)
- `e2_tracking.R` — single-leaf tracked vs QSS (degenerate config; superseded by e2_e3_patch). (historical)
- `e2_e3_patch.R` — tracked-q reproduces QSS soil, no plateau; per-cohort feasibility-clamp requirement. (§4.5, §7)

**Reverse-mode certification of the new fast subsystem**
- ★ `e4_fast_ad.cpp` — the (L+m) fast subsystem (tracked controls + m-collocation) taped via XAD. *Closest thing to the engine's reverse-mode kernel; reuse candidate for §4.6.*
- `e4_test.R` — adjoint = FD ~1e-8 across k, m. (§7)
- `e4_bias_test.R` — the B3 gradient-reduction-bias check: a hard member kink breaks adjoint=FD, smoothing restores it. **This is the prototype of the §9 open-item Richardson check** — port it to the real coupling before trusting reduced-m gradients in an optimizer.

**Reformulation / envelope checks**
- `r1_drainage_flow_check.R` — R1 exact drainage recession matches tight RK ~1e-13, positivity-preserving. (§6-R1)
- `h0_envelope_check.R` — H0 envelope identity does not hold for TF24 (water flux ≠ marginal carbon). (§9, h0-missive)

**Data**
- `data/rainfall_scenarios.csv` — the 5 scenarios (drought/dry/semiarid/wet/monsoon).
- `data/real_patch_snapshot.rds`, `data/bench_real_TF24.rds` — cached patch state + benchmark results (regenerable).

## Reproduce (standalone parts need only odelia; real-patch parts need `plant` built)

```
# method/reverse-mode (odelia only):
Rscript mri_soil_test.R ; Rscript mri_ad_test.R ; Rscript e4_test.R ; Rscript e4_bias_test.R
# real patch (build plant first: R CMD INSTALL odelia && cd plant && make):
Rscript real_patch_probe.R ; Rscript bench_real_patch.R TF24 60
Rscript factor_probe.R ; Rscript e1_setup_decomp.R ; Rscript e2_collocation.R ; Rscript e2_e3_patch.R semiarid
Rscript r1_drainage_flow_check.R
```
