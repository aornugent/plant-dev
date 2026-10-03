# Objectives

Heuristics choose TF24's node introductions and ODE steps together, so that
reverse mode gives stable `J`, gradients and curvatures, for residents and
invaders, on any rainfall record: constant, variable, wet, dry or episodic.

- **Accurate.** `ln J`, each gradient as an elasticity `d ln J / d ln θ`, and
  each curvature are within ε of the converged answer. ε is a tenth of the
  quantity's spread across realistic records of one climate. It is set once
  and held across the bank.
- **Stable.** The answer is set by the traits and the rainfall, not by the
  controller's incidental choices:
  1. *Reproducible:* nudging a knob (`tol` by ±5%, or the introductions by a
     quarter of their spacing) moves it by less than ε/3.
  2. *Continuous in the traits:* as the resident's θ or an invader's θ′ moves
     within a grid's radius, the answer changes smoothly on that one grid.
  3. *Predictable:* its error falls with each knob at that knob's order, so a
     second, looser run estimates a run's error.
  4. *Never fails:* nothing throws over the trait range, for residents or
     invaders.
- **Shared.** One grid serves each local analysis around the resident: a
  fitness landscape, a selection gradient, a curvature. Big steps in θ rebuild
  the grid. Where one grid's radius is shorter than the analysis, several grids
  or a finer one serve it.
- **Performant.** The least runtime at ε, compared at matched error, not at
  matched `ode_tol`. Heuristics use what the trait × climate dynamics offer.
  Where the dynamics offer nothing, the controller refines to brute force, which
  carries the same guarantee.
- **Diagnosed.** Every run reports its error estimate, how far its θ is from
  the grid's θ₀ against the grid's radius, and its failures.

## Numbers

- **ε,** from eight daily-weather seeds of the long-drought climate: 0.025 in
  `ln J`. For elasticities it is a tenth of each trait's own spread: for
  residents and invaders, 0.087 and 0.20 for `lma`, and 0.019 and 0.050 for
  `a_dG2`. It is never under 0.01, since an elasticity off by 0.01 moves a
  prediction of `ln J` across ×0.5–×2 by under ε/3; a quantity with no spread by
  construction (`S_D`, `a_f3`) takes 0.01. The table is
  `docs/measurements/eps-spread.md`.
- **One local analysis:** invaders from ×0.5 to ×2 of the resident, and the
  resident within ±10% of θ₀.
- **The bank** of records is set in `docs/design-grid-controller.md`.
