# Why `mass_above_ground`'s `rho` gradient has the wrong sign at 88 nodes

**Answer in one line.** It reproduces exactly; it is **discretisation, not a
defect**; the adjoint is exact to four or five digits against an independent whole-run
difference at the very node count where the sign is wrong; and the quantity is
**ill-conditioned** — the converged gradient is 1% of each of the two terms that
make it, so the swept term's ordinary 2.5% node error is 2.6x the answer and
takes the sign with it.

No code under `plant/` or `odelia/` was changed. Both trees are clean at
`claude/trusting-curie-4i9n3l` (`5321593a` / `be3e2cb`), so the `make test-cpp` /
fast-sweep guard did not apply.

---

## 1. The symptom, reproduced

`diag-gradient-error.md` reports, from the reverse-mode adjoint of the census
metrics on the birth-date coordinate (TF24, one species, `lma = 0.0825`,
`rho = 608`, `hmat = 16.59587`, `max_patch_lifetime = 5`, constant rainfall 3.0,
`ode_tol = 1e-4`):

| nodes | 88 | 175 | 349 | 697 |
|---|---|---|---|---|
| `mass_above_ground` | 9.6699473 | 9.6674165 | 9.6666681 | 9.6664601 |
| `d/drho` | **+1.9757e-04** | -4.4059e-05 | -1.1769e-04 | -1.2634e-04 |

Reproduced bit for bit. `ws_reprex.R` gives `+1.97574677e-04` at 88 nodes in
about twenty seconds.

## 2. Minimal reprex — one run, ~20 s

`ws_reprex.R`. One species, the default 88-node schedule, one metric, one trait,
and it prints the cause as well as the symptom:

```
88 nodes, 563 steps
mass_above_ground          9.66994728e+00
d/drho, total              1.97574677e-04   <- converged value is -1.244e-04
        direct term        1.24480825e-02
        swept term        -1.22505078e-02
        |swept| / |total|            62.0
```

The two terms are `stand_gradient`'s own decomposition, which
`SCM::census_trait_gradient` (`plant/inst/include/plant/scm.h:1104`) builds
explicitly: the trait adjoint **starts at** the census's own reading of the
traits at the final state (`both.trait`, `scm.h:1155`) and the sweep adds the
trajectory's contribution to it. The direct half is exported as
`ladder_census_trait_direct_tf24`
(`plant/src/gradient_ladder.cpp:952`); the total is `stand_gradient`; the swept
half is the difference.

`Rscript ws_reprex.R 1` runs the same thing one bisection finer (175 nodes,
~40 s) and the sign is back.

(The ratio the reprex prints, 62, is taken against the 88-node total, which is
itself 2.6x wrong. Against the converged total it is 101, which is the number
§5 works with.)

## 3. The decisive bisection — discretisation, and it corrects

`ws_repro.R -2 4`, seven nested levels on the same dyadic schedule, adaptive time
grid at `ode_tol = 1e-4` (`ws_repro_-2_4.rds`):

| nodes | 23 | 45 | **88** | 175 | 349 | 697 | 1393 |
|---|---|---|---|---|---|---|---|
| `mass_above_ground` `d/drho` | -2.9886e-03 | **+1.2108e-03** | **+1.9757e-04** | -4.4059e-05 | -1.1769e-04 | -1.2634e-04 | -1.2441e-04 |
| `leaf_area` `d/drho` | -1.7848e-03 | **+1.2812e-04** | -4.0253e-04 | -5.2821e-04 | -5.6593e-04 | -5.7094e-04 | -5.6938e-04 |
| `area_stem` `d/drho` | -5.6226e-07 | **+5.3950e-08** | -1.3273e-07 | -1.7769e-07 | -1.9081e-07 | -1.9286e-07 | -1.9219e-07 |

**The sign corrects at 175 nodes and stays corrected through 1393.** So this is
the discretisation investigation, not the adjoint one.

Two things the bisection adds that the refining-only study could not see:

- **All three metrics' `rho` columns are sign-wrong at 45 nodes.** The default
  88-node schedule is simply the level at which two of the three have recovered
  and one has not. `mass_above_ground` is not qualitatively different; it is one
  refinement behind, for the reason in §5.
- **`leaf_area` and `area_stem` are sign-wrong at 45 nodes with a direct term
  that is exactly zero**, so a direct/swept cancellation is not the whole story
  about `rho` — see §7.

The 697 and 1393 levels differ by 1.5% on `mass_above_ground d/drho`; that
residue is the adaptive time grid moving between levels (1036 vs 1661 steps), not
the node grid. It does not touch the sign.

## 4. Is the adjoint right? Yes — checked against two independent instruments

Before attributing anything to conditioning, the sweep has to be shown to be the
exact derivative of the discrete functional **at 88 nodes**, where the sign is
wrong. `ws_fd2.R` does that, with both confounds the package's own reference
capture names (`plant/tests/testthat/helper-gradient-ladder.R:1592`) removed:
the **raw strategy parameter** is moved rather than the trait (see §6), and both
sides census on the base run's time grid (`p$ode_times`).

At 88 nodes, `d = 1e-4`:

| metric | trait | central difference | sweep | forward tangent | diff/sweep |
|---|---|---|---|---|---|
| `leaf_area` | `lma` | -1.92105115e+01 | -1.92104140e+01 | -1.92104140e+01 | 1.00001 |
| `leaf_area` | `rho` | -4.02518743e-04 | -4.02530307e-04 | -4.02530307e-04 | 0.99997 |
| `mass_above_ground` | `lma` | -9.41154318e+01 | -9.41157270e+01 | -9.41157270e+01 | 1.00000 |
| `mass_above_ground` | `rho` | **+1.97569375e-04** | **+1.97574677e-04** | **+1.97574677e-04** | **0.99997** |
| `area_stem` | `lma` | -6.53229873e-03 | -6.53229134e-03 | -6.53229134e-03 | 1.00000 |
| `area_stem` | `rho` | -1.32721413e-07 | -1.32728778e-07 | -1.32728778e-07 | 0.99994 |

The difference is resolved rather than lucky: for the pair that matters,
`mass_above_ground d/drho` at 88 nodes reads `+2.1387e-04`, `+1.97569e-04`,
`+1.97707e-04`, `+2.00743e-04` at `d =` 1e-3, 1e-4, 1e-5, 1e-6 — a plateau of
0.07% across the middle two, with truncation above it and round-off below. The
same at 23 nodes, all nine metric/trait pairs, agrees to 1e-4 relative or better
(`ws_fd2.R -2`).

So: **a difference of whole re-runs, which shares no arithmetic with the sweep,
says the 88-node census functional genuinely increases with `rho`.** The wrong
sign is a property of the discretised functional, not of differentiating it.
The forward tangent (`ladder_trajectory_tangent_tf24`) agrees with the reverse
sweep to ten digits as well, so the transpose is sound.

## 5. Root cause

`mass_above_ground` is the only registered metric that reads `rho` explicitly:

```
mass_above_ground = mass_leaf + mass_bark + mass_sapwood + mass_heartwood
mass_sapwood = area_sapwood * height * eta_c * rho      (tf24_strategy.h:1839)
mass_bark    = area_bark    * height * eta_c * rho      (tf24_strategy.h:1850)
```

So `d/drho` is the sum of exactly the two opposing paths the brief names, and
`stand_gradient` computes them as separate terms:

- **direct**, `+1.2443923e-02` at 1393 nodes — denser wood, more mass in the
  bark and sapwood already standing. Because that mass is exactly linear in
  `rho`, this term's elasticity **is** the bark-plus-sapwood share of
  above-ground mass: `+0.78270`.
- **swept**, `-1.2568333e-02` — denser wood costs more per unit height
  (`dmass_sapwood_darea_leaf` ∝ `rho`, `tf24_strategy.h:2502`), so the stand is
  smaller. Elasticity `-0.79053`.
- **total**, `-1.2441e-04`. Elasticity `-0.007825`.

**The answer is 1% of each of the terms that make it.** The condition number
`|swept| / |total|` is **101**.

### The amplification, checked level by level

Errors below are against the 1393-node level (`ws_arith.R`):

The two terms add, so their relative errors add weighted by their sizes:

```
err(total) = (|direct|/|total|) x err(direct) + (|swept|/|total|) x err(swept)
           =        100.0      x err(direct) +       101.0       x err(swept)
```

| nodes | err in value | err in direct | err in swept | err in total | that formula | its swept part alone |
|---|---|---|---|---|---|---|
| 23 | -1.4033% | -1.3025% | -21.499% | **-2302.19%** | **-2302.19%** | -2171.90% |
| 45 | +0.0004% | -0.0120% | +10.635% | **+1073.21%** | **+1073.21%** | +1074.41% |
| **88** | **+0.0366%** | **+0.0334%** | **+2.529%** | **+258.81%** | **+258.81%** | +255.46% |
| 175 | +0.0104% | +0.0092% | +0.630% | +64.59% | +64.59% | +63.67% |
| 349 | +0.0027% | +0.0024% | +0.051% | +5.40% | +5.40% | +5.16% |
| 697 | +0.0005% | +0.0005% | -0.016% | -1.55% | -1.55% | -1.60% |

Three readings, each of which would have failed had the diagnosis been wrong:

1. **The direct term converges like a value, not like a gradient.** Its node
   error tracks the metric's own to two digits at every level (0.0334% against
   0.0366% at 88 nodes). It is a trapezium of a smooth function of the final
   state, and it is not where the error is.
2. **The swept term carries the ordinary gradient node error** — 2.53% at 88
   nodes, squarely inside the 0.35–2.5% band the other swept columns sit in
   (`ws_band.R`: `leaf_area d/dlma` 2.34%, `area_stem d/dlma` 2.46%,
   `mass d/dlma` 0.87%, the three `d/dhmat` 0.35–0.45%). **Nothing about the
   `rho` column is anomalous inside the sweep.**
3. **The total's error is its two terms' errors, amplified by 100 and 101.**
   At 88 nodes the total's absolute node error is `+3.2199e-04`, of which the
   swept term supplies `+3.1783e-04` (**98.7%**) and the direct term
   `+4.16e-06`. The formula above reproduces `err(total)` to the printed digits
   at **every** level from 23 to 697 — across four orders of magnitude of error
   and three sign changes — and the swept term alone accounts for 94-101% of it.

That last line is the verification. **A missing or mis-signed term in the adjoint
would appear as a roughly constant offset, independent of the node count.** What
is there instead is, at six node levels, exactly the two terms' own node errors
multiplied by fixed factors of 100 and 101 — the factors being the terms' sizes
relative to the answer. For the sign to come out right the swept term has to be
converged to better than 1/101 = 1%, which first happens at 175 nodes.

### Why the fixture in particular

The cancellation is not a knife-edge in `rho`; it is the fixture's patch lifetime
sitting on the zero crossing. Same stand, default schedule, varying
`max_patch_lifetime` (`ws_rho.R life`):

| lifetime | 4 | 4.25 | 4.5 | 4.75 | **5** | 5.25 | 5.5 |
|---|---|---|---|---|---|---|---|
| `d/drho` (88-node grid) | -3.3876e-03 | -1.6976e-03 | -1.0600e-03 | -6.8483e-04 | **+1.9757e-04** | +3.6420e-04 | +9.5272e-04 |
| direct | 1.0081e-02 | 1.0796e-02 | 1.1405e-02 | 1.1960e-02 | 1.2448e-02 | 1.2892e-02 | 1.3301e-02 |
| swept | -1.3468e-02 | -1.2494e-02 | -1.2465e-02 | -1.2645e-02 | -1.2251e-02 | -1.2528e-02 | -1.2348e-02 |
| `|direct|/|total|` | 3.0 | 6.4 | 10.8 | 17.5 | **63.0** | 35.4 | 14.0 |

and one bisection finer (175 nodes), where the crossing sits just above 5:

| lifetime | 4 | 4.5 | **5** | 5.5 | 6 |
|---|---|---|---|---|---|
| `d/drho` | -3.3719e-03 | -1.0102e-03 | **-4.4059e-05** | +9.6203e-04 | +6.3042e-03 |
| `|direct|/|total|` | 3.0 | 11.3 | **282.5** | 13.8 | 2.2 |

Young stands are dominated by the growth penalty; mature stands accumulate the
mass-per-volume gain. They cross at a patch lifetime of about 5, which is the
lifetime this fixture uses. **`max_patch_lifetime = 5` at `rho = 608` puts the
measurement on a stationary point of stand above-ground biomass in wood density.**

## 6. A confound that has to be stated: trait derivative is not parameter partial

Found while building the check in §4, and it matters for how
`diag-gradient-error.md`'s tables should be read.

`TF24_hyperpar` (`plant/R/tf24.R:116`) sets strategy parameters from traits:
`k_l = B_kl1 * (lma/lma_0)^-1.71` (leaf turnover from `lma`) and
`r_s = B_rs1/rho`, `r_b = B_rb1/rho` (sapwood and bark respiration from `rho`).
It does not read `hmat`. So `add_strategies(p, trait_matrix(...))` moves several
parameters at once, while the sweep's `1.lma` and `1.rho` columns are partials in
the single strategy parameter.

Same stand, same pinned time grid, one difference each way (`ws_hyper.R`,
23 nodes, `d = 1e-4`):

| metric | trait | d/d trait (through hyperpar) | d/d parameter | sweep column | trait/parameter |
|---|---|---|---|---|---|
| `leaf_area` | `lma` | -3.6348087e+00 | -2.3227302e+01 | -2.3221879e+01 | **0.156** |
| `leaf_area` | `rho` | -1.1955034e-03 | -1.7881949e-03 | -1.7847996e-03 | **0.669** |
| `leaf_area` | `hmat` | 3.9356448e-04 | 3.9356448e-04 | 3.9356285e-04 | 1.000 |
| `mass_above_ground` | `lma` | -2.1270974e+01 | -1.0263716e+02 | -1.0262577e+02 | **0.207** |
| `mass_above_ground` | `rho` | -9.0322060e-04 | -2.9960768e-03 | -2.9885764e-03 | **0.301** |
| `mass_above_ground` | `hmat` | 1.0815035e-03 | 1.0815035e-03 | 1.0814993e-03 | 1.000 |
| `area_stem` | `lma` | -1.4028470e-03 | -7.7710225e-03 | -7.7697244e-03 | **0.181** |
| `area_stem` | `rho` | -3.8661304e-07 | -5.6307696e-07 | -5.6225550e-07 | **0.687** |
| `area_stem` | `hmat` | 9.9713837e-08 | 9.9713837e-08 | 9.9713400e-08 | 1.000 |

`hmat` agrees bit for bit both ways; `lma` and `rho` do not, by factors of 5-6
and 1.5-3. Both are exactly the couplings `TF24_hyperpar` declares.

Consequence for the prior note: **its `dJ/dlma` and `dJ/drho` (finite differences
built with `add_strategies(matrix(th, ...))`, `ge_common.R:49`) are derivatives
along the hyperparameterised trait manifold, and the adjoint table beside them is
partials in the strategy parameter.** They are answers to different questions and
should not be read as two estimates of one number. Nothing in this diagnosis
depends on that, and it does not change any of the prior note's *within-column*
convergence statements — but the two tables are not comparable across.

## 7. Hypotheses, with what would have disconfirmed each

| hypothesis | prediction written before the check | outcome |
|---|---|---|
| **Near-cancellation of two larger opposing terms** (brief's first) | direct and swept each ~100x the total; their ratio ~1; the total's node error equals the swept term's times `|swept|/|total|` at every level | **Confirmed.** `|direct|/|total|` = 100.0 and `|swept|/|total|` = 101.0; the two terms' own node errors, scaled by those two factors, reproduce the total's error to the printed digits at six levels (§5). Disconfirming would have been a residual offset independent of the node count, or a direct term of the same size as the total. |
| **A `rho` path the tape does not carry** (brief's second) | the sweep would differ from a whole-run difference by a fixed amount at every node level, and the gap would not shrink with refinement | **Disconfirmed.** Sweep = central difference to 1e-4 relative at 23 nodes (all nine pairs) and at 88 nodes, on a pinned grid with the raw parameter moved (§4). The one candidate read in the source — the seed size, which `rho` enters through `mass_live_given_height` — is carried, by the implicit-function derivative in `seed_geometry()` (`tf24_strategy.h:1143`). |
| **Quadrature differentiates differently from how it integrates** (brief's third) | the sweep would not equal the exact derivative of the discrete functional | **Disconfirmed as stated** by the same check: the sweep *is* that exact derivative. Any inconsistency between `Species::reduce_competition` / `consumption_rate` and the output trapezium lives in the forward discretisation, which both the sweep and the difference see identically. It can only affect the *rate* at which the discrete gradient converges, not the agreement. |
| **An omitted event term** (brief's fourth) | a pinned-grid whole-run difference would exceed the sweep by the event contribution | **Disconfirmed** by the same agreement, on this stand. `census_operating_point_counts_tf24` reports 0% non-interior leaf solves under constant forcing, so no branch event fires here; this says nothing about intermittent records. |
| **A defect that no node count fixes** | the sign would stay wrong at every level including 1393 | **Disconfirmed.** Correct from 175 up (§3). |

## 8. What is *not* explained, and is worth a follow-up

`leaf_area` and `area_stem` have a direct `rho` term of **exactly zero** — they
read no `rho` — and their `d/drho` still carries 29-31% node error at 88 nodes,
against 2.3-2.5% for the same metrics' `d/dlma` and 0.38-0.45% for `d/dhmat`
(`ws_band.R`). So there is a second, smaller ill-conditioning in `rho` that this
split cannot expose, inside the sweep itself: `rho`'s net influence on stand size
is a residue of opposing rate-level paths (construction cost up, storage capacity
and so storage-dependent mortality down, sapwood respiration up). In elasticity
units the `rho` column's absolute node error at 88 nodes is 0.023 against
`lma`'s 0.0088 — 2.7x larger — *and* its elasticity is 4.7x smaller, which
between them give the 12x worse relative error. Separating those two would need a
per-path decomposition the current exports do not offer.

Also unmeasured here: whether the same cancellation holds under intermittent
forcing. Everything above is `constant 3.0`. Under a mixed record the prior
note's adjoint swings 13-43% between levels for reasons that are the time grid,
so the node-grid statement cannot be made there without pinning it first.

## 9. Recommendation — no code fix

**There is no defect to fix.** The adjoint is exact; the schedule is coarse for
this particular functional; the functional is ill-conditioned at this fixture.
A speculative change here would be a change to something that is already right.

What to do instead, in order:

1. **Report the conditioning beside the gradient.** `stand_gradient` already
   computes both terms and discards the split. Returning the direct term (or
   `|swept|/|total|`) alongside would make an ill-conditioned column visible at
   the call site, at no computational cost — the number is already in
   `both.trait` (`scm.h:1155`). This is the one change worth proposing, and it
   is a *reporting* change, not a numerical one. It also gives a cheap a
   posteriori indicator for consult question 4.5(a): a column whose
   `|swept|/|total|` is 100 needs two more refinements than one whose ratio is 1.
2. **Correct the reading in `diag-gradient-error.md` and in
   `docs/oracle-consultation-mixed-record.md` (E7).** "One functional/parameter
   pair carries the wrong sign" is true but reads as an accuracy failure of the
   adjoint. It is a conditioning statement about the pair: the converged
   derivative is 1% of its own two terms, at a fixture sitting on its zero
   crossing in patch lifetime. The 30-250% figures for `d/drho` are the same
   story at a smaller condition number.
3. **Do not choose `max_patch_lifetime = 5` for a `rho` sensitivity study.** It
   is the lifetime at which `d(mass_above_ground)/drho` passes through zero. A
   lifetime of 4 or of 6 puts the same measurement at a condition number of 3 or
   2 instead of 63-282, and needs no extra nodes.
4. **Move the traits, or the parameters, but say which.** Per §6, a harness that
   differences through `add_strategies` is not measuring the column the sweep
   reports.

## 10. Scripts

All in this directory, all `Rscript <file> [args]`, all reading
`plant` via `pkgload::load_all` and `odelia` via `library`.

| file | what |
|---|---|
| `ws_common.R` | fixture, node levels (coarsen and bisect), and `adjoint_split()` — the total / direct / swept decomposition |
| `ws_reprex.R` | **the minimal reprex**, ~20 s, self-contained (does not need `ws_common.R`) |
| `ws_repro.R` | the node bisection, 23 -> 1393 (`ws_repro_-2_4.rds`); `ws_show.R` prints it |
| `ws_fd2.R` | **the decisive check**: sweep vs forward tangent vs pinned-grid raw-parameter central difference |
| `ws_arith.R` | the condition-number prediction table of §5 |
| `ws_band.R` | per metric/trait node errors at 88 nodes, against 1393 |
| `ws_rho.R` | the lifetime (or `rho`) scan of §5 |
| `ws_hyper.R` | the trait-vs-parameter difference of §6 |
| `ws_short.R` | short-lifetime probe, used to find where the crossing is |
| `ws_fd.R`, `ws_fdshow.R` | the first, confounded FD attempt — kept because its failure is what found §6 |

Wall times on this box: one 88-node run 3.8 s, its sweep 15.7 s; 175 nodes 41 s;
349 nodes 98 s; 697 nodes 245 s; 1393 nodes 694 s.
