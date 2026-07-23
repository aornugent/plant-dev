# Design — reverse-mode as an idiomatic odelia DX across strategies

_Holistic system-design pass after (1) a deep study of the odelia + plant diffs,
the vendored XAD source/docs, and XAD's external-function guidance; (2) reading
the actual leaf seam, `implicit_node`, and `assemble_leaf_from`; (3) tracing the
b1/b2 bug history; (4) one throwaway prototype whose failure is itself evidence.
This is the third iteration and it deliberately does NOT one-shot a mechanism —
the leaf question resolves to a **decision gate**, not a foregone answer.
Supersedes the "package the splice / spliced_jacobian" framing of the earlier
cut of this doc, which was an anchor, not a conclusion._

## Triage: 3 — AD-engine boundary, all strategies, every future strategy.

## What is NOT in question (established by static study; high confidence)
- **The shared substrate is already the target shape.** `scm_gradient` +
  `rebind_from`/`PLANT_DIFFERENTIABLE` + `*_AD_FIELDS` + `census<Ψ>` + the odelia
  mass chart mean **K93 and FF16 add zero tape code.** A new strategy inherits all
  of it. (Agent-B catalogue; verified in the headers.)
- **All hand-rolled tape machinery is one function** — TF24
  `net_mass_production_dt` (src/tf24_strategy.cpp ~L554-715), plus a 2-derivative
  forward helper in `leaf_model.cpp`. Every `xad::Tape`/`registerInput`/
  `computeAdjoints`/`derivative()`/`deactivate` site is there.
- **`assemble_leaf_from` (the ecology) is already clean** — pure `S` arithmetic
  over `leaf_output::*` kernels, using `odelia::implicit_value` for the three-regime
  `p*` (interior-stationarity / bound-continuity / tracked-collar, L826-881) and
  `anchor(v,x)=S(v)+(x-to_passive(x))` for value-grafting (L733). No raw XAD.
- **`anchor` IS `implicit_value`'s core idiom** (implicit_node.hpp:47). It wants a
  name: `odelia::graft_value`.
- **XAD has no first-class `ExternalFunction` class** — the "external function
  interface" in XAD's docs *is* `CheckpointCallback` (computeAdjoint only), which
  `supplied_derivative` already subclasses. So `supplied_derivative` is the
  sanctioned XAD idiom; there is no higher XAD primitive to wrap.
- **`XAD_TAPE_REUSE_SLOTS` is unsafe here** — callback edges hold raw slot IDs a
  reused slot would alias. Permanently rejected.

## The one open question that gates the leaf design
TF24's leaf sensitivity reaches the run tape in one of two ways. Everything else
follows from which we pick, so this is THE decision:

**Candidate L-A — record `assemble_leaf_from` directly on the run tape.**
Deletes the entire outer seam (local sub-tape, per-output adjoint sweeps,
`supplied_derivative` injection, input alignment, the `chain_sign` convention,
the TF24f collar channel, the `soil_consumption_active_` buffer). The tape does
the chain rule, which **eliminates the b1 and b2 bug classes by construction**:
- **b1** (the historic ~1e30 blow-up) was *"an adjoint sign error on the injected
  soil-state partials"* (build-plan:129) — a bug the manual splice *created*; the
  `soil_uptake` kernel's sign flows correctly on the tape with no `chain_sign`.
- **b2** (plant#60) is the splice *dropping* `(∂c/∂p)(∂p*/∂ψ)`; recording directly,
  `p*`'s derivative propagates through the assembly automatically.
It also collapses TF24 into the same flat tape shape as FF16/K93 (one shape → one
memory story) and needs **no new odelia primitive**. Concept count goes *down*.
**RISK (measured, unresolved): a throwaway prototype tripped `scm_jacobian`'s R5
value-reproduction guard** — the active value drifted from the double reference.
By static reasoning every output is `anchor`-ed to the exact double value, so this
*should* pass; the drift's cause is not yet explained (likely a wiring bug, but
unproven). This is the gate.

**Candidate L-B — package the splice as a primitive** (the reverse, multi-output
dual of `register_implicit`). Keeps the splice's real virtue: the output *value*
is the exact double leaf output (`supplied_derivative`'s `y_value`), and only the
*derivative* is injected — so **R5 value-reproduction is guaranteed by
construction**. Hides all raw XAD behind one call and lets the primitive own the
`chain_sign` correctly *once* (so future strategies can't re-trip b1). Costs: keeps
the per-cohort-step full sub-Jacobian (m sweeps × ~590k steps — wasteful for a
scalar reduction that needs one adjoint direction) and the whole-leaf snapshot;
adds one concept instead of deleting machinery.

**Decision rule:** resolve *why L-A drifts R5*. If it is a fixable
value-preservation detail (the anchor/soil path not fully value-neutral) → **L-A
wins** decisively (simpler, deletes machinery, fixes two bug classes). If the
double GSS-optimum leaf output genuinely cannot be reproduced by the `S`
re-assembly to 1e-8 → **L-B wins** (its by-construction value guarantee is then
load-bearing, not incidental). This is a ~1-build experiment, deferred here per
the "study first" steer, but it is the *only* thing blocking convergence on the
leaf.

## Killed candidates (so the next search starts from the map)
- **Template the whole `Leaf` on `S`** — the hydraulic solve is an *adaptive*
  Brent/golden-section; its iteration count branches on values → non-differentiable
  and unrecordable. `assemble_leaf_from` exists precisely to re-express the
  *converged* leaf output smoothly (Brent off-tape via `implicit_value`). Dead.
- **Hand-analytic leaf Jacobian** — the hydraulics are too intricate to
  differentiate by hand maintainably; AD of the assembly is the point. Dead.
- **`XAD_TAPE_REUSE_SLOTS`** — slot aliasing vs callback edges. Dead.
- **Discrete adjoint ODE (no tape at all)** — a principled but far larger reframe;
  AD + checkpointing suffices. Deferred, not pursued.

## Memory (orthogonal to the leaf question)
- **Segmented checkpointed replay** is the one memory primitive (XAD's
  `ScopedNestedRecording` stage-checkpointing lifted to the Solver's fixed-schedule
  replay; fresh recording per window resets the slot counter). Bounds the
  forward-record peak for any flat tape. Needed for high life regardless of L-A/L-B.
- **But its urgency drops under L-A:** TF24's 268M-slot high-water is a folding
  pathology of the splice's nested sub-recordings; a flat tape's slots track
  statements (~single-digit M), so L-A likely *shrinks* TF24 memory outright.
- **Forward mode sidesteps the tape entirely for few-trait gradients**
  (`compute_jvp`, no tape). A mode policy in the entry (forward when n_inputs is
  small, reverse when n_outputs is small) is a cheap, exact win for single-trait
  sensitivities — and it is already implemented in odelia, just not wired to the
  SCM entry.

## Linked accuracy track (independent of DX, but it touches the same code)
The interior-`p*` derivative uses a **nested finite difference** (a central diff of
`profit_reduced`, itself FD-solved) — the oracle flagged this as the source of an
inaccurate `∂²profit/∂p²`, and it is the still-open **task #23** and the likely
residual behind the long-unresolved **AD/FD≈2.7**. The leaf already ships the
*analytic* `dprofit_droot_collar_psi`. Using it for the stationarity residual
removes one FD layer (accuracy) AND removes `profit_reduced`'s mutating re-solves
(`find_psi_stem_from_psi_root`→`E_up_`, `psi_stem_to_ci`→`ci_`) — which is what
forces the whole-leaf snapshot. So this one change may **fix the accuracy AND drop
the snapshot** (the 590k Leaf copies), and it composes with either L-A or L-B.

## Consolidations (concept-count, ride along)
- Name `graft_value` (= `anchor` = `implicit_value`'s idiom); a scalar
  `derivative_of` for the 2 raw-`xad::fwd` sites in `leaf_model.cpp`.
- Merge `implicit_value` + `register_implicit` into one IFT family with a
  partial-source policy {analytic | forward | reverse-local | FD}.
- Move the `rebind_from` completeness guard into odelia (plant re-implements it as
  R5); finish the TF24 env-soil double→active crossing it flags.
- Surface the FD-free dot-product oracle (`⟨Jv,u⟩=⟨v,Jᵀu⟩`) at the R boundary so a
  strategy author certifies a gradient with no FD reference. (This is also the
  clean resolver for "is the reverse graph fully connected".)
- Deferred (no witness yet): recorder mixin for adaptive backgrounds; named
  `DifferentiationTargets`; unifying the `SCM`/`Solver` L1 contract.

## The DX baseline this establishes (the answer, once the gate resolves)
A future strategy author writes only: physiology in `S`; `PLANT_DIFFERENTIABLE` +
an `*_AD_FIELDS` list; for an expensive *double* inner solve, an `assemble_from`
in `S` using `implicit_value`/`graft_value`; for an off-optimum channel, one seam
hook. Under **L-A** they then just *use* the assembly (no injection); under **L-B**
they hand it to one `spliced_jacobian` call. Either way: **no `xad::`, no tape
management, no hand-rolled recorder**, with memory-bounding and an R-level oracle
for free. The envelope-theorem structure stays strategy-side (irreducible ecology)
but becomes the only thing strategy-side.

## Phasing
- **Phase 0 (gate):** resolve why L-A drifts R5 (one focused build); pick L-A or L-B.
- **Phase 1:** implement the chosen leaf mechanism; refactor TF24 onto it,
  bit-identical, gated by R5 + the dot-product oracle. + `graft_value`/`derivative_of`.
- **Phase 1b (accuracy):** analytic `p*` stationarity (task #23); re-check AD/FD;
  drop/target the snapshot.
- **Phase 2 (memory):** segmented checkpointed replay + `Control` window knob +
  forward-mode option for few-trait gradients.
- **Phase 3:** rebind guard into odelia + finish TF24 soil crossing; oracle at R.
- **Phase 4:** IFT-family merge; deferred consolidations when a witness lands.
