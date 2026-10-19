# Review: PHYLLOPTIM-18, the leaf differentiated where its forward answers (Tier 2)

Self-review under `.claude/skills/code-review/` of phylloptim `PHYLLOPTIM-18`, three commits
on master d216a17 (0.10.3): 6d9a52b (root curve past its dry end, from archived 6ea53c6),
60d5790 (a determined collar, from archived 29982dc, plus the bound polish), 7699950 (the
bisection budget, from archived 300d229). The bodies were ported in this session, so the Cold
Reader's predictions are a lower bound on misses.

## Verdict: approve with changes (applied below)
## Triage: 2 — derivative rows at two operating points the derivative path refused, and a one-character refusal; no persisted format, no API change

## Ledger
Source: `residual-B.md` §2 and *For maintainers*; the brief.
- R1 the derivative path answers past the root curve's dry end with the rows of what the
  table returns (tangent to G(inf), then G(inf), no row for the floor).
- R2 a determined collar answers with the mean of its bounds' rows; the stem at psi_crit.
- R3 `uniroot` refuses a bisection that spends its budget.
- R4 19's finite-difference test passes on 0.10, whose brackets stop at 1e-4; if not, polish
  both bounds the way #136 polishes a pinned one.
- R5 no forward value moves on the golden grid; version 0.10.4.
- Out: the 0.9.0 base (#136 has it), 6b6f152 (held for its own measurement).

Design doc check: no design doc; residual-B §2 is the spec. Nouns added:
`cumulative_vulnerability_integral_limit_derivatives` (R1). Nothing else is named.

## Clean sheet
Dry end: in `closed_form_integral` pick the derivative bundle by where `at` sits (inside,
tangent, past the cap) and add G(inf)'s partials; in `closed_form_curve` return the table
value with no row past the end. Determined: a `collar_at` case recording the two bounds'
rows at weight 1/2 against the solved collar; `collar_coords_at` placing sigma at psi_crit
with zero collar response; polish both bounds where the interval collapses. Budget: `>` to
`>=`. Gap: the diff adds a refusal for a stem optimum inside its interval (settled by R2:
only psi_crit has rows without a curvature) and a dry-bound fallback after the polish
(finding 2 below).

## Prediction record
- `collar_at` at `Determined`: predicted each bound's row taken at that bound; actual: both
  `bound_at` calls take the residual at the midpoint `opt_root_psi_`, up to GSS_tol_abs/2 =
  5e-4 MPa from either bound. The rows are the theorem's at the midpoint, not at the root.
  Measured cost against a difference of the polished solve: collar row 0.86320 against
  0.86328 (9e-5 relative), profit −0.82908 against −0.82915. Stated in the test's comment;
  kept (Q1).
- Before this review, the collapsed branch's collar was predicted to be the midpoint of the
  bounds' roots; it was the midpoint of two 1e-4 iterates. Fixed (finding 1).
- No other misses — checked 7 (`cumulative_vulnerability_integral_limit_derivatives`, the
  two `closed_form_*` branches, `collar_at`, `collar_coords_at`, the collapsed branch,
  `uniroot`).

## Decisions reopened
- D1: chose to record the bounds' rows against the solved collar
  (`record_with_derivatives`) over summing `0.5*(wet + dry)` as active values. Settled by
  R2: at a root-limit dry bound the closed-form limit's value is the bound, not the midpoint,
  so a sum would change the forward value.
- D2: chose to polish both bounds over leaving them at the bracket's 1e-4. Settled by R4.
  The archived test passed on 0.10 only at its fixture: across the continuity fixture's
  determined band (psi_soil 5.9085–5.9125, 4001 points at 1e-6) the unpolished continuity
  bound sat up to 5.6e-7 MPa from its root, and a difference at h = 1e-6 of the collar
  was off the polished one by up to 0.14. With the fixture moved to the worst point
  (5.911964), the unpolished build fails 7 checks (collar row along root_P50 −1.6e-6, the
  solve's difference 0.014); polished, all pass (difference −1.5e-6).
- D3: chose to refuse a determined point whose stem optimum is inside its interval over
  placing it by its curvature. Settled by R2 and by use: lib19 ran every long-drought record
  at 3e-4 with finite gradients (`loc/prereg.md`, H19-1), so the refusal was never hit.
- D4: chose to read the tangent span's rows as G's at the last knot over differentiating the
  tangent formula. Settled by R1: the tangent's slope is f at the knot, so the knot's own
  motion cancels; `test_root_rows_past_the_dry_end_match_the_table` checks it against the
  table's central difference at three points.
- D5: chose `>=` over keeping `>` and documenting it. Settled by R3; `uniroot_smooth`
  already uses `>=`.

## Change simulation
- 6b6f152 lands (every root-find at roundoff): `polish_bracket_bound` is deleted, so its
  callers go with it. Edit sites: the pin path (upstream's), the wet-pin and replay sites,
  and the collapsed branch here. A grep for the name finds all four → one-place.
- A second table read past its end (the stem curve, if a consumer drives it past P99):
  `closed_form_curve`'s branch already keys on `vulnerability_psi_max`, the same for both
  curves → one-place.

## What must always be true
At a determined point the rows are the derivative of the collar the forward returned, and the
dry bound the rows differentiate is the one the forward used. Kept true by: structure for the
selector (`dry_bound_is_root_limit_` is written where the forward decides and read by
`collar_at`); the value by structure (the record carries `opt_root_psi_` itself); the rows'
agreement with the forward by test (`test_a_determined_collar_moves_with_its_bounds`).

## Structural findings (applied)
1. The determined collar was the midpoint of two 1e-4 iterates while its rows differentiate
   the roots — makes any difference-based check of the rows (plant's tests, a curvature by
   second differences) read the root-find's iterates instead of the model, because the
   iterates move with the inputs in steps. Applied: both bounds polished in the collapsed
   branch; free on every other path. The test's continuity fixture moved to where the
   unpolished bound is furthest off, so the test now guards the polish.
2. The polished continuity root can pass the root's own limit, and the rows would then
   differentiate a bound the forward did not use — the pin path already guards this.
   Applied: the polished root is capped at the root limit and the selector set from the
   same comparison the bracket uses (`!(dry < supply_psi_crit())`).

## Minor findings (applied)
- The archived test comment said "the solve stops at roundoff"; on 0.10 it does not. Now
  "both bounds are polished".
- With the bounds polished, a stem conductance of 1e-30 solves as a determined point
  instead of refusing as `stem_curve_domain`, so `test_infeasible_is_a_distinct_failure`
  lost its infeasible fixture. It now starves the continuity root-find of its budget
  (`ci_niter = 3`, token `collar_bracket`), as archived 6b6f152 did.
- `derivative-surface.Rmd` listed `determined` as refused and "not yet tested". Its table,
  warning and test list now say what collar_at does.
- The header map at the top of `leaf_model.hpp` listed `Determined` as refused. Updated.
- Comment rules checked on every added line: no process history, no banned words, each
  comment two lines or fewer except the ⚠️ hazard above `collar_coords_at`'s refusal (a
  silent wrong row, four lines).

## Questions with defaults
- Q1: why take both bound rows at the midpoint instead of at each bound? Taking them at the
  bounds needs two more supply draws on the determined path. Default if unanswered: keep
  the midpoint; the error is ≤ 1e-4 relative and bounded by GSS_tol_abs.
- Q2: a polish can invert the collapsed interval by ~1e-7 (wet past dry). The midpoint is
  still defined and the rows still the mean. Default: leave it; no fixture reaches it.
