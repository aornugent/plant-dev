# Judge's scarcity derivation (written before reading any candidate or the sealed sentence)

Runtime inside the ~5% of steps that hold crossings is scarce: R8's bar (+6.0% forward,
+7.3% sweep, about 264k node ratings) spread over the 726 crossing steps that hold the 9247
sign-changing node steps buys about 1.2 extra rows per crossing step, or about 28 node ratings
per crossing node step (one extra row there is +4.9%, a wasted attempt plus two halves +9.8%),
which is 7x under tightening tol to 1e-5 (+41%) and 30-40x under step ends at every crossing
(x2.9-3.3); within it a treatment must take the curvature spread at r = 1e-2 from plain's 0.56
to under 0.33 eps (R2, the binding line once R1's floor correction leaves plain 5% over, on
a_dG1 alone), and lines of code (R9; the incumbent spends ~1700) are the second, competing budget.

Working:
- node rating 65 s / 4.4e6 = 14.8 us; 296 node ratings per accepted step (row 4.4 ms).
- 9247 / 726 = 12.7 crossing nodes per crossing step, so one extra row costs 296 / 12.7 = 23
  node ratings per crossing node step, the same order as the incumbent's per-node split (26).
  Crossings cluster, so per-step and per-node treatments price alike; what the bar cannot pay
  for is more than about one extra row per crossing step.
- R2 needs a 40% cut in the curvature spread at r = 1e-2 (0.56 -> 0.333 eps); R1 needs 5% on
  a_dG1. The kink is 78-88% of plain's nudge moves (incumbent/plain ratios).
- Open in the scoring: per pass (forward 6.0, sweep 7.3) versus per seven-pass gradient run,
  where the incumbent's unsplit invader passes cost it nothing extra (its run overhead is
  (0.06 + 2.6 x 0.073)/7 = 3.6%) while a design that adds rows pays them on all seven passes.
