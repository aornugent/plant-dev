# Moved θ on the θ₀ grid: the reserve a stopping target needs

Subject: how much error a TF24 node schedule built at θ₀ carries at a moved θ on the same
grid, so that a schedule loop stopping at ε·(1 − reserve) at θ₀ keeps the whole local
analysis within ε. Every prediction is written here before the run or analysis it
concerns. Scripts are in this directory; outputs in `scratchpad/deep/rootcause/moved/`.
**[m]** measured, **[i]** inferred (a ratio law, an interpolation, a reading).

## Summary

(written after the results)

## Data and definitions (read before predicting)

- **Cases.** Each moved case is its parent's record with one trait moved by TRAIT_REL
  (`harness/schedule/lattice.R` CASES/HELDOUT, `rootcause/h1_run.sh`):
  dry-p50 = dry with root_P50 × 1.2; wet-adG2 = long-wet with a_dG2 × 1.25;
  episodic-lma = episodic with lma × 1.25 (0.32 → 0.40; ln 1.25 = 0.22, the "22%" of the
  proxies note). The weight file is the parent's in every case.
- **Runs.** `adj_run_nk.R`, libS, KNOTS=0, TOL 1e-4, ATOL 1e-4, WEIGHT_SOIL 10, the
  parent's weight, WEIGHT_MAX 100, HMAX 15, SHARE 0.1, SPLIT 1, gradient on: the E6
  committed setting, with TIMES = the parent's `val_insk_c_<parent>` node times and
  TRAIT_REL = the moved case's. Named `mv_<moved>_on_<parent>`.
- **Errors** in ε (resident ε, `eps_vec`), 47 quantities (ln J and 46 elasticities),
  against the moved case's own lib19-class reference (`rootcause/common.R`, via
  `proxies/lad.rds`). W = worst |err|, rms over the 47, along M = err · M_unit (the
  hydraulic direction).
- **Three errors per case.** e_mp: moved θ on the parent grid (new); e_mm: moved θ on its
  own committed grid (`val_insk_c_<moved>`, saved); e_pp: parent θ₀ on the parent grid
  (`val_insk_c_<parent>`, saved).
- **Reserve.** A loop stopping at θ₀ when W(θ₀) = 1 − r keeps W(moved) ≤ 1 if the moved
  error scales with the θ₀ error under refinement (same h² law). With g = W_mp / W_pp,
  r = max(0, 1 − 1/g). Read on W and on rms. The grid-rebuild effect proper is
  W_mp / W_mm.
- **Estimate transfer.** The parent's estimates of its own committed error, from saved
  runs: the x–c pair, est_x = (e_x − e_c)/(1/s_c − 1), s_c = proxy(c)/proxy(x); and E6's
  check, est_f = (e_c − e_f)/(1 − s_f), s_f = proxy(f)/proxy(c) (proxies from the parent's
  pilot, `a09_late.R`). They are used unchanged as estimates of e_mp. Read = median
  est/err over |err| > 0.2; corr; C3 (sign and ×2 on every quantity with
  max(|err|, |est|) > 1/3, at most max(1, 20%) misses); W read = max|est| / W_mp.
- **Guards.** (G1) the TIMES file equals the parent's committed node times bit for bit;
  (G2) each new run's recorded setting equals the moved case's committed run's except
  TIMES; (G3) one forward-only rerun of a saved committed run (episodic-lma on its own
  grid, the cheapest) reproduces its J bit for bit, so library and runner are unchanged.

## Pre-registration 1 (before any run)

Saved numbers the predictions lean on [m]: W_pp dry 0.35, long-wet 0.36, episodic 0.30;
W_mm dry-p50 0.35, wet-adG2 0.44, episodic-lma 1.28 (rms 0.141, 0.123, 0.678). The
parent grids have 149, 157, 135 nodes against the moved grids' 153, 158, 120.

| # | prediction | probability |
|---|---|---|
| R1 | G1–G3 hold: TIMES identical, settings identical but TIMES, J of the forward rerun bit-identical | 95% |
| R2 | dry-p50 on dry's grid: W_mp within ×1.3 of W_mm (0.27–0.46), so the implied reserve against dry's 0.35 is ≤ 0.25 | 70% |
| R3 | wet-adG2 on long-wet's grid: W_mp in 0.34–0.57 (within ×1.3 of W_mm), reserve against long-wet's 0.36 in 0–0.4 | 65% |
| R4 | episodic-lma on episodic's grid: W_mp ≥ 0.8, so the reserve against episodic's 0.30 is ≥ 0.6 | 70% |
| R5 | episodic-lma on episodic's denser grid (135 nodes against its own 120): W_mp < W_mm = 1.28 | 50% |
| R6 | cos(e_mp, e_mm) ≥ 0.85 for dry-p50 and wet-adG2 (the error is set by the trait and the record more than by which of two near grids is used) | 65% |
| R7 | The parent's E6-check estimate transfers on dry-p50 and wet-adG2 (read in 0.5–2 and C3 passes), not on episodic-lma (read < 0.5, under-reading) | 55% |
| R8 | The parent's x–c estimate transfers on wet-adG2 (read 0.5–2), not on dry-p50 (dry's own x–c read is 0.10) nor on episodic-lma | 60% |
| R9 | Rows of each new run within ±10% of the parent's committed rows (same nodes; the step count moves little with one trait) | 70% |

## Results 1

(after the runs)

## Predictions scored

(after the results)
