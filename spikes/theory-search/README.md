# Theory search: round-two drivers

The measurements and checks behind the round-two documents in `docs/review/search/`. Each
directory belongs to one developer:

- **`front/`, Developed 1 (`r2-1-…`).** The founder window on the closed TF24 stand
  (`spikes/field-dimension-066`, CASE closed).
  - `run_inv.R` is the driver. The `*.sh` scripts sweep it:
    - `geo`: geometric early introductions, 4, 8 and 12;
    - `held8` and `kept_*`: held against kept gains in P;
    - `lot`: ln b ± ln 2, the scaling laws;
    - `open`: the open stand.
  - The `*_read.R` scripts and `analyse.R`, `bynode.R` and `lai.R` read the results.
  - The `.rds` and `.log` files are the results the document quotes.
  - Left out: the two 1 MB resident recordings, `closed.rds` and `closed_an.rds`.
    `PHASE=resident` remakes them.
- **`lc/`, Developed 2 (`r2-2-…`).** Checks of the sensing–overhead law:
  - the aligned-tournament fit of the measured pair's A;
  - the reflection law ρ² = 1 − 4κ²;
  - the 20,000-case priority-effect sweep;
  - the acclimation sketch.
- **`inv/`, Developed 3 (`r2-3-…`).** Checks of the inverse-optimality identities:
  - the loop (lag) identity on a nonlinear toy;
  - R1 (ŷ = −∇A);
  - the linear case;
  - Kantorovich's radius.

The scripts were run from `/tmp/front`, `/tmp/lc` and `/tmp/inv`, and still name those paths.
`run_inv.R` loads plant from the instrumented leaf-table build (`PLANT_LIB`, see
`spikes/leaf-table/`). This is plant `ODELIA-66` on odelia 0.9.0.

All `front/` results are on one closed stand, one record and one build. The kept derivatives
are finite differences.
