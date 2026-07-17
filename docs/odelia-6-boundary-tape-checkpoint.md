# odelia design #6 — the Solver/SCM boundary, the growing tape, and checkpointing

Run under the system-design skill at the user's request, over three coupled decisions. The explicit
scarce resource here is **developer/reader working memory — concept count** (the code-review principle:
an abstraction must *reduce* complexity; a named object that merely relocates it makes DX worse). So the
bar for any new name is high, and "the floor is the design" is the target outcome, not a fallback.

## Triage: 2–3
The Solver/SCM seam is a module boundary with the gradient driver + plant as consumers; the tape/memory
decisions are internal and reversible. One coupled design because all three answer *where the
growing-dimension integration machinery lives and what it costs in names*.

## Requirements ledger
- **R-fewnames — a reader learns the fewest possible concepts for the SCM↔odelia seam.** *Quantity:* the
  target is **0 new named concepts**; every candidate pays for each name against a bug class removed.
- **R-tape — the reverse tape survives the mid-run resize.** *Quantity:* `N≈10²–10³` introductions;
  **confirmed** (v1 + `test-ad-growing-resize.R`). *Mechanism (spike):* `AReal` holds a slot **index**
  (`getSlot()`); the tape records against slot indices, so a `vector` realloc move-constructs the `AReal`s
  to new addresses **without touching their slots** — the tape is immune to the memory move. This is *why*
  v1 worked.
- **R-resize-perf — the per-introduction resize is not a hotspot.** *Quantity:* amortized **O(N) cheap
  POD moves** (geometric growth), dominated by the O(N·steps·stages) integration. Reasoned, unmeasured.
- **R-memory — peak tape memory < budget.** *Quantity:* ~0.5–4 GB estimated (catalog), fits a
  workstation; v1 never checkpointed. Not precisely measured.

**Scarce resource:** *concept count / working memory* — compute and RAM are ample (the ledger says so);
what is scarce is how many named objects a developer must hold to understand the seam.

## The floor
**Add nothing.** The SCM already HAS-A `Solver<patch_type>` and owns its `run_next_impl`
(`[grow][resize][integrate]`) loop, delegating stepping; the gradient driver duck-types the runnable
(`reset/run/get_system_ref/tape`). No `Runnable` concept, no `reserve_state` call, one tape.
- *R-fewnames:* 0 new names. ✓
- *R-tape:* confirmed by the spike + the test. ✓
- *R-resize-perf:* amortized-O(N) POD moves — not a hotspot (reasoned). ✓
- *R-memory:* fits (estimated). ✓ (measure to confirm.)

The floor suffices on every line whose quantity is known, and the two unknowns (resize-perf, memory) are
**measurements, not designs**. Per the skill: recommend the floor and stop — unless a candidate removes a
bug class the floor leaves open.

## Candidates (the boundary — the only sub-decision with a real fork)
- **A [first thought — the one to kill]** (`Runnable` concept): name the duck-typed surface as a C++
  `concept` + `static_assert(Runnable<SCM>)`. *Commitment:* the seam is a named contract. *Pays:* a better
  compile error + a documented surface. *Costs:* **+1 concept** (against R-fewnames). **Eliminated:** it
  removes **no bug class** — the load-bearing guarantee (the tape survives resize) is a *runtime* property
  a `concept` cannot check; a test checks it (and exists). So `Runnable` relocates the implicit surface
  into an explicit name without deleting a category of bugs — the exact abstraction-for-its-own-sake the
  user flagged. A concept that only improves a compile message is not worth a permanent name.
- **B [the floor]** (move 3, document at the boundary): a **comment** on the gradient driver naming the
  ~5 methods it calls, and the existing growing-resize **test** as the runtime guarantee. *Commitment:*
  none. *Pays* R-fewnames (0 names) + documents the surface where it is consumed. *Wins when* the seam has
  one witness and the guarantee is a runtime property (both true).
- **C** (move the boundary into odelia — the post-hoc cleanup candidate): odelia `Solver` grows an
  introduction/event hook and owns the loop; the SCM becomes a plain System. *Commitment:* odelia owns
  the growing loop. *Trade:* swaps the SCM-run-loop for a Solver-hook — roughly name-neutral, cleaner
  layering (plant declares, odelia drives). **Deferred, not eliminated:** one witness (the SCM);
  generalizing the Solver over a single structured-population model is the YAGNI trap. *Retrofit trigger:*
  a second growing-dimension System — then C's layering wins and the generalization is earned.

**Winner: B — the floor.** `Runnable` (A) is dropped: it adds a name without removing a bug class. C is
the named cleanup to reach for later, on a second witness — the "clean up post hoc" the user is open to.

## The commitment
**None new — the floor is the design.** The SCM stays the runnable by duck-typing; the gradient driver's
required surface is a comment where it is called; the growing-dimension guarantee is a test, not a type.

Kept true by structure: there is nothing to keep — the absence of a concept cannot be violated. The one
discipline: the driver's method list lives in a comment *at the call site* (not a floating doc), so it
can't drift from what `compute_jacobian` actually calls.

## Kill question
**Assumption whose falsity would force a new name:** *the SCM↔odelia seam has one witness and its
correctness guarantee is a runtime property.* If a **second** growing-dimension System appeared, C's
`Solver`-owns-the-loop earns its keep (a shared mechanism over two witnesses, smaller than two bespoke
loops). None exists today, so the floor holds; the trigger is recorded.

## The three verdicts
1. **Solver/SCM boundary → the floor. Drop `Runnable`.** Document the driver's required methods in a
   call-site comment; keep the growing-resize test as the guarantee. Defer C (odelia-owns-the-loop) to a
   second-witness retrofit. This **reverses odelia #5's "formalize a Runnable concept"** — that was the
   overbuild the user caught.
2. **Growing tape / `reserve_state` → deletion candidate.** The spike shows the resize is amortized-O(N)
   slot-preserving POD moves (the tape is immune, by slot-index). So `reserve_state` buys ~nothing.
   *Action:* a ~5-line timing spike on `test-ad-growing-resize.R` (with vs without `reserve_state`); if no
   measurable benefit (expected), **delete `reserve_state` from odelia** — an unused abstraction is the
   same debt as an unneeded one. If it surprises us (a per-`AReal`-move tape cost I could not rule out
   from the headers), keep it and call it once. **Do not add it to the critical path either way.**
3. **Checkpointing → measure-gated, no new name.** The floor is one tape (v1, worked). *Action:* instrument
   peak tape bytes on the largest resident-census gradient. If it fits the budget (expected), no
   checkpointing. If it breaches, checkpoint at the node-introduction boundary using the **vendored
   `XAD::CheckpointCallback`** (already used by `SuppliedDerivative`) — reuse, not a new abstraction. The
   introduction boundary is the natural segment edge; nothing else changes.

## What this settles (code not written, names not added)
- **No `Runnable` concept, no `static_assert`, no new type** at the SCM/odelia seam — a call-site comment
  + one test.
- **`reserve_state` is on the chopping block**, not the critical path — a profile decides keep-or-delete.
- **No checkpointing machinery** unless a memory measurement demands it, and then only the vendored
  callback.
- Net new named concepts across all three decisions: **0** (target met).

## What this makes hard
- **A worse compile error** when a future System forgets a runnable method (no `concept` to name the
  requirement). *Cope:* the call-site comment + the template error at `solver.run()` — acceptable for a
  one-witness seam; if it ever bites twice, that is also the C retrofit trigger.
- **A second growing-dimension System** would find no shared Solver machinery. *Cope:* that is exactly
  when C is built — the trigger is recorded, information only increases.

## Kill condition
A second growing-dimension System (or a measured resize/memory hotspot) → revisit: C (odelia owns the
introduction loop) for the boundary, a `reserve_state` call for the resize, `CheckpointCallback` at the
introduction boundary for memory. Each is a named, triggered retrofit — none paid for today.
