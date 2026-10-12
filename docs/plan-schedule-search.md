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
- **k** is the number of runs one schedule serves. It is 10 by default, about one local
  analysis: the resident gradient, a few invaders, a curvature chord. A fast schedule
  that takes an hour to find loses to a slower one found in minutes. Scores are also
  reported at k = 1 and k = 30, so the choice of k stays visible.
- **CPU or wall time.** T is CPU time by default. If T_find is instead counted as wall
  time on P cores (the cores a user runs on), an algorithm that runs several schedules
  at once can find its schedule faster; island 3 of Phase 4 searches exactly that.

**Feasibility.** The objectives of `OBJECTIVES.md` are constraints, not the target. A
feasible algorithm meets these on every case:
- **C1 accurate:** every quantity of the reported answer is within ε.
- **C2 no silent miss:** every quantity whose true error exceeds ε/2 has an estimate
  over ε/4.
- **C3 honest:** the estimate is within ×2, with the right sign, for at least 80% of
  quantities with error over ε/3.
- **C4 never fails:** no throw and no refusal.

**Quantities:** ln J, the 48 resident elasticities (without `recruitment_decay`), and an
invader with the resident's traits.

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
- one candidate's evaluation over the training bank takes under 50 ms, vectorised.

The simulation workers of Phase 4 do the fill in about 20 minutes; training cases go
first.

## Phase 3: baseline

Score on the evaluator:
- the incumbent: the hybrid loop from `dy`, passes until the ln J estimate is under
  ε/2;
- `dy70` with one certificate.

Their T, at k = 1, 10 and 30, is the number to beat.

## Phase 4: a parallel, evolutionary search over algorithms

Three kinds of worker do three different jobs. They run concurrently and never wait on
one another.

| worker | what it is good at | how many | what it costs per item |
|---|---|---|---|
| LLM agents | inventing structure: rules, features, control flow; reading diagnostics | 8 per generation | about 5 min per program |
| numerical optimisers | tuning one structure's knobs | the local cores, vectorised | 50 ms per evaluation |
| simulation workers | ground truth: filling the lattice, real runs of the leaders | about 6 cloud sessions of 4 cores, plus local | 5–10 min per verified program |

**The program database.** Every candidate is an R program behind one interface:
- `start(pilot)` returns a lattice point, or several to run at once;
- `next(state, certificate)` returns lattice points or a stop;
- a declared knob vector with ranges.

The database stores each program's:
- code and parents;
- tuned knobs and score;
- the diagnostics it earned: per-case T_find and T_use, each constraint's margin, the
  quantities that bind, and the path it took.

**Islands.** The database is split into islands, each seeded with a different
paradigm, so the search keeps several distinct lines alive:
1. **one-shot:** pilot features choose the lattice point; the certificate only
   verifies;
2. **adaptive:** a cheap start, refined by per-quantity certificates;
3. **speculative:** several lattice points run at once, and the cheapest certified one
   is kept (rewarded only if T is wall time, below);
4. **budgeted:** ε split between founders, late births and front, by the map's
   per-interval magnitudes;
5. **light pilot:** features from the soil-alone probe (about 0.25 of a run) or from no
   pilot, against a stand pilot.

The best program migrates between islands every three generations. An island that has
not improved in four generations is reseeded from the best of the others.

**A generation** takes about 10 minutes:
1. **Propose.** Eight agents run in parallel. Each samples parents from one island,
   weighted by score, reads their code and diagnostics, and writes one child. Each
   agent has an assigned operator:
   - tune a rule;
   - add a rule or feature;
   - cross two parents from different islands;
   - simplify: delete a rule and keep the program if its score holds. This keeps the
     winner from being overbuilt.
2. **Tune.** For each child, the optimiser fits its knobs: about 1,000 evaluations by
   CMA-ES with feasibility first, on the local cores. That takes about a minute.
3. **Score.** The child is ranked by **leave-one-case-out T**: its knobs are tuned on
   five training cases and scored on the sixth, in rotation. A program that encodes
   per-case answers scores badly by construction. Ties go to the shorter program.
4. **Verify.** The best program of each island runs end to end with real simulations
   on the training bank, spread over the simulation workers. That is about 18 gradient
   runs, roughly 5 minutes of wall time across 24 cores. It does not hold up the next
   generation.

**Exploiting the problem's structure.** The error and the cost add across regions:
founders, late births and front. So each region's rule is also searched as its own
subproblem, in parallel, with that region's share of ε as a knob. The full program
combines the regional winners, and the combination is scored as a whole before it
counts.

**Keeping the evaluator honest.** Programs are scored on a surrogate: stored runs plus
regional additivity. A search will exploit any error in it. So:
- every verified program reports real T and constraints beside its predictions;
- a disagreement over 20% in T, or any constraint that flips, sends the points behind
  it to the simulation workers, refines the lattice there (new points or a new axis),
  and re-scores the whole database. Re-scoring takes seconds;
- agents may read the evaluator but not change it, and never see the held-out bank.

**Simulation workers.**
- Sibling cloud sessions in the `plant` environment, built at the same commits as
  `lib_109`.
- They take runs from a queue: the lattice fill of Phase 2, verifications, new axes
  that agents request.
- They return compact results (answers, rows, edges) on a `schedule-library` branch.
- Cost is charged by rows through the measured model (113 s of forward time per
  million rows; a sweep is 3.27 times that), so T does not depend on which machine ran
  it.

**Stopping.** The search stops at the first of:
- the best leave-one-case-out feasible T improves by under 2% over three generations,
  and the last verification of each island's leader agreed with its prediction;
- six hours of wall time;
- a disagreement between the surrogate and real runs that survives two lattice
  refinements. That stops the search to root-cause the surrogate.

Phase 2 changes in one way: the simulation workers fill the lattice in about
20 minutes, not two hours.

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
| 2 | axes filled; evaluator exact on stored runs; additivity within 0.1ε; under 50 ms per evaluation | Phase 3 |
| 3 | incumbent and dy70 scored at k = 1, 10, 30 | Phase 4 |
| 4 | under 2% gain in leave-one-case-out T over three generations with verified leaders, 6 h, or an unresolved surrogate disagreement | Phase 5, or root-cause the surrogate |
| 5 | winner passes held-out, prediction and reproducibility checks | rules into the spec |
