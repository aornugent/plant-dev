# Generalising the reverse pass: the general system, and the concepts it deletes

The stand-scale reverse mode is correct on the birth-date coordinate and it cost more code than it
should have. This report says **why** it cost that much — a structural answer rather than a matter of
effort — and what to build so the next model does not pay it again.

Reports 00 to 08 state what the derivatives are and what a correct implementation must satisfy. They
are written from the model's side. **This one is written from the solver's**, and the discipline is
explicit: §1, §4 and §6 use no ecological vocabulary at all. No cohort, plant, light, soil, seed,
species, census, trait. Where a property cannot be stated without one of those words, that is
recorded as a finding rather than worked around — because it marks exactly where a solver-level
primitive would under-determine the model.

The claim in one line:

> **The engine offers two ways to get a gradient and nothing between them. Every line the project is
> unhappy about is the cost of the gap.**

The reading is of `plant` at `5a5e3984`, `odelia` at `0a2e26b`, `phylloptim` at `9c61fd9`.

---

## 1. The general system

Strip the model and what remains is one shape, which a solver could name.

> An **ensemble ODE**. The state is a list of **units** plus a **shared** part. Units are independent
> of one another given the shared part. The shared part is built from the units by **reductions**.
> Each unit reads the shared part through a **contraction** of small fixed width. The list of units
> **grows** at scheduled times. A **functional** of the final state is what we differentiate, with
> respect to many parameters at once.

Everything in reports 00 to 08 is a property of that shape or of the model filling it. Three
structures in it are what make the reverse pass hard, and they are §4.

### The five outcomes are already general

Report 00 §6 classifies every partial into *free*, *blocked*, *split*, *solved*, *sidestepped*. That
taxonomy is a solver's taxonomy wearing model clothes:

| outcome | the general statement |
|---|---|
| **free** | the quantity is integrated, so the adjoint ODE already computes its parameter sensitivity. **Anything that is state costs nothing.** |
| **blocked** | provably zero: a stationary quantity's channel through its own maximiser, an accumulator no equation reads, a value declared passive |
| **split** | a block that looks dense and is not. The general form: **the rank of the coupling is the width of the shared part, not the number of units** |
| **solved** | an implicit relation, differentiated by its defining condition rather than by its solver |
| **sidestepped** | wanted in principle, absent from the production path |

The useful move is not to restate them. It is to notice that **a System could declare which one each
channel is, and a solver could check the declaration.** Today they are established by reading and
recorded in prose; a *blocked* row and a missing row are the same number.

---

## 2. Where the lines are

| bucket | lines | where |
|---|---|---|
| general, already in odelia | ~480 | `step_adjoint`, `solve_adjoint`, `vector_jacobian_product`, the concepts |
| general, stranded in `plant` | ~325 | trajectory store, narrowing, widening, the segment loop, the growth-map VJP |
| **model-shaped — the target** | **~1,225** | the six interiors, the reduction transposes, the block interface, the functional seeds |
| genuinely model-specific | ~128 | the retention derivative, the seed geometry, the coordinate branch |

Within the model-shaped bulk the concentration is stark: `cohort_block_adjoint` (135),
`boundary_condition_adjoint` (110) and the light reduction transpose (89) are a quarter of it. And in
`tf24_strategy.h`, **810 of 2,300 lines are AD scaffolding — 35% of the file, 40% of the code**, the
largest single artefact being a 389-line hand-assembled Jacobian of a sub-model the strategy does not
own. The independent measure agrees: the file went from 1,426 lines split header/impl to 2,300
header-only across this branch, **+61%**.

The undifferentiated ergonomics are already good — K93 is 330 lines of C++ and ~250 of that is
biology. **All of the cost is the AD delta**, and none of it is visible to the scaffolder, which has
no notion of `ad_parameters`, `rebind`, or a scalar template parameter.

---

## 3. Two idioms, and only one of them can drift

The codebase already contains the answer to its own problem, applied unevenly.

**Derived by tape.** The functional seeds, the growth-map contraction and the boundary condition each
record their forward map at an active scalar and call `vector_jacobian_product`. A transpose obtained
this way **cannot** disagree with its forward, because there is only one function.

**Hand-mirrored.** Both reductions, the allometry pull-back and the environment cascade are written
twice and held together by a comment: *"Mirrors compute_competition_and_slope_impl term by term: the
same early exit, the same closing trapezium, the same node order."*

The mirrored half is ~440 lines transposing ~400 lines of forward. **The transposes are larger than
the code they transpose**, and there are at least twelve places where the two can silently diverge.

**There is no cost principle separating the two groups.** The taped set includes a full field rebuild
at the active scalar, once per stage — *more* expensive than the reduction transpose written by hand
beside it. The split is history, not design.

---

## 4. The three structures that make it hard

### 4.1 A reduction whose closing element is a function of the reduction

**Generally.** A reduction is taken over a list of elements. One further element sits at the inflow
end: it is a grid point of the reduction and a degree of freedom of none, and its value is set by an
algebraic condition evaluated at the current state — a condition that itself consumes the reduction.
The cycle is cut by **staging, not iteration**:

```
R0   the reduction with the closing interval omitted     (state alone)
e    the closing element, evaluated in R0                (state alone)
R    R0 plus the closing interval formed from e          (state alone)
```

**What that buys is purity.** Each of the three is a function of the state and time alone, so a stage
is reproducible from `(y, t)`. Iterating to the fixed point instead would leave the stage depending
on its starting guess — on history — and **purity of the right-hand side is the precondition for the
entire replayed adjoint**: the trajectory store, the stage rebuild inside the step transpose, and the
per-unit re-run all rest on it. The staging is not a numerical convenience; it is what makes the
reverse pass expressible at all.

**And the transpose inherits the staging.** Because the closing element is read at two different
points — one consumer sees the `R0` evaluation, another the `R` one — each read point needs its own
accumulator. `boundary_node_adjoints` carries `density_in_field` and `density_in_uptake` separately
for exactly this reason: *"one accumulator would transpose one derivative through the other's
argument."* The two values differ by more than `1e-6` relative and a test asserts they do.

> **The general rule: when a fixed point is resolved by staging, the number of accumulator slots a
> quantity needs equals the number of stages it is read at.** Nothing in the type system counts them.

**The forward model never made that distinction.** It holds one closing element and one slot; which
evaluation it is carrying is a property of what was last done to it. The reverse side was forced to
name the roles apart, and its five-field accumulator is the honest schema. That asymmetry is the
whole reason the boundary transpose costs 110 lines: **it is reconstructing a distinction the forward
model does not represent.**

So the generalisation is a *split*, not a new abstraction. The object is three things sharing a
struct — a re-derived cache of an algebraic condition, a quadrature node of every reduction, and the
template a growth event inserts — and separating them gives each one read point and one transpose.

**Where this under-determines the model** — three things that cannot be said generally:

- **The condition reads an *intermediate* of the rate evaluation**, not a state, a rate, or the
  transport speed. A primitive offering "the condition may read the element's rates" cannot express
  it; one offering "read anything the block wrote" is not a boundary-condition primitive at all.
  Where the line falls is a fact about this model.
- **Whether the attrition factor and the initial state must be the same number.** Sharing it is what
  makes `n·e^{−M} = B` exact. Two adjacent lines, no comment linking them, and no report says the
  identity is required.
- **The licence for the closing predicate.** "Close the interval only if the previous element still
  contributes" is statable; its *correctness* rests on monotonicity of the model's kernel, not of the
  quadrature. It changes which reduction is computed, so it is semantic rather than an optimisation.

### 4.2 The grid

**Generally.** A weighted reduction over an ordered element set whose weights come from a coordinate
on that set. Whether that coordinate is **passive** decides everything downstream: passive weights
are constants on the tape, and the transpose has no weight-derivative term; active weights make the
quadrature move with the state, and both the forward density equation and the transpose acquire a
term. **Those two terms are the same fact seen from opposite ends** — one report calls it a
compression term, the other a weight derivative — and neither report says so, because each is written
from one side.

**What plant does.** The passivity is bought by a *return type*: the coordinate accessor returns
`double` unconditionally. Report 05 §6.1's conditions (1) and (2) are then unviolatable rather than
testable. All four of its conditions hold on the supported coordinate.

**Four instantiations, not three.** The two field reductions, the functional, and — unnoticed by the
corpus — the fitness integral, which already integrates over the passive coordinate unconditionally
and excludes the closing element.

**Two defects the reading found, both on the unsupported branch:**

- **The closing interval's transpose writes only one end.** The interior loop emits the
  position-derivative term at both ends of every interval; the closing interval emits only its upper
  end. The slot is live and feeds a real accumulator. Unreachable today — double-guarded — which
  makes it precisely the shape report 05 §6.1 warns about: a wrong transpose parked on a dead branch.
- **The three reductions disagree about what a grid is.** One of them never uses the shared
  coordinate accessor at all; it builds its own grid twice, and on the unsupported coordinate that
  grid is **active** while the other two are frozen. So a tape of one carries a weight-derivative
  term the others structurally cannot have. The coordinate refusal is *a fence around that
  inconsistency, not a fix for it.*

**One degenerate interval per event is deliberate.** An event stamps the inserted element and then
refreshes the closing element's coordinate to the same time, so the closing interval has exactly zero
width at that instant. That is why the coordinate flag appears as a standalone clause in the closing
predicate, replacing the contribution test the other branch needs — and the guard is correspondingly
split: strict monotonicity on the interior grid, non-strict at the closing point. No width is divided
by anywhere in the quadrature or its transposes, so a degenerate interval is free.

**The one place the grid is told the time.** The closing element's coordinate is the current value of
the independent variable, so it must be refreshed before each reduction build or the closing interval
is short by one stage. The comment measures the damage at below `1e-6` and then rejects the
measurement as the reason: *"the interval is then a function of the step size, which the spatial
quadrature has no business depending on."* That is the correct instinct and it is the only place in
the discretisation where a spatial quadrature depends on the solver's clock.

### 4.3 Dimension growth

**Generally.** At passive event times the state is replaced by a wider one through a **growth map**
`G : R^d × R^p → R^{d'}`, `d' > d`, subject to two conditions: an **embedding** — an injective index
map under which carried rows are an exact identity, positionally relocated and *not* generally a
prefix — and a **completion** — the new rows are a differentiable function of `(y⁻, θ)`, not of `θ`
alone and not constant.

Because the event times are passive the adjoint is a plain chain rule with **no jump term**:

```
for each event, descending:
    sweep the flow of the segment above it
    θ̄ += (∂G/∂θ)ᵀ λ
    λ  ← (∂G/∂y⁻)ᵀ λ          now narrower
then sweep the segment below the first event
```

Three consequences make this a primitive rather than "one more Jacobian":

- **`(∂G/∂y⁻)ᵀ` is a scatter, not a truncation.** A width alone under-determines it, and a tail
  truncation is correct only for the last block. This is the part a hand-written implementation
  reliably gets wrong — and the right answer is to never write it. **plant's best decision in the
  whole reverse pass is here:** it records `G` at an active scalar and takes one VJP, so the
  relocation, the state half and the parameter half all fall out of one object and *"which widened
  row each narrow row became is derived rather than written out."*
- **`y⁺` is never on the tape.** It exists strictly between two accepted steps, so no recorder holds
  it. The reverse pass must replay the events forward to reconstruct each segment's first pre-step
  state, and the replay must be idempotent because it runs once per output row.
- **Width is stateful.** The System and every stepper buffer are sized to a width, so the sweep
  narrows as it descends and must recover the width sequence *newest-first*.

**If the event time were a function of the parameters**, the adjoint acquires the hybrid-system jump
term `λᵀ(f⁻ − f⁺)·dτ/dθ`, which none of the above computes. **Scheduled growth and state-triggered
growth are different primitives** and a concept must not accept both under one name — the second
would silently lose a term, in the same shape as every other failure in this corpus.

**What odelia knows about any of this: two comments and a `resize`.** The segment *range* exists;
everything else — discovering the boundaries, narrowing, widening, the replay, the growth-map VJP,
the parameter channel — is the model's. And because the boundary list is thrown away by the time a
sweep runs, it is **inferred from width diffs of the recording** and reconstructed by matching event
times exactly.

---

## 5. Three rungs, not two

**Route A — tape the trajectory.** A System declares a forward pass and `compute_jacobian` records
the whole run. The author writes no derivative code. The exemplar is 235 lines, none of them adjoint.
Report 01 §0 rules it out at scale: peak is the whole recorded computation.

**Route D — satisfy `AdjointRates`.** The System supplies the transpose of its own right-hand side.
odelia owns the stage recursion and the segment sweep; **the entire interior is the model's.** That
is the ~1,225 lines.

Nothing in between — and the gap is what got written by hand. But the reading turned up two
intermediate rungs, and one of them is already half-built.

**Rung B — tape one stage.** Record `set state → build the shared part → evaluate every unit →
reduce` once, at the active scalar, and take one VJP. That *is* `ode_rates_adjoint`, obtained rather
than written, and every hand-mirrored transpose disappears.

Two pieces of evidence that this is within reach rather than speculative. The whole-state-and-field
rebuild **is already recorded at the active scalar once per stage**, inside the boundary transpose —
so a tape traversing the entire upstream reduction exists in the innermost loop today; it simply is
not seeded to yield the reduction's adjoints. And the peak is bounded by construction: one stage is
`1/6M` of the whole trajectory, four to five orders below the number report 01 §0 rejects.

**What it trades away must be said plainly.** Report 01's *peak is flat in the unit count* is a design
commitment, asserted by a test on the recording size. A stage tape gives that up deliberately for
*peak is one stage*, which grows linearly in the unit count and needs an absolute number rather than
the same flatness test. **The instrument already exists** — the VJP returns the recording size and the
suite already reads it — so this is measurable today, before anything is designed.

**Rung C — blocked, over a declared structure.** When a stage does not fit, block it: but let odelia
block over a structure the System *declares* — units, reductions, reads, growth maps — taping each
piece, rather than have the model hand-write the interior. This is where plant should sit if rung B
is too large, and it is the difference between declaring a decomposition and implementing one.

---

## 6. The nouns odelia does not have

odelia has the hard algorithms and none of the vocabulary. A parameter row has no route out of
`ode_rates_adjoint(λ_dydt, λ_y)`, so the model made the accumulator a mutable System member the
driver clears and reads around a sweep — an out-of-band channel the solver cannot check. Report 01
§6's failure signature, *a gradient that is a fixed fraction of the right answer with the correct
sign and no error raised*, is unpoliceable by construction.

| noun | what it is | today |
|---|---|---|
| **parameter adjoint** | a parameter row's route out of a transpose | a mutable System member, now **six** writers, four defensive re-zero guards |
| **seed** | `∂C/∂y` at `T` | model-side |
| **reduction transpose** | a weighted sum over a grid with a passive coordinate | written five times by hand |
| **growth event** | an insertion, its map, and the segmented sweep | model-side; odelia has the range only |
| **refusal** | a gradient-validity channel, metric-level | **does not exist in C++ at all** |
| **graft** | `v + Σ ∂v/∂uᵢ·(uᵢ − passive(uᵢ))` | written **four** times |

Adding the parameter channel in-band is the one that matters most: it turns report 01 §6's silent
scaling error into a length mismatch. The growth boundary is where the argument is strongest, because
it is a second out-of-band writer to the same channel and its contribution is exactly what a missing
segment corrupts by a fraction (§9).

### 6.1 A detection-based protocol loses its caller silently — and that has already happened

Every hook in this design is discovered rather than declared: SFINAE detectors, then C++20 concepts.
A System that provides a hook gets the behaviour; one that does not gets a default. **Nothing checks
the converse — that a hook the model provides is still called by anyone.**

It is not a hypothetical. The engine once drove three caching hooks; a commit replaced that detection
protocol with a concept and deleted the three call sites. The model kept its half. Those three
functions are still defined, still compile, and are called by nothing, so the container they fill
stays empty forever and the one feature built on it — replaying a completed run's environment against
a different parameter set — throws on its first statement, for every model, always. **It has been
dead for over a month and the suite does not say so**, because the test that asserts the failure
message asserts it on an object that has not been run, where the message is also correct.

Two things follow that bear directly on §6's proposal.

**A missing hook must be a compile error, not a silent default.** Every noun added to
`ode_interface.hpp` widens this surface. The existing concepts already show the shape: one of them is
four hooks where the real consumer needs one, satisfied with three empty bodies — a model opting into
a contract it does not mean, and no way to say so.

**And the deleted half is not the half anyone guards.** The recording protocol carries a
`static_assert` that the concept is satisfied; the caching protocol carried nothing, and the caching
protocol is the one that broke. A concept asserts that a *type* is adequate. What went missing was a
*call*.

**The reduction primitive**, read off what the code actually needs: a **passive** coordinate accessor
(passive by return type, which is what makes the coordinate conditions unviolatable); a contribution
returning a **tuple**, so the value-and-slope walk, the per-resource walk and the per-metric walk are
one function with a codomain parameter; passive predicates for the early exit and the closing
interval, evaluated by the driver so forward and transpose cannot see different ones; and a declared
`coordinate_is_state` flag in one place instead of four `if` blocks in two files. The driver owns the
weights, the traversal, the association order and the half-factor — which today lands in four
different places, and one consumer traverses backwards.

**The growth primitive**: `apply`, `undo`, and the map as one scalar-templated function of
`(y⁻ ++ θ) → y⁺` used by the tape, by a forward-tangent reference and by the replay alike. Plus a
recording hook so the event list is **declared by the run** rather than inferred from width diffs —
which alone removes the newest-first recovery walk and the exact-float time matching, and makes
representable an event that changes no width at all.

---

## 7. What gets deleted

Great abstractions are measured in concepts removed.

| delete | why |
|---|---|
| `supplied_derivative.hpp` | **zero production consumers** anywhere. The construction the model needs is the other one |
| three of four grafts | one idea, four spellings. Only the model's copy has the finiteness guard report 05 §8 says the construction *needs* |
| `node_size_adjoints`, `node_uptake_adjoints` | structs of **named** slots. One parameter got a row by *adding a field*; each further one wants another field plus two hand-written partials |
| `light_reduction_slots` | the right idea named for one reduction |
| four competition walks | value / value-and-slope × ordered / unordered — one walk with a codomain parameter |
| five trapezium transposes | one driver, four integrands |
| six copies of the unit×(elements+1) walk | an iterator yielding `(slot, optional<state_row>, parameter_base, element&)` |
| six copies of "seed parameters before state" | one recorded map |
| the four parallel trait arrays | values, addresses, seeded flags and zero-at-interior flags, keyed by position to a **fourteen**-argument setter. The signature has already grown once; the two packages disagree about its arity today |
| `gradient::Status` | four values derived **from residual magnitude**, which report 05 §7.0 forbids. The correct ten-branch decision tree sits beside it, unused by the gradient entry point |
| the five explicit `∂p*/∂u` vectors | see below |
| `narrow_over_introductions`, `widen_over_introductions`, `narrow_to_segment`, the segment loop | odelia's, once growth is a declared event |

**The last two rows are the strongest evidence the primitives are missing.** The model does not use
the rank-one collapse at all: it forms `∂p*/∂u` explicitly for every input family and multiplies each
into every output row — precisely the outputs-by-parameters matrix report 02 §3.2 says is never
formed, ~200 lines of it. The opaque node *already exposes* the collapse; its consumer could not use
it, because the node's output set was enumerated from what the solver exposed rather than from the
consumer's equations. **Report 02 §3.0's warning, realised exactly** — and undetectable, because an
absent output has no column.

---

## 8. The implicit node

One package's gradient header is the implicit-node pattern written once against one model's
fifteen-wide parameter vector; the model's own `record_leaf_outputs` is the same pattern written a
*second* time against the same model. Neither is hydraulics. What *is* hydraulics is already cleanly
separated in the forward direction; the derivative direction has no such seam.

The general node, read off what the code consumes: a solve returning value, outputs and a
**classification by branch taken**; a residual with **feasibility as a separate channel, never a
sentinel value**; a curvature with the same feasibility channel per arm; an output declaration naming
which output *is* the implicit quantity (p-channel exactly 1) and which *is* the objective (p-channel
exactly 0); the ordinary partials; the bound derivatives; **an amplification ceiling on `|s|/|R_p|`**,
refusing the non-objective rows and emitting the objective row regardless; a factorisation hook; the
graft with its finiteness pre-test; and a transpose-identity harness.

That last item is what makes the rest affordable. `⟨v, Ju⟩ = ⟨Jᵀv, u⟩` needs **no reference gradient
and no differencing** — it is a property the transpose either has or does not — and it already holds
to `1.4e-14` over 294 operating points. A primitive that ships it gives every future node the one
check internal consistency cannot fake.

### 8.1 The cheapest branch has never been run

The variant that **has already dissolved the argmax** is not on the gradient path at all: its tracked
operating point is passed into a `double` evaluation and clamped against `double` bounds, so it does
not compile at an active scalar, and no export instantiates it.

That is worth stopping on. A tracked operating point is an ODE state, so its derivative arrives from
the adjoint for free — no implicit solve, no stationarity condition, no curvature to divide by, no
five kinds of point. It needs the marginal objective at a *prescribed* point, which the node already
returns, and the ordinary adjoint the engine already runs.

So: designing the implicit node against only the hard case will give it the hard case's shape. The
tracked-state case is the one that says what the *general* interface is, and it also exercises a
regime report 05 §7.0 lists among the states the gradient is not valid at and does not refuse.

---

## 9. Order, and the fences still standing

You do not move a fence until you know why it is there. Four are still there, and one that looked
like a fence is a hole.

**1. The branch tip does not build.** It calls seven symbols absent from every available ref of its
dependency; the superproject's pointer is the last commit that compiles. **The other half of the
root-carbon anchor is unpushed.** Nothing below can be validated until it lands.

**2. The upstream reduction has no isolated referee.** The probe is written and exported and **called
by no test**, so that transpose is checked only *through* the composed right-hand side, where a
cancelling pair of errors passes. Wiring it is an hour. Refactoring a transpose whose only check is
composed is refactoring without a net.

**3. One factorisation coefficient is unchecked in the direction that decides the answer.** The
residual runs over the potential family only — which report 05 §7.3 says is precisely the family that
*cannot* detect an error in it, the vectors being collinear. Report 08 §3.1 prices it: one percent
becomes fifteen- to twenty-six-fold in the direction the ecology cares about, and it sits in the
sweep **and** in its reference.

**4. The transposes themselves are fixed.** All four coordinate conditions hold on the supported
coordinate. **This fence is down**, which is why generalisation is the next move rather than a
competing one.

### And one live defect

**The first segment is never swept.** The sweep loop descends over the event boundaries and covers
recorded steps above the *first* boundary only; steps below it are never visited, and the loop exits
with their adjoint contribution simply missing. The forward references do not have this asymmetry —
their replay loops run one more segment than the sweep does — and the diagnostic counter agrees with
the loop rather than with the trajectory.

It is invisible on every fixture, because a run from bare ground introduces before it steps, so the
un-swept range is empty. It is reachable two ways: a resumed run, which integrates a gap before the
first event; and **any schedule whose first time is not the initial time**, because the schedule
setters validate no such thing. The branch's own comment asserts the invariant that would make it
safe, and nothing enforces it.

The failure shape is report 01 §6's worst: finite, correctly signed, a fraction of the right answer,
nothing raised. The fix is one line. **The structural point is that the segment list is inferred and
never checked for coverage** — no code asserts the ranges partition the recording — and that
assertion is one of the obligations a growth primitive would own.

### Then, in order

1. **Carry the seed closure outward.** Report 05 §10.1's declared-zero rows are **already closed** at
   the tip, by one call to a primitive that already existed — **which is this report's thesis
   demonstrated rather than argued.** Another strategy still freezes its birth size and still has the
   defect. The work is not to close it again; it is to make the closure the interface, so a model
   cannot declare a solved quantity `double` by accident.
2. **One parameter registration list.** Two lists of 47, paired by position, no guard, and they are
   the input to the column naming report 05 §9 warns about.
3. **Assert `rebind<double>` is the type itself.** A subclass inheriting `rebind` resolves to its
   parent and silently drops its own extra state. Latent only because no export names it — and
   inheriting `rebind` is exactly what the documented variant recipe produces. Three lines, at compile
   time, for every model, forever.
4. **Measure the stage recording** before designing anything (§5). The instrument exists.
5. **The parameter channel in-band**, then the block interface, then the reduction primitive, then
   growth. Design the implicit node against **both** the argmax and the tracked-state case (§8.1).
6. **Refusal.** The gradient returns a plain matrix; report 08 §9's requirement that an undefined
   metric be distinguishable from a zero one is **not representable in the return type**, and no
   adjoint-path code tests finiteness. A type change, cheaper before the interiors move than after.

---

## 10. Costs and gaps the design does not price

**The boundary transpose records a whole-ensemble tape in the innermost loop** — the full shared-part
rebuild plus a boundary evaluation per unit group, once per stage per step per functional. Its skip
guard only fires when no boundary channel is seeded. Report 01's "peak is one unit" is true of the
unit block and false of the stage.

**`ȳ(0)` is computed and discarded** — report 05 §10's sixth path, zero-valued here because the first
recorded state reads no parameter, live for any model whose initial state does.

**The supplied rows are ~36 re-solves of the opaque node per block.** Five families are
finite-differenced, and one of them rebuilds a tabulation each time. Against one evaluation for the
forward pass, per unit per stage per sweep. The differencing is deliberate and each step size is
reasoned; what is unpriced is the total.

**Each block copies the whole model object**, tabulations included, per unit per block. That is the
right answer to report 01 §3's purity requirement — it makes the permutation check pass by
construction rather than by discipline — and it is a per-unit allocation nobody has measured.

**An empty event list is still indistinguishable from an insensitive system**, except by a caller who
reads the diagnostic counter.

**The refiner's error estimate omits the closing element**, so the closing interval is the one part of
the grid never assessed. Two of the four reductions have no error estimate at all and inherit a grid
refined for the other two.

**Ties pass the schedule validator.** The sorted check permits equal times, and nothing on the
scheduled path calls the distinctness guard. Zero-width intervals are silently valid arithmetic —
measured at **>10%** on one reduction — and no comparison of integral *values* can detect it, because
a by-hand reference walks the same defective grid.

**Seven index spaces, every one a bare `size_t`.** Strategy state slot, node ODE row, flat ODE row,
reduction grid slot, block input row, block output row, aux slot — plus resource and parameter slots.
Conversions are hand-written, and the two-counter idiom that converts grid slots to ODE rows is
documented at one of the four sites that use it. The node's ODE layout — *states, then offspring, then
log density* — is written out as `state_size()` and `state_size() + 1` at four separate places and
exposed as a named constant nowhere. **The block interface already subsumes two of these**; declaring
its segments (§4.1's split, §6's reduction) would subsume two more.

**A tolerance that gates a branch rather than terminating a search.** One control entry's documented
justification describes a search that no longer uses it; its live role is a width comparison that
decides whether an operating point is optimised at all. It has since moved by two orders while the
measured widths it is compared against sit an order *inside* the resulting window. Report 05 §7.0
forbids classifying by a residual comparison; this is the same hazard one level out, on a width.

**Fifteen clamp sites, zero incidence counters.** Report 03 §4 and report 05 §6.2 both rule that where
a clamp masks a smooth function the honest action is to refuse the row *with its incidence counted*.
No clamp in the production path counts anything. The instrumentation that does exist is behind an
environment variable, inside an error formatter, and in a stall report.

**The gradient's own Control fingerprint omits the knobs that move the trajectory.** It carries four
entries, one of which is provably inert on the only supported coordinate, and none of the seven
ODE-control entries that set the recorded step times and sizes the sweep replays. Two runs differing
only in an ODE tolerance compare as gradients of the same function.

---

## 11. The corpus has drifted, and six of its claims would misdirect this work

Reports 00 to 08 are this project's memory, and a stale claim in them propagates into every decision
taken from them. A systematic audit against the code found the following. They are listed here rather
than in a defect log because each one changes what a reader would *do*.

**The top-ranked correctness item is already done.** Report 07 §7 ranks "give the size-space adjoint
its trait slot" first and calls it a correctness matter — rows that do not arrive at all. They arrive:
the carrier grew a fourth field, three of the four reduction-borne parameters now have rows, and the
shortfall report 06 §11 quotes as 3.041 percent is measured at 3.3e-02. Read as a work order today it
spends the budget on a closed row.

**The one it displaces is mis-scoped in both directions.** Report 08 §3.1 specifies the factorisation
check as *"one state, no gradient run, no stand"*, and the branch's own revert records that the
failure was **invisible** on exactly that fixture — no competition means no unit sits far from where
the pair was fitted. The coefficient it asks to check against a closed form *is* the closed form now,
so that half is vacuous; and the shipped test measures only the family the report itself says cannot
detect the error.

**A channel the dependency map deletes is live and linear.** Report 00 §4.2's third physical fact —
leaf area cancels out of the water channel — does not hold at this commit. Leaf area appears nowhere
in the root network; the resistances are intensive by construction and the conversion multiplies by
area afterwards, so per-unit uptake is **exactly linear in leaf area**. That is a first-order channel
from the allometric constants and height into the shared soil state, deleted from the map that §2 of
that same report calls the most important structural fact in the model.

**The count is 47, not 44.** Every report that states the parameter count states 44, and the recorded
step's input width follows it — 185 in three reports where the code gives 188.

**Three of report 08 §5.2's five structural assertions are unimplementable as written**, and one
contradicts report 00 §6: it asserts the per-layer soil block's off-diagonal cells are *exactly zero*
where report 00 says *diagonal plus rank one*, which is what the code has and what the suite measures.

**And the cost premise is not currently met.** The design exists because an adjoint answers every
parameter for one run and one sweep. Measured on this tree at 81 units and 171 accepted steps: the
forward run is 6.2 s and one gradient 1006 s, against roughly 291 s for re-running once per parameter.
The scaling argument stands and re-runs are not a usable alternative at production step sizes — but
the constant currently inverts the conclusion, **and nothing in the ladder measures time at all.** The
flatness guarantees the design rests on are about memory and target count; both are checked. That is
the strongest argument in this report for §5's measurement coming before §6's design.

---

## 12. What would falsify this

- **The interiors are not model-shaped.** If a second model with an inner solve needs a materially
  different *schedule* — not different kernels, a different order — the six-step interior is this
  model's and not a primitive. The cheapest probe is the simplest existing strategy: ask what its
  `ode_rates_adjoint` would have to be.
- **`Patch` cannot be made generic over its environment.** The reverse half names environment members
  no other environment has, so it would not instantiate. **If reductions cannot become a declared list
  the environment publishes, the primitive cannot live in odelia at all** — this is the precondition
  for everything in §6.
- **A stage recording does not fit.** §5's rung B rests on an unmeasured number, and the instrument
  to measure it already exists. If it does not fit, rung C is the answer and rung B is a distraction.
- **The reduction primitive does not cover the functional.** The functional is already transposed by
  tape with no hand transpose. If the driver cannot express it, it is not the general object.
- **The closing element cannot be split into three.** §4.1 claims the cache, the grid point and the
  growth template are separable. If some consumer genuinely needs them fused, the two-slot accumulator
  is essential rather than a symptom.
