# Why root_P50's certificate misreads: cancelling parts and wide late intervals

On the hybrid schedules of `central.md`, the central coarsening reads almost every
quantity's error within ×2. root_P50's resident elasticity is the exception:
- episodic: error +0.37ε, estimate −0.10ε;
- dry: error +0.54ε, estimate −0.37ε.

This note finds why. Its ε is 0.0108. Everything below is on dry, using central
differences (±2%) of ln J on forward runs. The scripts and the pre-registered rounds
are in `root-p50/` (`prereg.md`).

## Hypotheses tested

| round | hypothesis | test | result |
|---|---|---|---|
| 1 | H3: tolerance | H at a tenth of the tolerance | moved 0.034ε: rejected |
| 1 | H1: closings (effect side) | split the moves by the birth of the cohorts whose fate changed | births within 10 days of a closing carry +0.23ε then +0.02ε: rejected as stated |
| 1 | H2: reference | spread of the finest schedules' values | ±0.2ε: true in part, too small to explain +0.54ε |
| 2 | H4: late spacing | coarsen or bisect only late births (after the founders' window), or only founders | late births carry all of it (+1.04ε then −0.32ε, ratio −3.3); founders follow the square law (ratio 4.2); the parts add up |
| 3 | is the bisected late spacing asymptotic? | halve the late intervals again | moves −0.32ε then −0.15ε: first order |
| 4 | H1′: misplaced closings | move each closing node to the nearest closing of H's own run (median shift 0.16 day) | ladder unchanged (+1.06, −0.29, −0.18ε): rejected (its rule left the nodes on the shut side; round 6 tests that) |
| 5 | H5: moving corner | bisect only the late intervals that touch an edge, or only those that do not | ratio 1.93 beside edges; explained by round 12 |
| 6 | H6: edge nodes on the shut side of the run's own root | move every edge node inside its open window | ladder unchanged: rejected |
| 7 | H7: a layer of days beside the edge | graded nodes before closings, or after openings | closings carry it, openings none |
| 8 | H8: the layer is wider than 8 days | extend the nodes before closings to 32 days, or refine within 8 | wider moves it, finer does not |
| 9 | H9: through the soil, from births before closings | field-adjoint map at ±2% on Hoea | soil carries it; not concentrated before closings |
| 10 | H10: a kink in birth date | local ladder in two wide intervals, to 8.4-day nodes | square law, no kink: rejected |
| 11 | H11: the season of birth | late-uniform ladders on dry and on dry without its season | the seasonless record converges no better: rejected |
| 12 | H12: parts that cancel, each on the square law | field-adjoint map per late interval, two levels | holds |

## Root cause

**root_P50's error is a sum of interval parts of both signs, and the total is a quarter
of their magnitude** (round 12, `score12.R`). The field-adjoint map at ±2% on H's
all-late bisections gives each late interval of H its own move at two levels:

| | first bisection | second bisection |
|---|---|---|
| map total | −0.348ε (measured −0.32ε) | −0.154ε (measured −0.15ε) |
| sum of magnitudes | 1.479ε | 0.360ε |
| positive parts | +0.566ε | +0.070ε (ratio 8.1) |
| negative parts | −0.913ε | −0.224ε (ratio 4.1) |

- **Each interval follows the square law.** Over the 17 intervals with a move above
  0.02ε, the second move is a median 0.231 of the first (quartiles 0.20–0.26; the
  square law gives 0.25).
- **The total does not.** It is the small difference of larger parts that reach the
  square law at different spacings, so its successive moves keep a ratio near 2.
- **Wide intervals are the ones not yet on the square law.** By the width of H's
  interval:

  | width | intervals moving over 0.005ε | off the square law | share of Σ\|m1\| |
  |---|---|---|---|
  | 45–80 d | 10 | 0 | 0.43ε |
  | 80–110 d | 7 | 1 | 0.20ε |
  | over 110 d | 15 | 4 | 0.81ε |

  The over-110-day intervals carry over half the magnitude, and some change sign
  between levels (for example 12.22: +0.084ε, then −0.011ε).
- **J's parts are not like this.** J converges by the square law on the same grids
  (ratios 4–9), so a J-driven refinement leaves the wide late intervals alone.

**What carries it.**
- The soil: the map puts +0.585ε of a +0.484ε move through soil, against −0.055ε
  through light and −0.046ε in the births' own fate (round 9).
- It acts on the founders' fate, 10–20 years after the births it comes from (`parts.R`,
  `score9.R`).
- The root_P50 derivative of late births' fate varies over months of birth date: ±0.1
  within 0.74 years at b = 12, with an annual period on seasonal dry. The record's
  season is not necessary for it: on dry without its season (round 11) the late ladder
  converges no better.

**How the earlier rounds read it.**
- Rounds 5–8 refined subsets: intervals touching an edge, or nodes before closings.
- Each subset holds parts of one mix of signs. Refining it moves the total by however
  much that mix fails to cancel, so the ratios (1.93, 1.85) and the collar results
  reflect which intervals were chosen, not a first-order term.
- Round 6 changed edge nodes only, and changed nothing.
- Round 10 refined one interval and found the square law.

## What follows

- **The late spacing must resolve the derivatives, not only J.** On dry, late
  intervals of 45–80 days are on the square law for root_P50; over 110 days, a quarter
  are not. A late-interval cap of about 70 days is a start-rule knob. The uniform late
  ladder at 0.185 years (68 d) met the square law (ratio 4.21, round 11).
- **Certificates per quantity, not per total.** A quantity whose parts cancel has an
  estimated total that is a difference of large numbers. The map supplies each
  interval's part, so the loop can:
  - refine by the magnitudes, as it already does for J;
  - flag a quantity whose |Σe| is well under Σ|e|.
- **Edges need no special nodes for this.** Edge placement, in-run nodes and collars
  have no part in it. Edges stay nodes for J's sake (`breakpoints.md`), placed from the
  previous run's record.

## Files

`root-p50/`: pre-registrations (`prereg.md`, rounds 1–12) and scripts:
- `ladders.R`, `partial.R`, `where.R`, `realign.R`, `mkea.R`: rounds 1–5;
- `side.R`, `travel.R`, `mkopen.R`, `score6.R`: round 6;
- `mkcollar.R`, `mkcollar2.R`, `score7.R`, `profile.R`: rounds 7 and 8;
- `parts.R`, `soilmove.R`, `spike.R`, `score9.R`: round 9;
- `score10.R`, `period.R`: round 10;
- `laneUL.sh`, `score11.R`: round 11;
- `score12.R`: round 12.
