# Code review — Attempt B (sessions `013FAsD`): AD-1 → AD-2/3/4 → AD-7 → AD-1b stack

**Scope reviewed.** The cumulative diff of `claude/ad-1b-active-compile-rnzkra` against
`plant:develop` (PRs #17 → #22 → #23 → #24 → #25 → #26): scalar-template FF16 (AD-1, shared
with Attempt A), the Patch/SCM System contract and runnable (AD-2/AD-3), the `Replayable`
rename (AD-4), active-bound Gauss–Kronrod (`qk::integrate_ad`, AD-7), and the active
physiology compile + reverse-mode FD gate (AD-1b). AD-1 is reviewed in
[the Attempt A review](./attempt-A-review.md); this review covers B's deltas.

Judged against the project [code style](../../AGENTS.md#code-style) and the
[implementation spec](../ad-implementation-spec.md).

---

## Verdict: rethink approach

Attempt B is more honest about the *physics* than Attempt A: it templates `CanopyShape`,
`FF16_Environment`, and `ResourceSpline` on the scalar and adds `integrate_ad`, so the
crown integral's moving bound and the light read's `dE/dheight` actually flow — and it
proves a real **reverse-mode** `d(net_mass_production_dt)/d(lma)` against finite differences
(AD-1b). That is a stronger correctness demonstration, at the leaf, than A has anywhere.

But it buys that honesty with a **parallel overload set**: every shape/spline/environment
function now exists twice — a `double` body and an `enable_if<!is_same_v<S,double>>` active
body that must be kept numerically identical by hand. That is the spike's parallel-engine
debt (the thing the spec says to *delete*) reintroduced one leaf-function at a time, and it
directly violates the codebase rule *"No parallel near-copy of an existing type or path;
modify what exists."* And the stack stops at AD-1b — no `EmergentFunctional`, no
`stand_gradient` entry, no SCM-level FD gate — so the surface area grew while the
end-to-end correctness crux stayed unproven. B also contains a **concrete, provably-wrong
dropped derivative** at the seed cohort (finding 3) that A gets right.

---

## What must always be true

> The active overload of each physics function computes the **same number** (to AD
> tolerance) as its `double` twin, and freezes derivatives only where the quantity is
> genuinely structure (a fixed node, a piecewise-constant layer).

**Kept true by: convention.** The `double` and active bodies of `q`, `Q`, `leaf_area_above`,
`Qp`, `get_environment_at_height`, `step_light`, `smooth_floor`, `get_value_at_height` are
hand-written twins. Nothing structurally ties them; a fix to the double path (a clamp, a
guard, a reparametrisation) does not propagate to the active path, and the FD gate exercises
only one of the pair at a time. The `xad::value(...)` guards inside the active bodies are the
same convention-kept derivative-drops as Attempt A's `ad_value`, just inlined rather than
named.

---

## Structural findings

1. **Parallel active/double overloads across three physics headers.**
   `canopy_shape.h` (`q`, `Q`, `leaf_area_above`, `Qp`), `ff16_environment.h`
   (`get_environment_at_height` ×2, `step_light`, `smooth_floor`), `resource_spline.h`
   (`get_value_at_height` ×2) each gain a second `enable_if<!is_same_v<S,double>>` body
   duplicating the first. — Makes *every future change to a shape or light function* a
   two-site edit with no compiler enforcement that the sites agree, and makes the FD gate
   blind to divergence (it hits one body per run). This is the parallel-copy debt the plan
   exists to remove. — **Alternative:** one templated body per function, exactly as AD-1
   already did for the entire strategy. The *reason* a second body seemed necessary is the
   `xad::value()` guards inside them (finding 2) and the double-only dispatch members
   (`pow_eta_`, `leaf_above_` function pointers) in `CanopyShape` — fix those and the double
   path is simply the `S=double` instantiation of the single template.

2. **`xad::value()` guards inside the active bodies** (`step_light`: `if (xad::value(E) >=
   1.0)`; `smooth_floor`: `floor(xad::value(u))`; `resource_spline`: `xad::value(height) >
   cap`, `xad::value(value) < 0.0`; `qk::integrate_ad` NaN self-compares). — Same cost as
   Attempt A finding 1: each is a branch on the passive value that freezes structure, and a
   reader cannot tell the genuinely-piecewise-constant ones (the PPA layer index — correct
   to freeze) from the ones that drop a live term (the spline zero-floor and the `cap`
   clamp are at operating-point boundaries, but the *branch itself* discards curvature). —
   **Alternative:** branching on the passive value is legitimate *only* for genuinely
   piecewise-constant selectors (layer index); write that comparison once, in a single
   templated body, with a comment naming why the derivative is structurally zero there.
   The clamps (`max(0, spline)`, `height > cap`) are operating-point guards that should be
   the recorded-field / node-position machinery, not inline value reads.

3. **`height_seed` drops a real derivative, and its justification is provably wrong.**
   `ff16_strategy.cpp` computes the seed-height root in `double` and returns it lifted to
   `S` with **no derivative reattachment**, justified by the comment: *"the trait derivative
   is recovered through `area_leaf_0 = area_leaf(height_0)`."* That is false:
   `ff16_area_leaf(a_l1, a_l2, height)` has **no `lma` dependence** (verified in
   `ff16_production_kernel.h`), whereas `height_seed` solves
   `mass_live_given_height(h) = omega` where `mass_live_given_height` *does* depend on `lma`
   (via `mass_leaf = area_leaf·lma`). So `dheight_0/dlma ≠ 0`, and dropping it means
   `d(area_leaf_0)/dlma` and everything downstream of the seed cohort's initial size loses
   that term. — Makes *every emergent metric that flows through a birth cohort silently
   wrong* w.r.t. any trait feeding seed mass; it passes AD-1b (which fixes `height`
   externally and never exercises `height_seed`) and would fail the real SCM FD gate with no
   local symptom. — **Alternative:** reattach via the implicit function theorem (Attempt A
   does this and validates `d(height_0)/d(lma)` against FD to 1e-4) or, better, register the
   root through odelia's `supplied_derivative`. **Note this is a direct A-vs-B contradiction
   at an undocumented spot:** the spec never pins whether `height_seed` carries a derivative,
   and the two attempts made *opposite* choices — A correct, B wrong. That silence is a spec
   defect, not just a code bug.

4. **`SCM::reset` forks on the scalar** (`scm.h`: `if constexpr (is_same_v<value_type,
   double>)`, double path snapshots + copies, active path resets in place). — Identical in
   shape and cost to Attempt A finding 2: the run/reset control flow now has a resident and
   an active version to keep consistent. — **Alternative:** as in A — the seed-clobber is
   fixed by never copying an external snapshot over the solver's own system, for both paths;
   the schedule is data, so no scalar branch is needed.

5. **The stack stops at AD-1b; the composed gradient is unproven.** [conditional]
   No `EmergentFunctional`, no `stand_gradient`/`invasion_gradient` entry, no R surface, no
   SCM-level AD-vs-FD gate. AD-1b proves a *single plant at a fixed height* differentiates;
   the actual deliverable (an invasion offspring/census gradient matching FD across a run)
   is untested. — Makes it impossible to know whether the parallel-overload investment
   *works* end to end before committing to it. — **Alternative:** prove the smallest
   end-to-end invasion FD gate first (AD-5/AD-6), then decide how much active-physics
   surface it actually requires — likely far less than templating every shape function, if
   invasion reads the environment frozen.

---

## Minor findings

- **`integrate_ad` is a second full copy of the GK accumulation loop** (`qk.h`), which must
  stay bit-identical to `integrate()` by hand (the comment says so). — Template `integrate()`
  on the scalar/bound type instead of forking the rule; the `const`/stateless difference
  (integrate_ad writes no `last_*`) is a genuine contract divergence for the "same" rule.

- **`CanopyShape` stores a new `shading_model_` member solely so the active
  `leaf_area_above` can re-dispatch** (`canopy_shape.h`). The double path already encodes
  that choice in the `leaf_above_` function pointer; the dispatch fact now lives in two
  places and can disagree.

- **`smooth_floor`/`step_light` active bodies re-derive the PPA staircase** already written
  for the double path — a third near-copy of the same piecewise math.

- **AD-1b's test compiles the strategy `.cpp` via `sourceCpp` including the source file
  directly** (`#include ".../ff16_strategy.cpp"`), so it only runs against the source tree,
  not the installed package — the opposite constraint from A's tests (which link the
  installed `.so`). Neither exercises the shipped compiled AD path AD-11 will need.

---

## What this tells the reset

Attempt B is the more physically-correct *direction* (template the environment so there is
no frozen-double boundary to hand-patch) but the *wrong mechanism* for it (a parallel
overload per function instead of one templated body). Its two hardest problems — the
parallel copies and the dropped `height_seed` derivative — are both symptoms of the same
root cause as Attempt A: an **active/double boundary that the developer must service by
hand**, whether by A's scattered `ad_value` or B's twin overloads. The difference is only
*where* the hand-work lands. The reset should remove the boundary (uniform `S` end to end,
frozen strictly via odelia's recording) rather than pick which way to hand-service it.
