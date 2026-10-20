On a variable rainfall record TF24's soil sets every step of a run. The
rain is a cubic between daily knots, and a step that spans knots reads
it only at its six stages: on a synthetic 41-year daily record, run
without stops, offspring production J was 26% low. The way round, a
zero-depth rainfall pulse at every knot, made every cohort take the
soil's short steps.

The patch now names the soil as odelia's subsystem (odelia 0.8.1). A
Cash-Karp step that spans a knot integrates the soil in substeps of its
own, one ending on each knot, while the plants take the step's six
stages. On that record, without stops, J lands within 0.07% of the
stopped run in 41% of its steps, and a gradient costs 0.35 of the
stopped run's; a run with stops is unchanged bit for bit. Each step
records its substeps (`ode_soil_input_slopes`, `ode_soil_substep_ends`)
for replays, invasions and the reverse sweep: `set_ode_steps()` takes
them beside times and sizes, and refuses sizes without them across a
knot. `Control$ode_soil_substep = TRUE` (default FALSE) also substeps
the soil wherever its stiffness or its own error holds the step back.

Closes #105
