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
- The breakpoints cost one node per edge, the same count as E6's 12-day insets.

**A node's cost depends on its birth date:** an early node lives for the rest of the run.

## The commitment

**A schedule is a set of breakpoints (the first run's opening and shutting edges) plus a node
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
2. **First density:** graded by the offspring curve. Ages come from T(t):
   - the onset of offspring production replaces b = 10;
   - the time half of J has been produced replaces 17 and 20;
   - the time 90% has been produced replaces 25 (the late cut).
3. **Run** at a tolerance whose own error is under ε/10 (3e-5 has a floor of 0.004–0.012 rms).
   The replay shares the run's steps, so the run's tolerance error is never in the estimate.
4. **Replay** with every other interior node removed: error ≈ (Q_removed − Q)/3. This costs
   about 0.6–0.8 of a run.
5. **Stop** when every quantity is under its ε. The run is the answer.
6. **Otherwise** scale each spell's count by √(worst ratio) × 1.1, make sure the binding
   spells' counts change, and go to 3.

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
| Order 2 inside a spell at twice the spacing? | The interpolation part falls at order 1.6–2.0. With shutting breakpoints and even counts, the replay reads it at 0.92–1.02 |
| Replay honest by region? | ×0.8–1.25 on the saved region replays; dry-flat's interiors ×1.9 |
| Map–replay agreement as a check? | Tests nothing useful: the gap is ≤ 0.004ε at the committed spacing. Replaced by a parity replay: removing odd vs even nodes spreads 0–0.08ε |
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

- **The shutting breakpoints at real cost.** The next test is this layout on dry, long-wet and
  episodic-lma: one run and one replay each.
- **dry-flat's interiors,** which region replays read at ×1.9.
- **The bound for short spells.**

## The tool

```r
refine_schedule(p)   # returns list(schedule, answer, estimate, where, history)
```

Converges to ε by default.
