# T4 — filtered-field probe: the fast `u`-texture is J-irrelevant (arbitrage confirmed)

*2026-07-21. v2 Oracle response, claim 5: the O(M) member block is being integrated
at the fast block's resolution — but does J need it? Open-loop offline test on the
saved `intense_storms` 12-yr field, reusing the validated overwrite/replay path.
Recover the resident soil trajectory `u* = sweep_soil(a*)`, FFT low-pass it at a
sweep of cutoffs, overwrite the cache, re-advance member A as a probe, read J.
Script: `scripts/tf24-benchmarks/filtered_field_probe.R`.*

## Result

Baseline `J_0` (A on the unfiltered swept soil, same overwrite path) = 2.80e-7,
2.8% from the resident J (the overwrite-path discretisation, as in 9b). J vs cutoff:

| cutoff (cyc/yr) | texture removed below | J/J_0 |
|---|---|---|
| ∞ (none) | — | 1.000 |
| 730 | ~½ day | 1.022 |
| 365 | ~1 day | 1.022 |
| 180 | ~2 day | 1.028 |
| 52 | ~1 week | 1.136 |
| 12 | ~1 month | 2.273 |
| 4 | ~3 month | 15.57 |
| 1 | ~1 year | 5.4e6 |

**J is invariant to ~3% under removal of all `u`-texture below ~2 days**, bends by
+14% at the weekly scale, and only then diverges (2.3× monthly, 15× seasonal, blow-up
annual). The knee sits between weekly and monthly.

## Reading

The member block does **not** need the fast sub-daily/sub-weekly ripple in `u` — the
exact texture the shared global step (median `2–7×10⁻⁴` yr ≈ 0.07–0.26 day) is
currently resolving. It needs only the **~weekly-and-slower envelope** of `u`.

So the O(M) block is being integrated `~30–100×` finer than J requires:
- a member step at the **sub-weekly** scale holds J to a few %;
- at the **weekly** scale (~7 day) J is within ~14%.

Against the current sub-daily step this is a **~30–100× reduction in full-M solves** —
the largest single arbitrage identified. It licenses an **averaged member advance**
(members at macro steps; `u` sub-cycled to supply the slow envelope), *provided* a
cheap fast refresh of `a(u)` exists — which is exactly what T6 (Newton-on-g, analytic
`∂a/∂u`) would supply. T4 and T6 are therefore paired: T4 says the arbitrage exists,
T6 says whether the refresh that unlocks it is cheap.

## Caveats

- **Open-loop.** The probe sees the filtered `u` directly but does not feed back;
  with loop gain κ≈10 (9b) the closed-loop J-change could be larger. But the *flat
  region* is the robust licensing read: the probe already sees the removed texture, so
  its invariance to that removal is direct evidence the texture does not drive J.
  Confirm as a closed-loop model variant where only `g` sees the filtered `u`.
- **`u` only, `s` held.** `overwrite_cached_soil` filters the soil block; the cheap
  `s` aggregate is held at resident. `s` is flat in M and slow, so unlikely to carry
  J-relevant fast texture, but not separately tested here.
- **Single sequence/horizon** (intense_storms, 12 yr). The knee location may shift with
  forcing (a monsoonal burst sequence could push J-relevant structure to finer scales);
  re-run on a burst-dominated sequence before sizing a production macro step.
