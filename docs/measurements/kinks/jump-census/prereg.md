# Census of rate jumps on accepted stages (registered before the runs)

**Question:** how often do TF24's rate jumps occur on the stages of accepted steps,
across the ten-case bank? The jumps are inventory #13 (Determined collar), #14
(HydraulicShutdown) and #19 (the soil's positivity guard). The inventory's counts mixed
in rejected attempts, or came from older builds.

**Why it matters:** a jump inside a step leaves a gradient *bias* of Δf·dt/dθ, not jitter.
It is the one consequence in `deep-search-nonsmooth/first-principles.md` that could exceed
ε.

**Method:**
- For each run of the bank's committed set (`schedtest/adjmap/runs/val_ins75_c_*.rds`),
  replay it pinned on its own saved steps, forward only, on the library it was run with.
  Check that J equals the saved J.
- Read `census_operating_point_counts_tf24` and `census_clamp_counts_tf24`. Each counts
  only the evaluations of the accepted rows a pinned replay walks.
- Where the replay can keep each evaluation's operating-point kinds (the recorded
  solved values), also count the steps in which some node's kind changes into or out of
  Determined, HydraulicShutdown or BoundaryRootCrit between that step's evaluations.
  That is a jump inside a step. Count these steps before and after b = 25.

**Predicted:**

| Kind | Prediction | Probability |
|---|---|---|
| Determined | 0 on dry, dry-flat and wet; > 0 on at least one drought-type record, at < 0.1% of leaf solves | 60% |
| HydraulicShutdown | ≤ 10 solves per record; birth transients only | 60% |
| Positivity guard (#19) | 0 on accepted stages everywhere | 75% |
| Steps holding a change into or out of a jump kind | ≤ 50 per record, most after b = 25 | 50% |
