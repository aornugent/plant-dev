# Schedule error: what causes it, what a run knows, and a cheaper companion

Built from `error-modes.md` (the record), `in-run-signals.md` (what one run knows) and
`error-structure.md` (692 saved runs).

## What the error is

**Layout errors are designed out.** 29 modes are catalogued. Every mode that comes from
where nodes are placed, or from how the pair reads them, was removed by a rule:
- edge nodes, by the inset;
- the strips both runs share, by scaling the check's inset;
- overshoot in spacing, wide intervals, merged gaps and partial checks, each by a rule.

None of these needed a run's own signal.

**What remains is order 2, everywhere it lives** (measured on every doubling ladder,
every quantity and every case: pooled p 1.8–2.3).
- It concentrates in two classes:
  - the founders, 32% (lib19) and 6% (libAG) on a09's dry committed run; up to 80–108% of
    the squared error on four training cases on the G0 layout;
  - the intervals before a closing edge, 57% and 67%.
- Three directions carry 90% of it. The spells' direction is shared across cases; the
  founders' direction is case-specific.
- **The error's size is the case's.** The constant in front of h² varies across cases
  (about 100× in the raw proxy). Normalised by the pilot's J, an a-priori model still
  misreads by a median ×1.37, and as a stopping rule it needs a ×1.86 margin. That margin
  accepts only 22% of runs that are within ε.

**Random modes** are left outside the layout.
- Step jitter at the leaf's switch: the floor is about 0.03ε at 1e-4.
- Error that moves with θ: a check at θ₀ cannot cover it.

## What a single run knows

| Signal | What it estimates | Verdict |
|---|---|---|
| Each node's own part (plant's old omit-one) | — | Blind to the field part (the light and water a coarser node set changes for every other cohort). The two parts are of similar size and usually opposite sign: always positive while the true error changes sign on 4 of 10 cases; correlation 0.64–0.69 against the pair's 0.98 |
| The drop map | ln J only | ln J never binds |
| Per-node adjoints | ranks nodes | gives no error estimate |

No in-run signal estimates the elasticities' error. Those need a second gradient run on
a different spacing.

## So the guarantee is the algorithm's, and the companion only measures one constant

The order (2), the location (founders and closing edges) and the direction are the
algorithm's, and they are known before the run. What a second run must supply is one
number per quantity: the case's constant in front of h². That does not need a *finer*
run. A *coarser* run measures the same constant:

  err(committed) ≈ (Q_coarse − Q_committed) / (r² − 1),  with r = 1.6.

| Companion | Cost (committed runs) | Find, pilot + committed + companion | T = find + 2 uses (committed runs) |
|---|---|---|---|
| Finer check (today) | 1.55 | about 2.6 | 4.6 |
| Coarser companion | about 0.6 (nodes ÷ 1.6, by the rows model; estimated) | about 1.6 | 3.6, about −22% |

The answer reported is still the committed run's.
- If the estimate exceeds ε, a finer run follows: today 1 commit in 10 is fine.
- Jitter is amplified alike: 1/(1 − 1/r²) = 1.64 for the finer check, and 1/(r² − 1) =
  0.64 here, times a move that is r² larger. So the jitter's share of the estimate is the
  same.

**The risk is pre-asymptotic error at the coarser spacing.**
- With edges as nodes at coarse spell spacing, hydraulic quantities showed order ≈ 0.8.
- Agent C's widest-legal check failed 0/5. Wide intervals over about 110 d leave the
  square law (mode A5).
- The inset removes the edge nodes, but whether order 2 holds at 1.6× the committed
  spacing under the inset rule is unmeasured.

## H1 (registered before the runs)

*Hypothesis:* under the inset rule, scaled with the spacing, the error is second order
from the committed spacing to 1.6× coarser. So a coarser companion estimates the
committed run's error as well as the finer check does.

*Test:*
- For each of the ten cases, build the coarse companion: the committed rule at 1.6× the
  committed spacing, each edge node inset 12 × 1.6 = 19.2 d (E6's scaling, applied the
  other way).
- Run it as the bank ran: libS, no knot stops, 1e-4, the val_ins75 setting.
- Score the E6 committed run's error by (Q_coarse − Q_committed)/(r² − 1), with r taken
  from the proxy's shrink, as E6's s is.

*Predicted:*

| Prediction | Probability |
|---|---|
| C1–C5 pass on at least 9 of 10 cases, against E6's 10/10 with the finer check | 55% |
| Median read 0.8–1.25 | 60% |
| The companion's measured cost ≤ 0.7 of the committed run's | 75% |
| T on all ten at least 15% below E6's 9287 (rows model) | 60% |

*Refuted if* reads fall under 0.5 or above 2 on the hydraulic quantities: the
pre-asymptotic mode. The fallback then is a companion at r = 1.3.

## The two locations, root-caused (`founders/notes.md`, `closing/notes.md`)

**Founders.**
- *Mechanism:* each founder's fate falls nearly exponentially with birth date
  (time scale 0.4–0.8 y), because survival runs on the calendar for all of them. Linear
  hats in birth date misread that curve twice: in J's sum, and in the founders' uptake,
  which dries the soil for everyone.
- *Size:* the founders hold 44–94% of the inset committed run's squared error on nine of
  ten cases.
- *Simpson's rule over the founders' window:* 12 intervals reach the run-to-run floor
  (0.052ε rms on dry, 0.027ε on episodic-lma). The committed run's 17–19 trapezium
  intervals give 0.135 and 0.335. Rows fall 6–9%.
- Two cases only, on a patched build that does not reproduce libS exactly.

**Closing edge.**
- *Mechanism:* a seedling born later in a drying spell meets the drought with fuller
  reserves. The closing cohorts' hydraulic sensitivity turns over about 10 d before the
  edge, a position set by the seedling's reserves, not by the spacing. The 12-d inset node
  sits on that turn, so the inset is a tuned cancellation with no power law.
- *Cancellation:* on dry the closing regions' error cancels a larger hydraulic error
  elsewhere in the layout (root_P50 +0.34 against −0.64). Where that error lives (founders,
  opening strips or interior) is not yet attributed.
- *Equal intervals to the edge:* they halve the strip's error and keep its sign, but give
  order about 1, not 2, at +40% rows. Not worth it.
- *The fine side of any ladder sits on the derivative's jitter floor:* 0.024 rms, about
  0.09 along M.

**Consequence for H1.** A coarser companion fails because the closing strip's error has no
power law. It also fails because the layout's small dry error is a balance between regions
that a uniform coarsening moves.

## H5 (next, not yet registered in detail)

*Hypothesis:* the layout's error becomes one clean second-order term (founders by Simpson,
closing edge by a node at the edge and a fixed node at c − 12 d, everything else scaled with
the spacing). Then a coarser companion or the pilot's constant predicts it.
- Run on one build that reproduces libS.
- First attribute the −0.64 root_P50 elsewhere, because removing the founders' error
  could expose the closing-edge error it now cancels.

## C1–C5 for a loop whose last run is the answer

The loop: runs R1, …, Rk at shrinking spacing. The answer is Qk. Its signed estimate is
ek = (Q(k−1) − Qk)/(rk² − 1), from the pair with its predecessor. Rk's schedule is the
one the uses run on. T = Σ cost(Ri) + 2·cost(Rk).

| | Today | In the loop |
|---|---|---|
| C1 | every \|error\| ≤ ε | unchanged, on Rk. The final spacing is tuned to just meet ε at θ₀, which removes the slack the fixed rule had for the local analysis. So C1 is judged over the shared grid's uses at moved θ, or the loop stops at ε·(1 − reserve) with the reserve measured |
| C2 | every error over ε/2 has an estimate over ε/4 | unchanged, but it now also decides when to stop, so it is scored with the loop's decisions made on noisy values (stress draws) |
| C3 | 80% of estimates within ×2, sign right | unchanged, scored the same way. Stopping when a noisy estimate reads low biases the accepted estimates low. Plus a noise check: jitter/(rk² − 1) under ε/3, so a final ratio near 1 cannot make an estimate out of noise |
| C4 | nothing refuses or throws | extended to every iteration, and to termination (a bounded k) |
| C5 | never commit an answer whose own estimate exceeds ε | becomes the stopping rule, so it holds by construction except at the iteration cap. The test moves into C2/C3 |

An optional diagnostic: if the loop is stopped after any iteration i ≥ 2, (Qi, ei) still
passes C2/C3.
