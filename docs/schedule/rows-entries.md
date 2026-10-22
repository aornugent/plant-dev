# The schedule, final: rows and entries

> **Status: not built.** The extension of `refine.md` to the table of sites × strategies
> (`../review/site-selection.md`). Its five changes to `../../OBJECTIVES.md` (*Challenged
> upward*) await the user. Brought verbatim from the tag `archive/trusting-curie`
> (`docs/design-schedule.md`, 21 Oct), with paths fixed. Other paths (`measurements/...`,
> `review/...`, `grid-dynamics.md`, `design-*.md`) are on the tag, under `docs/`:
> <https://github.com/aornugent/plant-dev/tree/archive/trusting-curie/docs>. E1–E8 are the
> regnans roadtest's, not the evidence rounds' of `refine.md`.

A design under `.claude/skills/system-design/SKILL.md`. It finalises how TF24's
runs choose their nodes and steps, for the table of `review/representation.md`:
rows are sites (observed communities under their weather, recorded once) and
entries are strategies walked on a row's recording.

It keeps what the refine loop (`refine.md`) and the step
controller (`time-axis.md`; on the tag, `design-grid-controller.md`) settled, and changes what they serve.
Numbers are measured unless marked *estimated*: E1–E8 are
`measurements/regnans-roadtest/rootcause/`, §n is `grid-dynamics.md`.

## Triage: 3

It sets the public `refine_schedule` call, the control presets every TF24 run
uses, and the error report every entry of the table carries.

## Requirements ledger

- **R1 Accurate.** Per row, for each resident species:
  - its balance F = ln J − ln b, to |F| < 0.02, which keeps g within ε/3
    (dg/d ln b = −6.0, E5);
  - g, its invader's gradient at its own traits, every trait within the
    invader's ε (`lma` 0.20, `a_dG2` 0.050; at least 0.01).
  - Per entry: ln R′ within 0.025.
  - Optionally per row, F_θ (the stand's elasticities) within the resident's ε.
- **R2 Reproducible:** ±5% in tol, or a quarter spacing, moves each quantity by
  under ε/3.
- **R3 Predictable:** every reported number carries its own error estimate.
- **R4 Never fails:** any strategy of the pool walked on any row.
- **R5 Shared:** one row's grid serves all its entries, and is held across
  calibration steps in c while its estimate passes.
- **R6 Performant:** least runtime at ε, for a table of about 100 sites × 300
  strategies per record (*estimated* scale; `representation.md` §6).
- **R7 Diagnosed:** estimates, flags (race, unresolved) and failures, per row
  and per entry.

**Challenged upward** (each changes `../../OBJECTIVES.md`, so each is yours; the
default holds if unanswered):
1. **Curvatures leave the guaranteed set.** No reading of the table uses them.
   Default: drop.
2. **"Continuous in the traits on one grid" becomes a check.** Nothing chords
   or follows a curve any more. Entries are values. Where A_ij differs from
   A_ii + g·Δp by more than ε, the value is reported and the pair flagged.
   Default: replace.
3. **"Shared" moves from a radius in θ to holding a row across steps in c.**
   Rows do not move in θ. Default: adopt.
4. **The constant record moves to the never-fails suite.** One cohort carries
   its J (E8); no landscape there has a gradient to certify. Default: adopt.
5. **The local analysis becomes the pool.** Invaders ×0.5–×2 and the resident
   ±10% become: the pool's strategies on each row. Default: adopt.

**Scarce resource: invader member-steps.** In the table, entries are 18,000 of
19,500 forwards (`representation.md` §6): 92%. An entry costs its members times
the row's steps they live through. So the two levers are the entry's nodes and
the row's steps. The resident's own grid, which all earlier node work
optimised, is under a tenth of the cost.

## The floor

Every entry walked on all of its row's introductions, rows refined as built,
control_tf24 at 3e-5.
- Meets R1, R2 and R4 wherever measured.
- Fails R3: entries carry no estimate, and g is not in the refine's judged set.
  At 108 introductions g is 5.4ε off while ln J is 0.3ε off (E2), and nothing
  would say so.
- Fails R6 by the share of cost it leaves: thinning an invader's nodes by its
  share saves 35–47% of an entry at ≤ 0.17ε (§14), and the floor takes none of
  it.

## Candidates

**A [first thought], one loop for every run** (move 6).
- Commitment: each entry refines like a row, by its own replay.
- Pays for R3.
- Costs: a replay and a second walk per entry, about 1.6× each.
- Wins when entries are few, as in regnans's loop of one invader per step.

**B, an adaptive schedule per entry** (move 7, per strategy).
- Commitment: each entry places its own nodes by the root law on its own shares,
  refined until its own sub-sum estimate passes.
- Pays for R3 (the estimate is free) and R6 (46.6% saved, §14).
- Costs: a coarse walk and a loop per entry.
- Wins when strategies earn in very different windows.

**C, one entry schedule per row, each entry checking itself** (move 5:
the typical case, with the rest detected).
- Commitment: a row's entries share one node set, the root law on the row's
  own shares at scale 0.03. Each entry estimates itself by its sub-sum, and one
  that fails is re-walked on all the row's introductions.
- Pays for R3 (free estimate), R5 (one set per row) and R6 (40.6% saved,
  largest error 0.151ε, §14).
- Costs: one rule; a re-walk for the entries the rule misses.
- Wins when most strategies earn where the residents earn.

**Winner: C.**
- A pays a replay per entry for an estimate C gets as arithmetic: invaders do
  not interact, so dropping every other node is a sub-sum of the per-node
  offspring the walk already returns (exact to 8.9e-16, §14).
- B saves 6 more points than C (46.6% against 40.6%) for a loop and a coarse
  walk per entry, about the cost of the difference.
- C's rule needs no pilot invaders: the row's forward run gives the shares.

## The commitment

**Every node set is a level of a nested density, and every reported number
carries the difference from its own coarser half.**
- For a row, the half is a replay on the run's own steps (as built).
- For an entry, the half is a sub-sum of its own per-node offspring: free.

Kept true by structure:
- A schedule is (breakpoints, density, level). Node times are derived from it,
  with even counts per spell, so a set without a half cannot be expressed.
- An entry's walk returns per-node offspring, not only their sum, so its half is
  arithmetic on what it holds.
- The report has an estimate field per number, filled by the same call that
  fills the number.

## The algorithm

**A row** (one site, one record):
1. **First run** at 100 even introductions per resident species, 0.1 of a run:
   spell edges, offspring curve, T(t), the race check. A resident that is a
   race (one node carries over half its J) flags the row: values only, no
   gradient certified, no refinement past level 1.
2. **Schedule per resident species,** as built: breakpoints at its spell edges,
   density graded by its offspring curve and raised over t_r before each spell
   end, level 0 at scale 1.
3. **Balance b** at level 0: a secant (Broyden for several species; one run
   gives every F_i), warm from the site's data or the last c. It stops at
   |F| < 0.02. The last balance run is the row's run, so no run exists only to
   balance.
4. **Judge the row's own set:** each resident's ln J and g (its invader walked
   on all introductions, and swept), and F_θ if asked. The replay on every other
   node gives the coarse recording, and the invader walk and sweep on it give
   the coarse g.
   - The replay is ln J's and F's estimate, paid whatever g needs. The coarse
     invader has the coarse half's members, so its walk and sweep cost about
     half a fine one's: 0.3 + 1.0 F (E7: 0.59 and 1.94 at 201 nodes). That is
     g's certificate's whole price, about 1.3 F.
   - It is paid once per row schedule. A rejected pass pays nothing: the
     rejected run's g is the coarse g. Later runs on a held schedule (steps in
     c, the site's other records) carry the certified estimate, and certify
     again when their b has moved by more than a tenth (*judgement*: b moves
     with the field, and the field carries g's error).
   - Report Q − e. Stop when every 0.5|e| + u_q < ε (as built).
   - Otherwise double, as built: the rejected run is the next run's estimate.
5. **The entry schedule:** the root law on the residents' own shares, spacing ∝
   share density^(−1/3) at scale 0.03, as a subset of the row's introductions.

**An entry** (one strategy on one row):
1. Walk it on the entry schedule. The walk returns per-node offspring.
2. Estimate by the sub-sum: drop every other node, merge their weights. Report
   ln R′ and its estimate.
3. Where the bound fails, re-walk on all the row's introductions, flagged
   `refined`. Where it still fails, flag `unresolved`.
4. At a resident's own traits, use the row's full walk, so the identity
   R′ = J/b holds.

**The time axis** (`time-axis.md`, as settled and built):
Cash–Karp; the tied tolerance (`control_tf24`); the soil's factor 10; the soil
stepped alone where the plants draw under 10% of it; the soil's substeps landing
the rain's knots; the 15-day cap. The tolerance is chosen once, on the bank
(Validation, V1). Entries ride their row's steps and take none of their own.

## Kill question

Assumption whose falsity makes C unnecessary: that most strategies earn their
offspring in the birth dates where the residents earn theirs.
- Against it: §14 measured C's rule on 27 cases, eight invaders at ×0.5 and ×2
  of `lma` and `hmat` included, and its largest error was 0.151ε.
- For it: those strategies vary two traits around the residents. A pool of
  observed species may differ in hydraulics or phenology.
- Where it fails, the entry's own estimate says so, and the re-walk is the
  floor. **Survives:** the assumption sets C's cost, not its correctness.

## Consistency pass

- **Level 0 at scale 1 was blamed for cost** (the regnans roadtest settled at
  level 0 everywhere). But g needs about 200 introductions on long drought
  (E2, E6), and scale 1's graded layout is 232 on dry. The level is what g
  needs. The cost was the judged set: two resident sweeps over about 50
  elasticities, about 6 forwards per grid. It is now a replay ln J needs anyway
  and a coarse invader walk and sweep at half the members: about 1.3 forwards
  per resident, once per row schedule.
- **Why g's certificate cannot be cheaper than a coarse sweep.** g's node error
  has an own part, the invader's quadrature in birth date, and a field part,
  the coarse field it would read. The own part could come from a second seed
  in the fine sweep (the coarse sub-sum's weights). The field part cannot: it
  is a mixed derivative ∂² ln R′/∂θ′∂E along the drop's defect, and it is not
  small. It is +0.380 in `lma` on 108 → 215, 1.9ε, almost all light
  (`measurements/field-adjoint-map.md`). Spreading each panel's leaf area over
  its members' heights took it to −0.034 (`canopy-spread.md`), but the spread
  was dropped on 2026-10-19. With it back, the certificate would be the own
  part alone, from the fine sweep, at a few percent.
- **C's 40.6% was measured on ln R′ only.** Entries are values, so that is the
  quantity. The gradient that needs full nodes is the diagonal's, which takes
  them (step 4).
- **The window's weight saves 21–28% of rows** (§8, `control_window`), but it
  is built from the residents' and named invaders' shares. A row serves 300
  columns whose late earning it would not see, and the entries' sub-sums do not
  see time error. So it is off for rows until V4 measures entries under it.

## What survives deletion

| part | ledger line |
|---|---|
| breakpoints, graded density, level, even counts | R1, R3 (as built) |
| the replay, and the coarse g on it | R3 for g |
| balance stopping at \|F\| < 0.02 | R1 |
| the race check | R4, R7 |
| the entry schedule from the row's shares | R6 |
| per-node offspring from a walk, the sub-sum | R3 for entries |
| the re-walk on all introductions | R1 where the rule misses |
| the time axis as built | R1, R2, R4 |

**Deleted:**
- curvatures as a target, and the chords that carried them;
- the radius in θ, and the stall boundary's bisection;
- the resident's 50 elasticities as the judged set (F_θ stays on request);
- invaders' spell ends among the row's breakpoints (unmeasured, and now caught
  by the entry's estimate);
- the division at shared sign changes (`design-shared-sign-changes.md`, on hold
  since it is sub-ε; its trigger was a 1% chord, and chords are gone);
- the window's weight, until V4.

## What this settles

- No entry runs a loop of its own, and no entry pays a replay.
- Every number in the table has an estimate, a flag, or both.
- The row's grid is decided once per row, and every column of it reads the same
  steps.
- Constant rain no longer drives the controller's design.

## What this makes hard

- **The field's error in a far entry** is the row's, unestimated per entry. The
  replay measures it at the diagonal. Cope: V3 measures far columns against the
  diagonal; if the ratio is large, each row's coarse recording is kept and a
  sample of entries is re-walked on it.
- **An entry's time error** on its row's steps is not estimated. Cope: the cap,
  and V1's bank nudges with entries included.
- **Rows where a race flags:** values only.
- **The coefficient 0.5 and u_q** stay empirical, from eight cases.

## Kill condition

Entries that fail their sub-sum often (more than about a fifth, where the
re-walks cost what C saved) hand entries to B, per-entry schedules.

## Validation, before it is final

Each is a test the design states in advance, with its bar.

- **V1, the tolerance:** on the bank's smooth records and the held-out cases,
  rows and a column sample at 1e-4 tied, at an absolute tolerance of 1e-4, and
  at 3e-5 tied. Adopt the cheapest whose ±5% nudge moves every quantity under
  ε/3.
  - Known so far: the absolute tolerance of 1e-4 holds within 0.21ε at 0.65 of
    the cost, on long drought only (E6). dry-lma125 is 0.61ε at 1e-4 tied, and
    3e-5 fixes it for 1.32× the rows.
- **V2, the entries:** §14's 27 cases with real thinned walks (`add_entry`,
  PLANT-109). Bars: the sub-sum reads at least two thirds of each entry's error,
  and no accepted entry is over ε.
- **V3, the field in far entries:** each row's coarse recording, with the pool
  re-walked on it. It reports the field part of the error against the
  diagonal's.
- **V4, the window:** rows with and without it, entries included.
- **V5, two residents in one row:** balance by Broyden, breakpoints per species.
- **V6, the race check:** the constant record flags; no smooth record does.

## The build, in order

1. **Subtract.** Drop curvatures, the radius in θ and the 50-elasticity judged
   set from `harness/schedule/refine.R`. Close the sign-change division. Leave the window off for
   rows.
2. **g into the judged set:** the coarse invader walk and sweep on the replay.
   This is the next work item.
3. **Entries:** the entry schedule from the row's shares, the sub-sum, the
   re-walk, on `add_entry`.
4. **V1, V2, V3,** then the tolerance's choice.
5. **Rows of several species** (V5).
6. **Into plant:** `refine_schedule`, replacing the C++ `SCM::refine_schedule`
   and logpile's `refine_schedule` key, as `refine.md` says.

## Cost, per record, *estimated* from E7

For 100 sites × 300 strategies, three residents a row:

| part | before | now |
|---|---|---|
| rows: balance, run, residents' g | about 1,250 F | about 1,700 F, with the replay and g's certificate |
| entries | 18,000 F at 0.6 F | about 10,700 F at 0.36 F (C saves 40.6%) |
| total | about 19,250 F, 260 core-hours | about 12,400 F, 170 core-hours |

At an absolute tolerance of 1e-4, if V1 adopts it, about 0.65 of that: 110
core-hours. The rows' share rises, but every number now carries its estimate.

## The tool

```r
row <- refine_row(site, record, pool_control)  # balanced, judged, recorded
row$answer      # per resident: ln J, F, g (and F_theta if asked), corrected
row$estimate    # per number: e and its bound
row$schedule    # per resident: breakpoints, density, level; the entry schedule
row$flags       # race, unconverged, failed

entry <- walk_entry(row, strategy)  # ln R' on the row's entry schedule
entry$value; entry$estimate; entry$flags   # refined, unresolved
```
