# Addendum: per-member events, at their real cost

The consult reported this test as running. It has finished. The setting is the
test instance's, at `tol = 1e-4` and `3e-5`.

**The method.** Each member whose `P` crosses zero inside a step is split there.
The crossing is located on an interpolant of the step, the member is
re-integrated on the sub-steps in the step's fields, and the step's end is
corrected. A member whose `P` dips below zero and back inside one step is cut
twice.

**The interpolant must be of the step's order.**
- *A cubic* through the step's ends puts the fields the split members read off
  by more than one error weight on a sixth to a third of the crossing steps. `J`
  then moves away from `J*`: +1.6e-4 at `1e-4`, against +3.7e-5 unsplit.
  Halving only the crossing steps shrinks that move 10–13× each time, as `h⁴`.
  This explains the cubic result listed under *What we cannot yet explain*.
- *A quintic* through a half-step midpoint gives `J − J*` = +4.0e-6 at `1e-4` and
  +1.0e-6 at `3e-5`. The error now falls with `tol`, 9–12× nearer `J*` than
  unsplit.

**What it buys.** These are the largest moves of four elasticities over seven
tolerances within 5% of `1e-4`, in units of `ε/3`:

| | unsplit | split |
|---|---|---|
| `ln J` | 0.003 | 0.001 |
| the four elasticities, `θ_A`'s last | 1.05, 1.26, 0.91, 0.48 | 0.17, 0.28, 0.14, 0.06 |

- *The crossings are 70–85% of the spread.* The split cuts its standard deviation
  3.4–6.4× and leaves its mean within 0.4 `ε/3`.
- *The second derivative in `θ_A` is restored.* Unsplit, it sits 2.8–4.4ε below
  the wide chord at differences of 3e-4 to 1e-3; split, it is within about 1ε.
- *The grazing pair* sits at a knot where a pulse starts, its two crossings on
  either side of the step boundary. With two cuts, the split passes through its
  disappearance continuously, to the noise floor.

**What it costs.**
- *In member evaluations:* 10.2% more on an adaptive forward and 12.4% on a walk
  of the recording. The quintic's midpoints are 5.2 points of that.
- *Against the alternative:* `tol = 1e-5`, our remedy for the spread until now,
  costs about 41% more.
- *Possible savings, counted but not measured:* a stage-based interpolant, a
  shared solve of the member created now, and locating from the stages would
  bring the split to about 8%, or 3% with a pair whose fourth-order interpolant
  is free.
- *Not measured:* the reverse sweep's cost with the split, estimated at +10–20%,
  the probe with it, and other records.

**What this changes in our questions.**
- Per-member events become the step's part (d), on an interpolant of the step's
  order with two cuts for a dip.
- The open choice is the pair. One with a free interpolant of the step's order
  would cut the split's cost by about a factor of three.
