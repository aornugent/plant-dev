# Design — reverse-mode as an idiomatic odelia DX across strategies

_Holistic system-design pass (Tier 3), after a deep study of the odelia + plant
diffs, the vendored XAD source + docs, and XAD's external performance guidance.
Supersedes `tape-memory-design.md` (which addressed only memory and mis-scoped
TF24's cause — corrected in §Memory below). Four strategies (FF16, K93, TF24,
TF24f) now have reverse mode; this establishes the baseline that future
ecological complexity plugs into without re-inventing tape machinery._

## Triage: 3 — AD-engine boundary spanning odelia + plant, all strategies,
every future strategy. Requirements arrived partly as a solution-verb
("checkpointing"). Study-backed; a spike (the tape measurements) already ran.

## Requirements ledger
- **R1 — a new strategy adds only *ecology* to get reverse-mode gradients.**
  Quantity: net new `xad::` touch-points in a new strategy = **0** (today TF24
  has ~15 raw-XAD sites in one function; a new strategy would copy them).
- **R2 — the shared substrate stays zero-tape-code.** K93/FF16 already add no
  tape machinery; that must remain true and become the *only* option.
- **R3 — reverse-mode memory is bounded so verification is feasible.** TF24
  OOMs ~life 10; target life ≥ 10 within a few GB. Bound must hold for *both*
  tape shapes (flat and seam).
- **R4 — DX measured as concept count must go DOWN, net.** A plant developer
  should learn a small differentiation vocabulary, not XAD tape internals.
- **R5 — correctness is checkable by the author, cheaply.** Today the FD-free
  oracle exists but is C++-only; a strategy author cannot certify a gradient
  from R.

Scarce resource: **the plant developer's working memory** — every raw-XAD
concept a strategy must reason about is the cost; and, separately, **reverse
tape peak memory** for R3.

### What the study established (load-bearing facts)
1. **The shared substrate is already the target shape.** `scm_gradient` +
   `rebind_from`/`PLANT_DIFFERENTIABLE` + the `*_AD_FIELDS` X-macro +
   `census<Ψ>` + odelia's mass chart mean **K93 and FF16 add zero tape code**
   (their large header diffs are physiology relocated + templated on `S`).
2. **All hand-rolled tape machinery lives in one function** —
   TF24 `net_mass_production_dt` (src/tf24_strategy.cpp ~L554-715), plus a
   two-derivative forward-mode helper in `leaf_model.cpp`. Every `xad::Tape`,
   `registerInput`, `computeAdjoints`, `derivative()`, `deactivate/activate`,
   `shouldRecord()` site is there.
3. **That machinery is XAD's *sanctioned* pattern, hand-rolled.** XAD's docs
   endorse "external function / manual analytic adjoint" for an expensive
   off-tape sub-solve (root-find / optimiser) whose derivative is known — inject
   it via a `CheckpointCallback`. odelia's `supplied_derivative` **is** that
   idiom. So the fix is not to change the approach; it is to *package* it.
4. **odelia already has the forward+scalar dual** of this: `register_implicit`
   / `implicit_value` (IFT: `dy*/dp = -F_p/F_y`, inner solve never recorded).
   The reverse, multi-output case (leaf profit + per-layer uptake) has **no
   primitive** — so TF24 open-codes it.
5. **The two tape shapes and the OOM.** Flat (FF16/K93): every op recorded on
   the run tape; memory ∝ work × steps; not truncated by the sweep. Seam (TF24):
   the leaf solve is off-tape, but the *non-leaf* S-geometry still records per
   cohort-step, ratcheting `maxDerivative_` to 268M slots @ life 4;
   per-checkpoint `resetTo` truncates ops/stmts during the sweep but **never
   resets `derivatives_`/`maxDerivative_`** (XAD Tape.cpp), so the slot
   high-water is the surviving cost and the seam does **not** bound step-count
   memory. Both shapes accumulate a forward-pass peak ∝ steps.
6. **`XAD_TAPE_REUSE_SLOTS` is unsafe here and must stay off** — `supplied_
   derivative` edges store raw slot IDs that a reused slot would alias. (Kills
   the candidate from the prior design doc outright.)

## The floor
Keep TF24's seam as the copy-me template; no odelia change. **Fails R1/R2/R4**:
every future strategy re-rolls ~15 raw-XAD sites in its own `compute_rates`, and
the raw-tape vocabulary is exactly the working-memory cost R4 forbids. **Fails
R3**: no memory bound; TF24 stays capped ~life 10. The floor does not hold.

## Candidates (the design is two orthogonal primitives + consolidations)
The study shows the friction is two *independent* things — tape *plumbing* (a DX
problem) and tape *peak* (a memory problem) — so the design is two primitives,
each strategy-agnostic and each an instance of an XAD-endorsed pattern.

**P1 [Pólya, with witnesses] — `odelia::ode::spliced_jacobian`: the reverse,
multi-output dual of `register_implicit`.** The witnesses are real and ≥2: the
TF24 leaf profit/uptake seam today, and TF24f's collar channel; every future
strategy with an expensive double sub-model is the third. Commitment: *a model
never touches `xad::` to differentiate an off-tape sub-computation.* The
primitive owns the entire dance — input collection + `shouldRecord` filter, run
tape stand-down, the transient local tape lifecycle, the per-output adjoint
sweep (`clearDerivatives` + reseed), reading input adjoints, reactivation, and
the `supplied_derivative` injection of each output row. The caller provides only
(a) the active input handles and (b) an `assemble(...)->outputs` functor written
in `S` — the ecology. Pays R1/R2/R4. Costs: one new concept, and an optional
scratch save/restore hook (the Leaf's mutable scratch — the primitive can't know
what to save, so it takes a scope guard).

**P2 [trade compute for storage] — segmented checkpointed replay in the
Solver/SCM.** This is XAD's own `ScopedNestedRecording` stage-checkpointing,
lifted to the fixed-schedule replay loop. Partition the recorded L1 schedule
into K windows; the double schedule-discovery pass (already run) snapshots
System state at the K-1 boundaries; the reverse driver records + sweeps one
window at a time on a **fresh recording** (which resets `maxDerivative_` — the
one thing `resetTo` doesn't), carrying the window-boundary state-adjoint
backward. Commitment: *the tape holds at most one window's forward recording at
a time.* Bounds BOTH shapes (flat: recorded ops/window; seam: slot high-water +
edges/window). Pays R3. Costs: one Solver-level concept + a `Control` knob (K),
default 1 = today. Overhead ~one extra forward's worth of state-restore, because
the boundary states come free from the double pass (not 2× Griewank recompute).

**Consolidations (concept-count reductions that ride along; ranked):**
- **C1 — move the `rebind_from` completeness guard into odelia.** Today plant's
  `scm_gradient` R5 check re-implements it, and it flags that TF24's env soil
  config doesn't cross double→active ("b1") — i.e. TF24 is not yet
  differentiable through the soil channel. The guard belongs in
  `compute_jacobian`; finish the TF24 soil crossing so the guard passes.
- **C2 — unify the IFT family.** `implicit_value` + `register_implicit` +
  P1(`spliced_jacobian`) become one named family "off-tape derivative
  injection" with a partial-source policy {analytic | forward-AD | reverse-local
  | FD}. One concept, four instantiations, replacing two look-alike APIs.
- **C3 — two tiny helpers kill the last raw-XAD in plant:**
  `graft_value(v,x) = S(v)+(x-to_passive(x))` (carry x's derivative, replace its
  value) and a scalar `derivative_of(f,x)` (forward-mode) for
  `dprofit_droot_collar_psi`.
- **C4 — surface the FD-free oracle at the R boundary.** `⟨Jv,u⟩=⟨v,Jᵀu⟩`
  (compute_jvp vs compute_jacobian) already backs every seam test; expose it so
  a strategy author certifies a gradient from R without an FD reference. Pays R5.
- **C5 (larger, phase later) — a `Replayable` recorder mixin + contracted
  `set_recording`** so adaptive-background Systems stop hand-rolling recorder
  state; and unify the "Replayable runnable" contract so `SCM` stops
  re-declaring the Solver's L1 surface by hand.

Winner: **P1 + P2 + C1–C4** now; C5 phased. Eliminations: the floor fails
R1/R3; `XAD_TAPE_REUSE_SLOTS` fails correctness (slot aliasing); a
quadrature-specific memory lever was rejected (measured 29% of FF16, not the
driver).

## The commitments (one per primitive)
- P1: **a strategy differentiates an off-tape sub-model without naming `xad::`.**
  Kept true by structure — the only differentiation entry points a strategy can
  call (`spliced_jacobian`, the IFT family, `to_passive`, `graft_value`) take
  `S` and functors; the raw tape lives behind them. Enforced by a grep gate:
  `xad::` in a strategy `.cpp` is a CI failure.
- P2: **the reverse tape holds ≤ one schedule window.** Kept true by structure —
  the reverse driver owns the tape lifecycle (fresh recording per window,
  `clearAll` between); a second window's content is not expressible.

## Kill question
Assumption whose falsity makes P1 unnecessary: *"future strategies will keep
adding expensive off-tape sub-models."* Argued from ledger facts: TF24 (leaf
hydraulics) and TF24f (off-optimum collar) already have two; the model family's
whole direction is more ecophysiology (NSC storage, acclimation, more hydraulics
— see the plant issue themes). The assumption holds. For P2: falsified only if
every strategy of interest fits in memory at the needed life — false today for
TF24. Both survive.

## What survives deletion
- `spliced_jacobian` → R1/R2/R4 (deletes ~500 lines of TF24 seam + all raw XAD).
- Segmented replay + K knob → R3.
- rebind completeness guard in odelia → C1 (and unblocks TF24 soil).
- IFT-family unification → R4 (two APIs → one).
- `graft_value` / `derivative_of` → R1 (last raw-XAD sites).
- R-boundary oracle → R5.
Not now: C5 recorder mixin (real, but no new witness beyond the existing
adaptive Systems; take it when the next adaptive background lands).

## What this settles / makes hard
- Settles: no `XAD_TAPE_REUSE_SLOTS`; no per-strategy tape surgery; TF24's seam
  becomes a call, not a copy-template; the OOM is bounded for all strategies;
  authors certify from R.
- Hard: P2 adds ~one forward of recompute (state-restore) — fine for
  verification, tune K for production. P1's scratch-guard hook is a small wart
  (the primitive can't know a sub-model's mutable scratch); documented, not
  hidden. A window boundary must snapshot the *full* System state — reuse the
  `rebind_from` contract that already carries it.

## The DX baseline this establishes (the answer to the question)
A future strategy author, to get exact reverse-mode trait gradients + bounded
memory + an R-level correctness oracle, writes **only**:
1. physiology templated on `S` (already the norm);
2. `PLANT_DIFFERENTIABLE` + an `*_AD_FIELDS` list (one macro, one X-macro);
3. for any expensive *double* sub-model: an `assemble_from(...)->outputs` in `S`
   and one `spliced_jacobian` call (P1) — or an IFT node for a scalar solve;
4. for an off-optimum channel (à la TF24f): one `seam_*` hook adding an input.
They never write `xad::`, never manage a tape, never hand-roll a recorder, and
get memory-bounding (P2) and the oracle (C4) for free. The envelope-theorem
structure (`assemble_leaf_from`, the `p*` pivot, the collar channel) stays
strategy-side — it is irreducible ecology — but it becomes the *only* thing
strategy-side.

## Phasing (each phase ships value; code-review each diff)
- **Phase 1 (DX core):** P1 `spliced_jacobian` + C3 helpers; refactor TF24's
  seam onto it (bit-identical; the R5/oracle checks gate it). Deletes the raw
  XAD. — biggest DX win, lowest risk (pure repackaging of a working pattern).
- **Phase 2 (correctness plumbing):** C1 rebind guard into odelia + finish TF24
  soil crossing; C4 oracle at R. — unblocks full TF24 differentiability + author
  certification.
- **Phase 3 (memory):** P2 segmented replay + K knob. — lifts the life ceiling;
  re-measure TF24 forward-peak at K>1.
- **Phase 4 (consolidation):** C2 IFT-family merge; C5 recorder mixin when a
  witness lands.
