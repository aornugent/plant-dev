# The leaf as a single differentiable node

Everywhere else in TF24 a rate is a closed-form function of state and traits. In the leaf it is
not: the plant **chooses** its operating point, maximising carbon profit over the root-collar
water potential within a feasibility interval the soil sets. Differentiating a choice is a
different problem from differentiating an expression, and it has to be treated as one.

This report states the treatment: **the leaf is one node on the tape, and its local Jacobian is
supplied rather than recorded.** Report 00 §4.2 gives the forward solve;
[`05-reverse-mode-mathematics.md`](05-reverse-mode-mathematics.md) §7 gives the algebra of the
derivatives; report 00 §6 says where each row goes. What is here is why the node has this shape,
and what a boundary carrying it must guarantee.

---

## 1. Solve the condition; do not search the objective

The tempting approach — make the leaf scalar-templated so the tape records a maximisation along
with everything else — fails, and the reason runs deeper than "a tape would record the wrong
thing."

**A comparison search does not determine the argmax well enough to differentiate, by any route.**
Golden section shrinks its bracket by a fixed ratio per iteration and returns the midpoint. The
iteration count depends only on the bracket width and the tolerance; the objective enters only
through the comparison that picks which half to keep. So for a fixed comparison pattern the
returned argmax is an exact affine function of the bracket endpoints and **independent of the
objective's values** — a tape recording it yields the derivative of the bracket.

The instinct that this is nonetheless safe, because the comparison pattern is locally constant and
so the argmax moves affinely with a bracket that itself moves smoothly, **is false and has been
measured false.** Terminating on bracket *width* resolves the argmax only to the tolerance, and the
residual offset inside that width wanders discontinuously as the comparison sequence flips. Across
eleven steps in one trait the search returns **six distinct answers**, with a tread the width of
the tolerance. The argmax is piecewise constant at fine scales, and the consequence for a
derivative taken through it is the pair of failures this design most fears: **exactly zero**, or —
for traits reaching the hydraulic path — **smooth, plausible and sign-inverted.** Measured on one
vulnerability-curve parameter, the search returned `−2.6e-03` where the true derivative is
`+2.6e-04`: wrong sign, wrong magnitude, and nothing about the number to suggest either. A
photosynthetic trait came back 52 percent low by the same mechanism.

**A staircase announces itself; a smooth wrong sign does not.** That asymmetry is why the tread
being small is no comfort — the coarse failure is the detectable one.

**So the operating point is obtained by solving its own first-order condition, `∂Π/∂p = 0`.** That
resolves it to solver precision rather than to a bracket width, and the improvement is not
marginal: second differences in a trait are smoother by about three orders of magnitude. **It is
also cheaper** — roughly a quarter faster per solve, because a superlinear root-find reaches a
tolerance many orders tighter in fewer evaluations than a ratio-shrinking search needs for a loose
one. There is no accuracy-versus-cost trade here to reason about; the correct construction is the
fast one.

This is §6's first rule applied to the leaf's own operating point rather than to something
downstream of it. **A search is not a definition.** The differentiable object is the condition the
answer satisfies, and where that condition is available — as it is here, in closed form, and needed
by the forward model anyway — searching the objective instead discards it.

**A second, independent reason keeps the leaf passive.** It holds interpolators on fixed grids,
loose parameters and per-solve scratch with no boundary between them, caches keyed on exact
comparison, an integrator and a nested root-find. Each is a separate correctness question under an
active scalar, and a mistake in any of them is a wrong gradient rather than a compile error.

**So the leaf stays passive, and the tape gets one node.** Nothing inside it is differentiated; the
node relates its inputs to its outputs and the tape sees a small dense block.

---

## 2. The four facts that make the node cheap

- **Profit is the objective evaluated at its own maximiser.** By the envelope theorem its
  derivative is the partial derivative at *fixed* operating point — the argmax's motion contributes
  nothing. This is the entire carbon channel: assimilation, net mass production, all four growth
  rates, the mortality argument. **No argmax derivative is needed for any of it.**
- **Per-layer uptake is a different matter.** It is set as a side effect *at* the operating point,
  so it consumes the argmax rather than being the objective, and the envelope theorem says nothing
  about it. Here the argmax's motion is genuinely required, and the implicit function theorem
  applied to the stationarity condition supplies it.
- **At a bound both are simpler.** When the operating point is pinned to a feasibility bound, it
  *is* the bound, so its derivative is the bound's derivative — analytic, and exact. The profit row
  then reappears in the adjoint, because the envelope theorem has failed at a boundary; that is not
  an inconsistency between the branches but the theorem's own scope.
- **The selector between them is not a comparison on the residual.** Report 05 §7.0 gives five
  kinds of point and requires a decision tree on what *defines* each one. The reason is sharp: the
  marginal-profit function returns a hard sentinel zero in a no-flow or infeasible state, and no
  residual test can distinguish that from stationarity. A state so classified is recorded as an
  interior optimum, its curvature reads zero from the same sentinel, and the argmax multiplier
  divides by an exact zero with a generically non-zero numerator.

---

## 2.1 The paths through the leaf, and what each one does to a row

Four maps, and they are orthogonal: which branch the *solve* took, what the *state* is afterwards,
how each *input* reaches the answer, and which *supply* is in force. A gradient defect is nearly
always a confusion between two of them.

### 2.1.1 The solve's branches decide `∂p*/∂u` and nothing else

```
  set state
     │
     └─ bracket the feasible collar interval  [p_a, p_b]
          p_a = collar at which TOTAL uptake is zero          (wet end)
          p_b = min( collar at which the stem reaches its critical potential,
                     the root's own critical potential )       (dry end)
          │
          ├─ interval inverted ──────────────────────► NO PLANT. Refuse.
          │     the two limits have crossed: no collar both moves water and stays
          │     inside the root's limit. Whether that is a dry soil or a
          │     parameterisation the model cannot represent is a question the
          │     branch can answer and a tag cannot.
          │
          ├─ wettest layer already drier than the stem's critical potential
          │                              ─────────────► SHUTDOWN.  p* := psi_crit
          │     no argmax. Every layer's draw is zero. Profit is respiration plus
          │     the hydraulic cost at the critical potential, so it reads NEITHER
          │     soil NOR light, and the traits reaching only assimilation reach
          │     nothing.
          │
          ├─ gross assimilation cannot cover respiration
          │                              ─────────────► SHADE DEATH. p* := p_a
          │     also no argmax, but NOT the same rows: the collar sits at the wet
          │     end, so profit reads the soil THROUGH THE BOUND and the per-layer
          │     draws are individually non-zero while summing to zero.
          │
          ├─ interval narrower than the degeneracy threshold
          │                              ─────────────► DETERMINED. p* := midpoint
          │     feasibility fixed the point; nothing was optimised. Refuse: the
          │     interior formula would divide by a curvature with no defining
          │     relation, and the bound rows describe neither end.
          │
          └─ solve  ∂Π/∂p = 0  on the interval
               ├─ root strictly inside ──────────────► INTERIOR
               │     ∂p*/∂u = −(∂R/∂u)/Π_pp
               ├─ pinned at the wet end ─────────────► PINNED WET
               │     ∂p*/∂u = the wet bound's own row; dense in the state
               └─ pinned at the dry end, and WHICH LIMIT WON IS THE ROW
                    ├─ the stem's critical collar ───► PINNED DRY, searched
                    │     dense: the bound is a root-find over the potentials
                    └─ the root's critical potential ► PINNED DRY, constant
                          exactly zero in every state direction, and minus the
                          unit vector in its own parameter
```

**Read the tree as a map of `∂p*/∂u` and nothing else.** Every branch above changes that one factor;
none of them changes what an output *is*, and none changes how an input reaches the leaf. That is
report 05 §7.0's factorisation seen from the code's side, and it is why a body per branch is the wrong
shape — a per-branch body has to restate the other three maps inside itself.

**Three of the branches are refusals and they are refusals for different reasons**, which matters
because only one of them is a state of a forest. An inverted interval and a determined point are the
solver saying it could not choose; shutdown and shade death are plants, and they *answer*. Filing all
five under "not interior" loses the distinction the boundary exists to carry.

**And the two shut branches are one derivation with opposite rows.** Both have no argmax, so every row
is a difference of the solve itself and one code path serves both — but one seats the collar at the
critical potential and reads nothing, while the other seats it at the wet bound and reads the soil
through it. A table saying "zero flux, zero rows" is right about the first and wrong about the second.

### 2.1.2 After the solve, four ways to ask again — and three of them destroy something

A gradient asks the leaf about *perturbed* states, which means re-evaluating without re-deciding.
There are four ways to do that and they differ in what survives:

| asking again | the infeasible case | what it destroys |
|---|---|---|
| **solve again** | re-decides; a new branch, legitimately | the previous classification, which was the point of asking |
| **evaluate at a given collar, projecting** | silently moves the collar to the nearest end and evaluates there | **the classification** — the point is retagged as prescribed — and it returns §3.6's substituted branch |
| **evaluate at a given collar, refusing** | returns a flag and does **not** evaluate | nothing, if it also restores what it moved while establishing feasibility |
| **read the bound's analytic row** | reports non-finite | nothing: it restores the uptake state its own bracketing probes moved |

**The second row is the trap and the fourth row is the pattern.** Establishing feasibility requires
bracketing, bracketing probes collars, and every probe overwrites the uptake state — which *is* the
operating point for whoever solved it. So any of these can leave a leaf whose profit is from one
state and whose uptake is from another, and only the ones that save and restore do not. Report 00 §7
item 5 is the general form: **a read that moves an output is a cross-individual channel**, because one
solver serves every individual of a species.

**And projecting is not a small sin.** §3.6 shows the projected evaluation returns the shut branch,
one dark respiration away, with the same type and no error. Detecting it afterwards by comparing the
returned collar against the requested one is sound but is a *proxy* for the condition; asking the
condition first is the same information one step earlier, and costs the evaluation nothing because it
was going to be refused.

### 2.1.3 Each input reaches the answer one of three ways, and none of them needs a perturbation

This is the map that decides the cost, and it is orthogonal to the branch:

| route | which inputs | what the row is |
|---|---|---|
| **through the supply** | the soil potentials, and each layer's root mass | §3.2a's waist: the supply's own Jacobian, times one number per output. The marginal profit needs a second waist and no more. |
| **not through the supply at all** | radiation, the photosynthetic traits, the two cost traits, the maximum conductance, both critical potentials | a direct partial of a kernel, or the bound's own row. Nothing is re-solved. |
| **through the vulnerability curve's own shape** | the two curve **positions** and the two **steepnesses** | position: a scaling identity on the tabulated curve. Steepness: the cumulative curve's shape derivative, from the same series that gives its value. |

**The third row used to say "through a tabulation's own grid", list the steepnesses alone, and end in a
rebuild and a difference. All three parts of that were wrong**, and the correction is report 05 §7.6's.
Position and steepness are both curve parameters and both have exact rows; they differ in the *route* —
an identity for one, a series for the other — not in the standing of the answer. What made steepness look
different is that no *scaling* identity reaches it, which is true and does not imply a measurement.

**So no input's row requires a perturbation.** Every row above is a statement the model can make about
itself at the state it is already in. That is stronger than the ordering this section used to give, and
it changes what the boundary is for: there is no "exceptional case" whose machinery — a step size, a
feasibility question at a displaced state, a branch-stability check — the other rows have to be routed
around. **A row layer that perturbs the model is not paying for a hard case; it is declining to ask.**

Two things follow that §3.7 makes into a requirement. Treating all three routes alike is what makes an
environment row cost the same as a curve row, and it is what puts a feasibility question in front of
inputs that never needed one. And the *reason* the third row can be exact — which is not obvious, since
it reaches a tabulated integral — is that the only quantities needing the integral are its value and its
shape derivative; everything else is a derivative of the **integrand**, and the integrand is elementary.

### 2.1.4 The supply path changes the input list, not the algebra

Two supplies exist. The multi-layer one has per-layer potentials, per-layer root mass, and branch
kinks where the collar coincides with a layer's potential or the gravity balance; the single-potential
one has one potential and a series resistance, no root mass, and **no kinks at all.**

Three consequences worth keeping straight:

- **The input list's arity is a property of the observation**, not of the leaf: the layer count comes
  in with the state. An input index that means one thing at one layer count and another at a
  different one is a defect the type system cannot see.
- **A non-finite supply derivative means "difference it", not "no derivative exists."** At a coincidence
  the general expression is `0/0`, and the quantity it stands for — a span over an integral — is
  analytic through the point, because the two signs cancel. Refusing there discards a row the model
  has. The single-potential path never produces one, so a consumer tested only on it will never
  exercise the fallback.
- **Which critical potential bounds the dry end differs between the two paths.** On the multi-layer
  path the root's own limit does; on the single one the stem's does. So the *same* parameter is the
  active constraint on one path and slack on the other, at the same state.

---

## 3. The node

The node has a set of outputs, an adjoint arrives on each, and they leave as contributions to the
soil potentials, the geometry and light inputs, and the traits.

### 3.0 The output set is a design choice, and it is where a boundary silently under-serves

Which quantities the node treats as outputs is not given by the physics. It is chosen, and **two
consumers want different sets.** A calibration fits a leaf against gas-exchange observations, so its
outputs are the measured ones — assimilation, stomatal conductance, stem potential, the operating
point, profit. **A stand adjoint wants none of those except profit, and wants one the other does not:
per-layer uptake**, because that is the only thing a cohort writes into the shared soil (report 00
§2).

The two sets overlap in exactly one entry. So a leaf boundary built for either consumer serves the
other with a set that looks complete, returns finite numbers for everything it does list, and is
missing the channel the other one is about. **Nothing detects this**: the absent output has no
column, so it cannot read as a wrong number, and a caller that never asks for it never learns it is
not there.

The rule that follows is the one this whole report is an instance of: **enumerate the outputs from
the consumer's equations, not from what the solver happens to expose.** For a stand adjoint the
enumeration is report 00 §4.2's two kinds, and profit is the one they share.

**This has now fired, and not in the direction the section warns about.** The failure described above is
a consumer *under-served* — an absent output with no column. The one that happened is the mirror image
and it is not silent in the numbers, it is silent in the **interface**: a row layer built to serve both
consumers carried, for the calibration's benefit, three arguments the stand's equations never needed —
a trait copy, a driver record and a step — because answering for assimilation, for the stomatal
conductance and for a series resistance that belongs to the other supply path all require a
perturbation. Nothing in any number showed it. Report 07 §7 has the count: three of five arguments, and
what removed them was not a derivation but asking, of each, which consumer's equations name it.

**So the rule has a second half.** Enumerating outputs from the consumer's equations is what stops a
boundary under-serving; enumerating them *per consumer*, and giving each its own entry point, is what
stops the harder consumer's machinery becoming every consumer's cost. That is §7 rule 7 — design against
the easy case — applied to the argument list rather than to the return type.

### 3.1 Carbon is an envelope row

Profit is stationary in the operating point, so for every input `u`

```
contribution += λ_Π · ∂Π/∂u        at frozen p*
```

with no argmax derivative anywhere.

### 3.2 The rank-one scalar is the operating point itself

Everything not stationary in `p` carries the operating point's motion, and they all carry the *same*
motion, because `p` is one number. So the collapse is best written over the outputs rather than over
the soil layers:

```
s = Σ_j v_j · ∂y_j/∂p               one number, whatever the output set is
m = − s / Π_pp                      one divide
contribution += Σ_j v_j · ∂y_j/∂u|_p  +  m · ∇_u (∂Π/∂p)
```

Two channels in that sum are fixed by the mathematics rather than computed, and getting either wrong
is silent. **Profit's `p`-channel is exactly zero** — that is §3.1, the envelope theorem — and **the
operating point's own `p`-channel is exactly one**, because it *is* `p`. Everything else contributes
its ordinary partial.

Written this way the economy is visible: the matrix `(∂y/∂p)(∂p*/∂u)` is never formed, and the cost
drops from outputs × parameters to outputs + parameters. Report 05 §7.2 derives it; §7.3 gives the
structure of the mixed second derivative `∇_u(∂Π/∂p)`, the one genuinely new object the design
needs.

**Exposing the operating point as an output is what makes this composable.** A consumer that needs
uptake rows and one that needs conductance rows then contract through the same scalar, and neither
needs its own version of the argmax machinery.

### 3.2a There are two such scalars, not one, and they nest

The operating point is the collapse this report was written about. It is not the only one, and
missing the second is what makes the environment rows look like they need work proportional to the
number of soil layers.

At a **fixed** operating point the whole soil state reaches the leaf through **total uptake at the
collar** — one number, whatever the layer count. Report 05 §7.3 gives the chain: the stem potential
is the transport curve read at total uptake over the conductance, and everything downstream reads the
stem potential. So the held partials of §3.1 and §3.2 factor again:

```
∂y_j/∂u|_p  =  (∂y_j/∂E)·(∂E/∂u)          for every output that READS the supply
∂E_i/∂u|_p  =  the supply's own Jacobian   for the per-layer draws, which ARE the supply
```

**The two collapses are different in kind and that is why both are needed.** The operating point is
defined by a *condition*, so its row comes from the implicit function theorem and a slope has to be
divided by. Total uptake is defined by a *formula*, so its row is direct and nothing is divided. A
solver that owns an implicit node and a graft already owns both: the implicit node for the first, the
graft for the second, with no third primitive.

**What this buys is stated as a count.** With `L` layers there are `2L+1` state directions and a
handful of outputs. Written as a block it is outputs × directions. Written through the two scalars it
is outputs + directions, twice — once for the supply, once for the point. Nothing about the second
collapse is specific to leaves: it is the general statement that **a submodel should declare its
internal waists, not only its outputs**, and a consumer records against a waist exactly as it records
against an output.

**The marginal profit is the one quantity that needs a second intermediate too.** It differentiates in
the operating point, so it reads both what the supply delivers and *how that delivery responds to the
collar* — rank two where the outputs are rank one. That asymmetry is not an inconvenience; it is what
makes the water channel a chain rule rather than something to be estimated.

**And which two intermediates is a decision, not a description.** The natural-looking pair is total
uptake and its collar slope. The pair that makes the coefficients elementary is the **stem potential and
its collar response** — report 05 (7.3b). The difference is not cosmetic: in the first pair the
condition's dependence on the state appears to factor through one function of one variable, and it does
not, because the collar reaches stomatal conductance *directly* as well as through the stem potential.
A closed form written in the first pair is short by a whole term, and a row built on it is wrong by
whatever that term contributes — silently, since the structure is still rank two and every invariant
formed on the pair still holds.

**One of the two coefficients is free and the other is the only genuinely new number the design needs.**
The coefficient on the collar response *is* the profit's stem-potential derivative, which the forward
solve forms anyway. The coefficient on the stem potential is a second derivative of the profit, and §3.7
is the requirement that makes it available.

**Both coefficients must be partials, and this is the one place the design has a forbidden
alternative.** They can also be *solved for*, from two observed state directions — and that route is
available, cheap and wrong in a way no residual detects. The supply's columns are nearly collinear, so a
fit trades one coefficient against the other along the direction the consumer's own contraction
amplifies; report 05 (7.3d) prices it. **A fitted coefficient is the single worst way to obtain a number
on this path**, worse than differencing the whole row, and a boundary cannot tell a caller which it
received. §4 item 12.

### 3.3 The explicit part of the water channel is sparse, and one of its terms has left the model

Per-layer uptake reads its own layer's potential and the collar, so `∂E_i/∂ψ_j` is **diagonal — and
that is the whole soil Jacobian of the supply, not its diagonal part.** It is not the collar
conductance negated, either: the two endpoints sit at different points on a non-linear vulnerability
curve, so the integral terms do not cancel. That is report 00's fact 2 again — differences and
absolutes — and it means a boundary offering one of the two cannot be assumed to offer the other.

**And `∂E_i/∂area_leaf = −E_i/area_leaf` exactly** — leaf area is a single factor and the
resistances contain none. Report 00's fact 3 shows the factor then cancels downstream, so this is an
internal identity rather than a model channel.

That identity has a consequence worth its own line, because it is the reason the row can vanish
without anyone noticing. **A resistance network is homogeneous of degree −1 in the root carbon it is
built from**, so scaling carbon by `1/A` scales the resistances by exactly `A`. A boundary can
therefore take *resistances per unit leaf area* and never mention leaf area at all — which is the
right factoring, since which root-architecture model is in force is not the leaf's business. But
then **leaf area is a convention on both sides of an interface that cannot check it**: a caller
handing over resistances built from absolute carbon gets a silently wrong uptake rather than an
error, because five vectors of positive numbers look the same either way. §4 item 7 states the
general form.

### 3.4 The rank-one collapse is verified, independently

The identity a correct transpose must satisfy is `⟨v, J u⟩ = ⟨Jᵀ v, u⟩` for arbitrary `v` and `u`.
An implementation of exactly the construction above — the two scalars and the scaled row, with the
profit row's operating-point channel set to zero by the envelope theorem and the collar's set to
one because it *is* the operating point — satisfies that identity to **1.4e-14 over 294 operating
points**, five orders below the solve's own floor.

Two things follow that are worth more than the number. The identity is **the** check on this node,
because it needs no reference gradient and no differencing: it is a property the transpose either
has or does not. And the two constants in it are the whole of §2's first two facts, so an error in
the envelope reasoning shows up here rather than as a plausible wrong gradient downstream.

### 3.5 The bound case

The operating point is the argmax over an interval whose endpoints are themselves root-finds — the
potential at which total uptake vanishes, and the drier of the stem's and the root's critical
potentials. When the point is interior the bounds enter no row. When it is pinned, the bound's
derivative *is* the answer, and the endpoint conditions are what supply it.

This branch is exact where the interior branch is only as good as its linearisation point, which is
the opposite of what one might expect. Report 06 §7 states what it means: **a pinned plant is
drought**, and any conclusion about drought sensitivity depends on this branch being right.

### 3.6 What the first-order solve has to guard

Why the accuracy matters at all is worth stating, because it is what makes §1 a correctness argument
rather than a tidiness one. **A displacement of the operating point moves profit at second order and
uptake at first order.** So the carbon row survives an imprecise operating point and the water rows
do not — and the water rows are the ones that carry the competition.

Solving the condition rather than searching the objective removes that exposure at the root, and it
retires the intermediate construction that a search forces: a maximise-then-correct step, in which
the search is run loose and its answer polished onto the condition afterwards. That works, and it is
strictly worse than not having the search — an extra tolerance to size, an iteration cap whose
exhaustion is invisible in the value, and two failure modes where the direct solve has one.

Three things the solve does have to guard, and each is a property of the problem rather than of any
solver.

**One endpoint of the bracket is infeasible by construction, and it returns a sentinel.** The wet
bound is the collar potential at which uptake is exactly zero — which is precisely where the stem
potential meets the collar and the marginal-profit function takes its no-flow exit, returning a hard
zero that is not a derivative. **So a bracketing method is handed a sentinel at one end, always, and
a solver that trusts it reports the zero-transpiration point as the optimum.** Measured, that is a
profit of −1.90 returned against 2.52 at the true optimum. The infeasible sliver is narrow — under
`1e-6` of the bracket — so stepping inside it is cheap; the point is that it must be stepped over
rather than evaluated. Report 05 §7.0 states the sentinel hazard for *classification*; this is the
same sentinel one level down, corrupting the forward answer.

**Profit is discontinuous across that same boundary**, not merely steep, and **the mechanism is the
model's own zero-flux substitution rather than arithmetic running on a negative conductance.** Below
the edge the flux would reverse, so the downstream potential comes out wetter than the collar and the
model substitutes the shut state: conductance identically zero, intercellular CO₂ at the point where
*gross* assimilation vanishes. Approaching from inside, conductance tends to zero and the inner
supply-equals-demand solve drives *net* assimilation to zero instead. The two limits differ by
exactly the dark respiration — report 05 §7.0b — which is what the measured jump of 1.44 is.

Three things follow that a boundary has to respect:

- **The endpoint's value is not the limit from inside.** So the bound must not be *returned* either —
  a pinned operating point sits just inside the boundary, not on it.
- **The substituted branch and the intended one return the same type.** A finite, plausible number
  comes back either way, so a check applied *after* evaluating can only work if it can tell which
  branch produced the number. **Establish feasibility before evaluating; do not evaluate and test.**
  §4 item 9 states this as a requirement.
- **A negative conductance is a real hazard and it is on a different path.** The marginal profit
  reaches the inner CO₂ solve directly, without the substitution, and there a reversed gradient does
  make the bracket fail. Naming that as the profit's mechanism sends a reader to the wrong guard.

**And the two pin tests are not exhaustive; the leftover case is a failure, not a third pin.** If
profit is falling away from *both* ends into the interval, the interior stationary point is a
**minimum** and the maximum is at one of the bounds — but the gradients cannot say which. Attributing
it to whichever bound the test order happens to reach first returns a finite, plausible, wrong answer
with a genuinely non-zero gradient pointing the wrong way. It must refuse. That is case **N** of
report 05 §7.0, and the profits rather than the gradients are what identify it if an answer is
wanted.

**One kink is real and belongs to the problem.** Where a state crosses between interior and pinned,
the operating point has a genuine kink in trait space. No solver removes it — a search has it too —
and it sits where a calibration is most likely to wander.

---

## 3.7 The one requirement that makes every row a statement, and where it falls

Everything above says what the rows *are*. This says what a submodel has to be able to do to state
them, and it reduces to one sentence.

> **Every primitive the solve reads must supply one derivative order more than the row layer consumes.**

That is the design's whole commitment, and the rest of this section is why it is the right one, why it
is affordable, and where it binds.

### Why one order more, and not the same order

The rows the consumer needs are of two kinds. An output's row is a first derivative of the solve, so a
first derivative of each primitive suffices for it. **But the operating point is defined by a
condition, and that condition is *itself* a first derivative** — the profit's derivative in the
operating point. So its gradient is a **second** derivative of the model, and every primitive on the
chain has to go one order past what an output's row needs.

This is the structural reason the condition's gradient is the hard part, and it is worth saying plainly
because it is not a numerical difficulty that a better method removes. Any route to
$\nabla_u(\partial\Pi/\partial p)$ — by hand, by forward-mode differentiation of the composition, or by
differencing — needs those second derivatives. **What differs between the routes is only whether the
primitives supply them or the consumer estimates them.** A row layer that perturbs the model is what
happens when the primitives stop one order short: the missing order is recovered by putting the model
in a nearby state and looking, which is the one operation that reintroduces a step size, a feasibility
question at a state the model may not admit, and a branch-stability question — none of which the answer
has anything to do with.

### Why it is affordable, which is not obvious

The chain reaches a **tabulated cumulative integral**, and a second derivative of a tabulation is a
property of the fit rather than of what was fitted. That looks like a wall. It is not, and the reason
is Leibniz: differentiating a cumulative integral in its upper limit **removes the integral**. So the
transport curve's second derivative in a potential is the integrand's *first* derivative, and its mixed
partials in a potential and a curve parameter are the integrand's parameter partials — and the
integrand is an elementary function of the potential and of both curve parameters.

**The consequence is a short inventory, and it is the design.** Of everything the row layer needs, only
two quantities genuinely require the integral:

| what a row needs | where it comes from |
|---|---|
| the curve's value | the tabulation — which *is* the model, by §5's first ruling |
| its first derivative in a potential | the integrand: elementary |
| its second derivative in a potential | the integrand's own derivative: elementary |
| its mixed partial in a potential and a curve parameter | the integrand's parameter partial: elementary |
| the **inverted** curve's first and second derivatives | the reciprocal and $-S''/(S')^3$: elementary, given the two above — **and read by nothing**, once the stem potential's collar response is taken off the flux balance rather than off $P'$ |
| the curve's derivative in its **position** | a scaling identity on the tabulated curve: exact |
| the curve's derivative in its **steepness** | the incomplete gamma's shape derivative, from the same series as the value |
| the profit's second derivative in the stem potential | elementary compositions, plus the implicit function theorem applied twice to an explicit inner residual |

**Nothing in that column is a perturbation, a fit, or an inversion**, and the last four rows are what
turn §2.1.3's third route from a measurement into a statement.

**One more row belongs in it, and it is written now**: the supply's **second** collar derivative. Each
layer's flux is a numerator linear in the collar over a resistance built from the cumulative integral's
span over its value, so one collar derivative reads the integrand and a second reads the integrand's own
derivative — elementary, like everything else here. With it the profit's curvature in the operating
point is a statement, agreeing with the difference it replaces to $1.5\times10^{-8}$ over the golden
grid's interior points.

**Two things it did not do, and both are worth stating because the first was expected.** It did not
leave the boundary with no consumer of a step: the difference survives as the fallback on the branches
the closed forms do not describe, and a fallback costs an argument where a refusal does not. And it did
not need the tabulation's curvature — differentiating a cumulative integral in its upper limit leaves
the integrand there, so one more derivative leaves the integrand's own slope, which is a closed form and
not a difference of the fit's data. That is the rule in the row above doing its work: **every second
derivative here is a derivative of an integrand, never of an integral.**

### Where the requirement binds, and it is one place

The requirement fails at exactly one point today, and it fails quietly. **A tabulation that *infers*
its slope from neighbouring values does not supply the integrand — it supplies an approximation to it**,
and the two disagree by parts in ten thousand. That is above the threshold at which this corpus calls a
difference real, so combining a closed-form second derivative with a fitted first derivative is mixing
two models, and the inventory above collapses: $-S''/(S')^3$ is not the inverted curve's second
derivative if $S'$ is one function and $S''$ is another's.

**So the requirement is not "add a second derivative" but "supply the first one exactly, and the second
follows".** A tabulation built from the value **and the closed-form slope** at each knot has the
integrand as its own derivative, and then every row in the table above is consistent with the model
being evaluated. Report 05 §7.6 states the ruling, its measured cost as a forward-model change, and the
one property that has to be re-measured rather than inferred — that the argmax stays smooth enough in a
trait to differentiate, since the curve is what the operating point is found by climbing.

### What the requirement is worth, stated as bounds rather than as a plan

Two consequences, and both are properties of the design rather than of any implementation of it.

**The row layer's evaluation count becomes independent of the input count.** Where every row is a
statement, the only model evaluations a call makes are the ones the *forward* answer needed: one solve.
Where rows are recovered by perturbation, the count is a small multiple of the number of inputs, and
each perturbation re-runs the inner solve. **The gap between those two is the design's cost case**, and
it is the larger of its two arguments — the held block dominates, because an output's row perturbs the
whole operating point where the condition's row perturbs only the marginal profit.

**And the amplified error becomes round-off.** Report 05 (7.3d) shows the consumer's contraction
amplifies the *difference* between the two coefficients' relative errors. Where both are partials the
difference is round-off; where one is estimated it is that estimate's error; where one is *fitted* it is
that error times the fit's absorption ratio. **So the accuracy case and the cost case have one cause**,
and a design that closes one closes the other.

---

## 4. What the boundary must guarantee

The node is a contract between a passive solver and an active caller. Each requirement below is
stated with the failure it prevents.

**The rule the whole contract is an instance of, first, because it says why the node exists at all.**
There are exactly two ways to obtain a transpose, and only one of them can drift. **Derived by tape:**
record the forward map at an active scalar and take one vector-Jacobian product — such a transpose
*cannot* disagree with its forward, because there is only one function. **Hand-mirrored:** write the
transpose beside the forward and hold the two together by a comment. Every silent failure this corpus has
found is of the second kind — a term dropped on a branch no fixture reaches, an association order
restated at four sites, one column order assembled three times — and a hand-mirrored transpose is
routinely *larger* than the forward it transposes. So:

> **Record everything whose operations you can afford to record. Supply rows only where recording is
> impossible — an opaque solver — or unaffordable — the whole trajectory.**

**The leaf is the one place in this model where the first exception bites**, and §1 is why: the solve is
opaque not by accident but because recording it would differentiate a search rather than a definition.
Everything else in the step — the shared field, both reductions, the inflow condition, the downstream
aggregation — is recordable and should be recorded. **A supplied row is a debt**, and the reason to name
the rule before the requirements is that most of them are the terms of that debt.

**1. Only values cross, in both directions.** The caller hands doubles in and receives doubles and
derivative rows back. Nothing active enters the solver, and no tape is live inside it. This is what
lets the solver keep its caches, its exact comparisons and its inner solves without any of them
becoming a correctness question.

Note what this does *not* forbid. The solver may differentiate itself internally by any means it
likes — forward-mode on its own kernels, analytic spline derivatives, the implicit function theorem
at an inner root-find — and for a handful of inputs forward mode is the right choice there, being
tape-free and header-only. **The node is what composes a forward-differentiated solver into a
reverse sweep**, and the reason that works is precisely that the sweep never enters the solver. A
boundary is a scalar-type boundary, not an AD-mode boundary.

**2. The rows are grafted, not recomputed.** The recorded expression is
`value + Σ_i partial_i · (u_i − passive(u_i))`, which is **exactly** the value — every bracket is
zero — and carries the supplied derivative. Report 05 §8 gives the three preconditions and the one
that is easiest to miss: **a non-finite supplied partial corrupts the value, not only the adjoint**,
because `NaN × 0` is not a number. The finiteness test therefore belongs on the partials before
they meet the brackets; there is nowhere downstream to put one.

**3. A finite difference of the node cannot referee its own rows.** Property 2 makes the block's
forward value independent of a grafted input, so differencing the block returns identically zero on
exactly the columns a supplied row occupies — whether the row is right, wrong, or absent. Supplied
derivatives must be checked against the solver's own algebra, or against the transpose identity of
§3.4, and never against a difference of the step that consumes them.

**4. The input list must be derivable, not maintained.** A list assembled by reading a function
signature becomes silently incomplete when the signature grows, and the failure is a trait column
that reads **exactly zero** — this design's worst shape, because a zero reads as an answer. The
same hazard applies one level up: a caller that assembles its graft vector from a subset of the
declared inputs discards every row outside that subset, with no signal.

**5. Every exit sets the whole operating point.** An early exit that writes some outputs and leaves
others holding the previous solve's values is a cross-cohort channel, because the solver is shared
across every plant of a species. Report 00 §7 item 5 is the structural form of this.

**6. The classification is reported by the branch taken.** Not inferred afterwards from a residual,
for §2's reason. And it must be reset at the top of each solve, because a branch that declines to
write it leaves the previous plant's classification — a plausible answer about a different plant.

**7. A derived input cannot be checked by the side that receives it.** Whenever a boundary takes a
quantity the caller computed rather than the thing it was computed from — resistances instead of
root carbon, a conductance instead of a height, a per-unit-area quantity instead of an absolute one
— the convention is now shared and only one side can see it. The receiving side gets numbers that
are well-typed, positive and plausible under either convention, so **no check on that side can
exist.** This is the right factoring and it is worth doing; what it obliges is that the convention is
stated at the boundary and asserted on the *caller's* side, where the inputs to the derivation are
still visible. §3.3's leaf-area homogeneity is the instance that motivates it.

**8. Two channels of different shape must not share a loop.** The rows out of this node are not one
family. A soil row is a scalar price times a supply derivative; a light row has no supply derivative
to multiply at all, because at a fixed operating point radiation moves no water — it is a direct
partial of the assimilation kernel, closed by the inner root-find's own implicit-function term. A
single generic loop over "environment inputs" forces one shape into the other's, and the failure is
not a wrong number but an index: one channel ends up addressed through a container sized for the
other. **Where two rows have different derivations, give them different entry points**, and let the
caller pay the small cost of knowing which is which.

**9. Feasibility is established before an evaluation, never tested after one.** §3.6's substitution
returns a finite, plausible number of the same type as the answer it stands in for, so a check
applied afterwards has to distinguish two branches by their output alone. Where the substitution is
detectable only by comparing the returned operating point against the requested one, the detection is
sound but the evaluation has already run — and it ran the model on a state the model was declining to
represent. A surface that **refuses without evaluating** is the one to expose, and the caller's own
question ("would this state admit this operating point?") is the one to answer first.

**10. A guard belongs where its quantity can be formed, and that is often not where the number is
produced.** The amplification a fold makes dangerous is the output-adjoint-weighted response of the
point; a supplier of rows has no output adjoints and a primitive owning the quotient applies them
after it returns, so neither can form it (report 05 §7.0). What the supplier *can* form is a maximum
over inputs of differing units, which is not a quantity a ceiling can be stated for. **Do not place a
guard by proximity to the arithmetic it protects.** Ask which participant holds every factor, and put
it there; where that is the caller, the supplier's obligation is to hand back the factors rather than
a summary of them.

**11. Rows obtained by different means are not interchangeable, and the difference has to survive the
boundary.** A row that is an identity, a row assembled from closed forms, and a row taken by
perturbing the model are three different objects with three different failure modes — exact, exact
up to its factors, and carrying a step size, a feasibility question and a branch-stability question.
A consumer given all three as one vector of doubles cannot tell which discipline applies to which
entry, and will apply the weakest one it knows about to all of them. Where a boundary cannot carry
that distinction in its types, it must at least not *create* the ambiguity — which means not
perturbing to obtain a row the model can state.

**12. A coefficient shared across a row's entries must be a partial, never a fit — and the reason is
the opposite of the obvious one.** Where a row factors as a few scalars times a few vectors, the
tempting economy is to *recover* the scalars by solving for the pair that reproduces some observed
directions. It fits, it is cheap, and its residual on the directions it was solved from is excellent.
It is also the worst available estimator, because the directions available to solve from are nearly
collinear, so the fit trades one scalar against the other along precisely the direction a consumer's
contraction amplifies. Report 05 (7.3d) gives the arithmetic: the amplification acts on the
**difference** between the two scalars' relative errors, and a fit is the one procedure that maximises
it. Three defences suggest themselves — an anchor direction chosen from outside the family the pair will
serve, an out-of-sample check, a rule about which direction may anchor — and **all three are unnecessary
rather than insufficient**: take each factor as a partial in the coordinates it is a partial in, and
there is nothing to guard.

Note what this requirement does *not* say. **A shared factor is not the problem, and forbidding one
would be the wrong lesson.** A relative error common to every entry of a row passes through a
contraction unamplified; it is only the part that differs between entries that the cancellation
multiplies. So a design should share a factor *deliberately and completely*, putting as much of the
uncertainty as it can into something common, and reserve its care for the residual. The rule is about
the estimator, not about the sharing.

**13. Feasibility is a separate channel, never a sentinel value.** The marginal profit returns a hard
zero in a no-flow or infeasible state, and that zero is the same number stationarity returns. §2's fourth
bullet gives the consequence for classification and §3.6 gives it for the forward answer; as a
requirement on the interface it is simpler than either. **A quantity and the report of whether it exists
must not share a representation**, because every consumer then has to reconstruct the distinction from
context and each will do it differently — one testing a tolerance, one testing exact equality, one not at
all. The channel costs a bool per call and removes a whole class of failure, and the same applies one
level out: a classification field that is *hard-coded empty* reads as "nothing was unanswerable" rather
than as "this is not wired up", which is the same defect as a failing check written down as expected.

---

## 5. Two rulings that are easy to get backwards

**Differentiate the model being evaluated, not the model it approximates — and note that the two can
be made the same object.** Where the forward solve reads a tabulated curve, the derivative that belongs
on the tape is the *table's*, not the closed form the table approximates. A closed form substituted for
a **fitted** derivative is the more accurate derivative of a different function, and it introduces a
systematic disagreement — measured at parts in ten thousand for the vulnerability integral — that no
invariant on the gradient can attribute, because both routes are internally consistent and neither
referees the other.

**The ruling used to present two options and there are three.** Accept the disagreement, or replace the
table with the closed form as a forward-model change — or **build the table from the value and the
closed-form slope**, so that the table's own derivative *is* the closed form. The third collapses the
two objects into one: exact at every knot, a cubic through exact values and exact slopes between them,
and no gap left for an invariant to be unable to attribute. Report 05 §7.6 has the measured cost, which
is a forward-model change and therefore a re-blessing, and the one property that must be re-measured
rather than inferred — the argmax's smoothness in a trait, since the continuity class of the curve drops
while the quantity that matters is what the operating point climbs.

**Which is also the precondition §3.7 turns on.** With a fitted slope, a closed-form second derivative
cannot be combined with the table's first derivative: they belong to different functions, and the
inverted curve's second derivative in particular is built from both. So this ruling and the
derivative-order requirement are the same requirement seen from two sides — **supply the first
derivative exactly and the second one follows; infer the first and the second is unavailable.**

**A non-finite return is a legitimate answer; a silent substitution for one is not.** Where the
analytic route genuinely has no row — a branch kink, an equal-potentials boundary — returning
non-finite and *documenting that as the contract*, so the caller knows to difference or to refuse,
is the honest design and it composes: the decision is made where the information is. What is not
acceptable is the same non-finite quietly replaced by a difference *inside* a supplied row, because
then the value is unaffected, the derivative is quietly a different object, and no caller can see
which of the two it received.

The two are one line apart in code and opposite in kind. The test is whether the caller can tell:
**a sentinel that reaches the caller is an interface; a sentinel absorbed before it does is a
severance.** And a row refused for one layer should refuse the call, not the layer — a vector with
one meaningless entry among finite ones is the worst of the three outcomes.

---

## 6. What this asks of a strategy author

The engine's contract does not change: a strategy computes rates and gets a gradient. But a strategy
containing an inner solve has obligations no compiler checks. The first four are the sections above
restated as instructions, because what a *model author* needs is not what an *interface* needs; the
last two appear only here.

**1. Return the solution, expose the residual, never expose the search** (§1). For a quantity defined
implicitly the differentiable object is the defining equation, and a search is not a definition.

**2. Enumerate your outputs from the consumer's equations, not from what the solver exposes** (§3.0)
— and put the implicit quantity itself among them (§3.2), so every consumer that is not the objective
contracts through one scalar instead of carrying its own copy of the argmax machinery.

**2a. Declare your internal waists, not only your outputs** (§3.2a). Wherever a family of inputs
reaches a family of outputs through one scalar, that scalar is worth naming at the boundary even
though no consumer asked for it: naming it turns a block into two vectors, and the consumer records
against it exactly as it records against an output. The operating point is one such waist and is
easy to spot because it is implicit. **The ones defined by a formula are the ones that get missed**,
because nothing about them looks like a node.

**3. An objective at its own optimum is free; its other consumers are not** (§2). Ask of every output
whether it *is* the objective or merely reads the argument that maximised it — and note that the
freedom is a property of the **state**, not of the output: it is the stationarity condition, so it
holds where that condition holds and nowhere else. Supply the objective's response to the operating
point as a number rather than letting a consumer infer zero from the output's identity.

**4. A feasibility bound is part of the model, so its derivative is part of the answer** (§3.5).

**5. Count your branches before designing around them — on a driver that reaches the regime in
question.** Report 05 §7.0's five kinds are consecutive segments of one drydown, so a census taken on
a wet driver establishes nothing about a dry one, and a corner reported as unreachable is usually a
corner nobody drove at.

**And the driver that matters is rarely the one already being swept.** Three branches were reported
unreachable by grids that could not reach them, each one parameter away, and only the first is a
moisture question:

| the branch | what reaching it took | what the grid had |
|---|---|---|
| shade death, which is a **pin at zero uptake** | radiation below 26.6 µmol at 25 °C | a floor of 100, and 94.8 is the threshold at 40 °C — a five percent miss |
| a **gravity-balanced** layer, where the supply refused every derivative | a *single* soil layer, where the collar of zero uptake IS that balance | multi-layer profiles |
| the **root's own** critical potential binding the dry bound | a plant whose root gives up before its stem | defaults where that potential and the stem's are the same number, so the arm is unreachable by construction |

Two of the three are not soil moisture, and soil moisture is what gets swept. The third is worse than
unswept: it is **unreachable at the default trait vector**, so no driver sweep of any kind would have
found it — which is the argument for counting branches over *traits* as well as over drivers, and for
treating an input whose rows are zero everywhere as a question rather than an answer.

**6. Say whether a switch is a kink you mean.** A zero derivative may be exactly what the model
intends; the point is that it should be a recorded decision rather than an artefact of writing an
`if`. **This is the corpus's canonical statement of that rule**, and reports 01 and 03 point here
rather than restating it.

**7. Design the node against the *easy* case, and check it against the hard one.** The instinct is the
reverse, and it produces an interface shaped like the difficulty. This model has a variant in which the
operating point is a **tracked state** rather than an argmax — it ascends the marginal profit as an ODE
state instead of maximising instantaneously — and that case needs no implicit solve, no stationarity
condition, no curvature to divide by and none of §2.1.1's branches: its derivative arrives from the
adjoint like any other state's, and the only thing it wants from the leaf is the marginal objective at a
**prescribed** point, which the node returns anyway. **So the tracked case is the one that says what the
general interface is**, and the argmax case is a specialisation of it in which one extra number — the
condition's gradient — has to be supplied because no adjoint carries it.

A node designed the other way round acquires the argmax's shape everywhere: a curvature in the return
type, a classification every consumer must consult, a feasibility question in front of every row. Then
the easy case cannot be expressed in it at all, which is the observable symptom — **a variant of the
model that does not compile against its own gradient interface is the sign that the interface was carved
around the hard case.**

---

## 7. What would falsify this

- **Profit is not always the objective at its own maximiser.** Any path that sets profit other
  than by evaluating the objective at the returned operating point breaks the envelope argument
  there. The shutdown exits are such paths, and they are case X in report 05 §7.0 rather than an
  interior optimum.
- **The transpose identity fails at a state the forward model reaches.** §3.4 establishes it over
  interior and pinned points; a fold, a collapsed feasibility window or a tracked operating point
  are where to look next.
- **The rank-one collapse is not the only route from the operating point into a layer's flux.** Then
  the single scalar `s` is incomplete and the whole cost argument changes.
- **The soil state reaches an output by some route other than total uptake, at a fixed operating
  point.** §3.2a's second collapse rests on it, and it is checkable at one solved point without a
  gradient: hold the collar, move two layers in opposite directions so that total uptake is unchanged
  to round-off, and read every output that is not a per-layer draw. They must not move. If one does,
  the waist is not a waist and the environment rows are outputs × layers after all.
- **The wet-boundary jump is not the dark respiration.** §3.6 attributes it to the zero-flux
  substitution, which predicts a specific size, a dependence on leaf temperature, and no counterpart
  at the dry boundary. Any of the three failing means the discontinuity has a different cause and the
  discipline built on it is defending against the wrong thing.
- **The first-order condition has more than one root in the feasible interval.** §1's construction
  assumes the marginal profit crosses zero once. A second crossing is a second stationary point, and
  a bracketing solver returns whichever one its bracket contains — silently, and with a perfectly
  correct envelope row at a point that is not the maximum. Report 05 §7.0's fold analysis is where to
  look, since the curvature that would admit a second root is the curvature that would admit a fold.
- **The supplied rows disagree with the solver's own algebra.** This is the direct test and it needs
  no stand: evaluate one solve, form each row analytically, and compare. §4 item 3 says why it
  cannot be done any other way.
- **A stand adjoint can be built without per-layer uptake rows.** §3.0 rests on the claim that the
  soil coupling needs them, because per-layer draw is what a cohort writes into the shared state. If
  the soil's own adjoint can be closed through the *total* instead, the output sets are not disjoint
  after all and the section's warning is about nothing. Report 00 §2's rank argument is where to
  check: the coupling is a vector per layer, not a scalar, and the positivity guard makes the layers
  behave differently from one another.
- **The condition reads the state through some third intermediate.** §3.2a and report 05 (7.3b) claim
  the stem potential and its collar response are the whole of it. The test is out-of-sample and needs no
  reference gradient: recover the two coefficients from two state directions of *different families*,
  then predict the remaining directions. A residual that stays at round-off confirms rank two; one that
  grows with the number of predicted directions means a third intermediate. Note that this test passes
  for the *wrong* pair as well — the pair that omits the collar's direct route to conductance is also
  rank two — so it establishes the rank and not the coordinates. **What separates the two pairings is
  whether the coefficient claimed to be closed form agrees with a difference of the condition**, and
  that is the check the wrong pairing fails.
- **The derivative-order requirement is not sufficient.** §3.7 claims that one order past the row
  layer's consumption closes every row. If some row turns out to need a *third* order — a second
  derivative of the condition, for a curvature the consumer wants — then the requirement is a moving
  target rather than a property, and the argument that the primitives can be finished has to be
  replaced by one about how far to go. Report 05 §7.7's curvature correction is where to look, since it
  is the one quantity in the corpus a consumer might reasonably ask to differentiate again.
- **Supplying a tabulation's slope roughens what the solve climbs.** §5 and report 05 §7.6 rest on the
  argmax staying as smooth in a trait as it was under a solved-slope interpolant, and the continuity
  class *drops* when slopes are supplied. Measured it holds, but it holds as a measurement: a curve with
  more curvature between knots, or a coarser grid, is where it would fail, and the symptom would be
  trait derivatives degrading without any row changing.
- **The cancellation the water channel is judged against is the one a stand occupies.** Report 06 §7
  measures every run stand between 1.03 and 1.14 and reaches 16.3 only under a root system no
  trajectory develops. If a trajectory *does* develop one — or if a calibration ascending root
  conductance reaches it — then the corner is a specification rather than a hazard, and the error budget
  for the water rows is an order of magnitude tighter than the measured stands imply.
