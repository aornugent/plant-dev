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

## Distance-to-removal split (added) — the win shrinks

The refinement records the attaining member's `d(log density)/dt` (`ldr`),
which separates the low-relevance bucket into **stable-marginal** (`|ldr| < 0.1`,
harmless to down-weight) and **dying** (`ldr < −1`, heading to the `ρ → 0`
absorbing boundary — a survival bit that must keep full weight). Within the
`< 10 %`-weight bucket:

| sequence | stable (harmless) | dying (guard) | median ldr |
|---|---|---|---|
| bursty | 18 % | 33 % | 0.000 |
| ramp | 15 % | 51 % | −1.165 |
| long-low-interval | 11 % | 33 % | 0.141 |

**A third to a half of the marginal error-setters are dying members** — exactly
the survival bits `J` is most sensitive to, which the guard band must protect.
So the "down-weight the low-weight attainers" opportunity is substantially eaten:
of the `<10 %`-weight attainers, only ~11–18 % are cleanly stable-marginal; a
large share are transition members you cannot safely down-weight. This is the
tension the Oracle named, now measured: **the members that limit the step and
the members `J` depends on overlap heavily** — a member crossing the survival
threshold has fast-changing dynamics (large local error → sets `rmax`) *and* is
J-critical.

## Verdict (updated) — the norm lever is real but modest, and gated by a guard band

Stacking the constraints: ~30 % of accepted steps are reservoir-limited (a
member norm can't touch them); of the ~70 % member-limited, 14–21 % are
dominant (keep weight) and, within the marginal remainder, ~⅓–½ are dying
(guard). The cleanly-reclaimable population — member-limited, low-weight, and
stable — is therefore only roughly **10–20 % of accepted steps**. A
J-relevance-weighted norm with a survival guard band would work on those, but
its ceiling is modest, not the dramatic win the raw "<10 %-weight = 50–69 %"
figure first suggested. Worth prototyping only if a ~10–20 % accepted-step
reduction (J-neutral) is judged worth the guard-band machinery; otherwise the
architectural stone (waveform relaxation, which removes the global max-norm
entirely) is the better use of effort.

## Bit-identical

Instrument verified bit-identical with the monitor off (the hook is gated by
`step_monitor_enabled` and only appends to the diagnostic vector; it never feeds
the trajectory). See the commit's bit-identical check.
