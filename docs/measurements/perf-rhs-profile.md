# TF24 SCM rate evaluation: cost, dead members, and the multirate and implicit record

## Configuration

| | |
|---|---|
| Model | TF24 SCM, one species, `lma = 0.32`, `max_patch_lifetime = 40`, `node_density_in_birth_date = TRUE`, `establishment_window = 0.05` yr (one state `E` after the species' nodes) |
| Forcing | `long-drought`, aligned: a zero-depth rainfall pulse at each of the 2931 active knots |
| Tolerance | `ode_tol_rel = ode_tol_abs = 1e-3` |
| Nodes | uniform 429 over [0, 39.63] yr, spacing 0.0926 yr |
| Stepper | Cash–Karp 5(4): six rate evaluations per attempt, five stages and the first-same-as-last evaluation at the step's end |
| Code | plant `6613dd24` at `$SP/plant-adj`, built with R's default `-g -O2`; odelia and phylloptim as installed |
| Reproduction | `J = 12.575093099` at 11 240 steps: 11 239 accepted, 1 891 rejected inaccurate, 1 150 rejected by a thrown stage; 19 514 555 leaf solves (`p2_dead.R`, `p2_dead_T40.log`) |
| Profiled cut | the same node times and stops before 5 yr (54 nodes, 410 stops) with `max_patch_lifetime = 5` (`p1_common.R`) |

`$SP` is the session scratchpad; every path below is relative to `$SP/perf/profile`.

## Key numbers

| quantity | value | where |
|---|---:|---|
| member rates, share of the cut's instructions | 90.97% | §1.1 |
| · of which the leaf solve (stomatal optimisation) | 84.90% | §1.1 |
| boundary node and `E` | 6.51% | §1.1 |
| light field build | 1.46% | §1.1 |
| soil water rates | 0.04% | §1.1 |
| solver arithmetic and controller | 0.25% | §1.1 |
| R during the run / R setup outside it | 0.0005% / 0.10 s CPU | §1.1, §1.6 |
| member loop share at the operating configuration's 216 members (derived) | ≈98.8% | §1.1 |
| instructions per member evaluation: cut / states at 10, 20, 30, 40 yr | 112 k / 47 k, 109 k, 107 k, 107 k | §1.2 |
| CPU per member evaluation, cut, quiet machine | 20.2 µs | §1.2 |
| second rate evaluation at every leg start | 3.50% of the cut; 3.76% of the full run's member evaluations | §1.4 |
| member evaluations in rejected attempts, full run | 17.0% | §1.4 |
| accepted-step member evaluations below 1e-12 of the peak density | 0 of 14 595 030 | §2 |
| … below 1e-6 / below 1e-3 | 3.89% / 41.04% | §2 |
| deepest any member falls | 10^−8.39 of the peak | §2 |
| MRI as built on the branch | ≈10 micro-steps per macro step, each a member sweep; 6–25× slower than RKCK | §3 |
| `mri_uptake` member sweeps against RKCK's rate evaluations | 40× fewer (constant rain); 3.8× at 3.5e-3 `J` error; 1.0× at ≤ 4e-4 | §3 |
| IMEX on the branch | 20–50× slower than RKCK | §3 |
| tangent member evaluation (one `∂a/∂u` direction) against double | 1.96× | §4.4 |
| RODAS at the operating configuration | 3443 tangent rate evaluations and a dense 3443² LU per step; unreachable from the SCM; no adjoint | §4.1 |

## 1. What a rate evaluation costs

### 1.1 Where the instructions go

The 5-year cut under callgrind (valgrind 3.22, instruction counts only), with
instrumentation on for `scm$run()` alone (`p1_cg.sh`, `p1_cg.R`), parsed per
function symbol with inlined code folded into its caller (`cg_parse.py`) and
grouped by call edge (`cg_categories.py` → `cgT5.categories.txt`). `SCM::run()`
holds 42.78 G instructions. Valgrind's floating point moves the cut's trajectory
slightly: 1 977 attempts and `J = 1.79988e-14`, against 1 979 and `1.79971e-14`
natively.

| part | calls | instructions | share of the run |
|---|---:|---:|---:|
| member rates (`TF24_Strategy::compute_rates` and `Node::compute_node_rates` from the member loop) | 346 680 | 38.92 G | 90.97% |
| · the leaf solve inside them (`solve_leaf` → `find_root_collar_psi_for`) | | 36.32 G | 84.90% |
| · crown-mean light quadrature | | 0.96 G | 2.25% |
| · `Leaf::set_physiology` | | 0.41 G | 0.97% |
| · root network from carbon | | 0.17 G | 0.40% |
| uptake sums `a_ℓ` over members (`Species::consumption_rate`) | 62 790 | 0.17 G | 0.41% |
| boundary node and `E` (`Species::compute_boundary_node`: one newborn leaf solve in the field build, one in the rates) | 24 783 | 2.79 G | 6.51% |
| light field, both passes | 12 225 | 0.62 G | 1.46% |
| soil water rates (`TF24_Environment::compute_rates`) | 12 558 | 0.017 G | 0.04% |
| soil potentials `ψ(θ)`, computed on the first of each state's reads (inside the member rates above) | 371 463 reads | 0.021 G | 0.05% |
| state scatter and rate gather | | 0.115 G | 0.27% |
| solver arithmetic and controller (`Step::step` without its rate evaluations, `SolverInternal::step`, `adjust_step_size`) | 11 693 rate evaluations | 0.108 G | 0.25% |
| R (`libR.so`) during the run | | 194 k | 0.0005% |

Of the rows above, the 464 leg starts (54 introductions, 410 stops) take 7.18%:
3.68% is the introduction's field build and rate evaluation, and 3.50% is a
second rate evaluation of the same state (§1.4). By object, `plant.so` executes
86.68% of the instructions itself, libm 8.84% (`pow`, `exp`, `log`), libc 3.35%
(heap), libstdc++ 0.47%.

The cut's members are young (54 at most). An evaluation with `M` members costs
about `112 k × M + 300 k` instructions at the cut's states: the
member-independent part is the two newborn leaf solves (228 k), the light field
(51 k), and state handling, solver and soil rates (20 k). At the operating
configuration's mean of 216 members per accepted step this puts the member loop
at about 98.8% of an evaluation (derived, not measured).

### 1.2 One member evaluation

| measure | value | source |
|---|---:|---|
| instructions per member evaluation, cut | 112 271 (104 640 in the leaf solve) | `cgT5.categories.txt` |
| CPU per member evaluation, cut, quiet machine | 20.2 µs apportioned by instructions; 22.2 µs of run per member evaluation | `p1_time_T5.log` |
| instructions per member evaluation at a recorded state, t = 10 / 20 / 30 / 40 yr | 47.0 k / 108.9 k / 107.3 k / 106.7 k (108 / 216 / 324 / 429 members) | `cg_member_t{10,20,30,40}/` |
| CPU per member evaluation, full run, all-in, load average 8–10 | 16.5 µs (16.3 µs per leaf solve) | `p2_post.log` |

The cut took 7.608, 7.691 and 7.790 s of user CPU in three repetitions at load
average 0.30–0.54, with no other job running: 5.56 G instructions per second.
The per-state counts are one evaluation of every member at the state
`p2b_density.R` recorded, the patch rebuilt from it (`p3_member_cg.R`,
`p3_cg.sh`), with collection on inside `TF24_Strategy::compute_rates` only. The
full run's CPU time was taken while other jobs held all four cores, so it
carries contention. Its leaf solves end differently from the cut's: 85.07%
interior and 14.77% at the dry bound (`boundary-crit`, which returns after the
endpoint evaluations without the interior root-find), against 92.71% and 6.91%
on the cut (`p2_dead_T40.log`, `p1_kinds.log`). Over 0.01 yr resumed from each
recorded state, the solves end in the interior 53.8%, 100%, 97.6% and 100% of
the time at 10, 20, 30 and 40 yr, and at the dry bound 46.0%, 0, 1.1% and 0
(`p3_kinds.R` → `p3_kinds.log`, `p3_kinds_t40.log`).

### 1.3 Inside the leaf solve

From `cg_leaf.py` → `cgT5.leaf.txt`, averages over the cut's 371 463 solves
(104 640 instructions each):

| part | per solve |
|---|---:|
| TOMS748 root-find on the collar marginal (`maximise_profit_over_collar`) | 81.5% of the solve |
| feasible bracket (`prepare_collar_solve`: two `find_root_psi` root-finds) | 12.4% |
| `marginal_cost_water_multilayer`, `set_leaf_states_rates_from_psi_stem`, `find_psi_stem_from_psi_root` at the optimum | 5.7% |
| collar-marginal evaluations (`dprofit_at_collar_psi`) | 11.06 |
| `ci` root-finds (`psi_stem_to_ci`), each 6.3 TOMS748 iterations | 12.04 |
| stem-potential root-finds (`find_psi_stem_from_psi_root`) | 12.06 |
| multi-layer supply evaluations (`MultiLayerRoots::uptake_impl`) | 50.6 |
| Hermite-table lookups (`hermite_interpolator::span_of`) | 131 |

The solve is nested root-finding: every marginal evaluation of the outer
TOMS748 runs its own `ci` and stem-potential root-finds. `uptake_impl` is the
largest single cost in the run: 28.2% of all instructions executed in it, 32.25%
inclusive. Heap allocation and release execute 3.54% of the run.

### 1.4 A leg start evaluates the rates twice

`SCM::run_next` (`scm.h:659–660`) calls `introduce_nodes`
(`patch.h:1202`), which builds the field and computes the rates, then
`solver.set_state_from_system()` (`ode_solver_internal.hpp:296`), which calls
`Patch::ode_rates` (`patch.h:1506`), and that calls `compute_rates()` again on
the unchanged state. On the cut the second evaluation is 3.50% of the run. In
the operating configuration (`p2_post.R` → `p2_post.log`) the 3358 distinct leg
times carry 1 455 794 member evaluations (7.53% of the run's 19.34 M), half of
them, 727 897 (3.76%), in the second evaluation.

Where the run's member evaluations fall, placed from the census and the record
(the boundary node's two solves per rate evaluation subtracted from the leaf
solves):

| where | member evaluations | share |
|---|---:|---:|
| accepted steps, six per step | 14 595 030 | 75.47% |
| leg starts, two per leg | 1 455 794 | 7.53% |
| rejected attempts (the rest; about 180 members each) | 3 288 185 | 17.00% |
| all | 19 339 009 | |

### 1.5 Dead members: where the code would skip them, and whether it does

`Node::compute_rates` (`node.h:221`) calls `Individual::compute_rates`, and so
`TF24_Strategy::compute_rates` and the leaf solve, for every member
unconditionally. The only density test on the path is the guard on the
log-density rate (`node.h:212`: zero unless the density is positive and the log
density finite), which on the birth-date coordinate skips only a read of the
mortality rate. `Species::compute_rates` (`species.h:759`) visits every node; the
field (`field_splits`, `species.h:545`) and the uptake sum (`consumption_rate`,
`species.h:886`) multiply each member's contribution by its density and keep
zero-density members, for the reason `species.h:706` gives for the competition
grid. Members are never removed. The one density-based skip in the package is
`StochasticSpecies`' alive iterator (`stochastic_species.h:112`), which the SCM
does not use. `TF24_Strategy::compute_rates` reads the member's own state and the
environment and never its density, so a member at log density −700 costs what a
member of the same size, storage and soil costs.

At the 40-yr state, one evaluation of each of the 429 members costs 86.6–161.7 k
instructions, median 105.4 k (`p3e_cg.sh` → `member_each_t40_members.tsv`;
`p3_summary.R` → `p3_summary.log`). By the member's density relative to the
peak:

| density relative to the peak | members | mean instructions | median |
|---|---:|---:|---:|
| below 1e-6 | 74 | 108 057 | 105 607 |
| 1e-6 to 1e-3 | 209 | 101 499 | 104 698 |
| 1e-3 to 1e-1 | 108 | 110 194 | 112 677 |
| above 1e-1 | 38 | 122 166 | 120 606 |

The Spearman correlation of a member's count with its log density is 0.22 (with
its height, −0.22): the sparsest members cost what the rest do.

### 1.6 R outside the run

Building one fixture in R — parameters, the rainfall record and its
environment, the 2931 stop events, the `SCM` constructor — takes 0.103 s of CPU
(median of five; the parts' medians are 0.009, 0.024, 0.023 and 0.039 s;
`p5_setup.R` → `p5_setup.log`), against the full run's 318.7 s.

## 2. Dead members' share

In the operating configuration no member evaluation goes to a member whose
density is below 1e-12 of the stand's living density: zero of the 14 595 030
accepted-step member evaluations, whether the reference is the peak member
density or the summed density, in every birth-date band and every 5-year window
of evaluation time, and no member ever has a density of exactly zero
(`p2_dead.R` → `p2_dead_T40.log`, `p2_dead_bands_T40.tsv`, `p2_dead_time_T40.tsv`).
The state layout the classification reads was checked against the species'
own accessor (`p2b_density.R`: difference 0).

How deep members do fall (`p2b_density.R` → `p2b_density_T40.log`), as the
share of accepted-step member evaluations below a fraction of the peak member
density at that step:

| below | member evaluations | share |
|---|---:|---:|
| 1e-3 | 5 990 130 | 41.04% |
| 1e-6 | 567 300 | 3.89% |
| 1e-9 | 0 | 0 |
| 1e-12 | 0 | 0 |

The deepest any member falls is 10^−8.39 of the peak (the member born at
7.78 yr); 1% of members fall below 10^−7.01 at some step, and the median member's
lowest is 10^−3.65.

By birth-date band (`p2_bands.R` → `p2_bands_T40.tsv`): accepted-step member
evaluations, and the lowest density, as log10 of the peak, that any member of
the band reaches, and that the band's median member reaches.

| birth band (yr) | nodes | member evaluations | share | below 1e-12 | lowest | median member's lowest |
|---|---:|---:|---:|---:|---:|---:|
| [0, 1) | 11 | 727 608 | 4.99% | 0 | −6.09 | −5.98 |
| [1, 2) | 11 | 710 604 | 4.87% | 0 | −6.30 | −6.21 |
| [2, 3) | 11 | 690 312 | 4.73% | 0 | −6.52 | −6.42 |
| [3, 5) | 21 | 1 260 708 | 8.64% | 0 | −7.61 | −6.52 |
| [5, 10) | 54 | 2 902 386 | 19.89% | 0 | −8.39 | −5.65 |
| [10, 15) | 54 | 2 500 494 | 17.13% | 0 | −6.99 | −4.88 |
| [15, 20) | 54 | 2 048 262 | 14.03% | 0 | −5.47 | −4.26 |
| [20, 25) | 54 | 1 628 676 | 11.16% | 0 | −4.85 | −3.42 |
| [25, 30) | 54 | 1 140 390 | 7.81% | 0 | −4.04 | −2.58 |
| [30, 35) | 54 | 723 618 | 4.96% | 0 | −3.18 | −1.60 |
| [35, 40] | 51 | 261 972 | 1.80% | 0 | −2.67 | −0.66 |

By when the evaluation happens (`p2_windows_T40.tsv`), the share of member
evaluations below 1e-6 of the peak is 0 before 20 yr, then 0.02%, 0.47%, 1.33%
and 13.18% in the four 5-year windows to 40 yr; below 1e-3 it climbs from 0 in
[0, 5) to 63.6% in [35, 40].

Log densities near −745 are the instantaneous gate's: `Node::seat_at_birth`
(`node.h:270–310`) seats a newborn at log density −750
(`establishment_failure_hazard`, `internals.h:41`) when its establishment
probability is exactly zero. Under the averaged gate the establishment
probability a newborn is seated at is `E`, which relaxes toward the
instantaneous gate with time constant 0.05 yr and so stays positive; with the
gate shut, `E` falls as `e^{−20t}` and reaches 1e-12 of its open value only after
1.38 yr shut. The −750 cohorts of aornugent/plant#88 were measured on
`ad/reverse-mode`, which has no establishment window.

## 3. What was tried: the multirate and forward-speed branches

Sources: the plant branches and their odelia engines, and the notes for them,
which sit on the plant-dev branch of the same name (93 markdown files; neither
plant branch has notes under `docs/` or `inst/`). Copies are in `branchdocs/`,
commit logs, diffstats and the key files in `branchlogs/`
(`extract_branchdocs.sh`). In `/home/user/plant-dev/docs` the search terms occur
in the current consultation, its response and the handover, and otherwise only
as the name of odelia's `test-implicit-value.R` or the implicit-function
derivative in four measurement notes; in the plant tree only in
`notes/plan-tf24-soil-redistribution.md` (an implicit stepper "worth
revisiting for speed (the diagonal is ≈1.5e4 yr⁻¹ regardless)") and `NEWS.md`
(RODAS named as the remedy for stiff environment state). Every number in §3.2
comes from these records: July 2026 code and the branches' own fixtures
(`lma = 0.0825` in the `mri_uptake` gate, lifetimes 3–40 yr, tolerances 1e-4 to
1e-6), not the operating configuration.

### 3.1 What each branch holds

- **plant `claude/tf24-multi-rate-stepper-n5audm`** (12 commits past `141dc8df`,
  2026-07-18 to 20, head `9c8bd2d6`). The patch as a multirate system, laid out
  `[members | soil]` = `[slow | fast]` with `slow_size`, `fast_size`,
  `freeze_slow`, `slow_rates`, `fast_rates` for odelia's `method = "mri"`
  (`b536fc4d`); the fast block's uptake collocated over `m ≪ M` members
  (`cddd41f9`, `3a06ac3b`, `a3de7802`); an exact-drainage split of the soil
  (`analytic_partial_flow`, `residual_rhs`, `infiltration_rate`,
  `drainage_touchdown_time`, `c1b455f8`) and the split inner that uses it
  (`d4e5858a`); counters of fast-block and full rate evaluations (`ea30658e`,
  `71a681cc`); a shut-down leaf that draws no water (`a3957ca9`); a log-depletion
  soil chart, added and reverted (`fc0dd2bb`, `9c8bd2d6`); `ode_method = "imex"`
  (`64e1e729`).
- **odelia `claude/tf24-multirate-engine`** (`b88514d`). An MRI-GARK macro step:
  explicit RK on the slow block, the fast block sub-cycled by the adaptive solver
  over each leg, record-and-replay reverse mode, an exact-flow + ROS34PW2 split
  inner, and IMEX as `RodasStep` driven by a `BlockFdJacobian`.
- **plant `claude/tf24-forward-speed-n5audm`** (13 further commits, 2026-07-20 to
  26, head `5151f2a2`). Forcing-kink step clipping (`89b1ccb9`); event-classifier
  and error-norm diagnostics (`05df4c1f`, `97290ca6`, `202c4adf`); a slimmer
  replay cache (`b2f70dfa`); waveform-relaxation probes (`0015c9fd`); a TOMS748
  root-find on the analytic collar gradient in place of golden section
  (`5a48347b`); an analytic per-leaf `∂uptake/∂ψ_soil` (`bcb9ed9f`) and the stand's
  `∂a/∂u` as a gated by-product of the member loop (`99064255`);
  `ode_method = "mri_uptake"` (`c4845c4d`); an anchor fusion built, measured and
  reverted (`253c0c03`, `773bf057`, `5151f2a2`).
- **odelia `claude/tf24-forward-speed-engine`** (`8de3907`). Step and error-norm
  logs, the forcing-kink clip, a step monitor, `subcycle_uptake` (the fast block
  against a frozen affine coupling with a trust monitor), `Method::mri_uptake`,
  and a third-order (kutta3) slow advance.

### 3.2 What was measured

| attempt | measured | source |
|---|---|---|
| MRI, full-`M` coupling | ~58 fast-block evaluations per daily macro step (~9.7 micro-steps) on a 3-yr run; each fast evaluation re-runs the member loop; ≈13× the member solves of global RKCK; 110–725 cost units against 15–120 for global RKCK at converged `J` (6–25×), `J` error 0.7–23% | `ea30658e`; `branchlogs/multi-rate-stepper_patch.h:154–178`; `docs_oracle-consultation-multirate-verdict.md` |
| exact-drainage split inner (Lever 1) | 103 against 58 fast evaluations per macro step, ~0.6× the speed; slower than the adaptive inner at every macro step tried (1–60 forcing periods) | `d4e5858a`; verdict doc |
| collocation over `m ≪ M` members | ~3× cheaper; on evolved stands `m = 20` gives 38% soil error (life 8, 91 members) and 14% `J` error at `M = 352`; `m = 40` gives 2.4% at 2× the global cost | `a3de7802`; verdict doc |
| coupling held over a leg, or linearised or tabulated per macro step | held: error plateau 0.1–0.12 at any refresh rate; linearised per macro step: 440% uptake error for a top-layer drying, 370% for a graded one; separable per-layer tabulation: absolute error 0.06–0.76 | `docs_oracle-consultation-fundamentals.md` §7; `docs_tf24-multirate-factoring-probe.md` |
| IMEX (RODAS4, Jacobian of the 9-state soil block differenced through the full rate evaluation) | `J` error 3.6e-2 at tol 1e-4, 1.7e-3 at 1e-5, and 20–50× slower than global RKCK, 21.7× → 52.2× from tol 1e-4 to 1e-5, read as order reduction from a Jacobian differenced through the bracketing search | fundamentals doc §6h |
| global RODAS | not runnable on the patch then (no rebind hook). Soil-only surrogate: 1.5× the steps and ~5× the time of RKCK across a 3000× stiffness sweep; 5 + `M` surrogate: ~470× slower at `N = 205` | `docs_tf24-rodas-multirate.md` |
| TOMS748 on the collar gradient instead of golden section | 1.20× on a whole solve (111.0 → 92.3 s); this is the collar solve 6613dd24 runs | `5a48347b`; `docs_tf24-v2-T6-slice1-newton-collar-result.md` |
| `mri_uptake` (fast block against `a₀ + G(u − u₀)`, `G = ∂a/∂u` analytic) | constant rainfall: 3308 member sweeps against 132 320 cheap residual evaluations (40×), `J` error 2.42e-3. Seasonal forcing (amp 0.3), against RKCK's 16 581 rate evaluations: 14-d legs 2278 sweeps (7.3×) at 8.4e-2; 7-d 4358 (3.8×) at 3.5e-3; 3.5-d 8518 (1.9×) at 2.7e-3; 1.75-d 16 868 (1.0×) at ≤ 4e-4. Stress bank: 3.1–9.9× fewer sweeps, 1.0–3.2× wall clock. Four member sweeps per leg | `docs_tf24-v2-T6-tolerance-correction-and-remeasurement.md`; `docs_tf24-v2-T6-slice4-scenario-bank-result.md` |
| anchor fusion (four sweeps per leg to two) | 124 → 81 s (1.53×) but `J` moved 1.5e-2: the two sweeps at the same nominal state differ by up to 2.45e-2, unexplained on the branch | `docs_tf24-v2-T6-P1-setup-caching-and-anchor-fusion-result.md` |
| leaf setup share | `set_physiology` 37–47% of a member sweep under the golden-section solve; 1.0% of the run in 6613dd24 (§1.1) | P1 doc |

### 3.3 Why the multirate stepper did not cut cost

The fast block's rate is a function of the member loop. As wired, every fast
evaluation calls `fast_block_uptake` → `compute_species_rates`, a sweep over every
member's leaf solve (`branchlogs/multi-rate-stepper_patch.h:154–178`), and the
member loop is 91% of a rate evaluation on the cut here (§1.1), 95–100% on the
branch's fixtures. The micro-step count was accuracy-set, about ten per macro
step, and removing the stiff drainage exactly did not lower it. So the
decomposition paid a member sweep per micro-step and multiplied sweeps about
13-fold. The two routes to a cheaper micro-step both failed on accuracy: fewer
members (the evolved member set is not quadrature-friendly), and a frozen,
linearised or tabulated `a(u)` (`a` is a non-separable function of the whole
profile, and holding it drops the `∂a/∂u` restoring feedback). Taking the member
loop out of the micro-steps with an exact affine model worked, but the sweeps
then scale with legs × stages, and at the leg that matches RKCK's accuracy
(1.75 d) the sweep count equals RKCK's rate-evaluation count.

### 3.4 The claim

"Multirate collapses into a linearly-implicit treatment of the chain: the
expensive coupling term is a function of the fast variable, so every micro-step
re-evaluates the member loop. An additive split that keeps the member loop
explicit and evaluated once per stage is a different proposition."

- The first sentence holds for the MRI as built: by the code (the fast rate calls
  the member loop) and by measurement (≈10 micro-steps per macro step, ≈13× the
  member solves, 6–25× the cost). The variant that removed the member loop from
  the micro-steps did it by linearising `a` in `u` with the exact coupling
  Jacobian — the object a linearly-implicit treatment of the chain needs — and
  its saving was gone at matched accuracy.
- The second sentence describes something the record does not contain. The IMEX
  that was built evaluates the member loop 19 times per step (1 at the step's
  start, because a Rosenbrock step's end rates are not carried over; 1 + 9 for
  the differenced soil-block Jacobian, whose 9 columns on the branch include the
  4 flux accumulators; 2 for `∂f/∂t`; 5 stages; 1 at the end) and factors a dense
  `N × N` matrix (`branchlogs/odelia-b88514d_ode_jacobian.hpp`, `RodasStep`'s
  dense `lu_decompose`), with the Jacobian differenced through the leaf solve.
  `mri_uptake` keeps the member loop explicit per slow stage, but on fixed legs
  with a frozen-coupling sub-cycle, not as an error-controlled additive step.
- The branch record's premise that the step is accuracy-limited (`h|λ| ~ 1e-3`,
  "100% of steps accuracy-limited") was measured soil-only on a surrogate and on
  the branch's fixtures, run without stops at the forcing's knots. The current
  consultation records the aligned run at a median `h|λ|` of 1.86 against
  Cash–Karp's real stability boundary of 3.73
  (`/home/user/plant-dev/docs/handover.md`).

## 4. What exists for implicit integration

### 4.1 `ode_step_rodas.hpp`

RODAS4(3): six stages, L-stable, stiffly accurate, order 4 with an embedded
order 3 (Hairer–Wanner `rodas.f`, METH = 1). Every stage is one solve with
`W = I/(hγ) − J`, and stages 2–6 one rate evaluation each; `W` is factored once
per step by a dense LU (`ode_linalg.hpp`, `O(N³)`). `J` comes from forward-mode
AD (`ode_jacobian.hpp`):
the system rebound to the tangent scalar through `rebind_from`, one tangent rate
evaluation per state column, so `N` of them per step; `∂f/∂t` is a one-sided
difference (two rate evaluations); the end-of-step rates feed the controller
but are not carried into the next step (`first_same_as_last = false`), which
starts with its own evaluation. A step is therefore nine rate evaluations (five
stages, the end, the next start, two for `∂f/∂t`), `N` tangent ones and one
dense factorisation. It is selected by `odelia::ode::Method::rodas`
(`ode_solver_internal.hpp:24`).

- **Reach.** `Patch<TF24>` is rebindable to the tangent scalar, and
  `odelia::ode::Jacobian<plant::Patch<TF24…>>::compute` is compiled into
  `plant.so` (`nm`). But `SCM` builds its solver without a method
  (`scm.h:548`) and `Control` has no method key, so the SCM cannot select it. In
  odelia it is reachable only from the Lorenz example (`lorenz_interface.cpp`,
  `tests/testthat/test-rodas.R`).
- **At the operating configuration** `N = 8M + 1 + 10`, 3443 at `M = 429`: 3443
  tangent rate evaluations and a dense 3443 × 3443 factorisation per step.
- **Adjoint.** None. `SolverInternal::step_adjoint` refuses ("method='rodas' has
  no adjoint", `ode_solver_internal.hpp:81`); a forward replay refuses ("cannot
  replay what a run solved for", `:186`) because RODAS keeps no per-stage record
  of the leaf operating points; `Jacobian<System>::supported` is false at an
  active scalar (a tangent over an adjoint is not wired, and `tangent.hpp`'s
  `tangent_over` static-asserts against it). An adjoint through it would need
  the transposed stage recurrence (`Wᵀ` solves on the step's LU factors); the
  derivative of `J` along the stage vectors, `λᵀ(∂J/∂y)kᵢ` and `λᵀ(∂J/∂θ)kᵢ`,
  which are second derivatives of the rates through the member loop; the
  `∂f/∂t` term; and a per-stage record of the leaf operating points for replay,
  which the recording's shape (`std::array<…, 6>`, `ode_step.hpp:30`) does not
  hold for a Rosenbrock step.

### 4.2 `implicit_node.hpp`

Not an integrator. It puts values solved in double onto the tape with
implicit-function-theorem rows: `implicit_value` (`dy*/dp = −(∂F/∂p)/(∂F/∂y)`,
with or without the residual's own statements left on the caller's tape),
`record_with_derivatives` (a value with supplied rows, one statement), and
`preaccumulate` (a region replaced by its output rows). phylloptim's leaf uses
it for the collar operating point (`collar_at`: interior through
`implicit_value` on the marginal, whose curvature `marginal_collar_slope` is a
difference of the analytic marginal costing two model evaluations; pinned kinds
through their bound's residual, `bound_at`); TF24 uses it for the seed height
and attaches the leaf outputs' rows in `record_leaf_outputs`
(`tf24_strategy.h:1557`). It runs on every tangent or adjoint pass and never at
double.

### 4.3 The soil chain's Jacobian

From `TF24_Environment::compute_rates` (`tf24_environment.h:556–650`), for layers
`ℓ = 1…5` of thickness `dz = 0.3` m:

`u̇_ℓ = (in_ℓ − K(u_ℓ) − a_ℓ)/dz`, `K(u) = K_sat (clamp(u, 0, θ_sat)/θ_sat)^{2n_ψ+3}`,

with `K_sat = 163.04` m yr⁻¹, `θ_sat = 0.428`, `2n_ψ + 3 = 16.14`,
`in_1 = rain(t)·max(0, 1 − a_infil (u_1/θ_sat)^{b_infil})` (`a_infil = 1`,
`b_infil = 8`), and `in_ℓ = K(u_{ℓ−1})` below. A layer at or below
`θ_res = 0.01` has its rate set to zero unless it is positive (`:631`). With `a`
held, `∂u̇/∂u` is lower bidiagonal: diagonal `−K′(u_ℓ)/dz` (layer 1 also
`−rain·a_infil·b_infil·u_1^{b_infil−1}/θ_sat^{b_infil}/dz` while the excess is
positive), subdiagonal `+K′(u_{ℓ−1})/dz`, with
`K′(u) = K_sat (2n_ψ+3)/θ_sat · (u/θ_sat)^{2n_ψ+2}`. `K′/dz` is 2.05e4 yr⁻¹ at
saturation (`plant/notes/plan-tf24-soil-redistribution.md` measures 1.77e4 at
0.99 `θ_sat`) and falls as `u^15.1`. All of it is closed-form power laws; nothing in
6613dd24 forms it. The environment's five further states (rainfall,
infiltration, deep drainage, `Σ a_ℓ`, pulse runoff) take rates from `u` and `a`
and feed nothing back.

### 4.4 How `a_ℓ` depends on `u` through each member

`a_ℓ = Σ_j w_j n_j c_{j,ℓ} / area`: `Species::consumption_rate` (`species.h:886`)
integrates each node's uptake times its density by the trapezium over birth
date, closed by the newborn; `c_{j,ℓ}` is the leaf's `soil_consumption_` for layer
`ℓ` scaled to the member's canopy (`tf24_strategy.h:1962`). `u` reaches a member
only through `ψ_k = a_ψ (max(u_k, θ_res)/θ_sat)^{−n_ψ}/10⁶`, capped at
`soil_psi_max_` (`tf24_environment.h:683`) and computed once per state (`:749`).
All five `ψ_k` enter the member's multi-layer supply and its collar operating
point `ψ*`, the optimum of §1.3. So, per member,

`∂c_ℓ/∂u_k = [∂c_ℓ/∂ψ* · ∂ψ*/∂ψ_k + δ_ℓk ∂c_ℓ/∂ψ_ℓ] · dψ_k/du_k`,

a rank-one term through `ψ*` plus a diagonal: a dense 5 × 5, summed over members
with their weights. At a pinned optimum `ψ*` follows the active bound, itself a
function of `ψ`.

- **Analytic or not.** At double the leaf returns values only. At a tangent or
  adjoint scalar every output carries rows (§4.2), so `∂a/∂u` is available as a
  forward tangent through the member loop, one tangent rate evaluation per
  direction and five for the layers, and is formed nowhere at double. The
  forward-speed branch's `compute_duptake_dpsi_soil` (`bcb9ed9f`) and its
  member-loop fill of the stand Jacobian (`99064255`) are not in 6613dd24.
- **Cost.** One member's rate evaluation at the tangent scalar costs 228 847
  instructions against 116 743 at double, 1.96×, on the 2-yr cut
  (`p4_tangent_cg.R`, `p4_cg.sh`, `cg_tangent.py` → `tanT2.tangent.txt`: the
  trajectory tangent in the `lma` direction, whose rows pass through the same
  leaf outputs a soil direction's would). Of it, 110 525 is the leaf solve at
  double, 103 767 the rows (`record_leaf_outputs`, including the curvature's two
  model evaluations), and about 14.5 k the tangent arithmetic of the rest. The
  five layer directions as five tangent passes cost about 9.8 double member
  sweeps; no multi-direction tangent is instantiated.

### 4.5 What a soil-implicit split with the member loop explicit would need here

- **The partition exists in the state.** `Patch::ode_state` (`patch.h:1481`)
  writes each species' nodes and then `E` (`species.h:189`), then the
  environment's ten states; the soil is the contiguous tail, the layout the MRI
  branch used.
- **The soil rates given `a` are a separate, cheap function.**
  `TF24_Environment::compute_rates(resource_depletion)` takes `a` as its
  argument (1.4 k instructions a call on the cut), after `Patch::compute_rates`
  has run the member loop and formed `a` (`patch.h:1168–1196`); setting the soil
  state alone is a copy that invalidates the `ψ` cache
  (`tf24_environment.h:194–201`). An implicit soil stage with `a` held needs no
  member evaluation, and its Newton or linearly-implicit iteration needs only the
  bidiagonal of §4.3. Carrying `∂a/∂u` into the implicit part needs the five
  tangent directions of §4.4 per Jacobian.
- **odelia has no such stepper.** `Step` is Cash–Karp only (`ode_step.hpp`);
  `Method` is `{rkck, rodas}`; the per-step record of solved values is sized to
  six evaluations (`ode_step.hpp:30`); the adjoint exists only as
  `Step::step_adjoint`, which records the six evaluations and the tableau on one
  tape and sweeps it (`ode_step.hpp:253–298`). An implicit stage would need its
  solve on that tape, as recorded arithmetic of a 5 × 5 solve or as rows through
  `record_with_derivatives` / `implicit_value`.
- **plant has no method switch.** `Control` carries no method key and `SCM`
  constructs `Solver<Patch>` with the default (`scm.h:548`); the chain Jacobian
  is not written.
- **The soil rate is non-smooth** at the positivity guard (`θ_res`), the
  conductivity clamp (0 and `θ_sat`), the `ψ` floor and cap, and the
  infiltration `max(0, ·)`.
- **Pulses are state jumps at leg starts** (`Patch::apply_event`); the operating
  configuration has 3358 distinct leg times (429 introductions and 2931 stops,
  two of them coincident), each restarting the step sequence, so the method must
  be single-step.

## What was not reached

- A whole-run callgrind profile. The shares in §1.1 are from the 5-year cut,
  whose members are young and whose solves end in the interior more often than
  the full run's; the full run's per-member cost is known only at four recorded
  states (one evaluation of each member) and from CPU time taken under load.
- A quiet-machine CPU time for the full run: other jobs held the load average
  at 8–10 throughout it.
- The dead share of rejected attempts. They hold 17.0% of member evaluations and
  the record does not locate them; §2 counts accepted steps (and leg starts give
  the same zero).
- Per-member cost by operating-point kind: the kind is tallied per strategy, not
  per member.
- The tangent's cost at the operating configuration's states: measured on the
  2-year cut only. The per-member readout covers the 40-yr state only; the 10-,
  20- and 30-yr states have means.
- No implicit, IMEX or multirate stepper was built or run on 6613dd24; §3 is the
  branch record, on July 2026 code and the branches' own fixtures.
- Whether the operating configuration's step is limited by the chain's
  stability rather than by accuracy.
- The forward-speed branch's unexplained 2.45e-2 disagreement between two member
  sweeps at the same nominal state.
- `∂a/∂u` was not formed; its structure in §4.4 is read from the code.

## Scripts and outputs

All R scripts load plant through the harness (`tg/tg2_common.R`, `$SP/plant-adj`)
with `LD_NCORE=1`.

| script | what | output |
|---|---|---|
| `p1_common.R` | the cut: node times and stops before `T`, `max_patch_lifetime = T` | |
| `p1_time.R` | native CPU time of the cut, three repetitions, with counts | `p1_time_T5.log` |
| `p1_cg.R`, `p1_cg.sh` | the cut under callgrind, instrumentation on for `scm$run()` only | `cg_cgT5.out.2562.1`, `cgT5.log` |
| `cg_parse.py` | per-symbol self, inclusive and call-edge costs | `cgT5.{self,incl,edges}.tsv` |
| `cg_categories.py` | the shares of §1.1 and the per-member count | `cgT5.categories.txt` |
| `cg_leaf.py` | inside the leaf solve (§1.3) | `cgT5.leaf.txt` |
| `p1_kinds.R` | how the cut's leaf solves end | `p1_kinds.log` |
| `p2_dead.R` | the operating configuration, recorded: reproduction, dead census at 1e-12 | `p2_dead_T40.log`, `p2_dead_{bands,nodes,time}_T40.tsv`, `p2_dead_T40.rds` |
| `p2_post.R` | where the member evaluations fall; CPU per leaf solve | `p2_post.log` |
| `p2b_density.R` | depth below the peak density, layout check, state exports | `p2b_density_T40.log`, `p2b_density_T5.log`, `p2b_density_T40.rds`, `p2_state_t{10,20,30,40}.rds` |
| `p2_bands.R` | the band and window tables of §2 | `p2_bands.log`, `p2_bands_T40.tsv`, `p2_windows_T40.tsv` |
| `p3_member_cg.R`, `p3_cg.sh` | one evaluation of every member at a recorded state, collected inside `TF24_Strategy::compute_rates` | `cg_member_t{10,20,30,40}/`, `member_t*.log` |
| `p3e_cg.sh` | the same with a per-member readout | `member_each_t40_members.tsv`, `member_each_t40.log` |
| `p3_summary.R` | per-member counts at 40 yr against density | `p3_summary.log`, `p3_summary_t40.tsv` |
| `p3_kinds.R` | how the leaf solves end over 0.01 yr resumed from each recorded state | `p3_kinds.log`, `p3_kinds_t40.log` |
| `p4_tangent_cg.R`, `p4_cg.sh`, `cg_tangent.py` | a tangent pass against the double pass, 2-yr cut | `cg_tanT2.out.12704.{1,2}`, `tanT2.log`, `tanT2.tangent.txt` |
| `p5_setup.R` | R-side setup of one fixture outside `scm$run()` | `p5_setup.log` |
| `chain.sh` | runs `p2_post`, `p3`, `p4`, `p5` in sequence | `chain.log` |
| `extract_branchdocs.sh` | the branch notes, logs, diffstats and key files | `branchdocs/`, `branchlogs/` |

The `t = 40` run of `p3_cg.sh` exits with an R parse error after `P3 DONE`
(`member_t40.log`); its collected total (`cg_member_t40/`, 45 752 791) and its
member table are complete, and `p3e_cg.sh` reproduces the same total at that
state.
