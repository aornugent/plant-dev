# B. Splits, `control_tf24`, the soil substepped: PLANT-102 to 105 and ODELIA-53 to 55

Read from origin with git and the docs only. Nothing was built or run. "Final config" means
`harness/schedule/refine_case.R` at tol 1e-4. Line counts are hand-written code, with tests
and generated bindings left out.

## Per branch

| branch | adds | measured gain (citation) | used by final config | dependents | verdict |
|---|---|---|---|---|---|
| **ODELIA-53**, 19 commits | **12 foundation commits** (297753b–30f9a7b): `inst/` +3528/−1504; tests and notes +5357. Recording and transpose, walks of rows, `tolerance_factors`, step outcomes and binding component. **6 split commits** (1d7d986–d0d59d5): `inst/` +494/−41, tests +577. `SplitsSignChanges`, `taken_step`, `split_block`, `splits_by_block` | the foundations are what every gradient stands on. Splits: see PLANT-102 | yes: every sweep, walk and pinned replay; tolerance factors; splits | PLANT-95, 99, 100 (foundations); PLANT-102 (splits) | **KEEP, SHRINK.** (1) Drop d32b353: `hermite_interpolator.hpp` (286 lines) is dead. Nothing includes it, and `interpolator.hpp:66` already defines `odelia::interpolator::hermite_interpolator<S, Order>`, so including both headers fails to compile. (2) Move d040766's `notes/probes/` (about 2.0k lines that print numbers and check nothing) out of the package and into plant-dev. Keep its `r_free.cpp` compile check |
| **ODELIA-54**, 1 commit | `inst/` +12/−4, tests +112 | lets the sweep differentiate a row that split. Without it the sweep refuses | yes: every sweep of a split run | PLANT-103 | **KEEP** |
| **ODELIA-55**, 11 commits | `inst/` +656/−98, tests +597. `HasSubsystem`, `subsystem_substeps`, `choose_substeps`, `take_substepped_step`, `prepare_subsystem`, `substep_tol` = 1e-9, `drivers::Function::knots`, `Drivers::knots`. The rain-knot trigger (dff9af7, cb4d262) adds 71 lines | see PLANT-105 | yes | PLANT-105 to 110 | **KEEP, SHRINK the history.** Fold the rename and reshape commits (f19f7de ±1010, 9fe7eae ±400, 695ba9b) into the commits that introduce those names, so the upstream PR does not add names and then rename them |
| **PLANT-102**, 2 commits | +303/−3, tests +107. `Control$ode_split_sign_changes`, `SCM$ode_splits`, the `NamesSignValue` concept, `sign_value_aux`, and in `Patch`: `split_sign_changes`, `take_recorded_splits`, `sample_field`, `split_node`, `node_rates_in_field`. `Species::compute_node_rates` | At 1e-4 on the bank, ×1.05 nudge: plain moves up to 9 of 49 resident entries past ε/6 (worst 0.52ε, which is over ε/3). The split moves none (worst 0.14ε). `ln J` lands 3–13× nearer the reference, J′ = J to the bit (`design-sign-changes.md` §9, *The bank*). The driver's nudge spread falls 3.4–6.4× (`grid-dynamics.md` §11). In the search, a 33ε reverse-pass blow-up without splits was cured with them (`loc/prereg.md`, D2). Cost: forward +5.4% alone (§18, *Finished*); +2.9–3.5% CPU in the loop (`loc/prereg.md`) | yes: `ode_split_sign_changes = TRUE` ("the setting is part of the algorithm", `loc/prereg.md`) | PLANT-103. PLANT-105 (ODELIA-55 serves the substepped block to `dense_state`). PLANT-109 rewrites `take_recorded_splits` by birth date. PLANT-110 | **KEEP.** Dropping it loses the reproducibility gate at 1e-4: plain's 0.52ε fails ε/3. **Caveat:** splits on vs off was never re-measured on the final config (soil substepped, rain substeps, window). The 33ε blow-up D2 credited to splits was later root-caused to the stiff top soil layer, which the soil substeps cure (`localised.md`, *a stiff top soil layer*). So the gain at the final config is inferred, not measured. **Fix where it belongs:** the stale `_snaps/model-version.md`. It lacks `ode_split_sign_changes` here and TF24@v13 from PLANT-100, and is fixed only in PLANT-105 (6ab4e633, 0249bf39). `field_samples` hard-codes `5`, a count that can disagree with odelia's `taken_step::sample_fractions` |
| **PLANT-103**, 1 commit | +97/−27, tests +76. `split_as_recorded`, `node_value_at`, `node_width` | the sweep matches central differences to within 2e-3 on every record, against 7.5e-3 off with the sign changes held (§18, *The sweep through the splits*; §9, G3). Cost: sweep +7.3% | yes: `census_trait_gradient_tf24` on every split run | PLANT-105 and later | **KEEP**, or **MERGE INTO PLANT-102**: PLANT-102 alone cannot produce a gradient, because the sweep refuses a split row |
| **PLANT-104**, 2 commits | +24/−6 R. Exports `control_tf24(tol = 3e-5, base)` | no numerics. It names a setting once | **no.** `refine_case.R` sets the same fields by hand (below). Only `harness/pilot_window.R` calls it | PLANT-105 sets the substep share inside it | **SHRINK, then make it the single source** (below). Built as a stopgap: "becomes plant's defaults … and the function goes" (`design-grid-controller.md`, item 7) |
| **PLANT-105**, 12 commits | +246/−106, tests +212, plus the seasonal gradient reference re-captured (`reference-gradient.tsv` ±361). `Control$ode_soil_substep_max_uptake`. `Parameters`/`SCM$ode_soil_input_slopes` and `ode_soil_substep_ends`. `r_set_ode_steps` takes four vectors. The `HasSoil` concept, `Patch::subsystem*`. `TF24Environment::layer_rates`, `conductivity`, `infiltrated_share`, `uptake_fraction_of_flows`, `rainfall_knots`. The events path replays by step sizes | **Soil substepped (uptake under 10%):** rows −41.5% and −44.8% against the coupled baseline. A gradient run costs 0.63 of the coupled one. Every elasticity stays within 0.063ε. Under constant rain, 0.97× ARK's rows (−64%) (`design-soil-alone.md`, *Gates* G4/G6). It also cures the silent stiff-soil blow-up (elasticities up to 2186) and halves long drought's CPU, 77 s against 158 s (`localised.md`). **Rain substeps:** rows 0.73–0.90 of knot-stopping, worst move 0.23ε (`localised.md`, *The rain's knots … landed*). Without either stops or substeps, J is off 7.6ε (round 4 E) | yes: `ode_soil_substep_max_uptake 0.1`, the four-field pinned replays, no knot pulses | PLANT-106 (pilot), 107–110; the loop's constants (libS) | **KEEP, SHRINK.** Dropping it loses about 37% of a gradient run and the cure for the stiff-soil blow-up, and brings back the knot pulses: a harness-only stop whose absence is silently 17% wrong (round 4 E). Fixes are listed below |

## The requested checks

- **Stop instead of split (all measured, all worse):**
  - Global step ends at crossings cost 2.9–3.3× plain.
  - The sign-change refusal costs 3.4× (`grid-dynamics.md` symptom 9).
  - Halving the steps that hold a crossing costs a forward +9.7–13.5% (killed on per-pass cost).
  - A tighter tolerance costs +41% at 1e-5. The split at 1e-4 costs 0.77 of plain at 1e-5 (`design-sign-changes.md` §2–3; §18).
- **Unmeasured cheaper candidate:** the closed-form correction B (about 250 lines, 0.9% of a run). The judge ranked it first if M2 passed. M2 was never run on TF24 before the 1k-line build (`design-search/judge/verdict.md`).
- **The plain run, for the soil:**
  - The ×10 explicit weight (PLANT-100) is the baseline that the soil substeps beat by 37%.
  - Agent D's step cap at 3/stiffness, on a local branch, fixes the blow-up only. It is held in reserve.
  - The uptake trigger's value beyond the knot trigger is not measured on variable records. On those records most rain-interval steps span a knot anyway. Under constant rain there are no knots, so the uptake trigger is the whole −64%.
- **ARK:** there is no ARK code in PLANT-102–105 or ODELIA-53–55. `grep` finds only `bark`. odelia's existing RODAS gains refusals in ODELIA-55, and plant never selects it. `origin/ark-step` (odelia) and `origin/ark-soil` (plant) remain unmerged, kept by the user (Q2, `design-soil-alone.md`). Deleting them is the user's call.
- **`control_tf24` against `refine_case.R`:**
  - Six of the nine hand-set lines (tol, abs = 1e-4·tol, soil 10, max 100, 15 d, share 0.1) equal `control_tf24(1e-4)` exactly. Those six lines are redundant.
  - The preset is not complete: `ode_split_sign_changes`, required by the algorithm, is missing.
  - Its default `tol = 3e-5` is stale, since the loop runs at 1e-4.
  - Fix: add the split to the preset and default `tol` to 1e-4. `refine_case.R` then becomes `ctrl <- control_tf24(1e-4, Control(node_density_in_birth_date = TRUE))` plus the window's factors. `refine_schedule`'s port into plant (group 2) calls it.

## Mechanisms duplicated across odelia and plant

1. **Two Hermite interpolants in odelia.** `interpolator.hpp` and the dead `hermite_interpolator.hpp`. Drop the second.
2. **The rain's knots pass through four layers.** `Function::knots` → `Drivers::knots` → `TF24Environment::rainfall_knots` → `Patch::subsystem_knots`. Separately, plant's `HasSoil` concept restates the environment members that `Patch` then forwards, one line each, to odelia's `HasSubsystem`: two concepts for one contract. The handover's pending proposal ("odelia's hooks named by the block so TF24 speaks only soil") would remove one of them.
3. **The sample count:** `5` in plant against `sample_fractions` in odelia.
4. **The program through R is four parallel vectors,** with the setter checking their lengths. The user settled this as Q1's default. One `ode_program` field would remove the count check.
5. **Consolidated already:** the split's pieces and the soil's substeps share odelia's `integrate_substeps` and `take_substep`. The substepped block's dense output feeds `sample_field` unchanged.

## Fixes inside PLANT-105

- Fold the rename churn (8ec529b2 ±337, 0249bf39 ±650, c2f37337) into the commits that introduce those names.
- Return the model-version snapshot fix to PLANT-100 and PLANT-102.
- Refuse a replay that has times only (a grid) of a run that substepped. It collapsed the census to about 1e-9 with no refusal (213b7a3b), and "times alone are still a grid".
- `control.h` says "0 never does". A step that spans a rain knot substeps whatever the share, so say that.
- Open: the water-balance sums still read the main step's stages, so they miss 3.1% of dry's rain without stops (`localised.md`).

## Cost of these verdicts

- Every verdict above keeps the numerics, so none of them moves the loop's constants (0.82, 0.33ε).
- Moving the snapshot fix and squashing the history: a rebase of PLANT-100 to 110 with `--update-refs`. The conflicts are confined to `_snaps/model-version.md` and the renamed identifiers.
- Dropping d32b353 and the probes: no conflicts, since nothing includes either.
- If the splits were dropped instead:
  - PLANT-105, 109 and 110 and ODELIA-55 would conflict;
  - `ln J` would move by up to 13× its error and the elasticities by up to 0.19ε, which re-blesses the references;
  - r_min and u_q would need to be re-measured.

  Run the cheap settling test first: a ×1.05 nudge with splits off on the final config. Until then, keep the splits.
