## Why the sum can be reordered

The shade at height z is the sum, over cohorts, of each cohort's
density times its leaf area above z, and a cohort's leaf area above z
is exactly zero once z is at or above its top. So at any height, the
sum runs over the cohorts taller than that height, which are the
first cohorts in a list sorted tallest first. One running total down
that list gives the shade at every height in one pass. The exact
establishment counts from #94 give each cohort its own weight, which
is what lets the cohorts be summed in any order. The height
coordinate weights each cohort together with its neighbour in the
list, so it still sums every crown at every height when crowns cross.

## How often crowns cross

TF24's growth depends on each cohort's reserves, so a cohort can stall
in a dry spell while a younger one keeps growing past it. On the stand
above, the first pair crosses 6.9 years into the run and the pairs
only accumulate, to five by the end. Heights are out of order at 82%
of the times the light is rebuilt, and on the base every one of those
rebuilds summed every crown at every height.

![The number of cohorts out of height order at each rebuild of the light through the run](FIG:plant-114/share.png)

## What it saves

The forward run was timed five times on each build, alternating
between them. The medians are 223.8 s on the base and 211.5 s on this
branch, 5.5% less. Four of the five pairs differ by 4 to 6%, and the
fifth by 1.4%. As a check on the machine's noise, the same comparison
with 108 cohorts, where nothing crosses and both builds run the same
code, differs by 1.7% between medians.

![Forward CPU on each build, five interleaved pairs, every run shown](FIG:plant-114/forward.png)
