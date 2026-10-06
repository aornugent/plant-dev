# The orchestrator's derived scarce resource (sealed: for the judge only)

Runtime is not scarce for a treatment confined to the crossing node. 6% of a
forward spread over 9247 node steps is 0.42 ms each, about 28 node ratings,
against the 12 a full-order re-integration needs.

Runtime is scarce for anything that touches the row. A row is about 290 node
ratings, so a row per sign change is +62% on every pass of a gradient run,
and 2.9x was measured for global stops at every crossing. A row-touching
treatment can afford about 600–900 rows in all.

What is scarce is the number of discrete decisions the treatment makes, and
the number of passes that must repeat them. Each decision must be:
- reproduced bit for bit on replays;
- differentiated exactly on the sweep;
- kept continuous in theta on a frozen mesh (no jump above 1e-8).

That triple expression is where the incumbent's 1700 lines went (R3, R4, R9).
