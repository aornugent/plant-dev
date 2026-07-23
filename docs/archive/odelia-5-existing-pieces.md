# odelia design #5 — a pass over the existing engine pieces (making the build plan comprehensive)

The four new components (#1 scan, #2 implicit-node, #3 γ node, #4 firewall) are the *new* machinery.
This pass audits the pieces odelia **already has** so the build plan is comprehensive, not just the
deltas. Each piece: current state (grounded in the code), verdict, build-plan action. Tier is per-piece
(most are Tier 1–2 — keep/rename/simplify — not new designs).

## 1. Solver ↔ SCM interface — **keep the composition; formalize the Runnable contract; a Solver change is flagged, not taken**
**Current.** `odelia::ode::Solver<System>` is explicitly a *wrapper for simple systems* — its own comment
(`ode_solver.hpp:27–30`): "You would only write your own if you had system-specific needs, e.g. events,
cohort introductions." plant's SCM does exactly that: it **HAS-A** `Solver<patch_type>` (`scm.h:138`) and
owns the `[grow][resize][integrate]` loop (`run_next_impl`: introduce nodes due → `set_state_from_system`
(resize) → `advance_adaptive` to the next introduction), delegating the *stepping* to the Solver. The
gradient driver duck-types the runnable via `reset()`/`run()`/`get_system_ref()`/`tape`/`value_type`;
odelia's `Solver::run()` = `advance_fixed(replay_schedule_)` (the simple case), which the SCM overrides
with its self-segmenting run.

**Verdict (revised by [odelia #6](./odelia-6-boundary-tape-checkpoint.md) — no new name).** The
composition is sound and works. My earlier recommendation here — "formalize a `Runnable` concept" — was
**overbuilt** and is withdrawn: a `concept` would relocate the duck-typed surface into a name without
removing a bug class (the load-bearing guarantee, "the tape survives a mid-run resize," is a *runtime*
property a `concept` can't check — a test checks it, and one exists). Per the concept-count scarce
resource, the floor wins: **document the driver's ~5 required methods in a call-site comment** and keep
the growing-resize **test** as the guarantee. **0 new named concepts.**

**Flagged (deferred, one witness).** odelia's `Solver` could grow a native introduction hook and own the
segmentation loop, making the SCM a plain System (candidate C in odelia #6). Cleaner layering, but one
witness → the YAGNI trap. *Retrofit trigger:* a second growing-dimension System. This is the "clean up
post hoc" option. **No Solver structural change in v1; no new concept in v1.**

**Build-plan action:** a call-site comment on `compute_jacobian` listing the runnable methods; rely on
the existing `test-ad-growing-resize.R`. No `Runnable` type. Record C + its trigger.

## 2. The "driver" — **a naming fix (three-way clash)**
**Current.** "The driver" in `AUTODIFF.md`/`gradient.hpp` = the **gradient driver**
(`compute_jacobian`/`compute_gradient`/`compute_jvp`) — it owns record/seed/sweep/reduce, **never** the
schedule (`gradient.hpp:40–42`). The word collides three ways: (a) the intuition that the *Solver/SCM*
"drives" the ODE stepper; (b) plant's **`ExtrinsicDrivers`** (external forcings — rainfall/PPFD/…); (c)
the odelia demo systems carry drivers too.

**Verdict.** Naming only — the functions are already `compute_*`. Fix the *prose*: always "the **gradient
driver**" (or "the reduce loop"), never bare "driver"; reserve "drives" for the stepper and "extrinsic
drivers" for forcings. (Check the odelia demo `LeafThermalSystem` — confirm whether its drivers are even
exercised; if a dead driver member confuses readers, drop it.)

**Build-plan action:** doc pass renaming bare "driver" → "gradient driver"; a glossary line disambiguating
the three; audit the demo systems' driver members.

## 3. `reserve_state` — **exists; do NOT mandate; profile-gated**
**Current.** `Solver::reserve_state(n)` exists (`ode_solver.hpp:104`) but the gradient driver never calls
it; plant v1 didn't use it and the tape grew fine (slots are indices preserved across the `AReal` copy a
`vector` realloc does). **`std::vector` geometric growth ⇒ amortized O(N) copies total**, not O(N²) — so
the realloc cost is O(N) cheap slot-preserving copies over a run, dominated by the O(N·steps) integration.

**Verdict (revised by odelia #6 — deletion candidate).** The spike confirms `AReal` holds a slot *index*,
so the realloc is amortized-O(N) slot-preserving POD moves (the tape is immune) — `reserve_state` buys
~nothing. An unused abstraction is the same debt as an unneeded one, so it should be **deleted unless a
profile surprises us**: a ~5-line timing spike on `test-ad-growing-resize.R` (with vs without); if no
benefit (expected), remove `reserve_state` from odelia; if a per-`AReal`-move tape cost appears (I could
not fully rule it out from the headers), keep it and call it once. Not on the critical path either way.

**Build-plan action:** profile → **delete `reserve_state` or keep-and-call**; default expectation is
delete. Low priority.

## 4. Checkpointing (RK-step / introduction boundary) — **evaluate, don't pre-build**
**Current.** The gradient driver records **one tape** for the whole run and sweeps `m` rows over it
(`computeJacobian`); the forward `reset()+run()` happens once. Peak tape memory = the whole SCM run
(10³–10⁵ steps × growing N); the catalog estimated 0.5–4 GB (fits a workstation), and v1 never
checkpointed. The Oracle recommended checkpointing between RK steps / node introductions.

**Verdict.** Checkpointing trades **memory for recompute** (per-segment sub-tape re-run on the sweep) — a
memory optimization, not a correctness need. v1's one-tape approach worked because the budget fit. The
right move is **measure, then decide**: instrument peak tape memory on a realistic resident-census
gradient (largest N, longest horizon); if it breaches a budget (say > workstation RAM), checkpoint at the
**node-introduction boundary** (the natural segment edge — `XAD::CheckpointCallback` is vendored, and
odelia already uses it for `SuppliedDerivative`). Reserve the seam; don't build it blind.

**Build-plan action:** a memory-measurement task (peak tape bytes vs N, horizon); the introduction-boundary
`CheckpointCallback` seam reserved, gated on a measured breach.

## 5. Functionals — **sound; the multivariate case needs a test, not a redesign**
**Current.** A functional is any `{ codomain(); operator()(solver) → vector<S> }`; `compute_jacobian`
records once and sweeps `codomain` rows. So a **multi-metric** census (`codomain=m`) is already the
supported shape — one recording, m adjoint rows. `least_squares` (`gradient.hpp:226`) is the calibration
example; R0 would be another functional. The preliminary design (functional = general; R0 = applied
scalar; calibration = observations) holds.

**Verdict.** Correct as designed. What's *unverified* is the specific case plant needs: a **multi-variable,
multi-metric census** (weights `Ψ` reading several cohort state vars — height, area/mass_heartwood — and
several metrics at once), with the **cross-species** column layout (species-major) and the self-shading
cross-terms (`design.md` §8). The surface handles it; add a **test**. Cross-ref the user stories: persona
1 (forest ecologist) asks for exactly this (LAI + biomass + basal-area vs LMA + wood density);
persona 3 (calibration) is `least_squares`; persona 2 (mutant, deferred).

**Build-plan action:** a multi-metric, multi-variable, multi-species resident-census gradient **test**
(the persona-1 Jacobian), validated FD-free by the `compute_jvp` dot-product oracle + Gate-0 FD.

## 6. IC seeding — **plant now has it (78bd39); wire the AD side, sequence it**
**Current.** odelia supports+tests IC seeding (`ad_initial_state`, `DifferentiationTargets.ics`, the
LeafThermal test). The catalog said plant *stubbed* it — **now superseded**: plant#499 (commit `78bd39`,
"Initialise a patch from existing nodes," merged with the odelia #456 refactor) adds a clean
export/re-import primitive that seeds an **arbitrary initial size distribution at patch age 0**. So the
seed-at-age-0 IC path exists in plant.

**Verdict.** IC gradients are now tractable for the **age-0-seed** case (seed the initial node states
active, record from age 0, replay) — no resume conflict, because you record *from* the seeded state. The
**resume-from-mid-run-state** case (the `scm.h:231` ode-time-replay conflict) stays out (a different
workflow). The AD work is: wire `Patch::ad_initial_state()` to the 78bd39 age-0 node states; `d(metric)/
d(initial distribution)`.

**Build-plan action:** IC gradient sequenced after the resident core (as `design.md` §11 says) — wire
`ad_initial_state` to the 78bd39 seeded states + a test; the resume case remains a documented fence.

## 7. Replayable / interpolator / QAG — **simplify the interpolator; don't lift QAG; scope Replayable narrow**
**Current.** The `Replayable` concept (`record_stage`/`record_ode_step`/`replay_step`/`has_recorded_field`)
tidied early work. The interpolator accreted bandaids during the coupling-path era: the frozen
active-query derivative (odelia#38, the C3 17× ripple) and entanglement with geometric compression.
plant's QAG-adaptive is dormant (`max_iter=1`); the crown is fixed-rule QK.

**Verdict (enabled by odelia #1).** The scan (#1) took the separable coupling field, and the mass chart /
`TransportGeometry` took `dg/dh` — so the interpolator is **demoted to the non-separable fallback only**,
and the bandaids it grew for the coupling-path role are **no longer needed on it**: the frozen-query
derivative was for the coupling `∂A/∂z` (now the scan's exact read) and the compression entanglement is
now the `TransportGeometry`. So, opening the box: **simplify the interpolator back to a clean adaptive
spline** (record positions, recompute values active on replay) — shed the frozen-query and
compression code. **Do NOT lift QAG into odelia** — there is no adaptive-quadrature witness (crown = fixed
QK, P1f; leaf QAG = fixed); lifting a dormant mechanism generalizes over zero witnesses. **`Replayable`
scope shrinks** to: the fallback interpolator (L2) + the deferred mutant L3 — polish it to the pared
odelia#28 form and no more.

**Build-plan action:** simplify the interpolator (delete the frozen-query-derivative + compression
bandaids; keep clean construct/record/replay) — a **deletion**, sequenced with P1b (the scan makes it the
fallback); do not touch QAG; `Replayable` stays the odelia#28 pared concept.

## 8. L0 / L1 replay — **done and simple**
**Current.** L0 (cohort schedule) = the SCM's `refine_schedule`/node schedule, frozen up front; L1 (step
schedule) = the Solver's `recorded_steps()`/`set_schedule()`/`run()` (`advance_adaptive` to record,
`advance_fixed` to replay). Workflow coordination: run once adaptive, run again fixed.

**Verdict.** Nothing to design — simple and working. L3 deferred (mutant).

**Build-plan action:** none (confirm the SCM's run() interleaves L0 introductions with L1 `advance_fixed`
on the active replay — a test assertion, not new code).

## Summary — what this adds to the build plan
| Piece | Verdict | Action | Priority |
|---|---|---|---|
| Solver/SCM | keep composition | **call-site comment** + the growing-resize test (NO `Runnable` concept — see odelia #6); defer the odelia-owns-the-loop cleanup (1 witness) | low |
| "driver" | naming | prose → "gradient driver"; glossary vs `ExtrinsicDrivers`; audit demo drivers | low |
| `reserve_state` | deletion candidate | profile the resize; **delete** iff no benefit (expected) — else keep-and-call | low |
| checkpointing | evaluate | **measure peak tape memory**; introduction-boundary seam reserved, gated on a breach | med |
| functionals | sound | **multi-metric/var/species census test** (persona 1), oracle-checked | high |
| IC seeding | plant-done (78bd39) | wire `ad_initial_state` to the age-0 seed + test; resume-case fenced | med (sequenced) |
| interpolator | simplify | **delete** the frozen-query + compression bandaids (scan/mass-chart took them); don't lift QAG | med (with P1b) |
| L0/L1 | done | confirm the interleave with a test | done |

**Net:** no structural Solver change is required (the growing-Solver is flagged + deferred on one
witness); the build plan gains a Runnable-concept doc, three evaluate-then-decide items (reserve_state,
checkpointing memory, the resize profile), one deletion (interpolator bandaids), two tests (multi-metric
census, IC gradient), and a naming pass. IC seeding is *de-risked* (plant#499 landed it).
