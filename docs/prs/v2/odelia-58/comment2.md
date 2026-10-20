## How long the copy lasts

The copy is a single entry owned by the solver. It is filled from the
recording at the start of each step and is not touched again until
the next step starts. A System that keeps a pointer into the values it
was handed can therefore read through that pointer after the
evaluation ends, until the next step begins, just as it could read
through a pointer into the recording itself.

plant relies on this. Its patch keeps a pointer to the light
environment it read from the step's entry, because a cohort introduced
between two steps has its initial values computed in the light at the
end of the step before. In a replay that stores its own values, that
pointer is into the copy, and the copy still holds that step's light
when the cohort is introduced.

## What the sweep differentiates

When the replay keeps its states, each accepted step's copy is saved
in the replay's own recording, in the same place a fresh run saves the
values it solved. The reverse sweep of the replay then hands each
evaluation those values, read-only, so it differentiates the
calculation the replay made, including the values the System solved
itself. `test_a_pass_on_copied_rows_stores_its_own_values` checks this
under Cash-Karp and Dormand-Prince: the sweep matches a central
difference of the replay to 1e-8 relative.

A replay with the new argument copies one entry per step into the
solver, and one more into its recording when it keeps states. The
number of rate evaluations is the same either way.
