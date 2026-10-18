# Brief: aggregate review of the stack since develop — is each piece worth keeping?

The user's principles (apply them hard): Laziness Protocol (prefer deletion, minimise the diff,
consolidate decisions, flat call hierarchy), Subtract Before You Add, Minimize Reader Load,
Foundational Thinking, Model the Domain. Code style and naming: /home/user/plant-dev/AGENTS.md.
Goal: /home/user/plant-dev/OBJECTIVES.md. The user already suspects PLANT-108 (the spread) is
redundant. Default verdict for every piece is DROP unless evidence shows it is needed by the final
configuration or buys a measured gain worth its code.

## The stack (aornugent forks, origin branches already fetched)
- plant (/home/user/plant-dev/plant): one chain over origin/develop (95256cf3):
  PLANT-93 → 95 → 97 → 98 → 99 → 100 → 101 → 102 → 103 → 104 → 105 → 106 → 107 → 108 → 109 → 110.
  Each branch's own commits: `git log --reverse origin/PLANT-<prev>..origin/PLANT-<n>`; its diff:
  `git diff --stat origin/PLANT-<prev> origin/PLANT-<n>` and `git diff ...`.
  Side branches off the chain: PLANT-96 (off 95), the averaged establishment gate (b3a33626, 6613dd24).
- odelia (/home/user/plant-dev/odelia): ODELIA-53 → 54 → 55 over origin/master (31 commits).
- phylloptim (/home/user/plant-dev/phylloptim): PHYLLOPTIM-17 → 18 → 19 over origin/master.
- Inventory and proposed split: /home/user/plant-dev/docs/stack-split.md.

## The final configuration (what the delivered algorithm actually uses)
`harness/schedule/refine.R` (refine_schedule) and `harness/schedule/refine_case.R` (the control):
- control: ode_tol_rel 1e-4, ode_tol_abs 1e-8, node_density_in_birth_date TRUE,
  ode_tol_factor_soil 10, ode_tol_factor_times/values from a stored per-record weight file
  (scratchpad dev/window/rule_A/weight_<record>.rds, the "window" rule), ode_tol_factor_max 100,
  ode_step_size_max 15 d, ode_split_sign_changes TRUE, ode_soil_substep_max_uptake 0.1;
  events(events_default(p)) with no rain-knot pulses.
- per run: SCM run with record_trajectory, census_trait_gradient_tf24 (all-trait elasticities),
  pinned replays (p$ode_times, ode_step_sizes, ode_soil_input_slopes, ode_soil_substep_ends),
  establishment_weights (exact counts), net_reproduction_ratio_by_node, store_trajectory.
- Invaders, curvatures, walks: planned by OBJECTIVES, not yet used by the loop.
- The loop's constants (0.82, 0.33ε) were measured on libS = the chain through PLANT-110 +
  PHYLLOPTIM-19 + the rain substeps (now inside PLANT-105).

## Evidence to consult (claims need a citation: file and section)
docs/handover.md (progress table), docs/grid-dynamics.md (§8 window/weights, §10 ARK, §14 thinning,
§15 soil alone, §16 node axis spread vs lumped, §18 splits), docs/design-grid-controller.md,
docs/design-soil-alone.md, docs/design-sign-changes.md, docs/measurements/{soil-alone,
sign-changes, canopy-spread.md, perf-*.md, spot-check.md, root-p50.md}, docs/measurements/
schedule-search/ (incl. the stress test of the birth-date representation: crown spread vs lumped vs
exact interval light — search for "spread", "lumped", "stress"), docs/design-schedule-building.md,
docs/map-schedule-building.md.

## Per branch, report
1. What it adds: commits, lines (+/−), new public names (R functions, control fields, C++ types).
2. What it bought, measured (number + citation), or "no measured gain found".
3. Used by the final configuration? (yes, which call/field / no / only by a later branch).
4. Dependents: which later branches build on it (would a drop conflict?).
5. Verdict: KEEP / DROP / MERGE INTO <branch> / SHRINK (say what to cut), with the finding test:
   "keeping it makes <future task> harder because <mechanism>" or "dropping it loses <measured X>".
6. Cost of the verdict: rebase conflicts expected, references to re-bless, loop constants to
   re-measure (if a dropped piece changes numerics the loop's evidence rests on, say so).

Do not build, install or run SCM runs (three refine runs are using the cores). git, grep, reading
and tiny R snippets on saved data only. Do not commit, push or edit code. Write your section to
the file named in your prompt; keep it under ~2 pages; tables welcome.
