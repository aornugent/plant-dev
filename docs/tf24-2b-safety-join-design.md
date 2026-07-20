# Design — the 2b safety-join instrument

## Triage: 2 — crosses the odelia↔plant System-hook boundary and changes a hook
signature; but it is a diagnostic in the existing `step_monitor`/`step_argmax`
family, bit-identical off, reversible. Full procedure, kept tight.

## Requirements ledger
- R1: For the member that sets `rmax` on a step, record its weight `ρ` and a
  distance-to-removal proxy, joinable to time — over a full bank run (~12k
  accepted steps/scenario). *(challenged upward: the ask said "rejected
  attempts"; I propose the **accepted-step** attainer as the measured
  population — see kill question — because the churn test already showed
  accepted vs rejected argmax behaviour is nearly identical (churn_all≈churn_rej,
  soil% within a few pp) and the accepted-step attainer is exactly the member a
  J-weighted norm would down-weight. Confirm if rejected-attempt coverage is
  required; it needs the ragged full-`ρ`-vector variant below.)*
- R2: production bit-identical when the monitor is off — rel = 0.
- R3: minimise new names; reuse the `step_monitor` storage/R-export family.
- Scarce resource: **developer comprehension / new names** — compute is
  irrelevant (off in production; one extra map lookup when on).

## The floor
At each accepted step the controller already holds `control.last_rmax_index`
(set in `adjust_step_size`). Pass it into the existing `step_monitor` hook;
plant maps `i → member = i / vars_per_member` (when `i < slow_size`, else it is
a reservoir → sentinel), and returns two extra scalars appended to the monitor
row: the attaining member's weight `ρ` and a removal proxy. Offline, the
`step_mon` rows already carry `(t, h)`, so the answer is **read directly** — no
argmax↔ρ join step at all. Reuses `step_monitor` storage; +1 hook argument,
+2 recorded scalars.

**Suffices?** Yes for the decision (is the error-limiting member low-`ρ`/
far-from-removal, near-threshold, or mixed). Fails only the literal "rejected
attempts" wording — see the challenge above.

## Candidates
A [first thought] *inline join at the hook*: commitment — the attainer's `ρ`
is computed inside plant at each accepted step from `last_rmax_index`. Pays R1
(direct read, no offline join) + R3 (reuses `step_monitor`, +2 scalars). Costs:
accepted-steps only; +1 hook arg. Wins when accepted-step attainers are a valid
proxy (churn says yes).

B *ragged full-`ρ`-snapshot + offline join*: commitment — log the whole `ρ`
vector per accepted step, join any attempt's index offline (covers rejected
attempts too via state-reset equivalence). Pays R1 including rejected coverage.
Costs: ragged variable-`M` storage (new storage class + reshape logic), ~10M
doubles/run; more new names. Wins when rejected-attempt coverage is mandatory.

C *generic odelia-side capture*: commitment — odelia records `y[i]` (the raw
attaining component value) with no member semantics. Pays nothing — `y[i]` is
one ODE sub-variable (height/mortality/…) not `ρ`; cannot answer R1. Strawman-
adjacent; kept only to show the semantics must live plant-side.

Winner: **A**. B is eliminated by R3 (ragged storage + reshape is more than the
decision needs, and the churn data says accepted≈rejected). C is eliminated by
R1 (`y[i]` is not `ρ`).

## The commitment
The attaining member's J-relevance is measured inline at the one site that
already knows both the argmax index (controller) and the member layout (plant
hook).
Kept true by: the hook receives `last_rmax_index` by value and returns the two
scalars in the same vector `step_monitor` already stores — there is no separate
join to get out of sync.

## Kill question
Assumption whose falsity makes this unnecessary: *accepted-step attainers
represent the step-limiting population.* Argued from ledger facts: the churn
test measured churn_all 0.27–0.36 vs churn_rej 0.23–0.28 and soil% within a few
pp between accepted and rejected — so the argmax population is nearly the same
on both; the accepted-step attainer is additionally the exact member a
re-weighted norm acts on. Verdict: **survives** (rejected-only coverage would
change the population by <~5 pp on the churn evidence).

## What survives deletion
- `last_rmax_index` passed to the hook → R1 (without it the hook can't identify
  the member).
- 2 recorded scalars (`ρ`, removal proxy) → R1 (the answer itself).
- Everything else reuses `step_monitor` → held by R3.

## What this settles
- No new storage class, no offline argmax↔ρ join, no ragged reshape.
- Reservoir-attaining steps can't be miscounted as members (sentinel when
  `i ≥ slow_size`).

## What this makes hard
Rejected-attempt attainers are not covered (accepted-step proxy only). If forced
(the challenge comes back "must be rejected attempts"), switch to candidate B:
log the full `ρ` vector per accepted step and join the `step_argmax` rejected
rows offline via the bracketing accepted step (state-reset equivalence).

## Kill condition
The requirement change "rejected-attempt attainers specifically" → hands off to
candidate B.

## The design
1. **odelia** `ode_solver_internal.hpp`: at the accepted-step monitor call,
   pass `control.last_rmax_index` and `slow`/member info is not known to odelia
   — so pass just the index; plant knows its own layout. New hook signature:
   `system.step_monitor(mon_margins, mon_sig, rmax_index)`.
2. **plant** `Patch::step_monitor(...)`: gains the `int rmax_index` argument;
   if `0 ≤ rmax_index < node_ode_size()` it maps to a member and appends
   `{ρ_attainer, removal_proxy}` to `mon_margins`; else appends `{NaN, NaN}`
   (reservoir attainer). Uses the existing `species`/node accessors for `ρ`
   (node density) and the removal proxy (node weight vs the SCM's removal
   threshold, or `ρ·|φ|`).
3. **has_step_monitor trait** + the toy/other System `step_monitor` overloads
   gain the extra argument (or a defaulted overload) so the template still
   compiles.
4. **Analysis** `argmax_safety.R`: read `step_monitor_get()`, take the two new
   columns over accepted steps, and report the distribution of `ρ_attainer` and
   removal proxy (low-ρ/far → downweight; near-threshold → redistribute; mixed
   → guard band).

Bit-identical off: the hook is only invoked under `step_monitor_enabled`; the
extra argument is ignored when the monitor is off (the whole block is gated).
