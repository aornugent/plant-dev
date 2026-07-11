# Code review — Attempt A (sessions `01Rjb4D`): AD-1 → AD-5 invasion stack

**Scope reviewed.** The cumulative diff of `claude/ad-5-emergent-functional` against
`plant:develop` (PRs #17 → #18 → #19 → #20 → #21), i.e. the full stack: scalar-template
FF16 (AD-1), the Patch System contract (AD-2), the SCM runnable + `reset` fix (AD-3), the
`Replayable` rename + frozen-field dispatch (AD-4), and `EmergentFunctional` +
`stand_gradient` entry (AD-5). AD-1 is shared with Attempt B and is reviewed once here.

Judged against the project [code style](../../AGENTS.md#code-style) and the
[implementation spec](../ad-implementation-spec.md).

---

## Verdict: rethink approach

The stack compiles, links, and reaches an end-to-end R entry — genuinely further than
Attempt B. But it reaches it by building a **hybrid double/active model**: a uniform `S`
type whose derivative flow is punctured at ~20 hand-placed extraction points
(`ad_value(...)`), plus scalar-branched (`if constexpr (is_same_v<value_type,double>)`)
`reset`/`run` paths, plus an environment/canopy/crown-integral held frozen as `double`.
This is precisely the *parallel active/frozen axis* the epic's binding commitment (#7,
PROTO-1) said uniform-`S` would eliminate — reintroduced through the back door, one
`ad_value` call at a time. The design's promise was "derivatives flow structurally";
the code delivers "derivatives flow except where a developer remembered to drop them."

The lead problem is not any single finding below — it is that the invariant the whole
feature rests on is kept by **convention**, and the convention is invisible at every call
site.

---

## What must always be true

> A trait's derivative reaches every emergent metric it influences, **unless** that path
> is one we have deliberately and correctly frozen (the invasion resident canopy).

**Kept true by: convention.** Every `ad_value(x)` call is a point where the derivative is
discarded. Some are provably correct (reading the frozen resident environment, which is a
`double` by construction). Others are placeholders that silently drop a *real* derivative
to be "filled in later at AD-7/AD-8" (the crown integral, `canopy_shape`, `Qp`). Nothing
in the type, the name, or the call site distinguishes the two. The reader — and the next
developer debugging a wrong gradient — must hold the entire mental map of which drops are
safe. That map exists only in the author's head and the PR prose.

---

## Structural findings

1. **`ad_value()` is an unmarked derivative-drop scattered across ~20 sites**
   (`ad_value.h`; used in `node.h` ×7, `individual.h` ×3, `ff16_strategy.cpp` ×8:
   crown integral bound, `canopy_shape.leaf_area_above`, `Qp`, `mortality_dt`,
   `prepare_strategy`, `height_seed`). — Makes *debugging a zero/wrong gradient* far
   harder because the first step is auditing every one of those sites to decide whether it
   was a legitimate freeze or a missed lift, with no signal to rank them. — **Alternative:**
   there should be exactly one freezing mechanism, and it should be odelia's, not plant's.
   odelia already models "frozen" as *data presence* (`has_recorded_field()` → read the
   recorded `double` off-tape). Route every frozen read through the L3 recorded-field path
   so "frozen" is a property of the recording, checked in one place, instead of a call
   that any function can make. Where a value is *genuinely* off-tape double (a fixed
   integration node position), that is L2 and also belongs to the recording — not to an
   inline `value()` in physiology code.

2. **`SCM::reset` and `SCM::run_next_impl` fork on the scalar** (`scm.h`: two
   `if constexpr (is_same_v<value_type,double>)` blocks, the active branch `util::stop`-ing
   on adaptive/euler stepping). — Makes *any change to the run loop* twice the work and a
   drift risk, and worse, makes the active integrator a *different integrator* than the
   resident (fixed-schedule only, no adaptive control) — which quietly undermines the FD
   gate, since finite differences of the adaptive resident run are being compared to a
   fixed-schedule active replay. — **Alternative:** the replay schedule is *data*
   (`recorded_steps()` / `ode_times`), and both resident recording and active replay feed
   the same `advance_fixed`. Don't branch `run`/`reset` on the scalar at all; branch on
   "am I replaying a recording?", which is already how `using_ode_times()` works. The
   `reset` seed-clobber fix (the real bug in AD-3) is then a one-line change to *never*
   copy an external snapshot over the solver's own system, for both paths.

3. **Five files replace odelia's shared ODE iteration with hand-rolled loops**
   (`environment.h`, `individual.h`, `node.h`, `species_base.h`, `patch.h`: every
   `odelia::ode::set_ode_state(begin,end,it)` / `ode_state` / `ode_rates` free-function
   call became a local `for` loop, to template on the iterator). — Makes *keeping plant in
   step with odelia's ODE-serialisation contract* harder because plant now owns a private
   copy of iteration that odelia already provides, and the two can diverge silently
   (e.g. if odelia changes how it walks a range). This is net *more* code in plant, against
   a "deletion-heavy" plan. — **Alternative:** if odelia's helpers are `double`-only, that
   is a one-line template on the iterator type *in odelia* (a co-design item the spec's
   ledger explicitly allows), not a five-file fork in plant. Keep the reuse.

4. **`SCM` gains a hand-written copy ctor + assignment enumerating 8 members**
   (`scm.h`: `collect, collect_refinement_errors, history, parameters, control, patch,
   node_schedule, solver`), forced by the `unique_ptr`-typed `tape` member. — Makes
   *adding any SCM member* a silent-data-loss trap: forget to list it in both special
   members and every RcppR6 wrap (which copies) drops it, with no compile error. —
   **Alternative:** odelia already solved exactly this for `Solver` (copy resets the tape;
   the tape is amortization scratch, not value). Reuse that — hold the tape inside a small
   type whose copy is *defined once* to reset, so `SCM`'s copy stays `= default`. Don't
   re-solve the copyability problem a second time at the SCM level with a member roster.

5. **`height_seed` reattaches the trait derivative with a scalar-mode-dependent trick**
   (`ff16_strategy.cpp`: `g - ad_value(g)` extracts the derivative part, then
   `S(h_root) - g_deriv/dg_dh`). — This is a genuinely correct IFT reattachment (and its
   FD test passes, at forward-mode) — but it is *only* obviously correct for forward mode,
   where value and derivative travel together in one number. Under the **reverse** tape
   that also ships in `plant.so`, `g - value(g)` records tape operations whose adjoint
   behaviour is not the same construction, and there is **no reverse-mode test of this
   path**. — Makes *trusting any gradient that flows through seed height* rest on an
   untested, mode-specific identity; if it is wrong under reverse mode it biases silently.
   — **Alternative:** odelia ships `supplied_derivative` for exactly this — register the
   off-tape root and hand the sweep its analytic `dh/dtheta`. One sanctioned, tested,
   mode-correct seam instead of a hand-rolled one. (This is also the seam AD-9 needs for
   the leaf optimizer, so it is not speculative.)

---

## Minor findings

- **The headline metric's gradient is a structural zero today.**
  `EmergentFunctional::offspring_production` sums `weighted_fecundity` over nodes, but the
  offspring accumulator is held `double` until AD-6, so `d(offspring)/d(lma) = 0` on the
  wired path (PR #21 admits this). A metric whose gradient is hardcoded-zero will pass a
  "returns a finite double" smoke test and read as *working*. Gate on a non-zero FD match
  or don't ship the metric.

- **`offspring_production` re-implements the trapezium + birth-rate scaling** in the
  functional (`emergent_functional.h`) rather than reusing a model reduction — the exact
  hand-copied-census pattern the spec says to avoid. It reuses `weighted_fecundity`
  per-node but rebuilds the integration; a second census metric will copy it again.

- **Two of three shading models are silently non-differentiable.**
  `assimilation_average_light` and `assimilation_crown_top` still integrate a `double`
  lambda / read a `double E` (bound passed as `ad_value(height)`); only `deep_crown`
  (the default) carries a derivative. A user who sets `shading_model = "mean_light"` gets
  a plausible, wrong gradient with no error.

- **`set_ode_state(it, double time)` vs `set_ode_state(it, int index)` are distinguished
  only by argument type** (`patch.h`). A caller writing `set_ode_state(it, 0)` (int) silently
  selects the frozen-read path; `0.0` selects recompute. Overload-on-scalar-type for two
  semantically opposite operations is a footgun; name them (`set_ode_state_recompute` /
  `_replay`) or pass an explicit mode.

- **`ad_value` resolves the active case via unqualified `value(x)` (ADL)** with no include
  of XAD in the header — it compiles only in TUs that separately include XAD before it.
  This works today by include ordering; it is a latent build-fragility if the header is
  used from a new TU.

---

## What this tells the reset

The instructive fact is *where the complexity concentrated*: not in the AD itself
(odelia does that), but in the **boundary between active physiology and a double
environment**. Every structural finding above is downstream of that boundary existing.
The boundary exists because the stack sequences **invasion first** (resident canopy frozen
as `double`), so the model is mixed-scalar before the environment is ever templated — and
uniform-`S`'s promise (derivatives flow structurally) is void exactly there. Attempt B,
which templates the environment/spline/canopy from the start, has *less* of this scatter
in the physics (and more elsewhere) — evidence that the boundary, not the AD, is the thing
to design out.
