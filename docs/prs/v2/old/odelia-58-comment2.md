## How long the copy lives

The copy is one row owned by `SolverInternal` (`row_copy_`), assigned
from the recorded row at the start of each step and left alone until
the next step assigns it again. A System that keeps a pointer into the
entry it was handed can therefore read through it after the evaluation
ends, up to the next step's first evaluation, which is how long it
could read through a pointer into a recorded row in a pass that only
reads.

plant relies on that span. Its `Patch` keeps a pointer to the light
field it read from a row (`loaded_field`) past `end_solved`, because an
insertion between two steps introduces nodes at the instant the row
below ended and evaluates their inflow in that field. In a pass that
stores, that pointer is into the copy, and the copy still holds that
step's field when the insertion runs.

A rejected-and-retried attempt does not arise here: a pass over a
recording takes each recorded step once, at its recorded size.

## What the pass records, and so what its sweep differentiates

Where the pass keeps its states, `stepper_step` copies the copy into
the step's scratch row, and the accepted step moves that onto its
record, as it does for a run that solves afresh. The pass's recording
therefore holds the values the pass solved, and `solve_adjoint` on it
hands each evaluation those values, `const`, in place of solving.

In the whole game this is the difference between the two sweeps:
`reads` differentiates a pass that took the recorded `s = 1` at every
stage (148.41251, its own central difference), and `stores` a pass that
took its own `s = 0.5` past `y = 100` (117.7283, its own central
difference). Neither sweep matches the other pass, and each matches the
pass it recorded. For plant's invader the first is the derivative of
fitness at the resident's leaf and the second at the invader's own.

## Cost

Counts, for a pass over a recording of `n` steps with the argument
true: `n` row copies into the solver's row, plus `n` more into the
records where the pass keeps its states. The Chooser run in the whole
game has `n = 24` with six entries per row. A pass without the argument
copies a row only where it keeps its states, as on 0.8.1. The rate
evaluations are the same six per step either way.

## Tests

`test_a_pass_on_copied_rows_stores_its_own_values`, under Cash–Karp and
Dormand–Prince, steps the r = 2 recording at r = 5 with the argument
true and checks that the pass lands where the run's program alone lands,
bit for bit, without loading any recorded row; that each of a step's
six evaluations is handed the recorded row before it stores; that its
own recording holds its own choices, which differ from the run's;
that its sweep loads every row at the instant it was made; and that
the sweep matches a central difference of the pass to 1e-8 relative. `tests/standalone` passes under clang and GCC 13.
