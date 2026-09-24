# TF24 SCM time grid: the step controller

## Configuration

- **Code.** `plant` 6613dd24, the -O2 build in `$SP/plant-adj`. The stepper is odelia's Cash–Karp 5(4) with `OdeControl`, as installed. The `.so` mtime was 2026-09-23 13:14:26 before and after every batch.
- **Fixture.** TF24 SCM, one species, `lma = 0.32`, `max_patch_lifetime = 40`, `node_density_in_birth_date = TRUE`, `establishment_window = 0.05`.
- **Forcing.** `long-drought`: 14 599 daily control points in (0, 40), of which 2931 are active knots. "Aligned" means a zero-depth rainfall pulse at each active knot. Each knot is then a schedule entry that the integrator must land on.
- **Control.** `ode_tol_rel = ode_tol_abs = 1e-3` unless stated. `ode_step_size_max = 5` yr, `ode_step_size_min = ode_step_size_initial = 1e-6` yr, `a_y = 1`, `a_dydt = 0`.
- **Schedules.** u429 is `uniform_times(429)`; d108 is the default 108-node schedule.
- **Reproduced.** u429 gives J = 12.575093099 at 11 240 steps and d108 gives J = 12.117229796 at 9917 steps, both identical to the reference values. "Steps" is the harness count `length(ode_step_sizes)`, which is accepted steps + 1.
- **Cost measures.**
  - Accepted steps and attempts.
  - Member evaluations: the sum, over all rate evaluations, of the members held at the time. Every member held in either run keeps a log density above −50 throughout, so every member held is alive.
  - An attempt is 6 rate evaluations: 5 stages plus the end-state evaluation that is handed to the next step.
  - A thrown attempt stops at the stage that throws. That stage is counted as evaluated.
  - Each schedule entry (a knot stop or an introduction) adds 2 evaluations. `Patch::introduce_nodes` calls `compute_rates` even when it introduces nothing, and `set_state_from_system` evaluates the rates again.
  - CPU seconds (`user.self`) are secondary. Five agents shared 4 cores, so every timing is contaminated.
- **Regimes, from the rainfall record.**
  - First 3.5 yr.
  - Drought: calendar years whose rainfall is below 0.6 of the median year's. These are years 8–10, 20–22 and 32–34, 9 yr in all.
  - Wet: the other 27.5 yr.
- **How rejections were recovered.** Every rejected attempt was recovered, not estimated.
  - The controller's proposal was carried along each recorded run.
  - A step's first attempt is min(proposal, time to the next schedule entry). Any accepted step shorter than its first attempt was replayed in R from its recorded start state, through `Patch$derivs`, with the solver's tableau and controller law.
  - The replay is bit-identical to the solver. 44 of 44 re-taken steps reproduce the end state, the error ratio and the binding component exactly (`ctl_rk_check.R`).
  - On all 12 replayed runs (every u429 run and d108 at 1e-3) the recovered counts equal the run's own `ode_step_attempts` exactly, with 0 mismatched steps (`ctl_replay.R`).

## Key numbers

| | u429 | d108 |
|---|---|---|
| J; steps | 12.575093099; 11 240 | 12.117229796; 9 917 |
| attempts; rejected (inaccurate + thrown) | 14 280; 3 041 = 21.3% (1 891 + 1 150) | 12 360; 2 444 = 19.8% (1 916 + 528) |
| rejected share of rate / member evaluations | 17.0% / 17.0% | 16.9% / 16.9% |
| schedule entries' share of member evaluations | 7.5% | 7.6% |
| accepted steps ended at a knot stop / an introduction | 26.1% / 3.8% | 29.6% / 1.1% |
| median step; median error ratio r; steps with r ≥ 0.5 | 0.56 d; 0.030; 8.3% | 0.49 d; 0.040; 9.6% |
| steps bound by soil / member / E / flux accumulators | 75.7 / 22.8 / 1.5 / 0% | 85.8 / 12.0 / 2.2 / 0% |
| steps bound by a dead member (log density < −50) | 0 | 0 |
| accepted steps at h·\|λ\|soil ≥ 0.8β | 23.7% | 27.9% |
| inaccurate rejections at h·\|λ\|soil ≥ 0.8β | 59.1% | 58.5% |
| thrown attempts: share where the throwing state is the newest member's storage / whole-system h·\|λ\|/β median | 79% / 1.69 | 72% / 1.57 |
| accepted steps ∝ tol^(−p), tol 1e-2 … 1e-4 | p = 0.065 | |
| J spread over tol 1e-2 … 1e-4 (relative) | 4.0e-4, 3.1× the schedule's 1.3e-4 | 3.2e-3 (1e-2, 3e-3, 1e-3, 1e-4) |
| J, tol 1e-3 → 1e-2 | +1.65e-4 | +2.08e-3 |
| J, extra zero-depth stops at the 857-level birth dates | +1.65e-4 | |
| J without stops; without stops at h ≤ 5 d | −22.3%; −0.45% | |
| adjoint dJ/dlma: tol 1e-3 → 1e-4 | | −158.593 → −158.898 (+0.19%) while J moves −0.11% |
| adjoint at tol 1e-2 and 3e-3 | | refused (vulnerability-curve domain) |
| bound with the two stiff modes' stability removed (section 7): accepted steps; member evaluations saved at 1 evaluation per entry | 6 722 (−40%); 51% (I1) to 37% (walk); floor 74% | 6 254 (−37%); 49% to 35%; floor 73% |

## 1. Step anatomy

### Attempts and their cost

| | u429 | d108 |
|---|---|---|
| attempts | 14 280 | 12 360 |
| accepted | 11 239 | 9 916 |
| rejected, inaccurate | 1 891 | 1 916 |
| rejected, thrown (domain) | 1 150 | 528 |
| rejected, refused / accepted at minimum | 0 / 0 | 0 / 0 |
| rejected share of attempts | 21.3% | 19.8% |
| rate evaluations: accepted / rejected / schedule entries | 67 434 / 15 203 / 6 716 | 59 496 / 13 297 / 6 078 |
| rejected share of rate evaluations | 17.0% | 16.9% |
| member evaluations: accepted / rejected / schedule entries | 1.460e7 / 3.291e6 / 1.456e6 | 5.733e6 / 1.287e6 / 5.806e5 |
| rejected share of member evaluations | 17.0% | 16.9% |
| schedule entries' share of member evaluations | 7.5% | 7.6% |
| CPU (s) | 313.2 | 131.6 |
| member evaluations per CPU second | 6.17e4 | 5.78e4 |

- Rejected attempts preceded 2824 accepted steps in u429: one rejection before 2610 of them, two before 212, three before 1, four before 1. In d108 they preceded 2229 steps (2018 / 208 / 2 / 1).
- A thrown attempt costs 3.35 rate evaluations on average (3.41 in d108). 96% of throws (d108 95%) come at the stage at 0.6h or 1.0h, after 3 or 4 evaluations.
- Sources: `ctl_anatomy.R` (`out/anatomy_{u429,d108}_base.log`) and `ctl_note_numbers.R`.

### What ends each accepted step

| ended by | u429 | d108 |
|---|---|---|
| active-knot stop, proposal clipped | 2 929, + 2 shared with an introduction (26.1%) | 2 931 (29.6%) |
| introduction, proposal clipped | 426 (3.8%) | 107 (1.1%) |
| run end | 1 | 1 |
| controller, at its proposal | 5 057 (45.0%) | 4 648 (46.9%) |
| controller, after rejected attempts | 2 824 (25.1%) | 2 229 (22.5%) |

- A step is clipped whenever its proposal exceeds the time left to the next schedule entry. Each of the 3358 legs between schedule entries (u429; 3039 in d108) therefore ends in exactly one clipped step.
- A clipped step is a median 0.33 of the proposal it replaced (u429; quartiles 0.15–0.59). In d108 it is 0.32 (quartiles 0.13–0.58). 68% of clipped steps are cut to less than half the proposal.
- The solver does not update `step_size_last` on a clipped final step. The next leg therefore starts from the proposal that was clipped.

### Step sizes and legs

| | u429 | d108 |
|---|---|---|
| step size, days: 10 / 25 / 50 / 75 / 90% | 0.12 / 0.23 / 0.56 / 1.39 / 3.24 | 0.12 / 0.21 / 0.49 / 1.22 / 3.86 |
| largest step, days | 25.1 | 48.7 |
| legs (between consecutive schedule entries) | 3 358 | 3 039 |
| leg length, days: 25 / 50 / 75 / 90% | 1 / 1 / 3 / 13.4 | 1 / 1 / 1 / 12 |
| accepted steps per leg: mean; share of legs taken in one step | 3.35; 31.6% | 3.26; 32.6% |
| legs of 1 / 2 / 3 / 4–5 / 6–10 / 11–20 / > 20 steps | 1060 / 583 / 537 / 698 / 394 / 52 / 34 | 991 / 516 / 499 / 605 / 382 / 26 / 20 |
| error ratio r of accepted steps: 10 / 25 / 50 / 75 / 90% | 1e-4 / 0.0023 / 0.030 / 0.175 / 0.453 | 1e-4 / 0.0046 / 0.040 / 0.213 / 0.486 |
| accepted steps with r ≥ 0.5 | 934 (8.3%) | 950 (9.6%) |

### By regime

| u429 | first 3.5 yr | wet | drought | all |
|---|---|---|---|---|
| accepted steps (per year) | 1 061 (303) | 8 343 (303) | 1 835 (204) | 11 239 (281) |
| members held, mean | 18 | 240 | 224 | 216 |
| rejected attempts (% of attempts) | 244 (18.7%) | 2 342 (21.9%) | 455 (19.9%) | 3 041 (21.3%) |
| of which thrown | 16 | 858 | 276 | 1 150 |
| steps ended at a knot stop / an introduction | 27.5% / 3.6% | 24.4% / 3.5% | 33.0% / 5.3% | 26.1% / 3.8% |
| steps after rejections | 20.5% | 26.0% | 23.7% | 25.1% |
| median step, days | 0.39 | 0.49 | 1.00 | 0.56 |
| median error ratio | 0.056 | 0.034 | 0.013 | 0.030 |
| steps bound by soil / member / E | 93.4 / 6.5 / 0.1% | 76.4 / 22.0 / 1.7% | 62.5 / 36.1 / 1.4% | 75.7 / 22.8 / 1.5% |
| steps at h·\|λ\|soil ≥ 0.8β | 31.1% | 26.1% | 8.2% | 23.7% |
| member evaluations on rejected attempts / on schedule entries | 16.7 / 8.0% | 17.7 / 7.0% | 13.4 / 10.1% | 17.0 / 7.5% |

| d108 | first 3.5 yr | wet | drought | all |
|---|---|---|---|---|
| accepted steps (per year) | 1 089 (311) | 7 363 (268) | 1 464 (163) | 9 916 (248) |
| members held, mean | 74 | 99 | 99 | 96 |
| rejected attempts (% of attempts) | 230 (17.4%) | 1 907 (20.6%) | 307 (17.3%) | 2 444 (19.8%) |
| of which thrown | 3 | 406 | 119 | 528 |
| steps ended at a knot stop / an introduction | 26.8% / 7.8% | 27.6% / 0.2% | 41.3% / 0.5% | 29.6% / 1.1% |
| steps after rejections | 18.6% | 23.6% | 19.5% | 22.5% |
| median step, days | 0.36 | 0.43 | 1.00 | 0.49 |
| median error ratio | 0.042 | 0.048 | 0.019 | 0.040 |
| steps bound by soil / member / E | 91.9 / 7.5 / 0.6% | 86.4 / 11.3 / 2.3% | 78.0 / 19.2 / 2.8% | 85.8 / 12.0 / 2.2% |
| steps at h·\|λ\|soil ≥ 0.8β | 31.2% | 30.7% | 11.3% | 27.9% |
| member evaluations on rejected attempts / on schedule entries | 16.4 / 8.2% | 17.7 / 7.0% | 13.2 / 10.6% | 16.9 / 7.6% |

Sources: `ctl_regimes.R` (`out/regimes_base.log`) and `ctl_stiff_summary.R`.

## 2. What sets the step

The binding component is the `error_index` of the accepted attempt: the component with the largest weighted error ratio. It sets the next proposal.

| binding component | u429 | d108 |
|---|---|---|
| soil layer 1 / 2 / 3 / 4 / 5 | 1497 / 1404 / 1086 / 1082 / 3441 | 1471 / 1398 / 1042 / 1098 / 3496 |
| soil, total | 8 510 (75.7%) | 8 505 (85.8%) |
| flux accumulators | 0 | 0 |
| member states | 2 563 (22.8%) | 1 193 (12.0%) |
| E | 166 (1.5%) | 218 (2.2%) |
| controller-ended steps only: soil / member / E | 5 768 / 2 001 / 112 of 7 881 | 5 905 / 849 / 123 of 6 877 |

Member-set steps:

| | u429 | d108 |
|---|---|---|
| by state: mortality / height / storage / fecundity | 1729 / 536 / 173 / 125 | 697 / 115 / 212 / 169 |
| log_density, offspring, heartwood states | 0 | 0 |
| by birth date: < 3.5 / 3.5–10 / 10–20 / 20–30 / 30–40 yr | 212 / 575 / 637 / 623 / 516 | 303 / 327 / 222 / 222 / 119 |
| set by the newest member | 2 024 (79%) | 697 (58%) |
| set by a member younger than 0.1 yr | 2 114 | 106 |
| log density of the binding member: min / 5% / median | −13.6 / −6.7 / −0.83 | −14.5 / −10.7 / −0.96 |
| dead (log density < −50) / below −10 / below −5 | 0 / 27 / 282 | 0 / 78 / 326 |

- No member in either run falls below log density −50 at any recorded row. At the end of u429 the lowest is −19.5 and the median is −8.6 (`ctl_placement.R`). No step is set by a dead member.
- Members with log density below −5 bind mostly through fecundity and storage: 115 and 110 of 282 steps in u429, 155 and 171 of 326 in d108.
- The five flux accumulators never bind at `atol` ≥ 1e-4. At `atol` = 1e-5 they bind 4 steps (section 5).
- Sources: `ctl_anatomy.R` and `ctl_regimes.R`.

## 3. Rejections

### Where they fall

Counts are u429, with d108 in parentheses.

| | inaccurate | thrown | rejected per 100 accepted steps there |
|---|---|---|---|
| first step after a knot stop | 1001 (1031) | 73 (48) | 36.6 (36.8) |
| first step after an introduction | 18 (7) | 111 (1) | 30.2 (7.4) |
| mid-leg | 872 (878) | 966 (479) | 23.3 (19.7) |
| rain falling at the attempt's start | 1510 of 1891 (1494 of 1916) | 23 of 1150 (6 of 528) | |
| first 3.5 yr / wet / drought | 228 / 1484 / 179 (227 / 1501 / 188) | 16 / 858 / 276 (3 / 406 / 119) | |

- The first step after a knot at which rain is falling draws 47 rejected attempts per 100 steps in both runs. The first step after a dry knot draws 27.
- Inaccurate attempts were rejected by the soil layers in 1858 of 1891 cases (u429): layer 2 544, layer 3 483, layer 1 433, layer 5 220, layer 4 178. Member mortality rejected 22 and E 11. In d108 the soil rejected 1859 of 1916, E 44 and member states 13.

Component that bound the accepted step before the rejected attempt:

| | inaccurate (u429 / d108) | thrown (u429 / d108) |
|---|---|---|
| soil layer 1 | 773 / 782 | 9 / 8 |
| soil layers 2–5 | 1011 / 1020 | 49 / 39 |
| member | 98 / 88 | 1049 / 445 |
| E | 9 / 26 | 43 / 36 |

Sources: `ctl_anatomy.R` and `ctl_misc.R` (`out/misc_base.log`).

### Domain throws

- **Message and guard.** In u429 and d108 at tol 1e-3, every throw carries the one message `TF24 storage is negative`. The guard is in `TF24_Strategy::compute_rates`, `inst/include/plant/models/tf24_strategy.h:1987`: `if (storage < -storage_domain_tol * storage_max) odelia::util::stop_domain(...)`, with `storage_domain_tol = 1e-8` (line 1306). Neither the non-finite-environment `stop_domain` (`patch.h:861`) nor the completed-step refusal (`Patch::ode_state_valid`, storage < 0 at the end state) fired in any u429 run. In d108, `ode_state_valid` refused once, at tol 1e-4.
- **Stage that throws.**

  | stage | c = 0.2h | 0.3h | 0.6h | 1.0h | 0.875h | end-state evaluation |
  |---|---|---|---|---|---|---|
  | u429 | 29 | 0 | 686 | 419 | 2 | 14 |
  | d108 | 1 | 1 | 350 | 154 | 0 | 22 |

- **How many members.** One member is negative at the throwing stage in 934 of 1150 throws (u429). One throw has 332 negative.
- **Which member.**
  - It is the newest member in 907 of 1150 throws (u429) and 380 of 528 (d108).
  - Its age is a median 0.047 yr in u429 (quartiles 0.012–0.080) and 0.94 yr in d108.
  - Its log density is a median −0.64 (u429).
  - Its storage at the step's start is a median 5.3e-8 kg (u429, quartiles 1.4e-8–1.5e-7), below atol/100 in 1119 of 1150 throws. In d108 the median is 5.8e-8 kg, below atol/100 in 428 of 528.
  - The newest member's storage is below atol/100 at all 11 239 accepted steps of u429, and at 7 258 of 9 916 (73%) in d108 (`ctl_checks.R`).
  - A storage component enters the error norm with weight rtol·|S| + atol ≈ atol. A 100% error in a storage of 5e-8 kg therefore contributes a weighted ratio of 5e-5.
- **Retry.** Every throw is retried at exactly 0.2 of the thrown size. 1139 of 1150 retries are accepted (521 of 528 in d108).
- **Repetition.**
  - In u429, 268 legs carry throws, 4.3 per leg on average (maximum 15). In d108, 93 legs carry them, 5.7 per leg (maximum 41).
  - Successive throws within a u429 leg are 1, 2 or 3 accepted steps apart (297 / 505 / 72 cases; none further apart). In d108 the spacings are 189 / 211 / 22 cases, with 12 further apart.
  - The thrown attempt is a median 1.58× the accepted step before it (u429). Its 90th percentile is 5.0×.
- **Sources.** `ctl_replay.R`, `ctl_anatomy.R`, `ctl_regimes.R` and `ctl_note_numbers.R`.

## 4. Stiffness

### The soil chain's diagonal at every accepted step

- **Formula.** From `tf24_environment.h`, the drainage out of layer ℓ is `K_sat (θ_ℓ/θ_s)^q`, with q = 2 n_psi + 3 = 16.14, K_sat = 163.0411, θ_s = 0.428 and Δz = 0.3 m.
  - The diagonal is λ_ℓ = −q K_sat (θ_ℓ/θ_s)^q / (θ_ℓ Δz) for 0 < θ_ℓ ≤ θ_s. Above θ_s it is 0, because K is clamped at K_sat. This gives κ = K_sat/(θ_s^q Δz) = 4.83e8 yr⁻¹.
  - Below saturation the top layer adds −rain · b (θ_1/θ_s)^b / (θ_1 Δz), with b = `b_infil` = 8.
  - At saturation the drainage term alone is q K_sat/(θ_s Δz) = 2.05e4 yr⁻¹, a relaxation time of 26 minutes.
- **State used.** The state at each step's start.

| | u429 | d108 |
|---|---|---|
| \|λ\|max, yr⁻¹: 25 / 50 / 75 / 90 / 99% / max | 70 / 725 / 3 197 / 7 392 / 16 970 / 28 300 | 175 / 1 084 / 3 708 / 8 027 / 17 500 / 31 780 |
| layer attaining it: 1 / 2 / 3 / 4 / 5 | 3974 / 481 / 485 / 588 / 5711 | 3922 / 480 / 476 / 590 / 4448 |
| h·\|λ\|max/β: 25 / 50 / 75 / 90 / 99% / max | 0.065 / 0.44 / 0.78 / 1.01 / 1.43 / 1.91 | 0.145 / 0.53 / 0.83 / 1.05 / 1.46 / 1.76 |
| accepted steps at ≥ 0.8β / above β | 2 660 (23.7%) / 1 163 (10.3%) | 2 765 (27.9%) / 1 244 (12.5%) |
| controller-ended steps at ≥ 0.8β | 2 473 of 7 881 (31.4%) | 2 587 of 6 877 (37.6%) |
| infiltration term's median share of the top layer's diagonal where it rains | 0.26 | 0.26 |

- **Error ratio against stability.** The median error ratio of accepted steps rises with h·|λ|soil/β (u429; d108 in parentheses):
  - below 0.5: 0.007 (0.011)
  - 0.5–0.8: 0.072 (0.072)
  - 0.8–1.0: 0.20 (0.20)
  - 1.0–1.2: 0.28 (0.28)
  - above 1.2: 0.014, where the drainage mode sits on its quasi-steady state.
- **Uptake.** The uptake coupling's contribution to the soil diagonal was measured by one-sided differences at the sampled points below. It is a median 1.4e-4 (u429) and 3.5e-4 (d108) of the diagonal. It dominates only in dry layers, and those layers do not carry the dominant mode.

### The whole system at sampled points

The sample is 100 points per run, each taken at its start state and time:

- 50 controller-ended accepted steps, drawn at random;
- the first rejected attempt of 25 inaccurate rejections;
- the first rejected attempt of 25 thrown rejections.

Methods:

- **d108, exact.** The exact forward-tangent Jacobian of the rates (`ladder_rhs_state_jacobian_forward_tf24`) and its full spectrum at all 100 points.
- **Iterations.** Power iteration (60 JVPs) and Arnoldi (30) on finite-difference JVPs, in error-weighted coordinates. They agree with the exact spectrum at the median (ratio 1.0000) but overestimate at member-dominated points, by up to 3.3× in d108 and 22.8× in u429.
- **Two local eigenvalues.** At all 100 d108 points the exact dominant eigenvalue equals the larger of two local eigenvalues, to within 0.92–1.0002:
  - the soil diagonal above;
  - the largest eigenvalue over members of each member's own-state block: its six strategy rates against its six strategy states, exact by forward tangent (`ctl_eig_blocks.R`).
- **u429.** The same block estimate matches the exact spectrum to four digits at all 35 u429 points whose state is at most 1300 wide (up to 159 members; `ctl_eig_exact.R`). The block estimate is used for the other u429 points.
- **The member mode is storage relaxation.**
  - The member block's dominant eigenvalue equals that member's storage diagonal ∂Ṡ/∂S (ratio 1.000–1.014).
  - This is the relaxation of the pool dS/dt = charge (1 − r) − drain r, with r = S/S_max.
  - In error-weighted coordinates its eigenvector is largest in that member's mortality and log density, which read r, or in its height, whose growth is gated on r.

| h·\|λ\|/β, whole system | accepted (50) | rejected inaccurate (25) | thrown (25) |
|---|---|---|---|
| d108 (exact): 0 / 25 / 50 / 75 / 100% | 0.019 / 0.51 / 0.72 / 1.02 / 1.32 | 0.033 / 0.22 / 0.94 / 1.19 / 2.38 | 0.33 / 0.84 / 1.57 / 1.64 / 2.77 |
| d108: points at ≥ 0.8β | 20 | 14 | 19 |
| u429 (member blocks and soil diagonal): 0 / 25 / 50 / 75 / 100% | 0.068 / 0.47 / 0.67 / 0.90 / 1.56 | 0.080 / 0.22 / 0.89 / 1.22 / 2.48 | 0.38 / 1.46 / 1.69 / 1.86 / 2.86 |
| u429: points at ≥ 0.8β | 17 | 13 | 24 |
| mode carried by a member (by the newest) | u429 13 (10); d108 6 (6) | u429 5 (2); d108 2 (2) | u429 25 (20); d108 21 (21) |

- **Soil-carried points.** At 57 u429 points and 71 d108 points soil drainage carries the dominant mode, with |λ| 165–17 500 yr⁻¹ (u429).
  - Layer 5, with the deep-drainage accumulator beside it in the eigenvector, is the most frequent carrier at accepted points (29 of 50 in d108, 26 of 50 in u429).
  - Layer 1 is the most frequent carrier at inaccurate rejections (11 of 25 in d108, 9 of 25 in u429).
- **Member-carried points.** At the other 43 u429 points the member mode carries it: |λ| 152–1260 yr⁻¹ (median 602), carried by members aged 0.004–0.12 yr, the newest at 32 of the 43. In d108 it carries 29 points: 38–755 yr⁻¹ (median 332), ages 0.12–1.7 yr, always the newest.

### Stability-limited steps, and where the rejections sit

- **Accepted steps.** 24% (u429) and 28% (d108) of all accepted steps sit at or beyond 0.8β of the soil drainage mode alone. At the sampled controller-ended steps the whole-system share is 34% (u429) and 40% (d108).
- **Inaccurate rejections.** 59.1% (u429, 1118 of 1891) and 58.5% (d108) were attempted at h·|λ|soil ≥ 0.8β.
  - By band (u429): < 0.5: 581; 0.5–0.8: 192; 0.8–1.0: 286; 1.0–1.2: 376; ≥ 1.2: 456.
  - The rest sit at small h·|λ|: the first step after a rain knot, where the error is set by the forcing rather than by stiffness (section 3).
- **Thrown attempts.** These sit beyond the stability boundary of the newest member's storage mode: whole-system h·|λ|/β median 1.69 (u429) and 1.57 (d108). By the soil diagonal they sit at a median 0.04 (u429).
- **The throw cycle.** In dry legs the proposal grows past that boundary while the error ratio stays small. The storage error enters the norm weighted by atol, so the norm barely registers it. Growth continues until a stage drives the storage below zero. The retry at 0.2× is accepted, and the growth repeats (section 3).

Sources: `ctl_eig.R` (`out/eig_*_base.log`), `ctl_eig_blocks.R`, `ctl_eig_exact.R`, `ctl_stiff_summary.R` and `ctl_note_numbers.R`.

## 5. Tolerance economics (u429 unless stated)

### (a) `ode_tol_rel = ode_tol_abs`

| tol | J | J vs tol 1e-4 | accepted | attempts | rejected (thrown) | member evaluations | CPU (s) |
|---|---|---|---|---|---|---|---|
| 1e-2 | 12.577170485 | +1.66e-4 | 9 991 | 13 430 | 25.6% (1 740) | 1.775e7 | 286.0 |
| 3e-3 | 12.576132363 | +8.4e-5 | 10 527 | 13 915 | 24.3% (1 388) | 1.866e7 | 301.5 |
| 1e-3 | 12.575093099 | +1.3e-6 | 11 239 | 14 280 | 21.3% (1 150) | 1.934e7 | 313.2 |
| 3e-4 | 12.572169221 | −2.31e-4 | 12 240 | 15 060 | 18.7% (772) | 2.054e7 | 339.5 |
| 1e-4 | 12.575076980 | 0 | 13 463 | 16 450 | 18.2% (508) | 2.247e7 | 372.7 |

- **Cost response.** Over the two decades, accepted steps scale as tol^(−0.065), attempts as tol^(−0.042), member evaluations as tol^(−0.049) and CPU as tol^(−0.056). Tightening from 1e-2 to 1e-4 costs +27% member evaluations. An accuracy-limited fifth-order step would scale as tol^(−0.2).
- **J does not converge in the tolerance.** Its spread over the five levels is 4.0e-4 relative, 3.1× the schedule's 1.3e-4 at 429.
  - The level furthest from the tightest is 3e-4, at −2.3e-4.
  - The 1.3e-6 agreement between 1e-3 and 1e-4 lies inside that spread.
  - Measured against the tightest level, the time-integration error is 1.3–1.8× the schedule error at 1e-2 and at 3e-4.
- **When the differences accrue.** J accrues almost entirely between years 12 and 28: J(12) = 0.016, J(15) = 2.46, J(18) = 8.78, J(25) = 11.93. The runs' differences from the tightest level accrue over years 12–25, as yearly changes of up to 1.5e-4 of either sign. The largest are −1.47e-4 in year 14 and +1.36e-4 in year 17 at tol 1e-2, and −9.1e-5 in year 16 at 3e-4 (`ctl_jprofile.R`).
- **Which cohorts carry them.** Cohorts born in the first 3.5 yr carry 88.0% of J, and those born in years 7–10 carry 8.8%. The same two bands carry the time-grid differences. For tol 1e-2 against 1e-4, the < 3.5 yr band contributes +1.11e-4 of the +1.66e-4 and the 7–10 yr band +7.0e-5. For 3e-4 against 1e-4 the < 3.5 yr band contributes −2.52e-4 of the −2.31e-4 (`ctl_cohorts.R`).
- **Soil at the introductions.** Against tol 1e-4, the largest soil-moisture difference at the 429 introductions is 2.6e-2 (1e-2), 1.1e-2 (3e-3), 1.4e-3 (1e-3) and 6.4e-4 (3e-4). The medians are 1.1e-5 to 7e-7.
- **d108.** J moves monotonically: 12.142452 (1e-2), 12.133777 (3e-3), 12.117230 (1e-3), 12.103591 (1e-4). That is +0.21%, +0.14% and −0.11% against 1e-3, at 8675, 9263, 9917 and 12 376 steps.

### (b) `ode_tol_abs` at `ode_tol_rel = 1e-3`

| atol | J | J vs tol 1e-4 | accepted | attempts | rejected (thrown) | member evaluations | CPU (s) |
|---|---|---|---|---|---|---|---|
| 1e-5 | 12.575607651 | +4.2e-5 | 12 487 | 15 480 | 19.3% (748) | 2.111e7 | 345.8 |
| 1e-4 | 12.573732659 | −1.07e-4 | 12 209 | 15 122 | 19.3% (877) | 2.059e7 | 339.3 |
| 1e-3 | 12.575093099 | +1.3e-6 | 11 239 | 14 280 | 21.3% (1 150) | 1.934e7 | 313.2 |
| 1e-2 | 12.580379013 | +4.2e-4 | 10 152 | 13 612 | 25.4% (1 628) | 1.802e7 | 289.4 |

Accepted steps by binding component:

| atol | soil 1 / 2 / 3 / 4 / 5 | mortality | height | storage | fecundity | E | accumulators |
|---|---|---|---|---|---|---|---|
| 1e-5 | 1921 / 1845 / 1389 / 1135 / 3366 | 2210 | 175 | 269 | 46 | 127 | 4 |
| 1e-4 | 1869 / 1756 / 1328 / 1126 / 3398 | 1883 | 392 | 239 | 54 | 164 | 0 |
| 1e-3 | 1497 / 1404 / 1086 / 1082 / 3441 | 1729 | 536 | 173 | 125 | 166 | 0 |
| 1e-2 | 1358 / 825 / 1040 / 1159 / 2986 | 1695 | 477 | 112 | 327 | 173 | 0 |

- **Tightening atol from 1e-3 to 1e-5.** Height nearly stops binding (536 → 175) and so does fecundity (125 → 46). Layers 1–2, mortality and storage bind more, and the flux accumulators first bind (4 steps).
- **Loosening atol to 1e-2.** Layer 2 (1404 → 825), layer 5 (3441 → 2986) and storage (173 → 112) bind less, and fecundity binds 2.6× more.
- **J.** J is not monotone in atol either: the spread is 5.3e-4 relative. The largest move is +4.2e-4 at atol 1e-2.
- **No members are dead.** No member holds a log density below −50. plant#88 attributes the cost of tight atol to dead members' log density, and that state does not bind a single step here. Tightening atol shifts the binding toward soil layers 1–2, mortality and storage.
- **Source.** `ctl_tol.R` (`out/tol_table.log`).

### (c) dJ/dlma by the adjoint, d108

| tol | J | steps | dJ/dlma (chained) | adjoint CPU (s) |
|---|---|---|---|---|
| 1e-2 | 12.142451651 | 8 675 | refused | 298.7 |
| 3e-3 | 12.133777235 | 9 263 | refused | 319.9 |
| 1e-3 | 12.117229796 | 9 917 | −158.593 | (512.8 s wall, `$SP/tg/adj_dyadic_108.log`) |
| 1e-4 | 12.103591134 | 12 376 | −158.898 | 417.7 |

- **Refusals.** At 1e-2 and 3e-3 the adjoint refuses every metric, with `[phylloptim:infeasible:stem_curve_domain] cumulative_vulnerability_integral_derivatives_at: (psi/b)^c = 27222.3` (1e-2) or `3378.8` (3e-3) `is past the vulnerability curve's domain (4.605170)`. A state that the looser runs step through lies outside the domain where the derivative series holds.
- **Chaining.** The 1e-3 value is the saved `tg2_adj.R` columns chained through lma → (lma, r_l, k_l, nmass_l). The same chain gives −158.59298 there.
- **Grid effect on the gradient against J.** From 1e-3 to 1e-4, dJ/dlma moves +0.19% (0.305 in magnitude) while J moves −0.11%. The time grid moves the gradient 1.7× as much as J, in relative terms. This is the only available pair.
- **Other columns.** The raw columns are 1.lma −269.020 → −269.355 and 1.establishment_window 3.688 → 3.521 (−4.5%).
- **Sources.** `ctl_chain.R` (`out/chain2.log`) and `ctl_grad_inspect.R`.

## 6. The stop set (u429, tol 1e-3)

| | stops | J | J vs (a) | accepted | attempts | rejected (thrown) | member evaluations | CPU (s) |
|---|---|---|---|---|---|---|---|---|
| (a) aligned | 2931 | 12.575093099 | 0 | 11 239 | 14 280 | 21.3% (1 150) | 1.934e7 | 313.2 |
| (b) no stops | 0 | 9.775346878 | −22.3% | 10 373 | 14 911 | 30.4% (2 049) | 1.855e7 | 294.3 |
| (c) no stops, `ode_step_size_max = 5/365` | 0 | 12.518186305 | −0.45% | 10 914 | 14 969 | 27.1% (1 557) | 1.889e7 | 302.5 |
| (d) aligned + 428 zero-depth stops at the 857-level extra birth dates | 3359 | 12.577165793 | +1.65e-4 | 11 432 | 14 381 | 20.5% (1 068) | 1.971e7 | 318.0 |

- **(b) and (c).** Against (b), the aligned stops add 866 accepted steps but remove 631 attempts: rejections fall from 30.4% to 21.3%. (a) spends 4.2% more member evaluations than (b). Its 3358 schedule entries account for 7.5% of its member evaluations, against 429 entries in (b).
  - Without stops, J's deficit accrues from year 12: −4.4% by year 15, −18% by 18, −22% by 22.
  - Capping the step at 5 days (the control is `ode_step_size_max`) leaves −0.45%.
- **(d) against (a).** The extra stops change only step placement. They move J by +1.65e-4. A decade of tolerance moves it by +1.65e-4 (1e-3 → 1e-2), 1.3e-6 (1e-3 → 1e-4) and −2.3e-4 (1e-3 → 3e-4). Placement therefore moves J as much as the tolerance does, and more than the schedule error of 1.3e-4.
- **What the placement changes.**
  - **Cost.** 193 more accepted steps (428 more legs), 101 more attempts and 82 fewer throws. Member evaluations +1.9%.
  - **Where J moves.** The J difference accrues between years 12 and 23: +4.8e-5 in year 13, −2.5e-5 in 14, +7.8e-5 in 15, +1.6e-5 in 16 and +3.3e-5 in 23. Every other year moves it by less than 1e-5 (`ctl_checks.R`). Cohorts born before 3.5 yr carry 1.32e-4 of it, and those born in years 7–10 carry 3.2e-5.
  - **Along the record.** At the active knots, which both runs land on, the largest soil-moisture difference in a year reaches 2.7e-3 (years 10–11), and the largest log-density difference over members is 0.003 to 0.015.
  - **Saturation-excess switch.** The switch is `max(0, 1 − a_infil (θ_1/θ_s)^b_infil)` in `TF24_Environment::compute_rates`, tallied as the `infiltration` clamp when the bracket is negative.
    - No accepted step of (a)–(d), or of any run at tol ≤ 3e-3, ends with the top layer above θ_s. The switch is crossed 0 times along those records.
    - At tol 1e-2, 49 accepted steps end above θ_s and the record crosses θ_s 86 times.
    - Stage evaluations beyond the switch number 935 (a), 916 (d), 2578 (b) and 2499 (c).
    - Along the tolerance ladder they number 2998, 1650, 935, 563 and 322 (1e-2 … 1e-4).
    - The other stage-level soil clamps move with them. `soil_conductivity` (θ outside [0, θ_s]) goes 3894 (a) / 3785 (d), and 16 410 … 1 215 along the ladder. `soil_moisture_floor` goes 962 / 906, and 3760 … 292.
  - **The inner problem's classification** (`census_operating_point_counts_tf24`, counts over every solve of the forward run):

    | | interior | boundary-crit | boundary-root-crit | determined | hydraulic-shutdown |
    |---|---|---|---|---|---|
    | (a) | 16 600 168 | 2 881 864 | 140 | 18 715 | 13 668 |
    | (d) | 16 979 055 | 2 877 152 | 138 | 17 698 | 12 400 |
    | (d) − (a) | +378 887 | −4 712 | −2 | −1 017 | −1 268 |
    | (b) | 15 414 341 | 3 197 176 | 367 | 16 000 | 59 958 |
    | (c) | 15 866 849 | 3 090 556 | 308 | 18 103 | 71 317 |
    | tol 1e-2 | 14 739 408 | 3 068 404 | 202 | 71 705 | 24 037 |
    | tol 1e-4 | 20 264 870 | 2 407 803 | 76 | 860 | 4 454 |

    - Placement cuts hydraulic-shutdown solves by 9.3% and determined solves by 5.4%, which is −11% and −7% per member evaluation.
    - Along the tolerance ladder, hydraulic-shutdown solves fall 5.4× (24 037 → 4 454) and determined solves 83× (71 705 → 860) from 1e-2 to 1e-4. The boundary-crit share falls from 17.1% to 10.6%.
    - The counts are run totals and include rejected attempts' stages. Transitions per member along the record were not counted.
- **Sources.** `ctl_placement.R` (`out/placement.log`), `ctl_jprofile.R`, `ctl_cohorts.R` and `ctl_tol.R`.

## 7. What an integrator free of the two stiff modes could save

This is an offline bound from the recorded u429 and d108 runs at tol 1e-3. It removes the stability limits of soil drainage and of the members' storage relaxation, keeping the accuracy limit and the schedule entries. It does not count an implicit or IMEX method's own cost, and it is not a claim that any method achieves it.

### Method

- **The two stiff modes at every accepted step.** The soil drainage diagonal is the one from section 4. Each member's storage diagonal ∂Ṡ/∂S was taken at the step's start by one directional difference over every member's storage at once, each diagonal read from that member's own storage rate (`ctl_storage_diag.R`).
  - Against the exact member-block eigenvalue at the 100 sampled points of each run, the ratio is 0.990–1.000 (u429) and 0.972–1.000 (d108).
  - The largest storage diagonal is a median 188 yr⁻¹ (u429) and 44 yr⁻¹ (d108), maximum 1444 and 1031.
  - It belongs to the newest member at 84% (u429) and 96.5% (d108) of steps, and to one of the newest three at 100% and 98.5%.
- **Accuracy-limited steps.** A step counts as accuracy-limited where h·|λ|max/β < 0.5, with |λ|max the larger of the two diagonals: 4762 of 11 239 steps (u429) and 4329 of 9916 (d108).
- **The ratio without the stiff components.** Every accepted step was re-taken (`ctl_rns.R`). The re-take reproduces the recorded ratio at all 11 239 and 9916 steps. Its weighted ratio was then recomputed without:
  - each soil layer with h·|λ_ℓ| ≥ 0.5β, together with the accumulator fed by layer 1's infiltration or layer 5's drainage when that layer is out;
  - all eight states of each member with h·|λ_j| ≥ 0.5β, because the storage mode's eigenvector is largest in that member's mortality, log density or height.

  At the 6477 (u429) and 5587 (d108) steps carrying such a component, the median ratio falls from 0.073 to 0.0053 (u429) and from 0.094 to 0.0097 (d108). The ratio is then set by the other soil layers at 4 461 and 4 390 of those steps, and by member fecundity, mortality, height or storage at 1 861 and 1 125.
- **Local accuracy limit.** Each measured step k gets a_k = h_k · max(1, min(5, 0.9 r^(−1/5))).
  - r is the recorded ratio where the step is accuracy-limited, and the ratio without the stiff components elsewhere.
  - The floor at h_k holds because every accepted step was admissible. The cap at 5 is the controller's growth clamp.
  - A clipped step takes the larger of its own limit and that of the step before it in the leg.
- **Filling the legs** between consecutive schedule entries:
  - I1: ceil(Σ h_k / a_k) steps, that is, ∫dt/a over the leg.
  - I2: the controller's own walk. The proposal is min(5h, `ode_step_size_max`); each step is at most the smallest a over the span it covers; steps are clipped at entries, with the proposal carried across the clip as the solver does.
- **Assumptions.**
  - No rejected attempt and no throw.
  - The same schedule entries, and the same members in each leg, as the explicit run.
  - The error ratio scales as h⁵.
  - The stiff components, and a stiff member's other states, impose no accuracy limit beyond what the rest of the state imposes. This is the optimistic assumption. It holds where those components sit on their quasi-steady state.
  - The cost of a member evaluation is unchanged.
- **The first-specified estimator overcounts.** A per-leg h_acc built only from accuracy-limited steps gives 10 522–16 677 accepted steps (u429) and 10 005–12 651 (d108). The variants are per-leg maximum or median, running medians of 9, 25 or 101 samples, clipped steps included, threshold 0.25, unclamped, and the walk. The range runs from −6% to +48% against the measured count.
  - 2240 of 3358 u429 legs (2074 of 3039 d108) contain no controller-ended accuracy-limited step and take their h_acc from other legs.
  - 797 legs (637) then need more steps than measured: 3626 (3864) extra steps in all.
  - That estimator ignores that every measured step was admissible, and is not used below (`ctl_ideal.R`, `out/ideal_*_base.log`).

### Counts

u429 (measured: 11 239 accepted steps, 89 353 rate evaluations, 1.934e7 member evaluations):

| estimate | accepted steps | rate evaluations, 2 / 1 per entry | member evaluations, 2 / 1 per entry | member evaluations saved, 2 / 1 per entry |
|---|---|---|---|---|
| no stability credit (a = h at stability-affected steps), I1 | 9 869 (−12.2%) | 65 930 / 62 572 | 1.427e7 / 1.354e7 | 26.2% / 30.0% |
| stiff components out, I2 walk | 8 887 (−20.9%) | 60 038 / 56 680 | 1.299e7 / 1.227e7 | 32.8% / 36.6% |
| **stiff components out, I1** | **6 722 (−40.2%)** | **47 048 / 43 690** | **1.016e7 / 9.430e6** | **47.5% / 51.2%** |
| stiff components out, unclamped, I1 | 6 497 (−42.2%) | 45 698 / 42 340 | 9.877e6 / 9.149e6 | 48.9% / 52.7% |
| stiff components at 0.25β out, I1 | 6 152 (−45.3%) | 43 628 / 40 270 | 9.440e6 / 8.712e6 | 51.2% / 55.0% |
| stop-limited floor: one step per leg | 3 358 (−70.1%) | 26 864 / 23 506 | 5.823e6 / 5.095e6 | 69.9% / 73.7% |

d108 (measured: 9 916 accepted steps, 78 871 rate evaluations, 7.601e6 member evaluations):

| estimate | accepted steps | rate evaluations, 2 / 1 per entry | member evaluations, 2 / 1 per entry | member evaluations saved, 2 / 1 per entry |
|---|---|---|---|---|
| no stability credit, I1 | 8 917 (−10.1%) | 59 580 / 56 541 | 5.731e6 / 5.440e6 | 24.6% / 28.4% |
| stiff components out, I2 walk | 8 047 (−18.8%) | 54 360 / 51 321 | 5.228e6 / 4.938e6 | 31.2% / 35.0% |
| **stiff components out, I1** | **6 254 (−36.9%)** | **43 602 / 40 563** | **4.188e6 / 3.898e6** | **44.9% / 48.7%** |
| stiff components out, unclamped, I1 | 6 105 (−38.4%) | 42 708 / 39 669 | 4.103e6 / 3.812e6 | 46.0% / 49.8% |
| stiff components at 0.25β out, I1 | 5 739 (−42.1%) | 40 512 / 37 473 | 3.891e6 / 3.601e6 | 48.8% / 52.6% |
| stop-limited floor: one step per leg | 3 039 (−69.4%) | 24 312 / 21 273 | 2.322e6 / 2.032e6 | 69.4% / 73.3% |

- The median local limit is 2.96 (u429) and 2.44 (d108) times the measured step. Removing the ×5 cap lowers the I1 count by 3.3% (u429) and 2.4% (d108), so the estimate is not driven by extrapolation from small ratios.
- The I1 fill needs no more steps than measured in any leg. The I2 walk needs more in 184 legs of each run (379 and 377 extra steps), where its span rule and growth ramp are stricter than the measured sequence.
- With no evaluation at a knot stop, where a zero-depth pulse changes no state, and one at an introduction, the I1 estimate needs 8.80e6 (u429) and 3.61e6 (d108) member evaluations: 54.5% and 52.5% saved.

### The saving by source (I1 estimate, as a share of the measured member evaluations)

| source | u429 | d108 |
|---|---|---|
| accepted steps removed by the stability credit (I1 minus the no-credit fill) | 21.3% | 20.3% |
| accepted steps removed without it (steps short for other reasons, including the retries after rejections) | 9.2% | 7.7% |
| thrown attempts (the storage mode) | 4.3% | 2.3% |
| inaccurate attempts at soil h·\|λ\| ≥ 0.8β | 7.5% | 8.6% |
| inaccurate attempts below 0.8β (the first steps after rain knots) | 5.2% | 6.1% |
| the second evaluation at each schedule entry | 3.8% | 3.8% |
| **total** | **51.2%** | **48.7%** |

- **By the three sources.** Stability (accepted steps, first two rows) is 59.5% of the saving (u429) and 57.4% (d108). Rejections are 33.2% and 34.7%. The double evaluation at schedule entries is 7.3% and 7.8%.
- **Attributable to the two stiff modes.** The stability credit, the throws and the inaccurate rejections at ≥ 0.8β add up to 33.1% (u429) and 31.2% (d108) of the measured member evaluations.
  - Under the I2 walk the stability credit is 15.5% and 14.8% (walk against the walk without credit), and the total attributable is 27.3% and 25.6%.
  - The other 18.2% (u429) and 17.6% (d108) need no stiff treatment: the forcing-driven rejections, the steps short for other reasons, and the second entry evaluation.

Sources: `ctl_ideal.R` and `ctl_ideal_split.R` (`out/ideal_split.log`).

### Where the saving sits

Legs are classed by the gap between the active knots enclosing them. Daily legs are wet (knots 1 day apart); multi-day legs are dry.

| I1 estimate | u429 daily (wet) | u429 multi-day (dry) | d108 daily (wet) | d108 multi-day (dry) |
|---|---|---|---|---|
| legs; days | 2318; 2 250 | 1040; 12 350 | 2263; 2 250 | 776; 12 350 |
| share of measured member evaluations | 58.7% | 41.3% | 65.7% | 34.3% |
| accepted steps per leg, measured → I1 → I2 | 2.65 → 1.98 → 2.38 | 4.90 → 2.04 → 3.23 | 2.67 → 2.00 → 2.40 | 4.99 → 2.23 → 3.38 |
| saved, share of the class's own cost | 43.2% | 62.6% | 43.1% | 59.5% |
| share of the whole saving | 49.6% | 50.4% | 58.2% | 41.8% |
| of it: stability credit | 1.57e6 | 2.54e6 | 7.07e5 | 8.36e5 |
| of it: accepted steps without credit | 4.43e5 | 1.34e6 | 1.76e5 | 4.08e5 |
| of it: thrown | 2.9e4 | 7.97e5 | 3.5e3 | 1.72e5 |
| of it: inaccurate (≥ 0.8β / below) | 1.42e6 / 9.48e5 | 4.4e4 / 5.7e4 | 6.18e5 / 4.32e5 | 3.2e4 / 3.0e4 |
| of it: second entry evaluation | 5.03e5 | 2.25e5 | 2.19e5 | 7.1e4 |

- **u429.** The saving splits evenly between wet and dry legs.
  - Wet legs are 15% of the time and 59% of the cost. Their saving is 43% of their cost, half of it inaccurate rejections.
  - Dry legs save 63% of their cost, mostly stability credit, steps short for other reasons, and throws.
  - The stability credit itself sits 38% in wet legs and 62% in dry ones (d108: 46% and 54%).
- **d108.** Wet legs carry 58% of the saving.
- **By regime.** Of the I1 saving, 84% (u429) falls in the wet years, 16% in the drought years and 0.7% in the first 3.5 years. Each regime saves 46–52% of its own cost.

## Expectations against the measurements

- **"Steps are accuracy-limited at the median": contradicted.**
  - The median accepted step has error ratio 0.030 (u429) and 0.040 (d108). Only 8–10% of steps reach r ≥ 0.5.
  - The step count responds to tolerance as tol^(−0.065) over 1e-2 … 1e-4.
  - The steps are shortened by several things instead:
    - knot and introduction stops (30% of steps clipped, to a median one third of the proposal);
    - the proposal carried unchanged across each clipped step;
    - stability of soil drainage (24–28% of accepted steps at ≥ 0.8β, 31–38% of controller-ended ones);
    - the throw cycle of the newest member's storage.
- **"The soil chain binds most steps": confirmed.** Soil binds 75.7% (u429) and 85.8% (d108) of steps. Layer 5 alone binds 31% and 35%. The flux accumulators never bind at atol ≥ 1e-4. Members bind 22.8% and 12.0%, mostly through the newest member's mortality.
- **"Rejections are ~17% of attempts": contradicted as stated.** They are 21.3% (u429) and 19.8% (d108) of attempts, and 17.0% / 16.9% of rate and member evaluations. The two differ because a thrown attempt stops after 3.35 evaluations, and throws are 38% (u429) and 22% (d108) of the rejections.
- **"Knot stops end ~25% of steps": approximately confirmed.** Knot stops end 26.1% (u429) and 29.6% (d108) of steps. With introductions, 29.9% and 30.6% of steps are clipped.
- **"Loosening tolerance tenfold moves J by less than the schedule error": contradicted.** From 1e-3 to 1e-2, J moves +1.65e-4 (u429), against the schedule's 1.3e-4. From 1e-3 to 3e-4 it moves −2.3e-4. Step placement alone moves it +1.65e-4. On d108, 1e-3 → 1e-2 moves J +0.21%.

## What was not reached

- **u429 exact spectra.** No exact whole-system spectrum was taken for u429 states wider than 1300 (more than 159 members). The block estimate used there is validated on all 100 d108 points and 35 u429 points. The finite-difference iterations are unreliable at member-dominated u429 points.
- **Classification transitions.** Changes of the inner problem's classification were not counted as transitions per member along the record. The census gives run totals only, and the totals mix accepted and rejected attempts' stages.
- **Where the switch is crossed.** Which attempts, accepted or rejected, carry the stage-level saturation-switch and soil-clamp crossings was not resolved.
- **Gradient at loose tolerance.** The adjoint refused at 1e-2 and 3e-3, so the gradient's time-grid sensitivity rests on the one pair 1e-3 / 1e-4.
- **Coverage.** No tolerance ladder, atol ladder or stop-set variant was run on d108 beyond the four tolerance levels of (c). The regime split was not repeated for the ladder runs.
- **Timings.** CPU and wall seconds are contaminated by the shared machine and are secondary to the counts.
- **The section 7 bound.** It is taken at tol 1e-3 only. It does not count an implicit method's own cost or the rejections such a method would still meet at rain knots. It does not measure the stiff components' own accuracy demand; that demand is assumed not to bind.

## Scripts and outputs

All in `$SP/perf/controller`. Logs and saved outputs are in `out/`.

- `ctl_common.R`: the fixture, copied from `run_J` and extended with separate rtol/atol, the maximum step, CPU time and the census tallies.
- `ctl_run.R`: one recorded run. Tags `u429_base`, `d108_base`, `u429_t{1e-2,3e-3,3e-4,1e-4}`, `u429_a{1e-5,1e-4,1e-2}`, `u429_nostops`, `u429_nostops_h5d`, `u429_aligned857`, `d108_t{1e-2,3e-3,1e-4}_g`.
- `ctl_rk.R`, `ctl_rk_check.R`: the solver's attempt in R, and its bit-identity check.
- `ctl_replay.R`: every attempt of a run, recovered.
- `ctl_anatomy.R`, `ctl_regimes.R`, `ctl_misc.R`: sections 1–3.
- `ctl_eig.R`, `ctl_eig_blocks.R`, `ctl_eig_exact.R`, `ctl_stiff_summary.R`: section 4.
- `ctl_tol.R`, `ctl_chain.R`, `ctl_grad_inspect.R`: section 5.
- `ctl_placement.R`, `ctl_jprofile.R`, `ctl_cohorts.R`: sections 5–6.
- `ctl_storage_diag.R`, `ctl_rns.R`, `ctl_ideal.R`, `ctl_ideal_split.R`: section 7.
- `ctl_note_numbers.R`, `ctl_checks.R`: figures quoted above that no other script prints.
- `lane.sh`, `worker.sh`: job runners.
- `probe_iface.R`, `test_small.R`: one-year interface probes.
