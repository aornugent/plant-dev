# Supplied once: what odelia, phylloptim and plant each own

Report 09 states the solver's side of the reverse pass and leaves one item open — the inner solve's
supplied rows, the last hand-written derivative surface and the largest single cost in a gradient.
This report closes it, and in closing it finds that the same defect has three other instances.

**The referee is the mathematics plus the objective.** Where this disagrees with the code, one of
them is wrong and the disagreement is the finding. Nothing here tracks what has been built.

**Scope.** §1 is the rule. §2 is the layer carving. §3 to §6 are the four instances, each with its
mathematics, its ecology, its interface written out, and what it deletes. §7 is the solver's concept
surface. §8 is the order to build in. §9 is what this is bad at, §10 what would falsify it. Appendix
A records four routes that are closed, with the evidence, so they are not re-derived. Appendix B is
the branch merge.

---

## 1. The rule

> **A derivative is either recorded or supplied. Recording costs nothing to keep true. Supplying
> costs a consistency obligation, so it is supplied exactly once, by whatever owns the value, and
> handed back already paired with the input it belongs to.**

The first sentence is report 09 §2's rule and is settled. The second is this report's subject, and
the pairing clause is the half that makes it structural: **position must not be the interface.**
Three constructs in this tree have converged on that independently — odelia's
`input_and_derivative{input, derivative}`, whose comment says it is "kept as a pair so the two cannot
be assembled from separate lists and paired by position"; plant's `ad_parameter{&pars.x, #x}` macro,
which makes a name inseparable from the parameter it names; and the reverse-pass branch's
`leaf_trait` struct, which replaced five parallel arrays after one of them "paired every later
trait's value with another's address". The same move, found three times, never generalised.

Every hand-written derivative surface left in this tree is that rule broken in one of two ways —
supplied where recording was possible, or supplied by someone other than the owner:

| the surface | broken how | what it costs, measured |
|---|---|---|
| nine hand transposes inside a step | supplied where recordable | −2898 lines, already deleted |
| `record_leaf_outputs` + its shut sibling | supplied by the **consumer**, not the owner | 1023 lines, 1121 with what dies with them; 49.1% of a gradient profile |
| the trait order in two tables | the pairing done by the consumer, positionally | 1 of the 14 disagrees in name |
| `stem_b`'s row | one derivative supplied twice, by two owners | the two packages contradict each other in code |
| four quadratures over one grid | one grid supplied four times | closed: all four read one accessor |
| two state loaders | one boundary evaluation supplied twice | a second loader, and a read-point list with one instance |
| the `(a, b)` pair | a row supplied by fitting rather than by its condition | unvalidated in the direction that carries the ecology |

§§3–6 take the four live instances in order of size.

---

## 2. The three layers

The boundary positions are settled and this report does not move them. What it fixes is the shape of
what crosses each one.

```
        ┌──────────────────────────────────────────────────┐
        │ plant — the model                                │
        │   TF24: states, rates, allometry, the two        │
        │   reductions, the census, the growth map          │
        └───────┬──────────────────────────────┬───────────┘
                │                              │
   rebind_from<S>()                  inputs (values) ──►
   ad_parameters()                   ◄── rows, paired
   ode_rates() etc.                  ◄── the classification
                │                              │
        scalar S (any)                      double only
                │                              │
        ┌───────▼──────────┐        ┌──────────▼─────────────┐
        │ odelia — the     │        │ phylloptim — the leaf  │
        │ solver           │        │                        │
        │  the tape        │        │  the solve, in double  │
        │  the step        │        │  its own forward-mode  │
        │   recording      │        │   calculus (xad::fwd)  │
        │  the segment     │        │  the classification    │
        │   walk           │        │   by branch taken      │
        │  the graft       │        │  the parameter and     │
        │  the IFT + its   │        │   output enumerations  │
        │   refusal        │        │                        │
        └──────────────────┘        └────────────────────────┘
```

**odelia knows nothing about plants.** It records the model's own forward call, so the only thing a
model owes it is the ability to be evaluated at any scalar. It owns one supplied-derivative
primitive, `record_with_derivatives`, and one theorem, `implicit_root`.

**phylloptim knows nothing about stands.** It solves in `double`, differentiates itself in forward
mode, and hands back rows. That it never sees an active scalar is not a preference: `xad::adj`
requires `Tape<double>`, which is defined only in odelia's `src/Tape.cpp`, and phylloptim carries
`LinkingTo` with no `PKG_LIBS` and a CMake target that deliberately links nothing. Appendix A.2.

**plant knows nothing about tapes.** It writes its rate function once, at `S`, and grafts the leaf's
rows in.

---

## 3. The leaf

### 3.1 The mathematics decides the interface, and it is one table

Write `u` for the leaf's inputs, `p` for the root-collar water potential magnitude, `Π(p; u)` for
carbon profit, and `y_j(p; u)` for the leaf's outputs. The operating point solves

$$R(p; u) \;\equiv\; \frac{\partial \Pi}{\partial p} \;=\; 0 ,$$

and every output is evaluated there. Differentiating the condition,

$$\frac{\partial p^\star}{\partial u} \;=\; -\frac{\nabla_u R}{R_p}, \qquad R_p \equiv \Pi_{pp},$$

and every output's total row is

$$\frac{\mathrm{d} y_j}{\mathrm{d} u} \;=\; \underbrace{\frac{\partial y_j}{\partial u}\bigg|_p}_{\text{frozen}} \;+\; \frac{\partial y_j}{\partial p}\,\frac{\partial p^\star}{\partial u}. \tag{3.1}$$

**Two of the three factors in (3.1) are fixed by the mathematics for two of the outputs, and getting
either wrong is silent.** Profit is the objective at its own maximiser, so `∂Π/∂p = 0` — the
envelope theorem. The operating point *is* `p`, so `∂p*/∂p = 1` and its frozen row is zero. Every
other output supplies both factors ordinarily.

That is the entire declaration a submodel with an inner solve owes a consumer:

| role | frozen `∂y/∂u|_p` | `∂y/∂p` | the row (3.1) becomes |
|---|---|---|---|
| **Objective** — this output *is* what the point maximises | `∂Π/∂u` | **0** at an interior point; the multiplier `ν = ∂Π/∂p` at a pin | `∂Π/∂u + ν·∂p*/∂u` |
| **Point** — this output *is* the operating point | **0** | **1** | `∂p*/∂u` |
| **Ordinary** — this output merely consumes the point | supplied | supplied | both terms |

Exactly one output may be Objective and exactly one may be Point.

**Orthogonally, the kind of operating point decides `∂p*/∂u` and nothing else:**

| kind | what defines `p*` | `∂p*/∂u` |
|---|---|---|
| interior stationary | `R(p) = 0` | `−∇_u R / R_p` |
| pinned at a bound | `B(p; u) = 0` | `−∇_u B / B_p` — *the same quotient, a different condition* |
| pinned at a registered constant | `p* = φ_k` | the unit vector in `φ_k`, exactly; zero in every state direction |
| exogenous — shut down, or a tracked ODE state | nothing | zero (shut) or carried by the adjoint (tracked) |
| fold, or a solve that could not move | — | **refuse** |

**That factorisation is the whole design.** The current implementation entangles the two axes: it
has one function per *kind* — `record_leaf_outputs` and `record_zero_flux_outputs`, whose own
declaration admits "separate … because it shares none of it: no curvature, no envelope step, no
bound, no collar" — and inside each, per-*role* special cases written as ten `pinned ? … : …`
ternaries. Three kinds cost 1023 lines and the growth law is ~230 lines per kind. phylloptim
classifies **twelve** kinds; report 05 §7.0 names **five** that matter and observes they are
consecutive segments of one drydown. Separated, a kind is one row of the second table and a role is
one row of the first.

### 3.2 What the ecology says about each row, and why the asymmetry is real

**The Objective row is free, and that is a statement about adaptation.** At its own optimum a plant
is indifferent to small changes in its own behaviour, so a shift in the environment moves profit only
by its direct effect. This is why the most expensive part of the model costs nothing to differentiate
for the quantity that matters most.

**The Ordinary rows are not free, and that is where competition lives.** The plant is indifferent
about profit; it is not indifferent about *water*. Per-layer uptake is set as a side effect **at**
the operating point, so it consumes the argmax rather than being the objective, and the envelope
theorem says nothing about it. Since plants interact only through two shared fields and the water
field is depleted by uptake, `∇_u R` is the first link of **the only belowground competitive coupling
this model has**: my uptake lowers the soil potential, which reprices your water-for-carbon exchange
rate, which moves your operating point, which moves your uptake.

**And the direction the ecology cares about is the worst-conditioned one.** Water moves on
*differences* of potential while tissue fails on *absolutes*, so along the uniform drying direction
the model is a near-symmetry: the true flux response is a small residue on a channel amplified
fifteen- to twenty-six-fold. The corpus's own rule is that anything defined as a small difference of
large quantities must be computed as itself, never by subtraction in a caller — which is why §3.5's
`(a, b)` fit is a correctness item and not a cost item.

**A pin is drought.** A plant pinned at its zero-uptake bound has closed down; one pinned at its
critical potential is at the edge of hydraulic failure. Any conclusion about drought sensitivity
rests on the pinned branch being right, and there `ν = ∂Π/∂p` is the constraint's shadow price — the
carbon the plant would gain per unit of relaxation it cannot have.

**Exposing the operating point as an output is what makes one machine serve two consumers.** A
calibration fits a leaf against gas-exchange observations, so its outputs are the measured ones —
assimilation, conductance, stem potential, profit. A stand adjoint wants none of those except profit
and wants one the other does not: per-layer uptake. **The two sets overlap in exactly one entry.**
With the operating point declared Point, both contract through the same scalar and neither needs its
own copy of the argmax machinery.

### 3.3 The interface, written out

phylloptim gains one entry point. The enumerations are already its own; what is new is a role per
output, an observation-dependent output count, and rows returned in **parts** rather than totals.

```cpp
namespace phylloptim::gradient {

// How the operating point reaches an output. At most one Objective and at most
// one Point; the caller's request is refused if it declares two of either.
enum class Role { Objective, Point, Ordinary };

// Why an entry is zero, where it is. A bare zero cannot say, and an exact zero
// is the signature of a missing row far more often than of true insensitivity.
enum class Zero { none, slack, structural };

struct RowRequest {
  const int*  output;  const Role* role;  std::size_t n_output;  // into output_names()
  const int*  input;   std::size_t n_input;                      // into par_names(n_layers)
};

struct Rows {
  OperatingPointKind kind;          // by the branch taken, never from a residual
  std::string        message;       // set only where the kind is one that refuses

  OutputValues value;               // read them HERE: this call re-supplies the
                                    // base state without re-solving it, so the
                                    // leaf's own members hold the last
                                    // perturbed evaluation afterwards

  double point;                     // p*, the value the solve left
  double residual_slope;            // R_p at an interior point; B_p at a pin;
                                    // NaN where no condition defines the point
  std::vector<double> dresidual;    // n_input: grad of whichever condition defines p*
  std::vector<double> dy_dp;        // n_output: 0 for Objective at an interior
                                    // point, nu at a pin, 1 for Point
  std::vector<double> frozen;       // n_output * n_input, output-major
  std::vector<Zero>   zero;         // n_output * n_input, output-major
  double amplification;             // max_i |dresidual[i] / residual_slope|
};

Rows rows_at(Leaf&, const double* theta, const Drivers&,
             const RowRequest&, const Settings&);
}
```

**Three corrections to the shape above, from reading it against the packages.**

*`finite` is deleted.* The kind already says whether a row exists -- a fold and a
solve that could not move are kinds -- and a second way to ask the same question is
§3.3's own complaint about the five mechanisms, reintroduced one field lower.

*The input enumeration already carries root carbon, and the arity is already
`n_pars + 1 + 2L`.* Both landed with `rows_at` itself; what was missing was a value
reader and the perturbation, not the count. §5.2's assertion still cannot be written,
but for a different reason: see there.

*And the scarce resource here is not the 49.1%.* Four traits stay differenced under
§3.5's own test, so eight re-solves an operating point are fixed in place and this
interface cannot buy them back. What it buys is the number of independently-maintained
statements about one physical point: 976 lines, two classifications, five feasibility
mechanisms, one of fourteen trait names already disagreeing, and two packages
contradicting each other in code about `stem_b`'s row. Cost is the reason to want the
leaf faster; **agreement** is the reason to want this interface.

**Rows come back in parts, and the reason is a cost bound rather than taste.** Returning totals would
have the caller record `n_output × n_input` tape terms. Returning the parts lets the operating point
be **one node** that every output hangs off, so the tape holds `n_output + n_input`. That is report
02 §3.2's economy — "the matrix `(∂y/∂p)(∂p*/∂u)` is never formed, and the cost drops from outputs ×
parameters to outputs + parameters" — and it is exactly what the reverse-pass branch's
`implicit_root` already does. At 6 outputs and 26 inputs it is 156 terms against 32.

**Two of this section's four deliverables are load-bearing for the consumer and were not
obvious from the shape.** Roles and rows-in-parts can be built and verified against `at()` without
either, and then the consumer cannot use any of it:

- **Per-layer uptake has to be one of the outputs.** The five reported today are the calibration's
  -- assimilation, conductance, stem potential, the collar and profit -- and a stand adjoint wants one
  that is not among them. §3.2 says so in as many words; it is easy to read as motivation rather than
  as an interface requirement, and it is the latter.
- **And it interacts with the pinned convention, fatally if missed.** At a pin the condition's
  gradient is zero for every input, so each of *these* outputs carries a total instead. An output
  that is not one of them therefore has no route to any input at all, and its rows would come back
  exactly zero at every pinned and shut point -- which is where the drought is, and where zero and
  absent are the same number on the tape.

- **Root carbon needed neither owner this section offered, and the refusal was wider than the fact it
  rested on.** The leaf is handed a network already built, so the reasoning went, and nothing here can
  move the carbon behind it. But `duptake_droot_carbon` already recovers a layer's carbon as
  `3 * c_r_V` and differentiates on `1/rc`, so the architecture model's form was inside the package the
  whole time, shipped and tested. Both resistances the solve reads are proportional to `1/carbon`, so
  each one's own constant cancels out of a relative perturbation: a perturbed network is an in-place
  edit of the one in hand, needing neither of the two constants nor the layer thickness. The boundary
  does not move and the drivers do not widen. Refereed against the architecture model run again from
  moved carbon, which shares no code with it: bit-identical on all 45 values.

  What is refused instead is narrower, and it is named rather than left as a zero: the
  single-potential path, which builds its own one-element network and would report exact zeros for a
  perturbation it never reads; and, per input, a layer the network holds no roots in, where a zero
  would claim insensitivity to carbon that could be put there.

**A pin is answerable but not in parts, and that is measured rather than argued.** §3.1's pinned row
`∂Π/∂u + ν·∂p*/∂u` is right as mathematics and not evaluable as two halves: the held half needs the
collar held at `p*`, and at a pin `p*` sits one step-in from the bound, so moving the bound carries
the collar out of the feasible interval and an arm crosses. What is available is the total, by
following the point. So at a pin the total goes where the held partial would, that input's entry in
the condition's gradient is set to zero, and the assembly returns the total identically -- rather
than recovering the held half as `total − ∂y/∂p · ∂p*/∂u`, a difference of large quantities this
corpus requires be computed as itself.

Two consequences, both forced. **The operating point is a passive node at a pin**, since the
condition's gradient is then zero for every input, so the outputs' rows are independent totals and the
`n_output + n_input` economy is an *interior* economy -- at a pin it is `n_output × n_input` again,
which is what the consumer already pays there. And **`∂y/∂p` is not a number at a constrained state**
for the three outputs whose collar channel cannot be centred on `p*`, so a consumer must skip that
channel where an input's route to the point is zero: not-a-number times zero is not zero. A test that
compares against not-a-number and reads the false as agreement will report a clean zero over columns
it never checked.

**The quotient and its refusal stay in odelia**, because they are properties of the implicit function
theorem rather than of leaves. phylloptim returns `∇_u` of *whichever condition defines the point*
and that condition's own slope; `implicit_root` divides and refuses. At a pin this is the same call
with the bound's residual — which is why the pinned case needs no second code path anywhere.

### 3.4 What plant becomes

The whole leaf integration, replacing 1121 lines:

```cpp
const auto r = phylloptim::gradient::rows_at(leaf, theta, drivers, request, settings);
// A not-a-number means the row does not exist, and that is the only thing it
// means: an entry the arithmetic makes an identity comes back as the identity.
// Profit's loss ends the gradient; a water row's leaves the value the balance
// still needs.
scan(r.held);

// The operating point: one node, whatever defines it -- and where nothing does,
// a unit slope beside a gradient of zeros IS a point that does not move.
const S p = odelia::implicit_root<S>(r.point, r.residual_slope, zip(u, r.dresidual));

for (std::size_t j = 0; j < n_output; ++j) {
  auto terms = zip(u, row_of(r.held, j));
  terms.push_back({p, r.dy_dp[j]});
  *into[j] = odelia::record_with_derivatives<S>(r.value[output[j]], terms);
}
```

**plant does not branch on the kind at all**, which is stronger than this section first claimed and is
what the identities buy. It could not have branched on it anyway: the kind is not a proxy for whether
rows exist, since ten of a hundred and four pinned points come back with none while ninety-four
answer. What plant reads is the numbers -- a not-a-number is the absent row, everywhere. It never
branches on the role. Every `pinned ? … : …` ternary, the shut sibling, the trait table, the drive
loop, the arm chooser, the restores, the column order and its three reassemblies have nowhere left
to live.

**A refused Ordinary row is metric-level.** Report 05 §7.0: a sum has no defined value with an
undefined term, so no localisation is available and refusal is per metric, never per cohort. The
`zero` channel carries `slack` and `structural` outward into `gradient_status`, which is the right
abstraction already and does not change.

### 3.5 The root cause is the vulnerability tabulation

Four traits — `stem_b`, `stem_c`, `root_b`, `root_c` — must currently be differenced by re-solving,
because the curve's grid

$$\psi_{\max} = b\,\bigl(\log 100\bigr)^{1/c}$$

is a **function of the traits being differentiated**, and the forward model rebuilds it whenever
either moves. Report 05 §7.6's test settles what that means: *does the forward model rebuild the grid
when the parameter moves? If it does, the motion is the model.* So a row taken on a held grid
differentiates a different function.

Everything downstream follows from that one fact:

- a rebuilding `set_traits` cost **21.8 µs** against **0.02 µs** when it does not rebuild and ~**3 µs**
  for a whole leaf solve, so eight rebuilds per operating point looked like **58 solves' worth**.
  **That reading is spent, by a later measurement in this same corpus.** The rebuild is memoised on
  the pair that determines the curve, and nine `set_traits` over the four curve traits went
  **194 µs to 2.2 µs**; in situ the whole drive family is **24 µs of a 278 µs cohort block**, which
  is dominated by recording the cohort's rates at an active scalar — 271 of those 278. So the prize
  here is about **a tenth**, not the 56% the per-drive cost implied, and the cost argument for this
  step is not the one to lead with;
- `a` had to be *fitted* from a differenced direction rather than differentiated;
- and the two packages **contradict each other in code**: phylloptim claims `perturb_stem_b` is exact
  by homogeneity and worth 24.5×, plant measured that identity 1.9e-04 out against a rebuild's
  2e-06 and rejected it. Report 05 §7.6 agrees with plant and with the same numbers — the rescale
  sits at 0.99981 of a rebuilding reference where the rebuild sits at 1.000002.

**The fix is in the corpus already, and half of it is already deployed.** The series is in code,
returning the value, the integrand and both trait partials from one loop — and the value and the
integrand now **seed the knot table**, so the substitution this section prescribes has landed for
them. What is unused is `dG/db` and `dG/dc`, read by nothing but their own test. The flux integrates a
stretched-exponential vulnerability curve,

$$G(m) = \int_0^m \exp\!\Bigl[-\bigl(\tfrac{\sigma}{b}\bigr)^{c}\Bigr]\,\mathrm{d}\sigma
      = \frac{b}{c}\,\gamma\!\Bigl(\tfrac{1}{c},\,X\Bigr), \qquad X = \bigl(\tfrac{m}{b}\bigr)^{c},$$

and report 05 §7.6 gives `∂G/∂m`, `∂G/∂b` and `∂G/∂c` in closed form from one series with one extra
accumulator. **The 1e-23 against an independent high-precision integral is not in code anywhere** —
no script, probe or test computes it, so "the best-established derivation in this corpus" rests on a
number nothing checks. What the code does assert, over the same domain, is 1e-7 against a central
difference *of the same double-precision closed form* and 1.2e-15 against boost's value. Closing
that gap is cheap and belongs before the derivation is leaned on for a re-blessing. They
are unused because the only correct deployment is to replace the **table**, not its derivative:
substituting a closed form for a tabulated derivative is the more accurate derivative of a different
function, and introduces a systematic disagreement no invariant on the gradient can attribute.

The series argument is bounded by construction: the grid runs to where the vulnerability function
reaches a fixed small fraction, so `X = log(1/fraction)` identically and `x ≤ 4.61` wherever the
integral is evaluated — **for the stem curve, which `psi_crit` bounds. It is false for the root
curve, and the instruction that follows from it is the wrong way round.** The root integral spline
extrapolates past its last knot deliberately, under a `G(inf)` cap, because a layer drier than the
grid is an ordinary state and the soil potential a caller may pass is bounded only by its own
ceiling of 1000 MPa. At that potential `x` is about **2.9e6**, where this series overflows: its terms
sum to `gamma(a,x) e^x / x^a`. So the bound holds only *because* the table absorbs those reads, and a
closed form replacing the table has to carry the complete-gamma limit as a genuine branch — which is
the same cap the accessor already applies, so the cost is a named switch rather than new
mathematics. Assert the bound on the stem curve; give the root curve the limit.

**Making that change removes the grid, and with it:** the rebuild cost; the four differenced traits,
which become exact — `b` by the homogeneity `ψ ∂G/∂ψ + b ∂G/∂b = G`, `c` by the series' own
`a`-derivative; the two packages' disagreement, which dissolves rather than needing adjudication; and
the reason `a` could not be differentiated.

**This is a forward-model change and must be re-blessed as one.** The discipline is phylloptim's own,
established the last time it collapsed two implementations of one algebra: a hand-maintained parallel
copy *had already drifted* — one associated a bracket differently and used `s*s` where the other used
`pow(s,2)`, so "the AD derivative was the derivative of a slightly different function than the model
evaluated" — and the measured cost of the fix was 4.98e-07 on the golden grid. **One body, not two:**
the closed form replaces the table as the model, and the table is deleted rather than kept beside it.

### 3.6 The residue, named

One thing cannot be answered from the parts: **the conductivity spline is reachable from the
residual, via `uptake_impl`'s equal-potentials branch, and has no derivative accessor at all.** It is
the only one of the leaf's four splines read without one.

**Neither of the two options this section offers is the right one, and the code already says why.**
The derivative path does not silently return a wrong number: it returns NaN for the whole vector on
that window, under a stated contract that the caller falls back to a central difference. And plant
already absorbs it — it steps off the coincidence by 4e-8, retries both directions, and tallies the
step-off as a clamp — on the argument that the resistance there is `span/integral`, which *is*
`1/f_r` at coincidence and **analytic through it**, because the two signs cancel and one expression
serves both sides. The singularity is arithmetic, not a property of the model.

So the honest move is neither an accessor nor a refusal: **make the equal-potentials branch read
`span/integral` like the general branch.** That deletes the branch, deletes the only consumer of the
conductivity spline, and deletes a NaN window a caller currently has to know about. The function is
already available in closed form in the same file — the cost path evaluates `exp(-(psi/b)^c)`
directly — so what the spline tabulates is something the leaf computes anyway, on a branch that
fires only within 1e-8 MPa of coincidence. This is the one piece of §3.5's subject worth doing on
its own, and it is a deletion rather than an addition.

---

## 4. The grid

### 4.1 The mathematics: the abscissa decides the weights

A census, and each of the two field reductions, is a quadrature of a **density** against a
per-individual quantity:

$$\mathcal{C} \;=\; \sum_s \sum_k w_k \, n_k \, \mathfrak{m}(h_k, \varphi).$$

`n_k` is a density *in the coordinate the distribution is carried on*, so `w_k` must be gaps in
**that** coordinate. On the birth-date coordinate `w_k` is built from introduction times. Building it
from heights computes `∫ n \,\mathrm{d}h` where `n` is a density in `b` — a different integral of a
different density, **wrong on every stand and not only on a crossed one.**

Two further facts follow from the same choice, and they are one fact seen from opposite ends. Because
`b_k` is fixed at birth and passive, `∂w_k/∂(\text{state}) = 0`, so the transpose carries no weight
term; and on the height coordinate the density acquires the compression term
`∂g/∂h` while the transpose acquires the matching weight derivative. Report 09 §4.1 states the
identity; the consequence for an interface is that **passivity is the property to enforce, and the
mechanism is a return type**: a coordinate accessor returning `double` unconditionally makes both of
report 05 §6.1's first two conditions unviolatable rather than testable.

### 4.2 The measurement, which was why this was a correctness item

**This section has been overtaken, and the overtaking is the finding.** Every quadrature over the
size distribution now takes the coordinate the density is carried in, read through one accessor
whose return type is `double`. The last of them was routed through it the day after this section
was written, so what follows argued for work that is done rather than work that is left. Three
consequences, each checked against the tree:

- **The figures below describe code that is gone.** The census cannot be run on a crossed height
  grid at all now — it refuses — and the fused reduction's "100% relative" disagreement with the
  plain value reduction is unrepresentable, because the plain reduction *is* the fused one's first
  entry. What is asserted in its place is `16.8846` against `17.1720`: the +1.70% the choice of
  coordinate is itself worth.
- **The one grid still built without the accessor was the resource reduction.** It spelled its own
  passivity rationale in a comment and reversed its traversal to compensate for not negating
  heights. It reads through the accessor now, and the two projections that existed only to feed
  its two traversals are gone with it.
- **The hand-written transposes these figures were taken on no longer exist**, so the defect
  report 09 §4.1 parks on the unsupported branch — the closing interval's transpose writing only
  one end — is moot at the source level rather than fenced.

So §4's correctness case is spent. What survives is §4.3's abstraction question, and the
interval-major argument, which still has teeth. For the record, the figures that made the case:

| quantity | measured |
|---|---|
| leaf-area census, as-ordered against height-sorted, same state | **3.95%** |
| height moment, same | 3.91% |
| heartwood moment, same | 4.00% |
| the fused value-and-slope reduction against the plain value reduction, birth-date coordinate | **100% relative**, while agreeing bit for bit on the height coordinate |

The last line is the sharp one: the value reduction took its widths from the abscissa and the fused
reduction that **actually builds the field** took its widths from heights. Same map, two spellings,
one wrong.

**And the two failure modes are opposite, so one guard cannot serve both.** Where the grid is the
birth date, monotonicity is free — birth dates are strictly increasing by construction, so the guard
is an assertion and no sort is needed. Where a user-facing helper genuinely integrates over height,
crossing is real and it needs a sort or a refusal. A sort by height at the first site would be
*actively wrong*: reserve-gated growth makes crossing **more** common on the birth-date coordinate,
not less, so a guard testing height order refuses exactly the stands the forward model runs
correctly. Ecologically this is the observation that **plants can change their relative size but not
their relative age.**

### 4.3 The interface

One object, owned by the model, used by all four:

```cpp
// The size distribution's quadrature grid. The coordinate is whatever the
// density is a density in; the accessor returns double unconditionally, so a
// width cannot carry a derivative however a caller stores its grid.
class Grid {
public:
  double coordinate(std::size_t k) const;      // NOT the model's scalar type
  std::size_t size() const;

  // Interval-major, because the forward's association order is asserted
  // bit-exactly and a per-slot weight vector cannot reproduce it: the caller
  // keeps its own accumulator and is handed one interval at a time.
  template <class Visit> void intervals(Visit&&) const;

  bool monotone() const;                       // an assertion on this coordinate
};
```

**Interval-major is forced, not chosen.** `Σ w_k f_k` and `(Σ width_i (f_lo + f_hi))/2` are the same
map with a different association, and the forward's association is asserted bit-exactly against the
plain value reduction over 200 heights and seven crown shapes. Association order is a floating-point
decision, and it belongs to whatever owns the walk.

**One degenerate interval per event is deliberate and must stay free.** An event stamps the inserted
element and refreshes the closing element's coordinate to the same time, so the closing interval has
exactly zero width at that instant. No width is divided by anywhere in the quadrature or its
transposes, so a degenerate interval costs nothing — and the guard is correspondingly split: strict
monotonicity on the interior grid, non-strict at the closing point.

Whether `Grid` lives in odelia or in plant is decided by whether odelia's general system has a
coordinate on its unit list. **It does not, and the citation was to prose rather than to code.**
Report 09 §1's "units" is an English description of the model's shape; nothing in odelia's headers
encodes it. What odelia knows about an element is seven members of state and rate plumbing, its
state is a flat vector, and it keeps the growth event deliberately opaque — "what they mean, and
how many one widening adds, is never read here". There is no coordinate, no position and no
reduction anywhere in it.

So the generalise-only-over-witnesses rule runs the other way: all four witnesses live in one
plant class, `abscissa_of` is already the one accessor they read, and putting a `Grid` in odelia
would be a new abstraction over a shape odelia has never named. If it is worth building, it is
plant's. What odelia does have that is worth copying is the pattern rather than the object — its
spline holds active knot *values* against `double` knot *positions*, which is the same passivity
by return type, already generalised.

---

## 5. The parameter

### 5.1 One list with a role, not two lists and a string comparison

Today there are two enumerations of one thing: `field_ptrs()` with 62 entries — what a rebind carries
— and `ad_parameters()` with 47 — what is differentiated. Fifteen are excluded for two stated
reasons: two reach a base of zero in a `u^k` whose recorded derivative `u^k log u` is not a number,
and thirteen are read by no equation on this path. On top of that, `ad_parameter_zero_classes()`
re-derives slackness **by string comparison** on the parameter's own name.

The exclusions are not one thing. They are two of `gradient_status`'s own kinds, and that structure
already exists:

```cpp
enum class ad_role {
  differentiated,   // a column; an exact zero there is undeclared
  zero_slack,       // a column; an exact zero is complementary slackness
  zero_structural,  // a column; an exact zero is structural, on any trajectory
  refused,          // no column: the model cannot answer for it, and says so by name
  unread            // no column: reaches no equation on this path
};
struct ad_parameter { S* value; const char* name; ad_role role; };
#define PLANT_TF24_AD_PARAMETER(x, r) ad_parameter{&x, #x, ad_role::r}
```

**Five values, not three, and the correction matters.** Three cannot express what the table has to
say: `zero_slack` and `zero_undeclared` are two of the five kinds the status channel already
carries, and this step's own test is that the R-facing classification is *unchanged in value* — so
the declaration those two zeros come from has to survive the move rather than wait for §3.3. It
also has to distinguish the two reasons a parameter has no column, because one of them is a refusal
the model should report by name and the other is a parameter no equation reads. Whether an entry
has a column is then derived from the role rather than stored beside it.

**And the table belongs on the parameters, not on the strategy**, because `field_ptrs()` is called
on a bare `TF24_Pars` in the rebind, where no strategy exists to hold a table.

One consequence to accept rather than work around: with one table there is one order, and the
declaration's is the one the size assertion and the rebind already pair against. Two parameters that
had been appended out of order move, so their gradient *column positions* shift while every name,
value and zero class travels with them. A caller indexing a column by position feels that; there is
one such caller and its index is user-supplied.

One table. `field_ptrs()` is the whole of it; `ad_parameters()` is a filter on it; the `static_assert`
on `sizeof(TF24_Pars<double>)` that makes a forgotten member a compile error stays as it is. The
string comparison dies. And the two crown-shape parameters become `refused` **by name**, which
discharges a standing want: report 06 §11's domain table lists "refused by name — none; the set is
empty", with the note that a trait losing a row belongs there rather than returning a zero.

**`zero_slack` is not a role.** Complementary slackness is a property of the *operating point* — the
critical potentials are zero at an interior optimum because the point is not sitting on the bound
they set, and live at a pin — so it is per-request and comes back in §3.3's `zero` channel from the
package that knows which branch was taken.

### 5.2 The leaf's input table is verified against phylloptim's names, once

plant currently maintains its own copy of phylloptim's 14-trait enumeration in four parallel arrays
plus three masks, restated again in the shut sibling — nine tables in the two AD functions, fourteen
in the file, of which **three disagree in name**. Slot 12 is spelled `g1_TF24`, indexed as
`k_cost_scale`, and *is* phylloptim's `cost_scale_TF24` — a hydraulic cost scale, not a stomatal
slope — and every consistency check downstream agrees with the meaning rather than the name.

The fix is the pairing clause across a package boundary. plant declares its inputs **once**, in
phylloptim's order, and checks the names at construction:

```cpp
struct ad_parameter { S* value; const char* name; ad_role role; int leaf_par; };
#define PLANT_TF24_LEAF_PARAMETER(x, r, p) \
  ad_parameter { &x, #x, ad_role::r, phylloptim::gradient::par_##p }
```

**Not a second table, and not a name lookup.** The fourteen are already declared here, so what is
missing is one field: the leaf's own index, and `-1` for a parameter the leaf has no input for.
`theta` is then filled by SCATTER, so the leaf's order is never restated on this side, and the filter
is one comparison.

**And the assertion this section wanted cannot be written, for a reason that is not the arity.**
`n_pars_total(L)` counts a series resistance belonging to the single-potential supply path, which
this leaf is never on, so the two counts differ by one and always will. What can be written is
`static_assert(n_pars == 16)`, which fails the day the leaf grows a parameter this file has not
decided about -- the only drift a count could have caught.

**A name lookup would catch the rest, and it has nowhere to run.** The layer count is not a property
of the strategy; it arrives with the environment, inside the rate call. So resolution would run per
unit per step, or be cached against a count that can disagree with its source. It buys nothing
either: `par_cost_scale_TF24` IS a name, resolved by the compiler, so writing the leaf's spelling
beside this file's in the declaration makes a rename on either side a compile error. Four of the
fourteen differ, and that is where they are now written down.

---

## 6. The loader

### 6.1 The stage, and why the boundary is evaluated twice

```
per stage, given y and t:

  R₀ = reduce(units)                    the shared part, closing element omitted
  b₁ = boundary(R₀, y, t, φ)            the inflow condition, evaluated in R₀
  R  = R₀ ⊕ close(b₁)                   the shared part the rates read
  ──────────────────────────────────────────────────────────────────────────
  rates_u = F(u.state, read(R, u), φ)   per unit, independent
  ──────────────────────────────────────────────────────────────────────────
  b₂ = boundary(R, y, t, φ)             the SAME condition, evaluated in R
  R' = reduce₂(unit outputs ⊕ close(b₂))
  dydt = assemble(rates, R')
```

The two evaluations are not a detail. The boundary node's density solves a scalar fixed point,

$$n_b \;=\; B(t)\cdot \mathrm{pr\_estab}\bigl(L(h_0;\,n_b)\bigr),$$

because the node contributes to the field it is placed in — it is the lower endpoint both field
reductions integrate from. They differ by more than `1e-6` relative, with a test asserting it, and
`b₂` is what an introduced node inherits and what the census reads.

**The model does not iterate that fixed point, and calling `b₁` an iterate from `n_b = 0` reads it
the wrong way round.** `A₀` omits the closing interval entirely, not just the half of it that
depends on `n_b`, so `A₀` is not `A` evaluated at `n_b = 0`; the reduction that builds it never
reads the boundary node at all. That is what makes a stage a function of `(y, t)` and nothing else,
and the code says so in as many words — the cycle is removed by ordering rather than closed by
iteration, because iterating it "only attenuates the carried dependence by the contraction
modulus, which is ~1e-3". The two evaluations are one sweep of a fixed point the model declines to
close, which is a stronger statement than one step of it.

### 6.2 It is the un-re-derived-aux defect in a different costume

`b₂` is a **pure function of `(y, t, φ)`** — deterministic, derived, carried by nothing. The second
loader exists only because the ordinary loader stops after `b₁`, so a reverse pass reloading a
recorded state linearises the boundary at the wrong argument.

The corpus already has the rule and has already paid for breaking it. Report 04 §5.1: *re-derive a
state's dependent slots wherever that state is written, or write it through the setter that does* —
an invariant "a strategy can quietly break, because breaking it changes no number." When it was
broken for the seed's leaf area the value was right, no forward test moved, and the boundary
density's row came back **154 times** the truth.

### 6.3 The prescription

**One loader, and one invariant:** *loading a recorded state reproduces every derived quantity the
recording held.* That is checkable without a gradient — load a recorded state, then compare every
derived slot bit for bit against what the run recorded — and it is strictly stronger than the current
arrangement, which asserts the same thing by having two functions and a comment saying which to call.

`set_recorded_state` then leaves the concept — which is spelled `WidensState`, and which does name
it and *is* asserted, gating five of odelia's own `requires` clauses — and report 09 §3's read-point
list, a declaration with exactly one instance whose own text concedes that "a second model with two
read points is what forces the declaration", is not built.

**Three things measured against the tree, before this is built.**

*The invariant's scope is larger than "every derived quantity" suggests, and part of it is not
derived at all.* Three members are not functions of `(y, t)`: the survival weight and patch density
a node was born at, and an introduced node's own birth date. They survive today only because the
sweep narrows and widens the same live patch. Nine of TF24's aux and every rate are reproduced by
*neither* loader — only the two that `update_dependent_aux` covers are. And the recording the
comparison would be made against holds `ode_state()` only, which does not include the boundary
node, so the instrument does not currently hold the thing the invariant is about.

*The collapse is safe on the forward path, and that is checkable rather than hopeful.* Nothing is
read between a load and the rates call that follows it, the field is never rebuilt from the second
evaluation, and the reduction that forms `A₀` never reads the boundary node — so an appended `b₂`
cannot reach the next stage either. What it costs is one test that asserts the two evaluations are
distinct, six extra boundary leaf solves per step **on the forward path** — which by the cost
document's own asymmetry rule raises the bar the ratio is measured against — and one bit-identity
nobody has taken: whether the boundary evaluation alone reproduces what a full rates pass leaves on
the node, given that every node of a species shares one leaf and its temperature memo. Today's
second loader already rests on that identity, so the probe is worth taking whether or not the
collapse is.

*And the one-loader shape already exists in this tree.* The stochastic patch's loader runs the
environment build and the rates, which reaches all of the list above — where a load plus a boundary
evaluation reaches exactly one member of it. If one loader is the goal, that is its shape.

---

## 7. The solver's concept surface is inverted

Today the mandatory core is duck-typed and the optional extras are conceptualised. `ode_size`,
`ode_state`, `ode_rates`, `set_ode_state` and `reset` are named by **no concept at all**, and
`ad_parameters()` — the entire parameter half of every recording — is named by none either, so a
System with `rebind_from` and no `ad_parameters` passes the codebase's only `static_assert` and fails
deep inside the recording. Meanwhile `WidensState` is satisfied by nothing in odelia, asserted
nowhere in odelia, and gates five functions.

Three concepts, each asserted where it is used:

```cpp
template <class T> concept System =         // mandatory
  requires { typename T::value_type; } && requires(T s, /*…*/) {
    s.ode_size(); s.ode_state(it); s.set_ode_state(it); s.ode_rates(it); s.reset();
  };

template <class T, class U> concept Differentiable =    // reverse mode
  System<T> && requires(const T& s) {
    { s.template rebind_from<U>() };
    requires std::same_as<typename decltype(s.template rebind_from<U>())::value_type, U>;
    { std::declval<T&>().ad_parameters() };
  };

template <class T> concept Grows =          // dimension growth
  System<T> && requires(T s, const typename T::widening& w, /*…*/) {
    typename T::widening; s.widen(w); s.narrow(w); s.widened_state(w, time, in, out);
  };
```

Optional hooks — `record_ode_step`, `ode_state_valid`, `ode_time` — stay detection-by-absence with
`if constexpr`, because absence is a meaningful answer there and a concept with more members than its
consumer needs invites a model to opt into a contract it does not mean.

**Assert a concept where it is used, not where it is defined.** The instance worth remembering: a
concept describing the widening walk was referenced by nothing, and meanwhile the walk had acquired a
call to a member the concept did not name — so a System satisfying it in full still failed inside
that walk.

---

## 8. The order to build in

Each step is refereed by the one before it, and nothing is deleted before its reference is captured.

| # | change | done when | refereed by |
|---|---|---|---|
| **1** | **Merge the branches.** Rebase the 13 hardening commits onto the 46 solver commits; re-author rather than merge the `patch.h`/`scm.h` hunks, which sit on deleted structures; re-home the soft refusal at metric grain. Appendix B. | the ladder passes on the joined tree, and the hardening's incidence and parity tests still hold | the ladder |
| **2** | **Capture the reference.** `ladder_run_difference_pair` on the two-species competing stand, at every kind of operating point reachable, stored to disk. | every kind has a stored reference | — |
| **3** | **§4: the last grid through the one accessor.** Done, and smaller than this row assumed: every quadrature already took the density's own coordinate except the resource reduction, which now reads `abscissa_of` too. No `Grid` object; §4.3's argument for putting one in odelia does not hold. | one accessor, one traversal, and the two projections that fed the old one deleted | bit-identity of the gradient on the birth-date coordinate, which is the only one the sweep runs |
| **4** | **§6: one loader.** *Probe first.* `set_ode_state` reproduces every derived quantity; delete `set_recorded_state`. The collapse is forward-safe, but it costs six boundary leaf solves a step on the forward path and rests on an identity nobody has measured -- that the boundary evaluation alone reproduces what a full rates pass leaves on a node whose leaf is shared with every other node of its species. Take that probe before writing anything. | the probe holds, then the load/compare invariant holds bit for bit over a recorded run | bit-identity of the loaded state, and the recording extended to hold the boundary node it does not hold today |
| **5** | **§5: one parameter list with a role.** One table of 62 carrying `ad_role`, three hand-maintained lists collapsed to one, and `ad_parameter_zero_classes()`'s string comparison deleted. `eta` and the root-depth shape exponent become `refused` by name -- neither is a crown shape, and both would record a silently wrong zero rather than a NaN. | one table; the R-facing zero classification is unchanged in value | the declared-zero ladder rung, and the registered-versus-declared test, which was landed failing for exactly this reason |
| **6** | **§3.5: mostly overtaken, and re-scoped.** The series already seeds the knots, so the value substitution has landed; the rebuild is memoised, so the prize is about a tenth rather than 56%; and deleting the table needs the complete-gamma limit as a real branch, because the root curve extrapolates past its grid by design. What is worth doing on its own is **§3.6: delete the equal-potentials branch** in favour of `span/integral`, which removes the conductivity spline's only consumer and a NaN window with it. Note a golden re-bless is **already owed** from an earlier commit, and only macOS/arm64 can settle it. | the branch is gone, the spline with it, and no NaN window is left for a caller to know about | a Linux-versus-Linux golden A/B, which is exact and has no noise floor -- `--cross-platform` cannot see an argmax-field change below ~5.5e-4 |
| **7** | **§3.3: `rows_at` in phylloptim.** Roles, an observation-dependent output count, per-layer uptake as outputs, root carbon as inputs, rows in parts. Take plant's arm robustness and phylloptim's sentinel handling — each package has half. **The arm robustness is three rungs, not one, and their ORDER is load-bearing:** centred, then one-sided to second order where a single arm is inside, then the bound followed where a re-solved arm leaves the branch, then shrink, then refuse. Following the bound must come after re-solving — where both arms stay on the branch the two placements are different rows, 3.82 relative apart on assimilation at a wet pin. | one row layer; `transpose_at` and `rows_at` share `at()` | the transpose identity `⟨v,Ju⟩ = ⟨Jᵀv,u⟩`, which needs no reference gradient |
| **8** | **§3.4: plant's leaf integration.** Delete `record_leaf_outputs`, `record_zero_flux_outputs`, the trait tables, the drives. | §3.4's form is what is there, and it is not six lines: 1121 out and 221 in. What the count leaves out is that the rows are gone and what remains is a declaration — which is what report 09 predicted and this row did not | step 2's stored reference, at every kind |

**Steps 3 to 5 are independent of 6 to 8** and each is worth landing alone. Step 6 is the largest
single return and is the precondition for 7 being simple, because with the grid moving, four of the
row layer's inputs cannot be answered analytically at all.

**Do not delete the differenced implementation before step 2.** A change from differenced to analytic
returns a finite, plausible, wrong gradient when it is wrong, and the differenced implementation is
the only reference that exists today.

---

## 9. What this is bad at

**It changes the forward model once, on purpose.** Step 6 replaces a tabulation, so the golden grid
moves and must be re-blessed. The precedent measured the analogous collapse at 4.98e-07, and recorded
that tightening the inner solve's tolerance *first* cut a later unification's blast radius by 1400×,
"because the tolerance was the amplifier". Order the same way.

**It gives phylloptim a consumer-shaped entry point.** `rows_at` takes a role per output, which is a
concession to the stand; a calibration does not need it. The alternative — two entry points — is the
duplication this report exists to remove, so the concession is deliberate and the cost is that
phylloptim's interface now names a concept its own users do not use.

**Two rows still cannot be recorded**, and they must be named rather than hidden: the conductivity
spline has no derivative accessor (§3.6), and a tracked operating point in the acclimating variant
needs its own row from the adjoint rather than from a condition.

**It differences what the leaf can already answer in closed form, and pays twice for it.** The
environment rows go through the same perturbed evaluations as everything else, where the leaf has
`profit_env_derivatives` and the per-layer supply derivative and plant was reaching across the
boundary to combine them by hand. Measured: the uniform-drying direction — the only belowground
competitive coupling the model has, and the worst-conditioned one — reads 7.6e-04 against a bound of
1.6e-04 derived from the fit's own truncation, and the input count roughly triples on a family that
is half a gradient profile. Routing the row layer through the leaf's own closed forms is one change
that fixes the accuracy and the cost together.

**And it evaluates at collars it then discards.** A held row is probed at a collar the perturbed state
may not admit, and the clamp is detected exactly and the arm refused — so no number is wrong, but the
evaluation happened, on a branch where the profit algebra runs against a negative conductance. The
surface that would not evaluate one exists; what it costs is a profit evaluation on the feasible path
too, because the feasible interval's ends are locals the collar solve discards.

**The `Grid` is generality over four witnesses, not over a rumoured fifth.** If a fifth quadrature
appears that is not over the size distribution, it does not belong in this object.

---

## 10. What would falsify this

- **A kind of operating point is not a choice of `∂p*/∂u`.** If any of the five needs an expression
  the chain rule does not produce from §3.1's two tables, the factorisation is false and a per-kind
  body is honest after all. The cheapest place to check is the pin at a registered constant, where
  §3.1 makes the row an identity and the current code derives it.
- **A role is not a property of the output.** If an output is Objective at one state and Ordinary at
  another, the declaration is state-dependent and belongs in the returned numbers instead.
- **Rows in parts do not beat rows in totals.** The claim is `n_output + n_input` tape terms against
  `n_output × n_input`; measure the recording size at production width.
- **The abscissa fix does not move the 3.95%.** Then the census's error is not quadrature error and
  §4.2's attribution is wrong.
- **Deleting the table does not remove the rebuild.** If a curve trait still triggers a spline build
  after step 6, some other grid is a function of it and §3.5 has missed a channel.
- **The load/compare invariant fails on a quantity nobody listed.** Then the set of derived
  quantities is larger than the model believes, and §6.3's check is the instrument that says so.
- **`rows_at`'s transpose identity fails at a state the forward model reaches.** It holds today to
  1.41e-14 over 294 operating points; a fold, a collapsed feasibility window or a tracked operating
  point are where to look.

---

## Appendix A — closed routes, with the evidence

Recorded so they are not re-derived. Each was pursued in this session and abandoned on evidence.

**A.1 An `implicit_value` on a scalar-templated residual.** The idea: tape `R(p; u)` at an active
scalar, so `∇_u R` arrives for every input from one recorded evaluation and the drives disappear.
Closed by five obstacles, any one of which is sufficient: `basic_interpolator::eval` takes `double` at
every level, so all seven spline accessors need graft wrappers; making the residual differentiable
*in p* additionally needs `G″` and `(G⁻¹)″`, and `spline.hpp` has **no `deriv2`**; the transpiration
memo hits on exact `double` equality and returns a stored `double`, so an active call that hits gets
a plausible value with no derivative attached; `E_up_` and `soil_consumption_` are `double` members
*because plant writes back into them by name*, so typing them breaks plant's bindings; and the eight
temperature members are `double`, so a tangent through leaf temperature is severed at the assignment
— typing them is `Leaf<T>`, recorded as "closed, superseded, not going to be built."

**A.2 Reverse mode inside phylloptim.** `xad::adj` needs `Tape<double>`, declared `extern template`
and **defined only in odelia's `src/Tape.cpp`**. phylloptim carries `LinkingTo` with no `PKG_LIBS`
and a CMake target that records it deliberately links nothing. Reverse mode also puts a
process-global thread-local active tape in play inside a class plant copies per cohort. This is the
concrete form of the standing hazard that phylloptim's `Makevars` is exempt from the XAD storage-class
flags **only while it uses forward mode**, and that nothing will say so when that stops being true.

**A.3 Augmenting the state with the parameters** (`dθ/dt = 0`). Genuinely attractive: it deletes the
parameter argument from five signatures, the replaced-versus-accumulated asymmetry, the aliasing
refusal, the per-seed row pre-sizing, both width checks and `ad_parameters()` itself, and it unifies
the trait gradient with the initial-condition term since both become `ȳ(0)`. Storage is ~1.3 MB and
the arithmetic is nil. **Rejected because the error controller would then see 47 zero-rate
components**, which either changes step sizes — perturbing the forward model for a bookkeeping win —
or requires a new concept, *state that does not count for error*. That trades one seam for another.

**A.4 An implicit-node facility in odelia**, per report 09 §8.1's ten-item interface. The solver has
no stake in what an implicit node *is*: `record_with_derivatives` is the whole of its obligation, and
`implicit_root` earns its 15 lines only because it owns the IFT quotient **and its refusal at a
fold**, which are facts about the theorem rather than about leaves. The remaining nine items are
either already inside phylloptim's `at()` or belong to the model. The one that does earn a place —
naming which output is the implicit quantity and which is the objective — is §3.1's role, and it is a
property of the *outputs*, not a solver hook.

---

## Appendix B — the branch merge

`plant` forked at `cdf3f0c9`. `odelia`'s main-tree head is an **ancestor** of the worktree's and
`phylloptim`'s main-tree head is 14 commits **ahead** of the worktree's pointer, so neither
diverges: the merge is one package.

| | commits | diff | concentrated in |
|---|---|---|---|
| `ad/v3-forward` — the hardened gradient | 13 | +2573 / −258 | `tf24_strategy.h` +858/−131 |
| `ad/reverse-pass-simplify` — the step recording | 46 | +1580 / −2898 | `patch.h` +163/−1330 |

**Direction is forced.** The hardening's hunks in `patch.h` (+111) and `scm.h` (+217) sit on
structures the recording deleted (−1330, −287) — the per-cohort block workspace, its nine hand
transposes, and the introduction inference — so they cannot be merged, only re-authored. Rebase the
thirteen onto the forty-six.

**One item is design rather than porting.** The hardening's soft refusal is enforced per cohort, by
asking whether a given metric's seed reads an uptake output and refusing only those metrics. Under a
step recording that question has no operand rather than no answer: per-cohort uptake is an
intermediate of the rate call, not an output of the recording, so no seed carries a component to
test. The flag also sits on a strategy that is one per species shared by every node once the
per-cohort copy that reset it is gone, so it must land in storage the run still owns.

**The coarser grain is right, and the reason is measured rather than mathematical.** Refusal being
metric-level is what *permits* the selectivity, not what forbids it, so the argument does not come
from there: what report 05 §7.0 rules out is localisation *within* a metric, which is a different
statement and is untouched by the grain. What settles it is that the selectivity saves nothing on
this census — every metric is a size moment, growth reads water, and sweeping backwards gives every
metric a non-zero soil adjoint within a step or two of the census, so there is no water-independent
metric to spare. The ladder asserts that today, on the branch that has the finer grain.

**Two defects to fix in passing.** `tests/cpp/test_leaf.cpp:2690` and `:3101` initialise
`theta[n_pars]` with **15** values against `n_pars == 16`, so every entry from `R_d_25` on is shifted
and the transpose identity is verified at a point with essentially no dark respiration — 3.14e-5
against 1.44 — a conductance **8.5 orders** too large, and series resistance left at exactly zero by
the zero-fill, which is the one parameter the six single-potential points exist to exercise. Sizing
the array from its initialiser and asserting the count against `n_pars` is what makes a short list a
compile error instead of a shift. And phylloptim's `gradient.hpp` says "fifteen" in six places and a
stale "four" outputs in three, where the constants are 16 and 5; one of the three describes the state
before profit became a reported output and contradicts its own next sentence.
