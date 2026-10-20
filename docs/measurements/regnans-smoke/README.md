# The regnans workflow on TF24 with adjoints: a smoke test

`regnans_smoke.R` runs one evolutionary step on plant `PLANT-95` (#116, odelia
0.9.0), with every derivative from a sweep (plant#650 E1–E3). The fixture is
`test-tf24-fitness-gradient.R`'s: six years, hmat 6, constant rain, twelve
introductions. `smoke.log` is its output.

1. **Equilibrium.** Newton in ln b on ln J − ln b, its slope from the
   birth-rate column: b* = 21.4937 in 7 runs from b = 10.
2. **Cache.** The equilibrium run. An invader at the resident's traits has
   ln R′ = −2.4e-9, the equilibrium's own residual.
3. **Hill climb.** The selection gradient d ln R′/d ln lma is −79.46 by the
   sweep and −78.83 by a central difference of invasions (h = 1e-5).
   A line search of three trial invaders, run together against the cache,
   finds lma × 0.99 at ln R′ = +0.65.
4. **Invasion.** The invader alone reaches b* = 22.0563 in 5 runs, warm
   started; the old resident invading it has ln R′ = −0.31, so the invader
   replaces it.
5. **Next cache.** The new resident's own invader has ln R′ = 1.2e-10 and
   gradient −61.06.

Cost: 12 recorded runs, 15 sweeps, 8 invasions, 19.6 s.

## Found

- **Selection is along the trade-off.** `TF24_hyperpar` moves `r_l` and `k_l`
  with `lma`, so d ln R′/d ln lma is the sweep's three columns chained through
  the hyperparameterisation's Jacobian. The `1.lma` column alone is the
  partial: −122.5 against the total's −79.5, 54 % off at every trait value and
  birth rate tried. `nmass_l` also moves with `lma`, but no equation reads it,
  and the sweep refuses its column.
- **Two near-identical species make the community's Newton ill-posed.** Only
  their total density is well determined, so the 2 × 2 Jacobian is nearly
  singular: an undamped step sent the invader's birth rate to 1e74, and a
  damped one let the old resident decay 12 % a run for 20 runs. Mutual
  invasibility settles it in one equilibrium and one invasion: the invader
  alone, then the old resident as its invader.
- **`run_mutant()` is destructive.** After the back-invasion the SCM's ratios
  are the old resident's; read the community's fitness from its equilibrium
  (J/b).
- **The fixture's landscape is steep.** A 1 % change in lma moves ln R′ by
  0.65, because cohorts here reach maturity just before the patch ends.
  Long drought (b* = 4.659, `measurements/equilibrium.md`) is the realistic
  next case.
