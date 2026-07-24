# v3 Phase 1 — bring TF24/TF24f onto the primitives, minimal diff from base

The plan for the TF24 leaf wiring, derived from three session-18 investigations:
the code review (two structural findings), the git archaeology (no hidden-clean
commit; forward deletion beats revert), and the `leaf_output` design decision
(absorb it into `Leaf`). Read `v3-north-star.md` §4 first for the leaf design;
this doc is the executable sequence.

## The bar
The pristine pre-reverse-mode strategy is vendored at
`docs/reference/tf24-base-develop/` (develop merge-base). It is the DX bar: v3's
job is to add reverse-mode support with **as little divergence from those files as
possible**. Current drift is +796 lines across the TF24 leaf surface; ~300 of that
is deletable accretion (see below). Target: land near base + the FF16-shaped
templating tax + a thin leaf node map, and restore the property that the leaf
science is written **once** and reads like the original.

## The commitment (from the §-design decision, 2026-07-24)
> The leaf's output physiology is written once, as **scalar-generic closed-form
> methods on `Leaf`**; the double value path and the reverse-mode assembly call the
> same methods. No separate `leaf_output` namespace; no formula transcribed twice;
> no `xad::`/`tape`/`supplied_derivative`/`chain_sign`/`snapshot` token in the
> strategy TU.

Kept true by structure: the output methods are `template<class T>` (a double-only
second copy can't exist without deleting the template); the leaf *solver*
(`golden_section_max`/`uniroot`) keeps double-only signatures (an active scalar
cannot enter the iteration — taping it is inexpressible, so no OOM).

## Acceptance checks (grep-able)
1. `grep -cE 'xad::|\btape\b|supplied_derivative|chain_sign|snapshot' src/tf24_strategy.cpp` → **0** (FF16/K93 are 0 today; TF24 is 40+).
2. `grep -c 'namespace leaf_output' inst/include/plant/leaf_model.h` → **0**.
3. `grep -cE 'double Leaf::(assim_colimited|transpiration|electron_transport)\b' src/leaf_model.cpp` → **0** non-template copies (they became `template<class T>`).
4. odelia: `supplied_derivative.hpp` + its example **deleted** (the seam was its only caller).

## The sequence (each step small, Gate-0 checkable before the next)

### Step 1 — delete the seam, wire `assemble_leaf_from` directly
`net_mass_production_dt` (`src/tf24_strategy.cpp` ~555–715) opens a local `xad::Tape`,
records `assemble_leaf_from` on it, sweeps it, and injects partials via
`supplied_derivative`. `assemble_leaf_from` (726–889) is already an S-differentiable
run-tape-ready assembler (its `implicit_value` nodes inject the IFT edges). Delete
the local-tape block, `chain_sign`, the whole-leaf `snapshot`/restore,
`PLANT_TAPE_STATS`/`g_leaf_snap`, the `<chrono>`/`<odelia/supplied_derivative.hpp>`
includes; call `assemble_leaf_from` on the active `S` directly.
- **Gate-0:** the leaf gradient (p\*, profit, per-layer uptake) at a single cohort
  still FD-matches (the `weibull_leaf` cert pattern); value bit-identical to before.
- **Falls out:** in odelia, `supplied_derivative.hpp` + example are now orphaned →
  delete (acceptance check 4).

### Step 2 — make `Leaf`'s output methods scalar-generic (absorb `leaf_output`)
Move the closed forms into `Leaf` as `template<class T> T <name>(T…)` members, taking
the seeded params as **arguments** (they can't read the `double` members on the S
path). The already-closed-form methods (`assim_colimited`, `electron_transport`,
`arrh_curve`, `peak_arrh_curve`, `hydraulic_cost`) **collapse** onto the template
(the double value path calls `T=double`). The spline hydraulics
(`transpiration`/vulnerability) get the `incomplete_gamma` closed form as their
single source; keep the double spline **only** if `profile-plant` shows the double
path regresses, and then behind the same method (a `T==double` fast branch), never
as a separate namespace. `assemble_leaf_from` now calls `leaf.<name><S>(…)`.
- **Gate-0:** value-regression tests pass (closed form vs spline within tolerance —
  the closed form is the exact integral the spline approximated); the toy-witnessed
  channels (`root_b`/`root_c` via the series `d/dc`, the 3-branch `soil_uptake`) still
  FD-match at a single cohort.
- **Retrofit trigger for the spline:** double-path timing regression beyond tolerance
  (measure with `profile-plant`).

### Step 3 — fold the TF24f tracked collar into `assemble_leaf_from`
`seam_collar_psi_input()` (tf24_strategy.h ~274–279, overridden by TF24f) has one
legitimate use inside the keeper `assemble_leaf_from` (line ~828, the tracked-collar
branch). Fold that path in so the `seam_collar_*` hooks + the tf24f `psi_fd_step`
centred-FD collar gradient can go. This is the one genuine design step (not pure
deletion): TF24f's `q` is an ODE state read off the optimum; wire it as the tracked
regime of the same `assemble_leaf_from` (v3 §6, reuse `G(q)`).
- **Gate-0:** TF24f collar-ψ gradient FD-matches at a single cohort.

### Step 4 — delete the residual accretion + verify at scale
Delete `soil_consumption_active_` population (read `assemble_leaf_from`'s `cons_out`),
`dsoil_consumption_dpsi_collar_perlayer`, the double/S root-mass double-loop
(one path now), any leftover `fdseam` references. Then the closing gate:
- **Gate-0 → SCM:** run the acceptance greps (all pass); FD-verify the full
  TF24/TF24f SCM census gradient on a **frozen resolved schedule at tight inner τ**,
  δ in the valid window (task #27, `oracle-response-inner-argmax-adjoint.md`) — NOT a
  loose-FD ratio.
- **Memory:** one confirming `PLANT_TAPE_STATS=1` measurement (incomplete_gamma
  series × soil layers × cohort-steps); compare the curve to FF16's.

## Verification doctrine (do not relitigate)
- Gate-0 (single leaf/cohort, clean δ-swept FD) before any census FD.
- The three surfaces the plant wiring must re-certify but that are already
  toy-proven (so this is confirmation, not discovery): the resistance-network
  `soil_uptake` (incl. seeded `root_b`/`root_c`), the `E_column` bound-continuity
  residual, and the value-graft (`raw == truth` before trusting the grafted
  gradient). See `odelia/inst/examples/weibull_leaf_interface.cpp` (E)/(F)/(G).
- The SCM correctness anchor is the tight-τ frozen-schedule FD, never the loose-τ
  swept plateau (doctrine B).

## What is explicitly NOT in Phase 1
DeepCrown under AD stays stubbed (`assemble_leaf_from` is single-solve, like the
base; v3 §4.5 is separate). `field_ptrs()`/`*_AD_FIELDS` are load-bearing input
seeding (FF16/K93 use them) — not seam, do not touch. RODAS (~465 unused-by-plant
odelia lines) is a general odelia feature — surface to the maintainer, don't delete
here.
