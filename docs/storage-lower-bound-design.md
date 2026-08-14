# The storage pool's lower bound: what the flow has to look like

`docs/issue-609-handover.md` left one question open — why bounding the pool by the
shape of its own flow costs 13.7 times as many accepted steps. This answers it and
picks the form that follows. It supersedes that document's *live hypothesis* and
*experiment that settles it*; everything else there stands.

Its referee is the model plus the objective. Where it disagrees with the code, one of
them is wrong and the disagreement is the finding.

---

## Triage: 3 — the forward model's behaviour changes, and it has consumers outside this workspace

## What the cost is

**The rate has an attracting fixed point just above the empty boundary, and its
relaxation time is set by the drain limiter's scale.** With

    dS/dt = charge*(1 - r) - drain*L(r),   charge = Ppos*(1 - G(r)),  drain = Ppos - P

the rate's own eigenvalue is

    d(dS/dt)/dS = (1/S_max) [ Ppos( -G'(r)(1-r) - (1-G) ) - drain * L'(r) ]

which is exact, because production does not read the pool. For `L(r) = r/(r + D)` the
last term is `drain * D/(r + D)^2`, so at the boundary the time constant is

    tau = S_max * D / drain,        D = drain_ref = 1e-3.

Measured over the fixture's whole trajectory (one species, `lma = 0.0825`,
`birth_rate = 1.10`, `max_patch_lifetime = 10`, birth-date coordinate, schedule
refined once), against the same run on the form that ships:

| | accepted steps | wall | median dt | min tau |
|---|---|---|---|---|
| shipped `max(S,0)` and `net>0 ?:` | 940 | 8 s | 5.73e-03 | 2.162e-03 yr (18.9 h) |
| the charge/drain split as built | 12 865 | 114 s | 3.45e-04 | 7.260e-05 yr (**0.64 h**) |

**Both forms have the same knee. Only one has to resolve it.** The stiffest record
under each sits at `r = 1.1e-3`, which is `drain_ref` — the shipped form falls
*through* that knee into the region where `max(S,0)` makes the rate identically zero,
so the layer is never felt; the split form has a fixed point there and the controller
must resolve it. The step-count ratio 13.7, the median-`dt` ratio 16.6 and the
`min tau` ratio 29.8 are one fact seen three ways.

**The stiffest record is a seedling, not a large plant in drought.**

    t = 4.0 yr   height = 0.408 m   capacity = 9.93e-07 kg   r = 1.085e-03
    P = -1.657e-05    Ppos = +4.240e-05    drain = 5.897e-05    G = 0.271
    lambda = -1.377e+04 /yr    tau = 7.26e-05 yr = 0.64 hours

Read the second line. Production is negative and the smoothed positive part is **2.6
times its magnitude, with the opposite sign**, because `storage_prod_eps = 1e-4` is an
absolute rate in kg/yr and this plant's whole storage capacity is 1e-6 kg. So the
fixed point the solver strains to resolve is held up partly by carbon the smoothing
invented. §*What is not in scope* returns to that.

### Two candidates die here rather than in the search

**Rescaling `drain_ref` alone is not enough, and #610's rung 2 cannot help at all.**
An eigenvalue at a fixed point is a property of the vector field, not of the chart, so
`S = w^2` and `log S` leave `tau` exactly where it is. Rung 2 answers a *different*
shape — an exponential approach to a boundary with no interior fixed point, which is
what the shipped rate has, and which a log coordinate genuinely does linearise into a
drift an explicit stepper integrates for free. It does not answer this one. That is
worth recording against #610 rather than left implicit, because the two shapes look
alike from the outside and only one of them yields to a change of variable.

---

## Requirements ledger

R1: a negative storage state does not occur — unreachable, not clamped and not
repaired. **3.02 per cent of records, worst −7.13e-2 of capacity → 0.**

R2: the upper bound holds on the state rather than on each read. **fraction at
`r > 0.99` at 105.32 yr 0.527 → 0.000; worst state/capacity 1.035 → 0.862.**

R3: the forward model's cost does not regress materially. **940 accepted steps is the
mark; 12 865 is not landable.**

R4: the block stays differentiable, because it is on the census gradient's path.
**420 ladder assertions, block Jacobian forward against reverse 2.40e-16, all 17
injected corruptions still detected.**

R5: a behaviour change the bound causes is attributable to the bound. **Mortality
reads `r` directly and is 5.51/yr at `r = 0` against 0.11 at `r = 0.2` and a floor of
0.01, so where the pool comes to rest decides whether a starving plant dies in two
months or lives for decades. A rest point set by a smoothing constant is not the
bound's doing.**

R6: the census is re-blessed, with the movement recorded in the change that causes it.

*(Challenged upward, and answered inside this document rather than left hanging:*
#609's comment asks for `storage_prod_eps` to be rescaled in the same change, on the
grounds that once the two limiters differ the smoothing residue stops cancelling.
*That is true and it is measured at 0.27 per cent of records — see* What is not in
scope. *It is a larger defect than #609 and it is not a precondition for this one.)*

**Scarce resource**, derived from R3's quantities: the ratio of the pool's own
relaxation time to the step the controller would otherwise take. Nothing else in this
block is scarce — a recorded cohort step costs 2.3 ms against 18 microseconds for the
same rates in plain double, and the storage block is a small share of either, so
arithmetic added here is free and a time constant subtracted here is everything.

## The floor

Retune the one constant: `drain_ref` from `1e-3` to `1e-1`, and change nothing else.
Two lines including the comment.

It pays R1, R2 and R4 unchanged, and it **nearly** pays R3 — `min tau` rises to
1.435e-03, which is 0.66 of the shipped form's own worst, so the cost lands near 1.5
times the mark rather than 13.7. It fails on R5: a tenth of capacity is a tuned
number, and it is tuned against the solver's step rather than against anything a plant
does. The measurement that decides it is in the candidates' table below — the same
`min tau` is available with **no** constant at all, so the floor is paying a name for
a worse number.

## Candidates

**A [first thought]** — *move 1, weaken exactness.* Widen the drain limiter's scale to
`1e-1`. Commitment: the drain is throttled over the last tenth of the pool. Pays R3 at
`min tau = 1.435e-03`. Costs: keeps the constant, and its value is chosen against the
integrator. Wins when the limiter's shape is genuinely a mollifier of a switch and only
its width is free.

**B** — *move 6, Pólya with witnesses.* One mechanism for both directions:
`dS/dt = charge*(1-r) - drain*r`. Three witnesses, all in hand: the fill limiter is
already `(1-r)`; the drain limiter's only stated job was to keep the state
non-negative — its name in the shipped code is `floor_gate`; and the two were never
compared, because Option 4 inherited the second from the code it replaced. Smaller
than their sum: `drain_ref` is **deleted**. Pays R3 at `min tau = 5.503e-03`, which is
2.55 times the shipped form's own worst, and R4 more strongly than anything else here
— the rate becomes `charge - (charge + drain)*r`, linear in the state, so
`d(dS/dt)/dS` is the constant `-(charge+drain)/S_max`. Costs: a substantive statement
about drawdown, priced below. Wins when reserve mobilisation is proportional to what
is held, which is what a buffer is.

**C** — *move 3, move the system boundary.* Leave the rate as it ships and put the
bound in the solver: odelia#55's `ode_state_valid` and the domain throw. Commitment:
the model declares its domain and the stepper respects it. Pays R1 — measured, 3.02
per cent to 0. Costs: pays neither R2 (nothing bounds `S` above; the `min(r,1)` clamp
stays load-bearing on 53 per cent of a mature stand) nor R4 (the `net>0 ?:` slope step
stays, measured at 1.972 across the sign change and unbounded as the pool empties).
Wins when the rate is already right and only an inherited step size is at fault —
which is #599's soil water, and is not this.

**D** — *move 5, fix the typical case and detect the rest.* Keep the built hyperbolic
limiter and rescale the smoothing: `storage_prod_eps` becomes a fraction of the
plant's own maintenance flux. Commitment: every scale in the block is a fraction of a
flux the plant has. Pays R5. Does **not** pay R3: with the fabricated charge removed
the fixed point moves to the boundary but the eigenvalue is still `drain/(S_max*D)`,
and `min tau` is 5.58e-05 — measured, and no better than what is there now. Wins when
the stiffness is fabricated rather than structural, which this measurement refutes.

**Winner: B.** Eliminations. **A** buys R3 at 0.26 of B's `min tau` while keeping a
constant B deletes, and fails R5 because that constant is set against the integrator.
**C** fails R2 and R4 outright; it is the backstop, and it is already built and stays
in as one. **D** fails R3 by measurement — it is a real defect fix and it is not this
one.

The two shapes between A and B were priced too, because the family is one parameter
wide and the endpoints are not the only options:

| `L(r)` | min tau over the trajectory | vs shipped | `L` at r = 0.01 / 0.1 / 0.5 |
|---|---|---|---|
| `r/(r+1e-3)` as built | 7.260e-05 | 0.03x | 0.909 / 0.990 / 0.998 |
| `r/(r+1e-2)` | 2.020e-04 | 0.09x | 0.500 / 0.909 / 0.980 |
| `r/(r+1e-1)` | 1.435e-03 | 0.66x | 0.091 / 0.500 / 0.833 |
| `1-(1-r)^16` | 9.519e-04 | 0.44x | 0.149 / 0.815 / 1.000 |
| `1-(1-r)^8` | 1.703e-03 | 0.79x | 0.077 / 0.570 / 0.996 |
| `1-(1-r)^4` | 2.839e-03 | 1.31x | 0.039 / 0.344 / 0.938 |
| **`r`** | **5.503e-03** | **2.55x** | 0.010 / 0.100 / 0.500 |

The `1-(1-r)^k` family is the one that would keep the shipped drawdown *and* clear R3,
and it is rejected on the deletion pass: it holds the shipped shape in place by
choosing an exponent, and the shipped shape is a floor rather than a model.

## The commitment

**Every scale in the storage block is either a fraction of a flux the plant itself
has, or absent.**

Kept true by: `drain_ref` ceases to exist, so it cannot be mis-set; and the two
limiters are `(1 - r)` and `r`, which carry no scale to choose. The rate is then
`charge - (charge + drain) * r`, and a reader has to hold one idea — the pool is a
first-order filter on production, charging into headroom and draining in proportion to
its contents.

## Kill question

**The assumption whose falsity makes this unnecessary: that where the pool comes to
rest is read by something.** If it were not, `drain_ref` could be widened to whatever
the integrator likes and the shape would be free.

Argued from the ledger, and it survives: R5's own numbers. Mortality is
`d_I + a_dG1*exp(-a_dG2*r)` with `a_dG2 = 20`, so it spans 5.51/yr at `r = 0` down to
its floor of 0.01 by `r = 0.35`; the density rate is minus that mortality, and the
census carries `n = exp(l)` linearly. So the rest point reaches every census metric
through the density, and report 00 §4.3 says so independently.

**A second kill attempt, which is where this document's own earlier draft was wrong.**
If B's proportional drain left starving plants resting at an appreciable reserve, B
would fail R5 harder than the floor does — a plant that should read as starving would
read as mortality 0.11 instead of 5.51. Priced by root-finding the fixed point of the
full expression, `Ppos(1-G(r))(1-r) = drain*L(r)`, over the 155 records with `P < 0`:

| `L(r)` | rest `r`, median | max | mortality at rest, median | fraction resting above 0.05 |
|---|---|---|---|---|
| `r/(r+1e-3)` as built | 0.0000 | 0.0022 | 5.51 | 0.000 |
| `r/(r+1e-1)` | 0.0000 | 0.0866 | 5.51 | 0.058 |
| `r` | 0.0000 | 0.2018 | 5.51 | 0.077 |

**B survives, and the earlier draft of this section did not.** Ninety-two per cent of
starving records still rest at the boundary with mortality at its maximum; what B
moves is a tail of 12 records, 0.27 per cent of all records, up to `r = 0.20`. An
earlier attempt at this table evaluated the growth gate at the *observed* reserve
rather than at the fixed point, which put that tail at a quarter of all records and
would have killed B for the wrong reason. The gate rises with `r` and throttles the
charge, so the balance lands far lower than the observed-`r` arithmetic suggests.

## Consistency pass

- The scarce resource is a time constant, and the design adds arithmetic (nothing) and
  removes a time constant (a factor of 76). Consistent with a block whose recording
  cost is a small share of 2.3 ms.
- R4 asks for differentiability and the winner is *more* differentiable than the
  runner-up, not less: a polynomial in `r` against a rational function with a pole at
  `r = -drain_ref`. The pole is the thing that made the refusal necessary in the first
  place (handover, correction 1), and B moves it to infinity.
- R2 is paid by the fill limiter, which B does not touch, so B cannot regress it.
- The claim "both forms have the same knee" and the claim "B has no knee" are
  consistent: B is the `D -> infinity` limit of the family in which the knee's width is
  `D`.

## What survives deletion

| name | the ledger line holding it there |
|---|---|
| `charge * (1 - r)` | R2 — delete it and `dS/dt` at `r = 1` is `net_flux`, which can be positive |
| `drain * r` | R1 — delete it and `dS/dt` at `r = 0` is `net_flux`, which can be negative |
| `storage_prod_eps` | R4 — it is what makes `Ppos` differentiable at `P = 0` |
| `storage_gate_width` | not this design's; it is the growth gate's |
| `drain_ref` | **nothing. Deleted.** |
| the domain refusal and `non_negative_states` | R1 as a backstop — the exact flow cannot leave `[0, S_max]`, and a step longer than the local time constant still can |

## What this settles

- A state that cannot occur, rather than one clamped on each read: `r` needs no
  `min`, `S` needs no `max`, and the `(S + gate_ref) > 0` guard has nothing to guard.
- The kink at `net_flux = 0`, measured at 1.972 and unbounded as the pool empties.
- The stiff boundary layer, and with it the case for #610's rung 2: there is no
  coordinate to change to, and now no need for one.
- One constant fewer in a block that had three.

## What this makes hard

**A plant meets its shortfall from reserves in proportion to what it holds, so at half
reserves it draws at half the deficit rate.** The shipped form draws at essentially
the full rate until the pool is within 0.1 per cent of empty.

What that does *not* change is how much carbon goes unpaid: what a plant pays from
reserves is exactly the pool's depletion, in either form, so the integral over a
drawdown is the same and only its schedule differs. The reserve-mediated mortality
signal is therefore spread over a longer window — which is what a buffer is for, and
is the direction #517 asked for. If forced back, the `1-(1-r)^k` row of the table
above is the retreat: `k = 4` keeps R3 with a margin and restores most of the shipped
drawdown, at the price of the constant this design deletes.

**And the block still does not conserve carbon at either end.** At capacity the
withheld charge `Ppos(1-G)` leaves the budget; at the boundary the unmet part of the
deficit does. Both are properties of limiting a flux rather than spending it, both
predate this change, and routing either into growth or into tissue loss is a larger
modelling change than #609 proposes.

## Kill condition

**A shrinking storage capacity.** Every bound here is a statement about `r = S/S_max`
with `S_max` non-decreasing, which holds because `area_leaf_dt` is a product of two
non-negative factors. Admit tissue loss — which is what conserving the unpaid deficit
would need — and `S_max` can fall, `r` can exceed 1 from the denominator, and no
limiter on the flow can catch it. That hands off to candidate C, whose whole content
is that the solver, not the form, is where an unreachable state gets caught.

## The design

One line changes, and one constant goes:

```cpp
const S charge = Ppos * (1.0 - G);   // surplus the gate withheld
const S drain  = Ppos - P;           // shortfall met from reserves
vars.set_rate(state_idx_storage, charge * (1.0 - r) - drain * r);
```

Everything else in the block is already in place from the two commits `95e3ab64` and
`90ea565b`: the split, the removal of both clamps, and the domain refusal that catches
a step longer than the local time constant.

## What is not in scope, measured rather than deferred

**`storage_prod_eps` is an absolute rate against fluxes spanning six orders, and that
is a defect of the forward model rather than of this bound.** Measured on the same
trajectory, with turnover as the plant's own maintenance flux:

- turnover spans **4.60e-05 to 2.88e+01 kg/yr** across one stand;
- the shipped `eps = 1e-4` is **3.5e-06 to 2.17** of a plant's own turnover, and
  **exceeds it on 39.8 per cent of records**;
- so a plant at `P = 0` is credited with `eps/2 = 5e-5` kg/yr it does not have, which
  is 0.5 per cent of an adult's maintenance and **29 per cent of a seedling's**;
- and `Ppos` reaches **21.3 times `|P|`, with the opposite sign**, on the records where
  the pool is stiffest.

#609's comment predicted the arithmetic and asked for the fix in the same change,
because once the limiters differ the residue stops cancelling inside `net_flux`. The
residue does stop cancelling, and the size of what it then exposes is measured above:
the tail of 12 records, 0.27 per cent, that B moves off the boundary. Rescaling the
smoothing to `1e-2 * turnover` shrinks that tail's worst rest point from 0.2018 to
0.0349 and leaves nothing above 0.05.

**It is left out of this change on the evidence, not by preference.** It moves
establishment and every plant near its compensation point, it needs its own
re-blessing, and folding it in would make one census movement attributable to two
causes — which is report 08 §4.8's own rule. It wants an issue of its own, and the
measurements above are what that issue should be written from.
