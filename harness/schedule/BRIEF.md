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
