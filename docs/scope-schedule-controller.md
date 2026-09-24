# Scope: exact establishment counts, error maps from the sweep, and a schedule controller

**Status (September 2026):** §1 is being implemented on plant's `develop` as aornugent/plant#93 (see `handover.md`); §2–6 are parked.

This covers the three pieces of the performance design that do not depend on the record:
- **exact counts**, so cohorts no longer resolve the gate;
- **two error maps in units of `J`**, from the sweep an optimiser already runs;
- **a controller that places cohorts by error per unit cost**, and certifies the result.

The stepper is `scope-imex-stepper.md`. §6 gives the order for both.

**Scope of the controller: the birth-date coordinate only.**
- The height coordinate stays for now (decided September 2026). It is plant's default (`node_density_in_birth_date = false`) and FF16's, and `refine_schedule` stays with it.
- Its retirement is anticipated. Everything new sits on the birth-date branch of each reduction, and nothing new reads the height path. Retiring it would delete that branch, `refine_schedule`, the height sort and the height-only seeding, and nothing else.

## 1. Exact counts

**What a cohort stands for today: a point sample of recruitment.** At birth (`node.h:seat_at_birth`):
- the density is seeded at `β(b_j)·E(b_j)`, the recruitment rate at that instant;
- the cumulative loss is seeded at `−log E(b_j)`.

Every integral over birth date is a trapezium over those samples, formed in four places:
- `net_reproduction_ratio`, which is `J`;
- `consumption_rate`, the uptake `a`;
- `census_integral`;
- the competition walk, `field_splits` with `close_competition_and_slope`.

So each panel's recruitment is taken to be linear between its two samples. That fails on this record:
- `E` ramps over 18–40 days at the 56 band edges;
- the cohorts are 34–135 days apart;
- so a panel holding an edge gets the wrong mass, by an amount and sign set by where its cohorts fall (S3–S6, A5).

`E` also enters twice: the fields read it through the density, and `J` reads it through the survival factor.

**What it stands for instead: the establishment in its hat.** Recruitment `m(b) = β(b)E(b)` is rough only through `E`. The birth rate `β` and the fate of one recruit, `X(b)`, are smooth. So integrate `E` exactly and interpolate the rest:

`∫ β E X db ≈ Σ_j β_j X_j w_j`, with `w_j = ∫ E(b) φ_j(b) db`,

where `φ_j` is the hat at `b_j`.
- *The weight.* `w_j` is the establishment the cohort stands for, integrated exactly. `β` stays a point sample at `b_j`, as today, so `offspring_production` and `net_reproduction_ratios` keep their meaning under a varying birth rate.
- *The error left* is the interpolation error of `X`, `O(Δb²·X″)` times the mass. That is second order, whatever `m` does.

**How the weights are integrated.**
- *Each species carries two running states for its open panel,* the one since its last creation `b_N`:
  - `M₀ = ∫ E db`, with rate `E(t)`;
  - `M₁ = ∫ (b − b_N) E db`, with rate `(t − b_N)·E(t)`.

  The stepper integrates them, and its steps (median 0.56 days) resolve `E`'s ramps.
- *Each cohort carries its mass `w_j` as a state,* with rate zero.
- *At a creation at `b_{N+1}`, the insertion map closes the panel.* With `Δ = b_{N+1} − b_N`:
  - the previous cohort takes its upper share, `w_N += M₀ − M₁/Δ`;
  - the new cohort starts at its lower share, `w_{N+1} = M₁/Δ`;
  - the running pair restarts at zero.
- *Between creations, the open panel is shared the same way at every evaluation:*
  - the newest cohort adds `M₀ − M₁/(t − b_N)` to its stored mass;
  - the boundary cohort at `b = t` takes `M₁/(t − b_N)`.

**What else changes.**
- *A cohort is seeded at density `β(b_j)` and zero cumulative loss,* so its states describe the seed arriving at `b_j` without its establishment. `E` enters once, through the masses.
- *Every birth-date reduction becomes `Σ w_j·s_j·X_j`,* with the weights formed once per evaluation.
- *The patch-age weight `π(b)` stays in `J`'s per-recruit value,* where it is smooth.
- *The state grows by one entry per cohort and two per species,* about 4% of the recording.
- *R code that reads cohort densities on this path reads per-recruit values.* The masses are a new column.

**What it removes from the birth-date path.**
- the trapezium intervals, and the halving in `without_boundary`;
- the interval `field_splits` closes by hand where a crown's support crosses the height. With one term per cohort, a cohort below the height contributes an exact zero;
- the sort for cohorts whose heights cross (`ascending_by_abscissa`), because a weighted sum does not depend on order;
- the second entry of `E`;
- parking a failed recruit at `establishment_failure_hazard`. Its mass is zero instead.

**What it is.** A declared reformulation with the same continuous limit: `J` moves at the level of today's discretisation error.
- *Test: the handover's test 2.*
  - S3's split inverts;
  - uniform 215 lands within about 1e-3;
  - removing the 64 cohorts created inside closed bands moves `J` by ≪ 7e-2;
  - 429 and 857 extrapolate at a clean second order.
- *The gradient:* re-measure A2. The Oracle predicts it now converges at `J`'s rate.

**Invaders.** Each species integrates its own masses from its own gate, so invaders need nothing extra.

**Where it can land: on its own, on plant's `develop`.**
- *What it depends on.* Nothing else in this plan: not the adjoint, the controller, the stepper, the pool floor or the invader fix.
- *What `develop` (`95256cf3`) already has:*
  - the birth-date coordinate;
  - stops at the knots, through pulse events;
  - a boundary cohort that computes the establishment probability at every evaluation (`node.h:compute_initial_conditions`), which the running masses read.
- *The change is smaller there:*
  - `consumption_rate` already opens with its own birth-date branch;
  - `compute_competition` shares one loop between the coordinates, so it gains one early birth-date branch;
  - `J`'s trapezium is one function, `Patch::net_reproduction_ratio_for_species`;
  - the seeding is two lines of `compute_initial_conditions`;
  - the masses' bookkeeping is `Species::introduce_new_node` and the species' own states.
- *It does more there.* `develop` has no establishment window. Point samples of the instantaneous gate cannot converge in the schedule at all. With the masses, its ramps (0.07–0.7 days at openings) move from the schedule to the time stepper, and the window becomes a modelling choice rather than a numerical necessity.
- *Tests, all forward:*
  - the masses sum to a fine quadrature of `βE` along the run;
  - uniform ladders converge at second order, with the time grid held by giving every rung the finest rung's creation times as stops;
  - shifting the schedule by half a spacing moves `J` only at second order;
  - the cohorts inside closed bands can be removed;
  - the instantaneous gate converges in the schedule;
  - FF16's references are unchanged;
  - the change in step count is reported.
- *What it costs: the stack.* Its 15 commits above `develop` rewrote `node.h`, `species.h` and `patch.h`, about 1700 lines. So landing on `develop` first means re-applying the birth-date branches in their templated form when the stack is rebased, along with `census_integral` and `field_splits`, which only the stack has.
  - The window commit gets simpler: seeding no longer reads the establishment probability, and the window only feeds the masses.
- *Three things to settle in the change itself:*
  - `refine_schedule`'s drop-one indicator reads cohort densities, so on this path it must read the masses, or refuse;
  - R code reading birth-date densities gets per-recruit values;
  - two creations at one instant give a zero-width panel, whose share `0/0` is zero.

## 2. Two error maps from one sweep

Both come out of the sweep that computes the gradient, at a few percent of its cost (A6).

**Time: the adjoint-weighted local error of every step, `e_n = λ_{n+1}ᵀ·est_n`** (Cao and Petzold).
- *Where `est_n` comes from.* It is the step's embedded difference, `h Σ (b_i − b̂_i) k_i`. `step_adjoint` already evaluates every stage's rates to record the step (`ode_step.hpp:270–293`), so `est_n` is their passive combination, with no extra evaluation.
- *Where `λ_{n+1}` comes from.* `sweep_range` holds it when it calls the step.
- *odelia's change:* the sweep fills one number per recorded step and seed, and the Solver holds the table as it holds `recorded_rates`.
- *What it is:* a map, not an error. `est_n` estimates the embedded solution's error, which overstates the propagated one. So the map says where the time error sits, and a step-halving run sizes it (§3).
- *When it can be trusted:* until the stepper stops stages overshooting the soil's clamps, `J`'s time error does not follow the tolerance (T5). The map is only trustworthy once the stepper lands (§6, step 7).

**Birth date: the value per unit mass at every cohort, and the error of interpolating it.**
- *The value.* The adjoint of a cohort's mass at its creation row is `T_j = ∂J/∂w_j`: the value of one more unit of recruitment in its hat, the competition channel included.
  - It reads the whole effect, because the upper share the next creation adds to the mass only adds to it.
- *odelia's change:* the sweep already stops at every insertion row, to transpose the insertion map (`ode_solver.hpp:solve_adjoint`), and now it keeps `λ` there.
- *This replaces* the 207-line hook of `perf-adjoint-hook.patch`.
- *The error map is the drop-every-other difference, computed without another run.* Compare the product integration of `T` over hats at every cohort with one over hats at every other cohort. Both come from `T` and each closed panel's `M₀` and `M₁`, which are logged as plain numbers at its creation because nothing differentiates them. Their difference over a pair of panels, divided by 3, is that pair's error at second order.
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

1. **Stops as step targets, and drop the redundant evaluation at entries** (stepper scope §2.1). About 7% fewer member evaluations, with results unchanged.
2. **The pool's relaxation floor** (stepper scope §3, option A). A declared model change: measure `J` and `dJ/dθ`.
3. **Forward passes record their own rows** (stepper scope §2.3). TF24 invaders work, and their recordings sweep.
4. **Exact counts** (§1). The handover's test 2.
5. **The two maps** (§2).
   - *Validate the schedule map* against A6: it should predict refinements' changes in `J`.
   - *Validate the time map* against a step-halving run.
6. **The controller, schedule side** (§3). Benchmark against uniform ladders on the fixture, then the scenario bank.
7. **The stepper: the prototype driven from R, then odelia's tableau stepper and stiff block, then TF24's wiring** (stepper scope §4–5). The handover's test 3.
8. **The controller, time side, and its optimisation policy.** The handover's test 4 across the 11 points of `perf-across-theta.md`, and then a second consult framed around the family of records.
