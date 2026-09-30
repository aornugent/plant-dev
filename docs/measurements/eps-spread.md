# The spread of J and its gradients across rainfall records

Step 1 of `docs/design-grid-controller.md`: eight daily-weather seeds of one climate, run with `harness/eps_spread.R` on plant v12-targets (PLANT-95 + PLANT-96 + PLANT-97, before PLANT-98) at `tol = 1e-4` with the shared absolute tolerance. `1.lma` is the partial derivative in `lma` alone, not through the TF24 hyperparameterisation.

Eight rainfall records of the `long-drought` spec differing only in `seed` (31, 101, 102, 103, 104, 105, 106, 107); everything else of the spec kept (the drought-year multipliers, mean 3.0). Each record has its own zero-depth pulses at its own active knots. TF24, lifetime 40, one species at lma = 0.32, `uniform_times(108)`, tol 1e-4 (rel = abs), birth-date density. Built from `lib_v12t` (odelia 0.5.0, phylloptim 0.9.0, plant v12-targets).

The invader has the resident's own traits (theta' = theta) and runs through the resident's recorded field (`scm$run_mutant(p)`), so its gradient is the selection gradient. Elasticities are `theta * (dJ/dtheta) / J`; for a trait whose value is 0 the entry is `d ln J / d theta`. eps = sd / 10, sd over the records with n - 1 in the denominator.

## Per seed

| seed | knots | steps | J | ln J | J' | J'/J - 1 | e lma (res) | e lma (inv) | e a_dG2 (res) | e a_dG2 (inv) |
|---|---|---|---|---|---|---|---|---|---|---|
|  31 | 2931 | 11814 | 12.679020 | 2.539949 | 12.679020 |   0 | -8.2820 | -27.0542 | 1.0551 | 3.9701 |
| 101 | 2958 | 11793 | 13.462703 | 2.599923 | 13.462703 |   0 | -10.8365 | -29.6724 | 0.8522 | 3.7821 |
| 102 | 2897 | 11660 | 7.819984 | 2.056683 | 7.819984 |   0 | -9.8710 | -29.0532 | 1.0628 | 4.7638 |
| 103 | 2938 | 11954 | 7.972540 | 2.076003 | 7.972540 |   0 | -9.5235 | -25.8477 | 1.3415 | 3.7937 |
| 104 | 2923 | 11864 | 7.522141 | 2.017851 | 7.522141 |   0 | -9.4596 | -26.5312 | 1.4209 | 4.4328 |
| 105 | 2961 | 11583 | 12.410737 | 2.518562 | 12.410737 |   0 | -10.3728 | -27.6560 | 1.0562 | 3.8436 |
| 106 | 3035 | 12028 | 9.274400 | 2.227258 | 9.274400 |   0 | -9.8767 | -26.7272 | 1.1024 | 3.8270 |
| 107 | 2943 | 12073 | 12.753225 | 2.545784 | 12.753225 |   0 | -8.5038 | -23.2604 | 0.9437 | 3.0675 |

Seed 31's J is 12.6790200 against the tol-1e-8 reference 12.6687135 (+8.14e-04 relative). The census's offspring production (`g$value`) against `sum(scm$offspring_production)`: largest relative difference 0.0e+00 (resident), 0.0e+00 (invader).

## Spread and eps

sd from eight records is itself uncertain: with 7 degrees of freedom its 90% interval runs from about 0.71 to 1.80 times the estimate.

### Resident

| quantity | unit | mean | sd | eps | sd/abs(mean) |
|---|---|---|---|---|---|
| ln J | ln J | 2.323 | 0.252 | 0.0252 | 0.11 |
| lma | elasticity | -9.591 | 0.865 | 0.0865 | 0.09 |
| a_dG2 | elasticity | 1.104 | 0.19 | 0.019 | 0.17 |
| rho | elasticity | -6.901 | 0.673 | 0.0673 | 0.098 |
| hmat | elasticity | -10.18 | 0.824 | 0.0824 | 0.081 |
| omega | elasticity | -0.2748 | 0.0164 | 0.00164 | 0.06 |
| theta | elasticity | -4.273 | 0.521 | 0.0521 | 0.12 |
| a_l1 | elasticity | 1.646 | 0.156 | 0.0156 | 0.095 |
| a_l2 | elasticity | 2.317 | 0.484 | 0.0484 | 0.21 |
| a_r1 | elasticity | 2.901 | 0.282 | 0.0282 | 0.097 |
| a_b1 | elasticity | -1.241 | 0.0935 | 0.00935 | 0.075 |
| r_s | elasticity | -1.244 | 0.0814 | 0.00814 | 0.065 |
| r_b | elasticity | -0.4229 | 0.0277 | 0.00277 | 0.065 |
| r_r | elasticity | -1.495 | 0.113 | 0.0113 | 0.076 |
| r_l | elasticity | -9.068 | 0.685 | 0.0685 | 0.076 |
| a_y | elasticity | 7.257 | 0.846 | 0.0846 | 0.12 |
| a_bio | elasticity | 7.257 | 0.846 | 0.0846 | 0.12 |
| k_l | elasticity | -0.3687 | 0.0278 | 0.00278 | 0.076 |
| k_b | elasticity | -0.3737 | 0.0245 | 0.00245 | 0.065 |
| k_s | elasticity | -2.198 | 0.144 | 0.0144 | 0.065 |
| k_r | elasticity | -0.4018 | 0.0304 | 0.00304 | 0.076 |
| a_f3 | elasticity | -0.75 | 2.52e-15 | 2.52e-16 | 3.4e-15 |
| a_f1 | elasticity | 0.5877 | 0.0121 | 0.00121 | 0.021 |
| a_f2 | elasticity | -0.05559 | 0.0379 | 0.00379 | 0.68 |
| S_D | elasticity |     1 | 3.2e-16 | 3.2e-17 | 3.2e-16 |
| a_d0 | elasticity | 0.007967 | 0.00215 | 0.000215 | 0.27 |
| d_I | elasticity | -0.01852 | 0.00473 | 0.000473 | 0.26 |
| a_dG1 | elasticity | -0.4836 | 0.366 | 0.0366 | 0.76 |
| a_st1 | elasticity | 0.3992 | 0.206 | 0.0206 | 0.52 |
| a_st2 | elasticity | 0.09282 | 0.0452 | 0.00452 | 0.49 |
| a_st3 | elasticity | -0.002753 | 0.000558 | 5.58e-05 | 0.2 |
| storage_relaxation_offset | elasticity | 0.01587 | 0.102 | 0.0102 | 6.4 |
| k_I | elasticity | 2.067 | 0.293 | 0.0293 | 0.14 |
| vcmax_25 | elasticity | 7.073 | 0.511 | 0.0511 | 0.072 |
| stem_P50 | elasticity | 8.363 | 0.671 | 0.0671 | 0.08 |
| K_s | elasticity | 2.628 | 0.198 | 0.0198 | 0.075 |
| stem_c | elasticity | 1.519 | 0.166 | 0.0166 | 0.11 |
| TF24_beta2 | elasticity | 3.808 | 0.327 | 0.0327 | 0.086 |
| TF24_cost_scale | elasticity | -2.86 | 0.196 | 0.0196 | 0.069 |
| TF24_floor_lambda_o | d ln J / d theta | -2.57e-05 | 4.04e-06 | 4.04e-07 | 0.16 |
| jmax_25 | elasticity | 5.399 | 0.694 | 0.0694 | 0.13 |
| a | elasticity |  1.51 | 0.354 | 0.0354 | 0.23 |
| curv_fact_elec_trans | elasticity | 2.326 | 0.39 | 0.039 | 0.17 |
| curv_fact_colim | elasticity | 68.58 | 5.98 | 0.598 | 0.087 |
| R_d_25 | elasticity | -1.229 | 0.118 | 0.0118 | 0.096 |
| root_c | elasticity | 0.2194 | 0.032 | 0.0032 | 0.15 |
| root_P50 | elasticity | -0.4122 | 0.108 | 0.0108 | 0.26 |
| rooting_depth_max | elasticity | 0.238 | 0.0539 | 0.00539 | 0.23 |
| D_c | elasticity | 5.431 | 0.416 | 0.0416 | 0.077 |
| L_tip | elasticity | -1.029 | 0.0779 | 0.00779 | 0.076 |
| recruitment_decay | d ln J / d theta | 5.487 | 0.679 | 0.0679 | 0.12 |

### Invader at theta' = theta (the selection gradient)

| quantity | unit | mean | sd | eps | sd/abs(mean) | mean / resident mean - 1 |
|---|---|---|---|---|---|---|
| ln J | ln J | 2.323 | 0.252 | 0.0252 | 0.11 |  |
| lma | elasticity | -26.98 | 1.98 | 0.198 | 0.073 | 1.8 |
| a_dG2 | elasticity | 3.935 |  0.5 | 0.05 | 0.13 | 2.6 |
| rho | elasticity | -12.12 | 1.07 | 0.107 | 0.089 | 0.76 |
| hmat | elasticity | -9.737 | 0.818 | 0.0818 | 0.084 | -0.044 |
| omega | elasticity | 0.06179 | 0.0423 | 0.00423 | 0.68 | -1.2 |
| theta | elasticity | -6.226 | 0.853 | 0.0853 | 0.14 | 0.46 |
| a_l1 | elasticity | -2.188 | 0.131 | 0.0131 | 0.06 | -2.3 |
| a_l2 | elasticity | 3.618 | 0.671 | 0.0671 | 0.19 | 0.56 |
| a_r1 | elasticity | 8.489 | 0.605 | 0.0605 | 0.071 | 1.9 |
| a_b1 | elasticity | -2.317 | 0.174 | 0.0174 | 0.075 | 0.87 |
| r_s | elasticity | -1.868 | 0.14 | 0.014 | 0.075 | 0.5 |
| r_b | elasticity | -0.6353 | 0.0474 | 0.00474 | 0.075 | 0.5 |
| r_r | elasticity | -3.71 | 0.266 | 0.0266 | 0.072 | 1.5 |
| r_l | elasticity | -22.5 | 1.61 | 0.161 | 0.072 | 1.5 |
| a_y | elasticity | 16.55 | 1.48 | 0.148 | 0.089 | 1.3 |
| a_bio | elasticity | 16.55 | 1.48 | 0.148 | 0.089 | 1.3 |
| k_l | elasticity | -0.9146 | 0.0655 | 0.00655 | 0.072 | 1.5 |
| k_b | elasticity | -0.5614 | 0.0419 | 0.00419 | 0.075 | 0.5 |
| k_s | elasticity | -3.302 | 0.247 | 0.0247 | 0.075 | 0.5 |
| k_r | elasticity | -0.9969 | 0.0714 | 0.00714 | 0.072 | 1.5 |
| a_f3 | elasticity | -0.75 | 2.52e-15 | 2.52e-16 | 3.4e-15 |   0 |
| a_f1 | elasticity | 0.5643 | 0.0127 | 0.00127 | 0.023 | -0.04 |
| a_f2 | elasticity | -0.05172 | 0.0371 | 0.00371 | 0.72 | -0.07 |
| S_D | elasticity |     1 | 3.2e-16 | 3.2e-17 | 3.2e-16 |   0 |
| a_d0 | elasticity | -0.005297 | 0.000407 | 4.07e-05 | 0.077 | -1.7 |
| d_I | elasticity | -0.1614 | 0.00497 | 0.000497 | 0.031 | 7.7 |
| a_dG1 | elasticity | -5.779 | 0.373 | 0.0373 | 0.065 |  11 |
| a_st1 | elasticity | 1.958 | 0.228 | 0.0228 | 0.12 | 3.9 |
| a_st2 | elasticity | 0.5279 | 0.114 | 0.0114 | 0.22 | 4.7 |
| a_st3 | elasticity | 0.003472 | 0.00121 | 0.000121 | 0.35 | -2.3 |
| storage_relaxation_offset | elasticity | 1.645 | 0.164 | 0.0164 | 0.1 | 1e+02 |
| k_I | elasticity | 8.373 | 0.718 | 0.0718 | 0.086 | 3.1 |
| vcmax_25 | elasticity | 13.23 | 0.898 | 0.0898 | 0.068 | 0.87 |
| stem_P50 | elasticity | 27.62 | 2.17 | 0.217 | 0.079 | 2.3 |
| K_s | elasticity | 5.895 | 0.453 | 0.0453 | 0.077 | 1.2 |
| stem_c | elasticity | -2.597 | 0.696 | 0.0696 | 0.27 | -2.7 |
| TF24_beta2 | elasticity |  8.92 | 0.669 | 0.0669 | 0.075 | 1.3 |
| TF24_cost_scale | elasticity | -9.925 | 0.783 | 0.0783 | 0.079 | 2.5 |
| TF24_floor_lambda_o | d ln J / d theta | -9.908e-05 | 7.24e-06 | 7.24e-07 | 0.073 | 2.9 |
| jmax_25 | elasticity |  17.1 | 1.36 | 0.136 | 0.079 | 2.2 |
| a | elasticity | 8.373 | 0.718 | 0.0718 | 0.086 | 4.5 |
| curv_fact_elec_trans | elasticity | 9.418 | 0.777 | 0.0777 | 0.083 |   3 |
| curv_fact_colim | elasticity | 158.3 | 11.6 | 1.16 | 0.073 | 1.3 |
| R_d_25 | elasticity | -3.387 | 0.249 | 0.0249 | 0.074 | 1.8 |
| root_c | elasticity | 0.1497 | 0.0223 | 0.00223 | 0.15 | -0.32 |
| root_P50 | elasticity | 0.8501 | 0.115 | 0.0115 | 0.14 | -3.1 |
| rooting_depth_max | elasticity | 0.383 | 0.0641 | 0.00641 | 0.17 | 0.61 |
| D_c | elasticity | 10.93 | 0.855 | 0.0855 | 0.078 |   1 |
| L_tip | elasticity | -2.257 | 0.174 | 0.0174 | 0.077 | 1.2 |
| recruitment_decay | d ln J / d theta | -1.348 | 0.313 | 0.0313 | 0.23 | -1.2 |

## Refusals and outliers

No run refused `offspring_production` (every gradient finite).

Outlier rule: a quantity is flagged when its largest absolute deviation from the across-seed median exceeds ten times the median absolute deviation.

| role | quantity | median | mad | max dev / mad | farthest seed |
|---|---|---|---|---|---|
| stand | K_s | 2.726 | 0.0436 | 10.2 | 107 |
| stand | L_tip | -1.066 | 0.0168 | 10.4 | 107 |

## Numerical checks at seed 31

Each entry is (check run - base run) / sd, the base run being tol 1e-4 with 108 nodes, and sd the across-seed sd of that quantity; |ratio| < 0.1 means the move is below eps.

### tol 1e-5, 108 nodes

| role | quantity | base | check | delta | delta / sd |
|---|---|---|---|---|---|
| stand | ln J | 2.539949 | 2.539168 | -0.000781 | -0.00309 |
| invader | ln J | 2.539949 | 2.539168 | -0.000781 | -0.00309 |
| stand | lma | -8.282025 | -8.285264 | -0.00324 | -0.00374 |
| stand | a_dG2 | 1.055052 | 1.061439 | 0.00639 | 0.0336 |
| invader | lma | -27.05419 | -27.06306 | -0.00886 | -0.00448 |
| invader | a_dG2 | 3.970059 |  3.97028 | 0.000221 | 0.000441 |

- Resident, all 50 traits: median |delta / sd| 0.0077, largest a_f3 -2.5, S_D -0.69, a_st3 -0.2; 4 above 0.1, 1 above 1.
- Invader, all 50 traits: median |delta / sd| 0.0038, largest a_f3 -2.5, S_D -0.69, a_d0 -0.16; 4 above 0.1, 1 above 1.

### tol 1e-4, 215 nodes

| role | quantity | base | check | delta | delta / sd |
|---|---|---|---|---|---|
| stand | ln J | 2.539949 | 2.544145 | 0.0042 | 0.0166 |
| invader | ln J | 2.539949 | 2.544145 | 0.0042 | 0.0166 |
| stand | lma | -8.282025 | -8.311105 | -0.0291 | -0.0336 |
| stand | a_dG2 | 1.055052 | 1.061285 | 0.00623 | 0.0328 |
| invader | lma | -27.05419 | -26.97001 | 0.0842 | 0.0426 |
| invader | a_dG2 | 3.970059 |  3.96821 | -0.00185 | -0.0037 |

- Resident, all 50 traits: median |delta / sd| 0.033, largest a_st3 2.3, a_f3 -1.4, S_D  -1; 5 above 0.1, 3 above 1.
- Invader, all 50 traits: median |delta / sd| 0.019, largest a_f3 -1.4, S_D  -1, a_st3 -0.21; 6 above 0.1, 2 above 1.

## Wall time per run

Seconds; the resident's sweep repeats its run to keep the states, and the invader's run re-runs the resident to record its field and then walks it.

| run | steps | resident run | resident sweep | invader run | invader sweep | process wall |
|---|---|---|---|---|---|---|
| seed 31 | 11814 |  76 | 291 | 153 | 207 |  728 |
| seed 101 | 11793 |  76 | 287 | 155 | 212 |  731 |
| seed 102 | 11660 |  85 | 301 | 160 | 197 |  744 |
| seed 103 | 11954 |  90 | 318 | 170 | 215 |  794 |
| seed 104 | 11864 |  98 | 285 | 145 | 189 |  718 |
| seed 105 | 11583 |  84 | 286 | 146 | 180 |  698 |
| seed 106 | 12028 |  78 | 280 | 146 | 197 |  703 |
| seed 107 | 12073 |  77 | 272 | 144 | 191 |  684 |
| tol 1e-5, 108 nodes | 16186 | 107 | 379 | 194 | 240 |  922 |
| tol 1e-4, 215 nodes | 11900 | 151 | 543 | 273 | 364 | 1332 |

