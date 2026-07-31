# Phase 1, close review

Read against `build-plan.md` §2 and §4, `AGENTS.md`'s code style, `odelia/AGENTS.md`, and
`plant/agents.md`. Four findings, on the merged trees `p1/phase-1` (`1204d332`) and
`p1/odelia-integration` (`e10ab19`). No code changed.

---

## 1. The canopy's double/active split cannot be bit-identical, and a gate says it must be

**Severity: this one changes a Phase 3 premise.**

`CanopyShape<S>::pow_eta` takes two different code paths:

```cpp
if constexpr (std::is_same_v<S, double>) {
  return pow_eta_(u, eta_);          // the multiplication chain selected in initialise()
} else {
  if (to_passive(u) <= 0.0) return S(0.0);
  return std::pow(u, eta_);          // so the eta derivative u^eta * log(u) is recorded
}
```

At TF24's default `eta = 12` the `double` branch is `pow_eta_12` — `u² → u⁴ → u⁸ → u⁸·u⁴` — and
the active branch is `std::pow`. **This repository has already measured that those two disagree:**
over a production census of 15 087 (knot, height) pairs, 1 144 differ and every difference is
bounded by `4.440892e-16`, 2 ulp of 1.0 (`implementation-notes.md`, P0.12).

So **"the active value equals the double value to the last bit" is unachievable by construction**
at the default exponent. That is the gate this phase's active-build packet was given, and it was
never contradicted only because 41 compile errors stopped the value comparison from running. The
next person to clear those errors will run the gate, watch it fail, and go looking for a bug that
is not there.

**The code is right and the gate is wrong.** The split is not incidental: a multiplication chain
carries no exponent term, so `d/d(eta)` through it is structurally absent rather than merely
imprecise, which is exactly why the plan asks for `std::pow` on an active scalar. The price of
that necessary split is 2 ulp of value disagreement, and nobody wrote the price down.

Note the asymmetry in *which* exponents are affected: `pow_eta_general` is `std::pow` on both
branches, so a non-specialised `eta` agrees exactly. The disagreement is confined to the
specialised chains — 1, 2, … 12 — which is precisely where both models that use the class sit.

**What needs deciding, and it is not a style question.** The design stores the trajectory in
`double` and then records the reverse pass at an active scalar. If the canopy profile takes a
different arithmetic path at the active scalar, the adjoint's linearisation point is not the state
that was stored. The forward controller cannot amplify it on a reverse pass, so this is not the
0.67%-in-offspring mechanism P0.12 measured — but it is the same 2 ulp, in the same function, and
the phase that consumes it should say which of these it wants:

1. state the gate as agreement to a few ulp, with this mechanism named as the reason;
2. use `std::pow` on both branches, which moves `double` values and needs a re-bless — deliberately
   avoided in Phase 0;
3. keep the chains on the active branch too and accept that a seeded `eta` has no derivative,
   which defeats the reason for templating the profile.

## 2. odelia's design documents know nothing about Phase 1

**Severity: an integration gap, and it is the integrator's, not any packet's.**

`build-plan.md` §4 names one home per fact, and assigns `odelia/AUTODIFF.md` "the System
requirements" and `odelia/ARCHITECTURE.md` "the `Tape` link across the DLL boundary".
`odelia/AGENTS.md` repeats it: *"`AUTODIFF.md` is the reference for the AD surface a System
implements."*

Measured across both files, occurrences of every name this phase added:

    OdeElement 0   set_ode_aux 0   step_adjoint 0   vector_jacobian_product 0
    implicit_value 0   hermite 0   to_passive 0   forward_derivative 0
    step_size 0   ode_step_record 0

Phase 1 changed what a System and an element must provide — `OdeElement` pins the state-transfer
iterator, `set_ode_aux` became an ordinary member so the family is five rather than four, and the
solver now records a step size beside each accepted time — and updated none of it. No packet could
have: every allowlist was code and tests. It is exactly the class of work that falls to whoever
integrates, and it was missed.

## 3. `graft_value` is promised by two style guides, does not exist, and the idiom it was meant to own is now hand-written twice

**Severity: a documented instruction that cannot be followed.**

`AGENTS.md`'s code style says the two structural defences against the dangling
expression-template failure are *"`odelia::implicit_value`'s `static_assert` on its residual, and
`odelia::util::graft_value` owning the value-graft idiom so it is not hand-written."* The new
`plant/agents.md` §13, written in this phase, repeats it in its worked example:

```cpp
// GOOD -- materialised while its operands are alive
auto anchor = [](double v, const S& x) -> S { return graft_value<S>(v, x); };
```

`grep -rn 'graft_value' odelia/inst/include` returns nothing. So §13 tells a model author to call
a function that is not there — the first thing a reader will do with the new section.

Meanwhile the idiom landed twice, in two shapes, in two new headers:

- `hermite_interpolator::graft(value, dydu, u, up)` → `value + dydu * (u − up)`
- `implicit_node` → `S(y_star) − corr + util::to_passive(corr)`

Both are "materialise while the operands are alive, then subtract the passive part"; neither uses
a shared helper, because there is none. That is the "no parallel near-copy" rule and the specific
promise in the style guide, both unmet. The two are not literally the same call — one carries a
slope multiplier, the other a negation — so a shared helper is a small design question rather than
a rename, which is why it is reported rather than done.

Either add `odelia::util::graft_value` and route both through it, or correct both style guides.
The current state is the one option that should not persist.

## 4. The two style guides disagree about issue references, and the merged tree depends on which wins

**Severity: minor, but it is unresolved and it has live instances.**

`AGENTS.md` (workspace): *"No process history: issue tags … doc-section references … or mentions
of other repos."* `odelia/AGENTS.md`: *"A stable external anchor (a paper, `#472`, a GSL routine)
is fine; process references drift the moment the code moves."*

The merged plant tree carries 15 issue tags in `tf24_strategy.h` — `#517`, `#550`, `#526`,
`#527`, `#530` — every one of them pre-existing and carried across a file move when
`src/tf24_strategy.cpp` was deleted and its definitions moved into the header. The arithmetic
closes exactly (7 in the base header plus 8 in the base source equals 15 in the tip), so this
phase added none.

Under the workspace rule they are violations that a file move has now relocated into a header;
under odelia's reasoning they are legitimate stable anchors. Nobody has decided which applies to
plant, and a sweep will keep reporting them until someone does.

---

## Checked and cleared

- **`initial_states` is public.** `TF24_Environment` has a single `public:` and no private section
  at all, so a public snapshot member continues the file rather than departing from it. Not a new
  smell. It is also *not* R-visible: the yml's `set_initial_states` is a pre-existing, unrelated
  method on `Individual`.
- **The two `pow` guards agree in meaning.** `pow_eta` returns `0` at `u ≤ 0`, which is the leaf
  area density's value there; `TF24_Strategy::Q` returns `1`, which is the cumulative root
  fraction below `z = 0`. Different constants because they are different quantities, both correct.
- **No deduced return type on anything returning an active value**, verified by the first code
  ever to instantiate these templates at an active scalar, which is stronger than inspection.
- **The typedef sweep is complete and `xad::` is empty in plant**, on the merged tree.

---

# Addendum: reviewed against reports 00–04

The four findings above came from the build plan and the style guides. Re-reading the reports
with the merged code in hand adds two, and clears the interpolant.

## 5. The interpolant is faithful to its report, and `ResourceSpline` promises what it cannot yet honour

**Cleared, then reframed.** `hermite_interpolator` matches report 03 §5's specified surface
exactly — `init`, `eval`, `operator()`, `slope`, `value_and_slope`, `min`, `max`, `size`,
`knots`, `clear`, and the per-span record `{x0, inv_h, y0, c1, c2, c3}` stored contiguously so a
query touches one cache line. It is a superset in one respect the report did not ask for: every
query is templated on its argument type, so it accepts an active position.

But report 03 §5 also claims the surface "mirrors `basic_interpolator` so `ResourceSpline` can
hold one in place of the other", and that is where the code and the reports meet awkwardly:

    resource_spline.h:114   odelia::interpolator::basic_interpolator<S> spline;
    resource_spline.h:72    S get_value_at_height(S height) const;
    resource_spline.h:92    return height <= cap ? std::max(S(0.0), spline(height)) : S(1.0);

`ResourceSpline<S>` **declares an active-height accessor that its own interpolant cannot
honour** — `basic_interpolator<S>` carries `S` values on a `double` abscissa. At `S = double`
this is invisible; at an active `S` it is the active build's obstruction F.

**So obstruction F is not a defect to patch — it is the seam the interpolant swap lands on, and
the hermite was built to that shape.** Both halves exist after this phase and neither is
connected to the other: the fitted interpolant holds the production knot set and cannot take an
active position; the Hermite can take one and has no consumer. Report 03 §8 and the plan's P2.1
and P2.2 own the connection. Worth stating plainly because a reader meeting the mismatch cold
would reasonably try to fix it in `ResourceSpline`, which is the one place it should not be
fixed.

The templating went one step further than the interpolant beneath it. That is not wrong — the
accessor's signature is where the design is heading — but it means `ResourceSpline<S>`'s
signature is a promise dated for Phase 2, and nothing says so at the site.

## 6. Report 02's leaf input list has drifted, exactly as its own constraint predicted

Report 02 §6.8 enumerates the leaf's parameter inputs as **12**: `vcmax_25`, `jmax_25`, `a`,
`curv_fact_elec_trans`, `curv_fact_colim`, `b`, `c`, `psi_crit`, `beta2`, `g1_TF24`, plus `rho`
and `a_bio`.

Read from the merged code, `TF24_Strategy::prepare_strategy` passes **13** `pars.*` arguments
into `Leaf`'s constructor:

    pars.vcmax_25  pars.c  pars.b  pars.psi_crit  pars.root_c  pars.root_b
    pars.root_psi_crit  pars.beta2  pars.jmax_25  pars.a
    pars.curv_fact_elec_trans  pars.curv_fact_colim  pars.g1_TF24

So the report **omits three** — `root_c`, `root_b`, `root_psi_crit` — and **includes two that
arrive by a different route**: `rho` and `a_bio` are `set_physiology` arguments, per solve, not
construction-time parameters seeded once per run. That distinction is load-bearing for a supplied
local Jacobian, which must know which of its inputs are fixed for the run and which move per
call.

Report 02's C5 predicted this precisely: *"§6.8's input list was assembled by reading
`set_physiology`'s signature and would silently become incomplete if that signature grew — and
one entry has already been found dead that way."* It was assembled from `set_physiology`, which
is exactly why the three constructor-only root parameters are absent. The report is consistent
about its method; the method was incomplete, and it said so.

This also sharpens the trait-registration finding above. Thirteen registered parameters flatten
to exactly zero at the leaf boundary, and thirteen `pars.*` arguments cross that boundary — but
they are **not the same thirteen**. `p_50` and `K_s` are not constructor arguments: `p_50`
reaches the leaf through the derived `b`, and `K_s` through
`leaf_specific_conductance_max` on the per-solve path. So the flattening happens by two
mechanisms, at two different times in a run, and a Jacobian that treats them uniformly will be
wrong about which are constant.

**Proposed corrections, not taken** — reports are reference and are corrected with a one-line
note rather than rewritten:

- `reports/02` §6.8: the parameter count is 13 at construction plus the per-solve
  `set_physiology` arguments; `rho` and `a_bio` belong to the second group, and `root_c`,
  `root_b`, `root_psi_crit` to the first.
- `reports/03` §5: the drop-in claim holds for the type's surface but not for the abscissa —
  `ResourceSpline` cannot hold `basic_interpolator` and accept an active height, which is what
  the accessor now asks for.

## Cleared against the reports

- **Report 01 §4.1's block boundary** — knot *slopes* are named as block inputs, and nothing in
  Phase 1 supplies them to a block. Correct: the field carries no slope yet, and report 03 §8's
  step 1 and P2.2 own that. The Hermite carrying slopes is the primitive, not the wiring.
- **Report 01 §6.2's `ode_rates_adjoint`** — a new System requirement, Phase 3's. Phase 1 landed
  its odelia half, `Step<System>::step_adjoint`, which is the stage recursion the report says
  cannot live in plant because the tableau is private there. Consistent.
- **Report 04 §7.2's two-pass `Species::compute_rates`** and the `Node` accessors it needs —
  untouched, correctly, as that is P2.4.
- **Report 00 §7's "free" rows** — `dθ/dφ`, `dψ_i/dθ_i`, the bidiagonal soil, the write-only flux
  accumulators. Nothing in Phase 1 closes any of them; the half-templated environment leaves the
  soil in `double`, which is consistent with those channels being closed-form rather than taped.
  Whether that is by design or by coincidence is the decision finding 1 and the environment seam
  both point at.

---

# Addendum: the replay grid, and the two callers of `run()`

## The step-size record fixes a defect that is latent in odelia and live in plant

The trajectory record carries `(t, h, y)` because `h` is not recoverable from the times:
`fl(fl(t + h) − t) ≠ h`. That is settled by `build-plan.md` §2.8, whose control flow records and
consumes `(t, h, y)` per accepted step. §2.9's prose says "the ODE step times" and its storage table
lists only state, which is the looser statement, and it is the one both earlier trajectory-store
packets were written from.

Attempting to make odelia's *own* gradient driver replay over step sizes was reverted, and the
measurement is why: **no gradient reachable from R in odelia moves at all.** The only
recorded-replay gradient is the canopy one at `t ∈ [0, 2]` over 10 steps, where `ulp(t) ≈ 2e-16`
against `h ≈ 0.2` — the bits a time-driven replay discards fall below the last bit of the state.
The effect needs `t ≫ h`: at `t ≈ 100`, `ulp(t) ≈ 1.4e-14` against `h ≈ 0.02`, which is where
`test-step-record.R` measures 3 of 3 components differing by up to `2.92388e-12`. So the defect is
**latent in odelia and live in plant's `t ≈ 105` run**, and plant reaches the fix through
`advance_fixed_steps` directly, without `run()` being touched.

Every gradient and every AD-versus-FD residual was measured three ways — under the change, under
the revert, and on a clean reinstall of the base — and was bit-identical every time. The code is
byte-identical to base; what landed is the documentation of the finding and two test assertions.

## `Solver::run()` serves two operations through one door

Found by trying to change it. Both callers reach `run()` through `set_schedule()`, and the vector
alone does not say which was meant:

- **Replay a recorded adaptive trajectory** — `src/canopy_interface.cpp` records an adaptive pass
  on a double solver and hands its own recording to the active twin. `jacobian_on_double`'s comment
  says so at the call: *"hand the recorded L1 schedule to the active twin"*.
- **Differentiate a solve over a caller-supplied time grid** — `Solver_gradient_final_state`,
  `Solver_jacobian_final_state` and `Solver_value_and_gradient` in `src/lorenz_interface.cpp`,
  through `gradient_on_double` / `jacobian_on_double` / `Solver_value_and_gradient_impl` in
  `inst/include/odelia/solver_interface.hpp`. In `test-ad-jacobian.R` and `test-ad-functional.R`
  that grid is `seq(0, 1, length.out = 11)`, with the finite-difference oracle beside it being
  `solver$advance_fixed(times)` in R. **The grid is the specification; there is no recording, and
  nothing for a step size to be more faithful to.**

Making `run()` step by sizes unconditionally therefore broke nine tests of a working feature with
`First element in 'step_sizes' must be NaN`. The alternative offered was to branch on
`std::isnan(front())` — sniffing the data to guess which operation the caller meant. Neither is
right, and the packet stopped rather than choose.

**Owed: two explicit entry points**, so a recording and a specification are distinguished by the
caller rather than by inspection of the vector. Recorded in `AUTODIFF.md`, not implemented.

Also owed, and smaller: `AUTODIFF.md`'s pre-existing line *"`recorded_steps()` is the single source
of the replay grid"* is true of the recorded-replay operation and reads as though it covered the
caller-supplied grid, which arrives from R and never passes through `recorded_steps()`.

## These three entry points are not a superseded stub, and the history says so plainly

Worth settling, because "early AD stubs we are superseding" is the natural reading and it is wrong.
`Solver_gradient_final_state`, `Solver_jacobian_final_state` and `Solver_value_and_gradient` were
introduced in **the same commit** as `compute_jacobian`, `compute_gradient`,
`DifferentiationTargets`, `gradient_on_double` and `jacobian_on_double` — `dac5077`, 2026-07-10.
They were born together as one deliberate three-tier layering, and that commit is itself the
*retirement* of the spike:

> Replace the spike's hard-coded sum-of-squares gradient with the generic reverse-mode AD driver.
> … Retires the orphaned duplicate `Solver_*_impl` block from `ode_interface.cpp`.

So the early stub — a hard-coded sum-of-squares gradient and a duplicated `Solver_*_impl` block —
was already removed by the commit that created these. The layering it left has a job per tier:
`compute_jacobian` delegates record-once/row-sweep to vendored XAD; `gradient_on_double` /
`jacobian_on_double` lift the active twin via `rebind_from` and hand it the schedule; and the three
`Solver_*` entry points keep the twin invisible — *"built internally per call, and never seen by R
— no `active` flag, no active XPtr."*

`Solver_value_and_gradient` also has a purpose the others do not: it is the **calibration** entry,
sharing one tape between an optimiser's `fn` and `gr`, where an arbitrary functional goes through
the other two.

**Consequence for the owed work:** it is not a deletion. The distinction to make explicit is at
`set_schedule()`, and `LeafSolver_value_and_gradient` in the leaf example uses the same path, so it
is not confined to Lorenz.
