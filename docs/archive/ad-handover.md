# AD implementation — handover

A factual snapshot of the reverse-mode AD work (plant × odelia) and how to pick
it up. The authoritative spec is [`ad-implementation.md`](./ad-implementation.md);
the census-gradient solution has its own design doc,
[`ad-census-gradients.md`](./ad-census-gradients.md). This doc says where we are
and what to do next.

## Current state

Reverse-mode AD is **implemented and verified across all four strategies**
(FF16, K93, TF24, TF24f), with the TF24 family carrying full **soil↔canopy
coupling** on the tape, and the resident **stiffness** question answered with data.

- **FF16 and K93 carry `value_type = S`** — `X_Pars_<S>` / `X_Strategy_<S>` /
  `X_Environment_<S>` with `double` aliases, threaded through the
  `Individual/Node/Species/Patch<T,E>` templates, the `<It>` ODE seam, base
  `Environment_<S>`, `ResourceSpline_<S>`, `QK::integrate<S>`, position-templated
  `CanopyShape`. **K93 census gradients are machine-exact** (geometric compression
  of the `∂ₓg` transport term, opt-in `control$node_geometric_compression`).
- **TF24 and TF24f are now scalar-templated and reverse-mode** (this session,
  Stages A–F). `TF24_Pars/Strategy/Environment_<S>` and the TF24f variant; the
  **`Leaf` stays `double`** and its parameter sensitivity reaches the tape via
  `supplied_derivative` (the envelope-theorem leaf seam), never by templating the
  leaf. The instantiation set is closed: `double`, the reverse active scalar, and
  a forward (tangent) scalar used only as a verification oracle.
- **Soil coupling (Tier-B) is on the tape.** The resident soil-water layers
  integrate actively, coupled to the cohorts through `resource_depletion`; the
  `double` leaf reads an **active** soil ψ (injected `∂profit/∂(soil ψ)`), and the
  leaf's **water uptake** (`soil_consumption_`) is itself an active
  `supplied_derivative` output per layer — so the water-limited feedback
  (soil state → ψ_soil → leaf optimum → uptake → soil state) is differentiated,
  not dropped.
- **The double path is bit-identical.** All seam machinery is reverse-active-only
  (`if constexpr`); the `double` production path and the full test suite are
  unchanged.

### Stage ledger (this session, all on `claude/reverse-mode-ff16-tvyl4f`)

| Stage | What | Verified |
|---|---|---|
| A | scalar-template TF24/TF24f strategy + environment on `S` | `double` bit-identical |
| B | leaf `supplied_derivative` seam + birth-height IFT | Gate-0 ~1e-5 |
| C | resident soil coupling (`resource_depletion` → `value_type`, soil-ψ seam channel) | Gate-0 |
| D | TF24f collar-ψ channel (leaf runs at the tracked collar state) | seam FD ~1e-4 |
| E | resident light→leaf seam channel (self-shading) + `k_I` radiation | Gate-0 |
| F | soil-moisture **stiffness gate** (fixed-replay drift assessment) | see #48 below |
| — | #44 seam FD gating on `shouldRecord()` (~12× on the growing SCM) | bit-identical wiring |
| — | #46 forward-tangent NaN (`pow(0, active)` in `compute_competition` at z=0) | fixed, closed |
| — | Tier-B uptake **model-as-run** collar (fixes 14–48% frozen-collar error) | Gate-0 ~1e-5 |
| — | #47 **analytic per-layer** `d(uptake)/d(collar)` (piecewise `E`, FD is wrong) | ~1e-10, closed |

### Stiffness (Stage F, #48)

The docs deferred TF24/TF24f *resident* on a "replay-stiffness wall"
(`ad-touchpoint-catalog.md` X.7/Q25): `advance_fixed` replays the double-adaptive
grid with no error control, and the stiff soil↔canopy coupling was expected to
drift off it. **Measured empirically** (the prescribed double-replay-error gate):
the fixed-replay drift stays **bounded at ~1e-4…1e-3** across wet→dry and
short→long, *including deep water-limited drawdown* (soil to ~57% depletion) — the
wall is **not hit**. Stiffness manifests as **runtime** (adaptive step-count
explosion at dry × long lifetime), not incorrectness, and ~1e-3 drift is below the
census-metric FD noise floor. **Recommendation:** relax the Q25 deferral to a
**drift gate** + runtime caveat, not a hard refusal (see #48).

## Verification — Gate-0 leaf-level FD is the trustworthy oracle

The load-bearing lesson of this session: **verify at Gate-0 (single leaf / single
individual, smooth output, clean FD)**, not against the growing-SCM census metric.
The census functional `compute_competition(0)` is a trapezium over an adaptively
refined, moving cohort mesh; its FD is ~%-noisy and repeatedly gave misleading
results (a single-δ sign flip; a spurious ~1.2× gap). Gate-0 leaf FD, by contrast,
cleanly caught two real defects (the 14–48% frozen-collar uptake error, and the
piecewise-`E` collar-derivative issue) and validated every fix to ~1e-5.

Cross-checks used:
- **Forward-JVP vs reverse-VJP** (FD-free dot-product oracle, `odelia/gradient.hpp`):
  agree up to the frozen-leaf term; both disagree with census FD by ~20%,
  confirming the reverse gradient is consistent and the FD reference was the
  unreliable party. (A fully-clean oracle needs a forward leaf seam — deferred.)
- **`tf24_stiffness_drift`** — the double-replay-error gate (adaptive vs
  fixed-replay), the stiffness assessment above.
- Committed regression tests: `test-ad-tf24f-collar-uptake.R` (+ its two drivers)
  guard the #47 analytic collar-uptake term (leaf-level and seam, both ~1e-10).

## Branch / commit state

| Repo | Branch | Head | Contents |
|---|---|---|---|
| plant | `claude/reverse-mode-ff16-tvyl4f` | `2ec48414` | FF16 forward-instantiable; TF24/TF24f Stages A–F; Tier-B soil coupling; #44/#46/#47 |
| superproject | `claude/reverse-mode-ff16-tvyl4f` | `5c4b0d7` | submodule pointer bumps |

The earlier activation-foundation stack (FF16+K93 activation, interpolator routing,
skeleton threading, the census-gradient geometric compression) is upstream of this
branch; see the git history and the prior handover for those PRs.

## Next steps

1. **TF24f resident end-to-end uptake verification.** The collar-uptake term is
   verified at the seam (seed the collar, read `consumption_rate`), but a
   *resident* growing-SCM check (soil-state or resource-depletion functional,
   avoiding the noisy census metric) would close the loop where the tracked collar
   is a live taped state.
2. **Relax the stiffness deferral (#48).** Adopt `tf24_stiffness_drift` as the
   standing drift gate (refuse only above tolerance) instead of the blanket
   resident-defer; promote the driver into the suite.
3. **TF24 Tier-A — O(1) exact leaf partials (`#44`, deferred).** Replace the O(P)
   FD leaf seam with the nested-AD envelope+KKT scheme (one recording, K+2
   re-seeds). Needs a cache-free templated leaf body and, ideally, the odelia
   `supplied_derivative_envelope` surface (co-design sketched on #44). O(P) is
   accepted for now, so this is an optimisation, not a blocker.
4. **R-facing gradient API** (`ad-implementation.md` §8.1/§8.2, step 5) —
   `stand_gradient_cpp` + the R wrapper, so census gradients are reachable from R,
   not only the C++ harness.
5. **FF16 census gradients** — port FF16's `∂g/∂h` rate path to forward-mode
   instantiable (`rebind`) so it inherits the shared Species-level geometric
   compression.
6. **Decide the K93 default** — flip `node_geometric_compression` to `TRUE` and
   re-baseline the ~0.2% snapshots if the geometric discretisation is adopted.

## Build & verify

```r
# after ANY odelia header edit: reinstall (plant compiles against installed headers)
#   $ R CMD INSTALL odelia
Sys.setenv(TESTTHAT_PARALLEL = "false"); options(testthat.parallel = FALSE)
library(odelia)
pkgload::load_all("plant", quiet = TRUE)     # compiles plant C++ incrementally
# TF24/TF24f AD gates + the #47 regression:
testthat::test_file("plant/tests/testthat/test-ad-tf24f-collar-uptake.R")
testthat::test_file("plant/tests/testthat/test-strategy-ff16.R")   # bit-identity guard
testthat::test_dir("plant/tests/testthat", reporter = "silent", stop_on_failure = FALSE)
```

The full plant suite is green with `node_geometric_compression` **off** (the
default); `test-strategy-k93.R`'s "offspring production is unchanged" snapshots are
the K93 forward-output guard, and `test-control.R` pins the `Control` field set. A
changed number in `test-strategy-ff16.R`'s reference means you broke bit-identity —
diff the floating-point order, not just the value.

## Gotchas

- **Verify the active path at Gate-0, not the census metric.** A `double`-identical
  suite does not verify the gradient; the growing-SCM census FD is too noisy to
  trust (it fooled this session repeatedly). Single-leaf/single-individual FD is
  the trustworthy oracle.
- **Uptake is non-stationary in the collar.** Freezing the collar (correct for
  profit by the envelope theorem) drops `∂(uptake)/∂collar·dcollar/dθ`. Base TF24
  needs model-as-run (re-optimise the collar); TF24f needs the analytic per-layer
  `∂E/∂collar` (a straight FD is wrong — `E_from_Soil_to_Root_Collar` is piecewise
  per soil layer).
- **Do not template the shed** (leaf / soil curves / QAG / FD / `r_*` facades) — it
  participates only through `supplied_derivative`. Over-templating is the failure
  mode to avoid.
- **`pow(active_base=0, active_exp)` NaNs the tangent** via `log(0)` in the
  derivative formula even when the value is exact — guard `z==0`-type boundaries
  (the #46 fix). This bites forward mode loudly and reverse mode latently.
- **Reinstall odelia after an odelia edit** — plant builds against the *installed*
  odelia headers, not the submodule working tree.
- **Regenerating RcppR6 is needed only when you add/remove a registered field** —
  not for ordinary scalar-templating (`X_<S>` + `using X = X_<double>` keeps the
  binding names resolving).
