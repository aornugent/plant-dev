# Break-even: why ln R′ is so sensitive to P on the closed canopy

The leaf-table pilot (`spikes/leaf-table`) found a gain d ln R′/d ln P of 3.5e3–7.6e3 for
the invader at the resident's traits on the closed stand, against about 50–65 elsewhere.
This spike asks what causes it.

## Result

**The gain is a property of the node schedule, not of the leaf, the step control or
break-even.**

- **The cause.** On the closed stand, the cohort born at t = 0 outgrows the cohorts born
  0.37 yr later and suppresses them. By t = 7.8 it is 10.2 m tall, and the next cohort is
  3.9 m. Its density is e¹¹ times theirs.
- **Why the uniform schedule fails.** The fitness integrand over birth date peaks at
  0.02–0.07 yr: a boundary layer about 0.05 yr wide. The uniform 108-node schedule spaces
  nodes 0.37 yr apart, so it does not resolve the layer.
  - The t = 0 node carries the whole layer: 63% of the resident's R and 69% of the
    identity invader's R′.
  - That node is a single sheet of leaf area at one height. The identity invader's first
    cohort has exactly that height.
  - The tie is unstable. A small change in P puts the invader just above or just below the
    sheet, and the gap grows: d ln h/dε grows from 2 to 940 over t = 1–8 yr.
  - During t = 4–8 the leader also drains its reserves in the dry spells (r falls to 5e-4,
    and the hazard is near its ceiling a_dG1 = 5.5/yr). That transient is written into the
    hazard permanently: dH/dε = −4.8e3 from t = 9 to the end.
- **The fix.** Add 8 or 16 introductions inside (0, 0.37):
  - the identity gain falls from **6.5e3 to 120 and then 96**;
  - the first cohort's own gain falls from 1.04e4 to 59;
  - its share of R′ falls from 63% to 0.3%.

  Halving or doubling the ODE tolerance leaves the gain unchanged (7.29e3 and 7.23e3,
  against 7.24e3).
- **The shape.** ln R′(ε) is **smooth**: no steps and no noise down to ε = 1e-7.
  - It is linear to 1e-6 and concave beyond. At the default schedule the gain is 7244 at
    1e-7, 7214 at 1e-5, 5657 at 1e-4 and 1140 at 1e-3.
  - **AD agrees with finite differences to 5 digits** (7244.41 against 7244.38; for row 2,
    64.333 against 64.33). The tape is the function being differenced. What makes it steep
    is the discretisation.
- **It is not break-even.** On the closed stand, the pool invaders with ln R′ near 0 have
  gains of 33–145 (rows 11, 43, 29, 38, 31). Those far from it have gains of 17–120. Only
  the invader tied to the resident's t = 0 node reaches thousands.

**Real or numerical: numerical.** It is an unresolved boundary layer in birth date at the
start of the patch. Once that layer is resolved, ln R′ has an ordinary gain of about 100.
That is still above the pool's typical 40–60. It is the real but moderate steepness of
being among the leaders of a closing canopy.

## What it implies

- **Equilibrium.** ln b* = 3.595 is the equilibrium of the uniform schedule, not of the
  model. With 8 or 16 nodes added inside the first interval, the resident's F at that b
  is +0.157 and +0.169 instead of −8.5e-5. Assembly and equilibrium on this stand inherit
  an O(0.2) error in F, and the error is not visible to a tolerance study.
- **Invader schedules.** Invaders on every third introduction triple the weight of the t = 0
  node. That is why the identity invader read ln R′ = 1.00, not 0. With every introduction
  it reads −8.5e-5, which equals F.
- **Field-dimension spectra.** Pool fitness on the closed stand moves by O(1) when the
  start is resolved. These comparisons are confounded: the resident is then off its
  equilibrium (F = +0.17), and the invaders enter at every introduction rather than every
  third.

  | row | ln R′, uniform, every third | ln R′, +16 nodes, every one |
  |---|---|---|
  | 2 | −1.11 | +2.05 |
  | 29 | +0.24 | −1.09 |
  | 31 | +1.02 | −0.39 |

  The closed-stand spectra (`spikes/field-dimension-066`) used the uniform schedule, so
  their near-resident directions are dominated by the t = 0 node.
- **Selection gradients.** The rare-mutant derivative at the resident's traits is exactly
  the identity invader's derivative. On a closed canopy with the uniform schedule it is
  inflated about 60× (6.5e3 against about 100) and dominated by one node. Gradients there
  are not usable until the start is resolved.
- **The scheduler's ε (`OBJECTIVES.md`).**
  - The step controller is not the problem; the node schedule is.
  - The schedule must resolve the first ~0.1 yr of birth dates on stands where an early
    cohort takes the canopy.
  - Geometric introductions from about 4e-4 yr upward did that here.
  - The refine loop's error indicator should be checked on this stand, to see whether it
    asks for those nodes. That was not run here.
- **The leaf-table pilot.** Its "knife edge" (the identity invader's −0.86 from the table's
  bias) was this artefact. Its other gains (49 and 64) stand.

## Answers to the questions

1. **Shape of ln R′(ε), and AD against FD.**
   - Identity invader on the closed stand, default schedule (`results/gains.txt`):
     - smooth and monotone;
     - gain 7244 at ±1e-7 and ±1e-6;
     - concave beyond: the asymmetry (up/down) is 0.99 at 1e-6, 0.91 at 1e-5, 0.60 at
       1e-4 and 0.78 at 1e-3;
     - no jitter: two unscaled copies agree to 1e-9 in ln R′.
   - Row 2 (closed) and the identity invader on the open stand: linear to 1e-3, with gains
     64.33 and 49.49.
   - **AD.** The P direction is e(a_y) − e(r_l) − e(r_b) − e(r_s) − e(r_r), since
     net = a_bio a_y (A − R) − T.
     - Taken from `stand_gradient(hyperpar = NULL)` after `run_mutant`, it gives 7244.41
       and 64.333.
     - `fd_pars.R` confirms each elasticity by differences to 6 digits.
2. **Cohorts** (`results/cohorts_*.txt`).
   - Default schedule: the t = 0 cohort supplies 7215 of the 7244 gain (6513 of 6541 with
     every introduction). Its own d ln R_c/dε is 1.04e4.
   - Every other cohort's gain is 30–140.
   - With the start resolved, the cohorts born at 0.005–0.07 yr carry most of the R′
     (up to 14% each), with gains of 66–300.
3. **Mechanism** (`results/traj_*_cohort1.txt`, `results/resident_top_closed.txt`).
   - The identity invader's first cohort sits at the height of the resident's dominant
     t = 0 node, and the tie is unstable, as described under Result.
   - The sensitivity accrues over t = 4–8, while the leader drains its reserves (r down to
     5e-4) during the dry spells.
   - The open stand's first cohort has the same reserve dips (r = 1.5e-4 at 7.8 yr) and a
     dH/dε of only −30. So the reserve dynamics are not the amplifier; the tie is.
   - Ruled out:

     | perturbation | gain |
     |---|---|
     | gate width 0.05 | 2.75e3 |
     | gate width 0.2 | 9.5e3 |
     | storage_prod_eps 1e-3 | 7.9e3 |
     | ODE tolerance halved | 7.29e3 |
     | ODE tolerance doubled | 7.23e3 |

     These change the stand but leave the gain in the thousands. The light floor is not
     reached (as the pilot showed). `non_negative_states` refusals and the step pinning
     would show up as tolerance dependence or jaggedness, and there is neither.
   - The only lever that moves it is the introductions inside the first interval.
4. **Closed canopy or break-even?** Neither on its own; it is the tie with an unresolved
   leader node.

   | stand, schedule | invader | ln R′ | gain |
   |---|---|---|---|
   | closed, default | identity | 1.00 (every third), 0 (every one) | 7.2e3 / 6.5e3 |
   | closed, default | pool, ln R′ in −0.2…1.0 | | 33–145 |
   | closed, default | pool, \|ln R′\| > 4 | | 17–120 |
   | closed, +16 nodes | identity | 0.17 | 96 |
   | closed, +16 nodes | rows 2, 29, 31 | | 67–95 |
   | open, default | identity | 0.48 | 49 |
   | open, default | pool | | 21–194 (the largest for the worst invaders) |
   | open, +16 nodes | identity | | 61 |

   The gain rises as ln R′ falls (poor invaders sit nearer survival limits), not as it
   approaches 0. The ground light was not tabulated: the openness read from the invader's
   history failed (see Files), and the comparison above did not need it.
5. **Implications.** See above. Fitness is continuous and differentiable here; the
   derivative is meaningful, but it is the derivative of a discretisation that is wrong
   near t = 0. No ODE tolerance makes it smooth or correct. The node schedule has to
   resolve the leaders' boundary layer in birth date.

## Not done

- The refined schedule is not converged: the gain is 120 at +8 nodes and 96 at +16, and F
  is 0.157 and 0.169. A ladder at +32 and +64 would settle both.
- The refined stand was not brought back to equilibrium.
- The refine loop's own node placement on this stand was not run.
- The openness profile around the leader, from the invader's history (`light.R`), came back
  empty. `run_mutant` resets the history, so `light.R` drops every snapshot.
  `resident_top_closed.txt` shows the leader's isolation directly.

## Build and runs

- **Build.** Plant a1e6c061 (`ODELIA-66`) carries `probe.patch`, which is the pilot's
  `leaf_probe.patch` plus three additions:
  - `PLANT_LEAF_KEYS` and `PLANT_LEAF_PSCALES`: comma lists that scale several invaders'
    P in one run, each keyed on its exact vcmax_25;
  - `PLANT_GATE_WIDTH`, which overrides `storage_gate_width`;
  - `PLANT_STORAGE_EPS`, which overrides `storage_prod_eps`.

  It is installed `-O2` in `/home/a/.claude/jobs/9d586e52/tmp/breakeven/rlib`, a copy of
  `rlib-leaf` with plant rebuilt.
- **Stand.** `stand.R` is the pilot's closed (and open) stand.
  - Invaders are told apart by a relative vcmax_25 offset of k·1e-12. That is below
    anything measured: two unscaled copies agree to 1e-9 in ln R′.
  - `EVERY` sets the invaders' introductions.
  - `EXTRA=n` adds n introductions spaced geometrically over (3.7e-4, 0.26) yr.

## Files

- `stand.R`: the stand and the run helpers.
- `scan.R`: ln R′ against ε, for one or several rows.
- `ad.R`: the AD elasticities and the P direction.
- `fd_pars.R`: differences in a_y, r_l, and a_y with all four r scaled together. In
  `results/fdpars_closed.txt` that last set is labelled `P`. It is not the P direction.
- `traj.R` and `traj_summary.R`: cohort trajectories from `run_mutant`'s history, one per
  introduction.
- `light.R`: the resident's tallest cohorts at each introduction.
- `cohorts.R`: the per-cohort decomposition.
- `gains.R`: the table of every gain.
- `q1.sh`, `q2.sh`, `q34.sh A|B`, `q5.sh` and `tables.sh`: the runs, in order.
- `results/`: the tables quoted above.
- Raw `.rds` and logs are in `/home/a/.claude/jobs/9d586e52/tmp/breakeven/`.
