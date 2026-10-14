# F: inverting the method (round 4)

Lens: the skeleton pilot -> committed run -> finer check run -> Richardson-like estimate ->
commit one. Scripts beside this file (`lib.R` loads a case's c/f pair, reference, eps, a09
shrink, CPU); outputs in `scratchpad/dev/schedtest/F_out/`.

## Pre-registrations (written before each computation or run)

- P1 (sanity): `lib.R` reproduces a09's ten decisions and 10/10 pass in the proper setting.
- P2 (assumption 9, rows model): real CPU / run_cost(rows) lies within ±15% on every a09
  run, and f/c in real CPU is within 0.05 of f/c in the model on every case.
- P3 (assumption 8, extrapolation): the extrapolated answer c - d/(1 - s) has worst
  |error| <= 0.35 eps on every case at 1e-4; at 3e-4 (a09h) <= 0.5 eps.
