# T2 — PI step-size controller for odelia (design)

## Triage: 2 — a visible seam in the engine (every integration calls
`adjust_step_size`), but opt-in and reversible (a flag; delete = revert).

## Requirements ledger
- R1: cut the wasted rejection fraction — currently **0.27–0.31** of step attempts,
  each re-running the full O(M) member sweep. Target: materially lower (say ≤0.15),
  no worse than baseline on any bank sequence.
- R2: forward output (offspring/`J`) unchanged to convergence — the controller changes
  the step *sequence*, not the answer; `J` must stay at its converged value
  (rel ≤ ~1e-3 vs baseline, the tolerance-limited agreement).
- R3: production bit-identical when the feature is off (Part-1 invariant).
- R4: one new user-facing name at most (abstraction principle).

Scarce resource: rejected O(M) RHS sweeps — the ~30% of ~10⁴ steps that are undone
and retried, each costing the full per-member solve set.

Challenge logged upward: "PI controller" is a solution-verb; the outcome is R1+R2.
A cruder fix (just cap growth) is admitted as a candidate below.

## The floor
Gated reduction of the growth cap (5×→2×), no error memory. Fails nothing on paper,
but a pure cap only shrinks the *amplitude* of the grow→overshoot→reject limit cycle
(measured rej/acc 2.4–4.0×); it does not damp the cycle, because it still reacts to
`err_n` alone. Kept as candidate B — test-before-assume.

## Candidates
A [first thought] *add-memory*: a PI (Gustafsson/DOPRI5-stabilised) predictor using the
previous accepted error — commitment: the next step is predicted from `(err_n, err_{n-1})`,
not `err_n` alone — pays R1 by damping the limit cycle at its source — costs one bool +
one `double err_prev` state + a fixed constant `β=0.04` — wins when the rejection is an
oscillation (our measurement: rejected steps systematically *larger* than accepted).
B *do-less*: gated growth-cap 5×→2× — commitment: bound the per-step growth — pays R1 by
truncating overshoot — costs one bool — wins when overshoot is a single big jump, not a
sustained cycle.
C *reframe*: Hairer's "no growth on the step after a rejection" — commitment: never grow
immediately post-reject — pays R1 partially — costs nothing (the `shrank` flag exists) —
wins when rejections are isolated, not back-to-back.

Winner: **A**. Eliminations: B leaves the cycle intact (R1 only halved, and it slows
genuinely-smooth stretches — grows 2×/step where the problem allows 5×); C addresses only
the post-reject step, but the measured over-reach is systematic (rej/acc 3–4× across all
sequences, not just after rejects), so C under-pays R1. A subsumes both (it carries a
modest facmax and inherently damps post-reject) at the cost of one extra `double`.

## The commitment
One bool selects the controller; **off reproduces the exact current arithmetic**, on uses
the PI predictor.
Kept true by: the flag gates an `if`; the off-branch is the unmodified I-controller code,
byte-for-byte. Bit-identical (R3) is then structural, not a promise.

## Kill question
Assumption whose falsity makes this unnecessary: "the rejections are controller over-reach."
Argued from the ledger: rejected attempts are 2.4–4.0× *larger* than accepted steps
bank-wide (measured) — the controller demonstrably proposes too-big steps and is refused.
Survives.

## What survives deletion
- `use_pi_controller` (bool) → R3/R4 (the opt-in gate).
- `err_prev` (double) → R1 (the memory that damps the cycle; A's whole mechanism).
- everything else (β, facmax, exponents) are fixed literals, not new names.

## What this settles
- No change to the accept/reject *threshold* (still `rmax>1.1` → reject): the step
  sequence differs only via the predictor, so R2 is a convergence check, not a redesign.
- No plant-side logic: plant threads one bool through `Control`→`make_ode_control`.

## What this makes hard
A single fixed constant set (β=0.04, facmax=2, Gustafsson exponents) may be sub-optimal
for some sequence; if forced, expose them later. Not now — knobs are new names (R4).

## Kill condition
If A fails to cut R1 materially, fall back to B (the cap) — its "wins when" (single-jump
overshoot) is the next hypothesis, and it is a one-line change from A's code.

## The design
`OdeControl`: add `bool use_pi_controller=false`, `double err_prev` (reset to 1 in
`set_controls`). In `adjust_step_size`, when the flag is on:
- reject (`rmax>1.1`): pure-I shrink `S·rmax^(−1/ord)`, clamp [0.2,1], **don't** update
  `err_prev` (standard).
- accept: `fac = S · rmax^(−(1/ord − 0.75β)) · err_prev^(β)`, clamp [0.2, facmax=2], apply,
  then `err_prev = max(rmax, 1e-4)`.
When off: the existing dead-band I-controller, unchanged.
plant: `Control.ode_use_pi_controller` (bool, default false) → `make_ode_control`. One flag.
Validate in odelia toy-first (order preserved via a convergence check; reject fraction ↓ on
a stiff oscillatory toy), then measure on the bank (R1, R2).
