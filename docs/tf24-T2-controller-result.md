# T2 — PI step-size controller: built, measured, **net loss** (reverted)

*Result of the T2 design (`docs/tf24-T2-controller-design.md`). Built the PI
(Gustafsson/DOPRI5-stabilised) controller in odelia behind an opt-in flag
(`OdeControl::use_pi_controller` → plant `control(ode_use_pi_controller=)`),
validated toy-first, measured on the bank, then **reverted** — it reduces the
rejection *fraction* but increases *total work*. Knowledge kept here; code removed
to keep production pristine (bit-identical-off made the revert lossless).*

## What was built and validated (toy, Lorenz)

PI predictor in `adjust_step_size`, opt-in; off-path unchanged. Toy A/B:
- **bit-identical off: 0.000e+00** (PI-off reproduces the I-controller exactly).
- **accuracy preserved**: |PI−ref| = |I−ref| = 6.54e-5 @tol1e-6, 6.93e-7 @tol1e-8.
- **order preserved**: both shrink 94× per 100× tol tightening.

So the controller is correct and accuracy-neutral. The question was speed.

## Bank measurement (the decision) — PI costs MORE total work

Outer tol 1e-6, GSS_tol 1e-3, 12 yr. "Total work" = step *attempts* (each an O(M)
RHS sweep — accepted + rejected). Tested facmax∈{2,5}, β∈{0.04,0.08}; results were
insensitive to those (the cap is not the driver):

| scenario | I: attempts (acc / rej%) | PI: attempts (acc / rej%) | total work | J rel |
|---|---|---|---|---|
| intense_storms | 7348 (5250 / 28.6%) | 9452 (7160 / 24.2%) | **×1.29** | 7.8e-4 |
| extended_drought | 11410 (8246 / 27.7%) | 12904 (10466 / 18.9%) | **×1.13** | 1.6e-4 |

The PI **lowers the reject fraction** (0.286→0.242, 0.277→0.189) **but raises the
accepted-step count** (5250→7160, 8246→10466), so total attempts — the actual O(M)
cost — go **up 13–29%**. J is unchanged (converged). Wall time rose to match.

## Why — the reject fraction is a misleading target

The I-controller has a **dead-band** `[0.5, 1.1]×tol`: it *holds* a large step and
tolerates error up to 1.1× tol before rejecting. It runs **hot** — big strides, error
near the limit, ~30% of strides overshoot and are rejected. The PI has no dead-band;
it continuously re-targets a comfortable margin, running **cool** — smaller steps,
few rejections, but many more of them. On this problem the two nearly tie on the
*necessary* (accepted) work, and the PI's extra steps outweigh the rejections it saves.

The rejections are **not tunable over-reach**: they are the price of striding at the
accuracy limit on a problem whose local error is **broadband and unpredictable
step-to-step** (the classifier's finding — the collapse co-locates with nothing). A
predictive controller cannot reclaim them because there is nothing to predict; and a
conservative controller that avoids them pays more in step count. The I-controller's
"stride and sometimes reject" is close to work-optimal here.

## Verdict and disposition

- **T2 does not help.** Reject-fraction ↓, total work ↑ 13–29%, J unchanged. Reverted
  from odelia (`ode_control.hpp`, `ode_interface.cpp`) and plant (`control.{h,cpp}`,
  `RcppR6_classes.yml`); production back to the I-controller, bit-identical.
- **The Oracle's T2 premise is refuted by measurement** (per §7): the 27–35% rejection
  is not reclaimable controller over-reach; it is intrinsic to striding on a
  broadband-error problem. Corollary: the speed side is *not* "hygiene the controller"
  — the forward integrator is already near work-optimal at converged tol. This closes
  the speed question begun in round 5.
- **Untested cheaper variant, if ever revisited:** none of the standard controller
  moves is expected to win, since the error is unpredictable; the only lever left on
  the forward *cost* would be reducing the O(M) per-RHS work itself (member-reduction /
  mesh — a different program), not the controller.

## What remains (accuracy, where the real damage is)

Unchanged by this result: the corner-locator + IFT-node adjoint fix (plant#60, the
first-order-wrong gradient), the E4 verification (task #23), and the J survival-threshold
conditioning. Those are the live levers; the forward step controller is not one.
