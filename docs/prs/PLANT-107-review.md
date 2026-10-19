## Verdict: approve with changes (changes applied on the branch)
## Triage: 2 — a change of summation order in one reduction on one coordinate; no format, interface or model change.

Reviewed: PLANT-107 ported onto `PLANT-93` (77e15141) from the archived 1f31d75d, which sat on the
old stack. Predictions were written after the port, so the Cold Reader is weakened: its misses
are a lower bound.

## Ledger
- R1 (residual-A.md item PLANT-107; grid-dynamics.md §16): on the birth-date coordinate, once two
  cohorts cross in height, the field build stops walking every node at every knot.
- R2 (brief): results where nothing crosses are unchanged, bit for bit.
- R3 (brief): smallest change; nothing ported from the spread (PLANT-108, dropped); the test lands
  with the change.
- R4 (AGENTS.md): no parallel near-copy of an existing path.

## Clean sheet
When the scan reports a crossing on the birth-date coordinate, take the prefix over the nodes in
height order instead of list order; the merge against the ascending knot heights is unchanged.
Reuse the existing tallest-first ordering. No new names. — Gap: none. The archived diff had its
own `stable_sort` over active heights; the port uses `ascending_by_abscissa()`, which already
returns tallest first on passive positions (D1).

## Prediction record
- `ascending_by_abscissa()` (now two callers): predicted "indices in ascending −height, ties in
  any order"; actual: the same. Its declaration said it served only the height path's quadrature
  grid; **fixed**, it names both uses.
- `field_splits_nodes` birth-date branch: predicted "the prefix is over list order"; actual (after
  the change): list order while the scan certifies decreasing heights, `order` otherwise. The
  comment above the prefix says so.
- No other misses — checked 3 (the two above and the gate of the walk fallback).

## Decisions reopened
- D1: chose `ascending_by_abscissa()` over a new `stable_sort` on the nodes' heights (the archived
  form). Settled by R4: the function exists, sorts on passive positions (no comparison of active
  scalars), and is what the height path's walk already uses on a crossed grid. Ties: two nodes of
  equal passive height are both in or both out of every prefix, so their order changes only the
  association of an exact sum of two terms; `std::sort` is deterministic for a given input.
- D2: chose an empty `order` meaning list order, sorting only when the scan reports a crossing,
  over always building and using a permutation. Settled by R2: on a decreasing list the loop is
  the old loop index for index, so every number is bit-identical where nothing crosses; it is also
  the convention `reduce_competition` already uses for its `order`.
- D3: chose sorting per build over keeping the node list sorted (or caching the order with the
  height scan). Settled by R3: the sort is O(n log n) on doubles against O(n) crown evaluations per
  build, measured indistinguishable (§16: 0.114 against 0.113–0.117 ms per row; and here, see the
  case). A cached order would need every height-changing path to invalidate it, which the scan's
  cache already warns is easy to get wrong.
- D4: chose an exact sort over a height tolerance on the decreasing check. Settled by §16: a 1 cm
  tolerance repeated the sort's `J` only on the records tried, and needs a number to choose; the
  sort is exact on any record.
- D5: chose to leave the height coordinate's crossed build on the walk. Settled by the model: its
  trapezium pairs neighbouring nodes, so a crossing changes the quadrature grid itself; it is
  outside R1.

## Change simulation
- Differentiating through a crossed build (an active `T`): the order is formed from passive
  positions and indexes the active `w`, `scale`, `mom`; the reach loop compares heights as before.
  Edit sites: none → one-place.
- A second consumer of the tallest-first order (e.g. the census on the height coordinate, which
  refuses a crossed grid): calls `ascending_by_abscissa()` → one-place.

## What must always be true
On the birth-date coordinate `prefix[reach]` holds exactly the nodes whose height reaches the knot
(retired nodes, which carry exact zeros, aside). Kept by: structure — the prefix is built in an
order the scan certifies or that is sorted, and the reach index only falls as the knots ascend.

## Structural findings
None open.

## Minor findings (applied)
1. `ascending_by_abscissa()`'s declaration named only the height path: makes the next reader of the
   birth-date branch think it borrowed a quadrature-grid helper by accident. Rewritten to name both.
2. The archived test swapped the second and third cohorts. In the test stand those two are 26 µm
   apart at 4.413 m and no knot lies between them, so a prefix taken in list order would have
   passed it: the test could not fail. The ported test swaps the tallest cohort (4.413 m) with the
   shortest (0.590 m); 56 of the 65 knots lie between them, and at each a list-order prefix counts
   crowns below the knot.
3. AGENTS.md comment rules checked on every touched line: no process history, no banners, no
   metaphor words added (the existing `frozen` lambda is code and untouched in meaning).

## Questions with defaults
None.
