# Pathfinders for the next stage

Five pathfinders started together, each a new lever or a discarded approach
whose reason no longer holds. A session limit stopped them part way; what
survived was rescued, and the soil and node-axis runs were finished after. The
runs (`.rds`), libraries and probe worktrees stay in the session's scratch
`dev/pf_*`.

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

**Soil control under Cash–Karp** (`soil-control/`). This pathfinder asked three
questions about the soil under bounded Cash–Karp: whether Cash–Karp's own error
estimate judges the soil correctly (Q1); whether the estimate from the soil
integrated alone would do better (Q2); and whether the soil can be stepped on
its own where its coupling to the plants is weak, which revisits the
partitioned step of `grid-dynamics.md` §13 (Q3).
- *Q1 is done* (`q1_report.log`, on long drought and episodic). Cash–Karp's
  embedded estimate of the soil's error has a median ratio of 0.95 to the true
  error of the soil integrated alone. It is about right in wet spells, about
  twice too large in short dry spells, and blind in dry spells longer than 10
  days, where it reads a median of 0.00 against a true 0.061.
  - On steps limited by the soil, the members alone could take steps 4.7–7.2
    times longer in wet spells, and 1.4 times longer in dry spells past 10 days.
  - Steps whose uptake is under 1% of the soil's budget make up 51–66% of steps
    and 48–64% of rows. Of those, 91–97% are limited by the soil, and almost none
    fall in long dry spells, so the weak coupling is the wet regime, which is
    where the members have room to step further.
- *Q2 was not run,* because Q1 found Cash–Karp's estimate within a factor of two
  of the truth, the pre-registered condition for skipping it.
- *Q3 is done* (`q3/`, written up in `grid-dynamics.md` §15). On steps whose
  uptake is under 10% of the soil's budget, the soil is integrated on its own
  under an extrapolated uptake, a corrector pass follows, and the coupling's
  error enters the step's error norm.
  - The registered version judges the coupling's error at the soil's weight. It
    saves 48–49% of rows, but it fails its pass on `J` by 2.6% on episodic, where
    its error is 22 times bounded Cash–Karp's. Its gradients are unaffected.
  - A second version judges that error at the members' weight. It passes every
    criterion on both records: rows fall 41% and 45%, the error in `J` is
    +2.6e-5 and +7.1e-5, every elasticity is within 0.11ε of the reference, and
    the tolerance nudges move `ln J` by ±0.0002ε. At bounded Cash–Karp's error
    in `J`, it saves 41% and 29% of rows.
  - Below `3e-5` its error in `J` stops falling, at about 0.001ε, so the
    threshold that picks its steps must tighten with the tolerance. The replays
    used for finite differences add up to 0.03ε of noise to the elasticities,
    because the soil's adaptive inner steps are not held fixed.

**The node axis** (`node-axis/`, recorded in `grid-dynamics.md` §16): B, D and
B+D on long-wet and long drought, D against the thinning the field part
refuted, and the light field's ordering. The probe build is `src/probe_build.diff`.
- *Long-wet done* (`ladder_wet.log`, `q2_thin_wet.log`, `order_wet.log`,
  `cost_wet.log`):
  - D is on the square law over u108–u215–u429 (ratios 3.72–4.42, companions
    0.93–1.10). B and B+D are not (2.76 and 2.84, companions 0.71 and 0.65).
    The finest extrapolations of B, D and B+D agree to 0.033ε.
  - D's u108 + u215 extrapolation is the cheapest answer with an honest
    estimate: 2.41M rows for 0.090ε, its estimate covering 93%.
  - Thinning after b = 10 fails spread as lumped: the field part is the soil's.
  - The ordering breaks only at u429 (20% of builds, by at most 1.1 mm). The
    sort costs nothing measurable; walking every node costs 23% of a forward.
  - The spread costs 2–6% of the resident's sweep per row.
- *Running:* the long-drought ladders (H4).

**The events build's design:** not started.

**ARK against bounded Cash–Karp under constant rain**: in
`grid-dynamics/phase1c/combined/` (`prereg_const.txt`,
`report_const_partial.log`). On the 150-node resolved grid, bounded Cash–Karp
saves 5.7% against unweighted. ARK's forward takes 1550 steps against 3951,
−62.1%, with `J` within 1.7e-6. Its gradients and walks did not finish, and
its arm B and `1e-5` runs did not start.
