# Scope: exact establishment counts, error maps from the sweep, and a schedule controller

This covers the three pieces of the performance design that do not depend on the record:
- **exact counts**, so cohorts no longer resolve the gate;
- **two error maps in units of `J`**, from the sweep an optimiser already runs;
- **a controller that places cohorts by error per unit cost**, and certifies the result.

The stepper is `scope-imex-stepper.md`. §6 gives the order for both.

**Scope of the controller: the birth-date coordinate only.**
- `refine_schedule` stays for the height coordinate, which is still plant's default (`node_density_in_birth_date = false`) and FF16's.
- Retiring the height coordinate would delete it, and every trapezium below with it. That is your decision.

## 1. Exact counts

**Today, a cohort is a point sample of the recruitment it stands for.** At birth (`node.h:seat_at_birth`):
- the density is set to `β(b)·E(b)`;
- the cumulative loss is set to `−log E(b)`.

So `E` enters twice: the fields read it through the density, and `J` reads it through the survival factor.

The birth-date trapezium over those samples is formed in four places, which all read the same abscissae:
- `net_reproduction_ratio`, which is `J`;
- `consumption_rate`, the uptake `a`;
- `census_integral`;
- the competition walk, `field_splits` with `close_competition_and_slope`.

Where `E` ramps faster than the spacing, the samples misweigh it. That is where the schedule's error sat (S3–S6, A5).

**The change.**
- *Each species integrates its recruitment exactly, per panel between consecutive creations*, as two running masses beside `E`:
  - `M₀ = ∫ βE db`;
  - `M₁ = ∫ (b − b_last) βE db`.

  The stepper integrates them. Its steps (median 0.56 days) resolve the gate's ramps (18–40 days), so the schedule no longer has to.
- *At a creation, the finished panel's masses go into the species' state beside the new cohort, and the running pair restarts at zero.* This is part of the insertion map, so the sweep differentiates it like the rest.
- *A cohort is seeded at unit density and zero cumulative loss.* The mass it stands for is its hat's share of the two panels either side of it:
  - `w_j = M₁⁽ʲ⁾/Δ_j + M₀⁽ʲ⁺¹⁾ − M₁⁽ʲ⁺¹⁾/Δ_{j+1}`;
  - the newest cohort takes its upper share from the running pair, and the boundary cohort at `b = t` takes `M₁/Δ` of it.
- *The weights are computed once per rate evaluation, in one Species function, and every birth-date reduction becomes `Σ w_j·s_j·X_j`.* `E` now enters once, through the masses. The patch-age weight `π(b)` stays in `J`'s value, where it is smooth.

**What it removes from the birth-date path.**
- the trapezium intervals, and the halving in `without_boundary`;
- the interval `field_splits` closes by hand where a crown's support crosses the height. With one term per cohort, a cohort below the height contributes an exact zero;
- the sort for cohorts whose heights cross (`ascending_by_abscissa`), because a weighted sum does not depend on order;
- the second entry of `E`;
- parking a failed recruit at `establishment_failure_hazard`. Its mass is zero instead.

**What stays.** The height path is untouched, so FF16's references hold. The state grows by two entries per cohort and two per species, about 8% of the recording.

**What it is.** A declared reformulation with the same continuous limit: `J` moves at the level of today's discretisation error.
- *Test: the handover's test 2.*
  - S3's split inverts;
  - uniform 215 lands within about 1e-3;
  - removing the 64 cohorts created inside closed bands moves `J` by ≪ 7e-2;
  - 429 and 857 extrapolate at a clean second order.
- *The gradient:* re-measure A2. The Oracle predicts it now converges at `J`'s rate.

**Invaders.** Each species integrates its own masses from its own gate, so invaders need nothing extra.

## 2. Two error maps from one sweep

Both come out of the sweep that computes the gradient, at a few percent of its cost (A6).

**Time: the adjoint-weighted local error of every step, `e_n = λ_{n+1}ᵀ·est_n`** (Cao and Petzold).
- *Where `est_n` comes from.* It is the step's embedded difference, `h Σ (b_i − b̂_i) k_i`. `step_adjoint` already evaluates every stage's rates to record the step (`ode_step.hpp:270–293`), so `est_n` is their passive combination, with no extra evaluation.
- *Where `λ_{n+1}` comes from.* `sweep_range` holds it when it calls the step.
- *odelia's change:* the sweep fills one number per recorded step and seed, and the Solver holds the table as it holds `recorded_rates`.
- *What it is:* a map, not an error. `est_n` estimates the embedded solution's error, which overstates the propagated one. So the map says where the time error sits, and a step-halving run sizes it (§3).
- *When it can be trusted:* until the stepper stops stages overshooting the soil's clamps, `J`'s time error does not follow the tolerance (T5). The map is only trustworthy once the stepper lands (§6, step 7).

**Birth date: the value per unit mass at every cohort, and the error of interpolating it.**
- *The value.* `J` depends on the panel masses through the weights, so the adjoint of a cohort's panel masses at its insertion row is the value `T` per unit mass there:
  - `∂J/∂M₀⁽ʲ⁾ = T_{j−1}`;
  - `∂J/∂M₁⁽ʲ⁾ = (T_j − T_{j−1})/Δ_j`.

  It is the total value, since the competition channel runs through the same weights.
- *odelia's change:* the sweep already stops at every insertion row, to transpose the insertion map (`ode_solver.hpp:solve_adjoint`), and now it keeps `λ` there.
- *This replaces* the 207-line hook of `perf-adjoint-hook.patch`.
- *The error map is the drop-every-other difference, computed without another run.* Compare the product integration of `T` over hats at every cohort with one over hats at every other cohort. Both come from `T` and the stored panel masses. Their difference over a pair of panels, divided by 3, is that pair's error at second order.
- *Its limit is A5's.* Features of `T` narrower than the spacing are invisible from the schedule's own cohorts, so the pilot has to resolve them.

## 3. The controller

1. **Pilot.** Uniform in birth date, with exact counts: about 200 cohorts (0.2 yr) on this record, the Oracle's pilot.
   - `T`'s measured excursions are 0.1–0.5 yr wide (A5), so this spacing resolves most of them.
   - How the spacing should follow another record's own time scales is for the scenario bank to set. The candidate is the length of the record's drought bands, not of its dry spells between rain days, which are days long.
2. **One forward run and one sweep**, giving the two maps of §2 and the cost model.
   - A cohort born at `b` costs its share of every later rate evaluation, `6·c·(steps after b)`, read off the pilot's step record.
3. **Placement.**
   - *Density.* Cohort density is set by `ρ(b) ∝ (|d(b)|/cost(b))^{1/3}`, where `d` is the schedule map's error density. This is what makes each cohort's estimated error per unit cost equal at second order.
   - *Removal as well as addition.* The schedule is regenerated as quantiles of `∫ρ`, not inserted into, so cohorts are removed where they are not needed.
   - *Count.* `N` is set by the schedule's share of the budget.
4. **Budget split.** With cost `C_t ∝ ε_t^{−1/q}` for time and `C_b ∝ ε_b^{−1/2}` for the schedule, the cheapest split of `ε = ε_t + ε_b` satisfies `C_t/(q·ε_t) = C_b/(2·ε_b)`.
   - The constants come from the pilot's own costs and errors.
   - The time side sets the tolerance of the run whose step program is then pinned.
5. **Certificate.** `e_t + e_b ≤ ε`, from the sweep of the run on the new grid.
   - At each rebuild it is cross-checked by two runs: the every-other-cohort schedule, whose difference should be about 3·`e_b`, and the pinned program with its steps halved, for the time side.
6. **In an optimisation.**
   - Every iterate's sweep yields the certificate at that `θ` for nothing, because the grid is fixed within a gradient (H1).
   - While the certificate holds, the schedule and the pinned program stay. When it fails, rebuild from steps 2–4 at the current `θ`, using the current grid as the pilot.
   - Along-step consistency, `J(θ_{k+1}) − J(θ_k)` against the trapezium of the two gradients, is checked beside it.

**Where it lives.**
- *The maps are C++:* sweep outputs, in odelia and plant.
- *Placement and the certificate are R.* They run between runs, they are a few dozen lines each, and they are easier to change there.
- *The user's entry point:* `design_schedule(p, tol)` returns the schedule, the pinned program and the certificate. On the birth-date path, `run_scm(refine_schedule = TRUE)` calls it.

## 4. What a plant developer sees

- **On the birth-date coordinate, cohorts stand for exact masses.** A strategy writes nothing new: the masses read the establishment probability it already provides.
- **`design_schedule(p, tol)` returns a schedule, a pinned step program and a certificate.**
- **In a fit, `certificate(scm)` says whether to keep the grid.**

## 5. Risks

- **The pilot must resolve `T`** (A5). Test it on the scenario bank: records with impulsive storms are where a newborn's value can jump across a storm.
- **The drop-every-other map is first order in the stand's response**, as A5's formula is. A6 found such predictions within 5–25%, so the checkpoint runs are the certificate's real test.
- **Cancellation.** Errors of either sign cancel today (S6). Equidistributing `|d|` is conservative, and a design that relies on cancellation is not certifiable.
- **Long horizons.** Cohorts accumulate, so retiring them with a bound on their remaining value `T` would be needed. That is not scoped here.

## 6. Order of work, with the stepper

Each step has its pass criterion in the scope it comes from.

1. **Stops as step targets; drop the redundant evaluation at entries; delete RODAS** (stepper scope §2.1–2.2). About 7% fewer member evaluations, with results unchanged.
2. **The pool's relaxation floor** (stepper scope §3, option A). A declared model change: measure `J` and `dJ/dθ`.
3. **Forward passes record their own rows** (stepper scope §2.3). TF24 invaders work, and their recordings sweep.
4. **Exact counts** (§1). The handover's test 2.
5. **The two maps** (§2).
   - *Validate the schedule map* against A6: it should predict refinements' changes in `J`.
   - *Validate the time map* against a step-halving run.
6. **The controller, schedule side** (§3). Benchmark against uniform ladders on the fixture, then the scenario bank.
7. **The stepper: the prototype driven from R, then odelia's tableau stepper and stiff block, then TF24's wiring** (stepper scope §4–5). The handover's test 3.
8. **The controller, time side, and its optimisation policy.** The handover's test 4 across the 11 points of `perf-across-theta.md`, and then a second consult framed around the family of records.
