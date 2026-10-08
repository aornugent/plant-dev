# TF24 gradients in plant: what the solver and controller work buys

2026-10-08 · for the plant maintainers · sources in `docs/` of
[aornugent/plant-dev](https://github.com/aornugent/plant-dev)

## Summary

A TF24 analysis now gets every gradient from one reverse sweep. Its step and node
control spends accuracy where fitness is earned. The headline, timed alone on two
rainfall records (`docs/measurements/headline/`):

| | long drought | episodic |
|---|---|---|
| plant `develop`, default settings: one forward | 134 s | 98 s |
| … its gradient by central differences (100 forwards, computed) | ≈ 3.7 h | ≈ 2.7 h |
| brute force (215 nodes, `1e-5`): forward + gradient | 886 s | 536 s |
| the stack, 108 nodes, pilot included | 209 s (0.24) | 128 s (0.24) |
| the stack, 215 nodes, pilot included | 378 s (0.43) | — |

- **Accuracy.** On episodic the stack at 108 nodes lies within 0.40ε of brute
  force on all 50 quantities. On long drought 108 nodes are too few: entries
  miss by up to 2.1ε. At 215 nodes the stack matches brute force's accuracy
  (median 0.13ε against 0.12ε, both against the two-rung answer) for 0.43 of
  its time.
- **Correctness of the default.** Under plant's default Control, TF24's `J` on
  long drought is 0.45 on `develop` and 0.18 on the stack's build, against 12.75
  at convergence. The default settings carry that gap, not the model.
- **Stability.** No run, gradient or invader walk fails across the five-record
  bank. The ±5% tolerance nudge moves no gated entry past 0.08ε.

**The ask:** review of a stack of 17 branches on the aornugent forks, each closing
one issue, every new behaviour off by default. One open question for review is
FF16: on its birth-date coordinate the reference values move (below).

## Why

regnans builds evolutionary analyses from TF24 runs: a resident at demographic
equilibrium, invasion fitness and its landscape, selection gradients, curvatures,
singular strategies. Classifying one singular strategy takes about 84 runs of
three kinds: the resident's forward (91 s at equilibrium), invader walks on its
recorded steps (0.77 of a forward each), and reverse sweeps (2.2–2.9 forwards).
Each answer must sit within ε of the converged one: 0.025 in `ln J`, and a tenth
of each elasticity's spread over eight weather seeds (`docs/measurements/eps-spread.md`).

Before this work, plant could not deliver that for TF24:

- **No gradients.** Every derivative was a central difference: about 98 forwards
  for TF24's 49 parameters.
- **Failing walks.** On episodic and dry rainfall, the walk of an invader at twice
  the resident's `lma` raised on steps of 27–38 days, past the 26 days its carbon
  pools stay stable.
- **Unreported error.** A coarser companion run reported 0.33–0.41 of the
  invader's real node error, and under constant rain no uniform node count
  converged.
- **Staircase gradients.** Where a cohort's net production changes sign inside a
  step, the gradient jumped as the crossing slid between stages; curvatures across
  those jumps were off by up to 13ε.

## What changed, in merge order

| branch (issue) | what it does |
|---|---|
| `PLANT-93` (PR #94) | exact counts: establishment integrated exactly on the birth-date coordinate |
| `offspring-adjoint` (#91) | the reverse sweep: every parameter's gradient from one pass (TF24 v11) |
| `PLANT-95` (#95) | exact invader replay: an invader walks the resident's recorded steps; at the resident's traits J′ = J to the bit |
| `PLANT-97`, `PLANT-98` (#97, #98) | the pool's relaxation offset (TF24 v12); the pool's stage guard removed |
| `PLANT-99` (#99) | the first invasion walks the recorded run instead of repeating it (139 s against 300 s) |
| `state-weights` | per-state error weights and a bound on them (odelia and plant) |
| `PLANT-100`, `PLANT-101` (#100, #101) | the newborn's height found to roundoff (TF24 v13, phylloptim#17); the field build sets newborns without their rates |
| `PLANT-102`, `PLANT-103` (#102, #103) | a node's step split where its net production changes sign, forward and in the sweep (odelia#53, #54) |
| `PLANT-104` (#104) | `control_tf24()`: TF24's setting named once (tied tolerance, soil weight 10, weight bound 100, 15-day step cap) |
| `PLANT-105` (#105) | the soil stepped on its own where the stand draws little of its water (odelia#55) |
| `PLANT-106` (#106) | `control_window()`: tolerance loosened once fitness is earned, read off a cheap pilot run |
| `PLANT-107` (#107) | crossed crowns summed tallest first, keeping the light field's fast path |
| `PLANT-108` (#108) | the spread: each birth-date interval's leaf area spread over point crowns, so node error falls at the square law |
| `PLANT-109` (#109) | a walk finds the run's nodes by birth date, so an invader can walk a subset |

The stack sits on the fork's `develop` (`be3e2cb`, odelia 0.5.0). Upstream
`develop` has since moved to odelia 0.6.2 (`b5218f9b`), so the stack needs a
rebase before its PRs open upstream.

## Evidence, by change

Each line is a measured effect; sources are in `docs/design-grid-controller.md`
and `docs/measurements/`.

- **The reverse sweep.** A sweep costs 2.5–2.7 forwards at any node count, and
  matches central differences to 7e-4 of the resident's `lma` elasticity.
- **Sign-change splits.** `ln J` lies 3–13× nearer the converged answer than
  without them wherever nodes cross, and the nudge moves no gradient entry past
  ε/6 (up to 0.52ε without). The sweep through them is within 2e-3 of central
  differences on every record, for +5–9% of a gradient run.
- **`control_tf24()` with the window.** 31–34% of a gradient run saved against the
  unweighted run, and every walk runs: the 15-day cap removes the episodic and
  dry failures.
- **The soil stepped alone.** A gradient run takes 0.63 of the time (376 s
  against 596 s, timed alone); rows fall 42–45% on pulsed records and 64% under
  constant rain. Every elasticity stays within 0.063ε.
- **The pilot's window.** On all five records nothing fails, `ln J` is within
  5.8e-5 of a `1e-6` reference, and every entry within 0.004ε of the runs on
  the harness's window.
- **The sort.** Bit-identical at 108 nodes; at 429 a forward takes 0.97 of the
  time.
- **The spread.** Uniform nodes now converge at the square law (ratios 3.5–4.0
  on long-wet and dry), and a coarser companion reports 0.87–0.99 of the error,
  against 0.33–0.41 before. It costs the gradient 6.7% with splits on.
- **The walk by birth date.** In 36 thinned walks every kept node matches the
  full walk to the bit. A shared thinned schedule chosen from the pilot saves
  24–25% of a walk's rows, with the selection gradient by differences within
  0.004ε.

## What moves for existing users

- **Defaults are off.** Every new behaviour sits behind a `Control` field or a new
  function. With them off the stack is bit-identical, except where a test below
  was re-blessed.
- **The height coordinate**, plant's default, does not move.
- **FF16 on the birth-date coordinate moves.** The spread changes its competition
  sum: the deep-crown anchor goes from 17.1406 to 18.0109, and the two-species
  offspring test from 12.05/16.59 to 12.07/16.76. Its error at the default
  schedule is 9–25× lumped's, but it falls at the square law, so a coarser
  companion estimates it. Each move was registered before the re-bless.
- **TF24's model versions** v11–v13 change its numbers (the sweep, the pool
  offset, the newborn's height).

## Limits and open items

- **Episodic needs finer nodes** for a valid error estimate: its error only
  falls at the square law past 429 nodes, where the spacing drops below its dry
  spells (median 31 days).
- **The constant record's gradients** depend on where its later nodes sit, by up
  to 3ε; its graded grid refines only the first year.
- **Diagnostics are next**: each run's error estimate from a half-node companion,
  its distance from the grid's traits, and its failures.
- **The radius** over which one recorded grid serves an analysis is unmeasured.
- **Thinned walks** stay off by default; the pilot-chosen schedule is the
  candidate. Its one miss, 0.43ε, is `recruitment_decay`, a nuisance
  parameter; every other entry stays within 0.087ε.

## How to review

1. **Foundations** (`PLANT-93` to `PLANT-99`): exact counts, the sweep, replay.
   Each is bit-identical by default; the sweep's agreement with central
   differences is its test.
2. **The split** (`state-weights`, `PLANT-100` to `PLANT-103`, odelia#53–#54,
   phylloptim#17): the largest piece, and the one that changes the integrator's
   contract with plant.
3. **Settings** (`PLANT-104` to `PLANT-106`, odelia#55): R-level presets and the
   soil block.
4. **The node rule** (`PLANT-107` to `PLANT-109`): the spread is the one change
   that moves reference values, and the FF16 question above.
