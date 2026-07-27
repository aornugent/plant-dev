# Dead ends: do not re-derive, do not re-try

**Read this before proposing a mechanism.** Every entry was believed by someone competent, then
refuted by measurement. They are collected here because they were previously recorded as inline
retractions inside the documents that had asserted them — which meant a linear reader met the claim
before the correction, and a hurried one never met the correction at all.

**Rule:** when a claim is refuted, move it here and leave a one-line pointer where it was. Do not
delete it — an unrecorded dead end gets re-walked.

---

## Refuted by measurement

| claim | why it was believed | what refuted it |
|---|---|---|
| **Crown preaccumulation closes FF16's memory** (2.7× / 12×) | `v3-reverse-memory-design.md` §6d, tabulated without saying it was an estimate | measured **1.49× / 3.7×**. The estimate assumed the light-field read was 29% of the crown tape; it is **66%** |
| **Component leanness is a route to production lifetime** | four separate levers each looked worthwhile | ceiling ~3× (FF16) / ~5× (TF24) against a required ~2600×. The interpolator's genuine 5.89× moved TF24's total by **0.018%** |
| **The event segment is the right unit** | measured 1.10-1.34 ODE steps per segment | that ratio is a property of *one schedule policy*. **TF24 measures 18.43** — the segment fails there, though it still serves K93 (1.23) and FF16 (1.87) |
| **Reusing one tape, rewound between units** | the obvious way to remove per-unit tape construction | `resetTo` keeps the gradient exact but **does not release**: peak grows 48 kB → 742 kB, and the time advantage reverses to 8.4× |
| **Hoisting the query-factor `pow` out of the crown integral** | `pow` with active base *and* exponent looked dominant | **1.24×**. The per-node `pow` is ~30% of the field read, not its bulk. `deepening-6` had already predicted this: "FF16 adds no new scan, only more `a_p(z)` evaluations" |
| **Refining the interpolant on `to_passive` inside plant** | worked on a toy at 6.25× | in plant the target sums over **all cohorts**, so evaluating it twice costs more than the saved band solves. Tape went **up** 1.4-1.8%. The fix belongs in the refiner, and does |
| **`positions_history` / L2 as a recorded layer** | `AUTODIFF.md` described it; `ff16_environment.h` called it "the deferred L2 path" | an adaptive node set is **bit-identical** built plain or active with nothing recorded. Positions are `double` by type and the refiner decides on passive values |
| **`Replayable` is a deletion target** | all four hooks are no-ops on plant's resident path | it is **opt-in via `if constexpr`** — a System without the hooks never has them called and the branch compiles away. It costs zero concepts when unused. Only its *structure role* is dead |
| **The soil clamps are a gradient hazard because they are unsmoothed** | `smooth_positive` is used 3× in `ff16_strategy.h` and **0×** in `tf24_environment.h`, and the runoff floor is a physical boundary | **Half refuted, and the half that survives is a different mechanism.** Three of the four are *kinks* where a zero derivative is what the model means. The dangerous one is the drying guard (`:335`), which is a **severance** — it zeroes `d(rate)/d(uptake)`, cutting the plant→soil channel. And at the default rainfall **no clamp is visited at all**: min θ is 18–21× θ_r, min `runoff_factor` 0.9231. Smoothing was the wrong prescription; measuring which regime fires the guard is the right one |
| **A field assembled over `implicit_value` sources is a risk to the TF24 design** | it had no witness anywhere, and the field is rank-3 frozen-structure while the leaf solve is an IFT node | **Refuted by construction.** All 5 channels FD-exact at 6.9e-11 … 3.3e-9, the assembly pinned against an analytic identity at **2.2e-16**, holding over 2 → 40 sources and down to θ = 0.05. The composition was never the problem; the shared `Leaf` is |
| **A spline fitted to optical depth can carry the query tangent** | `A` refines cleanly where `exp(-A)` does not, and `ff16_environment.h` says so | it is 2-4× better and still **227% mean error** at production tolerance. Value and slope cannot come from different constructs without reproducing the detached-derivative pattern already deleted once |

## Four wrong attributions for one drift — the method failure worth remembering

TF24/FF16/K93 segment re-runs drift when rebuilt from `ode_state`. Four mechanisms were proposed and
tested before the right one was found **by reading the consumer of a quantity** rather than guessing.

| hypothesis | verdict |
|---|---|
| The per-node stamps | **Right in substance, refuted for the wrong reason.** `patch_density_at_birth` and `node_introduction_time` really are inert for the rates — checked correctly. The conclusion "stamps cannot affect the ODE state" was then drawn without finding the **third** stamp, `pr_patch_survival_at_birth`, which divides the fecundity rate |
| A stale first stage (first-same-as-last) | **Refuted twice.** Invalidating `dydt_in` on a width change changed *nothing*, because `set_state_from_system` already does `ode_rates(dydt_in.begin()); dydt_in_is_clean = true`. The one-line fix was inert and was dropped |
| Spline path-dependence | **Refuted.** The node comparison behind it was **malformed** — forward *entering* a segment against rebuilt *leaving* it. And restoring the spline properly through `r_set_state` changed the drift not at all: on the rate path K93 and FF16 read the field, not the spline |
| A lagged aux slot | **Real, but not this.** The lag exists and is load-bearing for FF16 (settling twice makes the match *worse*). It is not the drift |
| **`pr_patch_survival_at_birth`** | **Confirmed by a discriminating prediction** — it divides only the fecundity rate, so the error can only land there, and it does: `offspring_produced_survival_weighted`, every segment, both models, exclusively |

**The lesson, and it is the most transferable thing in this file:** when two regimes are measured and
stable, **diff the objects** rather than proposing mechanisms. Four hypotheses cost more than one
careful read of who consumes a quantity.

## Invocation artefacts that were mistaken for failures

| claim | reality |
|---|---|
| "odelia has 10 / 30 loader errors" (sessions 20 **and** 21, the second calling them *proven* pre-existing) | both were invocation artefacts. `testthat::test_dir()` does not attach the package; `test_local()` silently skips the whole AD workflow |
| "plant's `test-patch` / `test-scm` are broken" (session 22, briefly) | `Node`, `Parameters`, `trapezium` are **internal**, so `library(plant)` hides them. plant needs `load_all` |
| plant's `test-canopy-methods` failures are a model problem | stale blessings: `16.88946` dates to 2026-06-25, the shading model changed 2026-07-18/19/20 |

**A baseline controls for the change, not for the method.** Reproducing a number says nothing about
how it was obtained.

## Superseded framings kept only for their derivations

- `v3-step-local-adjoint.md` §3b — the event-segment unit. Marked dead text in place; the derivation
  is instructive, the conclusion is not (and see the segment row above: it survives for K93/FF16).
- `v3-reverse-memory-design.md` §6c — sets frozen-L2 aside on a *memory* argument. Sound, but it
  answers a different question from the one that was later asked about complexity.
- Session 19's attribution of the OOM to the deleted leaf seam. FF16 OOMs the same way and never had
  a seam.
