# refine_schedule: refine TF24's schedule from E6 until the run meets a target

Subject: a tool that starts from E6 and refines the node schedule until every quantity's
estimated error is under a target the user sets (ε, ε/2, ε/4 …). Every run nests in the one
before it, so no run is thrown away. Each run both improves the schedule and measures the
error of the region it refined. Built as `harness/schedule/refine.R`
(`refine_schedule`) and evaluated on the ten bank cases and the eight held-out cases. Every
prediction is written here, with a probability, before the run or analysis it concerns.
Scripts are in this directory; outputs in `scratchpad/deep/rootcause/refine/` (`runs/`,
`sched/`, `logs/`, `*.rds`). **[m]** measured, **[i]** inferred.

## Summary (written last)

**The tool** (`harness/schedule/refine.R`, `refine_schedule(case, start = "E6", target)`,
about 140 lines). It starts with E6's pair (S0, S1) and E1 = (Q0 − Q1)/(1.6² − 1). It stops
at S1 when every |E1| is under the target. Otherwise it refines one region per run, nested:
F, I1–I3 and L by bisection, O and C by halving each edge's inset. Regions are ranked by the
S1 map's |ln J| share per added row. The estimate is E1 − Σ measured S1 errors (4/3 of each
region's first move) + Σ remainders (m/3, or the measured ratio once a second move exceeds
half the first). The target is the only knob (no reserve). The backends are E6's saved runs
and map runs on a scratch libS + node-drop build, which reproduces libS `identical()`.
Tolerance is 1e-4 for ε and ε/2, and 3e-5 for ε/4, where the 5% nudge floor falls from
0.024 to 0.004–0.012 rms [m].

**ε (1e-4): E6 itself, 17/17 scored pass** [m]: E1 is under 1 everywhere (0.07–0.56), so
every case stops at S1 after 2 runs. Uniform refinement does the same.

**ε/2 (1e-4)** [m]: 17 of 18 stop at S1. Every S1 is within ε/2, but **6 of 10 scored pass**:
E1 reads S1's error with cos 0.33–0.54 on the dry records (dry, dry-p50, flat-al1125
C2/C3) and −0.17 / 0.15 on near-extinction dry-lma125. episodic-lma refines in 7 runs
(I3, L, L, I2, F). Its final is at 0.41 of ε/2 with 0.93× uniform's rows at matched error,
but its estimate reads ×2.1 (C3 fails). Seven cases are unscored at ε/2 because their
references move 0.17–0.30ε on their own.

**ε/4 (3e-5, six cases with references under ε/12)** [m]: 3/6 pass, all three at S1
(ld104-p50125, epi-hmat08, ld107-adG2125). flat-al1125 stops at S1 on E1 0.85 of ε/4 while
its error is 1.78. episodic-lma takes 8 runs (I3 L L I2 I3 F): it ends at 0.36 of ε/4 with
0.40× uniform's rows at matched error [i, extrapolated], but reads ×2.3. dry-lma125
(near extinction) hits the 10-run cap at 798 nodes. Its true error is under ε/4 from run 5,
but no run's estimate reads it (cos −0.55 to 0.75), and it costs 1.49× uniform's rows at
matched error.

**What limits convergence, in order** [m, mechanism i]:
1. **E6's pair is off the square law at S1's level.** It under-reads flat-al1125 ×0.63 and
   epi-hmat08 ×0.58 and over-reads episodic-lma ×1.32. The next uniform pair (S1 → S2u)
   reads flat-al1125 at 0.98 (cos 0.99), and its cos beats E1's on 4/4. The 12-d committed
   inset sits on the closing edge's turn, so S0's strip error is small for a reason the pair
   cannot see.
2. **The bookkeeping drifts.** With each region refined once, the estimate is exactly
   E1 − (Q1 − Q_k). E1's absolute misread therefore stays in it and grows relative to a
   shrinking error (reads ×2.1–2.3 at the end). The literal share rule (Σ remainders + E1 ×
   unmeasured |ln J| shares) loses E1 as regions get measured. It reads the finals better on
   episodic-lma (1.15 and 1.65, C3 passes) but is no better overall (C3 8 against 7 runs of
   19).
3. **The ln-J-only ranking.** The founders held episodic-lma's elasticity error (lma 0.21–0.23
   of 0.40), but ln J's map ranked them third and their rows are the dearest, so they came
   last. Cheap regions with small ln J (L) were taken first and repeatedly. On dry-lma125
   that raised the error, because the regions cancel.
4. **The near-extinction case.** The late region's moves alternate in sign (cos −0.8 to
   −0.95) and stop shrinking. The non-asymptotic flag fires, but its extra refinement
   cannot fix a region with no order. The case's old reference was also off by 0.24ε
   (the u857 rung shows a sign change between rungs). Against the new one S1's error is
   0.27, not 0.48, but E1 still reads it at cos 0.15.
5. **References and noise.** ε/2 is unscored on seven cases, and ε/4 on twelve. 3e-5
   brings the floor under ε/12 (0.004–0.012 rms), so noise was not the binding limit at ε/4.
   epi-hmat08's S2u error (0.089) sits at its reference's own move (0.077).

**Region honesty** [m]: the interiors keep their direction from one refinement to the next
(cos 0.82–0.98) and land within ×2 of the predicted remainder (4·m2/m1 0.62, 1.94). The late
region never keeps its direction. Founders and strips were never refined twice, so their
second-move honesty is untested here.

**Verdict** [i]: the decomposition removes error where it refines (every run nests, and the
interiors behave). But its estimate is only as honest as E6's pair, and that pair is off the
law exactly where tighter targets need it. A fix would re-anchor on the finest pair the
tool has run, rather than on E1, and rank by a per-quantity indicator rather than ln J.

## Setup

- **Backends.** S0 and S1 are E6's committed and check runs as built (bank: `val_insk_c` /
  `val_ins75_f`; held-out: `e6_c` / `e6_f`, libS, 1e-4). A run the tool asks for goes
  through `dwr/adj_run_dwr.R` in MODE=map, on a scratch build of libS's exact source
  (`summing/build/src0/plant`) plus `dwr/node_drop.patch` (`refine/build/lib`, deleted at
  the end), at the E6 committed setting (no knot stops, ATOL 1e-4, WEIGHT_SOIL 10,
  WEIGHT_MAX 100, HMAX 15, SHARE 0.1, SPLIT 1, the record's weight) and the target's
  tolerance. With the map's coefficients at zero this build reproduces libS's runs
  `identical()` (loop round, G1).
- **References.** Bank: the lib19-class references of earlier rounds (`proxies/lad.rds`).
  Held-out: `heldout/runs` u215 → u429 at 3e-5 (flat-al1125 u429 → u857). A reference
  scores a target only if its own move, max over quantities of (fine − coarse)/3 in ε, is
  under a third of the target. Where it is not, a u857 rung is built with the held-out
  recipe (`adj_run_nk.R` on adjmap/lib, knots as stops, 3e-5) or the case is marked
  unscored for that target.
- **Quantities.** ln J and 46 resident elasticities (rooting_depth_max set aside). Errors
  are in each quantity's ε (`docs/measurements/eps-spread.md`). At target t, everything is
  read in units of t·ε: C1 every |err| ≤ 1; C2 est > 0.25 where |err| > 0.5; C3 sign right
  and within ×2 on quantities with max(|err|, |est|) > 1/3, at most max(1, 20%) misses; C5
  every |est| ≤ 1; C4 nothing throws or refuses.

## The tool as designed (before any run)

**Regions** (by interval, from the pilot's edges before 25 and b1). An interval whose
midpoint is at or after 25 is late (L). Before 25: an interval inside [0, b1) is the
founders' (F). An interval inside a spell and more than 7.5 d (the check's inset) from both
of the spell's edges is an interior, by era of its midpoint: I1 (b1–10), I2 (10–17), I3
(17–25). The strip zones are the 7.5 d inside each opening edge (O) and before each closing
edge, b1's included (C), with the gap interval that reads them. Gap intervals hold no
establishment and are not refined.

**Refining a region.** F, I1–I3 and L: bisect every interval of the region. O and C: halve
each edge's inset, that is add a node halfway between the edge and its nearest node on the
spell side (none when that half is under half a day). Nothing is ever removed or moved, so
each run nests in the one before.

**Bookkeeping.**
1. Global pair: S0 = E6 committed, S1 = E6 check. E1 = (Q0 − Q1)/(1.6² − 1) per quantity
   estimates S1's error. If every |E1| is under the target, S1 is the answer: that is E6.
2. Otherwise refine from S1, one region per run. Rank regions by expected error removed
   per added row: an unmeasured region's error is rms(E1) × its share of the |ln J| profile,
   the shares being the S1 map's |ln J| per region (F, I1, I2, I3, L) with the strips
   taking the pair's ln J remainder after the map's regions, half each to O and C; a
   measured region's error is its measured remainder. Rows added: each new node times the
   current run's accepted steps after its birth.
3. A region's first refinement measures its error at S1's spacing: e_g = m_g·4/3 (m the
   move, order 2 at ratio 2), and leaves m_g/3. A later refinement replaces the
   remainder with m/3 of the newer move. The unmeasured regions together keep
   E1 − Σ_measured e_g: the global pair's remainder once the measured regions are taken out
   (no per-quantity split assumed). The estimate is that plus Σ the measured remainders.
4. A region refined twice whose second move is more than 1/2 of its first (rms over the
   quantities its first move put over three noise sds) is not asymptotic: its remainder
   uses the measured ratio ρ, m·ρ/(1 − ρ) (ρ capped at 0.8), and it gets one more
   refinement before the tool may stop.
5. Stop when every quantity's |estimate| is under the target (no reserve). The answer is
   the last run.

The bookkeeping telescopes [i]: with each region refined once, the estimate is
E1 − (Q1 − Q_k), so the tool is as honest as E6's global pair, and each move is measured,
not modelled. Order assumptions enter only from a region's second refinement on.

**ODE tolerance.** 1e-4 for ε and ε/2 (noise floor 0.024 rms, 0.09 along M; 3× that is
under ε/2·ε). Tighter for ε/4 (3e-5), where 3 × 0.09 = 0.27 exceeds the target; then S0 and
S1 are rerun at 3e-5 too, so that every move is a node move and the runs share the
references' tolerance.

**Uniform alternative.** The E6 check rule applied again: level k is a09's fill at
h/1.6^k over level k − 1's graded build, late edges out, inset 12/1.6^k d (k = 2: 4.69 d,
k = 3: 2.93 d). Estimate (Q_{k−1} − Q_k)/(1.6² − 1), same stopping rule.

## Pre-registration 0 (before the round's survey of saved runs is read further)

Already seen [m, `explore0.R`]: E1's largest |entry| per case is 0.07–0.30 on 17 cases and
0.56 on episodic-lma; S1's true worst error 0.09–0.48. The bank's episodic-lma reference
(m_lma1252 → m_lma1254, an older program) moves 0.95ε on its own (lma), so it cannot score
even ε. So at ε every case stops at S1, and at ε/2 only episodic-lma refines unless its
estimate changes. The interesting regimes are ε/2 on episodic-lma and ε/4.

| # | prediction | P |
|---|---|---|
| Z1 | A new episodic-lma reference (held-out recipe, u429 → u857) differs from the old one by more than 0.5ε on at least one quantity | 70% |
| Z2 | Its own move (u857 − u429)/3 is under ε/6 on every quantity (scores ε/2) | 50% |
| Z3 | dry-lma125's u857 makes its reference's own move under ε/12 (scores ε/4) | 50% |
| Z4 | dry-lma125's u429 → u857 reference agrees with u215 → u429 within 0.15ε everywhere | 60% |

## Change from the coordinator (before any prediction was scored)

The reserve is dropped: the tool stops when every quantity's estimate is under the target,
which is its only knob. No prediction had been registered with a reserve.

## Guard (`guard.R`) [m]

`un_sched(cs, 1)` (the uniform builder at k = 1) is E6's check schedule exactly on all
eighteen cases. On S1 no interval lies in a strip zone (each inset node sits exactly 7.5 d
in), so O and C start as the gap intervals' reading only. One refinement adds, as a share of
S1's rows: F 0.15–0.30, I1 0.20–0.28, I2 0.17–0.23, I3 0.09–0.11, O and C 0.11–0.32 each
(0.30–0.32 on the two dry-flat records, 77–90 edges), L 0.00–0.02.

## Pre-registration 1 (before the driver runs at 1e-4: targets ε and ε/2, all eighteen)

Known before this point: at ε every case stops at S1 (largest |E1| 0.56); at ε/2 only
episodic-lma can refine (|E1| 0.56); S1's true worst error is under 0.5 on every case
whose reference was scored before (0.09–0.48).

| # | prediction | P |
|---|---|---|
| A1 | At ε, S1 with estimate E1 passes C1–C5 on every case whose reference scores ε | 70% |
| A2 | At ε/2, it passes C1–C5 on every case whose reference scores ε/2 | 40% |
| A3 | At ε/2 the near-extinction case dry-lma125 fails C3 | 70% |
| A4 | At ε/2, episodic-lma's first refined region is founders or an interior era, not a strip or late | 70% |
| A5 | episodic-lma's final run passes C1–C5 at ε/2 against its new reference (if that reference scores ε/2) | 55% |
| A6 | episodic-lma at ε/2: the tool's final rows are at most uniform's at matched worst error | 50% |

## Pre-registration 2 (before any 3e-5 run: target ε/4)

ε/4 needs a reference whose own move is under ε/12 = 0.083: flat-al1125 (u857, 0.052),
ld104-p50125 (0.069), ld107-adG2125 (0.076) and epi-hmat08 (0.077) qualify now; dry-lma125
joins if Z3 holds, episodic-lma if its new reference moves under 0.083. These run at 3e-5
throughout (S0 and S1 rerun at 3e-5 in map mode), with a 5% tolerance nudge of S1 (3.15e-5)
on flat-al1125 and ld104-p50125 to measure the noise floor there; its rms sets the tool's
`noise` (the non-asymptotic test's threshold). At 1e-4 that floor is 0.024 rms, 0.09 along M.

| # | prediction | P |
|---|---|---|
| B1 | The 5% nudge at 3e-5 moves S1's quantities by at most 0.012 rms (half the 1e-4 floor) on both cases | 55% |
| B2 | S1 at 3e-5 is within 0.1 rms of S1 at 1e-4 (ε units) on every ε/4 case | 70% |
| B3 | ld104-p50125, epi-hmat08 and ld107-adG2125 all stop at S1 at ε/4 | 65% |
| B4 | flat-al1125 refines at ε/4 (some \|E1\| ≥ 0.25 at 3e-5) | 60% |
| B5 | Every ε/4 case's final run passes C1 at ε/4 | 60% |
| B6 | Every ε/4 case passes C1–C5 at ε/4 | 30% |
| B7 | Where the tool refines, its final rows are at most uniform's at matched worst error | 55% |
| B8 | Region honesty: where a founders' or interior region is refined twice, 4·m2/m1 (rms over the quantities its first move put over three noise sds) lies in [0.5, 2] in at least 2/3 of instances | 55% |
| B9 | The same for strips (O, C) | 35% |
| B10 | dry-lma125 (if scored at ε/4) passes C3 at ε/4 | 35% |

## Results 1: ε and ε/2 at 1e-4, S1 on every case (`drive.R`, `score.R 1e-04`; `score_1e-04.rds`) [m]

The driver reads E6's saved runs: E1's largest entry is under 0.5 on 17 cases (0.07–0.30),
so the tool stops at S1 on all of them for both targets (2 runs, S1's rows). episodic-lma
(|E1| 0.56) refines at ε/2; results below once its runs land. Uniform refinement takes the
same path (k = 1) wherever the tool stops at S1.

| case | ref (own) | W at ε | est max at ε | pass ε | W at ε/2 | pass ε/2 (C misses) | cos(est, err) |
|---|---|---|---|---|---|---|---|
| episodic | bank (0.02) | 0.09 | 0.15 | yes | 0.19 | yes | 0.87 |
| dry | bank (0.11) | 0.26 | 0.19 | yes | 0.52 | **no** (C2; C3 4/4) | 0.33 |
| long-wet | bank (0.17) | 0.16 | 0.13 | yes | 0.31 | unscored (0.169 > 0.167) | 0.88 |
| long-drought | bank (0.16) | 0.18 | 0.12 | yes | 0.36 | yes | 0.85 |
| episodic-lma | bank (0.95) | 0.41 | 0.56 | unscored | – | refines | 0.98 |
| dry-flat | bank (0.24) | 0.31 | 0.19 | yes | 0.61 | unscored | 0.51 |
| ld-102 | bank (0.18) | 0.16 | 0.17 | yes | 0.31 | unscored | 0.93 |
| ld-105 | bank (0.11) | 0.13 | 0.12 | yes | 0.26 | yes | 0.91 |
| dry-p50 | bank (0.10) | 0.19 | 0.17 | yes | 0.38 | **no** (C3 2/2) | 0.54 |
| wet-adG2 | bank (0.24) | 0.21 | 0.14 | yes | 0.43 | unscored | 0.95 |
| dry-lma125 | u215–u429 (0.13) | 0.48 | 0.30 | yes | 0.95 | **no** (C2; C3 23/25) | **−0.17** |
| flat-al1125 | u429–u857 (0.05) | 0.39 | 0.23 | yes | 0.77 | **no** (C2) | 0.87 |
| wet-lma08 | u215–u429 (0.28) | 0.20 | 0.24 | yes | 0.41 | unscored | 0.86 |
| wet-hmat125 | u215–u429 (0.30) | 0.31 | 0.26 | yes | 0.62 | unscored | 0.93 |
| epi-hmat08 | u215–u429 (0.08) | 0.14 | 0.07 | yes | 0.29 | yes | 0.80 |
| epi-adG208 | u215–u429 (0.14) | 0.19 | 0.16 | yes | 0.37 | yes | 0.72 |
| ld104-p50125 | u215–u429 (0.07) | 0.09 | 0.11 | yes | 0.18 | yes | 0.85 |
| ld107-adG2125 | u215–u429 (0.08) | 0.13 | 0.07 | yes | 0.25 | yes | 0.80 |

(W and est max in ε for the ε column, in ε/2 units for the ε/2 column; C2/C3 read in
target units.)

- **ε: 17/17 scored cases pass** with 2 runs, the E6 pair itself. **A1 holds.**
- **ε/2: every S1 is within ε/2** (worst 0.95 of ε/2, dry-lma125), so stopping there is
  right on C1, but **the estimate is not honest at ε/2 on the dry records**: 6 of 10 scored
  cases pass. The fails are dry (C2: a quantity over ε/4 read under ε/8; C3 4/4), dry-p50
  (C3 2/2), flat-al1125 (C2), and dry-lma125 (C2; C3 23/25, cos −0.17). The global pair
  reads S1's error with cos 0.33–0.54 on the dry family against 0.72–0.95 elsewhere.
  **A2 refuted, A3 holds.**
- So the weak point of the design at fine targets is its first step: E1 is the whole estimate
  wherever it says stop, and on the dry records it is right in size (est max 0.17–0.30 against
  W 0.19–0.48) but wrong in pattern. The square law across E6's pair (12-d inset → 7.5 d)
  holds for S0's error (the held-out round's read 0.98) better than for S1's.

**Map guard** (`guard_map.R`) [m]: the scratch build's map run of episodic-lma's S1 at 1e-4
reproduces E6's saved libS check run: J, step times and the 50 trait gradients
`identical()`. Its map (ε of ln J): F +0.029, I1 −0.011, I2 −0.041, I3 −0.083, L +0.004.

## Pre-registration 3 (before reading any refined run's error against its reference)

An offline variant of the bookkeeping, computed from the same runs: the user's literal
share rule, est = Σ measured remainders + E1 × (the unmeasured regions' |ln J| shares).
It loses E1 as regions get measured; the tool's (E1 − Σ measured S1 errors + Σ remainders)
keeps E1 throughout.

| # | prediction | P |
|---|---|---|
| V1 | Over the refined runs (all cases and tiers), the tool's estimate has the higher cos with the run's true error on more runs than the share variant | 60% |
| V2 | Over the same runs, the tool's estimate passes C3 (at the case's target) at least as often as the share variant | 55% |

## Results 2: episodic-lma's reference rebuilt (`refs.R`) [m]

u215 / u429 / u857 with the held-out recipe (10, 10 and 21 min). Own move u215 → u429 0.28ε,
u429 → u857 **0.065ε** (lma; rms 0.032), order 2.14 (median over 26 quantities moving
> 0.3ε). The u429 → u857 reference differs from u215 → u429 by at most 0.039ε and from the
bank's old one (m_lma1252 → m_lma1254, whose rungs disagree by 0.95ε) by at most 0.084ε
(rms 0.021): the old rungs moved a lot but their extrapolation was right. E6 against the new
reference: committed W 1.29, check W 0.42 (old: 1.28, 0.41).
**Z1 refuted** (0.084 < 0.5), **Z2 holds** (0.065 < 0.167). episodic-lma now scores ε/4 and
joins the 3e-5 tier (driver launched before any of its 3e-5 runs).

## Results 3: dry-lma125's third rung (`refs.R`) [m]

u857 (28 min). Own move u429 → u857 **0.038ε** (TF24_cost_scale; rms 0.014), so it scores
ε/4: **Z3 holds**. But the u429 → u857 reference differs from u215 → u429 by **0.241ε**
(TF24_cost_scale; rms 0.069), though u215 → u429's own move was only 0.128: on that quantity
the two moves have opposite signs, so the u215 rung was not on the square law.
**Z4 refuted.** Against the new reference S1's worst error falls from 0.48 to **0.27** (a_l1)
and S0's from 0.71 to 0.65. Part of the near-extinction "misread" of earlier rounds was the
reference. A sign change between rungs also means the 0.038 own move may understate the new
reference's error; dry-lma125's ε/4 scores are read with that caveat [i].
dry-lma125 joins the 3e-5 tier (driver launched before any of its 3e-5 runs).

## Results 4: the noise floor at 3e-5 (`nudge.R`) [m]

| case | 5% nudge of S1 at 3e-5: rms | max (q) | along M | S1 3e-5 − S1 1e-4: rms | max |
|---|---|---|---|---|---|
| flat-al1125 | 0.0122 | 0.041 (TF24_cost_scale) | +0.050 | 0.028 | 0.108 (TF24_cost_scale) |
| ld104-p50125 | 0.0041 | 0.015 (TF24_cost_scale) | +0.008 | 0.004 | 0.019 |
| episodic-lma | | | | 0.008 | 0.030 |
| epi-hmat08 | | | | 0.003 | 0.013 |

The floor at 3e-5 is 0.004–0.012 rms (1e-4: 0.024), 0.01–0.05 along M (1e-4: 0.09). **B1
refuted narrowly** (flat 0.0122 > 0.012); B2 so far holds (rms 0.003–0.028). The tool's
noise threshold at 3e-5 stays 0.012, the larger of the two. On flat-al1125 the tolerance
move is 0.11ε along M, a third of what 1e-4 adds to its S1 error (W 0.39 → 0.45 at 3e-5).

## Results 5: ε/4 on the four cases with ready references (`drive.R 3e-5`) [m]

At 3e-5 E1's largest entry is 0.212 (flat-al1125), 0.110 (ld104-p50125), 0.068
(epi-hmat08) and 0.083 (ld107-adG2125): all under 0.25, so the tool stops at S1 on all four
(2 runs). **B3 holds; B4 refuted** (flat-al1125's E1 0.212 < 0.25 although its S1 is 0.445
from the reference at 3e-5). Scores below with the rest of the tier.

## Pre-registration 4 (before the uniform k = 2 runs at 3e-5 on these four)

E1 under-reads flat-al1125's S1 (0.21 against 0.45). Is that the global pair (S0 → S1,
12-d → 7.5-d inset) or any order-2 pair? One run per case: uniform k = 2 at 3e-5. Then
E1' = (Q1 − Q2u)·1.6²/(1.6² − 1) estimates S1's error from the next pair up.

| # | prediction | P |
|---|---|---|
| U1 | On flat-al1125, E1' reads S1's worst error within ×1.3 (worst \|E1'\| ≥ 0.35) | 50% |
| U2 | E1' has a higher cos with S1's true error than E1 on at least 3 of the 4 | 60% |
| U3 | S2u passes C1 at ε/4 on all four | 75% |

## Results 6: episodic-lma at ε/2, 1e-4 (`drive.R`, `steps.R 1e-4 0.5`) [m]

Seven runs: S0 → S1 → I3 → L → L → I2 → F; 120 → 182 → 211 → 234 → 279 → 321 → 350 nodes, final
rows 662 141 (1.84× S1), all runs' rows 3.09 M. The map's |ln J| shares on S1 were I3 0.46,
I2 0.23, F 0.16, I1 0.06, O and C 0.03 each, L 0.02.

| run | region | W (ε/2) | tool est max | tool cos / read | share variant est max | share cos / read |
|---|---|---|---|---|---|---|
| S1 | – | 0.84 | 1.12 | 0.99 / 1.33 | = | = |
| 3 | I3 | 0.80 | 1.05 | 0.96 / 1.31 | 0.67 | 0.86 / 0.97 |
| 4 | L | 0.90 | 1.15 | 0.98 / 1.36 | 0.60 | 0.94 / 0.80 |
| 5 | L | 0.87 | 1.19 | 0.97 / 1.48 | 0.65 | 0.93 / 0.89 |
| 6 | I2 | 0.80 | 1.11 | 0.97 / 1.49 | 0.40 | 0.91 / 0.56 |
| 7 | F | **0.41** | **0.72** | 0.95 / **2.12** (C3 14/18 miss) | 0.36 | 0.92 / 1.15 (C3 pass) |

Moves (ε): I3 rms 0.086 (max a_l1 0.20); L 0.049 then 0.010 (4·m2/m1 0.79, cos −0.78:
the second is at the floor); I2 0.013; **F 0.112 (lma 0.23)**: the error sat in the founders,
which the |ln J| ranking put third. S1 was already within ε/2 (0.84), but E1 over-read it
×1.33, so the tool refined until the moves took 0.06ε off the worst estimate.
- **A4 holds** (I3 first). **A5 refuted**: the final run is at 0.41 of ε/2 (C1 holds) but
  its estimate reads ×2.1 (C3 fails): est = E1 − Σ moves carries E1's 0.13ε over-read
  forward in absolute terms while the error shrinks.
- Uniform: k = 2 (S2u, 569 310 rows, W 0.55 of ε/2) meets the rule; on the square law it
  would need ≈ 663 000 rows to reach the tool's 0.41 [i], the tool's final has 662 141.
  A6 is scored on the k = 3 run (queued).

## Results 7: the next pair up reads S1 where E6's pair does not (`upair.R`) [m]

S1's error read by E6's pair (E1) and by the next uniform pair, E1' = (Q1 − Q2u)·r²/(r² − 1);
reads are medians of est/err over quantities with |err| > 0.05ε.

| case (tol) | S1 W | E1 max / cos / read | E1' max / cos / read | S2u W (rows / S1's) | S2u's own est max / cos / read |
|---|---|---|---|---|---|
| flat-al1125 (3e-5) | 0.445 | 0.212 / 0.83 / **0.63** | 0.436 / **0.99** / **0.98** | 0.180 (1.38) | 0.170 / 0.95 / 0.85 |
| ld104-p50125 (3e-5) | 0.082 | 0.110 / 0.91 / 1.22 | 0.097 / 0.95 / 0.97 | 0.035 (1.47) | 0.038 / 0.68 / – |
| epi-hmat08 (3e-5) | 0.130 | 0.068 / 0.89 / 0.58 | 0.068 / 0.91 / 0.75 | 0.089 (1.56) | 0.027 / 0.72 / 0.30 |
| ld107-adG2125 (3e-5) | 0.121 | 0.083 / 0.89 / 0.77 | 0.110 / 0.92 / 0.82 | 0.054 (1.48) | 0.043 / 0.72 / 0.79 |
| episodic-lma (1e-4) | 0.419 | 0.558 / 0.99 / **1.32** | 0.315 / 0.99 / 0.80 | 0.277 (1.58) | 0.123 / 0.95 / 0.59 |

- **U1 holds** (flat E1' 0.436 against W 0.445). **U2 holds** (4/4). **U3 holds** (S2u
  0.035–0.18 < 0.25).
- E6's pair is off the square law at S1's level: it under-reads flat-al1125 ×0.63 and
  epi-hmat08 ×0.58 and over-reads episodic-lma ×1.32, while S1 → S2u reads flat-al1125
  at 0.98 [m]. The 12-d committed inset sits on the closing edge's turn (closing round),
  so S0's strip error is small for a reason the pair cannot see [i].
- epi-hmat08's S2u error (0.089) is no smaller than its reference's own move allows
  (0.077): at ε/4 that case is near its reference's floor.

## Results 8: episodic-lma at ε/4, 3e-5 (`steps.R 3e-5 0.25`) [m]

Eight runs: S0 → S1 → I3 → L → L → I2 → I3 → F; 120 → 182 → … → 409 nodes, final rows 1 015 633
(2.10× S1 at 3e-5), all runs' rows 5.0 M. The same path as at ε/2 (the 1e-4 and 3e-5 maps
rank alike), with I3 taken a second time before F.

| run | region | W (ε/4) | tool est max / cos / read | share est max / cos / read |
|---|---|---|---|---|
| S1 | – | 1.67 | 2.17 / 0.99 / 1.26 | = |
| 3 | I3 | 0.97 | 1.37 / 0.96 / 1.51 | 1.42 / 0.88 / 1.66 |
| 4 | L | 1.09 | 1.53 / 0.97 / 1.41 | 1.29 / 0.96 / 1.23 |
| 5 | L | 1.12 | 1.59 / 0.97 / 1.47 | 1.36 / 0.96 / 1.26 |
| 6 | I2 | 1.21 | 1.65 / 0.97 / 1.46 | 0.83 / 0.90 / 0.74 |
| 7 | I3 | 1.21 | 1.41 / 0.96 / 1.37 | 0.58 / 0.88 / 0.58 |
| 8 | F | **0.36** | **0.68** / 0.88 / **2.28** (C3 19/20 miss) | 0.46 / 0.93 / 1.65 (C3 pass) |

Moves (ε): I3 0.122 rms then 0.019 (4·m2/m1 0.62, cos 0.98: faster than order 2); L 0.036
then 0.007 (0.58); I2 0.019; F 0.103 (lma 0.21). Refining L twice and I2 raised the worst
error (1.09 → 1.21 of ε/4): those regions' errors partly cancelled the founders'. The
founders held the elasticity error (lma, r_l, TF24_cost_scale), but the |ln J| map put them
third and their rows are the dearest, so they came sixth.
- Final: within ε/4 (0.36; C1 holds) but read ×2.3 (C3 fails), the same over-read as at ε/2.
- The duplicate of `un_episodic-lma_3e-05_k2` (queued by hand and by the driver at once)
  cost one extra run.

## Results 9: the near-extinction case at ε/4, and the ε/4 table (`steps.R`, `score.R 3e-5`) [m]

dry-lma125 ran to the cap (10 runs): S1 → L → L → I3 → I2 → I3 → L → L → I1, 204 → 798 nodes,
final rows 1 626 422 (2.52× S1), all runs' rows 9.7 M. The tenth run was queued by the
driver's pass already in flight when the wrap-up came. The S1 map put L at 0.14 of the
|ln J| profile, and late rows are cheap, so L came first and returned four times.

| run | region | W (ε/4) | tool est max / cos | share est max / cos |
|---|---|---|---|---|
| S1 | – | 1.22 | 1.24 / 0.14 | = |
| 3 | L | 1.51 | 2.02 / 0.75 | 0.85 / 0.82 |
| 5 | I3 | 0.79 | 1.70 / −0.19 | 1.00 / −0.07 |
| 6 | I2 | 0.53 | 2.00 / −0.10 | 0.67 / 0.25 |
| 8 | L | 0.58 | 2.02 / −0.17 | 0.44 / 0.17 |
| 10 | I1 | 0.85 | 1.45 / −0.55 | 0.55 / −0.28 |

Moves (ε): L 0.090, 0.023, 0.037, 0.025 rms (TF24_cost_scale +0.25 first, cos with the
previous move −0.84, −0.78, −0.95: the late region alternates, flagged at its second move);
I3 0.084 then 0.042 (4·m2/m1 1.94, cos 0.82); I2 0.038; I1 0.014. The true error fell
under ε/4 from run 5 on and wandered (0.53–0.85), while the estimate stayed at 1.5–2.4 of
ε/4 with the wrong pattern: no run of the ten reads it (C3 0/8 for both bookkeepings).

**ε/4 per case** (3e-5; W and est in ε/4 units; rows of the final run; uniform's rows at the
tool's worst error from log-log interpolation on its k = 1–3 ladder [i]):

| case | runs | regions | nodes / rows | W | est max | read | pass | uniform (rule) | uniform at tool's W |
|---|---|---|---|---|---|---|---|---|---|
| flat-al1125 | 2 | – | 235 / 1.27 M | **1.78** | 0.85 | 0.63 | no (C1 C2 C3) | k = 1, the same | – |
| ld104-p50125 | 2 | – | 209 / 0.82 M | 0.33 | 0.44 | 1.22 | yes | k = 1 | – |
| epi-hmat08 | 2 | – | 215 / 0.61 M | 0.52 | 0.27 | 0.58 | yes | k = 1 | – |
| ld107-adG2125 | 2 | – | 200 / 0.77 M | 0.49 | 0.33 | 0.77 | yes | k = 1 | – |
| episodic-lma | 8 | I3 L L I2 I3 F | 409 / 1.02 M (all 5.1 M) | 0.36 | 0.68 | 2.28 | no (C3) | k = 2: 0.76 M, W 0.81, pass | ≈ 2.5 M (extrapolated past k = 3): tool 0.40× |
| dry-lma125 | 10 (cap) | L L I3 I2 I3 L L I1 | 798 / 1.63 M (all 9.7 M) | 0.85 | 1.45 | −1.27 | no (C2 C3 C5) | k = 2: 0.95 M, W 0.97, C3 fails | ≈ 1.09 M: tool 1.49× |

At ε/2 (1e-4) episodic-lma's final (0.66 M rows, W 0.41) against uniform's k = 2 (0.57 M,
W 0.55) and k = 3 (0.90 M, W 0.30): uniform needs ≈ 0.71 M at the tool's W, tool 0.93×.

## Region honesty: the predicted remainder against the next refinement's move [m]

A first move m1 predicts the region's remainder m1/3, which the next refinement reads as
(4/3)·m2; their ratio is 4·m2/m1 (1 = order 2), rms over the quantities m1 put over three
noise sds.

| case (tol) | region | 4·m2/m1 | cos(m1, m2) | 4·m3/m2, 4·m4/m3 |
|---|---|---|---|---|
| episodic-lma (1e-4) | L | 0.79 | −0.78 | |
| episodic-lma (3e-5) | I3 | 0.62 | 0.98 | |
| episodic-lma (3e-5) | L | 0.58 | 0.53 | |
| dry-lma125 (3e-5) | I3 | 1.94 | 0.82 | |
| dry-lma125 (3e-5) | L | 1.00 | −0.84 | 5.21, 2.68 |

The interiors keep their direction (cos 0.82–0.98) and land within ×2 of the prediction;
the late region does not keep its direction anywhere, and on the near-extinction case its
moves stop shrinking. The founders and the strips were refined once at most, so their
second-move honesty is untested here (dwr and p50 found the founders and interiors clean
order 2 on the bank).

## Predictions scored

| # | P | outcome |
|---|---|---|
| Z1 | 70% | refuted (new and old episodic-lma references differ by 0.084) |
| Z2 | 50% | holds (own 0.065) |
| Z3 | 50% | holds (own 0.038) |
| Z4 | 60% | refuted (0.241, sign change between rungs) |
| A1 | 70% | holds (17/17 scored at ε) |
| A2 | 40% | refuted (6/10 at ε/2) |
| A3 | 70% | holds (C3 23/25 on the old reference, 17/19 on the new) |
| A4 | 70% | holds (I3) |
| A5 | 55% | refuted (C3 fails, read 2.1) |
| A6 | 50% | holds (0.93×, interpolated) |
| B1 | 55% | refuted narrowly (flat 0.0122) |
| B2 | 70% | holds (rms 0.003–0.028 on all six) |
| B3 | 65% | holds |
| B4 | 60% | refuted (E1 0.212) |
| B5 | 60% | refuted (flat 1.78) |
| B6 | 30% | refuted (3/6) |
| B7 | 55% | refuted (episodic-lma 0.40×, dry-lma125 1.49×) |
| B8 | 55% | holds on the two instances (I3 0.62, 1.94) |
| B9 | 35% | untested (no strip refined) |
| B10 | 35% | refuted (C3 0/30 at the end) |
| U1 | 50% | holds (0.436 against 0.445) |
| U2 | 60% | holds (4/4) |
| U3 | 75% | holds |
| V1 | 60% | holds narrowly (the tool's cos higher on 10 of 19 refined runs: 10/11 on episodic-lma, 0/8 on dry-lma125) |
| V2 | 55% | refuted (C3 passes: tool 7, share variant 8) |

25 scored: 13 held (mean P 59%), 11 refuted (mean P 57%), 1 untested.

Runs: 49 in this round (4 references, 2 nudges, 32 map runs on the scratch build, 11 uniform
runs on 10 schedules, one of them twice), all exit 0. The scratch build is deleted; run summaries stay in `runs/`
(26 MB).
