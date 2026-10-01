# The step-3 spot-check

The floor of `docs/design-grid-controller.md`'s step 3 on four records unlike
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

- `J′` at `lma`·e^{−0.001}, ×1 and e^{+0.001} on one recording is 1424, 1.204
  and 0.0028. The finite-difference elasticity over ±0.001 is −6568, and the
  sweep's −1.4e17.
- The sweep gives −1.433e17 again at `3.15e-5`, with monthly zero pulses added,
  under plant's default absolute tolerance, and on the build before
  `PLANT-98`.
- So on a constant record `J′` is nearly singular in the invader's traits at
  θ′ = θ, and neither number answers. The resident's gradient is unaffected
  (`lma`'s elasticity −18.4).

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
  nodes, and does not converge. The invader's `lma` elasticity is −749 on 215.
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
