# plant-115 notes: every number and where it came from

Builds (`-O2`, `R CMD INSTALL --strip`, sources from `git archive`, deleted
after each install; `scratchpad/v2/build.sh`), phylloptim 0.10.2 (edaffe8):

- **B107** = origin/PLANT-107 6514fa4c (#114, this PR's base), odelia 0.7.3
  (88cbff7).
- **B105** = origin/PLANT-105 762ad2fc (this PR's head), odelia 0.8.1 from
  ODELIA-55 (bfa32cf). The branch's DESCRIPTION names aornugent/odelia@b707d21;
  bfa32cf differs from it only in `tests/standalone/r_free.cpp`.

Libraries `/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/v2/B107` and `.../v2/B105`.
Scripts and data: `docs/prs/v2/figures/plant-115/`. Rejected attempts are
read by the measurement probe described in `../plant-113/notes.md`
(`scratchpad/v2/probe/`), compiled against each build's headers.

CPU is `proc.time()` user + system, one R process at a time.

| number | source |
|---|---|
| snippet outputs, base and branch: stopped J 12.677287 on both, 11 791 steps on both; free J 9.361588 (base, 10 729 steps) and 12.66866 (branch, 4793 steps) | `snippet.R` via `Rscript -e "source('snippet.R', echo = TRUE)"` from the plant-dev root; logs `scratchpad/v2/out/snip115-B107.log`, `snip115-B105.log` |
| knot stops reproduce the base exactly: B107 and B105 stops, synthetic: J 12.6772865896124, 11 791 accepted, 2408 rejected, 640 509 rows on both; seasonal: J 917.665362732764, 850 accepted, 91 rejected on both | `soil-run.R <scenario> stops 1e-4 0 soil-run.csv` on each build |
| synthetic, ode_tol 1e-4, B105: stops 11 791 / 2408 rejected / 640 509 rows / forward 55.6 s / gradient run 55.3 + 176.7 = 232.0 s; substeps 4793 / 3079 / 237 971 / 26.2 s / 25.4 + 56.9 = 82.2 s; uptake 0.1: 4101 / 2812 / 209 737 / 23.9 s / 22.9 + 51.2 = 74.1 s; substepped steps 2081 (77 818 substeps) and 3086 (93 340) | `soil-run.R synthetic <arm> 1e-4 <0|1>`, rows in `soil-run.csv`; gradient runs also write `soil-run-B105-synthetic-<arm>-1e-04.rds` |
| ratios to stops: steps 0.41, stand evaluations 0.55 (6 x (accepted + rejected)), rows 0.37, forward 0.47, gradient run 0.35 | `soil.R` → `soil-cost.csv`, `soil-cost.png` |
| references, knot stops on B105: synthetic 1e-6 J 12.6685617 (23 184 steps), 1e-7 J 12.6687012 (34 248 steps); seasonal 1e-6 917.644767, 1e-7 917.647196 | `soil-run.R <scenario> stops <tol> 0` |
| |ln J − ln J_ref| at 1e-4: synthetic base-free 0.3025, stops 6.77e-4, substeps 3.01e-6, uptake 0.1 7.38e-5; seasonal base-free 3.13e-4, stops 1.98e-5, substeps 6.39e-5, uptake 0.1 6.37e-5 | `soil.R` → `soil-accuracy.csv`, `soil-accuracy.png` |
| base without stops 26% low: 9.361588 / 12.677287 − 1 = −26.2%; 0.07%: 12.66866 / 12.67729 − 1 = −0.068% | snippet outputs |
| seasonal, 1e-4: stops 850 / 91 / 68 968 rows / 5.89 s / 5.74 + 19.42 = 25.2 s; substeps 586 / 424 / 47 438 / 4.55 s / 5.02 + 10.98 = 16.0 s | `soil-run.csv` |
| one step: t0 0.703821 yr, h 13.476 d, 6 knots inside, 60 substep ends, every knot an end (distance 0); 4793 steps, 1688 span a knot, 2081 substepped; stage quadrature of the rain 0.3296 of 8.5900 (3.8%) | `step-run.R` (B105, no stops, 1e-4) → `step-run.csv`; `step.R` → `step.png` |
| substep tolerance 1e-9 relative, 1e-13 absolute | `substep_tol` and `choose_substeps` in odelia 0.8.1 `ode_step_rkck.hpp` |
| `reference-gradient.tsv`: only seasonal moves; 12 of 1430 rows by more than 1e-3 of their scale, all theta and omega, largest 0.036 of scale (species 2 theta on area_stem); 1143 identical | `../plant-113/reference-moves.R <plant clone> 6514fa4c 762ad2fc` |
| record facts (14 965 days, 2931 knots in the stand) | `record.R`; `length(AK)` |
| file line counts | `git diff --numstat 6514fa4c 762ad2fc` |
