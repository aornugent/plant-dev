# AD implementation — handover for the next chunk (FF16 + K93 activation)

Written at the boundary after the odelia read-surface and plant scalar skeleton
landed. It orients you through the design docs, the PR stack you're building on,
and — most importantly — the things we learned that are **not** in the docs.
Then it prescribes the next chunk.

**The one-line state:** the whole harness is threaded but still runs at
`value_type = double` everywhere (bit-identical, full suite 2282 pass / 0 fail).
The next chunk makes **FF16 and K93 the first strategies to carry an active
scalar**. Everything that chunk depends on is landed.

---

## 0. Where we are against the plan's build order

The roadmap is `ad-implementation.md` §15. Status:

| Step | Item | State |
|---|---|---|
| 0 | Skeleton `value_type=S` | ✅ (plant #34) |
| 0 | Delete `ad_value.h` | ✅ (never existed on `develop` — see insight #1) |
| 0 | Kink manifest + CI `value(` grep | ❌ **deferred** (bites only when active) |
| 0 | Guards → active-safe (`is_finite`/`util::stop`/`check_finite_ode_state`) | ❌ **deferred** (bites only when active) |
| 1 | Two `set_ode_state` overloads (resident/mutant) | ✅ (plant #33) |
| 1 | `ResourceSpline` → odelia interpolator | ✅ (plant #35 + odelia #36) |
| 1 | `EnvironmentRecording<E>` struct + fingerprint | ❌ **deferred to seeding** (raw members on `Patch` for now) |
| 1 | `Coupling` concept + `static_assert(Coupling<E>)` | ❌ **not written yet** — part of this chunk |
| 1 | FF16 env satisfies `Coupling` | ❌ this chunk |
| 2 | `QK::integrate<S>` + `CanopyShape<S>` + MeanLight→`S` | ❌ **this chunk** |
| 3 | `growth_rate_gradient` one body | ⚠️ threaded but FD-body still `double` (fine at double; revisit when active — catalog Cluster 6) |
| 4 | `height_seed` via `supplied_derivative` | ❌ later (needs the odelia seam fix, insight #14) |
| 5 | Seeding (X-macro) + `stand_gradient_cpp` + R wrapper | ❌ later |
| 6 | FF16 verify → TF24 | ❌ later |

Also done, not a numbered step: the odelia **read-surface** — recursive ODE
helpers templated on the state iterator (#35) and the interpolator active-query
eval (#36). These are what the plant hierarchy threads onto.

---

## 1. Read these, in this order

1. **`ad-implementation.md` (v2)** — **the authoritative spec.** §15 build order
   is your map; §4.1 (K93), §4.2 + §4.4 (FF16 crown/canopy), §6 (`Coupling` +
   environments), §8.1 (X-macro seeding), Appendix A (per-file change index).
   Where any other doc disagrees, this wins.
2. **`ad-infrastructure-design.md`** — the thesis / *why*: one uniform
   `value_type = S`, surgical in-place changes, no new abstractions, the
   invasion-vs-resident cut (§5.4, §7 L3).
3. **`ad-touchpoint-catalog.md`** — the survey + the 7 clusters. Read **Part V**
   (the System view): template by *graph membership*, not by file; most of plant
   stays `double` (the "shed"). This is the antidote to over-templating.
4. **`ad-record-replay.md`**, **`ad-r-interface.md`** — the record→replay
   primitive and the R boundary. Skim now; needed at the seeding phase.
5. **`ad-issues.md`** — the per-issue map (PLANT-*, ODELIA-*). Useful for the
   dependency graph, but the catalog judges it "the wrong altitude"; when it and
   the plan's build order differ, follow the plan.
6. odelia issues: **#22** (interpolator unification — **closed/done**; the
   `basic_interpolator` you use *is* that object), **#28** (record/replay
   demonstrator pare-down + the `live|frozen` → data-presence reframe — open;
   we applied its rename to plant in #33).

---

## 2. The PR stack you're building on

All branches hang off the superproject branch
`claude/agents-ad-implementation-22a7ej` (submodule pointers bumped at each step).
Everything is **`double`-identical** (verified), so nothing below changes a
number.

| PR | Repo | Branch (base) | What |
|---|---|---|---|
| [plant #33](https://github.com/aornugent/plant/pull/33) | plant | `claude/agents-ad-implementation-22a7ej` (`develop`) | Reframe mutant record/replay onto odelia `Replayable`; drop FF16 AD-spike tests + composite kernel |
| [plant #34](https://github.com/aornugent/plant/pull/34) | plant | `claude/ad-skeleton-foundations` (#33) | Scalar skeleton: `Internals_<S>`, absorb FF16 kernel, thread `value_type` + the `<It>` seam through `Individual`/`Node`/`Species`/`Patch` |
| [plant #35](https://github.com/aornugent/plant/pull/35) | plant | `claude/ad-interp-routing` (#34) | Route `ResourceSpline` through odelia's interpolator; retire `AdaptiveInterpolator` |
| [odelia #35](https://github.com/aornugent/odelia/pull/35) | odelia | `claude/ad-iterator-seam` (`claude/ad-surface`) | Template the recursive ODE-serialization helpers on the state iterator |
| [odelia #36](https://github.com/aornugent/odelia/pull/36) | odelia | `claude/ad-spline-active-query` (odelia #35) | `basic_interpolator` active-query eval (value+deriv wrapper) + bit-identical `construct` seeding |

Dependency to remember: **plant #35 needs odelia #36** (the seeding), and the
plant skeleton (#34) needs odelia #35 (the iterator seam). Land/merge order per
repo is bottom-up as listed. Get these reviewed before stacking the activation on
top — a mistake in the odelia surface ripples into every System.

**To continue locally:** you're on `plant@claude/ad-interp-routing` and
`odelia@claude/ad-spline-active-query`. Branch the next chunk off
`claude/ad-interp-routing`.

---

## 3. Undocumented insight (read this — it's the point of the handover)

1. **`develop` is *not* the baseline the plan/catalog describe.** Their "current"
   columns and `file:line` anchors were written against the earlier **spike
   branches** (`claude/ad-*`), which had `_ad`/`_active` twins, an already-
   templated `Internals_<S>`, `ad_value.h`, and the composite production kernel.
   On `develop` **none of that exists** — it's cleaner (no twins to collapse, no
   `ad_value.h` to delete) but *less* templated (hard-`double` `Internals`, no
   `value_type`). So the plan's "de-twin" / "delete `ad_value.h`" work is mostly a
   no-op here; you **build** the templating fresh. Don't go hunting for `_ad`
   twins — they aren't there.

2. **The ODE-iterator seam went into odelia (a deliberate divergence from the
   plan).** `ad-implementation.md` §2/§3 says *"the `<It>` seam is plant's, not
   odelia's ... plant does NOT use odelia's helpers."* We overrode that (owner's
   call, validated with the design skill): odelia #35 templates the recursive
   `set_ode_state`/`ode_state`/`ode_rates`/`ode_aux` helpers on the **state
   iterator**, matching the pattern odelia's own single-System examples already
   use, and plant's hierarchy (#34) both templates its methods on `<It>` **and**
   routes through those helpers. Net: one shared iteration in odelia. When you
   read the plan's §2/§3 iterator language, mentally replace "plant's own seam"
   with "odelia's templated helpers." The `Coupling` concept (§6.1) still checks
   the templated form.

3. **The active-query spline read is a value+derivative wrapper on
   `basic_interpolator`, not a re-implemented active polynomial, and not on
   `basic_spline`.** odelia #36 adds `operator()(Q)/eval(Q)` for a non-`double`
   query as `spline(value(u)) + deriv(value(u))·(u − value(u))` — the wrapper
   odelia's `deriv()` was explicitly written for. It's exact for first-order AD,
   works for frozen-`double` **or** active knot values, and leaves the vendored
   `spline.hpp` untouched. Consequence for you: **the light read at an active
   height already works** through `ResourceSpline` → `basic_interpolator`.

4. **Even the invasion/mutant reads light at an active height.** "Frozen canopy"
   means the *knots and values* are frozen `double`; the mutant still queries the
   spline at its own **active** height, so `d(light)/d(height)` flows through the
   spline slope. This is *why* insight #3 was needed for both resident and mutant
   — don't assume the mutant's light read is a plain `double`.

5. **RcppR6 `_<S>` + `double`-alias is confirmed sound — do NOT regenerate.** The
   `wrap`/`as`/`class_name_r` specializations in `RcppR6_post.hpp` are keyed on
   `plant::FF16_Pars` etc., which become the `double` alias (`FF16_Pars_<double>`)
   and resolve through it. So `template<class S=double> struct FF16_Pars_` +
   `using FF16_Pars = FF16_Pars_<double>` keeps `RcppR6_classes.yml` and the
   generated `RcppExports`/`RcppR6.cpp` valid with **no** `compileAttributes` /
   `RcppR6::RcppR6()` run. Plan §8.2 asserts this; we verified the resolution.
   This is the single biggest de-risk for the strategy templating.

6. **The narrowing workflow.** Thread `value_type` on the differentiable core
   (ODE state, rate arithmetic, the light read). Metric/query/R/stochastic/
   diagnostic methods stay `double` or narrow `value_type → double`. At `S=double`
   (this whole chunk) that narrowing is `double→double` — **invisible, so the
   suite stays bit-identical and you cannot yet see which narrows are wrong.**
   The narrowing sites only surface as compile errors when a strategy is first
   **instantiated at active** (Gate 0 / seeding). That is by design; fix each with
   `xad::value(...)` per the kink manifest (§11) at that point. Corollary: an
   all-`double` "activation" is real but unverified on the active path until you
   build one active instantiation — see the prescription below.

7. **Activation is all-or-nothing per strategy — you can't half-template a
   class.** `Patch<T,E>::value_type = T::value_type`, so the moment
   `FF16_Strategy` carries `S` it pulls in `FF16_Environment_<S>`, `QK<S>`,
   `CanopyShape<S>`, `FF16_Pars_<S>`. **K93 is dramatically smaller** (closed-form;
   no crown, no `QK`, no `CanopyShape`, no leaf, no soil) — which is why the
   prescription starts there.

8. **Bit-identity is the invariant, and FP *ordering* breaks it.** The FF16
   "reference comparison" test is a stored **bit-identical** baseline; any change
   to floating-point order (not just value) fails it. We hit this routing
   `ResourceSpline`: odelia's `construct` seeded the base grid `a + dx*i` while
   plant's retired refiner accumulated `x += dx` with an exact endpoint —
   last-bit different, and it broke the reference test until we aligned odelia's
   seeding (odelia #36). Lesson: when you replace numeric code, match the FP order,
   not just the math. Keep this chunk bit-identical.

9. **`Patch` already has the two `set_ode_state` overloads and the `Replayable`
   hooks** (from #33): resident `(it, time)` recomputes the env; mutant
   `(it, index)` reads `environment_history[idx][index]`; `odelia::ode::derivs`
   routes on `has_recorded_field()` (`= !recording && !environment_history.empty()`).
   The plan's `EnvironmentRecording<E>` struct + parameter fingerprint (§5) is
   **deferred** — the raw members (`step_history`, `environment_history`,
   `environment_cache`, `idx`, `recording`) live on `Patch` as the pre-gradient
   intermediate. Factor them into `EnvironmentRecording` when you wire seeding
   (the fingerprint guards a *gradient* call, which doesn't exist yet).

10. **FF16/K93 environments carry `S` but contribute 0 ODE state** (`ode_size()=0`;
    light-only). Only TF24 has soil ODE state. So the environment's
    `set_ode_state`/`ode_state`/`ode_rates` are no-ops for FF16/K93 — the scalar
    they carry is the **light values + the query**, not integrated state.

11. **The "shed" stays `double` (catalog Part V).** Do **not** template: the leaf
    model (`leaf_model.cpp`), the soil bucket, `QAG` (dormant, `max_iter=1`), the
    FD gradient primitives (`gradient.h`), the `r_*` R facades, or the guards.
    Template only the core: FF16's mass cascade + crown integral, K93's closed-form
    rates, and the light read.

12. **Verification harness realities** (these cost hours if unknown):
    - Install odelia with **`R CMD INSTALL` / `library(odelia)`**, never
      `load_all` — plant resolves odelia's compiled XAD `Tape` symbols at load
      (`AGENTS.md` caveat). **Reinstall odelia after any odelia header edit** —
      plant compiles against the *installed* odelia headers, not the submodule.
    - `pkgload::load_all("plant")` for plant (picks up C++ edits incrementally).
    - Set `TESTTHAT_PARALLEL=false` + `options(testthat.parallel=FALSE)` — parallel
      `test_dir` spawns `callr` workers that can't see the `load_all` namespace
      ("zero-length variable name").
    - The full plant suite (233 blocks) runs **>10 min** — target subsets, or
      background it (and don't nest `nohup` inside a background runner — it
      double-backgrounds and the "exit 0" is the wrapper, not the job).
    - **Expect `2282 pass / 0 fail / 1 error`.** The 1 error is
      `test-strategy-ff16.R` "Report generation" — `pandoc` is absent in this
      container; `run_scm` itself succeeds. It is *not* a regression.
    - odelia's AD tests (`test-ad-jacobian/functional/tape-cache`) **error** in a
      bare `library(odelia); test_file()` run — they call internal Rcpp functions
      only visible under the CI/package-namespace harness. But **`test-spline-ad.R`
      runs** (its `sourceCpp` compiles its own exports) — use it to FD-verify
      active spline/interpolator behaviour, as odelia #36 does.

13. **Gate 0 (`IndividualRunner`) is the cheapest way to prove the active path**
    (plan §15). It's a fixed-dimension single-plant System — no schedule, no
    introductions, no growing dimension. Seeding one parameter and FD-checking its
    single-plant gradient validates the tape + `value_type=S` + light read (+
    `height_seed` seam) **before** betting on the growing SCM. Strongly consider
    making it the active-verification target of this chunk (see below).

14. **`height_seed` (FF16) needs an odelia seam fix that isn't done.** Plan §7.4:
    `odelia::ode::supplied_derivative` throws on a passive input
    (`slot_ = INVALID_SLOT` → `Tape::incrementAdjoint` out-of-range). The fix
    (skip `(slot, partial)` pairs whose slot is invalid, filtering as a *pair*) is
    ~2 lines in odelia and **not yet applied**. You only need it once FF16 goes
    active *with* `height_seed` seeded (i.e. at Gate 0 / seeding), not for the
    pure `double` templating. Do it in odelia when you reach it.

---

## 4. Prescriptive plan for this chunk

**Goal:** FF16 and K93 instantiate at `value_type = S` (compile at active), staying
`double`-identical, and — recommended — prove the active path on `IndividualRunner`
(Gate 0). TF24/TF24f stay `double`.

### The templating mechanics (the core skill — same for every type)

For a concrete strategy/pars/environment `X`:

1. `template <class S = double> class X_` (rename the class), `using X = X_<double>`
   at the end of the header. Same for `X_Pars_<S>` / `X_Environment_<S>`.
2. In the strategy, declare `using value_type = S;` (it overrides the base
   `Strategy<E>::value_type = double` we added in #34). `Patch`/`Individual`/… pick
   `S` up automatically via `T::value_type`.
3. **Move method definitions into the header** (as `template` bodies) so the
   active instantiation can compile. The `.cpp` out-of-line defs must become
   header templates, or the active pass can't see them. (Explicit-instantiate the
   `double` path only if you also keep the header visible for active — simpler to
   just header-ify.)
4. Physiology arithmetic carries `S`; keep model dispatch (virtuals, the
   `assimilation_fn` member pointer, `ShadingModel`) as-is — those are model
   choices, not scalar branches (plan §4).
5. Do **not** regenerate RcppR6 (insight #5). Do **not** touch the leaf/soil/QAG/FD
   shed (insight #11).
6. Build at `double`, run the suite, confirm **bit-identical** (insight #8). The
   active narrowing sites won't appear until step (Gate 0) below.

### Recommended order

1. **`Coupling` concept + `static_assert`.** Write `coupling.h` (plan §6.1) and add
   `static_assert(Coupling<environment_type>)` to `Patch`. Do this first so a
   non-conforming environment fails at the boundary, not deep in the pass. (At this
   point no env satisfies it yet — expect to co-develop it with the first
   environment below.)
2. **K93 first** (`ad-implementation.md` §4.1 — the free restriction). Smallest
   surface: `K93_Pars_<S>`, `K93_Environment_<S>` (light-only, `ode_size()=0`,
   `get_environment_at_height<S>` via #36's active-query read), `K93_Strategy_<S>`
   (closed-form `size_dt`/`fecundity_dt`/`mortality_dt`; two kinks at
   `k93_strategy.cpp:117,139` → kink manifest). No `QK`, no `CanopyShape`, no leaf.
   This proves the whole templating pattern (class → `_<S>`, RcppR6 aliases,
   `Coupling`, `ResourceSpline<S>` for active light values) with minimal noise.
   Note: `ResourceSpline` (routed to odelia in #35) is still `double`-valued —
   template it on `S` for active knot *values* (positions stay `double`); at
   `S=double` it's unchanged.
3. **FF16 next** (§4.2 + §4.4). Adds the crown: `QK::integrate<S>` (one
   `template<class S,class F> S integrate(F,S,S)`, delete `integrate_ad`),
   `CanopyShape<S>` (template the profile, delete `_active` twins), **re-body
   MeanLight (`assimilation_average_light`) to `S`** (TF24's default integrates in
   `double` today — it silently drops the crown derivative if left). `FF16_Pars_<S>`
   with the X-macro `field_ptrs()`/`field_names()` single-source can wait for the
   seeding step, or do it here — your call. Leave `height_seed` as the `double`
   root-find for now (its `supplied_derivative` seam is step 4 / insight #14).
4. **Gate 0 (recommended, to actually verify active).** Wire `IndividualRunner`
   (`individual_runner.h`) as an AD target: seed one FF16 (then K93) parameter,
   run the single plant, `compute_gradient`, FD-check (~1e-4). This is where the
   narrowing sites (insight #6) surface — fix them with `xad::value` + start the
   kink manifest. If you'd rather keep this chunk pure-`double`, stop after FF16
   and make Gate 0 the top of the *next* chunk — but then nothing here is verified
   on the active path, only that it still compiles + is `double`-identical.

### Definition of done

- FF16 and K93 classes/pars/environments are `_<S>` templates with `double`
  aliases; TF24/TF24f untouched; the leaf/soil/QAG/FD shed untouched.
- `Coupling` written; `Patch` `static_assert`s it; FF16/K93 envs satisfy it.
- **Full plant suite `2282 pass / 0 fail`** (the pandoc error aside), FF16
  reference-comparison **bit-identical**, `stochastic.R` green (the `double` path
  of the shared hierarchy must keep compiling — plan §8.6).
- If you did Gate 0: `IndividualRunner` FF16 + K93 single-plant gradients FD-match;
  narrowing sites fixed; kink manifest started.

---

## 5. Build & verify recipe

```r
# after any odelia header change:
#   $ R CMD INSTALL odelia            # reinstall — plant uses installed headers
Sys.setenv(TESTTHAT_PARALLEL = "false"); options(testthat.parallel = FALSE)
library(odelia); library(testthat)
pkgload::load_all("plant", quiet = TRUE)          # compiles plant C++

# fast inner loop — the surface this chunk touches:
for (f in c("test-strategy-ff16.R","test-strategy-k93.R","test-environment.R",
            "test-canopy-methods.R","test-mutant.R","test-individual.R",
            "test-scm-support.R","test-stochastic.R")) {
  r <- as.data.frame(testthat::test_file(file.path("plant/tests/testthat", f),
                                         reporter = "silent"))
  cat(sprintf("%-26s P=%d F=%d E=%d\n", f, sum(r$passed), sum(r$failed), sum(r$error>0)))
}

# full sweep (>10 min — background or run once at the end):
#   testthat::test_dir("plant/tests/testthat", reporter="silent", stop_on_failure=FALSE)

# odelia active spline/interpolator behaviour (this one RUNS via sourceCpp):
#   (cd odelia && Rscript -e 'library(odelia);
#      testthat::test_file("tests/testthat/test-spline-ad.R")')
```

`test-strategy-ff16.R` carries the **bit-identical reference-comparison** — treat
a failure there as "you changed a number," and diff the FP order (insight #8).

---

## 6. Traps, in one place

- Regenerating RcppR6 — don't (insight #5).
- Forgetting to reinstall odelia after an odelia edit → plant builds stale headers.
- Templating the shed (leaf/soil/QAG/FD/`r_*`) — over-templating is the failure
  mode both prior attempts hit (catalog Part V).
- Half-templating a strategy class (insight #7) — it won't compile; go all the way
  or not at all.
- Treating the FF16 reference test as tolerance-based — it's bit-identical.
- Expecting the active path to be *verified* by a `double`-identical suite — it
  isn't; only Gate 0 / seeding exercises active (insight #6).
- The pandoc "Report generation" error is not yours (insight #12).

---

## 7. After this chunk

Steps 4–6: `height_seed` `supplied_derivative` seam (+ the odelia `INVALID_SLOT`
pair-filter, insight #14), the X-macro seeding + `stand_gradient_cpp` + R wrapper,
`EnvironmentRecording` + fingerprint, then Gate 1 (multi-species growing SCM) and
TF24/TF24f (the leaf mixed-scalar + soil — the design's highest-risk piece,
gated by PROTO-2). The plan's §15 + Appendix A drive all of it.
