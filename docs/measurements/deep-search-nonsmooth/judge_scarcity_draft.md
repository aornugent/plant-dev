# Judge's scarcity derivation (written before reading sealed_scarcity.md or any proposal)

From the ledger only:
- R1 bar 0.006 rms; today 0.048. R3 budget +14% rows.
- The one measured treatment that meets R1: step ends at the first and last sign change of each
  cluster, 0.0020 rms at +12.8% rows (+11.5% steps). It spends 12.8 of the 14 points of budget.
  Half of it (only steps > 0.5 d) spends 7.1% and misses R1 (0.0081).
- The soil-only split costs no rows (+8.5% evaluations) and reaches 0.010: the soil is cheap to
  cut, the stand is not. The residual 0.010 is the nodes reading the main step's soil.
- 14 728 sign changes in 234 of 4786 steps; one cluster ~0.44 d wide in ~2 d steps; top 30 steps
  hold 90% of the error. So the work is ~2 ends per switching step (~470 ends), not per change.
- R2/R7: one grid serves every theta' in the analysis; the step ends are held in replays, so ends
  placed at theta0's cluster edges do not follow the cluster when theta' moves it.

Scarce resource: whole-stand rows near the switch. The stand switches as one cluster, so about
two row ends per switching step settle R1, but they use 12.8 of R3's 14 points, leaving ~1.2
points for everything else; and because a held row end is fixed at theta0 while the cluster moves
with theta', the same ends must also serve every theta' on the grid (R2/R7), which held ends
cannot do unless the cluster's movement over one analysis stays within the margin they leave.
The cheap resource is the soil (substeps cost evaluations, not rows).
