# Brief: rewrite the seven landing PRs, with measurements and figures

The PRs are open: aornugent/phylloptim#21, aornugent/odelia#57 and #58, aornugent/plant#113, #114, #115, #116 (stacked #94 ← #113 ← #114 ← #115 ← #116). Their current text is in `docs/prs/opened/` (`*-body.md`, `*-comment.md`). The user's verdict: unclear. The "long drought" stand is a scenario we made up, and the text names it as if a reader knew it. They want each PR to explain what happens, characterise performance, and show it in figures (ggplot2).

## Read first
- The PR style guide, binding: `git -C /home/user/plant-dev show origin/ad/reverse-mode:docs/pr/STYLE.md`, and its worked example `docs/pr/plant.md` on the same branch.
- fast.ai's teaching philosophy (the style guide cites it): open with the whole game, a runnable example and its output, then the parts.
- `/home/user/plant-dev/AGENTS.md`, *Code style*: no metaphor. Say what happens: "a pass over the recorded steps", never "walk"; "fixed step sequence", never "pinned"; never "frozen/live/seeded/stand in".

## Shape of each PR (from STYLE.md)
- Title ≤ 50 characters, imperative, sentence case.
- Body ≤ 20 lines wrapped at 72: why it was needed, then what changed in observable behaviour. It becomes the squash commit.
- Comment 1, *the whole thing, then its parts*: a runnable R (or C++) snippet with its real output, pasted from a real run; then the terms this branch invents; one ASCII control-flow diagram; what changes for existing code; the file table; a reading order.
- Comment 2, *how it works*: the two to four mechanisms that are not obvious from the diff, each with its figure where a figure shows what prose fumbles, and the performance characterisation.
- Write for the maintainers (they wrote plant). No second person. State facts, not their importance. Every number says which configuration produced it.

## Scenarios
- Prefer plant's own reference regimes (`ladder_reference_regimes()` in `tests/testthat/helper-gradient-ladder.R`): constant rain `wet` (2.0), `drought` (0.1), `seasonal` (mean 1.0, amplitude 1.0), plus `shaded`/`clamped` where relevant.
- Where a daily rainfall record is needed (soil substeps, the storage pool's invader failures), use the synthetic record from `harness/long_drought.R`, and describe it exactly once in each PR that uses it: how it is generated (read the script), its length, its three multi-year droughts, and a small figure of it. Call it "a synthetic 41-year daily rainfall record", never "long drought" bare.

## Figures
- ggplot2 with ragg (`ragg::agg_png`, width 8 in, height 4.5 in, res 200), white background, `theme_minimal(base_size = 12)`, a colour-blind-safe palette (Okabe–Ito), direct labels where possible, a title that states the finding and a subtitle that states the configuration.
- One message per figure. Mechanism figures from real run data (a real step, a real cohort), not cartoons.
- Write each figure as `/home/user/plant-dev/docs/prs/v2/figures/<PR>/<name>.png`, with the script that made it (`<name>.R`) and its data (`<name>.csv`) beside it. Do not commit; the lead commits and links them.

## Measurements
- Counts (accepted steps, rejected steps, rate evaluations, rows) are deterministic: prefer them. Time with `proc.time()` user + sys CPU, one run at a time, repeated where a difference is under 10%, and show the spread.
- Before/after comparisons use the PR's base and head builds, or a runtime switch on one build when the switch reproduces the base exactly (say which).

## Deliverables per PR, in `/home/user/plant-dev/docs/prs/v2/<PR>/`
`title.txt`, `body.md`, `comment1.md`, `comment2.md`. Reference figures as `![alt](FIG:<PR>/<name>.png)`; the lead replaces `FIG:` with the hosted URL. Plus `notes.md`: every number with the command or script that produced it.

PR keys: `phylloptim-21`, `odelia-57`, `odelia-58`, `plant-113`, `plant-114`, `plant-115`, `plant-116`.

## Branches (aornugent forks)
- phylloptim `PHYLLOPTIM-18` (4026aad) on master 0.10.3.
- odelia `ODELIA-55` (bfa32cf, 0.8.1) on master; `ODELIA-56` (6c62da2, 0.8.2) on ODELIA-55.
- plant `PLANT-93` 77e15141 (#94) ← `PLANT-97` eb12399e ← `PLANT-107` 6514fa4c ← `PLANT-105` 762ad2fc ← `PLANT-95` 6ba51da1. 93–107 link odelia 0.7.3 and phylloptim 0.10.2; 105 links odelia 0.8.1; 95 links 0.8.2.
- Do not push to any branch and do not edit PRs or issues.

## Machine
4 cores, about 2.7 GB free disk. Load odelia with `library()`, never `load_all()`. Delete build objects (`src/*.o`, `src/*.so`) after each build. You may delete stale installed libraries under the scratchpad (`scratchpad/dev/lib_*`, `scratchpad/dev/schedtest/lib*`) to make room; keep `scratchpad/restack/` and `scratchpad/dev/ns/`.
