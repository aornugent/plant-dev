# The residual after the three landings: what lands, what waits, what goes

Sources: `residual-A.md` (gradients, replay, step control) and `residual-B.md` (splits,
phylloptim, scheduling), each read against the refreshed upstream: plant develop bd09645d,
odelia master 1e0f0f0, phylloptim 0.10.x. Already pushed: PLANT-93, PLANT-97, and ODELIA-55 with
PLANT-105.

## Land

| PR | what | the case, in one line | size |
|---|---|---|---|
| plant A + odelia A0 | TF24's offspring production and an invader's fitness differentiable, correctly | Upstream evaluates a TF24 invader at the resident's leaf operating points, so the fitness it reports is not the invader's; an identical invader under a 50% harvest reads ln J′ − ln J = +0.69, because harvests and extremes are silently skipped in an invasion | ~70 header lines + tests; odelia A0 ~30 lines (an invasion stores its own operating points) |
| phylloptim | the root curve differentiated past its dry end; a determined collar differentiated; a bisection that spends its budget refused | Upstream has neither derivative; without them a long-drought gradient is refused at 1e-4, and one gradient row reads 0.053 where it is −0.83 | PHYLLOPTIM-18, 19 + one commit of 17 |
| plant C (on PLANT-93) | crossed crowns summed tallest first | Without it, crowns that cross force a walk of every node, +23% of a forward; it needs exact counts because upstream's trapezium cannot be sorted | PLANT-107, ~60 lines |

## Wait for one measurement each

| piece | what would settle it | land if |
|---|---|---|
| plant B + odelia B0: per-state tolerance factors, their bound, `control_tf24()` | M1: a gradient run with and without the factors on the landed PLANT-105, against a converged reference | it still saves ≥ 15% at under ε/3 drift; the 31–34% was measured with coupled soil, the GSL rule and 3e-5 |
| PLANT-99: walk a recorded run without repeating it | M3: re-time the first invasion on the refreshed base | the 300 → 139 s saving survives |
| splits (PLANT-102/103 and odelia's split commits) | 18 gradient runs (five canonical cases + dry-lma125; splits off at 1e-4 and 1.05e-4, on at 1.05e-4) + 24 forwards for lma's curvature, about 2 CPU-hours, no build | anything outside the hydraulic direction moves more than ε/3 under the nudge without them, or the curvature spread exceeds ε/3 |
| roots to roundoff (PHYLLOPTIM-17's core) | a 17-replay noise probe on phylloptim 0.10 | the replay noise matters to something other than finite-difference tests (likely drop) |
| the scheduling algorithm (refine_schedule + PLANT-110's distance) | report Q − e; fix or flag the tolerance allowance dry-lma125 breaks; one head-to-head against develop's refiner on one base; decide FF16, K93 and the height coordinate | last, on top of everything above it needs |

## Drop

- **Upstream has it:**
  - PLANT-95's scalar templating, census gradient and sweep referees (upstream #648, #657);
  - its replay-by-times test, step reporting, event introductions and pinned-rows refactor;
  - ODELIA-53's caller's scalar, Hermite, recording and walks (odelia #59–#76), and its step
    records (`n_rejections`);
  - phylloptim's 0.9.0 base (#136).
- **No gain at ε:**
  - the newborn's height to roundoff (2.7e-8 in ln J);
  - PLANT-101 without splits (under 1%; fold it into the split PR if the splits land).
- **Unused:**
  - PLANT-106, `control_window()`;
  - PLANT-109, invader subset walks;
  - PLANT-96;
  - the averaged establishment gate;
  - the spread (PLANT-108; your decision).

## Order

PLANT-97 must land before plant A: without it, upstream's invader pools overshoot beyond about
×1.0001 of the resident. phylloptim's PR stands alone. Plant C needs PLANT-93. The scheduling
algorithm goes last.
