# AD implementation — handover

A factual snapshot of the reverse-mode AD work (plant × odelia) and how to pick
it up. The authoritative spec is [`ad-implementation.md`](./ad-implementation.md);
this doc only says where we are and what to do next.

## Current state

The scalar-templating **foundation is in place and `double`-bit-identical.**

- **FF16 and K93 carry `value_type = S`** — `X_Pars_<S>` / `X_Strategy_<S>` /
  `X_Environment_<S>` with `double` aliases, `value_type` threaded through the
  existing `Individual/Node/Species/Patch<T,E>` templates, the `<It>` ODE seam,
  base `Environment_<S>`, `ResourceSpline_<S>`, `QK::integrate<S>`, and a
  position-templated `CanopyShape`. Bodies are header-inline so an active
  instantiation can see them.
- **TF24 / TF24f are still `double`** (they ride the `double` aliases, untouched),
  and the **shed stays `double`**: the leaf hydraulics, soil retention/conductivity
  curves, `QAG`, and the FD gradient primitives.
- **No active instantiation yet.** Everything runs at `S = double`; the full plant
  suite is **2282 pass / 0 fail** (the one error is the pandoc-dependent "Report
  generation" test — environmental). The FF16 reference-comparison test is the
  bit-identity guard.

**The committed foundation** (`ad-implementation.md` §0, §0.5): `S` lives only on
ODE state/rate storage and the rate arithmetic that reads it (plus the seeded
pars and the active background reads); every other type is `double`; the sole
rate-path crossing is `supplied_derivative` at the shed edge. It is kept true
structurally — the shed's `double` signatures make activating the leaf a compile
error, and a model's scalar is decided by which of its members carry `S`. There
is **no `Coupling` concept** (removed — `Patch`'s own use compile-enforces the
same contract) and **one generic `make_strategy_ptr(Strat)`**.

### Open PRs / branches

| Repo | Branch | PR | Contents |
|---|---|---|---|
| plant | `claude/ad-strategy-activation` | [#36](https://github.com/aornugent/plant/pull/36) | FF16 + K93 activation; the v3 foundation (no Coupling) |
| plant | `claude/ad-interp-routing` | #35 | `ResourceSpline` → odelia interpolator |
| plant | `claude/ad-skeleton-foundations` | #34 | `Internals_<S>` + skeleton threading |
| plant | (base) | #33 | record/replay reframe onto odelia `Replayable` |
| odelia | `claude/ad-iterator-seam` | #35 | `<It>`-templated ODE-serialization helpers |
| odelia | `claude/ad-spline-active-query` | #36 | interpolator active-query eval |
| superproject | `claude/agents-ad-implementation-22a7ej` | [#18](https://github.com/aornugent/plant-dev/pull/18) | submodule pointers + docs |

The plant PRs are a stack (#33 → #34 → #35 → #36); odelia #36 stacks on #35.

## Orient on the plan

Read `ad-implementation.md`, in this order:
- **§0 + §0.5** — the commitment, the invariants (only `double` crosses R;
  resident vs mutant is data-presence), and the v3 deltas + the two forward flags
  below. Start here.
- **§15** — the build order and the gates. This is the roadmap.
- **§4.3 / §6.3 / §13** — the TF24-resident endpoint (mixed-scalar strategy,
  active soil ODE state, the deferred stiffness) that the foundation is shaped for.
- **§7** — the `supplied_derivative` seam (the shed's only bridge).

`ad-touchpoint-catalog.md` **Part V** ("the differentiable core vs the shed") is
the reference if you need to decide whether something goes active — but the
commitment above already answers it: state + rate arithmetic go active, the rest
stays `double`.

## Next step: prove the active path (Gate 0), then seed, then TF24

The foundation is done through `ad-implementation.md` §15 step 2. Nothing above
this line has exercised an **active** instantiation, so the active narrowings are
invisible so far (a `double`-identical suite cannot see them). The next work makes
the active path real and verified, cheapest-first:

1. **Gate 0 — `IndividualRunner` active FD-check (§15 Gate 0).** A single plant in
   a fixed environment: no schedule, no introductions, no growing dimension. Seed
   one FF16 (then K93) parameter, run, `compute_gradient`, FD-check to ~1e-4. This
   is the cheapest thing that instantiates a strategy at active, so it surfaces the
   narrowing sites the suite can't — fix each with `xad::value` per the kink
   manifest (§11), and make the two flagged items active:
   - `Node::growth_rate_gradient`'s **result** must carry `value_type` (§0.5 /
     Cluster 6): the FD stencil stays a `double` primitive, but the result feeds
     `log_density_dt` and every density-weighted metric — left `double` it silently
     drops the density-transport term.
   - `height_seed` via `supplied_derivative` (§7.2) — needs the odelia
     `INVALID_SLOT` `(slot, partial)` pair-filter (§7.4), a ~2-line odelia change.
2. **Seeding + the R boundary (§8.1, §8.2; step 5).** Add `rebind`/`rebind_from`
   and `ad_parameters()`/`ad_initial_state()` to `Patch`/`SCM`, then
   `stand_gradient_cpp` + the R wrapper (dimnames + the low-level-parameter caveat).
3. **The growing SCM (§15 Gate 1).** De-risk the mid-run active `resize()` and the
   cross-cohort active initial conditions on **K93 resident** (the clean closed-form
   spine) before FF16/TF24. Whether XAD's tape survives a mid-replay `resize()` is
   the largest unverified risk (§0.5) — this and Gate 0 are where it's answered.
4. **TF24 resident — the endpoint (§4.3, §6.3, step 6).** `TF24_Pars/Strategy/
   Environment` → `_<S>` (soil active state, the `resource_depletion` channel
   flipped to `value_type`, the `double` `Leaf` via `supplied_derivative`). The
   resident *numerics* (stiff soil↔canopy replay) are gated separately (§13) — the
   type foundation reaches the endpoint; the stepper does not yet hold it.

## Build & verify

```r
# after ANY odelia header edit: reinstall (plant compiles against installed headers)
#   $ R CMD INSTALL odelia
Sys.setenv(TESTTHAT_PARALLEL = "false"); options(testthat.parallel = FALSE)
library(odelia)
pkgload::load_all("plant", quiet = TRUE)     # compiles plant C++ incrementally
# fast inner loop, then the full sweep (>8 min):
testthat::test_file("plant/tests/testthat/test-strategy-ff16.R")   # carries the bit-identity guard
testthat::test_dir("plant/tests/testthat", reporter = "silent", stop_on_failure = FALSE)
# odelia active spline/interpolator behaviour (compiles its own sourceCpp exports):
#   (cd odelia && Rscript -e 'library(odelia); testthat::test_file("tests/testthat/test-spline-ad.R")')
```

Expect **2282 pass / 0 fail / 1 error** (the pandoc "Report generation"). A change
to a number in `test-strategy-ff16.R`'s reference-comparison means you broke
bit-identity — diff the floating-point order, not just the value.

## Gotchas

- **Do not regenerate RcppR6.** The `X_<S>` + `using X = X_<double>` aliases keep
  the binding names (`plant::FF16_Strategy`, …) resolving; `compileAttributes` /
  `RcppR6::RcppR6()` are not needed and would churn generated files.
- **Do not template the shed** (leaf / soil curves / QAG / FD / `r_*` facades) —
  it participates only through `supplied_derivative`. Over-templating is the
  failure mode to avoid.
- **A `double`-identical suite does not verify the active path** — only Gate 0 /
  seeding exercise active. Treat "compiles + bit-identical" as necessary, not
  sufficient.
- **Reinstall odelia after an odelia edit** — plant builds against the *installed*
  odelia headers, not the submodule working tree.
