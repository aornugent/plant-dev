On the birth-date coordinate, the shade at a given height is the sum
of the leaf area of every cohort taller than that height, because a
crown casts no shade below its own top. When the cohorts are listed
tallest first, the light build therefore keeps one running total down
the list and reads the shade at each of the 65 heights where it is
computed from that total. The node list is tallest first until a
younger cohort outgrows an older one, which TF24 allows because
growth depends on each cohort's reserves. From that moment the build
gave up the running total and summed every crown at every height, for
the rest of the run.

When the cohorts are out of height order, the birth-date build now
sorts them by height, using the ordering the height coordinate already
uses for the same purpose (`ascending_by_abscissa()`), and keeps the
running total. Each crown's contribution is unchanged and only the
order of the sum changes, so a run whose crowns never cross gives
bit-identical results, and one where they do changes only by rounding.

Closes #107
