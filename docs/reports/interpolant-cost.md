# What a slope-carrying light interpolant costs

Report 3 projected **+11.8%** on the forward run and called it the proposal's weak
point. This records what four measurements say instead. Harness:
`docs/reports/interpolant-cost.cpp` (build line in its header); the plant-side change
it needs is `docs/reports/canopy-shape-fused-q.patch`, against develop
`96941d3b`. Baseline for every projection is the build census in
`spline-build-census.md`: 20 304 builds, **3.916 s of a 59.5 s** TF24 run at
`max_patch_lifetime = 105.32`, 65 knots, `rescale_spline` at **193.2 us** per call.

## 1. The slope is the same object the value sweep already computes

`Q(u) = (1 - u^eta)^2` and `q(u,z) = 2 eta (1 - u^eta) u^eta / z`, so

    d/dz [k_I * A_j * Q(z/H_j)]  =  -k_I * A_j * q(z/H_j, z)

Verified against a central difference over the crown: worst
`|FD(dQ/dz) + q| / max|q|` = **2.243e-10**, which is the central difference's own
truncation at `d = 1e-6 H`, not an error in the identity.

Both are written in terms of one `pow_eta_(u, eta)` — the only non-trivial operation
in either. So a build that wants the pair does not want a second sweep.

**A defect this exposed in develop.** `q` as written divides by `z`, and at the
ground `q(0,0) = 2 eta (1-0) * 0 / 0` is **NaN**. The field's lowest knot is exactly
`z = 0` (`ResourceSpline::construct_spline` sets `lower_bound = 0.0`), so the moment
anything asks the field for its slope at the ground it gets NaN. Writing `q` over
`u^(eta-1)/H` instead of `u^eta/z` — equal for `z > 0` — is finite there (`q = 0` for
every `eta > 1`, `1/H` at `eta = 1`) and removes a division from the hot path. Measured
at the ground knot: `Q = 1.000000`, `q = 0.000000`, against `-nan` from the `z` form.

This is the same family as the recorded `pow(0, eta)` hazard, at the same knot.

## 2. Fusing the two sweeps roughly halves the extra work

Per-knot trapezium sweep over the cohorts, with the kernel behind a call boundary
(plant compiles with no `-flto` and no `UseLTO`, so `Individual::compute_competition`
is a real call per cohort per knot; a genuine two-translation-unit build gave 15.2 us
against `noinline`'s 15.1 us on the 141-cohort value sweep, so the stand-in is fair).

| eta | cohorts | value | two-pass | fused | two/value | fused/value |
|---|---|---|---|---|---|---|
| 12 | 40 | 4.75 us | 11.77 us | 7.20 us | 2.48 | **1.52** |
| 12 | 141 | 14.52 us | 39.83 us | 27.06 us | 2.74 | **1.86** |
| 12 | 300 | 30.41 us | 83.61 us | 51.50 us | 2.75 | **1.69** |
| 4 | 141 | 13.95 us | 36.62 us | 23.90 us | 2.63 | **1.71** |
| 11 | 141 | 66.91 us | 143.98 us | 98.23 us | 2.15 | **1.47** |

`eta = 11` is unspecialised, so `pow_eta_` is a libm `pow` and dominates; sharing it is
worth most there. Run-to-run spread on these ratios is about +/-0.1 — one sampled row
(eta 12, 300 cohorts) came back at 1.03 once and 1.69-1.79 on three re-runs.

**Two-pass costs 2.1-2.8x the value sweep; fused costs 1.5-1.9x.**

## 3. The Hermite build step is 10x cheaper than the cubic's

Kernel evaluations excluded — purely turning knot values into a queryable object.
`basic_interpolator::initialise` calls `spline::set_points`, which assembles a
`band_matrix` (two `std::vector<std::vector<double>>` bands, so one heap allocation
per row per band) and runs an LU solve whose `l_solve`/`r_solve` each return a fresh
vector. `hermite_interpolator::init` has no linear system: one pass over the spans,
and its storage is reused across calls.

| knots | cubic band solve | hermite spans | ratio |
|---|---|---|---|
| 17 | 0.738 us | 0.078 us | 0.106 |
| 33 | 1.430 us | 0.140 us | 0.098 |
| **65** | **2.556 us** | **0.258 us** | **0.101** |
| 129 | 5.019 us | 0.494 us | 0.098 |

A credit of **2.30 us per build**, so **-46 ms** over 20 160 rescales, independent of
everything else.

## 4. At matched knot count the Hermite wins on value AND slope

141 cohorts, errors normalised on the global range of the target (never pointwise:
light spans [~0,1] and `dQ/dz` is flat to roundoff at small `u`, where a pointwise
ratio divides a cancelled difference by a 1e-26 analytic value and reports 1.0).

| knots | cubic value | hermite value | cubic slope | hermite slope |
|---|---|---|---|---|
| 9 | 1.695e-01 | 3.739e-02 | 7.385e-01 | 1.776e-01 |
| 17 | 4.541e-02 | 1.041e-02 | 3.039e-01 | 7.208e-02 |
| 33 | 1.801e-03 | 1.139e-03 | 4.468e-02 | 2.918e-02 |
| **65** | **6.574e-04** | **4.465e-04** | **2.894e-02** | **1.949e-02** |
| 129 | 3.171e-04 | 1.339e-04 | 2.501e-02 | 1.015e-02 |

**This removes report 3's premise.** That report projected +11.8% from **142 knots
against 65**, on the reasoning that the knots must sit at the cohort tops because that
is what buys the convergence. The Hermite does not need them to *beat* the cubic: on
plant's own 65-knot set it is better on value (1.47x) and on slope (1.48x). The
cohort-top set buys much more slope accuracy and remains the right choice if the slope
consumer demands it — but it is a choice, not a precondition, and the two knot sets are
now separately priced.

Note both interpolants converge slowly here. At 65 knots neither can resolve 141 cohort
tops, so the error is set by unresolved curvature breaks rather than by polynomial
order. That is why 33 -> 65 gains so little for either.

## 5. The projection, on plant's existing 65 knots

Everything not in the interpolant choice — the `get_x` copy, `util::rescale`,
`clear()`, the `add_point` loop, `exp()` per knot — is common to both designs and
cancels in the delta.

| | build | run | change |
|---|---|---|---|
| develop | 3.916 s | 59.5 s | — |
| Hermite, upper bound | 7.05 s | 62.6 s | **+5.3%** |
| Hermite, lower bound | 4.11 s | 59.7 s | **+0.33%** |
| report 3's projection | 10.96 s | 66.5 s | +11.8% |

The **upper bound** assumes the whole 193.2 us per build scales by the fused 1.8x. The
**lower bound** assumes only the measured parts scale: +0.8 x 15 us of sweep, minus
2.30 us of band solve, = +9.7 us on 193.2 us.

**The bracket is wide because one thing is unmeasured, and it is not what I first
assumed.** The sweep accounts for 15 us and the band solve for 2.6 us — **17.6 us of
193.2 us. 91% of the per-build cost is unattributed.** The obvious candidate was
plant's missing LTO; that was tested and **rejected** (section 2: a real cross-TU call
boundary moved the sweep 14.0 -> 15.2 us, not to 190). So the mechanism is still open,
and the honest reading is that the bracket's width *is* that ignorance.

## What is left to measure

1. **Profile `rescale_spline` itself** and attribute the missing 91%. This is the
   single measurement that collapses +0.33%..+5.3% to one number, and it is worth
   doing on its own account: if 175 us per build is avoidable, that is 3.5 s of a
   59.5 s run available to develop with no AD work at all.
2. **Wire the Hermite into `ResourceSpline` on the 65-knot set** and time it, rather
   than composing separate measurements as section 5 does.
3. **Decide the knot set from the slope consumer, not from the build cost.** Section 4
   prices both; which one is needed depends on the accuracy the slope is read at.
4. **Land the `q` rewrite regardless of the interpolant.** Section 1's NaN is a defect
   in develop, reachable independently of anything proposed here.
