# Rung 2b result — what weight does the error-norm-limiting member carry?

> The norm-weight join: for each accepted step, the monitor now records the
> weight `ρ` and the species-weight-fraction of the member that attained `rmax`
> (the adaptive error-norm maximiser). Question: is the error-limiting member
> J-relevant (dominant → must keep full weight, no gain from a J-weighted norm)
> or marginal (low fraction → down-weighting lets the step grow)? Instrument:
> odelia `step_argmax`/`step_monitor` + plant `Patch::step_monitor` (bit-
> identical off). Script: `scripts/tf24-benchmarks/argmax_weight_join.R`.
> 2026-07-20.

## Result (accepted steps)

| sequence | n_acc | attainer is a member | median weight-frac | <1% wt | <10% wt | >50% wt (dominant) |
|---|---|---|---|---|---|---|
| bursty | 6253 | 68.6 % | 0.012 | 39.2 % | 68.8 % | 18.4 % |
| ramp | 6771 | 72.5 % | 0.107 | 26.1 % | 49.9 % | 20.7 % |
| long-low-interval | 10670 | 73.9 % | 0.020 | 32.6 % | 60.8 % | 13.6 % |

(weight-fraction = the attaining member's `ρ` as a fraction of its species'
total `ρ`; the remaining ~30 % of accepted steps are limited by a *reservoir*
component, not a member.)

## Reading — mixed, leaning "room exists," but a guard band is mandatory

- **The error norm is frequently set by low-weight members.** On 50–69 % of the
  member-limited steps the attainer carries **< 10 %** of its species' weight,
  and on 26–39 % it carries **< 1 %**. So a J-relevance-weighted norm has real
  room: down-weighting these low-`ρ` components would let the global step grow
  without touching accuracy `J` cares about.
- **But it is not clean.** On **14–21 %** of steps the attainer is a *dominant*
  member (> 50 % of species weight) — J-relevant, must keep full weight. And
  ~30 % of accepted steps are limited by the *reservoir* block, which a member-
  weighted norm cannot touch at all. So the norm lever's ceiling is bounded: it
  acts only on the member-limited (~70 %) steps, and within those only on the
  marginal ones.
- **The critical unresolved split.** Weight-fraction measures J-*relevance*, not
  distance-to-removal. A low-fraction attainer is either a small *stable* member
  (harmless to down-weight) or a member near the `ρ → 0` absorbing boundary (a
  survival bit — its error is exactly what `J` needs controlled, must keep full
  weight). This first cut cannot separate them, so the "< 10 % → reclaimable"
  figure is an **upper bound** on the opportunity.

## Verdict → the Oracle's "mixed" branch

This lands squarely on the Oracle's third outcome: **a J-relevance-weighted
norm with a full-weight survival guard band**, not a blanket loosening. The
data say:
- there is genuine room (majority of member-limited steps are set by <10 %-weight
  components), so the lever is worth prototyping;
- it must protect the dominant members (14–21 %) and the near-removal members
  (an unknown slice of the <1 % bucket) — a guard band, not a global down-weight;
- its ceiling is bounded by the ~30 % reservoir-limited steps it cannot help.

## Next measurement (firms up the win size)

Add **distance-to-removal** (and, when the reverse tape is run, the adjoint
weight `|λ_j|`) to the join, to split the low-fraction bucket into
harmless-to-down-weight vs near-threshold-guard. That converts the "< 10 %
upper bound" into the actual reclaimable fraction and sizes the guard band —
the gate before building the weighted-norm prototype itself.

## Bit-identical

Instrument verified bit-identical with the monitor off (the hook is gated by
`step_monitor_enabled` and only appends to the diagnostic vector; it never feeds
the trajectory). See the commit's bit-identical check.
