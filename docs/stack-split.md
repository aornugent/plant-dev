# What we built since develop: what to keep, and the two PR groups

An aggregate review, branch by branch, with DROP as the default verdict unless the final
configuration needs the branch or it bought a measured gain worth its code. Sections:
`docs/measurements/schedule-search/rootcause/review/stack/` (A: plant 93–101 and side
branches; B: plant 102–105 and odelia; C: plant 106–110 and phylloptim).

The plant stack is one chain over `develop`, PLANT-93 → 110 (64 commits), on ODELIA-53 → 55 and
PHYLLOPTIM-17 → 19. Only plant#94 (PLANT-93) has an open PR.

## Verdicts

| branch | verdict | why (measured; section) |
|---|---|---|
| PHYLLOPTIM-17 | keep, split | Root-finds stop at roundoff: replay noise in ln J falls from 1.9e-8 to 8.5e-15. It carries 8 commits of the unmerged 0.9.0 base, so split those off. Cut two probe programs (563 lines). (C) |
| PHYLLOPTIM-18, 19 | keep | They fix gradient refusals the loop hits (long drought at 1e-4) and one wrong gradient row (C) |
| ODELIA-53 | keep, shrink | Recording, walks and tolerance factors carry PLANT-95, 99 and 100. Cut the dead `hermite_interpolator.hpp` (286 lines; it duplicates `interpolator.hpp` and breaks a build that includes both). Move the 2.0k lines of `notes/probes` to plant-dev (B) |
| ODELIA-54 | keep | 12 lines that PLANT-103's sweep needs (B) |
| ODELIA-55 | keep | Fold the rename commits into the commits that introduce the names (B) |
| PLANT-93 | keep | Exact counts: a quarter-spacing shift moves J 0.22ε, against 1.45ε with point samples. The loop reads its weights (A) |
| PLANT-95 | keep, shrink | Used: scalar templating, the census gradient, pinned runs, invaders in the recorded field. Cut the `overstorey_staging` demo (391 lines). Later, as its own cut, the 1067-line test-only `gradient_ladder.cpp` compiled into the shipped .so (A) |
| PLANT-97 | keep, as a declared model change | The storage relaxation offset (7 d): explicit steps become stable, and invader throws fall from 759 to 149. J moves +2.0–2.7%. The loop's t_r and grade exist only because of it (A) |
| PLANT-98 | keep (or merge into 97) | It deletes the stage guard: throws 149 → 0 (A) |
| PLANT-99 | keep, shrink | Walking the recorded run cuts the first invasion from 300 s to 139 s. Cut `SCM$runs`, which exists for one test (A) |
| PLANT-100 | keep, shrink | The tolerance factors and their bound save 30.6–33.7% of a gradient run, and the loop sets them. Cut the unused accumulator factor. The newborn's height to roundoff shares PHYLLOPTIM-17's verdict (A) |
| PLANT-101 | keep | It drops a leaf solve nothing read, bit for bit (A) |
| PLANT-102, 103 | keep (103 could merge into 102) | Plain fails the nudge test at 1e-4 (0.52ε); split, nothing moves past ε/6, at +5.4% forward and +7.3% sweep. Not yet measured with splits off on the final configuration (B) |
| PLANT-104 | keep, fix | `control_tf24()` should be the one source of the controls: six of the nine the harness sets by hand equal it. Add the split and make 1e-4 the default (B) |
| PLANT-105 | keep, shrink | Stepping the soil alone makes a gradient run cost 0.63 of the coupled one and cures the stiff-soil blow-up. The rain substeps cost 0.73–0.90 of the rows of stopping at every knot. Fold the renames; refuse a replay given times only (B) |
| PLANT-106 | **drop** | The loop does not use `control_window()`: its weight files predate it, and the loop's first run already carries the record the window needs (C) |
| PLANT-107 | keep | Without it, crowns that cross force a walk of every node (+23% of a forward); the sort costs nothing measurable (C) |
| PLANT-108 | **keep unless a drop test passes** | See below (C) |
| PLANT-109 | **drop** | Subset walks enable thinning rules measured off by 0.74ε and 0.43ε. You decided the full walk stays, and nothing else uses it (C) |
| PLANT-110 | **drop from group 1** | The loop's estimates replace its node-error estimate. About 30 lines survive into group 2: the distance from the grid's run, the invaders' ln(θ′/θ) and failures (C) |
| PLANT-96 | **drop** | Superseded by PLANT-105's substeps; nothing depends on it (A) |
| averaged establishment gate | **drop** | The design says it will not land, and it sits off the chain. The plant-dev submodule pointer still points at it (A) |

Dropping 106, 109, 110, 96 and the gate changes no numbers. Every shrink is an amend in its own
branch followed by `rebase --update-refs`; conflicts are limited to regenerated bindings and
snapshots.

## The spread (PLANT-108)

- **Against:**
  - single runs are less accurate (2.72ε against 0.70ε at 108 uniform introductions);
  - on placed grids that reach ε, lumped and spread agree within 0.084ε;
  - it does not help graded nodes;
  - it costs 2–6% of a sweep;
  - it makes FF16 9–25× worse at FF16's default schedule.
- **For:**
  - it puts the error on the square law, so a coarser run estimates the error honestly: 0.95–0.98
    of it on uniform ladders, against lumped's negative ratios. On placed grids the invader's
    estimate reads 1.06 with the spread against 0.30 lumped;
  - every reference in the bank is an extrapolation on uniform ladders, which is honest only on
    the square law;
  - the loop's 0.82 and 0.33ε were measured with it. The earlier evidence puts lumped's ratio at
    0.30–0.80, at or below 0.82.
- **Drop test (about twice round 5's CPU):** run the five canonical loops on a build without
  PLANT-108. Drop it only if every case's ratio stays at 0.82 or above and the bound still covers
  the true error.

## Two PR groups, after the drops

- **Group 1, plant optimisations:**
  - PHYLLOPTIM-17 (split), 18, 19, then ODELIA-53, 54, 55;
  - PLANT-93, 95, 97 (+98), 99, 100, 101, 102 (+103), 104, 105, 107, and 108 if it stays;
  - one PR per issue, stacked.
- **Group 2, the scheduling algorithm:** one PR on top of group 1.
  - It ports `refine_schedule` from `harness/schedule/refine.R`. The first run's establishment
    rate and T(t) become records of the run.
  - It replaces the C++ `SCM::refine_schedule` and the `run_scm(refine_schedule =)` argument;
    logpile's key changes with it.
  - It carries PLANT-110's surviving 30 lines and calls `control_tf24()` for its controls.

## Also found

- **The phylloptim pin:** plant at PLANT-110 pins phylloptim == 0.9.1, while libS was built with a
  local edit to 0.9.3. The pin belongs in the branch that needs 0.9.3.
- **The model-version snapshot:** stale on PLANT-100 to 104 and fixed in 105. The fix belongs in
  100 and 102.

## A bigger reorganisation: by concern, not by history

The chain is in the order the work happened. Each branch sits on the one before because it was
built there, not because it needs it, and the history carries churn a reviewer must read past:
- names introduced and then renamed (ODELIA-55, PLANT-105, 108);
- references blessed and then blessed again (PLANT-97, 108);
- the spread, now reverted;
- a 1067-line test-only file in the shipped library;
- 23k lines in PLANT-95 alone.

`rebase --update-refs` keeps all of that, and every amend cascades up 16 branches.

Rebuilding by concern instead gives fresh branches cut from `develop`, one per concern, each
squashed to the commits a reviewer needs, and arranged as a graph rather than a chain:

| PR | concern | from | needs |
|---|---|---|---|
| phylloptim 1 | root-finds stop at roundoff; the root curve and a determined collar differentiated | PHYLLOPTIM-17 (without the unmerged 0.9.0 base), 18, 19 | phylloptim's 0.9.0 base |
| odelia 1 | runs at the caller's scalar, recording, walks, per-component tolerance factors | ODELIA-53, without the dead header and probes | — |
| odelia 2 | splits at sign changes, forward and sweep | ODELIA-53's split commits, 54 | odelia 1 |
| odelia 3 | a subsystem stepped alone, with substeps at its forcing's knots | ODELIA-55, renames folded | odelia 1 |
| plant 1 | exact establishment counts | PLANT-93 (plant#94) | — |
| plant 2 | the storage pool (a declared model change: the relaxation offset, no stage guard) | PLANT-97, 98 | plant 1 |
| plant 3 | differentiate a stand and replay it: scalar templating, census gradient, pinned replays, invaders in the recorded field, walks | PLANT-95 (without the demo and the test-only file), 99 | plant 1, odelia 1, phylloptim 1 |
| plant 4 | TF24's step control: tolerance factors and their bound, `control_tf24()` | PLANT-100, 104 | plant 3 |
| plant 5 | the field: no newborn rates in its build, crossed crowns summed tallest first | PLANT-101, 107 | plant 3 |
| plant 6 | splits at net-production sign changes, forward and sweep | PLANT-102, 103 | plant 4, odelia 2 |
| plant 7 | TF24's soil stepped alone, substeps at the rain's knots | PLANT-105, renames folded | plant 4, odelia 3 |
| plant 8 | the scheduling algorithm: `refine_schedule`, replacing the C++ refine | the harness loop, PLANT-110's distance diagnostic | plants 4–7 |

- **Size:** 8 plant PRs instead of 16, and 3 odelia PRs instead of 3 chronological ones.
- **Independence:** each PR is one concern a reviewer can hold in mind. Plants 4, 5 and 7 can
  merge independently once plant 3 lands, and plant 2 is independent of the gradient work.
- **References:** blessed once per PR that moves numbers (plants 1, 2, 5, 6 and 7), not every time
  a later branch touched them.
- **Cost:** each concern is rebuilt against `develop` by hand rather than rebased. That is a day of
  careful work, and its check is cheap: the final tree must be bit-identical to the libNS source,
  `no-spread` minus the agreed cuts, on the full suite and on the five canonical loops.
- **Open:** whether plant 2's model change should go upstream on its own first. It moves J
  2.0–2.7% and sets the loop's t_r, so everything after it is measured with it.
