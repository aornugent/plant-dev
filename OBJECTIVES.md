# Objectives

Heuristics choose TF24's node introductions and ODE steps together, so that
reverse mode gives stable `J` and gradients, for residents and invaders, on any
rainfall record: constant, variable, wet, dry or episodic.

- **Accurate.** What a workflow consumes is within ε of the converged answer.
  ε is a tenth of the quantity's spread across realistic records of one
  climate. It is set once and held across the bank. Judged by default:
  1. `ln J`, and the balance `F = ln J − ln b`;
  2. the invader's selection gradient `g` at the resident's traits, each trait
     as an elasticity `d ln R′ / d ln θ′`;
  3. the error of any scalar outcome a workflow differentiates (a misfit, an
     evolved trait), as its adjoint-weighted sum of the errors above;
  4. the sign of fitness where a decision turns on it: an entry, an exclusion,
     a certificate that nothing invades.

  The resident's elasticities `d ln J / d ln θ` are judged on request. They are
  ingredients of Jacobians, not answers, and an error in a Jacobian slows a solve
  without moving its root.
- **Stable.** The answer is set by the traits and the rainfall, not by the
  controller's incidental choices:
  1. *Reproducible:* nudging a knob (`tol` by ±5%, or the introductions by a
     quarter of their spacing) moves it by less than ε/3.
  2. *Continuous in the traits:* on one schedule, the answer changes smoothly as
     the resident's θ or an invader's θ′ moves.
  3. *Predictable:* its error falls with each knob at that knob's order, so a
     second, looser run estimates a run's error.
  4. *Never fails:* nothing throws over the trait range, for residents or
     invaders.
- **Shared.** A schedule is held through a solve (a calibration, an equilibrium,
  an assembly) and certified once at its root, not at every step of it. Invaders
  run on their resident's schedule, every introduction of it.
- **Performant.** The least runtime at ε, compared at matched error, not at
  matched `ode_tol`. Heuristics use what the trait × climate dynamics offer.
  Where the dynamics offer nothing, the controller refines to brute force, which
  carries the same guarantee.
- **Diagnosed.** Every run reports its error estimate per judged quantity, the
  schedule it was held on, and its failures.

## Numbers

- **ε,** from eight daily-weather seeds of the long-drought climate: 0.025 in
  `ln J` and `F`. For an elasticity it is a tenth of the trait's own spread: for
  the invader, 0.20 for `lma` and 0.050 for `a_dG2` (the resident's, when asked
  for, 0.087 and 0.019). It is never under 0.01, since an elasticity off by 0.01
  moves a prediction of `ln J` across ×0.5–×2 by under ε/3; a quantity with no
  spread by construction (`S_D`, `a_f3`) takes 0.01. The table is
  `harness/schedule/data/eps.csv` (its derivation is `docs/measurements/eps-spread.md` on
  the tag `archive/trusting-curie`).
- **Why g and not the resident's elasticities:** at the canonical schedule both
  sets converge in one pass on the same schedule. On a coarser one, judging the
  elasticities accepted runs with `g` 2.2ε and 7.5ε off on long-wet, where judging
  `g` refined to within 0.21ε (`spikes/refine-judged/`).
- **The bank** of records and cases is `docs/schedule/validation.md`.
