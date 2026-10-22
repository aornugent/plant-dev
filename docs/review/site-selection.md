# Selection estimated at observed sites, not solved for

**The reformulation.** Stop solving for the evolved community. Run the observed community
at each site under its own daily weather, and read selection there: the singular-strategy
condition is evaluated as a residual, never solved as a root. Observed traits and weather
supply what the forward problem would solve for. The data then calibrate the assumptions
(the trade-offs and the physiology), instead of the assumptions predicting the data.
Evolutionary equilibrium becomes something tested, not assumed.

This note distils the last three reviews of 21 October 2026, on the tag
`archive/trusting-curie` under `docs/review/`: `weaknesses.md` (the case against solving
for the outcome), `rebuild.md` (the residual) and `representation.md` (the table). Numbers
are measured unless marked *estimated* (E1–E8 are
`docs/measurements/regnans-roadtest/rootcause/` there, defined in `../findings.md`); F is
one TF24 forward run, about 49 s on long drought at an absolute tolerance of 1e-4 (E7).

**Two hypotheses recur** (`frontier.md` §3 on the tag). **H1, trait syndromes as few
modes:** plant traits covary along a few axes (the leaf economics spectrum; Díaz et al.
2016) because selection on fifty traits acts through a few directions of environmental
feedback. **H2, variability raises the dimension:** at equal mean rainfall, variable
records raise that number of directions, and with it the number of strategies that can
coexist.

**Not yet checked against the literature.** The reviews' novelty searches covered the
forward programme; no search was run on the residual reformulation itself. The closest
prior work they found elsewhere is constrained estimation of structural equilibria (Su &
Judd 2012) and ESS predictions compared with data but not fitted (Dybzinski et al. 2011).

## 1. Why the forward problem is the wrong target

The machinery is strong at one run, one scalar, many inputs: g in every trait from one
invader sweep, about 2.5 F; any trade-off applied after the sweep by the chain rule; a
recorded field any invader can read. It is weak at many runs and second order: a root of
the loop's conditions G(x; c) = 0 needs Newton steps × Krylov iterations × about 5 F per
product, about 150 F per root per record (*estimated*), and the Jacobian G_x needs chords of
sweeps that cross kinks and races.

"Given the assumptions, where does evolution go" needs the weak column, and that is where
four objections from `weaknesses.md` meet:
- **The outcome is set by the trade-offs, which are assumptions.** Theory knows outcomes
  hinge on a trade-off's shape (de Mazancourt & Dieckmann 2004) and cannot measure it. G_x
  is where they enter.
- **The root costs too much** at the scale of trait–climate maps: tens to hundreds of
  climate points, each needing records.
- **If selection has few modes, the adjoint's advantage shrinks.**
- **Forests are not at evolutionary equilibrium.** Trees live long and climate moves within
  a few generations. Trait–climate slopes in data are mostly species turnover.

## 2. The residual

At an observed site, G(x_obs; c) is a measurement, not an equation. Per species i:
1. **F_i = ln R′ at its own traits.** Balancing b sets it near zero. A species that cannot
   be balanced at its observed traits is a direct disagreement between model and site.
2. **g_i, an elasticity per parameter:** d ln R′/d ln θ_k for a rare lineage of species i
   differing by 1% in θ_k, growing in the light and water the observed community makes,
   under the site's record. One sweep gives every k.
   - In partials (`hyperpar = NULL`) each parameter moves alone.
   - Along a trade-off, g is Tᵀ g_partial, with T the trade-off's Jacobian. So "selection
     on `lma`" depends on T, and T is what the fit infers.
3. **Optionally F_θ:** the same species when all of it changes and the field responds.
   g − F_θ is its commons vector.
4. **Optionally, attribution:** g split over patch age, size and time by the adjoint, and
   over the days of the record.

**Scale, from the one number measured.** On long drought at TF24's defaults, g in `lma`
along the trade-off is −23.8: a variant with 1% lower `lma` has ln R′ higher by 0.24, R′
about 1.27. Field estimates of standardised selection gradients are mostly 0.1–0.2 per
standard deviation (Kingsolver et al. 2001). A within-species spread in ln `lma` of 0.2
would turn −23.8 into about 5 per standard deviation. A residual that large at a real site
would point at the trade-off or the model before it pointed at selection (*judgement*). The defaults are not an observed
community, so this says only that they are far from singular on that record.

**A nonzero residual has four readings,** separated across sites, not at one:

| reading | its signature across sites |
|---|---|
| a wrong or missing trade-off | shared by every site: one T fits them all |
| disequilibrium: climate has moved, or the species arrived recently | aligned with each site's recent climate trend |
| constraint: little heritable variation in that direction | shared across a lineage's sites, whatever the climate |
| model error | none of the above |

**Assumed:** ecological balance, approximately (|F| < 0.06 keeps g within ε on long drought,
since dg/d ln b = −6.0, E5; recently disturbed sites are out), and that the record
represents the climate regime. **Not assumed:** evolutionary equilibrium, the trade-off, the
mutational covariance M.

**Calibration needs no iteration over hypotheses** (`rebuild.md` §5, *derived*). With
the run held at the observed point, a trade-off's slopes enter g only through the chain
rule applied after the sweep, so **the residual is linear in the slopes**: one pass over
the sites, then least squares. Physiology constants are not linear: take one Gauss–Newton
step from the defaults, using g's Jacobian in the measured directions (two displaced
sweeps each), rerun at the fitted constants to check, and iterate only where the check
fails. Per species, site and record that is about 11 F for the residual and its
calibration gradient, and 25–50 F with 5–10 measured directions. For 100 sites and 8
records, about 40,000 F, 550 core-hours (*estimated*). An optimiser iterating over all
sites would cost about 440,000 F, 6,000 core-hours: the forward problem's cost by another
route. On the table (§3), each entry's sweep with the physiology on the tape gives
∂A_ij/∂c in every constant at once, and a Gauss–Newton step uses the whole table.

**Nash against planner, decided by data.** Do observed traits satisfy g = 0
(uninvadable), or F_θ = 0 (the stand optimum)? Each is one sweep per species. That tests
whether nature follows an optimisation principle, which Metz, Mylius & Diekmann (2008)
say exists only when the feedback is one-dimensional.

**The precedents.** EEO's successful models already make this move for physiology: the
P-model uses the least-cost condition algebraically and never simulates evolution (Wang et
al. 2017). This is the same move for competitive, whole-life fitness, which needs the
all-trait invasion gradient. Empirical economics made it for dynamic games: rather than
solve the equilibrium inside estimation, plug observed play into the optimality conditions
and require that no deviation pays (Hotz & Miller 1993; Bajari, Benkard & Levin 2007). Here
the resident run under observed traits is the observed play, and invaders are the
deviations.

## 3. The representation: a table of strategies in sites

A **site** is an observed community under its own daily weather; recording it once, with
each species' b balanced, gives its field. A **strategy** is a parameter vector: an
observed species' traits, from trait data where measured and defaults where not. The object
is one table,

  **A_ij = ln R′(p_j | E_i)**, a rare lineage of strategy j in the field of site i.

- Rows are recordings, made once. Columns are invader runs reading a row (about 0.6 F
  each). Invaders do not interact, so entries are independent.
- At a site's residents a sweep adds the row's gradient, g_i.
- It is the reciprocal transplant and the provenance trial, the field experiments
  ecologists trust most, computed with the competitors actually present.

**Every question is a reading of the table,** and nothing in it is a root:

| question | reading | does not need |
|---|---|---|
| is the community balanced? | A_ii ≈ 0 for each resident | — |
| is it at an ESS against the observed pool? | each row maximal at its residents: A_ij ≤ 0 for every absent j | a trade-off; equilibrium |
| what selection acts there? | g_i at each resident | equilibrium; M |
| what does it say about trade-offs? | g_i split along and normal to the observed trait spectrum | a trade-off function |
| home-site advantage, provenance transfer | A_ii − A_ij along a row or column | — |
| who could invade, now or under projected weather | positive entries; new rows recorded under projected weather | an assembly simulation |
| how many limiting factors? | the effective rank of A | a choice of field coordinates |

**Trade-offs read without a trade-off function** (*derived*). If every observed strategy is
feasible, a site at an ESS against the pool has A_ij ≤ 0: an exact, finite test, the
analogue of revealed preference in production theory (Varian 1984; Afriat 1967). And if
species vary along a low-dimensional spectrum Σ (Díaz et al. 2016), then at an ESS
selection along Σ vanishes. So g_i = g_∥ + g_⊥: **g_∥**, along the observed spectrum, is the
residual free of any trade-off assumption, the measure of disequilibrium; **g_⊥**, normal to
it, is held at zero by constraints the model does not know, and is their shadow price. The
data say which directions are feasible, and the model says what each is worth.

**Low rank is H1** (*judgement*). Fitness depends on the environment through a few
regulating variables (Levin 1970; Meszéna et al. 2006). Where that holds across sites,
A ≈ U Vᵀ, with as many columns as limiting factors. So the effective rank of A is H1,
measured on real sites; H2 asks whether it rises with rainfall variability. A low-rank table
is also recovered from a fraction of its entries (Candès & Recht 2009), so if H1 holds the
table is cheaper to fill. That reverses the objection that few modes weaken the adjoint.

**Non-smoothness is carried by values.** Off the diagonal the table holds values at the
spacing of observed traits; a race between cohorts (E8) is a value there, not an infinite
derivative. Derivatives are used only at residents, and checked against neighbours: where
A_ij differs from A_ii + g_i · (p_j − p_i) by more than ε, the value is what is reported.
Races are still possible on real weather: a species where one cohort carries most of R′ is
routed to one-sided invader runs, not a gradient (`rebuild.md` §5).

## 4. Cost

*Estimated*, per record, for 100 sites and 300 strategies:

| part | count | each | total |
|---|---|---|---|
| a row: the recording, b balanced for its residents | 100 | about 5 F | 500 F |
| an entry: an invader reading a row | 30,000 | about 0.6 F | 18,000 F |
| a resident's gradient: a sweep | 500 | about 1.9 F | 950 F |
| total | | | about 19,500 F, 265 core-hours |

There is no iteration: runs are made once, and every question is linear algebra on a table
of doubles. If the rank is small, filling a fifth of the entries brings the total to about
70 core-hours. Entries are 92% of the cost, so the levers are an entry's nodes and its row's
steps. The schedule design for the table (`design-schedule.md` on the tag) gives each row a
refined, certified schedule and each entry a thinned one with a free estimate from a sub-sum
of its own per-node offspring, bringing the total to about 170 core-hours. Records per site
multiply the cost; how many are needed is set by the spread of A across records.

## 5. What it gives up, and what is hard

- **Prediction in a climate with no observed community.** That still needs the forward
  solve. The table supplies its starting point and calibrated physiology, so the forward
  solve becomes a short extrapolation instead of a prediction from first principles.
- **Unmeasured parameters** are the weakest joint. Trait databases (AusTraits; Falster et
  al. 2021) cover `lma`, wood
  density, height and seed mass well, and hydraulic curves and allocation hardly at all.
  Read gradients only in measured directions, and report how much an entry moves across an
  unmeasured parameter's plausible range.
- **One shared physiology** is assumed for the strategies compared. Angiosperms and
  conifers need their own pools and spectra.
- **Separating model error from disequilibrium:** calibrate on sites whose climate has been
  stable, and read disequilibrium where it has moved.

**The fallback: demographic assimilation** (`rebuild.md` §3, candidate C). Fit the
physiology to remeasured plots' growth and mortality by size, over short runs. It is cheap
and needs no fitness at all, but it says nothing about selection. It is the route for the
physiology if the residual fit fails.

**Kill conditions** (`rebuild.md` §7). If trade-offs become well constrained independently,
the forward prediction becomes trustworthy and this shrinks to its validation. If no shared
physiology makes the residuals small at stable-climate sites, the model is wrong, not the
equilibrium; demographic assimilation takes over the physiology before the residual is
tried again.

## 6. Where it starts

1. **g under the scheduling guarantees,** extended to entries: an invader's ln R′ judged
   with the same ε (`../schedule/refine.md`, Next). It is now the whole product.
2. **Whether one invader run can carry many strategies** on plant#116's design. If so, a
   row's columns cost one run, not one each.
3. **A first table by hand:** three sites along one rainfall gradient, ten strategies.
   Check the diagonal, the row maxima, and gradients against their neighbours. Balance b,
   read g with `hyperpar = NULL`, and apply two trade-off slopes after the sweep, checking
   that linearity against a rerun built at the second slope.

## References

Each was resolved against Crossref in the original reviews unless marked.

- Afriat, S.N. (1967). *Int. Econ. Rev.* 8: 67–77. doi:10.2307/2525382
- Bajari, P., Benkard, C.L. & Levin, J. (2007). *Econometrica* 75: 1331–1370.
  doi:10.1111/j.1468-0262.2007.00796.x
- Candès, E.J. & Recht, B. (2009). *Found. Comput. Math.* 9: 717–772.
  doi:10.1007/s10208-009-9045-5
- Dybzinski, R., Farrior, C., Wolf, A., Reich, P.B. & Pacala, S.W. (2011). *Am. Nat.* 177:
  153–166. doi:10.1086/657992
- de Mazancourt, C. & Dieckmann, U. (2004). Trade-off geometries and frequency-dependent
  selection. *Am. Nat.* 164: 765–778. doi:10.1086/424762
- Díaz, S. et al. (2016). The global spectrum of plant form and function. *Nature* 529:
  167–171. doi:10.1038/nature16489
- Falster, D. et al. (2021). AusTraits. *Sci. Data* 8: 254. doi:10.1038/s41597-021-01006-6
- Hotz, V.J. & Miller, R.A. (1993). *Rev. Econ. Stud.* 60: 497–529. doi:10.2307/2298122
- Kingsolver, J.G. et al. (2001). *Am. Nat.* 157: 245–261. doi:10.1086/319193
- Levin, S.A. (1970). *Am. Nat.* 104: 413–423. doi:10.1086/282676
- Metz, J.A.J., Mylius, S.D. & Diekmann, O. (2008). When does evolution optimize? *Evol.
  Ecol. Res.* 10: 629–654. No DOI.
- Meszéna, G., Gyllenberg, M., Pásztor, L. & Metz, J.A.J. (2006). *Theor. Popul. Biol.*
  69: 68–87. doi:10.1016/j.tpb.2005.07.001
- Su, C.-L. & Judd, K.L. (2012). Constrained optimization approaches to estimation of
  structural models. *Econometrica* 80: 2213–2230. doi:10.3982/ECTA7925
- Varian, H.R. (1984). *Econometrica* 52: 579–597. doi:10.2307/1913466
- Wang, H. et al. (2017). *Nature Plants* 3: 734–741. doi:10.1038/s41477-017-0006-8
