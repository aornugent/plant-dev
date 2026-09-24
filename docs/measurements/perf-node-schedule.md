# TF24 SCM node schedule at fixed accuracy: where accuracy costs, what refine_schedule does, how lean a fixed schedule can be

## Configuration

- TF24 SCM, one species, `lma = 0.32`, `max_patch_lifetime = 40`, `node_density_in_birth_date = TRUE`.
- Forcing `long-drought`: 14 599 daily control points in range; multi-year droughts in rainfall years 8–10, 19–22 and 32–34 (patch age 7–10, 18–22, 31–34).
- Aligned: a zero-depth rainfall pulse at each of the 2931 active knots.
- `ode_tol_rel = ode_tol_abs = 1e-3`, `establishment_window = 0.05`.
- `plant` at `6613dd24`, the built `-O2` worktree `plant-adj`, loaded through `tg/tg2_common.R`. `plant-adj/src/plant.so` read `2026-09-23 13:14:26.561414` before and after every run.
- `J = sum(scm$offspring_production)`: the trapezium over the node times `b` of `w(b)`, a node's lifetime offspring weighted by patch-age density and `S_D`.
- **Cost counts.** "Steps" is `length(ode_step_sizes)` (accepted steps + 1, as `run_J` reports it). **Σ M** is the sum over accepted steps of the members alive at the step's start. Rejected attempts are counted apart: rejected on error, and rejected because a rate evaluation threw. The runs shared four cores with six to ten other processes; wall seconds are not used, CPU seconds are given where a table needs a time.
- **Reference.** `J∞ = 12.573422`, the order-3 extrapolation of uniform 429 / 857 / 1713. Relative error is `(J − J∞) / J∞`.
- "Uniform n" is `n` nodes evenly over `[0, 39.63]`: spacing 0.370 / 0.185 / 0.159 / 0.124 / 0.104 / 0.093 / 0.046 / 0.023 yr (135 / 68 / 58 / 45 / 38 / 34 / 17 / 8.5 d) at 108 / 215 / 250 / 320 / 380 / 429 / 857 / 1713.

## Key numbers

| | |
|---|---|
| **Reproduced** | default 108: `J = 12.117229796` at 9917 steps (Σ M 955 535). Uniform 429: `J = 12.575093099` at 11 240 steps (Σ M 2 432 505). |
| **Re-roll floor** | Uniform 429 with every node but `b = 0` moved by 1e-5, 3e-5 or 1e-4 yr reads J +6.5e-5, −5.9e-5, −6.2e-5 from the unmoved run: **sd 6.0e-5 of J over four runs**. The step sequence alone sets J to that level at `ode_tol = 1e-3`; the uniform ladder's last step (1.4e-5) is inside it. |
| **Where J and the cost are** | 72% of J from members born before `b = 1`, 88% before 3.56, 3.6e-5 after 22. A member born at `b = 0` costs 1.98× the mean member at every uniform level. Members born after 16 take 37% of Σ M, after 22, 21%. |
| **Where the error is** | 96% of uniform 215's +1.38e-2 is the stand's response, not J's own trapezium. The uniform-429 midpoints of `[6, 16)` alone move J by −0.1746, **101% of the 215 → 429 change, at 35% of its added Σ M**; members born there carry 10.5% of J. Filling `[0, 3.56)` removes 0.037 of trapezium error and the stand gives back 0.028. |
| **Dead bands and tail** | Uniform 429 without its 64 nodes inside the 56 dead bands: **−7.29e-2**. Uniform 215 with its nodes past `b = 22` thinned to one per 2 yr: J moves by −1.48e-3 of J, while the members born there carry 3.6e-5 of J. |
| **refine_schedule** | Every flag in every loop is the competition term's; the reproduction term set none alone. From the default at eps 2e-2 / 2e-3 / 2e-4 it stops after 6 / 8 / 11 runs at 178 / 390 / 957 nodes, **−1.32e-2 / −2.31e-3 / −5.60e-4**, for 7.3 / 15.3 / 44.8 M member evaluations over its runs; from uniform 108 at 2e-2, 4 runs, 140 nodes, +1.17e-2. 59% of its 1233 flags fall past `b = 16`, where the band fills move J by less than the re-roll floor; 6% before 3.56. |
| **Lean fixed schedules** | cw108, the cost-weighted design read off one uniform-108 run, is under 1e-3 at 100 nodes with Σ M 763 296 (+7.1e-4): 2.8× under uniform's least (380 nodes, 2 142 437). It stays under 1e-3 from 220 nodes (1 764 211, −5.4e-4): 1.2× under uniform. Its error is not monotone in the count (150: +2.1e-3, 180: −4.0e-3). No tail, rainfall-only or band-informed design beat it at any target. Under 1e-4 only inside the floor: cw108 320 (2 629 412), uniform 857 (5 029 471). |
| **Nested grid** | Along the uniform ladder `steps = 10 732 + 0.95 × nodes`; introductions end 1.0% (108 nodes) to 14% (1713) of the steps, the rainfall stops 24–30%. Over the 57 runs of 100–440 nodes, steps range 9 917–11 248 (±6.3%) while Σ M ranges 5.7×. |

## 1. Reproduction and the re-roll floor

| run | nodes | J | steps | Σ M | CPU s |
|---|---|---|---|---|---|
| default | 108 | 12.117229796 | 9 917 | 955 535 | 131 |
| uniform | 429 | 12.575093099 | 11 240 | 2 432 505 | 317 |

Both reproduce the fixture to every digit (`sc_repro.R`).

**The step sequence moves J by 6e-5 of itself.** Uniform 429 with every node but `b = 0` moved by δ (`sc_noise.R`, `sc_noise_summary.R`):

| δ (yr) | J | steps | against the unmoved run | against J∞ |
|---|---|---|---|---|
| 0 | 12.575093099 | 11 240 | | +1.33e-4 |
| 1e-5 | 12.575907553 | 11 248 | +6.48e-5 | +1.98e-4 |
| 3e-5 | 12.574347106 | 11 233 | −5.93e-5 | +7.36e-5 |
| 1e-4 | 12.574315946 | 11 246 | −6.18e-5 | +7.11e-5 |

- sd over the four 6.0e-5 of J, range 1.27e-4. The trapezium's own share of a move by δ (the first panel's `δ (w(0) − w(h)) / 2`) is 6e-7 to 6e-6 of J at these δ; the rest is the controller landing its steps elsewhere once the introduction stops move.
- **Relative errors under about 1e-4 are not attributable to the schedule at `ode_tol = 1e-3`.** The ladder's step from 857 to 1713 (−1.79e-4 in J, 1.4e-5 of it) is smaller than this spread, so the order-3 reading of 429 / 857 / 1713, and `J∞` itself, are not established below it by these runs.
- **Placement at fixed spacing** (`sc_q1.R`). The saved half-spacing-shifted grids against uniform 1713: shifted 857 reads +4.01e-4, uniform 857 +1.42e-5. The trapezium alone (the 1713 run's `w` at each grid's nodes, which both share with 1713 exactly) is +3.03e-4 and +5.6e-5. By band, `[0, 3.56)` gives +1.78e-4 and +1.65e-4, and `[6, 10)` +1.74e-4 and −1.82e-4: at 17-day spacing the trapezium over the post-drought recruitment still depends on where the nodes fall.

## 2. Where accuracy costs and where it is cheap

### 2.1 The integrand, the member cost and the trapezium's local term

Uniform 1713 (`tg/out/fdJ_uniform_1713.rds`; `sc_q1.R`). A member's cost is the accepted steps after its birth. The local term is `|w''| / 12`, from second differences of `w` on the 1713 grid: the trapezium's error per unit birth date per unit squared spacing. Node by node in `out/profile_uniform_1713.csv`; in 0.25-yr bins in `sc_q1.log`.

| birth band | share of J | max w | member cost / mean member | share of Σ M, uniform 215 | share of Σ M, uniform 1713 | mean \|w''\| / 12 |
|---|---|---|---|---|---|---|
| [0, 0.5) | 0.506 | 16.9 | 1.95 | 0.027 | 0.025 | 0.59 |
| [0.5, 1) | 0.213 | 8.28 | 1.93 | 0.027 | 0.025 | 1.46 |
| [1, 3.56) | 0.162 | 3.30 | 1.86 | 0.121 | 0.119 | 0.22 |
| [3.56, 6) | 0.0125 | 0.142 | 1.72 | 0.104 | 0.107 | 0.76 |
| [6, 10) | 0.0931 | 1.28 | 1.56 | 0.152 | 0.156 | 1.74 |
| [10, 16) | 0.0119 | 0.0723 | 1.33 | 0.205 | 0.202 | 0.19 |
| [16, 22) | 0.00123 | 0.0094 | 1.05 | 0.156 | 0.158 | 0.022 |
| [22, 40] | 3.6e-5 | 6.2e-4 | 0.47 | 0.209 | 0.207 | 1.0e-4 |

- `w` falls from 16.9 at `b = 0` by about half every 0.35 yr to `b ≈ 3.3`. Past the first dead band (`b = 3.56`) its largest value is 1.28, at `b = 7.96`: recruitment after the first drought.
- A member born at `b = 0` costs 1.978 / 1.983 / 1.982 / 1.981 / 1.979 × the mean member at 108 / 215 / 429 / 857 / 1713 nodes. Accepted steps run at 156–496 per year of patch age, fewest in drought years (`sc_q1.log`).
- Members born after `b = 16` carry 1.3e-3 of J and take 37% of Σ M; after 22, 3.6e-5 and 21%.

### 2.2 The local term against dropped nodes

For each coarser uniform level, the trapezium's own error is the trapezium of the 1713 run's `w` on the coarse nodes minus its trapezium on all 1713 nodes (exact: the ladder is nested). Beside it, the local term `(H³ / 12) w''` summed over the coarse panels, `w''` averaged over each panel from the 1713 grid (`sc_q1.R`). J units.

| band | 215: trapezium | 215: local term | 429: trapezium | 429: local term | 429: Σ \|panel\| | 857: trapezium | 857: local term |
|---|---|---|---|---|---|---|---|
| [0, 1) | +0.02755 | +0.02738 | +0.00701 | +0.00761 | 0.00839 | +0.00149 | +0.00190 |
| [1, 3.56) | +0.01963 | +0.02049 | +0.00391 | +0.00427 | 0.00391 | +0.00059 | +0.00094 |
| [3.56, 6) | −0.00056 | +0.00143 | −0.00165 | +0.00005 | 0.00669 | +0.00050 | +0.00014 |
| [6, 10) | −0.03270 | −0.00235 | +0.00518 | −0.00028 | 0.04655 | −0.00229 | −0.00007 |
| [10, 16) | −0.00778 | +0.00076 | −0.00090 | +0.00019 | 0.00430 | +0.00039 | +0.00005 |
| [16, 40] | +0.00018 | +0.00002 | −0.00003 | +0.00001 | 0.00067 | +0.00003 | 0.00000 |
| all | +0.00631 | +0.04772 | +0.01352 | +0.01185 | | +0.00070 | +0.00296 |

- **Before `b = 3.56` the local term is the trapezium's error**, to 0.6–9% at 215 and 429, where `w` is smooth.
- **Past it the local term does not describe the error.** Over `[3.56, 16)` the panel errors are one to two orders larger than the local term and cancel between panels: at 429, `[6, 10)`'s panels sum to +0.0052 and to 0.0466 in absolute value. The gate's openings (40 d, 10–90%) and closings (18 d) are not resolved by 34-day panels.

### 2.3 Uniform 215's error, by birth band

`J(215) − J(1713) = +0.174063` (1.38e-2 of J∞), split per coarse panel into the trapezium's own error (2.2) and **the stand's response**: the 215 run's `w` against the 1713 run's at the same nodes (`sc_q1.R`).

| band | total | trapezium | stand | mean of w₂₁₅ / w₁₇₁₃ − 1 |
|---|---|---|---|---|
| [0, 1) | +0.11268 | +0.02755 | +0.08514 | +1.1% |
| [1, 3.56) | +0.06413 | +0.01963 | +0.04451 | +2.2% |
| [3.56, 6) | +0.00388 | −0.00056 | +0.00444 | +2.7% |
| [6, 10) | −0.00230 | −0.03270 | +0.03040 | +2.4% |
| [10, 16) | −0.00433 | −0.00778 | +0.00345 | +2.4% |
| [16, 40] | 0.00000 | +0.00018 | −0.00018 | −1.5% on [16, 22) |
| all | **+0.17406** | **+0.00631** | **+0.16775** | |

- **96% of uniform 215's error is the stand's.** Under the 215 schedule, members born before `b = 16` have on average 1.1–2.7% more lifetime offspring than under 1713. Members born before 3.56 carry 102% of the error because they carry 88% of J.
- The same split, relative to J∞ (`sc_q3.R`): uniform 250 trapezium +7.9e-4, stand +1.12e-3; uniform 320 −9.5e-4, +7.60e-3; uniform 380 −3.9e-4, −4.8e-4; uniform 429 +1.08e-3, −9.45e-4, which cancel to +1.3e-4.

### 2.4 Which nodes the stand needs: band fills

Uniform 215 with the uniform-429 midpoints added inside one band at a time (`sc_bands.R`, `sc_q1_bands.R`). ΔJ is against uniform 215; trapezium and stand split it as in 2.3.

| band filled | nodes added | ΔJ | trapezium | stand | ΔΣ M | ΔJ per 10⁶ Σ M | share of J(429) − J(215) |
|---|---|---|---|---|---|---|---|
| [0, 0.5) | 3 | −0.00514 | −0.00690 | +0.00175 | 32 027 | −0.161 | 3.0% |
| [0.5, 1) | 2 | −0.00124 | −0.01443 | +0.01318 | 20 943 | −0.059 | 0.7% |
| [1, 3.56) | 14 | −0.00191 | −0.01492 | +0.01302 | 143 412 | −0.013 | 1.1% |
| [3.56, 6) | 13 | +0.00062 | −0.00088 | +0.00149 | 123 562 | +0.005 | −0.4% |
| **[6, 10)** | 22 | **−0.09551** | +0.03767 | −0.13320 | 188 749 | **−0.506** | **55.4%** |
| **[10, 16)** | 32 | **−0.07913** | +0.00687 | −0.08601 | 241 453 | **−0.328** | **45.9%** |
| [16, 22) | 33 | +0.00456 | −0.00021 | +0.00477 | 199 175 | +0.023 | −2.6% |
| [22, 40) | 95 | +0.00042 | −0.00000 | +0.00042 | 274 591 | +0.002 | −0.2% |
| sum of fills | 214 | −0.17734 | +0.00721 | −0.18456 | 1 223 912 | | 102.9% |
| uniform 429 | 214 | −0.17242 | +0.00721 | −0.17963 | 1 248 688 | | 100% |

- **The fills add up**: their sum is within 0.0049 (2.9%) of the whole 215 → 429 change.
- **Accuracy is bought in `[6, 16)`**, the cohorts recruited after the first drought takes the canopy: 101% of the change for 35% of the added Σ M. Those members carry 10.5% of J; the J they move is the stand's, felt by the members born before them.
- **Where J lives, filling is a wash at this level**: over `[0, 3.56)` the fills remove 0.037 of trapezium error and the stand answers +0.028.
- **The tail thins freely only down to 0.185 yr**: 95 midpoints in `[22, 40)` move J by +3e-5 of J (inside the floor) for 22% of the added Σ M. Thinned further, to 2 yr, it moves J by −1.48e-3 of J (section 4).

## 3. refine_schedule on the averaged model

`SCM::refine_schedule` run one iteration at a time (`sc_refine.R`). Each run is taken at `S_D = 0`, which enters only the offspring weights: `refinement_error_by_node` then returns the competition term alone, and the reproduction term and J are rebuilt from the unweighted fecundity with `plant:::trapezium` and `plant:::local_error_integration`. Checked in `sc_check_terms.R`: at `S_D = 0`, J, the step times and the reproduction term are bit-identical to a run at the default `S_D`, and the two terms recombine to that run's `refinement_error_by_node` bit for bit; `SCM$refine_schedule()` at `schedule_nsteps = 2` installs the emulation's second bisection (147 nodes) exactly, and its last run's J equals the emulation's second. A loop shares a schedule's run with any other loop that reaches the same schedule (all loops from the default share their first).

| start | eps | runs | stopped | nodes, last run | J, last run | rel. error | Σ M, last run | Σ M, all runs | flags (competition / reproduction / reproduction alone) |
|---|---|---|---|---|---|---|---|---|---|
| default | 0.02 | 6 | no flag | 178 | 12.407367 | -1.32e-02 | 1 392 441 | 7 316 788 | 70 / 5 / 0 |
| default | 0.002 | 8 | no flag | 390 | 12.544393 | -2.31e-03 | 2 671 747 | 15 342 593 | 282 / 24 / 0 |
| default | 0.0002 | 11 | no flag | 957 | 12.566382 | -5.60e-04 | 6 392 986 | 44 798 127 | 849 / 115 / 0 |
| uniform108 | 0.02 | 4 | no flag | 140 | 12.721103 | +1.17e-02 | 800 876 | 2 863 276 | 32 / 2 / 0 |

Per iteration (`sc_q2.log`): nodes, relative error of that run's J, and the largest indicator.

| loop | nodes | rel. error | largest indicator |
|---|---|---|---|
| default, 2e-2 | 108, 124, 147, 165, 176, 178 | −3.63e-2, −4.00e-2, −4.66e-3, −9.66e-3, −1.31e-2, −1.32e-2 | 0.307, 0.152, 0.0733, 0.0651, 0.0384, 0.0194 |
| default, 2e-3 | 108, 138, 176, 238, 294, 350, 385, 390 | −3.63e-2, −3.67e-2, +2.30e-3, +3.43e-3, −2.64e-4, −2.08e-3, −2.31e-3, −2.31e-3 | 0.307, 0.154, 0.0742, 0.0403, 0.0153, 0.0080, 0.00327, 0.00199 |
| default, 2e-4 | 108, 154, 219, 297, 436, 610, 789, 915, 949, 955, 957 | −3.63e-2, −3.67e-2, +2.11e-3, +6.36e-3, +2.62e-3, +5.68e-4, −2.95e-4, −5.32e-4, −5.63e-4, −5.60e-4, −5.60e-4 | 0.307, 0.154, 0.0742, 0.0402, 0.0154, 0.00622, 0.00192, 0.00160, 0.000798, 0.000399, 0.000199 |
| uniform 108, 2e-2 | 108, 127, 138, 140 | +5.59e-2, +1.82e-2, +1.18e-2, +1.17e-2 | 0.382, 0.142, 0.0402, 0.0191 |

- **Flags.** The competition term exceeded eps at every flagged node; the reproduction term exceeded it at 5 / 24 / 115 / 2 of them, always beside the competition term. At `S_D = 0` the competition term is read alone, so this count is exact, not inferred from the combined maximum.
- **The indicator now falls at every bisection**, in all four loops. Before the averaged gate it rose twice.
- **J does not follow it.** At eps 2e-2 the loop passes within 4.7e-3 of J∞ at its third run and stops at −1.32e-2 three runs later; at 2e-3 it passes −2.6e-4 at its fifth run and stops at −2.31e-3; at 2e-4 it stops at −5.6e-4 with its largest indicator at 2e-4, 9× the re-roll floor's sd. Each stop is a local indicator under eps, not a settled J (issue #90).
- **Where it put nodes.** Over all four loops, 733 of 1233 flags (59%) fall past `b = 16`, 389 (32%) in `[6, 16)`, 68 (6%) before 3.56. The eps-2e-4 loop ends with 103 / 33 / 43 / 112 / 160 / 180 / 202 / 124 nodes in the bands of 2.1 (from 76 / 10 / 3 / 4 / 3 / 3 / 4 / 5): 526 of its 957 past 16, where members carry 1.3e-3 of J and the band fills (2.4) move J by less than the floor, but where the competition term, a local trapezium error of the canopy normalised by the whole canopy, stays large.
- **It only inserts.** The default's 44 nodes below `b = 0.01` stay in every final schedule; each costs about 2× the mean member.
- **Cost.** Found and used, the loops cost 7.3 M (eps 2e-2, error 1.3e-2), 15.3 M (2e-3, 2.3e-3) and 44.8 M (2e-4, 5.6e-4) member evaluations; the last runs alone are 1.39 / 2.67 / 6.39 M. Uniform 380 reaches −8.7e-4 in one run of 2.14 M.
- **From uniform 108** the loop adds 32 nodes, 7 of them before `b = 1` and 14 past 16, and stops at +1.17e-2: a start 5.6× further off than the default's ends about as far off as the default's loop at the same eps.


## 4. Lean fixed schedules

### 4.1 The designs, and what finding them cost

Each design is a function of the node count `n` on `[0, 39.63]` (`sc_designs.R`, `sc_designs_e.R`), run on its own adaptive steps (`sc_design_run.R`). Node layouts by band in `sc_features.log`.

| design | construction | runs read | their Σ M |
|---|---|---|---|
| (a) uniform | `n` nodes evenly spaced | 0 | 0 |
| (b) tail | uniform over `[0, 22]` with `n − 9` nodes, then one node per 2 yr; 22 is where the uniform-108 run's `w` carries under 1e-4 of J (2.45e-5 past it, `sc_features.R`) | 1: uniform 108 | 577 599 |
| (c) cw108 | density ∝ `(|w''| / 12 / member cost)^(1/3)`, both read off the uniform-108 run (`w''` by non-uniform second differences, cost from its step times) and carried linearly between its nodes; floored at one node per 2 yr; `n` nodes at the quantiles | 1: uniform 108 | 577 599 |
| (c) cw215 | the same, read off the uniform-215 run | 1: uniform 215 | 1 183 817 |
| (d) soil | the empty patch's averaged gate is flat — 0.99778 to 0.99794 over the 40 years at birth rate 1e-10 (`sc_empty.R`) — so the same equidistribution on the empty patch's top-layer soil moisture, 30-day mean, per unit member cost of that run; no stand enters it | 1: empty patch, 2 nodes | 9 576 |
| (e) window | from the band fills (2.4): spacing `h` on `[0, 6)` and `[16, 22)`, `h / 2` on `[6, 16)`, one node per 2 yr past 22 | 9: uniform 215 + 8 fills | 11 878 265 |
| (e) twolevel | from the band fills and the trapezium split: `h` on `[0, 3.56)` and `[6, 16)`, `2h` on `[3.56, 6)` and `[16, 22)`, `4h` past 22 | 9 | 11 878 265 |

(e) is built from more than the two-run budget: the band fills are what located `[6, 16)`. Two single-schedule tests sit beside the designs: **nodead**, uniform 429 without the 64 nodes strictly inside the 56 dead bands of the saved gate scan (`P ≤ 0` on 5.84 yr, 14.6% of the horizon, the first at `b = 3.56`); and **u215tail**, uniform 215 with its nodes past 22 replaced by one per 2 yr.

### 4.2 Every fixed schedule measured

Trapezium and stand split each error as in 2.3; for grids not nested in 1713 the trapezium part reads the 1713 run's `w` through a monotone cubic in `log w` (`sc_q3.R`). Relative to J∞.

| design | nodes | J | rel. error | trapezium | stand | steps | Σ M | CPU s |
|---|---|---|---|---|---|---|---|---|
| cw108 | 60 | 12.830585 | +2.05e-02 | -2.90e-03 | +2.33e-02 | 10213 | 432 194 | 64 |
| cw108 | 100 | 12.582400 | +7.14e-04 | +2.50e-03 | -1.78e-03 | 10332 | 763 296 | 106 |
| cw108 | 150 | 12.599253 | +2.05e-03 | -1.72e-04 | +2.22e-03 | 10482 | 1 185 172 | 159 |
| cw108 | 180 | 12.522807 | -4.03e-03 | -4.38e-04 | -3.59e-03 | 10539 | 1 437 102 | 188 |
| cw108 | 220 | 12.566639 | -5.39e-04 | +3.00e-04 | -8.42e-04 | 10544 | 1 764 211 | 229 |
| cw108 | 320 | 12.572251 | -9.31e-05 | -8.99e-05 | -5.23e-06 | 10739 | 2 629 412 | 333 |
| cw215 | 100 | 12.490056 | -6.63e-03 | +2.58e-03 | -9.21e-03 | 10327 | 749 539 | 103 |
| cw215 | 220 | 12.543626 | -2.37e-03 | +7.97e-04 | -3.17e-03 | 10611 | 1 742 163 | 223 |
| default | 108 | 12.117230 | -3.63e-02 | +5.06e-02 | -8.68e-02 | 9917 | 955 535 | 131 |
| nodead | 365 | 11.656781 | -7.29e-02 | +2.67e-02 | -9.96e-02 | 11094 | 2 042 242 | 263 |
| soil | 150 | 12.788945 | +1.71e-02 | +1.02e-02 | +6.97e-03 | 10506 | 675 226 | 95 |
| soil | 320 | 12.347676 | -1.80e-02 | +1.15e-02 | -2.95e-02 | 10938 | 1 496 988 | 196 |
| tail | 150 | 12.460483 | -8.98e-03 | +6.01e-03 | -1.50e-02 | 10486 | 1 063 051 | 142 |
| tail | 220 | 12.537187 | -2.88e-03 | +3.25e-03 | -6.13e-03 | 10589 | 1 592 004 | 210 |
| tail | 320 | 12.562069 | -9.03e-04 | +5.14e-04 | -1.42e-03 | 10683 | 2 351 733 | 298 |
| twolevel | 150 | 12.534398 | -3.10e-03 | +4.41e-03 | -7.52e-03 | 10634 | 1 009 175 | 134 |
| twolevel | 180 | 12.539311 | -2.71e-03 | +4.38e-03 | -7.10e-03 | 10713 | 1 220 690 | 161 |
| twolevel | 240 | 12.550968 | -1.79e-03 | +2.18e-03 | -3.97e-03 | 10822 | 1 652 684 | 212 |
| u215tail | 129 | 12.728935 | +1.24e-02 | +5.27e-04 | +1.18e-02 | 10449 | 904 406 | 124 |
| uniform | 250 | 12.597469 | +1.91e-03 | +7.94e-04 | +1.12e-03 | 10991 | 1 386 988 | 182 |
| uniform | 320 | 12.657070 | +6.65e-03 | -9.50e-04 | +7.60e-03 | 11102 | 1 790 982 | 233 |
| uniform | 380 | 12.562520 | -8.67e-04 | -3.89e-04 | -4.80e-04 | 11179 | 2 142 437 | 273 |
| uniform (ladder) | 108 | 13.276378 | +5.59e-02 | -2.63e-04 | +5.62e-02 | 10577 | 577 599 |  |
| uniform (ladder) | 215 | 12.747510 | +1.38e-02 | +5.02e-04 | +1.33e-02 | 10921 | 1 183 817 |  |
| uniform (ladder) | 429 | 12.575093 | +1.33e-04 | +1.08e-03 | -9.45e-04 | 11240 | 2 432 505 |  |
| uniform (ladder) | 857 | 12.573626 | +1.63e-05 | +5.55e-05 | -4.13e-05 | 11627 | 5 029 471 |  |
| uniform (ladder) | 1713 | 12.573447 | +2.01e-06 | -1.41e-15 | +1.41e-15 | 12279 | 10 629 226 |  |
| window | 181 | 12.536997 | -2.90e-03 | +5.33e-03 | -8.23e-03 | 10501 | 1 290 658 | 169 |

- **(a) uniform is not monotone between 215 and 429**: +1.9e-3 at 250, +6.65e-3 at 320, −8.7e-4 at 380. From 320 to 429 (45 to 34 d) the error falls 50×.
- **(b) tail is biased low**: −9.0e-3, −2.9e-3, −9.0e-4 at 150 / 220 / 320. The 2-yr tail alone moves uniform 215 by −1.48e-3 of J (u215tail): trapezium +2.5e-5 of it, stand −1.5e-3.
- **(c) cw108 is not monotone in the node count**: +2.0e-2, +7.1e-4, +2.1e-3, −4.0e-3, −5.4e-4, −9.3e-5 at 60 / 100 / 150 / 180 / 220 / 320. Its trapezium error stays within ±3e-3 at every count; the stand's is what swings (+2.3e-2, −1.8e-3, +2.2e-3, −3.6e-3, −8.4e-4, −5e-6). Against uniform at matched Σ M: 6.7× under it at 1.18 M (cw108 150, 2.1e-3, against uniform 215, 1.4e-2), 12× under it at 1.76–1.79 M (cw108 220 against uniform 320), and **2.1× over it** at 1.4 M (cw108 180, −4.0e-3 at 1.44 M, against uniform 250, +1.9e-3 at 1.39 M).
- **(c) from the finer pilot is worse**: cw215 reads −6.6e-3 at 100 and −2.4e-3 at 220, against cw108's +7.1e-4 and −5.4e-4 at the same counts, and its pilot costs twice as much.
- **(d) soil misses where J is**: +1.7e-2 at 150 and −1.8e-2 at 320, with trapezium errors of +1.0e-2 and +1.15e-2. It puts 4 and 7 nodes before `b = 1` (cw108 at the same counts: 18 and 40) and 55 and 116 past 30.
- **(e) sits between (b) and (c)**: window 181 −2.9e-3; twolevel −3.1e-3, −2.7e-3, −1.8e-3 at 150 / 180 / 240; every one has a stand error of −4.0e-3 to −8.2e-3 against a trapezium error of +2.2e-3 to +5.3e-3. The band fills added up at uniform 215 (J(215) plus the two `[6, 16)` fills reads −4e-5), but window 181, whose only other difference from that composite is its 2-yr tail and a 1% longer spacing on `[0, 6)` and `[16, 22)`, reads −2.9e-3: the prediction does not carry once the tail is also thinned.
- **Dead bands**: nodead reads **−7.29e-2** — trapezium +2.67e-2 (one panel spans each band from edges where `w` is high), stand −9.96e-2 (the stand's own quadrature carries the edges' recruitment across the band).

### 4.3 The Pareto front

Least Σ M among the runs reaching each target, over (a)–(e) (`sc_q3.R`). "Staying" is the least Σ M from which every larger run of the same design also stays under the target.

| target | least Σ M, any run | least Σ M, staying | uniform, any run | uniform, staying |
|---|---|---|---|---|
| 1e-2 | **763 296**, cw108 100 (+7.1e-4) | 763 296, cw108 100 | 1 386 988, uniform 250 | 1 386 988 |
| 1e-3 | **763 296**, cw108 100 | **1 764 211**, cw108 220 (−5.4e-4) | 2 142 437, uniform 380 (−8.7e-4) | 2 142 437 |
| 1e-4 | 2 629 412, cw108 320 (−9.3e-5), inside the floor | — | 5 029 471, uniform 857 (+1.6e-5), inside the floor | — |

By design, first run under each target (Σ M): 1e-2 — uniform 250 (1.39 M), tail 150 (1.06 M), cw108 100 (0.76 M), cw215 100 (0.75 M), window 181 (1.29 M), twolevel 150 (1.01 M), soil none; 1e-3 — uniform 380 (2.14 M), tail 320 (2.35 M), cw108 100 (0.76 M), cw215 / soil / window / twolevel none. The 1e-4 row is below 1.6 sd of the re-roll floor: the two entries are not distinguishable from runs at 2e-4.

### 4.4 Finding against using

| schedule | Σ M to find | Σ M to use: first under 1e-3 | first under 1e-2 |
|---|---|---|---|
| uniform | 0 | 2 142 437 | 1 386 988 |
| tail | 577 599 | 2 351 733 | 1 063 051 |
| cw108 | 577 599 | 763 296 (1 764 211 staying) | 763 296 |
| cw215 | 1 183 817 | none measured | 749 539 |
| soil | 9 576 | none measured | none measured |
| window / twolevel | 11 878 265 | none measured | 1 009 175 |
| refine_schedule, eps 2e-3 from the default (section 3) | 12 670 846 (its first 7 runs) | none (−2.31e-3, 2 671 747) | 2 671 747 |

- cw108 found and used once costs 1.34 M member evaluations at its lucky count and 2.34 M at its staying count, against uniform 380's 2.14 M run.
- The re-roll check on cw108 320 (moved by 1e-5, `sc_noise_design.R`): J 12.572427139, +1.40e-5 of J from the unmoved run, −7.9e-5 against J∞.


## 5. The nested grid

Every node time other than `b = 0` ends a step; the 2931 rainfall stops end 2931 more whatever the schedule (`sc_q4_ladder.R`, `sc_q4.R`).

| schedule | nodes | steps | ended by an introduction | by a rainfall stop | by the controller | rejected: on error / on a throw |
|---|---|---|---|---|---|---|
| default | 108 | 9 917 | 107 (1.1%) | 2 931 | 6 877 | 1 916 / 528 |
| uniform | 108 | 10 577 | 107 (1.0%) | 2 931 | 7 537 | 1 894 / 837 |
| uniform | 215 | 10 921 | 214 (2.0%) | 2 931 | 7 776 | 1 884 / 1 037 |
| uniform | 429 | 11 240 | 428 (3.8%) | 2 931 | 7 881 | 1 891 / 1 150 |
| uniform | 857 | 11 627 | 856 (7.4%) | 2 931 | 7 840 | 1 873 / 1 221 |
| uniform | 1713 | 12 279 | 1 716 (14.0%) | 2 931 | 7 632 | 1 840 / 1 300 |
| cw108 | 220 | 10 544 | 219 (2.1%) | 2 931 | 7 392 | 1 906 / 832 |

Two node times from 215 on coincide with rainfall stops. In uniform 1713 four steps are 4e-16 to 7e-15 yr long: each finishes a step that landed one or two ulps short of an introduction, so 1716 step ends fall on its 1712 introductions.

Steps against nodes, least squares within each family:

| family | runs | nodes | steps per added node |
|---|---|---|---|
| uniform | 8 | 108–1713 | 0.95 |
| cw108 | 6 | 60–320 | 1.94 |
| tail | 3 | 150–320 | 1.14 |
| twolevel | 3 | 150–240 | 2.05 |
| band fills of uniform 215 | 8 | 217–310 | 1.57 |
| refine_schedule from the default, eps 2e-2 | 6 | 108–178 | 8.44 |
| refine_schedule from the default, eps 2e-3 | 8 | 108–390 | 3.91 |
| refine_schedule from the default, eps 2e-4 | 11 | 108–957 | 1.78 |
| refine_schedule from uniform 108, eps 2e-2 | 4 | 108–140 | 3.35 |

Band fills of uniform 215, steps added per node added: −2.0 on `[0, 0.5)`, −1.5 on `[0.5, 1)`, 0.86 on `[1, 3.56)`, 1.15 on `[3.56, 6)`, 0.95 on `[6, 10)`, 2.12 on `[10, 16)`, 2.06 on `[16, 22)`, 1.43 on `[22, 40)`.

- **Introductions are a small share of the steps, and the steps a small share of the spread in cost.** Over the 57 runs of 100–440 nodes, steps range 9 917–11 248 (±6.3%) while Σ M ranges 5.7× (0.58–3.27 M); introductions end 1.0–3.9% of the steps.
- **At equal node count, a schedule with fewer late nodes takes fewer steps**: default 108 takes 6.2% fewer than uniform 108; near 180 nodes cw108 takes 10 539, window 10 501 and the eps-2e-2 loop's 178-node schedule 10 495, against uniform 215's 10 921.
- **A node costs 1–2 steps where it joins nodes at 34–68-day spacing, and up to 15 where refinement drops it into the default's 1–2-yr gaps**: the eps-2e-2 loop's first two bisections add 16 nodes for 153 steps and 23 for 333.


## 6. The expectations, measured

| expectation | measured | |
|---|---|---|
| Uniform converges at order 3 once spacing is below ~34 days | From 320 to 429 (45 to 34 d) the error falls 50× (6.65e-3 to 1.33e-4), and 250 (58 d) reads 1.9e-3, under 320. Below 34 d the steps 429 → 857 → 1713 are −1.47e-3 and −1.79e-4 (ratio 8.2), but the second is smaller than the re-roll floor's sd in J (7.5e-4) | **Not established**: the approach to 34 d is not order 3, and below it the floor hides the order |
| Dead bands need nodes | Uniform 429 without its 64 nodes inside dead bands: −7.29e-2 | **Holds**, at 4× the bracket mesh's −1.9% |
| A member at `b ≈ 0` costs about 2× the mean member in a uniform schedule | 1.978–1.983× at 108–1713 | **Holds** |
| `w` is largest for `b < 3.56` | 16.9 at `b = 0` against at most 1.28 past 3.56; 88% of J before 3.56 | **Holds**, but the error is not there: filling `[0, 3.56)` moves J by −0.008 of the −0.172 that 215 → 429 moves it; `[6, 16)` moves −0.175 |
| Members born after `b ≈ 22` carry little of J | 3.6e-5 of J; their midpoints at 0.185 → 0.093 yr move J by 3e-5 of J | **Holds** for their own J and down to 0.185-yr spacing; thinned to 2 yr they move J by −1.5e-3 through the stand |
| A cost-weighted design beats uniform severalfold in Σ M at 1e-3 | First run under 1e-3: cw108 100 at 0.76 M against uniform 380 at 2.14 M (2.8×). Staying under: cw108 from 220 at 1.76 M against uniform from 380 at 2.14 M (1.2×) | **Only at a favourable count**: 2.8× at 100 nodes, 1.2× where it stays under, and 2.1× worse than uniform at 1.4 M |


## What was not reached

- **A fixed schedule that stays under 1e-3 at every nearby count with markedly less Σ M than uniform 380 (2.14 M).** cw108 is under 1e-3 at 100, 220 and 320 and over it at 150 and 180. In the 0.7–1.8 M range every design's error is a trapezium term and a stand term of ±(1–8)e-3 whose signs follow where nodes fall relative to the gate's openings and closings.
- **1e-4.** Every run under it (uniform 857 and 1713, cw108 320) sits inside the re-roll floor. Separating schedule error from step-sequence error at that level needs a tighter `ode_tol` or an average over re-rolled runs; neither was measured. `J∞` is not established below the floor either.
- **The floor elsewhere**: the step sequence was re-rolled on uniform 429 (four runs) and on cw108 320 (one), at `ode_tol = 1e-3` only.
- **An indicator that points where the band fills do.** The fills (nine runs) put the stand's error in `[6, 16)`; `refine_schedule`'s competition term puts 59% of its flags past `b = 16`, where the fills move J by less than the floor. A per-node indicator weighted by J's sensitivity to each node's density (the adjoint's) was not built. The stand acts through water as well as light, and no term of the indicator measures water.
- `refine_schedule` with coarsening, symmetric bisection, or a stop on the change in J (issues #89, #90).
- A construction of the (e) designs from two runs: their rule came from nine.
- Any other trait or record: every design was built and measured at `lma = 0.32` on `long-drought`; how a θ0 design holds across θ was not measured here.
- Why the stand's error answers to the tail's spacing once `[6, 16)` is resolved (window 181, u215tail): the recruitment after `b = 22` was not taken apart.


## Scripts

All in `perf/schedule/`; outputs in `perf/schedule/out/`, each script's log beside it (`<script>.log`, or the name in `slotA*.sh` / `slotB.sh`).

| script | what it does | sections |
|---|---|---|
| `sc_util.R` | plain-R helpers: member cost, Σ M, step endings, bands, trapezium panels, density-to-nodes; the active knots without loading the model | all |
| `sc_common.R` | the harness plus `run_S` (the fixture, CPU seconds, the indicator's two terms at `S_D = 0`), `combine_terms`, `bisect_flagged` | all runs |
| `sc_repro.R` | the two reproduction runs through `run_J` | 1 |
| `sc_noise.R`, `sc_noise_design.R`, `sc_noise_summary.R` | uniform 429 (and cw108 320) with every node but 0 moved by δ; the floor's table | 1, 4 |
| `sc_q1.R` | profile, member cost, local term, dropped nodes, uniform 215's split, placement; `out/profile_uniform_1713.csv` | 1, 2 |
| `sc_bands.R`, `sc_q1_bands.R` | the band fills of uniform 215 and their split | 2.4 |
| `sc_check_terms.R` | the `S_D = 0` split against a default-`S_D` run, and the emulation against `SCM$refine_schedule()` | 3 |
| `sc_refine.R`, `sc_q2.R` | the four refinement loops, one iteration at a time; their tables (`out/q2_table.md`) | 3 |
| `sc_empty.R` | the empty patch (birth rate 1e-10, two nodes): its gate and soil | 4 |
| `sc_features.R` | dead bands, the empty patch's gate and soil against them, where the pilot's `w` vanishes, finding costs, design layouts | 4 |
| `sc_designs.R`, `sc_designs_e.R`, `sc_design_run.R` | the designs (a)–(e) and the two tests, and their runs | 4 |
| `sc_q3.R` | every fixed schedule: error, split, cost; the Pareto front (`out/q3_table.md`) | 4 |
| `sc_q4_ladder.R`, `sc_q4.R` | step endings and steps per node over every run | 5 |
| `sc_handoff.R` | writes a run's schedule to `perf/schedules/` with its README line | hand-off |

Hand-off (`perf/schedules/`): `cw108_100.rds` (+7.1e-4, Σ M 763 296), `cw108_220.rds` (−5.4e-4, 1 764 211), `cw108_320.rds` (−9.3e-5, 2 629 412, inside the floor), each with its README line.

