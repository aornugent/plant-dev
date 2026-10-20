# plant-114 notes: every number and where it came from

Builds (`-O2`, `R CMD INSTALL --strip`, sources from `git archive`, deleted
after each install; `scratchpad/v2/build.sh`), odelia 0.7.3 (88cbff7) and
phylloptim 0.10.2 (edaffe8):

- **B97** = origin/PLANT-97 eb12399e (#113, this PR's base).
- **B107** = origin/PLANT-107 6514fa4c (this PR's head).

Libraries `/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/v2/B97` and `.../v2/B107`.
Scripts and data: `docs/prs/v2/figures/plant-114/`. The stand is
plant-dev's `harness/long_drought.R` (`stand_at`, `uniform_times`, `mkenv`,
`AK`), with a zero-depth pulse at every one of its 2931 knots.

CPU is `proc.time()` user + system, one R process at a time; runs of the
two builds alternate (B97, B107, B97, ...).

| number | source |
|---|---|
| snippet outputs | `snippet.R` via `Rscript -e "source('snippet.R', echo = TRUE)"` from the plant-dev root, `PLANT_LIB=B97` and `B107`; logs `scratchpad/v2/out/snip114-B97.log`, `snip114-B107.log` |
| 429 introductions, `ode_tol` 1e-4: 3358 stops, 2747 out of order (81.8%), first at t = 6.915, pairs 1 → 5 at t = 6.92, 10.03, 20.90, 29.79, 39.63; most 5 | `N=429 TOL=1e-4 crossing-run.R` on B97 → `crossing-share.csv`; `share.R` → `share.png` |
| widest pair 1.169 mm at t = 35.463, cohorts born 29.6296 and 29.7222 (34 days apart), 383 cohorts, 4 pairs at that stop | `crossing-run.R` → `crossing-heights.csv`; `crossing.R` → `crossing.png`, `crossing.csv` |
| 108 introductions, `ode_tol` 1e-3: 3039 stops, none out of order | `N=108 TOL=1e-3 crossing-run.R` on B97 → `crossing-share-108.csv` |
| 108 introductions: B97 and B107 J identical (12.662188249200183), 9266 accepted steps on both; CPU medians 44.10 s (B97) and 43.35 s (B107), ranges 43.34-44.83 and 42.81-44.18, five pairs | `N=108 TOL=1e-3 forward-run.R` → `forward-run-108.csv` |
| 429 introductions, five alternating pairs: B97 CPU 223.79, 221.90, 224.66, 221.59, 223.81 s (median 223.79); B107 211.49, 211.40, 211.23, 212.67, 220.68 s (median 211.49); per pair −5.5, −4.7, −6.0, −4.0, −1.4%; medians −5.5%; 12 016 accepted steps on both; J 12.746534371612489 (B97) and 12.746534371656043 (B107), 3.4e-12 relative | `N=429 TOL=1e-4 forward-run.R <rep> forward-run.csv`, queued in `scratchpad/v2/queue2.sh`; `forward.R` → `forward.png` |
| 108-introduction median gap 1.7% (44.10 vs 43.35 s), no crossing: the noise floor of this comparison | `forward-run-108.csv` |
| `reference-gradient.tsv` unchanged by this PR (the file is identical at eb12399e and 6514fa4c; 20 of its 1430 rows are NA on both) | `../plant-113/reference-moves.R <plant clone> eb12399e 6514fa4c` |
| file line counts | `git diff --numstat eb12399e 6514fa4c` |
