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
