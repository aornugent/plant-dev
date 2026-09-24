# The adjoint of J on the TF24 SCM: cost, convergence in the node schedule, and a goal-oriented schedule error estimate

**Configuration.** TF24 SCM, one species, `lma = 0.32`, `max_patch_lifetime = 40`,
`node_density_in_birth_date = TRUE`; forcing `long-drought`, aligned (a zero-depth
rainfall pulse at each of the 2931 active knots); `ode_tol_rel = ode_tol_abs = 1e-3`;
`establishment_window = 0.05` yr. `J = sum(scm$offspring_production)`. "The sweep" is
the shipped reverse pass seeded on J alone, `stand_gradient(scm, metrics =
"offspring_production")`. `plant` at 6613dd24. Forward runs without a recording ran on
the -O2 worktree `plant-adj` (its `.so` read 13:14:26.561 before and after every run);
recorded runs and sweeps ran on the hook build (§3.2: same commit and flags plus an
accessor, `.so` 22:38:27.646), which reproduces plant-adj's J and gradient bit for bit.
Uniform schedules put N nodes on [0, 39.63]; "default 108" is the default schedule
(geometric from b = 0, spacing 0.25 yr at b = 2–3, 0.5 yr to b = 5, 1 yr to b = 10,
2 yr to its last node at b = 38). References: J∞ = 12.5734; fixed-grid dJ/dlma =
−172.52 ± 0.03.

**Measurement.** Seconds are CPU user seconds of the R process
(`proc.time()[["user.self"]]`), taken while 6–11 runnable processes shared 4 cores;
they carry cache contention and compare within this note. Memory is the resident set
in MiB (2^20 bytes): VmHWM from `/proc/self/status`, reset before each phase through
`/proc/self/clear_refs`, and the process's maximum RSS from `getrusage` (`rtime.py`;
`/usr/bin/time` is not installed). A member evaluation is one individual's rate
evaluation: in a forward run one leaf solve (`census_operating_point_counts_tf24`,
rejected attempts included); in a sweep six per member per accepted step (five placed
from the recording, counted by the hook's `census_sweep_counters_tf24`, and the first
stage re-solved at the step's start state, `odelia::ode::Step::step_adjoint`).
Scripts and outputs are in `$SP/perf/adjoint` (`$SP` the scratchpad); each table
names its script.

## Key numbers

| | |
|---|---|
| **Sweep of J ÷ plain forward, CPU** | **2.66 / 2.55 / 2.55 / 2.51** on uniform 108 / 215 / 429 / 857, **2.59** on the default 108 — flat in the node count, below the 3.7–5.3× expected; sweeping all four census metrics costs 1.42× more, **3.67** on the default 108, which is where 3.7× came from |
| Per member evaluation | sweep 52.8–61.7 µs, forward 15.9–17.6 µs (3.3–3.5×); the forward makes 1.32× as many per accepted step (rejected attempts) |
| Recording | free in CPU (recorded forward 0.96–0.99× plain); **184–198 bytes per live node per step**, 2.9–3.1× the 64 bytes of its state entries; 109 / 213 / 427 / 880 MiB at 108 / 215 / 429 / 857 nodes |
| Peak resident set, recorded run + sweep | 297 / 458 / 781 / 1423 MiB (forward without recording: 153–155 MiB at every size) |
| **dJ/dlma by adjoint** | −182.20 / −168.11 / −171.45 / **−172.59** on uniform 108 / 215 / 429 / 857; default 108 −158.59; against −172.52 ± 0.03 |
| Gradient against J, 108 → 857 | the gradient's error falls 142× (−9.68 → −0.07, not monotone), J's 3100× (0.703 → 0.00023); at 429 the gradient is 0.62% off, J 0.013% |
| **Node values, uniform 429** | direct shares sum to J = 12.575, competition effects to −19.18, values to **−6.60**; v_k > 0 only for the 8 nodes born before b = 0.65 yr |
| Finite-difference check of λ_k | 3 nodes (b = 1, 10, 25): 1.9e-4, 1.6e-4, 1.8e-5 relative; forward tangent 1.5e-5 |
| **First-order error = trapezium defect of g** | with uniform 429's nodal g, predicts J_h − J_429 at **0.93× (u108), 0.97× (u215), 1.29× (default 108)**; J's integrand alone predicts −0.023 for u108 against +0.701 |
| η from a grid's own nodal values | 0.04× / 0.05× / 1.38× the true error on uniform 108 / 215 / 429, 0.40× on the default 108; the f-only η 0.32× / 0.29× / 7.2× / −0.15× |
| Cost of the estimate | recorded forward + hook sweep = 3.58–3.67 plain forwards; beyond the gradient sweep an optimiser runs anyway, 1.4–35 s (0.6–4.5% of it) |

## 1. Cost and memory

Each grid is two processes: `fwd.R` (a forward run without a recording, plant-adj) and
`adj.R` (a recorded forward run, the shipped sweep of J, then the hook's sweep, hook
build; on 857 without the hook). Every recorded run reached the unrecorded run's J to
the last bit at the same step count. Table from `report_q1.R` (`out/report_q1.rds`).

| grid | nodes | accepted steps (rejected attempts) | forward CPU s | ms / step | member evaluations / step | µs / member evaluation | recorded forward CPU s (÷ plain) | sweep CPU s | ms / step | member evaluations / step | µs / member evaluation | **sweep ÷ plain forward** | hook sweep ÷ shipped |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| uniform | 108 | 10 577 (2 731) | 83.3 | 7.9 | 449 | 17.6 | 82.3 (0.99) | 221.8 | 21.0 | 340 | 61.7 | **2.66** | 1.006 |
| uniform | 215 | 10 921 (2 921) | 159.8 | 14.6 | 876 | 16.7 | 154.4 (0.97) | 406.8 | 37.2 | 662 | 56.2 | **2.55** | 1.028 |
| uniform | 429 | 11 240 (3 041) | 311.5 | 27.7 | 1 736 | 16.0 | 308.3 (0.99) | 793.9 | 70.6 | 1 311 | 53.9 | **2.55** | 1.045 |
| uniform | 857 | 11 627 (3 094) | 637.8 | 54.9 | 3 454 | 15.9 | 612.8 (0.96) | 1601.6 | 137.8 | 2 607 | 52.8 | **2.51** | — |
| default | 108 | 9 917 (2 444) | 131.6 | 13.3 | 782 | 17.0 | 128.6 (0.98) | 340.5 | 34.3 | 590 | 58.2 | **2.59** | 1.018 |

| grid | forward: process max RSS | recorded run: resident after | recording payload (state) | resident growth ÷ payload | bytes per live node per step | sweep peak (its own working set) | adj.R process max RSS |
|---|---|---|---|---|---|---|---|
| uniform 108 | 153 | 263 | 109.0 (46.5) | 1.09 | 198 | 296 (+31) | 297 |
| uniform 215 | 153 | 390 | 212.6 (94.3) | 1.16 | 188 | 451 (+58) | 458 |
| uniform 429 | 154 | 655 | 427.1 (194.1) | 1.20 | 184 | 765 (+107) | 781 |
| uniform 857 | 155 | 1215 | 879.5 (408.2) | 1.22 | 183 | 1423 (+205) | 1423 |
| default 108 | 153 | 331 | 173.7 (77.1) | 1.08 | 191 | 365 (+31) | 365 |

MiB throughout. The payload is counted by the hook's `census_recording_size_tf24`: the
rows' own footprint (592 bytes each), state entries (8 bytes) and the leaf operating
points kept for replay (16 bytes).

- **The sweep of J costs 2.51–2.66 plain forward runs in CPU, flat in the node count**
  (2.66 at 108, 2.51 at 857). **Sweeping every census metric costs 1.42× the J-only
  sweep** (default 108, one recording: 482.9 s against 339.9 and 339.5 s for J alone, J's
  row identical in all three; `sweep_metrics.R`), which is **3.67 plain forward runs**: the
  earlier 3.7× (513 s against 140 s) was that every-metric sweep. Per member evaluation it costs 3.3–3.5× the forward's;
  the forward makes 1.32× as many member evaluations per accepted step, since it also
  evaluates 0.25–0.27 rejected attempts per accepted step and a sweep replays accepted
  steps only.
- **Recording costs nothing in CPU**: the recorded forward took 0.96–0.99× the plain one.
- **The recording is about 3× "one double per state entry per step"**: 183–198 bytes per
  live node per step against the 64 bytes of 8 state entries, because each step also
  keeps six leaf operating points per member (96 bytes). Of the payload 43–46% is state,
  50–53% operating points, 1–7% row headers. It holds a full state row per insertion as
  well: 3 039–3 786 insertion rows per run, 2 929–2 931 of them the rainfall pulses. The
  resident set grows 8–22% more than the payload, the gap widening with the node count.
- **The sweep's own working set is small beside the recording**: 31 / 58 / 107 / 205 MiB
  at 108 / 215 / 429 / 857 nodes, 0.24–0.29 MiB per node. At 857 the recording is
  880 MiB and the process peaks at 1423 MiB.
- A forward run without a recording adds 9–10 MiB to the loaded process at every size;
  its 153–155 MiB is R and the package.
- The sweep evaluates the inflow boundary six times per accepted step (63 456 /
  65 520 / 67 434 / 69 756 / 59 496).

## 2. The gradient's convergence in the schedule

dJ/dlma is the sweep's parameter columns chained through the hyperparameterisation:
d/dlma of `lma` 1, `r_l` −308.917, `k_l` −1.07252 (`chain.R`); `nmass_l`
(−0.0102) has no column. Tables from `report_q2.R` (`out/report_q2.rds`); the pinned
differences on 215 from `fd_lma.R`.

| grid | J − J∞ | order | dJ/dlma, adjoint | − (−172.52) | order | its lma / r_l / k_l terms |
|---|---|---|---|---|---|---|
| uniform 108 | +0.70298 | | −182.203 | −9.683 | | −306.69 / +103.53 / +20.96 |
| uniform 215 | +0.17411 | 2.01 | −168.108 | +4.412 | 1.13 | −287.06 / +98.93 / +20.03 |
| uniform 429 | +0.00169 | 6.68 | −171.452 | +1.068 | 2.05 | −289.53 / +98.20 / +19.88 |
| uniform 857 | +0.00023 | 2.90 | **−172.588** | **−0.068** | 3.97 | −290.71 / +98.23 / +19.86 |
| default 108 | −0.45617 | | −158.593 | +13.927 | | −269.02 / +91.84 / +18.59 |

- **The gradient does not converge at J's rate.** Over 108 → 857 its error falls 142×,
  J's 3100×; the orders read 1.13 / 2.05 / 3.97 against J's 2.01 / 6.68 / 2.90, and the
  error changes sign between 108 and 215. Between 215 and 429, where J's error falls
  103×, the gradient's falls 4.1×. In relative terms the gradient is 0.62% off at 429
  (J 0.013%) and 0.039% at 857 (J 0.0018%).
- At 857 the adjoint reads −172.588, 0.068 from the reference, outside its ±0.03.
- **On uniform 215 the adjoint and the pinned difference of the same grid part by
  3.4%**: central −174.017 at d = 1e-3 (backward −173.834, forward −174.201), −167.271
  at d = 1e-4 (backward −170.064, forward −164.478, second difference +55 866), against
  the adjoint's −168.108. The adjoint is the derivative of the recorded steps with the
  recorded operating points held; the pinned secant over ±1e-3 crosses what they hold
  fixed. On that run the forward counted `rooting_depth` clamped in 8.48 M of 9.57 M
  leaf solves (6.41 M in the sweep), `root_vuln_integral_cap` 822 k (none in the sweep),
  and operating points interior 8.19 M, boundary-crit 1.36 M, determined 9 138,
  hydraulic-shutdown 8 011; no refusal, curvature margin 0.853.

The five columns of largest |elasticity| (θ/J · ∂J/∂θ, uniform 857), relative to
their 857 values:

| column | value | elasticity | uniform 108 | uniform 215 | uniform 429 | default 108 |
|---|---|---|---|---|---|---|
| curv_fact_colim | 0.99 | +53.2 | +5.4% | +0.51% | −0.12% | −7.2% |
| hmat | 16.60 | −8.02 | +5.0% | +1.15% | +0.02% | −5.7% |
| lma | 0.32 | −7.40 | +5.5% | −1.25% | −0.41% | −7.5% |
| r_l | 287.85 | −7.28 | +5.4% | +0.71% | −0.04% | −6.5% |
| stem_P50 | 2.889 | +6.74 | +5.5% | +0.71% | −0.01% | −7.4% |

All five move together by 5.0–5.5% at 108 and by −5.7% to −7.5% on the default 108;
by 429 four are within 0.12% and the `lma` column itself is 0.41% off, the slowest.

## 3. The value of a newborn by birth date

v_k = d_k + λ_k: d_k = w_k f_k is node k's direct share of J, λ_k the adjoint of its
log-density entry in the state just after its introduction. §4.1 gives why these are
two separate terms here: λ_k is J's sensitivity to node k's initial log density and
carries the competition channel only; v_k is the sensitivity to the logarithm of the
node's birth flux.

### 3.1 What the shipped sweep exposes

It does not expose λ_k.

- `census_state_and_trait_rows()` is the seed: d(census)/d(state) and d(census)/d(trait)
  at the final time, from one recording.
- `census_trait_gradient()` returns the trait gradient and `at_first_state`, the adjoint
  at recording row 0: the empty patch's 11 entries (the averaged gate and the soil).
- odelia's `Solver::solve_adjoint` walks the rows top down. At each insertion row it puts
  the system on the row below, records `apply_insertion` there and transposes it
  (`state_and_parameter_adjoints`), replacing the wide adjoint — whose last node block is
  the new node's initial-state adjoint — by the narrow one. The wide adjoint exists only
  inside that loop; `extra_stops` splits ranges and returns nothing more.
- Every rainfall pulse is an insertion row too (an event with no node), crossed the same
  way; an introduction is the insertion row whose state is wider than the row below it.
- `ladder_census_initial_state_tangent_tf24(scm, direction, range)` gives one node's λ by
  a forward tangent replayed from that node's insertion: one replay per node.

### 3.2 The hook

Worktree `$SP/perf/adjoint/plant`, branch `perf-adjoint` off 6613dd24, uncommitted; the
diff is `perf-adjoint-hook.patch` beside this note (against `plant` 6613dd24) (207 added lines, none removed).

- `SCM::census_introduction_adjoints(metric, trait_gradient)` in
  `inst/include/plant/scm.h`: census_trait_gradient's descent taken one range per call,
  `solver.solve_adjoint(lambda, trait_adjoint, at, hi)` from each introduction row `at`
  to the row below the next (odelia crosses the pulse rows inside a range as in the
  shipped sweep), reading λ at each introduction row, then transposing that
  introduction with the `apply_insertion` recording the solver's walk makes, and ending
  with the shipped path's transpose of the averaged gate's start. It returns λ at every
  introduction row, full width, and the same sweep's trait gradient.
- In `src/census_gradient.cpp`: `census_introduction_adjoints_tf24(scm, metric)`,
  `census_sweep_counters_tf24(scm)` (leaf placements and boundary evaluations, running
  totals), `census_recording_size_tf24(scm)`; `R/RcppExports.R` and `src/RcppExports.cpp`
  regenerated by `Rcpp::compileAttributes`. No RcppR6 class changed, odelia untouched,
  the default path untouched.
- **Bit-identity** (`bitcheck.R`, default 108): the hook build's recorded J, plant-adj's
  recorded J (`tg/out/adj_dyadic_108.rds`) and plant-adj's unrecorded J are one double,
  12.117229795958, at 9917 steps; the hook build's J-only sweep equals plant-adj's
  every-metric sweep in J's row, column for column (`identical`), and the hook's
  gradient equals the shipped sweep's on every grid it ran (108, 215, 429, default).
- The hook's sweep cost 1.006 / 1.028 / 1.045 / 1.018 shipped sweeps (uniform 108 / 215 /
  429 / default 108).
- Its rows satisfy two exact identities of the model, which place each value on the
  right node and row (`export_nodes.R`): the mortality entry's adjoint is −d_k (a shift of
  the initial mortality scales that node's survival and nothing else), to 1.2e-14 –
  5.3e-14 against d_k up to 4.0; the survival-weighted offspring entry's adjoint equals
  w_k β p_k S_D exactly.

### 3.3 On uniform 429

`report_q34.R` (`out/report_q3.rds`, per node in `out/nodes_uniform_429.csv`).

| birth date b (yr) | nodes | direct share Σd | competition Σλ | value Σv | competition ÷ direct |
|---|---|---|---|---|---|
| [0, 0.5) | 6 | 6.371 | −6.048 | +0.323 | −0.95 |
| [0.5, 1) | 5 | 2.588 | −2.582 | +0.006 | −1.00 |
| [1, 2) | 11 | 1.722 | −1.975 | −0.254 | −1.15 |
| [2, 5) | 32 | 0.509 | −0.908 | −0.399 | −1.78 |
| [5, 10) | 54 | 1.221 | −5.207 | −3.986 | −4.27 |
| [10, 20) | 108 | 0.163 | −2.320 | −2.157 | −14.2 |
| [20, 30) | 108 | 0.00203 | −0.134 | −0.132 | −66 |
| [30, 39.63] | 105 | 4.5e-11 | −0.00297 | −0.00297 | — |
| all | 429 | **12.575 (= J)** | **−19.177** | **−6.601** | −1.52 |

Per unit birth date (g = v/w): g = +1.20 at b = 0, crosses zero at b = 0.74, −0.29 at
b = 1.8, −0.10 at b = 3.3; it swings to −3.05 at b = 7.96 (f 1.28, c −4.33 per yr), the
cohorts established as the first multi-year drought ends, and stays negative after.

- **The competition effect is large for early members in absolute terms**: the 11 nodes
  born before b = 1 carry −8.63 of the −19.18, and it cancels 95–100% of their own
  offspring. **Relative to own offspring it grows with birth date**: −1.8 at b = 2–5,
  −4.3 at 5–10, −14 at 10–20, −66 at 20–30.
- **Every member born after b = 0.65 has a negative value**: one more such newborn lowers
  J. Only the first 8 nodes are positive (largest v = 0.086 at b = 0.09); the most
  negative is −0.282 at b = 7.96. Scaling every node's birth flux by 1 + ε changes J by
  −6.60 ε.
- λ_k itself is −0.73 at b = 0 (half weight), −1.33 at b = 0.09, falling to −0.32 by b = 1,
  −0.40 at b = 7.96, and about −1e-9 at the last node.

**Check** (`fd_nodes.R`): the recorded steps replayed from the state after node k's
introduction with its log density moved by ±δ (`ladder_census_initial_state_replay_tf24`;
the unperturbed replay returns J to 2.2e-9, 12.575093101147 against 12.575093098974):

| node | b | central difference, δ = 0.02 | λ_k from the hook | relative | CPU s (two replays) |
|---|---|---|---|---|---|
| 12 | 1.019 | −0.3184158 | −0.3183548 | 1.9e-4 | 488 |
| 109 | 10.000 | −0.01171885 | −0.01172067 | −1.6e-4 | 453 |
| 271 | 25.000 | −6.11236e-4 | −6.11225e-4 | 1.8e-5 | 289 |
| 271 | 25.000 | δ = 0.005: −6.11652e-4 | | 7.0e-4 | 288 |

The forward tangent at node 271 (`ladder_census_initial_state_tangent_tf24`, 293 s)
reads −6.1121573e-4, 1.5e-5 from the hook's value. The birth-rate weight was not
perturbed: the direct term d_k is arithmetic on the node's own outputs, and the
identity λ_mortality = −d_k (§3.2) holds to 1e-14.

## 4. A goal-oriented error estimate for the schedule

### 4.1 How the code weights a node

Nodes sit at birth dates x_1 = 0 < x_2 < … < x_N; the patch runs to T = 40.

- **J** (`Species::offspring_production`) is the trapezium over the node birth dates
  alone: J = Σ_k w_k f_k, w_1 = (x_2 − x_1)/2, w_k = (x_{k+1} − x_{k−1})/2,
  w_N = (x_N − x_{N−1})/2, with f_k = β(x_k) p(x_k) S_D F_k(T): birth rate (1 here),
  patch-age density at birth, dispersal survival (0.25) and the node's per-capita
  survival-weighted offspring. Its last panel is [x_{N−1}, x_N]; no boundary node enters.
- **Every density-weighted reduction at time t** — the light profile at each height
  (`Species::field_splits`, `close_competition_and_slope`), each soil layer's uptake
  (`Species::consumption_rate`) and the census metrics — is the trapezium over
  {x_1, …, x_n, t}: the n nodes introduced by t, closed by the boundary node at abscissa
  b = t (`set_new_node_birth_date`), whose density is β(t) E(t), a newborn at the
  averaged gate. Node k weighs (x_{k+1} − x_{k−1})/2 once node k+1 exists and
  (t − x_{k−1})/2 while it is the newest; the boundary node weighs (t − x_n)/2. So a
  node's competition weight equals its J weight except over its first interval (a ramp
  from (x_k − x_{k−1})/2) and, for the last node, after x_N (growing to (T − x_{N−1})/2).
- **A node's log density moves only by its own mortality** (`log_density_rate` is
  −mortality rate on this coordinate), so a shift δ at introduction multiplies that
  node's term in every such reduction, at every later time, by e^δ, and reaches nothing
  else. λ_k = ∂J/∂ log ν_k(x_k) is therefore J's sensitivity to the node's weight in the
  competition reductions. J reads per-capita offspring, not density, so λ_k has no
  own-offspring term.

Hence v_k = d_k + λ_k is J's sensitivity to the logarithm of node k's birth flux (its
density and its J weight together), and per unit weight

  g_k = v_k / w_k = f_k + c_k,  c_k = λ_k / w_k.

With exact characteristics and to first order in the quadrature error,

  J_h − J∞ = Σ_k w_k g(x_k) − ∫ g(b) db,

the trapezium defect of g = f + c, c(b) the competition effect per unit birth date.
Its assumptions:

1. the characteristics' ODE error is ignored (ode_tol 1e-3; introductions are step
   boundaries, so a schedule also moves step placement);
2. first order in the quadrature error;
3. a node's competition weight is w_k throughout: the ramp over its first interval, the
   last node's growth past x_N, and the panel from the newest node to the boundary node
   are left out (that panel's defect is O(h³) over the run);
4. for an estimate from nodal values, g is smooth between nodes at the grid's spacing.

### 4.2 The estimate η, and a test of the premise

From nodal values alone: at each interior node the drop-one defect
D_k = T_with − T_without on [x_{k−1}, x_{k+1}] gives the fine trapezium's error there,
e_k = −D_k (h_1³ + h_2³) / (3 h_1 h_2 (h_1 + h_2)) (−D_k/3 on a uniform grid), split half
to each of the node's two panels (the end panels take e_2/2 and e_{N−1}/2); η is the sum
over panels. On odd uniform N the nested Richardson form (T_h − T_{2h})/3 is also taken,
which is (1/3) Σ_k (−1)^k v_k, an alternating sum of node values. η_f is the same estimate
of f alone. refine_schedule's indicator is read with `scm$collect_refinement_errors <-
TRUE` set before `run()`, from the active field `scm$refinement_error_by_node`
(`SCM::refinement_error_by_node`: per node, the larger of the drop-one competition
defect sampled at each introduction and the drop-one reproduction defect, each
normalised). `indicators.R`, `report_q34.R` (`out/report_q4.rds`).

| grid | J_h − J∞ | η | η ÷ true | η, Richardson | η_f | η_f ÷ true | η_f, Richardson | refine_schedule indicator: max / sum |
|---|---|---|---|---|---|---|---|---|
| uniform 108 | +0.70298 | +0.02852 | 0.041 | — | +0.22221 | 0.32 | — | 0.382 / 1.82 |
| uniform 215 | +0.17411 | +0.00842 | 0.048 | −0.16665 | +0.05001 | 0.29 | +0.00532 | 0.142 / 1.07 |
| uniform 429 | +0.00169 | +0.00234 | 1.38 | −0.05584 | +0.01215 | 7.2 | +0.00278 | 0.040 / 0.50 |
| default 108 | −0.45617 | −0.18323 | 0.40 | — | +0.06769 | −0.15 | — | 0.307 / 1.78 |

**The premise tested with an accurate g.** To first order the difference of two
schedules' J is the difference of their trapezia of one g, so uniform 429's nodal g,
taken on a coarser node set, predicts that set's J − J_429 with no reference integral
(nested grids read the 429 nodes; the default nodes read 429's g through its natural
spline):

| node set | predicted from g | from f alone | actual J_h − J_429 | predicted ÷ actual |
|---|---|---|---|---|
| uniform 108 | +0.6530 | −0.0234 | +0.7013 | **0.93** |
| uniform 215 | +0.1675 | −0.0084 | +0.1724 | **0.97** |
| default 108 | −0.5902 | +0.6551 | −0.4579 | **1.29** |
| cw108_220 (`perf/schedules`) | +0.0098 | +0.0019 | −0.0085 | −1.16 |

On uniform 108 the prediction sits in b = 5–10 (+0.413, of which competition +0.575 and f
−0.162) and b = 10–20 (+0.186); on 215 likewise (+0.093 and +0.071).

- **The premise holds**: with 429's g the trapezium defect gives the coarse grids' J error
  to 3–7% on the uniform ladder and 29% on the default schedule, where the spline carries
  429's g across the default grid's 1–2 yr panels. On the lean 220-node schedule, whose
  difference from 429 is 0.0085, it has the wrong sign: at that level 429's own g is not
  accurate enough.
- **J's integrand alone does not**: its defect on uniform 108 is −0.023 against +0.701,
  the opposite sign; the error there is the competition channel's, over cohorts born in
  years 5–20. On the default 108 the f-only defect (+0.655) and the competition defect
  (−1.245) are both large and of opposite sign.
- **From a coarse grid's own nodal values neither estimate tracks the error**: η is 4–5%
  of it on uniform 108 and 215, and the Richardson form has the wrong sign on 215. The
  nodes of those grids do not resolve g — its excursions in the drought years span
  0.1–0.5 yr (the averaged gate opens over about 40 days), against spacings of 0.37 and
  0.19 yr. At 429 (34-day spacing) η is 1.38× the true error, against 7.2× for η_f; on
  the default 108 η has the right sign at 0.40×, η_f the wrong one.
- refine_schedule's indicator is a normalised per-node drop-one measure, not an estimate
  of J's error: its maximum falls 2.7× from 108 to 215 and 3.5× from 215 to 429, while the
  error falls 4.0× and 103×.

### 4.3 Refining panels at equal added nodes

`refine_panels.R`: m panels bisected on the base schedule, each run forward. Arms: the
goal estimate from the base run's own nodal values (|η| per panel); the defect of 429's g
per panel (the same quantity with an accurate g); refine_schedule's indicator on the
panel below each node (the panel refine_schedule bisects); and f alone.

Uniform 108 (J − J∞ = +0.703 before; `out/refine_panels_uniform_108.rds`):

| m (nodes) | goal, own nodes | goal, 429's g | refine_schedule | f only |
|---|---|---|---|---|
| 10 (118) | +0.566 | **+0.227** | +0.401 | +0.677 |
| 25 (133) | **+0.071** | +0.186 | +0.204 | +0.213 |
| 50 (158) | +0.177 | +0.172 | **+0.153** | +0.180 |

- **No indicator wins at every m.** At m = 10 the defect of 429's g leaves 0.227 against
  refine_schedule's 0.401; at m = 25 the own-node goal ranking leaves 0.071 against 0.204;
  at m = 50 refine_schedule's is best, 0.153 against 0.172–0.180. f alone is last or near
  it throughout. From m = 25 to 50 the arms gather at 0.15–0.18 and the own-node goal arm
  moves back from 0.071 to 0.177: the further panels carry defects of both signs.
- **The defect of 429's g predicts each refinement's change**: −3/4 of the chosen panels'
  defects gives −0.444 / −0.490 / −0.492 against actual −0.476 / −0.517 / −0.531 (its own
  arm, m = 10 / 25 / 50), −0.248 / −0.431 / −0.513 against −0.302 / −0.499 / −0.550
  (refine_schedule's panels), −0.112 / −0.527 against −0.137 / −0.632 (own-node goal
  panels, m = 10 / 25). The own-node estimate predicts changes of −0.037 to +0.045 for the
  panels of every arm.

Default 108 (J − J∞ = −0.456 before; `out/refine_panels_default_108.rds`):

| m (nodes) | goal, own nodes | goal, 429's g | refine_schedule | f only |
|---|---|---|---|---|
| 5 (113) | **+0.129** | −0.505 | +0.368 | **+0.129** (the goal arm's panels) |
| 10 (118) | −0.391 | −0.472 | **−0.158** | +0.147 |
| 25 (133) | −0.459 | −0.461 | −0.462 | **−0.339** |

- **On the default schedule the J response to added nodes is not additive over panels,
  and the first-order prediction fails for most panel sets.** It holds for the m = 5 goal
  and refine_schedule sets (predicted +0.528 / +0.816, actual +0.585 / +0.825) and the
  m = 10 f-only set (+0.547 / +0.603); it fails for the m = 5 set of its own arm (+0.298
  predicted, −0.048 actual), for three of the m = 10 sets (+0.40 to +0.71 predicted, −0.02
  to +0.30 actual) and for all four at m = 25 (+0.44 predicted each, −0.005 to +0.117
  actual). The m = 5 goal and goal-429 sets differ by one panel and their J by 0.63.
- The default grid's panels in b = 5–38 are 1–2 yr wide, and a node there stands for
  1–2 yr of cohorts whose competition effect c reaches −4 per yr (§3.3): one added node
  is not a small perturbation of the canopy, which is what assumption 2 of §4.1 needs.
- At m = 25 every arm but f alone ends where it started (−0.459 to −0.462); the best single
  result is +0.129 at m = 5.

## 5. Costing

| grid | plain forward | recorded forward + hook sweep | ÷ plain | beyond the shipped gradient sweep | Richardson of J: half-node run | its estimate (p = 2 / p = 3) | true error |
|---|---|---|---|---|---|---|---|
| uniform 108 | 83.3 | 305.5 | 3.67 | +1.4 | — | — | +0.7030 |
| uniform 215 | 159.8 | 572.4 | 3.58 | +11.2 | 83.3 | +0.1763 / +0.0756 | +0.1741 |
| uniform 429 | 311.5 | 1137.6 | 3.65 | +35.4 | 159.8 | +0.0575 / +0.0246 | +0.0017 |
| uniform 857 | 637.8 | 2214.4 (shipped sweep, no hook) | 3.47 | — | 311.5 | +0.00049 / +0.00021 | +0.00023 |
| default 108 | 131.6 | 475.4 | 3.61 | +6.3 | — | — | −0.4562 |

CPU seconds (`report_q1.R`, `report_q5.R`).

- **The adjoint-based estimate costs 3.6–3.7 plain forward runs** (a recorded forward and
  the hook's sweep). An optimiser computes the sweep anyway; beyond it the estimate costs
  0.6–4.5% of the sweep (1.4–35 s), plus one pass over the nodes.
- **A Richardson estimate of J costs half a forward run** (the run at half the nodes); at
  215 it reads the error to 1.3% (p = 2), at 429 it is 34× too large (p = 2) or 15× (p = 3),
  at 857 0.93× (p = 3).
- **refine_schedule's loop** from the default 108 at its default `schedule_eps = 0.02`
  (`refine_iter.R`, `out/refine_iter_default_108_eps0.02.rds`; SCM::refine_schedule's
  rule, one logged run per iteration):

  | run | nodes | J − J∞ | CPU s | largest indicator | nodes flagged |
  |---|---|---|---|---|---|
  | 1 | 108 | −0.4562 | 129 | 0.307 | 16 |
  | 2 | 124 | −0.5025 | 141 | 0.152 | 23 |
  | 3 | 147 | −0.0586 | 159 | 0.073 | 18 |
  | 4 | 165 | −0.1215 | 172 | 0.065 | 11 |
  | 5 | 176 | −0.1652 | 180 | 0.038 | 2 |
  | 6 | 178 | −0.1660 | 181 | 0.019 | 0 |

  Six runs, 962 CPU s (7.3 forward runs of the default 108), end at 178 nodes with J
  1.3% low; the error is not monotone in the iterations and the loop stops, its largest
  indicator under 0.02, with −0.166 left. For comparison: uniform 215 (160 CPU s) reads
  +0.174, and the schedule agent's lean `cw108_220` (220 nodes, 226 CPU s here) −0.0068.
- The adjoint estimate measures the error (from the grid's own nodes) only where the grid
  resolves g (§4.2), so at the coarse levels where a schedule is chosen it does not replace
  a finer run; the first-order formula with an accurate g does predict the coarse grids'
  errors (0.93–1.29×), and on the uniform ladder it predicts which panels matter (§4.3).

## What was not reached

- **The hook's sweep, the node values and η on uniform 857**: 857 ran the shipped sweep
  only (§1, §2), so the 857 row of §4 and the node values there are absent.
- **A goal-oriented estimate that resolves g between nodes.** The estimate here reads
  nodal values only, and fails where the nodes do not resolve g (§4.2); evaluating g at
  panel midpoints (one extra node each, or the hook on a bisected grid) was not tried.
- **The lean schedule of `perf/schedules`** (`cw108_220`, 220 nodes) was run forward only
  (`fwd.R`: J = 12.566638858, 10 544 steps, 226 CPU s, the file's own numbers); no
  recording, sweep or η on it.
- **The two-species stand** behind the 5.3× figure was not re-measured.
- **Perturbing a node's birth-rate weight** in the finite-difference check: the log
  density was perturbed (§3.3); the direct term is the node's own arithmetic.
- **The ODE error's share of J_h − J∞** (tol 1e-3, with introductions as step boundaries)
  was not separated from the schedule's; the premise test of §4.2 holds it implicitly
  (0.93–0.97 on the uniform ladder).
- **Pinned differences of dJ/dlma** were re-measured on uniform 215 only (§2).
