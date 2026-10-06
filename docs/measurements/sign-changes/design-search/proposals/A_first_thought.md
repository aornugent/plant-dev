## Candidate A [first thought], move 6 (Pólya, with witnesses)

*The orchestrator's first thought: the incumbent's per-node cut, rebuilt as
one routine. It comes from the code review's blind clean sheet and its
Phase A (subtract) / Phase B (rebuild) plan.*

## Triage: 3. The sweep's record format, odelia's System concept and the passes' agreement are expensive to reverse.

## Requirements ledger
R1–R13 as given. No challenge beyond R4's.

## The floor
No treatment: tol 1e-5 for gradients, and chords at r = 3e-2.
- It fails R8: 1/0.77 = 1.30x the incumbent's runtime at matched gradient
  stability.
- It fails R2 at r = 1e-2: 0.56 eps against eps/3.

## Candidate
**Commitment.** A node's sign change is cut by one templated routine. The
forward, a replay and the sweep all call it, on doubles or on the active
scalar.
- *Witnesses:* three expressions of the same map today. The forward's
  split(), the sweep's taped_split, and the walk's refusal or replay agree
  only by convention.
- *Pays for:* R3, R4 and R9. One body makes a disagreement between the passes
  inexpressible.
- *Costs:* the routine is generic over the scalar. A double-only branch
  (detection) needs `if constexpr` on the scalar.
- *Wins when:* full order at the cut is needed, that is, when a cheaper
  treatment leaves the gradient's nudge spread above eps/3 at 1e-4 or the
  r = 1e-2 chord above eps/3.

**The routine, per step**:
- *Before the FSAL end evaluation,* read the node's net production at the
  stages. A sign change shows by a stage or end sign difference, or by a
  sample near zero.
- *Fit and locate:* sample the block's field at u = 0, 1/3, 2/3, 1 (the field
  builds shared across the step's split nodes), fit a cubic in u to net
  production, and take its roots and slopes from the fit.
- *Integrate the block in pieces* between the roots with the tableau, reading
  the field from the samples' interpolant.
- *Write* the pieces' end into y_end, so the FSAL end evaluation rates the
  corrected state. That removes the unsplit end, the end re-rating and the
  end's taped rate. The pieces' error replaces the kink's in yerr.
- *Record* `std::vector<sign_change>` per block per step (u, slope). Counts
  come from the record, at commit (push_step).
- *Sweep:* the same routine on the active scalar. Each cut's u enters by one
  implicit-function step on the fit's root.

## The commitment
One routine computes a step's cuts and pieces for every pass.
Kept true by: there is one function template, with no second body to drift.

## Kill question
Assumption: full order at the cut is needed. That is false if an
O(h^3)-accurate treatment with no re-rating meets R1 and R2. Unrefuted;
untested.
Verdict: survives on the ledger as written (R2 and R1 were met only by full
order in the record), but hangs on that test.

## What survives deletion
- `sign_change{u, slope}` (R3, R4)
- the routine (R1, R2)
- block field reads (R8)
- the System's block rating hook (R12)
- the per-block record (R4, R11)

## What this settles
Deleted from the incumbent:
- `searched` and `least_rate*`;
- `ode_split_record` as stored state (derived at commit instead);
- `unsplit_end` and the end re-rating;
- the parallel arrays, now one vector of `sign_change`;
- the dead `keep_field` restore and the redundant birth-date loop;
- the runtime refusal, now `if constexpr`;
- the public dense-state hook and its `y_start` copy.
Plant's block reads reuse `n_cohort_reads`, `cohort_reads` and
`set_cohort_reads`.

## What this makes hard
- Still about 12 node ratings and 4 field samples per split node step: about
  4% of a forward and about 4% of a sweep.
- Invaders stay untreated. Their field is recorded only at the resident's
  stages.

## Kill condition
A cheap O(h^3) treatment meets R1 and R2. Any candidate whose "wins when"
says the stage samples suffice.

## The design
- *odelia:* about 170 lines (`cut_sign_changes<T>`, `sign_change`,
  `block_rates`).
- *plant:* about 70 lines (the block rating in a read field).
- Five names.
