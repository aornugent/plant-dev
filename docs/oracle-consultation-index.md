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
| 4 | [`oracle-consultation-transport-compression.md`](./oracle-consultation-transport-compression.md) | standalone: the compression term `Cᵢ=∂ₓg` — value-stability vs gradient-correctness, framed for reframing | sent |
| — | [`oracle-response-transport-compression.md`](./oracle-response-transport-compression.md) | response to #4: **transport log-mass `λ=ℓ+logΔx`; compression cancels identically; both symptoms dissolve.** Predictions 1–4 to test before building | received |
| 5 | [`oracle-consultation-inner-argmax-adjoint.md`](./oracle-consultation-inner-argmax-adjoint.md) | standalone (session 13): the reverse-mode gradient through a **finite-tolerance inner argmax** — the IFT node differentiates the *ideal* optimum (0.652), the FD-of-code-as-run sees the loose bracketing search's *bracket-tracking* surrogate (0.573); every "a term is wrong" mechanism refuted, τ-sweep decisive. Asks: which object should the gradient compute, intrinsic-vs-representational, backward-compat fix, one-node-for-both-regimes. CLEAN. | drafted, not sent |

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
  snapshots only if it becomes the default (open item in the build plan). **UPDATE (2026-07-19): see
  Round 3 below — the mass chart is now applied to FF16 and the value-stability limit is characterised.**
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

---

## Round 3 — the mass chart applied to plant: R1/C1 confirmed; a new value-stability limit (2026-07-19)

Applying R1 (the transport log-mass chart) to a real plant strategy (FF16, resident SCM census + R0
gradient) both **confirms the Oracle's C1 diagnosis and R1 prescription** and **surfaces a limit R1 did
not price**: the neighbour-secant compression the chart uses is the *centred* discretisation, which is
value-unstable exactly where plant already has a documented density runaway (#550).

### C1 confirmed verbatim, and R1 fixes it (the derivative)
- **C1 reproduced exactly.** FF16's resident gradient was internally consistent (forward-JVP =
  reverse-VJP), value-exact (bit-identical trajectory), yet O(1) off a δ-independent finite difference,
  **concentrated in the traits that reach the metric only through the coupling** (self-shading light →
  growth). That is C1 word for word. Root cause: `Node::growth_rate_gradient` (the FD-stencil compression
  `∂ₓg`) returns a bare `double` on the active pass — its parameter-derivative is *dropped* — and the
  competition field's source weight is density-weighted, so the dropped transport derivative corrupts
  `d(field)/dθ` and thus every coupled gradient. This is also C2 in the flesh (a rate defined as an FD
  secant, its gradient mishandled).
- **R1 is the fix — for the DERIVATIVE.** Routing the transport derivative through the mass chart
  (`odelia::log_density_rate`, the neighbour secant) makes reverse AD match the finite difference:
  FF16 `d(offspring)/d(lma)` ratio **0.995–0.999** (life 25 and 40), across growth / offspring metrics.
  The Oracle's R1 ("compression vanishes iff C is the neighbour secant") is confirmed on a real strategy.

### The new finding R1 did not price — the centred chart is VALUE-unstable (same mechanism as #550)
- **The mass chart's VALUE overflows under NORMAL forcing.** Switching FF16's *value* onto the centred
  mass chart makes its cohort density run away (`log_density` → overflow) on a standard two-species run —
  no drought needed. Instrumentation at the blow-up: the compression is only ~ −24 (not a spike), cohort
  spacing is normal (no `Δx→0`), but the neighbouring growth rates are **exactly 0** — shaded understory
  cohorts whose growth FF16 shuts off at `net_mass_production ≤ 0`. The centred secant across that
  growth/no-growth boundary makes characteristics converge and density pile up.
- **Same underlying cause as #550, confirmed by reproduction.** #550 (TF24, extreme seasonal drought)
  and this FF16 case hit the **same guard** (`Patch::check_finite_ode_state`, from #552), the **same
  equation** (`d(log_density)/dt = −∂ₓg − mortality` spiking positive → overflow), the **same symptom**
  (density → +Inf, or a downstream non-finite soil state). Reproduced #550 directly (TF24 `lma=0.07`,
  rainfall `0.4·sin(2πt)+0.5`, 5 soil layers, `mpl=30`): "a cohort density runs away in the SCM
  size-density equations (… see #550)" at t≈17. So it is **the same mechanism, not merely a similar
  symptom** — the McKendrick transport term `−∂ₓg` growing without bound where the characteristic
  velocity `g` changes steeply/discontinuously in size.
- **The distinction is the discretisation, not the cause.** #550 is *model-side steepness* (drought /
  hydraulic-optimum discontinuity, deferred to #551 / NSC buffering #517) overwhelming even the **stable
  upwind FD stencil**. The FF16 case is *scheme-side sensitivity*: the **centred** mass chart amplifies
  the same term at a growth-shutoff boundary that the **upwind** stencil damps. The stencil is the stable
  production scheme by design (upwinding is the standard stabilisation for hyperbolic transport); the
  centred chart is not.

### Consequence for R1, and the open fork
R1 as delivered (centred neighbour secant) is correct for the **derivative** but cannot serve as the
**value** for a shutoff-prone strategy without a stabiliser. Two ways to reconcile:
- **(a) Derivative-only lift.** Keep the stencil value (stable), take only the mass-chart derivative
  (`value = to_passive(stencil) + (m − to_passive(m))`). Correct + stable for FF16; **but** it desyncs
  value and derivative and so is wrong for a strategy where the two schemes' *derivatives* differ (K93:
  reverse AD −451.9 vs FD 139.9). So it must be per-strategy (K93 keeps the full centred chart, which is
  stable for its monotone growth; FF16 takes the lift). Correct everywhere, but two transport behaviours.
- **(b) Upwind mass chart (the consistency prize).** Give the chart the stencil's stabilisation — a
  one-sided neighbour secant in the downwind (flow) direction. If that is both stable (matching the
  stencil's bound) *and* exactly differentiable (the chart's property), then **one scheme serves value
  and derivative for every strategy** — the clean unify. It would match the stencil's stability, so it
  fixes the FF16-normal case; it would **not** solve #550's model-side steepness (that stays #551/#517).
  *If (b) holds, consistency is worth re-blessing the K93 (and FF16) demography snapshots* (the ~0.2%
  shift), which is the stated preference. This is the next thing to prototype.

**Reproductions:** FF16 gradient — the `ff16_scm_gradient_driver.cpp` driver on the resolved schedule
(`run_scm(refine_schedule=TRUE)`), metric 0/2, compare `grad` vs `fd_grad`. #550 — the TF24 config in
`test-strategy-tf24.R` ("SCM cohort-density blow-up fails gracefully (#550)").

**Outbound elicitation drafted from these findings:** `oracle-consultation-transport-compression.md` —
a standalone, domain-clean statement on the compression term `Cᵢ = ∂ₓg` (the one rate that is itself a
numerical derivative). It lays out both discretisations flat with their measured value/gradient
behaviour (one-sided sub-grid: value-stable, gradient `O(1)`-wrong in the coupling channel; centred
neighbour secant: gradient-correct 0.5–1%, value-overflows at the `g=0` stall) and the contingent hybrid,
then asks — without proposing a fix — whether the stability/differentiability tension is intrinsic to
this term or an artifact of the transported variable / forming `∂ₓg` as a finite difference at all.
Passes the domain-leak gate. Not yet sent.
