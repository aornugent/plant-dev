# harness

R scripts that drive plant's TF24 from plant-dev, kept from the trusting-curie branch.
The one-off experiment drivers stay on the tag `archive/trusting-curie`. Run them from the
plant-dev root. `long_drought.R` loads plant from `PLANT_LIB` (an installed library) or
`PLANT_DIR` (a source tree; default the plant submodule).

Most need plant's open TF24 stack (PLANT-117, plant#118, or later), not `develop`.

| script | what it does | needs |
|---|---|---|
| `long_drought.R` | the rainfall records (`mkenv()`), the 40-year long-drought stand, `run_J()` | plant |
| `schedule/refine.R`, `schedule/refine_case.R` | the node-schedule refine loop, and one of its five cases at the setting they were measured on (`docs/schedule/refine.md`) | the open stack |
| `run_record.R` | the general driver: one stand and its invaders, stand and selection gradients, each phase timed and failures recorded, saved to an RDS that the analysis scripts read. The header lists every flag | the open stack; `WEIGHT_*`, `METHOD`, `SPLIT` and `PROGRAM` need branches with no PR (state-weights, ark-soil, sign-changes; the tolerance factors land per `docs/schedule/time-axis.md`), and `SHARE` is superseded by plant#115's substeps |
| `equilibrium.R` | the demographic equilibrium J(b*) = b* by a secant in ln b and by iteration, then the implicit-function warm start for a trait move | the open stack |
| `walk_identity.R` | checks that an invader walked at the resident's traits gives ln R′ = ln J − ln b | the open stack |
| `regnans_solvers.R` | regnans's equilibrium solvers (nleqslv, dfsane) on TF24 with node times held, for comparison with the secant | the open stack and a regnans checkout |
| `spot_check.R`, `node_parts.R` | convergence checks over saved `run_record.R` outputs in units of ε, and the split of a node error into its field and quadrature parts with a Richardson ratio | saved runs only |
| `ark436.R`, `stability.R` | Butcher tableaus (ARK4(3)6L, Cash–Karp, DP5), order conditions, stability boundaries and stage positivity on y′ = −y/T: the reference for any stepper choice | nothing (pure R) |
| `renewal_toy.R` | the Overstorey post's pulsed-rain toy: its mean lifetime output against a rare lineage's growth through its seed bank on the same series (`docs/schedule/workflows.md` §2) | nothing (base R, about 3 minutes) |
| `profile_forward.R`, `../scripts/profile-gradient.sh` | gperftools profiling of a gradient, guarding against LD_PRELOAD onto the R binary and pkgload unlinking the .so | gperftools |

Data: `schedule/data/eps.csv` is ε per quantity; `schedule/data/weights/` holds
control_window's rule-A tolerance weights per record (`docs/schedule/time-axis.md`).
