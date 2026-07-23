# v3 — the north star for reverse-mode AD in plant × odelia

_Written after a full re-reading of both repos' git history, the design docs, the
oracle deepenings, and the shipped code (three discovery passes). Its purpose is
to be the **guiding light that survives contact with reality** — grounded in what
actually happened, not a fourth fresh design. It reconciles the standing intent
(`design.md`, `odelia-index.md`) with the shipped reality (`p2c-leaf-adjoint-
design.md`) and states, honestly, the one place they diverged and why._

Read order for a new session: **this** → `design.md` (detailed what/why) →
`status.md`/`build-plan.md` header (where we are) → the oracle responses +
deepenings for derivations. The rest is archived (see §7).

---

## 1. The objective (the guiding light — never reduce this to a mechanism)
Two goals, both measured, neither traded away:
- **DX = concept count.** A plant strategy author expresses **only ecology** —
  scalar-generic closed forms + a few declarations. **Zero `xad::` tokens, zero
  hand-written adjoints in a strategy TU.** (design.md R1.)
- **Coverage.** All four strategies (FF16, K93, TF24, TF24f) and every future
  strategy get exact reverse-mode trait gradients through the SCM, plus bounded
  memory to a useful patch life. (design.md R6.)

**The failure mode this document exists to prevent:** TF24's genuine ecological
complexity repeatedly pulled the work down into a bespoke tape mechanism (the
leaf seam), and we optimized the mechanism instead of holding the objective.
Every design decision below is checked against §1, not against the seam.

## 2. The scarce resource, and the invariant that protects it
**Hand-written-adjoint correctness.** Every place a human writes a reverse rule
is a silent gradient-bug site — value-exact, passes every double test, wrong
only in the gradient (this is exactly what b1's sign error and b2's dropped term
were). The design is measured by how few exist:

> **Exactly TWO hand-written adjoints in the whole system — the `separable_field`
> transpose and the `register_implicit` IFT — each self-checked by the
> dot-product oracle `⟨Jv,u⟩=⟨v,Jᵀu⟩`. ZERO in strategies.** (design.md §1;
> odelia-index "two tape-aware Kernels".)

TF24's current local-tape splice is a **third** hand-written adjoint living
**inside a strategy**. That is the invariant violation. v3 = restore the
invariant.

## 3. Durable principles (the through-line that survived all 16 sessions)
These were never reversed; a v3 that breaks one is wrong.
- **DX = concept count; the floor (reuse+deletion) wins; a name earns itself
  only by removing a *class* of bugs with a second witness.** (Killed `Coupling`,
  `StateView`, `TransportGeometry`, `Runnable`.)
- **Only doubles cross the R boundary.** The tape is anchored on the C++ Solver.
- **Record→replay:** run adaptively once in double (discover the L1 schedule +
  L2 positions), replay frozen on the active scalar; `recorded_steps()` is the
  SINGLE source of the replay grid. (Violating this — a second grid source — was
  the FF16 R0 saga.)
- **Resident vs mutant = data-presence, not a mode** (L3 empty ⇒ recompute field
  active; populated ⇒ read frozen). Residents first; invasion deferred.
- **The activation rule:** a quantity goes active iff it is on the differentiable
  path AND produced by taped arithmetic; anything from iteration/optimisation/
  adaptive refinement stays `double` and reaches the tape only as a recorded
  value or an injected analytic derivative. **This is the clean odelia/plant
  boundary — the ~1500-line leaf hydraulics stay `double`.**
- **Exact fields, never sampled-spline differencing.** Coupling fields are
  closed-form (`separable_field` for light; `incomplete_gamma` for leaf/soil
  hydraulics); a rate defined as a numerical derivative must be computed from
  active quantities (a private numeric probe severs the tape).
- **The mass chart:** transport log-mass `λ=ℓ+logΔx`, `dλ/dt=−r`; the compression
  `∂ₓg` cancels identically, is computed nowhere, cannot overflow; use the SAME
  `Δx` in transport, reconstruction, and every Δx-weighted reduction.
- **Doctrine B — differentiate the ideal converged optimum,** not the solver
  path. Comparison search (golden section) is the least differentiable-through
  solver; its output is a staircase whose a.e. slope carries no objective info.
  **Correctness anchor = tight-inner-τ frozen-schedule FD, never a loose-τ swept
  plateau** (that measures the within-cell artifact — do not chase the ~0.8×/1.6×
  ratio; it is a reference artifact and must not close).
- **Verify at Gate-0** (single leaf/cohort, clean δ-swept FD); census FD is
  %-noisy and has fooled us repeatedly; `⟨Jv,u⟩=⟨v,Jᵀu⟩` is self-consistency, not
  correctness (both legs can traverse the same lossy path and agree while wrong).
- **The reset-timing/grounding contract:** a differentiable System must
  re-derive parameter-dependent precompute *after* seeding (`reset()`/
  `prepare_strategy`), or the channel is severed. (The real root cause of the
  omega/eta/allometry severances.)

## 4. The leaf — where TF24 overwhelmed the intent, and the way back
This is the crux. The genuine ecology is small; the accreted machinery is large.

### 4a. Irreducible ecology (any correct differentiator must handle all of these)
- **The inner optimum `p*` + envelope asymmetry:** profit is stationary in `p`,
  but transpiration/ci/ψ_stem/per-layer-uptake are **not** — they need
  `dp*/dstate` even where profit doesn't. ("Freeze p\*" is provably wrong.)
- **Multi-output leaf** (scalar profit + per-layer uptake vector), different
  stationarity and downstream consumers.
- **Soil-water feedback loop** (stiff retention curve, real physics — "the
  adjoint of a feedback loop is a feedback loop").
- **Three regimes** (interior-stationary / bound-at-ψ_crit fold / tracked-off-
  optimum for TF24f) with intrinsic nonsmoothness at transitions; plus a genuine
  hydraulic-failure discontinuity (shutdown) that must **not** be smoothed.

### 4b. The designed decomposition (design.md §5 — the target, never fully built)
Express the leaf so the differentiable path is exact and the inner solves are the
only tape-aware objects — **zero hand adjoint in the strategy**:
- 4 hydraulic splines → **exact reads**: the two integrals via `incomplete_gamma`,
  `f_r` elementary, the inverse via a scalar `register_implicit` root. No sampled
  `.deriv()` in the leaf residual ⇒ injected partials are exact.
- **N_ci** (stomatal root), **N_ψstem** (transpiration inversion) → `implicit_value`
  scalar IFT nodes (forward-mode partials, **no local tape, no nested tape**).
- **p\*** → double-side Newton polish + `register_implicit` (§4d; no new node).
- profit + per-layer uptake → **closed-form arithmetic** over the solved scalars
  and exact reads; the tape does the chain rule ⇒ **b1 (sign) and b2 (dropped
  term) become inexpressible**; no `chain_sign`, no manual injection, no snapshot.

### 4c. The accidental machinery this deletes
The shipped `net_mass_production_dt` seam (local-tape splice + `supplied_derivative`
injection + `chain_sign` + `src`-tag marshalling + whole-leaf snapshot +
`soil_consumption_active_` + the nested-FD `p*`) — all of it is servicing §4a the
hard way and is deleted by §4b. It exists because TF24 was sequenced last and got
a pragmatic shortcut instead of the decomposition; the shortcut then grew b1, b2,
the OOM workaround, and the task-#23 accuracy problem.

### 4d. The one genuinely hard build piece — and it needs NO new odelia concept
The p\* collar optimum is an **argmax**, and the double model solves it by golden
section — a staircase (doctrine B). A naive IFT node divides by a shelf-curvature
the `1e-6` detector misclassifies. The oracle's prescribed, *cheaper* fix
(≈9–13 obj-evals vs ≈16 today) decomposes into **two existing pieces — no new
primitive**:
1. **A plant-side terminal Newton polish of the double `p*` solve**
   (`leaf_model.cpp`): bracket-localise + read the branch flag at the bracket ends
   + 3–4 safeguarded Newton steps on the stationarity condition using the
   closed-form `Leaf::dprofit_droot_collar_psi` **we already have and don't use**,
   to `|p̂−p*|~1e-12`. This makes value and derivative describe *one* object and
   deletes the loose-GSS staircase — a change to the double solver, not the AD.
2. **`register_implicit` with the branch-selected residual** — interior
   `∂profit/∂p=0` (`dp*/dσ=−P_pσ/P_pp`) or fold continuity `F=0` (`−F_σ/F_p`) —
   which is exactly the IFT derivative of the converged Newton step. Existing
   primitive; the branch flag picks which residual.
One reduced gradient `G(q)` serves TF24 (solved) and TF24f (tracked off-optimum:
the same `register_implicit` residual, evaluated off the root). This **retires the
three-regime hand-code, the nested FD, and the `1e-6` detector** using only a
double-side polish + `register_implicit` — so it also holds the "two hand
adjoints, zero new concepts" invariant (§2). The residual judgment (is the
branch-select + two residuals clean as plant code, or does it want a thin
wrapper?) is a build-time code-review call, not a design gate.
(oracle/oracle-response-inner-argmax-adjoint; task #23.)

### 4e. The one HONEST open question (do not paper over it)
`design.md §5` assumes the decomposed leaf outputs record on the run tape as cheap
arithmetic. **Session 9 found the *undecomposed* leaf OOMs on the run tape at
life=1** — but that was recording the Brent + nested-FD re-solves, which §4b
removes. Whether the *decomposed* leaf is cheap enough to record directly is
**untested**. v3 is robust to the answer:
- **If it fits** → record directly; no injection primitive needed (simplest).
- **If it doesn't** → an **odelia-owned** local-adjoint primitive (the reverse
  multi-output dual of `register_implicit`: evaluate the sub-computation on a
  scratch tape, splice its exact Jacobian as O(#inputs) nodes) does it.
Either way **R1 holds** — the strategy has no hand adjoint; the tape lifecycle is
the engine's. This is a bounded implementation choice, **not** a design gate, and
it is settled by one measurement *after* §4b lands (not before — measuring the
undecomposed leaf, as I did, just re-derives the session-9 OOM).

## 5. The ladder to completion (each rung cited; verify, don't inherit status)
- **DONE, FD-verified:** FF16 + K93 full-SCM resident gradients (census + R0),
  zero tape code — the proof the target shape exists.
- **DONE, value-only:** TF24/TF24f full-SCM compiles + reproduces the double value
  bit-exactly; gradient **not** FD-certified (the seam is in place). (task #27.)
- **THE GAP (v3 Phase 1):** execute §4b for TF24 — wire `incomplete_gamma` into
  the 4 leaf splines; `implicit_value` for N_ci/N_ψstem; polish the double p* solve + `register_implicit`
  (§4d); express profit/uptake as closed-form; delete the §4c machinery. Verify
  with Gate-0 + the tight-τ frozen-schedule anchor (§3), **not** the census
  staircase. Then settle §4e with one memory measurement.
- **Phase 2 (memory to high life):** segmented checkpointed replay (XAD
  `ScopedNestedRecording` stage-checkpointing lifted to the fixed-schedule replay;
  fresh recording per window). Forward-mode (`compute_jvp`) for few-trait
  gradients sidesteps the tape entirely. (Both already partly in odelia.)
- **Phase 3 (deferred, real):** mutant/invasion (L3 frozen field), IC gradients,
  the fixed-point/Eulerian-BVP layer for regnans selection gradients.
- **Consolidations (ride-along):** name `graft_value` (=`anchor`=`implicit_value`
  idiom); merge `implicit_value`+`register_implicit` into one IFT family; move the
  `rebind_from` completeness guard (plant's R5) into odelia; surface the
  dot-product oracle at the R boundary so authors certify without FD.

## 6. Why this reaches the goals, and what would falsify it
- **DX:** after Phase 1, a TF24 author writes leaf forward algebra (exists as
  `leaf_output::`) + "ci and ψ_stem are roots, p\* is an optimum" + the Weibull
  integral + the shading separation. No `xad::`. That is R1, and it generalises:
  a future strategy declares its solves and kernels, nothing more.
- **Coverage:** the same primitives serve all four strategies; TF24f is the same
  `register_implicit` p* residual evaluated off-optimum.
- **Kill condition:** if the decomposed leaf both OOMs on the run tape AND cannot
  be bounded by the local-adjoint primitive within the DX budget, then the leaf
  genuinely cannot be zero-hand-adjoint and R1 must be relaxed for TF24 — but no
  evidence suggests this; §4e is the check.
- **Watch:** the p\* Newton-polish + branch-selected `register_implicit` (§4d) is
  the load-bearing hard piece (no new concept); if it
  cannot be built to give the ideal-optimum derivative cheaply, the whole p\*
  accuracy story (and task #27's residual) stays open.

## 7. Documentation set + archive plan
Canonical working set (a new session reads only these):
- **This doc** (north star) + **`design.md`** (detailed; §12 corrected to state the
  shipped seam reality, not the aspirational deletion) + a **status doc**
  (build-plan/HANDOFF Part-1 headers + the test-cited build-status matrix).
- Reference: `oracle/oracle-response-transport-compression.md`,
  `oracle/oracle-response-inner-argmax-adjoint.md`, `oracle/oracle-consultation-index.md`
  (evidence ledger), `p2c-leaf-adjoint-design.md` (shipped-leaf record),
  `oracle/oracle-consultation-guide.md` (methodology).
- Appendices (derivations): `deepenings/deepening-6` (separability — highest value),
  `deepenings/deepening-1`, `deepenings/deepening-2-4-5`, `deepenings/deepening-3`, `phase0-results.md`.

Archive (fold-forward then move to `archive/`): the seven `odelia-N-*` journey
notes (retired nouns), `HANDOFF.md` Part 2 + `build-plan.md` saga sections,
`tf24-numerical-formulation-and-misspecification.md`, `ad-touchpoint-audit.md`
(after extracting the grounding vocabulary into design.md), `tape-memory-design.md`
(self-superseded), `reverse-mode-dx-design.md` (its L-A is the session-9 OOM plan;
its analysis is folded here), and all oracle *statement* docs (keep the responses).
Net: ~14 working docs, down from 30+11.
