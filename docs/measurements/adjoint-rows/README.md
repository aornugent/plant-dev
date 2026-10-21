# Adjoint rows: a sweep that keeps its costate at every recorded row

A spike of `../../review/prices-and-manifold.md` §3, on odelia ODELIA-59
(b0f5c89) and plant PLANT-95 (8ae7ba87). It is not on any branch; the diffs are
`odelia-adjoint-rows.patch` (+21/−5 in `ode_solver.hpp`, plus a 26-line
standalone test) and `plant-adjoint-rows.patch` (+267/−3, of which about 95
lines are check helpers and 50 are generated exports). Check scripts and logs
are in `checks/`.

## What it does

- `Solver::solve_adjoint` and `sweep_range` take an optional
  `std::vector<adjoint_rows>*`. When given, it is sized to the recording and
  filled at three points: the seed, each row after its step's transpose, and the
  narrowed adjoint at each insertion.
- Wide and narrow at an insertion need nothing extra: the recording already has
  two rows there (the landing, narrow; the insertion, wide), and each kept row
  is as wide as its recorded state.
- With the option off, the only cost is one null test per step.
- In R, `stand_adjoint_rows(scm, metric)` (TF24, one metric per call) returns,
  per row: `time`, `introduction`, the named adjoint (`"1.3.mortality"`,
  `"env.k"`), and the same sweep's gradient.

## Checks, measured

- **Bit-identity:** value and full gradient are `identical()` with the option
  off and on, for resident and invader, and identical to the unmodified build.
- **The invader's mortality identity holds:** at each introduction, the adjoint
  of the node's mortality is −d_k, its direct share of R′, to 7.6e-14, with d_k
  up to 10.8.
- **The resident's does not, and should not:** on the birth-date coordinate
  log density is log β − mortality. So the resident's mortality adjoint is
  −(d_k + c_k), the newborn's value with its competition effect included: on
  node 1, d = 10.79 against λ = −4.22. perf-adjoint.md's identity belonged to an
  older coordinate.
- **Injection holds:** at 54 entries across a mid-run row and both sides of an
  introduction, adjoint × perturbation matches a pinned replay's central
  difference to 1e-5 relative for most entries. The worst entries (2e-3)
  converge to the adjoint as the step varies.
- **The sum rule holds to about 0.5% (resident):** contracting the rows with the
  rates' trait partials by a trapezium over rows reproduces the sweep's gradient
  to a median of 0.26–0.78%, with the worst trait at 7% (a_l1). Step-boundary
  costates cannot give the exact contraction; stage adjoints would.

## Cost, measured

+1.3–1.4% of a sweep on a 40-year long-drought stand with 108 introductions.
Peak memory rose by 35 MB (405 → 440 MB); the kept rows are 6.15M doubles
(47 MB), the size of the recorded states.

## What production needs

- odelia: a per-row visitor rather than a stored vector. Every use is a
  contraction, so each can run as a stream, and keeping the rows is then one
  visitor. Stage adjoints, optionally, for exact contractions.
- plant:
  - rows labelled with the metric, the sweep's kind (field held or
    responding) and the coordinate;
  - a per-individual view (weight, density) as a derived accessor;
  - node-adding rows flagged apart from pulse rows;
  - a layout read from the patch, not rebuilt from the schedule;
  - several metrics per call; FF16.
- Field adjoints for invaders are separate (`prices-and-manifold.md` §3a).
