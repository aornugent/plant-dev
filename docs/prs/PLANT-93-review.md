## Verdict: approve with changes (changes applied on the branch)
## Triage: 2 — a numerical-method change on one coordinate, with one public field removed and two node states renamed; not a wire format or module boundary.

Reviewed: PLANT-93 re-ported onto `develop` at bd09645d (the archived bae2dd9a sat on 95256cf3, ten upstream merges back). Predictions below were written after the port, so the Cold Reader is weakened: its misses are a lower bound.

## Ledger
- R1 (PR #94): on the birth-date coordinate every integral over birth date weights each cohort by the establishment probability integrated against its hat function, so offspring production stops depending on where the introductions fall. Measured target: a quarter-spacing shift moves J by well under ε/3 (OBJECTIVES, *Reproducible*).
- R2 (PR #94): the height coordinate is unchanged.
- R3 (reconstructed, from upstream since 95256cf3): every reduction upstream added over birth date follows the same weights: the field split and its prefix build (#648/#649), the census and its state adjoint (#648), the FF16 fitness and its birth-rate column (#658), the top layer and its retirement (#661, #676), the arrival window (#661), the snapshots (#661), the held-field invader (#661).
- R4 (brief): smallest change; no dead code, no renames-then-renames, no test-only code in the .so; tests in the same PR; references re-blessed with a reason.

## Clean sheet
Two node states, the interval's establishment and its first moment, grown only on the newest node at the boundary node's `pr_estab`; the density stops being a state (birth rate at the birth date times survival); one function turns the interval states into per-node weights; every birth-date reduction takes them. New names: `interval_establishment`, `interval_establishment_moment`, `interval_shares`, `establishment_weights`. — Gap: the diff also needs `Individual::birth_rate_at`, a retire that writes the hazard, a newborn retired on an infinite hazard rate, and a NaN for a one-cohort window. Each is settled below.

## Prediction record
- `Node::retire()`: predicted "density to zero, nothing else"; actual: the hazard is overwritten (to `establishment_failure_hazard`, plus `log b` when `b > 1`), because the density is derived from it. A retired cohort now reports a hazard of at least 750 instead of its hazard at absorption. Kept, and the comment says so: the density is derived, so the hazard is the only state that can carry "retired"; nothing reads a retired cohort's hazard after `absorb_tall` has taken its survival.
- `Species::establishment_weights(first, last)`: predicted "nodes first..last"; actual: `last == size()` means the boundary node. Documented at the declaration; the alternative (a second function) duplicates the loop.
- `Patch::establishment_weighted(w, f, first)`: predicted Σ w f with matching lengths; actual (first draft) stopped at the shorter vector, so a weight vector one too long or too short summed quietly. **Fixed**: the caller drops the boundary weight, and the loop indexes `f.at()`.
- `Node::compute_initial_conditions(env, pr, birth_rate)`: the birth-date density at birth reads the argument, and a load reads the strategy's rate at the birth date; the two are equal in every caller (the patch passes `birth_rate_at(time)` at the same instant). Noted, not changed.

## Decisions reopened
- D1: chose the density derived from the hazard (not a state) over keeping `log_density` as a state beside the two new ones. Settled by AGENTS' "no storing what can be derived": develop integrates the same mortality rate twice on this coordinate, and the two copies drift apart by the ODE error. X makes `density = b·exp(-mortality)` true by construction, at one state fewer.
- D2: chose deriving the birth rate from the strategy on every load over storing it on the node. Settled by R3 (#658): FF16's constant birth rate is an active gradient column, and an active value kept on a node is released between recordings, so a stored copy would drop the density's birth-rate channel with every number finite.
- D3: chose retiring through the hazard over a retired flag. Settled by #661's invariant that retirement is read off the density, so a loaded state carries it with no record of which cohorts went.
- D4: chose NaN for a one-cohort arrival window over a hat-averaged establishment fraction. UNSETTLED → Q1.
- D5: chose to retire a newborn whose hazard rate is infinite over integrating it. Settled by R3: with the hazard starting at zero, FF16 at `r_l = 1e6` (test-run-to "a statistic that is undefined...") reaches an infinite rate, a stage turns it into an infinite density, and the run stops at the minimum step. Survival is exactly zero from birth at an infinite rate, so this is the exact solution, and develop parks the same cohort the same way (at `pr_estab = 0`).

## Change simulation
- Differentiating the top layer (#661 refuses it today) → edit sites: `Species::absorb_tall` (weights are already formed by `establishment_weights`, active), the transpose the refusal names → one-place for the weights.
- A new census-like reduction over birth date → `Species::establishment_weighted_sum` → one-place. The snapshot (scm.h) and the fitness sum (patch.h) each keep their own short loop over the same weights, because one excludes the boundary node and the other takes a span; three loops over one weight vector is leaky but each is four lines.

## What must always be true
On the birth-date coordinate a node's density is `b(t_k)·exp(-mortality_k)` and its weight is formed from the interval states of the two intervals beside it, and nothing else reads `pr_estab` at a node. Kept by: structure (`set_ode_state`, `set_birth_state` and `retire` all go through `set_birth_date_density`; all weights come from `Species::interval_shares`).

## Structural findings
None open.

## Minor findings (applied)
1. `Patch::establishment_weighted` truncated silently (above): makes the next caller with a mis-sized weight vector harder to debug, because the sum is finite and short. Fixed by `pop_back` at the caller and `f.at()`.
2. `absorb_tall` read weights through the R accessor `r_establishment_weights`: makes the R accessor a C++ dependency. Now `establishment_weights(0, size())` with `to_passive`.
3. `refine_schedule()`'s new refusal sat before the top layer's, which made the latter unreachable (the top layer needs this coordinate). Moved after it.

## Questions with defaults
Q1: why NaN for a fitness window holding one cohort on this coordinate, where develop returns that cohort's output? Default if unanswered: NaN stays. No interval of the window integrates establishment, the docs already require a cohort at each end of a window, and the non-window integral is NaN below two cohorts for the same reason.
