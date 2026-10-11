# TF24's dynamics: one switch, three axes

This reads TF24's equations (plant at c8820993, phylloptim 0.9.1) for what causes
what, which traits matter, and the formalism that ties the numerics to the
ecology. The equation references are in the extraction notes kept with the
session; the measurements are in `measurements/predictable-error.md` and
`measurements/breakpoints.md`.

## The causal chain

Everything an individual does passes through one quantity, its **net production**

    P = a_bio·a_y·(A − R) − T                                  (S:2154–2157)

where:
- A is the leaf optimum's assimilation, which depends on light at the crown
  (radiation = k_I·L̄·PPFD) and on the soil water potential of the layers its
  roots reach, through the stem and root vulnerability curves.
- R and T are respiration and turnover of leaf, stem, bark and root mass, which
  scale with lma, rho and size.

P decides each process:

| process | how P enters | equation |
|---|---|---|
| establishment | p_estab = P₀²/(P₀² + (a_d0·a_l0)²) if P₀ > 0, else 0, with P₀ a newborn's P at seed height in the current light and soil | S:2694–2705 |
| growth | dH/dt ∝ P⁺·G(r)·(1 − f_rep(H)), with P⁺ the smooth positive part (ε = 1e-4) and G a logistic gate on relative storage r | S:1989–2001 |
| storage | charges at P⁺(1 − G) when P > 0; drains at about \|P\|·r when P < 0 | S:2044–2048 |
| mortality | d_I + a_dG1·exp(−a_dG2·r) | S:2623–2647 |
| reproduction | P⁺·G·f_rep(H)/(ω + a_f3) | S:2002 |

Two consequences follow:
- **There is no separate soil threshold and no hydraulic-failure hazard.** Drought
  and shade both kill the same way: they push P below zero, the pool drains, r
  falls, and the hazard rises.
- **The establishment gate is P = 0 evaluated at birth,** for a seedling at
  h₀ ≈ 0.31 m whose roots sit entirely in the top 0.3 m layer.

The soil closes the loop:
- Drainage is Campbell's form, K = K_s·x^16.14 with x = θ/θ_s.
- From saturation a layer drains in hours. Below x ≈ 0.6 (θ < 0.26) drainage
  takes months to years, so drying there is set by the stand's uptake.
- Rain arrives as pulses, and a pulse lifts the top layer within hours.

So:
- **An opening** is a rain pulse that lifts the top layer above the seedling's
  water compensation point. That is why every opening follows a rain onset by
  0.2–0.7 days.
- **A closing** is the stand's uptake drying the top layer back below it, or the
  canopy shading the seedling below its light compensation point. A full-light
  newborn on the run's soil finds 71 of 78 gaps; shade makes the rest.
- **Rain and soil without plants cannot place closings.** Without uptake the top
  layer never falls far enough. That is why the soil chain alone shuts creation
  nowhere.

## Where fate is not smooth in birth date

Follow a cohort born at b along its characteristic. Its itinerary is the
sequence of times at which its P crosses zero. Within a set of births that
share an itinerary, fate (survival, size, net reproduction) is a smooth
function of b. Fate breaks only where the itinerary changes, and that happens
in two ways:

1. **The cohort is born on the switch.** P₀(b) = 0 is a creation-window edge.
   A cohort born just inside a closed gap starts with P < 0 and carries one more
   crossing (at the next rain) than one born just after the opening. That gives
   fate a corner: it rises across the gap and falls after the opening.
2. **A cohort's P touches zero later, tangentially.** This is a grazing. On
   constant rain:
   - births before day 23.5315 never cross zero;
   - births after it cross twice (sign-change count 0 → 2): they stall under the
     founders, drain, and die;
   - their cumulative mortality rises from 0.46 to 3.9 within 0.032 days of
     birth date.

Transversal crossings away from these points are harmless:
- In the sharp limit the flow is continuous across P = 0, so the saltation
  matrix is the identity and J stays C² (`design-sign-changes.md`).
- 99.85% of long drought's crossings are transversal.

**The breakpoints are exactly the itinerary changes, and the run already records
them.** Per-node sign-change counts differ across:
- 100% of neighbour pairs that straddle an edge on the finest episodic grid,
  against 3% of other pairs;
- the constant front, between 23.5315 and 23.5320 days.

**How strong a breakpoint is** depends on what the extra excursion below zero
costs:
- On constant, an excursion under the closed canopy is fatal.
- On episodic, a newborn that waits out a dry spell does better the later it
  is born.

Most itinerary changes elsewhere (3–20% of neighbour pairs) are weak. That is
why edges and the one front are enough to restore the square law.

## The trait axes

Every trait with a large elasticity is a term of P or of the height race
(`measurements/eps-spread.md`, resident |elasticity|):
- curv_fact_colim 68.6
- hmat −10.2
- lma −9.6
- r_l −9.1
- stem_P50 8.4
- a_y = a_bio 7.3
- vcmax_25 7.1
- rho −6.9
- D_c 5.4
- jmax_25 5.4

They group into five processes, which act through three behavioural axes:

| axis | processes and traits | what it sets |
|---|---|---|
| **Compensation**: where P = 0 in the plane of light and soil water potential | carbon gain (vcmax_25, jmax_25, curv_fact_colim, curv_fact_elec_trans, a, k_I); costs (r_l, lma via k_l ∝ lma^−1.71, rho via r_s = 4012/rho, a_y, a_bio); water access and safety (stem_P50, stem_c, root_P50, K_s, D_c, rooting_depth_max, a_r1) | the light and water compensation points, hence when windows open and close and who stalls under a canopy: the positions of the breakpoints |
| **Race**: how fast carbon becomes height | da_l/dm (lma, rho, theta, a_l1, a_l2, a_r1, a_b1); allocation to seed (hmat, a_f1, a_f2) | the canopy hierarchy: the width of first-mover layers, where fronts fall, when J is earned |
| **Buffer**: how long P < 0 can be survived | a_st1, a_st2, a_st3, storage_relaxation_offset, a_dG1, a_dG2, d_I | how fatal an excursion is: the strength of a breakpoint, and drought and shade mortality |

The compensation and race axes carry J's large elasticities. The buffer traits
are small or change sign across records (storage_relaxation_offset, a_dG1), but
they decide whether an itinerary change is a corner or a cliff.

**The invader sees all three more sharply than the resident** (|invader/resident
− 1| has median 1.4). Its J′ near θ′ = θ sits on a compensation boundary in its
own trait: on constant, (ln J′)″ ≈ −2.5e4, a radius of 0.0075 in ln lma.

## The formalism

1. **Population:** a physiologically structured population model with
   environmental feedback, in the renewal (delay-equation) form of Diekmann and
   colleagues:
   - J = ∫ n(b)·f(b; E) db, a count times a fate integrated over birth date;
   - the environment E(t) (the light profile and the soil) is a functional of
     everyone alive at t.

   The birth-date coordinate is the method of characteristics, the Lagrangian
   form of the escalator boxcar train.
2. **Individual:** a hybrid, piecewise-smooth system with one switching function,
   P. TF24 smooths it at ε = 1e-4 kg/yr, far below the step's resolution, so in
   practice it is sharp.
3. **The birth-date map:** b ↦ f(b) is piecewise smooth. Its breakpoints are
   births on the switching surface (window edges) and grazings (fronts). These
   are the discontinuity-induced bifurcations of the theory of piecewise-smooth
   systems (di Bernardo et al. 2008), read along the birth-date axis rather than
   a parameter axis.
4. **Numerics:**
   - Exact counts integrate n.
   - Nodes at the breakpoints make each piece smooth.
   - The hat rule is second order on every piece.
   - The adjoint weights each interval by what it costs J.
5. **Traits:** θ moves the switching surface. Breakpoints then move smoothly with
   θ, and J and its gradient stay smooth, until a new tangency appears. That is
   a bifurcation in birth date, and it shows as a cliff in an elasticity.

## What it predicts, and the tests

- **Gate edges are known at the moment of birth.** P₀(t) of the boundary
  newborn is evaluated at every step. A run can place a node where P₀ crosses
  zero, as it happens.
- **Fronts are where a node's sign-change count differs from its neighbour's**
  and fate jumps with it. They are found after a pass and bracketed by
  bisection.
- **Openings follow rain; closings follow uptake and shade.** A probe of the
  soil needs the stand's uptake to place closings.
- **Breakpoint positions shift with the compensation and race traits; their
  strength with the buffer traits.** Measured on constant rain (forward runs,
  nodes every 1/16 day; registered in `schedtest/traits/prereg.md`):

  | setting | front (birth day) | end-mortality rise over the next 0.25 day |
  |---|---|---|
  | base | 23.56 | 84 |
  | lma ×0.8 / ×1.25 | 27.13 / 18.88 | 111 / 5.2 |
  | hmat ×0.8 / ×1.25 | 45.0–50.4 / 9.9–11.8 | (0.42 → 71) / (0.69 → 86) across the bracket |
  | a_dG1 ×0.5 / ×2 | 23.29 / 24.00 | 42 / 153 |
  | a_st1 ×0.5 / ×2 | 23.38 / 24.25 | 105 / 40 |

  - lma and hmat move the front by 4–24 days. The buffer traits move it by
    0.2–0.7 days and set its sharpness.
  - lma also weakens it (5.2 at ×1.25), so compensation acts on strength as well.
  - In every setting the front sits where the sign-change count goes 0 → 2.
- **Elasticity cliffs appear where θ creates or removes a tangency.** The
  invader's cliff at θ′ = θ on constant is one.
