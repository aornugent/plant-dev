# AD implementation — handover

A factual snapshot of the reverse-mode AD work (plant × odelia) and how to pick
it up. The authoritative spec is [`ad-implementation.md`](./ad-implementation.md);
the census-gradient solution has its own design doc,
[`ad-census-gradients.md`](./ad-census-gradients.md). This doc only says where we
are and what to do next.

## Current state

The scalar-templating **foundation is in place and `double`-bit-identical**, the
**active path is proven through the growing SCM**, and **K93 census gradients are
correct** (machine-exact).

- **FF16 and K93 carry `value_type = S`** — `X_Pars_<S>` / `X_Strategy_<S>` /
  `X_Environment_<S>` with `double` aliases, threaded through the
  `Individual/Node/Species/Patch<T,E>` templates, the `<It>` ODE seam, base
  `Environment_<S>`, `ResourceSpline_<S>`, `QK::integrate<S>`, and a
  position-templated `CanopyShape`.
- **TF24 / TF24f are still `double`** (they ride the `double` aliases), and the
  **shed stays `double`**: leaf hydraulics, soil retention/conductivity curves,
  `QAG`, the FD gradient primitives.
- **Gate 0 passed** — `IndividualRunner` (single plant, fixed environment) seeded
  at an active parameter, `compute_gradient` FD-checked. The cheapest active
  instantiation; it surfaced and fixed the active-narrowing sites the
  `double`-identical suite cannot see.
- **Gate 1 passed (K93 resident)** — an active, growing multi-cohort SCM
  differentiates correctly. The mid-run active `resize()` and the cross-cohort
  active initial conditions work: **XAD's tape survives a mid-replay `resize()`**
  (the largest unverified risk in the plan — now answered).
- **K93 census gradients are machine-exact.** Reverse-mode gradients of census
  functionals (offspring production, biomass, moments) through the growing K93 SCM
  match a converged finite difference to machine precision (`cosine(ad, fd) = 1.0`
  across both parameter classes), via **geometric compression** of the
  density-transport term, shipped as the opt-in `control$node_geometric_compression`
  (default `FALSE`). This **resolves** the transport-term (`∂ₓg`) problem that
  `ad-implementation.md` §15 tracked as the interim `~1.5%` forward-over-reverse
  injection; that account is now marked superseded. Full derivation:
  [`ad-census-gradients.md`](./ad-census-gradients.md).

**Active scope today.** K93's whole rate path is forward-mode-instantiable
(`rebind`) and its census gradients are correct. FF16 is scalar-templated but its
`∂g/∂h` derivative is not yet on the forward-mode path, so FF16 census gradients are
not yet available. TF24/TF24f are still `double`.

**The foundation commitment** (`ad-implementation.md` §0, §0.5) is unchanged: `S`
lives only on ODE state/rate storage and the rate arithmetic that reads it (plus the
seeded pars and active background reads); every other type is `double`; the sole
rate-path crossing is `supplied_derivative` at the shed edge. Kept true structurally
(the shed's `double` signatures make activating the leaf a compile error). No
`Coupling` concept; one generic `make_strategy_ptr(Strat)`.

## Branch / commit state

This session's work:

| Repo | Branch | Head | Contents |
|---|---|---|---|
| plant | `claude/ad-gate1-scm` | `abbf253a` | Gate 0, guard layer, Gate 1 (K93 resident), the census-gradient geometric compression + opt-in `Control` flag |
| superproject | `claude/agents-setup-docs-wl9b0v` | `66a631a` | submodule pointer bump + docs (`ad-census-gradients.md`, this handover, consolidation) |

Earlier activation-foundation stack (from the prior handover — confirm each is still
open/unmerged before relying on it):

| Repo | Branch | PR | Contents |
|---|---|---|---|
| plant | `claude/ad-strategy-activation` | [#36](https://github.com/aornugent/plant/pull/36) | FF16 + K93 activation; the v3 foundation (no Coupling) |
| plant | `claude/ad-interp-routing` | #35 | `ResourceSpline` → odelia interpolator |
| plant | `claude/ad-skeleton-foundations` | #34 | `Internals_<S>` + skeleton threading |
| plant | (base) | #33 | record/replay reframe onto odelia `Replayable` |
| odelia | `claude/ad-iterator-seam` | #35 | `<It>`-templated ODE-serialization helpers |
| odelia | `claude/ad-spline-active-query` | #36 | interpolator active-query eval |

## How the current result is verified

Gate 1 correctness is exercised by a **C++ harness** that records the K93 node
schedule on a `double` adaptive pass, replays it at the active scalar, and calls
`odelia::ode::compute_gradient` over the census functional (`size_sum`), FD-checked
against a converged central difference of the replayed model for both parameter
classes (trajectory-movers `b_0`/`b_1`; coupling-only `k_I`/`c_1`). The harness lives
in the session scratchpad and is **not** version-controlled (it is a spike, not
shipping code) — the shipping surface it exercises is the seeding API and the flag.

The seeding surface (`ad_parameters()` on `Patch`/`Species`/`Individual`,
`field_ptrs`/`field_names` on the strategy) is in place. The **R-facing gradient
wrapper (`stand_gradient_cpp` + the R entry point) is not yet built** — gradients are
reachable from C++ via `compute_gradient`, not yet from R.

## Next steps

1. **R-facing gradient API (`ad-implementation.md` §8.1/§8.2, step 5).**
   `stand_gradient_cpp` (table + fingerprint + cache precondition) + the R wrapper
   (dimnames, the low-level-parameter caveat, `Control` record) so census gradients
   are reachable from R, not only the C++ harness. This is the natural next
   integration step now that Gate 1 correctness holds.
2. **FF16 census gradients.** Port FF16's `∂g/∂h` rate path to be forward-mode
   instantiable (`rebind`), so it inherits the *same* Species-level geometric
   compression with no per-strategy transport-gradient work (that shared-fix
   property is R3 in the design). FF16 census gradients then become available.
3. **TF24 resident — the endpoint (§4.3, §6.3, §13).** `TF24_Pars/Strategy/
   Environment → _<S>` (active soil state, `resource_depletion` → `value_type`, the
   `double` `Leaf` via `supplied_derivative`); `∂g/∂h` here is `supplied_derivative`
   (the leaf optimiser, envelope theorem), **not** forward-over-reverse — do not
   conflate with K93/FF16. The stiff soil↔canopy replay numerics are gated
   separately (§13).
4. **Decide the K93 default.** `node_geometric_compression` is opt-in to keep the
   published K93 forward bit-for-bit. If the geometric discretisation is adopted as
   the canonical K93 numerics, flip the default to `TRUE` and re-baseline the K93
   "offspring production is unchanged" snapshots (the shift is ~0.2%, the intended
   change). See `ad-census-gradients.md` §6.

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
```

The full plant suite is green with `node_geometric_compression` **off** (the default);
`test-strategy-k93.R`'s "offspring production is unchanged" snapshots are the K93
forward-output guard, and `test-control.R` pins the `Control` field set. A change to a
number in `test-strategy-ff16.R`'s reference comparison means you broke bit-identity —
diff the floating-point order, not just the value.

## Gotchas

- **Regenerating RcppR6 is needed only when you add/remove a registered field.**
  Adding `node_geometric_compression` to `Control` this session required editing
  `inst/RcppR6_classes.yml` + `src/control.cpp` and running `RcppR6::RcppR6()` to
  regenerate the glue (`RcppR6_post.hpp`, `R/RcppR6.R`). Do **not** regenerate for
  ordinary scalar-templating work — the `X_<S>` + `using X = X_<double>` aliases keep
  the binding names (`plant::FF16_Strategy`, …) resolving, so `compileAttributes` /
  `RcppR6::RcppR6()` would only churn generated files.
- **Do not template the shed** (leaf / soil curves / QAG / FD / `r_*` facades) — it
  participates only through `supplied_derivative`. Over-templating is the failure
  mode to avoid.
- **A `double`-identical suite does not verify the active path** — only Gate 0 /
  Gate 1 / seeding exercise active. Treat "compiles + bit-identical" as necessary,
  not sufficient. (This is precisely how the transport-term gradient bug hid: the
  primal was bit-identical while the gradient was `O(1)` wrong.)
- **The census gradient is the derivative of the model actually run.** With the flag
  on, FD-check against the *geometric* forward (flag on for both AD and FD); with it
  off you get the old stencil model and its (inconsistent) gradient. Never FD-check
  one against the other.
- **Reinstall odelia after an odelia edit** — plant builds against the *installed*
  odelia headers, not the submodule working tree.
