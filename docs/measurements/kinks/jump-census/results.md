# Census of rate jumps on accepted stages: results

Against `prereg.md`, whose predictions are unchanged. Every number below is
**measured** unless it is labelled *bound* (arithmetic on measured counts) or *not
measured*.

## How it was run

- **Bank:** the ten cases `schedtest/adjmap/runs/val_ins75_c_*.rds`. Each links to
  `val_insk_c_*.rds`.
- **Library:** `adjmap/libS`, the library each case's `setting$env["LIB"]` names. Its
  plant is the rebased `PLANT-110` on `ODELIA-55`, built 2026-10-14 05:09 UTC, which is
  `localised.md`'s E5/E6 build ("on libS without rain stops at 1e-4").
- **Runner:** the cases carry `KNOTS = 0`, so they were run by `adj_run_nk.R`, not
  `adj_run.R`. `census.R` sets each case's saved env (`TRAIT_REL` included) and
  `PIN = <case>`, with `MODE = plain`, `FORWARD = 1` and the case's saved `node_times`. It
  then sources `adj_run_nk.R` and reads the tallies off the replayed `scm`.
- **Scripts:** `census.R <case>` writes one rds per case, and `summarise.R <dir>` makes
  the tables. Outputs and logs are in
  `scratchpad/deep/jump-census/` (`census_<case>.rds`, `<case>.log`, `summary.txt`).
  Two R processes ran at a time, taking 25–93 s each.
- **Counting:** every replay reports `ode_step_attempts` all zero, so it made no rejected
  attempts. The tallies therefore count only the evaluations of the accepted rows. These
  are 6.9–7.5 leaf solves per node-step (`solves / stand$rows`): the six RKCK stages, plus
  the end-of-step and split evaluations the replay walks.

## J check

All ten replays give the saved J with a relative difference of **0** (bit-identical), and
their `ode_times` are `identical()` to the saved program.

| case | record, seed | trait moved | steps | J (replay = saved) | rel. diff |
|---|---|---|---|---|---|
| dry | dry, 31 | none | 4542 | 1.19606594214158 | 0 |
| dry-flat | dry-flat, 31 | none | 6769 | 2.99483939762955 | 0 |
| dry-p50 | dry, 31 | root_P50 +20% | 4556 | 0.991345112123982 | 0 |
| episodic | episodic, 31 | none | 3493 | 1.98434146795413 | 0 |
| episodic-lma | episodic, 31 | lma +25% | 3331 | 0.0312817366740029 | 0 |
| long-drought | long-drought, 31 | none | 5040 | 12.7430138539015 | 0 |
| ld-102 | long-drought, 102 | none | 4777 | 7.77986502588387 | 0 |
| ld-105 | long-drought, 105 | none | 4611 | 12.4183188158176 | 0 |
| long-wet | long-wet, 31 | none | 5204 | 18.5291762335154 | 0 |
| wet-adG2 | long-wet, 31 | a_dG2 +25% | 5350 | 23.2281597262889 | 0 |

## Operating-point kinds (accepted rows only)

`census_operating_point_counts_tf24`. These kinds were 0 on every case and are left out
of the table: unsolved, boundary-soil, shade-death, prescribed, solver-refused and
non-finite-gradient.

| case | leaf solves | interior | boundary-crit | boundary-root-crit | **determined** | **hydraulic-shutdown** |
|---|---|---|---|---|---|---|
| dry | 2 780 544 | 2 174 367 | 606 177 | 0 | **0** | **0** |
| dry-flat | 5 964 381 | 4 922 890 | 1 041 491 | 0 | **0** | **0** |
| dry-p50 | 2 861 331 | 2 183 189 | 678 142 | 0 | **0** | **0** |
| episodic | 1 974 615 | 1 609 187 | 365 417 | 0 | **0** | **11** |
| episodic-lma | 1 600 955 | 1 379 616 | 221 314 | 6 | **0** | **19** |
| long-drought | 3 170 861 | 2 714 249 | 456 602 | 0 | **0** | **10** |
| ld-102 | 2 831 605 | 2 371 554 | 460 027 | 0 | **4** | **20** |
| ld-105 | 2 718 461 | 2 315 564 | 402 425 | 1 | **453** | **18** |
| long-wet | 3 178 995 | 2 740 047 | 438 445 | 2 | **489** | **12** |
| wet-adG2 | 3 364 125 | 2 894 257 | 469 434 | 0 | **424** | **10** |

As a share of leaf solves, Determined is at most 1.67e-4 (ld-105), which is 0.017%.
HydraulicShutdown is at most 1.19e-5 (episodic-lma).

## Clamp counts (accepted rows only)

`census_clamp_counts_tf24`. libS has the clamp census. These sites were 0 on every case:
light_floor, light_floor_crown, soil_moisture_floor (#20), **soil_positivity (#19)**,
soil_conductivity (#22), rainfall (#24), infiltration (#23), root_vuln_argument,
leaf_temperature and collar_potential.

| case | soil_positivity (#19) | soil_potential_ceiling (#21) | root_vuln_integral_cap (#16) | rooting_depth (#5) |
|---|---|---|---|---|
| dry | **0** | 0 | 1 480 | 2 441 517 |
| dry-flat | **0** | 0 | 0 | 5 050 395 |
| dry-p50 | **0** | 0 | 0 | 2 509 922 |
| episodic | **0** | 0 | 8 626 | 1 762 615 |
| episodic-lma | **0** | 0 | 4 456 | 1 361 360 |
| long-drought | **0** | 0 | 1 242 | 2 717 786 |
| ld-102 | **0** | 0 | 11 083 | 2 466 879 |
| ld-105 | **0** | 957 | 8 275 | 2 374 923 |
| long-wet | **0** | 282 | 3 705 | 2 707 845 |
| wet-adG2 | **0** | 176 | 9 849 | 2 842 227 |

The potential ceiling (#21) binds only on the three cases with hundreds of Determined
solves (ld-105, long-wet and wet-adG2). On ld-102 it does not bind, and Determined
appears there only 4 times. This co-occurrence is measured; whether the ceiling causes
the collapsed bracket is *not measured*.

## Steps holding a change into or out of a jump kind

**Not measured.** The replay's recording does not give R each evaluation's solved
values. In libS, `scm$store_trajectory()` returns per row only `time`, `step_size`,
`introduction`, `error_index`, `error_ratio` and `state`. This was checked on a libS run.
The per-evaluation `leaf_solved_point`s (collar and kind) are kept in C++
(`trajectory[i].solved`), but no R accessor reads them. A pinned replay also runs in one
`walk()` call, so the tallies cannot be split at b = 25 either. Nothing was built to
expose them.

*Bound:* a step can hold a change into or out of a jump kind only if one of its solves
is of that kind. So the number of such steps is at most that record's total of
determined, hydraulic-shutdown and boundary-root-crit solves:

| case | bound |
|---|---|
| dry, dry-flat, dry-p50 | 0 |
| long-drought | 10 |
| episodic | 11 |
| ld-102 | 24 |
| episodic-lma | 25 |
| wet-adG2 | 434 |
| ld-105 | 472 |
| long-wet | 503 |

## Predictions scored

| Kind | Prediction | Outcome |
|---|---|---|
| Determined | 0 on dry, dry-flat and wet; > 0 on at least one drought-type record, at < 0.1% of leaf solves | **Wrong.** It is 0 on dry and dry-flat, and > 0 on two long-drought seeds at ≤ 0.017%. But wet is not 0: long-wet has 489 and wet-adG2 has 424. |
| HydraulicShutdown | ≤ 10 solves per record; birth transients only | **Wrong.** Five of ten exceed 10: episodic-lma 19, ld-102 20, ld-105 18, long-wet 12 and episodic 11. The largest is 20. Whether they are birth transients is *not measured*. |
| Positivity guard (#19) | 0 on accepted stages everywhere | **Right.** It is 0 on all ten cases. |
| Steps holding a change into or out of a jump kind | ≤ 50 per record, most after b = 25 | **Not scorable.** The per-step kinds are not exposed. By the bound, ≤ 50 holds on seven of ten and is undecided on ld-105, long-wet and wet-adG2. The b = 25 split is not measured. |

## Does any jump kind occur on accepted stages often enough to matter?

On accepted stages the soil positivity guard never fires, and neither does any other soil
clamp except the K-type potential ceiling. HydraulicShutdown fires 0–20 times per record,
on the order of 1e-5 of solves. Determined is the only jump kind with a three-figure
count. It has 424–489 solves on long-wet, wet-adG2 and ld-105, about 1.5e-4 of solves,
and it travels with the potential ceiling binding. It is 0 or nearly 0 on the dry,
episodic and the other long-drought cases. On the same rows, the K-type Interior ↔
BoundaryCrit switch (#10) has 2.2e5–1.0e6 boundary-crit solves. That switch has already
been measured to cause step-placement jitter. Against it, the jump kinds are three to
five orders rarer.

Even so, the counts alone cannot say whether Determined matters on those three records.
Its bias is Δf·dt/dθ per step that straddles it. The jump is of the size of Determined's
own flux (inventory #13, 14). The number of steps it straddles is bounded only by
≤ 434–503, because the per-step kinds are not exposed. If those solves cluster in a few
steps, the bias is local and small. If many are isolated stage hits inside long steps,
they could add up. The next measurement is the per-step change count, which would need
an R reader for `trajectory[i].solved`, or a gradient comparison on long-wet with stops
placed at the Determined transitions. Until then, Determined on long-wet, wet-adG2 and
ld-105 is the one open candidate. HydraulicShutdown and #19 are too rare on accepted
stages to reach ε.
