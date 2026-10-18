# Refining a TF24 node schedule until it converges

A design under `.claude/skills/system-design/SKILL.md`, written after the root-cause rounds
(`docs/measurements/schedule-search/rootcause/`). It replaces the habit of tuning one
schedule (E6) with an algorithm that refines any schedule to a target, and reports each
run's own error.

## Triage: 3

The result becomes plant's user tool for converged runs (the role `refine_schedule` had), so
its call and its returned diagnostics are a public API.

## Requirements ledger

- **R1 Converged on demand.** Every quantity's error is within target·ε_q, with the target set
  by the user (1, ½, ¼). This is the only knob.
- **R2 Honest.** Every run reports its own per-quantity error estimate, passing C2/C3 at the
  target. A run's estimate must not depend on another schedule being on the asymptotic law.
- **R3 Never fails** (C4), including near extinction.
- **R4 Cheap.** The least rows at the target. At ε, E6 costs its committed run plus a 1.55×
  check (2.55 runs to find, T 9287 on the bank).
- **R5 Diagnosed.** Each run reports where its remaining error is.

**Scarce resource:** whole SCM runs, 1–7 minutes each. Every run must either be the answer
or estimate the answer; a check run that is then thrown away pays for neither.

## The domain, from first principles

Every stand total is an integral over birth date b of an exact establishment density times a
per-recruit integrand (fate, leaf area, uptake). A schedule is a quadrature rule over b. Its
error is local, order 2 in spacing wherever the integrand is smooth, and it adds over any
partition of b: five region runs sum to the whole within rms 0.039ε on dry, and a pinned
replay with every region dropped equals the sum of the per-region drops (cos 1.000).

What the rounds found about the integrand:
- **It has a corner at each opening edge o, and only there.** This held at all 22 opening
  edges on dry (`h5/notes.md` O1). Through a closing edge it is smooth and convex, and the
  gate's ramp is 1–2 d (`closing/notes.md`).
- **Elsewhere it is smooth but curved.** The founders' fate falls on a time scale L of
  0.4–1.2 y. The interiors' leaf area is convex in b. The closing cohorts' hydraulic
  sensitivity turns 9–12 d before each closing edge c.
- **An early node costs more.** It lives for the rest of the run, so the rows a node adds at
  b are w(b), the steps remaining after b.

The edge strips were never a separate kind of error. They are what happens when a
quadrature node is not placed on the integrand's corner. Put a node on every opening edge
and the corner is resolved. Everything between two opening edges is then one smooth panel:
a spell, the closing turn, and the following gap.

## The commitment

**A schedule is a set of breakpoints (the pilot's opening edges) plus a node density ρ(b)
on the panels between them. Every node that is not a breakpoint can be dropped, and a
pinned replay of the run with every other such node dropped is that run's error estimate.**

Kept true by structure:
- The schedule is the pair (breaks, ρ). Nodes are derived from it: in each panel, ⌈∫ρ⌉
  nodes placed to share ρ equally.
- No other node class exists: no insets, no strips, no edge layers.
- The drop function takes the derived interior nodes of each panel, alternately. It cannot
  touch a breakpoint because breakpoints are not in its input.

## The floor, and why it may be the whole design

**Floor:**
1. Start ρ₀ from the pilot: a09's graded density, which already follows the founders and
   the offspring curve.
2. Run S.
3. Replay S pinned to its own steps with every other interior node dropped. The estimate is
   e_q = (Q_drop − Q_S)/3, about 0.8 of a run, with no step jitter between the two.
4. If every |e_q| ≤ target·ε_q, stop. S is the answer.
5. Otherwise scale ρ by √(max_q |e_q|/(target·ε_q)) and go to 2.

Each iteration costs 1.8 runs. The last run is the answer. Its estimate is its own, so R2
holds without the pair assumption that broke E6's check at ε/2.

**Where the floor may fail:** R4. Uniform scaling also refines regions whose error is
already small. Whether that costs enough to matter is unknown; it is Q5 below.

## Candidates

| | Move | Commitment | Pays for | Costs | Wins when |
|---|---|---|---|---|---|
| A [first thought] | Allocate by measured error density | ρ ∝ (K̂/w)^(1/3), with K̂(b) from the node-drop map's ln J split (about +7.5% of a run) and w(b) from the run's own rows | R4: equal error per row | The map ranks regions for the elasticities' rms (profile cos 0.94) but does not size them per quantity. One more step that can be wrong | Error density varies a lot across b within a case |
| B (the floor) | Scale only | ρ = s·ρ₀ | R1, R2, R3 with the fewest parts | Over-refines low-error regions | The pilot's ρ₀ already has the right shape. On the bank, per-region allocation saved 4.1% of the uses' rows (`proxies/notes.md`) |
| C | Keep E6, swap the check for the drop | E6's layout, insets held fixed as if they were breakpoints, the pinned drop instead of the check | R2 at ε at once, small diff | The drop cannot see the inset strips' error (the gap `single/notes.md` names), which was large on dry (closing +0.34, opening −0.14) | The strips' error is under ε/10 on every case |

**Winner: B, with A's map kept as a diagnostic (R5), not as an allocator.**
- A is eliminated until Q5 shows allocation pays more than one extra step can lose.
- C is eliminated on R2: it keeps the one error the estimate cannot see.

## Kill question

*Assumption whose falsity makes this design unnecessary:* that the integrand is smooth
everywhere except at opening edges, so a density alone can resolve the closing turn at a
cost near E6's.
- **Against it:** E6 resolves the turn for free by cancellation. Its 12-d inset node sits on
  the turn. A density needs spacing under about 10 d near every closing edge.
- **For it:** the drop estimate is honest either way. So if the turn costs too much, the
  design survives: it simply reports the cost truthfully.
- **The retrofit is local:** add each closing edge's c − 12 d point as a second kind of
  breakpoint. It stays a breakpoint, never an inset, so it is never dropped.

Verdict: survives as a hypothesis with a stated retrofit. Q1–Q3 decide it.

## What survives deletion

| Name | Held by |
|---|---|
| breakpoints (opening edges from the pilot) | R2: the corner must sit on a node or the drop misreads |
| ρ, the node density | R4: where nodes go is the only cost lever |
| the pinned drop replay | R2: the only honest single-run estimate per quantity |
| the node-drop map | R5: location (ln J by region, 0.03ε) |
| `target` | R1 |

## What this settles

The following are deleted from the algorithm. Their records stay as measurements.
- the check run, and E6's pair estimate with its bookkeeping;
- insets, edge strips, the H5/U/E6+ layout variants and their strip handling;
- a-priori proxies, the reserve, the validity flag's interval threshold;
- greedy region bisection, and region ranking by ln J.

No estimate depends on two different schedules sharing an asymptotic law. Step jitter
never enters an estimate, because the drop replays the run's own steps.

## What this makes hard

- **Panels with no interior node** (short spells on dry-flat) have nothing to drop. Their
  error goes unestimated. The cope is a rule that every panel holding more than a set share
  of establishment gets one interior node. Q4 sizes this.
- **The order-2 assumption inside a panel at twice the spacing.** It holds up to about
  160-d intervals (`h5/notes.md`). ρ₀ must keep panels under that.
- **The drop needs every other node,** so ρ must give each panel at least two interior nodes
  for the parity to be clean.

## Kill condition

The closing turn costs more than E6's whole committed run at ε. Then switch to the
retrofit (c − 12 d as a breakpoint). If that still loses to E6 on R4, candidate C, with a
strip probe, is next.

## Questions the first runs answer (pre-register before running)

- **Q1** Breakpoints at opening edges only: does the drop estimate pass C2/C3 at ε and ε/2
  on all 18 cases (bank plus held-out, the references already built)?
- **Q2** The floor's rows at ε against E6's committed run plus check.
- **Q3** Does the closing turn need the c − 12 d breakpoint, or does ρ₀'s density resolve it?
- **Q4** How much error sits in panels with no interior node?
- **Q5** Does allocation by the map (A) beat scaling (B) at matched error, by more than the
  map's 7.5%?

## The tool

```r
refine_schedule(p, target = 1)   # returns list(schedule, answer, estimate, where, history)
```

- One loop over (run, drop). `where` is the node-drop map of the answer run.
- Backends: the harness runner on libS; the node-drop patch only for `where`.
