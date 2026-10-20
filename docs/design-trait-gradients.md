# Design: a trait's gradient follows the trade-off it was built along

A design under `.claude/skills/system-design/SKILL.md`, for a PR stacked on plant#116.

## Triage: 2

`stand_gradient()`'s default changes meaning for every caller who leaves `hyperpar` unset. It is
an exported function, but plant has no released version with it, and its callers are this
stack's tests and regnans's harness (unmerged, regnans#87).

## Requirements ledger

- **R1 Correct by default.** `stand_gradient(scm, traits = "1.lma")` is the derivative of the
  metric as lma moves through the construction that built the strategy, which is what a
  difference through `add_strategies()` measures. Today the default is the partial: 54 % off on
  the TF24 smoke fixture (−122.5 against −79.5), 2.4–4× on the 3-year hyperpar test.
- **R2 Partials stay reachable,** for sensitivity analyses on parameters, in one argument.
- **R3 No model runs.** The chain costs under 1 % of a sweep (the hyperparameter functions are
  closed-form R arithmetic).
- **R4 Every species, invaders included,** at its own traits.
- **R5 No silent wrong answer** when a strategy does not lie on the trade-off: one built and then
  edited by hand, or built through a different function.

Scarce resource: the caller's attention. A 54 % error that runs, returns finite numbers and
looks plausible.

## The floor

Default `hyperpar` to `param_hyperpar(scm$parameters)`, the same default `add_strategies()`,
`add_mutant()` and `generate_strategy()` use, so the gradient follows the construction both
sides agree on. `hyperpar = NULL` gives partials. Fails R5 alone: a strategy edited after
construction is silently chained through a trade-off it no longer lies on.

## Candidates

A [first thought] **Move the boundary: keep partials as the default and chain in the
caller.** Commitment: plant reports what the sweep computes. Pays for R2, R3. Costs: every
caller (regnans, trait fits, these PRs' own tests) must know the trap; R1 fails. Wins when
callers mostly want parameter partials; they do not: every evolutionary and trait-fit use
wants totals.

B **Optimise the typical case, detect the rest: the floor plus a guard.** Commitment: a column
is a derivative along an axis the strategy was built along, and plant checks the strategy lies
on it. The guard re-derives each species' derived parameters from its own traits and refuses,
with a sentence, where they disagree. Derived parameters (`k_l`, `r_l`, ...) are not axes under
a trade-off: they leave the default columns and are refused if named. Pays for R1–R5. Costs:
one argument default, one guard; a breaking change to the default's meaning. Wins when
strategies are built through `add_strategies()`, which is the documented path.

C **Move the decision offline: record the construction on the strategy.** Commitment: each
strategy carries its derived parameters' Jacobian, written when the hyperparameter function
runs. Pays for R5 without a guard. Costs: a field on every model's C++ strategy, carried
through copies, rebinds and logpile's fingerprints. Wins when strategies are built by
functions plant cannot name. Killed by R5 itself: a strategy edited after construction carries
a stale Jacobian, which is the silent failure the guard catches.

**Winner: B.** A fails R1 by the 54 % measured. C adds a C++ field to four models to buy what
a guard in R buys, and still fails R5 on an edited strategy.

## The commitment

**A gradient column is a derivative along an axis the strategy was built along: by default
the model's hyperparameter function, which plant checks the strategy lies on.**

Kept true by structure:
- the default argument is the same expression as `add_strategies()`'s;
- the guard runs on every chained call, before any column is formed;
- a derived parameter is not offered as a column, so a partial in it cannot be read as a total.

## Kill question

Assumption whose falsity makes this unnecessary: callers mostly want derivatives along the
traits, not parameter partials. Against it: the test files that difference by editing `pars`
directly. But those referee the sweep's own output, which is a partial by construction;
the workflows that consume gradients (regnans's selection gradients, trait fits, the smoke
test) all build strategies through `add_strategies()` and want totals. Survives.

## What survives deletion

- `hyperpar`'s default → R1.
- The guard → R5.
- Derived columns leaving the default set → R5 (no partial read as a total).
- `hyperpar = NULL` → R2.
- The `jacobian` element of the result → deleted: the derivative of each derived parameter is
  the hyperparameter function's to give, not the gradient's to report. No caller reads it but
  the test that checks the chain rule, which can difference the function itself.

## What this settles

- No caller passes the construction a second time, or can pass the wrong one by default.
- No caller needs to name traits to get totals: the default columns are the traits.
- The ⚠️ warning in `stand_gradient()`'s documentation goes; the trap it warned about is gone.

## What this makes hard

- A caller who wants a partial in a trait must say `hyperpar = NULL`. The tests that difference
  by editing `pars` must say so too: they referee partials.
- A strategy built through a custom hyperparameter function needs that function passed; the
  guard says so when it is not.
- Columns differ between the two modes: under a trade-off the derived parameters are absent.

## Kill condition

If plant moves the trade-offs into the strategies themselves (derived parameters computed in
C++ from traits, as functions the sweep differentiates), every column is a total natively and
this R-side chain, its guard and its argument go. Candidate C is the step before that, and
not worth it alone.

## The design

```r
stand_gradient(scm, metrics = NULL, traits = NULL,
               hyperpar = param_hyperpar(scm$parameters))
```

- `hyperpar = NULL`: today's partials, unchanged.
- Otherwise, per species:
  1. **Derived set:** the columns the function adds to a one-row matrix of the strategy's own
     parameters (none for K93).
  2. **Guard:** those columns, re-derived from the strategy's own traits, equal its
     parameters within 1e-7 relative (the function's own filter drops a column within
     `sqrt(.Machine$double.eps)` of the default, so equality is to that, not to the bit).
     Otherwise stop: "species 1's k_l is not TF24_hyperpar's at its traits; pass the function
     it was built with, or hyperpar = NULL for partials".
  3. **Jacobian:** one call on a matrix of 2P + 1 rows, each pair moving one trait by ±h, gives
     every derived parameter's derivative with respect to every trait.
  4. **Total:** `G[, traits] + G[, derived] %*% J` for the species' columns. A derived
     parameter with no column is one no equation reads (`nmass_l`); its partial is zero.
- Default `traits`: every column but the derived ones. Naming a derived one stops, pointing at
  the trait it comes from or at `hyperpar = NULL`.
- The birth-rate column is no parameter and passes through.
