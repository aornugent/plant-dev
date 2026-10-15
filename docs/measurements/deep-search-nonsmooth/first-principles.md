# The leaf's switch from first principles: what is real, what it costs, what is worth fixing

Every design since plant#112 was opened (step ends, divisions, targeted rules,
corrections) answers "how do we remove the jitter?". None asked how much the jitter
matters. This note asks that, against the objectives' own bars, before any more
mechanism.

## The domain

**Physically real.**
- A leaf runs either at its interior optimum or at its hydraulic limit, and it moves to
  the limit as the soil dries.
- On dry the whole stand moves together, because every node reads one soil against one
  species' limit.
- In the continuum of birth dates, the stand's uptake changes slope over a ramp about
  0.44 d wide (P2).
- J(θ) is smooth in the traits. The switch is a corner in time, not in θ.

**A numerical artefact.**
- An explicit step that holds the switch integrates the *derivative* of the soil's rate
  with an error of O(h × the slope jump). That error depends on where the stages fall,
  so the gradient changes when the step sequence changes.
- The forward value is not affected: its error at the switch is O(h²), and the tolerance
  sees it.

## Consequences, measured against the objectives' bars

All numbers are from dry, sharp gate, inset schedule, libD. They are in units of each
quantity's ε (`docs/measurements/eps-spread.md`).

| Consequence | Size | Bar | Matters? |
|---|---|---|---|
| ln J | ~1e-3 ε | ε | no |
| Elasticities, accuracy | the tolerance error itself: 0.013 at 1e-4, 0.020 stopped at 3e-4 (`lean/` L1) | within ε | no |
| Elasticities, reproducibility (a ±5% nudge of the tolerance) | rms 0.048, max 0.18 at 3e-4; 0.016–0.03 at 1e-4 | under ε/3 = 0.33 | no: met with about 2× margin |
| Selection gradient and analyses built on it (direction, where it vanishes) | the same 0.05 ε | ε | no: the analysis is built on ε |
| The error estimate from a pair of runs ("Predictable") | jitter 0.048 against a tolerance move of 0.018. The schedule check misreads at 3e-4 on dry; at 1e-4 the rule passes 10/10 (E6) | an honest estimate | **yes**, but only at 3e-4: it forces 1e-4, which costs 1/0.875 = +14% rows |
| Curvature rows by chords of gradients at r = 1e-2 | gradient jitter ÷ 2r. For `lma` (gradient ε 0.087, curvature ε 1.2), 0.025 ε of gradient becomes about 0.09 ε of curvature (estimate). Long drought measured 41 of 48 entries within ε/3 across r | ε/3 | **marginal**, entry by entry; unmeasured on dry |
| The averaged gate | rms 0.110, max 0.42 at 1e-4 | ε/3 | yes, but that gate will not land |
| Jumps in the rate (Determined, shutdown, the soil's positivity) | unknown: no census on current builds. A jump leaves a *bias* (Δf·dt/dθ), not jitter | ε | **unknown, possibly the largest** |

## What follows

**The leaf's switch is a cost problem, not an accuracy problem.**
- Its only measured material consequence is that the schedule's pair estimate cannot run
  at 3e-4. That bounds the value of any fix at about 12–14% of rows.
- The cheapest measured fix, the targeted stop, costs +3.6%, so its net gain is about
  9–10%.
- Every mechanism weighed so far is new code and new concepts spent to win that 10%:
  the stop, the division, the correction.

**The witness for a general representation in odelia is weak.**
- One kind of point (K, the switch) with a sub-ε effect.
- One out-of-scope W point (the averaged gate).
- The J kinds, whose frequency nobody has measured.

The principles (*Design for observed usage*; *Subtract Before You Add*) say not to build
it on this evidence.

## Recommended, in order

1. **Census the jumps.** Count Determined, HydraulicShutdown and positivity-guard
   evaluations on *accepted* stages across the ten-case bank on the current build
   (phylloptim 0.9.3).
   - It is cheap: the leaf solve already tallies its operating-point kinds.
   - It is the one unknown that could exceed ε, as a bias rather than jitter.
2. **Keep 1e-4 for the schedule's pair, and do nothing in odelia for the switch.**
3. **If 3e-4's 12% is wanted,** fix the *estimate*, not the integrator.
   - The pair misreads because its two runs take different steps, so their jitter does
     not cancel ("lesson 15").
   - A check run that steps on the committed run's step times shares most of that
     jitter, and the pair then reads the schedule's own error.
   - That uses no new mechanism: odelia already steps a System to a given grid. It is
     untested.
4. **Curvature rows on dry:** measure the chord's stability across r on dry before
   assuming the switch hurts it. If it does, take that row's diagonal from second
   differences of ln J, which carries no gradient jitter.
5. **Reopen the representation question only when a witness demands it:**
   - J kinds found on accepted stages; or
   - the averaged gate is revived; or
   - curvature rows fail on dry because of the switch.

   The search's map (`judge.md` §8, `lean/`, `correction/`) is the starting point then.

## The census (`docs/measurements/kinks/jump-census/results.md`)

Pinned replays of the ten bank runs on libS, accepted stages only. Every replay
reproduces its saved J exactly.

| Jump | Where it occurs | How often |
|---|---|---|
| Positivity guard (#19) | nowhere | 0 on all ten |
| HydraulicShutdown | five of ten records, 11–20 solves each | at most about 1e-5 of solves: too rare to reach ε |
| Determined | 0 on dry, dry-flat and dry-p50; 4 on ld-102; 424–489 on long-wet, wet-adG2 and ld-105 | at most 1.7e-4 of solves |

- Where Determined occurs in the hundreds, the soil's potential ceiling (#21, a slope
  jump) binds too. This co-occurrence is measured; whether one causes the other is not.
- The open question is how many steps those Determined solves fall inside: clustered in a
  few steps or scattered across many. At most 434–503 per record.
- The recording does not expose each evaluation's operating-point kind to R, so this
  could not be counted.
- Deciding it needs one of:
  - an R reader for the recorded solved values; or
  - one gradient comparison on long-wet with step ends placed at the Determined
    transitions.
