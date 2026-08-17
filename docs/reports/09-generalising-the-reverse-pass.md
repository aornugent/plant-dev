# Generalising the reverse pass: one recording per stage

The stand-scale reverse mode is correct on the birth-date coordinate, and it is now **one recording
per Runge-Kutta stage**. Everything between the state and the rates -- the shared field and both its
reductions, the inflow condition, every unit's physiology, the downstream aggregation and the
environment it feeds -- is an intermediate of that recording, and the transpose is one
vector-Jacobian product against the rate adjoints.

**This report is why that is the only sensible answer, and what it leaves a model to write.** The
design it replaced hand-wrote six transposes, and the argument against them is not that they were
long. It is that they could not be checked: a hand transpose is a claim about a forward function
written somewhere else, and nothing holds the two together.

Reports 00 to 08 state what the derivatives are and what a correct implementation must satisfy. They
are written from the model's side. **This one is written from the solver's**, and the discipline is
explicit: §1, §4 and §5 use no ecological vocabulary at all. No cohort, plant, light, soil, seed,
species, census, trait. Where a property cannot be stated without one of those words, that is
recorded as a finding rather than worked around — because it marks exactly where a solver-level
primitive would under-determine the model.

## The argument, in six steps

Each follows from the one before, and the third is a fact about the model rather than a choice.

1. **The model is an ensemble ODE.** The state is a list of units plus a shared part; units are
   independent given the shared part; reductions build the shared part from the units; each unit
   reads it through a contraction of small fixed width (§1).

2. **So a transpose is three kinds of work** — per unit, the reductions, and the inflow boundary
   where the list grows. The design that preceded this one wrote all three by hand and kept them
   consistent by ordering: each had to be linearised at the evaluation its own forward pass saw.

3. **But the inflow condition is evaluated *in* the shared part.** It is a whole physiology at the
   seed's size and it reads the field, so transposing it *requires* recording the field's build —
   and that recording was already being taken, once per stage, with every row but three discarded.

4. **Given the shared part is on a tape anyway, a hand-written reduction transpose is a second copy
   of rows already present.** Registering the field's knots as outputs of that recording delivers
   them in the same recording and the same sweep, because a reverse sweep is linear in its seed.
   Measured: the block Jacobian's worst cell is unchanged at `3.75e-16`.

5. **Given the units read that same shared part, recording them in the same tape costs less than
   recording each separately.** A per-unit block re-registers the whole field read for every unit; a
   stage reads it once. Measured: four units record 586,708 slots where four separate blocks would
   cost four times the one-unit 212,312 — 1.45× less, and the margin grows with the unit count
   because only the per-unit part of the recording scales. (Re-measured on the current tree; the
   figures were 586,260 and 212,088 two commits earlier, which is the same claim to three digits.)

6. **Therefore the whole stage is one recording.** Not as an economy — it is marginally faster, 13.1
   forward runs against 13.6 — but because at that point there is nothing left for a hand transpose
   to be a transpose *of* that the tape is not already carrying.

**What this costs is a commitment, and it was made deliberately.** Report 01 asks for peak memory
flat in the unit count, and that flatness was bought by writing every transpose between the state and
the rates by hand. Peak now holds the stage: linear in the unit count, 10.4 MiB at production width.
The rung that asserted flatness asserts the amortisation instead.

**The corollary is the part worth carrying to the next model.** A tape carries whatever the forward
reads, including a parameter nobody has registered yet. So the size-space carrier report 07 calls a
waist — a struct of named slots where each new parameter meant a new field and two more hand
partials — is not widened. It stops existing.

**§14 states where this ended up and what is left.** The entries in §7, §8 and §10 record which
parts of their claims survived contact and which were wrong; that record is kept, because the size
of a movement is what says whether a claim was structural. No step of it changed a number — the
gradient is bit-identical throughout, at 504 passing on the ladder.

**Every checkable claim below has since been read back against the code, and the report was losing
to the tree.** Most of what it proposes had been built while it went on describing the proposal:
§7's "what an author writes today" column is a before-picture, §8's delete-list is discharged but
for one row, §11's cost table names five components that no longer exist, and §2's most quotable
sentence — that the solver gained seven lines of header — understated the gain by two orders. Those
are corrected in place, with the old figure kept beside the new one wherever the movement is the
lesson. **A design report that is not re-read against the code becomes a description of a tree
nobody has, and the failure is quiet**, which is the same failure this report is about one level
up.

The reading is of `plant` on `ad/reverse-pass-simplify` and `odelia` on `ad/quadrature-primitive`,
which build at `-O2` and run. Every figure here is measured on that tree. Where an earlier reading of
this report is corrected the old figure is kept beside the new one, because the size of the movement
is what says whether a claim was structural or incidental — and because §12 is an audit of what this
corpus got wrong, which is not a section that may quietly improve its own record.

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

## 2. Where the lines were

| bucket | lines | where |
|---|---|---|
| general, already in odelia | ~480 | `step_adjoint`, `solve_adjoint`, `vector_jacobian_product`, the concepts |
| general, stranded in `plant` | ~325 | trajectory store, narrowing, widening, the segment loop, the growth-map VJP |
| **model-shaped — the target** | **~1,225** | the six interiors, the reduction transposes, the block interface, the functional seeds |
| genuinely model-specific | ~128 | the retention derivative, the seed geometry, the coordinate branch |

That was the reading this report was written from, and the middle row is the one it was aimed at.

**Measured after: `plant` sheds −2,080 lines against +661, across twelve files.** `patch.h` goes
2,407 → 1,455 and `species.h` 1,419 → 1,180; `species.h`, `tf24_environment.h` and `node.h` carry
no adjoint code at all. The three functions this section named as a quarter of the bulk —
`cohort_block_adjoint`, `boundary_condition_adjoint`, and the light reduction's transpose — are all
gone, together with the soil cascade, the offspring rate, the uptake trapezium, the environment's
rate transpose, and the carriers between them.

*(An earlier reading gave −1,576 against +246 over thirteen files, with intermediate per-file
figures. Neither the totals nor the endpoints reproduce against any base; they were taken
mid-flight and are corrected here rather than carried. The direction and the order of magnitude
were right, which is the part the argument used.)*

**`odelia` went the other way, and the size of it was under-reported by two orders.** This section
first put its shipped headers at −140 against +133 — *"a thousand-line deletion in the model cost
the solver seven lines of header"* — which was the most quotable sentence in the report and is
false. Measured across the whole branch, odelia's `inst/include` is **+994 against −329, net
+665**: a 341-line `adjoint.hpp` that did not exist, the batched stepper, the segment walk and its
partition assert, against a 70-line file retired. Its tests are +528 against −256.

**The exchange is still strongly in the model's favour and that is the claim worth keeping** —
plant sheds far more than odelia gains, and the shed lines are the ones that could drift while the
gained ones are checked in one place. But it is a transfer at roughly two lines out for one in, not
a thousand for seven, and the difference matters because the original number invited the reading
that a solver primitive is nearly free. It is not. It is cheaper than the drift, which is a
different argument and the true one.

**The bucket that did not move is the one worth looking at.** The graft is 412 lines in the strategy,
and only its last twenty moved: the *construction* is now odelia's, but the partials fed to it are
model-specific and stay. It is *inside* the recorded stage, so the tape consumes it rather than
replacing it. That is the honest shape of the result — a tape removes every transpose whose forward it
can record, and none of the boundary where a solver's answer is put onto the tape by hand. **The
model-specific row was ~128 lines and is really ~430**, because the graft belongs in it.

---

## 3. Two idioms, and only one of them could drift

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

**And the transpose inherited the staging.** Because the closing element is read at two different
points — one consumer sees the `R0` evaluation, another the `R` one — each read point needed its own
accumulator, and the carrier held two density slots for one quantity so that one accumulator could
not transpose one derivative through the other's argument. **That carrier no longer exists**: the
stage recording holds the ordering itself, because it records the two evaluations in the order they
happen. What survives is the fact underneath it — the two values differ by more than `1e-6` relative,
and a test still asserts they do.

> **The general rule: when a fixed point is resolved by staging, the number of accumulator slots a
> quantity needs equals the number of stages it is read at.** Nothing in the type system counts them.

**The forward model now makes that distinction, and it did not when this was first written.** The
staging above is three named functions rather than a sequence a reader has to reconstruct: one
builds the field with the closing interval omitted *and keeps each species' partial reduction*, one
places the closing element in it, and one rebuilds the field closing from what the first kept. The
kept partial is the object the middle step needs, and holding it is what makes the third step a
close rather than a re-derivation.

So the sharpest form of this section's old claim is withdrawn, and then withdrawn a second time. It
said the reverse side was forced to name apart a distinction the forward model does not represent,
and that this asymmetry was the whole reason the boundary transpose cost its lines. The forward
model represents it now. The first re-reading kept the accumulator count as the load-bearing
residue — two slots for one quantity, uncounted by any type. **That is gone too, and by the route
this report argues for**: a tape does not need to be told how many read points a quantity has,
because it records each read where it happens. The rule in the box below is still true of any
hand-written transpose. It is no longer true of anything in this tree, which is the point.

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

That concept is named throughout §5 and §6 as the thing the design argues against. It no longer
exists in the tree — §14.2 records what happened to it — and it is kept here because the argument is
about what it asked for.

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
classification becomes structural** — a consumer cannot fail to consult it. ~~which is the defect
that currently applies the interior formula at pins.~~ That defect does not occur: §5.5 records
that the submodel supplying these rows refuses at a non-interior point before any consumer reaches
the formula. What the primitive changes is not the outcome but where the guarantee lives — today it
rests on one dependency choosing to check, and a second consumer would not inherit it.

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
| ~~interior formula at a pinned point~~ | **already an abort**, one layer up — see below | — |
| segment list does not cover the recording | **abort** — coverage assert, enabled by a declared event | promotion |
| a hook loses its *caller* | **compile error** at the point of use — but a concept asserts a *type* | half |
| a rebind drops a subclass's state | **compile error** | invention |
| amplification through a near-fold | **abort** on `\|s\|/\|R_p\|`, objective row emitted regardless | invention |
| an undefined metric | **abort** — the return type carries validity | invention |
| ~~weight-derivative on a passive grid~~ | **struck** — already true today, bought by a return type | — |
| ~~a position used as a value~~ | **struck** — the named failure does not occur; the converse does, and must stay legal | — |
| state carried between units | **downgraded to a harness fixture**, not an abort | — |

**Why the pinned-point row is struck, and what checking it cost.** The rows this report's model records
are interior-optimum formulae: two trait rows are exactly zero by complementary slackness, and the
factorisation divides by a curvature that only exists at a stationary point. The strategy assumes all
of that and never asks — so this row read as a live silent-zero. It is not, because the submodel that
supplies the environment rows refuses first: it reads the operating point's *kind*, which its solve
records by the branch it took, and declines with *"the environment rows are an envelope step, which
needs an interior optimum"*. **Measured by walking two directions out of the fixtures' regime — soil
water from 0.40 down to 0.002, and leaf temperature from 25 to 50 — the refusal fires in both, at 0.1
and at 45 respectively, and the interior formula is never reached.** A guard added in the strategy on
top of that is a second copy of a check that already holds, so it was written, measured, and removed.

Two things survive it. The row was right that a residual test cannot do this job — an infeasible
point and a stationary one return the same number — and the mechanism that does work is the one the
row named: classification by the branch taken. And the check lives in the *submodel*, which is where
the classification is, not in the primitive this report proposes. That is the seam holding correctly,
and it is worth recording that the corpus found the row before it found the code discharging it.

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

**And rung B was already written, in odelia**, as the `else` of a branch on whether the System
carried its own transpose: lift to the active scalar, make one tape, and per stage record the
System's own `derivs` — which for this model *is* the state-and-field rebuild followed by the rates.
That is rung B verbatim. The model took the other branch, so it never ran on anything but a toy;
§14 is what happened when the branch was made to carry both and the model was routed through it.

**~~Deleting `ode_rates_adjoint` routes it into code that already exists.~~ Tried, and it does not.**
The sentence was the strongest claim in this report and it is false in four ways, each of which was
read off the branch rather than argued:

- **There is no parameter channel.** The branch registers the stage state as its only tape inputs and
  reads back only state adjoints. The twin is constructed *before* the tape, so every parameter in it
  is born without a slot and stays a constant for the recording. plant's entire gradient is a *trait*
  gradient; routed here, all 47 columns come back absent.
- **It has to record once and sweep per seed.** A branch that records per metric gives back the
  economy §5.3 and §6 both credit — three metrics becoming three recordings of the same stage. The
  branch has to reach the same record-once-sweep-many product the model's own transpose uses, which
  is also what supplies the parameter rows the bullet above is about.
- **It costs more, not less.** The branch *retakes the whole step* in double and then records six
  active evaluations: thirteen model evaluations per step, against six plus six hand transposes.
- **It is barely exercised.** One step of a three-state toy, never through the segment sweep, never
  batched, never with a parameter.

**Two of those four have since been discharged, which is what "tried, and it does not" was worth.**
The branch has a parameter channel — the accumulator is threaded through the stepper into the
product — and it reaches record-once-sweep-many rather than recording per metric. Those were the
two that made the objection structural rather than incidental, and closing them is most of what
§14 records. The remaining two were always the weaker pair: whether it costs more is now the
question §11 can no longer answer, and "barely exercised" was a statement about the suite, which
has changed.

**And the premise underneath was wrong, which is the more useful finding.** This report reads plant
as hand-writing its interiors. It is not: `cohort_block_adjoint` *is* odelia's own
`vector_jacobian_products`, at cohort granularity. **plant is already on a taped design** — what it
hand-writes is the two reductions, the environment cascade and the light/allometry scatter, about
440 lines, which is §3's number and not §2's 1,225. The gap between rung A and rung D is real; the
claim that one end of it is already built is not.

**One rung-B-adjacent economy landed before any of this, and it is the first noun in §7 to arrive.**
A block was recorded once and swept once per metric, where the loop it replaced recorded it once per
metric. **The economy report 05 §9.1 describes is therefore real rather than proposed** — but it
arrived by adding a dimension to the existing hand-written interiors rather than by taping a stage,
which is the counterfactual this report is arguing against: the same saving was available by
declaring the structure once, and was instead bought by widening three transposes and threading a
metric index through them. Both concepts it was carried on are gone (§14.2), and so are the two gaps
it had — it seeded state adjoints only, so parameters had to be registered as extra tape inputs
(§7's missing noun), and it shared one tape across six stages without releasing the slot array, at
~1.8× one stage's peak.

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

**Read the second column as "before", not as "today".** It was written against the tree this report
opened on, and five of its seven rows have since been discharged — the paragraphs after the table
say which and how. Two rows are wrong even as history: the parameter accumulator is described as a
mutable System member with six writers, which the text below the table correctly says is gone; and
refusal is described as not existing in C++ at all, which was never true of the dependency that
supplies the leaf's rows (see §14.5 item 2).

| primitive | what an author writes today | what they would write | how a mistake surfaces |
|---|---|---|---|
| **parameter adjoint** | a mutable System member, **six** writers, four defensive re-zero guards; since the batching a vector of them indexed by metric, so the out-of-band channel grew a dimension rather than acquiring a route | the state, the seeds and where to accumulate | a **length mismatch**, where before it was a fixed fraction of the right answer with the correct sign |
| **graft** | `v + Σ ∂v/∂uᵢ·(uᵢ − passive(uᵢ))`, written **four** times, only one copy carrying the finiteness guard report 05 §8 says it needs | the partials and the inputs | **abort** inside the graft on a non-finite partial, once, for every site |
| **reduction** | a forward walk and a hand-mirrored transpose, five times, held together by a comment | position, contribution, kernel, stage | a transpose cannot drift from its forward because there is one function |
| **seed** | `∂C/∂y` at `T`, model-side | the functional | — (already taped; it is here because it is the one the reduction primitive must also cover, §13) |
| **growth event** | insertion, map, narrowing, widening, replay, and a segment list **inferred from width diffs** | `apply`, `undo`, and the map | **abort** on a segment list that does not partition the recording — which is §10's live defect |
| **refusal** | nothing; it **does not exist in C++ at all** | which points are answerable | an undefined metric is a distinct value in the return type, not a plausible number |
| **opaque node** (§5.4) | ~200 lines forming `∂p*/∂u` explicitly per input family, plus four parallel trait arrays keyed by position to a fourteen-argument setter | the residual, the bounds, which output *is* `p` | the classification is the primitive's, so the interior formula **cannot** be applied at a pin |

**Building them corrected the count in the second row.** The graft was said to be written four
times. It is written three, and the third is not the same
construction: `hermite_interpolator::graft` carries a slope the tape computed, where the other two
carry a number supplied from outside it. That distinction is the whole of why the finiteness guard
exists — a supplied partial can be `NaN` while the model is healthy, and `NaN × 0` then poisons the
*value* — so folding the interpolant in would have put a guard on the hottest read in the model to
catch a condition that cannot arise there. The fourth was `supplied_derivative.hpp`, which was not a
copy but a rival mechanism, and is retired rather than unified: the graft does its job in arithmetic
at any scalar, where it needed a tape slot and an XAD checkpoint callback.

The parameter adjoint is fully in band: the accumulator is the caller's, handed to the primitive as
a destination, and the System member it used to live on is gone. A row that does not match the seeds
is now a length mismatch where it used to be a fixed fraction of the right answer.

**And the list is incomplete in a way worth naming here rather than at the end.** Every entry is a
piece of derivative *calculus*. None of them is the *machinery* a model writes around that calculus
— the recording, the seeding, the sweep, the twin, the tape, the traversal — which turned out to be
the larger half and to reduce to a single member. §14 states what followed from it.

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

**Half of this was built, and then deleted, and the deletion is the finding.**
`odelia::quadrature::trapezium_weights` took the grid through a callable returning `double` — so a
width could not carry a derivative however the caller stored its grid, which is passivity by type
rather than by discipline — and owned the stopping rule and the closing interval. Both of plant's
reduction transposes walked it. **Both transposes were deleted eight hours later** by the stage
recording, which transposes the reduction along with everything else it reads, and the primitive
went with them as a concept with nothing behind it. What it measured stands, and is the constraint
the design did not have:

> **A per-slot weight vector cannot serve the forward.** `Σ wₖ fₖ` and `(Σ widthᵢ(f_lo + f_hi))/2` are
> the same map with a different association, and the forward's association is asserted **bit-exactly**
> — the fused value-and-slope reduction against the plain value reduction, over 200 heights and seven
> crown shapes, with a control pinning the patch-level order too. So the primitive has to be
> **interval-major**, and a caller keeps its own accumulator. It is, which is why the transposes could
> take it; the forward needs a summing entry point on the same walk, and a re-blessing budget.

**The counts in §8 were wrong, and re-counting them a second time reversed the conclusion.** The
first re-count said the walk was *more* duplicated than §8 claimed: two hand-written trapezium
transposes rather than five, but a half-factor in **six spellings across eight lines**, an early exit
written **four** times and a closing predicate **five**, so that migrating the forward sites would
remove about **288 lines of walk code out of 505**.

**Counted against the tree as it now stands, that duplication is largely gone and was not removed by
this work.** Inside the competition walks there are **two** trapezium walks, not four — the
value-only path is a one-line delegation to the fused pair's first entry — **one** spelling of the
half factor, **one** in-loop early exit, and **two** closing predicates, which differ by one clause
and legitimately so. What is left is not a primitive's worth of duplication, and §14.5 records the
item as withdrawn rather than pending.

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
functions stayed defined, stayed compiling, and were called by nothing, so the container they fill
stayed empty forever and the one feature built on it — replaying a completed run's environment
against a different parameter set — threw on its first statement, for every model, always.

**It stayed dead for four months, and the suite's silence moved rather than broke.** The suite does
report it, as two failures; `AGENTS.md` lists them among six "known failures that predate the
gradient work" and tells every reader they are not a signal. They are precisely a signal, and the
attribution was wrong. Anything can be made quiet by being written down as expected.

**The hooks are now deleted rather than reconnected** (§14.5), which is the only reading under which
this section's rule holds: a hook nothing calls is not a contract, and the honest response to
finding one is to remove it or to make its absence a compile error — never to leave it standing on
the strength of the feature it was once for.

Two things follow that bear directly on §6's proposal.

**A missing hook must be a compile error, not a silent default.** Every noun added to
`ode_interface.hpp` widens this surface. The existing concepts already show the shape: one of them is
four hooks where the real consumer needs one, satisfied with three empty bodies — a model opting into
a contract it does not mean, and no way to say so.

**And the deleted half is not the half anyone guards.** The recording protocol carries a
`static_assert` that the concept is satisfied; the caching protocol carried nothing, and the caching
protocol is the one that broke. A concept asserts that a *type* is adequate. What went missing was a
*call*.

**It happened again during this work, one level down, and the mechanism is worth recording because it
is not a concept at all.** The two packages must agree on two XAD build flags — one sets the storage
class of the variable XAD reaches its active tape through, and the storage class does not change the
mangled name. Matching the defining side to the reading side is correct and was done. But odelia's
own tests compile their probes standalone, each restating its own compile flags, and **not one of the
seventeen sites carried either define**. Sixteen of odelia's tests stopped building that hour. The
suite reported them as errors and nobody was reading it, because seven more of its probes had been
dead far longer for a plainer reason: they never asked for the language standard their own includes
require, so every `concept` in them read as a syntax error. **odelia's AD tests — including the one
refereeing `vector_jacobian_product`, which the whole stage recording rests on — were 142 passing
assertions out of 369.** They are 369 now, and 384 with the new primitive's own.

**And running them turned up something none of them was written to find.** With the suite whole, the
leaf-thermal AD example takes a `memory not mapped` fault inside `LeafSolver_value_and_gradient` —
**once in five full runs**, and never in three runs of that file alone. It is nothing this work
touched and it is not in the reverse pass; it was invisible because those tests had not built. It is
recorded rather than fixed because a rare memory fault in an example's solver is its own piece of
work — and because a fault that needs the whole suite to appear is one more thing that only an
instrument nobody was reading could have been hiding.

The shape is the same as the caching hooks and the same as the four hand-walks of the parameter
order: **a rule restated at every site drifts at every site, and the instrument that would say so is
itself a site.** A primitive set that adds nouns to `ode_interface.hpp` without noticing that its own
referees are compiled seventeen different ways is building on an instrument it has not checked.

---

## 8. What gets deleted

Great abstractions are measured in concepts removed.

| delete | why |
|---|---|
| `supplied_derivative.hpp` | **zero production consumers** anywhere. The construction the model needs is the other one |
| three of four grafts — **and it was two of three** | one idea, three spellings, one of which turned out to be a different idea (§7). Only the model's copy had the finiteness guard report 05 §8 says the construction *needs*, and that copy is now the only one |
| six copies of "seed parameters before state" | one primitive, which writes the parameters itself so a caller cannot write the state first |
| the four parallel trait arrays — three booleans are one | one of the three was true at every entry and decided nothing. The values and addresses still key by position to a **fourteen**-argument setter, which is phylloptim's signature and not plant's to change |
| `node_size_adjoints`, `node_uptake_adjoints` | structs of **named** slots. One parameter got a row by *adding a field*; each further one wants another field plus two hand-written partials |
| `light_reduction_slots` | the right idea named for one reduction |
| four competition walks | value / value-and-slope × ordered / unordered — one walk with a codomain parameter |
| five trapezium transposes | one driver, four integrands |
| six copies of the unit×(elements+1) walk | an iterator yielding `(slot, optional<state_row>, parameter_base, element&)` |
| `gradient::Status` | four values derived **from residual magnitude**, which report 05 §7.0 forbids. The correct ten-branch decision tree sits beside it, unused by the gradient entry point |
| the five explicit `∂p*/∂u` vectors | see below |
| `narrow_over_introductions`, `widen_over_introductions`, `narrow_to_segment`, the segment loop | odelia's, once growth is a declared event |

**This table is now a list of things that happened, with one exception.** Checked against the tree,
every row above has been discharged: the retired file, the grafts, the seeding order, the trait
array (which is one array of structs carrying one boolean, not four arrays carrying three), both
named-slot carriers, the reduction transposes, the walk copies, and the narrow/widen/segment trio,
which are odelia's. **The exception is the classification enum**, which still derives four values
from residual magnitude in the way report 05 §7.0 forbids, and still sits beside the correct
decision tree unused by the gradient entry point. It is the only surviving deletion target here,
and it belongs with the opaque node (§14.5 item 1) rather than on its own.

**The last two rows were the strongest evidence the primitives were missing, and they are the two
that moved furthest.** The claim was that the model never uses the rank-one collapse — that it
forms `∂p*/∂u` explicitly for every input family, ~200 lines of precisely the outputs-by-parameters
matrix report 02 §3.2 says is never formed. **It uses the collapse now**, through a primitive that
takes the theorem's quotient once rather than once per layer per input, and the explicit vectors are
gone. What the row got right was the diagnosis: the node's output set had been enumerated from what
the solver exposed rather than from the consumer's equations, which is report 02 §3.0's warning
realised exactly, and undetectable, because an absent output has no column.

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

**2. ~~The upstream reduction has no isolated referee.~~ This fence is down, and it did not move.**
The probe it named was deleted together with the transpose it refereed, in the commit that replaced
that transpose with the stage recording — so there is no isolated reduction transpose left to
referee. What checks the reduction now is *stronger* than what the fence asked for: the composed
right-hand side is no longer checked by a contraction but entry by entry over the whole state
Jacobian, and a cancelling pair of errors — the fence's actual worry — cannot pass that.

The fence is kept for the same reason fence 1 is: it gated refactoring the reduction, and the
refactor removed the thing rather than the check.

**3. One factorisation coefficient is unchecked in the direction that decides the answer.** Report
05 §7.3 says the soil potentials' sensitivity pairs are collinear to about one part in 10⁴, so a
compensating pair of coefficients fits every one of them; report 08 **§4.1** prices the consequence at
fifteen- to twenty-six-fold along the uniform-drying direction, and it sits in the sweep **and** in
its reference. (Both this report and §12 cited §3.1, which is a different section.)

**The fence stands, and checking it moved it.** Two of its clauses turned out stale and the third
turned out to be the whole of it:

- *The residual runs over the potential family only* — still true, and the reason matters more than
  it did. The pair is no longer fitted from a potential; it is anchored in root carbon. So **no
  potential layer is in sample**, and the check's exemption of one of them — carried over from when
  the anchor was a potential — was excusing the layer that most needed checking.
- *The pair cannot be separated by a residual on the fitted family* — no longer the mechanism here,
  because the anchor is outside the potentials' span. The **anchoring family is now checked**, at
  7.1e-08 against the fit step's own 1e-05, which is the premise every predicted layer rests on and
  was untested.
- *The direction that decides the answer* — **this is the fence.** No check formed it. One does now,
  by perturbing along the direction rather than summing per-column differences, because a direction
  whose answer is a cancellation among its columns cannot be had from the columns.

**And measuring it produced two numbers this report did not have.** Per layer against its *own*
reference rather than a pooled one, the factorisation's residual is **20.9, 18.9, 17.5, 0.5, 1.4**
times the difference's error — which is one error, not five: the difference matrix is rank one, so
every layer is wrong by the same relative amount and that spread is one scalar seen through a
normaliser that divides by the block's largest entry rather than the column's. The previous bound
held by pooling a floor across layers that differ by three orders in convergence and by excusing one
of them. It is now bounded two ways, on the structure and on the size, at the fit's own truncation.

**The uniform-drying direction is reached by the root network's hydraulics, and by nothing a
trajectory develops.** The amplification is **1.1× on both patch fixtures** at the shipped traits —
and, measured at every node of every run stand, between 1.03 and 1.14, the competing stand included
at 1.143. Competition, shade, drought, cohort count, species count and run length each move it by
under a tenth. What moves it is the collar's tracking of a uniform soil shift, which is set by the
share of the hydraulic path lying between soil and collar: root conductance, and root mass spread
over the column rather than concentrated at the surface. At sixty times the root conductance and the
same root carbon, a one-cohort patch measures **16.3×** in a quarter of a second.

**So the attribution to a competing stand was this report's own, and it was wrong.** Report 05 §7.3
asserts fifteen to twenty-six with no measurement and no fixture behind it; its one "competing
stand" is a different table, about the pair's transfer to the root-carbon rows. A stand cannot reach
this regime, and a stand run with the traits that do reach it ends at 1.00× because the root carbon
that buys the conductance is a mass constant and the plant cannot grow.

**4. The transposes themselves are fixed.** All four coordinate conditions hold on the supported
coordinate. **This fence is down**, which is why generalisation is the next move rather than a
competing one.

### And one live defect — ***now fixed***

**The first segment was never swept.** It is swept as of this reading, and the fix is described at
the end of this section; what follows is the defect as it stood, kept because the shape of it is the
argument for the growth primitive. The sweep loop descended over the event boundaries and covered
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
nothing raised. **The structural point is that the segment list is inferred and never checked for
coverage** — no code asserts the ranges partition the recording — and that assertion is one of the
obligations a growth primitive would own.

**The fix was not a guard but a shape.** The sweep now runs the same decomposition the tangent runs:
one segment per width, so there is one more segment than there are widenings and the lowest runs down
to the initial state. Written that way, the second hole closes with the first — an empty boundary list
used to make the loop a no-op that returned the direct term alone, and now sweeps the whole
trajectory, because "no widenings" is one segment rather than none. A widening at the very first
recorded step leaves that lowest segment with no step in it, which is exactly what a run from bare
ground gives, so **every existing fixture was bit-identical and no fixture could tell**. The referee
that would prove it was named here as the recruit rung's count on a fixture resuming from a populated
state; it is written, and it separates the two walks by three counts — swept ranges, boundary
evaluations, and the adjoint the walk ends holding, which matches a forward tangent from the same
state to `1.11e-10` where the old walk would have read `0.878`.

## 11. Costs and gaps the design does not price

**~~Measured, and it is the sweep.~~ This section's cost table no longer describes anything, and it
is withdrawn rather than corrected.** It read:

| | share |
|---|---|
| boundary condition | **62.9%** |
| unit blocks | 32.7% |
| the shared-part build | 1.5% |
| the boundary nodes | 1.3% |
| **both reduction transposes and the environment cascade** | **1.1%** |

**Every row names an object that has since been deleted.** There is no boundary transpose taking a
whole-ensemble tape, no per-unit block, no reduction transpose and no environment cascade: the
stage recording replaced all five with one recording of `derivs`, swept once per seed. The
instrument went with them — the timing harness that produced these eight entries now returns four
keys, and its own source says why: *there are no components left to attribute between.*

**So the table cannot be re-measured, only re-derived, and nothing here has done that.** Two
inferences drawn from it elsewhere in this report fall with it: that the reductions were "the wrong
1.1%" to argue about, and that narrowing the recorded field would "take most of the 62.9%". Both
may still be true. Neither is now evidenced, and a share quoted from a profile of deleted code is
worse than no number, because it reads as measurement.

**What the section is still good for is the shape of the question.** The costs below it are read
off source rather than off a profile, and those that name surviving code are checkable; each is
marked where it is not. A fresh profile is its own piece of work, and the procedure for taking one
— counts times prices, never a profiler's own attribution — is in the cost document rather than
here.

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

**~~`ȳ(0)` is computed and discarded~~ — it is kept, exported and refereed** against a forward
tangent from the same state, which is the first-segment referee §10 describes. What survives of the
original claim is narrower and still true: it is not folded into the returned gradient, which sums
the trait adjoint and the direct term only — report 05 §10's sixth path, zero-valued here because the first
recorded state reads no parameter, live for any model whose initial state does.

**The supplied rows are ~~~36~~ about 18 to 20 re-solves of the opaque node ~~per block~~ per
boundary evaluation.** The count halved when the leaf stopped differencing all fourteen traits and
drove only the four that need it; "per block" named a decomposition that no longer exists. Five families are
finite-differenced, and one of them rebuilds a tabulation each time. Against one evaluation for the
forward pass, per unit per stage per sweep. The differencing is deliberate and each step size is
reasoned; what is unpriced is the total.

**~~Each block copies the whole model object~~ — struck.** There is no per-unit block on the
reverse path to do the copying; the stage recording replaced it. The copy that remains is a
synthetic timing probe with no caller in the suite or the R surface, and it measures nothing in
production.

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
log density* — is written out at ~~four~~ two places, one of which is now a named function carrying
the reason in a comment; the other two sites were in the deleted block transposes. **The block interface already subsumes two of these**; declaring
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
ladder run, not the source read; the ladder has since been run and the factorisation half is
settled below.

**The top-ranked correctness item is already done.** Report 07 §7 ranks "give the size-space adjoint
its trait slot" first and calls it a correctness matter — rows that do not arrive at all. They arrive:
the carrier grew a fourth field, three of the four reduction-borne parameters now have rows, and the
shortfall report 06 §11 quotes as 3.041 percent is measured at 3.3e-02. Read as a work order today it
spends the budget on a closed row.

**The one it displaces is mis-scoped in both directions.** Report 08 **§10** specifies the
factorisation check as *"one state, no gradient run, no stand"* (§4.1 is where the pricing is; this
report cited §3.1 for both, which is neither), and the branch's own revert records that the failure
was **invisible** on exactly that fixture — no competition means no unit sits far from where the pair
was fitted. The coefficient it asks to check against a closed form *is* the closed form now, so that
half is vacuous; and the shipped test measures only the family the report itself says cannot detect
the error.

**Measured, and the scoping objection turned out to point the wrong way.** The amplification that
makes the direction matter is **1.1× on both patch fixtures** — but also 1.03 to 1.14 at every node
of every run stand, so a stand does not supply the regime either. It is set by the root network's
hydraulics, which a patch can be given directly: at sixty times the root conductance and the same
root carbon, **16.3×**. The fence is patch-tier work costing a quarter of a second, not
trajectory-tier work costing a sweep.

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
reasoning offered here was that the leaf boundary *"still differences fourteen traits at two
evaluations each, exactly as before, so the saving is not there"* — **and that premise is now
false**: it differences four. The other ten are read in closed form, which is a real saving in
exactly the place this paragraph ruled out. Whether it is *the* saving is still unestablished, and
the honest position is unchanged: what is measured is the effect.

Two things survive intact. **Nothing in the ladder measures time**, so this figure is nobody's
regression test and the next change to the leaf can move it by another order with no failure
anywhere. And the flatness guarantees the design rests on are about memory and target count, which
are checked. What is withdrawn is the conclusion drawn from the constant: **this is no longer an
argument for measurement before design, because the measurement has been taken and it does not
oppose the design.**

---

## 13. What would falsify this

Checked against the tree. Three are answered, one is moot, and the three that remain open are the
ones about a *second* model — which is the shape of the whole risk here, and §14.6 says why.

- **~~A stage recording does not fit.~~ Answered: it fits.** The number is measured and returned
  beside the gradient. This was rung B's only load-bearing unknown.
- **~~The reduction primitive does not cover the functional.~~ Moot.** There is no reduction
  primitive: the transposes it would have served were deleted and the quadrature helper went with
  them (§7.1).
- **`Patch` cannot be made generic over its environment. Half answered, and the remaining half is
  not the environment.** The reverse half no longer lives in `Patch` at all, and the block interface
  the sweep needs is published by the base environment with defaults that the other two models
  inherit unchanged — so it *would* instantiate. What blocks a second model is the strategy: only
  one declares which of its scalars are parameters, and only one declares a rebind. The precondition
  for §6 is discharged on the side this bullet named and live on the side it did not.
- **The interiors are not model-shaped.** Still open, and the probe as written cannot be run — it
  named a member that no longer exists. The equivalent question is what the simplest strategy's
  parameter declaration would have to be.
- **~~The closing element cannot be split into three.~~ Still open, and no longer costly.** The
  fused object survives, but the two-slot accumulator that made the fusion expensive does not
  (§4.1), so this now falsifies a claim about tidiness rather than about correctness.
- **The declaration is not shorter than what it replaces, for a model that is not this one.** The DX
  claim is ~1,520 lines of transpose against a ~31-line structural core plus a parameter list, and
  that core was counted for the model the primitives were read off. **A declaration is not a saving if
  every new model needs a new field in it.** The probe is to write the declaration for the simplest
  existing strategy — which has an empty parameter list — and then for one that is genuinely
  different in shape, and ask whether the second needed the primitive to grow. If it did, §7 has
  described this model in a general vocabulary rather than found a general object.
- **The seven do not compose into a gradient without a model writing anything else. Answered, and
  the answer is worse than §14 first claimed.** The residue has been assembled and measured: it is
  seven members, not five, and one of them — `set_recorded_state` — is an adjoint-specific loader
  named by no concept, in a section that claimed no such thing exists (§14.1). The residue is the
  real measure of this report, and it is now measured rather than asserted.

---

## 14. Where this ended up, and what is left

§7 asks which primitives the solver is missing. Answered against the code, the question changed
shape twice: most of the pieces were already there, and the largest one was not on the list at all.
This section states the arrangement that resulted and gives the remaining work as instructions.

### 14.1 The arrangement, stated once

**The solver owns the reverse pass entire.** The tape, one for a walk. The twin, one for a
segment, re-seated before every recording because freshness is per recording and there are six a
step. The Runge-Kutta adjoint recursion, written once, batched, with the single-seed form an
adapter over it at one seed. The record-once-sweep-many product, with the parameter channel in
band. The stage recording itself, through the same rate call the forward pass uses — which is also
the one place a replay pass diverges from a resident one. The segment walk across widenings, with
its partition assertion and its narrow-widen round trip.

**A model declares ~~five~~ seven things, and six of them it already had.** How to rebind itself at
another scalar. How to seat an existing twin from itself. Which of its scalars are parameters. How
to compute rates. And **three** loaders, not one: `set_ode_state`, `set_ode_state_and_field`, and
`set_recorded_state`. Only the seat is new, and it is the value half of the rebind.

**The count was checked and it was wrong, and the way it was wrong is the interesting part.** This
section first claimed five, and said in the next breath that a model writes *no adjoint-specific
loader*. Both cannot hold: `set_recorded_state` exists **because** re-loading a state the ordinary
way linearises a boundary node the trajectory never carried, which is a reverse-pass concern and
nothing else. It is a hard requirement of the segment walk, called at three sites in the solver,
and **no concept mentions it** — it is duck-typed, so a model that omits it fails deep inside a
template rather than at a declaration. That is §7.3's own hazard, in the section claiming the
hazard had been designed out.

**Nothing else.** No tape, no seed vectors, no recordings, no Butcher coefficients, no operating
point carried forward to reverse, no transpose. The loaders are the residue, and they are three
where the argument wanted one.

### 14.2 What it replaced, measured

| removed | |
|---|---|
| the single-seed stepper and its own copy of the stage recursion | net **−79** in the header core, 239 out against 160 in |
| the model's transpose, its adjoint loader, its tape and its four counters | model **−148**, solver **+26**, net **−122** |
| both adjoint concepts | deleted outright, not reduced — see below |
| the third and fourth spellings of "can this rebind" | 5 aliases, 2 helpers, 14 sites |

**The concepts went entirely, and that was not the prediction.** The transpose concept looked like
two obligations — *I carry my own transpose*, which the generic path absorbs, and *here is my
stage's operating point*, which looked irreducible. The second does not exist: the state loader
rebuilds the field, re-derives every dependent auxiliary and re-solves the inner problem, so the
operating point **is** a function of the state and the time. The carriage never reached the twin at
all. Deleting it leaves the gradient bit-identical, which is the proof.

It is not wrong as an idea — a model whose operating point is *not* re-derivable would need exactly
it, and would save the re-solve this one performs — but it is not load-bearing here, and a concept
that is not load-bearing is one nobody checks.

**The loader was a symptom of the transpose being in the wrong place.** A separate one existed only
because the stepper positioned the double System immediately before calling the model's own
transpose, and that is not the position the transpose is taken from. With the recording in the
solver, it positions the twin from inside the recording, through the same rate call the forward pass
uses. The double System is never positioned for the transpose at all.

**The line count is the smaller half.** The larger half is that no model owns any part of the
gradient machinery — one member, and it is the value half of a rebind it already had.

**And what is NOT in this accounting.** The opaque node is untouched by all of it. That is model
calculus rather than solver machinery, and it is where the remaining hand-written derivative lines
actually live.

### 14.3 Two things that collapse, and one that looks like it should and does not

**"Can this rebind" is asked four ways, and three are derivable.** A type alias on the model; a
wrapper that applies it; a fallback helper in the solver that keys on the same alias; and a concept
plus a type function that key instead on the rebind *factory*. The last pair is the general one —
the type is `decltype` of the factory call, with the same not-rebindable fallback — so the alias,
the wrapper and the older helper all go.

**And the older helper is not merely redundant, it is wrong here.** Every type that declares the
alias also has the factory; the patch has the factory *only*. So the helper resolves the patch's
"active twin" to the **double** patch, and the solver member named for the active twin would hold a
passive one. It does not bite today because that path is not instantiated for this model, but it is
a silent degradation of exactly the kind §7.3 is about, and collapsing the four spellings to one
closes it.

**The step recorder and the field recorder are not the same thing, and one cannot replace the
other.** They look alike — both record on the forward pass and are read on a later one — but the
payload, the granularity and the consumer all differ: the step recorder keeps the **state** at each
accepted step, for a reverse walk that needs somewhere to run from; the field recorder keeps the
**field** at each stage, for a replay that must not recompute the resident. What the field recorder
replaces is the model's *other* recorder, the per-stage environment cache that predates it.

What can move, though, is the step recorder's driver. Toggling the recording, running, harvesting
the records and attaching the step sizes is twenty lines with nothing model-specific in it, and the
record itself is a time, a step size and a state. Both belong beside the concept that dispatches
them.

**One caution on the mutant flag.** It is doing two jobs — *use the cached field* and *this is an
invader: compute no boundary node, build no field, feed nothing back*. Only the first is what the
replay hooks replace. Fifteen sites in the model test that flag; most are the second job and stay.

### 14.4 The replay concept, co-designed

Not built yet, and deliberately: residents with endogenous feedbacks are the priority and an
invasion gradient is not. What follows is the shape the resident work must not foreclose.

```
concept Replays = requires(System s, std::size_t step, int stage, const_iterator in) {
  s.replay_step(step);          // restore that step's record
  s.set_ode_state(in, stage);   // load state against a recorded stage
};
```

Two members, and three deliberate absences.

**No mode query.** Whether a pass replays is the DRIVER's, not the System's, and it is not a
property of the type either. The driver counts the steps and knows which pass it is running, so it
takes the branch itself rather than asking the System every stage. This is the difference between a
resident gradient that cannot accidentally replay and one that silently returns a gradient with the
water feedback missing -- finite, plausible, and with no error raised, which is the failure this
corpus exists to prevent.

**No time lookup.** The step is handed in. Today it is recovered by searching the record for an
exact float match, with an abort when the time does not round-trip; the driver already has the
index, and passing it deletes the search, the sequential fast path, the cursor and the abort.

**No "field" in the name.** For this model the replayed object is a derived light field AND the
soil states it was integrated from, which are ODE state. The state half is the one that matters: a
System replaying part of its state is asserting that part is exogenous on this pass -- an invader
does not move the stand it invades -- and therefore that **its adjoint through that part is zero**.
That is a modelling claim, not an optimisation, and it is why this is not a cache.

**And the payload differs by pass, which is where the saving is.** A resident integrates its soil
moisture because the stand's water balance is endogenous. An invader integrates its own hydraulics
in response to a soil moisture it does not move -- so on that pass the soil is supplied rather than
integrated, and leaves the state vector. The two passes therefore run states of different width,
which is a fact about the model and not a detail of the record.

### 14.5 What is left

Five items. Each says what to do, why, and what would show it done.

**1. The opaque node — the last hand-written derivative surface, and mostly not what it looks like.**
Measured: **≈880 lines of TF24 exist only because of AD** — 766 in the strategy against 116 in the
environment, or 31% of `tf24_strategy.h` — and **460 of them are one function**, the leaf's supplied
rows.

**Split that function by what it actually is, because the split is the surprise.** Of 422 lines of
body, only **~70 are model calculus** — the implicit-function assembly, the rank-two `(a,b)` fit and
its unit conversions. **~121 are one mechanism written five times**: perturb, re-seat, harvest,
restore, guard, for the curvature, the carbon anchor, the conductance, the four driven traits and
the radiation. **~190 are plumbing** — a flat copy of twelve rows made only to loop over them for
finiteness before they are read again field by field, and three assemblies of the same five-segment
column order. **Plumbing is the largest bucket, calculus the smallest**, which is the reverse of how
this section has described it throughout.

Three details worth carrying into the work:

- **The five differences use three step conventions** — `max(|x|,1)·1e-6`, `x·1e-3`, `x·1e-6` — and
  only two of the five record why. A primitive owning the differencing owns the convention.
- **The trait order exists in four places**: this model's table, the leaf package's own index
  enumeration, eight local integer literals, and the fourteen-argument setter whose argument list
  *is* the order. Nothing enforces agreement. **Position 12 already disagrees in name** — it is the
  stomatal slope here and the cost scale there — and that alias is written down nowhere.
- **The three output assemblies repeat one column order.** A change must be made in three places and
  nothing catches a divergence, which is report 01 §6's failure signature exactly.

It is not reached by any further work on the sweep, and no sweep-side change will shrink it.

*Do:* give the solver an implicit node — the residual, the bounds, which output *is* the implicit
quantity, and the ordinary partials — so the model declares a solve rather than its calculus, and
the primitive owns the theorem, the envelope, the classification and the graft. §5.4 states what it
owns; §9 states the interface read off what the code consumes; §9.1 states which branch to design
against, and it is not the hard one.

*Done when:* the classification cannot be bypassed by a consumer, which is the defect that lets an
interior formula be applied at a pin; and the transpose identity holds without a reference gradient.

**2. Refusal — which is built at one site, in the wrong package, and nowhere else.** §7 called this
the row with nothing built at all; that overstates it. The dependency supplying the leaf's rows
already returns validity beside its answer — a `usable` flag and a message — and already refuses an
envelope step at a non-interior point, which is the mechanism §5.5 credits with striking the
pinned-point row. So the *construction* is proven and deployed.

What is missing is that it stops there. **The gradient the machinery finally returns carries no such
channel**: an undefined metric comes back as a plausible number, and a caller cannot distinguish it
from an answer. Every other silent failure in this corpus has been closed by making the wrong thing
impossible to express; this one is still expressible, and it is the outermost one, where it matters
most.

*Do:* lift the construction the dependency already uses into the solver's own return type, so
"undefined here" survives the whole way out rather than being flattened at the first boundary it
crosses.

*Done when:* a caller cannot ignore it without saying so, and the ladder has a rung that asks for a
gradient at a state where one does not exist and is refused rather than answered.

**3. ~~The reduction's forward walks.~~ Withdrawn, for three reasons that arrived together.** The
item asked to migrate four forward competition walks onto the traversal the transposes take.

The transposes no longer exist — the stage recording deleted both. The primitive no longer exists
either: `trapezium_weights` was dropped as a concept with no caller once they went, and its own
commit records why it could never have served the forward, which is that a per-slot weight vector
re-associates a sum whose association is asserted bit for bit. And the duplication has itself
shrunk to two walks, one half-factor, one early exit and two closing predicates (§7.1), which is
not a primitive's worth.

Against that, the walks are being rewritten on another branch, which builds the field in one
descent rather than once per knot and touches every file this item would. **Two rewrites of one
traversal is the failure this report is about**, so the walks belong to that branch.

*Do:* nothing here. If a reduction transpose is ever hand-written again, it needs an interval-major
walk with the caller keeping its own accumulator, and the deleted primitive is what one looks like.

**4. The replay pass, which is now the only way an invasion run exists at all.** The model's second
recorder has been **deleted**, and what it was is worth stating precisely, because it is this
report's own §7.3 finding arriving at its conclusion.

The per-stage environment cache — the one that kept a field per Runge-Kutta stage so an invader
could integrate against a resident it does not move — was reached through three hooks the solver
stopped calling. It had **zero call sites**: `cache_ode_step`, `cache_RK45_step` and
`load_ode_step` were defined, compiled, and invoked by nothing. So the container they fill was
never filled, and `set_mutant` refused on its first statement, for every model, always. The flag
that switches an invasion run on is set on the line *after* that refusal, so it was permanently
false and the nine guards reading it were all dead branches. **The whole feature, not merely its
cache, was unreachable** — and two of the six failures `AGENTS.md` tells every reader to expect as
pre-existing are exactly this, which is where the silence had moved to once the suite started
reporting it.

What was deleted: the three hooks, the two histories and the stage cache they filled, the cursor,
the exact-float time search and its abort, the stage-indexed state loader, the `Control` knob that
gated the write side, and the nine guards. `run_mutant` survives as the entry point and refuses
with an accurate message rather than a misleading one; `test-mutant.R` keeps its expected fitnesses
and skips, because those numbers are the specification for what replaces this.

**Its replacement is `odelia::ode::ReplaysField`, which already exists** — `record_stage`,
`replay_step`, `has_recorded_field` and a stage-indexed `set_ode_state`. Plant never satisfied it:
it kept the older spellings, so the concept evaluated false and every dispatch site in the stepper
compiled to nothing. That is the whole mechanism of the failure, and it is why re-implementing
against the concept is the fix rather than resurrecting the names.

*Do:* implement `ReplaysField` on the patch, and drive it from the solver. §14.4 settles the
shape: two members, the mode owned by the driver rather than asked of the System, the step index
handed in rather than searched for, and a payload that may include state — an invader integrates
its own hydraulics against a soil moisture it does not move, so that soil is supplied rather than
integrated and leaves the state vector.

*Done when:* the concept is satisfied and a `static_assert` says so at the point of use, so the
hooks cannot go quiet a second time; `test-mutant.R` stops skipping and meets the numbers it
already carries; and the mode cannot be set by anything but the driver — a resident gradient that
replays returns one with the water feedback missing, finite and plausible and unraised.

**5. Name the three loaders, because one of them is the residue this report went looking for.** A
model supplies `set_ode_state`, `set_ode_state_and_field` and `set_recorded_state`. Only the first
is mentioned by any concept; the other two are called directly by the segment walk, so a model that
omits one fails deep inside a template instead of at a declaration. `set_recorded_state` is the
sharp case: it exists purely because reloading a state the ordinary way linearises a boundary node
the trajectory never carried, which makes it an adjoint-specific loader — the thing §14.1 spent a
paragraph claiming a model no longer writes.

*Do:* put all three behind one concept, asserted where the walk uses them, and ask whether the
third is a loader at all or the *second* of the two boundary evaluations §5.1 makes structural. If
it is the latter, it is a read-point declaration and belongs with the reduction's staging rather
than with state loading.

*Done when:* a model missing any of the three fails at a `static_assert` naming the member, and the
gradient is bit-identical across the change.

**And the concept boundary stops a level too high, which is what makes item 5 worth doing.** Every
concept in the solver is checked against the patch. **Not one of the model's own AD members is
checked by anything** — the parameter list, the rebind, the environment's block interface and the
name list are all reached by duck typing one or two levels below the boundary, so a misspelling
surfaces as a template error inside the patch rather than as a diagnostic naming the member. The
seat is the sharpest case: it is asked of the patch, the patch has it, and **the strategies and the
environment do not** — the patch discharges its own seat by *rebinding* each of them, which
constructs the objects the seat exists to avoid constructing, on every recording, six times a step.
Either the seat reaches one level down or it is buying less than §14.1 claims.

**And one that is not a primitive.** The step recorder's driver — toggle recording, run, harvest,
attach the step sizes — is twenty lines with nothing model-specific in them, and the record is a
time, a size and a state. It belongs beside the concept that dispatches it.

### 14.6 The standing qualification, which none of the above removes

The introduction schedule is refined by bisecting on errors that depend on the traits, so the
schedule is a function of the parameters and the reverse pass treats it as constant. **Every
gradient this machinery produces is a partial derivative at a fixed discretisation.** That is
defensible and it is not what a reader assumes. Nothing in the code can check it, so it belongs
written beside any number the machinery produces.
