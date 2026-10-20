On the birth-date coordinate the light at a height sums the crowns of
every cohort taller than it, and a crown adds exactly zero below its own
top. The build therefore sums the cohorts tallest first and reads each
of the 65 knots from one running total. Tallest first is the node
list's order until a younger cohort grows past an older one, which
TF24's reserve-gated growth allows. From then on the build evaluated
every crown at every knot, at every stage, for the rest of the run.

When the height scan finds the list out of order, the birth-date build
now sorts the nodes by height (`ascending_by_abscissa()`, the order the
height coordinate already uses) and keeps the running total. Each
crown's term is unchanged; only the order of the sum changes, so a run
whose crowns never cross is bit-identical, and one where they do moves
by rounding. The height coordinate still evaluates every crown when
crowns cross, since its trapezium's grid is the node order itself.

Closes #107
