# Where the reverse pass spends, how to find out, and what is left

The reverse-mode stand gradient costs **14.1 times** a plain double forward run at
century scale — 463 s against 33.0 s, on a refiner-chosen schedule of 165 nodes
and 3197 steps. This states the method that locates that cost correctly, the
principles that decide which lever to reach for, and the levers that remain.

It is not a record of what was tried. Where a route is listed as closed, the
reason is a property of the model and is stated as one.

---

## 1. The instrument

**Three measurements, and any two of them will mislead you.**

| | answers | fails alone because |
|---|---|---|
| **structure** | what phases exist and what each calls | says nothing about how often or how dear |
| **count** | how many times each phase runs each primitive | unit costs differ by more than an order of magnitude |
| **cost** | what one call of a primitive costs | `-O2` inlining collapses frames, so attribution lies |

**share = count × price.** Rank by share, never by count and never by a profile's
own attribution.

The two failures this rule exists to prevent are both live in this model:

- **An active field build costs 26× a passive one.** By count the passive builds
  dominate (19,548 against 7,704); by share they are 2.5 per cent against 25.8.
  A count-ranked table puts the effort in exactly the wrong place.
- **A block recording costs 11× a plain leaf solve.** The reverse pass performs
  55,821 plain solves against 26,028 recordings — 3:1 by count, 1:5 by share.

### The procedure

1. **Read the control flow and name the phases.** The boundaries are where a
   distinct piece of work begins, not where a file begins.
2. **Tag each phase with an RAII scope** that sets a thread-global phase id and
   restores the enclosing one, so a nested phase does not leak into its parent.
   Put the scope on the *function definition*, never on a text pattern — two
   functions in this file open with identical lines.
3. **Count the expensive primitives per phase**, not per call site: the leaf's
   collar solve, the field build, the boundary evaluation, and the rate function
   split by scalar type. Counts have no variance; they need one run, not five.
4. **Price each primitive** from a sampling profile, or from a controlled A/B
   that removes a known number of them.
5. **Predict a lever's share before building it**, then hold the built lever to
   that prediction. A lever that returns a quarter of its projection has a wrong
   cost model behind it, and the model is the thing to fix.

### Four guards, each of which silently voids a measurement

**A no-op passes every correctness check.** A concept that is ill-formed
evaluates false, `if constexpr` takes the other branch, and the change never
runs — bit-identical, and worthless. Assert the path is live: a `static_assert`
on the concept at the point of use, or a counter that must be non-zero.

**Pin the compiler flags.** `pkgbuild::compile_dll` appends `-O0` unless
`debug = FALSE`, and the last `-O` wins. A user `~/.R/Makevars` setting
`CXXFLAGS` is a latent trap rather than an active one: both packages declare
`CXX_STD = CXX20`, so R uses `CXX20FLAGS` and a bare `CXXFLAGS` override does not
reach them — until someone drops `CXX_STD`, at which point the whole AD stack
silently drops to that setting. Build every arm
through `R_MAKEVARS_USER` with `CXX20FLAGS = -O2 -DNDEBUG -g`, and confirm from
the log that no `-O0` trails the `-O2`. `-g` changes no codegen and is what makes
a profile readable.

**Archive the binary.** `pkgload` copies the built `.so` to a temp directory and
unlinks it at exit, so a profile outlives the binary it names. Copy `plant.so`
aside after each build and resolve the profile against that copy, or the samples
are unresolvable addresses.

**Snapshot the maps before killing a long run.** gperftools writes the
`/proc/self/maps` trailer only at clean exit; a killed run leaves samples with
nothing to resolve them against. `cat /proc/<pid>/maps > file` while it lives and
the partial profile stays readable.

### The build, and the trap in it

```sh
R CMD INSTALL phylloptim                 # plant compiles against the INSTALLED headers
cd plant && rm -f src/*.o src/*.so       # R does not track header dependencies
R_MAKEVARS_USER=<Makevars-O2> \
  Rscript -e 'pkgbuild::compile_dll(".", compile_attributes = FALSE, debug = FALSE)'
```

`plant` links to phylloptim and odelia through `LinkingTo`, so it sees the
**installed** headers and not the working tree. Editing `phylloptim/inst/include`
and rebuilding plant changes nothing until phylloptim is reinstalled, and every
check afterwards passes against the old binary. Load with `library(odelia)` —
never `load_all` — then `pkgload::load_all("plant")`.

Profiling needs no privileges: `perf` is blocked wherever
`kernel.perf_event_paranoid` is above 2, but gperftools' `libprofiler` samples on
`SIGPROF` and works unprivileged. `LD_PRELOAD` it onto **`/usr/lib/R/bin/exec/R`
directly** — via `Rscript` the signal arrives during the exec chain and kills the
process. Set `OPENBLAS_NUM_THREADS=1`; the pthread build's pool spins in
`sched_yield` for about 2.5 per cent of a run that does no BLAS.

### What verifies a change

In increasing order of what it can see. The cheap ones do not substitute.

1. **Bit-identity of the gradient**, for anything that only changes how much is
   computed. `identical()` on the returned object, not a tolerance. This is the
   whole test for a caching, hoisting or deletion change.
2. **The ladder and the FF16 tripwire**, for anything that reassociates. A
   reassociation moves the gradient at round-off and leaves the census value
   exact; ~1e-16 is reassociation, ~1e-9 is the solver floor, ~1e-4 is a real
   difference.
3. **`ladder_run_difference_pair()`** — a difference that rebuilds the strategy
   and re-runs, on a stand where two species compete. The only instrument that
   shares no assumption with the sweep, and the only one that can referee a
   change from differenced to analytic. It carries a step-stability guard because
   a reading taken at an unconverged step is a factor of two out.

A single-species reference is not evidence for anything the competition reaches:
rows six per cent out have agreed with one to `1e-06`.

---

## 2. The principles

Six moves, weakest first. **The first three reduce a cost; the last three remove
one.** Reach right before reaching left.

| | the move | what it needs to be legitimate |
|---|---|---|
| **cache** | same inputs, same answer — keep it | a key covering everything the value depends on, or no cache at all |
| **append** | the new answer is the old plus a term | the term is separable in the arithmetic *as written*, not merely in the algebra |
| **perturb** | the new answer is the old under an identity | the identity must hold for the object evaluated, not the object approximated |
| **avoid** | the call has no consumer | trace every reader; "written and never read" is an observation, not a conclusion |
| **shortcut** | the answer is known without computing it | a declared zero needs a proof and a name, never a silent absence |
| **trim** | the consumer needs less than is produced | enumerate outputs from the consumer's equations, not from what the producer exposes |

**Two rules about which lever is worth pulling.**

**An asymmetric lever beats a symmetric one when the objective is a ratio.** The
target here is grad/run. A change that makes the forward model faster raises the
bar it is measured against: halving a cost the forward also pays moves the ratio
by a fraction of what it moves the absolute time. Rank levers by what they do to
the *reverse pass alone*, then check what they give back to the forward.

**Storage against recomputation is a decision, not a fact.** The per-cohort
decomposition rebuilds rather than stores because storage was the binding
constraint. Where the memory target has headroom, the same tradeoff is worth
re-taking with the numbers in front of you — but price it by share first: the
plain-double work this would remove is 3:1 by count and 1:5 by share.

**And the deepest form of the question is not "how do I compute this faster" but
"what is this a function of".** A quantity constant in time need not be
recomputed per step. A quantity linear in an input need not be re-differentiated.
A quantity the consumer discards need not be produced.

---

## 3. Where the cost is

Counts are from a 20-year fixture (2,214 stages), where the structure is
identical and the run is short enough to instrument; shares are from the century
profile. **Read a small fixture's shares with suspicion.** The field build is
`O(knots x cohorts)`, so at 17 cohorts it is a fifth of what it is at 165: the
same change measured 6 per cent on the fixture and 20 per cent at production.
Anything scaling with cohort count is understated by a short run, and so is the
ratio itself — 12.2x on the fixture against 15.0x at production.

| phase | count | share |
|---|---|---|
| **block recordings** — one per cohort per stage | 18,108 recordings | **58%** |
| **inflow boundary** — one node, per stage | 7,704 recordings | **25%** |
| **trajectory re-run** — a second full forward pass | 28,305 solves | **8%** |
| **stage rebuild** — the plain-double re-derivation | 20,322 solves | **6%** |
| sweep, replay, introductions, census | 7,410 | **~3%** |

Two facts follow that decide everything below.

**The reverse pass is not paying for reverse mode in the way it once did.** The
tape was 0.6 per cent of a block when the leaf's supplied rows were 86 per cent
of it. Those rows have since been cheapened by more than an order of magnitude,
and **XAD's tape machinery is now about 30 per cent of the whole gradient** —
slot pushes 12.2, the adjoint sweep 3.9, register/unregister 3.5, thread-local
tape lookups 3.4, active-value copies 2.3. The old ruling that the tape is not
worth attacking was true of a different cost distribution and is not true now.

**The boundary node is over-weight by a factor of five.** It is one node against
8.2 cohorts per stage and costs 25 per cent against their 58. Nearly all of it is
one thing: rebuilding the light field **at the active scalar**, which the cohort
blocks never do because they take the field as `2K` knot inputs.

---

## 4. What is left

Ranked by share of the reverse pass. Every item here is **asymmetric** — it
touches the reverse pass only — which is what §2 says to rank by.

### 4.0 The disturbance weighting — a map, not a saving

⚠️ **Read this as scenario-specific.** Patch disturbance is one scenario and
no-disturbance runs are also required, so nothing here is a general cost lever.
What it is, is a statement of where a *disturbed* run's answer actually lives.

The census is seeded at `max_patch_lifetime = 105.32` years. The model's own
disturbance regime is Weibull with shape 2 and a mean interval of **30.0 years**,
so survivorship at the seeding age is **6.25e-5**, and:

| patch age | share of disturbance-weighted mass |
|---|---|
| > 50 yr | 3.67% |
| > 70 yr | **0.345%** |
| > 80 yr | 0.083% |

The run's length comes from an `icdf_limit` "chosen to match Falster 2011" — a
tail cutoff, not a requirement on the answer.

**Under that scenario** the disturbance-weighted integral over patch ages is the
object the ecology wants, and for an adjoint it is the same single sweep: inject
`rho(t)·dC/dy` as a per-step source instead of seeding once at `T`. `Patch`
already carries the weighting, so it costs nothing and it changes what the number
*is* rather than how fast it arrives.

It buys run length only where a disturbance regime is in force. **On an
undisturbed run there is no weighting to exploit and the terminal census at the
full lifetime is the object**, so run length stays a modelling choice. Treat this
section as a correctness note for the disturbed scenario, not as a lever.

### 4.0b Build configuration — measured 8.4%, bit-identical

Three flags, no arithmetic change, applied identically to **both** odelia and
plant (a mismatch on the first is a silent storage-class conflict on a symbol
whose mangled name does not change):

```
-DXAD_NO_THREADLOCAL -DXAD_USE_STRONG_INLINE -fno-stack-protector
```

XAD reaches its active tape through a `__thread` variable defined in odelia and
read from plant; because R `dlopen`s odelia that resolves through a
`__tls_get_addr` call on every active value's construction and destruction.
Neither package contains a thread. `XAD_INLINE` is plain `inline` by default, so
the `AReal` copy constructor is emitted out of line; the flag that fixes it is
documented as client-side and carries no ABI hazard. And `xad::DerivInfo` holds
raw C arrays, so `-fstack-protector-strong` puts a canary on essentially every
active assignment.

**These now live in `plant/src/Makevars` and `odelia/src/Makevars`**, so an
ordinary rebuild carries them. They must stay in step: `XAD_NO_THREADLOCAL`
changes the storage class of a symbol whose mangled name does not change, so a
build with the packages disagreeing links and then misbehaves. `XAD_NO_THREADLOCAL`
also forfeits thread safety permanently — correct while neither package contains
a thread, and a thing to revisit if one ever does.

### 4.0c The block registers 130 field inputs and reads one

⚠️ **This is the one lever with no cheap referee.** Its `dR/dh` is a boundary term
plus the quadrature's node motion at an active bound, and report 03 §3.3 records
that a canopy-tied grid puts the tallest cohort's height column beyond what a
difference of the rates can check. Build the transpose-identity check on the
crown-integral map FIRST, and treat a passing stand gradient as necessary rather
than sufficient.


Report 05 §5.2 proves a cohort's whole physiology is driven by a **single**
scalar derived from the field. That rank-one collapse is exploited in the
algebra and **not at the tape boundary**: the recording still registers all `2K`
knot values and slopes and records the 21-point crown quadrature.

Register the one scalar instead and supply `dR/dLambda` analytically — Hermite
basis times the fixed quadrature weights times the crown kernel, at most `2(n+1)`
non-zeros by report 03 §3.1. Block inputs go **185 to 59**, on every recording,
and the block's cost stops scaling with knot count.

The exposure is `dR/dh`: the integration bound is active, so the row carries a
boundary term and the quadrature's node motion, and dropping either gives a
finite, plausible, wrong height column. The check needs no reference gradient —
the crown-integral map alone must satisfy `<v, Ju> = <J'v, u>` for random `v, u`.


### 4.1 The boundary's active field build — ~13%

The inflow condition rebuilds the light field on tape. The cohort blocks do not:
they read `(Λ, Λ')` as `2K` inputs, which is what makes their field dependence
rank one, and the hand-written light transpose scatters the resulting knot
adjoints back over cohort state.

Doing the same at the boundary retires the remaining active build.
`light_knot_adjoint` transposes the *inclusive* reduction, over `size() + 1`
nodes, while the boundary condition is evaluated in the field **without** the
boundary interval — a different transpose.

**The transpose itself is a deletion, not a derivation.** The closing trapezium
is one guarded block at the end of `compute_competition_and_slope_adjoint`,
touching only `lambda_f[upper]`, `lambda_s[upper]` and the boundary slot.
Skipping that block gives the exclusive transpose exactly; `light_knot_adjoint`
needs only to linearise on `compute_competition_and_slope_excl_boundary` to
match. Both were built this way and verified inert.

**Two things must be established before the wiring is attempted again**, and both
sank an attempt that assumed them.

*The knot count is not invariant across the adjoint sequence.* A supplied
accumulator sized to the built field met a spline carrying the three knots of the
fixed-value reset state, between the first knot transpose and the inflow call.
Anything that hands the field in must first establish where the grid is reset and
on which grid each accumulator is indexed.

*Supplying both fields drops a channel.* The recording needs the density in the
field WITHOUT the boundary interval and the density in the field WITH it, and the
forward's ordering makes the second depend on the boundary density the first
produced. Supplied as two independent inputs, that path leaves the tape. Forming
the closed field on tape from the open one instead needs the reduction's per-knot
exit state, which is the `O(K·N)` loop being removed. **So the lever cannot be
landed on a bit-identity argument** — it has to be landed on a measurement of
that channel, and refused if the measurement is not round-off.

Report 05 §6.1 flags a further channel easy to miss here — the newcomer's own seed
leaf area reaches the census through a field it does not contribute to.

### 4.2 Store rather than recompute — ~14%, and checkpointing is the wrong tool

`store_trajectory` (8%) and the stage rebuild (6%) are **48,627 of the reverse
pass's 55,821 plain leaf solves**. Both are pure recomputation.

⚠️ **Revolve and binomial checkpointing do not apply and would make this worse.**
Their purpose is to bound tape memory below `O(M)` by trading storage for a
`log M` recomputation factor. The per-cohort decomposition already makes peak
memory one cohort-step, independent of run length — the constraint they solve
does not exist here, and applying them multiplies this 14% by a log factor. The
move on this axis is the opposite one: store more.

#### The trajectory re-run — ~8%

`census_trait_gradient` opens by calling `store_trajectory()`, which re-runs the
whole model to record per-step states. The caller has just run it. This is a
**avoid**, not a cache: the work has a producer already, and what is missing is
that the first run does not record. The cost of making it record is memory,
about 25 MB at century scale, against a stated flat-memory target with headroom.

The hazard is the validity key. A trajectory reused after any mutation is a
gradient of a different model, and the failure is silent. Either the first run
records unconditionally, or the reuse is keyed on something that covers every
mutator — and a key that covers *almost* every mutator is worse than no cache.

### 4.3 The tape — ~30%, previously ruled out

Three specific costs, each with a mechanism:

- **Thread-local lookups on every active value's construction and destruction.**
  XAD reaches its active tape through `__tls_get_addr`; at 3.4 per cent this is
  pure addressing overhead on a single-threaded sweep.
- **Register/unregister churn**, 3.5 per cent, which counts short-lived active
  temporaries in the recorded arithmetic. Passive subexpressions on the active
  path are the usual cause and `to_passive` is the usual fix.
- **Granularity.** ~18,000 tapes are created and cleared per run, one per cohort
  per stage. The per-recording fixed cost is paid 18,000 times.

### 4.3b Identity tape statements from by-value active parameters

`Internals<S>::state/rate/aux/consumption_rate` return `S` **by value**, and
about sixty strategy signatures take `S` by value. With a tape active, an `AReal`
copy is not a copy: it registers a variable, pushes a slot with multiplier 1.0
and pushes a statement, and the destructor unregisters. So each one records a
full `y = 1.0*x` and is swept as such.

`net_mass_production_dt` is the clearest instance — it takes `S height_inverse`
by value and then discards it with `(void)`, recording a statement for a value
never read.

Taking these by `const S&` should be bit-identical, since a multiplier-1.0 chain
is exact. It attacks six profile lines at once and shrinks the sweep as well as
the recording.

### 4.3c The conductance rows, exactly and for free

Report 05 §7.3 establishes `R = F(E_up, dE_up/dp; p, phi)` with two scalars `a`
and `b`, and `b` in closed form. Read that identity in the maximum leaf-specific
conductance: it enters `F` **only** as the scale on both intermediates, since
`sigma = P(E_up/kappa + S_t(p))` and the bracket carries `E'_up/kappa`. Euler's
relation on that homogeneity gives

    dPi/dkappa = -b * E_up / kappa
    dR/dkappa  = -( a * E_up + b * dE_up/dp ) / kappa

both exact, both from scalars two drives already fix, and both replacing a
central difference and its two bracket root-finds.

**Take the check even if the saving is not wanted.** If `dPi/dkappa` does not
match the existing difference at wet, dry and shaded states, the same identity
underwrites report 05 §7.3's whole rank-two factorisation, and that is a
correctness finding rather than a performance one.

### 4.4 The leaf's remaining row families

Two families still difference where an analytic route exists.

**The photosynthesis marginal row.** `a`, `curv_fact_elec_trans` and
`curv_fact_colim`. The profit half is derived and verified; the marginal half
needs `A''` and a mixed second partial, both on kernels containing no
interpolator, cache or root-find — the one place in the leaf where an active
scalar raises no correctness question. Until both halves exist there is no drive
to remove.

**The collar-solve preparation.** Every drive re-runs `prepare_collar_solve`,
which is two root-finds for the feasible interval. The interval does not move for
a perturbation that moves no water, so the hoist is legitimate per family and
wrong applied to the loop: radiation and conductance cannot move it, a soil
potential or a layer's carbon can.

### 4.5 Spline reductions — **deferred**

The field build evaluates a reduction over every cohort at every knot. The
Yokozawa kernel is a polynomial in `u^η`, so three running sums over
height-ordered cohorts give every knot at once and the build is `O(K + N)` rather
than `O(K·N)`.

**This work is proceeding on another branch and must not be duplicated here.**
Two things to know when it lands. It is **symmetric** — the forward model pays
the same reduction — so it improves absolute time considerably and the ratio
much less. And it does not remove a build: it makes each one cheaper, so it
partly cannibalises §4.1 and should be sequenced after it, not before.

---

## 5. What not to do

**Do not hold the vulnerability curve's grid across a trait perturbation.** The
grid is `psi_max = b·log(100)^(1/c)` and `set_traits` rebuilds it whenever a curve
trait moves, so the moving grid is part of the function being differentiated. A
held grid, or the homogeneity rescale in `b`, differentiates the base spline
stretched — a different function. The test is one question: **does the forward
model rebuild the grid when the parameter moves?** If it does, the motion is the
model.

**Do not substitute a closed form for a tabulated derivative.** Where the forward
solve reads a spline, the derivative belonging on the tape is the spline's. The
closed forms are worth having as a replacement for the *table*, in the forward
model, as one change with one re-blessing — not as a drop-in for its derivative.

**Do not redesign the per-cohort decomposition.** It is what makes peak memory one
cohort-step, and that property is intact.

**Do not read a hoist as safe because a value is written and never read.** Whether
a dropped accumulator matters depends on whether its upstream quantity carries a
derivative, and a later declaration can change that.

---

## 6. Sequencing

Land one family at a time and hold each to the values it replaces before moving
on. A change from differenced to analytic returns a finite, plausible, wrong
gradient when it is wrong, and the differenced implementation is the reference —
it exists today, and it stops existing the moment it is deleted. **Capture the
reference before removing the differencing.**
