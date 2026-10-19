# PLANT-107: crossed crowns summed tallest first in the birth-date field build

Branch `PLANT-107` on aornugent/plant at e32afae5, one commit on `PLANT-93` (77e15141, exact
counts). It ports the archived 1f31d75d. Nothing comes from the spread (PLANT-108, dropped).
Review notes: `docs/prs/PLANT-107-review.md`. Scripts and logs: `docs/prs/PLANT-107/`.

It stacks on PLANT-93 because it sorts PLANT-93's per-node weights. Develop's birth-date build is
a trapezium that pairs neighbouring nodes, and a trapezium cannot be sorted (residual-A.md,
PLANT-107). The sort only does work once crowns cross, and on these records they cross only with
PLANT-97's storage pool (below). So merge it after PLANT-93, and expect a gain only once PLANT-97
is in too.

## PR body (plant's template: why, then what changed; becomes the squash message)

On the birth-date coordinate the light field at a height sums every cohort that reaches it. A
crown adds an exact zero below its own height, so the build reads a prefix of the cohorts taken
tallest first. That order is the node list's order until two cohorts cross in height. TF24's
reserve-gated growth lets two cohorts born days apart do that. From then on, the build fell back
to walking every node at every knot of the light field, for the rest of the run.

The build now sorts the nodes by height when they are out of order. It uses the order the
height-coordinate walk already uses on a crossed grid, `ascending_by_abscissa()`, and takes the
same prefix. Only the order of summation changes, and only in builds where crowns cross. A run
in which no crowns cross gives bit-identical results, and no reference moves.

Closes #107

## First comment (measurements, cost, review notes)

### The problem, in the model's terms
A cohort's crown casts shade only above the ground and below its top, so the field at height z
sums the cohorts taller than z. With heights falling down the node list, that is one prefix sum
per build, merged against the ascending knots. When two cohorts born close together swap heights,
the build used to give up the prefix and evaluate every crown at all 65 knots.

### The mechanism
- `field_splits_nodes`, birth-date branch only. If the height scan reports the list out of order,
  `order = ascending_by_abscissa()` (passive positions, tallest first). Otherwise `order` is empty,
  meaning list order, which is `reduce_competition`'s convention.
- The prefix and the reach merge index through `order`. Each node's term is unchanged, and the sum
  is associated in height order.
- The height coordinate still walks when crowns cross, because its trapezium's grid is the node
  order itself.

### Measured gain
All runs use the long-drought or long-wet harness stand (`harness/long_drought.R`: TF24, lma 0.32,
birth date, rain knots as stops), 40 years, `ode_tol` 1e-4, on an `-O2` build. They ran one at a
time, interleaved, on a machine three agents share.

| question | result | source |
|---|---|---|
| Do crowns cross on PLANT-93 alone? | **No.** Long drought, 108 and 429 uniform introductions: J and steps bit-identical with and without the sort (12.430811505939051, 12 729 steps; 12.410765613265177, 13 338 steps), so no build crossed. Long-wet at 429: 0 of 3 378 leg ends out of order. | `forward.log`, `census.log` |
| Do they cross with PLANT-97's storage pool? | **Yes**, at 82% of leg ends (2 747 of 3 358), from t = 6.9 to 40, up to 5 pairs per build, by at most 1.03 mm (develop + PLANT-97, long drought, 429). | `census.log` |
| The forward on PLANT-93 + PLANT-97, long drought, 429, with and without the sort | CPU 290.9 / 298.9 s without, 272.4 / 280.7 s with: **−6.2%** (pairs −6.4%, −6.1%). Same 12 017 steps. J moves by 3.4e-12 relative (12.746534371612489 → 12.746534371656043). | `forward2.log` |

- *Noise.* Identical code paths read −4.5% and +6.3% apart on this machine (`forward.log`). Runs of
  the same arm differ by 3% (`forward2.log`). The −6.2% held in both interleaved pairs, but it is
  of the same size as the noise.
- *Against the earlier record.* grid-dynamics.md §16 put the walk at +23% of a forward, and the
  crossings at 20% (long-wet) to 79% (long drought) of builds from 429 introductions. Those runs
  had the spread on (`pathfinders/node-axis/order_all.log`: `wet_D_u429_o0`, `ld_D_u429`).
  - The crossing share holds without the spread, given the storage pool: 82% here against 79%
    there. The crossings come from the reserves, not the spread.
  - The cost of the walk does not hold: about 6% here against 23% there. The spread made each
    crown's evaluation per knot dearer.
- *The scratch base.* PLANT-93 + PLANT-97 is a local merge of 77e15141 and b23b2d67. It conflicted
  only in NEWS.md, RcppR6.R's hash line and the gradient reference TSV. It was not pushed.
- ε = 0.025 in ln J (OBJECTIVES). The sort moves ln J by 3.4e-12, about 1e-10 ε.

### What it costs
- Runtime: none where nothing crosses, since the build runs the old loop index for index. Where
  crowns cross, the sort takes O(n log n) on doubles once per build, which is included in the
  −6.2%. §16 measured it at 0.114 ms per row against 0.113–0.117 ms.
- Lines: species.h +20/−13 (the branch, its gate, two comments); test-canopy-methods.R +32.
- References moved: none. Interface: none.

### How it is tested
- New test, `test-canopy-methods.R` "on the birth-date coordinate the field takes crossed crowns
  tallest first":
  - a 2-year TF24 birth-date stand with the tallest (4.413 m) and the shortest (0.590 m) cohort's
    heights swapped;
  - the field at every knot equals Beer's law of the walk (`compute_competition_and_slope`) to 1e-14,
    value and slope.
  - 56 of 65 knots lie between the swapped heights, so a prefix taken in list order would fail.
  - The archived test swapped cohorts 2 and 3, which are 26 µm apart with no knot between them, so
    it could not fail.
- Full serial sweep on the `-O2` install of e32afae5: 92 files, 5 448 expectations, 0 failed, 0
  errors. The `skip_on_cran` files were rerun with `NOT_CRAN=true` (model-version 23,
  pm-leaf-demo 17, stand-gradient-hyperpar 10): all pass. Still skipped: the macOS-only default
  baseline, the opt-in scenario gateway, and two plot tests whose packages (ggridges, patchwork)
  are not installed.
- Bit-identity where nothing crosses: the FF16 birth-date references (test-strategy-ff16,
  test-canopy-methods) pass unchanged. The long-drought forwards above are bit-identical.

### What a reviewer should check
1. The gate `(!scan.decreasing && !birth_date) || n_moments == 0`: on the birth-date coordinate a
   crossed list now takes the prefix. The walk remains for the height coordinate and for profiles
   that are not polynomial in w.
2. With `order` empty the prefix loop is the old loop, so `o == i`, and nothing changes where the
   heights fall.
3. Retired cohorts with the top layer on: they are sorted by their fixed height with the rest, and
   they carry density zero, so their terms in the prefix are exact zeros wherever they sit. The
   reach merge still passes over them.
4. A question for the maintainers: on PLANT-93 alone no realistic run crosses, so this path runs
   only in the test until PLANT-97 lands. Should it wait for PLANT-97? The review's default is no,
   because the code needs PLANT-93 and not PLANT-97.
