# When two plants the same height are no longer the same plant

Adding a carbohydrate store to TF24 changed a plant's lifetime offspring production by roughly
tenfold. This report is about whether that number is ecology or arithmetic, and it concludes that it
is arithmetic — but the arithmetic fails for a reason that is genuinely about the biology, and the
repair that follows is the one that keeps the biology intact.

Self-contained. Everything is measured on `plant` `develop` at `141dc8df`, single species, TF24 with
`lma = 0.1978791`, default `Environment` and `Control`, `max_patch_lifetime = 105.32`, 141 cohort
introductions, five soil layers, `refine_schedule = FALSE`, compiled `-O2 -DNDEBUG`. Comparison runs
use FF16 at `lma = 0.0825` and K93 at `b_0 = 0.059`. Probe scripts and outputs are in
[`probes/`](../../probes); the implementation is `plant` `claude/nsc-density-measurements-efiolz`.

---

## 1. The premise that stopped being true

For most of its life `plant` has been a **size-structured** model, and it has meant that literally:
a plant's fate was determined by its height and the environment around it. Two plants the same
height, in the same patch, at the same moment, were the same plant. Nothing distinguished them,
because there was nothing else to a plant.

That premise is load-bearing in a way that is easy to miss, because it does not appear in any
equation. It appears in the *representation*. When every plant of a given size is identical, you can
describe a stand by counting plants per unit height — a size distribution — and lose nothing. The
distribution is a complete description of the population.

A storage pool ends that. Two saplings the same height, one with a full store and one that has been
shaded and drawn down, are not the same plant: they will grow at different rates and die at
different rates. A plant now carries a piece of its own history. The size distribution is no longer
a complete description of the stand, because it does not say who is carrying what.

Everything in this report follows from that one change, and from the fact that the solver's
bookkeeping was built back when the premise still held.

## 2. What the solver actually tracks

The SCM follows **cohorts**: groups of plants introduced at the same moment, which thereafter
experience the same environment and so remain identical to each other forever. A cohort is a point
moving through state space, carrying a number.

Nothing ever moves a plant from one cohort into another. Plants are born into a cohort and they
leave it only by dying. So the number of individuals in a cohort obeys

```
dN/dt = -mortality × N
```

and that is the whole of the population dynamics. There is no other term. Everything else in the
model — the physiology, the light competition, the water — determines the *mortality rate* and where
the cohort has got to, but not the accounting.

`plant` does not store `N`. It stores `log_density`: plants per **metre of height**. To get from a
count to a density in height you have to say how much height the cohort occupies. If a cohort spans
`Δh` metres, then

```
n = N / Δh
```

and `Δh` is not constant. If the cohort just below you is growing faster than you, the gap between
you narrows; the same plants are pressed into a thinner slice of height, and the density rises
although nobody was born. That is the **compression term**, and it is why the density equation has a
`-d(growth)/d(height)` in it at all. The term is not biology. It is bookkeeping for how wide, in
height, a cohort currently is.

## 3. The term cancels

Here is the fact that reframes the whole problem. In `develop`, `log_density` is read in exactly two
places: the trapezium that builds the light profile, and the stand's draw on each soil layer. Both
are integrals over height of the form

```
∫ n(h) · e(h) dh
```

Substitute `n = N/Δh`, and note that the `dh` of the quadrature *is* the cohort spacing `Δh`. The
widths divide out. The integral is a sum over cohorts, `Σ N_j · e_j`.

So the solver works out how much height each cohort occupies — at a cost of one extra complete
hydraulic optimisation per cohort per Runge-Kutta stage, because getting `Δh`'s rate of change means
re-running the whole rate calculation at a perturbed height — divides the count by it, and then
multiplies by it again at the only place the answer is ever used.

**The compression term is a change of variables that the model undoes.** No ecology passes through
it. Nothing about who is alive, or how much carbon they are holding, or how fast they are growing,
enters or leaves through that term. It converts units, and then the units are converted back.

That gives a clean criterion for the question this report opened with. An error in the compression
term cannot be an ecological result, whatever it does to the output, because the term is not a
channel through which ecology travels. It is a channel through which *only* representation travels.

## 4. Why it was right, and how it is computed

Under pure size structure, growth rate is a function of height and the environment. That has a sharp
consequence: how fast the gap between two neighbouring cohorts is closing is determined by height
alone, so you can find it out from **one plant**. Take a cohort, nudge its height by a micron, re-run
its rate calculation, and see how much the growth rate moved. That is the compression.

`Node::growth_rate_gradient` does precisely this, with `node_gradient_eps = 1e-6` and a one-sided
backward difference. For FF16 and K93 it is not an approximation to the right answer — it *is* the
right answer, computed by finite difference.

The perturbation holds everything except height fixed. Under size structure there is nothing else to
hold, so the question of what "everything else" means never arises. With a storage pool, it does.

## 5. Where the perturbation goes wrong

The intuitive story is that storage breaks things because two neighbouring cohorts can now differ
physiologically, so one plant can no longer speak for the pair. That story is true, but it is **not**
what causes the tenfold error, and finding that out is the substance of this report.

Look at the part of the run where the damage is done — patch ages 1.5 to 3, where the two treatments
of the density diverge. Over 405 interior cohort pairs there:

| | median |
|---|---|
| gap between neighbouring cohorts | 2.44 mm |
| growth rate, upper cohort | 2.398 m/yr |
| growth rate, lower cohort | 2.398 m/yr |
| ratio of the two | **0.9999** |
| difference in reserve fraction between neighbours | **0.0000** (90th percentile 0.0020) |

Neighbouring cohorts in this window are **indistinguishable**. Same size to within a couple of
millimetres, same growth rate to four figures, same reserve fraction. The physiological divergence
that the intuitive story blames is simply not present here.

And yet, at the same 405 pairs:

| | median |
|---|---|
| the one-plant perturbation | **−0.2312** |
| the correct operator | **+0.0674** |

Opposite signs, and the perturbation is three and a half times too large in magnitude. One concrete
pair, at patch age 2.25: heights 4.929 m and 4.926 m, both growing at 2.398 m/yr, both at reserve
fraction 0.453; the perturbation says −0.2288, the truth is +0.0365.

So the error is not that the two plants differ. **It is that the perturbation invents a plant that
does not exist.**

Here is the mechanism. TF24 gates growth on the reserve *fraction* `r = S/S_max`, where the capacity
`S_max = a_st1 · mass_sapwood` scales with sapwood mass and therefore with height. A plant that grows
taller builds more sapwood and thereby a bigger tank. In the stand, plants fill that tank as they
build it. Two adjacent cohorts are the same cohort a moment apart, so the measurement above — their
reserve fractions agreeing to four decimal places while their heights differ — says exactly that:
along the path a plant actually travels, the fraction barely moves while the capacity grows.

The perturbation makes the plant taller and holds its **absolute** carbon fixed. It gives the plant a
bigger tank with the same fuel in it. The reserve fraction drops, with no carbon having moved
anywhere. The growth gate is a logistic of width `storage_gate_width = 0.1`, so it multiplies that
spurious fraction change by ten, and reports back: taller plants grow much more slowly.

That plant is not in the stand. Nothing in the model ever gets taller without accumulating carbon.
The perturbation walks in a direction transverse to the one-dimensional path the population actually
occupies, and reports the slope it finds there.

### 5.1 Confirming it, and the algebra

Write the height growth rate as `g = C(h) · P₊(h) · G(r)`, with `G` the logistic gate. Then

```
∂g/∂S  =  g (1−G) / (w · S_max)                     w = storage_gate_width = 0.1
```

Along a cohort's own path, `dS/dh = f/g` with `f = dS/dt`, so the term the one-plant perturbation
omits is

```
(∂g/∂S)(dS/dh)  =  (1−G) · f / (w · S_max)
```

The growth rate cancels — a point worth stating because it is tempting to expect this term to blow
up where growth stalls, and it does not. Across the whole run the closed form tracks the measured
disagreement with a Spearman correlation of 0.933; in the stalled cohorts (growth below `1e-8` m/yr)
it predicts exactly zero and the measurement is `1.1e-11`.

The direct test is better than the algebra. Add a third estimate: perturb height, but rescale the
carbon pool to hold the reserve *fraction* constant — that is, perturb along the direction the plant
actually travels. Over the whole run and 3 459 interior pairs, with `A` the one-plant perturbation,
`B` the fraction-preserving version, and `C` the correct operator:

| patch age | `A` (fixed carbon) | `B` (fixed fraction) | `C` (correct) |
|---|---|---|---|
| 0.5 – 1 | +0.198 | +0.7928 | +0.7877 |
| 1 – 2 | **−0.221** | +0.2405 | +0.2390 |
| 2 – 3 | **−0.209** | +0.0656 | +0.0634 |

`B` reproduces `C` to within 1–3%. Perturbing in the direction the plant travels gets the right
answer; perturbing at fixed carbon does not, and from patch age 1 gets the sign wrong. Over the
whole run the fixed-carbon-versus-fixed-fraction gap accounts for 86.7% of the total disagreement.

This is not a proposal to switch to `B`. `B` works here because the reserve fraction happens to be
quasi-stationary along trajectories at these parameters, which is a contingent fact and not a
structural one. It is offered as the measurement that identifies the mechanism.

## 6. The other case, and why differencing neighbours is not the fix

Neighbouring cohorts *can* diverge physiologically, and when they do the picture is different. At
patch age 24 there is a cohort at 41.4 cm with its store empty, growing at 0.025 m/yr, sitting
directly above a fresh recruit at 34.4 cm which arrived with 80% of capacity and is growing at
0.142 m/yr — **5.6 times faster than the plant above it**, seven centimetres away. This is the
suppressed sapling bank against a new arrival, and it is real ecology.

It is also uncommon: across 2 645 interior pairs, 1.1% have a neighbour growing more than twice as
fast, and 0.3% more than five times.

The obvious repair is to stop perturbing one plant and difference the two neighbours instead:
`(g_upper − g_lower)/Δh`. In the limit of fine spacing that converges to the right operator, and it
costs nothing because both growth rates are already computed.

But it converges to the right operator only when the two cohorts are close in *state*, not merely in
size. At the pair above, the neighbour difference gives −1.670 where the one-plant perturbation gives
−0.132; neither is a derivative of anything, because there is no smooth function being
differentiated between a starved plant and a full one seven centimetres apart. And refining the
cohort schedule does not help, because inserting more introduction times does not make a recruit and
its shaded neighbour any more alike.

So the neighbour difference is right in the common case and undefined in the rare one — and the rare
one is exactly the sapling bank, which is the phenomenon storage was added to represent. It also
divides by a cohort gap whose measured minimum over the run is `1.6e-5` m, with 14% of gaps below
`1e-4` m.

## 7. It is not a precision problem

Before concluding that the operator is wrong, rule out that it is merely badly resolved. Evaluate the
one-plant perturbation on a single patch state at age 2, across five decades of step size, against
the correct operator `C`. At that patch age neighbouring cohorts are physiologically identical (§5),
so the neighbour difference is a sound discretisation of the total derivative here, whatever §6 says
about the rare pairs where it is not:

| step size | perturbation | change from the `1e-6` value | distance from `C` |
|---|---|---|---|
| `1e-3` | −0.269644 | 5.5e-03 | 0.3015 |
| `1e-4` | −0.270122 | 5.5e-04 | 0.3019 |
| `1e-5` | −0.270173 | 5.0e-05 | 0.3020 |
| `1e-6` | −0.270178 | — | 0.3020 |
| `1e-7` | −0.270179 | 5.0e-06 | 0.3020 |
| `1e-8` | −0.270178 | 5.2e-06 | 0.3020 |

The perturbation is converged to five decimal places across the whole range. Its distance from the
right answer is `0.302`, which is **55 times its own resolution spread**, and the right answer's own
median magnitude is `0.0318` — so the perturbation is 8.5 times too large and, at this patch age, of
the opposite sign.

This matters for the obvious remedies. Computing the derivative analytically, or by automatic
differentiation, would deliver exactly this number to machine precision. It is already exact. The
problem is not the derivative's accuracy; it is that the transport equation does not want this
derivative.

## 8. A free measurement, and a discriminating one

There is a way to measure the disagreement over an entire run with no instrumentation at all, and it
is worth setting out because it also gives a test that distinguishes "the stencil is a coarse
approximation" from "the stencil is a different quantity".

The number of plants between two neighbouring cohorts can only fall, and only by mortality. Because
mortality is itself an integrated state in `plant`, `log N + mortality` must be constant along each
cohort. Reconstructing `N = density × gap` from collected output and differencing gives a per-cohort
drift, and a line of algebra shows that this drift rate is *identically* the difference between the
two candidate stencils. So collected output already contains the operator disagreement.

Excluding the lowest interval, which is bounded below by the fixed inflow boundary and so genuinely
gains plants:

| | summed drift | worst single cohort | pairs |
|---|---|---|---|
| TF24 | **+245.8** | **158×** | 9 555 |
| FF16 | +7.94 | 1.59× | 9 870 |
| K93 | +1.41 | 3.02× | 9 050 |

Totals alone cannot say whether this is a discretisation error that would refine away. Dividing by
elapsed time to get a rate, and regressing on the cohort gap width, can:

| | slope of log·rate on log·gap | R² |
|---|---|---|
| FF16 | **+0.78** | 0.81 |
| K93 | +0.16, magnitudes `1e-9` to `1e-3` | 0.01 |
| TF24 | **−1.02** | 0.24 |

A quadrature error scales with the gap: halve the spacing and halve the error. FF16 does close to
exactly that, and its magnitudes are three orders smaller. TF24's runs the other way — the error is
*larger* where cohorts are closer together, which no quadrature error does.

Regressing instead on the growth rate resolves it: slope +0.99, R² = 0.94. Fit both together and the
growth rate keeps a coefficient of 1.04 while the gap width falls to 0.16. The apparent gap
dependence was a confound — small gaps are where the fast-growing recruits are. TF24's drift is
proportional to how fast the plant is growing and essentially independent of the discretisation,
which is the signature of a term that is absent rather than coarsely resolved.

## 9. Three things it is not

Ruling these out took as much work as establishing the rest, and each was a plausible reading.

**The density does not stop existing.** A carried state makes it possible in principle for two cohorts
to cross in height, at which point a density in height is undefined. It does not happen here. Across
37 patch states and 3 459 interior pairs there are zero crossings; the minimum gap is `1.6e-5` m.
46% of interior pairs are closing at any moment, but the closing rate decays as their states converge,
and the earliest linear extrapolation to a crossing is 4.05 years away. TF24's height rate is a
positive factor times a smooth positive part times a logistic, so growth is non-negative by
construction and nothing shrinks.

**The omitted term does not diverge when growth stalls.** It is natural to expect `(∂g/∂S)(f/g)` to
blow up as `g → 0`, and to conclude from that that no stencil can work. It does not: `∂g/∂S` carries
its own factor of `g`, which cancels the `f/g` exactly. Measured, the stalled cohorts have a drift
rate of `1.1e-11` against a closed-form prediction of zero. The disagreement lives in the vigorous
cohorts, not the suppressed ones.

**The reserve dilution is not a separate bug from the missing term.** They are one thing seen from two
reference points — §5.1's `A`, `B` and `C` are three estimates of the same operator, not two errors
stacked. Fixing the perturbation direction would remove most of the error at these parameters
without removing the reason it was there.

## 10. Why it is early, and why nobody saw it

Recruits arrive filled to 80% of capacity, and they are small, so their capacity climbs steeply with
height. The spurious term is largest exactly among fresh seedlings, and it inflates their density.

That propagates through the only channel the density has. Too many seedlings means too much leaf
area, which means too much shade, in the window when the cohorts that will form the canopy are
establishing:

| patch age | leaf area as `develop` computes it | as the corrected model computes it | ratio |
|---|---|---|---|
| 0.75 | 1.66e-03 | 1.15e-03 | 1.45 |
| 1.5 | 5.04e-02 | 2.49e-02 | 2.02 |
| 2.0 | 2.29e-01 | 9.74e-02 | 2.35 |
| 2.5 | 6.82e-01 | 2.71e-01 | **2.52** |
| 3.0 | 1.360 | 0.586 | 2.32 |
| 5.0 | 1.762 | 1.676 | 1.05 |
| beyond 25 | | | **1.005** |

The cohorts that build the canopy grow up under two and a half times too much shade. They end up
smaller and less fecund, and lifetime offspring production comes out roughly tenfold low.

By patch age 25 the two agree to half a percent. Seedlings are a rounding error in a closed canopy's
leaf area, so every mature-stand diagnostic — leaf area, canopy height, stem density — agrees. The
error is confined to the first five years of a hundred-year run and is invisible in everything a
mature stand reports. That is why it survived.

## 11. The resolution: stop changing variables

§3 established that the compression term is a change of variables that gets undone. The repair is to
not perform it.

Carry the density in **birth date** — plants per year of introduction time — rather than per metre of
height. Then:

| | density in height | density in birth date |
|---|---|---|
| rate | `−d(growth)/d(height) − mortality` | `−mortality` |
| at birth | `log(birth_rate · pr_estab / g)` | `log(birth_rate · pr_estab)` |
| competition | trapezium over heights | trapezium over introduction times |
| soil draw | the same substitution | |
| the perturbation | one extra hydraulic solve per cohort per stage | not called |
| size distribution | an integrated state | computed at report time |

Nothing moves an individual along the birth-date axis — that is what a birth date is — so the whole
transport term is mortality, which is already a state. The abscissa of both integrals becomes the
introduction schedule, which is known exactly rather than reconstructed from a derivative. There is
no division by a growth rate at the boundary, no division by a cohort gap anywhere, and no
requirement that cohorts stay ordered.

Four consequences worth naming individually.

**The boundary condition stops being a cliff.** The birth density `birth_rate · pr_estab / g` diverges
as the newborn's growth rate approaches zero, and `develop` assigns zero density — deleting the
recruit — when it is non-positive. At these parameters the birth growth rate never goes non-positive
(minimum 0.0959, median 0.821), so this is latent rather than active, but it is a cliff sited exactly
on the plant a storage model exists to describe: a recruit germinating into deep shade or a drought,
alive, not growing, living off reserves. In birth-date coordinates the recruit arrives with a finite
weight and no division.

**The state becomes bounded.** `log density` in birth-date coordinates is `log(birth_rate · pr_estab)`
minus an integral of mortality, so it can only decrease. Measured, the newborn density spans a factor
of 16.8 across the run under the height coordinate and 3.03 under the birth-date coordinate (the
latter is just variation in establishment probability), and the largest `log_density` reached is 1.564
against −0.002. `develop` carries a guard that aborts a run when `log_density` exceeds 50; in
birth-date coordinates that guard can never fire.

**The size distribution becomes an output.** `n = N/Δh` is computed when a run is reported, not
integrated for a cohort's whole life. This is the difference that makes the ecology representable: a
stand in which many birth dates map to nearly one height genuinely has a very large density there.
As a reported quantity, that is a description of a sapling bank. As an ODE state it is a stiff term
in the right-hand side.

**It is cheaper.** At four times the schedule resolution, TF24 runs in 314.9 s against 659.1 s, and
takes 6 143 accepted ODE steps against 8 530 — from the deleted hydraulic solve, and from a
right-hand side that no longer contains a `1e-6`-divisor derivative.

## 12. Evidence that this is the same model

The obvious worry about a change this size is that it is a different model that happens to be better
behaved. The check is to run it where the original is known to be right.

Under pure size structure the two coordinate systems must agree, because the compression term is
then correctly computed and the change of variables is exact. Refining the introduction schedule by
midpoint insertion, so both see byte-identical schedules at each level:

| model | introductions | density in height | density in birth date |
|---|---|---|---|
| **K93** — growth is a function of size | 141 | 0.0305466 | 0.0306275 |
| | 281 | 0.0305653 | 0.0305833 |
| | 561 | 0.0305692 | **0.0305736** |
| **FF16** — heartwood couples weakly | 141 | 19.8244 | 20.0319 |
| | 281 | 19.9490 | 20.0352 |
| | 561 | 20.0122 | **20.0361** |
| **TF24** — storage, through the gate | 141 | 42.1402 | 395.441 |
| | 281 | 54.7988 (**+30.0%**) | 399.085 (+0.92%) |
| | 561 | 59.0590 (**+7.8%**) | **400.917** (+0.46%) |

On K93 the two agree to `1.4e-4` relative. On FF16, to `1.2e-3`. The birth-date formulation
reproduces `develop` wherever `develop` is correct — which is the strongest statement available that
it is the same model in different coordinates, and not a new one.

On TF24 they do not agree, and only one of them has converged. The height coordinate moves +30% and
then +7.8% and is still climbing; the birth-date coordinate moves +0.92% and then +0.46%, halving
each level, to about 401. Whatever else is true, `develop`'s TF24 offspring number is not a converged
value of anything.

With the coordinate switched off, all three strategies reproduce the pre-change build bit-identically
— `identical()` on the offspring scalar, zero ulps — and the test suite passes: 2 363 assertions
across 48 files, no failures, including the FF16 bit-identity reference comparison and the drift
guard on each model's default parameters.

## 13. An outside witness

Both statements so far — that the operator is wrong, and that the corrected one converges — are
arguments about the deterministic solver made from inside it. `plant` carries a second, independent
solver: a stochastic, finite-population model in which individuals arrive and die as discrete events.
It counts plants. It has no compression term, no density, and no cohort grid, so it cannot prefer
either treatment.

Both solvers report leaf area per unit ground area through the same division by patch area, so the
comparison is direct. Poisson arrivals at the same birth rate, establishment as a Bernoulli draw on
the same probability, three patch areas to confirm that the finite-population bias has flattened, run
to the same patch lifetime.

Leaf area above ground level, in the window where the two treatments differ:

| patch age | area 4 | area 16 | area 64 | sd (area 64) | density in height | density in birth date |
|---|---|---|---|---|---|---|
| 1.0 | 0.00381 | 0.00347 | 0.00327 | 0.00100 | 0.00628 | 0.00383 |
| 1.5 | 0.02370 | 0.02262 | 0.02027 | 0.00476 | 0.05035 | 0.02488 |
| 2.0 | 0.08553 | 0.08777 | 0.07713 | 0.01310 | **0.22926** | 0.09738 |
| 2.5 | 0.22713 | 0.24357 | 0.21221 | 0.03042 | **0.68229** | 0.27117 |
| 3.0 | 0.46026 | 0.52081 | 0.45887 | 0.05268 | **1.35999** | 0.58568 |
| 5.0 | 1.57245 | 1.66668 | 1.66303 | 0.02183 | 1.76160 | 1.67564 |

As a ratio to the largest patch: the height coordinate sits at 2.97, 3.22 and 2.96 across ages 2 to 3;
the birth-date coordinate at 1.26, 1.28 and 1.28. The individual-based stand is stable across a
sixteenfold range of patch area and carries 58 to 177 individuals through that window, so this is not
a small-sample artefact. The height coordinate sits about twelve replicate standard deviations above
it; the birth-date coordinate within two.

The witness rules out the height coordinate and is consistent with the birth-date one. It agrees with
the refinement result and with the step-size result, and it shares no assumption with either.

It also cannot say anything about the mature stand: after canopy closure every statistic agrees to
within the individual-based model's own replicate spread, and its living stem count is so noisy — the
largest-patch value moves 7.2, 5.1, 5.0, 6.3, 2.0 across ages 20 to 100 — that the two treatments
cannot be separated by it at all. This is the same fact as §10, seen from outside.

The remaining 25% by which the birth-date coordinate exceeds the individual-based stand in that window
is not explained here. The schedule places 141 introductions over 105 years and the recruitment window
is where the distribution changes fastest, so schedule resolution is the first thing to rule out;
nonlinear averaging over a finite population is the second.

## 14. What this means for the ecology

**The repair does not touch the biology.** No strategy code changes. Storage dynamics, the reserve
gate, reserve-dependent mortality, the birth fill: untouched. What changes is which coordinate the
population's bookkeeping is carried in.

That is worth weighing against the alternative repair, which is real and which would also work.
Making the store an explicit function of size and environment would restore the size-structured
premise by construction: two plants the same height would be the same plant again, the compression
term would be correct, and the whole problem would vanish.

It would also delete the phenomenon. A store's entire function is memory. Stefaniak et al. (2026),
against whom TF24's storage is calibrated, find that the **variance** of stress duration shifts
community composition more strongly than its mean — an effect size of `ω² = 0.25`, "large", on the
Slow-Risky strategy's basal area, against "very small" for the mean at almost every level — and their
four strategies are defined by a utilisation rate and a switch time, which are properties of the
pool's dynamics rather than of its equilibrium value. A plant whose reserves are a function of its
current size cannot have come through a drought differently from one that has not. That repair makes
the solver comfortable by removing the thing being modelled.

**And the phenomenon the store exists to represent is the one the height coordinate handles worst.**
Stefaniak et al. attribute the Slow strategies' success to a "high carbon storage minimum, which
facilitated the survival of small saplings in the shade". That sapling bank is precisely the
suppressed, tightly-packed, slow-growing part of the size distribution — where cohort gaps fall below
`1e-4` m, where a density in height is largest and worst conditioned, where the recruit-versus-starved
pair of §6 lives, and where §10 shows the error is generated. In birth-date coordinates a stalled
cohort is an ordinary quadrature point carrying an ordinary weight.

Their own storage model never met this problem, because they ran the individual-based solver:
hundred-year runs on 100 m² patches with individual trees, at roughly three days per simulation. An
individual-based model counts plants. The group's storage work is already, in effect, in count
coordinates. The difficulty is specific to the deterministic solver's density variable and not to the
biology — which is why §13's witness is the right arbiter, and why it agrees.

**Nothing about the resolution is specific to storage.** The condition that breaks the one-plant
perturbation is that growth reads *any* state other than size. TF24 reads a carbon store today. The
allometric calibration factor Stefaniak et al. require — needed because gating growth breaks the
pipe-model balance, so each component mass becomes an independent state — would add four more. A
repair that sites the storage term explicitly, adding `(∂g/∂S)(dS/dh)` with analytic partials, has to
be extended once per carried state and re-derived every time the physiology changes. Removing the
change of variables does not.

## 15. Costs, and what is not settled

**Every TF24 baseline moves**, and by a lot. FF16 and K93 move by `1.2e-3` and `1.4e-4`, which is
small but is above a bit-identity tripwire, so their reference comparisons would need regenerating if
the coordinate became the default.

**A downstream claim should be treated as open.** TF24's single-species offspring production was
reported as falling from 227.9 to 25.4 on adding reserve gating, and the model's scientific version
was bumped on the strength of it. The pre-storage number is solver-insensitive — the two coordinate
systems agree to `1e-3` on FF16 — and the post-storage number is solver-dominated, differing 6.8-fold
between coordinates at the finest refinement level, with only one of them converged. The direction of
that result is not established and should be re-measured.

**Adaptive schedule refinement has not been re-derived.** Its error metric is written against the
height grid; the structure carries over to a birth-date abscissa but the work has not been done.

**Cohort crossings have been checked at one parameter set.** §9's census is a single trait value and a
single environment. The drought sweep that motivated the storage pool has not been instrumented, and
a fold in the interior is most likely under the kind of seasonal stress regime Stefaniak et al.
simulate, which has never been run against the deterministic solver.

**A separate defect, found alongside and unrelated.** TF24's storage state leaves its intended range:
the minimum recorded value is `−2.249e-3`, in 14.0% of recorded cohort-times, affecting 65 of 142
cohorts, from patch age 3.5 onward. The rate is gated to vanish as the store empties, but a finite
step from a small positive value with a negative rate carries the state below zero, where the gate
pins the rate at zero. The rate calculation clamps on read, so the plant behaves as though its store
were exactly empty — gate at its floor of 0.269, storage mortality at its bounded maximum — and it
recovers only when production turns positive. This wants its own issue.

## 16. In one paragraph

A storage pool gave plants a memory, and a memory means two plants the same height are no longer the
same plant. The solver's size distribution assumed they were — not in an equation, but in the choice
to carry a density in height, which requires knowing how much height each cohort occupies and
therefore requires a derivative of growth with respect to size. That derivative is computed by making
a plant taller without giving it any carbon, which dilutes its reserve fraction and, through a gate ten
times narrower than the dilution, reports a slope from a direction no plant in the stand travels. The
resulting error is threefold in seedling leaf area, tenfold in lifetime offspring, and entirely
invisible after canopy closure. The correct compression term is available, but the better move is to
notice that the density in height is a change of variables the model performs and then undoes, and to
carry the population in the coordinate it was born in.

## References

Falster, D. S., FitzJohn, R. G., Brannstrom, A., Dieckmann, U., Westoby, M. (2016). plant: A package
for modelling forest trait ecology and evolution. *Methods in Ecology and Evolution* 7, 136-146.

Stefaniak, E. Z., Tissue, D. T., Falster, D. S., Medlyn, B. E. (2026). Greater variability in
environmental stress favours trees that prioritise storage of carbohydrate reserves over growth: a
modelling analysis. EGUsphere preprint, https://doi.org/10.5194/egusphere-2026-1474. Local copy:
[`docs/reference/stefaniak-et-al-2026-storage-strategies-egusphere-2026-1474.pdf`](../reference/stefaniak-et-al-2026-storage-strategies-egusphere-2026-1474.pdf)
(CC BY 4.0).
