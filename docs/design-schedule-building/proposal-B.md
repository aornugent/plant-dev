# Proposal B: build the schedule once at θ₀; every run reads it, its error included

## Triage: 3

The design touches public R API (`run_scm`, `control_window`, `diagnose_scm`) and the core numerics of the birth-date coordinate. Several requirements arrived as mechanisms ("pilot", "companion").

## Requirements ledger

R0–R10 as written in `design-schedule-building.md`. The quantities this proposal uses:

- **R1.** Errors against the finest extrapolation (`node-axis/ladder_*.log`). Spread u215 alone errs by at most 0.707ε on long drought and 0.882ε on long-wet. The (108, 215) extrapolation errs by at most 0.152ε and 0.090ε.
- **R4.** On long drought the ratio over (54, 108, 215) is 4.98, with 6 of 96 negative; over (108, 215, 429) it is 3.92. On long-wet the same two triples give 5.78 and 3.78. Episodic's J ratio is 0.76 over (108, 215, 429) and 4.75 over (215, 429, 857).
- **R6.** An analysis is 60–84 forward-equivalents. Of those, 4–6 per resident are secant forwards that need only J smooth in b.
- **R7.** Rows per forward on the ledger's bounded setting:

  | rungs | long drought | long-wet | episodic |
  |---|---|---|---|
  | u54 | 0.312M | 0.391M | – |
  | u108 | 0.637M | 0.795M | 0.416M |
  | u215 | 1.311M | 1.619M | ≈0.857M |
  | u429 | 2.714M | 3.327M | ≈1.77M |
  | u857 | – | – | ≈3.64M |

  Episodic's coarser rungs are scaled by long drought's ×2.06 per halving. The soil stepped alone scales every row alike.
- **Drift in θ** (measurements, `perf-across-theta.md` §3.2). On a schedule frozen at θ₀, uniform-215 J error is +1.37e-2 at θ₀. Within the resident's ±10% box it is 1.33–1.78e-2, so a correction recorded at θ₀ removes 77–97% of the error there. At a regime change (`stem_P50` ×1.25, 1.85e-3) it would overshoot about 6×. This covers J only, on lumped crowns. Elasticities are unmeasured.

**Scarce resource (derived).** The scarce resource is rows in the 54–80 ε-bearing runs that replay one schedule. Anything a run decides or measures for itself is paid up to 80 times, and under R3 it breaks continuity in θ. Anything decided per schedule is paid once. On long drought each run's companion costs 0.637M of the 1.948M rows in an extrapolated forward (33%), while the whole build costs 6.6M once.

**Challenged upward:**
1. **R4.** "A second, looser run estimates a run's error" asks for a companion per run. I believe the outcome you want is each run's error bounded. If so, a companion recorded at θ₀, plus the run's distance from θ₀ (which R8 already asks for), suffices inside the grid's box. Confirm?
2. **R0, "together".** Node error is 100× time error (R1), and the window's saving (21–23%) is independent of N. I believe "both chosen by rule, in one call" is the outcome, not a joint optimisation. Confirm?
3. **R8's radius is unmeasured.** This design needs it as the reach of the recorded correction (see Kill condition).

## The floor

The floor is today's pieces in one wrapper, with the node rule as decided (item 6): pilot → `control_window` → every ε-bearing run at rungs N/2 and N, extrapolated, with N fixed by a ladder at θ₀.

- It meets R1 (0.09–0.17ε), R2 (as measured on the extrapolated pair), R3, R4, R5, R6 and R8.
- Without a front rule it fails R0 and R1 on constant: no uniform count converges there (u108 gives J = 1.204 against 289.274). Every design needs that rule, so it is shared below.
- It fails R7 only against a design that drops the per-run companion: 0.637M of 1.948M rows per forward on long drought.

## Candidate

**Move 2: move a decision offline.**

| | |
|---|---|
| Commitment | A run decides nothing about its resolution and measures nothing about its error. Introductions, the tolerance over time, the invaders' introductions and the per-quantity correction are computed once per schedule at θ₀ and read by every run. |
| Pays for | **R7:** drops each run's N/2 companion, saving 20–26% of an analysis's rows (§4). **R8:** every run reports an error estimate and its distance at zero rows. **R0:** N, the window and the constant record's front are chosen by rule. |
| Costs | Two public functions (`schedule_scm`, `report_scm`) replace two (`control_window`, `diagnose_scm`). One C++ view type, `BirthInterval`. The correction is stale away from θ₀, and its sensitivity in θ is gone. |
| Wins when | An analysis replays one schedule ≥ 10 times inside a box where the correction drifts by under about 30%. The ±10% resident analysis of `OBJECTIVES.md` is such a case. |

**Winner: the candidate, if the drift measurement holds.** Otherwise the floor wins. At matched error the floor pays 20–26% more rows (R7).

## The commitment

Every number that sets a run's resolution or states its error is a field of the `schedule`, a value built once at θ₀. Runs only read it.

**Kept true by:**
- `run_scm(..., schedule = s)` takes introductions and tolerance factors only from `s`.
- The birth-date SCM keeps refusing `refine_schedule()`.
- `report_scm()` runs nothing. Its `error` column can come only from `s$error`.

## Kill question

**The assumption whose falsity makes this unnecessary:** a correction recorded at θ₀ stays close to the error at every θ in the analysis's box.

**From the ledger:**
- R3 makes Q_N(θ) and Q_{N/2}(θ) smooth on one frozen grid. So the correction (Q_N − Q_{N/2})/3 is smooth in θ, which means drift is O(Δθ) and has no jumps.
- R4's companion reports 0.95–0.98 of the error, so at θ₀ the corrected run matches the extrapolation.
- R6 bounds the box at ±10% for the resident.
- Smoothness bounds the drift's shape, not its size. The only measurement of size (J, lumped) is 3–30%.

**Verdict: survives for the resident.** For invaders over ×0.5–×2 it is untested. That untested case is the kill condition.

## What survives deletion

| Name | Held by |
|---|---|
| `schedule` (the value) | R6: one per analysis |
| `schedule_scm()` | R0: N, the window and the front chosen by rule |
| `report_scm()` | R8: each run's estimate, distance and failures |
| The u54 rung of the ladder | R4: the ratio certifies the (N/2, N) pair |
| The front bisection | R1 on constant |
| `BirthInterval` | R10, and three call sites that each rebuild (node, next, width, shares) |
| `top_powers`, `height_coefficients` | R10 renames |

**Deleted:**
- the "pilot" noun;
- public `control_window` and `diagnose_scm`;
- per-run companions;
- a per-run substep decision. The soil threshold stays a constant of `control_tf24` (share 0.1). The user deferred its tuning, and nothing measured makes it vary by record.

## What this settles

- No run chooses introductions, so J(θ) stays smooth on one schedule (R3). A schedule rebuilt at θ was worse than the frozen one (`perf-across-theta.md`: −2.2e-3 against +5.9e-5).
- No run pays for its own error estimate.
- No AD pass ever meets a decision: the build runs in double.
- No birth-date refinement path inside `SCM`.

## What this makes hard

- **Regime changes inside the box.** A correction recorded at θ₀ can overshoot about 6× (the `stem_P50` ×1.25 case). Cope: `report_scm` returns the distance, and the analysis rebuilds when it leaves the box.
- **Derivatives formed by differencing.** A constant correction cancels in regnans' differences of ln J′ and in chords for curvatures. Gradients must come from the sweep, whose elasticities carry their own recorded correction. Curvatures stay raw at N; their ε is 1.2–4.0.
- **A run's own error away from θ₀** is not measured, only bounded by distance. Cope: `schedule_scm` at the new θ, which is the floor's companion, paid once.

## Kill condition

The kill condition is a correction drift over 30% for elasticities across the resident's ±10% or the invader's ×0.5–×2. At 30%, the residual is 0.15 + 0.30 × 0.707 = 0.36ε on long drought and 0.09 + 0.30 × 0.882 = 0.35ε on long-wet, already at ε/3. The same applies if R4 is held as "each run's own companion".

Either case hands that role back to the floor: two rungs per run.

The first measurement is u108 and u215 with gradients at lma and hmat ×0.95, ×1.1, and invaders at ×0.5 and ×2 on long drought. That is four resident gradient runs and four invader walks with sweeps, each at both rungs: 4 × 7 × 1.948 + 4 × 3.4 × 1.948 ≈ 81M rows.

## The design

### 1. The interval

`BirthInterval<T>` is a non-owning view of the cohorts born between two adjacent introductions: `{const Node& lower; const Node& upper;}`. Species hands it out for each closed interval and for the open one (`upper` = the boundary node).

- `width()`: `upper.introduction_time() − lower.introduction_time()`.
- `establishment_shares()`: today's `Node::interval_shares`, the pair {E − M/Δ, M/Δ} to its two ends. These were the "exact counts". Their sum over a node's two intervals is still the node's establishment weight.
- `for_each_crown(visit)`: today's `for_each_interval_crown`, the "crown spread". It visits `crowns_per_interval` = 8 midpoint crowns `(top, leaf_area)`.

E and M stay ODE states on the lower node (`interval_establishment`, `interval_establishment_moment`), because the state vector is indexed by node.

The crown record becomes `{top, leaf_area, top_powers}`: `mom` → `top_powers`, `crown_moments` → `top_powers`, `height_weights` → `height_coefficients`. On the height coordinate the rename is bit-identical. Nothing else there moves (R9).

### 2. Control flow

```
L4 analysis (regnans)
│   s <- schedule_scm(p0, env, invaders)        once; again on leaving the box
│   loop 54–80 runs + secants:                   reads s; writes nothing to s
│       scm <- run_scm(p_θ, env, schedule = s); r <- report_scm(scm, s, invaders)
│
├─ L3 schedule_scm (double only, at θ0)
│   1. pass: 54 nodes @1e-3, soil alone, lma ×0.5, ×2 walked
│        reads  R(t), R′(t); each interval's J share at its two ends
│        loop:  bisect intervals whose ends' share of J differs by > 1/8,
│               to 1/16 day; re-run the pass               [fires on constant]
│        writes window factors (rule A), the front, the invaders' introductions
│   2. secant to b*(θ0) at rung N (from 215), forward only; these are the analysis's own runs
│   3. ladder loop: gradient runs (stand + invader at θ′=θ) at N, N/2, N/4
│        reads  per-quantity Q at three rungs
│        if >10% of ratios fall outside [3, 5.3]: N ← 2N, repeat (cap 857, then a failure row)
│        writes error = (Q_N − Q_{N/2})/3, ratio, θ0, b*
│
└─ L2 run_scm on s: introductions from s; insert node, integrate to the next
   └─ L1 step (odelia): adaptive steps under s's factors; 15-day cap; soil share 0.1; splits
      └─ L0 rates: BirthInterval.establishment_shares → weighted sums;
                   BirthInterval.for_each_crown → light field by top_powers prefix sums
```

The resident's steps stay online at L1. They depend on θ: a pinned θ₀ program left the domain at 1–317 steps (`perf-across-theta.md`). Invaders walk the resident's recording, as today.

### 3. R API

```r
schedule_scm(p, env = NULL, ctrl = control_tf24(), invaders = list(), events = NULL)
#  -> list(introductions, control, invader_introductions,
#          error = data.frame(run, quantity, parameter, value, every_other,
#                             every_fourth, error, ratio),
#          theta, birth_rate, failures)
run_scm(p, env = NULL, ctrl = control(), ..., schedule = NULL)   # existing, one argument added
report_scm(scm, schedule, invaders = list(), gradient = TRUE)
#  -> list(quantities = data.frame(run, quantity, parameter, value,
#                                  error, corrected = value + error),
#          distance, failures)
```

### 4. Rows per analysis

The analysis has 84 forward-equivalents. Of these, 54–72 are ε-bearing; the rest are secant forwards. Rows are on the bounded setting.

**Long drought (N = 215; (54, 108, 215) passes at 4.98):**
- Floor: 84 × 1.311 + (54…72) × 0.637 + the u54 ratio rung 7 × 0.312 + pilot 0.2 = **146.9–158.4M**.
- This proposal: 84 × 1.311 + build rungs 7 × (0.312 + 0.637) + pass 0.2 = **116.9M**, which is **20–26% less**.
- Today as coded (N = 215 by hand, `diagnose_scm` once): also 116.9M. Its runs are uncorrected, though: up to 0.707ε at θ₀ against this proposal's 0.152ε.

**Episodic (the build escalates to N = 857):**
- Floor at (429, 857): 84 × 3.64 + (54…72) × 1.77 + 7 × 0.857 + 0.13 = **407.5–439.3M**.
- This proposal: 84 × 3.64 + 7 × (0.416 + 0.857 + 1.77) + 0.13 = **327.2M**, which is **20–25% less**.
- Today as coded, a hand-chosen N = 215 gives 76M of runs that are not on the square law (ratio 0.77, companion 0.19). Its error is unknown until `diagnose_scm` runs, and fixing it costs the analysis again.

**Other records:**
- **Long-wet:** the build adds u429 (ratio 5.78, then 3.78), costing 23M once against 43–57M saved. N = 215.
- **Dry:** the ladder holds over (108, 215, 429). N = 215.
- **Constant:**
  - The front loop runs about 11 bisection passes of about 43k rows each (0.47M). Its 1/8 threshold is unmeasured: it must not fire on the pulsed records, which the acceptance suite checks.
  - The window is skipped (the user's decision).
  - The bulk's convergence is unmeasured (ratio 1.65 on the causal grid). The ladder halves it, and past 857 the schedule records a failure.
  - The invader's cliff (J′ from 938 to 0.0017 over ±1% in lma) is outside any box. Its distance flags it.

### 5. Today's pieces

| Piece | Becomes |
|---|---|
| The pilot | Pass 1 of `schedule_scm`; no public noun |
| `control_window()` | Merged: an internal step of pass 1 |
| `diagnose_scm()` | Merged: its ladder becomes step 3; its table becomes `s$error`; its distance and failures move to `report_scm` |
| `SCM::refine_schedule()` | Kept unchanged for the height coordinate (R9) |
| Invaders' shared thinned schedule | Recorded as `s$invader_introductions`; full walk stays the default (the user's decision) |
| `control_tf24()` | Kept; holds the cap, bound, soil weight and substep share |
| `interval_shares`, `for_each_interval_crown` | Renamed: `BirthInterval::establishment_shares`, `BirthInterval::for_each_crown` |
| `mom`, `crown_moments`, `height_weights` | Renamed: `top_powers`, `top_powers`, `height_coefficients` |
