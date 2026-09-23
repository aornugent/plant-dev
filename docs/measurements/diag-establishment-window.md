# TF24's establishment window, measured: which form, which default, and what it does to the ladder and the gradient

TF24 SCM, one species, `lma = 0.32`, `max_patch_lifetime = 40`,
`node_density_in_birth_date = TRUE`, forcing `long-drought` (14 599 daily control
points in range, three multi-year droughts), `ode_tol_rel = ode_tol_abs = 1e-3`,
aligned — a zero-depth rainfall pulse at each of the 2931 active knots.
`J = sum(scm$offspring_production)`. Unless a row says otherwise, "the window"
is the averaged gate at its default `establishment_window = 0.05` yr.

Two builds. **Base**: `plant` `offspring-adjoint` at `bb1d8a8a`, a built copy in
the scratchpad (`tg/plant-base`). **Window**: branch `establishment-window`
(worktree `plant-adj`, pushed to `origin`). Every window-build measurement run
logged `plant-adj/src/plant.so` at `2026-09-23 13:14:26.561414` before and
after (27 runs); the base copy's library reads `13:35:53.589411566`, its build
time. Reproduction check on the base build: `J = 12.052622159` at 9931 steps,
the fixture's number to every digit.

Wall-clock seconds below were taken with two or three runs sharing four cores;
steps and `J` are unaffected, seconds are comparable only within a table.


## The numbers

| | |
|---|---|
| **Form and default** | Offline (§1), averaging the **gate** beats averaging the **carbon**: filtering the carbon leaves the narrowest opening as sharp as the instantaneous gate at every window (min 10–90% width 0.000 d) and takes 2–3 openings entirely. Averaging the gate at **`tau_g = 0.05` yr** widens the median opening 10–90% from 0.058 to 39.8 d and takes none (reach at least 0.53). |
| **Where it lives** | One ODE state per species, after its nodes, in `Species`; present only for a strategy satisfying `EstablishesOverWindow`, so FF16 and K93 are bit-identical and TF24f inherits it. The boundary node is seeded at it; a patch that starts empty starts it in equilibrium, and the sweep transposes that start (§2). |
| **What the node reads** | In the model, the averaged gate opens over **39.8 d** (10–90%, median; 1–99% 81.6 d) and closes over **17.7 d**, against 0.058 and 1.73 d for the instantaneous gate on the same stand, the offline prediction to 3–4 digits (§3). |
| **The ladder** | The uniform ladder converges, **below the instantaneous floor**: steps −0.529, −0.172, −1.5e-03, **−1.8e-04** (1.4e-05 of `J`) at 215 / 429 / 857 / 1713 nodes, order 3.0 at the end, `J` = 12.5734. The plain (bisected default) ladder does not converge by 857: 12.1172 / 12.1118 / 12.6005 / 12.6532 (§4). |
| **The fixed-grid gradient** | On the instantaneous model's 499-node bracket held fixed across `lma`, **backward −169.659, forward −169.652, `J''` = +6.9**, where the instantaneous model reads −170.593 / −181.360 / −10 768. On the three grids that resolve the averaged model (uniform 857, shifted 857, bracket with band fill 865), `J''` = +884 / +1176 / +1161 with the one-sided pairs 0.88–1.18 apart, the range of the instantaneous edge-following ladder (+575 to +996), and the central differences agree to 0.065: **`dJ/dlma` = −172.52 ± 0.03** (§5). |
| **The adjoint** | The window's column, **3.687605** /yr on the plain 108 grid, against the pinned central difference 3.694496 at `d` = 5e-05 (0.19%, inside the pinned runs' own floor of about 0.8% at that step); the `lma` column chained through the hyperparameterisation, −158.593 against −158.762 (§6). |
| **`J` against 12.417 ± 0.006** | **+0.156 (+1.26%)** at 0.05 on the converged uniform ladder; +0.054 / +0.146 / +0.259 at 0.02 / 0.05 / 0.1 on the band-filled bracket — **the opposite sign to Step 0's −0.47%**, carried by cohorts born before the first dead band: the stand's response, which the offline estimate held fixed. A node schedule built for the instantaneous gate leaves the bands without nodes and reads the averaged model 1.9% low (§7). |
| **Re-baselined** | The whole-run gradient reference, recaptured (1380 shared rows: median move 6.6e-08 of scale; drought, whose 46-step gradient is not converged in the step sequence, moves most), with one row that reads across a census jump declared; the TF24 / TF24f model-version snapshot. No pinned TF24 SCM output moved (§8). |

---

## 1. Step 0, offline: two forms at three windows

On one captured run of the base build (108 nodes, stops at every active knot,
every daily control point and 61 points across each of the reference scan's 112
crossings: `J = 12.078661117` at 26 019 steps), the newborn's carbon `P(t)` was
read at every recorded state (47 558 rows) and filtered two ways, both started
in equilibrium at `t = 0`, with the stand held as captured (no canopy feedback):

- **(a)** filter the carbon, `dG/dt = (P - G)/tau`, gate `g(G)`;
- **(b)** filter the gate, `dE/dt = (g(P) - E)/tau`, gate `E`;

with `g(P) = P^2/(A^2 + P^2)`, `A = 8.793079e-06`. Widths are in days, median
(min) over the 56 openings or 56 closings; an opening's levels are fractions of
the rise from its value at the opening root to its peak in that live stretch.
`dJ` is `int c(b) (G(b) - g(b)) db` with `c = w/g` from the 1375-node bracket
run (`em/run_reloc_A_64.rds`, `J = 12.417292`).

| | open shut to ½ | open 10–90% | open 1–99% | open lag of ½ | close 10–90% | close 1–99% | openings under 1% / 50% / 90% / 99% of plateau | reach min | `dJ` offline |
|---|---|---|---|---|---|---|---|---|---|
| instantaneous | — | 0.058 (0.026) | 0.204 (0.079) | 0 | 1.731 (1.040) | 7.043 (2.110) | 0 / 0 / 0 / 0 | 1.000 | — |
| (a) 0.02 | 0.451 (0.000) | 1.289 (0.000) | 5.040 (0.000) | 5.93 | 2.071 (0.000) | 7.435 (0.000) | 2 / 2 / 3 / 8 | 0.000 | −0.0274 (−0.220%) |
| (b) 0.02 | 5.079 (1.252) | 16.01 (1.971) | 33.28 (2.619) | 4.83 | 15.11 (1.597) | 30.35 (2.097) | 0 / 0 / 7 / 17 | 0.534 | −0.0265 (−0.213%) |
| (a) 0.05 | 1.093 (0.000) | 3.187 (0.000) | 11.55 (0.000) | 10.92 | 2.724 (0.000) | 9.055 (0.000) | 2 / 2 / 5 / 13 | 0.000 | −0.0733 (−0.590%) |
| **(b) 0.05** | **12.64 (1.261)** | **39.78 (1.400)** | **81.61 (1.863)** | **7.66** | **17.72 (1.700)** | **26.05 (2.310)** | **0 / 0 / 15 / 25** | **0.531** | **−0.0587 (−0.472%)** |
| (a) 0.1 | 2.003 (0.000) | 6.132 (0.000) | 21.88 (0.000) | 10.39 | 4.288 (0.000) | 13.33 (0.000) | 3 / 3 / 6 / 12 | 0.000 | −0.1317 (−1.060%) |
| (b) 0.1 | 24.93 (1.284) | 76.88 (0.313) | 141.7 (0.433) | 3.24 | 18.33 (1.672) | 24.83 (2.591) | 0 / 0 / 18 / 26 | 0.504 | −0.0949 (−0.764%) |

Uniform nodes across the median opening 10–90% width, at 108 / 215 / 429 / 857
nodes over `[0, 40]`: (a) 0.05, 0.02 / 0.05 / 0.09 / 0.19; **(b) 0.05, 0.29 /
0.58 / 1.17 / 2.33**; (b) 0.02, 0.12 / 0.23 / 0.47 / 0.94.

**Chosen: (b) at `tau_g = 0.05`.**

- (a) leaves the narrowest opening as sharp as the instantaneous gate at every
  window (min 10–90% width 0.000 d) and takes 2–3 openings entirely (peak under
  1% of the plateau): `g(G)` switches over the same narrow band of `G` that
  `g(P)` does over `P`. Its median 10–90% opening, 3.2 d at 0.05, is 0.19 nodes
  wide at 857.
- (b)'s median widths scale with the window (10–90% opening 16.0 / 39.8 / 76.9
  d), and no opening is taken (reach at least 0.50 at every window). Its minima
  (0.31–1.97 d) are stretches whose band or live interval is short, so the rise
  measured is a small one that ends early.
- 0.05 over 0.02: the median opening 10–90% is 2.5× wider (39.8 against 16.0 d),
  one node across it from 429 uniform nodes rather than from 857+; `dJ` −0.47%
  against −0.21%.
- 0.05 over 0.1: `dJ` −0.47% against −0.76% and 15 against 18 openings under 90%
  of the plateau, for a median opening half as wide (39.8 against 76.9 d).

## 2. What was built, and where the state lives

- **One ODE state per species**, the averaged gate `E` (dimensionless, in
  `[0, 1]`), held by `Species<T,E>` after that species' nodes: a species' block
  is its nodes, then `E`; the environment's block still comes last. `ode_size`,
  `ode_state`, `set_ode_state`, `ode_rates` and `for_each_active` (so the
  sweep's active system carries it) are extended.
- Present only where the strategy satisfies `EstablishesOverWindow<T>`, a
  concept on `establishment_window()`, by `if constexpr`. FF16 and K93 compile
  the old path (`window_size = 0`).
- **The boundary node is seeded at `E`** — mortality `-log E`, density
  `birth_rate * E` — through a four-argument
  `Node::compute_initial_conditions(..., pr_estab)`. The three-argument one is
  the same function seeded at the gate of the instant; the body was split into
  the newborn's own rates and the seating, operation order unchanged.
- **The rate** `dE/dt = (g(P) - E)/establishment_window` is taken where the
  boundary node's rates are, in the rebuilt field the water aggregation reads.
- **The start**: `Patch::reset()` of a patch that starts empty calls
  `start_establishment_windows()` after `compute_environment()`, so `E(0)` is
  the newborn's gate and `dE/dt(0) = 0` exactly. A patch seeded from a state
  (`set_initial_state`) takes `E` from it; `make_initial_state()` writes it.
- **The gradient**: the start reads the traits through the gate, so the first
  recorded state depends on them. `census_trait_gradient` transposes the start at
  row 0 and adds its rows to the traits'; `census_trait_tangent` re-seats the
  window on the active system.
- **The parameter**: `TF24_Pars::establishment_window`, default 0.05 yr, a
  `PLANT_TF24_AD_PARAMETER` column, a `RcppR6_classes.yml` entry (bindings
  regenerated). `prepare_strategy` refuses a window that is not positive and
  finite. `scientific_version` 11 -> 12.

**Why the species.** The gate is a property of a species' newborn — its carbon at
seed size and `A = a_d0 * seed leaf area` are that species' traits — and the
window is that strategy's parameter, so there is one state per species and the
species reads `strategy->establishment_window()`. The boundary node is not ODE
state (it is re-evaluated at every rate evaluation), and the environment is shared
by every species. In the species block the environment's block is untouched, and
every routine that walks the flat state species by species (the sweep's
`visit_active`, `ode_state_valid`, `rebind_from`) needed only the species' own
size.

**TF24f** derives from `TF24_Strategy`, inherits the accessor, satisfies the
concept and carries `E` too: an empty TF24f patch holds one entry per species,
`E(0) = 0.9986995`, the same as TF24's. Its compound version tracks to
`TF24f@v12.1`.

**The stochastic patch** is unchanged: it establishes on the gate at the instant
(`stochastic_patch.h`, `establishment_probability(environment)`).

## 3. The gate the node reads, in the model

Window build, the Step 0 capture repeated (same stops, same 108 nodes): `J =
12.103458616` at 26 017 steps (base 12.078661117 at 26 019). `E` read straight
from each of the 47 556 recorded states; the instantaneous gate on the same stand
from the newborn's carbon, by replaying each recorded state into a patch.

| days, min / median / max | instantaneous gate, this stand | averaged gate `E` | offline (b) 0.05 |
|---|---|---|---|
| open: shut to ½ | 0.010 / 0.023 / 0.149 | 1.262 / **12.643** / 13.179 | 1.261 / 12.641 / 13.171 |
| open: 10–90% | 0.026 / 0.058 / 0.371 | 1.399 / **39.788** / 51.229 | 1.400 / 39.784 / 49.575 |
| open: 1–99% | 0.079 / 0.204 / 0.816 | 1.887 / **81.631** / 104.279 | 1.863 / 81.605 / 104.408 |
| open: lag of ½ behind the instantaneous | 0 | −0.146 / 7.682 / 12.655 | −0.146 / 7.659 / 12.655 |
| close: 10–90% | 1.040 / 1.732 / 87.987 | 1.701 / **17.712** / 40.087 | 1.700 / 17.720 / 40.085 |
| close: 1–99% | 2.110 / 7.055 / 438.467 | 2.321 / **26.026** / 432.637 | 2.310 / 26.045 / 432.621 |
| close: lag of ½ | 0 / 0 / 28.703 | 8.525 / 12.301 / 36.617 | 8.521 / 12.302 / 36.615 |

- 112 instantaneous edges on this stand (56 opening, 56 closing), the count the
  reference scan has.
- Openings under 50% / 90% / 99% of the plateau: **0 / 15 / 25 of 56**, reach min
  0.5337, median 0.9982 (offline 0 / 15 / 25, 0.5309, 0.9982). Dead bands the
  average does not take below 1% of its peak: 50 of 57.
- `E` ranges 8.764e-05 to 0.997931 over the horizon; `max |dE/dt|` = 19.675 /yr
  against the bound `1/window` = 20.
- The opening 10–90% width the node reads is **690× the instantaneous one**
  (39.8 against 0.058 d median) and **the closing one 10×** (17.7 against 1.73
  d). The run reproduces the offline form to 3–4 digits on every median: the
  carbon's zero crossings are the weather's, and the averaged model does not
  move them at this resolution.

## 4. The ladders: `J`

Three families on the window build, each nested, each run on its own adaptive
steps. **Plain**: the default 108-node schedule bisected (108 / 215 / 429 / 857;
spacing past `b = 3` is 2 / 1 / 0.5 / 0.25 yr). **Uniform**: `N` nodes over
`[0, 39.63]` (spacing 0.370 / 0.186 / 0.093 / 0.046 / 0.023 yr). **Shifted**: the
uniform grid moved by half its spacing, sharing only `b = 0` with it.

| family | nodes | `J` | steps | s | `J` step | ratio | order |
|---|---|---|---|---|---|---|---|
| plain | 108 | 12.117229796 | 9 917 | 136 | | | |
| plain | 215 | 12.111849854 | 10 184 | 262 | −0.005380 | | |
| plain | 429 | 12.600465782 | 10 902 | 541 | +0.488616 | −0.011 | — |
| plain | 857 | 12.653184052 | 11 401 | 1106 | +0.052718 | 9.27 | 3.21 |
| uniform | 108 | 13.276378401 | 10 577 | 87 | | | |
| uniform | 215 | 12.747510333 | 10 921 | 170 | −0.528868 | | |
| uniform | 429 | 12.575093099 | 11 240 | 327 | −0.172417 | 3.07 | 1.62 |
| uniform | 857 | 12.573626344 | 11 627 | 654 | **−0.001467** | 117.6 | 6.88 |
| uniform | 1713 | 12.573447233 | 12 279 | 1427 | **−0.000179** | 8.19 | 3.03 |
| shifted | 429 | 12.583145309 | 11 240 | 329 | | | |
| shifted | 857 | 12.578490331 | 11 618 | 675 | −0.004655 | | |

The instantaneous model on the same grids (base build): plain 12.0526222 /
12.0888310 / 13.0315024 / +3.4% at 857 (`diag-nested-grid.md`,
`diag-edge-resolving-mesh.md`); uniform 13.348726052 / 12.776659098 /
12.492590826 / 12.455149719 at 10 551 / 10 884 / 11 204 / 11 577 steps, steps of
−0.572067, −0.284068, −0.037441, ratios 2.01 and 7.59.

- **The uniform ladder converges, and below the instantaneous model's floor.**
  Its last two steps are 1.2e-04 and **1.4e-05 of `J`**; the bracket ladder of
  the instantaneous model stopped at about 1.5e-04 per doubling. Order 3.0 over
  429 / 857 / 1713; extrapolated `J` = 12.573422 (order 3), 12.573388 (order
  2), 12.573268 (order 1). The step from 215 to 429 is 117× the next; at 429
  the spacing (34 d) is first under the averaged gate's median opening 10–90%
  width (40 d).
- **The plain ladder does not converge by 857**, and jumps between 215 and 429 as
  the instantaneous one does (+0.4886 against +0.9427): its spacing past `b = 3`
  is still 0.25 yr at 857, 2.3× the averaged gate's median opening width.
- **The shifted family** reads +0.0081 and +0.0049 above the uniform one at 429
  and 857.
- **Cost**: the window adds 0.2–0.4% steps at every uniform level (10 577 against
  10 551 at 108, 11 627 against 11 577 at 857) and the same wall time per node
  (654 against 650 s at 857).

## 5. The fixed-grid gradient

`dJ/dlma` by pinned whole-run differences, `d = 1e-3` on the trait (which moves
`lma`, `r_l`, `k_l`, `nmass_l` through the hyperparameterisation), each grid held
fixed across the trait and the step times pinned to the centre run's. The
central difference uses only the two pinned runs; backward, forward and `J''`
also use the centre run, which is not pinned (§6 for what that costs).

| grid | backward | forward | central | `J''` |
|---|---|---|---|---|
| plain 108 | −159.115 | −158.409 | −158.762 | +707 |
| plain 215 | −164.545 | −163.709 | −164.127 | +836 |
| plain 429 | −173.382 | −174.171 | −173.777 | −789 |
| plain 857 | −175.614 | −174.371 | −174.993 | +1243 |
| uniform 108 | −182.365 | −181.340 | −181.852 | +1025 |
| uniform 215 | −173.834 | −174.201 | −174.017 | −367 |
| uniform 429 | −172.577 | −171.870 | **−172.223** | +707 |
| uniform 857 | −172.973 | −172.089 | **−172.531** | +884 |
| shifted 429 | −173.299 | −172.653 | **−172.976** | +646 |
| shifted 857 | −173.069 | −171.894 | **−172.482** | +1176 |
| bracket + band fill, 865 | −173.128 | −171.966 | **−172.547** | +1161 |
| **bracket fixed at the instantaneous mesh's own roots, 499** | **−169.659** | **−169.652** | **−169.655** | **+6.9** |

On the instantaneous model (`diag-edge-resolving-mesh.md` §7 for the brackets;
the base copy here for the uniform grids):

| grid, instantaneous | backward | forward | central | `J''` |
|---|---|---|---|---|
| bracket fixed at its own re-located roots, 499 | −170.593 | −181.360 | −175.977 | −10 768 |
| bracket following the edges, 499 | −169.862 | −169.287 | −169.574 | +575 |
| uniform 215 (base build) | −174.107 | −170.620 | −172.364 | +3487 |
| uniform 857 (base build) | −171.446 | −170.394 | −170.920 | +1052 |

- What the instantaneous model's fixed grids get wrong
  (`diag-edge-resolving-mesh.md` §7): a fixed schedule's bias mixes the edges' motion with the trait's effect on
  where they are misplaced; only +0.287 (0.17%) of the +3.95 is the direct
  transport term, the rest arrives through the canopy, and a bracket held fixed
  at the reference trait's own roots is further off (3.8%) than a misplaced one
  (2.3%), curved −10 768 on one side of the reference.
- **On the bracket that fails the instantaneous model, the window's one-sided
  differences agree to 0.007 (4e-05) and `J''` is +6.9**, against 10.77 apart and
  −10 768 for the instantaneous model on the same 499 nodes: none of the
  fixed-schedule curvature. That bracket leaves the bands empty, which the
  averaged model needs filled (§7). **On the three grids that resolve the averaged
  model** — uniform 857, shifted 857, the bracket with band fill — `J''` is +884,
  +1176, +1161 with the one-sided differences 0.88–1.18 apart: **the range of the
  instantaneous model's edge-following ladder** (+575, +799, +996 at 1/16, 1/32,
  1/64 fill; 0.58–1.00 apart).
- On every uniform and shifted grid the window's one-sided differences are
  0.37–1.18 apart (`|J''|` 367–1176; at fixed `d` the two are one number). The
  instantaneous model on uniform grids is benign too at 857 (1.05 apart, +1052)
  and not at 215 (3.49 apart, +3487): a uniform grid rarely has a node on an
  edge.
- **The uniform family's central difference settles**: −181.85, −174.02, −172.22,
  −172.53, steps +7.84, +1.79, −0.31 (ratio 4.4, then the sequence turns), the
  last 0.18%. The shifted family reads −172.98 at 429 and −172.48 at 857.
  **At 857 the two families agree to 0.049 (0.03%)**, at 429 to 0.75 (0.44%),
  and the band-filled bracket (865) reads −172.547: three grids within 0.065, so
  `dJ/dlma` = **−172.52 ± 0.03** for the window at 0.05 on this stand, 1.6%
  steeper than the instantaneous model's edge-following −169.8 ± 1.1. The time
  grid's own effect on it at `ode_tol = 1e-3` was not measured here (1.08 on the
  instantaneous model).
- The plain family is still moving at 857 (−1.22 on its last step) and sits 1.4%
  steeper than the uniform one there, with `J` itself 0.63% high.
- The bracket without band fill reads −169.66, 1.7% shallower than the three,
  with its `J` 1.8% low (§7).

## 6. The adjoint

`stand_gradient` on the plain 108-node grid, window default: `J = 12.117229796`
equals the census's `offspring_production` to every digit; forward 140 s,
gradient 513 s (3.7×).

- **The window's column**: adjoint `dJ/d(establishment_window)` = **3.687605**
  /yr. Pinned central differences on the same grid: 3.694496 at `d` = 5e-05
  (backward 3.732731, forward 3.656262, `J''` = −1529): **0.19% from the
  adjoint, which sits between the one-sided pair.** Smaller steps read the
  pinned runs' own floor, not the derivative: 3.590721 at 5e-06 (backward
  4.242944, forward 2.938497) and 7.259120 at 5e-07 (11.962488, 2.555751). The
  one-sided differences part as `1/d` because `J` moves by 2–4e-06 between pinned
  runs at neighbouring windows; at 5e-05 that floor is about 0.03 of the column
  (0.8%). On the short stand of `test-tf24-establishment-window.R` the same
  column agrees with a pinned difference to 4.8e-07 and with the forward tangent
  to 5e-16.
- The same floor, at `d = 1e-3` on the trait, is up to about ±6 in each `J''` of §5
  and ±0.003 in its one-sided differences.
- **The lma column**, chained through the hyperparameterisation (`d/dlma` of
  `r_l` −308.917, of `k_l` −1.07252; `nmass_l` −0.0102 moves no equation): the
  adjoint's parameter columns give −269.020 + 91.836 + 18.591 = **−158.593**,
  against the pinned central −158.762 (backward −159.115, forward −158.409): inside
  the one-sided pair, 0.11% from the central.

## 7. `J` against the instantaneous reference

The window changes the model, so this is a shift, not an error.

| mesh | window | `J` | against the instantaneous on that mesh | against 12.417 |
|---|---|---|---|---|
| uniform ladder, extrapolated | 0.05 | 12.5734 | | **+0.156 (+1.26%)**; +0.15 to +0.17 against 12.40–12.42 |
| uniform 1713 | 0.05 | 12.573447 | | +0.156 |
| shifted 857 | 0.05 | 12.578490 | | +0.161 |
| bracket 793 + band fill (865) | 0.05 | 12.563238 | | +0.146 |
| bracket 793 + band fill (865) | 0.1 | 12.675691 | | +0.259 |
| bracket 793 + band fill (865) | 0.02 | 12.471129 | | +0.054 |
| uniform 429 | 0.05 | 12.575093 | +0.082502 against its instantaneous 12.492591 | +0.158 |
| uniform 429 | 0.1 | 12.684941 | +0.192350 | +0.268 |
| uniform 429 | 0.02 | 12.492716 | +0.000125 | +0.076 |
| bracket 793, no fill in the bands | 0.05 | 12.321637 | −0.097723 (−0.79%) | −0.095 |
| bracket 793, no fill in the bands | 0.1 | 12.531815 | +0.112455 (+0.91%) | +0.115 |
| bracket 499, no fill in the bands | 0.05 | 12.349067 | −0.077050 (−0.62%) | −0.068 |
| uniform 857 | 0.05 | 12.573626 | +0.118477 (+0.95%) | +0.157 |

Uniform 429's spacing (33.8 d) is 4.6× the 0.02 window (7.3 d), so its 0.02 row is
not resolved; the band fill's (11.4 d) is 1.6×.

- **The shift has the opposite sign to Step 0's prediction.** Offline, with the
  stand held as captured, (b) at 0.05 moved `J` by −0.0587 (−0.47%) and at 0.1
  by −0.0949; in the model the window moves it by **+0.156 (+1.26%)** at 0.05
  and +0.259 at 0.1. Split by birth date on the 865-node mesh against the
  instantaneous 793-node one: `b < 1` +0.119, `[1, 3.5)` +0.028, `[3.5, 6)`
  +0.004, `[6, 10)` −0.005, `[10, 22)` −0.002. All of it is carried by cohorts
  born before the first dead band (`b = 3.56`), where the gate never closes and
  `E` tracks it — the stand's response, which the offline estimate holds fixed.
  Where the window acts directly, `[3.5, 22)`, the model moves `J` by −0.003,
  against −0.059 offline. (The instantaneous side of this split is its
  793-node bracket without band fill; its gate is zero in the bands.)
- **A mesh built for the instantaneous gate is wrong for the averaged one.** The
  bracket meshes carry no node inside a dead band (gaps up to 170 d), because the
  instantaneous gate is zero there. `E` is not: it decays over the window after
  the gate closes, and the trapezium from the closing-edge node (`E` near its
  plateau) to the opening-edge node spreads that across the whole band. 72 fill
  nodes at 1/32 yr inside the 16 gaps move `J` +0.2416 (12.3216 -> 12.5632). The
  birth-date windows that hold the bands, `[3.5, 22)`, move +0.0023 in all; the
  rest is carried by cohorts born before the first band, `b < 1` +0.1904 and
  `[1, 3.5)` +0.0488: through the stand, as with the window itself.
- **`dJ/dwindow` is positive**: secants on the 865-node mesh +2.6 /yr from the
  instantaneous value to 0.02, +3.07 from 0.02 to 0.05, +2.25 from 0.05 to 0.1;
  +2.20 from 0.05 to 0.1 on uniform 429; the adjoint +3.69 on the plain 108 grid.
  Offline, stand held: −1.07 and −0.72 /yr.

## 8. What was re-baselined, old and new

**`tests/testthat/reference/reference-gradient.tsv`**, the whole-run difference
reference, recaptured by `scripts/capture-reference-gradient.R` unchanged: 1940
rows, 20 of them the two zero-default columns it cannot difference, as before.

- **New rows, no old value: 540.** 480 `offspring_production` rows (the file
  predated that metric), 30 for `establishment_window` and 30 for `S_D` on the
  three size metrics (`S_D` was declared uncaptured; it is now captured, and the
  test's uncaptured list is `TF24_floor_lambda_o`, `recruitment_decay`).
- **Common rows, 1380.** Move in the metric's own scale (the test's
  normalisation): median 6.6e-08, 90th percentile 4.4e-05, max 0.481; 40 rows
  move more than the test's 2e-3 floor. Median relative move of a row's own value
  by regime: wet 1.9e-05, clamped 4.9e-03, seasonal 1.4e-02, shaded 1.6e-02,
  drought 0.25.
- **The largest moves, old -> new:** drought 1.theta leaf_area 306.647 ->
  590.983; 1.theta area_stem 0.39230 -> 0.47154; 2.omega leaf_area −367.620 ->
  −442.691; 1.omega leaf_area −13.688 -> −80.983; 1.theta mass_above_ground
  744.271 -> 826.667; 2.theta leaf_area 250.731 -> 297.498; 2.omega area_stem
  −0.092783 -> −0.113409; 2.theta mass_above_ground 365.479 -> 331.938. For lma,
  e.g. drought 1.lma leaf_area −2.39937 -> −2.65565, clamped 1.lma leaf_area
  2.52197 -> 2.50927, wet 1.lma leaf_area −6.82657 -> −6.82629 (4e-05).

**Why the drought rows move.** The reference differences whole runs on the base
run's own step times, and those step times move: 46 steps on the base, 52 with the
window (one more state under error control). At the reference's tolerance the
drought gradient is not converged in the step sequence, on either build:

| `ode_tol` | base steps | base 1.theta leaf_area | window steps | window 1.theta leaf_area |
|---|---|---|---|---|
| 1e-4 (the reference's) | 46 | +306.64 | 52 | +590.99 |
| 1e-6 | 96 | +618.47 | 111 | +612.69 |
| 1e-8 | 223 | +602.02 | 263 | +589.13 |

At 1e-8 the two builds' census values agree to 1.1e-04 relative or better and
this column to 2.1%, which is the window's own effect on it. A small window does
not recover the old numbers: against the old reference the window build leaves 15 drought columns
past tolerance at `establishment_window = 0.002` and 14 at 0.05 (worst 1.theta
leaf_area, 0.488 and 0.481), and wet none at either (worst 1.0e-04). The move is
the added state's step sequence on a stand whose gradient that sequence does not
converge, not a change in what is differenced.

**One reference row reads across a jump in the census.** On `clamped`, species 1
`a_bio`, the recaptured row's four steps read −17.095 / −39.304 / −19.247 /
−19.855 (leaf_area; rel. steps 1e-6 / 1e-5 / 1e-4 / 1e-3) and the capture's rule
(most-agreeing adjacent pair, coarser member) chose −19.855. The sweep reads
−17.0950 and fails the test at 2.51e-03 against the 2e-3 floor. One-sided pinned
differences place a jump between `a_bio (1 + 7e-6)` and `a_bio (1 + 1e-5)`:

| rel. step | forward | backward | central |
|---|---|---|---|
| 1e-7 | −17.09447 | −17.09541 | −17.09494 |
| 1e-6 | −17.09034 | −17.09956 | −17.09495 |
| 7e-6 | −17.06163 | −17.12695 | −17.09429 |
| **1e-5** | **−61.46842** | −17.14045 | −39.30443 |
| 2e-5 | −39.12681 | −17.18424 | −28.15553 |
| 1e-4 | −21.05990 | −17.43461 | −19.24726 |
| 3e-4 | −20.55226 | −20.34459 | −20.44843 |
| 1e-3 | −17.02343 | −22.68697 | −19.85520 |

The forward excess over the smooth forward difference falls as `1/h` past the
jump (−44.4, −22.1, −4.4 at 1e-5, 2e-5, 1e-4), and the backward one picks up a
second jump between 1e-4 and 3e-4. The old reference read −17.2028 at 1e-5 with the jump outside its first two steps. The row
is kept as captured; the test declares the column (`reference_straddled_jump`,
asserted both ways: it must still show `|s2 - s1|` over 5x the floor) and reads it
at its finest step. With that, all five regimes pass: worst answered residual
6.9e-05 wet, 1.5e-03 drought, 8.1e-05 seasonal, 5.5e-05 shaded, 5.0e-04 clamped.

**`tests/testthat/_snaps/model-version.md`**: TF24 and TF24f only —
`pars.establishment_window` = 0.05 added, `TF24@v11 -> TF24@v12`,
`TF24f@v11.1 -> TF24f@v12.1`. FF16 and K93 unchanged.

**No TF24 or TF24f SCM output pinned in a test moved.** `test-strategy-tf24.R`
(18 tests) and `test-strategy-tf24f.R` (11) pass with only `establishment_window
= 0.05` added to their default lists. The other edited expectations are layout:
`test-patch.R` (the empty patch's state is `E` then the soil, its rate `0` then
the soil's), `test-species.R` (an empty TF24 species holds `E`; the tests start
it at the newborn's gate and the boundary node then matches a free `Node`'s
initial conditions bit for bit), `test-census.R` (the species state is its nodes
then `E`; G3 now reads the boundary node through `E`'s own seed column, equal to
`w_k density_k / E * area_leaf_k` to 1e-10).

## 9. Step counts, before and after

| run | base | window |
|---|---|---|
| fixture, default 108-node schedule | 9 931 | 9 917 |
| plain 215 | 10 174 | 10 184 |
| plain 429 | 10 816 | 10 902 |
| uniform 108 / 215 / 429 / 857 | 10 551 / 10 884 / 11 204 / 11 577 | 10 577 / 10 921 / 11 240 / 11 627 |
| Step 0 capture (108 nodes, 21 431 stops) | 26 019 | 26 017 |
| ladder reference stands: wet / drought / seasonal / shaded / clamped | 182 / 46 / 135 / 185 / 185 | 181 / 52 / 146 / 186 / 189 |

Their `J`: wet +3e-09, drought +1.4e-04, seasonal +2.8e-05, shaded +3.2e-04,
clamped +3.6e-08 relative.

## 10. Tests

Full serial sweep of the pushed head `6613dd24` (`testthat::test_file` per file,
`TESTTHAT_PARALLEL = false`, `-O2`): **79 files, 536 tests, 2 failed, 0 errored, 6
skipped, 746 s** with two or three measurement runs sharing the cores. Both failures are
`test-mutant.R`'s "mutant method works" (`pr1m10_rr` 2.77316 against 2.77322,
`pr3m10_rr` 2.83187 against 2.83174), identical on the base build. The FF16 guard
(`test-strategy-ff16.R` 9 tests, `test-strategy-ff16-reference-comparison.R` 2)
and `test-strategy-k93.R` pass unchanged; `test-strategy-tf24.R` (18) and
`test-strategy-tf24f.R` (11) pass with the new default added to their lists.

`test-tf24-establishment-window.R`, 6 tests:

- the parameter's default, its gradient column, and the refusal of 0, −0.05,
  NaN, Inf;
- the layout: each species' block is its nodes then `E`, an empty patch holds
  one entry per species, FF16 none;
- the equilibrium start: `E(0)` is the newborn's gate and `dE/dt(0)` exactly 0;
- relaxation in one held environment against `gate + (E0 - gate) exp(-t/window)`
  (the rate to 1e-12; classical RK4 at a hundredth of the window to 1e-9);
- every introduced node seeded at the average (`mortality = -log E`,
  `log_density = log(birth_rate E)`, to 1e-14) on a stand whose average ranges
  under 0.1 to over 0.99;
- the window's column: the sweep against the forward tangent of the same
  recording (5e-16 of the column measured, 1e-12 asserted) and against a pinned
  whole-run central difference at `h = window * 1e-4` (4.8e-07 measured, 1e-05
  asserted).

The census and gradient suites (17 files) pass, including the whole-run
reference over five regimes with the one declared straddle (§8).

## 11. Scripts, and the build they ran against

In `tg/` of the scratchpad; nothing under `plant/`, `plant-dev` or the existing
scratchpad scripts was touched, and fixture helpers were copied (`ld_common.R`,
`lh_common.R`, `rw_common.R`) with the load pointed at the worktree (`TG_PLANT`
selects the base copy). Step 0: `tg_capture.R`, `tg_filter.R`. In the model:
`tg2_scan.R`, `tg2_ramps.R`. Ladders: `tg2_common.R`, `tg2_fd.R` (uniform, plain),
`tg2_fd2.R` (shifted), `tg2_fdJ.R`, `tg2_fd_base.R`, `tg2_fdJ_base.R`,
`tg2_table.R`. Brackets: `tg2_mesh.R`, `tg2_meshfd.R`, `tg2_bandfill.R`,
`tg2_bandfill_fd.R`, `tg2_windows.R`, `tg2_windows2.R`, `tg2_shift.R`. Adjoint:
`tg2_adj.R`, `tg2_chain.R`, `tg2_taufd.R`. Reference: `tg_refcmp.R`,
`tg_refworst.R`, `tg_refmoves.R`, `tg_refjumps.R`, `tg_jump.R`, `tg_tighttol.R`,
`tg_refmove.R`. Tests: `tg_testfile.R`, `tg_onefile.R`, `tg_sweep.R`, `tg_steps.R`.
Two comment-only header edits in `b3a33626` (a reflowed comment in `node.h`, the
v12 note in `tf24_strategy.h`) postdate the library; `pkgbuild::needs_compile`
reads FALSE.

---

## What was not reached

- **Why the stand responds with the opposite sign.** The shift lives in cohorts
  born before the first dead band (§7), and adding nodes inside the bands moves
  those same cohorts; which part of the stand carries it — light, soil water,
  the post-drought recruitment the average delays — was not taken apart.
- **A mesh built for the averaged gate.** The uniform family converges
  (1.4e-05 last step) and the other two sit within +0.04% / −0.08% of it at ~860
  nodes, but no bracket was placed on the averaged gate's own kinks, and the
  band fill was run at one spacing (1/32 yr).
- **The plain family's limit.** It is still moving at 857 nodes (−1.22 in the
  derivative, +0.053 in `J`); its spacing past `b = 3` would need two more
  bisections to sit under the gate's opening width.
- **The derivative's convergence rate.** The uniform family's last step is 0.18%
  and turns; the fixed-grid derivatives were taken at `d = 1e-3` only and at
  `ode_tol = 1e-3`, whose time-grid effect on the instantaneous model's derivative
  was 1.08 (`diag-edge-resolving-mesh.md`).
- **The adjoint on a converged mesh.** It was taken on the plain 108-node grid
  only.
- **The stochastic patch** still establishes on the gate at the instant; nothing
  was measured there.
- **One trait, one record, one coordinate.** `lma = 0.32` on `long-drought`,
  `node_density_in_birth_date = TRUE`, `ode_tol = 1e-3` throughout.
