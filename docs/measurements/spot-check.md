# The step-3 spot-check

The floor of `docs/design-grid-controller.md`'s step 3 on four records unlike
long drought, each with its two companions, and long drought with two
tolerance nudges. Cash–Karp under the tied tolerance at `tol = 3e-5`, 108
uniform nodes, each record's knots as step targets, one species at `lma = 0.32`,
lifetime 40, birth-date density.

`harness/run_record.R` on `PLANT-98` (plant 2.0.0.9002, odelia 0.5.0, the
`lib_guard` library), checked by `harness/spot_check.R` against `eps.csv`.
Every run's output and log is in `spot-check/`, listed in `jobs.tsv`;
`checks.csv` and `runs.csv` are the tables below. The fifteen runs took 37
minutes on four cores.

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
