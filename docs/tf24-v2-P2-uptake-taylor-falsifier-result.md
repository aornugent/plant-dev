# P2 — Path-A falsifier: the cheap uptake-refresh assumption HOLDS (dry-limit death mode falsified)

*2026-07-22. The speed arbitrage (T4/T6) advances cohorts on a weekly macro-step while
soil water sub-cycles, refreshing total uptake `a` from soil water `u` cheaply instead of
re-solving all cohorts. It dies if `a(u)` curves too fast to refresh cheaply — the old
multirate/held-`a` attempts died exactly this way (freezing `a` plateaus at ~10% error),
and the fear was that it breaks near the dry limit where response is 50–291× hypersensitive.
Cheap offline test, existing machinery only (recorded uptake `a*(t)` + `u*(t)=sweep_soil`):
per soil layer, per weekly window, fit uptake ~ poly(layer water) at degree 1 and 2; the
relative residual is how far uptake departs from a cheap Taylor refresh. Split windows by
wetness tercile to probe the dry limit. Script: `uptake_taylor_falsifier.R`.*

## Result (two scenarios)

| | weekly Δu (driest, med) | linear resid (med) | quad resid (med) | quad DRY tercile (med) | quad WET tercile (med) |
|---|---|---|---|---|---|
| intense_storms (12 yr, 172 win) | 0.008 | 0.097 | 0.046 | **0.009** | 0.085 |
| extended_drought (20 yr, 298 win) | 0.009 | 0.139 | 0.090 | **0.013** | 0.187 |

(p90 of the quadratic residual is 0.20–0.29 on both — a minority tail of hard windows.)

## Reading — PASS, and the feared failure mode is falsified

- **Uptake is a low-order function of soil water in most weekly windows** (median quadratic
  residual 5–9%; a real refresh using the analytic slope across all layers, not this crude
  per-layer 1D fit, would do better — this is a lower bound on refresh quality).
- **It is *most* predictable near the dry limit** (dry-tercile median ~1%), the exact
  opposite of the "dies near bounds" fear. Physically: near the dry limit soil water barely
  moves per week (small Δu) and uptake tracks it smoothly. **The Oracle's death condition —
  "re-expands every fast step near bounds, and bounds dominate" — is NOT met.**
- **The hard windows are WET / high-swing** (wet-tercile median 8–19%, plus a ~⅓ tail),
  where storms move soil water fast. These are exactly the windows a **trust-monitored
  re-expansion / local sub-step** is designed to catch — the T6 design already anticipates
  this ("re-expanded on demand," not frozen across a macro excursion).

## Verdict: GO to the T6 build (Newton-on-uptake), eyes open

The core assumption of the speed arbitrage — uptake is cheaply refreshable as soil water
moves over a weekly macro-step — **holds**, and the specific way its ancestors died
(dry-limit breakdown) **does not occur**. This clears the way to build the analytic
uptake-vs-soil-water slope (Newton on the leaf branch-death condition, which has a real
root — unlike the argmax `∂P/∂p=0` that had none, and unlike the FD-through-bracketing
Jacobian that was noise) and a macro-step scheme with a trust monitor on the wet windows.

**The one caveat to carry into the build:** the wet-window residual is real (8–19%), and
uptake errors amplify ~10× through feedback (T3). Within a macro-step with a trust monitor
that re-syncs at macro boundaries this is transient (not a persistent field bias), but the
**end-to-end offspring accuracy of the macro-stepped scheme must be measured**, not assumed
— that is the build-and-measure question P2 cannot settle. The 30–100× cohort-solve saving
(T4) is the prize; the wet-window trust-monitor rate sets how much of it is realised.

## Caveats
- Per-layer 1D fits (crude); a real refresh uses the cross-layer slope + can re-expand
  mid-window — so these residuals over-state the true refresh error.
- Per-window relative residual can inflate on near-flat windows (tiny range); the medians
  (the robust signal) are small, the inflation lives in the p90 tail.
- Two scenarios; the dry-limit result is consistent across both and is the load-bearing one.
