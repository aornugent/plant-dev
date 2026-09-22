# Discretisation error of the gradient under node refinement

TF24 SCM, one species, `lma = 0.0825`, `max_patch_lifetime = 5`, optimised `-O2`
build, `TESTTHAT_PARALLEL = false`, serial inside each run and four runs at a
time. `J = sum(scm$offspring_production)`. **No code under `plant/` or `odelia/`
was changed**; both trees are clean at `claude/trusting-curie-4i9n3l`
(`5321593a` / `be3e2cb`), so the `make test-cpp` / fast-sweep guard did not apply.

**Completed:** `constant 3.0`, `mixed-ordinary` and `moist-drizzle` on the full
design, plus coarsened-schedule order studies on `constant 3.0` and
`mixed-ordinary`.
**Missing:** `moist-storms` and `moist-drought` were queued and stopped unrun, and
`ge_supp.R` (the tolerance reference and the lifetime-10 check) was never started.
See *What is missing* at the end.

---

## Answers

**1. Order of `dJ/dtheta` versus order of `J`: the same (~2) under single-branch
forcing; about half an order lower under branch co-occurrence.**
Measured where there is enough error to see it — on a schedule coarsened below the
default as well as refined above it (12, 23, 45, 88, 175, 349, 697 nodes, one
shared time grid). Constant forcing, error against the Richardson limit / the
697-node gradient:

| nodes | `J` | error in `J` | falls by | `dJ/dlma` (d=1e-3) | error in `dJ/dlma` | falls by |
|---|---|---|---|---|---|---|
| 12 | 6.2311796e-07 | -34.890% | — | -3.5116353e-05 | +35.894% | — |
| 23 | 8.2581225e-07 | -13.710% | 2.54 | -4.7341622e-05 | +13.576% | 2.64 |
| 45 | 9.1760847e-07 | -4.118% | 3.33 | -5.2587401e-05 | +4.000% | 3.39 |
| **88 (default)** | 9.4676904e-07 | **-1.071%** | 3.84 | -5.4081812e-05 | **+1.271%** | 3.15 |
| 175 | 9.5439192e-07 | -0.275% | 3.90 | -5.4745843e-05 | +0.059% | 21.5 |
| 349 | 9.5637064e-07 | -0.068% | 4.05 | -5.4725410e-05 | +0.097% | 0.61 |
| 697 | 9.5685759e-07 | -0.017% | 4.00 | -5.4778253e-05 | 0 | — |

The value's error falls by 2.54, 3.33, 3.84, 3.90, 4.05, 4.00 per halving —
converging on 4, i.e. **order 2**, which is what the trapezium rule
(`util::trapezium`, `plant/inst/include/plant/patch.h:912`) should give. **Over the
range where the gradient's error is above the finite difference's own noise floor
— 12 to 88 nodes — it falls by 2.64, 3.39, 3.15, matching the value's 2.54, 3.33,
3.84.** Past 88 nodes the gradient's error is already 0.06–0.24%, at or under the
scatter of the difference itself, and the ratios (21.5, 0.61) are noise.

So under constant forcing **the gradient converges at the value's order**. Two
independent readings agree: `dJ/drho` on the refining levels gives order
**2.00 / 2.41** monotonically, and the reverse-mode adjoint of the census metrics
(no finite difference in it at all) gives **1.68–1.78** for the gradients against
**1.68–1.76** for the values they differentiate.

**Under mixed forcing it does not, and that is the one place the brief's
expectation is borne out.** The same coarsened study on `mixed-ordinary` (14%
branch co-occurrence), error against the 349-node values:

| nodes | `J` | error in `J` | falls by | `dJ/dlma` (d=1e-3) | error | falls by |
|---|---|---|---|---|---|---|
| 12 | 8.044008e-11 | +9.525% | — | -3.54428e-09 | -8.933% | — |
| 23 | 7.538850e-11 | +2.647% | 3.60 | -3.36938e-09 | -3.558% | 2.51 |
| 45 | 7.396916e-11 | +0.715% | 3.70 | -3.29858e-09 | -1.381% | 2.58 |
| **88 (default)** | 7.362407e-11 | **+0.245%** | 2.92 | -3.28691e-09 | **-1.023%** | 1.35 |
| 175 | 7.356418e-11 | +0.163% | 1.50 | -3.27568e-09 | -0.678% | 1.51 |
| 349 | 7.344439e-11 | 0 | — | -3.25363e-09 | 0 | — |

The value falls by 3.60 and 3.70 per halving (**order ~1.87**) before it reaches
its floor; the gradient falls by 2.51 and 2.58 (**order ~1.34**). **The gradient is
about half an order slower than the value here.** The two coarsest gradient errors
(8.9%, 3.6%) are far enough above the reference's own uncertainty (~0.3%, from
`g(349)` against `g(697)` in the refining study) that the first ratio is
trustworthy; the ratios past 45 nodes are not, and the `d = 1e-4` column of the
same table is non-monotone and should not be read at all.

What is **not** estimable is an order from the refining levels alone (88 → 697),
which is what the brief asked for and what the first three designs attempted. There
the gradient's error is 1.3% at the default and 0.06% one halving later; the
difference's own scatter is 0.3–0.9%. Three of the five per-window estimates in
that range come out as 5.02, -1.37, -0.87. **A line through those would be a line
through noise and this note does not fit one.**

**2. The gradient's error at the default node count: about 1%, the same size as the
value's.**

| forcing | co-occurrence | error in `J` at 88 nodes | error in `dJ/dlma` at 88 nodes | FD scatter at 88 nodes |
|---|---|---|---|---|
| `constant 3.0` | 0.00% | **-1.07%** | **+1.27%** (d=1e-3), +0.24% (d=1e-4) | 0.88% over 3 steps |
| `moist-drizzle` | 2.64% | **-0.86%** | **+0.88%** (mean of the two widest steps) | 1.90% over 3 steps |
| `mixed-ordinary` | 13.97% | **+0.24%** | **-0.33%** (d=1e-3), +0.10% (d=1e-4) | 0.24% over two steps |

`dJ/drho` at the default schedule under constant forcing: **-1.09%**.
Take **~1%** as the number, and note it cannot be pinned tighter than about ±0.5%
by finite differences, because at a single node level the three difference steps
disagree by 0.24–1.90%.

**3. Branch co-occurrence: it lowers the gradient's convergence order without
raising its error, and it changes which discretisation is binding.** At 0%
co-occurrence the gradient converges at the value's order (~1.9 both); at 14% the
value still converges at ~1.87 and the gradient at ~1.34. The *size* of the node
error at the default schedule nonetheless goes **down** with co-occurrence (1.07%
-> 0.24% for `J`, 1.27% -> 1.02% for `dJ/dlma`), because the fitness integrand has
less left to resolve late in a run where the stand is collapsing. What
co-occurrence makes much worse is the time grid, not the quadrature. Full answer
under Q3.

**4. The reverse-mode adjoint is reachable from R, but not for this `J`.** Full
answer under *Is the adjoint reachable*.

---

## Why four designs — what each one assumed that was false

The brief's plan was: freeze the ODE step program, refine the node grid, watch `J`
and `dJ/dtheta`. Three of the four designs below are that plan; each failed for a
different reason and the reasons are the substance of this note.

### Design 1 — capture the program at the default node level, replay it at every level

**Assumed:** a program captured once is a valid time grid at any node count.
**False.** The 88-node program replayed at 175 nodes gives `J = 7.81e-07` against
`9.54e-07` — **18% wrong** — while being correct to 1e-5 at 349 and 697 nodes. The
per-level gradients at 175 nodes come out positive (`+9.94e-04` against a true
`-5.47e-05`). `ge_level.R` / `ge_constant.log`.

### Design 2 — capture at the finest node level, replay everywhere

**Assumed:** the failure in (1) was coarseness, so capture from the finest run.
This one does deliver a literally identical time grid — node levels are nested
bisections, so the 697-node run stops at every coarser level's introduction times,
and all four levels then walk **exactly the same 1082 times** (verified, 0 missing
at every level). **Still false.** `J` at 88 nodes is `8.42e-07` against `9.47e-07`
— **11% wrong** — and at 175 nodes `8.49e-07` against `9.54e-07`. Step-size
statistics are not the explanation: the maximum step in each time window is within
a factor of 1.5 of the adaptive run's at every level (`ge_stepdist.R`). This is the
bimodal step-*placement* failure `spike-fixed-grid.md` documents — a discrete event
flipping, not truncation error growing. `ge_verify.R`.

### Design 3 — the union of all four levels' accepted programs

**Works.** It holds every level's introduction times (so every level walks the same
set of times) and is at least as fine as each level's own accepted program (so no
level is integrated more coarsely than its own controller asked for). It reproduces
each level's adaptive answer to 1e-6–3e-5 under constant forcing and gives a
monotone second-order series. Cost: 2449–3032 steps against the adaptive 532–1082,
and 7278–11613 steps under mixed forcing.

**But it exposed the real obstacle, which is the brief's failure mode (a).** With
the time grid finally pinned, the node error at the default schedule turns out to
be ~1%, and one bisection takes it to 0.27%. The central difference's own scatter
across `d` in {1e-3, 1e-4, 1e-5} at a single node level is 0.24–1.90%. **The signal
and the noise are the same size**, so no order can be read from levels 88 → 697.
This is not a plateau failure in the sense the brief feared — a plateau does exist,
and it is wider than the prior spike's, 0.24–0.9% under constant forcing — it is
that the quantity being measured shrank below it after one refinement.

### Design 4 — coarsen the schedule as well as refine it

**The fix, and it is cheap.** Take every other introduction three times (88 → 45 →
23 → 12) and run those on the same union grid — coarse levels' times are a subset
of the default's, which is a subset of the union, so the shared-grid property still
holds and coarse runs are fast (fewer cohorts). The error at 12 nodes is 35%, four
halvings above the noise floor, and the decay ratios in the table under Answer 1
are then readable. **This is what the order in Answer 1 rests on.**

### On failure mode (b) — is a gradient measurable on a near-extinct `J`?

The brief's worry was that four of six mixed records sit at `J` between 4.3e-11 and
7.5e-10 where a prior agent found the node-count error to be 16–31% and
non-convergent. **Measured here, that reading was the time grid, not the node
grid.** Under `mixed-ordinary` at the default 88-node schedule:

- adaptive time grid, `ode_tol = 1e-4`: `J = 1.77e-10`;
- union time grid (4.3x the steps): `J = 7.36e-11`;
- union grid at 697 nodes: `J = 7.34e-11`.

The default adaptive answer is **142% high**, and the *node*-grid error at the same
schedule is **0.24%**. Refining the node grid does repair the adaptive number — 88
→ 175 moves it from 1.77e-10 to 7.33e-11 — but as a side effect of forcing more
ODE stops (1725 → 1845 steps), not as quadrature convergence. So the prior "16–31%
and non-convergent" is reproduced and re-attributed: **it is the ODE tolerance
under intermittent forcing, exactly as `diag-schedule-refinement.md` concluded, and
not the cohort count.**

Given that, is a relative error on 7.3e-11 meaningful? **As a discretisation
statement, yes**: the union-grid series is smooth, its successive changes are
-0.08%, -0.16%, +0.002%, and its finite difference has a 0.04–0.24% plateau. The
number is well resolved. **As an optimiser-relevant statement, no** — `J << 1`
everywhere here, so nothing measured is a self-replacing stand. That is
`max_patch_lifetime = 5`, not the forcing; see *What would actually work*.

---

## Method

### Node levels

The default schedule at lifetime 5 is **88 times** on a dyadic staircase —
`dt = 2^floor(log2(0.2 t))` clamped to `[1e-5, 2]` (`plant/src/scm_utils.cpp:6`) —
so spacing runs from `1e-5` near `t = 0` to about 1 year near `t = 5`. Refining
bisects every interval; coarsening takes every other introduction and keeps the
endpoint. Levels are nested, which is what makes one shared time grid possible:
**12, 23, 45, 88, 175, 349, 697**.

### Holding the time grid fixed — what was actually done, and what it means

`J` is a quadrature over the node grid *and* the endpoint of a time integration,
and the run stops at every introduction, so **refining the nodes refines the time
grid whether or not you want it to**. The time grid cannot be held fixed by fiat.
What was done is design 3 above: one program, the union of every level's accepted
program, replayed by its times (`set_ode_steps(times, numeric(0))`, the times form,
per `spike-fixed-grid.md`). Every level walks the same set of times and no level is
integrated more coarsely than its controller asked for.

**What it means:** the `union` rows below isolate the node grid as nearly as this
model permits, at 2.5–4.5x the ODE cost. The `adaptive` rows are what a caller gets
today, where the two errors move together. Where they disagree the disagreement is
reported rather than averaged.

### The gradient

Central difference in a relative step,
`(J(theta0(1+d)) - J(theta0(1-d))) / (2 d theta0)`, at `d` in {1e-3, 1e-4, 1e-5}.
Three steps per level, so the plateau is measured at each level rather than
assumed — and it is not the same everywhere. Under constant forcing all three lie
within 0.31–0.88% of each other at every level. Under mixed forcing `d = 1e-5` is
already through the model's own solver-noise floor (it moves `dJ/dlma` by up to
33%); over {1e-3, 1e-4} the spread is 0.04–0.24%. **The usable range of difference
steps is forcing-dependent and has to be measured per forcing.**

### Is the adjoint reachable from R for `dJ/dtheta`? Reachable — but not for this `J`.

Reverse mode **is** exposed and does answer: `stand_gradient(scm)`
(`plant/R/stand_gradient.R:99`) -> `census_trait_gradient_tf24`
(`plant/src/census_gradient.cpp:81`) -> `SCM::census_trait_gradient` -> odelia's
`solve_adjoint` (`odelia/inst/include/odelia/ode_solver.hpp:347`) and `sweep.hpp`.
It is used in the tables below.

It does **not** answer for `J = sum(offspring_production)`. The only seeds that
cross the R boundary are the three registered census metrics — `leaf_area`,
`mass_above_ground`, `area_stem`
(`plant/inst/include/plant/models/tf24_strategy.h:787`), seeded by
`census_state_adjoint_tf24`. `census_trait_gradient_tf24` takes metric *names*, not
a seed vector; the one entry point that does take a seed
(`ladder_rhs_adjoint_tf24`, `plant/src/gradient_ladder.cpp:491`) transposes a single
right-hand-side evaluation on a `Patch`, not a trajectory. Nothing else in
`NAMESPACE` exposes a sweep.

**The gap is small and well defined rather than fundamental.** Offspring production
*is* a linear functional of the terminal ODE state: each node carries
`offspring_produced_survival_weighted` as an ODE state
(`plant/inst/include/plant/node.h:37, 156, 325`), and `Patch::offspring_production`
is a trapezium of that state times `patch_density_at_birth * S_D *
birth_rate(t_i)` over the node times (`patch.h:903`). The same sweep would carry it
if a seed existed for it. Two constraints a caller would inherit: the sweep refuses
unless `control$node_density_in_birth_date = TRUE` ("the reverse-mode gradient runs
on the birth-date size-density coordinate only"), which is a *different*
discretisation of the stand from the height-coordinate runs used everywhere else
here; and it consumes the run's recording.

**So `dJ/dtheta` is finite differences alone in this note.** The adjoint is reported
beside it as an independent, finite-difference-free measurement of how the gradient
of a node-grid trapezium converges.

### Forcing

Not constant-for-a-run. `probe7_rain.R`'s seasonal two-state Markov chain with
gamma depths, extended two ways (`ge_rain.R`): an **interannual multiplier**, so a
record carries drought years and wet years rather than one stationary climate; and
occurrence/amount parameter sets that trade **event size against event count** at a
comparable annual total. Depths are then scaled to a stated daily mean so a storm
record and a drizzle record are comparable. Six years of daily values.

| record | mean mm/d | annual totals (mm) | wet days | mean wet-day | max daily | top 5% of days deliver | longest dry run |
|---|---|---|---|---|---|---|---|
| `constant 3.0` | 3.0 | 1095 x6 | 100% | 3.0 | 3.0 | 5% | 0 d |
| `moist-drizzle` | 5.0 | 2062 1379 2279 1380 2381 1468 | 30% | 16.8 | 68 | **35%** | 35 d |
| `moist-storms` | 5.0 | 1997 1666 2061 1504 2126 1595 | 25% | 20.2 | 154 | **61%** | 47 d |
| `moist-drought` | 5.0 | 2171 2297 **814 772** 2891 2005 | 23% | 21.4 | 215 | **68%** | 73 d |
| `mixed-ordinary` | 3.0 | 1434 978 1487 691 1437 543 | 11% | 28.0 | 281 | **86%** | 130 d |

`moist-drizzle` and `moist-storms` share an occurrence pattern, an interannual
multiplier and an annual total and differ only in how depth is delivered — the
storm/drizzle contrast at matched totals. `moist-drought` carries a two-year
drought. `mixed-ordinary` is seasonal weather with large storms in it.
`constant 3.0` is the sanity reference only.

**A confound that could not be designed away.** At lifetime 5, stand viability and
branch co-occurrence are the same axis. Every record measured
(`ge_probe.R`, `ge_scale.R`, `ge_moist.R`) falls on one monotone line:

| record | longest dry run | non-interior solves | `J` at 88 nodes |
|---|---|---|---|
| `constant 3.0` | 0 d | **0.00%** | 9.47e-07 |
| `moist-drizzle` | 35 d | 2.64% | 8.30e-08 |
| `moist-storms` | 47 d | 6.1% | 3.0e-09 |
| `moist-drought` | 73 d | 7.3% | 9.0e-10 |
| `mixed-ordinary` | 130 d | **13.97%** | 7.36e-11 |
| (dropped) `storms-swing` | 208 d | 22.6% | 1.8e-12 |

Raising the annual total does not break the link: `storms-drought` at 3.0, 4.5, 6.0
and 8.0 mm/d gives `J` = 2.4e-12, 5.0e-12, 4.5e-12, 3.6e-12. **Intermittency, not
total, is what empties the stand**, so a cell with 25%+ co-occurrence and a viable
stand does not exist at lifetime 5. The two records above 20% were dropped on the
extinction rule rather than measured.

---

## Q1 — the observed order, in full

### constant 3.0 (0% co-occurrence)

Value, refining levels only:

| grid | 88 | 175 | 349 | 697 | order | Richardson limit | error at 88 |
|---|---|---|---|---|---|---|---|
| adaptive | 9.46742769e-07 | 9.54409969e-07 | 9.56369253e-07 | 9.56861207e-07 | **1.97 / 1.99** | 9.57025e-07 | **-1.074%** |
| union | 9.46769039e-07 | 9.54391917e-07 | 9.56370639e-07 | 9.56857593e-07 | **1.95 / 2.02** | 9.57020e-07 | **-1.071%** |

Adding the coarsened levels (the table under Answer 1) extends this to
1.14, 1.65, 1.94, 1.95, 2.02 — the order climbing to 2 as the asymptotic regime is
entered, which is the shape a genuine second-order method has on a non-uniform grid.

`dJ/dlma` on the union grid, refining levels:

| nodes | d=1e-3 | d=1e-4 | d=1e-5 | spread |
|---|---|---|---|---|
| 88 | -5.4081812e-05 | -5.4505079e-05 | -5.4560314e-05 | 0.88% |
| 175 | -5.4745843e-05 | -5.4753578e-05 | -5.4915189e-05 | 0.31% |
| 349 | -5.4725410e-05 | -5.4712085e-05 | -5.5087228e-05 | 0.69% |
| 697 | -5.4778253e-05 | -5.4636414e-05 | -5.4938118e-05 | 0.55% |

Level-to-level moves at `d = 1e-4`: -0.45%, +0.08%, +0.14%, against a per-level
scatter of 0.31–0.88%. **Not estimable from these four levels** — the per-window
estimates are 5.02/-1.37 (d=1e-3), 2.58/-0.87 (d=1e-4), 1.04/0.21 (d=1e-5), which
is three answers to a question with one. The same difference taken on the *adaptive*
grid scatters by 3.3–40.3% across steps and is useless for anything.

`dJ/drho`, union grid, `d = 1e-3` — quiet enough to carry an order:

| nodes | value | successive difference |
|---|---|---|
| 88 | -4.5387228e-08 | — |
| 175 | -4.5774424e-08 | -3.872e-10 |
| 349 | -4.5871301e-08 | -9.688e-11 |
| 697 | -4.5889583e-08 | -1.828e-11 |

Ratios 4.00 and 5.30: **order 2.00 / 2.41**, monotone, error at 88 nodes **-1.09%**.
(One difference step only, so its plateau was not verified.)

Reverse-mode adjoint, census metrics, birth-date coordinate — no finite difference
anywhere in it:

| quantity | 88 | 175 | 349 | 697 | order | error at 88 |
|---|---|---|---|---|---|---|
| `leaf_area` | 4.3294719 | 4.3282036 | 4.3278210 | 4.3277155 | 1.73 / 1.86 | **+0.041%** |
| `d/dlma` | -19.210414 | -19.557835 | -19.664179 | -19.677344 | 1.71 / 3.01 | **+2.395%** |
| `d/drho` | -4.0253e-04 | -5.2821e-04 | -5.6593e-04 | -5.7094e-04 | 1.74 / 2.91 | **+29.70%** |
| `d/dhmat` | 3.8096e-04 | 3.8212e-04 | 3.8237e-04 | 3.8237e-04 | 2.24 / 7.98 | -0.368% |
| `mass_above_ground` | 9.6699473 | 9.6674165 | 9.6666681 | 9.6664601 | 1.76 / 1.85 | **+0.037%** |
| `d/dlma` | -94.115727 | -94.768962 | -94.972334 | -94.993163 | 1.68 / 3.29 | **+0.931%** |
| `d/drho` | **+1.9757e-04** | -4.4059e-05 | -1.1769e-04 | -1.2634e-04 | 1.71 / 3.09 | **+252.9%, sign wrong** |
| `d/dhmat` | 1.0643863e-03 | 1.0673362e-03 | 1.0679695e-03 | 1.0679909e-03 | 2.22 / 4.89 | -0.338% |
| `area_stem` | 1.3822602e-03 | 1.3818144e-03 | 1.3816755e-03 | 1.3816379e-03 | 1.68 / 1.88 | **+0.046%** |
| `d/dlma` | -6.5322913e-03 | -6.6568769e-03 | -6.6938337e-03 | -6.6993335e-03 | 1.75 / 2.75 | **+2.520%** |
| `d/drho` | -1.3273e-07 | -1.7769e-07 | -1.9081e-07 | -1.9286e-07 | 1.78 / 2.68 | **+31.42%** |
| `d/dhmat` | 9.5043e-08 | 9.5380e-08 | 9.5456e-08 | 9.5459e-08 | 2.16 / 4.50 | -0.437% |

**The order is the same for a value and its gradient — 1.68–1.78 on the first
step for both — and the error constant is not.** The census values are converged to
0.04% at the default schedule while their `lma` gradients are off by 0.9–2.5% (20
to 60 times worse) and their `rho` gradients by 30–250%, one of them with the
**wrong sign**. A functional being well converged says nothing about its gradient
being well converged.

For `J` itself the two errors happen to be the same size (1.07% and 1.27%). That is
a property of this functional and this trait, not a rule: it holds when the error
constant has about the same relative sensitivity to `theta` as `J` does, which is
true for `lma` here and badly false for `rho` on the census metrics.

### moist-drizzle (2.64% co-occurrence)

| grid | 88 | 175 | 349 | 697 | order | error at 88 |
|---|---|---|---|---|---|---|
| adaptive | 7.98852730e-08 | 8.07759999e-08 | 8.35391724e-08 | 8.08117072e-08 | non-monotone | — |
| union | 8.30212011e-08 | 8.35441347e-08 | 8.37004814e-08 | 8.37334208e-08 | **1.74 / 2.25** | **-0.864%** |

`dJ/dlma`, union grid:

| nodes | d=1e-3 | d=1e-4 | d=1e-5 | spread (3) | spread (2 widest) |
|---|---|---|---|---|---|
| 88 | -4.2494864e-06 | -4.3310992e-06 | -4.3126078e-06 | 1.89% | 1.90% |
| 175 | -4.3058263e-06 | -4.3355309e-06 | -4.3489884e-06 | 1.00% | 0.69% |
| 349 | -4.2897441e-06 | -4.3405145e-06 | -4.4021779e-06 | 2.59% | 1.18% |
| 697 | -4.3119906e-06 | -4.3444710e-06 | -4.3633092e-06 | 1.18% | 0.75% |

Error at 88 nodes: **+1.62%** (d=1e-3), +0.34% (d=1e-4), +0.88% (mean of the two
widest). Order not estimable (level-to-level moves are -0.10%, -0.11%, -0.09% at
d=1e-4, below the 0.69–1.90% scatter and not decaying).

The adjoint under this forcing is **not** a node measurement: its value sequence
for `leaf_area` is 4.24778, 4.24356, 4.24249, 4.24229 (order 1.97 / 2.45, fine) but
its `d/dlma` sequence is -19.055, -18.948, -18.885, -18.818 with differences
+0.107, +0.063, +0.067 — not decaying at all. The adjoint runs on the adaptive
grid, and that grid is non-monotone in `J` under this forcing (7.99, 8.08, 8.35,
8.08 x1e-8). **The adjoint's order is readable only where the adaptive time grid is
converged, i.e. under constant forcing.**

### mixed-ordinary (13.97% co-occurrence)

| grid | 88 | 175 | 349 | 697 | error at 88 |
|---|---|---|---|---|---|
| adaptive | **1.77114282e-10** | 7.32716266e-11 | 7.35735559e-11 | 7.33373891e-11 | **+141.8%** |
| union | 7.36044830e-11 | 7.35463977e-11 | 7.34278378e-11 | 7.34294898e-11 | **+0.238%** |

`dJ/dlma`, union grid (`d = 1e-5` is through the noise floor here and is shown for
completeness only):

| nodes | d=1e-3 | d=1e-4 | d=1e-5 | spread (2 widest) |
|---|---|---|---|---|
| 88 | -3.2738507e-09 | -3.2659412e-09 | -2.9991648e-09 | 0.24% |
| 175 | -3.2692641e-09 | -3.2663645e-09 | -3.5165890e-09 | 0.09% |
| 349 | -3.2534252e-09 | -3.2522270e-09 | -2.1929479e-09 | 0.04% |
| 697 | -3.2632056e-09 | -3.2692246e-09 | -3.3543022e-09 | 0.18% |

Error at 88 nodes **-0.33%** (d=1e-3) / **+0.10%** (d=1e-4). Level-to-level moves
+0.14%, +0.49%, -0.30% — non-monotone and the size of the scatter. **No order
estimable: there is no error left to halve.** The adjoint under this forcing swings
by 13–43% between levels and is not a node measurement either.

---

## Q2 — the gradient's error at the default node count, in full

See the table under Answer 2. Restated as a design fact:

- **~1%** under low co-occurrence forcing, **~0.3%** under high, for both `J` and
  `dJ/dlma`, once the time grid is pinned to a refinement of every level's
  requirement (2.5–4.5x the ODE steps).
- **Not** what a caller gets today. On the default adaptive grid under mixed
  forcing `J` at 88 nodes is 142% wrong; under constant forcing the same central
  difference scatters 3.3–40.3% across difference steps.
- **Not** transferable to another functional of the same stand: the same schedule
  carries 0.04% error in a census value and 0.9–2.5% in that value's `lma`
  gradient.

---

## Q3 — does branch co-occurrence change the answer?

| forcing | non-interior | node error in `J` at 88 | node error in `dJ/dlma` at 88 | usable difference steps |
|---|---|---|---|---|
| `constant 3.0` | 0.00% | -1.07% | +1.27% | 1e-3, 1e-4, 1e-5 |
| `moist-drizzle` | 2.64% | -0.86% | +1.62% | 1e-3, 1e-4, 1e-5 (spread 1.9%) |
| `mixed-ordinary` | 13.97% | +0.24% | -0.33% (vs 697 nodes) / -1.02% (vs 349, coarsened study) | 1e-3, 1e-4 only |

**On the size of the node error: no — and if anything the opposite.** The forcing
with 14% co-occurrence has a *smaller* node-grid error in both the value and the
gradient than the single-branch forcing. The default dyadic schedule is coarse late
in the run (~1 year spacing near `t = 5`); under constant forcing the fitness
integrand still has structure there worth resolving, whereas under intermittent
forcing the late cohorts contribute almost nothing and the trapezium has little
left to get wrong.

**On the order: yes, and this is the clearest difference between the two
regimes.** From the coarsened studies, over the levels where both quantities are
above their floors:

| forcing | co-occurrence | value error falls by | value order | gradient error falls by | gradient order |
|---|---|---|---|---|---|
| `constant 3.0` | 0.00% | 2.54, 3.33, 3.84 | ~1.9 | 2.64, 3.39, 3.15 | ~1.8 |
| `mixed-ordinary` | 13.97% | 3.60, 3.70 | ~1.87 | 2.51, 2.58 | ~1.34 |

At 0% co-occurrence the gradient tracks the value halving for halving. At 14% the
value keeps its second order and the gradient loses about half an order. The
practical consequence is the opposite of alarming and worth stating plainly:
because the gradient's error at the default schedule is *smaller* under mixed
forcing to begin with (1.02% against 1.27%), a slower order costs little here — but
it means refining the schedule buys less under co-occurrence than the value's
behaviour would suggest.

**On the time grid: yes, decisively.** Co-occurrence travels with intermittency and
intermittency is what breaks the default ODE tolerance. At 88 nodes under
`mixed-ordinary` the adaptive answer is 142% high; the equivalent comparison under
constant forcing is within 1e-5. **What co-occurrence changes is which
discretisation is binding, not how large the quadrature error is.**

**On the finite difference: yes.** The usable range of difference steps narrows from
two decades to one — `d = 1e-5` is through the floor under mixed forcing (it moves
`dJ/dlma` by up to 33%) while it is on the plateau under constant forcing. Any
automated step-size rule has to measure that per forcing.

One caveat on the reach of this answer: the three completed records span 0% to 14%
co-occurrence. The prior 28–31% figure lives in records whose `J` is 1e-12, which
were dropped on the extinction rule. **Nothing here measures a stand with 25%+
co-occurrence, and nothing here should be extrapolated to one.**

---

## What would actually work — a concrete follow-up

The fixture is the limitation, not the method. In order of expected value:

1. **Raise `max_patch_lifetime` well above 5, and pick a trait value that gives a
   self-replacing stand.** This is the single change that fixes most of the
   objections. At lifetime 5 every `J` measured is 1e-7 to 1e-11, and the cohorts
   that matter are all in the first year — which is exactly where the default
   dyadic schedule is finest, so the measurement is taken in the least interesting
   part of the grid. A lifetime of 30–50 (not the full 105.32, which is unaffordable
   at this cadence) with `lma` chosen so `J ~ O(1)` would put the quadrature error
   where the biology is and make "0.3% of `J`" mean something to an optimiser.
   A lifetime-10 spot check is scripted in `ge_supp.R` and was not run.

2. **Add one census metric for offspring production and read `dJ/dtheta` off the
   adjoint.** The plumbing is already there — `offspring_produced_survival_weighted`
   is an ODE state and `Patch::offspring_production` is a linear functional of the
   terminal state — and only the seed is missing. That removes the finite
   difference entirely, and with it the 0.24–1.90% scatter that is the binding
   constraint on every order estimate in this note. It would also make the
   measurement 6x cheaper (one sweep instead of six runs per level).
   The two constraints to design around: the sweep requires
   `node_density_in_birth_date = TRUE`, and it consumes the recording.

3. **Coarsen as well as refine, always.** The order in Answer 1 is only readable
   because the schedule was coarsened to 12 nodes. Refining from an already-converged
   default cannot produce a convergence order in any quantity whose error is near
   the measurement noise, and this is generic rather than specific to this fixture.

4. **Tighten `ode_tol` before measuring anything under intermittent forcing.** The
   142% adaptive error at the default schedule is a tolerance problem. Repeating any
   of the above at `ode_tol = 1e-6` under mixed forcing would separate the two
   errors without needing a pinned grid at all — and would cost less than the union
   grid does (the union runs at 4.3x the adaptive steps).

5. **Only then go after 25%+ branch co-occurrence.** With a longer lifetime, a
   record with months-long dry spells may leave a viable stand, which is what a
   co-occurrence cell needs to be worth measuring. At lifetime 5 that cell does not
   exist.

---

## What is missing, and other caveats

- **`moist-storms` and `moist-drought` were queued and stopped unrun.** The
  storm/drizzle contrast at matched annual totals is therefore half-measured:
  `moist-drizzle` is complete, `moist-storms` is not. Their branch shares (6.1% and
  7.3%) and `J` (3.0e-09, 9.0e-10) are known from `ge_probe.R` / `ge_moist.R` only.
- **The coarsened `mixed-ordinary` study stops at 349 nodes**, not 697, to fit the
  time available. Its gradient reference `g(349)` therefore carries about 0.3%
  uncertainty (measured as `g(349)` against `g(697)` in the refining study), which
  is why only the first of its decay ratios is quoted as trustworthy.
- **The order difference between the two regimes rests on one scenario each, one
  trait and one difference step.** It is a signal worth following up, not a
  measured law.
- **`ge_supp.R` was not run**: the `ode_tol` 1e-4 vs 1e-6 reference check per
  scenario, and the lifetime-10 comparison.
- **Wall times are contended** (a second workload shared the four cores for part of
  the session) and are ratios at best. Step counts, node counts, `J` and gradients
  are exact.
- **No jointly converged reference exists under mixed forcing.** The union grid is a
  refinement of four `ode_tol = 1e-4` runs and is self-consistent to 0.2%; it is not
  a proof of convergence to the continuum.
- **The adjoint runs on the birth-date coordinate**, the finite differences on
  height. They are two measurements of the same question, not a cross-check of the
  same numbers.
- **One difference step only for `dJ/drho`**, so its plateau was not verified.

## Scripts

All in this directory, all runnable as `Rscript <file> [scenario] [...]`:

| file | what |
|---|---|
| `ge_rain.R` | the forcing generator and the four mixed records |
| `ge_common.R` | SCM construction, node levels, central differences, order estimates, branch census |
| `ge_level3.R` | the per-scenario sweep on the union grid (`ge3_*.rds`) |
| `ge_coarse.R` | the same on coarsened as well as refined levels (`gec_*.rds`) — **this is the script that makes an order readable** |
| `ge_report3.R` | `ge3_*.rds` -> the tables above |
| `ge_supp.R` | ODE-reference check and lifetime 10 (not run) |
| `ge_probe.R`, `ge_scale.R`, `ge_moist.R` | forcing selection: `J` and branch shares |
| `ge_verify.R`, `ge_stepdist.R` | the two failed fixed-grid designs |
| `ge_level.R`, `ge_level2.R` | designs 1 and 2, kept because their failures are results |
