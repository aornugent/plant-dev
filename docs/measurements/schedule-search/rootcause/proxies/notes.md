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

(written last)

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
