# What the density is, once plants carry storage

`aornugent/plant#69` asks which of two stencils the compression term wants. This report argues the
question is posed one level too low: with a carried state the Eulerian density in height is not
merely harder to discretise, it is not guaranteed to exist, and `plant` already computes it in a way
that neither reading of the issue endorses. The treatment that follows the ecology is to stop
carrying a density and carry a **count** — the Escalator Boxcar Train formulation (de Roos 1988),
which is what physiologically structured population models use and what `plant`'s own stochastic
solver already does.

Read after [report 10](10-density-transport-and-carried-physiology.md), whose derivations and
measurements this depends on and does not repeat. Code references are `plant` `develop` at
`141dc8df`. **Nothing here is a new measurement**; §9 separates what is read from the tree, what is
derived, and what still has to be run.

---

## 1. Where `log_density` actually enters the model

Report 10 and `#69` both discuss the compression term as though `log_density` were a demographic
output. It is not. In `develop` the density is consumed in exactly two places:

| site | use |
|---|---|
| `node.h:235` `Node::compute_competition` | `density * individual.compute_competition(z)`, summed by the trapezium in `species.h:212` to build the light profile |
| `node.h:98` `Node::consumption_rate` | `individual.consumption_rate(i) * density`, the stand's draw on each soil layer |

It does **not** enter reproduction. `Patch::net_reproduction_ratio_for_species` (`patch.h:453`)
integrates each node's `weighted_fecundity` over introduction times; that is per-capita lifetime
offspring weighted by patch-age density, and `log_density` appears nowhere in it.

Two consequences, and both matter for how the question should be framed.

**The 10.3x in offspring is entirely a resource-feedback effect.** The chain is: stencil -> density
-> competition trapezium and soil draw -> light and water -> assimilation -> growth and fecundity ->
offspring. No term in the fitness integral reads the density directly. Report 10 §3.2 attributes the
move to the stencil, which is true but skips four links, and the intermediate links are separately
testable (§8.3).

**`log_density`'s meaning is not open.** `#69` frames the choice as "what is `log_density` a density
of?", a question about intent. Operationally it is already fixed: it is the weight a cohort carries
in two resource integrals. The right object is whichever one makes `sum_j (weight_j * leaf_area_j)`
converge to the stand's actual leaf area above a height. That is a question with an answer, not a
preference.

## 2. `develop` computes neither reading of `#69`

`Node::growth_rate_gradient` (`node.h:212`) perturbs height through
`Individual::growth_rate_given_height` (`individual.h:138`), which is

    set_state(HEIGHT_INDEX, height);  compute_rates(environment);  return rate(HEIGHT_INDEX);

so every other state is held at its current value — including storage, held as an **absolute** pool
`S`. But capacity is a function of height: `S_max = a_st1 * mass_sapwood(area_sapwood(area_leaf(h)), h)`
(`tf24_strategy.cpp:687`), and the reserve gate reads the **fraction** `r = S/S_max`
(`tf24_strategy.cpp:195`, `:208`). Perturbing the height therefore inflates the denominator and
lowers `r` without any carbon having moved.

What the probe returns is

    dg/dh |_S  =  dg/dh |_r  +  (dg/dr) * (dr/dh)|_S ,      (dr/dh)|_S = -r * dln(S_max)/dh  <  0

Reading B of `#69` wants growth's sensitivity to size **at fixed physiology**. The physiologically
meaningful state is `r` — it is what the gate reads and what
`mortality_storage_dependent_dt` reads. `dg/dh |_S` is neither Reading A nor Reading B; it is
"at fixed absolute carbon, with the reserve fraction diluted by the perturbation".

**The spurious term has a fixed sign and a large prefactor.** With `G = logistic((r - a_st2)/w)`,
`dg/dr = g(1-G)/w`, so the contribution is

    -g * (1-G) * r * dln(S_max)/dh / w

`storage_gate_width` is `0.1` (`tf24_strategy.h:380`), so it is amplified tenfold, and `dln(S_max)/dh`
is several per metre for a seedling. It is negative everywhere, because capacity rises with height.
That is the shape report 10 §3.1 measures: the sub-grid values are **uniformly negative** (`-0.060`
to `-0.234`) where the cohort-grid values sweep monotonically through zero. An order-of-magnitude
estimate at seedling sizes lands in the same band as the measured values, so a material fraction of
`develop`'s compression signal is plausibly this artefact rather than any size effect.

This is cheaper to settle than anything in `#69`'s list, and it should be settled first (§8.1),
because it separates "storage genuinely decorrelates the two operators" from "the probe mishandles
storage". Those call for different work.

## 3. Count conservation is an identity, not evidence

Report 10 §4 and `#69` present conservation of individuals as a merit of the cohort-grid stencil.
It cannot be, in the direction claimed. The spacing between two characteristics obeys
`d(dh)/dt = g_i - g_below` exactly, so defining

    d(log n)/dt = -(g_i - g_below)/dh - mortality

makes `d(log N)/dt = -mortality` an algebraic identity for `N = n * dh`. The cohort-grid arm cannot
fail that test. The `6.6e-05` and `-2.97e-06` in report 10 §4 measure the ODE integrator, not the
model. Presenting the winner of a test it defines is the weakest form of the argument and invites the
obvious objection.

What the same measurement **does** establish is stronger and should be the claim instead. Under the
sub-grid stencil the model carries two incompatible accounts of crowding at once: the cohort
positions move at the true growth rates, so their spacing evolves as `g_i - g_below` whatever the
density does, while the density evolves at `dg/dh|_S`. Both the densities and the spacings appear in
the *same* competition trapezium (`species.h:212`). So the light profile — and through §1 everything
downstream of it — is built from a size distribution that disagrees with itself. The `+3.99` summed
drift and the `3.4x` worst cohort are the size of that disagreement, not a leak to be plugged.

## 4. The compression term is a Jacobian, and storage lets it vanish

Stripped of discretisation, the SCM is Lagrangian: it tracks characteristics. In Lagrangian
coordinates the population balance is

    dN/dt = -mortality * N

with `N` the number of individuals in a cohort. That is the whole transport equation. The Eulerian
density is a derived quantity, `n = N / J`, where `J = dh/da` is the Jacobian of the map from birth
date `a` to height `h`. **The compression term is `d(log J)/dt`.** Everything contentious in `#69`
lives in `J`.

**Under pure size structure `J` cannot vanish.** With `g = g(h,t)` Lipschitz, two plants at the same
height at the same instant have the same growth rate, so characteristics that meet coincide —
Picard-Lindelöf. `J > 0` for all time, and a density in height exists globally. This is why FF16 and
K93 are comfortable, and it is a theorem rather than a convention.

**With a carried state that guarantee is gone.** `g = g(h, s, t)`, and two plants at the same height
with different reserves have different growth rates, so their characteristics in height can and do
cross. `J` reaches zero and changes sign. Report 10 §8 measured exactly this: 12 non-descending
pairs, minimum `dh = -0.0273` m. Those are not a boundary nuisance to be guarded — **`J < 0` is the
Eulerian density ceasing to exist.**

The failure is a fold, the same object as a caustic in ray optics or a shock in a scalar conservation
law, and the reserve gate manufactures folds by design. Along the storage manifold
`ds/dh = f/g` with `f = dS/dt`, so the omitted term

    (dg/ds)(ds/dh)  =  (dg/ds) * f / g

diverges like `1/g` wherever growth stalls. A stalled cohort — gate shut, `g ~ 0` — has plants
accumulating at one height while recruits keep arriving behind it. The divergence is structural, not
a discretisation artefact, and no stencil removes it.

**Ecologically the pile-up is real.** It is the suppressed sapling bank, and surviving in it is
precisely what storage buys: Stefaniak et al. (2026) attribute the Slow strategies' success to a
"high carbon storage minimum, which facilitated the survival of small saplings in the shade". So the
model is right and the state variable is wrong. The ecology says the density in height should become
singular at a stall; a solver carrying `log n` as an ODE state cannot represent that, and
`Patch::check_finite_node_densities` exists because it does not.

## 5. The boundary condition is where the ecology is actually lost

`Node::compute_initial_conditions` (`node.h:177`):

    set_log_density(g > 0 ? log(birth_rate * pr_estab / g) : log(0.0));

The birth density is `birth_rate * pr_estab / g`. Two things follow, and both are the `1/g` of §4
appearing at the inflow rather than in the interior.

**As `g -> 0` the newborn enters with unbounded weight.** This is the same divergence, and it is why
report 10 §8 finds the boundary pair carrying a mean `|stencil|` of `8.36` against `0.129` for
interior pairs, with a maximum of `161.7`. It is not a property of pairing against a fixed node; it
is `1/g` at the one place in the stand where `g` is most likely to be small.

**If `g <= 0` the cohort is assigned zero density and deleted.** Under a reserve gate that is not an
edge case. A recruit germinating into a period of negative net production, or into deep shade, is
exactly the individual the storage model exists to describe: alive, not growing, drawing down
reserves, waiting. `set_initial_states` (`tf24_strategy.cpp:694`) gives it `a_st3 = 0.8` of capacity
so it usually clears the gate — but the whole point of `#517`/`#554` was drought, and under drought
it need not.

So `plant`'s SCM has a discontinuity sited precisely on the phenomenon that motivated adding storage.
Reading B keeps it. Counts remove it: the number recruited in `[t, t+dt]` is
`birth_rate * pr_estab * dt`, with no division and no cliff.

## 6. The formulation the ecology asks for

Track the count, not the density. This is the **Escalator Boxcar Train** (de Roos 1988): each cohort
carries the number of individuals and the mean individual state, with the density represented as
moments over subdomains moving along the characteristics. It was built for physiologically structured
models with an arbitrary number of individual state variables under nonlinear environmental feedback,
which is what TF24 became at `#554`.

Concretely, in `plant`:

| now | instead |
|---|---|
| state `log_density`; `log_density_dt = -dg/dh - mortality` | state `log_count`; `log_count_dt = -mortality` |
| birth: `log(birth_rate * pr_estab / g)`, undefined at `g <= 0` | birth: `birth_rate * pr_estab` over the introduction interval |
| competition: trapezium in height weighted by density | `sum_j count_j * competition_effect(h_j; z)` |
| soil draw: `consumption_rate * density` | `consumption_rate * count` |
| `Node::growth_rate_gradient`, `Individual::growth_rate_given_height`, four `node_gradient_*` `Control` fields | deleted |
| density is an ODE state | density is `count / dh`, computed at report time only |

Why this is the answer that follows the ecology rather than the solver:

1. **It dissolves the question instead of deciding it.** `dN/dt = -mortality * N` says individuals
   leave a cohort only by dying. That is true whatever state they carry, and true whether or not
   heights stay ordered. There is no stencil to choose and no modelling assumption to site.
2. **It survives the fold.** Trajectories in the full state space `(h, s)` never cross — ODE
   uniqueness. Only their projection onto `h` crosses. Counts live in the full space; densities live
   in the projection. §4's 12 non-descending pairs stop being a premise failure and become an
   ordinary report-time detail.
3. **It is well conditioned exactly where the density formulation is worst.** Along a trajectory
   `log N(t) = log N_0 - integral(mortality)`, and the integrand is smooth and bounded. The density
   carries `log n(t) = log n_0 - integral(dg~/dh) - integral(mortality)`, whose first integrand is
   unbounded — and it carries it **for the cohort's whole life**, so a compression error during the
   recruitment window multiplies that cohort's weight until it dies. That is why report 10 §3.3's
   sub-grid arm is not converged (`42.13 -> 54.80 -> 58.75`, +30% then +7%) while the count-equivalent
   arm is flat (`434.77 -> 436.05 -> 422.80`). Resolution-insensitivity is the signature of
   integrating something smooth.
4. **It makes the SCM and the stochastic solver the same model.** `StochasticSpecies`'s competition
   is already "a plain sum over individuals (no density weighting, no trapezium)"
   (`stochastic_species.h:28`). Under counts the deterministic competition integral takes the same
   form. The claim that the SCM is the deterministic limit of the individual-based model becomes
   structurally true rather than true in a limit no one takes — and it makes §8.2's oracle an exact
   comparison rather than an approximate one.
5. **It delivers everything P2.4 was designed for, as a by-product**: one fewer leaf solve per cohort
   per stage, no `1e-6` divisor, and a right-hand side without the stiff term (report 10 §4 measured
   3.8x fewer accepted steps from removing it). It also has no `dh` in a denominator at all, where the
   cohort-grid stencil divides by a gap whose measured minimum is `8.2e-06` m with 23.5% below `1e-4`.

**The cohort-grid arm already is this formulation, expressed in the wrong coordinates.** That is why
it conserves to `1e-6` (§3) and why it is flat under refinement. Its `~430` limit is the count
formulation's answer. So: report 10's measurements identify the right limit, and the right
implementation is not the stencil that reached it.

### 6.1 What it costs

The Escalator Boxcar Train is formally first order in cohort spacing for smooth solutions, where the
characteristic method can be second order. That trade is worth naming, and here it is not binding:
the solution has caustics, so formal order is not defined at the places that dominate the answer, and
the measured behaviour is the opposite of the formal ordering — the first-order arm is flat under 4x
refinement while the higher-order arm moves 40%.

The count-weighted sum is not bit-identical to the density trapezium, so **every baseline moves**,
including FF16's and K93's. That is the re-blessing conversation `#69` already flags, now unavoidable
rather than optional. Schedule refinement needs its error metric re-derived in count coordinates; the
structure carries over but it is real work. Report 10 §7 records that the two-pass loop, the
deletions, and four replacement tests already exist on `transport/cohort-grid-stencil`.

## 7. Making storage size-slaved is the one option to close off

Report 10 §5.1 and `#69`'s comment both float making storage an explicit function of size and
environment, so that `ds/dh` becomes analytic and "the size-structured assumption becomes true by
construction". It would. It would also delete the ecology.

Storage's entire function is memory. Stefaniak et al. (2026) — the paper TF24's storage is calibrated
against; `set_initial_states` cites its Eq 8, and `#554` names it as the calibration target — find
that stress **stochasticity** shifts community composition more strongly than mean stress intensity.
In their Table 2 the effect of the variance of stress duration on the Slow-Risky strategy's basal area
is `omega^2 = 0.25` ("large"); in Table 3 the effect of the mean is "very small" at almost every level.
Their four strategies are defined by a utilisation *rate* and a switch *time* — properties of the
pool's dynamics, not of its equilibrium value.

Variance can only matter if the plant integrates its history. If `s = s(h, E)` instantaneously, a
plant that has just come through a drought is indistinguishable from one that has not, and the entire
result the storage model exists to reproduce vanishes by construction. It is the option that makes
the solver comfortable by removing the phenomenon.

Two further things the paper settles:

**Their own NSC model never met this problem, because they ran the individual-based solver.**
plantNSC results are 100-year runs on 100 m^2 patches with individual trees, at roughly three days
per simulation on a cluster. An individual-based model counts plants; it has no compression term. The
group's NSC work is already in count coordinates. The question is specific to the SCM's density
variable, not to the biology.

**plantNSC carries far more non-size state than TF24 does.** Because the gate breaks the pipe-model
balance, they add a calibration factor `c_i(H, A_l, M_i)` (their Eqs 2-3) that reads the *actual* pool
mass against the allometrically correct one, making each component mass an independent state —
"periods of no height increase in an individual can be explained by an allometric mismatch after the
period of stress". If `plant` ever adopts that scheme the state is `(h, s, M_foliage, M_sapwood,
M_bark, M_root)` and no reduction to a density in height is available at any price. Whatever is
decided now should be decided for `k` carried states, not for one.

## 8. What to measure, in order

**8.1 The fixed-fraction probe. Cheapest, and it comes first.** Add a variant of
`growth_rate_given_height` that rescales `S` to hold `r` constant while perturbing `h`, and re-run
report 10 §3.1's correlation. This separates §2's dilution artefact from any real decorrelation. It
is strictly more diagnostic than `#69`'s freeze-the-pool test, which shows only that storage matters —
something already known — where this shows *how much of the disagreement is a defect in the probe*.
A large recovery toward the cohort-grid values means part of the 10.3x is a bug, and the re-blessing
conversation changes shape.

**8.2 The stochastic oracle.** `StochasticPatchRunner` is already instantiated for TF24
(`inst/RcppR6_classes.yml:888`), so this needs no C++. The individual-based model counts plants and
has no compression term, so it cannot favour either arm. Agree the comparison protocol *before*
running: the two solvers differ in more than the stencil (finite population, discrete deaths,
demographic stochasticity, patch-age weighting), so compare peak stand structure and per-capita
lifetime fecundity, not only the offspring scalar. Land near `~430` and the omitted term is real;
near `~60` and it is not.

**8.3 Freeze the environment and confirm the channel.** §1 says the whole 10.3x travels through the
light profile and the soil draw. Record the environment trajectory from one arm and force both arms
to run against it. If offspring then agree, the causal chain is closed and the argument reduces to a
single question about the competition integral. If they do not, something outside §1 is in play and
should be found before anything is re-blessed.

**8.4 Look for interior folds across the parameter envelope.** Report 10 found the 12 non-descending
pairs only at the boundary, at one parameter set. Instrument the sign of `h_i - h_{i+1}` over the
interior across the drought sweep `#554` used (`mpl` in {20,30,50,70} x amplitude 0.30-0.40). If
interior folds occur anywhere in the intended envelope, `J` changes sign in the stand, the Eulerian
density is undefined there, and the decision is forced rather than argued.

**8.5 Only then, re-bless.**

## 9. A downstream claim that should not be relied on yet

`#554` reports single-species offspring moving `227.9 -> 25.4` with reserve gating, read as "a
defensible consequence of reserve gating". The two numbers are not comparable on the same footing:

- **Before storage**, the compression term barely moves the answer — report 10 §3.2 measures +16.4%
  on FF16 and +1.4% on K93 between the two arms. `227.9` is close to solver-independent.
- **After storage**, the compression term dominates: 10.3x between arms, and the surviving value is
  not converged (`42.13 -> 54.80 -> 58.75`).

So a solver-insensitive number is being compared with a solver-dominated one, and the direction of
the reported effect is not safe. At report 10's parameters the count-equivalent limit is `~430`. Those
are different parameter sets from `#554`'s, so this is a flag rather than a result — but the
qualitative claim that reserve gating reduces reproductive output should be treated as open until §8
closes, and `TF24_Strategy::scientific_version` was bumped to 3 on the strength of it.

## 10. Measured, versus read, versus derived

**Read from the tree** (`develop` at `141dc8df`): §1's two density consumers and the absence of
density from the fitness integral; §2's `growth_rate_given_height` body, the `S_max(h)` dependence,
and `storage_gate_width = 0.1`; §5's birth density and its `g <= 0` branch; §6's note that
`StochasticSpecies` sums over individuals; §8.2's TF24 instantiation of `StochasticPatchRunner`.

**Read from the paper**: §7's `omega^2` values, the individual-based methodology, the calibration
factor, and the sapling-bank attribution.

**Derived, not measured**: §2's magnitude estimate for the dilution term — the sign and the `1/w`
amplification are read from the code, the size is an order-of-magnitude argument and belongs to §8.1
to confirm or kill. §3's identity. §4's Jacobian argument and the `1/g` divergence, which is
mathematics rather than a probe. §6's third point, explaining the refinement asymmetry.

**Taken from report 10, not re-measured**: every number in §3, §6, §8, §9 that carries a figure —
the correlations, the offspring table, the refinement levels, the conservation drift, the gap
statistics.

**Not claimed**: which limit is ecologically correct. §8.2 is the measurement that decides it and it
has not been taken. Nor anything about a multi-species stand, or about `plant` under an
`ExtrinsicDrivers` regime with a seasonal stress period of the kind Stefaniak et al. simulate — the
latter is where a fold is most likely and it has never been run against the SCM.

---

## References

de Roos, A. M. (1988). Numerical methods for structured population models: the Escalator Boxcar
Train. *Numerical Methods for Partial Differential Equations* 4(3), 173-195.

Falster, D. S., FitzJohn, R. G., Brannstrom, A., Dieckmann, U., Westoby, M. (2016). plant: A package
for modelling forest trait ecology and evolution. *Methods in Ecology and Evolution* 7, 136-146.

Stefaniak, E. Z., Tissue, D. T., Falster, D. S., Medlyn, B. E. (2026). Greater variability in
environmental stress favours trees that prioritise storage of carbohydrate reserves over growth: a
modelling analysis. EGUsphere preprint, https://doi.org/10.5194/egusphere-2026-1474. Local copy:
[`docs/reference/stefaniak-et-al-2026-storage-strategies-egusphere-2026-1474.pdf`](../reference/stefaniak-et-al-2026-storage-strategies-egusphere-2026-1474.pdf)
(CC BY 4.0).
