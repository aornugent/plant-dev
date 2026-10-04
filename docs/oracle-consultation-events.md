# Per-member events in a field-coupled ensemble: how to build them, and what they buy two workflows

*A draft, not yet sent. It continues `oracle-consultation-strategy.md`, its
addendum and your reply, in the same thread, and uses their notation.*

## What we ask

We ask for a rigorous assessment of how to build per-member events: what the
build must contain, in what order, how each part enters the reverse sweep, how
each part can fail, and what test would show each failure. We would like the
assessment made against two workflows, in this order of priority:

1. **Base-run gradients with stable and efficient second derivatives.**
2. **Convergent and cheap probe gradients, many per base run.** An optimiser
   uses them to step a probe's constants toward constants where the probe would
   outgrow the base; when one gets there, the base run is redone with it
   included and the loop starts again.

Both are described below. Events may be the wrong object for one workflow or
for both, or the right object built in a way we have not considered. If so,
please say so; we would rather be redirected than have our plan refined.

Much has changed since your last reply. Several of your readings have been
tested, some confirmed and some refuted, and the system the events must fit has
moved. The next section reports that first, because the assessment depends on
it.

## What has changed since your last reply

**The base run's setting.** The base run now uses a weighted error norm, built
into the solver:
- the chain's five components weighted ×10;
- every state weighted by a function of `t` read from a pilot's `R(t)`, which
  rises to 100 late in the run;
- every state's combined weight capped at 100;
- every step capped at `15δ`, where `δ` is the forcing's sampling interval.

The cap on weights exists for a reason we had not foreseen. With the chain at
×10 and the late weight at ×100, the chain's weight late in the run was 1000.
The error test then accepted steps in which a chain stage fell so low that its
`φ_ℓ` sat at `φ_max`, far outside the range on which the members' rates have a
derivative, so every gradient was refused. Rejected attempts reached `φ_max`
at any weight, but only accepted steps reach the sweep, and at 100 no accepted
step did. The `15δ` cap is your safety net for the probes' pools, at `2.16τ_s`.
It costs 0.0–2.4% of the window's saving. With it, none of eight probe walks
fails on three pulsed records (two constants, each at ×0.5, ×0.7, ×1.4 and ×2),
so probes need no sub-steps of their own under this pair.

On three pulsed records, this setting saves 31–34% of a gradient run against
the unweighted run at the same `tol = 3e-5`. `ln J` moves by at most 0.0006ε.
Against a `tol = 1e-5` reference, the base run's largest elasticity error falls
from 0.09–0.19ε to 0.056–0.078ε, and the probe's from 0.03–0.07ε to
0.020–0.030ε. Under ±5% tolerance nudges, the base run's largest move on the
test record is 0.61 of ε/3 and the probe's 0.08.

**Your lever one, the chain implicit and loosely weighted, tested in the build.**
The implicit chain (ARK4(3)6L, explicit in the members) was built into the
solver and run on three pulsed records with every gradient and probe.
- It saves 42–55% of a gradient run against the unweighted run, and 16–33%
  against the setting above. Nothing fails.
- At `tol = 3e-5` it misses the accuracy bar: the base run's largest elasticity
  error is 0.36–0.40ε, and `J`'s error is about 100 times that of the
  Cash–Karp setting.
- Tightening `tol` from `3e-5` to `1e-5` shrinks a smooth error about 3× and a
  kink's about 1.25×. The test record's error fell 3.1×, so it is a smooth
  bias from the method's fourth order, not the crossings' kinks.
- At matched error the Cash–Karp setting wins on the pulsed records: the
  implicit chain at `1e-5` still sits 2.0–2.7× farther from the reference for
  only 6–11% less cost.
- Under constant forcing, where stability binds, the implicit chain saves
  62–67%. That is where it stays.

**The pair, and a free order-4 extension.** You pointed us to a stage-based
order-4 interpolant. Cash–Karp has one, provided the end-of-step rate `f(y₁)` is
used, which the solver evaluates on every attempt anyway. With it, the order-4
weights form a one-parameter family, and without it none exists. We chose the
C¹ quartic that minimises the order-5 error at `ϑ = ½`. Events on it match the
midpoint quintic, for the cost of the cubic:

| `tol = 1e-4`, the test instance | `J − J*`, relative | added cost, share of a forward |
|---|---|---|
| unsplit | +3.66e-5 | |
| split on the cubic through the ends | +1.65e-4 | 5.87% |
| split on the midpoint quintic | +3.99e-6 | 10.09% |
| split on Cash–Karp's quartic | +3.41e-6 | 5.89% |

At `3e-5` the quartic's error is +9.0e-7, for 5.11%. Its spread under seven
nudges matches the quintic's: the addendum's four elasticities, `θ_A`'s last,
move at most 0.17, 0.26, 0.14 and 0.06 of ε/3. Dormand–Prince 5(4) is worse on
this system: 11–15% more rows at equal `tol`, a `J` error that stalls near
7e-5, and 8–38× as many rejected stages, every one holding a negative pool. So
the pair stays Cash–Karp.

**A multirate step where the draw is small.** You placed the multirate gain in
the pulses, where the draw is about 1% of the chain's budget, and expected
the implicit chain to take it more simply. The implicit chain did not take it
at matched error, so we tested a multirate step in that regime directly.
- *Which steps.* At each step's start the solver computes the draw's share of
  the chain's budget, summed over components: `Σ|a_ℓ|` over
  `Σ(|in_ℓ| + |out_ℓ| + |a_ℓ|)`, with `out_ℓ = k·clamp(v_ℓ, 0, 1)^q`. When it is
  under 10%, the step is multirate; 62–67% of steps are. At a 1% threshold the
  share is 51–66% of steps, almost none of them in quiescent stretches longer
  than `10δ`.
- *What a multirate step does.*
  - The chain is integrated alone by Cash–Karp at `1e-9` under a draw
    extrapolated linearly from the previous step, stopping at the members'
    stage times, where the members read it.
  - One evaluation at the members' end gives the end draw. The chain is
    integrated again under the straight line from the starting draw to that end
    draw, and the step keeps this corrected chain.
  - The coupling's error enters the norm in the chain's place. It is the larger
    of two gaps: between the two chain integrations at the end, and between
    each stage's actual draw and the line.
- *Results, on the test record and a second pulsed record.*
  - Judged at the chain's weight, ten times looser than the members', the
    coupling's error biased `J` on the second record by 22 times the Cash–Karp
    setting's error. There, loosening `tol` from `3e-5` to `1e-4` hardly moved
    the bias (+2.6e-4 to +2.9e-4), so `tol` was not controlling it.
  - Judged at the members' weight, the step takes 41% and 45% fewer rows than
    the Cash–Karp setting at the same `tol`, or 41% and 29% fewer at matched
    error in `J`. Every elasticity in five constants stays within 0.11ε of the
    reference, against the Cash–Karp setting's 0.055ε. The largest shift is a
    bias of the step, not noise, since the replays behind it are smooth. The
    nudges move `ln J` by ±0.0002ε.
  - Below `tol = 3e-5` its `J` error stops falling, at about 0.001ε (+2.6e-5 at
    `3e-5`, +2.7e-5 at `1e-5`), because the 10% threshold does not tighten with
    `tol`.
  - Central differences on replays of a multirate run carry a noise of about
    2.5e-7 in `ln J`, because the chain's adaptive inner steps change with `θ`.
    Reverse mode through replays that hold those inner steps fixed would carry
    none of it; that is not built.
- *Where the crossings fall.* On these runs 35% of the crossings fall on
  multirate steps (35.2% and 35.5% on the two records). All of them are upward
  crossings at pulse onsets; none of the downward ones fall there.

We have decided to build this step. Tuning its threshold is deferred to later
work on scheduling heuristics.

**The creation grid.** Two candidate rules from our strategy's item 4 were run
as ladders on two records, with every gradient: graded openings refined by
halving, and uniform creation times with each panel's term spread in `Φ`. A
run's error estimate is its move from the next coarser rung, divided by three.
- The spread rule reports its own error on both records. Over 108, 215 and 429
  creation times the ratio of successive moves is 3.32–4.42 across four groups
  of quantities, none negative, and the estimate reports a median 0.95 and 0.98
  of the true error.
- The graded rule does not, under the new setting. Its estimate reports 0.71
  and 0.80 of the error, and adding the spread to graded openings does not help
  (0.65).
- The spread's two-rung extrapolation reaches 0.09–0.17ε at 1.95–2.41M rows,
  with its estimate covering 93–95% of quantities.
- Dropping creation times after `b = 10` fails with the spread as without it,
  because that part of the error arrives through the chain.
- `Φ`'s 65 knot values are built in one pass that accumulates the members'
  terms in order of `x`, which holds while `x` decreases with creation time.
  At 429 or 494 creation times two members created close together can swap
  order: in 20% of the field builds on one record and 79% on the other, by at
  most `1.2·10⁻³` in `x`. The code's fallback for disorder walks every member at
  every knot and costs 23% of a forward. Sorting the members by `x` before the
  pass costs nothing measurable.

We have decided on the spread rule.

**Probes.** A probe has no field part, since its members only read the recorded
fields. So its own creation times can be thinned by each one's share of `J′`,
whatever the base run needs. The test emulated thinned walks exactly from one
full walk's per-member data. Creation times were spaced in proportion to their
share of `J′` per unit creation time, to the power `−1/3`: the spacing that
minimises their count at a fixed weighted error for a second-order quadrature.
Thinned so, a probe's walk and sweep keep a median 53–66% of their rows (at two
scales of the spacing) and stay at most 0.17ε from the full walk's `ln J′`, over
27 cases: nine probes on each of three records. The probe's gradient under
thinning is not measured, and a thinned walk no longer repeats `J` at
`θ′ = θ`.

**Your readings, tested.**
- *The 798 rejections in the first `δ` after knots are not class switches.* On
  a build that repeats the run bit for bit, 1 of 793 such attempts holds a
  class switch (0.13%). Their ratio jumps about 12× after a growth of about
  1.01; the 8× after 1.03 we quoted was a ratio of medians. They are the chain's
  own transient: the outflow `k·clamp(v_ℓ, 0, 1)^q` switching on as a pulse's
  onset or rise fills the first two components, so that `h|λ|/β` rises from
  0.07 on the step before to 0.26 within the step. One step of the chain alone,
  from the coupled state at the attempt's start, gives a ratio within 2× of the
  coupled one for 96–98% of them. A guard read from that step removes them. It
  saves 10.4% of a forward but adds 1.9% to the rows, so a gradient run costs
  0.2% more.
- *The partition's drift.* Your first suspect, stage six reading the chain
  late, is refuted: a lockstep version, one chain step per member step with
  stage `i` reading member stage `i`'s true draw, repeats the coupled run bit
  for bit. Your second test, the chain's draw read from a tight recording while
  the members keep long steps, put the members' side and the mechanics within
  about 2e-5 in `J`. The cause was that no estimate measured the coupling's
  error; with it in the members' norm, the error falls with `tol` again. That
  restores convergence but not cost. It also taught us the rule the multirate
  step follows above.
- *The spread's slow sweep.* You suspected a sixteen-fold tape. Profiled, the
  spread adds 13% to the tape, and 2.8% to the sweep's time at `3e-5` and 8% at
  `1e-3`, all of it in the field build. The 1.7–3.4× slowdown was wall-clock
  time under load, plus the disorder fallback at 429 creation times.
- *The sweep's cost per row.* The sweep costs 2.5–2.7 forwards. It holds 0.83 as
  many member evaluations per row as a forward, each costing 3.26 times as
  much. Taping one member evaluation at its recorded solution costs 2.4 times a
  forward evaluation, search included, and writes about 33 KB of tape. The inner
  problem is already differentiated by one implicit-function solve per root,
  never by taped iterations, at 37% of the sweep's instructions. Three changes
  would take 47–51% off the sweep:
  - each active knot is recorded as an identity row, which still splits the
    sweep and pays two rebuilds of the model's state (19%);
  - each member's quadrature of `Φ` over `[0, x_j]`, now on the tape, would be
    recorded as one value with its partials (20–24%);
  - a slope of the inner solution, now taken by central difference in the
    sweep, would be stored with the recorded solution (8.5%).

## The two workflows

Both read one object: the map from the constants to the answers on one frozen
grid. Workflow 1 needs that map twice differentiable over a small box around
the base. Workflow 2 needs it continuous, exact where it is evaluated, and
cheap, over a box several of its length scales wide.

**1. Base-run gradients with stable and efficient second derivatives.** This
comes first. A run must deliver `ln J`, each elasticity `d ln J / d ln θ_k`, and
second derivatives of `ln J` in `ln θ`, all within ε of their converged values,
with the four tests holding: reproducible, continuous in `θ`, predictable,
never failing. ε is set today for the column in `θ_A`, each elasticity's
derivative in `ln θ_A`; for `θ_A`'s own second derivative it is 1.17 in the base
role and 3.8 in the probe role. One grid must serve base runs within ±10% of
the `θ₀` it was built at. In `ln θ` that box is 0.095 wide, about 0.39 of the
base run's length scale `|g|/|g′|`, so a quadratic model holds over it.

Today the second derivatives come from chords of gradients at `θe^{±u}`. For
five constants and both roles that is about 68 forwards, against 7 for the
gradients. The alternatives you named are forward-over-reverse, about 26, and
forward second differences once `J(θ)` is smooth on a frozen grid, about 10.
On the unsplit grid the second difference in `θ_A` sits 2.8–4.4ε below the wide
chord; split at every crossing, it comes within about 1ε, and the elasticity is
flat in the difference size within 0.06 of ε/3.

**2. Probe gradients for an optimiser.** The loop runs as follows:
- the base run is recorded once and treated as data;
- many probes are evaluated against it, each a walk and a sweep;
- each probe's gradient `dJ′/dθ′` steers an optimiser toward constants where
  `J′ > J`, where the probe would outgrow the base;
- when a probe's constants get there, the probe joins the base. The base run is
  redone with both kinds of members, which changes the fields, and the loop
  starts again against the new base.

Repeated, this assembles a base of several kinds of members, one probe at a
time, and maps `J′` across `θ′` along the way. What the loop needs from a probe:
- gradients that converge as the base run's settings, `tol` and the creation
  times, are refined;
- a low cost per evaluation, since the base run's own cost is spread over many
  probes;
- `J′ = J` exactly at `θ′ = θ`;
- nothing failing anywhere in `θ′ ∈ θ·[0.5, 2]`.

The probe's box is about four of its length scales wide (0.177 against ln 2), so
no quadratic model spans it. A map of `J′` over it is a set of evaluations,
made consistent by one recording. The probe's ε is 4–8 times looser than `ln J`'s
over one length scale, which suits steering but not interpolation.

A probe today walks the base run's recorded steps and stages, re-evaluating its
own members in the recorded fields, with no error control of its own. Its sweep
holds the base run's fields fixed. At `tol = 1e-4` it already passes the nudge
test: its largest move is 0.32 of ε/3, and its gradient's jumps are 3e-5 of
itself.

An earlier thought of ours is that a continuous extension of the base run's
step, of the step's order, would let each probe set its own program against the
base run's stored fields, rather than walk the base run's steps. Its own steps
would go where its members need them: its crossings and its fast pools. Its own
creation times would go where its `J′` is earned. That program would be recorded
on the probe's own tape for its adjoint. Your last reply pointed the same way:
read the fields between recorded instants from the end states and rates, never
from internal stages, and rebuild `Φ` from interpolated `x_j`.

## Per-member events, as measured

All of this was measured on the test instance under the unweighted norm, with
108 creation times, at `tol = 1e-4` unless stated.

**The method.** When a member's `P` changes sign inside a step, that member is
split at the crossing:
- the crossing is located on the step's interpolant;
- the member alone is re-integrated on the two sub-steps, in the fields the
  interpolant gives;
- the step's end state for that member is replaced.

A member whose `P` dips below zero and back inside one step is cut twice. Other
members and the fields are not touched. A probe build evaluates one member in a
step's field, bit for bit as the full evaluation does.

**What it buys.**
- The crossings are 70–85% of the gradients' spread under tolerance nudges. The
  split cuts its standard deviation 3.4–6.4× and leaves its mean within 0.4 of
  ε/3.
- `J`'s error falls with `tol` once no step holds a kink, 9–12 times nearer `J*`
  than unsplit. Unsplit, it changes sign between tolerances.
- The second derivative is restored, as above.

**What it costs.** On the cubic, the split costs 2.3% of a forward to locate,
4.1% to sub-step and 0.9% to correct the step ends. 9233 members were split, in
726 of 14 845 steps. The quartic matches the cubic's cost.

**How the structure moves with `θ`.**
- Crossings change step under a change in `θ_A` at these rates: 1–3 at ±1e-5,
  4–7 at ±1e-4, about 78 at ±1e-3 and 650 at ±1e-2. Each moves `J` by about
  5e-9 on the quintic and 1e-8 on the cubic.
- *Grazing.* One member, holding 3.1% of `J`, dips to `P = −2.9·10⁻⁴` at a knot
  where a pulse starts, with its two crossings on either side of the step
  boundary there. The dip vanishes within +1e-5 in `θ_A`. With one cut per member
  step, the frozen structure jumped 5.8e-7 in `ln J` there, 2–3 of ε/3 in one
  small elasticity. Cutting twice wherever a member's `P` has an interior
  minimum inside a step made it continuous to the noise floor, for 0.06–0.6%
  more cost.

**What failed or was not measured.**
- *The pre-registered field test failed for every interpolant, the quintic
  included.* On each crossing step it compared the interpolated chain and
  members, from which the split members' fields are built, with a reference,
  and asked each to lie within one error weight. Its misses were in members
  without a crossing, so the test may be the wrong gate.
- *Not measured:* the reverse sweep's cost with the split; the probe with
  events; other records; the new setting; and the multirate step.
- *Build estimate:* 0.9–1.3k lines in four or five stacked changes. They touch
  the solver's step, its recording and its sweep, and the model's rates for one
  member in an interpolated field.

## Structural features, any of which may be load-bearing

We do not know which of these matter most for the build.
- *The crossings.* There are 9235 per run, in 195 clusters. Upward crossings
  sit within a pulse's first `δ`; downward clusters hold about 45 crossings over
  `6δ` in quiescent stretches. Under the multirate step 11–14% of steps hold
  one (859 of 7693 on the test record), against 4.9% on the unweighted run at
  `1e-4` (726 of 14 845), because the steps are fewer and longer.
- *The positive part.* `P⁺ = ½(P + √(P² + ε_P²))` turns over `ε_P/|Ṗ|`, about
  2e-7 time units, so a step sees a kink. The pool's rate switches with the sign
  of `P` at the same point.
- *Class switches.* A member's inner solution leaves the lower end of its
  bracket a median `0.26δ` before its upward crossing. Each switch is a C⁰ kink
  in `p_j`, so in the member's draw, in the chain's rate and in `P`. With
  `P < 0` there, `P⁺` barely moves, but the pool's rate moves with
  `u⁻ = P⁺ − P`. Switches are not the chain's rejections in the first `δ`
  after knots (above), but they appear in 23–34% of the members' own rejected
  attempts. They show in the chain's error estimate at 10²–10⁴ times the chain
  alone's, but where the chain is near its floor and the ratio stays small: 3
  of 42 such attempts were rejected. On a frozen grid they are kinks in `J(θ)`.
- *The multirate step's inner chain.* A third of the crossings fall on steps
  where the chain's trajectory comes from its own inner integration, not from
  the global step's interpolant.
- *The window's long steps.* The late weight lengthens steps up to the `15δ`
  cap, after the window in which `J` is earned.
- *The fields lag a split member.* A split member's corrected path reaches the
  fields only at the next step, so the fields lag it by its own share of one
  step. Members' shares of the fields are largest for the first created, and
  those created before 3.6 time units carry 78–100% of `J`.
- *The probe's region moves.* Under constant forcing the members that earn 90% of
  `J′` are created before 2.2, 0.12 and 0.012 time units at `θ_A` ×0.5, ×0.99
  and ×1.01.
- *The probe's `J′` far from the base.* `J′` runs to hundreds or thousands at
  `θ_A` ×0.5 on the pulsed records (541–2682), far past the point where the loop
  adopts a probe. An optimiser that overshoots still evaluates there.
- *The diagonal.* At `θ′ = θ` a probe re-evaluates the base run's own stages, so
  `J′ = J` to the last bit, and nothing an event adds may break that.
- *Stops.* Every knot and creation time ends a step, so crossings near a knot sit
  on a step boundary.
- *The order of members by `x`.* With the members sorted before `Φ` is built, a
  swap changes only the order of summation.

## Facts an answer can rely on

- The pair is Cash–Karp 5(4), with its free order-4 extension from the six stages
  and `f(y₁)`. The base run uses the weighted norm and caps above, which are
  built. The multirate step where the draw is small and the spread rule for
  creation times are decided and prototyped, not yet built.
- A recording holds every evaluation's inner solutions and fields. Replays and
  probes walk it bit for bit, and the rates are deterministic functions of state
  and time.
- The sweep differentiates the discretised model as run. Creation times and step
  sizes are constants within a gradient, and values on the tape must equal the
  forward's. Anything that refines a member is part of the discretisation and
  is frozen with it.
- The members' rates may not change. The chain's discretisation and the
  forcing's representation are part of the model.
- Cost is rows first, then the sweep's cost per row, then the forward's cost per
  row, then rejections. A run with every gradient of both kinds is about seven
  forwards: the base forward, its sweep (2.6), a probe's walk (0.8) and its
  sweep (2.6).
- ε is a tenth of each quantity's spread across eight records from one
  generator: 0.025 in `ln J`. Every elasticity's ε is at least 0.01.

## Questions

1. **The build for workflow 1.** What must events contain so that `J(θ)` and its
   gradient are smooth enough on a frozen grid to give stable second
   derivatives?
   - How should the cut structure be made a smooth function of `θ`, across a
     crossing that moves to the next step, a pair that merges into a graze, and
     a crossing that lands on a stop?
   - How should the crossing time enter the tape: by the implicit-function
     theorem at the located root, or otherwise? And how should the adjoint's
     jump at the switch be carried?
   - How should the derivative behave near a graze, where `Ṗ → 0`?
   - Which route to second derivatives is cheapest at stable error once events
     exist: forward differences, forward-over-reverse, or chords of gradients?
     What sets each route's noise floor?
   - Should class switches be events too, given that they are kinks in `J(θ)` on
     a frozen grid?
2. **The build for workflow 2.** Should a probe walk the base run's steps, with
   events inside them, or set its own program against the base run's stored
   fields, or something else?
   - If its own program, what must the base run store, and what does each probe
     evaluation then cost? This includes the multirate step's inner chain.
   - How should a probe's program be recorded on its own tape, so that its sweep
     replays exactly what its walk did?
   - How should the structure be frozen for an optimiser that moves `θ′` by
     steps of unknown size, so that `J′(θ′)` stays continuous where the
     optimiser needs it while each evaluation stays exact for its own program?
   - Can a probe's own creation times keep `J′ = J` exactly at `θ′ = θ`, or must
     the diagonal keep the base run's?
   - What convergence order should a probe's gradient show in the base run's
     settings, and how should a run estimate its error?
3. **Events and the multirate step.** A third of the crossings fall on
   multirate steps. How should a split read the chain there, and does the inner
   chain change the interpolant's order, the location, or the adjoint?
4. **The gate.** The field test we pre-registered failed for every
   interpolant. What criterion should decide whether an interpolant is good
   enough for events?
5. **Order and cost.** What is the smallest build that delivers workflow 1's
   stable second derivatives? What can wait for workflow 2? Where will the
   sweep's added cost go, and what should gate each stacked change?
6. **What have we missed?** Is there a formulation under which the crossings
   stop mattering for one workflow or both? Or one that organises the probe
   loop differently, around the stored base run rather than around each probe's
   walk? If we are building the wrong thing, tell us what the right thing is.
