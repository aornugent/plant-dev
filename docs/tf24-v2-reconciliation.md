# Reconciling the two experimental arms (2026-07-21)

Two arms of investigation now meet on the same phenomenon. This records how they
fit — and where the newer arm **revises** the older one's verdict.

## Arm 1 — the placement/measure ladder (through rung 2)

Run against the benchmark bank of challenging rainfall scenarios. Rung 2
(goal-oriented placement) returned:
- The **default fixed schedule is a bad universal starting point** (up to ~10× off at
  its own node count; plain uniform 3–35× closer). A cheap, robust DX win.
- **J does not converge under node-count refinement for any placement family**
  (default/uniform/g-mass disagree 9–45% at 4×; successive deltas grow).
- **Verdict (as written):** refining moves which marginal members cross the ρ→0
  survival threshold → J jumps non-monotonically → "*no placement indicator can
  certify a limit that does not exist*" → **item B (J is intrinsically discontinuous;
  fix is model-side mollification, not numerics).**
- **Open idea:** the rainfall sequence as a prior (rung 3 rainfall-as-locator: drought
  windows predict the lineage-ages carrying survival crossings). Not run.

## Arm 2 — the coupling/spectrum arm (this session)

The v2 Oracle response reframed κ≈10 (9b) as the loop gain behind the whole
approximation graveyard *and* behind 9c. Two decisive offline tests run:
- **T1 (Arnoldi on T′) → Outcome A.** ρ(T′)≈7–8 (WR dead), but nothing at +1 (nearest
  eigenvalue 0.05–0.2 away, conditioning ~5–22). **The mean-field fixed point is
  well-conditioned: the continuum J exists and is a stable observable.**
- **T4 (filtered-field probe).** J invariant (≤3%) to removing all `u`-texture below
  ~2 days; the member block is over-resolved ~30–100× (needs only the weekly-and-slower
  envelope of `u`).

## The reconciliation (the crux)

**T1 overturns arm 1's central interpretation.** Rung 2 inferred "*a limit that does
not exist*"; T1 measures directly that the limit **does** exist and is well-conditioned.
Not a data conflict — the *same phenomenon* (9c ≡ rung-2 non-convergence) — but the
inference was premature:

- Rung 2 saw non-convergence **under τ_ins refinement** and concluded no limit.
- τ_ins refinement is the **wrong axis**: it adds *light* members but never splits the
  *emergent heavy* atoms (9a: a 40%-mass atom is O(tens of %) from its own limit no
  matter how many light members are added).
- T1 shows the limit exists → "non-convergence under τ_ins" is consistent with "a limit
  exists," reached only by a *different* refinement: **heavy-atom splitting.**

**Consequence for the survival-flip discontinuity** (the 1532× spike; a 40%-mass atom
present in one mesh, absorbed in the next): re-read as a **granularity artifact of the
coarse measure**, not intrinsic. Split that atom into many light children and its
boundary crossing resolves smoothly (a fraction crosses at a time), instead of flipping
as one lump.

**Consequence for item B:** possibly unnecessary. Rung 2 said the fix *must* be a model
change (mollify J). T1 says it is likely a numerical protocol (wrong refinement axis).
**T5 (heavy-atom splitting) is the decider:** J moves under splitting → the fix stays in
numerics, item B is off the table; J invariant under splitting → granularity is
innocent, item B survives (the discontinuity is genuinely in the model).

## What stands, what folds in

- **Default-bad / uniform-3–35×-better** stands independently — still a cheap DX win.
  T1 reframes it as a *partial* fix; the real convergence fix is splitting, not placement.
- **The rainfall prior is now more motivated and bridges both arms.** T4: J needs only
  the weekly-and-slower `u` envelope — set by the rainfall envelope — bounding how coarse
  a member step is safe. Survival crossings (atoms to split/place) are driven by drought
  windows. So the same sequence is a prior for *both* where to split/place members *and*
  how coarsely to advance them. Untested (rung 3 / part of T5).

## UPDATE — the claim-4 leg is FALSIFIED (T5a), which redirects the whole plan

Before building T5's split machinery I checked its premise directly (run N/2N/4N, read
per-node weights: `emergent_skewness.R`, `tf24-v2-T5a-emergent-skewness-result.md`).
**The premise is false.** The heaviest atom carries ~1.6% of the J-mass (not ~40%) and
its fraction **halves each mesh doubling** (∝1/M) — the measure has no dominant atom and
τ_ins refinement subdivides it cleanly. The Oracle conflated 9a's whole-second-**species**
weight fraction (0.388) with a single **cohort** (~1.6%).

**So the reconciliation must be restated.** Two legs, one survives:
- **T1 leg stands:** the coupling field `a*` is well-conditioned; the continuum exists.
- **Claim-4 leg falls:** the non-convergence is **not** heavy-atom granularity, because
  there is no heavy atom and the measure refines cleanly.

**With granularity out and the field well-conditioned, the residual J-movement must be
field-shift (κ-amplified feedback) and/or survivor-flips (members crossing ρ→0
differently at different meshes).** The survivor-flip is precisely the intrinsic
survival-boundary discontinuity rung 2 routed to **item B** — and T1 does NOT protect J
from it (T1 conditions the field `a*`, not the moment across the boundary). **So item B
is back on the table as a live cause**, and the reconciliation is no longer "T1 rescues
the forward problem, fix is splitting." It is: **T1 says a limit exists; the question is
whether the residual non-convergence is protocol (field-shift/placement) or intrinsic
(survivor-flips = item B).**

## Status of the remaining closers (revised)

- **T5 — heavy-atom splitting: DROPPED.** Premise falsified by T5a; nothing heavy to
  split; do not build the cohort-split machinery.
- **T3 — common-field ΔJ decomposition: now the DECISIVE test.** Splits the J-movement
  into field-shift (protocol; placement/feedback — fixable in numerics) vs survivor-flips
  (intrinsic; item B — model-side). This is the fork the line of work now turns on.
- **T2 — insertion-transient audit:** still useful; a growing-with-density insertion mass
  is another protocol candidate for the field-shift term.
- **T4→T6 — the arbitrage:** independent of the above; Newton-on-g offline falsifier
  gates the ~30–100× member-step arbitrage. Still live and high-value.

## RESOLVED by T3 — the non-convergence is field-shift (protocol), not item B

T3 (`tf24-v2-T3-common-field-decomp-result.md`) settles the fork on both sequences
(intense_storms, whiplash — the latter carried 9c's 1532× spike): the mesh J-movement is
**~0% placement/quadrature, 100% κ-amplified field-shift, diffuse (no survivor-flip
spike), at small τ_ins.** So:
- **Item B is off the critical path.** The survival-boundary discontinuity does not drive
  the non-convergence; the 9c 1532× spike was a low-g lineage's *relative* error,
  J-negligible. Rung-2's "intrinsic discontinuity → must mollify J model-side" is
  **overturned.**
- **The fix is numerical: converge the field `a* = ∫c dμ`.** J's own integrand is already
  mesh-converged; the field (a c-weighted moment) is not, and feedback amplifies its
  residual ~10× into J. The production default mesh is far from *field*-converged.
- **Why g-mass placement anti-correlated (rung 2):** it targeted J's integrand, which is
  converged; the error is in the field. The right indicator targets field convergence,
  resolvent-weighted `(I−T′)⁻¹` — the Oracle's claim-1 proposal; T1's dominant modes are
  those weights.

## Final reconciliation (T1 + T5a + T3)

- **T1:** field `a*` well-conditioned; continuum J exists and is stable.
- **T5a:** measure refines cleanly (max weight ~1.6%, ∝1/M); no heavy atom (claim 4 wrong).
- **T3:** mesh non-convergence is 100% field-shift (feedback), diffuse, at small τ_ins.

**Both arms now meet cleanly.** Arm 1 (placement ladder) observed non-convergence and the
badly-placed default; arm 2 explains it: the coupling **field** is under-resolved at the
default mesh, and feedback amplifies the residual — a numerical protocol problem, not the
intrinsic J-discontinuity arm 1 inferred. The default-schedule DX win stands (it's the
field being coarse). The rainfall prior stands (drought windows shape the field). The
arbitrage path (T4→T6, member block over-resolved in *time*) is orthogonal and live.

## What remains
- **The forward-convergence lever:** a field/resolvent-weighted member-mesh indicator
  (target `a*` convergence, not `g`); T1's dominant modes supply the resolvent weights.
  A multi-level (N→2N→4N) field-shift/Richardson read on `a*` would size the convergence
  rate (T3 measured one N→1.5N step).
- **The time-arbitrage:** T6 (Newton-on-g offline falsifier) gates the ~30–100× member
  macro-step (T4).
