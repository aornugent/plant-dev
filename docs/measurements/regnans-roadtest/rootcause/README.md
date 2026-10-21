# Why a regnans step on TF24 takes an hour, and what regnans needs

The roadtest (`../roadtest.R`, results in `../first-pass.txt`) took 54–79 minutes
per 40-year climate on the plant #116 tip. This note finds where that time goes,
tests the assumptions behind it, and asks whether our scheduling and invader
adjoints fit what regnans does. Experiments E1–E4 are the scripts here; their
numbers are in `results.txt`. All ran on long drought at its `b* = 4.676` with
`lma = 0.32`, on the same build as the roadtest, with three roadtest climates
running on the other cores.

## 1. Where the time went

Long drought, 4752 s in all:

| | s | share | needed by regnans's loop? |
|---|---:|---:|---|
| pilot forward, 100 even introductions at b = 1 | 50 | 1% | first point only |
| refine: its own first run, the level-0 run and its half-grid replay, each with a full sweep | 782 | 16% | once per grid |
| Newton: 2 runs, each a forward and a full sweep | 908 | 19% | yes |
| selection gradient: an invader run and its sweep | 362 | 8% | yes |
| landscape, 9 invaders in one run | 818 | 17% | no, a diagnostic |
| central differences, 4 invaders | 357 | 8% | no, a check |
| one step uphill: the new resident's equilibrium, 3 runs | 1364 | 29% | yes, it is the next step |
| back invasion, 1 invader | 92 | 2% | no |

A quarter of the time is checks regnans would not run. Most of the rest is the
loop regnans repeats at every evolutionary step: an equilibrium and a gradient.

## 2. The unit cost: one forward run

A forward run at 201 introductions costs 77 s (E1). It is accepted steps × cohorts
alive × the cost of evaluating one cohort, about 13 µs per evaluation and 7.6
evaluations per step (`../../perf-sweep.md`).

- **The steps are set by time, not by the introductions.** 108, 201 and 402
  introductions take 8223, 8549 and 9024 steps (E1, E2), so cost is close to
  linear in the introductions.
- **Daily rain triples the steps.** Long drought and seasonal take 8549 and 8691
  steps, with median steps of 1.1–1.2 days. Constant rain takes 3221, with a
  median of 3.3 days (E4).
- **The 15-day step cap never binds,** on 0.04% of steps. Removing it changes
  nothing (E1).
- **The absolute tolerance of 1e-8 costs 1.6 times.** At 1e-4 the run takes 5157
  steps and 48 s instead of 8549 and 77 s, and ln J moves by 6e-4, 0.02 ε (E1).
  Its effect on gradients is not measured. The 1e-8 came with the refine harness's
  tuned setting, whose soil tolerance factor of 10 and window weights the #116
  tip does not have.
- **About 200 introductions are needed,** so the grid is not oversized. Against
  402 introductions (E2):

  | introductions | ln J | invader's d ln R′/d ln lma | ln R′ at lma × 0.95 |
  |---:|---:|---:|---:|
  | 108 | 0.3 ε | 5.4 ε | 0.9 ε |
  | 201 | 0.01 ε | 0.19 ε | 0.17 ε |

## 3. The domain, written down

Everything regnans asks for is individuals growing in a field: the light
profile and the soil water at each patch age.

- **A resident** is a population whose individuals make the field they grow in.
  Its equilibrium is the birth rate `b*` at which `J(b*) = b*`.
- **An invader** is individuals in a field they do not change. Its fitness is
  linear in what it introduces: `R′ = Σ_s ρ(s) W(s; θ′, E)`. Here `W` is the
  offspring of one individual born at `s`, and `E` is the resident's field.
- **At the resident's own traits, the invader is the resident.** `R′ = J/b = 1`,
  and plant's invader reproduces it to 1e-12. So the selection gradient
  `∂ ln R′/∂θ′` at `θ′ = θ` is the resident's own derivative with its field held
  fixed. It is a property of the resident's run.

Read that way, each cost in §1 has a plain cause.

1. **Newton pays for a sweep it does not need.**
   - Each Newton run sweeps the whole recording (2.3 forwards) to get one scalar,
     `d ln J/d ln b`.
   - The secant through the last two runs gives the same slope for free: −0.7457
     against the sweep's −0.7525 on long drought, and −1.2014 against −1.1953 on
     dry. A secant in `ln b` converged in 1–2 runs from the refine's starting
     point on every climate but constant.
   - So a Newton run costs 3.3 forwards where 1 would do.
2. **For one evolving trait, a difference is cheaper than a sweep.** At the
   resident (E3), the gradient is the same three ways:
   - the sweep gives −23.78595;
   - a forward tangent gives −23.78595;
   - two invaders at `lma × e^{±0.001}` give −23.78594.

   The costs are 0.64 + 2.05 forwards for the invader run and its sweep, 0.64 +
   1.31 for the run and a tangent, and 1.24 for the two invaders. This repeats the
   co-design's arithmetic (`../../../design-workflows.md`, R7): sweeps pay from
   two evolving traits.
3. **Running invaders together shares no work.** Nine invaders in one run cost
   818 s, nine times the back invasion's 92 s. Three cost 148 s at 201
   introductions, against one resident's 77 s (E2). An invader's individuals cost
   what a resident's do. Running them together only removes step choice, which an
   invader never does anyway.
4. **The refine checks quantities regnans does not use, and not the one it does.**
   - It judges the resident's ~50 elasticities, with the field responding, from
     two full sweeps. That costs about 6 forwards per grid.
   - On constant rain it ended unconverged because of `a_l1` and `a_f2`, traits
     regnans does not move.
   - It never checks the invader's gradient with the field held. That gradient
     converges differently: at 108 introductions it is 5.4 ε off while ln J is
     0.3 ε off (E2). On long drought the refine's level 0 happens to be fine for
     it, but nothing would say so if it were not.
5. **Constant's 7 Newton runs and rebuilt grid come from the pilot.**
   - 100 even introductions miss constant's short establishment window. J(1) came
     out 0.52, and the equilibrium is at b* = 24.5.
   - At 201 even introductions and b*, J is 2.8e-10 (E4).
   - In regnans's loop, every step after the first starts from the last `b*`.
     Only the first point needs a pilot, and it should be spaced where
     establishment happens, as the refine's own spacing rule already does.
6. **The step uphill guessed its birth rate from the wrong field.**
   - It started Newton at `b* exp(ln R′/(1 − slope))`. But `R′` is the invader in
     the old resident's field, and alone it makes its own field.
   - So it started at 8.5 against an answer of 5.5 on long drought, and at 2.04
     against 1.56 on episodic, and took 3 runs.
   - Starting from the old `b*`, a 5% move is about 0.3 off in ln J − ln b (the
     co-design's figure), which is 1–2 secant runs.

## 4. What one evolutionary step costs, in forwards at b*

| | the roadtest | the same answers, matched to regnans |
|---|---:|---:|
| equilibrium | 2 × (1 + 2.3) = 6.7 | 1–2, a warm secant |
| selection gradient | 0.64 + 2.05 = 2.7 | 1.24, two invaders |
| a step | 9.4 (12 min) | 2.2–3.2 (3–4 min) |
| verifying a grid, once per grid | about 6: the pilot-spaced first run, the half-grid replay, and a sweep on each of two grids | about 1.1: the half-grid forward and two invaders on it, judged on ln J and the gradient alone |

The step is 3–4 times cheaper with what plant has today. If the absolute
tolerance of 1e-4 holds the gradient within ε, as it holds ln J, it is about 5
times cheaper, at roughly 2–2.5 minutes. The co-design's reference analysis (a
singular strategy found and classified, about 84 forwards) would then take about
1.1–1.8 hours on one core.

## 5. Where the adjoints and the refine do earn their keep

- **Many traits at once:** the resident's whole elasticity row, trait fitting,
  and any analysis evolving two or more traits. Here one sweep beats 2k runs.
- **OBJECTIVES' guarantees for every elasticity,** for residents and invaders.
  That is what the refine checks, and it is the right check for that goal. It is
  the wrong check, at the wrong price, inside regnans's one-trait loop.

So the machinery is not wrong; it is aimed at a different consumer. For regnans,
the sweep belongs in the answer's report (the full elasticity row, once, at the
end), not in the loop.

## 6. What this suggests, untested

- **A tangent with the field held, carried in the resident's own run.** It would
  give the selection gradient as a by-product of the equilibrium's last run, with
  no invader at all. Its cost is unmeasured. plant's `census_trait_tangent` (2.1
  times an invader run, as a replay) suggests about 1.3 forwards on top of the
  run, against 1.24 for two invaders. So it is a simplification more than a
  saving.
- **The grid judged on what the analysis uses:** ln J for the equilibrium, and the
  evolving traits' invader gradients.
- **Invaders thinned to the introductions that carry their R′.** Earlier
  measurements kept 53–66% of an invader's run at 0.17 ε
  (`../../../grid-dynamics.md` §14).

## 7. The loop, rethought

### Two unknowns, two conditions

An evolutionary analysis on plant tracks two things:
- the traits θ: one, as in the roadtest, or all of TF24's ~50;
- the birth rate b, the seed rain the resident receives.

It needs two conditions:
- **Demographic equilibrium:** the stand returns the seed it receives,
  `F(θ, b) = ln J − ln b = 0`. For each θ, one birth rate `b*(θ)` satisfies this.
  Drawn in the (θ, ln b) plane, those birth rates trace a curve.
- **Selection:** the selection gradient `g(θ, b)` is the slope of a rare
  invader's ln R′ in its own traits, in the field the resident makes at (θ, b).
  Evolution moves θ along `g`. A singular strategy is where `g = 0` on the curve.

### What the roadtest does: walk to the curve, then step

```
 ln b                          o = a run
  |        curve F = 0
  |       /                    at each θ: Newton runs up and down
  |  o   /                     until it sits on the curve,
  |  o  o                      then one step sideways in θ
  |  | / o
  |  |/  o
  |  o   o
  +---------------- θ
```

At every θ, Newton runs until |F| < 1e-4. Each of its runs also does a full
sweep, but only to read one number, the birth-rate slope.

### What adjoints allow: step along the curve

The curve's direction at any point follows from two slopes:
`d ln b*/dθ = −(∂F/∂θ)/(∂F/∂ ln b)`. The resident's sweep of ln J, with the field
responding, gives both in one pass, for every trait at once:
- **∂F/∂ ln b, from the birth-rate column.** On long drought it is −1.75: 10%
  more seed gives about 7.5% more offspring, because crowding absorbs the rest.
- **∂F/∂θ, from the trait columns.** The stand's total elasticity in `lma`
  along the trade-off is −5.9 (`../../../design-workflows.md`, R5, at 108
  introductions).

So a move in θ comes with a predicted move in ln b. The next run lands next to
the curve, not somewhere far off it:

```
 ln b
  |        curve F = 0
  |       /
  |      o            one run per step: θ and ln b move together,
  |     o             along the curve's direction; what is left of F
  |    o              is corrected on the next step
  |   o
  +---------------- θ
```

**Checked on the roadtest's own step uphill** (long drought; lma from 0.32 to
0.304, so Δ ln lma = −0.051):
- `d ln b*/d ln lma = −(−5.9)/(−1.75) = −3.37`, so ln b should rise by 0.173.
- The predicted b* is 5.56. The true one, found by the roadtest's Newton, is
  5.48. That is 0.015 off in ln b, which leaves |F| = 0.026.
- E5 says a gradient read at |F| = 0.026 is 3.4 × 0.026 = 0.09 off, 0.4 ε. So
  the first run at the new traits already gives a usable gradient, and one more
  run brings |F| to O(0.026²).
- The roadtest instead started from a guess built on the old resident's field,
  b = 8.55, 0.44 off in ln b. It took 3 runs.

### Why the equilibrium need not be solved

- The field matters. Along the trade-off, the resident's total elasticity is
  −5.9, while the selection gradient with the field held is −23.8.
- But how close to the curve you must stand is set by how fast `g` changes with
  b. On long drought it is `dg/d ln b = −6.0` (E5), so the gradient's error is
  3.4 × |F|. It stays within ε (0.20) for |F| < 0.06, and within ε/3 for
  |F| < 0.02. The roadtest solved to |F| < 1e-4.
- E5 also checks the claim that at the resident's traits the invader is the
  resident: its ln R′ equals F to every printed digit, at every birth rate tried.

### One step of the loop, in full

The state is (θ, ln b) and the last run's recording.
1. **Run the resident** at (θ, b), recording it. Read F.
2. **Sweep the resident's ln J,** with the field responding. This gives
   ∂F/∂ ln b and ∂F/∂θ for every trait: 2.3 forwards.
3. **Take the selection gradient g, with the field held.** Two ways:
   - one trait: two invaders at θ e^{±0.001}, 1.24 forwards;
   - every trait: one invader at θ and its sweep, 2.7 forwards. This works on the
     #116 tip today.
4. **Move:** θ ← θ + Δθ, then ln b ← ln b − (F + ∂F/∂θ · Δθ)/(∂F/∂ ln b).
   Δθ can be an evolutionary step along g, or a step toward g = 0.

Steps 2 and 3 read the same recording. A sweep's cost is about 75% recording the
tape and about 10% the reverse pass (`../../perf-sweep.md` §2). So step 3, for
every trait, could become a second reverse pass over step 2's tape with the
field's adjoints dropped. That would cost an estimated 0.3 forwards, and needs no
invader run. It is not built.

### What becomes possible

**A singular strategy found without nested equilibria.**
- Finding where g = 0 becomes one root-find in (θ, ln b) together, not a
  search with an equilibrium solved inside every candidate.
- For one trait it is a secant on g along the curve. Each iteration is one run
  and the gradient, about 2.2 forwards. A secant's error falls roughly as
  0.3 → 0.1 → 0.02 → 0.001, so about five iterations from a start 30% off.
- For several traits it is a Broyden iteration on the same pair.

**Classification for almost nothing.**
- *Convergence stability* is the sign of dg/dθ along the curve. The secant
  iterations have already measured it.
- *Evolutionary stability* is the sign of ln R′'s curvature in the invader's
  traits. Two invaders at θ e^{±0.05} give it, since `ln R′(θ) = F` is already
  known.

**Every trait's selection gradient at every step.** In TF24 that is a vector of
about 50. It says which traits are under selection and in which direction. It
is also what a multi-trait canonical equation, or a search for which traits
matter, needs.

**Estimated budgets,** in forward runs at b* (about 77 s each at 201
introductions, or 48 s if the looser absolute tolerance holds):

| | today's loop | the loop above |
|---|---:|---:|
| one evolutionary step, one trait | 9.4 | 2.2 |
| one evolutionary step, every trait | not practical (about 60 by differences) | 6.0, or about 3.6 with the second reverse pass |
| a singular strategy and its classification, one trait | about 84 (the co-design's floor) | about 18: a cold start of about 4, grid verification of 1.1, five iterations of 2.2, and an ESS check of 1.2 |

The 18 is an estimate built from measured pieces, not a measured run.

### What it does not remove

- **The cold start.** The first equilibrium still needs a secant from a pilot,
  about 4 runs to |F| < 0.02. On constant rain the pilot needs its introductions
  front-loaded: even spacing gives a J 570 times too small.
- **The cost of one run.** About 8,500 steps of about a day, times about 200
  introductions (E1, E2). Section 6's levers apply: the absolute tolerance, and
  thinned invaders.
- **Large steps.** The predictor is a straight line, accurate to O(Δθ²). Where the
  curve bends sharply it needs shorter steps. On constant rain, Newton saw the
  birth-rate slope run from +0.99 to −8.5, which is untested ground for this
  loop.

### Not yet shown for this loop
- the tolerance on |F| on other climates (E5 is long drought only);
- the predictor on constant rain, and over a sequence of steps rather than one;
- the secant's iteration count toward a real singular strategy;
- the second reverse pass's cost.

## 8. Constant rain: no gradient at the resident

The third pass (`../logs/roadtest-constant.log`) finished the constant climate,
and its landscape jumps at the resident's own traits:

| lma × | 0.85 | 0.95 | 1.00 | 1.05 | 1.20 |
|---|---:|---:|---:|---:|---:|
| ln R′ | +8.78 | +7.40 | 0 | −39.85 | −44.95 |

- The central difference is −40 197 at h = 1e-4 and −8 161 at h = 1e-3. The sweep
  gives −6.3 million. So ln R′ changes by about 8 within ±0.01% of `lma`: a
  jump, not a steep slope.
- The selection gradient does not exist there, and neither the loop above nor
  regnans's differences can follow it.
- The same climate's b* moved from 24.5 to 45.1 when its schedule was rebuilt,
  and both refines ended unconverged.

The cause is not yet known. Three candidates:
- a real priority effect: an even-aged stand where a cohort a hair taller takes
  the light;
- a jump in the leaf model, such as the hydraulic shutdown in the kink inventory;
- an artefact where an invader's crowns tie with the resident's in the light
  field.

A tiny trait change that moves ln R′ by 8 points away from a smooth priority
effect. Episodic, dry-flat and the other climates have smooth landscapes, and
their sweeps match central differences to 1e-6.

## Assumptions not yet checked

- The absolute tolerance's effect on the gradients: only ln J was measured.
- Node needs on climates other than long drought. Constant needs its introductions
  front-loaded, and even grids fail there outright.
- The secant's run counts are read from the roadtest's logs at one tolerance, not
  measured across a sequence of evolutionary steps.
- Timings were taken with three other R processes running on a 4-core machine.
  Ratios within one experiment are comparable; absolute seconds are high by a few
  percent to tens of percent.
