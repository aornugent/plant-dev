# Refining a TF24 node schedule until it converges

A design under `.claude/skills/system-design/SKILL.md`, written after the root-cause rounds
(`docs/measurements/schedule-search/rootcause/`, evidence in `rootcause/evidence/notes.md`) and
revised after a Tier-3 review (`rootcause/review/design-review.md`, against a blind clean sheet,
`review/clean-sheet.md`). It replaces tuning one schedule (E6, today's tuned schedule) with an
algorithm that refines a schedule until it converges and reports each run's own error. It is the
node axis of `docs/design-grid-controller.md`, which holds the time axis and the arc. The
account for users is `docs/vignettes/node-schedules.Rmd`.

## Triage: 3

It replaces plant's `refine_schedule` (a `run_scm()` argument, an `SCM` method on FF16, K93,
TF24 and TF24f, and a key in logpile's request schema that reaches its fingerprints), so its
call and its returned diagnostics are a public API.

## Requirements ledger

From `OBJECTIVES.md`; ε_q per quantity from `docs/measurements/eps-spread.md`.

- **R1 Accurate by default.** Each quantity's true error is within ε_q, with no knob. The
  quantities are `ln J`, every elasticity and every curvature, for residents and for invaders
  from ×0.5 to ×2 of the resident.
- **R1′ Any simulation length.** No rule names an absolute birth date or patch age.
- **R2 Honest.** Every run reports its own estimate per quantity. The estimate does not depend
  on a second schedule being on the asymptotic law.
- **R3 Never fails,** including near extinction.
- **R4 Shared.** One schedule serves a local analysis around θ₀: invaders ×0.5–×2, the resident
  within ±10%. A big step in θ rebuilds it.
- **R5 Cheap.** The least runtime at ε. E6 costs its committed run plus a 1.55× check.
- **R6 Diagnosed.** Each run reports its estimate, where its error is, its distance from θ₀
  against the schedule's radius, and its failures.

Left to `design-grid-controller.md`: the time axis (tolerances, splits, the soil stepped on its
own), and Stable 1–3 as tested by its acceptance suite.

**Scarce resource:** whole SCM runs, 1–7 minutes each.

## The domain

Every stand total is an integral over birth date of an exact establishment count times a
per-recruit integrand (fate, leaf area, uptake). A schedule is a quadrature rule over birth
date. Its error is local and adds over birth date:
- where the integrand is smooth, an interval's error is about count × width² × curvature;
- errors measured region by region add to the whole within 0.04ε;
- a replay with every region removed equals the sum of the single removals (correlation 1.000).

**Where the integrand is not smooth** (dense references and fate maps, evidence E1, R4, R13,
R15):
- **At a spell's opening its slope jumps,** at all 22 openings on dry.
- **At a spell's end it stays continuous,** but an interval across the end takes the gap's
  different curve, so its error is set by where its last node sits, not by the spacing. Fate's
  own curvature rises 1.3–5× toward the end, and the hydraulic and storage sensitivities 6–17×.
- **Where cohorts stall** (constant rain): neighbours' counts of P sign changes differ, and
  survival falls from 0.63 to 0.02 across 0.03 days.

So both ends of each spell are breakpoints, and a stall boundary where one exists. A gap
between spells holds no establishment and needs no node inside it.

**Where it curves most, inside a spell:**
- the first cohorts, graded by the offspring curve, with ages from T(t), the share of J still to
  be produced after time t (R7);
- the last weeks before each spell end, over a width t_r = o·ln(a_st3·a_dG2), the time a
  seedling's reserves take to run down (19.4 d at the bank's traits). It predicts the rise's
  width within 26% on every case, and doubling the storage offset doubles it (×2.2–2.4; R17,
  R18). Its height is about 2 everywhere.

## The commitment

**A schedule is breakpoints, a density between them, and a level k that doubles every count;
each spell holds an even number of intervals at equal shares of the density. Removing every other node inside each spell
leaves a coarser schedule of the same kind, and a replay of the run on that schedule, on the
run's own steps, is the run's error estimate.**

Kept true by structure:
- The schedule object stores (breakpoints, density, k). Node times are derived from it, and the
  derivation rounds each spell's interval count up to even, so an odd count cannot be
  expressed.
- The estimate has two terms: the replay's, and a fixed term for what the replay cannot see.
  The stop compares their sum with ε_q, so the second term cannot be forgotten.
- No other node class exists: no insets, strips or edge layers.

## The algorithm

Built as `harness/schedule/refine.R` (`refine_schedule`). Every full run is a candidate answer;
no run exists only to be compared with.

1. **First run** (forward, 100 even introductions, 0.09 of a full run). It gives the spell
   openings and ends, the offspring curve, and T(t).
2. **Schedule.** Breakpoints at 0, every spell edge up to t90, and the horizon. Between them,
   each spell's interval count: one where the density holds at most one, otherwise even plus
   two. Nodes sit at equal shares of a density graded by the offspring curve (ages from T(t))
   and raised to 2 over t_r before each spell end. Level k multiplies every count by 2^k, so
   each level's nodes contain every node of the level below.
3. **Pass 1:** run level 0 at 1e-4 (scale 1 is canonical: below it the estimate can read low), then replay it on its own steps with every other interior
   node removed: e_q = (Q_removed − Q)/3, at 0.51–0.66 of a run.
4. **Stop** when every quantity's bound, |e_q| / r_min + u_q, is under ε_q.
   - r_min = 0.82, the lowest per-case median ratio of estimate to true error on the graded
     layout (medians 0.82–1.17 on five cases). Per quantity the ratio runs 0.49–1.17, so the
     bound held on these cases through u_q, not through r_min (`review/profile.md`).
   - u_q covers what the estimate cannot contain: the tolerance's bias at 1e-4 (≤ 0.11ε), and
     after a replay the spells too short to hold two intervals (≤ 0.22ε): 0.33ε. After a
     doubled pass the short spells are estimated, and the pair's step noise (0.024ε rms at
     1e-4) takes their place: 0.16ε.
5. **Otherwise refine by doubling:** run level k + j, with j the fewest doublings whose
   predicted bound |e_q|/4^j/r_min + 0.16 is under 0.9. The rejected run is the new run's
   removal case, so its estimate is e_q = (Q_coarse − Q_fine)/(4^j − 1), with no replay. Go to
   4; after four passes return the finest run, flagged as unconverged.

Spell ends are taken once, from the first run, so that the levels nest. Ends move a median
0.48 d between schedules (the first spell's by 12 d); round 5 used a pilot's ends throughout
and passed on all five cases.

**Then fix the schedule.** The refined schedule is returned and held. Later runs in the local
analysis (invaders, the resident moved within ±10%, the two runs of each curvature) run on it
unchanged and each reports its own replay estimate and its distance from θ₀. A run whose
estimate is over its limit, or a step past the radius, rebuilds from step 1 at the new θ.

**Invaders.** An invader establishes on its own P at seed height, so its spell ends can differ
from the resident's, and libS walks invaders only at the resident's birth dates. The schedule's
breakpoints are therefore the union of the resident's spell ends and those of the analysis's
invaders, from one forward walk per invader set. Unmeasured: no run has covered θ′ ≠ θ.

**A stall boundary** is placed from each run's own counts of P sign changes per node: bisect the
pair whose counts differ. Today's runs do not record that count; a diagnostic build placed the
stall to 0.0003 d in five rounds.

## Candidates

| | Move | Commitment | Wins when |
|---|---|---|---|
| A [first thought] | Allocate by measured error density | count per spell from the node-drop map's ln J split and each node's cost | error density varies a lot across birth date within a case |
| **B (chosen)** | Scale only | one scale N over a fixed density | the first density already has the right shape. Per-region allocation saved 4.1% of runtime on the bank, and ln J's split misplaces the elasticities' error |
| C | Keep E6, replay instead of the check | E6's layout, insets held fixed | the insets' error is under ε/10 everywhere. It is not: +0.34ε in the spell-end strips on dry |

## What the evidence settled

| Question | Answer |
|---|---|
| Slope jumps only at openings? | Yes, but spell ends need breakpoints too. With openings only, worst errors were 3.36ε (dry), 1.13ε (long-wet) and 3.24ε (episodic, lma ×1.25), and the replay estimated 0.2–0.44 of them |
| Order 2 inside a spell at twice the spacing? | The interpolation part falls at order 1.6–2.0. With both ends as breakpoints and even counts, the replay estimated 0.75–0.87 of the error (cosine 0.88–0.97) |
| Both ends as breakpoints, uniform density? | Worst 0.79ε (dry), 0.47ε (long-wet), 0.76ε (episodic-lma; E6 1.29). The replay missed a root_P50 / storage-offset component (±0.4–0.6ε) on dry and episodic-lma |
| Graded before spell ends, two more intervals per replayed spell? | On dry: worst 0.36ε (E6 0.35), the replay estimated 0.97 of the error, 232 nodes against E6's 149 (+56%). At 1e-4, run plus replay ≈ E6 committed plus check (2.45 against 2.43) |
| The grading's width? | t_r, from parameters: within 26% on every case, ×2.2–2.4 when the storage offset doubles. The drought's length does not predict it |
| Replay honest by region? | ×0.8–1.25 on the saved region replays; dry-flat's interiors ×1.9 |
| Parity replay as a second estimate? | No: with even counts the even removal never merges a spell's end intervals; on dry it estimated 0.37 of the error |
| Probe nodes between nodes? | Not today: the run refuses invaders born at dates it did not introduce |
| The graded layout on five cases at 1e-4? | dry, long-wet, episodic-lma, dry-flat and a held-out episodic with a_dG2 ×0.8 (t_r 17.8 d): worst error 0.30–0.56ε, at or under E6 committed's (0.35–1.29) on every case; the spell-end component within 0.23ε (0.4–0.6 uniform). The bound on the worst quantity, from its error and the case's read, is 0.67–0.89ε, so each case stops at the first pass. Real rows 1.47–1.66× E6 committed; run plus replay 0.92–1.10× E6 committed plus check |
| Does the stop ever accept a run over ε? | No, on five cases started at half scale (`rootcause/refine2/`): every pass 1 was over ε (1.0–1.8) and rejected; every pass 2 accepted, worst 0.26–0.66ε. The pass-2 bound covered every quantity but epi-adG208's a_l1 (0.66 against 0.55): level 0 at half scale was short of the square law there (1.625 → 0.661 → 0.152 over three levels), so its estimates read low. Not spell ends, short spells or steps (R21) |
| What does a reject cost? | Starting at half scale and doubling: 1.56–1.74× round 5's scale-1 run plus replay, which accepted every case at pass 1. Doubling beats rescaling by √, which is not nested and needs its own replay |

## Guarantees, by construction

- **G1 The last run is the answer;** the run before it is its estimate.
- **G2 Coverage.** Every interval in a spell with two or more is merged once. Shorter spells
  are covered by u_q, a measured maximum (0.22ε over five cases), not an estimate.
- **G3 No step noise in the estimate:** the replay uses the run's steps.
- **G4 Any length:** the ages come from T(t) and the grading's width from t_r. Not yet: the
  run's tolerance weights sit on a fixed 0–40 y grid, and T(t) has not been measured on another
  length.
- **G5 It stops:** each rejected pass at least doubles every count, cutting the error at least
  fourfold on the square law, and a cap of four passes reports a failure.
- **G6 No run is only a check:** a rejected run becomes the next run's estimate.

## What survives deletion

- breakpoints → R1 (an interval across a spell end is out of order 2)
- density → R5 (on dry the grading took the worst error from 0.79 to 0.36ε for 49 more nodes;
  doubling every count, 135 more, left ±0.2ε)
- the level k → R1 (the only knob the loop turns; doubling keeps levels nested, so the rejected
  run is the next estimate, R5)
- even counts → R2 (an odd count leaves an interval unmerged; it hid 17 of 70 spell ends)
- u_q → R1 (what the replay cannot see)
- fixing the schedule after refining → R4
- invaders' spell ends among the breakpoints → R1 for invaders (unmeasured)

Deleted: re-reading spell ends each pass (it breaks nesting, so every pass would need its own
replay), the √ rescaling (not nested, same reason), the short-spell bound (5–50× short), and the
five-run bisection for the stall.

## What a strategy supplies

In one place, so FF16, K93 and TF24f keep working: its breakpoints from a run's establishment
record (none: one spell [0, horizon]), its grading before spell ends (none for strategies
without reserves), its ε table, and its u_q. TF24's are above.

## What this makes hard

- **Cost:** the graded layout has 38–68% more nodes than E6's committed run (1.47–1.66× its
  rows); run plus replay is level with E6's run plus check (0.92–1.10×). The gain is an honest
  estimate in one run, not fewer rows.
- **The fixed term u_q:** 0.33ε of the budget goes to what the replay cannot see, two thirds of
  it to short spells. A bound for them that is not a worst case would return most of it.
- **Several passes:** each extra pass spends a run and its replay, about 1.6 runs.
- **Continuity across a rebuild:** the answer jumps where a big step in θ rebuilds the
  schedule.
- **Invaders with their own spells:** unmeasured.

## Kill condition

If a first schedule's error density proves case-specific enough that scaling wastes much more
than the 4.1% measured, candidate A (allocation by the node-drop map) takes over.

## Still open

- Below scale 1 the estimate can read low (epi-adG208 a_l1 at half scale, 0.45); the spells that
  carry the slow part are not located.
- r_min and u_q from five cases; the bank has ten.
- The invaders' spell ends against the resident's.
- dry-flat's interiors, where region replays estimated 1.9× the error.
- Which of light or water carries the understory's error (the node-drop map says soil carries
  58–89%; not checked against a run that separates them).
- The per-node count of P sign changes, which today's runs do not record.

## The tool

```r
fit <- refine_schedule(p)
fit$answer     # ln J, elasticities and curvatures, from the last run
fit$estimate   # each quantity's estimate e_q, and its bound |e_q|/r_min + u_q
fit$schedule   # breakpoints, counts at the final level, node times, t_r, ages
fit$where      # ln J's error by spell, from the node-drop map (+5-8% of a sweep)
fit$history    # each pass: level, nodes, answer, estimate, worst bound
fit$costs      # CPU per run: forward and sweep
fit$status     # converged | unconverged
```

Later runs on the fixed schedule report `estimate`, `where` and their distance from θ₀.

It replaces, in one change: the C++ `SCM::refine_schedule` and the `run_scm(refine_schedule =)`
argument in plant; and logpile's `refine_schedule` key in `resolve_control`, `manifest.R` and
`solver.R` (this changes request fingerprints).

Built so far in the harness, not yet in plant: `answer`, `estimate`, `bound`, `extrapolated`
(Q − e, reported, not the answer), `schedule`, `history`, `costs`, `status`. Not yet built:
curvatures, invaders' spell ends, `where`, and the distance from θ₀.
