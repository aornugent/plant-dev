# The split as built, and how rough `J(θ)` is on a frozen grid

*Not yet sent. It continues `oracle-consultation-events.md` and your reply to it,
in the same thread, and uses their notation.*

## What we ask

We built the per-member split into the forward step and ran your scan of second
differences in `u`. From `u = 1e-2` up it holds as you predicted. Below `1e-2` a
residue remains, and our first reading of it was wrong. Read again, the map
from `θ` to `J` on a frozen grid is rough in ways your model of its noise does
not have:
- every replay carries noise of about 2e-8 in `ln J`, unsplit too, under a
  change in `θ` as small as 1e-12;
- over longer intervals `ln J` departs from a smooth curve by more than that
  noise, and does so alike in every variant of the split we ran;
- the residue below `u = 1e-2` is about the same in every variant, and falls
  more like `1/u` than `1/u²`.

No change of the split's own cut structure was resolved above the noise. We
would like your reading of what produces each of the three, whether each
matters for the gradients and the sweep through splits we are about to build,
and whether there is a way to make `J(θ)` smooth on a frozen grid, or a reason
it need not be. We may be looking at this through the wrong variable; if so,
say so.

## The split as built, beside your reply

- *The interpolant* is Cash–Karp's quartic, as you advised.
- *Detection.* A member is cut once where `P` has opposite signs at the step's
  ends. It is cut twice where a stage strictly inside the step has the far sign
  and `P` on the dense output agrees at that stage's abscissa. This is not your
  cut at interior extrema of `P`: a dip that lies between the step's start and
  its first interior stage, at a fifth of the step, is missed.
- *Location.* Regula falsi (Illinois) on the dense output, each iterate
  evaluating `P` at the interpolated state with the member's own components,
  stopping once iterates move less than 1e-10 of the step.
- *The pieces.* The member alone is integrated again over each piece with the
  step's tableau, reading the chain and the other members from the dense output.
  Each piece evaluates the smooth `P⁺`, not the branch per piece you advised:
  we kept the rates as they are, and a branch would thread a flag into the
  member's rate function.
- *The end.* The member's rates are evaluated again at its corrected end state,
  so the next step's first stage reads it.
- *Not built:* the sweep through splits. Gradients refuse a run that split, so
  everything below is about `J`, not about its gradient.

**The setting of every measurement here.** The test record, 108 uniform creation
times with each member's term in `Φ` at its own `x_j`, the unweighted norm, a
single rate, `tol = 1e-4` unless stated. The decided setting differs: the
weighted norm with its caps, the multirate step with its inner steps frozen on
replays, and the spread rule. The split has not been run in it.

**What the split does to `J`.**
- At `tol = 1e-4` it puts `J` at +3.43e-6 from the reference, against +3.55e-5
  unsplit. From `1e-3` to `3e-5` its error falls 5.0×, 6.0× and 2.5×. Below
  `3e-5` an error the unsplit run shares stops it: at `1e-5` they carry +5.8e-6
  and +5.3e-6, and the split at `1e-6` is still 1.05e-6 from `1e-7`. We have not
  traced that error.
- It costs 0.5–0.7 ms per member step split: +12.5% of the unsplit forward at
  `1e-3` and +7% at `3e-4` and `1e-4`, timed alone. 92% of it is single-member
  evaluations, each of which rebuilds both fields from every member and solves
  again the inner problem of the member that would be created now (39%).

## Your scan in `u`

Second differences of `ln J` in `ln θ_A` at `θ_A(1 ± u)`, on replays of each
arm's own recorded steps, against that arm's replay at `u = 0`. The converged
value is −43.45. The `3e-3` column is from our prototype, which agrees with the
build within 0.02 at the other three.

| `u` | `1e-3` | `3e-3` | `1e-2` | `3e-2` |
|---|---|---|---|---|
| unsplit | −47.18 | −44.31 | −44.00 | −43.62 |
| split | −42.87 | −43.33 | −43.44 | −43.47 |

- *From `u = 1e-2` up the split holds.* Over `tol` and its ±5% nudges, each a
  program of its own, its value spreads by 0.06 at `1e-2` and 0.002 at `3e-2`;
  unsplit, by 0.65 and 0.12 (the prototype).
- *Below, a residue:* +0.57 at `1e-3` against the value at `1e-2`. Your model of
  the noise, passages of 5e-9 with random signs, gave 3e-3 at `1e-2` from 650 of
  them; scaled to the 78 within `±1e-3`, it gives about 0.1 there.

These differences are our instrument here. Second derivatives will come from
the adjoint, and they are not this question.

## What `J(θ)` looks like on a frozen grid

All on the build, the split as above, `θ_A` moved alone.

- *Noise in every replay.* Neighbouring replays from our bisections, 1e-9 to
  6e-8 apart in `u` and mostly with no change of cut structure between them,
  differ from the smooth change by 2.6e-8 rms and up to 7.2e-8 (36 intervals). That
  is about 1.9e-8 of noise in each replay. A change of 1e-12 in `θ_A`, where the
  smooth change is 8.3e-12, moves `ln J` by +1.5e-8 and +1.0e-8 unsplit and by
  −0.8e-8 and −1.8e-8 split. The same `θ` repeats bit for bit.
- *So no change of structure was resolved.* We bisected three to brackets of
  1e-9 in `u`: a crossing passing from one step to the next; a pair lost when
  its first crossing passed a knot, both then falling before the next step's
  first interior stage; and a pair lost inside a step. Each bracket's change less
  the smooth change, −0.85e-8, +0.74e-8 and −4.6e-8, lies inside the noise.
- *A slower departure.* Over intervals of 6.25e-5 in `u` between 0 and `1e-3`,
  `ln J` departs from a smooth curve by 6.5e-8 (standard deviation), about 2.5
  times what the noise gives, in runs of one sign.
- *The residue falls more like `1/u` than `1/u²`.* A `1/u` law through `1e-2`
  and `3e-2`, `−43.48 + 4.5e-4/u`, predicts the `3e-3` value within 0.003 and
  reads `1e-3` 0.16 low. A law in `1/u²` through `1e-3` and `3e-2` misses `3e-3`
  by 0.07 and `1e-2` by 0.03. At `3e-3` the programs at `tol` and its two nudges
  all sit above the `1e-2` value, by 0.11, 0.15 and 0.35, so it has a sign. The
  unsplit residue at `1e-3` has the other sign and is about 6 times larger.

**Three variants of the split, each changing one thing.**
1. *The step's end corrected* by the pieces less the whole step, both in the
   dense output's field, so that a cut at either end of a step changes nothing
   and a passage is continuous by construction.
   - Its slower departure is the split's: 6.8e-8 against 6.5e-8, correlating
     with it interval by interval at 0.78 (signs agreeing in 13 of 15), the two
     differing by about what the replays' own noise gives (4.3e-8 against
     3.7e-8).
   - One lost pair's change grew to −5.4e-7, far above the noise. The correction
     carries across the pair the difference between two integrations, one in the
     dense output's field and one in the stages'.
   - That jump falls inside `+1e-3` and pulls the second difference there down
     by 0.54, to +0.18 above its `1e-2` value; without it, +0.72.
   - `J`'s error at `1e-4` grew 6.7×.
2. *The same, with a cut at every sign change the dense output shows on 32
   points per step.* The detection misses 6 or 7 pairs a run. All but two lie in
   the first fifth of a step that starts at a knot where a pulse begins after
   three or more quiescent `δ`, where `P` falls as low as −0.39. With them cut
   the residue is +0.71 at `1e-3`, at 12 times the forward's cost.
3. *The cut structure frozen at `θ_A`* (the prototype), a crossing that moves to
   another step being integrated unsplit there: −42.79, −43.10, −43.58 and
   −43.49 at the four `u`.

**Not measured.** The gradient through splits, and so whether the roughness
reaches it. Whether the slower departure exists unsplit, where the staircase
from uncut crossings is larger (its residue at `1e-3` is about 6 times the
split's). The split in the decided setting and on other records. The source of
the noise and of the slower departure.

## Why it matters to us

- Not for `J`'s accuracy: 2e-8 is six orders under `ε` for `ln J`.
- The objectives ask that each answer change smoothly with `θ` on one grid.
- The sweep through splits is next. Your gate for it compares its gradient with
  central differences of the frozen-grid forward. At 1.9e-8 per replay a central
  difference at `±u` reads an elasticity to about `2.6e-8/(2u)`: 1.3e-4 at
  `u = 1e-4`. Your gate for the multirate step, central differences at `±1e-6`
  below 1e-10 once its inner steps are frozen, cannot be met: the noise is there
  with no multirate step at all.

## Structural features, any of which may be load-bearing

We do not know which of these matter most.
- A frozen grid fixes the step times. The cut structure is found again on every
  replay. A replay steps to the recorded times, so at `θ` itself it repeats its
  forward within 3.6e-9 rather than bit for bit.
- The pieces read the fields from the dense output; an unsplit step reads its
  stages.
- Every piece evaluates the smooth `P⁺`, so a cut placed off the crossing puts
  a kink inside a piece. The location stops at 1e-10 of the step.
- Detection reads the sign of `P` at the stages, not its extrema.
- The inner problem is nested bracketing root-finds, cold-started at every
  evaluation, each stopping on a tolerance. A one-ulp change in its inputs moves
  its output by about 1e-9.
- Class switches are not cut: a `C⁰` kink in `p_j` a median `0.26δ` before an
  upward crossing, which your reply named as the natural place for a bias.
- The model's other kinks: the chain's `max(0, ·)` at `v_floor`, its outflow's
  clamp at 1, `max(0, 1 − v₁⁸)` in its inflow, and `φ`'s bounds.
- A split member's corrected path reaches the fields only at the next step.
- Every knot and creation time ends a step.

## Facts an answer can rely on

- The members' rates may not change. Whether a branch per piece counts as a
  change to them is for us to decide; tell us what it would buy.
- Replays are deterministic: the same `θ` repeats bit for bit.
- The sweep differentiates the discretised model as run. Anything that refines
  a member, a split included, is part of the discretisation and is frozen with
  it.
- Cost is rows first, then the sweep's cost per row, then the forward's, then
  rejections.

## Questions

1. **What makes `J(θ)` rough on a frozen grid.** Noise of about 1.9e-8 per
   replay under any change in `θ`, unsplit too; a slower departure of 6.5e-8
   per 6.25e-5 in `u`, alike in the split and in its correction at a step's end;
   and a residue below `u = 1e-2` that every variant shares, falling more like
   `1/u` than `1/u²`. Which features above carry each, and what is the cheapest
   test that would tell?
2. **What the split should be.** Since no change of the split's own structure
   was resolved above the noise, what would your branch per piece and cuts at
   interior extrema change in `J(θ)` on a frozen grid, and how would we see it?
   Is there a formulation under which `J(θ)` on a frozen grid is as smooth as the
   unsplit model allows, and how smooth is that?
3. **What a frozen grid should freeze.** The step times alone, or also the cut
   structure, the cut times, or the inner problem's iterations? What does each
   buy for `J` and for the sweep, and what does it cost?
4. **The sweep through splits.** With this roughness, what should its gate be,
   and against what reference? Does the roughness reach the gradient, and how
   would we see it if it did?
5. **The decided setting.** Would the weighted norm's longer late steps, the
   multirate step's inner chain or the spread rule change any of this?
6. **What have we missed?** Is this roughness something to remove, to bound and
   report, or to leave alone? If there is a way around frozen grids for what we
   need of them, tell us.
