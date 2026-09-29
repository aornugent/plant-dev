# Objectives

The solver work exists to give gradients from TF24's reverse mode, for residents
and for invaders, on realistic rainfall records. The gradients drive
gradient-based calibration and searches along selection gradients. The aim is
heuristics for the ODE steps and the node schedule, each with a stated guarantee
and a per-run check, not one optimal schedule.

## First: the dynamics converge

Nothing is designed on an axis until the axis passes these tests, on each record.
The time axis's knob is the ODE tolerance; the schedule axis's is the node
spacing in birth date.

- **(a) The error follows its knob.** Along a ladder, `J`'s error falls at the
  axis's order (time with `tol`, the schedule with the spacing squared), with a
  constant stable within about ×3.
- **(b) The error is not a draw.** A nudge to the knob (`tol` within ±5%, or the
  schedule shifted by a quarter of a spacing) moves `J` by at most a tenth of the
  error budget the setting is chosen for. This is also what limits how far `J`
  jumps when a grid is rebuilt during an optimisation.
- **(c) The grid transfers.** A grid built at `θ₀` still passes (a) and (b) at
  every `θ` within `Δ` of `θ₀` (`|ln θ_k − ln θ₀,k| ≤ Δ` in each parameter), and
  for invaders within `Δ` of the resident. No stage leaves the model's domain and
  nothing throws. The largest such `Δ` is the grid's trust radius.

The tests apply to the gradients as well as to `J`.

Designs judged on dynamics that fail these are judged against chance. The
stepper was measured where `J` was a draw at every tolerance, and a schedule
rebuilt at a new `θ` was worse at all four points tried.

## Then: the goals

1. **Resident gradients on a fixed grid.** Away from an optimum, relative error
   at most 0.3 (Carter 1991; below 1 for descent). Near one the gradient goes to
   zero, so bound the error in the optimum's location, `|H⁻¹·δg|` with `H` the
   objective's Hessian and `δg` the gradient's error, against the precision
   wanted in `θ`.
2. **One grid per rainfall record, shared across `θ` and by invaders, within its
   trust radius, which a check on every run reports.**
   - The selection gradient is taken at the resident's traits, where the invader
     runs on the resident's own grid, so goal 1 applies.
   - The radius covers the rest: invaders across a trait range, fitness
     landscapes, and the resident as `θ` moves.
   - Near a singular strategy, bound the error in its location.
3. **Heuristics that each come as a rule, a guarantee and a check,** for steps
   and nodes together. The guarantee is one of (a)–(c), measured across the bank
   of records; the check runs every time.
4. **Across a bank of rainfall records,** not tuned on one.
5. **Cost last:** a budget per resident gradient and per invader, not a minimum.

## Why the grid is fixed

Reverse mode differentiates the model as discretised, and the step controller is
not differentiated. On an adaptive grid each `θ` has its own discrete model, so
`J` jumps where the grid re-adapts and the gradient is the slope of a different
function at each point. On a fixed grid `J(θ)` is one smooth function, and
reverse mode returns its gradient exactly. A fixed grid also keeps the tape's
shape the same at every `θ`, and no step is rejected.

## Numbers still to set

- **`Δ`, the trust radius:** invaders need about ±5% today; an earlier test of fixed
  grids covered ±2× in six parameters, with the steps subdivided 1.5–2×.
- **The precision wanted in `θ`,** which sets the bound on the gradient near an
  optimum or a singular strategy.
- **The bank of records,** and the cost budget.
