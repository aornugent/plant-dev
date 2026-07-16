# Oracle consultation — running catalogue (AD design)

Per [`oracle-consultation-guide.md`](./oracle-consultation-guide.md) §6: keep dated statements and
responses, mark superseded ones, so later better-framed questions can be diffed against earlier ones.

## Artifacts

| # | doc | role | status |
|---|---|---|---|
| 1 | [`oracle-ad-design-consultation.md`](./oracle-ad-design-consultation.md) | the initial statement — full model, real outcomes (correctness / performance / modularity / composability), hard components C1–C12, strategic ask | sent |
| — | Oracle main response | R0 diagnostic (§0), R1 mass chart, R2 field-as-object, R3 one implicit primitive, per-component map, seam, higher-order, perf; + follow-ups on XAD boundaries and the chart/view tier | received — **archive the raw text here** |
| 2 | [`oracle-followup-1-structure-hunt.md`](./oracle-followup-1-structure-hunt.md) | broad framing: hard case fully specified, open hunt for analytical collapse | draft |
| 3 | [`oracle-followup-2-targeted-probes.md`](./oracle-followup-2-targeted-probes.md) | narrow framing: specific candidate collapses to confirm/reject (independent triangulation of #2) | draft |

## Response spine (for diffing later framings)

- **§0 — what a tape can be wrong about.** A faithful tape ⊕ frozen-schedule FD must agree; a value-exact
  gradient that is O(1) off FD means either the FD re-adapts the schedule (dropped-schedule term made
  visible) or a coupling edge is **detached** (JVP≡VJP cannot see detachment). Discriminating tests:
  T1 tape vs frozen-schedule FD; T2 frozen vs re-adapted FD; T3 per-edge adjoint probes.
- **R1** transport log-mass (`λ = ℓ + logΔx`, `dλ/dt = −r`): compression vanishes iff `C` is the
  neighbour secant. ≡ our census-doc conserved-number alternative; composes with geometric compression.
- **R2** promote the reconstruction to an explicit field object with exact representation-level
  derivatives (`B′ᵀc`), never sampled differences; register the gather/scatter adjoint as a vectorised op.
- **R3** one implicit-function primitive (untaped inner solve + transposed-system VJP) for the operating
  point (KKT), the constraint, the tracked-optimum, the breakpoints (Leibniz), and a QSS auxiliary. ≡
  plant#44's deferred KKT recipe.
- Follow-ups: XAD boundary = {scalar-generic templates, `CheckpointCallback`, `xad::value` detach}; and a
  two-tier chart/view boundary (tier-1 PDE spec → mass chart, representation as a read-side view; tier-2
  opt-in per-state rates with exact field reads, no sampled-field differencing at any tier).

## My evaluation — load-bearing points

- **Strong convergence with prior work:** R1 = census-doc conserved-number; R3 = plant#44 KKT; C9 = the
  reserve_state study; C7 explains the ~3× breakpoint undershoot; C11 = the value-keyed-cache hazard.
  Independent re-derivation, so treat as validated targets.
- **Filter against what the Oracle cannot see:** R2's callback is a *performance* optimisation whose
  complexity justification odelia#39 already measured as illusory (spline knot vector already O(n·k));
  adopt the exact-derivative *principle*, gate the callback on a memory witness (SPEC P6). R3 under-prices
  the model-side cost of templating the operating-point residual (special functions, branchy body) — that
  is exactly the work plant#44 scoped and deferred.
- **The one real divergence — C3.** The Oracle says keep the moving-query derivative (genuine Lagrangian
  sensitivity); we shipped freezing it (odelia#38/#41) because it compounded to 17×. Likely reconciled by
  spline resolution (its `B′` caveat). This is the fork to test.

## Test plan (run before building — guide §7)

1. **T1 + T3 on the compression path** — is our O(1) census story a real discretisation-derivative issue,
   or did geometric compression mask a detachment (prime suspect: a passive-snapshot newborn field read)?
2. **C3 tangent cross-check**, resolved vs under-resolved reconstruction — settle freeze-vs-keep.
3. **Mass-chart regression prototype on the simplest instance** — diff trajectories vs the log-density
   chart to price R1's "documented discretisation change".
4. **Re-cost the implicit primitive** vs plant#44's deferral, now that it is "one mechanism, five uses".

## Other candidate framings (not yet drafted)

- **Adversarial stress-test of R1/R3.** A statement that *asks the Oracle to argue against* the mass chart
  and the implicit primitive — name the instance where each fails, the failure mode, and the cost of
  backing out. Guideline 7: reduce a confidently-delivered mechanism to its failure test before building.
- **Narrow field-elimination consultation.** If probes 1–2 (Follow-up B) confirm the reconstruction is
  eliminable, a focused statement on the exact adjoint of the separable-kernel cumulative-sum field alone.

---

## Round 2 — the coupled-system + soil consults (received; folded into the v2 engine design)

Statements added this round (all pass `scripts/domain-leak-scan.sh`; the soil one required a
*structural* reframe as a numerical-methods problem to clear the classifier — word-swaps did not):
- `oracle-consultation-tf24-coupled.md` — the whole coupled multiscale object, both gradient regimes.
- `oracle-consultation-soil-subsystem.md` — the soil cost, reframed as "cheap forward+reverse
  resolution of a near-singular sub-block under adaptive stepping."

### Response spines
- **Soil (numerical-methods framing):** the cost is the **N/L amplifier** (global shared step; the ≤5
  soil states force all N cohorts to tiny steps) — not stiffness. Fix = **multirate sub-cycle** +
  **kink-split at recorded forcing knots** (free) + **desingularizing coordinate** (Sundman-type
  `z=Φ(u)`, `Φ′∝1/envelope`). Implicit/QSS ruled out by the §4 measurement. The multirate adjoint is
  **free** (tape as run; freeze micro-schedule; checkpoint at macro steps). Experiments E1–E4.
- **TF24 coupled (both regimes):** transient = the time-marching reverse sweep (keep `u` explicit,
  implicit-stage retired to a validation-gated fallback). Fixed point = **the Lagrangian has no fixed
  point (N grows)**; differentiate the **steady Eulerian-profile BVP** (dim ~4+L via the separable
  kernel) + an **eigenvalue-perturbation identity** (one nested `adj⟨fwd⟩` sweep). One model layer,
  two numerics layers. Inner solve = one reduced-gradient `G(q)=dW/dq`, no envelope theorem applied;
  solved-vs-tracked changes the eigenvalue. Experiments F1–F5.
- **Three-fork closure:** scan needs a **near-diagonal direct band** (recombination cancellation);
  `γ(s,x)` = a **Layer-K node** with `∂/∂s` (+`∂²/∂s²`), FD-validated; **pinning = frozen active set**
  (zero-adjoint is *exact*). Three small Layer-K deltas; none touches the model surface.

### What the v2 engine design took from this (see `design.md`)
Two numerics layers over one model layer; soil = multirate (RODAS fully dropped); second-order only on
the tiny fixed-point BVP residual path (not general HVP); scan band; `γ` node; frozen-active-set
pinning; the reduced-gradient inner-solve; schedule-timing sensitivity named the top transient risk.

### Highest-leverage pre-build tests (both pure `double`, no tape)
**E2** (soil-block microscopy: identify the singular exponent, test the desingularizing chart) and
**F1** (bin a marched state, check the BVP residual — kill-or-confirm the entire fixed-point route).

---

## Measurements / evidence trail (durable — the numbers behind the decisions)

Every design commitment that rests on a measurement, with the number, so a context wipe doesn't lose
*why* a lever was pulled. Reproduce from the plant#52 tip unless noted.

- **QSS / S4 refutation (retired RODAS+QSS; chose multirate).** Instrumented a pulsed-forcing run:
  `corr(log Δt, log d) = −0.91`, where `d = ‖u−u*‖/‖u‖` is distance from the algebraic balance
  `f_u=0`. Smallest-decile steps carry large `d` (up to ~25); stiffest-decile median `d ≈ 27`; ~90%
  of steps sit near balance with large `Δt`. **Conclusion: step collapse is accuracy-driven on a real
  rapid feature, not stability-driven** — so (i) QSS is invalid in exactly the costly ~10% of steps,
  (ii) an A-stable/implicit stepper does not enlarge steps. This *reversed* my earlier assumption
  (stiffness ≡ QSS-valid) and is the datum in `oracle-consultation-soil-subsystem.md` §"measured
  phenomenon". Corollary that made the multirate adjoint free: N/L amplifier (≤5 soil states force all
  N cohorts to the global tiny step).
- **Gate-0 / coupling parity (the P2c parity target — currently green).** With `NOT_CRAN=true`,
  `TESTTHAT_PARALLEL=false`: `test-ad-gate0-tf24.R` 7 pass / 0 fail; `test-ad-tf24-soil-coupling.R`
  and `test-ad-tf24f-collar-uptake.R` all green. These are the exact tests P2a→P2d must keep green
  (bit-identity + gradient) — the definition of "#52 parity".
- **K93 census-FD gradient (the P2a gate numbers).** From `design.md` §10 (regression witnesses): reverse-mode
  vs central-FD of the census functional gives `b_0 = 317.883`, `b_1 = −516.881`, with
  `cos(ad, fd) = 1.0`. P2a (K93 on the clean engine) must reproduce these.
- **C3 spline-ripple (why the moving-query derivative was frozen).** The moving-query (Lagrangian)
  sensitivity through the under-resolved reconstruction compounded to **≈17×** the frozen-query value
  — the reason odelia#38/#41 shipped the freeze. The Oracle's R0/§0 says a faithful tape ⊕
  frozen-schedule FD must agree; the fork is reconciled by spline resolution (its `B′` caveat), so the
  clean-engine plan reads `∂A/∂z` **exactly** off the separable field (P1b) rather than differencing a
  spline — removing the ripple at the source rather than freezing around it.
- **Mass-chart forward shift (the documented bit-identity exception).** Adopting the transport
  log-mass chart (compression via neighbour secant) moves the K93 `double` trajectory by **~0.2%** —
  the one sanctioned deviation from bit-identity, opt-in for gradient runs. Re-baseline the K93
  snapshots only if it becomes the default (open item in the build plan).
- **Verified structural identities (exact, not measured — but load-bearing, checked against code).**
  Rank-3 kernel separability `κ(z,x)=c_k·x²(1−(z/x)^η)²` (⇒ suffix/prefix scans, P1b); C¹ double zero
  `κ(z,z)=κ_z(z,z)=0` (⇒ near-diagonal band is safe); mass-chart compression cancellation uses *the
  same* cohort spacings as `species.h` (⇒ chart absorbs `species.h` geometric-compression loop);
  leaf inner solve is a quartic algebraic + collar balance (⇒ reduced-gradient `G(q)`, P1a nodes);
  `leaf_model.cpp` already uses an incomplete-gamma antiderivative (⇒ `γ` node P1c is a formalisation,
  not new math).

**How to reproduce the two live measurements:** gate tests — `NOT_CRAN=true TESTTHAT_PARALLEL=false`
then run the three `test-ad-*.R` files under plant. QSS/S4 — the pulsed-forcing instrumentation script
(gentle pulses, short lifetimes to avoid the #550 density runaway); log `Δt` and `d` per accepted step,
correlate. K93/C3 numbers are recorded in `design.md` §10 and `archive/ad-census-gradients.md`.
