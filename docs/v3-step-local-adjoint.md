# Step-local adjoint — the deferred engine change, in implementation detail

**Status: DEFERRED, designed, not built.** The decision to defer is deliberate and
recorded in §0. The design search that selected it is
[`v3-reverse-memory-design.md`](./v3-reverse-memory-design.md); this document is the
implementation-level record so the work can be picked up cold.

---

## 0. Why deferred, and what still needs it

The owner's sequencing (2026-07-26) is leanness first (option C), this second. That is
defensible on its own terms: C is incremental, ships value per lever, breaks no
contract, and leaves this change's per-step tape smaller when it does land.

But C has a measured ceiling, and it is not enough for TF24. Taking K93's 2 150
B/cohort-step as the SCM skeleton, FF16's crown as 40 372 and TF24's leaf as a further
37 196:

| after | FF16 | TF24 |
|---|---|---|
| crown preaccumulation (~12×) | 7.7× | 1.9× |
| + analytic p\* residual (2.7× on the leaf) | 7.7× | 4.1× |
| + `incomplete_gamma` analytic partials | 7.7× | 5.6× |
| + expression fusion (~1.3× everywhere) | **10.0×** | **7.3×** |
| **required at `max_patch_lifetime = 105.32`** | **≥ 8×** | **≥ 15–45×** |

**So C closes FF16 and does not close TF24.** C takes TF24 from OOM-at-`life=4` to
roughly `life=20–40`, which is enough to unblock the #27 FD gate and
`test-ad-tf24-scm-gradient.R` test 1 — but a TF24 census gradient at production patch
lifetime needs this document. That is the trigger to build it: **TF24 wanted at
`max_patch_lifetime` ≳ 40.**

> **CORRECTION (session 21, measured).** The table's crown row is wrong. The 12× was an
> estimate; the crown was then measured at every boundary
> (`v3-reverse-memory-design.md` §6e, probe under `docs/reference/`): the achievable factor
> is **1.49×** with the light reads left on the run tape, **3.7×** with them moved inside,
> because the field read is **66%** of the crown tape rather than the 29% assumed. Re-run
> the table with 3.7× in that row and **C's ceiling falls to ~3× for FF16 and ~5× for
> TF24 — so leanness alone reaches production lifetime for neither strategy.**
>
> The trigger therefore widens: it is no longer only "TF24 beyond `life` ≈ 40" but
> **FF16's only remaining route to `life = 105.32`** as well. The deferral above was
> priced against a C that could close FF16; it cannot.

The second trigger is unrelated to memory: this change makes peak memory *independent*
of patch lifetime, so it is also what stops R2 being re-asked every time someone raises
the lifetime.

---

## 1. The commitment

> **The tape never spans more than one integration step.** Reversal happens on the
> run's own recurrence; what crosses between steps is a state adjoint vector of
> `double`, not tape.

Kept true by structure, not discipline: the driver `resetTo`s the step's start position
after each sweep, so a tape spanning two steps is not constructible, and the
cross-boundary quantity is `std::vector<double>`, so carrying an active value across a
step is not expressible in the type.

## 2. The algorithm

Let the run be `y_{k+1} = Φ_k(y_k, θ)` for k = 0…N−1 on the recorded L1 grid, and the
functional `J = Ψ(y_N, θ)`.

**Forward pass (double, once).** Run adaptively as today to discover the schedule, then
replay in `double` storing `y_k` at every step start. Only step-start states are
needed — re-recording a step reproduces its RK stages exactly — so this is
`steps × width × 8` bytes: **0.92 MB** at TF24 `life=3`, ~2.9 MB at `life=105`.

**Seed.** Record `Ψ` alone on a fresh tape with `y_N` as input; sweep to get
`λ_N = ∂J/∂y_N` and the direct term `∂J/∂θ`.

**Backward pass, k = N−1 … 0.** For each step:

1. `pos = tape.getPosition()`
2. load `y_k` into the System (`set_ode_state`), register `y_k` and θ as inputs
3. record exactly one step: `advance_fixed({t_k, t_{k+1}})`
4. seed the output adjoints with `λ_{k+1}` and sweep (`computeAdjointsTo(pos)`)
5. read `λ_k` off the state inputs; **accumulate** `∂J/∂θ +=` the θ derivatives
6. `tape.resetTo(pos)`

Each step is recorded exactly once more than the forward pass — recompute factor **1**,
which is the optimum. This is not Revolve and has no log factor, because the trajectory
is cheap enough to store in full (§0 of the design doc: 10 000× smaller than its tape).

**Peak tape = one step:** 47 MB at TF24 `life=3` against 9.20 GB; ~51 MB at FF16
`life=105` against OOM.

**Exactness.** This is the same chain-rule product as the whole-run sweep, merely
associated right-to-left in blocks. It is *exact*, not an approximation — unlike the
continuous adjoint (integrating an adjoint ODE), which would carry its own
discretisation error. Expect agreement with the whole-run tape to round-off.

## 3. What plant already provides

No new segmentation concept is needed. `SCM::run_next_impl` is already
`[grow][resize][integrate]`, and `solver.advance_fixed(e.times)` already advances a
given step list from a set state. `recorded_steps()` remains the single source of the
grid, so the "forgot to record" guard does not move. `set_ode_state` already
recomputes the light field and reconstructs density from spacing.

XAD already provides every primitive: `getPosition`, `resetTo`, `computeAdjointsTo`,
`clearDerivativesAfter`. **No `CheckpointCallback`, no nested recording, no recompute
schedule.**

## 3a. CORRECTION (session 21): the replay surface is a contract change, and it is B's real prerequisite

§3 above claims "no new segmentation concept is needed". That is true of the *schedule* and
false of the *replay surface*. Two facts, both read off the current code before any driver
was written:

**(i) The driver only knows how to replay the WHOLE run.** `compute_jacobian` duck-types
its solver on six members — `tape`, `get_system_ref`, `ad_parameters`,
`ad_initial_state`, `reset`, `run` — and `run()` is opaque. `soil_leaf`'s `Runner::run()`
is the witness: three `advance_fixed` segments with `sys.introduce()` between them, so its
step sequence *and its two state-dimension changes* are sealed inside one call. A backward
pass cannot index into that. So B needs the run re-expressible as an indexed sequence —
"advance step k from state y" — and that is one genuinely new concept on the interface
every differentiable System presents, not merely a new driver behind the old one.

**(ii) The `replay_step()` hook assumes the pass is monotone, and the two implementations
disagree about it.** `CanopySystem::replay_step()` reads `positions_history.at(step)` and
then `++step` — a private cursor that only walks forward. `Patch::replay_step()` instead
*resolves* its index from `time()`, with a sequential fast path and a `std::find`
fallback, so it already tolerates arbitrary order. **A backward pass would therefore be
silently wrong on one System and correct on the other** — §4.4's failure shape exactly, and
invisible because each is self-consistent on a forward replay.

**The fix for (ii) is a DX win independent of B, and it should land first:** pass the step
index to the hook — `replay_step(std::size_t k)`. Then `CanopySystem` loses its cursor
member and `Patch` loses its time search and its `idx`; neither has to *infer* where it is,
because the Solver already knows. That is a hook whose signature changes rather than a hook
added, it deletes state from both implementations, and it makes "the cursor and the
schedule cannot go inconsistent" structural — the same argument that makes
`recorded_steps()` the single source of the grid.

**Sequencing this implies**, and it differs from §7's ladder: (1) index the replay hook in
both repos, verified by the existing suites — self-contained, and correct whether or not B
proceeds; (2) settle the indexed-step contract that replaces the opaque `run()`, under
`system-design`, since it is a shared-interface concept; (3) only then write the driver,
starting at `soil_leaf` — which is the right first witness precisely *because* its
`introduce()` calls make it the hard case for (2), not the easy one.

## 4. The five things that can make it silently wrong

Ordered by how easy each is to miss. (1) and (2) are the ones to design against; the
rest are checklist items.

**4.1 The cohort-introduction adjoint jump.** A newborn's IC reads the active stand
(`density = birth·pr_estab/g`), so at an introduction the newborn's adjoint feeds back
into the standing state's adjoint. Under the whole-run tape this is just more tape and
comes out automatically; here it is a distinct term at a distinct boundary. Treat the
introduction as its own recorded segment — it already is one — and sweep it exactly
like a step. The state dimension changes across it, so `λ` changes length: entries for
not-yet-born cohorts simply do not exist before it.

**4.2 Time-distributed functionals lose their current contract.** `least_squares`
reads `solver.get_history_step(idx)` and holds those **intermediate** states as active
values (`gradient.hpp:226`). Under this design they are stored `double`s on no tape, so
it **cannot work as written**. The replacement is standard: an observation at step *j*
contributes `∂L/∂y_j` into `λ_j` during the backward pass. But that changes the
functional contract from *"a pure reduction of the positioned solver"* to *"declare the
steps you read and contribute a per-step adjoint seed"* — a new concept in a documented
interface, and calibration is one of `AUTODIFF.md`'s three axes, so it is not a corner
case. **Convert `least_squares` as part of this work, not after it.** Final-state
functionals (census, R0/offspring) are unaffected and need no change.

**4.3 Re-recording must be bit-deterministic from the stored state — now an
invariant, not an accident.** Verified today: TF24's `find_root_collar_psi` runs a
fresh `golden_section_max` over bounds from `prepare_collar_solve`, derived from the
current soil state, so the leaf operating point is a pure function of (state, traits)
and re-recording reproduces it. `decide()` value-branches are already recorded and
replayed frozen. **But** any future warm-start in a strategy's inner solver — seeding
the collar bracket from the previous step's answer is an obvious speed idea — would make
the step path-dependent and break the gradient *silently*, with every double test still
green. This is a new foot-gun class; it wants a structural guard, not a comment.

**4.4 The stored trajectory must be complete.** Everything a step reads must be
restored by `set_ode_state`, including derived caches: aux slots, the light field, and
TF24's `psi_soil_inverted_` / `root_vuln_integral_soil_`. Anything cached but not
re-derived is the reset-timing bug in a new location — the same silent, plausible,
wrong failure shape as populating the L3 cache or precomputing in a constructor.

**4.5 Parameter-adjoint accumulation is hand-rolled.** XAD zeroes derivatives per
recording, so `∂J/∂θ` must accumulate into odelia's own `double` across steps; a lost
or double-counted step is silent. This also means dropping `xad::computeJacobian`,
which currently owns record-once/sweep-m-rows — odelia hand-rolls m sweeps per step
(carrying m `λ` vectors, so the census vector still costs **one** backward pass). That
cuts against "invoke the vendored facilities, don't re-implement them", so keep the
hand-rolled loop to one place.

## 5. What it settles

- **There is no growing tape.** A one-step tape cannot outlive a `resize()`, so
  `test-ad-growing-resize.R`'s subject becomes *unreachable* rather than verified, and
  `reserve_state` stops being a question. This is the concern that "the odelia + SCM
  bridge has never felt quite right" — it dissolves rather than being managed.
- No checkpoint schedule, no callback type, no recompute policy; the recompute factor
  is fixed at 1 by construction.
- Peak memory stops depending on patch lifetime.
- Crown preaccumulation becomes redundant *as a memory measure* (§0 of the design doc
  ranks it break-even on time), so if this lands first, that lever can be skipped.
- Strategy code does not change at all — this is entirely inside odelia's driver, so
  the DX objective is untouched.

## 6. Cost

~2× active-run wall time (each step's forward is recorded once more). Plus §4.2's
contract change. Debuggability improves: a wrong adjoint localises to one step.

## 7. Verification plan

1. **`soil_leaf` first** (odelia, seconds per iteration). It is the right witness: a
   node inside `ode_rates`, a mid-run `introduce()` that exercises §4.1, a closed
   feedback loop, and an existing re-integrating FD reference it already matches to
   <1e-9. Gate: same gradient **and** peak tape flat in step count.
2. **K93 in plant** — cheapest full SCM, and its 0.75 GB whole-run tape is a working
   AD-vs-AD oracle.
3. **FF16, then TF24**, keeping the whole-run driver available as the oracle at short
   lifetime, plus the forward `⟨Jv,u⟩=⟨v,Jᵀu⟩` check, which shares none of this
   design's machinery and is therefore the only truly independent one.
4. **Acceptance is a number:** FF16 and TF24 census + R0 gradients at
   `max_patch_lifetime = 105.32`, under 2 GB peak, FD-verified per the tight-τ
   frozen-schedule reference in `oracle/oracle-response-inner-argmax-adjoint.md`.

## 8. Naming constraint

The end state is that **`compute_jacobian` *is* step-local** — not a sibling. A
parallel `compute_jacobian_stepwise` would add a name and a choice to every caller
while removing neither, which is exactly the DX failure mode the objective names.
Develop behind a branch if that is safer, but delete the branch before calling it done.

## 9. Kill condition

If per-cohort state ever grows until the stored trajectory is comparable to its tape,
the premise fails and **checkpointing** (trading that storage back for recompute)
becomes correct after all. The ratio is 10 000× today; it is the number to watch.

---

## 3b. Step (2) settled: the unit is the event segment, and `run()` becomes derived

`system-design`, session 21. **Triage 2** — a contract member on the interface every
differentiable System presents.

### Requirements ledger

- **R1** — B's backward pass must be expressible against every differentiable System:
  index the run, restore unit k's start state, record exactly unit k, sweep, discard.
  **Quantity: 4 implementors** — odelia `Solver`, `soil_leaf::Runner`, plant `SCM`, plant
  `IndividualRunner`.
- **R2** — peak tape ≤ one unit. **Measured (FF16, `life` 4/10/40): 95/110/145 ODE steps
  against 86/93/108 introductions = 1.10/1.18/1.34 ODE steps per event segment.**
- **R3** — concept count = new members × implementors.
- **R5** — the value stays bit-reproducible, so the forward pass must remain today's code.
- **R6** — first-order-blind sites stay enumerable. B adds none; it is exact.

**Scarce resource: new members every differentiable System must implement.** This is the
finding that decides the design — at unit = one ODE step peak tape is ~55 MB (FF16
`life=105`), at unit = one event segment it is ~74 MB, and R2's target is 2 GB, so **both
pass with 27–36× margin. Memory does not choose the unit; concept count does.** Therefore
choose the unit the code already has.

### The floor

**Add nothing: `set_schedule(sub-grid)` + `run()` + the existing `history`.** All three
exist, and `history` already stores per-unit `System` copies under `collect`, which is the
stored trajectory *and* is complete in §4.4's sense (derived caches included).

**It fails R1, on the SCM specifically.** `SCM::set_schedule` does not just set the L1
grid — it calls `node_schedule.r_set_ode_times` and `r_set_use_ode_times(true)`, so the
grid and the **introduction schedule** are the same act. Handing it a two-point sub-grid
truncates the node schedule and silently drops the introductions inside the window. The
floor cannot express "replay just unit k" for the one implementor that matters most.

### Candidates

- **A [first thought]** *(move 3: move the boundary)* — `unit_count()`, `restore(k)`,
  `advance_unit(k)`: **3 new members × 4 implementors**. Pays R1 directly. Costs: a second
  control flow alongside `run()`, which is the cost §4 charged candidate A of the original
  search. Wins when the backward pass genuinely needs to do something the forward pass
  never does.
- **B** *(move 2: record → replay)* — the forward pass records its own segmentation, so
  add one Solver-side member `replay_unit(k)` and nothing to the System. **1 new member ×
  2 schedule owners.** Wins when the recording already knows the unit boundaries — it does.
- **C** *(move 6: Pólya with witnesses)* — as B, **and re-express `run()` as
  `for (k = 0; k < unit_count(); ++k) replay_unit(k);`**. Then `replay_unit` is not a
  concept added beside `run()`; it is the loop body that already exists in all four
  implementors, named, with `run()` derived from it. Wins when the whole-run replay and the
  per-unit replay must be the same code — which R5 requires.

**Winner: C.** A is eliminated on R3 and on the second control flow (3 members × 4
implementors, and a backward path that can drift from the forward one — the defect R5
exists to prevent). B is C without the last step, and leaves `run()` as an independent
body that can disagree with the loop; the deletion pass below removes it.

### The commitment

> **A run is a sequence of independently replayable units, and the whole-run replay is
> derived from that sequence rather than the other way round.**

**Kept true by:** `run()` having no body of its own beyond the loop over `replay_unit(k)`.
A unit that cannot be replayed standalone therefore cannot be part of a run — the forward
pass would not work either, so the backward pass cannot be the only thing that breaks. This
is what removes B's "second control flow" cost entirely: there is one replay path, used
forwards by `run()` and out of order by the adjoint driver.

**The unit is the event segment** — `[introduce][integrate to the next introduction]` —
because that is what `SCM::run_next_impl` and `soil_leaf::Runner`'s three segments already
are, and R2's measurement says it costs 1.34× the theoretical minimum peak, against 27× of
margin. Choosing the ODE step instead would buy 1.34× of memory nobody needs and require a
decomposition neither implementor has.

**Consequence for §4.1:** the cohort-introduction adjoint jump stops being a special
boundary. An introduction is *inside* a unit, so its adjoint is recorded and swept with the
rest of that unit's tape — no distinct term, no separate segment to get right.

### Kill question

**Assumption whose falsity makes this unnecessary:** that the backward pass must reuse the
forward pass's code. If a backward-only path were acceptable, the driver could hand-roll
the stepping and no contract would change.

**Verdict: survives.** R5 requires the replayed value to be bit-reproducible, and §4.3
requires re-recording a unit to be bit-deterministic from its stored state. Both are
properties of *the same code running twice*; under a separate backward path they degrade
from structure to convention, and the warm-start foot-gun in §4.3 becomes undetectable.

### What survives deletion

- **`replay_unit(k)`** → R1 (nothing else can express the backward pass) and R5 (one path).
- **`unit_count()`** → R1: the driver must know how many units to walk, and it is not
  `recorded_steps().size()` — units are segments, steps are 1.10–1.34× as many.
- **`run()`'s body** → nothing. It becomes the two-line loop, so it is deleted, not added to.
- **`restore(k)` / `advance_unit(k)` as separate members** → nothing. Restoration is part of
  replaying a unit, and splitting them invites a caller that advances without restoring.

### What this makes hard

Peak tape is 1.34× larger than a per-ODE-step design, and a unit containing an unusually
long integration gap (the resume path, where `e.time_introduction() > t0`) is one unit
however many steps it holds — so a resumed run has one oversized unit. Coped with by
splitting only that case, if it ever binds; the ordinary path introduces at nearly every
step, which is exactly why it does not bind today.

### Kill condition

**A run whose units stop being small** — a strategy that introduces rarely, so segments hold
many ODE steps and one unit's tape approaches the budget. The measured ratio (1.10–1.34) is
the number to watch; at ~30 steps per segment the ODE step becomes the right unit and
candidate A's finer decomposition is the retrofit.

### 3b-i. Refinement found while shaping the driver: restoration needs a handed-over trajectory

§3b says two members. Writing `replay_unit(k)` shows it is **three**, and the third one
is not a new *kind* of thing.

`replay_unit(k)` must restore unit k's start state, and it cannot restore it from its own
`history`: the double forward pass is what *populates* the trajectory, so on the active
pass the trajectory has to arrive from outside. That is already how every other recorded
layer crosses the double→active boundary — L1 via `set_schedule`, L2/L3 via
`set_recording`. So the trajectory is handed over the same way, and **it is best understood
as a fourth recording layer rather than a new mechanism**: call it the recorded *state*
trajectory alongside the recorded schedule (L1), node positions (L2) and field values (L3).
`Solver::history` (a `std::vector<System>` populated under `collect`) is already exactly
this, and for plant it is already complete in §4.4's sense because it holds whole `System`
copies including derived caches.

**Members, final: `unit_count()`, `replay_unit(k)`, `set_trajectory(...)`** — with `run()`
derived from the first two, and the third joining the existing hand-over family.

The alternative — the driver calls `set_state(y_k, t_k)` itself and `replay_unit(k)` only
advances — was rejected: it splits restore from advance, so a caller that advances without
restoring is expressible, which is the silent-wrongness shape §4.4 warns about. Keeping
restoration inside `replay_unit` is what makes the misuse inexpressible.

**This is where step (3) starts.** Nothing above requires further design; the next action is
code: add the three members to odelia's `Solver`, re-express `run()` as the loop, mirror
them on `soil_leaf::Runner`, and only then write the driver. The existing gradient must be
bit-identical after the `run()` re-expression alone — verify that before the driver exists,
because it isolates "the loop is the same loop" from "the adjoint is right".
