# Generalising the reverse pass: the missing rung, and the concepts it deletes

The stand-scale reverse mode is correct on the birth-date coordinate and it cost more code than it
should have. This report says **why** it cost that much, which is a structural answer rather than a
matter of effort, and what to build so the next model does not pay it again.

Reports 00 to 08 state what the derivatives are and what a correct implementation must satisfy.
This one is about where the code that satisfies them **lives**, and it makes one claim:

> **The engine offers two ways to get a gradient and nothing between them. Every line the project
> is unhappy about is the cost of the gap.**

The reading is of `plant` at `5a5e3984`, `odelia` at `0a2e26b` and `phylloptim` at `9c61fd9`.
Two facts about that tree belong at the top because they gate everything below (§7).

---

## 1. The two routes, and the cliff

**Route A — tape the trajectory.** A System declares a forward pass — `set_ode_state`,
`compute_rates`, `ode_state`, `ode_rates`, `ad_parameters`, `rebind_from` — and
`compute_jacobian` records the whole run and sweeps it. The author writes no derivative code at
all. `CanopySystem` is the demonstrator and it is 235 lines, of which none are adjoint.

**Route B — satisfy `AdjointRates`.** The System supplies `ode_rates_adjoint(λ_dydt, λ_y)`: the
transpose of its own right-hand side. odelia then owns the Runge-Kutta stage recursion and the
segment sweep, and **the entire interior is the System's.**

Route A is what a strategy author should meet and report 01 §0 rules it out: peak memory is the
whole recorded computation, which for a stand at production lifetime is hundreds of gigabytes.
So `plant` takes route B, and route B's contract begins one level too high. `AdjointRates` asks
for the transpose of the whole right-hand side, and the right-hand side of a patch is a
population coupled through two reductions. There is no smaller thing the System may declare.

**That is the cliff, and it is the whole finding.** The gap between "write a forward pass" and
"write the transpose of a coupled population" is roughly 1,200 lines, and `plant` wrote them.

### What the interior actually is

`Patch::ode_rates_adjoint` is 65 lines and is report 01 §1's forced ordering, named:

```
soil_adjoint          (a) environment transpose, seeds every cohort's uptake row
offspring_adjoint     (a) an output that reads a state, not only a rate
cohort_block_adjoint  (b) per cohort: record, seed, sweep, release
light_knot_adjoint    (c) knot adjoints -> size space
allometry_adjoint     (d) size space -> state and traits
boundary_condition_adjoint  the inflow boundary, which report 01 does not name
```

**The schedule is right and should not move.** The ordering is forced, the code says so, and the
four coordinate conditions of report 05 §6.1 all hold. What is wrong is that every one of those
six is a hand-written member of a class that names its own environment's fields.

---

## 2. Where the lines are

| bucket | lines | where |
|---|---|---|
| general, already in odelia | ~480 | `step_adjoint`, `solve_adjoint`, `vector_jacobian_product`, the concepts |
| general, stranded in `plant` | ~325 | trajectory store, narrowing, widening, the segment loop, the introduction VJP |
| **model-shaped — the target** | **~1,225** | the six interiors, the two reduction transposes, the block interface, the census seeds |
| genuinely TF24 | ~128 | retention derivative, seed geometry, the coordinate branch |

Within the model-shaped bulk the concentration is stark. Three functions —
`cohort_block_adjoint` (135), `boundary_condition_adjoint` (110) and the light reduction transpose
(89) — are a quarter of it. And in `tf24_strategy.h`, **a 389-line hand-assembled Jacobian of a
sub-model the strategy does not own** is the single largest artefact in the file: **810 of 2,300
lines are AD scaffolding — 35% of the file, 40% of the code.** The independent measure agrees: the
strategy went from 1,426 lines split header/impl to 2,300 header-only across this branch, **+61%**,
and templating forced every definition into the header so every translation unit now compiles the
whole model.

The undifferentiated DX is already good. K93 is 330 lines of C++ and ~250 of that is biology.
**All of the cost is the AD delta**, and none of it is visible to the scaffolder, which has no
notion of `ad_parameters`, `rebind`, or a scalar template parameter.

---

## 3. Two idioms, and only one of them can drift

The codebase already contains the answer to its own problem, applied unevenly.

**Derived by tape.** `census_state_adjoint`, `census_trait_direct`, `boundary_condition_adjoint`
and `introduction_adjoint` each record their forward map at an active scalar and call
`vector_jacobian_product`. A transpose obtained this way **cannot** disagree with its forward,
because there is only one function.

**Hand-mirrored.** The light reduction, the water reduction, the allometry pull-back and the soil
cascade are written twice — once forward, once transposed — and held together by a comment:
*"Mirrors compute_competition_and_slope_impl term by term: the same early exit, the same closing
trapezium, the same node order."*

The mirrored half is ~440 lines transposing ~400 lines of forward reduction. **The transposes are
larger than the code they transpose**, and there are at least twelve places where the two can
silently diverge: the early-exit condition, the closing-trapezium predicate, the short-circuits,
the soil positivity guard with its NaN-safe form, the infiltration clip, two independent
`∂ψ/∂θ`, the crown kernel's height derivative, and the four hand-kept layouts of the block's
input vector.

**This is not an argument that the mirrors are wrong.** They are checked, and they pass. It is an
argument about what the next model inherits: a mirror is a promise renewed by hand at every edit,
and the promise is not transferable.

---

## 4. The missing rung

Between "declare a forward pass" and "declare the transpose of a population" there is one honest
intermediate, and it is the structure `plant` already has:

> **A System declares that it is a population of units coupled through shared fields by reductions.
> odelia owns the blocked reverse pass over that structure.**

Everything needed is already written, in the wrong place or in a shape only one caller can use.

### 4.1 The block interface — promote it

`Individual::block_inputs / set_block_inputs / block_outputs / block_input_size` is 61 lines and
is the best abstraction in the codebase: a complete, model-agnostic statement of *a unit's rate
function as a pure function of its own boundary*. Both the sweep and the forward-tangent reference
drive it identically. It is exactly what report 01 §2 defines as the unit.

It should be odelia's, and it should stop being flat. `vector_jacobian_product` takes
`vector<double>`, so every caller writes a pack and a matching unpack — **133 of
`cohort_block_adjoint`'s 135 lines are that**, and the retention chain factor `∂ψ/∂θ` is smuggled
into the unpack loop. A block that declares its input *segments* — own states, field reads,
environment reads, parameters — lets the primitive do the scatter, and the four hand-synchronised
layouts collapse to one declaration.

### 4.2 The five nouns odelia does not have

odelia has the hard algorithms and none of the vocabulary. A parameter row has no route out of
`ode_rates_adjoint(λ_dydt, λ_y)`, so `plant` made the trait accumulator a mutable member of the
System that the driver clears and reads around a sweep — an out-of-band channel odelia cannot
check. Report 01 §6's failure signature, *a gradient that is a fixed fraction of the right answer
with the correct sign and no error raised*, is unpoliceable by construction.

| noun | what it is | today |
|---|---|---|
| **parameter adjoint** | a trait row's route out of a transpose | a mutable System member, five writers, four defensive re-zero guards |
| **seed** | `∂C/∂y` at `T`, a functional's transpose | `census_state_adjoint`, `plant`-side |
| **reduction transpose** | trapezium over a passive abscissa, with its own parameter rows | written five times by hand |
| **refusal** | a gradient-validity channel, metric-level | **does not exist in C++ at all** |
| **graft** | `v + Σ ∂v/∂uᵢ·(uᵢ − passive(uᵢ))` | written **four** times |

Add these five to `ode_interface.hpp` and `gradient.hpp` and the interior stops being prose.
Adding the parameter channel in-band is the one that matters most: it turns report 01 §6's silent
scaling error into a length mismatch.

### 4.3 The reduction primitive

Strip the biology and the light reduction, the water reduction and the census are one object:

> Given grid points `k = 0…n` (the cohorts, then the boundary node), a **passive** abscissa `xₖ`,
> a per-point contribution `fₖ = nₖ · φ(stateₖ, traits)`, and passive predicates deciding where the
> sum stops and whether the closing interval is taken — form `Σ wₖ fₖ` with `w` the trapezium
> weights of `x`. The transpose scatters with the same weights, the same stopping point, the same
> predicate, and the weight-derivative term **only** where `x` is active.

Give the driver the predicates and report 05 §6.1's four coordinate conditions stop being
conditions and become properties: (1) and (2) fall out of `abscissa` being `double` by type, (3)
and (4) fall out of the driver owning the guards. A condition that cannot be violated needs no
test and no reviewer.

Make the codomain a template parameter and a second family goes with it: the value-only and
value-and-slope walks are the same walk with a component dropped, written twice more, plus their
two unordered variants.

---

## 5. What gets deleted

Great abstractions are measured in concepts removed, not lines saved.

| delete | why |
|---|---|
| `supplied_derivative.hpp` | **zero production consumers** anywhere. The construction `plant` needs is the other one |
| three of four grafts | `implicit_value`, `supplied_derivative`, `record_with_derivatives`, `hermite_interpolator::graft` are one idea. Only the `plant` copy has the finiteness guard report 05 §8 says the construction *needs* |
| `node_size_adjoints`, `node_uptake_adjoints` | structs of **named** slots. `k_I` got a row by *adding a field*; `η`, `a_l1`, `a_l2` each want another, plus two hand-written partials apiece |
| `light_reduction_slots` | the right idea named for one reduction. Generalised, it serves the soil parameters that today have nowhere to go |
| four competition walks | value / value-and-slope × ordered / unordered — one reduction with a codomain parameter |
| five trapezium transposes | one driver, three integrands |
| six copies of the species×(nodes+1) walk | an iterator yielding `(slot, optional<state_row>, trait_base, node&)` |
| six copies of "seed traits before state" | one recorded map |
| the four parallel `lt*` arrays | values, addresses, seeded flags and zero-at-interior flags, keyed by position to a **fourteen-argument** `set_traits`. The signature has already grown once; `phylloptim` declares thirteen traits and TF24 hardcodes fourteen. Report 02 §4 item 4's exact failure shape, live |
| `gradient::Status` | four values derived **from residual magnitude**, which report 05 §7.0 forbids. `OperatingPointKind` is the correct ten-branch decision tree, sitting beside it, unused by the gradient entry point |
| the five `dcollar_d*` vectors in `record_leaf_outputs` | see below |

That last row is the strongest single piece of evidence that the primitive is missing, and it is
worse than a duplication. **TF24 does not use the rank-one collapse at all.** It forms
`∂p*/∂u` explicitly for every input family — light, conductance, root carbon, the fourteen leaf
traits, each soil potential — and multiplies each into every layer's row: an
`n_layer × (2 + n_layer + 14)` product. That is precisely the outputs-by-parameters matrix report
02 §3.2 says is never formed, and it is ~200 lines.

The leaf *already exposes* the collapse. Its consumer could not use it, because `transpose_at`'s
output set is the calibration's five and not the stand's per-layer uptake — so the consumer rebuilt
the argmax machinery from scratch. **Report 02 §3.0's warning, realised exactly:** the output set
was enumerated from what the solver exposed rather than from the consumer's equations, and nothing
detected it, because the absent output has no column.

---

## 6. The implicit-node primitive

`phylloptim`'s `gradient.hpp` is the implicit-node pattern written once against one model's
fifteen-wide parameter vector, and `tf24_strategy.h`'s `record_leaf_outputs` is the same pattern
written a **second** time against the same model. Neither is hydraulics. What is hydraulics —
vulnerability curves, the incomplete-gamma integral, Ohm's law over a layer network — is already
cleanly separated in the forward direction. The derivative direction has no such seam.

The general node, read off what the code actually consumes:

1. `solve(u) → {p*, kind, y}` with **classification by branch taken**, reset per solve, read-only.
2. `residual(p; u) → (value, feasible)` — feasibility as a **separate channel, never a sentinel
   value**. `phylloptim` proves the point: the flag exists, defaults to `nullptr`, is dropped by
   the R binding, and every consumer that cannot see it re-derives it by exact-zero comparison.
3. curvature, with the same feasibility channel per arm.
4. an output declaration: which output **is** `p` (p-channel exactly 1), which **is** the
   objective (p-channel exactly 0 — the envelope theorem), which are ordinary.
5. `∂y/∂p`, `∂y/∂u|_p`, `∂R/∂u` — analytic where available, differenced at held `p` otherwise.
6. `∂B/∂u` per bound, with which bound is active. **Absent from `phylloptim` entirely.**
7. **An amplification ceiling on `|m| = |s|/|Π_pp|`**, refusing the non-objective rows and emitting
   the objective row regardless. Report 05 §7.0 is explicit that the guard belongs here and not on
   the curvature; `phylloptim` guards `Π_pp < 0` and forms no ceiling, so near a fold it returns a
   large finite number.
8. a factorisation hook — declare the basis, let the primitive recover the scalars from a
   nominated anchor direction.
9. the graft, with its finiteness pre-test.
10. a transpose-identity harness, so a new node gets `⟨v, Ju⟩ = ⟨Jᵀv, u⟩` for free.

Item 10 is what makes the rest affordable. That identity needs **no reference gradient and no
differencing** — it is a property the transpose either has or does not — and it already holds to
`1.4e-14` over 294 operating points. A primitive that ships it gives every future node the one
check that cannot be faked by internal consistency.

### 6.1 The cheapest branch has never been run

**TF24f is not on the gradient path at all.** It is templated on `S`, but its tracked collar
potential is passed into a `double` evaluation and clamped against `double` bounds, so it does not
compile at an active scalar — and no export instantiates it.

That is worth stopping on, because TF24f is the variant that **has already dissolved the argmax**.
Report 00 §4.7: the collar potential is an ODE state, so its derivative arrives from the adjoint
ODE for free — no implicit-function solve, no stationarity condition, no `Π_pp` to divide by, no
five kinds of point. A tracked state needs no `record_leaf_outputs` at all. It needs `∂Π/∂p` at a
*prescribed* point, which the leaf already returns, and the ordinary adjoint the engine already
runs.

So the question the ordering below has to answer honestly is which is worth more: generalising a
389-line argmax node, or making differentiable the variant that does not need one. The second is
smaller work and it exercises case X, which report 05 §7.0 lists among the states the gradient is
**not** valid at and does not refuse. It is not a substitute — TF24 is the reference and the
argmax node is what the reference needs — but a primitive designed against only the hard case will
be shaped by it, and the tracked-state case is the one that says what the *general* interface is.

---

## 7. Order, and the fences that are still standing

You do not get to move a fence until you know why it is there. Four are still there.

**1. `plant`'s branch tip does not build.** `5a5e3984` calls `dmarginal_profit_duptake_slope`,
`roots_.duptake_droot_carbon` and `grad::profit_env_derivatives`; none exists in any `phylloptim`
ref available here. The superproject's pointer at `b78cff21` is the last plant commit that
compiles against the phylloptim it records. **The `phylloptim` half of the root-carbon anchor is
unpushed.** Nothing below can be validated until it lands.

**2. The light reduction has no isolated referee.** `ladder_light_reduction_adjoint_tf24` is
written and exported and **called by no test**. The light transpose is refereed only *through* the
composed right-hand side, where a cancelling pair of errors passes. Wiring it is an hour, and
refactoring a transpose whose only check is composed is refactoring without a net.

**3. `b` is unchecked in the direction that decides the answer.** The factorisation residual runs
over the soil potentials only — which report 05 §7.3 says is precisely the family that *cannot*
detect an error in `b`, because the vectors are collinear and a compensating pair fits every row.
The root masses and leaf area are unrefereed. Report 08 §3.1 prices this: a one percent error in
`b` is a fifteen- to twenty-six-fold error in the uniform-drying direction, and it sits in the
sweep **and** in its reference.

**4. The transposes themselves are fixed.** All four coordinate conditions hold; report 05 §6.1's
"repair before you extend" is discharged. **This fence is down**, and it is why generalisation is
the next move rather than a competing one.

Then, in order:

1. **Carry the seed-height closure outward.** Report 05 §10.1's eight declared-zero rows are
   **already closed** at plant's tip: `seed_geometry()` recovers the row with `implicit_value` on
   `mass_live_given_height(y) − omega`, and `set_initial_states` writes it. It took one call to a
   primitive that already existed — **which is this report's thesis demonstrated rather than
   argued.** FF16 still freezes its birth size at preparation and still has the defect. The work is
   not to close it again; it is to make the closure the interface, so a strategy cannot declare a
   solved quantity `double` by accident.
2. **One trait registration list.** `ad_parameters()` and `ad_parameter_names()` are 47 addresses
   and 47 strings paired by position with no guard, and they are the input to the column naming
   report 05 §9 warns about.
3. **`at_scalar` should assert `rebind<double>` is the strategy itself.** `TF24f` inherits
   `rebind` from `TF24` and so resolves to a strategy with six states instead of seven, silently
   dropping its tracked potential. Latent only because no export names TF24f — and inheriting
   `rebind` is exactly what the documented "write a variant strategy" recipe produces. Three lines,
   caught at compile time, for every strategy, forever.
4. **The parameter channel in-band**, then the block interface, then the reduction primitive.
   Design the implicit node against **both** TF24's argmax and TF24f's tracked state (§6.1), or the
   interface will be the hard case's shape rather than the general one. Whether TF24f is made
   differentiable first is a modelling call, not a refactoring one.
5. **Refusal.** `census_trait_gradient` returns `vector<vector<double>>`; report 08 §9's
   requirement that an undefined metric be distinguishable from a zero one is **not representable
   in the return type**, and no adjoint-path code tests finiteness. This is a type change, and it
   is cheaper before the interiors move than after.

---

## 8. Two costs the design does not currently price

**`boundary_condition_adjoint` records a whole-patch tape in the innermost loop.** It rebuilds the
65-knot field over every cohort at the active scalar and runs a full seed-size physiology per
species, once per stage per step per metric. Its skip guard only fires on a stand with no boundary
sensitivity. Report 01's "peak is one cohort" is true of the cohort block and false of the stage.

**`ȳ(0)` is computed and discarded.** The last narrowed adjoint is overwritten by the trait read on
the next line. That is report 05 §10's sixth path — zero-valued on TF24 because the first recorded
state is soil-only, live for any model whose initial state reads a trait.

**The supplied rows are ~36 leaf re-solves per block.** Five families inside `record_leaf_outputs`
are finite-differenced — the curvature, the root-carbon anchor, conductance, twelve leaf traits and
radiation — and a leaf trait's difference rebuilds the vulnerability grid each time. Against one
evaluation for the forward pass, per node per stage per sweep. The differencing is deliberate and
the reasoning behind each step size is sound; what is unpriced is the total.

**Each block copies the whole strategy, `Leaf` and vulnerability splines included.** The forward
path shares one strategy across every cohort of a species; the reverse path constructs a fresh
`shared_ptr<active_strategy>` per node per block. That is the right answer to report 01 §3's
purity requirement — it is what makes the permutation check pass by construction rather than by
discipline — and it is a per-node allocation nobody has measured.

---

## 9. What would falsify this

- **The interiors are not model-shaped.** If a second strategy with an inner solve needs a
  materially different schedule — not different kernels, a different *order* — then the six-step
  interior is TF24's and not a primitive. The cheapest probe is FF16: it has
  `compute_competition_and_slope` and no transpose at all, so ask what its `ode_rates_adjoint`
  would have to be.
- **`Patch` cannot be made generic over `E`.** The reverse half names
  `light_availability.knot_count()`, `get_soil_number_of_depths()` and
  `dpsi_from_soil_moist_dtheta()`; `FF16_Environment` has none of them, so the whole reverse half
  fails to instantiate on any other environment. **If reductions cannot become a declared list the
  environment publishes, the primitive cannot live in odelia at all** — this is the precondition
  for everything in §4.
- **The reduction primitive does not cover the census.** The census is already transposed by tape
  with no hand transpose. If the driver cannot express it, it is not the general object.
- **Blocking is not what costs the memory.** Report 01 §8 asks for the per-cohort recording size at
  production width and two target counts an order apart. `block_recording_size` and `block_sweeps`
  are instrumented and, as far as this reading goes, unreported.
