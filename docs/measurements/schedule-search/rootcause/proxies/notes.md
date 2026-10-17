# A-priori proxies for the schedule error constant, and loop policies replayed offline

Subject: which a-priori proxies predict TF24's per-case schedule error constant (the
coefficient of h², per quantity and for the worst quantity), and which adaptive loop
(run 1 coarse; run 2 at a spacing chosen from a proxy; the last pair estimates the last
run's error as (Q1 − Q2)/(r² − 1); a further run if over ε) finds the cheapest schedule
that meets ε. Offline only: saved runs, no new SCM runs. Every prediction is written here
before the analysis it concerns. Scripts are in this directory; outputs in
`scratchpad/deep/rootcause/proxies/`. **[m]** measured on saved runs, **[i]** inferred
(a fit, an interpolation in spacing, a model or a reading).

## Summary

**Proxies (part A, ten cases, E6-family ladder).** W varies little on nine cases
(0.30–0.58) and 1.28 on episodic-lma, so the honest baseline is the null proxy (no case
factor): worst misread ×3.06, stopping margin ×3.06. Every pilot-only proxy (a09
J-normalised, the founders' form, an interiors' analogue) misreads episodic-lma by ~×3,
and P1's case factor ranks the cases the wrong way (Spearman −0.62). The forward ln J pair
is worse (×5.2: ln J's error cancels between regions). The one case factor that helps is
the elasticity scale S_el of any gradient run (P5): worst misread ×1.76, margin ×1.72, 75%
of within-ε runs accepted at it, no false accept — at the cost of a coarse gradient run,
which a loop makes anyway. Per quantity no a-priori proxy gives signs or a pattern beyond
a fixed rms envelope (62–69% within ×2). Frontier: cost 0 → margin ×2.9–3.1; 0.75 cr → ×1.72
(P5) or the x–c pair (per-quantity read 0.12 in |log|, but misreads dry/dry-p50 per
quantity); 1.47 cr → E6's check, ×1.13.

**Loops (part B).** The saving comes from the last run being the answer (a pair at R 1.6
amplifies jitter 0.91 against E6's 2.32), not from the proxy: P5, P0 and a fixed ratio land
within ±2% of each other. On today's layout the x → c loop replays at ×0.856 of E6, all ten
in 99% of draws, but dry and dry-p50 pass only by C3's one-miss allowance (reads 0.06,
0.29). On a clean order-2 layout: ×0.81 with r1 = 1.6, ×0.76 with r1 = 2.0 (outside every
measured run). E6 itself fails STRESS (72–87% of case-draws) by its coarse estimate's
noise. Forward-first never pays (×0.95–1.01).

**Location (coordinator's additions).** G + 1 axis runs identify region constants well
(residual 0.03–0.06, order checks to 0.004–0.009), but amplify noise 3.3–6.4× (past ε/3
along M from G = 3); one pair with directions from other cases does not locate (directions
do not transfer: the founders' recovered direction is right on 4 of 10); a Gaussian split
is overconfident. The per-region optimal layout saves 4% of the uses' rows and loses 22–24%
net once its extra run is paid: location is a diagnostic, not a lever.

**Diagnosis.** A validity flag with the 110-d interval check never lies (false-valid ≤
1.6%) but rejects 89–100% of passing iterates, including every cheap loop's final; without
it the flag is honest on clean/order layouts (≤ 1.9%) but not on today's (6–10.5%). H5's
dry ladder reads its x–c pair at 0.86 with 160-d intervals, so the threshold needs
recalibrating on H5.

**H5 (dry only so far).** The coarse pair is honest (read 0.86 [0.67, 0.99], C1–C5 pass),
but the layout costs 1.54× E6's committed rows for 1.7× its worst error; the best loop on
it costs +30% against E6 on dry. Moved θ: no shared-grid runs exist; near-layout readings
put the reserve at 0.2–0.75. Three real runs are proposed for each of the coarse rung and
the moved-θ reserve (section C).

## Data and definitions (read before predicting)

- **The ladder.** Each of the ten cases has three gradient runs of E6's layout family
  (a09 spacing function h scaled by r, each edge node inset 12·r d, late edges left out;
  libS, no knot stops, 1e-4): `val_insx_x` (r = 1.6, inset 19.2 d), `val_insk_c`
  (r = 1, E6's committed run), `val_ins75_f` (r = 1/1.6, inset 7.5 d, E6's check). Two
  side rungs: `val_insk_f` (r = 1/1.6 with the 12-d inset kept) and `val_insx12_x`
  (r = 1.6 with the 12-d inset kept, four cases). Errors are in ε against the lib19-class
  references (`rootcause/common.R`); 47 quantities (ln J and 46 elasticities).
- **The constant.** On the square law, err_q(r) = K_q r². K_q is read at r = 1 as the
  committed run's true error e_c,q. The worst constant is W = max_q |e_c,q|.
- **Regions.** F = the founders' part of e_c (`founders/q1_committed.rds`, −4/3 × the
  move when the founders' intervals are bisected); rest = e_c − F (closing strips,
  interiors, opening strips, jitter). The founders' lattice error at f = 32
  (`founders/q1_lattice.rds`, eF32) is the founders' constant on its own layout.
- **Cost.** Rows model: run_cost(rows, gradient) = rows · 113e-6 s · (1 + 3.27 if
  gradient). A forward run is 0.234 of a gradient run on the same schedule. Costs in
  "committed runs" (cr) are in units of the case's own `val_insk_c` gradient run.
- **Scoring of a final run** (`round4/F/lib.R` crit): C1 every |err| ≤ 1; C2 est > 0.25
  where |err| > 0.5; C3 sign right and est within ×2 of err on every quantity with
  max(|err|, |est|) > 1/3, at most max(1, 20%) misses; C5 every |est| ≤ 1. (There is no
  C4 in the current scorer.) T = T_find + 2·T_use in the rows model, pilot excluded, as
  `round4/AG/lib.R` score_pair (E6: T 9287 on ten, 10/10).

## Pre-registration A (before any proxy is computed; `a_proxies.R`)

Proxies, each a scalar per run (or per case × r²) scaled by one factor β fitted
leave-one-case-out (geometric mean of true/proxy over the other nine cases' runs):
- **P1** the J-normalised a09 proxy, Σ (nrr/J_pilot)^0.6 h³ over open intervals of the
  run's schedule (pilot only);
- **P2F** the founders' form (h_F²/12)·share_F·⟨g′² + g″⟩ from the pilot's fate, at the
  run's founders' spacing h_F (pilot only); **P2I** an interiors' analogue,
  (h_I/70 d)² × the pilot's drydown index (share of J from founders × number of closing
  edges before b = 10 per year); **P2FI** both, summed in quadrature with LOCO weights;
- **P3** P2F (and P1) × the case's elasticity scale S_el = rms(elasticity/ε), read from a
  coarse gradient run (`val_insx_x`; cost 0.75 cr);
- **P4** the forward pair's ln J constant, |lnJ_x − lnJ_c|/(1/s_c − 1) (two forward runs,
  x and c: about 0.41 cr), and **P4s** P4 × S_el;
- **P5** the coarse gradient run's own quantities: S_el × r² alone; per quantity,
  |e_q| ∝ |E_q|/ε_q (relative error the same across traits); the drydown sensitivity
  |E_a_dG2| as a case factor;
- **P6a** the coarse gradient pair x–c itself (H1's estimate; 0.75 cr), the bar from
  below; **P6b** E6's finer check (1.47 cr), the bar from above.

| # | prediction | probability |
|---|---|---|
| A1 | P1 on the ten committed runs: median read of W in 0.75–1.33, and its largest misread (max of read, 1/read) ≥ ×2, episodic-lma under-read | 70% |
| A2 | As a stopping rule over the ladder's rungs (x, c, f, insk_f, insx12; 44 runs), P1 needs a margin ≥ ×2.5 to cover every run, and at that margin accepts ≤ 30% of the runs truly within ε | 65% |
| A3 | P2F alone reads committed W worse than P1 (larger median \|log read\|) | 55% |
| A4 | P3 (P2F × S_el) halves P2F's spread (max/min of true/predicted W over cases) and brings episodic-lma within ×1.5 of the median case | 45% |
| A5 | P4 (forward ln J pair) misreads committed W by more than ×3 on at least one case (ln J's error cancels between founders and the rest; long drought's e_c ln J is about 0) | 75% |
| A6 | Per quantity, \|e_q\| ∝ \|E_q\|/ε_q within a case has a median Spearman correlation (over quantities, per case) below 0.4 | 65% |
| A7 | P6a (x–c pair) has the best per-quantity read of the non-check proxies (smallest median \|log read\| on quantities with \|e\| > 0.2) but its worst case misreads W by ≥ ×2.5 (dry or dry-p50) | 85% |
| A8 | No proxy costing at most the pilot plus two forward runs supports a stopping rule with a margin ≤ ×2 that covers all 44 rungs | 80% |
| A9 | On rest = e_c − F, P2I ranks the ten cases' rest worst with Spearman ≥ 0.5 | 40% |

### Results A, first pass (`a_proxies.R`, `a_proxies.log`) [m]

Read = LOCO-predicted W / true W on the committed run; margins over the 44 rungs. (Full
table and the per-quantity reads are in the log; the consolidated table is in Results A2.)

| proxy | cost (cr) | median read | range | worst misread (case) | m90 | m100 | within-ε runs accepted at m100 | FA at m90 |
|---|---|---|---|---|---|---|---|---|
| P1 | 0 | 1.26 | 0.34–2.31 | ×2.91 (episodic-lma) | 2.25 | 2.91 | 61% | 4% |
| P2F | 0 | 1.49 | 0.19–2.03 | ×5.31 (episodic-lma) | 4.97 | 8.04 | 14% | 18% |
| P2I | 0 | 1.49 | 0.25–2.05 | ×3.97 (episodic-lma) | 3.79 | 6.86 | 6% | 9% |
| P3 (P2F × S_el) | 0.75 | 1.31 | 0.19–1.84 | ×5.31 (episodic) | 3.54 | 9.10 | 8% | 10% |
| P3a (P1 × S_el) | 0.75 | 0.96 | 0.50–2.04 | ×2.04 (episodic) | 1.99 | 2.30 | 64% | 4% |
| P4 (forward ln J pair) | 0.41 | 1.06 | 0.19–4.27 | ×5.23 (dry-flat) | 4.02 | 7.69 | 14% | 0% |
| P5 (S_el × a09 shrink) | 0.75 | 0.92 | 0.67–1.76 | ×1.76 (dry-p50) | 1.58 | 1.72 | 75% | 0% |
| P5d (\|E_a_dG2\|) | 0.75 | 1.32 | 0.42–1.86 | ×2.40 (dry-flat) | 2.13 | 3.53 | 53% | 0% |
| P6a (x–c pair) | 0.75 | 1.04 | 0.76–2.57 | ×2.57 (episodic) | 1.11 | 1.31 | 89% | — |
| P6b (E6's check) | 1.47 | 1.04 | 0.89–1.50 | ×1.50 (dry) | 1.12 | 1.13 | 100% | — |

- P1's case factor is anti-informative on the committed runs: Spearman(prediction, W)
  −0.62. Its reads look acceptable only because W itself varies little across cases
  (0.30–0.58 on nine, 1.28 on episodic-lma).
- Per quantity, the a-priori proxies give no usable pattern: |e_q| ∝ |E_q|/ε_q has median
  Spearman 0.20 over quantities within a case (0.05–0.94).
- A9's interiors' analogue ranks the rest the wrong way (Spearman −0.50).

Scored:
- A1 **confirmed**: median 1.26, largest misread ×2.91, episodic-lma under-read 0.34.
- A2 **refuted** (half): the margin is ×2.91 ≥ 2.5, but at it P1 accepts 61% of the
  within-ε runs, not ≤ 30%. On this E6-family sample W varies less than on the 692-run
  library error-structure used (22% there).
- A3 **confirmed**: P2F's median |log read| over the rungs is 0.54 against P1's 0.34.
- A4 **refuted**: P3's spread is 9.8× against P2F's 10.8×; episodic-lma reads 0.45
  against a median of 1.31.
- A5 **confirmed**: P4 misreads dry-flat ×5.2 (0.19) and episodic ×4.3.
- A6 **confirmed**: median Spearman 0.20.
- A7 **refuted as registered**: P6a has by far the best per-quantity read (median |log
  read| 0.12 against ≥ 0.64 for every a-priori proxy), but its worst misread of W is
  episodic's ×2.57 over-read; dry and dry-p50 read W at 1.07 and 1.01, although their
  per-quantity reads are 0.10 and 0.37 (H1). W hides the misreads that C3 catches.
- A8 **confirmed**: the cheapest class's best margin is P1's ×2.91.
- A9 **refuted**: Spearman −0.50.

## Pre-registration A2 (before the null proxy and the envelope reads are computed)

The null proxy P0 has no case factor: one constant × the a09 shrink from c (within a
case, the same r² law every proxy uses). Per-quantity reads above used a geometric-mean
scale per quantity, which small errors pull down (every scalar proxy reads a median 0.3–0.5);
the envelope version scales each quantity by its rms over the training cases.

| # | prediction | probability |
|---|---|---|
| A10 | P5 beats P0 on both the worst misread of committed W and m100 over the 44 rungs; P1 does not beat P0 on either | 70% |
| A11 | With the rms envelope per quantity, no a-priori scalar proxy gets ≥ 60% of the quantities with \|e\| > 0.2 within ×2 | 75% |
| A12 | P5's read of committed rms (not W) has a worst misread ≤ ×2 | 55% |

### Results A2 (`a_proxies.R`, rerun with P0, the envelope and rms reads) [m]

| proxy | cost (cr) | worst misread of committed W | m100 over 44 rungs | within-ε accepted at m100 | Spearman(pred, W) on c | per quantity within ×2 (envelope) | worst misread of committed rms |
|---|---|---|---|---|---|---|---|
| P0 (no case factor) | 0 | ×3.06 (episodic-lma) | 3.06 | 56% | −0.73 | 62% | ×4.87 |
| P1 | 0 | ×2.91 (episodic-lma) | 2.91 | 61% | −0.62 | 59% | ×4.63 |
| P3a (P1 × S_el) | 0.75 | ×2.04 | 2.30 | 64% | −0.14 | 69% | ×1.93 |
| P4s (ln J pair × S_el) | 1.16 | ×4.45 | 6.55 | 25% | 0.01 | 69% | ×4.05 |
| **P5 (S_el × a09 shrink)** | 0.75 | **×1.76** (dry-p50) | **1.72** | **75%** | 0.02 | **69%** | ×2.03 |
| P5d | 0.75 | ×2.40 | 3.53 | 53% | −0.37 | 65% | ×2.80 |

- The null proxy is the honest baseline: W varies 0.30–0.58 on nine cases, so any
  proxy whose case factor is uninformative reads them within ×1.6 and fails only on
  episodic-lma. Every pilot-only proxy misreads episodic-lma by about ×3 (0.16–0.34):
  its error is the soil field part of the founders' error, whose trait derivative a
  forward pilot cannot see (founders/notes.md, E).
- The elasticity scale S_el = rms(E/ε) of any gradient run is the only case factor that
  helps: S_el is 1.8× the median on episodic-lma, and the error in an elasticity is h²
  times the trait derivative of the error constant, which grows with the trait
  sensitivity of J [i]. It does not order the nine ordinary cases (Spearman 0.02 on c);
  it lifts the one case that matters.
- Per quantity, a fixed rms pattern across cases already reads 62% of the quantities
  over 0.2 within ×2; case factors add at most 7 points. No a-priori proxy gives signs.

Scored:
- A10 **refuted as registered**: P5 beats P0 on both (×1.76 against ×3.06; m100 1.72
  against 3.06), but P1 beats P0 too, by a margin within noise (×2.91 against ×3.06 on
  both), while ranking the cases the wrong way (Spearman −0.62).
- A11 **refuted**: P5, P3a and P4s reach 69% within ×2, and P0 62%.
- A12 **refuted, narrowly**: P5's worst misread of committed rms is ×2.03 (episodic-lma
  reads 0.49).

## Pre-registration B (before any loop is replayed; `b_loop.R`)

**Replay model.** Spacing r is relative to E6's committed run. Three error modes:
- **meas** (today's layout): the stored rungs r = 1.6, 1, 1/1.6 exactly; between rungs,
  each quantity linear in r² between the neighbouring rungs, plus the share of jitter
  the interpolation removes [i]; r is clipped to [1/1.6, 1.6], since no E6-family run
  exists outside it.
- **clean** (what H5 aims at): err_q(r) = e_c,q · r² plus fresh jitter for every run [i],
  r in [0.5, 2.0] (r > 1.6 extrapolates past the coarsest measured run: marked).
- **order** (clean with pre-asymptotic scatter): err_q(r) = e_c,q · r^p_q, p_q drawn per
  case, quantity and draw from N(2, 0.3²) truncated to [1.2, 3] (the measured per-quantity
  orders 1.8–2.5) [i].
Jitter per run: N(0, 0.020²) per quantity plus 0.09·z along M (0.024 rms in all). A
nested repeat of a spacing reuses its jitter. Rows: log rows piecewise linear in log r
through the three rungs, end slopes beyond [i]. Estimates use the a09 shrink
s = proxy(r_b)/proxy(r_a), interpolated the same way, as E6 does.

**Policies.** E6 (c then f, commit c when every |est| < 1); E6-shaped with other r1 and
ratio ("commit coarse"); the last-run loop: gradient run 1 at r1; run 2 at r1/R2 (fixed)
or where P5 (S_el of run 1, LOCO scale) or P0 predicts W = t2; stop when max|est| < τ;
else the controller r_next = r·(t/est)^(1/2), each step clipped to a pair ratio in
[R_min, 2], at most four gradient runs; damping options none / clip / blend (geometric
mean of this and the previous measured constant); forward-first (two forward runs, ln J
constant, P4's LOCO scale picks the gradient pair).

| # | prediction | probability |
|---|---|---|
| B1 | The replay reproduces E6 from the stored rungs exactly: T 9287, 10/10 | 95% |
| B2 | meas: no last-run loop passes 10/10 below E6's T; every loop whose pair spans 1.6 → ≤ 1.28 fails C3 on dry or dry-p50 | 70% |
| B3 | clean: the best last-run loop passes all ten in ≥ 95% of draws at T ≤ 0.80 × E6's | 60% |
| B4 | clean: choosing run 2 by P5 beats the best fixed ratio (same r1) by ≥ 5% in T at equal pass rate | 45% |
| B5 | Forward-first is never on the T–pass front, in any mode | 75% |
| B6 | Without step clipping the controller oscillates (≥ 4 gradient runs) in ≥ 5% of case-draws; clipping to [R_min, 2] removes it | 40% |
| B7 | At the front's cheapest feasible point the constraint that binds is C3, not C1 or C5 | 55% |
| B8 | order mode costs the best clean policy ≥ 5 points of pass rate (case-draws) at the same parameters | 50% |

**Scoring amended before any replay (coordinator's message, registered here before the
first run).** Loops are judged on the last run R_k with e_k = (Q_{k−1} − Q_k)/(R² − 1),
R = r_{k−1}/r_k (the spacing ratio, not the a09 shrink; E6 keeps its own rule and
shrink). T = Σ cost(R_i) + 2·cost(R_k); the wasted part Σ_{i<k} cost(R_i) and k are
reported. STRESS: every decision (stop, next spacing, the proxy's run-2 choice, the
forward pair) is made on perturbed values, truth + the scorer's miss (N(0, 0.025²) per
quantity, shared by the case's runs) + N(0, 0.04²) per run; C1 and the reads (C2, C3)
are judged against the truth. Reported per policy: the amplified floor 0.09/(R_k² − 1)
along M (flag > ε/3) and 0.024/(R_k² − 1) rms; C4 = termination (k ≤ 4) and no run
outside the measured range [1/1.6, 1.6] (in clean/order, r > 1.6 is reported as
"outside the evidence", since whether those runs refuse is unknown); interruptibility
(do C2 and C3 hold on every intermediate (Q_i, e_i), i ≥ 2). B1 is scored without
STRESS (the stored rungs exactly).

## Pre-registration C (before the location study; `c_regions.R`)

Region error vectors on disk: founders F on c (all ten, −4/3 × (fbis − c)); closing
strips C = −(res − c) (dry, dry-p50, dry-flat, long-wet); on top of res: interiors I
(−4/3 × (I2 − res), and I4 for an order check), opening side O, late L, b1 edge B (dry,
dry-flat; long-wet I, O). Model per quantity: e(run) = e∞ + Σ_g K_g h_g², h_g relative
to the base run.

| # | prediction | probability |
|---|---|---|
| C1 | G + 1 axis runs (res + F2 + I2 [+ O4 + L4]) predict e_res within rms 0.06 on dry and dry-flat, and K_I from I2 predicts I4 within rms 0.04 | 60% |
| C2 | Their noise amplification (sd of the predicted error per unit run jitter) is ≥ 2× that of E6's coarse estimate (2.3) for G = 4 | 75% |
| C3 | Optimal per-region allocation (founders / rest on ten cases from c, fbis, f; four regions on dry and dry-flat) saves < 10% of T against one global scale at the same ε target, after paying for the extra runs | 70% |
| C4 | Region directions transfer across cases within a family: cos ≥ 0.8 for the founders within each of the two families, and for I between dry and dry-flat | 55% |
| C5 | On dry, I and C are nearly anti-parallel (cos ≤ −0.6), so one pair cannot split them (condition number of the 2-direction fit ≥ 5) | 60% |
| C6 | One pair (c–f move) with directions from other cases recovers the founders' error within ×1.5 (norm) on ≥ 7 of 10 cases | 40% |
| C7 | The Bayesian split (priors from part A's proxies, the pair fixes the total) has a posterior sd of the founders' share ≥ 0.15 on most cases | 55% |

## Pre-registration D (before the validity flag is scored on the loop iterates; `d_flag.R`)

Every iterate i ≥ 2 is flagged valid when all applicable checks hold: the coarser run's
largest open interval before b = 20 is under 110 d; the amplified floor 0.09/(R² − 1) is
under 1/3; with three runs, the two successive moves shrink within ×[0.5, 2] of the law
and cos ≥ 0.9; max|e_i| is within ×[1/2, 2] of P5's a-priori prediction. False-valid =
P(C2 or C3 fails | valid); false-invalid = P(invalid | C2 and C3 hold).

| # | prediction | probability |
|---|---|---|
| D1 | The interval check marks every pair whose coarse run is r ≥ 1.28 invalid (a09 caps 100 d at r = 1, so 128 d at r = 1.28) | 85% |
| D2 | In meas mode, the false-valid rate is ≤ 5%, but dry and dry-p50 x–c pairs that pass C3 by its one-miss allowance (reads 0.06–0.3) are flagged invalid only by the interval check, not by the order or proxy checks | 60% |
| D3 | The false-invalid rate is ≥ 50% for the cheapest feasible loops (they use r1 ≥ 1.6), so a flag that must not lie costs most of the loop's saving | 65% |

### Results C (`c_regions.R`, `c_regions.log`) [m unless marked]

**Region vectors on disk (rms, ε).** Founders on c: all ten (0.03–0.34). dry: C 0.085,
F on res 0.132, I 0.145, O 0.049, L 0.023, B 0.018. dry-flat: C 0.054, F 0.142, I 0.069,
O 0.026, L 0.018, B 0.005. long-wet: C 0.019, I4 0.022, O 0.021. dry-p50: C 0.104.

**(1) Transfer.** The founders' directions cluster into two families, but loosely:
{dry, dry-p50, ld-105, long drought, dry-flat} cos 0.81–0.99 among themselves;
{long-wet, wet-adG2} 0.98 with each other and 0.61–0.89 with the first group;
{episodic, episodic-lma, ld-102} cos only 0.47–0.60 among themselves and −0.78 to +0.37
against the rest. ld-102 (a long-drought seed) sits with the episodic cases. Closing
strips: dry, dry-flat, dry-p50 cos 0.91–0.98; long-wet 0.34–0.57 against them. I: dry
against dry-flat 0.92. O: 0.72–0.83.

**(2) Conditioning on one case.** No pair of regions is near-parallel: on dry
cos(I, C) = −0.53, cos(F, L) = −0.86 (L is at the jitter floor), cos(C, O) = −0.86;
κ(F+I+C) = 2.0 (dry), 1.4 (dry-flat); κ(F+I+C+O) = 4.3 and 5.1. Interiors and closing
strips are separable on one case when their directions are known; the problem is knowing
them.

**G + 1 axis runs on res.** The fitted sum predicts e_res (rms 0.209 dry, 0.196 dry-flat)
with residual rms 0.063 / 0.064 (G = 2: F, I), 0.062 / 0.043 (G = 3, + O), 0.052 / 0.033
(G = 4, + L); cos 0.95–0.99; C2 and C3 hold on all. The interiors' order holds: K_I from
I2 predicts I4 within rms 0.009 / 0.004 (cos 1.00). Noise amplification of the predicted
error per unit run jitter [i, from the design]: G = 2 3.27, G = 3 4.32, G = 4 5.37, G = 5
6.36 — against 2.32 for E6's coarse estimate and 0.91 for a last-run pair at R = 1.6. Along
M (0.09 per run) that is 0.29, 0.39, 0.48, 0.57: past ε/3 from G = 3. The coordinator's
mixed design (run 2 refines F ×2 and I ×1.4, run 3 the reverse) amplifies 1.98 against the
axis design's 3.27 for G = 2.

**(3) One pair, directions from other cases** (G = 2: the founders' and the rest's first
principal direction over the other nine cases, fitted to the c–f estimate of e_c). The
fit leaves 35–86% of the estimate's norm unexplained (median 0.60): the two directions
from other cases do not span this case's error. Founders' norm recovered within ×1.5 on
7 of 10, but with cos ≥ 0.7 on only 4 (dry 0.93, dry-p50 0.91, ld-105 0.81, long drought
0.80); episodic −0.53 and ld-102 −0.47 come out with the wrong direction. The founders'
share is misread by up to 0.6 (ld-102: 0.05 against 0.67; episodic-lma 0.92 against 0.41).
Noise amplification of the founders' coefficient 2.5–3.4 per quantity, against 1.89 for
the G + 1 run (fbis) that measures it directly.

**(4) Gaussian split** (priors: P3-LOCO for the founders' norm, P5-LOCO for the rest;
the pair fixes the total). Posterior sd of the founders' share 0.03–0.11, while the
posterior mean misses the measured share by up to 0.62 (ld-102 0.05 against 0.67,
episodic-lma 0.85 against 0.41, dry 0.80 against 0.58). The spread understates the
misread: the model's error is in the directions, which the Gaussian treats as known.

**What location is worth.** Ten cases, two regions (founders, rest), K from c, fbis and f,
the cheapest final layout meeting max_q(|F_q| h_F² + |R_q| h_R²) ≤ target against one
global scale: the uses' rows fall 4.1% (target ε) and 4.3% (0.7ε) summed over the ten
(per case 0.2–10%: wet-adG2 10%, long-wet and ld-102 6.5–7%, long drought 0.3%). Paying
for the fbis run turns that into a net T increase of about 22–24% per case. Four regions
on res (dry, dry-flat; rows of res's dense closing layout, so [i]): 1.2–2.7%. **Location
is a diagnostic, not a lever**: no per-region allocation found here pays for one extra
run.

Scored:
- C1 **confirmed** for G ≥ 3 (residual 0.033–0.062; G = 2 is 0.063–0.064, at the edge);
  the I2 → I4 order check holds to 0.004–0.009.
- C2 **confirmed**: G = 4 amplifies 5.37, 2.3× E6's coarse estimate.
- C3 **confirmed**: 4% of the uses' rows, a net loss once the extra run is paid.
- C4 **refuted**: within the larger founders' family cos runs 0.61–0.99, and the second
  "family" is three cases at 0.47–0.60; I between dry and dry-flat 0.92 holds.
- C5 **refuted**: cos(I, C) on dry is −0.53, κ 1.8. The two are separable on one case.
- C6 **confirmed as registered** (norm within ×1.5 on 7 of 10), but the direction is right
  (cos ≥ 0.7) on only 4 and reversed on 2; as a locator it fails.
- C7 **refuted**: posterior sd 0.03–0.11, under 0.15 on all ten — and overconfident.

## Results B: loops replayed (`b_loop.R`; pass 1 `b_loop_pass1_{coord,jit}.log`, 1673 policies × 3 modes × 20 draws; pass 2 `b_loop_pass2_{coord,jit}.log`, `f_front.R`, the 84 survivors × 200 draws) [m on the stored rungs; i wherever a run is interpolated or r > 1.6]

**Guard.** Without STRESS the replay gives E6 from the stored rungs exactly: T 9287,
10/10, per case 614 832 990 964 634 1683 857 821 854 1038.

**E6 itself under STRESS.** Deciding on perturbed values, E6 passes 72.5% of case-draws
(coord) and 87% (measured jitter only); all ten together in 0.5% and 15% of draws. Its
failures are C3 on dry, dry-flat and dry-p50: the coarse-run estimate d/(1 − s) amplifies
a run's noise 1.64·√2 ≈ 2.3×, which is enough to push quantities near ε/3 out of ×2. E6's
10/10 on the real runs holds for that one draw of the jitter.

**Best feasible policy of each family** (all ten pass in ≥ 95% of 200 draws; T on ten,
rows model; E6 9287):

| mode / noise | policy | T | ×E6 | all ten | worst W | k mean | wasted | amp. floor along M | runs outside [1/1.6, 1.6] |
|---|---|---|---|---|---|---|---|---|---|
| meas / jit | loop r1 1.6, fixed R 1.6, τ 1, t 0.7 (x → c, a third run where needed) | 7948 | 0.856 | 0.99 | 0.80 | 2.11 | 1676 | 0.16 | 0 |
| meas / jit | loop r1 1.6, P5 t2 0.4, τ 0.8, clip 1.5 | 7965 | 0.858 | 0.98 | 0.81 | 2.00 | 1554 | 0.07 | 0 |
| meas / coord | loop r1 1.6, P0 t2 0.4, τ 1 | 8147 | 0.877 | 0.955 | 0.82 | 2.12 | 1689 | 0.21 | 0 |
| meas / coord | loop r1 1.28, fixed R 1.25, clip 1.5 | 8783 | 0.946 | 1.00 | 0.94 | 2.00 | 1778 | 0.10 | 0 |
| clean / both | loop r1 2.0, fixed R 1.6, τ 1, t 0.7 | 7023 | 0.756 | 1.00 | 0.90 | 2.10 | 1454 | 0.06 | all |
| clean / both | loop r1 2.0, P5 t2 0.7, clip 1.5 | 7069 | 0.761 | 1.00 | 0.82 | 2.10 | 1472 | 0.07 | all |
| clean / both | loop r1 1.6, fixed R 1.4, τ 0.9 | 7505 | 0.808 | 1.00 | 0.75 | 2.10 | 1655 | 0.09 | 0 |
| order / jit | loop r1 2.0, fixed R 1.6, clip 1.25 | 7435 | 0.801 | 0.97 | 0.93 | 2.18 | 1699 | 0.16 | all |
| order / jit | loop r1 1.6, fixed R 1.4, clip 1.25 | 7629 | 0.822 | 0.96 | 0.81 | 2.11 | 1705 | 0.16 | 3% |
| any | forward-first (best) | 8784–9358 | 0.95–1.01 | 0.95–1.00 | 0.79–0.95 | 2.0–2.1 | 2392–2609 | ≤ 0.16 | 0–65% |

- **The saving comes from the last run being the answer, not from the proxy.** A pair at
  R = 1.6 whose finer run is the answer amplifies jitter 0.91 (against E6's 2.32), so the
  loop is more robust than E6 under STRESS, and the coarse partner costs 0.75 cr instead of
  the check's 1.47. P5, P0 and the fixed ratio land within ±2% of each other at the same
  r1 (clean: 7023 / 7069 / 7083; meas-jit: 7948 / 7965 / 8109). Choosing run 2 by a proxy
  only changes which cases need a third run.
- **r1 sets the saving**: r1 = 1.28 → ×0.90–0.95, 1.6 → ×0.81–0.88, 2.0 → ×0.75–0.81. r1 = 2.0
  is outside every measured run of this layout family: whether a run there keeps the square
  law, or refuses, is unknown.
- **No amplified floor exceeds ε/3** at any feasible point (0.06–0.21 along M); Rmin 1.25 is
  enough for the last pair. Termination: k ≤ 3 on every feasible policy; the iteration cap
  (4) is hit only by undamped policies off the front (up to 67% of case-draws for
  `none` with small steps; 24–30% with the step clipped).
- **meas mode passes dry and dry-p50 without reading them.** On today's layout the x–c pair
  reads dry's error at 0.06 and dry-p50's at 0.29 (H1), yet C3 passes: with the spacing-ratio
  estimate only one quantity exceeds ε/3, and C3 allows one miss. The pass is a scorer
  allowance, not a correct estimate; the flag (Results D) is what has to catch it.
- **Fronts.** T against pass rate (case-draws): the cheap end is E6-shaped pairs at
  r1 = 1.6, R = 1.25 (×0.72–0.74, pass 18–78%, worst W 2.0–2.6: C1 and C3 fail); then the
  last-run loops climb from pass 0.63 (×0.77) to ≥ 0.995 (×0.86 meas; ×0.75 clean). T
  against the worst-case margin to ε among feasible policies (clean/jit): ×0.754 at margin
  0.03, ×0.756 at 0.10, ×0.761 at 0.18, ×0.808 at 0.25, ×0.865 at 0.42 (meas/jit: ×0.856 at
  0.20, ×0.862 at 0.42). The front has two sensible points: the cheapest loop (margin
  0.10–0.18) and a margin-0.42 loop at +10% T (r1 1.6, R 1.6, τ 0.8, t 0.5: final at r = 1).

Scored:
- B1 **confirmed**.
- B2 **refuted**: the x → c loop passes all ten in 99% (jit) of draws at ×0.856 — but dry
  and dry-p50 pass C3 by its one-miss allowance with reads 0.06 and 0.29.
- B3 **confirmed as registered** (×0.754–0.756), only with r1 = 2.0, outside the evidence;
  inside it (r ≤ 1.6) the best is ×0.808.
- B4 **refuted**: P5 is within ±2% of the best fixed ratio, either side.
- B5 **confirmed** for the T–pass front (forward-first costs ×0.95–1.01: the forward pair
  pays for nothing the first gradient run would not give); it sits on the T–margin front
  in meas/coord only at ≥ ×1.0.
- B6 **refuted**: the loop never oscillates (each step is finer); undamped small steps
  creep to the iteration cap, and clipping the step reduces that (67% → 24–30% in the worst
  policy) but does not remove it.
- B7 **partly**: at the feasible frontier C3 is the constraint that binds (fC3 0.05, fC1 0);
  just below it, the cheaper E6-shaped points fail C1 as well (worst W 2.0–2.6).
- B8 **refuted**: order scatter costs the clean optimum 1.2 points of case-draw pass rate
  (but 12 points of the all-ten rate: 1.00 → 0.88).

## Results D: the validity flag (`d_flag.R`, `d_flag.log`; 420k iterates per noise) [m on replays]

| mode / noise | valid | false-valid P(C2/C3 fail \| valid) | false-invalid P(invalid \| C2&C3 hold) | without the 110-d check: false-valid / false-invalid |
|---|---|---|---|---|
| meas / coord | 7.6% | 0.2% | 91% | 10.5% / 10% |
| meas / jit | 7.8% | 0.0% | 91% | 5.9% / 11% |
| clean / coord | 11% | 0.0% | 89% | 0.7% / 2.5% |
| order / coord | 11.5% | 1.6% | 89% | 1.9% / 8.6% |
| order / jit | 11.5% | 0.5% | 89% | 0.5% / 4.3% |

- The interval check decides everything: every pair whose coarse run is r ≥ 1.28 is
  invalid (a09 caps 100 d at r = 1), every pair at r ≤ 1.05 valid on it. With it the flag
  never lies (≤ 1.6%) but rejects 89–100% of the iterates that pass, including every final
  iterate of every cheapest feasible loop. C1 never fails on a valid iterate.
- Without it, noise, order and proxy agreement are honest in clean and order modes
  (false-valid 0.1–1.9%) and cheap to satisfy (false-invalid 0.4–8.6%), but not on today's
  layout: 6–10.5% false-valid in meas. The proxy check catches 60–80% of dry's and
  dry-p50's misread iterates; the order check needs three runs, which those cases do not
  make.
- **H5 changes the interval check's premise.** On H5's dry ladder (below) the x–c pair,
  whose coarse run has intervals up to ~160 d, reads the committed run's error at a median
  0.86 [0.67, 0.99], corr 0.96. The 110-d threshold came from edge-anchored spells (mode
  A5); it should be recalibrated on H5's ladders, not carried over.
- **Region split (labelled a-priori).** The a09 proxy's founders' band predicts the
  founders' measured share of the committed error with Spearman 0.25, median miss 0.25
  (episodic-lma 0.65 against 0.24, dry-p50 0.59 against 1.05). The run history of a
  global-spacing loop does not identify regions (Results C); an a-priori split is a label,
  not a measurement.

Scored:
- D1 **confirmed** (100% invalid at r ≥ 1.28, n = 84k–134k per mode).
- D2 **refuted** in its second clause: false-valid is 0–0.2%, but the proxy check also
  flags 60–80% of the dry / dry-p50 misreads, not only the interval check.
- D3 **confirmed**: false-invalid 90–100% on the cheapest feasible loops' final iterates.

## Slack for the local analysis (`e_moved.R`, `e_moved.log`) [m]

No run in the library shares a grid between θ₀ and a moved θ: the three trait-moved cases
built their own grids from their own pilots (1–4 shared nodes of 85–235). The nearest
reading compares each moved case with its θ₀ case on the same record and the same rule:

| θ₀ → moved | rung | W θ₀ / moved | cos of the error vectors | rms difference |
|---|---|---|---|---|
| dry → root_P50 0.2 | c | 0.35 / 0.35 | 0.90 | 0.070 |
| long-wet → a_dG2 0.25 | c | 0.36 / 0.44 | 0.95 | 0.044 |
| episodic → lma 0.25 (−22%) | c | 0.30 / 1.28 | 0.67 | 0.598 |

A grid tuned to just meet ε at θ₀ would need a reserve of about 0.2 for the a_dG2 move and
about 0.75 for the lma move, which lies outside the resident's ±10% but inside the
invaders' ×0.5–×2. No invader errors are on disk. **Runs needed** (three, references
exist): dry-p50 on dry's committed grid, wet-adG2 on long-wet's, episodic-lma on
episodic's (each `adj_run_nk.R`, the θ₀ case's `val_insk_c` node times, the moved case's
trait); then an invader at ×0.5 and ×2 lma on one θ₀ grid with u215/u429 invader
references (four more runs plus references).

## H5's ladder on dry (`build_h5.R`, `h5_check.R`, `b_loop.R` with LAD; dry-p50 still running) [m; loop replay i]

| rung | nodes | rows × E6 committed | W | rms | along M |
|---|---|---|---|---|---|
| N16 (s 1.6) | 193 | 1.32 | 1.46 | 0.397 | −1.54 |
| N10 (s 1) | 224 | 1.54 | 0.60 | 0.170 | −0.65 |
| N06 (s 1/1.6) | 273 | 1.92 | 0.16 | 0.071 | −0.30 |
| E6 committed | 149 | 1 | 0.35 | 0.159 | −0.30 |

- The coarse side is now on the law in direction (cos(d1, d2) 0.92) and nearly in size
  (|d1|/|d2| 2.02 against 2.56, p ≈ 1.5). The x–c pair, as the loop uses it, reads N10's
  error at median 0.86 [0.67, 0.99], corr 0.96, C1–C5 pass: H1's dry failure is gone.
- But H5's fixed nodes make it dearer and its committed rung less accurate than E6's:
  1.54× the rows for 1.7× E6's worst error. The best replayed loop on H5-dry (x at s 1.6,
  then s 1.14) costs T 1080 against E6's 832 on dry (+30%), passing in 100% of draws.
- So on dry H5 buys honesty of the coarse pair at a price above the loop's saving.
  H5's opening `inset` variant (178 nodes at s 1) would recover part of it.

## C. How the search was run, and what to run for real

- **Cheap-first ladder.** Pass 1: 1673 policies (E6-shaped, last-run loops over r1, the
  run-2 rule, τ, the controller's target, damping and R_min; forward-first) × 3 error modes
  × 10 cases × 20 draws, 4 min per noise model. Pass 2: the 84 policies on any pass-1 front
  or best in a family, × 200 draws, with every iterate's flag recorded. Then H5's dry
  ladder through the same replay (15 s).
- **Constrained, not weighted.** Feasible = every case passes C1–C5 (C4: k ≤ 4, here
  k ≤ 3) in ≥ 95% of draws, decisions on perturbed values; among feasible policies, least
  T. The grid is small enough to enumerate, so the constrained optimum and the whole front
  (non-convex parts included) are read directly; no weighted sum is tuned, and a damped
  multiplier method is not needed at this size. Fronts are in Results B.
- **Recommended real runs (ask the main session first).**
  1. *The coarse rung the cheapest front point needs:* one run at s = 2.0 of the layout
     that will be used (H5 rule N) on dry, episodic-lma and long-wet (3 runs). If the
     2.0 → 1.25 pair keeps the square law there, the loop r1 2.0, R 1.6 is expected at
     T ≈ ×0.76 of the same layout's E6-style cost (clean replay), all ten passing; risk:
     intervals of ~200 d leave the law (mode A5) or the run refuses — then r1 = 1.6
     (×0.81) is the fallback, which H5's own N16 rungs already test.
  2. *Moved θ on a θ₀ grid* (3 runs, references exist): dry-p50 on dry's grid, wet-adG2 on
     long-wet's, episodic-lma on episodic's. This sets the reserve a stopping target
     ε·(1 − reserve) needs; the near-layout reading says 0.2 (a_dG2) to 0.75 (lma −22%).
  3. *Nothing new for x → c on today's layout*: it is fully replayed from stored runs
     (×0.856, all ten in 99% of draws), except episodic-lma's third run, interpolated at
     r ≈ 0.67 (1 run would replace the interpolation). It should not be adopted while dry
     and dry-p50 pass only by C3's allowance.

## Predictions scored

| # | P | outcome |
|---|---|---|
| A1 | 70% | confirmed |
| A2 | 65% | refuted (margin ×2.91, but accepts 61%) |
| A3 | 55% | confirmed |
| A4 | 45% | refuted |
| A5 | 75% | confirmed |
| A6 | 65% | confirmed |
| A7 | 85% | refuted as registered (worst misread is episodic's over-read) |
| A8 | 80% | confirmed |
| A9 | 40% | refuted (Spearman −0.50) |
| A10 | 70% | refuted (P1 beats P0 by noise) |
| A11 | 75% | refuted (69%) |
| A12 | 55% | refuted narrowly (×2.03) |
| B1 | 95% | confirmed |
| B2 | 70% | refuted (passes by C3's allowance) |
| B3 | 60% | confirmed (only with r1 2.0, outside the evidence) |
| B4 | 45% | refuted |
| B5 | 75% | confirmed |
| B6 | 40% | refuted |
| B7 | 55% | partly |
| B8 | 50% | refuted |
| C1 | 60% | confirmed |
| C2 | 75% | confirmed |
| C3 | 70% | confirmed |
| C4 | 55% | refuted |
| C5 | 60% | refuted |
| C6 | 40% | confirmed as registered (norm), fails as a locator (direction) |
| C7 | 55% | refuted (and overconfident) |
| D1 | 85% | confirmed |
| D2 | 60% | refuted |
| D3 | 65% | confirmed |

14 confirmed (mean P 69%), 1 partly, 15 refuted (mean P 58%).
