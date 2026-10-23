# Leaf table: can a precomputed P replace TF24's leaf optimisation?

A pilot on the closed-canopy stand of `spikes/field-dimension-066` (CASE closed). It asks
four things: how much of an invader evaluation the leaf costs, what the leaf's inputs are
along real trajectories, how well a table of P reproduces the live leaf, and what the
table's error does to ln R′.

## Result

- **The leaf is about 90% of the time** in both the resident run and the invader replay.
  A rate evaluation solves the leaf once per cohort per RK stage, at 8.8 µs a solve.
  - One invader in `run_mutant` (36 cohorts) takes **1.50 M leaf solves**, about 14.7 s.
  - Each `run_mutant` call first re-runs the resident pinned to its steps, which takes
    another 4.13 M solves (about 39 s).
- **The leaf has no hidden state.** Plant's own `Individual$compute_rates`, given only
  the logged (L̄, ψ by layer, h), reproduces the live P to 1e-10.
  - The climate is constant in this stand.
  - The inputs are L̄, five ψ, and height. Height enters twice: the conductance
    k_max = K_s θ / path(h), and the root network built from min(h, rooting_depth_max).
- **Soil compresses to two numbers, not one.**
  - The two are ψ₁ and a mean of layers 2–5 weighted by wet root conductance. With them,
    P is reproduced to rms 0.004, max 0.09, against a median |P| of 11.6.
  - A single conductance-weighted mean is 70× worse (rms 0.29, max 1.4). Layer 1 carries
    93–100% of the wet conductance, but it dries first. The deep layers then supply the
    water, and at times take water back from the stem (hydraulic redistribution), through
    the nonlinear vulnerability curve.
- **A 4-D table (L̄, ψ₁, ψ_deep, h) with multilinear reads reaches 0.1% rms in P at
  32×32×16×32.** Error falls about as h², but it carries a negative bias: P is concave, so
  linear reads sit under it.
- **ln R′ is too sensitive for that accuracy.**
  - d ln R′ / d ln P is 50–65 for an ordinary invader. For the resident's own traits on
    the closed stand it is 10³–10⁴, and nonlinear.
  - In-run, the best table moves ln R′ by:
    - −0.023 for pool invader 2 on the closed stand;
    - −0.007 for the identity invader on the open stand;
    - −0.86 for the identity invader on the closed stand.
  - The jitter floor of these runs is 3e-4.
  - Holding ΔlnR′ ≤ 1e-3 at a gain of 60 needs P's systematic error below about 1.6e-5
    relative. That is 25× below the best table here, and about 5× finer per axis for a
    multilinear table: on the order of 10⁸ points.
- **Speedup, if the error were acceptable.**
  - The leaf share is 0.90–0.91, so the ceiling on one invader's marginal cost is about
    10× (14.7 s → about 1.5 s).
  - Building the table per trait vector costs n × 8.8 µs in C++: 0.85 s at 96k points,
    4.6 s at 524k.
  - So one fresh invader runs 6× faster at 96k (rel. bias 1e-3) and 2.3× at 524k
    (4e-4).
  - The pool of 48 runs 4.8× faster at 96k: 745 s → about 155 s, including the pinned
    re-run.
  - A table reused across fields (the 17 perturbed residents, or the passes of a
    gradient) amortises its build, and the speedup approaches 8–10×.

**Verdict.** A table can screen invaders: rank them, and read the sign of ln R′ where
|ln R′| ≫ 0.05. It cannot replace the leaf where ln R′ is read near its noise floor, as in
the field-dimension spectra and the derivatives.

## What was run

- **Build.** plant a1e6c061 (`ODELIA-66`), odelia 0.9.0 (8b7b934), phylloptim 0.11.0
  (ef75769). They are installed `-O2` into `/home/a/.claude/jobs/9d586e52/rlib-leaf`; the
  odelia and phylloptim installs are copied from `rlib-refine` and their headers are
  identical to those commits. The plant build carries `leaf_probe.patch`, which is
  pilot-only and inert unless its environment variables are set. The patch:
  - counts and times every `solve_leaf`;
  - logs (inputs, outputs) at every 10th leaf call;
  - can replace one species' P by a table (`PLANT_LEAF_TABLE`) or scale it
    (`PLANT_LEAF_PSCALE`). The species is keyed by an exact vcmax_25 (`PLANT_LEAF_KEY`),
    and the live solve still runs.
- **Stand** (`run.R`):
  - long-wet record; resident lma 0.32·e⁻¹ and the other traits at their defaults;
    ln b* = 3.595;
  - lifetime 40, 108 uniform introductions, `ode_tol_rel` 1e-4, birth-date coordinate;
  - invaders from the field-dimension pool, on every third introduction;
  - 12 586 steps.
  - `CASE=open` gives the long-drought stand (lma 0.32, ln b* = 1.539, 8159 steps).
- **Profile.**
  - `profile.sh` gives wall-clock times and leaf-solve counters, for the resident alone
    and for the resident plus 2, 3 or 4 invaders. The per-invader cost is the difference.
  - `gprof.sh` samples natively with gperftools. It is started from inside R around each
    phase through `gprof_shim.c`, because `perf` is closed (`perf_event_paranoid` = 4)
    and an `LD_PRELOAD`ed profiler kills `Rscript`'s exec. The top of each cumulative
    profile is in `results/prof_*.cum.txt`.
- **Inputs** (`inputs.R`): 1.52 M logged calls (every 10th) from the resident run and
  from `run_mutant` over pool rows 1–3. Output is in `results/inputs.out`.
- **Compression** (`compress.R`) and **table** (`table.R`): both evaluate through plant's
  `Individual` at 105 µs a point from R. The table axes:
  - light from 0.08 to 1;
  - asinh(ψ/1 MPa) for ψ₁ from 1e-4 to 8 MPa and ψ_deep from 1e-4 to 6 MPa;
  - log h from 0.3 to 20 m.
- **Effect on ln R′.** `lnR.sh`, `scale.sh`, `scale2.sh` and `lnR2.sh` put the table or
  a scale on one invader's P in a real `run_mutant`. All runs are in `results/lnR.csv`.

## Profile

Closed stand, gperftools at 200 Hz, inclusive shares:

| | resident run (64.5 s) | run_mutant, 2 invaders (68.7 s) |
|---|---|---|
| leaf optimisation (`solve_leaf` + `set_physiology`) | 90.8% | 91.0% |
| rest of the strategy's rates (crown-light quadrature 2–3%, root network 0.5–0.8%, allometry, storage) | 6.2% | 6.5% |
| light field build (`Patch::compute_environment`) | 2.7% | 1.8% |
| soil (`TF24_Environment::layer_rates`) | 1.0% | 0.2% |
| ODE stepping and the rest (no tape on a forward run) | ≤1% | ≤1% |

The leaf counters agree: 57.4 s of the 64.5 s resident run is inside `solve_leaf`, and
13.1 s of the 14.7 s each invader adds. No solve replays a recorded operating point,
because `run_mutant`'s pinned re-run of the resident solves afresh.

Inside the leaf, the collar root-finder (TOMS 748 bracketing) is 71% inclusive. Each
probe solves the stem and c_i problems (`psi_stem_to_ci` 28%) and the multilayer uptake
(`uptake_impl` 32%), so the cost is the number of probes.

**Leaf solves per invader evaluation: 1.50 M.** That is 36 cohorts × about 42 k each:
about 6.6 per step per living cohort, one per RK stage plus the establishment
evaluations. On top of that come 4.13 M for the pinned resident re-run, once per
`run_mutant` call. The resident's own adaptive run takes 6.55 M.

## Inputs along trajectories

Climate is constant here: VPD 1 kPa, c_a 40 Pa, T_leaf 25 °C, PPFD 1800.

The first block is the pinned runs (`run_mutant`); the resident row is its own adaptive
run.

| | L̄ (1%–100%) | h (m) | ψ₁ (MPa, 1%–99%) | ψ₃ | ψ₅ | k_max |
|---|---|---|---|---|---|---|
| resident traits, pinned | 0.16–1 (median 0.75) | 0.37–18.1 | 0.0026–5.1 | 0.0027–0.21 | 0.0028–0.071 | 4.0e-5–4.9e-4 |
| invader vcmax 127 | 0.15–1 (0.66) | 0.36–13.3 | 0.0025–5.1 | same field | same field | 5.8e-5–6.1e-4 |
| invader vcmax 96.1 | 0.13–1 (0.62) | 0.38–14.2 | 0.0025–5.1 | | | 4.2e-5–4.4e-4 |
| resident, adaptive run | min 0.089 | | 1.9e-6 – 1000 (cap) | | | |

- The light floor binds at 0.089: no call reaches the 1e-4 clamp.
- The adaptive run's rejected stages probe the soil far outside the accepted range, out to
  the 1000 MPa ceiling at single layers. The pinned runs never do.
- ψ_deep reaches 5 MPa in the dry spells.
- Operating points: 85% are interior and 15% sit on the ψ_crit bound (BoundaryCrit);
  BoundaryRootCrit, Determined and HydraulicShutdown together are under 0.1%.

**Does soil compress?** The supply is Σᵢ (ψ_c − ψᵢ − zᵢ)/(r_H,ᵢ span/∫f_r + r_V,ᵢ), so it
is linear in ψ only while f_r ≈ 1. Errors in P, from 3000 resident-trait calls (half of
them with ψ₁ > 0.2), with the 6 calls at the ceiling excluded:

| soil passed to the leaf | rms | p99 | max |
|---|---|---|---|
| all five layers (check against the log) | 5e-11 | 3e-10 | 9e-10 |
| ψ_w, one wet-conductance-weighted mean | 0.29 | 0.90 | 1.37 |
| ψ₁ in every layer | 0.84 | 2.4 | 2.9 |
| ψ₁ and ψ_deep (the conductance-weighted mean of layers 2–5) | **0.0041** | 0.022 | 0.095 |

## Table accuracy in P

The error is against the live leaf along the logged calls of that trait vector. It
includes the two-number soil compression. The median |P| is about 11.

| trait vector | grid | points | rms | p99 | max | bias |
|---|---|---|---|---|---|---|
| resident (row 1) | 12×12×8×12 | 13 824 | 0.064 | 0.24 | 0.75 | −0.023 |
| | 20×20×12×20 | 96 000 | 0.026 | 0.11 | 0.50 | −0.011 |
| | 32×32×16×32 | 524 288 | 0.010 | 0.047 | 0.23 | −0.0039 |
| pool row 2 | 12×12×8×12 | 13 824 | 0.081 | 0.33 | 0.79 | −0.019 |
| | 20×20×12×20 | 96 000 | 0.031 | 0.15 | 0.32 | −0.011 |
| | 32×32×16×32 | 524 288 | 0.012 | 0.056 | 0.13 | −0.0043 |

- The soil axis matters. log ψ, the first try, left 0.09 rms at 524k: the error sat in
  the dry end, where P moves most. asinh(ψ/1 MPa) cut it 9×.
- The largest residuals are BoundaryCrit points: there P has a kink across the change of
  regime.

## Effect on ln R′

| stand, invader | gain d ln R′/d ln P (from P × (1 ± 1e-4)) | table 13.8k | 96k | 524k |
|---|---|---|---|---|
| closed, pool row 2 (ln R′ = −1.11) | 64 (symmetric) | −0.15 | −0.062 | −0.023 |
| open, identity (ln R′ = 0.48) | 49 (symmetric) | | −0.020 | −0.0070 |
| closed, identity (ln R′ = 1.00) | 3.5e3 / 7.1e3 (asymmetric; 6.9e3 / 7.6e3 at ±1e-5) | −1.37 | −1.23 | −0.86 |

The in-run shifts match the gain times the table's relative bias. For row 2,
64 × (−4.0e-4) = −0.026, against −0.023 measured. So the bias, not the scatter, is what
moves ln R′.

The closed-stand identity invader is a knife edge: 1e-5 in P moves its ln R′ by 0.07. It
was not chased further. It shows that some invaders in a closed canopy sit where survival
compounds a near-compensation carbon balance over decades.

## What blocks a table

1. **Accuracy against the gain** (above). This is the binding constraint.
   - Bias correction (a C¹ or cubic read, or subtracting the concavity bias) would buy
     perhaps an order of magnitude. That is not the 25× or more needed, and kinks at
     regime changes cap any smooth interpolant.
2. **One table per leaf-relevant trait vector.**
   - P depends on vcmax_25, K_s, rooting_depth_max (and θ, a_r1, the root shape), but not
     on lma, rho or hmat. Invaders that share the leaf traits could share a table; this
     pool varies all six.
   - A selection gradient over traits needs ∂P/∂trait, which a fixed-trait table does not
     have.
3. **Height is a fourth axis, not hidden state.** k_max moves with h at every height. The
   root network is the same for every cohort at a given h and traits, and stops changing
   once h > rooting_depth_max. So there are no per-cohort root networks, beyond height.
4. **No history dependence.** The leaf reproduces from its inputs to 1e-10, and the
   pinned runs never replay a recorded point.
5. **Constant climate here.** Time-varying VPD, temperature, CO₂ or PPFD add an axis each.
6. **Residents need transpiration by layer.** The two-number soil compression loses the
   per-layer split. Invaders don't feed back, so for them only P matters, and the pinned
   resident re-run keeps the live leaf.
7. **The AD path.** `record_leaf_outputs` asks the leaf for its derivatives at the solved
   point. A table would have to supply ∂P/∂(L̄, ψ₁, ψ_deep, h) from a C¹ interpolant;
   multilinear slopes are piecewise constant.
8. **Adaptive runs.** Rejected stages probe ψ far outside any table, out to 1000 MPa. A
   table needs a clamp or a fall-back to the live leaf there. The pinned replay never
   probes there.

**What would keep the exact answer.** The leaf's cost is the number of probes in the
collar root-finder (71% of the leaf). A small table of the collar ψ (`opt_root_psi`) over
the same four axes could seed a tight bracket or a Newton start. P would then be the live
optimum to solver tolerance, and the gain above would not apply. The speedup is bounded
by how many probes the bracket saves, perhaps 2–4×; it was not measured here.

## Files

- `build.sh` installs the instrumented plant (`leaf_probe.patch`, applied to plant
  a1e6c061).
- `run.R` is the stand: resident, then `run_mutant`. It also holds the profiling hooks.
- `profile.sh`, `gprof.sh` and `gprof_shim.c` produce the timings and the native
  profile.
- `inputs.R`, `compress.R` and `table.R` (with `common.R`) produce the input ranges, the
  soil compression and the table accuracy.
- `lnR.sh`, `scale.sh`, `scale2.sh` and `lnR2.sh` are the in-run checks of ln R′.
- `results/`:
  - `inputs.out`, the leaf counters (`stats_*.txt`) and the profile tops
    (`prof_*.cum.txt`);
  - `lnR.csv`, every ln R′ run.
- `table_accuracy_*.rds` holds the table-accuracy rows.
- Raw logs, tables and profiles are in `/home/a/.claude/jobs/9d586e52/tmp/leaf/`.
