# plant-116 notes: every number and where it came from

Builds (`-O2`, `R CMD INSTALL --strip`, sources from `git archive`, deleted
after each install; `scratchpad/v2/build.sh`), phylloptim 0.10.2 (edaffe8):

- **B105** = origin/PLANT-105 762ad2fc (#115, this PR's base), odelia 0.8.1
  from ODELIA-55 (bfa32cf).
- **B95** = origin/PLANT-95 6ba51da1 (this PR's head), odelia 0.8.2 from
  ODELIA-56 (6c62da2).

Libraries `/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/v2/B105` and `.../v2/B95`.
Scripts and data: `docs/prs/v2/figures/plant-116/`. The stand is
`fixture.R`, a copy of `fitness_stand_parameters()`,
`fitness_stand_environment()` and the control of
`tests/testthat/test-tf24-fitness-gradient.R` at 6ba51da1.

CPU is `proc.time()` user + system, one R process at a time.

| number | source |
|---|---|
{{ROWS}}
