# TF24 Solver Performance — Session Handoff

> **Two-part document.** Part 1 (**PERSISTENT HEADER**) is authoritative and
> carries across every handoff — treat it as the constitution for this line of
> work, edit it only to correct a stated fact. Part 2 (**STATE & NEXT STEPS**)
> is rewritten each session. Read Part 1 in full before touching anything;
> it exists so context-loss does not reset the project to first principles.

---

# PART 1 — PERSISTENT HEADER (authoritative; rebuild context from this)

## 1. The overarching goal (DX-first)

Make the **TF24 soil-water / plant SCM faster in the forward direction and
stable in the reverse (AD) direction**, over the scenarios that actually matter:
**long horizons (~70 yr), dynamic and realistic rainfall (including multi-year
droughts and monsoonal bursts), and multi-species assemblies.** "Faster" and
"stable" are only meaningful *at the accuracy the downstream science needs* —
which is the accuracy at which the **offspring-production output and the
reverse-mode gradient (J) are converged**, not the tightest tolerance the
integrator can be pushed to.

This is a **developer-experience (DX) goal, not a benchmark-chasing goal.** The
win we want is a system that a scientist can run over hard scenarios without it
failing, stalling on step count, or drifting in reverse — and that a developer
can read and reason about. A 2× speedup bought with machinery that makes the
code unreadable is a loss, not a win.

## 2. odelia codesign

The numerical engine lives in **`odelia`** (a header-only C++ ODE library:
`Solver<System>`, steppers `rkck`/`rodas`/`mri`, XAD-based record→replay reverse
AD). `plant` is the client (the TF24 SCM). The working relationship is
**codesign**:

- New solver capability is **built and validated inside odelia first**, against
  cheap toy systems / demos where correctness is obvious, *then* wired into the
  real `plant` patch. Do not prototype engine features inside plant.
- plant consumes odelia as a normal dependency: **`library(odelia)`** (installed
  package), and **`pkgload::load_all()`** for plant itself.
- Keep the engine general and the client-specific glue in plant. A hook that
  only TF24 needs is a *trait the engine offers*, with the TF24 logic on the
  plant side.

## 3. How we work: system-design + code-review skills, every time

Before any non-trivial change, **invoke the `system-design` skill**; before
committing, **invoke the `code-review` skill.** These are not ceremony — they
are the guardrails that this project has repeatedly needed.

**The abstraction principle (the reviewer's north star), verbatim intent:**

> Prefer abstractions that *reduce* complexity, and push back on overbuilding.
> Abstractions for abstraction's sake make the DX hard. Great design picks
> boundaries that make the code dead simple to understand and reason about;
> having too many named objects works against that principle.

Concretely: **every new name (class, method, trait, config key, term) must pay
for a specific requirement.** If a reader must learn more than one or two
decisions before the rest of the code follows, it is overbuilt. The
`system-design` skill's floor-first procedure (dumbest thing that meets the
ledger wins unless a cited number kills it) is the default. "None found — the
floor was the design" is a good outcome.

## 4. Hard-won lessons (the traps this project has actually fallen into)

These are paid-for in wasted sessions. Do not relearn them.

1. **Measure the REAL coupled patch, never a surrogate.** The multirate effort
   was driven by a linear-relaxation *surrogate* canopy (#43) whose coupling was
   a free mean of θ. The real coupling — uptake `a_ℓ(θ) = Σ_j ρ_j c_ℓ(cohort_j,
   θ)` — is an **O(N) sum over per-cohort hydraulic solves**, state-dependent,
   and is *the dominant cost*. Every conclusion from the surrogate was wrong for
   the real system. Use `Solver<Patch<TF24,TF24_Environment>>` and the
   `patch_rhs_calls` / `mri_fast_rate_calls` counters (`plant/src/mri_diag.cpp`).

2. **The real stiffness is root uptake near θ_res, NOT drainage.** Drainage
   (`K(θ)`, exp≈16) and matric potential (`ψ(θ)`, exp≈−6.57) *look* stiff but
   soften-tests show they are not the step-limiter. The genuinely hard region is
   **the driest layer where cohorts are drawing water near residual θ** —
   `|J_full|` there is 50–291× the hydrology-only Jacobian. #43 measured
   hydrology-only and so missed this entirely.

3. **Layer-averaged / stand-averaged metrics mislead.** A metric averaged over
   5 soil layers or over a benign single-species run hides the one driest, stiff
   layer / the rare hard drought window. Always look at the worst layer and
   deliberately construct hard scenarios (multi-year drought, `gen_extreme`).

4. **Validate in J-units, not θ-units.** The reverse-mode gradient is ~10×
   hypersensitive relative to the forward state. A reformulation that is
   "neutral" on offspring output can still move J. Check the gradient, not just
   the trajectory.

5. **RODAS needs an AD Jacobian hook the patch does not have.** `method="rodas"`
   requires `Jacobian<System>` → a `rebind<U>()` on the System so the engine can
   run forward-AD for the Jacobian. The double-only `Patch` has no `rebind`, so
   **RODAS cannot run on the real coupled patch at all** (not just in reverse).
   Any implicit-stepper plan must first give the patch a templated rebind, or
   confine the implicit solve to a sub-block that has one.

6. **Don't over-generalize from an easy run to "solved" or "impossible".** Both
   directions have burned us: benign runs → "not stiff" (false); one slow MRI
   run → "steppers can't help" (too strong). State the scenario every number was
   measured on.

7. **⚠ "Converged reference" means BOTH tolerance families. `ode_tol` defaults to
   1e-4.** plant carries two independent families: **inner-solve** (`GSS_tol_abs`,
   `ci_abs_tol`) and **outer ODE** (`ode_tol_rel`, `ode_tol_abs`, **default 1e-4**).
   For an entire session we wrote `GSS_tol_abs <- 1e-12; ci_abs_tol <- 1e-12`, called
   it "the converged reference", and left `ode_tol` at 1e-4 — so the reference carried
   ~4e-3 of its own time-integration error. Measured (mean=1, amp=0.3, life=40):
   `ode_tol=1e-4` → J=35.1148736; `ode_tol=1e-5` → J=**35.2448663** (moves 3.7e-3);
   and `mri_uptake`'s own converged limit is ≈35.24 — i.e. **the reference was the
   outlier and the scheme under test was right.** Every accuracy number measured that
   way was wrong, and wrong in the **pessimistic** direction, which is exactly why it
   escaped notice: the scheme looked *worse* than it was, so nothing tripped a
   too-good-to-be-true check. **Corollary: an error that flatters your reference is as
   dangerous as one that flatters your method — sanity-check both directions.**
   **Structural fix, use it:** `scripts/tf24-benchmarks/converged_control.R` exposes
   `converged_control(ode_tol, inner_tol)` and `mri_uptake_control(days, ...)`. Never
   hand-roll the tolerance block again. Note the asymmetry that hid the bug:
   `mri_uptake` reports `yerr=0` (always accept), so `ode_tol` does **not** control it
   — its accuracy is set by `ode_step_size_max`/`mri_uptake_tol`/`nmicro`. Tightening
   "the tolerance" therefore moves the reference **only**, and a shared under-converged
   reference silently mis-scores every method that ignores it.

## 5. Security / process constraints (verbatim, non-negotiable)

- **Active development branches (post-split, 2026-07-22):**
  **`claude/tf24-forward-speed-n5audm`** (plant) and
  **`claude/tf24-forward-speed-engine`** (odelia). The `plant-dev` meta stays on
  **`claude/tf24-multi-rate-stepper-n5audm`** but its `.gitmodules` now tracks the
  two forward-speed branches (submodule SHAs unchanged: plant `5a48347b`, odelia
  `2f78191`). **Do the T6 build here.**
- **Frozen pre-split branches (the MRI/IMEX engine line, do NOT build on):**
  `claude/tf24-multi-rate-stepper-n5audm` (plant, ends at `9c8bd2d6`) and
  `claude/tf24-multirate-engine` (odelia, ends at `b88514d`). On 2026-07-22 the
  work was split: everything from the forcing-kink clip onward (classifier hooks,
  step monitor, slim cache, WR probe, **T6 Slice 1**) was moved to the
  forward-speed branches; these two were reset (force-pushed) back to the split
  commits so they carry only the MRI/collocation/IMEX/R-C block.
- **Push ONLY to `aornugent/*` forks. NEVER push to `traitecoevo/*`.**
- Commit trailers:
  `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>` and
  `Claude-Session: https://claude.ai/code/session_01BvyqPT8pVL7bCZvWqmhZHM`.
- **Never** put the model identifier in commits, PRs, code, or comments.
- git config: `user.email noreply@anthropic.com`, `user.name Claude`.
- Load odelia via `library(odelia)`; load plant via `pkgload::load_all`.
- **Production must be bit-identical when `ode_method != "mri"`.** This is the
  invariant that makes all the experimental machinery safe to carry.
- **Do NOT create PRs unless the user explicitly asks.**

## 6. How to rebuild context from scratch (do this first, every new session)

1. Read this whole file (Part 1 + Part 2).
2. Read the **current** docs (see Part 2 "Document map"): the live design
   `docs/oracle-consultation-event-aware{,-response}.md` and the round-6 verdict
   `docs/oracle-consultation-tf24-recharacterized{,-response}.md`. The
   `oracle-consultation-multirate-*` rounds and `tf24-multirate-*` docs are
   **superseded/historical** — read only for the audit trail, do not build from them.
3. Confirm branch state matches Part 2 (`git log --oneline -3` in all three
   repos). If a PR for the branch has merged, restart the branch from the
   default branch (see the process rules in the task brief).
4. Rebuild plant if you changed headers: `pkgload::load_all` recompiles.
5. Re-run the current baseline (Part 2's "current measurement" script) to
   confirm nothing regressed before building anything new.
6. **Confirm with the user before starting any tangential build.**

---

# PART 2 — STATE & NEXT STEPS (rewritten each session)

*Last updated: 2026-07-26 (session 7 — T6 Slice 4 DONE, then an Oracle review round, an escape CERTIFICATION, a #550 diagnosis, and a TOLERANCE CORRECTION that revises every offspring-accuracy number. NEXT = four per-leg COST priorities, see the ▶ NEXT SESSION block. Original Slice 4 entry follows.) (session 7 — T6 Slice 4 DONE: end-to-end scenario bank + the kutta3
accuracy fix. `mri_uptake` runs the full dynamic bank, out-surviving rkck (all 6 complete vs rkck's
3), death mode absent, 3–10× cohort-solve reduction; and the slow advance was upgraded
forward-Euler→kutta3 (odelia one-liner), cutting the dynamic-regime offspring bias 12%→<0.1% at the
weekly leg. bit-identical off; odelia toy 25/25 incl. adjoint <1e-6. See
`tf24-v2-T6-slice4-scenario-bank-result.md` and the "▶ NEXT SESSION" block. Session 6 built Slice
3b-iii DONE end-to-end — step 1 (toy odelia uptake integrator) PASS; step 2 (mri_uptake wired on the
real TF24 patch) PASS forward — 40× fewer O(M) cohort sums at 9.8e-3 offspring vs rkck, bit-identical
off. Session 5 built Slice 3b-i (stand ∂a/∂u, bit-identical) and
Slice 3b-ii (macro-step falsifier = GO, 2.9×–40×). Session 2 wrote the domain-clean v2 characterisation
(`oracle-consultation-fundamentals-v2.md`). Session 3 got the **v2 Oracle response** (a major
reframe, verbatim in `oracle-consultation-fundamentals-v2-response.md`), triaged it into a new
falsifier ladder (`tf24-v2-response-triage.md`), and ran the cheap offline falsifiers. The
forward-convergence question is now **RESOLVED**, and the diagnosis is the OPPOSITE of session 2's
tentative item-B conclusion.*

***THE HEADLINE (session 3): the forward problem is well-posed and the fix is NUMERICAL, not a
model change.*** *Three offline tests, reconciled in `tf24-v2-reconciliation.md` and stated for
plant maintainers in `tf24-offspring-convergence-finding.md`:*
- ***T1 (Arnoldi on T′, `tf24-v2-T1-arnoldi-result.md`):*** *the coupling-field fixed point is
  well-conditioned — spec(T′) has ρ≈7 but NOTHING at +1 (min|λ−1|≈0.05–0.2, cond ~5–22). The
  continuum J EXISTS and is a stable observable. (κ≈10 = WR divergence, NOT J ill-posedness.)*
- ***T5a (emergent skewness, `tf24-v2-T5a-emergent-skewness-result.md`):*** *the Oracle's claim-4
  premise is FALSE — max cohort weight fraction is ~1.6% (not ~40%) and ∝1/M; the measure refines
  cleanly, no heavy atom to split. (Oracle conflated 9a's second-SPECIES weight with a single
  cohort.) → T5 (splitting) DROPPED.*
- ***T3 (common-field ΔJ decomposition, `tf24-v2-T3-common-field-decomp-result.md`):*** *the
  9c/rung-2 non-convergence is **100% soil-water field-shift** (κ-amplified feedback), diffuse, at
  small τ_ins — NOT placement, NOT survivor-flips. **Item B is OFF the critical path**; rung-2's
  "intrinsic discontinuity, mollify the model" verdict is OVERTURNED. The fix is to converge the
  FIELD a*=∫c dμ (a c-weighted moment), which the default mesh under-resolves; this is why the
  reproduction-targeted refiner and g-mass indicator anti-correlated (J's integrand is already
  converged; the error is in the field).*

***PROTOTYPES this session:*** *P1 (static field-aware schedule, `tf24-v2-P1-field-aware-schedule-result.md`)
= NULL — dense-early is non-monotonic vs uniform (confounded by a uniform reference + J
hypersensitivity); corroborates that static/local placement can't see feedback-dominated error.
Uniform stays the pragmatic simple best but is not a convergence fix, and dense uniform is ~5× the
per-run cost. P2 (uptake-Taylor falsifier, `tf24-v2-P2-uptake-taylor-falsifier-result.md`) = **PASS**
— uptake is a low-order function of soil water over weekly windows and MOST predictable near the dry
limit (dry-tercile ~1%); the way the multirate/IMEX ancestors died is falsified. → **GO to T6.***

***T6 progress (session 6): Slice 1 SHIPPED; Slice 2 gate DONE; Slice 3a BUILT+VALIDATED; Slice 3b-i
(stand ∂a/∂u) BUILT+VALIDATED; Slice 3b-ii (falsifier) = GO (2.9×–40×); Slice 3b-iii DONE end-to-end
— step 1 (toy odelia integrator) PASS (accuracy ~5e-4, 9.7–16.5× coupling reduction, cheap monitor
within ~1.5× oracle, record→replay adjoint exact) and step 2 (mri_uptake on the real patch) PASS
forward (40× fewer O(M) cohort sums at 9.8e-3 offspring vs rkck, bit-identical off). Slice 4 (session
7) DONE — see below.*** ***T6 Slice 4 (session 7): scenario bank = speed/robustness demonstrator (rkck
crashes 3/6, all traces near-extinction at every trait+scale → offspring ill-conditioned on the bank,
lesson #4); accuracy assessed in a survivable dynamic regime instead. Forward-Euler slow advance had
an O(H) dynamic bias (12% at weekly leg); swapped to 3rd-order kutta3 (odelia one-liner, outright
swap not a control key) → ≤2e-4 at moderate seasonality, 2.3e-3 on the constant gate, bit-identical
off, toy adjoint intact. Bank post-kutta3: all 6 complete (kutta3 also un-crashed intense_storms),
3–10× cohort-solve reduction, 1–3.2× wall-clock (wall-clock wins only where the cohort sum dominates),
death mode absent.*** *The two levers on record:
(T6, chosen) the SPEED arbitrage — 10–100× fewer cohort solves (T4 headroom) via cohorts-on-a-
weekly-step with a cheap analytic uptake refresh; and (deferred) the ACCURACY refiner (P1 showed
static shapes fail). Item B not needed; rung 3 moot (T3: survivor-flips J-negligible).*

## ▶ NEXT SESSION — start here: T6 per-leg COST reduction (4 priorities, prescriptive)

**Branches (post-split): develop on `claude/tf24-forward-speed-n5audm` (plant) and
`claude/tf24-forward-speed-engine` (odelia); meta stays on
`claude/tf24-multi-rate-stepper-n5audm` and its `.gitmodules` tracks the two forward-speed
branches. Push ONLY to `aornugent/*`. See Part 1 §5.**

**THE FRAME (session 7's key finding — read this before choosing work).** Slice 4 shipped and
`mri_uptake` works. But re-measurement against a properly converged reference showed that **the
cohort-solve advantage evaporates exactly where the accuracy becomes good**: in the survivable
dynamic regime (amp=0.3) it is **3.8× fewer cohort solves at 3.5e-3**, and by H=1.75 d (error
≤4e-4, reference-limited) the coupling count 16868 ≈ rkck's 16581 RHS evals — **no saving at all.**
So the binding constraint is no longer accuracy; it is **per-leg member-sweep cost**. Every item
below lowers that, which is what widens the usable operating window. **Do NOT chase accuracy knobs
or the stress bank** (see §3a for what is parked and why).

**Also: stop quoting one reduction factor.** It is strongly regime-dependent — 40× on the
constant-rainfall gate, 3.8× in the dynamic regime at the same weekly leg, 3–10× on the stress bank.
Always state the regime.

### 0. Rebuild context (read in this order)
1. **Part 1 in full** (codesign rules, bit-identical invariant, branch/commit rules, hard-won lessons).
2. `docs/tf24-v2-T6-newton-uptake-BUILD-SPEC.md` — the build plan + the REUSE MAP + gate-result callouts.
3. The result docs, in order: `tf24-v2-T6-slice1-newton-collar-result.md`,
   `tf24-v2-T6-slice2-duptake-gate-result.md`, `tf24-v2-T6-slice3a-analytic-duptake-result.md`,
   `tf24-v2-T6-slice3b-i-stand-duptake-result.md`, `tf24-v2-T6-slice3b-ii-macrostep-falsifier-result.md`,
   `tf24-v2-T6-slice3b-iii-uptake-integrator-result.md` (toy),
   `tf24-v2-T6-slice3b-iii-step2-mri-uptake-patch-result.md` (the real-patch PASS), and
   `tf24-v2-T6-slice4-scenario-bank-result.md` (note its CORRECTION banner).
   **Then the three session-7 docs, which supersede numbers in the above — read all three:**
   **`tf24-v2-T6-tolerance-correction-and-remeasurement.md`** (why every offspring-accuracy figure
   moved, and the corrected table — read FIRST),
   **`tf24-v2-T6-refresh-sweep-escape-certification-result.md`** (the escape is certified), and
   **`tf24-v2-T6-density-blowup-550-investigation-result.md`** (the stress-bank crashes are a model
   divergence; what we may and may not claim).
   Oracle: `oracle-consultation-arbitrage-review{,-response}.md` (the response's §4 is refuted; its
   volunteered architecture is a target, not a licence to build) and the parked
   `oracle-consultation-hypersensitivity-extinction.md`.
4. Rebuild: **odelia first** (plant LinkingTo it), then plant.
   - odelia: from `odelia/`, `Rscript -e 'options(pkg.build_extra_flags=FALSE); pkgbuild::compile_dll(compile_attributes=FALSE)'`
     then `R CMD INSTALL --no-docs --no-byte-compile odelia` (installs headers plant compiles against).
   - plant: from `plant/`, `rm -f src/*.o src/*.so`, `Rscript -e "library(methods); RcppR6::RcppR6()"`,
     then `Rscript -e 'options(pkg.build_extra_flags=FALSE); pkgbuild::compile_dll(compile_attributes=TRUE, debug=FALSE)'`.
   Sanity (should reprint their headline numbers):
   `Rscript scripts/tf24-benchmarks/duptake_stand_gate.R` (dry tercile med ~1e-5);
   `Rscript scripts/tf24-benchmarks/macrostep_falsifier.R` (adaptive cohort-sums 1–14/40);
   `Rscript scripts/tf24-benchmarks/refresh_sweep.R` (escape certified: error falls with the forced
   re-anchor rate R in all 9 regimes, no floor above the ~3e-7 splitting error).
   In-package tests: from `odelia/`, `testthat::test_dir("tests/testthat", filter="example-uptake")` (25 pass).
   **`mri_uptake_gate.R` was re-pointed at a converged reference (lesson #7) and its headline number
   is NOT yet re-established — the re-run was still in flight at the end of session 7. Re-run it and
   record the result before quoting any gate figure.** Its old 9.8e-3 / 2.3e-3 were measured against
   an `ode_tol=1e-4` reference and are upper bounds on disagreement, not measurements.

### 1. What is already DONE and TRUE (do not rebuild; build on these)
- **Slice 1 (plant):** control key `newton_collar_solve` (OFF/bit-identical); ON = safeguarded
  `util::uniroot_smooth` (TOMS748) root-find on `Leaf::dprofit_droot_collar_psi==0` with the
  endpoint-sign safeguard (`g_a>0 && g_b<0` ⇒ interior; else boundary). Max rel 6.8e-4, 1.20×.
- **Slice 3a (plant):** `Leaf::compute_duptake_dpsi_soil()` fills `duptake_dpsi_soil_` (row-major
  `i*n+k`) = d(soil_consumption_[i])/d(psi_soil_inverted_[k]). Two branches keyed on the SAME
  g_a/g_b test (interior IFT on `dprofit=0`; boundary IFT on the active continuity condition — NOT a
  residual threshold). FD of closed-form leaf fns at the fixed operating point. Validated max 6.1e-4.
  Steps `hE=1e-6`, `hg=1e-5`.
- **Slice 3b-i (plant, DONE this session):** the stand uptake Jacobian, mirroring the
  `consumption_rate` chain. `Internals::duptake_jacobian` (row-major `i*ns+k`, already in
  soil-moisture space — the retention chain is folded in by the fill), filled per-cohort in
  `TF24_Strategy::compute_rates` behind **`control.compute_uptake_jacobian`** (default OFF →
  field empty → **bit-identical**, verified: SCM offspring OFF==ON to the last bit). Retention factor
  `TF24_Environment::duptake_retention_factor(k) = +n_psi·psi_mag/theta` (interior; 0 floored/capped),
  verified exact. Aggregated by `Patch::assemble_duptake_jacobian()` (density trapezium, sum/area);
  `Patch::resource_depletion()` exposes stand `a`. Both R-exposed. Gate
  `duptake_stand_gate.R`: dry tercile med **1.0e-5**, abs-err/global med **1.2e-4** / max 2.3e-3.
  (Wet relative error is FD-noise-limited — coupling scale ~0.03 vs 30.8 dry — not a Jacobian error;
  an h-sweep confirms the FD converges to the analytic value there.)
- **Slice 3b-ii (R, DONE this session) — the GO decision.** Offline macro-step falsifier
  (`macrostep_falsifier.R`): a split micro-stepper (`flow(dt/2)·residual(dt)·flow(dt/2)`) run
  byte-identically two ways over a weekly window, differing ONLY in the coupling channel — TRUE
  `a(u)` (O(M) cohort sum) vs LIN `a0+J(u−u0)`. **Result: the arbitrage is viable across the whole
  {wet,mid,dry}×{drought,drizzle,storm} bank** — an adaptive trust monitor (re-linearize when the
  error would exceed tol=1e-2) cuts cohort-sums to **1–14 of 40 (2.9×–40×)** while keeping soil
  accuracy **≤5.5e-4** everywhere. The MRI-ancestor death mode (cohort-sums ≈ nmicro) does NOT occur
  (worst 14/40, dry+storm rewetting). Without a monitor, dry+storm hits 650% `a`-error → the monitor
  is necessary and sufficient.
- **Key soil fact (used by the falsifier, reuse it in 3b-iii):** the coupling `a` enters the soil
  ODE ONLY through the uptake term `−a_i/dz_i` in `residual_rhs`; rainfall infiltration + inter-layer
  drainage cascade are `a`-independent (`analytic_partial_flow` + the rain/cascade terms). The soil
  balance = exact drainage flow ⊕ (rain+cascade+uptake) remainder. R surface already exposed:
  `TF24_Environment::r_residual_rhs(theta,a)`, `r_analytic_partial_flow(theta,dt)`.
- **THE TRUST-MONITOR SPEC (3b-ii's deliverable, now IMPLEMENTED in 3b-iii):** the linearization
  error is ~C·‖δu‖² and **corr(a_err, ‖δu‖²) = 0.985**. THE MONITOR LESSON (learned mid-build,
  3b-iii): trigger on the **2nd-order remainder** e² = (‖pred_a−a₀‖/‖a₀‖)² — NOT the first-order
  excursion ‖J·δu‖ (which over-triggered 12×, because `a` genuinely moves a lot; that is the whole
  point). e² is probe-free, needs only a₀ and J (Slice 3b-i), conservative by an O(1) factor
  (cheap count ≥ oracle = the safe direction). This is the production monitor form on the patch
  (`Patch::trust_excursion`).
- **Slice 3b-iii step 1 (odelia, DONE) — the toy integrator.** `tf24-v2-T6-slice3b-iii-uptake-
  integrator-result.md`. New inner `subcycle_uptake` (leg-start capture + fixed-nmicro micro-steps
  on the frozen affine coupling + trust-monitored re-capture; record→replay of the re-expansion
  indices via `MRISchedule.reexpansions`), `UptakeSubcycle` functor, `mri_coupling_evals`, and the
  `UptakeSystem` toy. Reuses `mri_macro_step`/`freeze_slow`/`MRISchedule` wholesale (for plant
  `coupling_size()==0` the MRI-GARK aggregate channel is already inert). Gate `test-example-uptake.R`
  PASS: accuracy ~5e-4, 9.7–16.5× coupling-eval reduction (death mode absent), cheap monitor within
  ~1.5× oracle, **record→replay adjoint matches FD <1e-6** (reverse mode proven on the toy).
- **Slice 3b-iii step 2 (plant, DONE) — mri_uptake on the real patch.** `tf24-v2-T6-slice3b-iii-
  step2-mri-uptake-patch-result.md`. odelia `Method::mri_uptake` + `MriUptakeStep` (mri_forward_euler
  coupling + `UptakeSubcycle`, shared `mri_step_run`); `subcycle_uptake` gained a Strang split
  micro-step (`analytic_flow·residual_frozen·analytic_flow`) for stiff Systems (`has_residual_frozen`).
  Plant patch hooks (all `if constexpr(env_has_split<E>)`-guarded → FF16/K93 no-ops, bit-identical):
  `refresh_anchor` (a₀=`fast_block_uptake`, J=`assemble_duptake_jacobian`, counts `mri_coupling_evals`),
  `predicted_uptake`, `residual_frozen`, `trust_excursion`, `trust_true_error` (oracle diagnostic).
  Control keys `mri_uptake_tol`(1e-2)/`mri_uptake_nmicro`(40); `scm_ode_method` maps "mri_uptake".
  Gate `mri_uptake_gate.R` (30-yr TF24 SCM): **40× fewer O(M) cohort sums** (1654 vs 66160 cheap
  residual evals) at **9.8e-3 offspring vs rkck**, **re-expansions = 0** (death mode absent),
  bit-identical off (TF24 default offspring 1.03714898556177 unchanged; FF16 runs).
- **HONEST SCOPING carried into Slice 4 (from step 2):** (a) the residual ~1% offspring error is the
  **order-1 MRI macro-discretization** (shared with `method="mri"`), NOT the refresh (0 re-expansions;
  refresh validated by 3b-ii ≤5.5e-4 + the toy ≤5e-4) — a Slice-4 knob (finer macro grid, or a
  higher-order coupling table e.g. `mri_kutta3` for the slow advance). (b) The SCM drives the solver
  with `advance_adaptive`; the macro-leg size is bounded via `ode_step_size_max` (set weekly in the
  gate). (c) A `method="mri"` full-resolve isolation is impractical (the >30-min 6–25× penalty T6
  removes) and confounded at short horizons by near-zero-J hypersensitivity (lesson #4; use ≥12 yr).
  (d) Patch-level REVERSE mode is NOT wired (forward is the deliverable; `reexpansions` is recorded
  and replay-ready; reverse proven on the toy only).
- **Session 7 (T6 post-Slice-4): four things established, two of them corrections.**
  1. **Escape CERTIFIED** (`refresh_sweep.R`, `tf24-v2-T6-refresh-sweep-escape-certification-result.md`).
     The affine coupling structurally escapes the frozen-coupling refutation: with the monitor OFF and
     the re-anchor rate R forced, the soil-trajectory error falls monotonically with R in **all 9**
     `{wet,mid,dry}×{drought,drizzle,storm}` regimes — smooth ones ~O(1/R²), kinked storm ones ~O(1/R)
     — with **no floor above the ~3e-7 splitting error**. The `dry+storm` re-rise leg (the 650%
     unmonitored blow-up, the Oracle's #1 re-entry worry) escapes cleanly. Contrast the held-`a`
     re-entry signature: a floor at O(0.1). **Consequence: the margin-box (M2) and curvature (M3)
     guards the Oracle proposed are convergence-RATE optimisations, not correctness fixes.**
  2. **The stress-bank crashes are plant#550, a MODEL divergence** (`ρ → +∞` in the weight equation),
     not a drainage overflow — see §3a and `tf24-v2-T6-density-blowup-550-investigation-result.md`.
     **New evidence:** T6 Slice 1 (`newton_collar_solve`) **rescues 1 of the 3 crashing traces**
     (`extended_drought` completes, J=5.65e-10), supporting #551's discontinuity mechanism on an issue
     upstream closed as not planned. **Correction it forced:** on that trace `mri_uptake` is **~1400×**
     below the now-obtainable reference, so "completes traces the reference cannot" is **NOT** a
     robustness win and the Slice 4 claim was softened.
  3. **⚠ CORRECTION — the tolerance error (hard-won lesson #7).** Every offspring-accuracy figure in
     Slice 4, the crosscheck and the gate was measured against a reference converged in only the
     inner-solve family, with `ode_tol` left at its **1e-4 default**. The reference was the outlier:
     `ode_tol=1e-4 → J=35.1148736`, `1e-5 → 35.2448663`, and mri_uptake's own limit is ≈35.24.
     **Corrected (amp=0.3): the weekly-leg error is 3.5e-3, not 1.8e-4** (the old figure was flattered
     by the bad reference *and* by a sign crossing). Full account:
     `tf24-v2-T6-tolerance-correction-and-remeasurement.md`. Structural fix: `converged_control.R`.
  4. **The order test is DEAD and the cost frame changed** — see the NEXT SESSION frame and P3.
- **Oracle round 6 (review) done; a follow-up submission is parked.**
  `oracle-consultation-arbitrage-review.md` + `-response.md` (includes a volunteered full target
  architecture, to be built only behind its ladder). Its §4 mechanism was **refuted** (see §3a).
  `oracle-consultation-hypersensitivity-extinction.md` is written and awaiting a response; it corrects
  a **material incompleteness in all five prior rounds** — none had ever disclosed the **weight
  equation** `d(log ρ)/dt = −∂g/∂ξ − m`, i.e. that the weight dynamics *differentiate* the member
  velocity field in the member coordinate (by one-sided FD, `eps=1e-6`), so `ρ` can diverge to **+∞**
  and not merely to the absorbing 0.
- **Foundational facts:** T4 → cohorts ≤3%-sensitive to sub-weekly soil (freeze weekly). P2 → uptake
  low-order in soil water, most predictable near dry. Arbitrage = freeze cohorts, sub-cycle soil,
  refresh `a` from `∂a/∂u` instead of the O(M) cohort sum.

### 2. THE REUSE MAP (retired MRI machinery, present in the tree — do NOT rebuild)
(Full detail in the build-spec Slice-3 note.) Reuse:
- **odelia** `inst/include/odelia/mri.hpp`: `mri_macro_step`/`mri_advance` (freeze-slow macro/micro
  skeleton), `MRISchedule` + `replay` flag (record→replay reverse-mode for free), the
  `AdaptiveSubcycle`/`SplitSubcycle` functor seam (l.270-287), `has_freeze_slow` trait;
  `ode_step_mri*.hpp` `MriStep`; `Method::mri` dispatch in `ode_solver_internal.hpp`. Toys +
  tests: `inst/include/examples/{two_rate_system,drainage_system}.hpp`,
  `tests/testthat/test-example-{two-rate,drainage}.R`.
- **plant** `inst/include/plant/patch.h`: `[slow=cohorts | fast=soil]` layout, `slow_size`/`fast_size`,
  **`freeze_slow`** (l.272-283 — freezes canopy + light field per leg = the macro-step freeze),
  `slow_rates`/`fast_rates`, `mri_split`, and the `record_uptake`/`sweep_soil`/
  `overwrite_cached_soil` probe (l.418-432, l.1082-1094 — the closest existing "freeze cohorts,
  sub-cycle soil vs a prescribed a(t)" scaffold). Control keys `ode_method`/`n_collocation_nodes`/
  `mri_use_split`; counters `mri_fast_rate_calls`/`patch_rhs_calls` (`src/mri_diag.cpp`).
- **The ONE thing to replace:** `fast_rates` (patch.h l.308-315) → `fast_block_uptake()` (l.289-302)
  → `assemble_resource_depletion()` (l.897-907) runs the O(M) cohort sum on EVERY fast-RHS eval
  (that is why the old MRI was 6–25× slower). T6 swaps it for `a ≈ a0 + (∂a/∂u)(u−u0)`, a NEW
  frozen-per-leg context (like `freeze_slow`), NOT the linear `aggregate`/g channel
  (`coupling_size()==0` for plant).

### 2b. Slice 3b build order — ✅ ALL DONE (see §1 for details + result docs)
- **3b-i — stand ∂a/∂u (plant). ✅ DONE.** Gate `duptake_stand_gate.R`.
- **3b-ii — offline macro-step falsifier (R). ✅ DONE = GO.** Falsifier `macrostep_falsifier.R`.
- **3b-iii — odelia integrator (toy) + real-patch wiring. ✅ DONE.** Step 1 gate
  `test-example-uptake.R`; step 2 gate `mri_uptake_gate.R`. `ode_method="mri_uptake"` exists,
  bit-identical off, 40× coupling reduction at 9.8e-3 offspring on the 30-yr single-species SCM.

### 3. Build order — the four priorities (prescriptive) — ← START HERE

Ordered by value-per-effort against the per-leg cost floor. **1 and 2 are measurements/refactors
with no new numerics; 3 needs two rebuilds; 4 is a real build.**

**P1 — Resolve the setup-caching contradiction (a MEASUREMENT, no build). Biggest certain win.**
Our own record contradicts itself and the Oracle flagged it: the cost-structure round said the
≈11-unit per-member setup is **`u`-independent and cacheable per macro interval**; the later
characterisation charged it per `u`-change. **One measurement settles it.** If the old claim holds,
the setup is cached across all three slow-advance stages **and** every re-expansion → **up to ~half
the member-loop cost**, which is larger than every other item here. Method: instrument the member
loop (or A/B a memoised vs non-memoised setup) at the weekly operating leg in the survivable dynamic
regime; report setup vs objective-eval vs argmax shares of one sweep. Plant already memoises some
θ-independent per-cohort setup (see the R1 issue item 7, "setup-cache seam") — check what is actually
reused before building anything.

**P2 — Fuse the anchor capture with the slow advance's first stage. ~25% off the floor.**
Today a leg pays 4 member sweeps: the anchor (`refresh_anchor`: `a₀` + `G`) plus 3 slow-advance
stages. The same loop can emit `ẋ`, `a₀` and `G` sharing one setup ⇒ **4 → 3 sweeps/leg**. Do this
after P1, because what can be shared depends on what the setup caching allows. `refresh_anchor` and
`compute_species_rates`/`assemble_resource_depletion` are the seam (`plant/inst/include/plant/patch.h`).

**P3 — `mri_heun` vs `mri_kutta3` A/B at the fixed operating leg. Another ~third.**
Settles 3 → 2 sweeps/leg. **This replaces the H-sweep order test, which is DEAD** (§1: the scheme is
not in an asymptotic regime; a ~2.7e-3 deterministic jitter floor in J-vs-H makes order unextractable
at *any* reference quality). Method: rebuild odelia with `mri_heun()` at
`ode_step_mri_impl.hpp:MriUptakeStep::step` (one line, same place kutta3 went), re-run the corrected
gate + the amp=0.3 dynamic point, compare **J error and coupling count** against kutta3. Decision:
if Heun holds ≲ kutta3's 3.5e-3 at the weekly leg, ship it and take the sweep back. Two rebuilds
(~4 min each) — budget for them.

**P4 — Adaptive H with a prior-conditioned schedule. Biggest build, do last.**
Re-expansion rates of **0.11–0.53 per leg** say the legs have real headroom, and the drive/gate
geometry is known a priori, so the H-schedule can be precomputed with the trust monitor absorbing
only state-dependent surprises. The 3-stage table embeds a 2nd-order companion, giving a **free
slow-error estimate** to accept/reject legs on. `system-design` this before writing code; it also
subsumes the old "fixed macro grid in `scm.h`" idea.

### 3a. Parked, with reasons (do NOT restart these without a new reason)
- **The stress bank as an ACCURACY test.** It is a cost/monitor measurement only. The rkck crashes
  there are **plant#550**, a *model-level* cohort-density divergence (`ρ → +∞`), not a solver
  overflow — upstream's own position (plant#552) is *"trustworthy completion is blocked on the
  model"*, and #551 (the `opt_psi_stem`-discontinuity root cause) was **closed as not planned**. See
  `tf24-v2-T6-density-blowup-550-investigation-result.md`.
- **The Oracle's rung #5 (retrofit the exact recession into the global RK).** Refuted before
  building: the crashes are the density mode, never the soil mode. A solver fix for a non-solver
  failure.
- **The H-sweep order test.** Dead, see P3.
- **Patch-level reverse mode / the `∂²a/∂u∂(x,θ)` HVP.** Real and unscoped, but a separate subsystem
  and forward is the deliverable. Keep the door open (see §1's reverse-mode note); do not build now.
- **Hypersensitivity/extinction.** A submission is written and parked:
  `oracle-consultation-hypersensitivity-extinction.md` (awaiting a response).

### 4. Discipline (the reason this is working)
Gate offline before every C++ build; validate bit-identical-OFF; run `system-design` before a
non-trivial change and `code-review` before every commit (Part 1 §3). Gates keep catching real
problems before they ship: Slice 2 (interior-only wrong on dry/boundary states); Slice 3a
(residual-threshold boundary dispatch → keyed off g_a/g_b); Slice 3b-iii step 1 (the trust monitor
first triggered on the FIRST-order excursion ‖J·δu‖ → over-triggered 12×; fixed to the 2nd-order
remainder e², the safe form now on the patch); Slice 3b-iii step 2 code-review (deleted dead
`fast_rates_frozen`). Keep doing this. NOTE the generic-Patch trap (seen twice, 3b-i and 3b-iii):
a `Patch` method that calls a TF24-only environment method (e.g. `get_soil_number_of_depths`) breaks
FF16/K93 compilation — guard the body with `if constexpr (env_has_split<E>::value)`.

### Session-2 measure-axis context (superseded by session-3's resolution; audit trail only)

- **Do NOT rebuild from these as if open:** the session-2 ladder (ghost/WR/placement) and its
  tentative item-B routing are SUPERSEDED — T3 showed the non-convergence is field-shift, not the
  survival discontinuity, so item B is off the critical path.
- Session-2 authority docs (historical): `docs/tf24-two-oracle-synthesis.md`,
   `docs/tf24-correction-response-triage.md`, the ladder result docs, and the verbatim responses
   `docs/oracle-consultation-fundamentals-response-{fresh,ongoing}.md`,
   `docs/oracle-consultation-correction-response-fresh.md`, elicitations
   `docs/oracle-consultation-fundamentals{,-correction}.md`
   (both domain-clean — keep them that way; the classifier trips on soil/cohort/rain/
   leaf/etc.).
3. **What is settled this session (do not relitigate):**
   - **The measure axis carries the dominant *reproducible* error, not the time axis.**
     The production run uses a *fixed* insertion schedule that is **~6× from mesh-converged**
     (J 2.15e-6 fixed vs 3.4e-7 refined on one sequence); even two *refined* meshes differ
     ~2.3%. Fixed uniform densification is **not asymptotic** (Richardson order p≈0.2,
     negative extrapolant — `docs/tf24-richardson-result.md`): placement, not count,
     converges the measure. So a *certificate* for J needs adaptive/goal-oriented placement,
     not the >15-min refiner. The tol-band "production at loose edge" check is **unresolved**
     (confounded by the unconverged mesh; redo on a converged measure).
   - **Forcing spline knots (fresh Oracle's top stone): real but minor.** A step crossing a
     C² daily knot rejects +12–36 pp more (size-controlled), but only **1.3–3.9 pp of the
     ~30% rejection** is knot-attributable. Not a frontier-reopener
     (`docs/tf24-node-distance-result.md`). Corrected the elicitation's §4 error (forcing is
     a C² cubic spline, not piecewise-linear).
   - **The error norm is an extreme value over a growing member block (item D,
     confirmed).** 192–345 distinct components attain `rmax` among rejects (entropy
     0.77–0.83); members dominate over reservoirs (~70/30); consecutive churn 0.23–0.28
     (drifts, not memoryless → nothing for a serial predictor, explains the PI failure).
     `docs/tf24-argmax-churn-result.md`.
   - **The J-weighted-norm lever is real but modest.** The norm-weight join
     (`docs/tf24-norm-weight-join-result.md`): the `rmax`-attaining member is J-marginal
     (<10% species weight) on 50–69% of member-limited steps — but the distance-to-removal
     split shows **⅓–½ of those marginal setters are *dying*** (`d(log ρ)/dt < −1`,
     heading to the `ρ→0` boundary = survival bits that must keep full weight). Net cleanly-
     reclaimable ≈ **10–20% of accepted steps**, gated by a survival guard band. Worth a
     prototype only if that's judged worth the machinery; the architectural stone (WR) likely
     beats it.
   - **`J`'s inter-mesh spread is BOTH diffuse and survival-bits** (`docs/tf24-deltaJ-decomp-result.md`,
     first cut on an unconverged pair): median relative per-lineage error 0.53 (diffuse) with
     a 1532× spike (a survival flip). Clean separation needs a *both-converged* mesh pair.

4. **The frontier / build order (fresh Oracle's falsification ladder, cheapest-first —
   `docs/tf24-correction-response-triage.md`):**
   - **Cheap rungs DONE:** knots (minor), churn (confirmed), Richardson (fixed family
     non-asymptotic → certificate needs goal-oriented placement), norm-weight join +
     ldr split (modest lever).
   - **The unlock — DONE and VALIDATED (2026-07-21):** **ghost members = `run_mutant`.**
     The OOM was the RK45 cache storing a full `Environment` (incl. the light spline's
     adaptive builder + band workspace, both replay-unused) per sub-step. Fixed by caching
     only the field a replay reads — light knots + soil state, `EnvStepRecord` (plant
     `b2f70dfa`, bit-identical, `test-mutant.R` green). 12-yr ghost now peaks **1.14 GB**
     (was OOM). **Item 1 validated:** frozen-field error is O(mass fraction), →0 as ρ→0
     (relJ 63→0.42→0.036→0.003 as probe mass 0.39→0.06→0.006→0.0006); `J_real→J_ghost` as
     mass→0. The ghost is an exact rare-invasion / marginal-member probe. **3 yr is
     pre-reproductive (J~1e-15); use ≥12 yr** (J~2.7e-7). Result +
     scripts: `docs/tf24-ghost-validate-result.md`, `scripts/tf24-benchmarks/ghost_{validate,massfrac}.R`.
   - **Rung 5 (WR contraction) — RUN and KILLED (2026-07-21).** Built the probe (plant
     `0015c9fd`: `record_uptake` + `sweep_soil` + `overwrite_cached_soil`, off by default,
     bit-identical, `test-mutant` green) and measured the Picard contraction of
     `a→u→members→a` on saved fields. **κ ≈ 10 ≫ 1**, uniform across δ and across all six
     2-yr windows (δ=0 round-trip sanity 1.1%). Plain/windowed/damped WR **diverges** — it is
     the same ~10× coupling amplification already on record (members respond enormously near
     `u_min`, the 50–291× region). Only Anderson/Newton–Krylov on the small `a(t)+s` fixed
     point could work, which abandons WR's cheap-Picard appeal. Retired as posed. Full result:
     `docs/tf24-wr-contraction-result.md`. Probe hooks kept as documented diagnostics.
   - **Rung 2 (goal-oriented placement) — RUN and does NOT fund (2026-07-21).** Tested across
     the measure-stressing bank scenarios (extended_drought, dry_to_wet, long_horizon,
     whiplash). (i) The Oracle's hierarchical-surplus indicator is **anti-correlated** with
     the J-error (Spearman −0.56…−0.86); error sits ~100% at small τ_ins (J's mass), not at
     surplus peaks. (ii) g-mass placement doesn't robustly beat uniform (loses on the deep
     long_horizon mesh). (iii) **Schedule-neutral convergence: J does not converge under
     node-count refinement for ANY family** — successive deltas grow, families disagree
     9–45% at 4×. This is the **survival-flip discontinuity** (refining moves which members
     cross ρ→0), not a placement problem — nothing to place *toward*. Routes to **item B
     (J mollification, model-side)** as the real measure-axis requirement, exactly as both
     fundamentals Oracles said. Cheap DX side-win: the production **default schedule is badly
     placed** (whiplash 847% off); plain uniform is 3–35× closer at matched count. Full
     result: `docs/tf24-goal-placement-result.md`; scripts `goal_placement_{predict,test,converge}.R`.
   - **Surviving ladder (NOT run — user paused here this session):** rung 3 (certified survival
     crossings via ghost bisection in `τ_ins`), paired with the **rainfall-as-locator test**
     (drought windows in the known forcing should predict the lineage-ages carrying survival
     crossings → free bracket). This would quantify the discontinuity to inform item B's
     mollification width. **Item B (J mollification)** is the identified measure-axis requirement
     but is a model-side decision (survival-margin window width), not numerics. The user chose to
     **pause after the Oracle update** rather than run rung 3 — the forward-numerics frontier is
     already resolved to a conclusion. Rung 3 is the clean head of the queue for next session.
   - **Model-side, logged not built:** Newton-on-`g` / the bordered-fold locator for the
     gradient seam (plant#60, updated this session with the exact `{F=0, ∂F/∂r=0}` system);
     J mollification; multi-block NaN-guard/growth-clip.
   - **E4 / adjoint correctness (task #23)** still the one un-run high-value correctness test.

5. **Rebuild env only to run code:** `R CMD INSTALL --no-docs --no-byte-compile odelia`;
   then `rm -f plant/src/*.o plant/src/*.so` and `options(pkg.build_extra_flags=FALSE);
   pkgload::load_all("plant", export_all=TRUE)`. The **norm-weight-join instrument** is built
   (odelia `step_monitor` hook gained an `rmax_index` arg; plant `Patch::step_monitor` appends
   the attaining member's ρ, weight-fraction, and `d(log ρ)/dt`) — **bit-identical off,
   verified rel=0**. `step_argmax_*` log (which component sets `rmax` per attempt) also built.

Still standing independently: the **pruning sign-off** (task #20) and the
**multispecies-capture** harness fix.

## Gate result (2026-07-20) — the event stepper is dead; the frontier is the mesh/J

Build-order #1 (forcing-kink clip) shipped: bit-identical off, offspring
preserved, cost-neutral, small reject reduction; only ~2 % of accepted steps land
on forcing features — confirming forcing is a minor step driver.

Build-order #2 (the classifier gate) is **done and decisive: INTRINSIC.** The
shadow-monitor + per-cohort branch-signature instrument (odelia `step_monitor`,
plant `tf24_solve_diag`, bit-identical off) ran the full bank at converged tol.
Across all 5 scenarios (20–70 yr, wet and dry): the hypothesized event surfaces
are **never approached** (soil clamps/runoff never fire; leaf-shutdown margin
never below 4.66 — shutdown is at 0; argmax collapsed-interval never fires;
≥99.8 % of cohort solves take the smooth GSS branch), and the ~30 % rejection
waste **does not co-locate** with the discrete events that do fire (median 2 %
within ±1 step). Step size is weakly predicted only by *continuous* structure
(GSS interval width / soil wetness, ρ≈0.3–0.4). **The kill question is answered:
the 70–98 % collapse is intrinsic fast structure, not removable events.** So
spec §4a–4e (dense output, event location, active-set, transition handlers) are
**not built** — they would buy ~nothing. Full write-up:
`docs/tf24-classifier-gate-result.md`. A stress battery (whole-profile drydown,
TF24f, multispecies) confirmed INTRINSIC holds at the dry extreme and surfaced two
findings: (i) **leaf shutdown is nearly unreachable by construction** — it keys on
the wettest accessible layer and even 12 yr zero rain can't dry the profile to
psi_crit; the stand dies of carbon starvation from the drying topsoil while a wet
deep layer persists (`docs/tf24-soil-profile-eco.md`, task #24); (ii) **TF24f is
too fragile to run on hard sequences** — the tracked-ψ control leaves the feasible
leaf-solve domain at the default `k_acclim=1` (**filed plant#61**), so the
"delete the argmax via TF24f" lever needs a feasibility guard first. Next: the
proximity governor is optional (small expected win, since rejections don't
co-locate); the real work is the **coupling-weighted mesh + J** (§7 below).
Remaining battery gap: multispecies capture (harness birth-rate API mismatch).
Filed: **plant#61** (TF24f tracked-ψ leaves the feasible domain at default k_acclim)
and **plant#62** (leaf shutdown nearly unreachable — wettest-layer keying). Oracle
consult written as a deep neutral characterisation (no directed questions):
**`docs/oracle-consultation-intrinsic-characterisation.md`** — the classifier is
the Oracle's own E1/build-#2 and its result *refutes* the round-6/7 event-program
bet (collapse is intrinsic/broadband, not removable events; enrichment lift ≈0.8–1.0).

## Where we are (one paragraph)

Seven Oracle rounds + direct measurement settled that the **time-integrator is not
the lever** (no block decomposition beats global explicit RK at converged `J`). The
round-6/7 verdict then proposed one forward pathway — an **event-aware** global
explicit RK (step-to-event) — gated on a classifier (build-#2 / E1) that would
first prove the step-collapse is made of **removable events**. **We built that gate
and it refuted the premise:** the collapse is **intrinsic/broadband**, not
event-attributable (enrichment lift ≈0.8–1.0; event surfaces fire <0.5%; the
dominant hypothesised event is unreachable *by construction*; the argmax-bound
event never fires; the one control-smoothing remedy, tracked-`p`/TF24f, is
numerically infeasible as posed → plant#61). So **§4a–4e of the event spec are not
built.** The forcing clip (#21) shipped anyway (free). The remaining forward
frontier is the **member mesh + functional `J`** (§7). A deep-characterisation
consult reporting all this is written and awaiting the Oracle. Two correctness
items sit outside the perf work: the **reverse-mode gradient bug** (plant#60, E4,
task #23) and the **multi-block non-finite failure** (diagnosed H1/overflow).

## Repo state (exact)

| repo | branch | HEAD |
|---|---|---|
| plant-dev (meta) | `claude/tf24-multi-rate-stepper-n5audm` | `e719cfd` (session-7: Slice 4 result + kutta3, escape certification, #550 investigation, Oracle review round + hypersensitivity submission, tolerance correction + `converged_control.R`, four-priority handoff) |
| plant (active) | `claude/tf24-forward-speed-n5audm` | `c4845c4d` (+ **Slice 3b-iii step 2**: `ode_method="mri_uptake"` patch hooks `refresh_anchor`/`predicted_uptake`/`residual_frozen`/`trust_excursion`/`trust_true_error`, control keys `mri_uptake_tol`/`nmicro`, `mri_coupling_evals` counter; over Slice 1/3a/3b-i) |
| plant (frozen) | `claude/tf24-multi-rate-stepper-n5audm` | `9c8bd2d6` (pre-split MRI/collocation/IMEX/R-C block only) |
| odelia (active) | `claude/tf24-forward-speed-engine` | `8de3907` (+ **Slice 4**: `mri_kutta3()` slow advance in `MriUptakeStep::step`, replacing `mri_forward_euler` — cuts the dynamic-regime O(H) offspring bias; over `3cfed4e` (+ **Slice 3b-iii**: `subcycle_uptake`+`UptakeSubcycle`+`MRISchedule.reexpansions`+`mri_coupling_evals`, `Method::mri_uptake`+`MriUptakeStep`+`mri_step_run`, `UptakeSystem` toy + `test-example-uptake.R`) |
| odelia (frozen) | `claude/tf24-multirate-engine` | `b88514d` (pre-split MRI/RODAS/IMEX engine block only) |

**2026-07-22 branch split:** the current work was divided at plant `9c8bd2d6` /
odelia `b88514d`. The pre-split MRI/IMEX engine line stays on the original branch
names (frozen at those commits); all later diagnostic + T6 work continues on the
new `tf24-forward-speed-*` branches, which the meta `.gitmodules` now tracks.

**Session 3 changed no C++** — all findings came from R probes on saved fields reusing the
session-2 machinery (`set_record_uptake`/`run_mutant`/`sweep_soil`/`overwrite_cached_soil`). T6 is
the first session-3 C++ build (not yet started).

All three clean and pushed to `aornugent/*`. Open PRs: none (do not open without explicit
ask). Issues filed: **odelia#47** this session (L3 replay: record only the recomputable
field, per the slim-cache precedent); **plant#61** (TF24f tracked-ψ leaves the feasible
leaf-solve domain at default `k_acclim`) and **plant#62** (leaf shutdown near-unreachable —
wettest-layer keying) in the prior session.

## What is built (all bit-identical when off; kept as documented diagnostics)

- **MRI** (`ode_method="mri"`): partition works (cuts cohort evals ~7.6×) but each
  soil micro-step re-pays the O(N) coupling → slower than rkck. Engine: `odelia`
  `mri.hpp`; plant partition hooks on `Patch`.
- **Collocation** (`control$n_collocation_nodes`): ~3× cost win but 25–279% error
  on evolved stands (the evolved measure defeats blind subsampling).
- **IMEX** (`ode_method="imex"`, RODAS4 + block-FD Jacobian): measured 20–50×
  worse (the deficit was later shown to be RODAS order-reduction from a noisy
  FD-Jacobian through the argmax; either way, not the lever). Kept as a diagnostic.
- **R-C (correctness, keep):** a shut-down TF24 leaf draws no water — removes
  phantom uptake + fixes a dead-drought AD-gradient bug (`leaf_model.cpp`,
  `test-tf24-shutdown.R`).
- **R-D (experiment, CONFIRMED DEAD — REVERTED #19):** soil log-depletion chart
  ζ=ln(θ−θ_res). Verified neutral and reverted; production byte-identical to the
  pre-R-D state. Done.
- **Benchmark bank + instrumentation:** `scripts/tf24-benchmarks/` (6 canonical
  hard rainfall sequences as `data/*.rds` + generator + `event_sizing.R` +
  `RESULTS.md`); odelia `step_diag` step-attempt log (off by default).
- **Forcing-kink clip (#21, shipped):** odelia `has_clip_times` + `clip_forcing`
  control; plant `clip_time_after` / `extrinsic_drivers_next_node_after`. Clips
  trial steps to rainfall feature knots. Bit-identical off; cost-neutral.
- **Stage-1 classifier instrument (#22, shipped; the GATE):** odelia
  `step_monitor` (per-accepted-step margins + branch signatures, `step_diag`
  storage + `has_step_monitor` trait) and plant `Patch::step_monitor` /
  `tf24_solve_diag` per-cohort branch sink / `TF24_Environment::soil_event_margins`.
  Bit-identical off. Verdict INTRINSIC (see "Gate result" above);
  `scripts/tf24-benchmarks/classifier_{capture,analyze}.R`.

## Measured facts that anchor the plan

- **Classifier gate (E1 / build-#2), the current authority — supersedes the earlier
  event-sizing interpretation.** ~27–35% of step attempts rejected; min h
  ≈1e-8–1e-9·T scattered. The earlier read ("70–98% unattributed → dry-end
  state-dependent crossings: shutdown/argmax/θ_res") was a **hypothesis; the gate
  refuted it.** Measured across 5 bank scenarios + drydown (all bit-identical
  monitored): rejections co-locate with an event-surface flip only **2–4% (median
  2%)** of the time; the member solve is **≥99.7% the single smooth branch**;
  switch-off fires **<0.5%** and its margin never reaches 0 (unreachable by
  construction, plant#62); the **argmax-bound (degenerate-interval) event never
  fires (0)**; clamps/runoff never fire. Enrichment `P(event|hard)/P(event|easy)
  ≈ 0.8–1.0` → **collapse is intrinsic/broadband.** The only (weak) continuous
  predictor of step size is the **argmax feasible-interval width** (Spearman
  ρ≈0.24–0.42) and, collinearly, soil-depletion margins (ρ≈0.4). Full write-up:
  `docs/tf24-classifier-gate-result.md`.
- **Multi-block failure:** multispecies (4 spp) goes non-finite at t=5.745 yr with
  the step **growing** (h up to ~0.25 yr) → **not** coupled-mode stiffness (H2);
  signature is H1 large-step overshoot / density overflow (`exp(log_density)→Inf`).
  (Classifier multispecies capture is still blocked on a harness birth-rate API
  fix — a remaining gap.)
- **`J` is ~10× hypersensitive** (23% inter-scheme spread) — validate in J-units.

## The forward pathway — event-aware integrator (Oracle round-7 build order) — ⚠ LARGELY RETIRED BY ITS OWN GATE

**Status:** step 1 shipped (clip); step 2 (the gate) ran and **refuted** the premise
of steps 3–4 → **steps 4a–4e are not built** (see the gate result above; the spec
`docs/tf24-event-aware-spec.md §3` now carries the INTRINSIC verdict inline). Step 3
(proximity governor) is optional and low-value (rejections don't co-locate, so it
has little to grip). **Step 5 (member mesh + `J`) is the surviving frontier.** The
build order is kept below for the audit trail; do **not** build 4a–4e without a new
Oracle mandate that overturns the gate.

**Spec (now historical for §4, live for §7): `docs/tf24-event-aware-spec.md`**
(verified coupling map; system-design ledger; codesign split; acceptance vs
`BASELINE.md`).

Full design rationale: `docs/oracle-consultation-event-aware{,-response}.md`.
Design = step-to-event on the same global explicit RK; the localizer and the
removable-vs-intrinsic **classifier are one instrument.**

1. **Forcing-kink step clipping** — clip trial steps to the known rainfall-kink
   table. ~5 lines, zero risk, removes the 2–31% kink share. Ship first.
2. **Shadow-monitor + branch-signature run (THE GATE).** Per accepted step, log all
   cheap event functions (heavy-member shutdown margin, clamp margin θ−θ_res,
   argmax-bound margin, kink proximity) **+ an integer branch signature from inside
   each per-cohort solve** (0 extra solves). Sign/signature flips time-stamp every
   crossing incl. un-hypothesized ones. Attribution + a smooth-arc refinement test
   (poly fit vs discontinuity) splits the 70–98% residual into event-attributable
   vs intrinsic. **Decides whether the full build pays off.**
3. **Proximity governor** — cap the trial step at ~1.2× time-to-nearest-event
   (from logged margins + drift) → converts rejection bisection (O(N)×5–15 probes)
   into one dense-output root solve. Targets the ~30% rejection overhead. Also the
   likely cure for the multi-block H1 overshoot.
4. **Dense-output event location + hot restart** (full stage recompute, never reuse
   FSAL across an event) for the shutdown threshold; **clamp active-set** (pin/
   release, not hysteresis); **tracked-p (TF24f)** to delete the argmax-bound class.
5. **Member mesh + functional (the real frontier).** Add a **coupling-weighted
   (ρ·|c|) refinement indicator** (free — the full-M byproducts exist every step);
   re-run the M-refinement certification of `J`. Reconsider `J`'s conditioning
   (reformulation may beat any numerics — a model-side call).

## Next actions (in order)

0. **[gated on the Oracle] Receive + triage the response** — see the "▶ NEXT
   SESSION" block at the top: save it dated, then reduce every claim to the cheapest
   falsifiable test (raw classifier data lets you test attribution/geometry reframes
   for free) and run it before building. This is the head of the queue.
1. **[frontier, most likely next build] Coupling-weighted (ρ·|c|) mesh refinement +
   `J` re-certification** (§7 / event build-order step 5 — the surviving frontier).
   The insertion schedule resolves `x(t)` but `J` depends on `∫c·ρ`; add a `ρ·|c|`
   refinement indicator (free — the full-M byproducts exist every step) and re-run
   the M-refinement certification of `J`. Attacks the 24%-class error + 23%
   inter-scheme spread at the root. **Do this unless the Oracle redirects.**
2. **[correctness, separate branch] Gradient bug (plant#60 / E4):** the one prior
   Oracle item not yet tested. Verify on `claude/odelia-ad-tape-reverse-496fuf` —
   adjoint dJ/dθ vs a true FD that **re-optimizes the argmax**, on a real transpiring
   patch state (the envelope-at-fixed-p* recipe may drop `(∂c/∂p)(∂p*/∂u)`). Task #23.
3. **[code-review sign-off] Pruning pass (task #20):** deletion of MRI / collocation /
   `mri_use_split` — analysis done, physical deletion **awaiting user sign-off**.
   Keep IMEX + R-C. Bit-identical-off licenses it. Now *more* justified: the frame is
   fully retired by the gate.
4. **[coverage gap] Multispecies classifier capture** — fix the `add_strategies`
   birth-rate API mismatch in `classifier_battery.R` (needs per-species birth rate;
   `rep(1,n)` did not satisfy it — check `add_strategies` signature), then capture the
   R3 failure case through the monitor. Also the natural place to confirm whether the
   multi-block H1 blow-up co-locates with any event.
5. **[optional, low-value] Proximity governor** — only if a reject-fraction win is
   wanted; expected small since rejections don't co-locate with event surfaces.

## Document map (status)

**Current / authoritative (session 3 — the live line of work)**
- `tf24-solver-performance-HANDOFF.md` — this file (the build plan).
- **`tf24-v2-T6-newton-uptake-BUILD-SPEC.md` — the T6 build plan (prescriptive).**
- **`tf24-v2-T6-slice1-newton-collar-result.md` — Slice 1 DONE (Newton/gradient collar
  solve shipped; bit-identical off, ON matches GSS max rel 6.8e-4, 1.20× whole-solve).**
- **`tf24-v2-T6-slice2-duptake-gate-result.md` — Slice 2 gate DONE (CONDITIONAL GO). Interior
  IFT ∂a/∂u validated to ~1e-4; found interior IFT fails on BOUNDARY-PINNED operating points
  (dry regime, Spearman 0.71 vs stationarity residual). Slice 3 ∂a/∂u must be TWO-BRANCH.**
- **`tf24-v2-T6-slice3b-iii-uptake-integrator-result.md` — Slice 3b-iii step 1 (toy odelia
  integrator) PASS: `subcycle_uptake`/`UptakeSubcycle`, the 2nd-order monitor lesson, 9.7–16.5×
  reduction, record→replay adjoint <1e-6.**
- **`tf24-v2-T6-slice3b-iii-step2-mri-uptake-patch-result.md` — Slice 3b-iii step 2 (mri_uptake on
  the real patch) PASS forward: 40× coupling reduction at 9.8e-3 offspring, bit-identical off, +
  the honest scoping Slice 4 must resolve.**
- **`tf24-v2-T6-slice3a-analytic-duptake-result.md` — Slice 3a DONE. Two-branch analytic C++
  `Leaf::compute_duptake_dpsi_soil` (interior IFT + boundary continuity IFT, dispatched by the
  g_a/g_b signs from Slice 1); re-gated analytic-vs-FD across the bank: ALL med 4.2e-5 / max
  6.1e-4, DRY med 4.0e-5. Bit-identical (not on production path). NEXT: Slice 3b (rho-weighted
  stand ∂a/∂u + retention chain, then the odelia macro/micro integrator + trust monitor).**
- `tf24-offspring-convergence-finding.md` — the finding for plant maintainers (concrete, no
  formalism): offspring non-convergence = under-resolved soil-water field × feedback, not the
  model; fix is a field-targeted schedule, not the reproduction-targeted refiner.
- `tf24-v2-reconciliation.md` — how the two experimental arms meet; the T1/T5a/T3 synthesis.
- `oracle-consultation-fundamentals-v2.md` + `-response.md` — the v2 characterisation (sent) and
  the Oracle's reframe (received, verbatim).
- `tf24-v2-response-triage.md` — the falsifier ladder (T1–T6) with per-test verdicts.
- Result docs: `tf24-v2-T1-arnoldi-result.md` (field well-conditioned),
  `tf24-v2-T5a-emergent-skewness-result.md` (no heavy atom; claim-4 false),
  `tf24-v2-T3-common-field-decomp-result.md` (100% field-shift; item B off critical path),
  `tf24-v2-P1-field-aware-schedule-result.md` (static shapes NULL),
  `tf24-v2-P2-uptake-taylor-falsifier-result.md` (uptake cheaply refreshable → GO to T6).
- Scripts (session 3, all in `scripts/tf24-benchmarks/`): `arnoldi_spectrum.R`,
  `emergent_skewness.R`, `common_field_decomp.R`, `field_aware_min.R`,
  `uptake_taylor_falsifier.R` (+ results/ `.rds`).

**Session-2 / earlier (historical — see the audit-trail note in the NEXT SESSION block)**
- **This session's ladder results (2026-07-21):**
  `tf24-ghost-validate-result.md` (rung 1: ghost = `run_mutant` validated as an exact
  marginal-member probe; slim-cache fix, memory numbers),
  `tf24-wr-contraction-result.md` (rung 5: WR killed, κ≈10), and
  `tf24-goal-placement-result.md` (rung 2: goal-oriented placement does not fund; J
  non-convergent under refinement = survival-flip discontinuity → item B). odelia#47
  (L3 replay slim-record) filed on GitHub.
- `oracle-consultation-fundamentals-v2.md` — **the current Oracle characterisation (this session's
  update; supersedes `-fundamentals.md` + its correction).** Self-contained, domain-clean,
  no directed questions, no proposed remedies; §9 folds in ghost probe / WR κ≈10 / placement
  non-convergence. A review artifact — not sent.
- `oracle-consultation-fundamentals.md` — **the consolidated fresh-Oracle elicitation** (zero prior
  context, domain-clean, no question/no proposed remedy): the complete system + discretisation +
  correctness reference + the full measured record of every approximation tried and why it resisted
  (decomposition/MRI/RODAS/IMEX, member-reduction, tracked-control, events, inner-tolerance, PI
  controller, reformulations). Consolidates all prior rounds; the intended fresh-Oracle send.
- `oracle-consultation-intrinsic-characterisation{,-response}.md` — the deep neutral
  characterisation consult **and the Oracle's response** (the noise-floor hypothesis).
- `tf24-noise-floor-E1-E2-result.md` — **the E1/E2 triage of that response (current
  authority on the inner-search question):** source floor confirmed, solver-level
  mechanism refuted, F1 ill-posed (corner optimum), J-bifurcation finding.
- `tf24-classifier-gate-result.md` — the gate measurement + verdict (INTRINSIC) and
  the stress battery. The reason the event program is retired.
- `tf24-soil-profile-eco.md` — the shutdown-reachability mechanism (plant#62).
- `oracle-consultation-guide.md` — how to frame consults + **§7 test-before-build**
  (apply to the incoming response).
- `scripts/tf24-benchmarks/` — the bank, harness, `BASELINE.md` (frozen numbers),
  `classifier_{capture,battery,analyze}.R`, and `results/classifier_raw/` (saved
  per-step monitor data for free offline re-attribution).
- `tf24-event-aware-spec.md` — the event-integrator spec; **§4 retired by the gate**
  (verdict recorded inline in §3), §7 (mesh/`J`) still live. Reference, not a plan.
- plant#60 — reverse-mode gradient bug (E4, out of scope: reverse mode not in play);
  plant#61/#62 — filed prior session; odelia#47 — filed this session.

**Context, superseded by the gate**
- `oracle-consultation-event-aware{,-response}.md` — the round-7 design that
  proposed the event program; its own gate (build-#2) refuted its premise.
- `oracle-consultation-tf24-recharacterized{,-response}.md` — the round-6 verdict
  (block decomposition retired) + corrected system description. Still correct on
  the negative results; superseded on the event program.

**Superseded / historical** (kept for the audit trail; do NOT build from these)
- `oracle-consultation-multirate-{update,response,followon,followon-response,collocation,collocation-response,verdict}.md`
  — Oracle rounds 1–5, the block-decomposition line, retired by round 6.
- `tf24-multirate-recharacterization.md` — the round-5-era recharacterization
  (its conclusion is folded into the round-6 consult).
- `tf24-multirate-engine-port-spec.md`, `tf24-multirate-implementation-plan.md` —
  the MRI/decomposition build plan. **Retired approach** — banner added.
- `tf24-multirate-forward-track.md`, `tf24-multirate-factoring-probe.md`,
  `tf24-multirate-real-patch-results.md`, `tf24-rodas-multirate.md`,
  `tf24-reformulations-evaluation.md` — historical analysis from the decomposition
  effort.

**Adjacent workstream (separate, live):** the `ad-*.md` set + `docs/README.md`
cover the reverse-mode AD infrastructure; plant#60 lives at that boundary.

## Key files (quick map)

- Engine: `odelia/inst/include/odelia/` — `mri.hpp`, `ode_step_rodas.hpp` (+
  `ode_step_imex.hpp`, `ode_jacobian.hpp` `BlockFdJacobian`), `step_diag.hpp`,
  `ode_solver_internal.hpp` (`Method` dispatch + step log).
- Patch / partition / R1 flow: `plant/inst/include/plant/patch.h`,
  `models/tf24_environment.h`.
- Collocation: `plant/inst/include/plant/species.h`, `individual.h`.
- Control surface: `plant/inst/include/plant/control.h`, `src/control.cpp`,
  `inst/RcppR6_classes.yml` (`ode_method`, `n_collocation_nodes`, `mri_use_split`);
  `scm.h` (`scm_ode_method`).
- Diagnostics: `plant/src/mri_diag.cpp`; odelia `src/step_diag.cpp`.
- R-C: `plant/src/leaf_model.cpp`, `tests/testthat/test-tf24-shutdown.R`.
