# Can placement alone remove the founders' error?

The question: can a schedule default that adapts to the founders' window replace Simpson's
rule, with no tunable control? plant's original default (`node_schedule_times_default`)
placed nodes densely at the start, with spacing 0.2·b rounded down to a power of two.

`placement.R` scores J's own (interpolation) part of the founders' error in ln J, in ε. It
works offline on the f64 lattice's fate shapes (`founders/q2_shape.rds`), with uniform
establishment over [0, b1). Output: `placement.log`.

| case | hat, uniform 12 / 17 | hat, graded 12 / 17 | Simpson, uniform 12 | log-fate, uniform 12 | original default (nodes) |
|---|---|---|---|---|---|
| dry | +0.58 / +0.29 | +0.32 / +0.16 | −0.015 | −0.089 | +0.13 (85) |
| episodic | +0.14 / +0.07 | +0.13 / +0.06 | −0.000 | −0.019 | +0.21 (85) |
| episodic-lma | +0.37 / +0.18 | +0.25 / +0.12 | −0.001 | −0.031 | +0.11 (86) |
| long-wet | +0.51 / +0.25 | +0.24 / +0.12 | +0.021 | −0.45 | +0.13 (85) |
| dry-flat | +0.97 / +0.48 | +0.37 / +0.18 | −0.057 | −0.41 | +0.13 (86) |
| all ten (range) | | gain over uniform ×1.1–2.6 | gain over graded 17: ×4–1000 | | |

*Graded* puts equal h³·nrr″ in each interval, the optimum for the hat rule at a given node
count.

**Placement cannot replace the order.**
- The best grading gains ×1.1–2.6 over uniform spacing. That is the same error with 5–40%
  fewer founders' nodes, and the founders' window is about 14% of T.
- The scorer found the same: spacing for equal error per interval did not beat the step
  layer (`localised.md`, 13 October).
- Simpson at 12 intervals is ×4–1000 below the graded rule at 17.

**The original default is the wrong shape here.**
- Its spacing grows with age, which suits dynamics whose time scale grows with age.
- The founders' fate falls on a fixed time scale, L = 0.4–1.2 y.
- So it puts 85 nodes in the window, about 70 of them before b = 0.5 y. Its error,
  0.11–0.21, is no better than 17 uniform intervals.

**Log-fate interpolation adapts to the shape but is not robust.**
- It is exact for an exponential: ×6–12 better on dry and episodic-lma.
- On the S-shaped records it is worse than the hats (long-wet −0.45, wet-adG2 −0.64).
- It touches only J, not the uptake and light sums.

**Caveat.** This covers J's own part only. The field part (the founders' uptake through the
soil) is half of the elasticities' founders' error on dry and 75–95% on episodic-lma. Its
integrand is the same set of delayed copies, so the conclusion is expected to hold
[unmeasured].

## So: Simpson as the representation, the count as the adaptive default

Neither part needs a control.
- **The quadrature.** Node weights come from piecewise-quadratic interpolation over
  consecutive pairs of intervals, of any widths, conserving each pair's exact
  establishment. This is the hat weights plus the pair correction in `founders/simpson.patch`,
  generalised to unequal widths.
  - Applied to every pair, it needs no window at all.
  - If pairs across edges hurt, the window becomes a model fact: the pairs before
    establishment first closes.
- **The schedule.** The founders' window gets an even number of equal intervals. The number
  follows from the pilot's L and b1 through the (h/L)⁴ bound: 12 meets the floor on dry and
  episodic-lma.

**Open before building:**
1. Does Simpson on every pair help or hurt outside the founders (spell interiors, opening
   and closing edges)?
2. FF16's references move under it; they would be re-blessed as a numerics change.
3. A build that reproduces libS: the founders' libF does not.
