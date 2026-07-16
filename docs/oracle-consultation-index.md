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
