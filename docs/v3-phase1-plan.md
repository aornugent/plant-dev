# v3 Phase 1 — bring TF24/TF24f onto the primitives, minimal diff from base

The plan for the TF24 leaf wiring. Read `v3-north-star.md` §4 first for the leaf
design; this doc is the executable sequence and the live status.

**Status: Steps 1 and 2 are DONE and verified (session 19). Steps 3 and 4 are
next; both are now specified against measured numbers rather than expectations.**

## The bar
The pristine pre-reverse-mode strategy is vendored at
`docs/reference/tf24-base-develop/` (develop merge-base). It is the DX bar: v3's
job is to add reverse-mode support with **as little divergence from those files as
possible**.

Drift across the TF24 leaf surface (re-measure, don't trust this table):

| file | base | at plan-writing | now |
|---|---|---|---|
| `src/tf24_strategy.cpp` | 768 | 1222 | **1128** |
| `inst/include/plant/leaf_model.h` | 399 | — | **635** |
| `src/leaf_model.cpp` | 1482 | — | **1463** (net deletion) |

Total leaf-surface drift went +796 → **+577**. Steps 3 and 4 should take it lower.
`leaf_model.cpp` ending up *below* base is the shape to aim for elsewhere: the
scalar-generic templates replaced duplicated formulas rather than adding to them.

## The commitment (from the §-design decision, 2026-07-24)
> The leaf's output physiology is written once, as **scalar-generic closed-form
> methods on `Leaf`**; the double value path and the reverse-mode assembly call the
> same methods. No separate `leaf_output` namespace; no formula transcribed twice;
> no `xad::`/`tape`/`supplied_derivative`/`chain_sign`/`snapshot` token in the
> strategy TU.

Held. The output physiology is now `template <class T> static T` members of `Leaf`
(definitions after the class in `leaf_model.h`); the R-exported double methods
delegate at `T=double`; `arrh_curve`/`peak_arrh_curve` collapsed entirely.

## Acceptance checks (grep-able) — 3 of 4 pass
1. ✅ `grep -cE 'supplied_derivative|chain_sign|g_leaf_snap|PLANT_TAPE_STATS' src/tf24_strategy.cpp` → **0**
2. ✅ `grep -c 'namespace leaf_output' inst/include/plant/leaf_model.h` → **0**
3. ✅ no non-template `double Leaf::` copies of the closed forms (arrh/peak deleted outright)
4. ❌ **odelia `supplied_derivative.hpp` NOT yet deleted** — see Step 4a. All
   remaining plant references are stale *comments* (verified: 8, in
   `ff16_strategy.h:752`, `tf24_strategy.h:111,272,288,429,434,436`,
   `tf24f_strategy.h:17`). No live caller anywhere.

## What Steps 1–2 delivered, and the bug that dominated the session
The seam is gone and `assemble_leaf_from` is called directly on the active `S`;
`leaf_output` is absorbed into `Leaf`. Verified: **Gate-0 FD-matches on all 7
channels** (`vcmax_25`, `jmax_25`, `K_s`, `k_I`, `lma`, `rho`, `a_l1`), TF24
soil-coupling (3) and light-coupling (6) AD tests pass, tf24f collar-uptake (11)
passes, the active run reproduces the double trajectory exactly, and the double
path is bit-identical (`test-leaf`, `test-strategy-tf24`, `test-strategy-tf24f`).

Most of the session went to one bug: see **"Hard-won rule"** at the bottom. Read it
before writing any AD code.

---

# Step 3 — fold the TF24f tracked collar into `assemble_leaf_from`

The one genuine design step left, and it now has a **measured target**.

### 3a. Delete the proven-dead hooks (pure deletion; do this first)
`seam_collar_psi_partial()` and `seam_collar_uptake_partials()` are **dead** — the
deleted seam was their only caller. Verify, then delete:

    grep -rn 'seam_collar_psi_partial()\|seam_collar_uptake_partials(' plant/src plant/inst plant/tests | grep -v 'virtual\|override'
    # must print nothing but one comment line

Sites: declarations `tf24_strategy.h:275,279`; overrides `tf24f_strategy.h:63,70`.
Deleting `seam_collar_psi_partial` orphans `dprofit_dpsi_`, which orphans the
`leaf.dprofit_droot_collar_psi(used)` call at `tf24f_strategy.cpp:73` and probably
the `psi_fd_step` FD block at `:82`. Follow that chain and delete what it frees.
**Keep `Leaf::dprofit_droot_collar_psi` itself** — RcppR6-exported
(`Leaf__dprofit_droot_collar_psi`) and R-test-exercised.

### 3b. Fold the one live hook
`seam_collar_psi_input()` (`tf24_strategy.h:274`) has exactly one live use, at
`tf24_strategy.cpp:732`, selecting the tracked-collar regime inside
`assemble_leaf_from`. Wire TF24f's tracked `q` as the tracked regime of the same
assembler (v3 §6, reuse `G(q)`) so the virtual hook can go.

### 3c. Close the measured 2.9e-4 residual — BEFORE declaring Step 3 done
`test-ad-tf24f-collar.R` has **1 failing assertion of 3**. Not a regression from
the root-cause fix: that path previously used the seam's hand-written analytic
partial (`seam_collar_psi_partial`) and now flows through the assembled
expression, so the number legitimately changed and is slightly off.

| ψ | ad | fd | rel |
|---|---|---|---|
| 0.8 | 1.618655248 | 1.618565425 | 5.6e-5 (passes, tol 1e-4) |
| 2.5 | −0.0224825395 | −0.0224889651 | **2.9e-4 (fails)** |

**The gap is δ-independent from δ=1e-7 to 1e-3** (swept). By this project's own
rule that means a real missing derivative term, *not* FD noise — do **not** "fix"
it by loosening the tolerance.

Prescribed diagnostic — decompose by output channel instead of staring at the
composite. Extend `tf24f_collar_driver.cpp` to return `d(psi_stem)/dψ`,
`d(E_up)/dψ`, `d(ci)/dψ`, `d(profit)/dψ` separately and FD each. The channel
carrying the residual localises the term. Ranked hypotheses, test in this order:
1. **Clamping.** The tracked branch grafts `p_star = graft_value(p_star_d, *collar)`,
   so `dp*/dψ ≡ 1`. But `evaluate_root_collar_psi` **clamps** the target into the
   feasible `[bound_a, bound_b]`; where ψ is clamped the true derivative is 0, not
   1. ψ=2.5 sits nearer a bound than ψ=0.8, which fits the error growing. Print
   `prepare_collar_solve`'s interval at both ψ first — this is a five-minute check.
2. **Regime classification.** `assemble_leaf_from` picks interior vs bound from
   `E_column` at the converged point, but TF24f runs *off* the optimum. Confirm the
   tracked branch is not taking an optimum-only shortcut.
3. **A missing off-optimum envelope term**: at a tracked collar `dW/dp ≠ 0`, unlike
   the interior optimum, so terms that legitimately vanish there must not be
   dropped here.

Gate-0 for Step 3: all three ψ FD-match at tol 1e-4, with the FD reference δ-swept
and shown δ-independent.

---

# Step 4 — delete residual accretion, then verify at SCM scale

### 4a. Finish acceptance check 4 (pure deletion)
- delete `odelia/inst/include/odelia/supplied_derivative.hpp`
- delete `odelia/inst/examples/supplied_derivative_interface.cpp`
- delete `odelia/tests/testthat/test-ad-supplied-derivative.R` + its
  `helper-load-odelia.R` entry
- clean the 8 stale plant comments listed under acceptance check 4
- NEWS: the primitive is retired because the seam it existed for is gone

### 4b. Residual accretion
`soil_consumption_active_` population, `dsoil_consumption_dpsi_collar_perlayer`
(`leaf_model.cpp:980`, called only from `:956`), any leftover double/S double-loop.
Check each for live callers before deleting — several RcppR6 exports look dead and
are not.

### 4c. The closing gate (task #27) — do 4d FIRST, it currently blocks this
`test-ad-tf24-scm-gradient.R` has two tests:
- test 1, "compiles, runs, reproduces the double value" — live assertions. **It is
  currently OOM-killed (SIGKILL, exit 137) at its `life=4`, not merely slow.** See
  4d for the measured tape growth and the options. `life<=3` completes in 47-97 s.
- test 2, "**full-SCM gradient FD-verification (OPEN — staircase reference
  needed)**" — an explicit `skip()` at line 85. **This is the gate.**

To close it, build the reference the way the Oracle prescribes, not by sweeping for
a plateau:
- read `docs/oracle/oracle-response-inner-argmax-adjoint.md` FIRST — binding here;
- AD vs FD on a **frozen resolved schedule** (L0 `node_schedule_times` **and** L1
  `ode_times` from `run_scm(refine_schedule=TRUE)`) at **tight inner tolerance**
  (`GSS_tol_abs`), δ fixed in the valid window (δ ~ τ^{1/3}, above the staircase
  noise floor, below the step that drives the SCM non-finite, #550);
- do NOT chase a loose-τ swept plateau — the documented artifact two sessions burned on.

**Now that Gate-0 FD-matches on 7 channels, a residual disagreement at SCM scale is
more likely the FD reference than the adjoint. Verify the reference before believing
any ratio.**

### 4d. Memory — MEASURED, AND IT IS NOT A TF24 PROBLEM (re-diagnosed session 20)
**The failure is a genuine kernel OOM, and the earlier attribution to seam deletion
is refuted.** Both halves of that are measurements, not inferences.

**The failure mode.** `tf24_scm_gradient("lma", 20, 4, 0L, ...)` peaks at **15.19 GB
RSS** and is `SIGKILL`ed; the kernel `oom_kill` counter increments and `dmesg`
carries the victim record (`anon-rss:15928804kB`, `global_oom`). Not a hang, not an
exception, not a segfault. The tape is ~88% of that RSS, and its size is exactly
`ops·12 + stmts·8 + deriv·8` (4 445 422 996 B at `life=1`, to the byte), so there is
no leak and no allocator waste. Memory is **fully released** between calls (RSS
returns to 0.13 GB), so the five successive calls in test 1 do not accumulate.

**The scaling, for two strategies:**

| model | life | steps | node width | tape | KB/(step·width) |
|---|---|---|---|---|---|
| FF16 | 4 | 95 | 602 | 1.53 GB | 26.2 |
| FF16 | 10 | 141 | 658 | 3.39 GB | 35.7 |
| FF16 | 40 | 235 | 903 | 9.02 GB | 41.5 |
| FF16 | 105.32 *(its own default)* | — | — | **OOM** | — |
| TF24 | 1 | 129 | 532 | 4.45 GB | 63.3 |
| TF24 | 2 | 166 | 567 | 7.01 GB | 72.7 |
| TF24 | 3 | 194 | 595 | 9.20 GB | 77.8 |
| TF24 | 4 | — | — | **OOM** | — |

**FF16 never had a seam and has no leaf solve, and it OOMs the same way** — at its
own production `max_patch_lifetime`. So seam deletion is not the cause. Per
cohort-step TF24 costs only ~1.9× FF16; the leaf is a **2× multiplier, not the
mechanism**. The mechanism is shared and structural: **one tape holds the whole SCM
run, so tape size scales as steps × cohorts.** This is a pre-existing,
strategy-independent limit that TF24 merely reached sooner (its `life` is smaller
because its steps are dearer). Growth is *not* "linear at 34 MB/step" — per-step
cost rises with the cohort count.

**The v3 design's scaling fix is intact — do not go looking for a regression.**
What v2 blew up on is measurably gone (`weibull_leaf_tape_profile`,
`pstar_ode_reprex`):
- a naive on-tape solve is iteration-dependent: 11 001 → 42 081 ops/solve as inner
  iterations go 20 → 60;
- the `implicit_value` node path is flat: **699 ops/solve** at `n_solves` 1, 10, 100;
- per-step cost is flat in step count: 42 918 → 42 610 ops/step over `n_steps`
  20 → 160.

**What the toys never measured is the per-evaluation constant on the composition
plant actually records.** They certified simpler shapes:
- `weibull_leaf_tape_profile` — one p\* node at a *known* p\*, no central
  difference: **11.7 KB/solve**;
- `soil_leaf` — a `ci` node inside `ode_rates` with the closed feedback loop and a
  growing tape, 60 steps: 2.60 MB total = **22.7 KB per plant-step**;
- `pstar_ode_reprex` — plant's actual shape (`implicit_value` on a **central
  difference** of a reduced profit whose every evaluation rebuilds the nested
  ψ_stem and ci nodes): **664 KB/step**, ~29× `soil_leaf`.

The reprex now reports tape stats, so that multiplier is decomposable
(`n_steps=40`, `nlayer=2`, ops/step): closed form 5 267 → p\* node without nesting
10 514 → nested nodes with p\* frozen 16 009 → **both, i.e. plant's shape, 42 742**
(8.1×). The central difference roughly doubles the nested content.

**Sizing the candidates against those numbers.** Fitting the three TF24 points gives
tape ∝ life^0.66 (3 points — treat as an order-of-magnitude guide):
1. **Analytic stationarity residual** (was option 2): ~2.7× for TF24, so `life=4`
   drops from ~11 GB to ~4 GB. Buys 1–2 life units, is TF24-only, and does nothing
   for FF16. Worth doing, but it is not the fix.
2. **Checkpointing** is the only mechanism that breaks the steps × cohorts
   accumulation, and `chkpt=0` on every run above confirms XAD's checkpoint API
   (`insertCallback`, `newNestedRecording`/`endNestedRecording`,
   `getAndResetOutputAdjoint`) is entirely unused. At production lifetime the
   extrapolation is ~94 GB for TF24 and ~35 GB even with (1), so **no constant-factor
   cut reaches a full-lifetime patch gradient for either strategy.**
3. Coarser cohort-step schedule for gradient runs (accuracy cost — measure).

**Re-scope accordingly:** this is engine work for *all* strategies, not a TF24
Phase-1 step. Phase 1 needs only "TF24 at the lives its tests use", which (1)
delivers; the production-lifetime gradient needs (2) and should be tracked as its own
engine task. Question with a default: if TF24 is only ever wanted at short lives,
(1) alone closes Phase 1 — **default if unanswered: do (1) in Phase 1, and open (2)
as engine work covering FF16/K93 too.**

The env hook lives in `scm_gradient.h` (~119); the reprex reports `mem_bytes`/`ops`/
`stmts` so the per-step constant can be re-measured in seconds without a plant build.

---

## Verification doctrine (do not relitigate)
- Gate-0 (single leaf/cohort, δ-swept FD) before any census FD.
- A **δ-independent** AD/FD gap is a real derivative bug; a δ-dependent one is an
  FD-reference problem. Establish which before hunting.
- The SCM correctness anchor is the tight-τ frozen-schedule FD, never the loose-τ
  swept plateau.
- Toy-proven, so the plant checks are confirmation not discovery: the
  resistance-network `soil_uptake` (incl. seeded `root_b`/`root_c`), the `E_column`
  bound-continuity residual, the value-graft, and the nested interior-optimum
  composition (`pstar_ode_reprex`).

## Hard-won rule this phase added — read before writing any AD code
**Never give a deduced return type to a function or lambda that returns an AD
value.** XAD operators return *expression templates* holding references to their
operands, so a deduced return type hands the caller references to temporaries and
by-value parameters that die on return; the caller materialises a dangling
expression and records reused stack bytes as a tape operand slot, and the reverse
sweep segfaults far from the cause. **valgrind cannot see it** — the dangling
storage is stack, not heap.

    // BAD  -- returns a dangling expression template
    auto anchor = [](double v, S x) { return S(v) + (x - to_passive(x)); };
    // GOOD -- materialised while its operands are alive
    auto anchor = [](double v, const S& x) -> S { return graft_value<S>(v, x); };

This was the TF24 reverse-sweep segfault and it cost a session. Because the
corruption depended on stack layout, disabling almost any unrelated thing made it
"disappear" — freezing p\*, dropping the nested nodes, removing `soil_uptake`, and
de-statefulling the double solvers each looked like a fix and none was. Defences now
in place: `odelia::util::graft_value` owns the graft idiom; `implicit_value`
static_asserts its residual returns `S` exactly; `AGENTS.md` → "Never (code)" carries
the rule; and `odelia/inst/examples/pstar_ode_reprex_interface.cpp` reproduces it on
demand (`graft=2`) with the full account in its header.

## What is explicitly NOT in Phase 1
DeepCrown under AD stays stubbed (`assemble_leaf_from` is single-solve, like the
base; v3 §4.5 is separate). `field_ptrs()`/`*_AD_FIELDS` are load-bearing input
seeding — not seam, do not touch. RODAS is a general odelia feature — surface to the
maintainer, don't delete here.

## Worth reporting upstream (not blocking)
`OperationsContainerPaired::for_each` in vendored XAD visits only `start_chunk` and
`end_chunk`, silently skipping intermediate chunks when a statement's operands span
more than two. Unreachable at the current 8 M chunk size, so the vendored tree was
left pristine.
