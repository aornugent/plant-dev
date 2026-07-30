# Probes and drivers

Each `*.R` here states its CONFIGURATION and its RESULTS in a header, so a number can be re-taken
without reconstructing how it was produced. Build `-O2` deliberately before timing anything — see
plant-dev `AGENTS.md`, "Testing plant".

`../docs/build-plan.md` §5b is the measurement list and says what each decides. `M1`
(`m1_moving_bound.cpp`), `M2` (`m2_canopy_shape.cpp` with `m2_canopy_shape.sh`), `M3`'s accuracy half
(`m3_fixed_fractions.R`), `M5` (`m5_scratch.R`, which needs
`../docs/reports/m5-scratch-arms.patch` applied to the tree it loads), `M6`, `M7`
(`aux_round_trip.R`) and `M8` (`descending_heights.R`) are run. `M4` is not, and `M3`'s bit-identity
half waits on P2.1.

Timings: a production TF24 lifetime is ~86 s at `-O2` on this box with `collect = FALSE`, and
`collect = TRUE` adds ~38 s of R-side assembly. An incremental rebuild after touching one header in
`inst/include/plant/` is ~2m45s, not the ~25 min a full build costs.

The two C++ probes carry their own build lines. Both need `odelia/src/Tape.cpp` for XAD's
`active_tape_`, and R plus Rcpp because `ode_util.hpp` reaches Rcpp for `util::stop`. Two more
things they cost: `<chrono>` must precede `<XAD/XAD.hpp>`, or `chrono_io.h` fails to parse; and
holding two versions of one header in a translation unit means rewriting one into its own
namespace **after** its `#include`s are stripped, since a header included inside a namespace looks
up `std::` inside it.

Four traps that cost time:

- `max_patch_lifetime` must be set on the **base** parameters, before `add_strategies` — that call
  builds the node schedule, and a later change leaves the schedule past the lifetime
  (`time_max must be greater than (or equal to) current time`).
- R buffers `cat` output to a file, so a long probe shows nothing until it exits. Do not read progress
  from a redirect; wait for the exit.
- `pkill -f <pattern>` matches the shell running it. Use a bracketed class: `pkill -f "gradient_bud[g]et"`.
- `run_scm(collect = TRUE)`'s `$species` **is** the flat tibble of one record per (step, node), so
  `r$species[[1]]` is its first column rather than the first species. The same object's
  `$env$soil_moist` is long over (step, layer) with no layer column, five rows per output time in
  layer order.

---

# Rainfall transients, cherry-picked

Drivers built to stress TF24's soil solver. Brought here so the coupling work in
`docs/archive/05-soil-plant-coupling.md` (archived) can be measured against a driver that produces
wetting and drying **fronts**, rather than against a uniformly scaled-down constant
rainfall — which shifts the mean and collapses the stand instead of moving the collar
across its operating regimes.

## Provenance

| path | from |
|---|---|
| `tf24-benchmarks/data/*.rds`, `generate_bank.R`, `BASELINE.md` | plant-dev `claude/tf24-multi-rate-stepper-n5audm` |
| `tf24-multirate/data/rainfall_scenarios.csv`, `gen_rainfall.R` | plant-dev `claude/multirate-stepper-review-r6dpwn` |

Each `data/<name>.rds` is a list of `rain` (daily vector), `life` (years) and `desc`.
`_manifest.rds` names the six.

## What is in them

Measured on the files as checked in:

| scenario | life (yr) | days | mean/d | sd/d | max/d | dry days | longest dry run |
|---|---|---|---|---|---|---|---|
| `dry_to_wet` | 25 | 9 125 | 0.613 | 5.64 | 172 | 95.1% | 652 |
| `long_horizon` | 70 | 25 550 | 1.360 | 11.80 | 400 | 93.6% | 376 |
| `extended_drought` | 30 | 10 950 | 0.213 | 2.24 | 84 | 97.1% | **1 100** |
| `intense_storms` | 20 | 7 300 | 0.510 | 6.42 | 223 | **98.0%** | 360 |
| `multispecies` | 40 | 14 600 | 0.982 | 8.11 | 291 | 94.0% | 360 |
| `whiplash` | 24 | 8 760 | 0.908 | 8.21 | 289 | 95.5% | 377 |

The generator's five climate columns, for reference:

| | drought | dry | semiarid | wet | monsoon |
|---|---|---|---|---|---|
| mean/d | 0.030 | 0.079 | 0.863 | 1.640 | 0.606 |
| sd/d | 0.432 | 0.893 | 4.438 | 6.817 | 4.073 |
| dry days | 99.2% | 98.6% | 91.2% | 86.8% | 96.4% |

The shape that matters: **the mean is low and delivered in bursts.** Standard deviation is
6–9x the mean, 94–98% of days are dry, and dry runs reach one to three years. That is what
makes them useful here — a front moves the whole profile through the retention curve, so the
collar traverses its feasible interval repeatedly rather than sitting at one end.

## What they are good for, and what they are not

**Good for incidence and robustness.** Counting how often a discrete construct is reached is
a robust question on these traces, and they were built to reach constructs a benign driver
does not.

**Not good for accuracy.** Report 5 section 6 records why: every trace sits at offspring
1e-8 to 1e-13 by construction, where the functional is ill-conditioned for every method
while its own trajectory converges cleanly, and the same species and birth rate give
offspring ~1 under constant rainfall. An accuracy reference needs a regime where the
functional is O(1), which means the model's own seasonal driver at a sustaining mean with
amplitude dialled up — not these.

## Running the probes against develop rather than the branch

The probes take the package path from `pkgload::load_all("plant")`, which resolves to the
submodule — and the submodule tracks a feature branch, not `develop`. To measure develop:

```sh
git -C plant worktree add /home/user/plant-develop origin/develop
cd /home/user/plant-develop && make compile          # ~25 min, serial
sed 's#load_all("plant"#load_all("/home/user/plant-develop"#' scripts/<probe>.R > /tmp/p.R
Rscript /tmp/p.R
```

The installed `odelia` now includes `<XAD/XAD.hpp>` in `ode_util.hpp`, so the
`-include XAD/XAD.hpp` workaround an earlier note recorded is no longer needed.

Verified identical between develop and the branch (so forward-path numbers transfer):
`set_leaf_states_rates_from_psi_stem`, `prepare_collar_solve`, `find_root_collar_psi`,
`evaluate_root_collar_psi`, `profit_at_collar_psi`, `E_from_Soil_to_Root_Collar`.
Differing: `set_shutdown_state`, `dprofit_droot_collar_psi`, `dE_from_soil_dpsi_collar`.
