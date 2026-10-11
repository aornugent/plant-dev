# Breakpoint-aligned ladders across traits and records (registered before the runs)

For each record (episodic, dry, long-wet; nr setting, lib_109) and trait setting
(theta0; lma x1.25; stem_P50 x0.8): a forward run on 54 even introductions; L0 =
those introductions less the ones born while establishment is shut, plus the
run's own creation edges; L1, L2 its nested bisections; each with both roles'
gradients.

Predictions, for every combination:
1. Median ratio of successive moves (L0-L1)/(L1-L2) over the resident and the
   invader elasticities in [3, 5], with at most 15% negative; ln J ratio in [3, 5].
2. (Q_L0 - Q_L1)/3 against Q_L1 - Q_L2: median in [1.0, 1.7] (4/3 exact).
3. L1's error against L1 + (L1 - L2)/3... (self-referenced) under eps for at least
   90% of quantities, recruitment_decay excluded.
A combination that fails 1 or 2 is examined for an unaligned breakpoint (a
neighbour pair whose sign-change counts differ outside any edge).
