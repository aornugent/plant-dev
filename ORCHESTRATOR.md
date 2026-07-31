# Orchestrator

How a phase of this build is run: one session acting as architect, orchestrator and reviewer over
subagents that do the implementation in isolation. Written to be handed to a fresh session, and
carrying the concrete plan for Phase 1 at the end.

The division exists because an agent cannot assess its own completeness. What replaces
self-assessment is that **every packet's gate is a command whose output the orchestrator re-runs**.
Phase 0's record supports the division and locates the risk: the agents corrected the architect four
times and stopped on one real contradiction, while every serious error in the phase was an
unguarded architect edit. So the discipline below applies hardest to the orchestrator's own hands.

---

## 1. Rebuild context before designing anything

In this order, and in full rather than by grep:

1. `AGENTS.md` here, `plant/agents.md`, `odelia/AGENTS.md` — session start, build recipe, style.
2. `docs/build-plan.md` — the specification.
3. `docs/tf24-correctness.md` — the prerequisites and what has landed, at which commit.
4. `docs/implementation-notes.md` — the evidence, the pinned build, the standing lessons.
5. `docs/reports/00`–`04`, `07` for the phase in hand. They are develop-time analysis; read them
   against the landed table so a fixed defect is not re-planned.

Then establish ground truth rather than assuming it, because the tree moves between sessions:

- `git log`, `git status`, and **the submodule pointers**, in both `plant` and `odelia`. Confirm the
  base is where the plan says. Phase 1's was not.
- Confirm the pinned build took: a value gate that does not name its flags measures the compiler.
- Re-measure the reference forward run yourself. It is one build and one run, and it is the number
  every bit-identity gate in the phase is written against.

## 2. The packet

A packet is a bounded change whose gate someone who was not there can re-run. If the gate cannot be
written as a command with an expected answer, the packet is not ready to send. Every field, every
time:

1. **The change in one sentence, plus an explicit file allowlist.** Touching anything else is a
   deviation to report, not initiative.
2. **The gate as a command, with the expected form of the answer.** Not "verify it works".
3. **What it may not do:** no baseline regeneration, no adjacent tidying, no new files unless named,
   and no design choices — where two readings exist, report both and stop.
4. **Required reading by pointer** — the task's own section and the one report section carrying the
   mechanism. Not "the corpus".
5. **The build recipe verbatim**, including `rm -f src/*.o src/*.so` before every build.
6. **The style rules verbatim**, plus one before-and-after exemplar from the file being edited.
7. **Its own worktree, its own R library, its own scratch directory** (§4). Phase 0 lost work three
   times to shared scratch.
8. **Report format:** the diff, each gate's output pasted verbatim, and an explicit "what I could not
   do". Stated plainly: *do not report a gate as passing that you did not run.*
9. **Its own baseline first.** Take the base tree's reference number in the packet's own worktree
   before the first edit, and stop if it does not reproduce. Every later figure is then same-tree,
   same-session.

## 3. Sequence and fan-out, decided by dependency

Fan out what is independent; sequence what is not. Phase 0's twelve items were independent and ran
eight-wide. Phase 1 is a chain with two independent limbs, so it runs in waves (§7) and the spine
gets one agent at a time. Fanning out a dependency chain thrashes: the downstream agent rebases
onto a moving base and its bit-identity gate measures the rebase.

## 4. Environment isolation

Phase 0 needed one worktree per packet and nothing more, because it touched only `plant`. **Phase 1
edits `odelia` headers, and that changes the shape of the problem:** `plant` reaches those headers
through the *installed* `odelia`, and `odelia` must be a real install because `plant` resolves its
XAD `Tape` symbols at load time. Two agents installing `odelia` into the shared site library would
overwrite each other's headers and each would then build `plant` against the other's.

So each packet that touches `odelia` gets:

```sh
mkdir -p /home/user/lib-<packet>
export R_LIBS_USER=/home/user/lib-<packet>          # searched before the site library
Rscript -e 'install.packages("<odelia worktree>", repos = NULL, type = "source")'
```

and every subsequent `Rscript` in that packet keeps `R_LIBS_USER` set, so `LinkingTo` resolves
`odelia`'s include directory out of the packet's own library and the site library supplies
everything else. A packet that touches only `plant` needs no library of its own.

Worktrees: `git worktree add -b <branch> /home/user/wt-<packet> <base>`, about 19 MB and a 95 s
build each, which is what makes one per packet affordable. Scratch: `/home/user/p1/<packet>/`,
never the shared scratchpad.

## 5. Review

- **Re-run every gate.** An agent's "tests pass" is unverified until its output has appeared in the
  orchestrator's own session. A false pass is worse than a gate not run.
- **A mechanical sweep over every diff before it lands** — `/home/user/p0/style-sweep.sh` covers
  doc-section references, issue tags, decorative nouns, banners, `xad::` inside `plant`,
  deduced-return-type lambdas, comment runs over two lines, and touched baselines or generated
  files — **plus reading every comment line the orchestrator did not write.**
- **The cross-model tripwire on every merge, not at the end of the phase.** Phase 0's
  offspring-to-zero regression survived three steps because FF16 and K93 only ran once, at the end.
- **In Phase 1 the tripwire is bit-identity, which makes it cheap and absolute.** Nothing in this
  phase may move a number except the one item that is allowed to (§7, the environment's aux), and
  that one states in advance which assertions move and by how much.
- **When an agent reports a contradiction, investigate against the code before overriding it.**
- **Hold your own edits to packet discipline.** Anything hand-edited and called non-semantic gets a
  bit-identical gate before it is believed. Prefer to delegate even a revert as a packet.

## 6. Integrate, and record

One integration branch per phase. After each merge, **verify every change is present** rather than
trusting the auto-merge, then build once and run the tripwire. The composite number for the phase is
taken on the merged tree in one session; a per-item forward figure below about 0.15% in offspring
needs a mechanism, not a before-and-after pair. **Re-bless nothing** — recording a shift is the job,
accepting it is the owner's.

Recording is part of "done", not a pass afterwards. `implementation-notes.md` takes the commit, the
build, the gates as run, the shift where numbers moved, and anything the item revealed that the plan
did not predict — that last field is what earns the file. `build-plan.md` and `tf24-correctness.md`
take a commit tag and nothing else. Reports are reference, never edited to track progress, but a
forward-pointer that has become factually wrong is corrected with a one-line note that leaves the
develop-time analysis intact.

## 7. Standing hazards

- `pkgbuild::compile_dll()` defaults to `-O0` and appends its flags last; pass `debug = FALSE` and
  check a compile line ends at `-O2`.
- `rm -f src/*.o src/*.so` before every build. R's make does not track header dependencies and the
  core is header-inline, so a header edit otherwise fails to compile in — a silent false pass.
- `library(odelia)` from a real install, never `load_all` for odelia; `load_all` the plant tree under
  test; `Sys.setenv(TESTTHAT_PARALLEL = "false")`.
- R buffers `cat` to a redirect. Poll for the process to exit; do not read progress out of the file.
- `pkill -f <pattern>` matches the shell running it and will kill the session. Kill by PID.
- `run_scm(collect = TRUE)$species` is the flat per-step-per-node table; `$species[[1]]` is a column.
- Two like-typed positional arguments of unrelated meaning are a silent-swap hazard, and templating
  is when to re-check the call sites by meaning rather than by type.

---

# Phase 1, as planned

Nothing in Phase 1 computes a gradient. Its whole product is that the model *can* carry an active
scalar, that the plumbing no longer names `double`, and that a run's trajectory is stored.

## Ground truth, measured this session

**The base moved, and it is not what the plan says.** `origin/p0/phase-0` is now `7b05b55e`, which
merges upstream `develop` — five commits including six TF24 hydraulics fixes and a re-blessed
scenario baseline — into the Phase 0 tip. Six files are touched by both sides. Phase 1 branches from
`7b05b55e`, and PR #66 is still open, so Phase 1 stacks on it rather than on `develop`.

**All eight Phase 0 items survive the merge**, checked by reading the merged tree rather than
trusting it: the leaf's `assign` and `refresh_soil_potentials`, `n_resources()`, the recompute in
`introduce_new_nodes`, the crown-base branch, the establishment overloads, and
`consumption_rate` starting at `new_node`.

**The merge is numerically inert on this configuration.** At the pinned build, one species, five
layers, `max_patch_lifetime = 105.32`, `refine_schedule = FALSE`:

| | offspring production | accepted steps |
|---|---|---|
| `p0/phase-0` before the merge | `42.176246845059751` | 5 105 |
| `p0/phase-0` at `7b05b55e` | `42.176246845059751` | 5 105 |

Bit-identical, which is the useful result: **Phase 1's bit-identity target is unchanged**, and
upstream's TF24 work is invisible at the default driver — consistent with P0.5 measuring zero
incidence on the shutdown exits it hardens.

**odelia's base is not where the plan says either.** The plan calls for `854a8e18` "on `master`";
`854a8e18` is *not* on master, it is master plus thirteen commits of earlier AD-surface work, and
the submodule is checked out forty-five commits further along on the AD branch. Of the five names
P1.1 asks for, `implicit_value` and `hermite_interpolator` already exist on that branch and
`vector_jacobian_product`, `step_adjoint` and `OdeElement` exist nowhere.

## The dependency graph

```
P1.1a  odelia: OdeElement + the four range helpers ─┬─ P1.1b  vector_jacobian_product (T1–T3)
                                                    ├─ P1.1c  step_adjoint
                                                    ├─ P1.1d  implicit_value + hermite active read
                                                    └─ P1.2a  plant plumbing, S = double
                                                                 └─ P1.2b  TF24<S>, six commits
                                                                      ├─ P1.3  trait registration
P1.4  the trajectory store (independent throughout)                  └─ P1.5  the active build
```

`P1.4` touches `scm.h` and pure `double`, and depends on nothing here, so it runs from the start.
The spine is one agent at a time. `P1.5` is the one addition to the plan's task list and §9 argues
for it.

## Waves

| wave | packets | base |
|---|---|---|
| A | P1.1a, P1.4 | odelia `854a8e18`; plant `7b05b55e` |
| B | P1.1b, P1.1c, P1.1d | P1.1a's branch |
| C | P1.2a | plant `7b05b55e`, odelia at P1.1a |
| D | P1.2b — six commits, each bit-identical before the next | P1.2a's branch |
| E | P1.3, P1.5 | P1.2b's branch (P1.5 also needs P1.1b) |

Eight packets, and the wave boundaries are the barriers: B needs A's concept, C needs it installed,
D needs C's signatures, E needs D's templates. Within a wave the packets are independent and run
together.

## The packets

**P1.1a — the concept and the four range helpers.** `OdeElement` constraining the element's
`value_type` iterator, and `ode_state`, `ode_rates`, `ode_aux`, `set_ode_state` over an element
range templated on the iterator; the two legacy `double` typedefs deleted. `set_ode_aux` is an
ordinary member, not an opt-in. `needs_time` is left alone.
*Gate:* the odelia suite unchanged; `ode_util.hpp` still includes no XAD; and a deliberately
`double`-typed element rejected by `OdeElement` with the error reported at the helper rather than as
a page of instantiation noise.

**P1.1b — `vector_jacobian_product`.** Writes into a caller-owned buffer and returns the recording
size. `f` is generic and instantiated at the active scalar inside, so `plant` never spells `xad::`.
*Gate:* T1 against a central finite difference of the same block; T2 the recording size invariant
across two input counts an order apart and two output counts; T3 **stops** when a tape is already
active.

**P1.1c — `Step<System>::step_adjoint`.** Takes the step's start state so the six stage states can
be rebuilt from members that already exist.
*Gate:* one step's adjoint against a finite difference of that step on the Lorenz System.

**P1.1d — `implicit_value`, and the interpolant read at an active position.** Both have prior art on
the AD branch; the interpolant's `eval` takes `double u` there, and the addition is the
`value + slope · (u − to_passive(u))` read M1 measures the crown integral's height adjoint as
exactly zero without. Plus the non-finite step-size rejection.
*Gate:* one test per name driven from a System rather than from an example, and the active-position
read reproducing a finite difference in the query position.

**P1.2a — plant's plumbing at `S = double`.** The nine headers whose signatures adopt the legacy
typedefs: `patch.h`, `node.h`, `stochastic_patch.h`, `environment.h`, `individual.h`, `species.h`,
`species_base.h`, `individual_runner.h`, `stochastic_node.h`. **The plan's "26 uses" is a count of
signatures; there are 44 textual occurrences, because most are declared in-class and defined out of
it** — so the gate is *zero* remaining occurrences, not a count matched. Read-out direction is
signature-only; only `set_ode_state` has work behind it and that work is P1.2b. Add the missing
`#include <plant/individual.h>` to `node.h`.
*Gate:* bit-identity. At `S = double` the deduced iterator *is*
`std::vector<double>::iterator`, so this generates identical object code: offspring
`42.176246845059751` at 5 105 steps, and the suite's pass and fail sets unchanged.

**P1.2b — TF24 templated.** `Internals<S>`, then `TF24_Pars<S>` and `TF24_Strategy<S>`, then
`TF24_Environment<S>` and `ResourceSpline<S>`, then the six containers reading `value_type` from
`T`, then the yml and its regeneration, then `growth_rate_gradient`'s `thread_local` scratch
removed outright. `Control`, `ExtrinsicDrivers` and `Leaf` stay `double`. `CanopyShape` is
templated from **the version now on the branch** — function-pointer chains, the crown-base branch,
the shared static `eta_c` — and gains the one split templating forces: the chains on `double`, and
`std::pow` on an active `S` so `u^eta · log(u)` is taped, guarded by `to_passive(u) <= 0`, under
`if constexpr` and not a runtime flag. Re-check `q(z_over_height, z)`'s call sites by meaning.
*Gate:* bit-identity after every one of the six commits, same two numbers; the TF24, TF24f,
patch, individual and stochastic suites unchanged; and no deduced return type on anything returning
an active value.

**P1.3 — trait registration.** `ad_parameters()` and `ad_parameter_names()` from the yml, called
once per gradient evaluation and held for the run.
*Gate:* the two agree in size and order, and seeding by name and by index reach the same field.

**P1.4 — the trajectory store.** `struct ode_step_record { double time; std::vector<double> state; }`
and `SCM<T,E>::store_trajectory()`, replaying the resolved schedule in `double`, one state per
accepted step. No wrapper type and no separate times vector. Then a test for
`Species::set_birth_state`, which has none.
*Gate:* the replayed final state bit-identical to the forward run. **The trap:** `r_ode_times()` is
the replay grid; `patch.step_history` is the mutant cache's index and in production still holds
`{0.0}`, which is where a 60x error came from.

**P1.5 — the active build.** One test translation unit instantiating the templated TF24 at odelia's
active scalar and asserting only that it compiles and reproduces the `double` value at the same
inputs. §9 argues why.
*Gate:* it compiles, and the active value equals the double value to the last bit.

## Per-task hazards surfaced by re-reading the reports

Confirmed against reports 00, 01, 04, 07 and `tf24-correctness.md`. Each is a constraint a packet must
carry, quoted so the agent need not re-derive it.

**P1.1 / P1.2a — the aux family becomes load-bearing over a slot written nowhere.** TF24's
`aux_names()` returns eleven names but `assimilation` "is declared, allocated, reported to R and
written nowhere — exactly 0 on all 10 153 records" (report 07 §1.5). P1.1 asserts the aux iterator
advances by `aux_size()`, so that permanently-zero slot is now inside a structurally-checked width.
Left as-is it is harmless (a zero adjoint), but it is the same defect class P0.4 removed from the
resource vector, and the packet should state it rather than have the agent trip on the width mismatch.

**P1.1 — publishing the environment's per-layer uptake is fresh work.** `tf24-correctness.md` P0.4
says "sizing it by resource count and publishing it are the same edit". Only sizing landed
(`n_resources()`); nothing publishes uptake to aux. So the environment-aux commit (below) writes the
publication for the first time — not a rider on a landed change.

**P1.3 — two caches are keyed on a proper subset of their dependencies, and registering the traits
they cache gives a silently-zero channel.** `photo_temp_cached_` is keyed on `(leaf_temp,
atm_o2_kpa)` while caching `vcmax_` and `jmax_`, and "both parameters are differentiation targets"
(P0.10). `psi_soil_cache_` is keyed on exact `double` equality of the soil state, "and a
finite-difference verification perturbs exactly that state". P0.10 could not execute either — the keys
are run-constant, so no census reordering moves them — so they are the two carriers Phase 0 left
unmeasured. Registering `vcmax_25` or `jmax_25` in P1.3 without addressing the key severs the channel
with nothing thrown. The packet names both and requires the FD check to perturb the cached parameter.

**P1.2b — a second `pow` at an unguarded site, reachable only under a seeded exponent.**
`TF24_Strategy::Q` keeps one `pow` for the root-mass distribution at `root_depth_shape_eta = 0.2`
(P0.12). P0.7's value guard does not cover its *derivative*: `u^eta · log(u)` at `u = 0` is the same
NaN as the canopy's, at a site the crown-base branch does not touch. Latent unless
`root_depth_shape_eta` is a differentiation target — so P1.3 must not register it without the guard,
and P1.2b's `if constexpr` split should cover this site too, not only the canopy.

**P1.2b — TF24f is templated alongside TF24 and carries two open defects.** Its per-individual API is
"silently wrong" (`plant#61`: establishment exactly 0 against TF24's 0.9984, "the clamp that rescues
the value path is the same clamp that makes the gradient point out of it"), and the only guard on
P0.1's derivative-staleness fix is that the TF24f suite passes — there is no committed probe. If
templating perturbs that suite, the guard goes with it. The packet flags both as watch items, not as
Phase 1 work to resolve.

**P1.2b — two latent link/return hazards in the class being templated.**
`TF24_Strategy::compute_roots` is "declared and never defined … a link error waiting for its first
caller" (07 §1.10), and instantiation behaviour differs from today's non-template case.
`Leaf::electron_transport()` "declares a local shadowing the member it computes and relies on the
caller assigning the return value" — the exact shape of P1.2b's named deduced-return-type failure
mode. Both go in the packet's checklist.

**P1.4 — the store must restore one birth-time scalar the state vector does not carry.** Each `Node`
holds `pr_patch_survival_at_birth`, a plain `double` set at birth, not in `ode_state`, that divides
the fecundity rate; omitting it puts the whole error in `offspring_produced_survival_weighted` and
nothing else (report 01 §9 C6, verified on K93 and FF16). P1.4 replays the resolved schedule rather
than reconstructing, so `compute_initial_conditions` re-stamps it — the packet's rule is "replay,
never rebuild a Patch from records". `Species::set_birth_state` exists and has no test; P1.4 adds one.

**P1.4 — the store's grid is finer than any measurement in the project.** Everything measured to date
is at 142 output times or 10 153 cohort-time records; P1.4 stores 5 105 accepted steps, "the first
artefact at that resolution, and no existing number cross-checks it" (P0.5's degeneracy note). The
gate is therefore bit-identity of the replayed final state at the pinned build and nothing weaker.
The one state a record cannot reproduce by arithmetic is the `dh = 0` boundary interval at the
instant of introduction (report 04 §7.1) — but P0.9 made the rates there current, which is exactly
what makes "store state, rebuild rates by evaluating" sound; before P0.9 it was wrong at 141 steps.

## The reports need a reconciliation pass, and it is not Phase 1's

The re-read found the reports substantially stale against Phase 0: six of report 07's ten findings are
fixed with nothing in the file saying so, report 04's state-census figures are all on the pre-Phase-0
trajectory (5 055 steps, not 5 105), and report 07 §2.2 is internally contradictory on the light
floor (it claims "4.638%, confirmed firing" against its own §1.8's "0 of 8 292, minimum 0.1657209").
These are reference documents, not status, so they are corrected with one-line landed-notes, not
rewritten — a bounded docs task for whoever next touches them, tracked here so it is not lost. It does
not block Phase 1; Phase 1 reads the code and this file, not the reports' stale counts.

## The one thing in Phase 1 that is not bit-identical

**`Environment` becoming an aux element changes `aux_size()`.** `Patch::ode_aux` runs over the
species range only, while `ode_state` and `ode_rates` continue into the environment, and that
asymmetry is what leaves the soil's positivity guard unrecoverable on the sweep. Closing it means
the environment publishes its per-layer uptake, so the aux vector gets wider and every R-visible aux
width moves with it. The plan files this under P1.1, but `Environment` is plant's, so it belongs in
**P1.2a as its own commit, after the bit-identical sweep** — the sweep keeps its clean gate, and the
widening states in advance which assertions move and by how much. Nothing else in the phase may
move a number.

## Design constraints, settled

1. **odelia's base is `854a8e18`, and the three existing primitives come across as spikes.**
   `implicit_value`, `hermite_interpolator` and the non-finite step-size rejection are cherry-picked
   rather than re-derived, but **they are not finished code** — they are to be improved, optimised and
   integrated properly, not lifted. §9 lists what each owes. The AD branch tip is not the base: it
   also carries `mass_transport.hpp` and `separable_field.hpp`, whose mass chart §7 rules out.
2. **P1.5, the active build, is in scope.** Without it Phase 1 ends with TF24 templated but never
   instantiated at anything but `double`, so Phase 3 would discover every error at once, the `Leaf`
   boundary included.
3. **`Environment::n_cohort_reads` / `cohort_reads` / `set_cohort_reads` is deferred.** §2.3 gives
   `Environment` the triple, but no task owns it and its size is only well defined once P2.1 fixes
   the knot count.
4. **Phase 1 stacks on PR #66**, one PR per task, each targeting its parent branch.

## What the spikes owe, and what Phase 1 must add beyond the plan's list

Read against the code rather than the plan, five things are owed that no task currently names.

**The legacy typedefs cannot be deleted in P1.1a.** `odelia` itself uses
`ode::iterator`/`ode::const_iterator` in **zero** places — they exist only for `plant`, which names
them in **44** — so deleting them in the odelia packet leaves plant unbuildable until P1.2a lands
two waves later, and neither packet can then gate on its own. They stay through P1.1a and are
deleted in **one odelia commit at the end of P1.2a**, once plant has stopped naming them.

**The four range helpers are already templated on the AD branch** (`412d1b7`), so P1.1a's new work is
the concept, the deletion above, and `set_ode_aux` as an ordinary member. Cherry-pick the templating;
do not rewrite it.

**`hermite_interpolator`'s per-stage rebuild is P1.1d's, not P2.1's.** `init` takes positions, values
and slopes together and then validates ascent, scans for uniformity and fills 65 spans — structure
that cannot change once P2.1 fixes the fractions, re-derived 36 000 times a run. P2.1 names the split
(`set_nodes` once per run, `set_data` per stage) as part of its own task, but the split is
odelia-side, has no plant consumer yet, and moves no forward number, so it belongs here where the
primitive is being finished. P2.1 should consume a completed interpolant, not reshape one mid-phase.
The same packet adds the active-position read — `eval` takes `double u` today, and M1 measures the
crown integral's height adjoint as exactly zero without it — and renames the `active` flag, which
in this codebase's vocabulary reads as "active scalar" and means "initialised".

**`implicit_value`'s IFT denominator is a double central difference** at `eps = 1e-6·(|y*|+1)`, so the
node's derivative inherits a finite-difference error where the rest of the design is exact. Replacing
it with a forward tangent would force every caller's residual to become generic, which is a real cost
for one call site. So P1.1d **measures it rather than changing it**: the IFT derivative against a
central difference of `y*` over the eight parameters `height_seed` carries, at three values of `eps`.
It changes only if the error is material, and the number is recorded either way. Phase 0's lesson was
that a readability rewrite of working arithmetic moved more than the fix it accompanied.

**Nothing owns the forward-derivative helper, and it is Phase 1's.** §3's sixth row asks for a small
forward-derivative helper so `src/leaf_model.cpp` stops spelling `xad::`, and the design's rule is
that `grep -r 'xad::' plant/inst plant/src` returns nothing. It still returns **five lines**, all in
one function computing `dA/dci` and `dC/dpsi_stem` by forward mode. No P-task names it, it is small
and independent, and the invariant it restores is exactly what P1.5's active build tests. It becomes
**P1.1e**, an odelia helper plus the one plant call site, gated on bit-identity and on that grep
being empty.

**`plant/agents.md` has no §13.** The plan's §4 requires that a task changing what a model author
writes updates it in the same PR, and P1.2b is that task, so **P1.2b creates §13** from §4's
seven-item outline. It is a deliverable, not a follow-up.

## Corrections owed to the documents

- `docs/reports/interpolant-cost.md` §1 records the crown-base density limit at `eta = 1` as `1/H`.
  It is **`2/H`**, measured bitwise when P0.7 landed. This is the third document to carry the wrong
  constant and the last one still carrying it.
- The same file's "What is left to measure" item 4 asks for the `q` rewrite to be landed. **P0.7
  landed a branch instead**, deliberately, and the rewrite was reverted for moving two models for no
  gradient benefit. Items 1–3 remain open and are Phase 2's.
- `docs/build-plan.md` P1.1 says "From `854a8e18` on `master`". `854a8e18` is **not** on `master`; it
  is `master` plus thirteen commits of earlier AD-surface work.
- `docs/build-plan.md` §2.9 says `Patch::introduce_new_nodes` "rebuilds the field but does not
  recompute rates", and builds an argument on it: that at 141 of 5 055 steps `k1` is the rate vector
  from before the newcomer entered the field, so `lambda_k1` belongs to the step boundary. **P0.9
  fixed that** — the rates are now recomputed there. The seam is still at the step boundary, but it
  is now clean, which simplifies rather than complicates Phase 3. The paragraph needs re-deriving
  against the branch.
- Line numbers cited for `patch.h` are stale by about a hundred lines: upstream's height-inversion
  diagnostic landed in the merge. Packets should cite names, not lines.
- `docs/build-plan.md` P1.2a's "26 uses" is a count of signatures. A grep finds **44** occurrences
  across the same nine files, because most are declared in-class and defined out of it.
- **`docs/build-plan.md` §2.9's `k1`/step-boundary paragraph — re-derived against the post-P0.9
  branch (landed this turn).** It reasoned from "`introduce_new_nodes` rebuilds the field but does not
  recompute rates"; P0.9 recomputes them there, so at the 141 introduction steps `dydt_in` is now the
  freshly recomputed rate at the widened state, `derivs(y_after, t)` — the correct linearisation
  point, wrong before P0.9. The seam stays at the step boundary but is now clean (a bookkeeping seam,
  not a stale-point one), which simplifies Phase 3 rather than complicating it.
