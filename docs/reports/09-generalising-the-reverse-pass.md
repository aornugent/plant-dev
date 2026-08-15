# Generalising the reverse pass: the primitives that would make it ergonomic

The stand-scale reverse mode is correct on the birth-date coordinate and it cost more code than it
should have. **This report is about what odelia should offer so that writing a differentiable model
in `plant` stops being a derivative-engineering exercise.** It says why the cost was structural
rather than a matter of effort, and it specifies the primitives that remove it — for the model that
exists and for the next one.

The measure it is written against is a developer's, not a benchmark's:

> **What does an author of a new model have to write before they get a correct gradient, and how
> much of it can be wrong without anything saying so?**

Today the answer is about **1,520 lines** of reverse-pass code in `plant` (§2), of which ~440 are a
hand-mirrored transpose held against its forward function by a comment (§3), and the honest answer
to the second half is *most of it* — the corpus's recurring failure shape is a finite, plausible,
correctly-signed wrong number. The target is a forward pass plus a **structural declaration of about
thirty lines** (§5.2), with every transpose derived and the remaining mistakes turned into compile
errors or aborts.

Reports 00 to 08 state what the derivatives are and what a correct implementation must satisfy. They
are written from the model's side. **This one is written from the solver's**, and the discipline is
explicit: §1, §4 and §5 use no ecological vocabulary at all. No cohort, plant, light, soil, seed,
species, census, trait. Where a property cannot be stated without one of those words, that is
recorded as a finding rather than worked around — because it marks exactly where a solver-level
primitive would under-determine the model.

The claim in one line:

> **The engine offers two ways to get a gradient and nothing between them. Every line the project is
> unhappy about is the cost of the gap.**

§7 is the deliverable — seven primitives, each with what an author writes today, what they would
write instead, and how it fails when they get it wrong. Everything before it is the evidence that
those seven are the right seven; everything after it is what they delete and what they do not fix.

The reading is of `plant` at `cdf3f0c9`, `odelia` at `8ac1da2`, `phylloptim` at `1b0b468` — the
triple the superproject points at, seven, two and fourteen commits past the one this report was
first written against.

**This reading is a build.** The previous one was not, and said so: §10's first fence recorded that
the tip called symbols no available ref of its dependency carried. That fence is down — the triple
above compiles at `-O2` and runs — so every number below is measured on a tree that works rather
than inferred from source. Where the re-reading moved a figure, the old one is kept beside it,
because the size of the movement is what says whether a claim was structural or incidental.

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

Within the model-shaped bulk the concentration is stark: `cohort_block_adjoint` (**152**),
`boundary_condition_adjoint` (**131**) and the light reduction transpose (**92**) are a quarter of
it. Each of the three grew — 135, 110 and 89 at the previous reading — and **they grew for one
reason, which is the batching of §5.3**: the two block entry points now take a vector of seed sets
and carry a metric index through, so record-once-sweep-many cost them a dimension. That is a real
economy paid for in exactly the place this report says the lines are.

And in `tf24_strategy.h`, **2,356 lines** against 2,300, still header-only against the 1,426 the
file held split header/impl before this branch. The AD share was measured at 810 lines then and has
not been re-derived on the same classification here, so treat 35% of the file as the previous
reading's figure rather than this one's; what is re-measured is the total, and the total moved by
2.4%.

**The reverse-pass surface in `plant` totals about 1,520 lines**, summed over the function spans
rather than estimated: ~779 in `patch.h`, ~145 in `species.h` and ~574 in `scm.h`. That is within a
few percent of the previous reading's 325 + 1,225 = 1,550 for the same territory, so **the bulk has
not shrunk — it has been re-apportioned.** Nothing in the intervening twenty-three commits deleted a
transpose; two of them added a dimension to three.

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

**The forward model now makes that distinction, and it did not when this was first written.** The
staging above is three named functions rather than a sequence a reader has to reconstruct: one
builds the field with the closing interval omitted *and keeps each species' partial reduction*, one
places the closing element in it, and one rebuilds the field closing from what the first kept. The
kept partial is the object the middle step needs, and holding it is what makes the third step a
close rather than a re-derivation.

So the sharpest form of this section's old claim is withdrawn. It said the reverse side was forced
to name apart a distinction the forward model does not represent, and that this asymmetry was the
whole reason the boundary transpose cost its lines. The forward model represents it now. **What
survives is the accumulator count**, which is the part that was actually load-bearing: the reverse
side still carries two density slots for one quantity, for the reason the struct's own comment
gives — one accumulator would transpose one derivative through the other's argument — and nothing
in the type system counts read points even though the forward model now stages them. The
distinction being representable did not make it *counted*.

**And the staging costs two full field builds per environment computation**, which §5.3's tape
arithmetic has to carry and did not: the value the first build returns is kept, but the interpolant
it fits is fitted twice.

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

## 5. The design: a structural declaration in place of a derivative obligation

Everything above is diagnosis. This is the proposal, and it rests on one move.

> **`AdjointRates` asks a model for the transpose of its own right-hand side. Ask it instead for the
> shape of its right-hand side, and derive the transpose.**

Every line of scaffolding in the model exists to discharge a *derivative* obligation. A model that
declares its *structure* has no derivative obligation left, and what remains is the forward pass.

### 5.1 The shape, which is not model-specific

```
per stage:
    R₀       = reduce(units)                   # the closing element omitted
    closing₁ = boundary(R₀, y, t, φ)           # the inflow condition, in R₀
    R        = R₀ ⊕ close(closing₁)            # the shared part
    rates_u  = F(u.state, read(R, u), φ)       # per unit, independent
    closing₂ = boundary(R,  y, t, φ)           # the SAME condition, in R
    R'       = reduce₂(unit outputs ⊕ closing₂)# the downstream reduction
    dydt     = assemble(rates, R')
```

with insertions at passive event times. That is the model's stage, and nothing in it names the model.

**The two boundary evaluations are the shape, not a detail.** The condition is the same function at
different arguments, the upstream reduction reads the first and the downstream reduction reads the
second, and they differ by more than `1e-6` relative with a test asserting it. A declaration listing
"the boundary condition" in the singular gives the downstream reduction a transpose linearised at the
wrong operating point — so what a model declares is a **read-point list**, and §4.1's rule (one
accumulator slot per stage a quantity is read at) is then counted by the engine rather than by the
reader.

### 5.2 Three layers, and an author only writes the first

**L1 — the forward pass.** `rates(state, reads, params) → rates`. No rebind, no parameter address
list, no hand-derived partials, no `passive()`, no `if constexpr (double)`, no adjoint scatter, no
graft.

**Not necessarily scalar-templated, and this matters.** There are two ways to make a model
differentiable in this tree and the cheaper one is not the one the reference model took. *Lifting*
templates the whole strategy on the scalar and hand-supplies a Jacobian wherever it will not lift —
+61% file size, a 47-line rebind, eight dual-path branches, two parallel parameter lists. *Extracting*
leaves the model alone and pulls the differentiable arithmetic into scalar-templated free functions
that the `double` model then **delegates to**, so the existing forward suite validates faithfulness.
The second is 125 lines and changes the strategy's shape not at all. A declaration that demands a
rebind over the whole strategy accepts neither of the other two strategies in this tree — one has no
template parameter at all. **L2 must support a partially-lifted model.**

**L2 — the declaration.** The parameter list as `{name, &field, role}` pairs; each reduction as
`{position, contribution, kernel, stage}`; the read layout as typed segments; the read-point list;
the growth map; and, for a model with an inner solve, the opaque node.

**Its size splits, and the split is the honest number.** The structural core — reductions, read,
boundary, growth — is **~31 lines** for the reference model and shorter for the simplest one, whose
parameter list is *empty*. The parameter list adds ~60 one-line entries. **The opaque node's
declaration is a few hundred lines**, because a curvature, a two-coefficient factorisation with a
model-chosen anchor direction, and fourteen traits with a complementary-slackness mask all have to be
named, and none of them exists on the forward path. §2's 389-line artefact therefore **moves into the
declaration rather than disappearing** — around 86% of its body is the primitive's, but what survives
is a declaration and not a deletion.

**L3 — the engine.** The tape, the blocking, both reduction transposes, the segment sweep, the
parameter accumulator, the refusal channel, and the harness.

### 5.3 The rule that decides what is taped and what is supplied

> **Tape everything whose operations you can afford to record. Supply rows only where recording is
> impossible — an opaque solver — or unaffordable — the whole trajectory.**

By that rule the reductions are taped, and the number rather than the precedent is the argument.
Counted on the source: two shared-part builds per stage at 65 query points, over ~81 units with an
early exit, at ~19 recorded operations per contribution — **≈10⁵ recorded operations, order 3 MB of
tape per stage.** That is roughly *one existing block's* tape. The reduction is not what is expensive;
the supplied-row assembly is. The ~440 hand-mirrored lines, the twelve drift sites and the latent
closing-interval defect all go, and the direct saving is the extra plain-`double` shared-part build
one of those transposes performs per stage.

**Two corrections to how this was first argued.** Citing the boundary transpose as *evidence of
affordability* is circular — §11 lists that same object as an unpriced cost, and an expensive thing
already being done is not proof that expensive things are affordable. And it is not "in the innermost
loop": it runs once per stage, after the per-unit loop.

**The reduction tape is also not separable from rung B.** The closing element is evaluated **twice**
per stage and the two reductions are linearised at different evaluations (§5.1). A tape of the
reductions alone cannot recover that ordering; only a tape over the whole stage records the sequence
and gets it right by construction.

The current split still has no cost principle behind it — the taped set includes a full shared-part
rebuild, more expensive than the reduction transpose written by hand next to it. That part stands.

### 5.4 The opaque node, which is what makes TF24 expressible

A model with an inner solve declares the solve, not its calculus:

- the residual `R(p; u)`, with **feasibility as a separate channel and never a sentinel value**;
- which output **is** `p` (its `p`-channel is exactly 1) and which **is** the objective (exactly 0);
- `∂y/∂p` for the ordinary outputs, and `∂B/∂u` per bound.

The primitive owns the envelope theorem, the implicit function theorem, the rank-one collapse, the
amplification ceiling, the classification, the graft, and the transpose identity. **The
classification becomes structural** — a consumer cannot fail to consult it, which is the defect that
currently applies the interior formula at pins.

One generalisation follows, and it is **not** free: let the node carry **M operating points instead
of one**. The collapse is then `M` independent rank-one collapses — cheap, `O(M)`, block-diagonal
because the solves are independent. But `M` is not small. The shipped integration rule gives **21
points**, and each needs its own supplied-row assembly, which is ~36 re-solves of the opaque solver.
Priced against §12's measurement — one block VJP is ~3.9 ms against ~73 µs for a forward rate
evaluation, so the graft is ~54× the thing it differentiates — `M = 21` multiplies the dominant term
and takes one gradient from 1006 s to roughly **six hours**.

**And the refusal it would remove is not about rank.** The multi-point mode is refused because its
crown means pass through a submodel that carries `double` and is not scalar-templated at all. That is
a fact about a dependency, not about the primitive. The honest claim: M operating points make the
mode *expressible*, at M× the dominant cost, once that dependency is lifted.

### 5.5 Correctness by construction, or abort — with the four rows that do not survive

Every defect in this corpus returns a finite, plausible number. The design's test is that each one
moves out of that class. **An adversarial pass against this table struck or downgraded four of twelve
rows**, and the two the section originally called "the whole argument" are the two that failed
hardest. The corrected table, with each row marked *promotion* (the mechanism is already written in
this tree at one site and missing at another) or *invention*:

| failure | under the design | |
|---|---|---|
| transpose drifts from its forward | **impossible — given a rebind asserted complete** (see below) | promotion |
| parameter list and name list disagree | **compile error** — one list of pairs, completeness by `sizeof` | promotion |
| non-finite supplied partial *or input* | **abort**, inside the graft; the input half is one line | promotion |
| interior formula at a pinned point | **abort** — classification is the primitive's, by branch taken | promotion |
| segment list does not cover the recording | **abort** — coverage assert, enabled by a declared event | promotion |
| a hook loses its *caller* | **compile error** at the point of use — but a concept asserts a *type* | half |
| a rebind drops a subclass's state | **compile error** | invention |
| amplification through a near-fold | **abort** on `\|s\|/\|R_p\|`, objective row emitted regardless | invention |
| an undefined metric | **abort** — the return type carries validity | invention |
| ~~weight-derivative on a passive grid~~ | **struck** — already true today, bought by a return type | — |
| ~~a position used as a value~~ | **struck** — the named failure does not occur; the converse does, and must stay legal | — |
| state carried between units | **downgraded to a harness fixture**, not an abort | — |

**Why the two struck rows were wrong.** Passivity bought by a return type is not a proposal — it is
deployed, in the accessor every reduction but one already uses, and its guarantee survives every
downstream mistake because the conversion happens at the source. Claiming it as a gain double-counts.
And the failure the position type was supposed to prevent runs the wrong way: a *value used as a
position* is the construction the height coordinate legitimately needs, where the position **is** the
state. A type forbidding it would make the correct model inexpressible and close the unsupported
coordinate permanently rather than fixing it.

**Why the permutation row is a fixture and not an abort.** The invariant only exists on a grid whose
weights coincide, and the suite's fixture is hand-built to make two of them coincide. At an arbitrary
state a swap changes the answer, so there is nothing to compare — and the check reads *forward* rates,
while the state that could actually carry between units on the reverse side is the parameter
accumulator and the boundary slots. The harness is the right home; the engine cannot abort on it.

**And the first row needs an obligation the design did not list.** "One function" is one *source
text* evaluated on **two objects** — the value path's, and a hand-copied active twin. That copy omits
nine members, one of which decides whether the shared part is built at all, so the tape would be the
transpose of a function the value path never evaluated. One omission of exactly this kind has already
been found and patched by hand, with a comment saying so. **A rebind asserted complete is a new engine
obligation**, and the pattern that would discharge it — a completeness assert against an invariant the
compiler already computes — is written 180 lines away in the same file, for a different aggregate.

### 5.6 What it cannot guarantee, and what it does instead

Three things no primitive can check, and the honest response to each.

**Whether a kink is meant.** Undecidable. But it can be *declared*: a branch on an active value is
either a severance the model intends or a guard, and the position type makes an undeclared one a
compile error. Guards then carry an incidence counter by construction — today fifteen clamp sites
carry none.

**A derived input's convention.** Resistances per unit area and resistances absolute are both vectors
of positive numbers, and the receiving side cannot tell. The primitive requires the convention to be
declared and asserted on the **caller's** side, where the inputs to the derivation are still visible.

**A model-specific factorisation.** The hook is general; the residual check is the primitive's; the
*states it runs on* are the model's — and the branch's own history says they must come from a
competing stand, because without competition no unit sits far from where the coefficients were fitted.

---

## 6. Three rungs, not two

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

**This is measured, not argued.** An instrumented build records the whole stage and reports:

```
stage tape (bytes) = 206,162 + 64,952 · N          R² = 1.0000000, every point within 0.08%
```

**65.0 kB per unit.** At production width — a full-lifetime stand, refined schedule, **164 units** —
one stage is **10.4 MiB**; two species is 20.6 MiB. One gigabyte is not reached until N ≈ 16,500, and
sixteen until N ≈ 264,000. Peak RSS tracked the logical tape, so there is no hidden allocator
multiplier. Route A at the same width is ≈ 101 GiB, which is report 01 §0's rejected figure —
**four orders, not the four-to-five claimed above.**

**And rung B is already written, in odelia.** `step_adjoint` has two branches, and the `else` of
`if constexpr (AdjointRates<System>)` lifts the System to the active scalar, makes one tape, and per
stage records the System's own `derivs` — which for this model *is* the state-and-field rebuild
followed by the rates. That is rung B verbatim, and it is still there at this reading, now behind a
`static_assert` on the rebind hook that names what a System has to provide to take it. The model
satisfies `AdjointRates`, so the `if constexpr` takes the other branch.

**~~Deleting `ode_rates_adjoint` routes it into code that already exists.~~ Tried, and it does not.**
The sentence was the strongest claim in this report and it is false in four ways, each of which was
read off the branch rather than argued:

- **There is no parameter channel.** The branch registers the stage state as its only tape inputs and
  reads back only state adjoints. The twin is constructed *before* the tape, so every parameter in it
  is born without a slot and stays a constant for the recording. plant's entire gradient is a *trait*
  gradient; routed here, all 47 columns come back absent.
- **There is no batched form.** `step_adjoint_batched` opens with a hard assertion on the batched
  concept and the generic branch has no batched twin, so three metrics would become three recordings
  — giving back the economy §5.3 and §6 both credit.
- **It costs more, not less.** The branch *retakes the whole step* in double and then records six
  active evaluations: thirteen model evaluations per step, against six plus six hand transposes.
- **It is barely exercised.** One step of a three-state toy, never through the segment sweep, never
  batched, never with a parameter.

**And the premise underneath was wrong, which is the more useful finding.** This report reads plant
as hand-writing its interiors. It is not: `cohort_block_adjoint` *is* odelia's own
`vector_jacobian_products`, at cohort granularity. **plant is already on a taped design** — what it
hand-writes is the two reductions, the environment cascade and the light/allometry scatter, about
440 lines, which is §3's number and not §2's 1,225. The gap between rung A and rung D is real; the
claim that one end of it is already built is not.

**One rung-B-adjacent economy has landed since, and it is the first noun in §7 to arrive.** odelia
now carries a `BatchedAdjointRates` concept and plant a batched entry point: a block is recorded
once and swept once per metric, where the loop it replaces recorded it once per metric. **The
economy report 05 §9.1 describes is therefore real rather than proposed**, and it arrived by adding
a dimension to the existing hand-written interiors rather than by taping a stage. That is worth
holding onto, because it is the counterfactual this report is arguing against: the same saving was
available by declaring the structure once, and was instead bought by widening three transposes and
threading a metric index through them. Two gaps in that branch, both nameable: it seeds state adjoints only, so parameters must be
registered as extra tape inputs (§7's missing noun); and it shares one tape across six stages without
releasing the slot array, which costs ~1.8× one stage's peak until a clear-and-re-register per stage.

Three results that were not expected:

- **A stage records *less* per unit than a block does.** 22.9 kB inside a stage against 55.9 kB
  standalone — 41% — because the per-unit block re-registers the whole 135-wide read and re-derives
  the interpolant's span data for every unit, where a stage does it once.
- **The whole-shared-part transpose is correct by tape**, checked against a central difference of its
  own forward at `1.3e-10`, `2.7e-06`, `3.7e-08`. That is the object the ~440 hand-mirrored lines
  transpose, transposing itself. And the stage tape delivers the parameter rows — **47** registered,
  27 non-zero, all finite — out of the tape rather than an out-of-band mutable member. The count was
  written 44 here, which is §12's own fourth finding landing in the report that reports it.
- **Time is neither a win nor a loss and must not be claimed as either.** One stage's record-and-sweep
  is 1.4× the per-unit block loop it replaces. Both are ~100× below the ~0.98 s per stage §12
  measures, because that is the opaque node's supplied rows, which rung B leaves untouched.

**What it trades away.** Report 01's *peak is flat in the unit count* is a design commitment asserted
by a test. A stage tape gives it up deliberately for *peak is 65.0 kB per unit*, which needs an
absolute number rather than a flatness test.

**One correction to how this was first put.** "The instrument already exists" was true of the
per-unit block and false of the stage: the one call that records the whole shared-part build
**discards its return value**, so the number it already computes is thrown away. That branch is
taking a 3.4 MiB whole-patch recording per stage today — **65% of a full stage tape** — to read two
densities and a height out of it.

**Rung C — blocked, over a declared structure.** When a stage does not fit, block it: but let odelia
block over a structure the System *declares* — units, reductions, reads, growth maps — taping each
piece, rather than have the model hand-write the interior. This is where plant should sit if rung B
is too large, and it is the difference between declaring a decomposition and implementing one.

---

## 7. The seven primitives — the deliverable

odelia has the hard algorithms and none of the vocabulary. A parameter row has no route out of
`ode_rates_adjoint(λ_dydt, λ_y)`, so the model made the accumulator a mutable System member the
driver clears and reads around a sweep — an out-of-band channel the solver cannot check. Report 01
§6's failure signature, *a gradient that is a fixed fraction of the right answer with the correct
sign and no error raised*, is unpoliceable by construction.

**Each entry below is a noun odelia does not have, and the reason it belongs there rather than in a
model is the same in every case: it is the same object for every model, and writing it per model is
what produces the drift.** The DX claim is the third column — what an author writes instead — and the
robustness claim is the fourth, because a primitive that removes work and keeps the silent failures
has not earned its place.

| primitive | what an author writes today | what they would write | how a mistake surfaces |
|---|---|---|---|
| **parameter adjoint** | a mutable System member, **six** writers, four defensive re-zero guards; since the batching a vector of them indexed by metric, so the out-of-band channel grew a dimension rather than acquiring a route | nothing — the row leaves the transpose in-band | a **length mismatch**, where today it is a fixed fraction of the right answer with the correct sign |
| **graft** | `v + Σ ∂v/∂uᵢ·(uᵢ − passive(uᵢ))`, written **four** times, only one copy carrying the finiteness guard report 05 §8 says it needs | the partials and the inputs | **abort** inside the graft on a non-finite partial *or input*, once, for all four sites |
| **reduction** | a forward walk and a hand-mirrored transpose, five times, held together by a comment | position, contribution, kernel, stage | a transpose cannot drift from its forward because there is one function |
| **seed** | `∂C/∂y` at `T`, model-side | the functional | — (already taped; it is here because it is the one the reduction primitive must also cover, §13) |
| **growth event** | insertion, map, narrowing, widening, replay, and a segment list **inferred from width diffs** | `apply`, `undo`, and the map | **abort** on a segment list that does not partition the recording — which is §10's live defect |
| **refusal** | nothing; it **does not exist in C++ at all** | which points are answerable | an undefined metric is a distinct value in the return type, not a plausible number |
| **opaque node** (§5.4) | ~200 lines forming `∂p*/∂u` explicitly per input family, plus four parallel trait arrays keyed by position to a fourteen-argument setter | the residual, the bounds, which output *is* `p` | the classification is the primitive's, so the interior formula **cannot** be applied at a pin |

**Two of the seven carry most of the DX gain and they are not the same two that carry most of the
robustness gain.** The reduction and the opaque node are where the lines are — five hand-mirrored
transposes and a two-hundred-line explicit Jacobian. The parameter adjoint and refusal are where the
silence is: one turns a scaling error into a length mismatch, the other turns "the gradient is
undefined here" from a thing no type can say into a thing the caller cannot ignore. **Build for lines
and you keep the silent failures; build for silence and the model stays as big as it is.**

Adding the parameter channel in-band is the one that matters most, and the growth boundary is where
the argument for it is strongest: it is a second out-of-band writer to the same channel, and its
contribution is exactly what a missing segment corrupts by a fraction (§10's live defect).

### 7.1 The reduction primitive, read off what the code needs

A **passive** coordinate accessor — passive by return type, which is what makes report 05 §6.1's
coordinate conditions unviolatable rather than testable. A contribution returning a **tuple**, so the
value-and-slope walk, the per-resource walk and the per-metric walk are one function with a codomain
parameter. Passive predicates for the early exit and the closing interval, evaluated by the driver so
forward and transpose cannot see different ones. And a declared `coordinate_is_state` flag in one
place instead of four `if` blocks in two files.

**The driver owns the weights, the traversal, the association order and the half-factor** — which
today lands in four different places, and one consumer traverses backwards. That last point is the
DX argument in miniature: association order is not a modelling decision, it is a floating-point
decision, and a model author is currently required to get it right in four places to keep two sums
agreeing in their last bits (report 03 §3.2).

**Half of this is now built, and building it corrected the specification.**
`odelia::quadrature::trapezium_weights` takes the grid through a callable returning `double` — so a
width cannot carry a derivative however the caller stores its grid, which is passivity by type rather
than by discipline — and owns the stopping rule and the closing interval. Both of plant's reduction
transposes now walk it. What is not yet migrated is the *forward*, and the reason is a constraint the
design did not have:

> **A per-slot weight vector cannot serve the forward.** `Σ wₖ fₖ` and `(Σ widthᵢ(f_lo + f_hi))/2` are
> the same map with a different association, and the forward's association is asserted **bit-exactly**
> — the fused value-and-slope reduction against the plain value reduction, over 200 heights and seven
> crown shapes, with a control pinning the patch-level order too. So the primitive has to be
> **interval-major**, and a caller keeps its own accumulator. It is, which is why the transposes could
> take it; the forward needs a summing entry point on the same walk, and a re-blessing budget.

**The counts in §8 were wrong and the walk is more duplicated than they say.** There are **two**
hand-written trapezium transposes, not five — the census transpose is taped, and the offspring
transpose has no grid at all. But the half-factor has **six spellings across eight lines**, the early
exit is written **four** times, and the closing predicate **five**. Migrating the forward sites
removes about **288 lines of walk code out of 505**, and that is where this primitive pays for itself:
on the transposes alone it roughly breaks even in lines and buys only the hardening.

### 7.2 The growth primitive

`apply`, `undo`, and the map as one scalar-templated function of `(y⁻ ++ θ) → y⁺` used by the tape,
by a forward-tangent reference and by the replay alike. Plus a recording hook so the event list is
**declared by the run** rather than inferred from width diffs — which alone removes the newest-first
recovery walk and the exact-float time matching, and makes representable an event that changes no
width at all.

**And it owns the coverage assertion.** §10's live defect — the first segment never swept — exists
because the segment list is inferred and nothing checks that the ranges partition the recording. That
assertion has no home in a model; it is a property of the primitive's own output, and it is the
clearest single case in this report of a bug that exists *because* the noun is missing.

### 7.3 A detection-based protocol loses its caller silently — and that has already happened

**This is the constraint every primitive above is built under**, so it is stated once here rather
than repeated seven times: a hook that a model provides and nothing calls is invisible, and adding
nouns is exactly what widens that surface. A primitive set that makes the reverse pass ergonomic and
loses a call silently has moved the failure rather than removed it.

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

---

## 8. What gets deleted

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

## 9. The implicit node — §7's seventh primitive, specified

*§5.4 states what it owns and §7 states what an author writes instead; this is the interface read off
what the code actually consumes.*

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

### 9.1 The cheapest branch has never been run

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

## 10. Order, and the fences still standing

You do not move a fence until you know why it is there. Four are still there, and one that looked
like a fence is a hole.

**1. ~~The branch tip does not build.~~ This fence is down.** It recorded that the tip called symbols
absent from every available ref of its dependency, that the newest buildable commit was the one the
superproject pointed at, and that every reading in this report was therefore a reading rather than a
build. The missing half has landed, the two packages' XAD build flags were matched from both sides,
and the stated triple now compiles at `-O2` and runs. **This report's numbers are measured on it.**

The fence is kept rather than deleted because of what it gated: it said nothing below could be
validated until the build landed, and that was right — the cost premise of §12, which is the
strongest conclusion in this report, reversed the moment it became measurable.

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

**The first segment is never swept**, and it is still not swept at this reading — re-checked
against the current tip rather than carried forward, because the file it lives in changed by 113
lines in between. The sweep loop descends over the event boundaries and covers
recorded steps above the *first* boundary only; steps below it are never visited, and the loop exits
with their adjoint contribution simply missing. The boundary list is built from the width changes
between consecutive recorded states, so the lowest index the loop ever passes to the sweep is the
one before the *first* width change, and everything under it is silently outside the traversal. The
forward references do not have this asymmetry — their replay loops run one more segment than the
sweep does — and the diagnostic counter agrees with the loop rather than with the trajectory.

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
4. ~~**Measure the stage recording** before designing anything.~~ **Done** — §6 carries the law, the
   per-unit constant and the production-width figure, and the answer was that a stage fits. What
   replaces it as the gating measurement is nothing: §12's cost premise, which was the other reason
   to measure before designing, has since been taken and does not oppose the design.
5. **Then the primitives, in the order §7 argues for.** The **parameter channel in-band** first: it
   is the smallest, it is the one that converts report 01 §6's silent scaling error into a length
   mismatch, and every primitive after it writes through it. Then the **block interface**, then the
   **reduction** (§7.1), then **growth** (§7.2) — which brings the coverage assertion that closes the
   live defect above as a by-product rather than as a patch. Design the **opaque node** against
   **both** the argmax and the tracked-state case (§9.1); designing it against only the hard case
   gives it the hard case's shape.

   **The order is by dependency and by blast radius, not by size.** The reduction is the biggest
   single win in lines and it is third, because a reduction primitive writing parameter rows through
   an out-of-band accumulator inherits the failure the first item exists to remove — and then the
   drift it fixes and the silence it kept would be indistinguishable in any disagreement.
6. **Refusal.** The gradient returns a plain matrix; report 08 §9's requirement that an undefined
   metric be distinguishable from a zero one is **not representable in the return type**, and no
   adjoint-path code tests finiteness. A type change, cheaper before the interiors move than after.

---

## 11. Costs and gaps the design does not price

**The boundary transpose records a whole-ensemble tape in the innermost loop** — the full shared-part
rebuild plus a boundary evaluation per unit group, once per stage per step per functional. Its skip
guard only fires when no boundary channel is seeded. Report 01's "peak is one unit" is true of the
unit block and false of the stage.

**Measured, and it is the sweep.** Component shares of one right-hand-side transpose, taken in
process so they are immune to machine drift:

| | share |
|---|---|
| boundary condition | **62.9%** |
| unit blocks | 32.7% |
| the shared-part build | 1.5% |
| the boundary nodes | 1.3% |
| **both reduction transposes and the environment cascade** | **1.1%** |

**So this report has been arguing about the wrong 1.1%.** The hand-written reductions are the
maintenance problem and they are nearly free; the object that costs is the one already written the
way §5.3 recommends — by tape. Two consequences. Any argument that taping a reduction is too
expensive is answered before it is made: it is a rounding error on this profile either way, so the
choice is settled by drift and not by cost. And the *next* cost question is not the reductions at
all, it is why a whole-ensemble recording per stage per step per functional is taken to read two
densities and a height out of it.

**That question has been answered, and answering it deleted the reductions' transposes.** The
boundary condition is evaluated *in* the field, so the knots are a strict intermediate of its own
recording — one dependency chain, not two — and a reverse sweep is linear in its seed. Registering
the knots as outputs of that recording therefore delivers the field's rows **in the same recording
and the same sweep**: they were already being computed, already being swept as zero-adjoint
arithmetic, and dropped, while the identical rows were formed a second time by hand beside them.
Seeding them costs nothing and retires the light reduction's whole transpose — the knot pull-back,
the size-space scatter, the species-level trapezium transpose, both carriers, the strategy's slot
lookup and trait rows. Measured after: the component shares are unchanged and the worst block
Jacobian cell is 3.75e-16, which is what it was before.

**Two of §8's entries are deleted by not needing the concept at all.** The size-space adjoint is
§7's second waist and §8's `node_size_adjoints` — the struct where a new parameter meant a new field
and two more hand partials. A tape carries whatever the forward reads, including a parameter nobody
has registered yet, so the waist does not need widening; it needs not existing.

**And the cost fork is now explicit, which is what makes rung B worth more than this report argued.**
Consuming those rows *requires* all 65 knots on the tape. Narrowing the recording to the two or three
spans the newborn actually reads — its queries are all at or below the seed's height, and a Hermite
query touches one span — would take most of the 62.9%, but only while the hand transposes still
exist to supply the rest. **Correctness and cost are available separately here and together only
under rung B**, which records the shared field once per stage and hangs every transpose off it.

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
only in an ODE tolerance compare as gradients of the same function. **Re-checked by reading what a
gradient returns**: the four are the collar search tolerance, the intercellular tolerance, the node
gradient step and the schedule epsilon — a solver knob, a solver knob, a differencing step and a
grid epsilon, and not one of them a property of the trajectory the sweep replays.

---

## 12. The corpus has drifted, and six of its claims would misdirect this work

Reports 00 to 08 are this project's memory, and a stale claim in them propagates into every decision
taken from them. A systematic audit against the code found the following. They are listed here rather
than in a defect log because each one changes what a reader would *do*.

**Four of the six were re-checked against the current tip and hold; the sixth reversed.** The trait
slot, the leaf-area channel and the parameter count were re-read in the code and are unchanged; the
cost premise is corrected below and is the reason this section is worth re-reading rather than
re-citing. The two not re-derived are the factorisation check's scoping and report 08 §5.2's
assertions, which are claims about the *test suite* rather than about the model — they need the
ladder run, not the source read, and this reading did not run it.

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

**~~And the cost premise is not currently met.~~ It is met, and this is the largest correction the
re-reading makes.** The design exists because an adjoint answers every parameter for one run and one
sweep. The previous reading, taken on a tree that did not build, put the forward run at 6.2 s and one
gradient at 1006 s over 81 units and 171 accepted steps, against roughly 291 s for re-running once
per parameter — and concluded that the constant inverted the design's own argument.

Re-measured on the built tree, on the refined schedule, at **84 units and 204 accepted steps** — a
fixture slightly *wider and longer* than the one that produced those figures:

| | previous reading | this reading |
|---|---|---|
| forward run | 6.2 s | **1.11 s** |
| one gradient, three metrics | 1006 s | **15.67 s** |
| gradient ÷ forward | 162 | **14.1** |
| 47 re-runs | ~291 s | **52.2 s** |
| adjoint against re-running | **3.5× worse** | **3.3× better** |

**The ratio is fourteen and it is flat**: 14.0, 13.9 and 14.1 at lifetimes of a half, one and three.
So the gradient costs about fourteen forward runs whatever the run length, break-even sits at
fourteen parameters, and the model carries forty-seven. **The premise is met with a factor of three
to spare, and the flatness is the part worth keeping** — it says the sweep's cost tracks the run
rather than compounding with it.

**What moved it is not established, and should not be guessed from the commit subjects.** The
plant-side leaf boundary still differences fourteen traits at two evaluations each, exactly as
before, so the saving is not there. The likely home is the dependency's shared curve caches, since
§11 records that each block copies the whole model object *tabulations included* and that one
differenced family rebuilds a tabulation every time — but that is an attribution and what is
measured is the effect.

Two things survive intact. **Nothing in the ladder measures time**, so this figure is nobody's
regression test and the next change to the leaf can move it by another order with no failure
anywhere. And the flatness guarantees the design rests on are about memory and target count, which
are checked. What is withdrawn is the conclusion drawn from the constant: **this is no longer an
argument for measurement before design, because the measurement has been taken and it does not
oppose the design.**

---

## 13. What would falsify this

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
- **The declaration is not shorter than what it replaces, for a model that is not this one.** The DX
  claim is ~1,520 lines of transpose against a ~31-line structural core plus a parameter list, and
  that core was counted for the model the primitives were read off. **A declaration is not a saving if
  every new model needs a new field in it.** The probe is to write the declaration for the simplest
  existing strategy — which has an empty parameter list — and then for one that is genuinely
  different in shape, and ask whether the second needed the primitive to grow. If it did, §7 has
  described this model in a general vocabulary rather than found a general object.
- **The seven do not compose into a gradient without a model writing anything else.** Each entry in
  §7 is specified against the site it was read off, and nothing here has assembled all seven end to
  end. The residue — whatever a model still has to write once every primitive exists — is the real
  measure of this report, and it is currently unmeasured.
