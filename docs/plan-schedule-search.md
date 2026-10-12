# Plan: a schedule builder chosen by search over a scored bank

The goal is a set of rules that builds a birth-date schedule for any trait × rainfall
case. Each built schedule has every quantity within ε, reports an honest error
estimate, and costs the fewest rows. The mechanisms are now known:
- `estimate-shortfall.md`: lopsided panels;
- `central.md`: central coarsenings and the per-quantity certificate;
- `breakpoints.md`: edges and fronts;
- `root-p50.md`: parts that cancel, and wide late intervals.

So the remaining choices can be scored rather than argued. This plan fixes the
objective first, then lets agents search the rules against it.

Out of scope here:
- curvatures;
- the ODE tolerance (held at the `nr` setting: tol 3e-5, the soil weight and window
  of `central.md`);
- the implementation in plant, which comes after, with its own issues.

## Phase 1: does a late cap make the per-quantity certificate honest?

**Question.** With late intervals capped at 70 days, does the central coarsening read
every resident quantity's error, root_P50 included, without per-interval maps at ±u?

**Runs.** On dry and on episodic:
- start `dy70`: `dy` with late spacing 70 d throughout, in place of 0.185 y then 0.37 y;
  edges from the existing first pass; no base nodes while establishment is shut;
- the hybrid H of `dy70` and its coarsening C, each with gradients.

That is four runs. Errors are against the references of `central.md`.

**Pass, if all three hold on both records:**
1. every resident quantity with |error| > ε has an estimate over ε/2;
2. the estimate (C − H)/3 is within ×2, with the right sign, for at least 80% of the
   quantities with |error| > ε/3, root_P50 included;
3. H + (H − C)/3 is within ε on every quantity.

**Decision.**
- Pass: the certificate needs no maps at ±u, and option (b) is dropped.
- Fail on root_P50 only: (b) is kept as a component for flagged traits.
- Fail more widely: stop, and root-cause before Phase 2.

## Phase 2: the objective, the bank and the evaluator

**The builder interface.** Agents change only this. One R file per component under
`harness/schedule/`:
- `start(pilot, case)`, which returns birth dates;
- `certify(runs)`, which returns per-quantity estimates and per-interval ranks;
- `refine(schedule, ranks)`, which returns a schedule;
- `stop(estimates)`, which returns a decision and the reported answer.

A builder is a list of these four functions and their knobs. It runs from a pilot to
its own stop.

**The evaluator** (`harness/schedule/evaluate.R`).
- Fixed, and not edited by the search.
- Runs a builder on every case, caching each run by (build, record, traits, schedule).
- Scores each case against its reference.

**Quantities scored:**
- ln J;
- the 48 resident elasticities (without `recruitment_decay`);
- the invader quantities of an invader with the resident's traits.

**Objective.** The fewest total rows over the bank, counting pilot, passes and
certificate runs, subject to these hard constraints on every case:
- **C1 accurate:** every quantity of the reported answer is within ε.
- **C2 no silent miss:** every quantity whose true error exceeds ε/2 has an estimate
  over ε/4.
- **C3 honest:** the estimate is within ×2, with the right sign, for at least 80% of
  quantities with error over ε/3.
- **C4 never fails:** no throw and no refusal.
- **C5 deterministic:** the same builder on the same case gives the same rows.

A builder that breaks a constraint on any case is infeasible. Among feasible
builders, the score is total rows; ties go to the smaller worst error.

**The bank.**

| set | cases | references |
|---|---|---|
| training | constant, dry, episodic, long-wet, long drought, episodic lma ×1.25 | exist (`refinement.md`, `central.md`) |
| held-out | dry-flat, two long-drought weather seeds of `eps-spread.md`, dry root_P50 ×0.8, long-wet a_dG2 ×1.25 | to build |

Held-out cases never steer the search; they only accept or reject its winner.

**References.** Each is three uniform levels plus front nodes on constant, u215 → u429
→ u857, extrapolated from the two finest. A reference is accepted for a quantity when
its last ratio lies in [2.5, 6] or its last move is under ε/5. A quantity that fails
this on a case is dropped from that case's score and listed.

**Done when:**
- every training and held-out reference is built and checked;
- the evaluator reproduces the incumbent's recorded numbers (the hybrid loop from `dy`,
  `central.md`) within 0.05ε;
- a repeat evaluation hits the cache for every run.

## Phase 3: the baseline

Score these on the training bank:
- the incumbent;
- the incumbent with the Phase 1 decision (`dy70`, and the certificate it settled).

Their costs and constraint margins are the numbers to beat.

**Done when** both are scored, with each constraint's margin per case.

## Phase 4: the search

**Agents.** Six at most, one per component direction:
- the start: founders' grading, late cap, edges from the pilot;
- the constant front;
- the certificate: central window, extrapolation;
- refinement: the share refined, ranking by magnitude, which quantities rank;
- the stop rule;
- one free agent, which recombines the leaders.

**Rounds.**
1. In each round an agent proposes up to two builders.
2. Each candidate is screened on episodic and constant, the two cheapest training
   cases that exercise pulses and the front.
3. Candidates that pass screening are scored on the whole training bank.
4. Every agent sees the leaderboard, with per-case margins and costs, before the next
   round.

**Budget.**
- At most 40 full training-bank evaluations.
- At most four rounds.
- Shared runs come from the cache.

A full evaluation is about 18M rows, roughly 25 minutes of wall time on this machine's
four cores.

**The search stops at the first of:**
- two consecutive rounds in which the best feasible cost improves by under 5%;
- the budget spent;
- no feasible builder after two rounds. Then the search stops, and the failing case is
  root-caused by systematic debugging, not tuned around.

## Phase 5: acceptance

The cheapest feasible builder is the winner. It is accepted when, on the held-out bank:
- C1–C5 hold on every case;
- reproducibility holds: on dry and episodic, `tol` ±5%, and introductions shifted by a
  quarter of their spacing, each move every quantity by under ε/3;
- invaders at lma ×0.5 and ×2 are within ε on dry and episodic.

**If it is rejected:**
- the next feasible builder is tried;
- if none passes, the failing held-out case joins the training bank and Phase 4
  resumes, once.

**Done when** a winner is accepted. Its rules then go into the vignette and the design
spec, ready for the plant issues.

## Order and stopping, in short

| phase | stops when | next |
|---|---|---|
| 1 | the three checks are read on both records | Phase 2, with (a) or (b) settled |
| 2 | references built and checked; evaluator reproduces the incumbent; cache works | Phase 3 |
| 3 | incumbent and its Phase-1 variant scored | Phase 4 |
| 4 | improvement under 5% for two rounds, budget spent, or nothing feasible | Phase 5 or root cause |
| 5 | a winner passes held-out, reproducibility and invader checks | rules into the spec |
