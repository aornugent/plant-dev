# Pre-registration (round 3, agent B), before scoring valx.R

Offline test of "thin the committed schedule, keep the check whole": committed = a merge
probe (a04's committed schedule thinned), check = a05's real check run (every edge kept),
estimate = (Q_t - Q_k)/(1 - s), s = proxy_err(check)/proxy_err(thinned).

- X1 long drought, mg10 and mgs10: commit coarse, C1-C5 pass, median read 0.85-1.25.
- X2 dry, mg10 and mk10 (stem_c +0.24): the worst coarse error passes 1 or its estimate
  does, so dry commits fine (T rises above a05's 1372); C1-C5 pass.
- X3 dry, mgs10/mgt10 (shift <= 0.10): commit coarse in at most one of the two; pass.
- X4 dry-flat, mg10 (shift 0.12) and mgs10 (0.04): commit coarse, pass, median read 0.8-1.1.

## Outcome (valx.R)

- X1 holds: long drought mg10/mgs10 commit coarse, pass, read 1.16/1.23, T 2371/2389 (a05 2743).
- X2 half fails: dry mg10/mk10/mg0-10 commit fine as predicted, but C3 fails (1/4): the
  check's estimate s/(1-s)·d carries the thinning shift (stem_c +0.21-0.24) into the fine run's read.
- X3 fails: mgs10/mgt10 both commit coarse and fail C1 (a_l1 1.01/1.00 against 0.97 unthinned).
- X4 holds: dry-flat mg10/mgs10 commit coarse, pass, read 0.86, T 1913/1982 (a05 2391).
- Also: dry mg10-40 (13 gaps after 10) passes, T 1300 (a05 1372); mg5.5-5.7 fails C2 on
  storage_relaxation_offset (estimate 0.243 against 0.25; the unthinned base reads 0.272).
