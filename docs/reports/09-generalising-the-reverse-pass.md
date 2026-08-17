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
That is roughly *one* unit block's tape. The reduction is not what is expensive; the supplied-row
assembly is, and §8 is the one place the rule's second clause bites.

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

**Two defects live on the unsupported branch.** Both are the shape report 05 §6.1 warns about — a
wrong transpose parked where no fixture reaches it:

- **The closing interval's transpose writes only one end.** The interior loop emits the
  position-derivative term at both ends of every interval; the closing interval emits only its upper
  end. The slot is live and feeds a real accumulator.
- **The reductions disagree about what a grid is.** One of them never uses the shared coordinate
  accessor; it builds its own grid twice, and on the unsupported coordinate that grid is **active**
  while the others are frozen — so its tape carries a weight-derivative term the others structurally
  cannot have. The coordinate refusal is *a fence around that inconsistency, not a fix for it*, and
  the same file states the opposite rule elsewhere and obeys it there (§10 item 8).

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

## 9. The replay pass

A pass in which part of the state is supplied rather than integrated, because it is exogenous *on that
pass*.

```
concept Replays = requires(System s, std::size_t step, int stage, const_iterator in) {
  s.replay_step(step);          // restore that step's record
  s.set_ode_state(in, stage);   // load state against a recorded stage
};
```

Two members, and three deliberate absences.

**No mode query.** Whether a pass replays is the **driver's**, not the System's, and it is not a
property of the type either. The driver counts the steps and knows which pass it is running, so it
takes the branch itself rather than asking the System every stage. This is the difference between a
resident gradient that *cannot* accidentally replay and one that silently returns a gradient with the
water feedback missing — finite, plausible, and with no error raised.

**No time lookup.** The step is handed in. Recovering it by searching the record for an exact float
match needs a cursor, a sequential fast path and an abort when the time does not round-trip; the
driver already has the index.

**No "field" in the name.** The replayed object is a derived field AND the states it was integrated
from, which are ODE state. The state half is the one that matters: a System replaying part of its
state asserts that part is exogenous on this pass, and therefore that **its adjoint through that part
is zero**. That is a modelling claim, not an optimisation, and it is why this is not a cache.

**The payload differs by pass, which is where the saving is.** A resident integrates the shared
resource because the balance is endogenous. An invader responds to a resource it does not move — so on
that pass the resource is supplied rather than integrated and leaves the state vector. The two passes
run states of different width, which is a fact about the model and not a detail of the record.

**One caution on the flag that switches the pass on.** It does two jobs — *use the supplied resource*
and *this is an invader: compute no boundary node, build no field, feed nothing back*. Only the first
is what a replay hook replaces; most of the sites testing that flag are the second job and stay.

## 10. What is left

Items 1 to 3 are the design's remaining construction; 4 is a measurement; 5 to 9 are defects and
residues found beside it. **Items 1, 2 and 3 and support for a second model are deferred**, so the
live work is 4 onward.

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

**3. The replay pass, which is the only way an invasion run exists at all.** *Deferred.* The model's
second recorder is deleted: the per-stage cache it kept was reached through three hooks the solver had
stopped calling, so the container was never filled and the entry point refused on its first statement
for every model, always — §7's hazard at full size. The entry point survives and refuses with an
accurate message; its test keeps its expected fitnesses and skips, because those numbers are the
specification for what replaces it.

*Do:* implement §9's concept on the model's container and drive it from the solver.

*Done when:* the concept is satisfied and a `static_assert` says so at the point of use, so the hooks
cannot go quiet a second time; the test stops skipping and meets the numbers it already carries; and
the mode cannot be set by anything but the driver.

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

**5. The environment's interface is half virtual and half template**, and a caller holding a base
reference gets a silent no-op and a width of zero rather than a diagnostic. The two halves answer the
same question about the same object, so which one a call site reaches decides whether it works, and
nothing states which. This is §7's boundary problem one level in.

*Done when:* one mechanism answers it, or the base refuses at compile time what it cannot do.

**6. `growth_rate_gradient` full-copy-constructs a unit per element per rate call on the forward
path**, having lost the thread-local scratch it used to reuse. It is a forward-path cost paid by every
gradient, and it is arithmetic-free — the fix is a scratch object, not a derivation.

*Done when:* the copy is out of the loop and the forward suite is bit-identical.

**7. The unordered reduction walk still sorts and differences on an active key** — §4.1's second
defect, live. The same file states the opposite rule elsewhere and obeys it there, which is what makes
this a slip rather than a decision.

*Done when:* the key is passive by return type, as §4.1 says the coordinate is.

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
