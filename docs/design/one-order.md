# One order

> **Landed, bar a memo.** The leaf's derivative boundary: seven kinds of derivative became four,
> and one interior placement fell from 861 tape statements to 360. Read it before
> changing how a derivative reaches the stand from the leaf.
>
> Three items in the memo are recorded and unbuilt -- the height family, `pushAll`'s
> block form, and widening the transpose identity past four of twelve kinds. They are
> named at the end of `two-paths.md`, which is the live work. Its measurements are in
> `measurements.md`.

**The leaf's derivative crosses to the stand as data, at first order, from
primitives that carry their own slopes.**

That sentence is the whole design. Everything below is what it costs not to have it,
what to build, what is already refuted, and how to know when it is right.

**STATUS: LANDED.** The rule above is now true of the tree. Of the seven derivative
mechanisms this file was written to remove, **four are gone** -- the tangent nested
above the tape, `SecondOrder` and both its lift arms, finite differences, and the
midpoint asymptotic with its three thresholds. What remains is a tabulation for what
has no closed form, primitives carrying their own slopes, a forward tangent and a
reverse tape: the irreducible four. One interior placement fell from **861 to 360
statements**. Steps 6b and 7 are refused rather than pending, and the design space
behind that refusal is exhausted in the memo below.

This is the prescription. `measurements.md` is the record it came out of and carries
the measurements in the order they were taken; nothing here needs that order to be
read. Where the two disagree, this one is the intent and the disagreement is a bug in
this file.

---

## The objective

`census_trait_gradient` is the one product. On the century fixture it costs **131.9 s**
against a **32.6 s** forward run, and about a third of that is one function:
`record_leaf_outputs`, which records phylloptim's whole gas-exchange model onto
plant's tape **once per cohort per RK stage per step** -- 861 statements, 2,333,500
times, two billion recorded statements a gradient.

It does that to obtain, per placement, **one value and one row per input for two
outputs**. The recording is scaffolding for the rows.

The objective is not speed. It is that **a maintainer can read this**. Seven different
mechanisms currently supply derivatives here -- a tabulation, hand closed forms, a
forward tangent, a reverse tape, a tangent nested above that tape, finite differences,
and a midpoint asymptotic with three measured thresholds -- and a reader has to learn
all seven and which applies where. That is the prime directive's failure condition.
The speed is a consequence.

---

## The prescription

> **Every elementary primitive ships with its own slope, as a sibling closed form in
> one definition. A tabulation stores only the lowest order Leibniz cannot give.
> Every root-find is closed by the implicit function theorem on its residual. AD
> composes them. Nothing is differenced, and nothing takes a second derivative of a
> composition.**
>
> **The leaf then works in double and hands the stand values with rows. The stand
> records only the supply.**

`vulnerability_curve_at<T>` and `vulnerability_curve_slope_at<T>` are already exactly
that shape, in one definition, refereed against each other. The rule is not new. It is
applied once and missing everywhere else.

### Why this and not something else

The leaf's operating point is defined **by a derivative**: `p*` is where
`R = dPi/dp` vanishes. So the stand's gradient wants derivative information one order
above the model's own definition -- unless `R` is a function the model HAS rather than
one it computes. Make the two kernel slopes primitive and `R` becomes a value; then
both ingredients of the implicit function theorem,

```
dp*/dtheta = -(dR/dtheta) / (dR/dp)
```

are **first derivatives of R**, and there is no second order anywhere in the model.

### The ecology says the same thing, and says it first

The stationarity condition, written in the quantities the ecology weighs:

```
R  =  lambda * S  -  C'(sigma) * V
```

the carbon bought by the water an extra unit of collar pull draws, against the cost of
the extra tension that pull puts on the stem. **`lambda = dA/dE_up` is the marginal
water-use efficiency** -- this model's central quantity, and the subject of the
companion manuscript.

⚠️ **The code spells it as a derivative to be computed rather than a value the model
has. In an optimality model a MARGINAL IS A VALUE.** A model whose primary ecological
quantity is spelled as a derivative will always need one AD order more than the ecology
does, and every one of the seven mechanisms is that extra order being paid for in a
different currency.

---

## The eight connected components, and how each closes

Traced so that nothing is left needing a mechanism of its own. Two closures only:
**a primitive that carries its slope**, or **the implicit function theorem on a
residual**.

| component | closes by | status |
|---|---|---|
| vulnerability curve `f`, `f'` | primitive with slope | **done** -- one definition, this session |
| its integral `G` | tabulated for the VALUE only; `dG/dpsi` **is** `f` by Leibniz; the trait rows by Euler and the gamma shape series | value done; the derivative reads are the work |
| the layer mean of `f` over a suction interval | from `f`, not as a divided difference of `G` | **the midpoint asymptotic is standing in for this** |
| photosynthesis `A`, `A'` | primitive with slope | **the one genuinely missing pair** |
| hydraulic cost `C`, `C'` | one line over `f'` | missing, and nearly free |
| transport `sigma`, `V` | the flux balance `kappa(G(sigma) - G(p)) = E_up`; no inverse, no tabulated derivative | **done** -- `V = (S/kappa + f(p))/f(sigma)` |
| supply `E_i`, `E_up`, `S`, `dS/dp` | primitives, all closed form | **done** -- `duptake_dpsi`, `d2uptake_dpsi2` |
| concentration `ci` | IFT on an explicit algebraic residual | done |
| operating point `p*` | IFT on `R` | done, but `R` is not yet a value |
| the two bounds | IFT on `E_up = 0` and on the stem's continuity; the third is a trait, so its row is a unit vector | done |

**Nothing in that table needs an order above the first**, once `A'` and `C'` are
primitives.

---

## The data structure

The boundary is **not "the leaf"**. It is the two waists, `E` and `S`, and once they
are named the logic has nowhere else to go.

**Measured** (`probe_rank`): the whole state reaches profit through `E` alone and the
condition through `(E, S)` alone. Seventeen supply-side inputs, residual **1e-15**.

```cpp
// What the leaf hands the stand. Every field a double: the state does not appear,
// because it reaches this leaf through E and S and nothing else.
struct LeafGraft {
  double profit, collar;                 // Pi* and p*, as the double solve found them
  double dprofit_dE;                     // rank one -- the entire supply channel
  double dcollar_dE, dcollar_dS;         // rank two; both zero where p does not respond
  double dprofit_dtrait[n_trait];        // the direct channel
  double dcollar_dtrait[n_trait];
  double uptake[L], duptake_dp[L];       // the draws, and their chain through p*
};
```

### The graft is acyclic, and the order is load-bearing

`E_i` depends on the collar and the collar's row depends on `E`. It resolves because
everything anchors at the **passive** `p*` the double solve returned:

```
1. record the supply at the PASSIVE p*   187 statements, measured -- E, S and every
                                         E_i, each already carrying the state's rows
2. graft the collar    p  = p* + dcollar_dE(E-E0) + dcollar_dS(S-S0) + traits
3. graft profit        Pi = Pi* + dprofit_dE(E-E0) + traits
4. graft each layer    E_i = E_i + duptake_dp[i] * (p - p*)
```

**About 194 recorded statements a placement, against 861.** Profit's collar channel
never appears -- the envelope theorem as an omitted term rather than one that has to
come out to zero, which is the shape `outputs_at` already uses.

⚠️ **The stand records the supply; it does not receive it.** The supply's closed-form
Jacobian exists (`duptake_dpsi_soil` diagonal, `duptake_droot_carbon` **lower
triangular** because a layer's carbon reaches every layer below it through
`r_R_V_sum`) but supplying it means carrying an `L x L` block and its NaN contract
across the boundary. Recording is 187 statements and asks the model for nothing. This
is `one-reverse-pass.md`'s own rule applied where it belongs: **record what you can
afford, supply only what you cannot.**

⚠️ **Twelve operating-point kinds, not five.** Five is the number of placement arms;
`ShadeDeath` shares the wet one, `HydraulicShutdown` does not move the collar, and six
more must go on throwing so the catch can refuse. The graft needs no branch for this --
the coefficients are simply zero where the collar does not respond -- **but only
because they are supplied numbers.** The envelope theorem holds at an interior
stationary maximum and nowhere else, so an interface that lets a consumer INFER
profit's `p`-channel is correct at one kind and silently wrong at the others.

---

## What to build, in order

Each step lands alone, and **each referee is written before the thing it referees**.
That order is not a preference: it is what the last two increments cost when it was
the other way round.

| | step | referee, written first | |
|---|---|---|---|
| 1 | `dC/dsigma` as a primitive beside `C` | against a tangent through the kernel | **DONE** bit-identical |
| 2 | `dA/dci` as a primitive beside `A` | against a tangent | **DONE** rel 2.14e-16 |
| 3 | `R` assembled from the primitives, so it is a value | `test_leaf`, and the count | **DONE** |
| 4 | delete the nested tangent, `SecondOrder`, and both second-order lift branches | `test_leaf`, ladder, statement count | **DONE** |
| 4b | **the waist: `SupplyDraw`, recorded once and passed in** | the transpose identity | **DONE** 531 -> 444 |
| 5 | the layer mean from `f` rather than from a difference of `G`; the three thresholds go | the family against a higher-order average | **DONE** 3 -> 1, and 60,000x on d2 |
| 6 | the graft: the layer draws | the transpose identity | **DONE** 444 -> 360 |
| 7 | profit's and the collar's rows supplied; delete the `<S>` surface | see the memo below | **not worth building** |

**Measured, one interior placement at five soil layers: 861 -> 360 statements and
1257 -> 636 operations** -- the supply draw 187, `collar_at` 99, `outputs_at` 74.
`marginal_assembled` 396 -> 66 and `collar_coords_at` 117 -> 30. `test_leaf` 1127/0 with the solve checksum bit-identical, the ladder
554/0/5, the non-ladder 3295/0, odelia 346/0/3, and `test_golden`'s mismatch count
unchanged at its pre-existing 223.

### Step 4b was not in the original order, and it is the one that pays

The compose above anchors everything at the passive `p*`. What the code turned out
to be doing is recording the supply **two or three times** at that same point:
`implicit_value` evaluates its residual at the passive `y_star`, so `marginal_at`
records the whole supply there; `outputs_at` then records `E_from_soil_at` again at
the same passive collar for profit, and again at the live collar for the draws. Of
531 statements, about 359 were supply and ~86 of those a byte-for-byte duplicate.

`SupplyDraw<S>` is that recording, taken once and passed in. It carries the collar
it was taken at, because **a draw from the wrong collar is a wrong number rather
than a missing row** -- profit reads the flux wherever it is evaluated, so a stale
draw answers with the uptake from somewhere else and every value stays finite.
`check_draw` is what makes that a stop; it caught two real mistakes the moment it
existed.

⚠️ **The per-layer draws stay RECORDED for now, and the rest of the graft should
not be built at all.** What is left above the waist splits three ways: 187
statements of supply that must stay recorded, **86 of layer draws that are worth
grafting once the NaN contract is fixed**, and 169 of gas exchange that are not.

`duptake_dpsi` already returns the per-layer collar slopes, so the layer graft is
available today; it is held only because that vector is **NaN by contract where a
bound meets a layer**, and a coincidence of exactly that kind at 5.6e-08 corrupted
this model once already. `dE_i/dp` is a plain chain rule with no envelope
subtlety and the transpose identity referees it exactly, so fixing the contract
makes it a good trade.

**Supplying profit's and the collar's rows is a different question and the answer
is no.** The objection is not NaN, it is that the envelope theorem's
kind-dependence stops being structural and becomes a coefficient table a human
maintains. `outputs_at` gets it right today by OMISSION -- it hands profit the
passive collar at `Interior` and the live one otherwise -- so AD follows the branch
the model actually took. Supplying rows means hand-encoding `dprofit_dcollar`
correctly at twelve kinds, and the struct at the top of this file already got that
wrong. The rows also still have to be PRODUCED, by a vector tangent inside the
leaf, so the mechanism count does not fall: a graft protocol replaces a recorded
surface. Step 7 depends on this, and so does not land either.

### Two corrections to what is written above

⚠️ **`LeafGraft` as prescribed is missing `dprofit_dcollar`, and the omission is the
trap the next section warns about.** The envelope theorem kills profit's collar
channel at an interior stationary point and **nowhere else**; at a pinned kind the
collar is fixed by a bound and `dPi/dp` is not zero. `outputs_at` already knows this
-- it hands profit the passive collar only at `Interior` and the live one otherwise
-- so the field must be SUPPLIED and merely happen to be zero at `Interior`. A
consumer that infers it is correct at one kind and silently wrong at the others.

**Step 5 is DONE, and the shape is not what this file first proposed.** A mean is an
average, not a divided difference, and writing it as one removes the failure mode
instead of managing it. Every quantity in the family became one sum over the same
nodes:

```
x_i = m + (s/2) t_i      a_i = (1 + t_i)/2      b_i = (1 - t_i)/2

mean       = 1/2 sum w_i f  (x_i)          d2/dhi2    = 1/2 sum w_i f''(x_i) a_i^2
d/dhi      = 1/2 sum w_i f' (x_i) a_i      d2/dlo dhi = 1/2 sum w_i f''(x_i) a_i b_i
```

Which quantity is wanted picks which derivative of the curve goes under the sum and
which power of the bound weights multiplies it. Nothing divides by the span at any
order, so the `f''/3` and `f''/6` limits are not derived, they come out. One
function, ten call sites. Measured against an independent 15-point average:

| worst over three centres, nine spans | mean | d/dbound | d2/dbound2 | mixed |
|---|---|---|---|---|
| before | 2.07e-12 | 2.24e-06 | 2.67e-05 | 4.97e-07 |
| **after** | **4.33e-15** | **2.34e-11** | **4.43e-10** | **1.57e-10** |

⚠️ **ONE THRESHOLD SURVIVES AND IT IS A COST SWITCH.** A fixed rule is not accurate
over a LONG interval -- the curve has a weak singularity at the surface, and seven
nodes reach only 8.3e-07 across the whole domain -- while the difference is well
conditioned and far cheaper there. So the sum is used below a span of 1e-3 and the
difference above. Measured: at 1e-1 the forward model DOUBLES; at 1e-3 it costs 3 to
4 per cent, and an interleaved A/B of the century gradient puts the two arms within
1 per cent of each other.

⚠️ **THE MIDPOINT WAS NEVER A SECOND MECHANISM -- it is the same rule at one node**
(t = 0, w = 2 gives f(mid) for the value and f'(mid)/2 for d/dbound). What decides
the order is what the consumer needs: the templated path takes one node because a
lift asks for the value and its first rows and nothing more; the double family feeds
the second derivatives and pays for seven. Recording the seven-node sum on the tape
instead cost 17% of a century gradient, and lifting the double answer cost 29%.

⚠️ **AND IT REMOVED THE 0/0 THE SUPPLY REFUSED AT.** `duptake_dpsi` returns NaN where
a layer's potential equals the collar, and its caller falls back to a central
difference, because the mean was integral/span with both vanishing. At span zero
every node collapses onto the bound, so the mean is `f(lo)`, its bound derivative is
`f'(lo)/2` and its second is `f''(lo)/3`. `probe_coincidence` measures the family
reproducing the closed forms to every printed digit at four coincidences. So
`at_equal_potentials` -- a fourth tuned constant at 1e-8, three refusal sites -- and
the finite-difference fallback behind it have nothing left to catch. Not yet removed:
it changes an acclimation gradient in plant and wants its own increment.

---

## How to know it is right

**The transpose identity is the check, and it needs no reference gradient and no
differencing.** For arbitrary `v` and `u`,

```
<v, J u>  ==  <J^T v, u>
```

The construction this prescribes satisfied it at **1.4e-14 over 294 operating points**
when it existed before (`docs/reports/02`, recoverable at `5d49947^`). Nothing else
here can catch an error in the envelope reasoning: the two structural constants --
profit's `p`-channel exactly zero at kind S, the operating point's exactly one -- are
what the identity tests, and a wrong one produces a plausible gradient everywhere else.

Then, in order of what they can see:

* `probe_rank` -- the rank claim, with a control that must fail and a collinearity
  guard. Re-run it after any change to the supply.
* `probe_primitive` -- each primitive against the tangent it replaces.
* `probe_leaf_tape` -- the statement count. **A design claim here is a counted number,
  never a timing.**
* `test_leaf`, 1127 checks; the ladder, 673; the non-ladder, 3295 with one
  pre-existing `kableExtra` error.
* The century gradient answers: 169 segments, 0/47 non-finite, no refusal.

---

## What this forbids, each with the measurement that forbids it

Do not re-propose these. Each cost a session.

| refused | the measurement |
|---|---|
| **a tangent above the adjoint** (`FReal<AReal>`) | the three kernels cost **31 statements at the working scalar and 566 nested** -- 18.3x. ⚠️ The stated cause is 5 of 8 statements a node costs: `BinaryExpr` stores its operands and its cached value BY VALUE and `value()`/`derivative()` return `Scalar` by value, so at `Scalar = AReal` each pass is a recorded statement -- 3 tree-build, 2 value, 3 derivative. The unnamed 3 make the cost SUPERLINEAR in depth, so **fusing a nested expression makes it worse**: one fused nest measured 160 against 99 flat. Flatten it, never fuse it |
| **three metrics in one walk** (`xad::adj<T,3>`) | **1.15x to 0.97x** (odelia `828cd83`): the statement walk is shared but the derivative scatter is N times the bytes, and they cancel. It may also no longer compile |
| **a dense block for all six outputs** | six sweeps against three walks: 39 us against 34 |
| **moving the tape rather than shrinking it** | **recording costs 16x sweeping**, so where the tape lives argues about a sixteenth of the cost |
| **a per-placement tape cycle as the objection to a private tape** | 0.14 us on a reused tape. It was never the cycle. (But constructing a `Tape` reserves **192 MiB**, so a private tape must be a held member) |
| **a finite difference as a referee near a coincidence** | a step of 1e-6 straddles a 5.6e-08 feature; refined across three steps it read -9.63, +166, -10588 and never converged |
| **two analytic routes agreeing as evidence** | they shared the corrupted input. Agreement is evidence only between independent routes |

---

## Traps that will mislead you silently

* **`util::to_passive` strips EVERY layer.** At a nested scalar it removes the inner
  direction as well as the outer, and every `implicit_value` correction is built as
  `x - to_passive(x)`. Measured: a mixed second derivative read **exactly 0.0** against
  a differenced 2.97e-03.
* **`identical(NaN, NaN)` is TRUE in R.** Every bit-identity check passed against an
  all-NaN gradient for the century fixture's whole existence. Count finite entries;
  never compare.
* **A refusal is metric-level.** One bad leaf not-a-numbers three metrics x 47 columns.
* **`make` does not track `inst/include` headers.** A `test_leaf` that says "up to
  date" after an odelia edit is the old binary. `rm` it.
* **`test_golden`'s 223 cross-platform mismatches are pre-existing.** Prove it by
  stashing before reading one as yours.
* **`record_with_derivatives` costs n statements for n rows**, because `+=` on an
  active is a full recorded assignment. One statement with n operations is available,
  as a single expression or `pushAll` + `pushLhs`. This decides the graft's cost.
* **`initDerivatives` zero-fills the whole derivative array per seed**, sized by the
  high-water SLOT mark rather than the live count. A recording's slot count costs
  beyond its statements.

---

## What we would have built from the outset

Four studies, run to exhaust the design space rather than to confirm a preference.
They agree, and what they agree on is not what this file said.

### The standard answer is the one we refused, and it is not exotic

Every AD framework surveyed treats "solve in plain double, hand the outer tape a
value and a derivative block" as its **first-class use case**, not a workaround:
JAX's `custom_root` and `custom_vjp`, PyTorch's `autograd.Function`, jaxopt and
Optimistix, cvxpylayers and OptNet, and on the C++ side ADOL-C's `ext_diff_fct`,
CoDiPack's `ExternalFunctionHelper`, dco/c++'s external adjoints and Tapenade's
`_D`/`_B` convention. Naumann names the two variants: **preaccumulation** (get the
local block by `min(n, m)` sweeps) and the **Symbolic Adjoint** pattern (get it from
the implicit function theorem, no sweeps at all).

dco/c++'s own paper uses this shape as its worked example -- a Newton solve inside a
larger taped computation -- and reports **3.5x faster and about 30x less tape**.
SU2's production adjoint reports about **50% off the adjoint solve** from
preaccumulation alone.

⚠️ **So "supplying rows" was never the risk.** This file's objection -- that it makes
the envelope theorem's kind-dependence a hand-maintained coefficient table across
twelve kinds -- **does not survive measurement**. Twelve is the enum: **six kinds
carry rows and six throw**, and the six need **four residuals and one scalar**, not
twelve coefficient sets. The term this file called "a term whose size is the solve's
tolerance rather than the model's" measures **1.6e-15 relative**.

### What decides it is a ratio, and ours says the block should win

Preaccumulation pays `min(n, m)` sweeps against `O(T)` taped statements, so the
deciding ratio is `T / min(n, m)`. Here `T = 360`, `n = 31` inputs, `m = 6` outputs:
**60**. That is squarely the regime every source reports as a large win.

⚠️ **AND A PRIVATE LEAF TAPE IS NOT BLOCKED. That claim was wrong and is measured
wrong in `probe_two_tapes`.** `TapeAlreadyActive` is about two tapes being ACTIVE at
once, which the theorem never asks for. It wants a SEQUENCED tape: pause the stand's
recording with `deactivate()`, run the leaf's own tape to completion, sweep it for
the block, resume, splice. The outer recording survives with its statement count
intact and the combined gradient is exact. `deactivate()` and `deactivateAll()` are
both public, and `setActive` throws only where a DIFFERENT tape is live.

**What decides it is arithmetic, and the unit is a statement WALKED** -- recording and
sweeping cost the same walk. With `T` leaf statements, `k` stand seeds and `m` leaf
outputs:

| | walks per placement | at T=360, k=3, m=6 | |
|---|---|---|---|
| recorded inline | `T + kT` | **1440** | |
| preaccumulated by an inner tape | `T + mT + m + km` | **2544** | 1.77x worse |
| analytic block, no recording | `m + km` | **24** | **60x better** |

**Preaccumulation loses because `m > k`: it spends six inner sweeps to save three
outer ones.** That is the whole criterion -- a preaccumulated block pays for itself
only where the local output count is below the outer seed count. Ours is double it.
Forward production is worse again: `n = 16` trait directions measures 38-52 us
against 6.4 us for recording.

So the numeric routes lose on arithmetic, not on tooling. **The analytic block does
not**, and it is 60x rather than the few per cent this file first claimed.

### Which leaves the analytic block, and the model does give it

With no sweeps affordable, the only route is the Symbolic Adjoint: the rows from the
theorem rather than from a pass. The structure is there, and it is smaller than the
struct at the top of this file suggests.

**`A = A(E)` exactly.** The concentration's residual reads the flux and the
photosynthesis traits and nothing else -- no `sigma`, no `p`. So the whole carbon
side is a one-dimensional function of total transpiration, and **the rank result is a
theorem rather than a measurement**. It is also stronger than stated here: the TOTAL
profit row is rank one in the held `E` column at every kind, because

```
dPi*/du = (lambda_E + M a) E_u  +  M b S_u
```

and the second term vanishes twice over -- `M = 0` at an interior point, `b = dp*/dS`
exactly zero at every bound. `probe_rank` now measures it at 2.7e-16 to 9.9e-15.

The uniform form is Fiacco's, and it needs no branch:

```
dPi*/du  =  dPi-hat/du |_p  -  sum_j mu_j dc_j/du |_p
```

At an interior point every multiplier is zero and this collapses to the omission
`outputs_at` already makes. At a bound the multiplier IS the correction the envelope
theorem does not give. **One formula, four residuals** -- interior `M`, the wet bound
`E_up`, the dry-stem `T1` at `psi_crit`, and `p = root_psi_crit` -- which is what
`collar_at` already is. The kind selects which residual, not which formula.

And the coefficients have names the manuscript already uses: `dPi*/dE` **is**
`marginal_price_water()` exactly at Interior, PinnedWet and ShadeDeath, and
`b = -marginal_price_water() / marginal_collar_slope()` by an exact Maxwell relation
(`M` is affine in `S`, so `dM/dS = dPi-hat/dE`), measured at 2e-15.

### So why it still does not get built

Three reasons, in order of weight.

1. **It needs eight closed forms that do not exist.** `dM/dtheta` at Interior wants
   `dA'/dtheta` and `dlambda_TF24/dtheta` -- four mixed second partials of the
   assimilation kernel and four of the cost. That is the same rule steps 1 and 2
   already used, one order up, and each is refereeable against a tangent; but it is
   eight new things a reader must hold, and the supply's 187 statements stay recorded
   either way, so the walks go 1440 to about 772 rather than to 24.
2. **The referee does not cover it.** The transpose identity reaches four kinds of
   twelve, and `census_trait_tangent` cannot help: it runs the same supplied numbers
   through the same graft, so a wrong row makes both routes wrong identically --
   this file's own "two analytic routes agreeing" trap. Coverage, not algebra, is
   the binding constraint.
3. **One supplied number is already wrong.** `dprofit_droot_collar_psi` returns its
   `0.0` sentinel at ShadeDeath where the true `M = -C'(p*) = -1.3137`. Any design
   taking `M` from there inherits that.

### The Symbolic Adjoint is a PRIMITIVE, not hand-rolling -- and half of it exists

Worth separating, because "supply the rows" sounds like "write the derivative out by
hand" and it is not the same thing. The pattern has two halves and only one of them
is model-specific.

**The attachment is a library primitive, and odelia already has it.**
`record_with_derivatives(value, against, into)` IS a supplied-row node: it puts a
number on the caller's tape carrying rows it was handed. `implicit_value` is the
Symbolic Adjoint for a scalar root already -- it supplies `dF/dy` and RECORDS the
residual to get `dF/dtheta`. The symbolic sibling supplies both, and then it is
`record_with_derivatives(y_star, {{theta_k, -dFdtheta_k/dFdy}}, out)` with no
recording at all. **The concept is in the tree; what is missing is a cheaper spelling
and a block form.**

Two things to build, both small and both in odelia beside the other two:

* **`pushAll` instead of `+=`.** `record_with_derivatives` costs **n statements for n
  rows**, because `out += d * (x - to_passive(x))` is a full recorded assignment each
  time. `Tape::pushAll` + `Tape::pushLhs` are public and give **one statement with n
  operations**. Two hazards must live inside the primitive rather than at callers: a
  passive input's slot is `INVALID_SLOT` and pushing it is an out-of-bounds write on
  the sweep, and `registerOutput` is a no-op on an already-slotted value, so the
  destination must be a fresh local.
* **A block form**, several outputs over one shared row set, so a leaf-shaped
  boundary is one call rather than `1 + L`.

Neither saves anything today -- every live call site is `n = 1` -- so they are a
precondition, not a win. But they are what makes the analytic route a primitive
someone uses rather than a protocol someone maintains, and they are worth having
before anyone tries it.

⚠️ **`probe_leaf_tape` prices a dense block at `n_out * n_in` statements**, on the
stated assumption that a supplied row costs a statement each. With `pushAll` it is
`n_out`. The counterfactual it prints is **31x too pessimistic**, and every design
conversation here has read a number that argued the wrong way.

⚠️ **BUT THE `+=` SPELLING IS THE ONLY ONE THAT COSTS n, AND `graft.hpp` NEVER USED
IT.** An XAD expression template assigned ONCE is one statement however wide it is,
so `graft_curve`'s longhand sum of three `slope * (x - to_passive(x))` terms is
already 1 statement and 3 operations -- measured bit-identical to the primitive in
value and all three rows. The case for one spelling there is the zero-row skip and
the finiteness gate, not the tape. Nothing is bought by rewriting it for speed.

### Scoped: what the primitives cost, and the one that changes the plan

Measured against `odelia/src/Tape.cpp` at `adj<double>`, not derived.

**`pushAll` body for `record_with_derivatives`.** One call carrying n live rows plus
one passive input with a live row plus one zero row:

| n | today | with `pushAll` |
|---|---|---|
| 1 | 3 statements, 3 operations | **1, 1** |
| 5 | 7, 11 | **1, 5** |
| 31 | 33, 63 | **1, 31** |

⚠️ **ONE, NOT THE TWO PROJECTED HERE.** This said two because `into = out` looked
like a second statement; a MOVE-assign of an active records nothing, so the built
form is `1, n` at every n. Landed in `implicit_node.hpp` and guarded in
`tests/standalone/r_free.cpp` at n = 1, 5 and 31. The order is
**value -> `pushAll` -> `registerOutput`**, which is XAD's own assign order with the
last two fused.

⚠️ **AND IT IS REVERSE MODE ONLY, WHICH IS A BRANCH ON THE SCALAR AND NOT ON THE
TAPE.** Everything on this boundary is instantiated at three scalars -- `double`,
a direction and an adjoint -- because the transpose identity's forward side runs
the whole leaf at `FReal`. A primitive that reads `S::tape_type` unconditionally
does not compile there, and one that tests for an active tape instead returns a
value with every row silently missing.

⚠️ **Four hazards, all reproduced, all of which must live inside the primitive.** A
passive input's slot is `slot_type(-1)` and the sweep indexes without a bounds check,
so pushing it **segfaults**. `registerOutput` is a no-op on a slotted value, so the
operations go unclaimed and **the next statement anyone closes adopts them** --
measured, an unrelated `2*y` came back carrying `d/dx = 5`. Assigning the value after
the close pushes an empty statement that **zeroes the adjoint**. And nothing may fail
between `pushAll` and `registerOutput`, because a statement's operations are
implicitly everything pushed since the last `pushLhs`.

**Do not build the block form.** ⚠️ A statement has exactly one lhs, so **m outputs
cost m statements however they are spelled** -- a block saves zero statements and
zero slots. And the leaf-shaped boundary does not want one anyway: the compose is
rank one, so L of the L+1 rows are `n = 1`.

**⚠️ AND THE SEQUENCED TAPE IS THE FINDING.** Break-even for preaccumulating one node
is `m(T+1+k) < kT`, which at `T = 360, k = 3` is **m <= 2**. **A scalar residual has
m = 1 by construction**, so *every* live `implicit_value` site qualifies -- sigma, ci,
the two bound collars, the interior collar, the seed height. At `m = 1` the cost is
`2T + 1 + k` against `T + kT`: a win for any `T > 2`.

That overturns the objection recorded above. **An inner tape needs no closed forms at
all** -- it produces `dF/dtheta` numerically over the whole input list and splices one
statement. So preaccumulation is not a rival to the Symbolic Adjoint here; **it is the
supplier for its rows**, and it applies exactly where the analytic route was refused
for wanting eight derivations that do not exist.

⚠️ **Two costs the walk model does not count**, and they decide it: one **tape cycle
per preaccumulated node per placement** -- the leaf would pay five, at 2.3M placements
-- and a closure cannot express its own input list, so `implicit_value`'s signature
cannot preaccumulate; the residual must be re-expressible over an explicit list.

**The one number to measure next.** `probe_leaf_tape` already prints the empty tape
cycle and calls it "the overhead move 2 has to beat". At `m = 1` the sequenced tape
reaches `dF/dtheta` with no closed forms, refereed by the transpose identity, at every
residual this file gave up on. That cycle cost is the only unmeasured input.

### The one-parameter family in height -- MEASURED, and exploitable by invariance

`probe_height` measures it. The claim holds, but **not for the reason first written
here**: interpolating the operating point in height does NOT pay. What pays is that
the RECORDED SHAPE is invariant across the family.

The probe reconstructs plant's own height -> leaf-input map and is scored against the
operating point **plant itself recorded in aux** at the stand's own 170 cohort
heights: worst error 1.8e-5 MPa on the collar, 1.85e-4 on profit.

**N is 115.** The century fixture places 2,333,500 operating points over 20,286 rate
evaluations, so **one trait set at one stage is shared by 86 to 170 placements**, ~139
typical. That is the factor with an N in it.

**The kind is constant, and that is a counted number, not an argument.**
`census_operating_point_counts_tf24` over the whole century run: **`interior`
2,829,442, every other kind 0.** Zero adjacent-cohort kind differences. Over 57 soil
states, 55 have the entire height sweep in ONE kind -- the kind is set by the SOIL and
flips for the whole species at once.

⚠️ **Interpolation is refuted, measured.** A uniform log-spaced table needs **513
nodes** to hold profit inside plant's ODE tolerance, against 170 cohorts. Adaptive
bisection needs 79 nodes but **284 exact solves to build them** -- more than the 170
it would serve. Subsampling the cohorts is worse than useless: they pile up at the
canopy top, so thinning opens the sparse low end (2.4e-2 MPa at every second cohort).

**What pays is the invariance, and one measurement carries it:**

> **Above `rooting_depth_max` = 1.5 m the root resistances are BYTE-IDENTICAL** --
> checked at h = 1.5001 m against h = 30 m, byte for byte. Above the cap the only
> cohort-varying leaf inputs are **`kmax` and `ppfd`: 2 of 31, not 2L + 2.** On the
> century stand **75.3% of placements are above the cap**, and 93% at the last step.

And the byte-identical part is exactly the expensive part: the supply draw is **187 of
the 360 statements** a placement records.

**Three things to build, cheapest first.**

1. **A height-keyed memo on the solved operating point.** 44% of placements have an
   immediately preceding cohort within 1e-4 m and 59% within 1e-3 m; at the measured
   worst slope of 0.497 MPa/m a 1e-3 m key costs at most 5e-4 MPa, well inside the
   ODE's own 1e-4 tolerance. That is 44-59% of 2,829,442 forward solves.
   ⚠️ `leaf_solved_points` cannot do this -- it is a positional replay cursor whose
   `load()` faults on running off the end.
2. **Share the supply draw above the cap.** 187 statements per placement over inputs
   that are byte-identical for three quarters of them. Record once per
   (species, stage, layer-bin) and graft.
3. **One recording per (species, stage, kind, layer-bin)** -- worth doing only with
   `pushAll` and the block form above.

⚠️ **What would kill it, all measured.** A **mixed-kind band** at psi_soil 5.49-5.79
MPa, right at `root_psi_crit` -- narrow (0.0009 in soil moisture) and never entered by
this fixture, but a drought run crosses it, and inside it a sweep carries three
kinds. They are **ordered in height**, so a boundary can hold three contiguous
segments found by bisection -- but it must not assume one kind. The **1.5 m cap is a
real slope break** (8.8e-6 against 1e-9 at the four layer boundaries, which are C1):
segment at it, never interpolate through it. The **four layer-count breakpoints change
the number of inputs**, so one recorded DAG cannot span them. The **canopy changes
every stage** and it is what moves the collar -- with light held, the collar's whole
range over 0.3-7 m is 0.187 MPa against 0.450 with the canopy. And **N is per
species**: this fixture has one, and every factor here falls with S.

### What could be done instead, in the order I would do it

1. **The height family above.** It has an N in it and nothing else here does.
2. **`pushAll` and the block form in odelia.** Small, self-contained, refereed by the
   transpose identity, and a precondition for anything analytic later.
3. **Widen the transpose identity's coverage.** Four kinds of twelve is the binding
   constraint on every supplied-row design, and it is the cheapest thing on this list
   to improve.
4. **The seven dead aux slots.** `record_leaf_outputs` writes seven leaf readings per
   cohort per stage whose only reader is the R serialisation -- no rate, no metric, no
   C++ consumer. They are tape slots that nothing sweeps.
5. **`use_energy_balance`.** plant declares it, exports it, lists it as a parameter
   and as `no_gradient` -- and never writes it to the leaf. It is inert, and the
   templated surface has no energy-balance term, so wiring it later would silently
   omit a channel from every row.

### The domain has met this and flinched

Land-surface adjoints (BETHY/CCDAS, adJULES, CLM via OpenAD) all differentiate
closed-form stomatal schemes; none has faced a constrained argmax. The stomatal
optimality lineage -- Cowan-Farquhar, Medlyn, Sperry, Wolf, Eller's SOX -- hit the
same cost wall at DGVM scale and **removed the solve rather than differentiating
it**. The closest precedent the survey found translates CLM-ml to JAX and reports a
secant solver's gradient reaching **9.95e144** when the iterations are unrolled,
fixed by the implicit function theorem at the converged root.

**No published work differentiates an inequality-constrained, active-set-switching
hydraulic optimisation.** This sits in a gap: the optimisation literature has the
theory and no plant instance, the plant literature has the model and has never
differentiated it.

---

## Where this sits

This is one leaf of the cascade in `principles.md`, which carries the prime directive
and the five moves that produced the plan. Read that first; it is the top.

```
principles.md            the rules, and the map -- START HERE
└── two-paths.md         THE WORK: what the two read paths cost

the record, none of it outstanding:
├── subtraction-targets.md   what was not earning its keep, by consumer
├── unification.md           where one idea was spelled twice
├── one-reverse-pass.md      what the model forces; the cut, sequenced 0-9. Closed
│     └── step 8 is the leaf, and THIS FILE is what step 8 became
├── one-program.md           a trajectory as a composition of maps. Steps 4 and 6 open
├── measurements.md          root causes and figures, including this file's
└── one-order.md         ← you are here. The leaf's derivative boundary
```

**Up:** this exists to serve the prime directive -- *if a maintainer would find it
exhausting, it is a bad solution*. Seven mechanisms for one model's derivatives is the
failure condition; one rule is the fix, and the 4x on the tape is a consequence rather
than the point.

**Across:** it closes `subtraction-targets.md` 15 (the orphaned root-curve chain, once
nothing needs a second-order supply row), takes `unification.md` 1's third spelling of
the leaf's derivatives, and is the content of `one-reverse-pass.md`'s step 8, which
that document sizes but does not design.

**Down:** nothing. This is a leaf, and when it lands the vocabulary a reader has to
hold to follow one rate evaluation drops from seven derivative mechanisms to one rule.
