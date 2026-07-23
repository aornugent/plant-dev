# Design — bounding reverse-tape memory for the SCM gradient

_System-design pass (Tier 3). Inputs: the session's tape measurements
(`PLANT_TAPE_STATS`), XAD's tape API, `odelia/AUTODIFF.md` (the Solver owns the
L1 schedule; record→replay), and the DX objective (concept count)._

## Triage: 3 — a new AD-engine primitive touching the tape memory model, in
odelia, affecting all three strategies and every future gradient. Expensive to
reverse; requirements arrived partly as a solution-verb ("tape checkpointing").

## Requirements ledger
- **R1 — TF24 full-SCM gradient is memory-feasible at the verification life.**
  Today OOMs by ~life 10; life=4 already uses 2.15 GB. Target: life ≥ 10 within
  a few GB. (This is the concrete blocker on task #27.)
- **R2 — one idiomatic mechanism across FF16/K93/TF24**, not per-strategy fixes.
  Quantity: net new *caller* concepts = 0 (the `scm_gradient(p, ctrl, targets,
  functional)` surface must not grow); net new *engine* concepts ≤ 1.
  (challenged upward: the user asked for one primitive "ideally" — confirming R2
  is a hard requirement, not just a preference, because the alternative is 2
  divergent per-strategy fixes below.)
- **R3 — caller value/gradient unchanged** (bit-reproduction of today's result;
  the existing R5 assert must still pass).
- **R4 — compute overhead bounded**: no worse than ~1 extra forward pass.

Scarce resource: **tape high-water memory** — the persistent
`operations_ + statements_ + derivatives_` arrays that grow with the *whole*
N-step replay. (Wall-time is secondary; the reverse sweep is cheap — TF24's is
97 ops.)

### What the measurements pinned (so the design targets the real cost)
- **FF16/K93 OOM = recorded content.** FF16 life=2: 57.9M ops + 39.8M stmts =
  1.29 GB. Quadrature is only **~29%** (0.79M ops/GK-point × 21; verified by
  scaling the rule 15→41). The other ~71% is the general recorded trajectory —
  so the lever must bound *total* recorded content, not quadrature.
- **TF24 OOM = slot ratchet, not content.** ops=97 / stmts=95 *constant* across
  life (per-step sensitivity rides `supplied_derivative` `CheckpointCallback`
  edges, not recorded ops). Memory is the `derivatives_` slot vector: ~76M
  slots (life 2) → ~268M (life 4), because `XAD_TAPE_REUSE_SLOTS` is off and
  active temporaries free non-LIFO so `maxDerivative_` ratchets monotonically.
- Both causes are rolled back by the *same* XAD operation: `resetTo(pos)`
  discards `operations_`/`statements_` after `pos` **and** rolls back
  `iDerivative_` (reclaims slots). One primitive can bound both.

## The floor
Two targeted fixes, no new engine concept:
(a) TF24 — reduce active-temporary minting in `compute_rates` (compute geometry
in `double`, cross to active later) to stop the slot ratchet;
(b) FF16 — leave as-is (fits to ~life 40-50, likely adequate).

**Fails R2, and (a) fails its own feasibility check.** (a) is TF24-only and
FF16-only respectively — two mechanisms, not one. Worse, (a) is *unproven*: the
95-stmt/76M-slot split means we cannot yet say the slots come from *avoidable*
temporaries rather than the *intrinsic* active state the trajectory carries
(the state is active precisely because it carries the trait sensitivity —
`to_passive`-ing it would sever the gradient, violating R3). A floor that might
sever the gradient is not a floor. So the floor does not hold; R1+R2 must be
paid by a mechanism that bounds memory **regardless of the slot source**.

## Candidates
A [first thought] **move 4 (checkpoint & replay the middle)** — *segmented
checkpointed reverse*. Partition the recorded L1 schedule into K windows. The
existing double schedule-discovery pass also snapshots the (double) System state
at the K-1 window boundaries. The reverse driver then, for each window from last
to first: restore the boundary state, re-record *only that window* on a fresh
tape, sweep it, carry the window-boundary state-adjoint to the previous window,
`resetTo`/`clearAll`. Commitment: the tape holds at most one window at a time.
Pays for R1 (memory → O(N/K)) **and** the TF24 slot ratchet (resetTo reclaims
slots per window) with one mechanism → R2. Costs: one engine concept
(windowed replay) + carrying the boundary state-adjoint. Wins when: the cost is
memory-over-a-long-replay and a cheap pass already knows the trajectory — which
the ledger says it is.

B **move 1 (weaken exactness) — flip `XAD_TAPE_REUSE_SLOTS`.** Commitment: freed
slots are recycled via a free-list. Pays for R1 on TF24 only (slots). Costs:
*unsafe* — `supplied_derivative` stores raw slot IDs in callback edges that fire
during the sweep; a recycled slot corrupts the adjoint (R3). And it does nothing
for FF16's recorded content (R1 for FF16). Eliminated: fails R2 and R3.

C **move 7 (amortize) — batch the tape across cohorts / shrink per-step minting.**
Commitment: fewer active temporaries per cohort-step. Pays partially for TF24
slots. Costs: per-strategy hand-optimization, model-by-model, fragile; doesn't
touch FF16 content. Eliminated: fails R2; same unproven-feasibility risk as the
floor's (a).

Winner: **A**. Eliminations: B fails R3 (callback slot aliasing) and R2 (FF16);
C fails R2 (per-strategy) and shares the floor's unproven feasibility.

## The commitment
**The reverse tape holds at most one schedule-window's recording at any time.**
Kept true by: structure — the reverse driver owns the tape lifecycle; it calls
`newRecording` at a window's start and `resetTo`/`clearAll` at its end, so a
second window's content is never expressible on the tape simultaneously. Memory
is thereby O(window), independent of N and of what mints slots.

## Kill question
Assumption whose falsity makes this unnecessary: *"no cheap per-strategy fix
bounds memory for all strategies at once."* Argued from ledger facts: TF24's fix
(slots) and FF16's fix (content) are different mechanisms and TF24's is unproven
(may sever the gradient), so no single cheap per-strategy fix exists → the
assumption holds → the primitive survives. (If a future finding shows TF24's
slots are entirely avoidable *and* FF16 never needs life > ~40, this design
becomes unnecessary — that is the kill condition below.)

## What survives deletion
- Windowed replay loop → R1/R2 (the whole point).
- Boundary **double** state snapshots → R4 (reuse the existing double pass;
  without them the reverse would need a second forward, breaking R4).
- Carried window-boundary **state-adjoint** → R3 (reverse-mode correctness
  across windows; without it the gradient is wrong).
- K (window count) as a `Control` knob → R1 (tunable: TF24 wants small windows
  for slots, FF16 trades content; same knob, one concept).
Nothing else. No caller-facing name (R2's 0-concept clause): `scm_gradient`'s
signature is unchanged; the windowing lives inside the entry / Solver.

## What this settles
- No `XAD_TAPE_REUSE_SLOTS` flip (candidate B deleted) — the callback-slot
  aliasing hazard is never introduced.
- No per-strategy tape surgery in `compute_rates` (floor/C deleted).
- The plant developer learns nothing new: same call, same result, more life.

## What this makes hard
- Wall time: bounded by R4 to ~one extra forward's worth of state-restore +
  re-record bookkeeping; if K is pushed very large (TF24 pathological slot
  control) the per-window overhead grows — cope by tuning K, and later by
  Revolve-style log-scheduling if ever needed (not now — one witness).
- A window boundary lands mid-way through a cohort introduction: the boundary
  snapshot must capture the full System state (nodes + environment + birth
  bookkeeping), i.e. exactly what `rebind_from` already carries — cope by
  snapshotting through that same contract.

## Kill condition
TF24's slot minting is proven fully avoidable at the plant level **and** FF16's
life-40 ceiling is confirmed adequate → hands off to the floor (targeted
per-strategy fixes, no primitive). Until both hold, the primitive is the design.

## The design (sketch)
1. **odelia Solver / `scm_jacobian`**: add a windowed reverse mode. The double
   pass (already run to discover the schedule) additionally records the System
   state at K-1 boundary step-indices.
2. **Reverse driver**: for w = K-1 … 0: `rebind_from` + restore boundary state
   w; `newRecording`; replay window w's steps (active); register the window's
   output = (final functional for w=K-1, else the next window's boundary-state
   leaves); `computeAdjoints`; read the boundary-state adjoints as the seed for
   window w-1; accumulate the target-input adjoints; `resetTo`/`clearAll`.
3. **Data flow**: target-input adjoints accumulate across windows; boundary
   state-adjoints chain windows. Bit-identical to the single-tape result (R3),
   verified by the existing R5 value assert plus a gradient equality check
   between K=1 (today) and K>1.
4. **Knob**: `Control::gradient_tape_windows` (default 1 = today's behaviour;
   >1 enables windowing). One field, no caller change.
