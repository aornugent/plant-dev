# One order

**The leaf's derivative crosses to the stand as data, at first order, from
primitives that carry their own slopes.**

That sentence is the whole design. Everything below is what it costs not to have it,
what to build, what is already refuted, and how to know when it is right.

This is the prescription. `one-program.md` is the record it came out of and carries
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
| 6 | the rest of the graft: profit's and the collar's rows supplied | the transpose identity | not started |
| 7 | delete the leaf's whole `<S>` surface above the waist | the ladder, and the count | blocked on 6 |

**Measured, one interior placement at five soil layers: 861 -> 444 statements and
1257 -> 772 operations**, `marginal_assembled` 396 -> 66 and `collar_coords_at`
117 -> 30. `test_leaf` 1127/0 with the solve checksum bit-identical, the ladder
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
| **a tangent above the adjoint** (`FReal<AReal>`) | the three kernels cost **31 statements at the working scalar and 566 nested** -- 18.3x, because `FReal` assigns value and derivative separately and the expression template cannot fuse across it |
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

## Where this sits

This is one leaf of the cascade in `principles.md`, which carries the prime directive
and the five moves that produced the plan. Read that first; it is the top.

```
principles.md            the rules, and the route -- START HERE
├── subtraction-targets.md   what is not earning its keep, by consumer
├── unification.md           where one idea is spelled twice
├── one-reverse-pass.md      what the model forces; the sequenced cut; the tape's cost
│     └── step 8 is the leaf, and THIS FILE is what step 8 became
├── one-program.md           the live record: a trajectory as a composition of maps,
│     └── and the root causes and measurements this prescription came out of
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
