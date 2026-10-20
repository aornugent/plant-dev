TF24's soil water is the fastest part of the model, and on a daily
rainfall record it sets the step length for every cohort. The rain is
a cubic that changes every day, and a step longer than a day reads it
at only six times. Run without stops on a synthetic 41-year daily
record, a stand's offspring production J came out 26% low. The usual
workaround, a zero-depth rainfall pulse on every day, stops the run at
each day, so every cohort is integrated in daily steps.

TF24 now names its soil as the fast part that odelia 0.8.1 integrates
in substeps. A step that crosses a day boundary integrates the soil in
short substeps, one ending on each day boundary, while the plants are
evaluated at the usual six points. On that record a run without stops
lands within 0.07% of the stopped run in 0.41 times as many steps, and
its gradient takes 0.35 times as long. Runs that keep their stops are
unchanged. Each step records its substeps, and `set_ode_steps()` takes
those records beside the step times and sizes, so a replay repeats the
same calculation.

Closes #105
