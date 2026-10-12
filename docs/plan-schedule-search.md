# Plan: search for the scheduling algorithm against a scored bank

**What is searched:** the scheduling algorithm. That is the rules that turn what a
pilot run reveals, and what later certificates report, into schedules and stop
decisions. It is never a schedule for one case. A rule that fits only the training
cases fails the held-out ones.

**What is minimised:** the total time to a converged answer, summed over the bank:

    T = T_find + k · T_use

- **T_find** is the CPU time of every run the algorithm makes before it commits to a
  schedule: the pilot, each pass, and each certificate run.
- **T_use** is the CPU time of one gradient run on the committed schedule.
- **k** is the number of runs one schedule serves. It is 2: finding a schedule counts
  nearly as much as one use of it. A fast schedule that takes an hour to find loses to
  a slower one found in minutes. Scores are also reported at k = 1 and k = 10.


**Feasibility.** The objectives of `OBJECTIVES.md` are constraints, not the target. A
feasible algorithm meets these on every case:
- **C1 accurate:** every quantity of the reported answer is within ε.
- **C2 no silent miss:** every quantity whose true error exceeds ε/2 has an estimate
  over ε/4.
- **C3 honest:** the estimate is within ×2, with the right sign, for at least 80% of
  quantities with error over ε/3.
- **C4 never fails:** no throw and no refusal.

**Quantities:** ln J and the 48 resident elasticities (without `recruitment_decay`).
Invaders are checked in Phase 5; on these schedules they have been within ε wherever
the resident was (`central.md`).

Out of scope: curvatures; the ODE tolerance, held at the `nr` setting; the
implementation in plant.

**Fast feedback is the design constraint.** An agent must score a candidate algorithm
over the whole training bank in seconds, not by running simulations. So candidates are
scored offline against a library of stored runs. Real runs fill the library in the
background and validate the winner.

## Phase 1 (done): a late cap makes the per-quantity certificate honest

`dy` with late intervals capped at 70 d (`dy70`), hybrid H and coarsening C, on dry and
episodic:

| case | H worst | over ε | read within ×2 (over ε/3) | extrapolated worst | H cost, forward + sweep |
|---|---|---|---|---|---|
| episodic, dy | 1.42ε | 1 | 3 of 5 | 0.47ε | 67 + 219 s |
| episodic, dy70 | 0.54ε | 0 | 1 of 1 | 0.36ε | 84 + 253 s |
| dry, dy | 1.06ε | 1 | 8 of 10 | 0.91ε | 131 + 471 s |
| dry, dy70 | 0.65ε | 0 | 18 of 18 | 0.44ε | 160 + 474 s |

- All three checks pass on both records.
- root_P50 is under ε/3 on both: +0.15ε and +0.29ε, inside its reference's ±0.2ε.
- So the certificate needs no maps at ±u, and option (b) is dropped. Scripts are in
  `schedtest/p1`.

## Phase 2: the lattice, the library and the offline evaluator

**The lattice.** Every schedule an algorithm can request is a point on a per-case
lattice. Its axes are the choices the mechanisms showed to matter:
- founders' window: 8, 16, 32 or 64 even nodes over [0, b1);
- late spacing: 140, 70, 35 or 17.5 d;
- edges from the pilot: on or off. Base nodes born while establishment is shut are
  dropped at every level;
- constant's front band: none, or nodes every 1/512 d across the front, graded ×1.5
  outward.

The levels on each axis are nested, so adjacent levels are a run and its central
coarsening. Each point's certificate then comes from its neighbour, with no extra run.

**The library.** Per case, one gradient run at each level of each axis, the others held
at a middle level: about eight runs a case. Each stored run carries:
- its answer;
- its measured CPU time (forward and sweep);
- its edges.

An off-axis point (founders' level f with late level l) is predicted by additivity
across the two regions:

    Q(f, l) ≈ Q(f, l0) + Q(f0, l) − Q(f0, l0)

Round 2 of `root-p50.md` found the founders' and late parts additive. The stored
library already has many of these points, or points close to them: the uniform
ladders, `dy`, `dy70`, the hybrid and bisection passes, and the late-uniform ladders.
The fill computes only what is missing.

**The evaluator** (`harness/schedule/evaluate.R`, fixed; agents do not edit it).
- It replays a candidate algorithm on each case:
  - every schedule request is answered from the library;
  - every request is charged that run's stored CPU time;
  - an off-axis request is answered by additivity, at the cost of the run it stands
    for.
- It returns T, C1–C4 with their margins, and the path the algorithm took.

**Done when all of these hold:**
- every training-case axis is filled;
- the evaluator reproduces each stored lattice run exactly;
- additivity is checked on four real off-axis runs (two cases × two points), with every
  quantity within 0.1ε of its prediction. If it fails, the full product is filled on
  the cases that fail;
- one candidate's evaluation over the training bank takes seconds.

The fill runs once in the background on the four cores; training cases go first.

## Phase 3: baseline

Score on the evaluator:
- the incumbent: the hybrid loop from `dy`, passes until the ln J estimate is under
  ε/2;
- `dy70` with one certificate.

Their T, at k = 1, 2 and 10, is the number to beat.

## Phase 4: generate, test in parallel, combine

A loop in the manner of AlphaEvolve, small enough for four cores. Each round:
1. **Generate.** Write up to four candidate algorithms. Each is the current best with one
   idea changed: a rule, a feature read from the pilot, a refinement step, a stop rule.
   The ideas come from the last round's diagnostics: where each case spent its time,
   and which constraint or quantity was tight.
2. **Test in parallel.** Score all four at once on the training bank:
   - offline, in seconds, where the library covers their schedules;
   - otherwise their missing runs share the four cores.

   A candidate's own knobs are tuned by a small grid on the evaluator.
3. **Combine.** The best feasible candidate becomes the base. Ideas that each helped
   on their own are merged into one candidate, which is scored before it counts.
4. **Record** the round: candidates, T, constraint margins, and what was learned.

Rules may read only what an algorithm can observe: the pilot run and its own
certificates, never the case's name. The held-out bank of Phase 5 checks that.

**Stopping.** The loop stops at the first of:
- two consecutive rounds without a 2% gain in the best feasible T;
- eight rounds;
- a round in which no candidate is feasible and the cause is not understood. Then the
  failing case is root-caused before the loop resumes.

## Phase 5: validation with real runs

The winner and the runner-up are run end to end with real simulations, not the
library, on the held-out bank:
- dry without its season;
- two long-drought weather seeds;
- dry root_P50 ×0.8;
- long-wet a_dG2 ×1.25.

References for these are built in the background during Phases 2–4: uniform u215,
u429, u857 plus front nodes on constant, extrapolated, and checked per quantity.

**Accepted when:**
- C1–C4 hold on every held-out case;
- the real T is within 20% of the evaluator's prediction on the training cases;
- reproducibility holds: `tol` ±5%, and introductions shifted by a quarter of their
  spacing, each move every quantity by under ε/3, on dry and episodic.

**If not accepted:**
- the runner-up is tried;
- if both fail, the failing held-out case joins training, and Phase 4 resumes once.

Then the accepted algorithm's rules go into the vignette and the design spec, ready
for the plant issues.

## Stopping criteria, in short

| phase | stops when | next |
|---|---|---|
| 1 | done: all three checks pass on dry and episodic | Phase 2 |
| 2 | axes filled; evaluator exact on stored runs; additivity within 0.1ε; seconds per evaluation | Phase 3 |
| 3 | incumbent and dy70 scored at k = 1, 2, 10 | Phase 4 |
| 4 | two rounds without a 2% gain, eight rounds, or an infeasible round not understood | Phase 5, or root cause |
| 5 | winner passes held-out, prediction and reproducibility checks | rules into the spec |
