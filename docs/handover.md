# Handover

For the session that sends the performance consult. The consult (`oracle-consultation-solver-performance.md`) is the statement of the system and its measured behaviour; this is what a session needs beside it to act.

## Where it stands

- **The stability problem is settled.** TF24 establishment reads the gate averaged over `establishment_window = 0.05` yr, the default the user accepted (aornugent/plant#92). Its record is `oracle-consultation-gradient-control.md`, `oracle-response-gradient-control.md` and `measurements/diag-establishment-window.md`.
- **Next: the performance consult goes to a fresh Oracle.** The user sends it. Capture the response verbatim as `docs/oracle-response-solver-performance.md`.
- **The user's questions**, which the consult's four question groups carry:
  - replace `refine_schedule`, which was built for FF16 and the height coordinate, with something fast to find and lean in `Σ M`, suited to TF24, the birth-date coordinate and realistic rainfall;
  - one grid per rainfall record, fixed and shared across θ, with a trust region set by conditioning metrics;
  - controller improvements, and whether implicit or multirate integration helps;
  - whether the adjoint can drive convergence, or costs more than it saves.
- **The measurements behind the consult**, in `docs/measurements/`:
  - `perf-step-controller.md`: step anatomy, stiffness, rejections, tolerance, stops, and §7's bound;
  - `perf-rhs-profile.md`: callgrind, dead members, the multirate branch record, the implicit machinery;
  - `perf-node-schedule.md`: error and cost by birth date, `refine_schedule`, lean designs;
  - `perf-across-theta.md`: a θ0 discretisation read across three axes, and conditioning metrics;
  - `perf-adjoint.md`: cost, gradient convergence, node values, the goal-oriented estimate. `perf-adjoint-hook.patch` sits beside it.

## Code state

- **`plant-dev` records `plant` at `6613dd24`**, the head of `establishment-window`, stacked on `offspring-adjoint`: issues #91 and #92, no PRs. The main `plant/` tree is detached there, with `plant-adj`'s `-O2` build copied in (`needs_compile` FALSE).
- **Full serial sweep at `6613dd24`:** 536 tests, 2 failures, both in `test-mutant.R` and identical on the base build (stale references on the base branch).
- **The adjoint hook** (`perf-adjoint-hook.patch`, 207 lines, against `6613dd24`) adds `SCM::census_introduction_adjoints` and three R functions. It reads the adjoint at every introduction and is bit-identical on the default path. It lives in an uncommitted worktree, `$SP/perf/adjoint/plant`; apply the patch to a fresh branch to use it.
- **Builds in the scratchpad**, which survives a container restart; background jobs do not:
  - `plant-adj`: the worktree on `establishment-window`;
  - `tg/plant-base`: `bb1d8a8a`, the instantaneous gate;
  - `perf/adjoint/plant`: the hook build.

## Established — do not re-derive

| fact | numbers |
|---|---|
| Cost is member evaluations | `1.12e5` instructions and 20 µs each. The member loop is ~99% of a rate evaluation, the inner solve 85%. `u429` takes `1.934e7` |
| The step is not accuracy-limited | median error ratio 0.030; steps ∝ `tol^−0.065`. Soil binds 76% of steps and members 23%, mostly the newest member's mortality |
| Two local stiff modes | soil drainage, `2.05e4` yr⁻¹ at saturation, with 24% of accepted steps at `h|λ| ≥ 0.8β`; the newest member's storage, 150–1444 yr⁻¹. The exact Jacobian's dominant eigenvalue is the larger of the two |
| Rejections | 21.3% of attempts and 17% of member evaluations. Every throw is the storage guard at `tf24_strategy.h:1987`, on the newest member's storage (`5e-8` kg, below `atol/100`) |
| Entries | each of the 3358 evaluates the rates twice, 3.8% of member evaluations; a zero-depth knot needs neither evaluation |
| Stiff-free bound | 33–51% fewer member evaluations (the controller's walk / a filled leg); the floor, one step per leg, is 74% |
| Time error is not tolerance-controlled | `J` spreads `4e-4` over `tol` 1e-2 … 1e-4. Pure placement moves it `1.65e-4`; the schedule re-roll floor is `6e-5` sd |
| Schedule error is the stand's | 96% of uniform 215's error. `[6, 16)` fills buy 101% of the 215 → 429 change |
| `refine_schedule` on the averaged model | every flag is the competition term's, 59% of them past `b = 16`; at eps `2e-4` it takes 11 runs and 44.8 M evaluations to reach −5.6e-4 |
| Lean schedules | `cw108_220`: −5.4e-4 at 1.76 M, against uniform 380's 2.14 M; the error is not monotone in the node count |
| Across θ | a θ0 lean schedule holds over the box, and rebuilding it is worse; band edges move ≤ 0.09 yr. A pinned step program is 6–12× over tolerance 5% out. Richardson ranks schedules and does not track within one |
| The adjoint | the sweep of `J` is 2.5–2.7 forwards; the recording ~190 B per member per step. The gradient converges more slowly than `J`; adjoint and secant on `u215` part by 3.4% |
| Node values | only the 8 members born before `b = 0.65` have positive value. The `g`-defect predicts coarse errors at 0.93–1.29× with `u429`'s `g`, and at 0.04× from a coarse schedule's own members |
| Still true from the stability work | tableau blindness to events under `0.3h`; stops at the 2931 active knots are the minimal exact set; `β = 3.7343596` |

## Build gotchas that cost time

- `make` → `compile_dll` → `R CMD INSTALL` loses the outer make's jobserver and builds `-j1`. Run `env MAKEFLAGS=-j3 Rscript -e 'pkgbuild::compile_dll(compile_attributes = FALSE, debug = FALSE)'`. A header change is then ~15 minutes.
- Restarting `compile_dll` can wipe `src/*.o`.
- `pkill -f` on a pattern that appears in your own command line kills your own shell. Stop a build by walking its PID tree.
- `plant` compiles against `phylloptim`'s **installed** headers; `rm plant/src/*.o` after a `phylloptim` header change. `compile_dll` exits 0 having compiled nothing when the `.so` is newer than every source; use `force = TRUE`.
- A new TF24 parameter needs its `PLANT_TF24_AD_PARAMETER` entry, its `inst/RcppR6_classes.yml` entries and `RcppR6::RcppR6()`.
- A background wait must key on a sentinel line its own script prints: R writes `1e-04` as `0.0001` in file names. Four waits spun for hours on names that never appeared.
- Five agents on four cores ran into the account's usage limit and stopped mid-run. `SendMessage` to an agent's id resumes it from its transcript, with its background jobs still running.

## Harness

In the session scratchpad, not committed:
- `tg/tg2_common.R`, which sources `lh_common.R` and then `ld_common.R`: the fixture on `plant-adj`, with `run_J(times, lma, window, tol, stops, pin, record, gradient)`. `TG_PLANT` selects another build.
- `perf/<name>/`: each agent's scripts and outputs, with per-run `.rds`. The names are `controller`, `profile`, `schedule`, `theta` and `adjoint`.
- `perf/schedules/`: the lean schedules `cw108_{100,220,320}.rds` and a README.
- Older harnesses: `rw_*` (gate scan), `em_*` (edge mesh) and `adj_*`.

## Open, beyond the consult

- **Free wins, waiting on the user's go-ahead:**
  - the second rate evaluation at every entry, and any evaluation at a zero-depth knot (3.8%);
  - the storage's error weight, since `atol` hides it and so drives the throw cycle.
- **A pinned step program subdivides silently.** `step_to` subdivides a step whose stage leaves the domain and records nothing, so the realised grid is not the pinned one (`perf-across-theta.md` Θ5). This matters to replay and to the adjoint; no issue is filed.
- **The adjoint refuses at `tol ≥ 3e-3`.** A stage state lies past the vulnerability curve's derivative domain (`perf-step-controller.md` §5c).
- **`test-mutant.R`**'s stale references on the base branch.
