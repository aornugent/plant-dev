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

## Premise check before building T5

T5's split machinery rests on the claim that **skewness is emergent** (max ρ_j ~0.3–0.4
at every mesh density). Verified directly first (run N/2N/4N, read per-node weights):
`scripts/tf24-benchmarks/emergent_skewness.R`, result appended below.

## Status of the two remaining closers

- **T5 — heavy-atom splitting** (needs a measure-preserving mid-run cohort split;
  cannot be faked with the frozen-field probe because probe error is O(weight fraction)
  and heavy atoms are exactly where it fails — 9a: 63% error at 0.39). Decides item B.
- **T4→T6 — the arbitrage** (Newton-on-g offline falsifier gates the cheap `a(u)`
  refresh that realises the ~30–100× member-step arbitrage).

## Bottom line

Arm 2's T1 **rescues the forward problem** from arm 1's "intrinsic discontinuity, needs
a model change" verdict: the continuum J is well-posed, and 9c/rung-2 non-convergence is
a fixable wrong-axis discretisation protocol. The benchmark bank and rainfall-prior fold
into the two closers (T5, T6) rather than forming a separate track.
