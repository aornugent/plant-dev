# Test 1 result — the forcing spline knots: a real but minor rejection driver

> The cheapest falsifiable test of the fresh Oracle's ranked-first finding
> (the "forcing node lattice"), corrected for the fact that the driver is a
> **C² cubic spline**, not piecewise-linear. Run offline on the saved
> classifier per-step logs (`results/classifier_raw/*.rds`) — no re-run.
> Scripts: `scripts/tf24-benchmarks/node_distance_test{,2,3,4}.R`. 2026-07-20.

## The claim under test

Fresh Oracle, stone 1: the daily forcing knots are "the prime suspect for
the entire broadband accuracy limit … 5–20× on accepted steps." It assumed
piecewise-linear forcing (C¹ kink per knot). **Corrected:** the driver is a
C² cubic spline through daily knots (spacing `DK = 1/365 ≈ 2.74×10⁻³ yr`).
A cubic spline still has a **discontinuous third derivative at every knot**,
so an order-5 method cannot reach full order across one — the weaker
residual worth testing. No prior instrument logged distance-to-knot; the
classifier and the #21 clip only ever looked at sparse *value-change
features*.

## What the data show (5 single-species bank scenarios)

**Density (test 1).** The median accepted step is **0.08–0.22 × DK**;
**84–92 % of accepted steps are sub-knot** (`h < DK`). The daily knots are
*sparser* than typical steps, so most integration runs on smooth cubic arcs
*between* knots. (This corrected an initial worry that steps span many
knots — they do not.)

**Real, size-independent effect (test 3 — the decisive one).** Holding step
size to a 0.15×DK-wide window (so "crosses a knot" vs "fits between" differs
only by *phase*, not size), a step that crosses a knot rejects **+12 to +36
pp more** than an identically-sized step between knots — consistent across
all 5 scenarios, growing monotonically as more of the step sits past the
knot:

| h window | d(pp) range across scenarios |
|---|---|
| [0.30, 0.45]·DK | −1.6 … +9.9 (small/noisy) |
| [0.45, 0.60]·DK | +11.1 … +23.4 |
| [0.60, 0.80]·DK | +20.6 … +35.6 |
| [0.80, 1.00]·DK | +17.8 … +27.5 |

This is the signature of the C²-knot third-derivative jump limiting local
error across a knot. The whole-sample enrichment (test 1: rejects 1.5–1.8×
more likely to span a knot) is *not* merely the "rejects are larger" size
confound (test 2 showed the raw enrichment concentrated at `h≈DK`); test 3
isolates it at fixed size and it survives. **Stone 1's corrected residual is
confirmed as a real mechanism.**

**But a minor lever (test 4).** Size-matched counterfactual — if
knot-spanning attempts rejected at the matched-size non-spanning rate:

| scenario | reject % | counterfactual % | knot-attributable (pp) |
|---|---|---|---|
| extended_drought | 29.7 | 27.8 | **1.8** |
| dry_to_wet | 31.0 | 28.7 | **2.4** |
| intense_storms | 30.2 | 28.9 | **1.3** |
| long_horizon | 27.0 | 24.6 | **2.4** |
| whiplash | 28.5 | 24.5 | **3.9** |

Only **1.3–3.9 pp of the ~27–31 % total rejection** is knot-attributable —
~5–13 % of the rejection overhead. Only **6–16 % of attempts** span a knot
whose value is actually *changing* (flat dry-spell knots have no
third-derivative jump — a cubic spline through equal values is exactly
constant — so they are harmless; this is why the #21 value-change-feature
clip was already ~cost-neutral). The remaining ~90 % of rejection is *not*
knot-related.

## Verdict

**Confirmed as a mechanism, refuted as a significant lever.** The C² spline
knots do cause excess rejection (order reduction across the third-derivative
jump), and they were genuinely uninstrumented before this test — the fresh
Oracle's structural observation ("no instrument ever looked at the grid
nodes") was correct. But corrected from its piecewise-linear premise, the
effect is **~2–4 pp of the ~30 % rejection**, not the 5–20× it was pitched
as. A perfect knot-avoidance scheme would cut total rejection from ~30 % to
~27 %, and the total-*work* win would be smaller still (a knot-clip trades a
rejection probe for a shortened accepted step; and it must not clip
flat-dry-spell knots or it destroys quiescent-period striding).

**Consequence for the frontier.** The forcing joint does **not** reopen the
forward problem. The sub-order-2 "wall" (47× per 3 decades past converged
`J`) is **not** explained by the knots — if it were, the attributable
fraction would be large, not 2–4 pp. The dominant ~26 % rejection and the
low effective order live in the *continuous* structure — the C¹-but-
violently-curved coupling field the ongoing Oracle described — not the
forcing representation. This aligns the two Oracles: the ongoing Oracle's
"integrator is at the efficient frontier" survives the fresh Oracle's
sharpest challenge, now that the challenge is measured.

**If ever pursued** (low priority): the only sensible form is *not* "clip to
all daily knots" (kills dry-spell striding) but clipping the trial step at
the next *value-changing* knot **and its immediate spline neighbours** (the
cubic induces third-derivative jumps a few knots either side of a rain
event), or switching the forcing to a limiter/monotone interpolant that
suppresses the induced curvature. Expected ceiling ~2–4 pp reject, ~1–2 %
work. Not worth a build unless bundled with other forcing-side work.
