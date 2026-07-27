# Requirements the design must satisfy, with the evidence for each

**Purpose.** Every design in this project has failed on an early simplification. This file is the
input to the next design question: the **complete set of concrete requirements backed by objective
evidence**, and — separately and explicitly — **what is still untested**. A requirement that appears
here is measured or read from code with a citation. A belief that is not measured appears in §6, never
in §1–§4.

**How to use it.** §1–§4 are what a candidate design must pay for. §5 is what is already true, so a
candidate may assume it. **§6 is the risk register — read it before committing to anything**, because
each entry is a way the next design could fail the same way the last five did.

Sources combed for this: `v3-facts.md`, `v3-engine-design.md`, `v3-control-flow.md`,
`v3-dead-ends.md`, `HANDOFF.md`, `build-plan.md`, plant's gradient tests, and the probes in
`docs/reference/`. Where a document contradicted the code, the code won and §7 records the correction.

---

## 1. Outcome requirements

| | outcome | quantity | evidence |
|---|---|---|---|
| **R1** | exact trait/parameter gradients of emergent SCM outputs | census 3-vector (LAI / biomass / basal area) **and** R0 / offspring | FF16 R0 now matches FD at **2.6e-06 (lma)**, **6.1e-06 (a_l1)**, **1.3e-08 (k_l)** — see §7.1, this is *better* than the docs claimed. **TF24 has never been FD-verified at all** (§6 A4) |
| **R2** | at production lifetime | TF24 `life = 105.32`: **987 node states + 9 soil, 2 598 ODE steps**. Whole-run tape **≈231 GB**; needs **~2 600×** | `v3-facts.md` §1; marginal per-state-step **86.2–107 kB**, flat over widths 543→606 |
| **R3** | concept count a plant developer can hold | plant touches **34** odelia names; engine is **5** concepts; odelia is **19** headers | `v3-facts.md` §6 |
| **R4** | FD-verifiable | frozen **resolved** schedule (L0 `node_schedule_times` **and** L1 `ode_times`), δ in the valid window | `HANDOFF.md` Part 1; and per-unit FD is **roundoff-dominated**, best at `d_rel` 1e-3 (§5.7) |
| **R5** | a new strategy/environment needs no new engine vocabulary | zero new names per model | `v3-engine-design.md` |
| **R6** | the forward model must not regress | develop **49.57 s / 2 621 steps** vs branch **50.31 s / 2 599** = **+1.5%** | `docs/reference/tf24-develop-benchmark.sh` |

**Scarce resource:** tape bytes in one reverse sweep — **47–56 MB per ODE step** at production width,
i.e. per-state-step × states × steps. Every component optimisation measured is ≤2% of it.

## 2. The storage contract — what a stored unit must carry

Now **measured**, not inferred. A unit that omits any row is wrong in a specific, named way.

| must carry | why | measured consequence of omitting | cost at TF24 production |
|---|---|---|---|
| the ODE state per step | the integrand | — | **20.7 MB** (2 598 × 996 × 8 B) |
| per-species cohort counts | the width, and the field's tie-break index | width mismatch / reordered sum | negligible |
| the light spline nodes + values | `r_set_state`'s 4th argument | drift | negligible |
| **all three birth stamps per node** (introduction time, patch density at birth, `pr_patch_survival_at_birth`) | the fecundity rate **divides by** the third (`node.h:74,217`) | error lands **exclusively** in `offspring_produced_survival_weighted`; restoring them cuts relative drift **~10× (FF16)** and **~17× (TF24)** | 3 doubles × 141 cohorts ≈ **3.4 kB** |
| **NOT the aux** — settle exactly **once** | the forward pass genuinely uses the *lagged* aux | double-settling makes FF16 **worse by ten orders** (1.50e-36 → 1.61e-15) | zero — **closed**, see §5.5 |

**Re-run:** `NOT_CRAN=true Rscript docs/reference/restore-stamp-probe.R`

**A requirement with no API.** `Patch::r_set_state` (`patch.h:832-847`) restores state, counts and the
spline and **nothing else**; `Species::set_birth_state` exists (`species.h:132`) but `Patch` exposes
`at_species()` **const-only** with `species` private, so **no public route exists**. The probe
`const_cast`s; a real design cannot. **This is a required plant API change (#45).**

## 3. Structural preconditions

Each is a condition the design must satisfy or explicitly guard. "Undefended" means nothing in the
code prevents violation.

| | precondition | status | evidence |
|---|---|---|---|
| **P1** | the structural change is applied **inside** the unit, not between units | required; ordering is the one thing to get right | placed between, a stand-dependent newborn loses its adjoint — **19% error, right sign**, undetectable by a constant-IC toy |
| **P2** | a **fresh tape per unit**, never a rewound one | required, and counter-intuitive | `resetTo` keeps exactness (1.8e-15) but **does not release**: peak 48 kB → 742 kB; time advantage reverses 1.48× → 8.42× |
| **P3** | structure is a deterministic function of **plain** values | true today, **UNDEFENDED** | a new environment sorting on an active key breaks it; only a sentence guards this |
| **P4** | the field's source order is stable across a rebuild | **verified** for two species | ties break on the flat index (`patch.h:741-748`); two K93 species replay at `copy_abs` **exactly 0**. **Caveat: equal widths only** (§6 B1) |
| **P5** | **all species share `eta`** | **HARD CONSTRAINT, newly found** | one query-factor set serves every source (`patch.h:757-759`); mixing η **diverges** — field computes **7.98e+14** where the exact kernel gives 0.118 |
| **P6** | only the **DeepCrown** shading profile is differentiable | `FlatTopBox`/`FlatTopSoftBox` have **no correct tangent route** | non-separable; defaults are DeepCrown, both alternatives explicitly pedagogical |
| **P7** | no path-dependent background (hysteresis, non-ODE accumulator) | none in plant today | if one appears, it must become ODE state or be recorded — and the deleted L2 recording returns |
| **P8** | the `Leaf` must hold state **consistent with** the unit | **OPEN — the one blocker (#37)** | inline replay **exactly 0**; deferred **1.8e-13 → 1.3e-8**; FF16/K93 zero both ways |
| **P9** | if units own Strategy copies, trait adjoints **must be summed** across units | conditional on the #37 choice | `Strategy::ptr` is a `shared_ptr`, so a Patch **copy shares** the AD input; a per-unit Strategy makes each distinct and one read gives **41–51%** of the answer |
| **P10** | a per-unit Strategy copy must re-seat **Species AND every Node** | consequence of P9 | `SpeciesBase` holds the `shared_ptr`, every Node holds a copy (`species.h:31,158`); `Individual`'s only entry is its constructor — **a half-re-seated patch is silently mixed state** |
| **P11** | never give a deduced return type to a function/lambda returning an AD value | absolute | XAD operators return expression templates holding references to temporaries; valgrind cannot see the failure; two live instances found historically |
| **P12** | only `double` crosses the R boundary | absolute | project invariant |

## 4. Verification requirements

| | requirement | evidence |
|---|---|---|
| **V1** | the FD reference must be **verified before** any ratio is trusted | a TF24 SCM/leaf FD is a **δ/τ-indexed family**, not one number; too small → staircase noise, too large → non-finite |
| **V2** | the correctness anchor is AD vs FD on the **identical resolved schedule** at tight inner tolerance | `oracle/oracle-response-inner-argmax-adjoint.md` Decisive Experiment 2 |
| **V3** | the closing gate needs a **tolerance, not an equality** | the design's restore path is **~2e-5 relative on live state** — not bit-exact. The alarming 5.47 / 45% figures are on a cohort at `log_density` = −328 (density 1e-143) |
| **V4** | AD == FD failure on an identical schedule is a **real derivative bug**, not a replay artefact | forward AD == reverse AD yet both ≠ δ-independent FD ⇒ hunt the model code |
| **V5** | check a gradient test did not **skip** | `skip_if_not(built, …)` turns a sourceCpp failure into a skip; that silently disabled 11 FD assertions once |

## 5. What is already established — a candidate may assume these

1. **Peak = whole ÷ units**, and the reduction factor *is* the unit count. Peak flat at 6 560 B over 30→480 units while whole-run grows 91 636 → 1 438 036 B.
2. **Component leanness cannot close R2.** Best genuine win 5.89× moved TF24's total by **0.018%**.
3. **A spline cannot carry the tangent** — 227% mean error at production tolerance. Hence the field.
4. **One rank-3 kernel serves all three strategies**, and a field over `implicit_value` source weights is FD-exact (5/5 channels, assembly pinned at **2.2e-16**).
5. **The aux lag needs no storage** — settle once. Closed this session.
6. **Adaptive structure needs no recording** — a node set is **bit-identical** built plain or active. L2 as a layer is deleted.
7. **Soil needs no concept** — it is ODE state; the clamps are closed (the one severance is unreachable, both water sinks shut off at 12.5× θ_r). **Do not smooth them.**
8. **The event segment is the unit for K93 (1.23) and FF16 (1.87); TF24 needs the step (18.43).**
9. **The restore is not the bottleneck** — 11–15% of a unit.
10. **In plant, on a frozen trajectory:** a unit under AD is FD-exact (**1.3e-09**), trait adjoints accumulate, a codomain-2 Jacobian costs **+0.38%**, per-unit tape **0.96 MB** (K93, ~40 cohorts) and **4.38 MB** at production lifetime.

---

## 6. UNTESTED OR LOW CONFIDENCE — the risk register

Ranked by whether it could **invalidate the design** rather than merely cost work.

### Tier A — could invalidate the design or its central number

| | assumption | why it is not yet evidence | cheapest decisive test |
|---|---|---|---|
| **A1** | **the chained state adjoint works in plant** | **This is the core of the design and it has never run in plant.** Everything measured in plant is either a whole-run single tape, or (this session) a unit on a **frozen** trajectory where the entering state is a tape *constant*. Carrying λ = entering-state adjoints from unit k+1 into unit k — the thing that makes the sweep a sweep — is witnessed **only on an odelia toy** | two adjacent K93 units, chain λ, compare against the whole-run reverse AD gradient of the same functional |
| **A2** | **`introduce_new_nodes` on tape carries the newborn's adjoint** | P1's 19% silent error is measured **on the toy**, not in plant. In plant the newborn's dependence on the entering state is exactly what an untested ordering would drop, and the failure is silent with the right sign | one unit that opens with an introduction; compare the entering-state adjoint against FD w.r.t. that state |
| **A3** | **the ~89 MB TF24 per-unit tape** | **R2's entire case rests on this number and it is an extrapolation** — measured marginals stop at width 606, production is 987, and no TF24 *unit* tape has ever been measured. K93's unit tape is known (0.96→4.38 MB); TF24's is not, and is blocked by P8 | TAPE_STATS on one restored TF24 unit — needs #37 first |
| **A4** | **TF24 gradients are exact** | The TF24 test asserts only **`is.finite`** and value reproduction. Its FD verification is explicitly **"OPEN — staircase reference needed"** (#27). So R1 is unverified for the model the whole design exists to serve | Oracle Decisive Experiment 2: frozen resolved schedule, tight inner tolerance, δ in the window |

### Tier B — would force rework, not a redesign

| | assumption | gap |
|---|---|---|
| **B1** | multi-species works | **No gradient has ever been taken with two species.** Replay is verified in double only, and only with **equal widths** at every segment (both species introduced on the same schedule). Differing widths — the case the tie-break exists for — is untested. And P5 may force field rework before multi-species is meaningful at all |
| **B2** | the R0 path works | `set_birth_state` is called by **no test**, there is **no public API** to reach it (§2), and the rebuilt drift lands **precisely** in the slot R0 reads. Census gradients are unaffected |
| **B3** | the step unit is reachable | splitting `advance_fixed(e.times)` inside `SCM::run_next_impl` has **never been attempted**. TF24 requires it (18.43 steps/segment) |
| **B4** | the `Leaf` fix is a local change | unchosen (#37), and the choice **changes P9/P10**: per-unit Strategy forces adjoint summation *and* re-seating every Node. `Leaf` has **no structural boundary** between parameters and per-solve scratch (~30 loose doubles, 5 vectors, 4 interpolators, `leaf_model.h:139-200`) — which is why "audit the caches" decays |
| **B5** | the FF16 gate protects exactness | it asserts **1e-2** while the true agreement is **~1e-6** (§7.1). A **100× accuracy regression would pass green** |
| **B6** | the 4.2× time cost holds in plant | measured on an odelia toy at ~22 µs/unit. plant's per-unit cost is now known in isolation, but **no end-to-end plant sweep has been timed** |

### Tier C — known, bounded, documented

| | item |
|---|---|
| **C1** | restore is **not** bit-exact (~2e-5 relative on live state) → V3 |
| **C2** | **empty species 0 is latent UB** (`patch.h:758` dereferences `node_begin()` on an empty vector). Measured reachability **0** on one ordinary schedule; undefended in general |
| **C3** | `Patch::r_at` **does not compile** (`patch.h:179`); latent until instantiated |
| **C4** | the soil drying guard is a real severance, merely **unreachable**; `rainfall = 0` throws plant's own density guard (the plants fail first) |
| **C5** | P3 has **no structural defence** — only prose |
| **C6** | plant's suite carries 2 stale blessings + 1 pandoc error, all pre-existing |

---

## 7. Corrections made while compiling this

**7.1 — "FF16 has an open dropped-derivative bug" is STALE, and the truth is the opposite.**
`HANDOFF.md` Part 1 says *"This is FF16's current open bug; see PART 2"* — but Part 2 was rewritten
and no longer mentions it, so the reference dangles. `build-plan.md` records **AD −6299 vs FD −1630**,
and `test-ad-ff16-scm-gradient.R`'s STATUS header still records **a_l1 AD 0.0629 vs FD 0.1007** (a 38%
gap). **Measured today, that gap is gone** — the a1–a4 severance fixes closed it:

| channel | AD | FD | rel |
|---|---|---|---|
| lma (growth + self-shading) | −56.0698330 | −56.0699810 | **2.64e-06** |
| a_l1 (growth + self-shading) | 0.1007215 | 0.1007221 | **6.06e-06** |
| k_l (pure loss) | −2.6635231 | −2.6635231 | **1.31e-08** |

Value reproduces the double exactly (0.597074276) and `jvp == dot`. The test passes **6/6, no skips**.
So FF16's coupled self-shading gradient is exact to the FD's own noise floor. **Had this stayed
uncorrected, the next design would have been blocked on a bug that no longer exists** — and the loose
1e-2 gate (B5) is what let the stale story survive.
Re-run: `NOT_CRAN=true TESTTHAT_PARALLEL=false Rscript -e 'pkgload::load_all("plant"); library(odelia); testthat::test_file("plant/tests/testthat/test-ad-ff16-scm-gradient.R")'`

**7.2 — the exactness facts and the design's path are different columns.** `segment-rerecord-probe`'s
`from_copy_abs` (whole-`Patch` storage) is **exactly 0** for K93/FF16; `rebuilt_abs` (plain values +
restore — **what the design does**) drifts. "K93 replays bit-exactly" is a statement about the column
the design does *not* use.

**7.3 — the aux-lag question in `v3-control-flow.md` is closed**, and that document now carries the
answer inline rather than the open question.
