# How it works

## Why the sum can be reordered

On the birth-date coordinate the light at height z sums w_i n_i a_i(z)
over nodes, and a crown's leaf area above z, a_i(z), is exactly zero
for z at or above its top. So the sum at z is over the nodes taller
than z, which in height order are a prefix, and one running total over
the nodes serves all 65 knots. #94's per-node weights are what make
each term independent of its neighbours; the height coordinate's
trapezium still needs list order and keeps the fallback.

## How often crowns cross

TF24's growth is gated by its reserves (#517), so a cohort can stall
while a younger one passes it. On the stand above the first pair
crosses at t = 6.9 yr and the pairs only accumulate, to five by the
end: 82% of the run's 3358 stops have heights out of order, and on the
base each build there took the fallback. With 108 introductions
(cohorts 135 days apart) no pair crosses, and nothing changes.

![Pairs of cohorts out of height order at each stop of the run](FIG:plant-114/share.png)

## What it saves

Five pairs of forward runs of the stand above, alternating base and
branch, CPU as user + system: medians 223.8 s on the base and 211.5 s on
this branch, 5.5% less. Four pairs differ by 4.0 to 6.0%, the fifth by
1.4%. Both builds take the same 12 016 steps, and J differs by 3.4e-12
relative, the rounding of a reordered sum. As a check on the noise, the
same comparison at 108 introductions, where no crown crosses and both
builds run the same loop, reads 1.7% between medians.

![Forward CPU with and without the sort, five interleaved pairs, every run shown](FIG:plant-114/forward.png)
