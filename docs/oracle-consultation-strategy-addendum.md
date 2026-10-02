# Addenda to the strategy consult

## Per-member events, at their real cost

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

## The step-size law on the coupled run

The chain-alone result in finding 3 has been tested on the coupled run. The bar
was set before the runs, and the law fails it narrowly; what it separates
matters more.

**The runs** (test instance and constant forcing, `tol = 3e-5` unless stated):

| | rejected (at knots) | member evaluations | `J − J*` |
|---|---|---|---|
| our law | 3912 (1238) | 7.06e6 | −1.26e-5 |
| PI | 2905 (1123) | 7.10e6 | −2.3e-6 |
| PI + the chain's seeds | 1936 (190) | 6.84e6 | +8.2e-6 |
| constant forcing: our law / PI / PI with Gustafsson's gains | 739 / 229 / 83 | 3.76e6 / 3.36e6 / 3.25e6 | at most 2e-8 |

- *At matched error* PI with the seeds saves 5–11% on the test instance, mostly
  through the seeds. The elasticity in `θ_A` on fixed steps moves 0.0015ε.
- *Under constant forcing* the coupled run cycles where the chain alone settles:
  five accepted steps, then one rejected, near the stability limit. PI leaves 229
  rejections; Gustafsson's gains leave 83, but they cost 15% more at matched
  error on the test instance.

**What the rejections are.** Their cost falls from 18.2% of the run's member
evaluations to 9.3%. What remains:
- 661 at a crossing inside the attempt, which no step-size law removes and the
  split does;
- 798 bound by the chain on the first to fourth step within `δ` after a knot.
  Their ratio jumps about 8× after a growth of only 1.03. The chain alone's step
  program, which matches the coupled one within a step in 89% of intervals,
  could seed them; only its first step is used so far.
- 199 overshoots after a small ratio, 190 at knots, and 9 at the stability
  limit.

**The separation.** On the chain alone the global error is nearly proportional
to `tol` over four decades, under either law on the test record and under PI
under constant forcing. Its mean never changes sign. The coupled `J`'s error
changes sign within ±5% of `tol`, and falls with `tol` once each crossing is
split. So the sign changes are the crossings', not the controller's. The
controller's remaining part is the cycle at the stability limit and the
first-`δ` transient after knots.

## The window as a rule

Strategy items 2 and 3(a) have been tested together.

**The rule.**
- *The pilot:* 54 creation times at `tol = 1e-3`. It reads `R(t)` within 10%
  wherever `R ≥ 1e-3`, on four pulsed records, for 0.25–0.32 of a forward. With
  27 creation times it misses one record's tail by 25%. Its creation count
  matters, and its `tol` barely does.
- *The weight:* every `σ_n` on a step starting at `t` is multiplied by
  `1/clamp(R̂(t)/0.1, 0.01, 1)`. `R̂` is the pilot's largest `R` over the base run
  and the probes at the range's ends.
- *The thinning:* creation times after the window are spaced
  `⌊√weight⌋` lattice spacings apart.

**What it buys.**
- 21–23% of a forward from the weight, and 25–28% with the thinning, on three
  pulsed records. Under constant forcing it buys 3.6%.
- On full-gradient runs it saves 21–23%.
- Every quantity of both kinds moves at most 0.016ε under the weight and 0.078ε
  under the thinning.

**Where it fails.**
- *A failing probe breaks the walk.* On one record the probe at `θ_A × 2`, with
  `J′ ≈ 1e-19`, earns its `J′` late. On the weighted steps, 31–38δ long against
  5–11δ unweighted, its density equation produces a non-finite value.
- *Protecting that probe too* (adding the range's other ends to `R̂`) saves only
  10–12%, and the same walk still fails, later.
- *A probe's share is the wrong guard.* Probes 9–21× outside the protection move
  at most 0.06ε; what breaks is the probe's stability on the base run's long
  steps, which no weight on the base run sees.

**What this adds to our questions.**
- A probe that walks the base run's steps inherits their length. The
  window-weighted base run wants long steps late; a failing probe needs short
  ones.
- That makes strategy item 5, probes on their own steps, a requirement of the
  window rule rather than an economy.
