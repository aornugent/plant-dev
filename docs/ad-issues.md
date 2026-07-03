# AD infrastructure: work items, dependencies, and build order

Companion to [`ad-infrastructure-design.md`](./ad-infrastructure-design.md).
Each item is scoped to one layer (odelia / plant / UX) or is a de-risking
prototype. Items are deliberately small; where a design is still open the item
says what must be decided and by which prototype.

**Legend.** Class: **CP** critical path · **PROTO** de-risking prototype (gates a
CP item) · **NTH** nice-to-have. Repo: `odelia` / `plant` / `meta` (docs, fixtures).

---

## Prototypes (do first — each can move a decision)

### PROTO-1 — Scalar-cost measurement · repo: plant · gates PLANT-1, decision 2
Implement the FF16 frozen cohort as a uniform-`value_type` odelia System, gradient
one metric, compare `tape.getMemory()` and wall-clock to the spike's mixed engine
on the canonical cases. **Output:** a number that chooses uniform scalar vs. an
encapsulated "frozen input" fallback. Blocks committing to the full-scalar Patch.

### PROTO-2 — TF24 census cross-sensitivity · repo: plant · gates TF24 census, decision 7
One TF24 cohort; gradient a density-dependent census metric with the leaf-optimizer
IFT delivered as an on-tape `AnalyticEdge`; check against finite differences.
**Output:** confirmation (or refutation) that the full-scalar `run_mutant` replay
captures the density→optimum cross-term. **Highest risk in the whole design** — run
early; a refutation rescopes TF24 census out of v1.

### PROTO-3 — `AnalyticEdge` / `CheckpointCallback` ergonomics · repo: odelia → plant · feeds ODELIA-3
Minimal `CheckpointCallback` that injects a known d(out)/d(in) into a reverse tape;
reproduce one leaf-optimizer sensitivity from the spike bit-for-bit. **Output:** the
`AnalyticEdge` API shape. Prerequisite for the clean version of PROTO-2.

---

## odelia layer (generic, plant-agnostic)

### ODELIA-1 — Generalize `compute_gradient` to an arbitrary functional · CP
Replace the hard-coded `sum_of_squares` with a caller-supplied functional
`std::vector<S> f(const System& solved)`. Keep `sum_of_squares`/`advance_target` as
a prebuilt instance. **Depends on:** —. **Blocks:** ODELIA-2, PLANT-4.

### ODELIA-2 — `compute_jacobian` (reverse, row-sweep) · CP
Record once, one adjoint sweep per output row (adjoint `XAD::computeJacobian`
pattern), reusing the Solver-owned tape. **Depends on:** ODELIA-1. **Blocks:**
PLANT-4, UX-1.

### ODELIA-3 — `Independents` + `AnalyticEdge` · CP
The "differentiate w.r.t. what" bundle (renamed from `Seeds`) and the analytic-edge
injection built on `CheckpointCallback`. **Depends on:** PROTO-3. **Blocks:**
PLANT-2 (traits), PLANT-6 (leaf edge).

### ODELIA-4 — Test coverage: multi-output `leaf_thermal` · CP-support
Extend odelia's own example to exercise `compute_jacobian` + an `AnalyticEdge`, so
the generic surface is covered without plant. **Depends on:** ODELIA-2, ODELIA-3.

### ODELIA-5 — Document the AD API contract in `ARCHITECTURE.md` · CP-support
Extend the existing Tape-linking contract to cover the AD *API* (functional shape,
`Independents`, edges) so plant depends on a versioned odelia surface. **Depends
on:** ODELIA-1..3.

---

## plant layer (surgical changes to existing types)

### PLANT-1 — Uniform `value_type = S` on Patch/Species/Node/Individual · CP
Collapse the mixed active/frozen `<T,E,S>` into one uniform scalar. **Depends on:**
PROTO-1 (decides uniform vs. fallback). **Blocks:** PLANT-3, PLANT-4.

### PLANT-2 — Single scalar-templated Strategy parameter store · CP
Remove the dual double-`pars` / lifted-active-struct representation so a named
trait can be registered active. **Depends on:** —. **Blocks:** PLANT-3.

### PLANT-3 — Patch `set_params` / `set_initial_state` (odelia AD contract) · CP
Implement the System contract on Patch; map trait names + birth-rate to registered
active inputs. **Depends on:** PLANT-1, PLANT-2, ODELIA-3. **Blocks:** PLANT-4.

### PLANT-4 — Differentiate `run_mutant` (invasion gradient) · CP
The FF16 invasion gradient as `compute_jacobian` through the existing
`run_mutant` with `S=active`. Retires `ff16_emergent.cpp`. **Depends on:**
ODELIA-2, PLANT-3. **Blocks:** PLANT-5, PLANT-7.

### PLANT-5 — Scalar-template `Species::compute_competition` + census; reuse · CP
Template the reductions on `S`; delete `gradient/{coupled_canopy.h, scm_harvest.h}`.
Enables the resident/total gradient (active canopy). **Depends on:** PLANT-1.
**Blocks:** PLANT-7.

### PLANT-6 — Leaf-optimizer `AnalyticEdge` for TF24/TF24f · CP
Route the forward-mode leaf sensitivity through the odelia edge. **Depends on:**
ODELIA-3, PROTO-2. **Blocks:** PLANT-7 (TF24/TF24f).

### PLANT-7 — Port TF24 / TF24f; delete parallel engines · CP
TF24/TF24f as the same differentiated `run`/`run_mutant`; remove
`tf24_emergent.cpp`, `tf24f_emergent.cpp`, the R harvest, and the five local tapes.
**Depends on:** PLANT-4, PLANT-5, PLANT-6.

### PLANT-8 — Frozen light on odelia's differentiable spline · CP-support
Build the cached resident light on `basic_spline<S>` so schedule-freeze is a
primitive. **Depends on:** PLANT-5. Folds into PLANT-4/5.

### PLANT-9 — Un-skip the 7 FF16 AD tests · NTH-then-CP
Once AD runs on odelia's tape/load path, convert the skipped tests to exercise the
compiled path. **Depends on:** PLANT-4.

---

## UX / API / workflow

### UX-1 — `stand_gradient()` stable surface · CP
Keep the public signature; forward to `compute_jacobian` + `EmergentFunctional`.
**Depends on:** ODELIA-2, PLANT-4.

### UX-2 — Regression oracle fixture · CP (do alongside migration)
Snapshot the spike's validated Jacobians to `tests/testthat/fixtures/
gradient-baseline.rds`; two-tier tolerance (bit-identity / noise floor). **Depends
on:** —. **Gates:** every PLANT-* merge.

### UX-3 — Enumerate the metric set + kernels · CP-input
List the emergent metrics `stand_gradient` must support (LAI, biomass, basal area,
offspring_production, census-at-time, …) and their kernels, so the
`EmergentFunctional` interface covers them in one shape. **Owner:** maintainers.

### UX-4 — Gradient benchmark harness · NTH
`scripts/bench_gradient.R` timing the sub-costs; also feeds PROTO-1. **Depends
on:** —.

---

## Build order (critical path)

```
PROTO-3 ─► ODELIA-3 ─┐
ODELIA-1 ─► ODELIA-2 ─┼─► PLANT-3 ─► PLANT-4 ─► UX-1
PROTO-1 ─► PLANT-1 ───┘        ▲          │
PLANT-2 ──────────────────────┘          ├─► PLANT-5 ─► PLANT-7
UX-3 (input) ─────────────────────────────┤   PROTO-2 ─► PLANT-6 ─┘
UX-2 (oracle) ── gates every PLANT-* merge ┘
```

**Sequencing notes.**
- The three prototypes are independent and come first; PROTO-2 is the one that can
  rescope the release, so front-load it.
- odelia's foundation (ODELIA-1..3) and the scalar decision (PROTO-1 → PLANT-1) can
  proceed in parallel; they converge at PLANT-3.
- FF16 invasion (PLANT-4) is the first end-to-end proof and should land before any
  TF24 work.
- Nothing merges without UX-2 (the AD-vs-AD oracle) green.

## Not in this release
- Second-order / Hessian (`fwd_adj`).
- Full resident-feedback TF24f at long patch lifetime (physics stiffness; may stay
  gated).
- Moving plant's leaf-level forward-mode AD into odelia (stays plant-local).
