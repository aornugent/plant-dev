# Offline: the crossing step halved in the program

## Triage: 3 — the treatment crosses odelia's step, its sweep and the row every walker reads. The incumbent's review asked to rethink the orchestration, and the ledger arrived as mechanisms ("split", "cut").

## Requirements ledger
R1–R13 as in `ledger.md`, unchanged except R8 (challenged below). Two readings of the incumbent I add:
- it misses R7 as worded: ln J′ − ln J = 7.0e-5 on the diagonal (`curvature_rows.log`);
- it counts splits before the validity check, where R11 asks for committed steps.

Scarce resource: reader load. Any per-crossing treatment costs about 0.25 of a full gradient run's 7 forwards, against the floor's 2.9, so runtime is nearly settled. The incumbent spends 1722 lines and five mechanisms on that 0.25: three detection rules, regula falsi, pieces in a field read at five fractions, the end rated again, and implicit-function cuts.

## The floor
Plain Cash–Karp at 1e-5, with no code. It fails R8: +41% leaf solves on every pass, 2.9 forwards per full gradient run against 0.25. R2 is borderline (0.33ε at r = 1e-2, inferred).

## Candidates
**A, under the move (decision offline):** where some node's net production changes sign inside an accepted step, the forward replaces that step with two equal steps, and the halves are ordinary steps of the program.
- Commitment: the treatment is the mesh.
- Pays for R8 against the floor (0.41 against 2.9 forwards), and for R3, R4, R7 and R12 by construction.
- Costs one concept and one flag: +10% on the forward and +5.1% on every replay (counted from 726–760 halved steps).
- Wins when crossings cluster. On long drought, 9247 node crossings sit in about 726 of 14 840 steps, 12.7 per step. So a row per crossing step costs about what the incumbent spends there: 1.1 rows per split step in its forward, 1.5 in its sweep (measured).

Set aside under the same move:
- **B: per-node sub-steps at fixed fractions,** with no location and no implicit function, decided again on every run. It deletes about 14% of the incumbent (inferred) and keeps half its margins (m = 3: d_I 0.51 ε/3, inferred). Its choices jump by the node's smooth local error, the same mechanism as the incumbent's pair-birth jump.
- **C: the incumbent, with its walkers adding the resident's recorded end changes.** It meets every line and fixes R7 at no cost, but deletes nothing.

**Where the move leads back.** The move's first answer is the incumbent's: the forward decides and the sweep replays. Three facts push the decision further offline, into the mesh:
- A per-node choice made again on every run stays continuous only through a location. A location needs the implicit function: held cuts are 7.5e-3 off, against R4's 2e-3.
- Freezing per-node choices per grid needs a new field in the program.
- A step is already data that every pass replays.

**Winner: A if the challenge below is accepted; C under the default answer.**
- The floor fails R8 by 2.5 forwards per full gradient run.
- B keeps 86% of the incumbent's code (R9) and halves its R1 and R2 margins.

## Challenge (R8, upward)
A costs 0.16 forwards more than C per full gradient run:
- the forward +10% against +6.0%;
- the sweep +5.1% against +7.3%;
- each invader walk and its sweep +5.1% against 0.

That is 2.3% of the run, and about 5% of a walk-dominated analysis (inferred). In exchange it removes about 1350 of the incumbent's 1722 lines. Would you accept that? Under the default answer (no), A misses R8 by those amounts, and C is this move's design.

## The commitment
The treatment is the mesh: a crossing step becomes two ordinary steps of the program, so nothing after the forward decides anything.

Kept true by: the System's only obligation is `sign_values()`. odelia halves only inside the adaptive step, and what it produces is the existing row type. The pinned paths (`step_to`, `step_by`, the walks, the sweep, the tangent walks) take the program as given and have no way to halve.

## Kill question
Assumption: crossings cluster, so a row per crossing step costs about what per-node pieces cost.
- On long drought (ledger): 12.7 node crossings per crossing step. The incumbent's forward pays 0.38 ms × 12.7 = 4.8 ms per split step, against 4.4 ms for a row.
- On the constant record, 41 node steps split in 3355 steps (spike), so A adds at most 1.2% of rows whatever the clustering.
- On episodic, 6210 node steps split in 9248 steps (spike).

Verdict: survives.

## What survives deletion
- `KinksAtSignChanges` (the concept that asks for `sign_values()`, taken from the incumbent): R1, R2. The forward has to see where the rates change form.
- Halving a kept attempt whose readings take both signs: R1, R2.
- m = 2: R8. With m = 3 the added rows double.
- `ode_halve_sign_changes`: R10.
- Per-node `halved` counts, added when the halves commit: R11.
- `sign_value_aux()` on TF24's strategy: R12. The model names its own sign value.

## What this settles
- No per-node path anywhere: no dense output, field reads, pieces, cuts, slopes, implicit-function nodes or held stage times. odelia knows nothing about blocks (R12).
- The sweep, invader walks, tangent walks and pinned replays run today's code. `require_unsplit` is deleted.
- J′ = J to the last bit on the diagonal (R7).
- On a frozen grid, J is analytic in θ, with no choice to jump at (R3). The sweep is exact, with no held times (R4).
- No new record type.

## What this makes hard
- Every walker pays for the halves: +5.1% on each invader walk and its sweep on long drought.
- The forward discards one attempt per crossing step: +10%, against the bar's 6.0%.
- The staircase is halved, not removed (inferred):
  - R1: d_I 0.68 ε/3 (0.84 at the toy's measured ratio), against the incumbent's 0.28;
  - R2: 0.15ε, against 0.05;
  - at 3e-4, R1 probably fails (0.8–1.0 ε/3).
- Replays at θ ≠ θ₀ keep θ₀'s halves. The toy showed no loss at r ≤ 3e-2.

How I'd cope: m = 3 (d_I 0.51, but 0.77 forwards per full gradient run against C's 0.25), or halve only inside the window's weight where that weight is set.

## Kill condition
R8 held per pass, or R1 required at 3e-4. Either one hands the design to C: the per-node record, with walkers adding its recorded end changes.

## The design
- **odelia** (on `a62e97c`):
  - The concept `KinksAtSignChanges`.
  - `Step::step` reads `sign_values` after each stage and at the end, as the incumbent's step does, and reports whether any value takes both signs over the start, the five stages and the end.
  - In `SolverInternal::step`, an attempt that is kept and changes sign is replaced by two pinned steps of h/2, each pushed as a row. A throw, or a state the validity check refuses, rejects the attempt as the adaptive path already does.
  - The next proposal comes from the original attempt. Per-value counts are added at commit.
  - About 85 lines, plus 110 of tests.
- **plant** (on `4555ea13` with v13 and #101, which are separate issues):
  - TF24's `sign_value_aux()` and `Patch::sign_values()` (empty when the flag is off), taken from the incumbent.
  - `Control::ode_halve_sign_changes`.
  - `SCM::r_ode_halved`, reported per node.
  - About 50 lines, plus about 60 of generated bindings and 70 of tests.
- **Data flow:** the adaptive forward writes the program, and every later pass replays its rows.
- **Size:** about 375 lines, against 1722.
- **Deleted:**
  - from odelia: the dense output, the five reads and their quartic, `integrate_pieces`, `Step::split` (detection, regula falsi, golden search), `taped_split`, `part_split`, `unsplit_end`, `RatesParts`/`SplitsSignChanges`, and the split record's search and least-rate fields;
  - from plant: `part_width`/`part_reads`/`part_rates`, `set_node_ode_state`, `compute_node_rates`, `field_recorded` and `require_unsplit`.

## Spike files (`spikes/offline/`)
- `toy.R`: 24 nodes reading net production through σ (η = 1e-4) and a fast soil state, Cash–Karp on frozen meshes. Arms: plain, sub(m), cut (relocated each θ), and glob(m) (halves kept in the mesh).
- `nudges.R`, `nudges_1e-6.{log,rds}`: kink-dominated, since the cut's spread is 0.3% of plain's.
  - Gradient sd under 7 nudges, relative to plain: glob2 0.64, glob3 0.35, sub4 0.28, sub8 0.18, cut 0.003.
  - Curvature sd at r = 1e-2: glob2 0.27, glob3 0.23, cut 0.001.
  - glob(m) equals sub(m) at each m, including θ₀'s halves replayed at θ₀e^{±r}.
- `nudges_1e-4.{log,rds}`: coarse steps. Plain's spread is kink-dominated (cut 0.017), but sub-stepping changes each treated node's smooth error, and that dominates the sub arms (sub3 0.77). Read as a caution only.
- `nudges_hf_1e-4.log`: a fast ripple gives 1% crossing node steps, but the smooth error dominates (cut 0.73 of plain). Uninformative; its reference run was stopped.
- `continuity.R`, `cont_sub3.*`, `cont_cut.*`: on coarse steps, choices remade per run jump.
  - sub3: 24 changes, median 1.9e-10, 5 above 1e-8.
  - cut: 18 changes, median 1.4e-9, 4 above 1e-8.
  - A frozen program has none.
- `flip_probe.R`: the largest jumps are a node's smooth local error in a coarse step (2.3e-6 relative change in F), or a pair at the scan's resolution.
- `fwd_constant.*`, `fwd_episodic.*` (TF24, `lib_rr`, split on, 1e-4, 108 nodes): constant has 41 node steps split in 3355 steps; episodic has 6210 in 9248.
- `analyze.R`, `analyze_glob.R`, `nudges_glob.R`: analysis scripts. `nudges_glob.R` is superseded by the glob arms in `nudges.R`.
