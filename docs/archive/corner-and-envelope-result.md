> **ARCHIVED 2026-07-29 — its central conclusions do not describe the production regime.
> See [`../audit-2026-07.md`](../audit-2026-07.md).**
>
> **This is the most misleading document in the corpus and the reason the audit happened.**
> It concludes that TF24's collar operating point is a corner "at every state that
> solves", that this is "the ordinary case", and that an envelope-justified adjoint loses
> **89–100%** of the carbon-channel derivative. Report 06 §6 derives the whole reverse pass
> *from* the envelope theorem, so if that conclusion held the design would be dead.
>
> **It does not hold.** Every measurement here is on a **single soil layer at
> `test-leaf.r`'s parameters** — a configuration §5 of this very document admits is
> degenerate, with `soil_consumption_` measuring 1e-13 to 6e-11. In that configuration
> `p*` is pinned at `bound_a`, the zero-uptake collar. §3's own table gives it away: the
> offset `p* − psi_soil` is **0.004900 at every state**, which is exactly
> `grav_head_z_[0] = 9.8e-3 × 0.5`. The "corner" is a bound pinning in a leaf that is
> barely transpiring, not a feature of the objective.
>
> Measured on a production run instead (report 06 §9, develop build, 10 153 records):
> corner incidence **zero**; minimum margin **0.02688 MPa**, 27× `GSS_tol_abs`, growing
> with dryness; the operating point a genuine **stationary interior maximum**
> (`|∂Π/∂p| ~ 1e-5 … 1e-7` at tight tolerance); and the envelope holding to
> **0.006–0.9%** on `d(profit)/dψ`. What *is* wrong on the production path is the
> **co-output**: `d(consumption)/dψ` is off by **47.6–53.2%**, fully explained by
> cancellation of the search's own error, and that is report 06's subject.
>
> **What survives.** §2's geometry of the shelf is real and report 06 identified every
> number on it (`ci` = 4.330575 = `gamma_25 · umol_per_mol_to_Pa`; the 1.5000 jump is
> exactly `R_d`; the physically correct replacement, the net-zero compensation point at
> 5.490638, is a closed-form quadratic root). §5's refusal to conclude anything about the
> water channel from a degenerate probe was correct and should have been applied to §1 and
> §4 as well. §6's "Report 2's Newton polish is doubly dead" is **withdrawn** — it rests
> on §1.
>
> The lesson, recorded because it is general: **a probe's configuration is part of its
> result.** A single-layer leaf at hand-set potentials is not the production path, and this
> document says so in §5 while generalising from it in §1, §4 and §6.

# The corner, and what freezing the operating point costs — measured on develop

Settles two open items from `05-soil-plant-coupling.md`: whether the collar operating point
is a stationary maximum or a corner (§3, previously measured only elsewhere), and what an
envelope-justified adjoint that freezes the operating point actually loses (§3's severity,
previously **inferred**).

Both run from R against **develop** using surfaces develop already exposes —
`find_root_collar_psi`, `evaluate_root_collar_psi`, and develop's own exact analytic gradient
`dprofit_droot_collar_psi`. No instrumentation, no code change. Harnesses:
`scripts/corner_probe.R`, `scripts/envelope_gap_probe.R`.

Single soil layer so the operating point is unambiguous and soil potential is the only knob;
`GSS_tol_abs` tightened to 1e-10 so the geometry is measured rather than the search's
resolution. Leaf parameters are `test-leaf.r`'s.

---

## 1. The operating point is a corner, at every state that solves

The classifier is a **sign change**, not a magnitude. At an interior maximum `dprofit/dp`
passes through zero, so it is positive just below `p*` and negative just above. Measured, at
`d = 1e-4 * p*` either side:

| psi_soil (MPa) | p* | profit | g(p*−d) | g(p*) | g(p*+d) | sign change? |
|---|---|---|---|---|---|---|
| 0.05 | 0.0754 | −0.011 | 0.00121 | 0.00113 | 0.00105 | no |
| 0.20 | 0.2049 | −1.694 | −1.282 | −1.282 | −1.283 | no |
| 0.50 | 0.5049 | −1.206 | −4.287 | −4.287 | −4.288 | no |
| 1.00 | 1.0049 | −4.718 | −8.760 | −8.760 | −8.761 | no |
| 1.50 | 1.5049 | −10.060 | −11.94 | −11.94 | −11.94 | no |
| 2.00 | 2.0049 | −16.476 | −13.43 | −13.43 | −13.43 | no |

**Zero of six.** The gradient is one-signed and essentially constant across `p*` everywhere.
So the operating point is not a stationary point at any sampled state, and the corner is not
an edge case — it is the ordinary case.

Note the slope is **state-dependent**: −1.28, −4.29, −8.76, −11.94, −13.43 as the soil dries.
Report 5 §3 quotes −8.8, which corresponds to `psi_soil ≈ 1.0`. It should be read as one point
on a curve, not a constant.

## 2. The geometry, directly

Mapping `evaluate_root_collar_psi` finely across the interval at `psi_soil = 2.0`, and reading
`ci_` at each point to identify the branch:

| offset from p* | profit | ci | slope |
|---|---|---|---|
| −0.300 | −17.976 | 4.3306 | — |
| −0.030 | −17.976 | 4.3306 | **0.000** |
| −0.001 | −17.976 | 4.3306 | **0.000** |
| **+0.001** | **−16.490** | **5.4910** | **−13.43** |
| +0.030 | −16.880 | 5.5023 | −13.46 |
| +0.300 | −20.537 | 5.5855 | −13.54 |
| +0.600 | −24.548 | 5.6538 | −13.15 |

A flat shelf with slope **exactly 0.000** and `ci` **exactly constant**, a jump of **1.5000**,
then a smooth decline. `ci` steps 4.3306 → 5.4910 across it. This reproduces report 5 §3's
table (4.331 / 5.488, jump ~1.5) on develop, and confirms the mechanism: on the shelf the
inner assimilation solve returns its non-productive fallback at a pinned operating point, and
`p*` is the smallest collar magnitude at which the productive branch exists.

## 3. `p*` tracks the soil one-for-one

Measured `dp*/dpsi_soil` = **1.00000** to five digits at every state, and

| psi_soil | p* | p* − psi_soil |
|---|---|---|
| 0.50 | 0.504900 | 0.004900 |
| 1.00 | 1.004900 | 0.004900 |
| 1.50 | 1.504900 | 0.004900 |
| 2.00 | 2.004901 | 0.004901 |

**The offset is constant.** So the plant does not hold its collar potential as the soil dries —
it holds the *gradient* between soil and collar, which is what drives uptake. That is a clean
structural fact about the coupling and it has two consequences below.

**It also makes a frozen evaluation ill-posed near the corner.** Because the corner moves with
the soil at rate ~1, holding the collar at the unperturbed `p*` while perturbing the soil lands
on the *opposite branch*. A naive frozen finite difference therefore returns the jump height
divided by the step — diverging as 1/step (measured −752, −7503, −75003 at steps 1e-3, 1e-4,
1e-5) — which is not an estimate of anything. Any probe of this kind needs a branch check;
`ci` supplies one.

## 4. What freezing the operating point costs: 89–100% of the derivative

Decomposing the total derivative of the carbon channel,

    d(profit)/d(psi)  =  [explicit partial at fixed p*]  +  g * dp*/dpsi

with `g` from develop's analytic gradient and both finite differences taken at `d = 1e-4`
(stable to five digits over steps 1e-3 … 1e-4, branch-checked):

| psi_soil | total | g | g · dp*/dpsi | explicit | argmax share |
|---|---|---|---|---|---|
| 0.50 | −4.810 | −4.287 | −4.2886 | −0.521 | **89.2%** |
| 1.00 | −9.072 | −8.760 | −8.7603 | −0.312 | **96.6%** |
| 1.50 | −12.035 | −11.94 | −11.9356 | −0.099 | **99.2%** |
| 2.00 | −13.349 | −13.43 | −13.4249 | +0.076 | **100.6%** |

**The argmax's motion is essentially the whole derivative, and the share grows toward 100% as
the soil dries.** An envelope argument keeps only the `explicit` column, which falls from −0.52
to within finite-difference noise of zero.

So the finding is stronger than report 5 §3's claim. Freezing the operating point does not drop
a first-order *correction* — it drops **the derivative**, retaining a residual that is 11% of
the answer at the wettest state sampled and indistinguishable from zero at the driest.

Two honest limits on the `explicit` column: it is a difference of two similar measured numbers,
so at `psi_soil = 2.0` its magnitude (0.076 against a total of 13.3) is at the finite
difference's own accuracy and should be read as "small and possibly zero" rather than as
"+0.076". And the share exceeding 100% is that same noise, not a real overshoot.

## 5. The water channel is NOT settled here, and this configuration cannot settle it

`soil_consumption_` at the re-solved operating point measures **6.97e-13, 8.98e-12, 3.26e-11,
6.21e-11** across the four states, with `d(consumption)/d(psi)` around 1e-9. Those are
degenerate magnitudes: a single-layer leaf at these parameters is barely transpiring, so ratios
computed from them are not informative. This is exactly the caveat raised on
`aornugent/plant#60`:

> A standalone-leaf forward proxy is too degenerate to be decisive (E_up drops to ~1e-13 at
> hand-set operating points); use a real patch state.

What §3's constant offset *suggests* — that with `p*` tracking the soil one-for-one the driving
gradient is nearly invariant, so uptake responds weakly to soil potential at the re-solved
operating point — is consistent with the numbers but cannot be concluded from them. **The water
channel needs a real transpiring patch state**, and that remains open.

This matters for the design, because the water channel is the one issue #60 argues is
load-bearing: `profit_` is the value function and `soil_consumption_` is a non-stationary
co-output. §4 establishes that even the *value function* is not envelope-safe here, which is
the stronger and more surprising half; the co-output's magnitude is still to be measured.

## 6. What this settles, and what it changes

**Settled.**
- The corner is real on develop, at every sampled state, by develop's own analytic gradient
  (§1, §2). Report 5 §3 moves from *measured elsewhere* to *measured here*.
- Its incidence is not rare — it is the ordinary case, so report 5 §3 describes the production
  path (§1).
- Freezing the operating point costs 89–100% of the carbon-channel derivative (§4). Report 5
  §3's severity moves from *inferred* to *measured*, and understates it.
- `dp*/dpsi = 1` with a constant offset (§3), which is a new structural fact and the reason a
  frozen probe is ill-posed.
- Report 2's Newton polish is doubly dead: no interior root exists (§1), and the quantity it
  was protecting — the envelope argument on `profit_` — is not available either (§4).

**Changed.**
- Report 5 §3 quotes −8.8 as *the* slope. It is state-dependent, −1.3 to −13.4 over the sampled
  range, growing with dryness (§1).
- Report 5 §1's "what this report does not claim" no longer applies to the carbon channel and
  should be narrowed to the water channel.

**Still open.**
- The water channel's magnitude, on a real patch state (§5). This is the remaining half of
  `plant#60`.
- Whether a bracketing root-find on `dprofit_droot_collar_psi` converges cleanly to this corner
  in practice. §1 shows the gradient is one-signed *across* `p*`, so there is **no sign change
  to bracket** at the corner itself — the sign change is between the shelf's exactly-zero
  gradient and the branch's −13.4. Whether a bracketing method locates that reliably is a
  question the proposed primitive now has to answer, and §1 makes it sharper rather than
  softer.
