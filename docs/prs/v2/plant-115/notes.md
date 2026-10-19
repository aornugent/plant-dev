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
{{ROWS}}
