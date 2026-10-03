# Pathfinders for the next stage, interrupted

Five pathfinders started together, each a new lever or a discarded approach
whose reason no longer holds. A session limit stopped them part way. What
survived is here; the runs (`.rds`), libraries and probe worktrees stay in the
session's scratch `dev/pf_*`.

**Invader thinning** (`invader-thinning/`): an invader's members dropped by
their own share of `J′`. A rare invader moves no field, so the field part that
refuted the resident's thinning (`grid-dynamics.md` §8, test 2) is absent.
- *Step 1 done* (`step1.log`): the exact emulation of a thinned walk from one
  full walk's per-node data repeats every full walk's `J′` to 8.9e-16. Over the
  stand's invader and eight invaders on three records (27 cases), bounded
  Cash–Karp:

  | rule | `ln J′` error, median / largest | over ε/3 | walk and sweep rows saved, median (range) |
  |---|---|---|---|
  | root-law spacing, scale 0.1, per invader | 0.046 / 0.165ε | 0 | 46.6% (23.5–64.9%) |
  | the same, scale 0.03 | 0.008 / 0.047ε | 0 | 34.2% (15.9–57.8%) |
  | one schedule per record from the nine invaders' largest shares, 0.1 | 0.011 / 0.123ε | 0 | 36.5% |
  | one schedule from the stand's own shares, 0.03 | 0.011 / 0.151ε | 0 | 40.6% |
  | the cumulative share's tail past 1 − 1e-4 dropped | 0.023 / 0.124ε | 0 | 16.5% |

- *Recorded in `grid-dynamics.md` §14, and parked until the schedule rules are
  built.*
- *Not run:* step 2, the real thinned walks and sweeps on the probe
  (`invader_subset.patch`: an invader's schedule a subset of the run's
  introductions), so the selection gradient's error is unmeasured; and the
  diagonal, where a thinned walk no longer repeats `J`.

**Soil control under Cash–Karp** (`soil-control/`): the soil's error judged by
the chain alone, and the soil sub-stepped where its coupling to the plants is
weak (the partition, revisited).
- *Q1 done* (`q1_report.log`, bounded Cash–Karp on long drought and episodic):
  - Cash–Karp's embedded soil estimate against the chain alone's true error
    has median ratio 0.95 overall: about 1 in wet spells, 2× over in short dry
    spells, and blind in dry spells past 10 days (median 0.00 against a true
    0.061).
  - On soil-bound steps the members could take 4.7–7.2× longer steps in wet
    spells (R_soil/R_mem median 2.3e3–1.9e4), 1.4× in dry spells past 10 days.
  - Steps whose uptake is under 1% of the soil's budget are 51–66% of steps
    and 48–64% of rows, 91–97% of them soil-bound, and almost none in long dry
    spells: the weak coupling is the wet regime, where the members' headroom is.
- *Q2 not run:* Cash–Karp judges the soil within [0.5, 2] (Decision 1).
- *Q3 done* (`q3/`, recorded in `grid-dynamics.md` §15). Steps whose uptake is
  under 10% of the soil's budget take the soil alone at `1e-9` under an
  extrapolated uptake, with a corrector and the coupling's error in the norm.
  - The registered step, the coupling judged at the soil's weight, saves 48–49%
    of rows but fails its pass on `J` by 2.6% on episodic (+2.6e-4, 22× bounded
    Cash–Karp's). Its gradients are unaffected.
  - Judged at the members' weight (exploratory), it passes every criterion on
    both records: rows −41% and −45%, `J` +2.6e-5 and +7.1e-5, elasticities
    within 0.11ε of the reference, nudges ±0.0002ε. At bounded Cash–Karp's `J`
    error it saves 41% and 29% of rows.
  - Its `J` error stops falling below `3e-5` (about 0.001ε), so its flag must
    yield as the tolerance tightens. The replays' unfrozen sub-steps add up to
    0.03ε of noise to finite-difference elasticities.

**The node axis** (`node-axis/`): B, D and B+D on long-wet and long drought, D
against the thinning the field part refuted, and the light field's ordering.
- *Done:* the spread canopy ported onto `state-weights` and built
  (`src/spread_port.diff`), with an ordering probe; schedules made
  (`schedules.txt`).
- *Not run:* any ladder.

**The events build's design:** not started.

**ARK against bounded Cash–Karp under constant rain**: in
`grid-dynamics/phase1c/combined/` (`prereg_const.txt`,
`report_const_partial.log`). On the 150-node resolved grid, bounded Cash–Karp
saves 5.7% against unweighted. ARK's forward takes 1550 steps against 3951,
−62.1%, with `J` within 1.7e-6. Its gradients and walks did not finish, and
its arm B and `1e-5` runs did not start.
