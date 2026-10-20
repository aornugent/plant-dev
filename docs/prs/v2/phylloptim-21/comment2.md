## Why the knot's derivatives serve the tangent

Past the last knot k, the table returns the tangent G(k) + f(k)(psi − k)
until it reaches G's limit. Both k and the tangent's slope f(k) move
with the traits, but k is defined as the water potential at which
conductivity falls to its 1% floor, so f(k) is that floor for every
trait value. Differentiating with respect to a trait θ gives

    d/dθ [G(k) + f(k)(psi − k)] = ∂G/∂θ at k + f(k) dk/dθ − f(k) dk/dθ
                                = ∂G/∂θ at k

so the derivatives past the knot are G's derivatives at the knot.
Past the limit the value is G(∞) = b Γ(1 + 1/c), whose derivatives
are written out in `cumulative_vulnerability_integral_limit_derivatives`.

![The root integral and its root_P50 derivative from 4 to 10 MPa, with central differences, and the range master refused shaded](FIG:phylloptim-21/root_integral.png)

On plant's root curve the derivative matches a central difference of
the table to 4.2e-11 everywhere past the knot. It jumps where the
tangent meets the limit at 7.39 MPa, because the value switches there
from the tangent to the limit; the value is continuous, and the
derivative is correct on each side.

## A collar on a closed range

When the range of feasible collar potentials is narrower than
`GSS_tol_abs`, the solve sets the collar to the middle of the range
and optimises only the stem. The collar's derivative is therefore the
average of the derivatives of the range's two ends. The wet end is a
bound as at any collar. The dry end is either the continuity root or
the root's own critical potential, whichever is wetter, and the second
does not move with the soil water potential, so where it closes the
range the collar's derivative halves. The stem is held at `psi_crit`,
with no response to the collar; a stem optimum inside its range would
need the curvature of the held-collar problem, which is not computed,
so it is refused with a message saying so.

![The two ends of the collar range and the collar against soil water potential, and the collar's derivative against a central difference of the solve, with the range master refused shaded](FIG:phylloptim-21/collar_interval.png)

On a sweep of soil water potential from 5.0 to 5.88 MPa the range
closes from 5.328 MPa, and master refused all 135 points past it. On
this branch the derivative agrees with a central difference of the
solve to 3.1e-5 where the range is open, and to 0.38% where it has
closed. The remaining difference comes from evaluating both ends'
derivatives at the middle of the range, up to 0.05 MPa from either
end; evaluating them at the ends would cost two more supply
evaluations per point.

## Why both ends are refined first

The two ends come from root-finds that stop when their bracket is
1e-4 MPa wide, and the collar is their midpoint, so it carries their
stopping error, which jumps as the inputs change. A central difference
of the solve divides that error by twice the difference step, and on
master that made the difference along the soil water potential wrong
by up to 1.5e-3. Both ends of a closed range now go through
`polish_bracket_bound`, which master already used to refine a fixed
end, so the collar is the midpoint of accurate ends. That refinement
is the one change to forward values.

## Tests

`test_leaf` checks the derivatives past the knot against differences
of the table, and the closed-range derivatives against differences of
the solve along `root_P50`, `stem_P50` and the soil water potential,
with each kind of dry end. On Linux it passes 3018 checks, and the
branch's `test_leaf.cpp` compiled against master's headers fails 17 of
them, each a refusal. R testthat passes 1524 tests with one skip.
