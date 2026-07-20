# Triage — fresh Oracle's response to the correction

> Reduces each claim to its cheapest falsifiable test, cheapest first, marking
> offline/free vs build. Response verbatim in
> `oracle-consultation-correction-response-fresh.md`. 2026-07-20.

## The frame shift (accepted)

The Oracle accepts the addendum's relocation: the time-stepper is at its floor
*for the norm it is given*; the ceiling is now three things, each with a live
pathway:
1. **the norm** controls the wrong thing (accuracy `J` doesn't need),
2. **the architecture** charges `O(M)` for every global stepping decision,
3. **the measure** was never converged (6× under production, 2.3% even refined).

## The one structural unlock: zero-weight "ghost" members

The load-bearing idea under items 1/2/3/6. Because members interact *only*
through the aggregates `a` and `s`, a member carried with **zero contribution
to both sums** (own state, own `ρ`-law, own `p*`, excluded from `a`,`s`) is an
**exact passive probe** of "what a member inserted at `τ_ins` would do," up to
its own self-feedback — which is `O(its mass fraction)` and **vanishes exactly
at the `ρ→0` crossing** where we most need it (the §2c 1532× spike is a
marginal member by definition). Given one saved `(u,s)(t)`, a ghost costs
`~1/M` of a solve, is embarrassingly parallel, takes its own tiny steps. This
turns the lineage axis from "re-run the whole forward" (the >15-min refiner)
into "replay cheap probes against frozen fields."

## The six items → tests, cheapest first

| # | claim | cheapest test | cost | status |
|---|---|---|---|---|
| 4-tail | `J` bit-stable across 100× tol band; production at loose edge | J@1e-4 vs 1e-6 on one mesh | 2 runs | **DONE — inconclusive** (61% apart, but confounded by unconverged mesh; must redo on a converged measure — `tf24-richardson-result.md`) |
| 2 (free) | smooth part of the measure error has a stable convergence order → certified `J` by Richardson | J on a nested schedule family {47,93,185}, fit order+extrapolate | 3 runs, offline | **DONE — struck** (fixed densification non-asymptotic, p≈0.2, negative extrapolant; uniform refinement does not converge the measure — placement does. The free-Richardson route fails; goal-oriented/ghost placement is promoted to *the* route) |
| 2b join | are `rmax`-attaining members low-`ρ`/far-from-threshold (harmless to downweight) or near-threshold (redistribute tol)? gates the norm lever | join `rmax` index log ↔ per-member `ρ_j`, dist-to-removal, adjoint `|λ_j|` | needs a synchronized `ρ`/margin log per attempt (small instrument) + reverse tape for `|λ_j|` | **DONE (first cut)** |
| 1 | ghost = exact passive probe | insert same candidate as ghost vs real; compare `g(τ_ins)` + crossing location | one solve + replays | **build (ghost capability)** |
| 5 | windowed waveform relaxation converges (Picard/Anderson on `a(t)`, 5+1 functions) — removes global max-norm, `O(M)`-per-decision, and the plateau | perturb `a(t)` by δ on saved fields, one member sweep, measure contraction per window | one sweep on saved fields | **build (ghost/replay + WR harness)** |
| 3 | certify the crossing instead of resolving it | ghost bisection in `τ_ins` | O(1/M)/probe | **build (needs ghost)** |
| 6 | Newton-on-`g` (branch-death), setup cache, salvage, batching | (already characterised; Newton-on-`g` is model-side per plant#60) | — | model-side / deferred |

## Reading

- **Rungs runnable now (offline/cheap):** the tol-band check and Richardson.
  Both attack claim 2/4 and need no new instrument. Running.
- **The 2b norm-weight join** is the next-cheapest and the gate on the *only*
  accepted-step lever inside the current architecture (the `J`-weighted norm).
  It needs a small synchronized log (per rejected attempt: the `rmax` member's
  `ρ_j` and distance-to-removal). The adjoint `|λ_j|` refinement needs the
  reverse tape. This is a modest, bit-identical-off instrument in the family we
  already built (`step_argmax`, `step_monitor`).
- **The ghost-member capability is the high-value build** — it is the shared
  substrate for items 1, 3, 5 and turns three "heavy run" items into cheap
  replays. But it is a genuine new capability (carry a member excluded from
  `a`/`s`, integrate it against saved `(u,s)(t)`), so it is a deliberate build,
  gated on the ghost-vs-real validation (item 1) passing first.
- **WR (item 5)** is the architectural swing — potentially removes the global
  max-norm, the `O(M)`-per-decision, and the decomposition plateau at once. Its
  kill-or-fund test (contraction factor of one sweep on saved fields) is cheap
  *once the ghost/replay substrate exists*. Highest upside, gated on the
  substrate + the loop-gain measurement (the held-`a` plateau warns Picard may
  be marginal → Anderson + windowing).
- **Newton-on-`g` (item 6)** is reaffirmed as the top per-eval lever and the
  supplier of analytic `∂p*/∂state` to both the WR sweeps and the adjoint — but
  it is model-owner territory (plant#60), so it stays logged there, not built
  here.

## Order of operations (proposed)

1. **Now:** tol-band + Richardson (running). Decides whether `J` is certifiable
   from cheap data and whether the smooth measure error is asymptotic.
2. **Next (small build):** the 2b norm-weight join instrument → run the norm gate.
   This is the cheapest lever that could cut accepted steps and stays inside
   the current architecture.
3. **Then (validation-gated build):** the ghost-member probe + the ghost-vs-real
   validation (item 1). If it passes, it unlocks certified crossings (item 3),
   goal-oriented placement (item 2), and the WR contraction test (item 5) — all
   cheaply. If it fails (frozen-field error too large away from crossings), the
   architecture stone narrows to WR-with-real-sweeps and the placement work
   falls back to the refiner.
4. **Model-side, logged not built:** Newton-on-`g` (plant#60); multi-block
   NaN-guard/growth-clip (still standing).
