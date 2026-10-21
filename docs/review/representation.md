# The representation: a table of strategies in sites

`rebuild.md` chose the trade-off: evaluate the singular-strategy condition at
observed communities, as a residual, instead of solving for it. This note
gives the representation that makes that natural, and shows that it answers
more than the residual did.

## 1. The object

A **site** is an observed community under its own daily weather. Recording it
once, with each species' b balanced, gives its field E_i: the light and water
over patch age that its residents make.

A **strategy** is a parameter vector p_j: an observed species' traits, from
trait data where measured and defaults where not.

The object is one table:

  **A_ij = ln R′(p_j | E_i)**, the lifetime fitness of a rare lineage with
  strategy j, in the field of site i.

- **Rows are recordings**, made once.
- **Columns are invader runs** reading a row's recording (about 0.6 F each,
  E7). Invaders do not interact, so the entries are independent.
- **At a site's residents, a sweep adds the row's gradient** in every
  parameter: g_i = ∇_p A_i(p) at p = p_i.

This is the reciprocal transplant and provenance trial, the field experiment
ecologists trust most, computed with competition included: each entry is a
strategy growing among the competitors actually present at a site.

## 2. Every question is a reading of the table

| question | reading | assumptions it does not need |
|---|---|---|
| is the community balanced? | A_ii ≈ 0 for each resident | — |
| is it at an ESS against the observed pool? | each row is maximal at its residents: A_ij ≤ 0 for every absent strategy j | the trade-off; the equilibrium |
| what selection acts there? | g_i at each resident | the equilibrium; M |
| what does it say about trade-offs? | g_i split along the observed trait spectrum and normal to it (§3) | a trade-off function |
| home-site advantage, provenance transfer | A_ii − A_ij, along a row or a column | — |
| who could invade, now or under future weather | positive entries; new rows recorded under projected weather | an assembly simulation |
| how many limiting factors? | the effective rank of A (§4) | a choice of field coordinates |

Nothing in this table is a root. The only solve is b, one dimension per
species, inside each row.

## 3. Trade-offs, read without a trade-off function

**The test needs no trade-off at all.**
- Suppose every observed strategy is feasible: one physiology, shared by the
  species compared.
- A site at an ESS against that pool has no absent strategy that invades it:
  A_ij ≤ 0. That is a finite, exact test, row by row.
- It is the analogue of revealed preference in production theory. Firms that
  share a technology and face different prices must each choose an output at
  least as profitable, at its own prices, as every other firm's choice (Varian
  1984; Afriat 1967 for consumers). There, the objective is known only through
  prices. Here it is computed exactly at every column, so the test is exact,
  not linearised.

**The gradient splits into a test and a price** (*derived*).
- Observed species vary along a low-dimensional spectrum Σ (the leaf economics
  spectrum; Díaz et al. 2016). If neighbours along Σ are feasible, then at an
  ESS selection along Σ must vanish: g_i is orthogonal to Σ's tangent at p_i.
- So g_i = g_∥ + g_⊥:
  - **g_∥, along the observed spectrum,** must be zero at an ESS. It is the
    residual free of any trade-off assumption: the measure of disequilibrium.
  - **g_⊥, normal to it,** is held at zero by trade-offs the model does not
    know. It is their shadow price: the fitness that would be gained per unit
    of each constraint relaxed, a Lagrange multiplier.
- The spectrum's tangent comes from the trait data themselves (local principal
  directions among neighbouring species), so the data say which directions are
  feasible, and the model says what each direction is worth.
- This replaces fitting trade-off slopes (`rebuild.md` §5) as the first
  reading. A fitted slope remains a later, parametric refinement.

## 4. Low rank: H1 becomes the compression

- Theory says fitness depends on the environment only through a few regulating
  variables (Levin 1970; Meszéna et al. 2006). Where it is close to linear in
  them across the sites, A ≈ U Vᵀ: site factors times strategy factors, with
  as many columns as there are regulating variables.
- So the effective rank of A is the number of limiting factors, measured on
  real sites and real strategies. H1 asks whether it is small. H2 asks whether
  it rises with the sites' rainfall variability.
- **If it is small, the table is cheap to fill** (*judgement*). A low-rank
  matrix is recovered from a fraction of its entries (Candès & Recht 2009), and
  the gradients at residents add side information.
- That reverses weakness 6. If H1 is true, the adjoint's advantage in many
  traits shrinks, but the table gets cheaper to fill. H1 now pays for itself.

## 5. Non-smoothness is carried by values, not derivatives

- Off the diagonal the table holds values at the spacing of observed traits.
  A race between cohorts (E8) is a value there, not an infinite derivative.
- Derivatives are used only at residents, and each is checked against its
  neighbours. Where A_ij differs from A_ii + g_i · (p_j − p_i) by more than ε,
  the landscape between them is not smooth, and the value is what is reported.
- So derivatives are a local refinement wherever the values say the landscape
  is smooth, and never the only evidence.

## 6. What it costs

*Estimated* from E7 (F ≈ 49 s at an absolute tolerance of 1e-4), per record:

| part | count | cost each | total for 100 sites, 300 strategies |
|---|---|---|---|
| a row: the recording, b balanced for its residents | 100 | about 5 F | 500 F |
| an entry: an invader reading a row | 30,000 | about 0.6 F | 18,000 F |
| a resident's gradient: a sweep | 500 | about 1.9 F | 950 F |
| total | | | about 19,500 F, 265 core-hours |

- A fifth of the entries, if the rank is small, brings it to about 70
  core-hours.
- Records per site multiply it. How many are needed is set by the spread of A
  across records.
- **There is no iteration.** Every question in §2 is linear algebra on a table
  of doubles in R. Runs are made once; questions are asked afterwards.
- Calibration is the one reading that needs more: each entry's sweep with the
  physiology on the tape gives ∂A_ij/∂c in every constant at once, and a
  Gauss–Newton step on c uses the whole table.

## 7. Why this is the representation, not a feature

The same move runs through every part of the design: **run once, decide
afterwards.**

| decided after the runs | from |
|---|---|
| the trade-off | the chain rule on partials, already in `stand_gradient` |
| whether the community is at an ESS | the row maxima |
| which directions are feasible | the observed spectrum |
| how many limiting factors | the rank |
| where the landscape is smooth | entries against gradients |

It meets each of the objections in `weaknesses.md`:
- **4, trade-offs:** none is specified. Feasibility comes from the data, and
  the model prices the constraints.
- **5, cost:** a fixed, parallel table with no iteration.
- **6, few modes:** low rank makes the table cheaper.
- **7, equilibrium:** rows are observed communities. Equilibrium is the row
  maxima's test, not an input.
- **2, non-smoothness:** values carry it, and derivatives are checked against
  them.

It meets the data in their own shape:
- columns are trait records (AusTraits);
- rows are plots with their daily weather;
- entries are what reciprocal transplants and provenance trials measure.

## 8. What it makes hard

- **Unmeasured parameters** are the weakest joint. A column with hydraulics at
  defaults is a partly specified strategy. Read gradients only in measured
  directions, and report how much an entry moves when an unmeasured parameter
  is varied across its plausible range.
- **One shared physiology is assumed** for the strategies compared. Lineages
  with different constraints (angiosperms and conifers) need their own pools
  and spectra.
- **Ecological balance in each row,** approximately: |F| < 0.06 keeps a
  gradient within ε on long drought (E5). Recently disturbed sites are out.
- **Prediction in a climate with no observed community** still needs the
  forward solve of `formulation.md`. The table supplies its starting point and
  its calibrated physiology.

## 9. First steps

1. **g under the scheduling guarantees** (the next work item), extended to
   entries: an invader's ln R′ judged with the same ε.
2. **Whether one invader run can carry many strategies** on the #116 design. If
   so, a row's columns cost one run, not one each.
3. **A first table by hand:** three sites along one rainfall gradient, ten
   strategies. Check the diagonal, the row maxima, and gradients against their
   neighbours.

## References

- Afriat, S.N. (1967). The construction of utility functions from expenditure
  data. *Int. Econ. Rev.* 8: 67–77. doi:10.2307/2525382
- Candès, E.J. & Recht, B. (2009). Exact matrix completion via convex
  optimization. *Found. Comput. Math.* 9: 717–772.
  doi:10.1007/s10208-009-9045-5
- Meszéna, G., Gyllenberg, M., Pásztor, L. & Metz, J.A.J. (2006). Competitive
  exclusion and limiting similarity: a unified theory. *Theor. Popul. Biol.*
  69: 68–87. doi:10.1016/j.tpb.2005.07.001
- Varian, H.R. (1984). The nonparametric approach to production analysis.
  *Econometrica* 52: 579–597. doi:10.2307/1913466
- Díaz, S. et al. (2016; online 2015). The global spectrum of plant form and
  function. *Nature* 529: 167–171. doi:10.1038/nature16489
- Levin, S.A. (1970). Community equilibria and stability, and an extension of
  the competitive exclusion principle. *Am. Nat.* 104: 413–423.
  doi:10.1086/282676
