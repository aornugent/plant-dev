# Determined collars and the soil's potential ceiling: results

Against `prereg2.md`, whose predictions are unchanged. Every number below is
**measured** unless it is labelled *derived* (arithmetic on measured counts) or
*inferred* (read from the code, not measured).

## How it was run

- **Source:** the plant libS was built from, `S_src/plant_stack` at `PLANT-110`
  `07f7c256`. The build at 05:05:56 UTC on 14 October was of `208c0a88`. That commit
  differs from `07f7c256` only in `NEWS.md` and a test file. The source was copied to
  `scratchpad/deep/jump-census2/src/plant`, and the diagnostic patch is
  `src/jc2.patch` there. odelia and phylloptim were copied from libS.
- **Patch** (disposable, not committed):
  - each `leaf_solved_point` also keeps the plant's height, a mask of the layers it
    roots in and a mask of the layers at the potential ceiling (ψ ≥ `soil_psi_max_`).
    The second build (`lib2`) also keeps the top layer's ψ;
  - `census_solved_tf24(scm)` reads every recorded evaluation's solves, by row and
    slot. The slots are the five stages, the end state, the end before a split, the
    split's field samples, a split block's substeps, and the sign-change roots. Each
    solve carries its node;
  - `census_unstored_tf24(scm)` tallies the solves that no record keeps, inside and
    outside a sign-change search.
- **Library:** built `-O2` into a new `jump-census2/lib`, then `lib2` with the top
  layer's ψ added. libS and every other library are untouched. `lib` was deleted after
  its runs to save disk. `lib2` is the same build plus one stored field.
- **Reproduction:** every pinned forward replay gives the saved J with a relative
  difference of **0**. That is long-wet 18.5291762335154, wet-adG2 23.2281597262889 and
  ld-105 12.4183188158176, on both builds. The times are `identical()` to the pin, and
  the replays make 0 step attempts. The census counts equal `results.md`'s exactly. The
  pinned gradient replay's 50 elasticities are `identical()` to the saved ones.
- **Scripts (beside this note):**
  - `d1.R <case> [pin] [tag]` is the pinned forward replay plus the solved record;
  - `d1_lib.R` places each solve at its fraction u of the step and in its (sub)step;
  - `summarise2.R` and `d1_table.R` make D1's tables;
  - `mkends.R` adds the step ends;
  - `d2_run.R` runs one pinned long-wet run (forward or gradient);
  - `d2_score.R` makes D2's table. ε is `round4/JT/nudge.R`'s `eps_vec`: the
    resident ε of `eps.csv`, floored at 0.01.
- **Outputs:** in `scratchpad/deep/jump-census2/`: `d1_*.rds`/`.log`, `summary2.txt`,
  `d1_table.txt`, `d2_*.rds`/`.log`, `d2_score.txt` and `pin_ends_long-wet.rds`. No
  trajectory was kept.

## What a record holds, and what it does not

- The recorded evaluations hold 359 of long-wet's 489 Determined solves, 360 of
  wet-adG2's 424 and 350 of ld-105's 453.
- No Determined solve falls outside a record or among the unstored solves
  (`census_unstored_tf24` counts 0).
- The remainder (130, 64 and 103, *derived*) are the regula-falsi iterates of the
  sign-change search. Each iterate is evaluated into `&change.solved`, and the next
  iterate overwrites it, so only the root is kept (*inferred*, `taken_step::sign_changes`).
- These iterates place the split. They are not stages of any integration.
- Long-wet's 282 ceiling reads split the same way: 152 recorded evaluations and 130 in
  the overwritten iterates (*derived*).

## D1: where and how bunched

**Every recorded Determined solve is in a split block's substep evaluation (slot 8). No
stage, end state, sample or sign-change root of any step holds one.**

| | long-wet | wet-adG2 | ld-105 |
|---|---|---|---|
| steps holding Determined | **1** | **1** | **1** |
| the step: t, h | 38.79196–38.81692, 9.11 d | 38.79418–38.81460, 7.46 d | 35.66124–35.67714, 5.80 d |
| Determined solves in it (recorded / census) | 359 / 489 | 360 / 424 | 350 / 453 |
| nodes (of those alive) | 130 of 156: nodes 0–129 | 127 of 158: 0–126 | 122 of 146: 0–121 |
| their births b; ages | 0–22.04; 6125–14168 d | 0–21.14; 6453–14167 d | 0–21.91; 5027–13022 d |
| Determined evaluations per node | 1–3 of 12 | 1–3 of 12 | 1–3 of 12 |
| where in the step (u) | 0.052, 0.078, 0.157 | 0.053, 0.079, 0.159 | 0.053, 0.079, 0.158 |
| before / after b = 25 (by birth) | 130 / 0 | 127 / 0 | 122 / 0 |
| before / after t = 25 (by step time) | 0 / 1 step | 0 / 1 | 0 / 1 |
| jump inside the step | yes, in every node: inside the first split substep | same | same |

- **Inside each step:**
  - nearly every node splits on its net production's sign change, at u 0.250–0.266:
    152 of 156 nodes on long-wet, 155 of 158 on wet-adG2 and 145 of 146 on ld-105;
  - its first substep, [0, ≈0.26] of the step (1.5–2.4 d), goes Interior (u = 0)
    → Determined (u 0.05–0.16) → BoundaryCrit (0.23) → Interior (0.26);
  - no node is Determined throughout: 130, 127 and 122 (step, node) pairs, and every
    one changes kind inside one substep;
  - the younger nodes (b > 21–22) split too, but never reach Determined;
  - by substep evaluation on long-wet, Determined is met at u ≈ 0.052 by 106 nodes, at
    0.078 by all 130, and at 0.157 by 123. wet-adG2 is 113/127/120 and ld-105 is
    111/122/117.
- **What the split's field reads (`lib2`, top-layer ψ at each solve):**

  | | long-wet | wet-adG2 | ld-105 |
  |---|---|---|---|
  | ψ_top at the Determined solves, MPa | 186–1000 (median 498) | 279–1000 (627) | 648–1000 (1000) |
  | ψ_top at the main stages, u = 0 / 0.2 / 0.3 / 0.6 / 1 | 1.72 / 2.00 / 2.16 / 0.0064 / 0.016 | 2.21 / 2.49 / 2.36 / 0.0072 / 0.013 | 2.29 / 2.58 / 2.65 / 0.0049 / 0.016 |

  - The step holds a rain arrival between u = 0.3 and 0.6: ψ_top falls from about 2
    to about 0.006 MPa. The sign changes sit just before it.
  - The split block's substeps read the soil from the field sampled at u = 0, 0.25,
    0.5, 0.75 and 1 and interpolated between those samples (*inferred*:
    `Patch::split_node`, `sample_at`).
  - At u 0.05–0.16 that field puts the top layer 100–500 times drier than the stages
    on either side (u = 0 and u = 0.2), up to the ceiling.
  - The interpolant overshoots below the dry samples ahead of the rain's jump
    (*inferred* from the measured ψ). So the Determined collars are not a drought the
    stages meet. They come from the split field's interpolation across a rain arrival
    inside a step.
- **HydraulicShutdown:**
  - long-wet: 9 recorded of 12. 3 are on the newest node (node 155, b 38.30, age
    125 d) in one 3.12-d split step at t 38.64, u 0.035–0.105, ψ_top 7.9–9.5 MPa. 6 are
    on the boundary node, in the split substeps of the newest node's block, at t 35.82,
    38.64 and 39.56;
  - wet-adG2: 10 of 10. 3 are on the newest node (age 164 d) at t 38.64, and 7 on the
    boundary node;
  - ld-105: 14 of 18. 3 are on the newest node (age 247 d) at t 34.84, ψ_top
    7.6–10.3 MPa. 11 are on the boundary node, at t 34.84, 37.73 and 37.93, with ψ_top
    up to 1000 at the last two;
  - on the introduced nodes it is one node per record, the newest, in one step. It
    changes kind inside its first split substep, and it is after b = 25. These are birth
    transients of the newest cohort, met in a split field. The boundary node's solves
    were not followed through their steps.
- **BoundaryRootCrit:** 2 on long-wet, both on the boundary node (t 35.82 and 39.56,
  ψ_top 5.7 and 5.6 MPa). None is recorded on wet-adG2. ld-105's single one is in the
  overwritten iterates (*derived*). None is on an introduced node.
- **The ceiling:**

  | | long-wet | wet-adG2 | ld-105 |
  |---|---|---|---|
  | evaluations with a layer at the ceiling | 152 (census reads 282) | 155 (176) | 808 (957) |
  | layer | 1 (top) only | 1 only | 1 only |
  | rows (t) | the Determined step only (38.8169) | the Determined step only (38.8146) | the Determined step (35.6771) 290; 37.7285 84; 37.9298 434 |
  | slot | split substeps only | same | same |
  | those holding a Determined solve | 130 of 152 | 127 of 155 | 239 of 808 |
  | Determined solves whose evaluation has a rooted layer at the ceiling | 130 of 359 (36.2%) | 127 of 360 (35.3%) | 239 of 350 (68.3%) |

  - Every Determined node roots in all five layers (mask 31), so "a layer it roots in"
    means "the top layer".
  - The evaluation at u ≈ 0.079 is at the ceiling for 149 of the 152 split nodes on
    long-wet, 154 of 155 on wet-adG2 and 143 of 145 on ld-105. On ld-105 the one at
    u ≈ 0.158 is too (143). The Determined evaluations either side read 186–650 MPa:
    below the ceiling and still Determined.
  - ld-105's two other ceiling rows are the boundary node's HydraulicShutdown rows.
  - The ceiling never binds in a main-stage evaluation.

## D2: how much it moves the gradient (long-wet)

- **AD:** the pinned gradient replay on the patched library. Its 50 elasticities are
  `identical()` to the saved run's.
- **Central differences:** (ln J(θ(1+δ)) − ln J(θ(1−δ))) / 2δ on the saved step program
  (`TRAIT_REL` with `PIN`). Every run's times are identical to the pin, and it makes 0
  attempts.
- **Added ends:**
  - `mkends.R` adds ends at the first and last Determined transition of the one step
    that holds one: u = 0.026 and 0.193 of row 5321. That gives 5204 → 5206 steps,
    whose pieces are 0.24, 1.52 and 7.35 d;
  - the step was substepped, so each piece keeps its input slope. Its substep ends are
    the parent's that fall inside it, plus every stage and sample fraction;
  - on that grid Determined goes to **0** (census and record), and the ceiling binds in
    no recorded evaluation. HydraulicShutdown (9) and BoundaryRootCrit (2) are
    unchanged;
  - J moves by 6.4e-7 relative, which is 2.6e-5 ε in ln J.

| trait | ε | AD (saved = pinned) | CD δ 1e-3 | CD δ 1e-4 | AD−CD, 1e-3 (ε) | AD−CD, 1e-4 (ε) | AD ends − AD plain (ε) | AD−CD on ends grid, 1e-3 (ε) |
|---|---|---|---|---|---|---|---|---|
| lma | 0.0865 | −7.98562 | −7.98579 | −7.98557 | +0.0020 | −0.0005 | +3.8e-5 | +0.0020 |
| TF24_cost_scale | 0.0196 | −2.48981 | −2.48983 | −2.48990 | +0.0012 | +0.0045 | +5.3e-5 | +0.0012 |
| stem_c | 0.0166 | 1.22400 | 1.22399 | 1.22408 | +0.0008 | −0.0045 | −0.9e-5 | +0.0009 |
| a_l1 | 0.0156 | 1.16541 | 1.16545 | 1.16537 | −0.0024 | +0.0025 | +0.7e-5 | −0.0024 |
| root_P50 | 0.0108 | −0.26382 | −0.26380 | −0.26381 | −0.0011 | −0.0002 | +3.6e-5 | −0.0011 |
| a_r1 | 0.0282 | 2.36490 | 2.36488 | 2.36497 | +0.0008 | −0.0022 | −3.9e-5 | +0.0008 |
| R_d_25 | 0.0118 | −1.02369 | −1.02369 | −1.02377 | −0.0004 | +0.0065 | +3.7e-5 | −0.0004 |
| rooting_depth_max | 0.0100 | 0.27386 | 0.27373 | 0.27385 | **+0.0127** | +0.0012 | −0.0e-5 | +0.0127 |

- **|AD − CD|:**
  - at δ = 1e-3 the largest is 0.0127 ε (rooting_depth_max); every other trait is
    ≤ 0.0024 ε;
  - at δ = 1e-4 the largest is 0.0065 ε (R_d_25);
  - rooting_depth_max's 1e-3 difference is the CD's own: its two CDs differ by 0.0115 ε
    and its 1e-4 CD agrees with AD to 0.0012 ε. That is consistent with the rooting
    depth's kink (#5) within ±1e-3 of θ (*inferred*);
  - on the ends grid AD − CD is the same to 4 decimals, so the missing Δf·dt/dθ term is
    below what these differences resolve.
- **AD with added ends − AD plain:**
  - rms 3.3e-5 ε over the eight traits (max 5.3e-5 ε, TF24_cost_scale);
  - rms 2.8e-5 ε over all 47 scored quantities, `nudge.R`'s set;
  - that is everything the step's Determined episode and its stage placement carry.

## Predictions scored

| Prediction | Prob. | Outcome |
|---|---|---|
| D1: Determined solves fall in ≤ 60 steps per record: bunched, a few nodes for a few steps each | 60% | **Right on the count, wrong on the shape.** 1 step per record. But that step holds 122–130 nodes (every node born before b ≈ 22) at 1–3 evaluations each, not a few nodes over a few steps. |
| D1: ≥ 80% of Determined solves are in evaluations where a layer the node roots in sits at the ceiling (the ceiling is the cause) | 55% | **Wrong.** 36.2%, 35.3%, 68.3%. The ceiling binds in the same step, substep and nodes, at the deepest point of the same dip. Determined also appears at 186–650 MPa, below the ceiling. Both come from the split field's interpolated dip, and neither causes the other. |
| D1: most steps holding Determined also hold a change of kind (the jump is inside the step) | 50% | **Right.** 1 of 1 step on each record, and every one of the 122–130 node sequences changes kind inside its first split substep. |
| D2: every \|AD − CD\| ≤ 0.1ε at δ = 1e-3 | 65% | **Right.** Largest 0.0127 ε (rooting_depth_max, CD error); the rest ≤ 0.0024 ε. |
| D2: \|AD with added ends − AD plain\| ≤ 0.05ε rms | 65% | **Right.** rms 3.3e-5 ε (8 traits) and 2.8e-5 ε (47 quantities). |

## Verdict

Neither the Determined collar nor the potential ceiling matters at ε on these records.
- On each of long-wet, wet-adG2 and ld-105, Determined occupies one step late in the run
  (t 35.7 or 38.8). There it touches only split-substep evaluations of the older nodes,
  1–3 each over 1.5–2.4 days.
- AD agrees with central differences to ≤ 0.013 ε at δ = 1e-3 (≤ 0.0065 ε at 1e-4).
  Two step ends that remove every Determined solve and every ceiling hit move ln J by
  2.6e-5 ε and the elasticities by ≤ 5.3e-5 ε.
- Per `prereg2.md`, nothing is built for the collar. The ceiling, binding only inside
  the same dip and on the newest cohort's boundary solves, is no more than a symptom
  here.
- What D1 adds to inventory #13 and #21: on these records both are not physiology. The
  split's soil field is interpolated across a rain arrival inside the step, and it puts
  the top layer 100–500× drier than the stages around it read. That is worth a line in
  the inventory. The same mechanism could matter on a record where many such steps
  fall earlier in the run, and that is not measured here.
