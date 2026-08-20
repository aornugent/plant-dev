# Generalising the reverse pass

The stand-scale reverse mode is correct on the birth-date coordinate, and it is **one recording per
Runge-Kutta step**. Everything between the state and the rates — the shared field and both its
reductions, the inflow condition, every unit's physiology, the downstream aggregation and the
environment it feeds — is an intermediate of that recording, and so is the tableau that joins the six
stages into a step. The transpose is one vector-Jacobian product against the adjoint of the state the
step ends at.

Reports 00 to 08 state what the derivatives are and what a correct implementation must satisfy,
written from the model's side. **This one is written from the solver's**, and the discipline is
explicit: §1, §3 and §4 use no ecological vocabulary at all. No cohort, plant, light, soil, seed,
species, census, trait. Where a property cannot be stated without one of those words, that is
recorded as a finding rather than worked around — because it marks exactly where a solver-level
primitive would under-determine the model.

§1 to §9 state the design. §10 is what is left, and §11 is the qualification that attaches to every
number the machinery produces.

**§9 is the newest part and it is where the design pays for §8.** §8 sends the opaque solver to a
supplied row because recording it would differentiate a search. §9 observes that being off the tape is
also what makes its *answer* restorable, so the pass that supplies its rows need not repeat its search
— and that the same mechanism, with the payload's kind changed, is what an invasion run needs for the
resource it does not move.

## 1. The general system

Strip the model and what remains is one shape, which a solver could name.

> An **ensemble ODE**. The state is a list of **units** plus a **shared** part. Units are independent
> of one another given the shared part. The shared part is built from the units by **reductions**.
> Each unit reads the shared part through a **contraction** of small fixed width. The list of units
> **grows** at scheduled times. A **functional** of the final state is what we differentiate, with
> respect to many parameters at once.

## 2. What is taped, and what is supplied

Two ways to obtain a transpose exist, and only one of them can drift.

**Derived by tape.** Record the forward map at an active scalar and take one
`vector_jacobian_product`. A transpose obtained this way **cannot** disagree with its forward,
because there is only one function.

**Hand-mirrored.** Write the transpose beside the forward and hold the two together by a comment —
*the same early exit, the same closing trapezium, the same node order*. Every silent failure this
corpus has found is of this kind: a term dropped on a branch no fixture reaches, an association order
restated at four sites, one column order assembled three times. A hand-mirrored transpose is also
routinely *larger* than the forward it transposes.

So the rule, which decides every open question below:

> **Tape everything whose operations you can afford to record. Supply rows only where recording is
> impossible — an opaque solver — or unaffordable — the whole trajectory.**

**The reductions are taped, and the number rather than the precedent is the argument.** Counted on the
source: two shared-part builds per stage at 65 query points, over ~81 units with an early exit, at
~19 recorded operations per contribution — **≈10⁵ recorded operations, order 3 MB of tape per stage.**

**And the conclusion drawn from that count was wrong, which §2.1 is about.** It read "roughly one unit
block's tape" as "the reduction is not what is expensive", and priced the rule's first clause as free.
Measured, the tape is most of the reverse pass and the reduction is most of the tape.

### 2.1 What taping costs, measured

The rule above says to tape whatever can be afforded. What that costs was never measured, so here it
is, at the scale §9.6 is sized on — 3,381 recorded steps, a final state of 1,361, three functionals.

**A recording is taken once and walked once per functional, so the two halves separate by asking for
one functional instead of three.** One functional: 135.41 s. Three: 173.80 s. So **one walk is 19.2 s
and three are 33% of the gradient**, and the recording with everything around it is the other 67%.

**And the recording's own arithmetic is bounded by the pass that does it without a tape.** The forward
run makes the same six rate evaluations a step in the passive scalar and takes 37 s, against 116 s for
the recording. So **≈80% of a gradient is the tape: building it and walking it.** Sampling agrees
independently — the walk's own frames are 29.5% of the gradient and the allocate/register/append/release
frames another 10.9%, before counting the pushes the optimiser inlines into the model's own functions,
which is most of them.

Three things follow, and they are the whole of what the rest of this report can offer on cost:

- **An operation removed is removed four times.** Once from the construction and once from each walk.
  So a change to the forward model's *operation count* is a reverse-mode change with a multiplier, and
  ranking one as a forward-model performance detail understates it by that factor.
- **The walk is pure arithmetic over recorded edges.** No model evaluation reaches it, so its only
  parameter is edge count — and the number of walks, which §5 revisits.
- **The largest single term is the shared-part reduction**, at 19.0% of a gradient to build against
  5.3% of a run to build the same number of times: **8.3× dearer per build inside a recording**, and
  the difference is entirely tape. §4.1 states what follows for its algorithmic order.

**What this does not overturn is the rule.** Hand-writing the reduction's transpose to keep it off the
tape is still the wrong answer, and §4.1's one-ended closing interval is the standing proof of why.
What it overturns is the idea that the forward reduction's *order* is somebody else's performance
concern.

**The two clauses can apply to one read, and the interpolant is where they do.** A field read at a
position has two derivative channels and they are with respect to different independents, so they are
answered differently and neither is a fallback for the other:

- **with respect to the knot data — taped.** The polynomial is linear in the four knot values and
  slopes it touches, so the tape returns those partials exactly, and there is no analytic substitute
  to supply: the partial with respect to a knot slope *is* the basis function. Four non-zeros per
  query, and the adjoint is `O(1)`.
- **with respect to the query position — supplied.** The span is indexed at the position's *value*, so
  the read records no dependence on it and the tape would return exactly zero. The interpolant's own
  analytic slope is grafted on, at a displacement that is numerically zero, so the value is unchanged
  and the two channels cannot contaminate each other.

**The slope's own query-derivative is refused rather than answered**, because grafting it would need
the span's second derivative — and the read is C¹ and not C², so that number describes the fit rather
than what was fitted. A value accessor must keep working when a slope accessor refuses; pairing them
would force a forward model with no derivative problem to stop.

**A forward association order, once asserted, is a constraint on the transpose.** `Σ wₖ fₖ` and
`(Σ widthᵢ(f_lo + f_hi))/2` are the same map with a different association, and the forward's
association is asserted **bit-exactly** — the fused value-and-slope reduction against the plain value
reduction, over 200 heights and seven crown shapes, with a control pinning the aggregate order too.
Any reduction machinery must therefore be **interval-major**, with the caller keeping its own
accumulator; a per-slot weight vector cannot serve the forward. Association order is not a modelling
decision, it is a floating-point one, and it belongs to whatever owns the walk.

## 3. The stage

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
second, and they differ by more than `1e-6` relative with a test asserting it. Anything listing "the
boundary condition" in the singular gives the downstream reduction a transpose linearised at the
wrong operating point. So what a model declares is a **read-point list**, and the rule *one
accumulator slot per stage a quantity is read at* is then counted by the engine rather than by the
reader.

## 4. The structures that make it hard

### 4.1 The grid

**Generally.** A weighted reduction over an ordered element set whose weights come from a coordinate
on that set. Whether that coordinate is **passive** decides everything downstream: passive weights
are constants on the tape and the transpose has no weight-derivative term; active weights make the
quadrature move with the state, and both the forward density equation and the transpose acquire a
term. **Those two terms are the same fact seen from opposite ends** — one report calls it a
compression term, the other a weight derivative.

**How the passivity is bought: by a *return type*.** The coordinate accessor returns `double`
unconditionally, which makes report 05 §6.1's conditions (1) and (2) unviolatable rather than
testable. All four of its conditions hold on the supported coordinate. Passivity by type rather than
by discipline is the pattern worth copying — a width cannot carry a derivative however the caller
stores its grid.

**Four instantiations, not three:** the two shared-part reductions, the functional, and the fitness
integral, which already integrates over the passive coordinate unconditionally and excludes the
closing element.

**Its ORDER is a reverse-mode decision, not a forward-model one.** Written as it stands the reduction
walks the element set once per query point, so it is `O(K·N)` in query points and elements. Where the
kernel factorises — a function of the query position times a function of the element's own coordinate,
summed — every query point is a partial sum of the same running totals over the elements in coordinate
order, and the build is `O(K + N)`. That is a property of the kernel and nothing here can check it, so
a model that has it declares it.

Two things about what such a rewrite is worth, and the first is why it belongs in this report at all:

- **The tape shrinks with the operation count, so the transpose comes out cheaper without being
  written.** This is the one lever that reduces §2.1's dominant term while leaving §2's rule intact:
  the reduction stays taped, there is no hand-mirrored transpose, and the sweep walks `O(K + N)` edges
  because that is what the forward pass performed. Ranking it as symmetric — "the run pays the same
  reduction" — understates it by §2.1's factor of four.
- **It re-associates, and the forward association is asserted bit-exactly** (§2). So it is a
  re-blessing of every reference the reduction's value reaches, which is the whole of its price and is
  not negotiable down.

**One degenerate interval per event is deliberate.** An event stamps the inserted element and then
refreshes the closing element's coordinate to the same time, so the closing interval has exactly zero
width at that instant. That is why the coordinate flag appears as a standalone clause in the closing
predicate, replacing the contribution test the other branch needs — and the guard is correspondingly
split: strict monotonicity on the interior grid, non-strict at the closing point. No width is divided
by anywhere in the quadrature or its transposes, so a degenerate interval is free.

**The one place the grid is told the time.** The closing element's coordinate is the current value of
the independent variable, so it must be refreshed before each reduction build or the closing interval
is short by one stage. The damage measures below `1e-6`, and that measurement is *not* the reason to
refresh: the interval is otherwise a function of the step size, which a spatial quadrature has no
business depending on. It is the only place in the discretisation where one does.

**Every reduction reads its grid through that one accessor**, including the fallback walk used when the
ordering has broken and the downstream reduction, both of which used to build their own. That is what
makes the passivity structural: a width cannot carry a derivative because no reduction has a route to
an active position (§10 item 7).

**One defect remains on the unsupported branch**, and it is the shape report 05 §6.1 warns about — a
wrong transpose parked where no fixture reaches it. **The closing interval's transpose writes only one
end**: the interior loop emits the position-derivative term at both ends of every interval, the closing
interval emits only its upper end, and the slot is live and feeds a real accumulator. The coordinate
refusal is *a fence around it, not a fix for it.*

### 4.2 Dimension growth

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
  reliably gets wrong, and the right answer is to never write it: record `G` at an active scalar and
  take one VJP, so the relocation, the state half and the parameter half all fall out of one object
  and which widened row each narrow row became is *derived* rather than written out.
- **`y⁺` is never on the tape.** It exists strictly between two accepted steps, so no recorder holds
  it. The reverse pass replays the events forward to reconstruct each segment's first pre-step state,
  and the replay must be idempotent because it runs once per output row.
- **Width is stateful.** The System and every stepper buffer are sized to a width, so the sweep
  narrows as it descends and must recover the width sequence *newest-first*.

**The decomposition is one segment per width**, so there is one more segment than there are widenings
and the lowest runs down to the initial state. Written that way an empty event list is one segment
rather than none, and the lowest segment is empty exactly when a run starts from bare ground — which
is why no fixture built that way can tell the difference, and why the sweep must be decomposed the
same way the forward tangent is rather than guarded.

**If the event time were a function of the parameters**, the adjoint acquires the hybrid-system jump
term `λᵀ(f⁻ − f⁺)·dτ/dθ`, which none of the above computes. **Scheduled growth and state-triggered
growth are different primitives** and a concept must not accept both under one name — the second
would silently lose a term.

## 5. What the solver owns, and what a model declares

**The solver owns the reverse pass entire.** The tape, one for a walk. The System at the adjoint
scalar, one per recording, lifted by the primitive that records on it. **One recording per step**,
spanning all six Runge-Kutta stages and the combination that closes them, taken through the same rate
call the forward pass uses — which is also the one place a replay pass diverges from a resident one.
The tableau itself, written once and stepped through by the forward pass and the recording alike. The
record-once-sweep-many product, with the parameter channel in band. The segment walk across
widenings, with the run's declared event list checked against the recording it sweeps, and the
narrow-widen round trip.

**The recording spans the step and not the stage, and that is the whole of the design.** A stage
recording cannot see the arithmetic that joins the stages, so something has to transpose the
Runge-Kutta method by hand and stay consistent with the tableau by discipline — the defect this
report exists to remove, sitting in the solver rather than the model. A step recording transposes the
stepper's own arithmetic. It is also the cheaper pass: a stage recording rebuilds each stage's state
in `double` before it can record that stage, so it walks the step twice at thirteen model
evaluations, where a step recording's stage states are its own intermediates and it walks once at
six.

**The System is lifted to the adjoint scalar inside the primitive that records on it**, rather than
being built by a caller and handed down. Lifting per recording is one construction per step and buys
slot freshness; the alternative is tape management, which §10 item 4 states and prices.

**Every seed goes through one recording.** There is no single-seed entry point at the step or the
solve level: a caller wanting one row passes a batch of one, because a second signature over the same
recording is a second place for the seam between the state half and the parameter half to be got
wrong. So three metrics cost one recording and three sweeps, not three recordings — which is why the
recorded rate count at production width is exactly six per step whatever the metric count.

**And the three sweeps are three walks of one tape, which is a batch the tape itself can carry.** The
adjoint scalar is templated on a derivative width defaulted to one, so a slot holds one adjoint
component and a batch of three is three passes over the same recorded operations. At width three each
slot holds the batch and the operations are read **once**. What that removes is the reading, not the
derivative storage — the same components are cleared and accumulated either way — so it is worth the
part of the walk that is operation traffic and not the part that is slot traffic: **about 12% of a
gradient**, measured against §2.1's split.

It is also a deletion rather than an addition: the loop over seeds inside the record-once-sweep-many
product goes, because the width carries what the loop was carrying. And the batch stops being able to
disagree with itself — a width is a type, so a caller cannot hand in a batch of a different size from
the one the recording was taken for, where a loop over rows can and the check for it is a length
comparison.

**The parameter channel is in band, and its two halves have opposite disciplines.** The accumulator is
the caller's, passed as the last argument; the state adjoints are **replaced** and the parameter
adjoints are **added to**, so the caller pre-sizes one row per seed and clears once per sweep, and
passing the same vector for both is refused outright. A row that does not match the seeds is a length
mismatch, where an out-of-band accumulator on the System gave a fixed fraction of the right answer
with the correct sign and nothing raised.

### 5.1 The two passes

```
FORWARD -- once                          REVERSE -- once per recorded step, descending
───────────────                          ────────────────────────────────────────────
SCM::run                                 solve_adjoint_over_widenings
└ Solver::advance_adaptive                └ Solver::solve_adjoint        one segment, k_last..k_first
  └ Step::step                              └ Step::step_adjoint         ONE recording per step
    ├ derivs x 6 stages                       └ state_and_parameter_adjoints
    │ └ Patch::set_ode_state                    (1) rebind_from<active>   the System, lifted
    │   ├ species state                         (2) ad_parameters()       the parameter pointers
    │   └ compute_environment                   (3) in = state ++ parameters
    │     ├ excl_capturing  -> rebuild_spline   (4) clearAll()            slot counter -> 0
    │     ├ compute_boundary_nodes              (5) registerInputs(in)    BEFORE newRecording
    │     └ closing         -> rebuild_spline   (6) newRecording()
    └ Patch::compute_rates                      (7) derivs x 6 stages, then step_end
                                                    └ the same ode::derivs, on the lifted
                                                      System, rebuilding the field per stage
                                                (8) per seed: clearDerivatives -> seed ->
                                                              computeAdjoints
```

Five invariants the shape carries, each of which fails silently if broken:

- **The six evaluations and the tableau that closes them are inside one recording**, so the
  Runge-Kutta method is transposed by the tape. Nothing transposes it by hand and nothing has to stay
  consistent with the coefficients by discipline.
- **`k1` is re-derived at the step's own start state.** First-same-as-last hands the forward `step()`
  the previous step's rates, which a reverse traversal has not rebuilt.
- **Inputs are registered before `newRecording()`.** Registering after leaves them outside the
  recording, and the sweep then reports every input adjoint as zero with nothing thrown.
- **`clearAll()` is right *here*** because the System is lifted per recording, so every scalar arrives
  holding no slot. Where a lifted System is cached and outlives its recording the same call is wrong
  — returning the counter to zero is what makes the carried slots alias live variables (§10 item 4).
- **The state is sliced at a width the recording and the sweep must agree on.** Slicing past the state
  reads parameter values as state, and the sweep then splits the adjoints at a different seam from the
  one the recording used, so the width is checked where the recording is taken rather than in the
  callers that happen to check it.

**And the segment list is declared by the run, not inferred from the recording.** A caller hands over
`{after_step, event}` pairs and the walk checks them against the recording it was given: in range, in
the order the run took them, and partitioning it. **Inferring the widenings from the state's width
instead cannot fail that check, because it defines the answer** — which is the whole reason the
declared list is the shape. The narrowing is checked too, by a round trip: `narrow` must undo exactly
the width `widen` added and return the state it was given, or it is dropping something other than what
`widen` added.

### 5.2 What a model declares

**A model declares five things, and four of them it already had.** How to assign itself from another
scalar's copy. Which of its scalars are parameters. How to compute rates. And **two** loaders, not one
and not three: `set_ode_state`, and `set_recorded_state` for a state the run recorded.

**A sixth arrives with §9 and it is the read-point list this section says would force one.** A model
that replays anything declares its payloads — each one's kind and its extent — and the loader gains a
stage index. That is not a new kind of declaration: §3's read-point list is what indexes it, so the
model states *where a quantity is read* and the engine counts the slots. The sentence below still
holds — **a second model with two read points is what forces the declaration** — and §9 is that
declaration arriving from the other direction, because a payload has to be keyed by read point whether
or not a second model exists.

**Nothing else.** No tape, no seed vectors, no recordings, no Butcher coefficients, no operating point
carried forward to reverse, no transpose. The loaders are the residue, and they are two where the
argument wanted one — the second earns its place, because a run genuinely carries more than it
records. `set_recorded_state` is the ordinary load plus the inflow condition's *second* evaluation, so
it is not a third kind of loading; it is §3's second read point arriving as the one thing a model
writes beyond loading its state. It stays spelled as a loader rather than promoted to a read-point
declaration because with one read point above the ordinary load there is nothing to enumerate. **A
second model with two read points is what forces the declaration.**

## 6. Three layers, and an author only writes the first

**L1 — the forward pass.** `rates(state, reads, params) → rates`. No rebind, no parameter address
list, no hand-derived partials, no `passive()`, no `if constexpr (double)`, no adjoint scatter, no
graft.

**Not necessarily scalar-templated, and this matters.** There are two ways to make a model
differentiable and the cheaper one is not the one the reference model took. *Lifting* templates the
whole strategy on the scalar and hand-supplies a Jacobian wherever it will not lift — +61% file size,
a 47-line rebind, eight dual-path branches, two parallel parameter lists. *Extracting* leaves the
model alone and pulls the differentiable arithmetic into scalar-templated free functions that the
`double` model then **delegates to**, so the existing forward suite validates faithfulness. The
second is 125 lines and changes the strategy's shape not at all. A declaration demanding a rebind over
the whole strategy accepts neither of the other two models in this tree — one has no template
parameter at all. **L2 must support a partially-lifted model.**

### 6.1 The one thing L1 has to know about the tape, and it is a signature

An author writing L1 owes the tape nothing — except this, because nothing else can say it and the cost
is §2.1's second-largest term.

**With a tape active, a copy of an active value is not a copy.** It registers a variable, pushes a slot
carrying a multiplier of one, pushes a statement, and unregisters on destruction — so it records a full
`y = 1 · x` and the sweep walks it as one. **A by-value parameter of active type therefore costs an
operation per call**, and so does a by-value return of a pair of them, and so does a local copy of an
accessor's result. A `const&` costs nothing: it binds to what is already there.

Two properties make this worth stating rather than leaving to taste:

- **It is bit-identical.** A multiplier-one chain is exact, so removing it cannot move a number, which
  means it is the one cost reduction in this report that needs no re-blessing of anything.
- **It is invisible.** The passive instantiation of the same signature costs nothing, so the forward
  suite reports the same time, the same numbers and the same everything. Only the recording pays, and
  only an operation count can see it.

Measured on the reference model: the allocate/register/append/release frames are 10.9% of a gradient
and the active value's own constructor subtree is 19.4%, against a hot kernel — the one the shared-part
reduction calls once per element per query point — whose entire signature set is by value, and which
returns a pair of active values by value on top of that.

**So the rule for L1 is: take active values by `const&` and return them by value once.** It is not a
style preference; it is the difference between an operation and none, on the hottest arithmetic in the
model, and no other layer can fix it — L2 declares what a model *is*, and this is a property of how its
own functions are written.

**L2 — the declaration.** The parameter list as `{name, &field, role}` pairs; each reduction as
`{position, contribution, kernel, stage}`; the read layout as typed segments; the read-point list; the
growth map; and, for a model with an inner solve, the implicit node.

**Its size splits, and the split is the honest number.** The structural core — reductions, read,
boundary, growth — is **~31 lines** for the reference model and shorter for the simplest one, whose
parameter list is *empty*. The parameter list adds ~60 one-line entries. **The implicit node's
declaration is a few hundred lines**, because a curvature, a two-coefficient factorisation with a
model-chosen anchor direction, and fourteen traits with a complementary-slackness mask all have to be
named, and none of them exists on the forward path. The hand-written derivative surface therefore
**moves into the declaration rather than disappearing** — around 86% of its body is the primitive's,
but what survives is a declaration and not a deletion.

**L3 — the engine.** The tape, the blocking, both reduction transposes, the segment sweep, the
parameter accumulator, the refusal channel, and the harness.

## 7. Concepts: a choice, a refusal, and where to assert

A compile-time **choice** is a concept plus `if constexpr`. A compile-time **refusal** is a concept
inside a `static_assert`. Both are concepts; only one has a branch. No detection structs and no
runtime capability flags.

**Assert a concept where it is used, not where it is defined.** A concept nobody checks does not
merely fail to catch things — it drifts out of agreement with its own caller, and nothing reports
that either. The instance worth keeping in mind: a concept describing the widening walk was referenced
by nothing anywhere, and meanwhile the walk had acquired a call to a member the concept did not name,
so a System satisfying it in full still failed inside that walk.

**A hook nothing calls is not a contract.** A model can provide a hook that no call site reaches, and
nothing anywhere reports it: the hook compiles, the container it fills stays empty, and the one
feature built on it fails on its first statement for every model, always. This is the mirror of the
above — a model providing a hook nobody calls, against a solver describing a requirement nobody
checks — and both are invisible for the same reason. **The honest response to finding one is to
delete it or to make its absence a compile error, never to leave it standing on the strength of the
feature it was once for.**

Two rules follow, and every noun added to the solver's interface header is judged by them:

- **A missing call must be a compile error, not a silent default.** A concept asserts that a *type*
  is adequate; what goes missing is a *call*.
- **A concept with more members than its consumer needs invites a model to opt into a contract it
  does not mean** — four hooks where the real consumer needs one, satisfied with three empty bodies,
  and no way to say so.

**And the boundary stops a level too high.** Exactly two `static_assert`s check a solver concept
against the model, both at the same site and both about the top-level container — that it records steps
and that it widens state. Below them, **not one of the model's own AD members is checked by anything**:
the parameter list, the copy, the environment's block interface and the name list are reached by duck
typing one or two levels down, so a misspelling surfaces as a template error inside the container
rather than as a diagnostic naming the member.

## 8. The implicit node

§2's rule sends everything to the tape except an opaque solver and the whole trajectory. This is the
opaque solver, and it is the largest hand-written derivative surface left.

A model with an inner solve declares the solve, not its calculus. The primitive owns the envelope
theorem, the implicit function theorem, the rank-one collapse, the amplification ceiling, the
classification, the graft, and the transpose identity. **The classification becomes structural** — a
consumer cannot fail to consult it. Today that guarantee rests on one dependency choosing to check,
and a second consumer would not inherit it.

### 8.1 The interface, read off what the code consumes

- a solve returning value, outputs and a **classification by branch taken**;
- a residual `R(p; u)` with **feasibility as a separate channel, never a sentinel value**;
- a curvature with the same feasibility channel per arm;
- an output declaration naming which output **is** the implicit quantity (its `p`-channel is exactly
  1) and which **is** the objective (exactly 0);
- the ordinary partials `∂y/∂p`, and the bound derivatives `∂B/∂u`;
- **an amplification ceiling on `|s|/|R_p|`**, refusing the non-objective rows and emitting the
  objective row regardless;
- a factorisation hook;
- the graft with its finiteness pre-test;
- a transpose-identity harness.

**That last item is what makes the rest affordable.** `⟨v, Ju⟩ = ⟨Jᵀv, u⟩` needs **no reference
gradient and no differencing** — it is a property the transpose either has or does not — and it
already holds to `1.4e-14` over 294 operating points. A primitive that ships it gives every future
node the one check internal consistency cannot fake.

**The graft is one construction with a real variant, not three copies.** `v + Σ ∂v/∂uᵢ·(uᵢ −
passive(uᵢ))` carries a finiteness guard because a *supplied* partial can be `NaN` while the model is
healthy, and `NaN × 0` then poisons the value. Where the slope is one the tape computed, that
condition cannot arise and the guard would sit on the hottest read in the model to catch nothing. So
the guard belongs to the supplied-partial form, and the two are not interchangeable.

### 8.1a What the node must add for §9, and it is two members

The interface above says what the node supplies. **It does not say that the solve can hand back what it
found, or take it back**, and §9's Kind B payload is exactly that. Report 07 §9 states the same
requirement from the model's side, where it is the last entry on the list of what the submodel must gain;
here it is: a token carrying the operating
point, the branch it was found on, and the feasible bounds, which the producer alone constructs and the
producer's own restore alone consumes.

Two properties make it a restore rather than an imposition, and both are load-bearing:

- **The restore's closing arithmetic must be the solve's own.** Where the solve places its outputs and
  the prescribed evaluation places its outputs by the same expressions, a restore at the solve's own
  answer is bit-identical, and bit-identity is the only referee this payload can have. Where they are
  two spellings of one placement, the restore drifts and nothing says so.
- **The solve must close on the condition at the point it returns**, because that is what seats the
  coefficients a row is read from. A restore evaluates the condition once at the recorded point and is
  then seated exactly as a solve leaves it — so a boundary that already satisfies that precondition
  needs nothing further, and one that does not cannot be restored at all. **The precondition that makes
  the row layer a read is the same one that makes the restore possible.**

**And a restore must decline the branches that never searched.** A point the solve reached by an early
exit costs nothing to reach again, so the token says so and the caller solves — which keeps the cheap
branches cheap and needs no flag.

### 8.2 Design against the branch that has never run

The variant that **has already dissolved the argmax** is not on the gradient path at all: its tracked
operating point is passed into a `double` evaluation and clamped against `double` bounds, so it does
not compile at an active scalar and no export instantiates it.

That is worth stopping on. A tracked operating point is an ODE state, so its derivative arrives from
the adjoint for free — no implicit solve, no stationarity condition, no curvature to divide by, no
five kinds of point. It needs the marginal objective at a *prescribed* point, which the node already
returns, and the ordinary adjoint the engine already runs.

**Designing the node against only the hard case will give it the hard case's shape.** The
tracked-state case is the one that says what the *general* interface is, and it also exercises a
regime report 05 §7.0 lists among the states the gradient is not valid at and does not refuse.

### 8.3 The factorisation, and what it is worth

The node's two-coefficient factorisation is **anchored in root carbon**, which is outside the fitted
family's span, so **no potential layer is in sample** and a check exempting one of them excuses the
layer that most needs checking. The anchoring family is checked at `7.1e-08` against the fit step's
own `1e-05` — the premise every predicted layer rests on.

**The residual is one error, not five.** Per layer against its own reference it reads 20.9, 18.9,
17.5, 0.5, 1.4 times the difference's error, but the difference matrix is **rank one**, so every layer
is wrong by the same relative amount and that spread is one scalar seen through a normaliser dividing
by the block's largest entry rather than the column's. It is bounded two ways, on the structure and on
the size, at the fit's own truncation.

**The direction that decides the answer cannot be had from the columns**, because its answer is a
cancellation among them; it is checked by perturbing along the direction. Along it the amplification
is **1.1× on both constructed fixtures**, and between **1.03 and 1.14** at every node of every run
stand, the competing one included. Competition, shade, drought, unit count, model count and run length
each move it by under a tenth. What moves it is the share of the transport path lying between the
source and the collar: at sixty times the root conductance and the same root carbon, a one-unit
fixture measures **16.3×**. **A stand cannot reach that regime** — run with the traits that do reach
it, it ends at 1.00× because the carbon buying the conductance is a mass constant and the model cannot
grow.

## 9. Replay: one mechanism, two kinds of payload

A **replay** is a pass in which part of what a step needs is supplied from a record rather than
recomputed. One mechanism serves every case; what differs between cases is not the mechanism but
whether the supplied quantity is on the tape, and that single question decides where each is
admissible.

### 9.1 The two kinds, and the one rule

**Kind A — a moved cut.** The payload is a quantity the recording would otherwise build as an
*intermediate*. Supplying it does not restore an intermediate; it **registers the quantity as an
input**, moving the cut the recording is taken across. The recording is then of the same function at
the same point over a wider input set, so its transpose is correct and the payload's adjoint comes
out of the sweep like any input's.

**Kind B — a restored answer.** The payload is a quantity that never reaches the tape at all, because
§2's rule sends it to a supplied row instead of a recorded one. Restoring it changes no tape edge,
registers nothing, and asserts nothing.

> **A payload is admissible on a pass if it is Kind B, or if it is Kind A and the pass's own model
> declares that quantity exogenous.**

That is the whole rule, and the reason is arithmetic rather than taste. A Kind A payload's adjoint
has to go somewhere. Where the pass treats the quantity as exogenous the adjoint is discarded and the
reduction that built it is not run — the saving is the whole reduction. Where the pass does not, the
adjoint must be **scattered back onto the units**, and that scatter *is* the reduction's transpose,
which requires the recording — **so on that pass there was never anything to save.** Supplying a Kind
A payload where its adjoint is needed is not unsafe so much as pointless, and the failure it produces
if the scatter is then skipped is a whole channel missing with every number finite.

Kind B has no such condition because there is no adjoint to place: the rows were supplied either way.

**This is why §2's rule and this section are the same statement.** §2 keeps an opaque solver off the
tape because recording it would differentiate a search. Being off the tape is exactly what makes its
answer restorable on every pass. **The design's most expensive exception is the only part of a step
whose value can be reused without touching the transpose** — and the general form is: *whatever is
supplied rather than taped can have its value restored; whatever is taped can only have its cut
moved.*

### 9.2 The concept

```
concept Replayable = requires(System s, std::size_t step, int stage, const_iterator in) {
  s.record_stage(stage);        // per RK stage, on the recording run: keep this stage's payloads
  s.replay_step(step);          // per step, on a replay pass: make that step's record current
  s.set_ode_state(in, stage);   // load state against a stage rather than a time
};
```

Three members, and **two of them the engine already calls**. The stepper calls `record_stage` at every
stage — five inside the stage loop and one at the state the step ends at — so the record side is live
wherever a run is stepping. And the rate call already carries a stage index and dispatches the loader on
it, so the stage-indexed load is live too.

**`replay_step` is called on the two fixed-step paths and nowhere else, and that is half right.** A
replay pass runs a schedule the run already fixed, so a fixed-step path is exactly where it belongs —
record on the adaptive path, replay on the fixed one, which is a symmetry worth keeping. **What is
missing is the call from the adjoint walk**, which is neither: it is driven by a descent over recorded
steps, and it is where a Kind B payload has to be made current. So the additions are the step argument
(§9.4), that one call site, the payload registry (§9.3), and one deletion.

**`has_recorded_field()` goes.** It is a **mode query on the System**, and whether a pass replays is
the **driver's**, not the System's. The driver counts the steps and knows which pass it is running, so
it takes the branch itself and hands over the live payload set. A System that can answer "am I
replaying?" is a System that can accidentally replay, and the symptom is a resident gradient with a
feedback silently missing — finite, plausible, nothing raised.

**And no time lookup, and no "field" in the name.** The step is handed in, because recovering it by
searching the record for an exact float match needs a cursor, a fast path and an abort when the time
does not round-trip, and the driver already has the index. And the name drops "field" because the
payload set is open: the two instances below are a field and an inner solve's answer, and neither is
the other's special case.

**Removing the query removes a branch, and the loader has to absorb it.** Today the rate call chooses
between a stage-indexed load and a time load by asking the System whether it holds a record. With the
query gone there is nothing to ask, so **the loader takes both and branches on neither**: the time,
because a model has a clock, and the stage, because a model with live payloads indexes them by it and a
model without ignores it. One signature, no dispatch, and a model that replays nothing is unaffected —
which is the same shape as §4.1's coordinate accessor, where the guarantee is bought by the signature
rather than by a rule about who calls what.

**One hazard the current pair carries and the merged signature retires.** A stage-indexed loader and a
time loader **overloaded on the same name**, one taking `int` and one taking `double`, are separated only
by an implicit conversion — so a caller passing the wrong one of two numbers gets the other overload
silently, and what comes back is a state loaded against the wrong argument. Two names or one signature;
never two overloads whose arguments convert to each other.

### 9.3 What a payload declares, and who selects

Each payload declares two things and no more: **its kind**, which is a compile-time property of the
quantity, and **its extent**, which is the number of values it holds at a given step's width.

Selection is the **driver's**, at run time, and it cannot be otherwise: the pass is not a property of
the type, so the same System serves a resident sweep and an invasion sweep. So the guard is a
**refusal by name** rather than a `static_assert` — the engine, handed a payload set for a resident
sweep, refuses any Kind A member in it and says which. That is a stated cost of the design: §7 wants a
missing call to be a compile error, and this one cannot be, because what is wrong is a *pass* and not
a *type*.

**The kind is not settable, and one instance needs more than that.** Where a payload carries a
**classification** the producer decided by the branch it took, a loose pair of values would let a
caller invent one — and a tag that a caller can invent is a tag a caller can disagree with, which is
the reason such tags are read-only in the first place. So a payload of that shape is an **opaque token
the producer alone can construct and the producer's own restore alone can consume.** A caller can
carry it and hand it back; it cannot make one up. That preserves the read-only guarantee exactly while
making the restore expressible, and it is the difference between *restoring what the solve found* and
*telling the solve what to think*.

### 9.4 The index, and the off-by-one that would be silent

The store is keyed by **(step, the stepper's own stage index)**. The stepper numbers six rate
evaluations a step: five inside the stage loop, and one at the state the step ends at.

**First-same-as-last is what makes that numbering not the one a reverse pass wants.** The forward step
takes `k1` from the previous step's last evaluation, so the six slots a forward step writes are its
five interior stages plus **the state its successor starts from**. A reverse traversal has not
rebuilt that, so the recording re-derives `k1` at the step's own start state — and therefore

> the recording of step *n* reads its `k1` from **(n − 1, last stage)**, and its remaining stages from
> **(n, 0 …)**. The first step reads `k1` from the evaluation the solver makes before any step.

Getting that wrong transposes a step at a **neighbouring state**: every number finite, every number
plausible, and wrong by one stage's worth of drift. It is the same shape as every silent failure this
report exists to remove, so the mapping is written here once and the walk derives it rather than each
caller restating it.

### 9.5 Rejected attempts, widening, and when nothing is written

**A rejected attempt must not commit.** The stage hook fires on every *attempt*; the step hook fires
only on acceptance. So the per-stage payloads are a scratch indexed by stage, overwritten by each
retry, and committed by the step hook — which is what the two hooks already do, so this costs no new
mechanism.

**The payload is committed at the step's own width**, beside that step's state. So nothing has to be
relocated through §4.2's embedding: each step's record is self-consistent, and a widening between
steps changes the next record's extent rather than re-indexing the last one's.

**And a run that is not recording writes nothing.** The store rides the same flag the trajectory does,
so a plain forward run pays neither the memory nor the writes. That is what keeps this a cost the
gradient's consumer opts into.

### 9.6 The two instances

| | payload | kind | extent | admissible | what it removes |
|---|---|---|---|---|---|
| **A** | the shared field's knot values and slopes | A — a moved cut | 2K per (step, stage) | an invasion sweep, where the resident's field is exogenous by definition | the whole `O(K·N)` reduction |
| **B** | the inner solve's answer: the operating point, the branch it was found on, and the feasible bounds | B — a restored answer | one token per unit per read point per (step, stage) | **every pass** | the *search*, leaving one evaluation |

**The field is already cut there.** §2 lists the interpolant's knot values and slopes as the
independent inputs the sparsity claim is about, and the interpolant already holds them as members with
a primitive that sets them. So Kind A costs no new state: restoring the field is writing the two
vectors the build would have written.

**The inner solve is Kind B for the reason §8 gives.** Its rows are supplied, so its value reaches the
tape only through the graft, whose inputs are the ones the consumer holds. A restored operating point
therefore changes no recorded operation — and it must arrive as §9.3's token, because the branch taken
is part of what was found.

**Both are sized, and neither is large against what a step recording already holds.** At the scale the
reference model is profiled on — 3,381 recorded steps, a final state of 1,361, six stages a step, and
seven state entries per unit so about 193 units at the end and roughly half that on average:

| | extent | store | measured share it removes |
|---|---|---|---|
| **A** the field | 2 × 65 per (step, stage) | **21 MB** | **16.7%** of a sweep, on the pass that admits it |
| **B** the inner solve, point and branch | ~2.0 × 10⁶ tokens | **20 MB** | **12%** of a sweep, on every pass |
| **B** with the feasible bounds as well | + 2 values a token | + 16 MB | a further 2–4% |

against the **62 MiB** one step recording already holds. And the two do not compete: A is the reduction
and B is the inner solve, so a pass admitting both pays 41 MB and removes both shares.

**One asymmetry decides which to build first, and it is not the size of the share.** B is priced
*identically* on both passes — the inner solve runs at the passive scalar either way — so its whole
share is recomputation, and a restore that reproduces the recorded value is refereed by bit-identity and
nothing else. A's reduction is priced **16.7× dearer** inside a recording than in a run, because there
the operation count *is* the tape and the sweep walks it twice; so where A cannot be admitted, the lever
on that path is algorithmic rather than stored, and its ranking as a symmetric change is wrong by that
factor.

**A restored point carries the branch the solve took, never a "prescribed" one.** That distinction is
load-bearing: a consumer that *imposes* a collar has no classification and must be refused, and a
consumer that *restores* one has the original. So the row layer needs no relaxation and its refusal of
an imposed point stays exactly as it is.

**And a restore is only offered where a search happened.** The branches that exit before the search
have nothing to save, so the restore declines them by returning false and the caller solves — no flag,
no mode, and the cheap branches stay the cheap branches.

### 9.7 What the payload differs by, which is where the invasion saving is

A resident integrates the shared resource because the balance is endogenous. An invader responds to a
resource it does not move — so on that pass the resource is supplied rather than integrated and
**leaves the state vector**. The two passes therefore run states of different width, which is a fact
about the model and not a detail of the record, and it is why the invader's field is Kind A
*admissibly*: its adjoint is not part of the answer.

**One caution on the flag that switches such a pass on.** It does two jobs — *use the supplied
resource* and *this is an invader: compute no boundary node, build no field, feed nothing back*. Only
the first is what a replay hook replaces; most of the sites testing that flag are the second job and
stay.

### 9.8 What this is bought with, and what would falsify it

**The price is that a restore is only as exact as the record.** Kind B's whole claim is that the
restored value is the one the pass would have computed, so the referee is bit-identity and nothing
weaker. That holds because the recorded step state is exact, the step sizes are recorded, the tableau
is shared, and the inner solve is deterministic — so every stage state is reproduced bit for bit and
the search would find the same answer. **Make the record lossy in any of those and Kind B degrades
into a warm start**, which carries a tolerance, is not bit-identical, and is refereed by nothing this
corpus trusts.

Three things would falsify the design:

- **A Kind B payload whose restore is not bit-identical.** The check is direct and needs no reference:
  restore, then solve, and compare every output. A disagreement means the payload is short of
  something the branch reads.
- **A Kind A payload whose adjoint turns out to be needed on the pass that declared it exogenous.**
  Then the saving was a dropped channel. The check is the transpose identity of §8.1, which needs no
  reference gradient.
- **The stage mapping of §9.4 being wrong at the run's first or last step**, where the
  first-same-as-last carry has no predecessor and no successor. Those two steps are where a fixture
  built from the middle of a run cannot see a defect, so they want a fixture of their own.

## 10. What is left

Items 1 to 3 are the design's remaining construction; 4 is a measurement; 5 to 9 are defects and
residues found beside it. **Items 1, 2 and 3 and support for a second model are deferred.** Items 5, 6
and 7 are closed — 6 as a refusal rather than a change, and the reasoning is kept because the
instinct it argues against is a recurring one.

**1. The implicit node — the last hand-written derivative surface.** *Deferred.* Measured: **~976 lines
exist only because of AD** — 853 in the strategy, 37% of its 2312, against 123 in the environment, 16%
of its 779; counted conservatively, excluding the bare `template` lines and the `double` halves of the
eight dual paths, ~781. **471 of them are one function**, the inner solve's supplied rows, whose body
is 422 lines. Split by what the lines do:

| bucket | lines |
|---|---|
| model calculus — the closed-form rows, the rank-two `(a,b)` fit, the unit conversions | **146** |
| plumbing — passive copies, the trait table, three re-assemblies of one column order | **113** |
| five perturb / re-supply / harvest / restore / guard blocks | **97** |
| comment-only rationale | 41 |
| the refusal and arity guards the dependency hands up | 15 |
| signature and closing | 10 |

**Calculus is the largest bucket, not the smallest.** So this is not mostly mechanism, and a primitive
owning only the differencing would take about a quarter of it. The case for the node is therefore not
the line count: it is that those 146 lines are the theorem written out by hand, at one site, with the
classification a consumer can bypass. §6 prices what happens to them — they move into a declaration
rather than disappearing.

Three details to carry into the work:

- **The five differences use five spellings of the step, from two magnitudes**, and one named constant
  `1e-3` is spent three different ways: signed-relative with no `abs`, so a negative base steps the
  wrong way; `abs`-relative; and `max(abs(x),1)`-relative. Only two of the five record why. A
  primitive owning the differencing owns the convention.
- **The trait order exists in nine places**, across three packages and R: an index enumeration, a name
  table, a positional apply, a fourteen-argument setter declared and defined, this model's own table,
  its own positional call, eight local integer literals, and a seventeen-argument constructor. Nothing
  enforces agreement, and **three positions disagree in name** — 1 and 2 are the stem's two here and
  the leaf's two there; 12 is the cost scale there, stored as the stomatal slope here, and named for
  the cost scale by the literal that indexes it. The aliases are written down nowhere.
- **The plumbing is load-bearing in the way that hides errors.** A flat copy of twelve rows exists only
  to run one finiteness loop, after which the same twelve numbers are assigned individually; and the
  five-segment column order is re-assembled three times plus once per layer, so a change must be made
  in four places and nothing catches a divergence.

It is not reached by any further work on the sweep, and no sweep-side change will shrink it.

*Do:* give the solver §8's node, so the model declares a solve rather than its calculus. Design
against §8.2's branch, not the hard one.

*Done when:* the classification cannot be bypassed by a consumer, which is what would let an interior
formula be applied at a pin; and the transpose identity holds without a reference gradient.

**2. Refusal — both ends of the channel exist and the middle drops it.** *Deferred.* The dependency
supplying the inner solve's rows returns validity beside its answer — a flag and a message — and
records its operating point **by the branch taken**, in an eleven-state classification. Its own comment
states why a residual test cannot substitute for that: the no-flow state returns a hard `0.0`, so
"residual within tolerance ⇒ interior" records it as stationary and then reads a curvature of zero off
the same sentinel — twice-confirmed and wrong, because the two states return the same number. **The
construction is proven, and that dependency's own entry point does return status and message to R as
character columns.**

**This model converts the flag to a throw at the first read**, and the ten further guards in the same
function are the same shape, so the function is throw-or-succeed with no per-point classification. What
reaches R is pure numbers. The one field that looks like this channel — an `unanswered` entry on the
returned list — is hard-coded empty, which reads as *nothing was unanswerable* rather than *this is not
wired up*, and is the same failure as a check written down as expected.

So an undefined metric comes back as a plausible number, or as an error that takes out the whole call,
and a caller can distinguish neither from an answer. Every other silent failure in this corpus has been
closed by making the wrong thing impossible to express; this one is still expressible, and it is the
outermost one.

Also here: a classification enum in the same dependency derives four values **from residual
magnitude**, which report 05 §7.0 forbids — and it sits beside the eleven-state tree above, which the
gradient entry point never reads. It is the same subject as item 1 and lands with it.

*Do:* lift the construction the dependency already uses into the solver's own return type, so
"undefined here" survives the whole way out rather than being flattened at the first boundary it
crosses.

*Done when:* a caller cannot ignore it without saying so, and the ladder has a rung that asks for a
gradient at a state where one does not exist and is refused rather than answered.

**3. Replay — the concept is designed and the engine already calls most of it.** *Deferred, and no
longer only about invasion.* The model's second recorder is deleted: the per-stage cache it kept was
reached through three hooks the solver had stopped calling, so the container was never filled and the
entry point refused on its first statement for every model, always — §7's hazard at full size. The
entry point survives and refuses with an accurate message; its test keeps its expected fitnesses and
skips, because those numbers are the specification for what replaces it.

**What §9 changed about this item is its size and its beneficiary.** The stage hook is already called
at every stage, the loader's stage index is already threaded through the rate call, and the step hook
is already called where a step begins — so what is missing is the payload registry, the step argument,
and the deletion of the System-side mode query. And the beneficiary is no longer only an invasion run:
the **inner solve's answer is a Kind B payload admissible on every pass**, which is where the measured
saving is, because a resident sweep re-searches for an operating point the run has already found.

*Do:* the three members of §9.2 with the payload registry of §9.3, the token for the classification,
and the stage mapping of §9.4 written once in the walk.

*Done when:* a `static_assert` says the concept is satisfied at the point of use, so the hooks cannot
go quiet a second time; the pass cannot be set by anything but the driver; a Kind A payload offered to
a resident sweep is refused by name; and the Kind B restore is refereed by bit-identity against the
solve it replaces.

**3a. The forward model is run again for every consumer of one recording.** *Closed, and the blocker was
not what the code said it was — twice.* A gradient opened by asking for the states its sweep walks, and the
run that produced them had just finished. On the reference fixture that repeat is **38 s against a 182 s
gradient**, and a referee set of three consumers paid it three times.

**The first reason given was wrong.** It said the states had to be emptied as they were read, because they
lived in one store and the step sizes that reached them in another, so a store left behind could be paired
with a later run's sizes. Folding the state, the time it was reached at and the size that reached it into
one record disposed of that: one record cannot be mispaired.

**The second reason was wrong too, and it is the one worth recording.** It said a sweep is not re-entrant
because a widening inserts a unit and what that unit carries which is not ODE state does not come back with
the width. The symptom was real — a second sweep refused with two units at one coordinate — but the cause
was not the width. **The walk opened by widening a System that was already at its full width**, purely to
assert that narrowing undoes it, and it did that at whatever state the System had been left holding, which
is a state no widening was ever applied to. On a fresh run the stamp it wrote was unique and nobody noticed;
after a sweep it collided with the one the walk's own tail had just written. The guard was not blind to the
defect, the guard **was** the defect.

*What closed it, and it is a deletion.* §4.2's `widen` and `narrow` are gone. A walk now says which recorded
step to be at and the System reconciles itself to it, so there is no ordering for a caller to get wrong and
nothing for a round trip to check. **The guard is deleted rather than fixed**, along with the newest-first
descent, the widen-back climb, the applied-count cursor and the narrow-on-throw. What replaces them is one
loader whose idempotence is structural: reconciling to a target is the same operation however many times it
runs, where stepping from a cursor is not.

Two things fell out that were not the point:

- **The stamp an inserted unit carries was read off the System's clock**, and every number it needs is a
  function of the time the schedule fixed. So it is now an argument, and one insertion serves the run and
  the walk — where two spellings previously agreed by call order.
- **A value the sweep transposes was being produced by a different function from the one it transposes.**
  The insertion's value came from the mutation and its rows from the map. Both now come from the map, and
  the whole ladder is bit-identical, which is what two spellings of one function look like.

*Done:* two sweeps of one recording run without a repeat and agree bit for bit — an assertion the suite has
always made and, until now, has only ever reached through a fresh run.

**3b. A flag that has to be set before a run was only reachable after one.** *Closed.* Keeping the states a
sweep walks is the caller's decision, and the caller could only express it on a constructed object — but
construction runs. So every caller wanting states built the stand, set the flag, and built it again, and the
wasted run is **55 s of a 283 s** gradient path. The flag is now an argument to the call that does the
running. Nothing about this was a design question; it is here because it was mistaken for one, and the
measurement that mattered was of the run nobody had counted.

**3c. A recorded schedule replayed forward is exact, and cheaper than choosing it again.** *Measured, and
one field short of usable.* The reverse pass already treats the step sizes as constants: it replays the ones
the run recorded rather than choosing its own, because a walk that chose would be differentiating a
controller the model does not contain. The forward pass need not choose either — and pinned to the sizes a
run took, it **reproduces that run bit for bit over 3,381 steps**, gradient included, while paying **15%
less**, because it attempts no step it will reject.

The code said this was impossible, and named a cause: a rejected attempt moves patch state that is not ODE
state, and a pinned run makes no such attempt. The states are measurably identical, so whatever a rejected
attempt leaves behind is rebuilt from the state before anything reads it. **A claim about what a replay
cannot reproduce is checkable in one run, and this one had never been checked.**

*Done, and the contradiction that guarded it was a third store of one recording.* The schedule was three
members — the times, the sizes, and a bool saying to use them — held together by a rule in a comment about
which setter cleared which. It is one vector now, and using it is **derived from holding it**: no flag, so no
way to hold a schedule and not take it, and one setter for both halves, so no way to hold a size recorded
against another run's times. That is the same fold as the state beside its step size, and as the widening
beside the step it followed: **the third instance of one recording kept in two places.**

**And the contradictory comments were hiding two features in one field.** `ode_times` means a grid a caller
wants stopped at *and* a run a caller wants replayed, told apart by whether a second container happened to be
empty — so one branch was exact and intended while the other was inexact and nobody's intention. A recording
**is** a grid that also knows its sizes, so both are one schedule and a step carrying no size is stepped *to*.
Two replay entry points become one, and the emptiness test that stood for the distinction goes.

⚠️ **Deciding per item what was decided per schedule is how the fix first broke it.** Gating the replay on
"does this interval hold a step" rather than "is this schedule pinned" agrees for every interval except one
crossed in a single step — and there the pinned branch silently became the adaptive branch, with every number
finite and plausible. The only witness was a bit-identity check that already existed. **A guarantee re-derived
from something adjacent is the failure this report exists to remove, and it is available to the person
removing it.**

**4. Manage the tape instead of rebuilding the System — measured, viable, and not taken.** Lifting the
System per recording is one construction per step, and there is a second way to get slot freshness
that costs no construction at all. `clearAll()` returns the tape's slot counter to zero;
`newRecording()` alone does not, so a scalar carried in from an earlier recording holds a slot
permanently below the counter and can never be handed out twice. **Measured on the two-species
fixture over 1, 2, 4, 8 and 16 steps: statements 90 and operations 170, flat — so `newRecording()`
does discard the previous recording's operations — and variables growing by exactly six per recording,
which is the System's own live scalars.** The leak is bounded by what the System owns, not by what the
recording writes.

**It was not taken because its correctness rests on an invariant no signature states: `clearAll()`
must never be called while a System that has recorded is still alive.** That is a condition over every
caller of that tape, it fails silently, and it is the same shape as the failures this report exists to
remove. The rebind makes the wrong thing unrepresentable instead, and that is worth one construction a
step until it is measured to matter. **The asymmetry between the two call sites is the evidence, and
both sites carry it:** where the System is lifted per recording, `clearAll()` is right; where the
lifted System is cached and outlives the recording, it is wrong, because returning the counter to zero
is what makes the carried slots alias live variables — and two consecutive gradients then disagree.

*Do, if it bites:* clear the tape once where the System is known fresh, and `newRecording()` between
recordings — then measure the derivative array's growth at production width rather than on the small
fixture, because the leak scales with the System's live scalar count and the real one is four orders
larger. **Two numbers decide it:** that growth against the 62 MiB a step recording already holds, and
the construction cost this would remove, measured as a share of a gradient rather than assumed.

*Done when:* one of the two is measured to dominate, and the loser is written down here so it is not
re-derived.

**4a. Four cost items, priced, and one open question about the rule they sit under.** *§2.1 has the
measurement; this is the list.* In descending order of what each is worth on the reference fixture:

| | what | worth | price |
|---|---|---|---|
| a | the shared-part reduction at `O(K + N)` rather than `O(K·N)` (§4.1) | 19.0% to build, plus its share of a 29.5% walk | re-associates, so a re-blessing |
| b | ~~the repeated forward run~~ (item 3a) | **taken**: 38 s per extra consumer, plus a 55 s construction run | none: a deletion |
| c | one walk at derivative width three rather than three walks (§5) | ~12% | a type change, and it deletes the seed loop |
| d | active values by `const&` (§6.1) | targets 19.4% construction and 10.9% push/pop | none: bit-identical |

**And the open question, which is about §2's rule rather than any of the four.** The rule says to tape
whatever can be afforded and to supply rows only where recording is impossible or unaffordable. Every
silent failure this report exists to remove is a hand-mirrored transpose, so the rule should not be
relaxed — but "afforded" was never measured, and measured it is ~80% of the reverse pass, three quarters
of that one reduction. Two things follow which the rule as written does not say:

- **Affordability is a property of the forward algorithm, not of the tape.** The same map is affordable
  at `O(K + N)` and not at `O(K·N)`, so the order at which a model writes a reduction is a reverse-mode
  design decision. Ranking it as a forward-model performance detail understates it by four.
- **The exception is not cheap either.** The one place the rule sends a row to be supplied costs 20.6% of
  a gradient in the row layer alone — about what the dominant taped term costs. So "tape it or supply it"
  is not a cheap-versus-dear choice; both are dear, and the case for taping is correctness, which is the
  case it should be argued on.

**What is genuinely open is whether there is a third thing to do with a reduction.** Taping it is correct
and dear; hand-mirroring it is cheap and has failed every time it has been tried here. The candidate
third is a reduction whose transpose is *derived* — a primitive owning the walk, so the forward and the
transpose are one declaration and cannot drift, the way §8 proposes for the implicit node. Whether that
is a real category or a hand-mirrored transpose with better manners is not settled here, and it should be
settled before anything is built on it.

**5. The environment's interface was half virtual and half template.** *Fixed by deletion.* One
question — what a unit reads out of the shared part — had two answer mechanisms on the base: the
**count** was `virtual`, and the two **fills** were templates, which cannot be. A base reference
therefore got the derived count and the base's identity fill, so the width was right and the buffer was
never written; the same split gave a width of zero where the fill was live.

**The reachable half needed no base reference at all, and that is why it mattered.** Because the count
is virtual, a new environment declaring it with `override` is spell-checked by the compiler. Because
the fills are templates, they are joined by name hiding alone — so an environment that overrode the
count and misspelled or omitted a fill compiled clean and inherited an identity that writes nothing.
One member of an inseparable trio was checked and the other two were not.

The three base members are gone, so the question has one answer, held by the class that knows it, and a
type that cannot answer says so at the call site with the member named. **The self-consistent defaults
beside them stay**: an environment with no integrated state answers zero width and returns every
iterator where it found it, and those two agree. It was the count that could be overridden apart from
its fill that had to go.

*And the referee could not have caught it.* The buffer is value-initialised, so a fill that writes
nothing reads exactly like one that writes zeros, and the check comparing two paths passed on two
buffers neither had filled. It now holds the returned iterator against the declared width.

**6. `growth_rate_gradient` copy-constructs a unit per element per rate call — and the scratch that
would remove it must not come back.** *Closed, as a refusal rather than a change.* The copy is real:
the sub-grid probe needs a mutable unit to perturb, and it takes one per call. Three things decide
against caching it.

It measured **within 1.5%** of the alternatives when the scratch was removed, so the prize is small.
It is **not on the gradient path at all** — the transport term calls it only on the height coordinate,
and a density in birth date changes only by mortality, which is the coordinate the reverse pass
requires. And the function has since moved down to the unit and become scalar-templated, so a cached
scratch would exist **at the active scalar** and carry that recording's slots into the next one: the
aliasing this report prices at §10 item 4, bought for 1.5% on a path no gradient runs.

**The general rule is the finding, not the arithmetic.** A cache whose lifetime exceeds a recording is
unsafe at an active scalar, and a function template gives no signature in which to say so — the
instantiation that is unsafe is the one nobody wrote down. A scratch is safe only where it cannot exist
actively: confined to the `double` instantiation, or owned by an object that is itself lifted per
recording.

*Done:* the three places that still described the scratch as present or desirable now say why it is
not.

**7. The reductions that built their own grid have been routed through the shared accessor** — §4.1's
second defect. *Fixed, and the diagnosis needed correcting on the way.*

**The sort was never the problem.** An active comparison returns a plain `bool` and records nothing, so
ordering on an active key and ordering on its passive value produce the identical permutation and the
identical tape. A comment claiming otherwise was overstating what passing the key through the value
accessor buys in a comparator: nothing.

**The differencing was the problem.** `(h₁ − h₀)` on two live scalars makes every interval width a
differentiable function of two units' state, so the reduction carried a weight derivative that the walk
it stands in for structurally cannot have — the same number with different derivatives. Two sites did
it: the fallback walk used when the ordering has broken, which never called the shared accessor at all,
and the downstream reduction's own grid, which is the site this section cites as the exemplar and which
was building an active grid immediately below a passive one.

Both now read positions through the accessor that returns `double`, so the widths are passive by return
type rather than by discipline. **Bit-identical**, and provably so rather than by measurement: the
value accessor returns the same bit pattern the active scalar carries, the negation the accessor applies
is exact, and the permutation was already decided on values. What changed is only which tape edges
exist.

**8. The container's copy is unified one level and asymmetric at the next.** There is now one map,
`assign_from`, with the rebind a line over it, and a referee that copies both ways and holds the
results against each other. But the rebind constructs through a constructor that runs `reset()` and
the assignment does not, so the two remain separately written.

**What that referee cost by arriving second is the lesson worth keeping.** Unifying the two without it
moved the trajectory columns by three orders and took three rebuilds to attribute, against the one
minute the check takes to run. For a change that asserts two things are equal, the check that they are
is the change's own premise — writing it afterwards means testing the premise with the twenty-minute
instrument instead of the one-minute one.

**9. A resumed run that also grows at its initial time would seed the wrong read point.** It widens
before its first step, and the seeding at the active scalar would carry the boundary's first
evaluation where the run carried the second. No fixture reaches it, because the one resumed fixture
grows later than its initial time. It lives in the model's own seeding, not in the walk, and **it
wants a fixture before it wants a fix.**

## 11. The standing qualification, which none of the above removes

The insertion schedule is refined by bisecting on errors that depend on the parameters, so the
schedule is a function of the parameters and the reverse pass treats it as constant. **Every gradient
this machinery produces is a partial derivative at a fixed discretisation.** That is defensible and it
is not what a reader assumes. Nothing in the code can check it, so it belongs written beside any
number the machinery produces.
