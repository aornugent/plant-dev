# Refining a TF24 node schedule until it converges

A design under `.claude/skills/system-design/SKILL.md`, written after the root-cause rounds
(`docs/measurements/schedule-search/rootcause/`) and revised after the evidence round
(`rootcause/evidence/notes.md`). It replaces tuning one schedule (E6) with an algorithm that
refines a schedule until it converges, and reports each run's own error. The user-facing
account is `docs/vignettes/node-schedules.Rmd`.

## Triage: 3

The result becomes plant's tool for converged runs (the role `refine_schedule` had), so its
call and its returned diagnostics are a public API.

## Requirements ledger

- **R1 Converged by default.** Every quantity's error is within its ε_q
  (`docs/measurements/eps-spread.md`), with no knob to tune.
- **R1′ Any simulation length.** No rule names an absolute birth date or patch age.
- **R2 Honest.** Every run reports its own per-quantity error estimate (C2/C3). A run's
  estimate does not depend on another schedule being on the asymptotic law.
- **R3 Never fails** (C4), including near extinction.
- **R4 Cheap.** The least rows at ε. E6 costs its committed run plus a 1.55× check.
- **R5 Diagnosed.** Each run reports where its remaining error is.

**Scarce resource:** whole SCM runs, 1–7 minutes each.

## The domain

Every stand total is an integral over birth date of an exact establishment count times a
per-recruit integrand (fate, leaf area, uptake). A schedule is a quadrature rule over birth
date. Its error is local, and adds over birth date:
- where the integrand is smooth, an interval's error is about count × width² × the integrand's
  curvature;
- regions add to the whole within 0.04ε;
- a replay with every region removed equals the sum of the single removals (correlation 1.000).

**What the integrand does** (dense references and fate maps, `evidence/notes.md` E1):
- **At an opening edge its slope jumps.** This held at all 22 openings on dry. The part that
  is not smooth is 12–67× the spell interior's.
- **At a shutting it stays continuous, but its curvature rises tenfold within 2–3 weeks**,
  most of all in the hydraulic sensitivities. An interval across the shutting reads the gap's
  different curve, so its error is set by where the last node sits, not by the spacing.
- **The first cohorts, including their first days, and the late cohorts are smooth.**

**So both edges are breakpoints.**
- A spell [o, c] is one smooth panel.
- The gap after it holds no establishment, so it needs no interior node.
- The breakpoints cost one node per edge. With a09's density the layout has 8–23% more
  nodes than E6's committed run.

**A node's cost depends on its birth date:** an early node lives for the rest of the run.

## The commitment

**A schedule is a set of breakpoints (each run's own spell openings and ends, and a stall boundary
where one exists) plus a node
count per spell, the spell's nodes placed to share a density equally. Every node that is not a
breakpoint can be removed, and a replay of the run on its own steps with every other interior
node removed is that run's error estimate.**

Kept true by structure:
- The schedule is (breaks, density); nodes are derived from it.
- Each spell gets an even number of intervals. The removal then merges every interval in a
  pair, each pair with an equal share of the density. No interval goes unmerged, and no removed
  node sits off centre.
- No other node class exists: no insets, strips or edge layers.

## The algorithm

1. **First run** (forward, about 100 even introductions). It gives the openings and shuttings,
   and T(t): the share of J still to be produced after each calendar time.
2. **First density:** graded by the offspring curve, and toward each shutting over its last
   three weeks (with two more intervals per spell). Ages come from T(t):
   - the onset of offspring production replaces b = 10;
   - the time half of J has been produced replaces 17 and 20;
   - the time 90% has been produced replaces 25 (the late cut).
3. **Run** at a tolerance whose own error is under ε/10 (3e-5 has a floor of 0.004–0.012 rms,
   at 1.4× the steps of 1e-4). The replay shares the run's steps, so the run's tolerance error
   is never in the estimate.
4. **Replay** with every other interior node removed: error ≈ (Q_removed − Q)/3. This costs
   about 0.6–0.8 of a run.
5. **Stop** when every quantity's estimate is under 0.88ε (at 1e-4: the replay cannot see the
   tolerance's bias, ≤ 0.11ε, and estimates 0.75–0.97 of the error). The run is the answer.
6. **Otherwise** take spell ends from this run (ends move with the schedule: median 0.48 d, the
   first spell's by 12 d), scale each spell's count by √(worst ratio) × 1.1, make sure the binding
   spells' counts change, and go to 3.

**A stall boundary** (constant rain: cohorts born after day 23.5 stall under the canopy) is a
breakpoint where neighbours' counts of P sign changes differ. It is placed by bisection on forward
runs (five rounds of about 100 nodes, to 0.0003 day); today's runs do not record that count.

**Spells too short for two intervals** keep one interval and are not replayed.
- They hold 23–71% of establishment but 0.5–6.6% of J and 1–19% of the interpolation error.
- Leave out spells below a share of the J window, and report a bound on their error.

**When doubling is enough:** if a step doubles every spell's count, each run is the previous
run's removal case. The previous run then estimates the new one without a replay, at the cost
of 0.024 rms of step noise.

## Candidates

| | Move | Commitment | Wins when |
|---|---|---|---|
| A [first thought] | Allocate by measured error density | count per spell from the map's ln J split and each node's cost | error density varies a lot across birth date within a case |
| **B (chosen)** | Scale only | counts scale together | the first density already has the right shape. Per-region allocation saved 4.1% of use rows on the bank |
| C | Keep E6, replay instead of the check | E6's layout, insets held fixed | the insets' strip error is under ε/10 everywhere. It is not: closing +0.34 on dry |

## What the evidence settled

| Question | Answer [m] |
|---|---|
| Slope jumps only at openings? | Yes, but shuttings need breakpoints too. With openings only, worst errors were 3.36ε (dry), 1.13ε (long-wet) and 3.24ε (episodic-lma), and the replay read 0.2–0.44 of them |
| Order 2 inside a spell at twice the spacing? | The interpolation part falls at order 1.6–2.0. On real runs with both edges as breakpoints and even counts, the replay reads the whole error at 0.75–0.87 (cos 0.88–0.97), and never accepts a run over ε |
| Layout with both edges as breakpoints? | Worst error 0.79ε (dry), 0.47ε (long-wet), 0.76ε (episodic-lma; E6 1.29). The replay misses a root_P50 / storage-offset component (±0.4–0.6ε) on dry and episodic-lma, most likely the hydraulic change before each shutting under a uniform density. Run + replay ≈ E6's committed + check |
| Replay honest by region? | ×0.8–1.25 on the saved region replays; dry-flat's interiors ×1.9 |
| Map–replay agreement as a check? | Tests nothing useful: the gap is ≤ 0.004ε at the committed spacing |
| Parity replay as a second estimate? | No: with even counts the even removal never merges a spell's end intervals; on dry it read 0.37 of the error. A second estimate needs a second schedule (the previous run, when counts double) |
| Probe nodes between nodes? | Not today: the run refuses invaders born at dates it did not introduce |
| Map's light/water split? | Says soil carries 58–89% of the field part. Not yet checked against a run that separates the channels |

## Guarantees, by construction

- **G1 The last run is the answer.** Earlier runs and replays are spent, unless each step
  doubles every count; then each run estimates the next.
- **G2 Coverage.** Every interval in a spell with at least two intervals is merged once (even
  counts). Short spells are bounded, not estimated.
- **G3 No step noise in the estimate:** the replay uses the run's steps.
- **G4 Any length:** no rule holds an absolute age.
- **G5 It stops.** Scaling with a margin and a forced count change cuts the worst ratio each
  pass; a cap reports a failure.

## Still open

- **The grading before each shutting.** On dry a root_P50 / storage-offset component fell at order
  about 1 under a uniform spell density. It is not a slope jump (every cohort in the last 36
  days empties its reserves; mortality is smooth in reserves). It is curvature, 3–12× higher
  over the last three weeks, carried mostly through the field. Density following the larger
  curvature, about 2× over 18 days tapering to 1 by 27, with two more intervals per spell,
  takes the worst error from 0.79 to 0.36ε (E6 0.35) and the replay's read to 0.97, at 232
  nodes against E6's 149. At 1e-4, run plus replay ≈ E6's committed plus check. Open: take the
  grading's width from the first run, and test on more cases.
- **The bound for short spells.** The first proposal was 5–50× short; their true error was
  0.05–0.10ε on the three cases.
- **The tolerance.** 3e-5 costs 1.4× the steps; 1e-4 with every quantity held to 0.88ε covers
  its measured bias (≤ 0.11ε on five cases) at 0.7 of the cost.

## The tool

```r
refine_schedule(p)   # returns list(schedule, answer, estimate, where, history)
```

Converges to ε by default.
