# Step attempts by outcome on the TF24 adaptive solver

Fixture: `scm_base_parameters("TF24")`, one strategy (`lma = 0.0825`),
`max_patch_lifetime = 5`, default `control()` (RKCK 4(5), `tol_abs = tol_rel =
1e-8`, `a_y = 1`, `a_dydt = 0`, `step_size_min = 1e-8`). Two forcings, exactly
`probe7_rain.R`'s:

* **constant** — `extrinsic_drivers_set_constant("rainfall", 3.0)`
* **semiarid** — the pulsed daily series (seed 24), tiled across the lifetime.

Build: `odelia` installed from source, `plant` built with `make compile`
(`-O2`), serial, `TESTTHAT_PARALLEL="false"`. Script: `rejcount.R`.

## Instrumentation

`SolverInternal::step()` retries until a step is taken, and a run reported only
the steps it kept. `odelia::ode::step_outcomes` now counts the five ways an
attempt can end, incremented where each is settled inside the retry loop;
`SolverInternal::reset()` clears them. `plant` surfaces them as
`scm$ode_step_attempts`, a named integer vector, beside `ode_times` /
`ode_step_sizes`.

Distinguishing (e) from (a) needed one thing the solver could not already see:
whether the error estimate was over tolerance on a step that was nevertheless
taken. `OdeControl` now names the threshold it tests (`tolerable_ratio = 1.1`,
previously a literal in one branch) and answers `error_over_tolerance()` from
the ratio it already records, so nothing repeats the number.

Cost: five `size_t` increments, one per attempt, on a path that has just run
five to six patch rate evaluations. Coverage in `tests/standalone/r_free.cpp`
(`test_step_outcomes_are_counted`), which reaches all five buckets.

Committed as `odelia be3e2cb` and `plant 5321593a` on
`claude/trusting-curie-4i9n3l`, both pushed to the `aornugent` forks.

## The census

| outcome | constant | semiarid (pulsed) |
|---|---|---|
| **(a)** accepted | 530 | 1017 |
| **(e)** accepted at the floor (`rmax > 1.1`, could not shrink) | **0** | **0** |
| **(b)** accuracy rejection | 97 | 292 |
| **(c)** domain rejection, thrown | 27 | 104 |
| **(d)** domain rejection, refused by `ode_state_valid()` | **0** | **0** |
| **total attempts** | **654** | **1413** |
| rejections (b+c+d) | 124 | 396 |
| **rejections / attempts** | **19.0 %** | **28.0 %** |

(a) reproduces the earlier measurement exactly — 530 accepted steps under
constant forcing, 1017 under pulsed — and (a)+(e) equals the number of finite
step sizes on `scm$ode_step_sizes` in both runs, so every step this run took
went through the error-controlled path and none through `step_to` / `step_by` /
`step_euler`.

Three of the five outcomes carry everything. **(e) never happens**: no step in
either run was committed over tolerance at `step_size_min`, so the branch
`ode_control.hpp:178-186` describes is not exercised here. **(d) never
happens** either: `Patch::ode_state_valid` refused no completed step, because
the one thing that would make it refuse — a non-finite environment state — is
caught a stage earlier by the throw below.

## Cost in rate evaluations

Measured directly, with a temporary counter inside `Step<System>::step`
(applied, measured, reverted — not committed). Every attempt that completes
runs exactly 6 rate evaluations: 5 stages plus the endpoint, the endpoint being
the next step's `k1` under first-same-as-last. An attempt that throws stops at
the offending stage and costs fewer.

| | constant | semiarid |
|---|---|---|
| rate evaluations, total | 3843 | 8344 |
| on accepted attempts (6 × (a+e)) | 3180 | 6102 |
| on accuracy rejections (6 × (b)) | 582 | 1752 |
| on thrown attempts | 81 | 490 |
| **on rejected attempts** | **663 (17.3 %)** | **2242 (26.9 %)** |
| mean cost of a thrown attempt | 3.0 evals | 4.7 evals |

A cross-check fell out of the same run: `Patch::set_ode_state` was entered
exactly (rate evaluations + throws) times in both runs — the extra being the
explicit state restore after each caught `DomainError` — so the stepper is the
only thing evaluating rates during the run, and the total above is the run's
whole rate-evaluation cost.

The accounting in the brief (accepted 6, rejected 5) gives 16.3 % and 24.5 %.
It undercounts by about one point in each case for one reason: an accuracy
rejection also pays for the endpoint evaluation, because `Step::step` computes
`dydt_out` before the error estimate is formed and the caller discards it. An
accuracy rejection costs 6, not 5. Throws are the cheap rejections, not the
dear ones.

## (f) Where the DomainErrors come from

`plant` has exactly two `stop_domain` call sites, and nothing in `phylloptim`
or `odelia` adds a third. Both were counted with a temporary tally (applied,
measured, reverted):

| throw site | condition | constant | semiarid |
|---|---|---|---|
| `plant/inst/include/plant/models/tf24_strategy.h:1979-1985` | `storage < -storage_domain_tol * storage_max` (TF24 storage pool negative by more than `1e-8` of capacity) | **27** | **104** |
| `plant/inst/include/plant/patch.h:848` | a non-finite environment (soil-water) state | **0** | **0** |

The tallies match `rejected_thrown` exactly in both runs (27 and 104), so every
`DomainError` the solver caught came from that one site and none was raised and
swallowed elsewhere.

**All of them are in the per-member inner path, none in the environment block.**
The site is inside `TF24_Strategy::compute_rates`, evaluated per individual per
stage; it fires when an RK stage overshoots the empty end of a cohort's storage
pool. The environment-block site — the one that exists for the soil-water
runaway — never fired on this fixture, and correspondingly `ode_state_valid()`,
whose environment check is the same condition applied to the completed step,
refused nothing.

## Verdict on "~480 rejections in a resident run that goes on to complete"

**Not confirmed. The number does not reproduce, and the quantity it names is
off by more than that.**

The comment (`ode_solver_internal.hpp`, in the `step_to` block) attributes ~480
to the TF24 model *throwing* — `DomainError` rejections. On the fixture above
that count is **27** (constant) and **104** (pulsed): 18× and 4.6× below the
claim. Read more generously, as *all* rejections, it is **124** and **396** —
still not 480, though the pulsed figure is the right order.

The fixture is not obviously the one the number came from: it pins
`max_patch_lifetime = 5`, where the TF24 default is 105.32. Re-measured at the
default lifetime, both forcings overshoot 480 badly:

| lifetime 105.32 | accepted | (b) | (c) | (d) | (e) | attempts | rejections |
|---|---|---|---|---|---|---|---|
| constant | 7466 | 1631 | 159 | 0 | 0 | 9256 | 1790 (19.3 %) |
| semiarid | 18368 | 6386 | 1978 | 0 | 0 | 26732 | 8364 (31.3 %) |

So no TF24 resident run measured here — short or default lifetime, constant or
pulsed — gives ~480 of anything. 480 falls between the short-lifetime run (124
/ 396 rejections) and the default-lifetime one (1790 / 8364), which is what one
would expect of a number taken on a third fixture that is not recorded.

What survives of the claim: TF24 throws `DomainError` **routinely** rather than
exceptionally — 4.1 % of attempts under constant forcing, 7.4 % under pulsed,
and 7.4 % at the default lifetime under pulsed — which is the point the comment
was making about the pinned-time path. The specific figure should not be
trusted or quoted; it names throws and the throws are far fewer.

Note the rejection rate is also stable in lifetime (19.0 % → 19.3 % constant,
28.0 % → 31.3 % pulsed), so rejections scale with the run, and any single
absolute count only means something with its fixture attached.

## Guard runs

* `odelia make test-cpp`: all checks pass, including the new
  `test_step_outcomes_are_counted`.
* `odelia` R suite: 313 pass, 0 fail, 5 errors — all five in
  `test-implicit-value.R`, all `Rcpp::sourceCpp` failing to build the snippet.
  Pre-existing and unchanged.
* `plant` fast sweep (every file but `test-mutant.R`,
  `test-strategy-tf24.R`, `test-strategy-tf24f.R` — 75 files as the directory
  now stands): 4405 pass, 0 fail, 0 error.
* `plant/tests/testthat/test-mutant.R`: 22 pass, 2 fail — the two known
  pre-existing failures on this branch, unchanged.

## Files

* `rejcount.R` — the census, both forcings (writes `rejcount.rds`)
* `rejcount_long.R` — the same at a settable `max_patch_lifetime`, one forcing
  per process
* `sweep_rej.R` — the plant fast sweep
