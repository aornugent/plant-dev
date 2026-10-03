# The spread of J and its gradients across rainfall records

Step 1 of the design's assessment (`docs/assessment.md`), run with `harness/run_record.R` (`ATOL=1`) on plant v12-targets (PLANT-95 + PLANT-96 + PLANT-97, before PLANT-98) at `tol = 1e-4` with the shared absolute tolerance. `lma` is the partial derivative in `lma` alone, not through the TF24 hyperparameterisation.

Eight rainfall records of the `long-drought` spec that differ only in `seed` (31, 101, 102, 103, 104, 105, 106, 107). Everything else in the spec is kept (the drought-year multipliers, mean 3.0). Each record carries zero-depth pulses at its own active knots. TF24, lifetime 40, one species at lma = 0.32, `uniform_times(108)`, tol 1e-4 (rel = abs), birth-date density; `lib_v12t` (odelia 0.5.0, phylloptim 0.9.0, plant v12-targets). Script: `harness/run_record.R` with `ATOL=1`; ε for every quantity is in `eps.csv` beside this note.

The invader has the resident's own traits (theta' = theta) and walks the resident's recorded field (`scm$run_mutant(p)` on the resident's `scm`), so its gradient is the selection gradient. Elasticity = `theta * (dJ/dtheta) / J`; for a trait whose value is 0 (`TF24_floor_lambda_o`, `recruitment_decay`) the entry is `d ln J / d theta`. sd is over the eight records (n - 1 denominator); eps = sd / 10.

## Per seed

| seed | knots | steps | J | ln J | J' | J'/J - 1 | lma, res | lma, inv | a_dG2, res | a_dG2, inv |
|---|---|---|---|---|---|---|---|---|---|---|
|  31 | 2931 | 11814 | 12.679020 | 2.539949 | 12.679020 | 0 | -8.2820 | -27.0542 | 1.0551 | 3.9701 |
| 101 | 2958 | 11793 | 13.462703 | 2.599923 | 13.462703 | 0 | -10.8365 | -29.6724 | 0.8522 | 3.7821 |
| 102 | 2897 | 11660 | 7.819984 | 2.056683 | 7.819984 | 0 | -9.8710 | -29.0532 | 1.0628 | 4.7638 |
| 103 | 2938 | 11954 | 7.972540 | 2.076003 | 7.972540 | 0 | -9.5235 | -25.8477 | 1.3415 | 3.7937 |
| 104 | 2923 | 11864 | 7.522141 | 2.017851 | 7.522141 | 0 | -9.4596 | -26.5312 | 1.4209 | 4.4328 |
| 105 | 2961 | 11583 | 12.410737 | 2.518562 | 12.410737 | 0 | -10.3728 | -27.6560 | 1.0562 | 3.8436 |
| 106 | 3035 | 12028 | 9.274400 | 2.227258 | 9.274400 | 0 | -9.8767 | -26.7272 | 1.1024 | 3.8270 |
| 107 | 2943 | 12073 | 12.753225 | 2.545784 | 12.753225 | 0 | -8.5038 | -23.2604 | 0.9437 | 3.0675 |

- J' equals J to the last bit on every record (J'/J - 1 = 0, not only 1e-12).
- `g$value` equals `sum(scm$offspring_production)` exactly on every run, resident and invader (largest relative difference 0e+00).
- Seed 31's J is 12.679019954, against the tol-1e-8 reference 12.6687135 (+8.14e-04 relative). It matches, to the nine decimals printed, the earlier `harness/v12_steps.R` run at the same setting (12.679019954, 11814 steps).

## Spread and eps

ln J' = ln J on every record, so the ln J row serves both. Rows marked * are the same on every record to rounding (sd/|mean| < 1e-10): J is proportional to S_D, and J's a_f3 elasticity is -a_f3 / (omega + a_f3) = -0.75, as it would be if seed output went as 1 / (omega + a_f3). They have no spread, so this measurement sets no eps for them. An sd from eight records is itself uncertain: with 7 degrees of freedom its 90% interval runs from 0.71 to 1.80 times the estimate.

| quantity | unit | res mean | res sd | res eps | inv mean | inv sd | inv eps |
|---|---|---|---|---|---|---|---|
| ln J | ln J | 2.323 | 0.252 | 0.0252 | = | = | = |
| lma | elasticity | -9.591 | 0.865 | 0.0865 | -26.98 | 1.98 | 0.198 |
| a_dG2 | elasticity | 1.104 | 0.19 | 0.019 | 3.935 | 0.5 | 0.05 |
| rho | elasticity | -6.901 | 0.673 | 0.0673 | -12.12 | 1.07 | 0.107 |
| hmat | elasticity | -10.18 | 0.824 | 0.0824 | -9.737 | 0.818 | 0.0818 |
| omega | elasticity | -0.2748 | 0.0164 | 0.00164 | 0.06179 | 0.0423 | 0.00423 |
| theta | elasticity | -4.273 | 0.521 | 0.0521 | -6.226 | 0.853 | 0.0853 |
| a_l1 | elasticity | 1.646 | 0.156 | 0.0156 | -2.188 | 0.131 | 0.0131 |
| a_l2 | elasticity | 2.317 | 0.484 | 0.0484 | 3.618 | 0.671 | 0.0671 |
| a_r1 | elasticity | 2.901 | 0.282 | 0.0282 | 8.489 | 0.605 | 0.0605 |
| a_b1 | elasticity | -1.241 | 0.0935 | 0.00935 | -2.317 | 0.174 | 0.0174 |
| r_s | elasticity | -1.244 | 0.0814 | 0.00814 | -1.868 | 0.14 | 0.014 |
| r_b | elasticity | -0.4229 | 0.0277 | 0.00277 | -0.6353 | 0.0474 | 0.00474 |
| r_r | elasticity | -1.495 | 0.113 | 0.0113 | -3.71 | 0.266 | 0.0266 |
| r_l | elasticity | -9.068 | 0.685 | 0.0685 | -22.5 | 1.61 | 0.161 |
| a_y | elasticity | 7.257 | 0.846 | 0.0846 | 16.55 | 1.48 | 0.148 |
| a_bio | elasticity | 7.257 | 0.846 | 0.0846 | 16.55 | 1.48 | 0.148 |
| k_l | elasticity | -0.3687 | 0.0278 | 0.00278 | -0.9146 | 0.0655 | 0.00655 |
| k_b | elasticity | -0.3737 | 0.0245 | 0.00245 | -0.5614 | 0.0419 | 0.00419 |
| k_s | elasticity | -2.198 | 0.144 | 0.0144 | -3.302 | 0.247 | 0.0247 |
| k_r | elasticity | -0.4018 | 0.0304 | 0.00304 | -0.9969 | 0.0714 | 0.00714 |
| a_f3 * | elasticity | -0.75 | 2.52e-15 | - | -0.75 | 2.52e-15 | - |
| a_f1 | elasticity | 0.5877 | 0.0121 | 0.00121 | 0.5643 | 0.0127 | 0.00127 |
| a_f2 | elasticity | -0.05559 | 0.0379 | 0.00379 | -0.05172 | 0.0371 | 0.00371 |
| S_D * | elasticity | 1 | 3.2e-16 | - | 1 | 3.2e-16 | - |
| a_d0 | elasticity | 0.007967 | 0.00215 | 0.000215 | -0.005297 | 0.000407 | 4.07e-05 |
| d_I | elasticity | -0.01852 | 0.00473 | 0.000473 | -0.1614 | 0.00497 | 0.000497 |
| a_dG1 | elasticity | -0.4836 | 0.366 | 0.0366 | -5.779 | 0.373 | 0.0373 |
| a_st1 | elasticity | 0.3992 | 0.206 | 0.0206 | 1.958 | 0.228 | 0.0228 |
| a_st2 | elasticity | 0.09282 | 0.0452 | 0.00452 | 0.5279 | 0.114 | 0.0114 |
| a_st3 | elasticity | -0.002753 | 0.000558 | 5.58e-05 | 0.003472 | 0.00121 | 0.000121 |
| storage_relaxation_offset | elasticity | 0.01587 | 0.102 | 0.0102 | 1.645 | 0.164 | 0.0164 |
| k_I | elasticity | 2.067 | 0.293 | 0.0293 | 8.373 | 0.718 | 0.0718 |
| vcmax_25 | elasticity | 7.073 | 0.511 | 0.0511 | 13.23 | 0.898 | 0.0898 |
| stem_P50 | elasticity | 8.363 | 0.671 | 0.0671 | 27.62 | 2.17 | 0.217 |
| K_s | elasticity | 2.628 | 0.198 | 0.0198 | 5.895 | 0.453 | 0.0453 |
| stem_c | elasticity | 1.519 | 0.166 | 0.0166 | -2.597 | 0.696 | 0.0696 |
| TF24_beta2 | elasticity | 3.808 | 0.327 | 0.0327 | 8.92 | 0.669 | 0.0669 |
| TF24_cost_scale | elasticity | -2.86 | 0.196 | 0.0196 | -9.925 | 0.783 | 0.0783 |
| TF24_floor_lambda_o | d ln J / d theta | -2.57e-05 | 4.04e-06 | 4.04e-07 | -9.908e-05 | 7.24e-06 | 7.24e-07 |
| jmax_25 | elasticity | 5.399 | 0.694 | 0.0694 | 17.1 | 1.36 | 0.136 |
| a | elasticity | 1.51 | 0.354 | 0.0354 | 8.373 | 0.718 | 0.0718 |
| curv_fact_elec_trans | elasticity | 2.326 | 0.39 | 0.039 | 9.418 | 0.777 | 0.0777 |
| curv_fact_colim | elasticity | 68.58 | 5.98 | 0.598 | 158.3 | 11.6 | 1.16 |
| R_d_25 | elasticity | -1.229 | 0.118 | 0.0118 | -3.387 | 0.249 | 0.0249 |
| root_c | elasticity | 0.2194 | 0.032 | 0.0032 | 0.1497 | 0.0223 | 0.00223 |
| root_P50 | elasticity | -0.4122 | 0.108 | 0.0108 | 0.8501 | 0.115 | 0.0115 |
| rooting_depth_max | elasticity | 0.238 | 0.0539 | 0.00539 | 0.383 | 0.0641 | 0.00641 |
| D_c | elasticity | 5.431 | 0.416 | 0.0416 | 10.93 | 0.855 | 0.0855 |
| L_tip | elasticity | -1.029 | 0.0779 | 0.00779 | -2.257 | 0.174 | 0.0174 |
| recruitment_decay | d ln J / d theta | 5.487 | 0.679 | 0.0679 | -1.348 | 0.313 | 0.0313 |

The invader's elasticities are not within a fifth of the resident's. Over the eight records the invader's lma elasticity is 2.67 to 3.27 times the resident's, and its a_dG2 elasticity 2.83 to 4.48 times. Take, per trait, the median over records of |invader / resident - 1|: across the 48 non-structural traits that median is 1.4, and it is below 0.2 for only 3 traits (hmat, a_f1, a_f2).

## Finite-difference check at seed 31

Central differences of ln J in ln theta, step +-0.001 relative. The resident replays its own step program (`p$ode_times`, `p$ode_step_sizes`), a fixed grid whose field responds to theta. The invader is walked through the resident's recording, which holds the field. The replayed program reproduces J to +5.1e-08, not to the bit.

| role | trait | swept | central difference | swept / difference - 1 |
|---|---|---|---|---|
| resident | lma | -8.28202 | -8.27616 | 0.00071 |
| resident | a_dG2 | 1.05505 | 1.05499 | 5.7e-05 |
| invader | lma | -27.05419 | -27.05445 | -9.3e-06 |
| invader | a_dG2 | 3.97006 | 3.97006 | -1.1e-06 |

## Refusals and outliers

- No run refused `offspring_production`, and every gradient entry of every run is finite.
- Outlier rule: a quantity is flagged when its largest absolute deviation from the across-seed median is more than ten times the median absolute deviation (MAD). Structural rows are excluded.

| role | trait | median | MAD | max dev / MAD | farthest seed |
|---|---|---|---|---|---|
| resident | K_s | 2.726 | 0.0436 | 10.2 | 107 |
| resident | L_tip | -1.066 | 0.0168 | 10.4 | 107 |

- resident K_s by seed: 31 2.348, 101 2.736, 102 2.737, 103 2.717, 104 2.799, 105 2.748, 106 2.661, 107 2.28.
- resident L_tip by seed: 31 -0.9211, 101 -1.066, 102 -1.072, 103 -1.066, 104 -1.101, 105 -1.075, 106 -1.041, 107 -0.8918.
- Neither flag is a single wild entry. Seeds 31 and 107 sit together, apart from the other six records, which cluster tightly and so make the MAD small. Neither is anywhere near the two-orders-of-magnitude cells that `stand_gradient`'s documentation warns of.
- Just under the cut: resident a_f2 (8.79, seed 107); resident a_st2 (8.02, seed 104); resident stem_P50 (8.33, seed 107); resident D_c (9.41, seed 107); invader a_dG2 (9.88, seed 102); invader a_st3 (9.14, seed 105).
- The broadest spreads relative to the mean: resident storage_relaxation_offset (sd/|mean| 6.4; changes sign); resident a_dG1 (sd/|mean| 0.76; changes sign); invader a_f2 (sd/|mean| 0.72; changes sign); invader omega (sd/|mean| 0.68; keeps its sign). Each is spread across the records, not a single outlier.

## Numerical checks at seed 31

(check run - base run) / sd, where the base run is tol 1e-4 on 108 nodes and sd is that quantity's across-record sd. |ratio| < 0.1 means the setting's error is below eps. Structural rows are left out.

| check | role | quantity | base | check value | delta | delta / sd |
|---|---|---|---|---|---|---|
| tol 1e-5, 108 nodes | resident | ln J | 2.539949 | 2.539168 | -0.000781 | -0.0031 |
| tol 1e-5, 108 nodes | invader | ln J | 2.539949 | 2.539168 | -0.000781 | -0.0031 |
| tol 1e-5, 108 nodes | resident | lma | -8.282025 | -8.285264 | -0.00324 | -0.0037 |
| tol 1e-5, 108 nodes | resident | a_dG2 | 1.055052 | 1.061439 | 0.00639 | 0.034 |
| tol 1e-5, 108 nodes | invader | lma | -27.05419 | -27.06306 | -0.00886 | -0.0045 |
| tol 1e-5, 108 nodes | invader | a_dG2 | 3.970059 | 3.97028 | 0.000221 | 0.00044 |
| tol 1e-4, 215 nodes | resident | ln J | 2.539949 | 2.544145 | 0.0042 | 0.017 |
| tol 1e-4, 215 nodes | invader | ln J | 2.539949 | 2.544145 | 0.0042 | 0.017 |
| tol 1e-4, 215 nodes | resident | lma | -8.282025 | -8.311105 | -0.0291 | -0.034 |
| tol 1e-4, 215 nodes | resident | a_dG2 | 1.055052 | 1.061285 | 0.00623 | 0.033 |
| tol 1e-4, 215 nodes | invader | lma | -27.05419 | -26.97001 | 0.0842 | 0.043 |
| tol 1e-4, 215 nodes | invader | a_dG2 | 3.970059 | 3.96821 | -0.00185 | -0.0037 |

- tol 1e-5, 108 nodes, resident, 48 traits: median |delta / sd| 0.0071, 90th percentile 0.035, largest a_st3 (-0.2); 2 above 0.1, 0 above 1.
- tol 1e-5, 108 nodes, invader, 48 traits: median |delta / sd| 0.0038, 90th percentile 0.005, largest a_d0 (-0.16); 2 above 0.1, 0 above 1.
- tol 1e-4, 215 nodes, resident, 48 traits: median |delta / sd| 0.032, 90th percentile 0.058, largest a_st3 (2.3); 3 above 0.1, 1 above 1.
- tol 1e-4, 215 nodes, invader, 48 traits: median |delta / sd| 0.018, 90th percentile 0.052, largest a_st3 (-0.21); 4 above 0.1, 0 above 1.
- On the node axis, ln J moves 0.0042 to 215 nodes and 0.00541 to 429 (an earlier `harness/v12_steps.R` run, J 12.747781765). Their ratio is 1.29, against 1.25 for an error that goes as the spacing squared. The 108-node error in ln J is then about 0.0056, or 0.022 sd. On the time axis, with an error that goes as tol, the 1e-4 error is about 1.1 times the move to 1e-5: 0.0034 sd.

Every move above eps (|delta / sd| > 0.1):

| check | role | trait | base | check value | delta / sd |
|---|---|---|---|---|---|
| tol 1e-5, 108 nodes | resident | a_d0 | 0.008559 | 0.008897 | 0.16 |
| tol 1e-5, 108 nodes | resident | a_st3 | -0.002559 | -0.002674 | -0.2 |
| tol 1e-5, 108 nodes | invader | a_d0 | -0.005163 | -0.005227 | -0.16 |
| tol 1e-5, 108 nodes | invader | a_st3 | 0.003679 | 0.003835 | 0.13 |
| tol 1e-4, 215 nodes | resident | a_d0 | 0.008559 | 0.00902 | 0.21 |
| tol 1e-4, 215 nodes | resident | d_I | -0.01975 | -0.02032 | -0.12 |
| tol 1e-4, 215 nodes | resident | a_st3 | -0.002559 | -0.00129 | 2.3 |
| tol 1e-4, 215 nodes | invader | omega | 0.08971 | 0.08539 | -0.1 |
| tol 1e-4, 215 nodes | invader | a_l1 | -2.104 | -2.119 | -0.11 |
| tol 1e-4, 215 nodes | invader | a_d0 | -0.005163 | -0.005232 | -0.17 |
| tol 1e-4, 215 nodes | invader | a_st3 | 0.003679 | 0.00343 | -0.21 |

10 of the 11 moves above eps are in elasticities below 0.1 in magnitude. Above one sd: resident a_st3 on tol 1e-4, 215 nodes (-0.00256 -> -0.00129). Here the setting's own error exceeds the quantity's spread across records.

## Curvatures

Added after the eight records above, with `harness/curvature.R` on `PLANT-98` (the stage guard out) at `tol = 1e-4` with the absolute tolerance tied to `1e-4` of it, 108 uniform nodes, each record's own knots. Each entry is `d e / d ln lma` for the column's elasticity `e`, from reverse-mode gradients at `lma * exp(+-D)`, `D = 0.01`, `lma` alone: the resident pinned to its own run's steps, the invader walked through that run's recorded field. The chord is `(e(D) - e(-D)) / 2D`. For `lma` the chord less its `O(D^2)` term is also given: `2 (ln J)'' - chord`, with `(ln J)''` the second difference of `ln J` over the same three points. Why the chord and not a narrower difference is in the design spec's step 4 (*The reply's tests*): on one grid, the gradient jumps as crossings pass the steps' stages.

| seed | res lma, less O(D^2) | res lma, chord | res a_dG2 | res hmat | res stem_P50 | res rho | inv lma, less O(D^2) | inv lma, chord | inv a_dG2 | inv hmat | inv stem_P50 | inv rho |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 31 | -43.86 | -44.18 | -0.5476 | -32.92 | 30.89 | -24.83 | -200.5 | -192.7 | 8.69 | -57.68 | 124.8 | -77.5 |
| 101 | -56 | -55.86 | 1.128 | -40.4 | 39.54 | -29.19 | -218 | -214.9 | 11.1 | -70.83 | 144.9 | -89.48 |
| 102 | -19.34 | -20.5 | 2.101 | -5.692 | 12.94 | -2.697 | -107.6 | -107.6 | 9.025 | -13.46 | 66.18 | -23.42 |
| 103 | -34.35 | -34.33 | 1.019 | -26.8 | 24.52 | -17.18 | -130.2 | -127.6 | 6.831 | -43.6 | 81.36 | -45.39 |
| 104 | -39.34 | -38.14 | 0.696 | -26.75 | 26.54 | -19.06 | -131.6 | -130.4 | 9.283 | -43.93 | 89.48 | -46.82 |
| 105 | -48.64 | -50.41 | 1.459 | -35.73 | 35.48 | -25.84 | -173.3 | -167.6 | 11.11 | -57.2 | 113.5 | -66.56 |
| 106 | -28.32 | -27.49 | 1.415 | -17.04 | 18.89 | -9.932 | -118.4 | -117.3 | 9.049 | -29.3 | 76.74 | -34.1 |
| 107 | -42.92 | -43.09 | 0.2815 | -34.96 | 30.05 | -24.62 | -138.7 | -135.8 | 5.274 | -55.41 | 85.41 | -56.59 |

| quantity | res mean | res sd | res eps | inv mean | inv sd | inv eps |
|---|---|---|---|---|---|---|
| lma, less O(D^2) | -39.1 | 11.6 | 1.16 | -152.3 | 40.2 | 4.02 |
| lma, chord | -39.25 | 11.7 | 1.17 | -149.2 | 38.3 | 3.83 |
| a_dG2 | 0.9442 | 0.81 | 0.081 | 8.795 | 1.97 | 0.197 |
| hmat | -27.54 | 11.4 | 1.14 | -46.43 | 18.2 | 1.82 |
| stem_P50 | 27.36 | 8.64 | 0.864 | 97.8 | 27.1 | 2.71 |
| rho | -19.17 | 9 | 0.9 | -54.98 | 22.1 | 2.21 |

At seed 31 the resident's value less its `O(D^2)` term is -43.86 here against -43.67 from runs adaptive at `lma * exp(+-D)`, and the invader's is -200.5 against -200.9 from the same combination at `D = 0.001`: within 0.2 eps for both.

## Wall time per run

Seconds, with two of these runs at a time on the 4-core machine (other R work shared it for the first hour). The resident's sweep includes a repeat of the forward run to keep its states. The invader's run re-runs the resident to record its field, then walks it.

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

On the eight 108-node runs the forward run takes 81 s (median), the resident's sweep 3.5 forward runs, and a whole seed 12.1 min.
