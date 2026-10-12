# Why the map's estimate reads low during refinement

Round 3 of map-driven refinement (`refinement.md`) ran:
- six records and trait settings;
- three start rules:
  - 16 even nodes over the founders' window (`s16`);
  - the default's nodes there (`dft`);
  - 108 even nodes plus edges (`u108e`);
- an elasticity guard on top.

Every lane reached ε. On every lane and start, though, the ln J estimate Σe/3 read 1/2 to 1/3 of the error, and each pass removed only about 40% of it. This note finds where the shortfall comes from. Errors are in ε of ln J against the references of `refinement.md`. Scripts and the pre-registrations are in `estimate-shortfall/`.

## Round 3 in brief

| case | passes to ε | final rows | rows over all passes | final ln J error / estimate |
|---|---|---|---|---|
| episodic, s16 | 3 | 584k | 1.79M | −0.35 / −0.14 |
| episodic, u108e | 1 | 466k | 0.85M | −0.43 / −0.17 |
| dry, s16 | 4 | 1344k | 4.86M | −0.21 / −0.08 |
| long-wet, s16 | 1 | 930k | 1.79M | −0.34 / −0.06 |
| long drought, s16 | 3 | 1900k | 6.62M | −0.32 / −0.08 |
| episodic lma ×1.25, s16 | 2 | 434k | 1.07M | −0.50 / −0.16 |
| constant, s16 | 6+ | 179k | 1.11M | −0.01 / −0.01 (a_l1 still 1.2ε) |

- **The start rules compare as follows.**
  - The 54-node start's error sits in births of years 0–2, which earn 75–90% of J on three of its nodes. Fate there falls nearly exponentially in birth date (`fine.R`, `scan.R`).
  - The default's geometric grading toward b = 0 did no better than 16 even nodes over that window, at more rows.
  - u108e reached ε soonest.
- **The guard was too strict.** The elasticity guard (stop only when every resident elasticity moved under ε/4) kept every lane going past ε.
- **On constant rain the race traits' elasticities need resolution just after the front.**
  - a_l1's move between nested grids sits at births 24–26 days, past the front (`where_el.R`).
  - The ln J map does not rank those births.
- **Prediction 3 of `prereg.md` (estimate within a factor 2) failed, and so did prediction 4 (passes summed below uniform L2).**

## Where the shortfall is

**The map is exact, and bisection is honest** (`ab.R`). C is the grid with every other node dropped; B is the bisection.

| grid | error | 4/3 (P − B) | C − P measured | C − P from the map | (C − P)/(P − B) |
|---|---|---|---|---|---|
| episodic u108e, pass 1 | −0.433 | −0.428 | −0.506 | −0.503 | 1.57 |
| episodic u108e, pass 3 | −0.169 | −0.171 | −0.168 | −0.169 | 1.31 |
| dry s16, pass 3 | −0.370 | −0.389 | −0.395 | −0.394 | 1.35 |

- The refined grids follow the square law from P downward: 4/3 of the bisection move is the error to 1–5%.
- The coarse grid at 2h is what falls outside the asymptotic range. The square law asks for (C − P)/(P − B) = 4.

**Own and field parts scale differently** (`parts.R`, `cause.R`).
- The own part's coarsening-to-bisection ratio is 3.0–3.8; the field part's is 1.7–2.5, mostly through soil.
- The two have opposite signs, so coarsening cancels more than bisection does.
- By cause, the non-square-law part comes from births after year 3.7: soil ratios are 1.5–1.9 there, against about 6 for founders' panels.

**It sits in wide late panels** (`width.R`).

| panel span (episodic, pass 3) | soil part, e_P / 4 (P − B) |
|---|---|
| under 80 days | 0.8–1.2 |
| 80–160 days | 0.33 |
| 160–400 days | 0.085 |

Dry shows the same pattern. Eight panels, most at the base spacing of 135 days, hold 83% of the shortfall (`missed.R`).
- Dropping their middle node moves J by about 0.
- Bisecting them moves J by 4 × (−0.03).
- Refining them fully moves J as bisection predicts (+0.058 against +0.060, `missmove.R`).

## What the error in a missed panel looks like

In the most-missed panel, births 7.985–8.519, the error depends on where its one interior node sits (`mkehc.R`, position scan). E is measured against 3-day spacing:

| interior node | E |
|---|---|
| none | −0.021 |
| at 8.10 | −0.042 |
| at 8.25 (midpoint) | +0.0002 |
| at 8.37 | +0.008 |
| at 8.148 (pass 3's) | −0.023 |

- E is smooth in the node's position and changes sign.
- A smooth integrand would err with one sign and least at the midpoint, so this is not ordinary quadrature error.
- With even spacing the error falls to 0.002 at 49 days and 0.0004 at 24 days.

## Hypotheses tested and rejected

| hypothesis | test | result |
|---|---|---|
| Closings move with the grid, leaving corners inside panels | edges of a forward run on pass 3's grid (`edgemove.R`) | Closings do move (median 0.48 d; the founders' closing by 12 d) and openings do not. Protecting edges in the coarsening raises the ratio from 1.31 to 2.08 only. |
| A first-mover layer or spike in fate within late windows | fate at 1–2-day spacing in the two most-missed panels and two other late windows | Fate is smooth, nearly linear. |
| Convex seedling uptake across the open interval | soil, scan minus pass 3, by week (`sawtooth.R`) | No growth with the open interval's age. The difference appears at rain pulses, with the opposite sign. |
| A fate corner at each rain onset that breaks a dry spell | a corner exists at 8.091 (slope −0.046 to −0.071 per 2 d); 44 such onsets added as nodes (`mkonset.R`) | The error moved by 0.001. |
| Time stepping near pulses, set by where introductions put the stops | the same grids at a tenth of the tolerance | E unchanged to 1e-4. |
| Season of birth (record amplitude 0.8) | filling late windows to 23 days (`mkseason.R`); the same episodic rain at amplitude 0 (`flatcmp.R`) | Filling cut the error five-fold (−0.169 to −0.035) and raised the ratio to 2.68. The non-seasonal record shows the same ratio as the seasonal one (2.73 against 2.85), so season is not the cause. |

## Root cause: the coarsening's geometry

**The rule err(P) = (C − P)/3 holds only when every dropped node sits at the midpoint
of the panel it merges.**
- Each interval's error goes as h³. So for a dropped node at fraction l of its panel,
  err(P) = (C − P) × (l³ + (1 − l)³) / (3l(1 − l)).
- At l = 1/2 the factor is 1/3, as the plain estimate assumes. As l → 0 it grows
  like 1/(3l): the coarsening move reads about 3l times the panel's error.

Dropping every other node on an edge-aligned grid makes lopsided panels wherever two
nodes nearly coincide. Typically that is an edge landing beside a base node, or the
start rule's founders' nodes landing beside the 54-node base. Bisection halves every
interval and a uniform grid has l = 1/2, which is why both read honestly.

**Panel by panel** (`geompanel.R`). Truth is 4/3 of each panel's share of the
bisection move, which is honest here.

| panels, by the dropped node's position | episodic u108e, pass 3: truth / plain | dry s16, pass 3: truth / plain |
|---|---|---|
| central, l > 0.35 | −0.067 / −0.051 | −0.142 / −0.107 |
| l from 0.2 to 0.35 | −0.030 / −0.002 | −0.070 / −0.023 |
| lopsided, l < 0.2 | −0.073 / −0.003 | −0.179 / −0.001 |

- Lopsided panels carry most of the shortfall: 0.07ε of 0.115ε on episodic and
  0.18ε of 0.26ε on dry. Their coarsening reads about zero, as the geometry predicts.
- Correcting each panel by its factor does not rescue them. Their tiny move is set by
  other effects, and the 1/(3l) factor amplifies the noise, with the wrong sign on dry.
- Central panels read 54–82% of their error in the spans that matter.

**This explains the earlier observations:**
- the missed panels were lopsided (135 days + 1 day; 59 + 135 days);
- the ratio fell when onsets were added as nodes (1.31 to 1.52, more near-coincident
  pairs) and rose when late windows were filled evenly (2.68);
- the seasonal and flat records agree (same geometry);
- a single node's effect depended on its position.

**The confirmed estimator.**
- Run the map on the bisection B, with every midpoint dropped, so each dropped node
  is central.
- It predicts P − B exactly (−0.128ε on episodic u108e, pass 3), and 4/3 of that is
  P's error: −0.171ε against −0.169ε, and −0.389ε against −0.370ε on dry s16, pass 3.
- B's own error is a third of the move.

## What is established

1. The drop map is exact, and the bisection move is an honest estimate on these grids.
2. The coarsening reads low mainly because of its geometry. Lopsided panels, where
   two nodes nearly coincide, report about 3l of their error.
3. The wide late panels in the earlier width table are mostly lopsided ones. Central
   panels of 80–160 days read 54–82% of their error.
4. So Σe/3 under-reports, and the loop never refines the panels it under-rates, which
   is why each pass gains only about 40%.
5. What the earlier position scan showed is the same geometry: in a two-interval
   panel, the node's place decides how much of the error the coarsening sees.

**Further mechanisms tested and rejected:**
- the rooting-depth cap at 1.5 m, by removing it (`traj.R`, `defects.R`);
- a sorting front in growth, from height increments (`growth.R`);
- a single growth curve in age (`agecurve.R`).

The cohort states are smooth in birth date. The fine-banded map (`bands.R`) puts the
panel's field effect at 1–12 years after birth.

**What follows for the algorithm:**
- An estimate is honest when every dropped node is central and the grid it coarsens to is resolved.
- Running the map on the bisection B, whose coarsening is P, gives 4/3 (P − B) as P's error and (P − B)/3 as B's.
- That costs one run at about twice P's rows, the same as a nested pair, but the run also ranks B's panels.
