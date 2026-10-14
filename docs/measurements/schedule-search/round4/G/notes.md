# Agent G, round 4: let the data speak

Scope note (lead, mid-task): the reverse sweep's own per-row cost is deferred; do not
propose optimising the sweep itself.

## 1. Index (index.R)
988 saved runs over four directories, 744 with a gradient. Cost: forward CPU =
1.11e-4 s/row + 2.4e-3 s/step (R² 0.99); sweep = 3.56e-4 s/row + 2.6e-3 s/step
(sweep/forward median 3.0, range 2.35–3.79). Rows dominate both: a step costs about
22 rows of overhead in the forward, 7 in the sweep.
