# What a scheduling algorithm can rely on

Measured mechanisms, for agents searching scheduling algorithms with `score.R`. The
sources are under `docs/measurements/`.

1. **Elasticities need finer late spacing than ln J.**
   - A late interval over about 110 d is not yet on the square law for elasticities:
     its contribution can change sign between levels.
   - Intervals of 45–80 d were all on the square law.
   - ln J converges even at 140 d, so ln J is a poor proxy for what elasticities need.

   (`root-p50.md`)
2. **Elasticity errors are sums of contributions of both signs** that cancel about
   four-fold: the magnitudes sum to about 1.5ε against a total of 0.35ε.
   - When either point of a pair is too coarse for the square law, (Q_fine − Q_coarse)/3
     can misread: wrong sign, or ratios near 2.
   - Pairs with both points on the square law give honest estimates. With 70 d late
     spacing the certificate read 18 of 18 quantities within ×2 on dry.

   (`root-p50.md`, `central.md`)
3. **A coarsening reads honestly only when its dropped nodes are central.**
   - A drop at fraction l of its panel reads about 3l of the error.
   - Edges beside base nodes make such lopsided panels.

   (`estimate-shortfall.md`)
4. **The founders' window earns 70–90% of J, and fate falls steeply across it.**
   - Cases with a trait moved can need fine founders: lma ×1.25 has its lma error at 5.5ε
     with f = 8, 1.45ε with 16, and 0.49ε with 32.
   - The window converges by the square law (ratio about 4.2).
5. **Late births reach the founders through the soil.** Their errors act on the
   founders' fate 10–20 years after birth, so late spacing drives elasticities such as
   a_l1, a, curv_fact_elec_trans and root_P50. (`root-p50.md`)
6. **The founders' and late regions' errors add**: within 0.02–0.15ε of real runs, and
   0.33ε at dry's coarsest point.
7. **Edges are nodes**, taken from the pilot's establishment record; they keep the
   per-interval estimates honest. Constant rain has a front that needs nodes at about
   1/512 d; it is not in this bank. (`breakpoints.md`)
8. **Binding quantities so far:** a_l1, a, curv_fact_elec_trans, TF24_cost_scale,
   storage_relaxation_offset, vcmax_25, lma (in the lma case) and root_P50.
9. **Cost.**
   - A gradient run costs 4.27 forward runs.
   - Rows are about linear in node count.
   - The late region dominates the node count: l = 35 has about twice the nodes of
     l = 70.
10. **The pilot sees little of the founders.** It has 54 uniform nodes, only five of
    them in the founders' window, and its features did not separate lma ×1.25 from
    plain episodic.

## Learned in generation 1 (four agents, about 90 candidates, then real runs)

11. **Cost is about the check plus three times the answer.** T ≈ C(check) + 3 C(answer):
    the answer is paid once to find it and twice in use. Commit the cheapest point that
    meets ε, and check it with another. Every run carries a large fixed cost, mostly edge
    nodes (68–152 per case), so extra probes rarely pay.
12. **Founders' nodes are nearly free; late spacing sets the cost.** f ≥ 24 holds the lma
    case's founders' error near 0.7ε.
13. **A check's points must both be at l ≤ 70.** Checks against l = 140 misread
    storage_relaxation_offset and root_P50 for elasticities: ratios near 1 or a wrong
    sign, not 4.
14. **Edges are essential.** Without edge nodes, real runs on episodic and dry gave
    estimates 4–30× off and errors over ε.
15. **Schedules that are not nested jitter.** Real runs deviate from the scorer's smooth
    fit by rms 0.04ε, with one quantity in twenty near 0.25ε (root_P50 at l = 59).
    - A check whose two schedules are not nested amplifies this by 1/(1 − s), where s is
      the step's shrink factor in h², s = (h_fine/h_coarse)²: ×3.6 for a 7/6 step.
    - The small diagonal step (22, 70)/(26, 59) failed C3 on real episodic runs:
      root_P50's estimate was −0.59 against an error of +0.36.
    - Nested schedules (f and l related by powers of two, so one's nodes are a subset
      of the other's) share their jitter, and their difference keeps none of it.
    - The scorer models this by default (STRESS = 5 draws). Only "ROBUST: feasible on
      all draws = TRUE" counts.
16. **Stored lattice points are real runs and carry no jitter.** f ∈ {8, 16, 32, 64} at
    l = 70, and l ∈ {140, 70, 35, 17.5} at f = 16, plus their region combinations.
    Every other point is interpolated, and its jitter shrinks as it nears stored levels.

## Learned in generation 2 (four agents, about 55 candidates), rescored under v3

17. **The scorer is v3.** Each run carries its own jitter (rms 0.04ε, measured from real
    non-nested pairs and from ±5% `tol` nudges), and each unstored point adds a smooth
    fit error up to 0.1ε. Estimates are signed: a signed estimate with the wrong sign
    fails C3. C5: no answer is committed with its own estimate over ε. Robust means
    feasible on all 20 draws (`STRESS=20`, the default).
18. **No candidate passes all 20 draws but brute force.** Answering (32, 35) outright
    costs T = 13248. The leaders pass 17–18: `g2_free/c08_pilot_route.R` (T_max 10433)
    and `c10_route_wide.R` (10754). The seed and the nested ladders fail every draw: the
    (16, 140) check gives wrong-sign estimates on long-wet, long drought and lma.
19. **Why the leaders fail: a late pair cannot see the founders' error.** (32, 70)
    against (32, 35) shares f = 32, so its estimate holds only the late part. At f = 32
    the founders' part is up to about 0.25ε (noise-free):

    | case, quantity | 32/70 | 64/70 | 32/35 | 64/35 |
    |---|---|---|---|---|
    | dry, TF24_cost_scale | 0.43 | 0.33 | 0.27 | 0.03 |
    | long-wet, a | −0.41 | −0.25 | −0.29 | −0.13 |

    With jitter it crosses ε/3 unestimated, and C3 fails where only one or two
    quantities are over ε/3. An estimate must cover both regions: by additivity, the
    error is the founders' part plus the late part, each from its own nested pair.

## Learned in generation 3 (three agents, about 110 candidates)

20. **A pair that moves both regions at once sees both errors in one difference**:
    (16, 70)/(32, 35), or a fine answer against a far coarse check such as (8, 140),
    whose h² shrink of about 13 divides misreading and jitter alike.
21. **Robust on 20 draws, below brute force (13248):** `g3_regions/c05_band2.R` at
    10363, `g3_descent/c09_pilot_3way.R` at 11705. Both route on pilot thresholds
    (a late-share band at 0.083; J < 0.5) that separate the training cases by as
    little as 1.2×, so they are fitted to the bank, not derived. `g3_free/c13` (11152)
    passed only through the draws' seeds, and fails once those were made unique.
22. **The scorer now refuses** an answer or estimate that leaves out a quantity, and
    gives every point its own jitter seed. Still open: one fit-error vector per case
    and draw, so unstored points of equal weight cancel it; an all-positive estimate
    is taken as a bound and skips the sign test.
