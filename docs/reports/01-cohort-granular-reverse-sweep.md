# Cohort-granular reverse-mode gradients

Reverse-mode AD must hold a complete tape before it can walk it backwards, so peak memory is the
whole recorded computation. For a stand at production lifetime that is hundreds of gigabytes, and
no amount of making the recording leaner closes a gap of that order.

This report states the decomposition that removes the problem. It does not make the recording
smaller; it changes what a recording *is*.

> **Store the trajectory in plain `double`. On the reverse pass, record and sweep one cohort at a
> time.**

Report 00 §2 is why this is possible; report 05 §4 and §5 are the algebra of the step and the
segment; this is the decomposition, its ordering, and what it demands of the model it decomposes.

---

## 1. The decomposition

The reason it works is a property of the model rather than of any implementation. Within one
Runge-Kutta stage every cohort influences every other **only** through two shared objects. So the
per-stage computation is four layers, and the middle one is thin:

```
     y  =  cohort states  +  environment states
     |
ALL  |  per cohort, independent, closed form   (allometry: leaf area, density)
     v
LGT  |  ONE reduction over all cohorts, then an interpolant   (the light field)
     v
RAT  |  per cohort, independent, EXPENSIVE     (rates; for TF24, the leaf solve)
     v
SOIL |  ONE reduction, then the soil           (uptake -> soil rates)
     v
    dydt
```

The reverse pass runs those four layers backwards in a strict order with **no circular
dependency**, and this is the point that had to be settled before the design was viable. The graph
looks circular — RAT's sweep needs the light adjoints LGT produces, and LGT needs the light
adjoints RAT produces — and it is not, because ALL is a *separate closed-form map*, adjointed
analytically rather than on a cohort's tape:

```
given λ (the adjoint of y at the end of this step)

  a   the closed-form seeds -- everything a block's outputs need before it can be swept:
        SOIL adjoint  -> λ_soil, and λ_uptake for every cohort
        offspring     -> a direct mortality adjoint
        transport     -> λ_g for every cohort   (height coordinate only)
  b   for each cohort j:  fresh tape; record ONLY cohort j's rates; seed its output
                          adjoints from (a) and from the stage recursion; sweep once;
                          read off λ_states, λ_knots, λ_ψ, λ_traits; RELEASE the tape
                                                     <-- PEAK IS ONE COHORT
  c   LGT adjoint   -> λ at the field's knots -> λ_(leaf area, density, height)
  d   ALL adjoint   -> λ_y_j (field contribution)   closed form
  e   λ_y_j = direct + field
```

Step (b) holds all the expensive arithmetic and its tape is released before the next cohort's is
created. Steps (a), (c) and (d) are linear or closed-form maps whose adjoints cost what their
forward evaluation costs.

**Every part of (a) is a seed, which is why they are one step.** A block cannot be swept until
every one of its output adjoints exists. The soil adjoint supplies the uptake rows; offspring
supplies a mortality adjoint directly, because it reads that *state* and not only a rate; and on
the height coordinate the transport stencil supplies each cohort's growth-rate adjoint, because
there a cohort's growth feeds its neighbours' density rate as well as its own. Only the remaining
rate adjoints come straight from the stage recursion. **The ordering is forced, not chosen** —
placing the transport term after the blocks would seed them with an adjoint that does not yet
exist.

### Three properties make this worth doing

**Peak is flat in run length and in the stage count.** The tape is one cohort's rates at one stage,
so six stages means six sequential tapes of the same size rather than one six times larger. A
whole-run tape is linear in step count and multiplies by the stage count; this does neither.

**Peak is flat in the number of differentiation targets.** Seeding more traits adds registered tape
slots, not recorded operations — the arithmetic of one cohort's rates is identical whether one trait
is seeded or all of them. Only the trait accumulator grows, by one double per trait. **Time is flat
in the target count too**, because a reverse sweep's cost scales with the number of output rows
rather than inputs. That is reverse mode's central property and the decomposition preserves it
intact.

**No new vocabulary reaches a strategy author.** The cohort's rate function is recorded exactly as
it already stands; the decomposition lives entirely in the gradient driver.

### What it costs

A stored plain trajectory, and a doubling of the plain-`double` work: the backward pass rebuilds
stage states by re-running the step in `double` rather than storing them, so each stage is evaluated
once forward and once again on the way back. Each (stage, cohort) pair is then recorded and swept
exactly once. **Storage is independent of the stage count**, which is what makes rebuilding
preferable to storing.

### What it depends on

That a cohort's rates are a pure function of that cohort's boundary. §3 is that requirement in
full. It is a property of the model, it has been broken more than once by shared solver state, and
nothing structural defends it.

---

## 2. The unit and its boundary

### 2.1 What is inside the block

The block is **one individual's physiology**, and that is narrower than the demographic equations.
Its inputs are the cohort's own states, the light field's knot values and slopes, the soil
potentials, and the traits; its outputs are the strategy's rates, the density rate, and one uptake
per layer. Report 05 §5 states both vectors and their counts.

Three boundary decisions, each of which was wrong in an earlier reading:

**Density is not an input.** The cohort's rate function never reads it. Density reaches the world
one level up, through the two reductions.

**The density rate *is* an output.** The block's contract is that it reproduces the node's rate, and
the node's rate is the density rate. On the height coordinate that costs the block a second,
displaced physiology evaluation; on the birth-date coordinate it is mortality alone, already
computed.

**The growth rate is not a separate output.** It is one of the strategy's rates, and counting it
again double-counts it.

### 2.2 The coordinate decides the block's rank as well as its cost

On the birth-date coordinate the density rate is mortality alone, so the block makes **one** query
of the light field, and every one of its outputs depends on the field through the single scalar the
physiology receives. The field block is therefore **rank one**: `12 + 2K` numbers rather than
`24K`.

On the height coordinate the density rate evaluates the physiology a second time at a displaced
height, and that evaluation makes its own field query at a different position — under mean light, an
integral to a different upper limit, which is not a multiple of the first. **So the block has rank
at least two there, and more under Richardson extrapolation.** The coordinate choice buys the
factorisation as well as the solve, and report 05 §5.1 and §5.2 carry both.

### 2.3 Preparation must not run inside the block

Deriving a strategy's dependent quantities builds the leaf's interpolators and runs the seed
height's root-find. Doing that per cohort per stage is millions of each, and it does not need to:
the interpolators and the quadrature rule are passive, the crown constant is one closed-form line,
and the seed quantities are read by the birth path rather than the rate path. Preparation is
resolved once per gradient evaluation.

---

## 3. Is the cohort a legitimate unit?

The decomposition is valid only if a cohort's rates are a pure function of its own state, the
environment values it reads, and the traits. If information carried from one cohort to the next,
re-running one cohort in isolation would not reproduce the forward pass.

**The risk is concrete and structural.** Every cohort of a species holds a pointer to the same
strategy object, and therefore to the same leaf. Anything that object remembers between calls is a
channel the reverse pass cannot see. Three shapes of failure have all occurred:

- **A buffer sized but not cleared.** A resize whose fill reaches only new elements, written only as
  deep as the plant has roots, leaves the previously solved plant's values in the layers below —
  billed to the water balance, and read by the sweep as this plant's.
- **An exit that writes part of an operating point.** A shutdown path that sets three members and
  leaves a fourth stale attributes one plant's uptake to another.
- **A cache keyed on less than it depends on.** A cache whose key omits a parameter is correct
  exactly while that parameter is constant, and a differentiation target is by definition a
  parameter someone intends to vary.

All three are now closed in the forward model, and the value of listing them is that **none of them
is detectable by a re-run.** The forward pass is order-deterministic, so a stale read reproduces
exactly, and every double-valued test passes. The check that catches them is a **permutation**:
solve a census of states in different orders and require every output to be bit-identical. That is
the only check a reordering can fail and a re-run cannot.

Separately, and at a different level: the *stage* is a pure function of `(y, t)` only once the
field's dependence on the boundary node is resolved within the stage rather than carried from the
one before. That is a property of the patch, not of the cohort, and it does not touch the choice of
unit — but it is what lets the trajectory store one state per accepted step and lets the reverse
pass rebuild stage states by re-running.

---

## 4. The inflow boundary

The field's reduction integrates from the boundary node, so the field is a functional of the state
**and of the boundary condition**. That condition is a flux.

**In the mathematics it is standard, and it is one term.** The size-density equation closes with a
recruit flux `B(t)`, so on the height coordinate `n(x_b) = B / g(x_b)` and on the birth-date
coordinate `n(x_b) = B`. The division is not an artefact: it converts a flux, which is what the
ecology measures, into the density the state happens to store.

The reverse-mode treatment follows from the direction of time. The adjoint of an advection problem
runs backwards, so **the forward problem's inflow boundary is the adjoint problem's outflow
boundary** — and an outflow boundary needs no condition. The boundary enters the gradient as the
adjoint at the boundary times the boundary condition's own derivative. No extra adjoint equation, no
boundary data.

**What it is not is parameter-only.** The establishment probability runs a full physiology
evaluation at birth size, so it reads the light field and the soil, and therefore depends on every
other cohort's state. Both halves of that derivative are required: the half through the recruit flux
and, on the height coordinate, the half through the growth rate at birth size.

**And the seed is taken in `n`, not in `ℓ`.** Report 05 §5.3 gives the reason — at a marginal
recruit `∂ℓ/∂P` diverges while `∂n/∂P` tends to zero, and the census carries `n` linearly, so the
finite answer is reached by seeding the quantity that has one.

---

## 5. Introductions, where the state changes dimension

An introduction widens the state, so the adjoint is not a single backward solve over a fixed space
but a sequence of backward segments, each narrower than the one after it. Report 05 §4.1 states the
boundary condition and its three channels; three structural requirements belong here.

**A width alone under-determines the narrowing.** The state is species-major, so introducing into
one species shifts every later species and the environment by one node stride. A narrowing
implemented as a truncation of the tail is wrong for every species but the last, and the argument
has to be a per-species list.

**The newcomer's rows are contracted, not dropped.** Dropping them narrows the width just as well
and returns a gradient that is finite, correctly signed and wrong — the worst available failure
shape. Recording the boundary condition at an active scalar and taking one vector-Jacobian product
delivers both terms of the two-term derivative plus the state channel, rather than hand-writing
them.

**The pre-step states must be rebuilt.** The states each segment's first step ran from are not part
of the recorded trajectory, so the run must replay every introduction forward to recover them, and
again afterwards to leave the system repeatable.

**And an empty segment list is not an insensitive stand.** It is a sweep that never ran, and the two
must be distinguishable.

---

## 6. Two accumulators, and the failure they share

Two of the four destinations of a cohort sweep accumulate across cohorts, and both are load-bearing
for the same reason: **one trait is one input read by every cohort, and one knot value is one input
read by every cohort whose crown spans it.**

Because the strategy is shared, a single trait is one input, not one per cohort. Treating each
cohort as a distinct input instead yields a gradient that is a **fixed fraction of the right
answer, with the correct sign and no error raised.** That is the signature to test for, and it is
the same shape for the knot accumulator.

**Nothing in a size-space adjoint can carry a parameter row.** A reduction transpose that writes
through a structure holding only size and density slots has no route to a trait accumulator, however
correct its arithmetic. Report 05 §6.1 and §10 give the consequence: the light reduction's four
parameter rows and the water reduction's parameter half fail for the same structural reason rather
than by coincidence, and closing it is a question about *where the accumulator is*, not about the
derivative.

---

## 7. What this asks of a strategy author

The design's claim is that it adds no vocabulary to the *engine*. It does impose requirements on how
a model is structured, and they are held by discipline rather than by the type system.

**1. Per-cohort state belongs in the cohort, and nothing may carry between cohorts.** The reverse
pass re-runs one cohort in isolation, so anything the forward pass left on a shared object and read
back is invisible to it.

**2. Shared mutable members are a liability, and the safe pattern is write-before-read.** A member
read before it is written in the same call is a cross-cohort channel, and no re-run test would catch
it (§3).

**3. A cache must be keyed on everything its value depends on, or not exist.**

**4. Narrow the environment interface.** The cost of differentiating a cohort scales with how many
environment values it reads. A strategy that read the whole environment, or queried it at
state-dependent points chosen by a search, would be materially more expensive.

**5. Expose an inner solve's *residual*, not its *search*.** Report 02 §1.

**6. Never define a rate as a numerical derivative of an active quantity.** A finite-difference
stencil can be a legitimate discretisation — the one-sided height difference is the upwind form of
the advection term — but evaluated in plain `double` on a differentiated path it silently drops the
channel it discretises.

**7. Say whether a switch is a kink you mean.**

**8. Fixed quadrature rules are structure; adaptive ones are not.** A rule that places nodes as a
deterministic affine function of its bounds tapes correctly at an active bound. A rule whose node
*count* depends on an active value makes the recorded computation state-dependent — and the same
applies to an interpolant whose knot count is chosen by a refiner.

---

## 8. What would falsify this

Stated as checks rather than arguments, so the answer is a number.

- **A cohort's rates are not reproducible from its boundary.** Re-run one cohort from stored state
  plus stored environment reads and compare bit for bit; then permute a census of states and require
  the same. Any difference locates a carried quantity, and §3 says where to look.
- **Peak does not stay flat.** Report the per-cohort recording size at production width and lifetime,
  and at two target counts an order apart. Growth in either says the unit is not what §2 claims.
- **Trait adjoints do not accumulate.** A gradient that is a fixed fraction of a reference, with the
  correct sign, is the signature (§6).
- **The stage traversal loses a term on a dense tableau.** A recursion written against a tableau
  where each stage depends only on its predecessor does not exercise the general sum over earlier
  stages. **This failure has no measured signature** — what is known is only that a lost term is
  silent, so the check has to be a comparison against an independent method rather than an
  inspection.
- **An interior split of a recording does not sweep bit-identically to the whole sweep.** That is
  the check on the segment structure of §5, and it needs no gradient reference.
