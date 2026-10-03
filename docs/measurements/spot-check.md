# The step-3 spot-check

The floor of the design's step 3 (`docs/assessment.md`) on four records unlike
long drought, each with its two companions, and long drought with two
tolerance nudges. Cash–Karp under the tied tolerance at `tol = 3e-5`, 108
uniform nodes, each record's knots as step targets, one species at `lma = 0.32`,
lifetime 40, birth-date density.

`harness/run_record.R` on `PLANT-98` (plant 2.0.0.9002, odelia 0.5.0, the
`lib_guard` library), checked by `harness/spot_check.R` against `eps.csv`.
Every run's output and log is in `spot-check/`, listed in `jobs.tsv`.
`RUNS=docs/measurements/spot-check OUT=docs/measurements/spot-check Rscript
harness/spot_check.R` writes the tables below from them: `runs.csv`,
`checks.csv`, and every quantity's move in `moves.csv`. The first fifteen runs
took 37 minutes on four cores.

## The runs

| record | `J` | steps | base run (s) | peak memory (MB) |
|---|---|---|---|---|
| constant | 1.204 | 3 638 | 160 | 245 |
| dry | 1.190 | 9 134 | 501 | 458 |
| episodic | 1.979 | 11 026 | 545 | 485 |
| long drought | 12.669 | 17 684 | 923 | 704 |
| wet | 18.40 | 21 922 | 1 140 | 823 |

On every run no phase raised and no attempt was refused, the invader at
θ′ = θ reproduces `J` exactly, and the census reproduces `J` exactly.

## The tolerance check

The companion at `tol` ×1.05 passes where every quantity moves by less than
ε/6.

| record | resident | invader |
|---|---|---|
| constant | passes (largest 2e-4 ε) | fails on 43 of 49 |
| dry | fails on 21 of 49: `omega` 0.65ε, `a_l1` 0.55ε | passes (0.06ε) |
| episodic | passes (`a_dG1` 0.14ε) | passes (0.04ε) |
| long drought | `a_dG1` 0.24ε at ×1.05, 0.06ε at ×0.95 | passes (0.06ε) |
| wet | `a_dG1` 0.23ε | passes (0.02ε) |

- On long drought, over the three runs at `3e-5` ×0.95, ×1 and ×1.05, the
  resident's largest move is 0.72 of ε/3 (`a_dG1`) and its median 0.19; the
  invader's largest is 0.17. So `3e-5` passes the first test there on three
  samples, while one companion's ε/6 refines it.
- `ln J` moves by at most 1e-3 ε on every record.

## The node check

The companion on 54 nodes passes where every quantity moves by less than ε. It
fails on every record:

| record | `ln J` | resident over ε | invader over ε |
|---|---|---|---|
| constant | 290ε (`J` falls to 8e-4) | 47 of 49 | 46 of 49 |
| dry | 1.8ε | 43 of 49 | 31 of 49 |
| episodic | 1.0ε | 15 of 49 | 8 of 49 |
| wet | 0.57ε | 6 of 49 | 40 of 49 |

The resident's `a_st3` moves most on dry, episodic and wet (37–94ε). Step 1
found its 108-node error larger than its spread on long drought. On 54 nodes the
spacing is 0.75 time units, longer than long drought's spans between gaps in
creation (about 0.6), so the move need not follow the square law; the check's
next rung, 215 nodes, decides.

## The constant record's invader

On uniform nodes, which never resolve this record's founders: the last section
has why, and the resolved numbers.

- `J′` at `lma`·e^{−0.001}, ×1 and e^{+0.001} on one recording is 1424, 1.204
  and 0.0028. The finite-difference elasticity over ±0.001 is −6568, and the
  sweep's −1.4e17.
- The sweep gives −1.433e17 again at `3.15e-5`, with monthly zero pulses added,
  under plant's default absolute tolerance, and on the build before
  `PLANT-98`.
- So on uniform nodes the constant record's `J′` is nearly singular in the
  invader's traits at θ′ = θ, and neither number answers. The resident's `lma`
  elasticity there is −18.4, against −7.1 resolved.

## The 215-node rung and dry at `1e-5`

Seven more runs: each record on 215 nodes at `3e-5`, and dry at `1e-5` and
`1.05e-5` on 108 nodes. The 108-node error is estimated as 4/3 of the move to
215 nodes, if the error falls as the spacing squared.

| record | role | main traits' largest | over ε | over ε/3 |
|---|---|---|---|---|
| long drought | resident | `lma` 0.42ε | 2 of 49 | 19 |
| long drought | invader | `lma` 0.65ε | 3 | 22 |
| episodic | resident | `lma` 0.18ε | 3 | 7 |
| episodic | invader | `ln J` 0.18ε | 4 | 7 |
| wet | resident | `a_dG2` 0.40ε | 1 | 7 |
| wet | invader | `lma` 1.19ε | 12 | 31 |
| dry | resident | `a_dG2` 0.94ε | 6 | 41 |
| dry | invader | `stem_P50` 0.64ε | 2 | 39 |

The main traits are `ln J` and the traits step 1 takes curvatures in: `lma`,
`a_dG2`, `hmat`, `stem_P50` and `rho`. Over ε, the rest are the small
elasticities step 1 flagged: `a_st3` (14–71ε for the resident), `a_d0`, `omega`
and `a_l1`.

- Their 108-node errors are small in absolute terms: the largest is 0.012 (the
  resident's `rooting_depth_max` on dry), and `a_st3`'s 71ε on episodic is
  0.004.
- With an elasticity's ε at least 0.01, the 108-node error exceeds ε on three
  quantities outside wet and the constant record, by at most 1.6× (the
  invader's `a_l1` on long drought), and on nine of wet's invader's.

- The 54- and 215-node estimates disagree. On dry `J` falls 4.6% from 54 nodes
  to 108 and rises 0.7% from 108 to 215, so 54 nodes is off the square law.
- On the constant record `J` is 0.0008, 1.204 and 200.7 on 54, 108 and 215
  uniform nodes, none of which resolves its founders (the last section). The
  invader's `lma` elasticity is −749 on 215.
- Dry's tolerance check at `1e-5` leaves one quantity just over the limit, the
  resident's `TF24_cost_scale` at 0.178ε against ε/6. Its largest move falls
  from 0.65ε (`omega`) at `3e-5` to 0.18ε, and its main traits' from 0.23ε to
  0.09ε.

So on wet and dry the check points to `1e-5` on 215 nodes, which has not been
run. On 215 nodes the main traits' node error would be a quarter of 108's, under
ε/3 on every record; `1e-5` passes the tolerance check on dry and was not run on
wet. On long drought and episodic, 108 nodes keeps the main traits within ε,
but not the small elasticities, which 215 nodes does not bring within their ε
either. 215 nodes costs 1.97–2.13× the 108-node run on the four records, and
`1e-5` costs 1.21× `3e-5` on dry, so `1e-5` on 215 nodes would cost about 2.5×
the spot-check's setting.

## How each error scales, and where the node error lives

`harness/error_structure.R`, from the runs here and long drought's two sets of
seven nudges at `1e-4` and `1e-5` (seed 31, 108 nodes, `PLANT-98`, in
`../nudges/`). No new runs.

**The tolerance axis is cheap to brute-force.**
- On long drought the steps go as tol^−0.15: 14 839 at `1e-4`, 21 107 at
  `1e-5`.
- The resident's spread over seven nudges falls as tol^0.6 for the main traits
  and tol^0.8 for the rest (medians). Its largest is 0.146ε at `1e-4` and
  0.012ε at `1e-5` for the main traits, and 0.225ε and 0.025ε for the rest. On
  dry one nudge at each tolerance gives tol^0.69.
- The invader's spread is at most 0.07ε at `1e-4` and does not fall with tol.
- The mean move from `1e-4` to `1e-5`, the axis's bias, is 0.03ε for the
  resident's main traits, at most 0.07ε. On dry the move from `3e-5` to `1e-5`
  is 0.36 of the nudge at `3e-5` (median): the error there is the nudges'
  spread, not a bias.
- So halving the spread costs about 1.15× the steps. A rule on this axis can
  save at most the steps between a passing tolerance and a looser one where the
  bias binds: 1.42× from `1e-5` to `1e-4` on long drought, where the bias is
  still 0.03ε, and about 2× to `1e-3` if the steps keep to tol^−0.15 and the
  bias, unmeasured there, allows it.

**The node axis carries the error.** At `3e-5` the move from 108 to 215 nodes
is 14, 15, 4.2 and 46 times the tolerance nudge's (median over quantities) on
long drought, dry, episodic and wet.

**It is not on a power law.** Where the move is resolved,
`(Q54 − Q108)/(Q108 − Q215)`, about 4 on the square law, has median 2.2 on dry,
−2.5 on episodic and 8.4 on wet. It is negative, a change of direction, on 16 of
81, 33 of 57 and 16 of 65 quantities.

**The node error lives in the first three units of birth date,** as two parts
that nearly cancel. `J` is the sum over nodes of establishment weight times net
reproduction ratio times the density of patches of the node's age at its birth.
The field part of the move from 108 to 215 nodes is the change in net
reproduction at 108's birth dates, on 108's weights; the quadrature part is the
rest.

| record | net | field part | of it before 3 | quadrature part | of it before 3 |
|---|---|---|---|---|---|
| long drought | +0.44% | +1.97% | 96% | −1.53% | 97% |
| dry | +0.71% | +2.78% | 92% | −2.08% | 98% |
| episodic | +0.35% | +0.96% | 105% | −0.61% | 105% |
| wet | +0.33% | +2.04% | 97% | −1.71% | 99% |

- Births after 3 carry −3% to 27% of the net, dry the most.
- The table first left out the patch density, as the grid consultation's copy
  does; each part moved by at most 0.04% of `J`.
- The first node alone carries 29%, 27%, 14% and 32% of `J` on 108 nodes, and
  its net reproduction ratio rises 1.6–11% at each doubling: on wet 1290, 1430 and
  1470 on 54, 108 and 215 nodes.
- The nodes born before 3 are 9 of 108 and cost 16% of the member evaluations.
  A node's evaluations go as the steps after its birth, so an early node costs
  1.95× the mean.

**On the constant record the first node is all of `J`.** Its net reproduction
ratio is 0.098, 297 and 9.9e4 on 54, 108 and 215 nodes; the second node's is
9e-8 on 108. Uniform nodes lump the record's founders into it, as the next
section shows.

## The constant record, resolved

Its `J` and its invader's gradient on uniform nodes are artefacts of the
schedule, not of plant. `harness/first_panel.R` reproduces the numbers below;
the trajectories are from the same runs with `run_scm(..., collect = TRUE)`.

- *Under constant rainfall the canopy closes and stays closed.* Nothing thins
  the stand: the first node's mortality integral is 0.47 by year 40, against
  12 on wet. On wet, light at 2 m recovers from 0.29 in year 6 to 0.65 in year
  10; on the constant record it is 0.18 by year 10 and 0.11–0.12 after.
- *So only the founders survive.* Every cohort born after about day 24 stalls
  under them, empties its storage and dies. On 108 uniform nodes the second
  node, born at 0.37, stops at 8.4 m in year 6, and its mortality integral is
  178 by year 40. With the first spacing split 128 ways, the cohorts born by
  0.0637 reach 17.7–18.0 m with mortality 0.42, and the one born at 0.0666
  stalls at 15.4 m and dies.
- *Uniform nodes put all the founders into the first node,* whose weight is
  half a spacing: 0.37, 0.19 and 0.09 years of recruits on 54, 108 and 215
  nodes, against the founders' 0.064. The lumped node shades itself and levels
  off at 13.7, 16.3 and 17.7 m, against 18.0 resolved.
- *Those heights straddle `hmat`, 16.6 m,* where the share of production put
  into seed, `1/(1 + exp(50 (1 − h/hmat)))`, is 1.6e-4, 0.30 and 0.97. So `J`
  is 0.0008, 1.2 and 200.7.
- *Resolved, `J` converges:* 287.9, 291.5 and 289.4 with the first spacing
  split 8, 32 and 128 ways (115, 139 and 235 nodes), and 288.2 on plant's
  default schedule, which puts 57 of its 108 nodes before day 24. The
  resident's `lma` elasticity is −7.4 and −7.1 at 8 and 32 ways.
- *The invader's singularity goes with it.* At 8 and 32 ways, `J′` at
  `lma`·e^{∓0.001} gives an elasticity of −194 both times, and the sweep −173
  and −155, against −6568 and −1.4e17 on 108 uniform. A kink at θ′ = θ remains:
  the one-sided differences at 32 ways are −172 and −215, and the swept value
  lies outside them.
- *Later, those splits turned out not to resolve the founders' front.*
  `creation-grid.md` grades the first window and puts nodes every 1/16 day around
  the front. There `J` converges at 289.274, the resident's `lma` elasticity at
  −6.94 and the invader's at −186.2. The kink is the curvature of a smooth `J′`,
  sampled by a panel across the front.
- *On the other records the first spacing barely matters.* Split 8 ways, it
  moves `J` by −0.05%, −0.60% and −0.04% on long drought, dry and wet, against
  +0.44%, +0.71% and +0.33% from 108 to 215 nodes. Plant's default schedule
  moves wet's by +1.4%.
- *The resident's structure holds under its own traits.* On the 32-way split,
  residents at `lma`·e^{u} for u from −0.02 to +0.02 keep the same six founders,
  and `J` runs smoothly from 333.9 to 251.6, a local elasticity of −6.6 to −7.5.
- *The invader's moves.* On the same recording, the births that carry 90% of the
  invader's `J′` end at 2.2, 0.74, 0.12 and 0.012 years at `lma` ×0.5, ×0.9,
  ×0.99 and ×1.01.
- *And its landscape is a cliff at θ′ = θ.* `J′` is 115 451, 11 184, 911,
  291.5, 0.0026 and 6e-13 at ×0.5, ×0.9, ×0.99, ×1, ×1.01 and ×1.1. An invader a
  little better than the resident takes the canopy from its founders; one 1%
  worse is shaded out. That is the model's, not the grid's.
