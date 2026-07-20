# Test 2 result — the error norm is an extreme value over a growing member block

> Item D, both Oracles: the ~30 % rejection and the ~M^0.4 eval-count scaling
> may be extreme-value statistics of the max-norm over a growing block — "does
> the component achieving rmax churn step-to-step?" was the one-query test.
> Built the odelia norm-argmax log (`step_argmax_*`, bit-identical off,
> verified `rel_diff=0`), captured across the bank. Scripts:
> `scripts/tf24-benchmarks/argmax_churn.R`; instrument: odelia
> `ode_control.hpp` + `step_diag.{hpp,cpp}` (branch `claude/tf24-multirate-engine`,
> commit 8133918). 2026-07-20.

## What the log records

Per step *attempt*: the index `i` of the state component that set `rmax` in
the adaptive error norm, the `rmax` value, the state dimension, and
accept/reject. State layout is `[members | soil]`, so soil = the last
`env_size = 9` indices; everything below that is a member (cohort) state.

## Result (5 single-species bank scenarios)

| scenario | rej % | max dim | churn (rej) | distinct rmax comps (rej) | norm. entropy (rej) | soil % of rejects |
|---|---|---|---|---|---|---|
| extended_drought | 29.7 | 833 | 0.27 | 204 | 0.83 | 30.5 |
| dry_to_wet | 31.0 | 817 | 0.23 | 202 | 0.77 | 33.8 |
| intense_storms | 30.2 | 793 | 0.28 | 192 | 0.79 | 24.3 |
| long_horizon | 27.0 | 993 | 0.28 | 345 | 0.82 | 33.7 |
| whiplash | 28.5 | 809 | 0.27 | 213 | 0.79 | 55.2 |

Three facts, consistent across all scenarios:

1. **The rmax-setting component is spread across hundreds of components.**
   192–345 distinct components set `rmax` among the rejected attempts, out of
   a max dimension of ~800–1000 — i.e. roughly a quarter to a third of the
   whole (growing) state vector takes a turn limiting the step. Normalised
   entropy 0.77–0.83 (1 = uniform) confirms the attribution is broad, not
   concentrated on one stiff mode.

2. **Members, not soil, predominantly set the norm.** In 4 of 5 scenarios the
   soil block sets `rmax` on only 24–34 % of rejects; the majority are set by
   *member* (cohort) states. (whiplash is the exception at 55 % — a
   soil-dominated hard sequence.) So the step-limiting error lives mostly in
   the large member block, exactly where an extreme-value-of-many-components
   effect would put it.

3. **Moderate consecutive churn (0.23–0.28), not white noise.** The argmax
   changes on ~1 in 4 consecutive rejected attempts — so a marginal component
   persists for a few steps, then the identity drifts as the population
   evolves. Enough persistence that it is not memoryless, but diffuse enough
   that a serial (PI) predictor has almost nothing to lock onto — which is
   precisely why the PI controller measured **worse** (+13–29 % work): there
   is no serial structure to exploit.

## Verdict

**Item D's diagnosis is confirmed.** The ~30 % rejection and the M^0.4
eval-count growth share one mechanism: the error norm is the maximum over a
large, growing block of member components, and the maximiser drifts through
hundreds of them. This is the same object both Oracles named (extreme value
of a max-norm), and it explains the three otherwise-loose facts together —
the τ-invariance, the no-event-co-location (from the classifier gate), and
the PI failure.

**Consequence for the lever.** Both Oracles proposed the same and only
remaining lever that could cut *accepted* steps: replace the max-norm's flat
per-component weighting with a **goal-oriented / J-relevance weighting**
(floor member components by `ρ_j` or by adjoint weight), so near-zero-weight
members stop setting the global step — with full weight retained for anything
inside the survival guard band (at-risk members can be future-heavy). This
test establishes the *precondition* for that lever (members do set the norm,
broadly) but not its *safety*: it does not yet say whether the rmax-setting
members are **marginal** (low ρ, J-irrelevant → down-weighting is free) or
**heavy/at-risk** (high ρ or near-threshold → down-weighting would corrupt
J). That is the next measurement — cross-reference each rmax member's index
with its `ρ` / distance-to-survival-threshold — and it is the gate on whether
the J-weighted norm is worth building. It is a bigger step than this log
(needs the member weight/threshold exported alongside the argmax) and edges
toward the functional/model side, so it should be a deliberate, separately
scoped build, not a drive-by.

**Net:** speed via a J-weighted norm remains the single live forward lever
after all others were retired — but it is now gated on one more cheap-ish
measurement (marginal vs heavy) before any code, per the test-before-build
discipline.
