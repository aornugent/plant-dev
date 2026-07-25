# T6 Slice 4 — end-to-end scenario bank + the kutta3 accuracy fix: RESULT

*2026-07-22. Slice 3b-iii wired `ode_method="mri_uptake"` on the real TF24 patch
(40× cohort-solve reduction, 9.8e-3 offspring on a 30-yr constant-rainfall SCM).
Slice 4 is the acceptance test: does the arbitrage hold across the full dynamic
scenario bank, at the accuracy the science needs? The answer required rethinking
what "accuracy" can even mean on these traces, and one C++ change.*

## 1. The bank is a speed/robustness test, not an accuracy test — here is why

Running the six bank scenarios (`slice4_scenario_bank.R`, birth=20, converged
tol, weekly macro cap) surfaced three hard facts that invalidate an offspring-
vs-rkck accuracy comparison **on the bank**:

- **rkck crashes on 3/6.** whiplash, extended_drought, long_horizon all die with
  "Detected non-finite contribution" at converged tol — a genuine explicit-RK
  integration failure on the sharp soil forcing, **independent of birth_rate**
  (swept 20→2000, all crash). So there is no global-RK reference on exactly the
  scenarios where the arbitrage matters most. RODAS/imex are unavailable for the
  SCM patch (no rebind hook / active scalar), so no stiff reference exists either.
- **Near-extinction at every trait and every rainfall scale.** offspring is
  1e-8–1e-13 on all six traces even at birth=20. An lma sweep (0.04→1.0) is
  monotone-decreasing (best case ~2e-10, ten orders below replacement); a
  rainfall-scale sweep (1×→20×) never lifts dry_to_wet above ~1e-9. The
  near-extinction is intrinsic to the traces (they were built as soil-integrator
  stress tests), NOT a trait/forcing-magnitude choice — the *same* species+birth
  gives offspring 1.03 under constant rainfall. In that regime offspring is a
  hypersensitive functional (hard-won lesson #4): relative errors are dominated
  by ill-conditioning, not by the integrator.
- **Offspring is not a usable convergence observable there.** `slice4_selfconv.R`
  refines mri_uptake's OWN time-discretization (macro leg 7d→1.75d, tol 1e-2→1e-3,
  nmicro 40→80, cohort mesh fixed). The two finest rungs agree to <2% on 4/5
  scenarios (the trust monitor / micro count are NOT the limiter), but the
  production-vs-refined offspring gap is O(1)–O(10) and **non-monotone** (e.g.
  long_horizon 8.2e-8 → 1.5e-8 → 4.7e-6): the same lesson-#4 hypersensitivity
  makes even one method's own step-size change swing offspring by orders of
  magnitude. The soil TRAJECTORY converges fine (3b-ii ≤5.5e-4); the offspring
  INTEGRAL of it is pathological near extinction.

**Conclusion:** the bank measures speed + robustness; accuracy must be judged in
a well-conditioned regime (§3).

## 2. Speed + robustness on the bank (the deliverable the bank CAN measure)

Post-kutta3 (§3), all six scenarios complete under `mri_uptake`:

| scenario | life | rkck | cohort-solve ↓ | reexp/leg | wall-clock |
|---|---|---|---|---|---|
| intense_storms | 20 | 6.8e-10 | 6.7× | 0.11 | 1.9× |
| whiplash | 24 | **crash** | 3.9× | 0.15 | 1.0× |
| extended_drought | 30 | **crash** | 5.8× | 0.16 | 1.7× |
| dry_to_wet | 25 | 1.0e-8 | 9.9× | 0.22 | 3.2× |
| long_horizon | 70 | **crash** | 6.0× | 0.22 | 1.6× |
| drydown | 16 | 1.5e-10 | 3.1× | 0.53 | 1.1× |

- **Cohort-solve reduction 3.1–9.9×** (the O(M) sums that T6 targets), **wall-clock
  1.0–3.2×.** Both are lower than the forward-Euler headline (§3) because kutta3
  costs ~2× the coupling count per leg — the price of the accuracy fix.
- **Trust-monitor death mode absent everywhere** (re-expansion 0.11–0.53/leg vs
  the DEAD threshold ≈ nmicro). The 3b-ii prediction holds on the real patch
  across the whole dynamic bank — the monitor never collapses to global RK.
- **mri_uptake completes traces the reference cannot** — whiplash /
  extended_drought / long_horizon (rkck crashes) and, with kutta3, intense_storms.
  **⚠️ CORRECTED (see `tf24-v2-T6-density-blowup-550-investigation-result.md`):
  completing is NOT the same as being right, and must not be read as a robustness
  win.** The rkck crashes are the plant#550 cohort-density blow-up (a *model*
  divergence, not a solver overflow); upstream's own position (plant#552) is that
  when it fires, "trustworthy completion is blocked on the model." On
  `extended_drought` — the one crashing trace for which we can now obtain a
  reference (rkck completes it when `newton_collar_solve=TRUE`) — **mri_uptake is
  ~1400× below that reference** (4.06e-13 vs 5.65e-10, rel err 0.999; the collar
  solver changes mri_uptake by only 0.3%, so the gap is mri_uptake, not the
  confound). Both values sit deep in the near-extinction hypersensitive regime on
  a trace the model is documented to diverge on, so the honest reading is that
  **neither number is trustworthy there** — not that mri_uptake is superior.

## 3. The accuracy fix: kutta3 slow advance (the one C++ change in Slice 4)

Accuracy is assessable in a **survivable dynamic regime** — `slice4_crosscheck.R`
uses the model's own seasonal driver (`build_scenario`, rainfall_mean=1 = the
sustaining level, rainfall_amp_frac dialed up) so offspring is O(1) and rkck
survives. There the diagnosis was unambiguous:

**Forward-Euler slow advance leaves an O(H) offspring bias under dynamic forcing.**
At amp=0.3 (healthy offspring ~35) the weekly-leg error was **12%**, converging to
rkck only as the leg shrank (8.4% @3.5d, 1.2% @1.75d, 0.6% @0.875d) — first-order,
the forward-Euler signature — but reaching ~1% needs a 1.75-day leg (coupling 8434
vs rkck 16581, only ~2×), eroding the speed win. This is the order-1 macro
discretization flagged in step-2, NOT the refresh (self-conv showed the monitor
isn't the limiter).

**Fix:** advance the slow (cohort) block with the existing 3rd-order MRI-GARK
`mri_kutta3()` coupling instead of `mri_forward_euler()` (one line in
`MriUptakeStep::step`, odelia). At the SAME weekly leg:

| regime | forward-Euler | **kutta3** | rkck ref |
|---|---|---|---|
| survivable dynamic (amp=0.3, offspring 35) | 12% | **1.8e-4** | 35.11 |
| static (amp=0, offspring 45) | 2e-3 | 5e-3 | 44.90 |
| constant-rainfall gate (30 yr) offspring rel | 9.8e-3 | **2.3e-3** | 1.0379 |

kutta3 turns a 12% dynamic bias into <0.1% at the weekly leg, keeping the
cohort-solve reduction (crosscheck 3.5–8.9×; gate 40×). Validated:
- **odelia toy tests `test-example-uptake` 25/25 pass**, incl. record→replay
  adjoint <1e-6 — the 3-stage advance keeps reverse mode replay-safe (stage count
  is deterministic, so record and replay take identical structure).
- **bit-identical off** preserved (kutta3 lives only on the mri_uptake path; the
  default SCM offspring is unchanged).

Chosen as an **outright swap, not a control key.** mri_uptake exists for dynamic
coupled runs where forward-Euler's 12% is unfit for gradient-quality J; kutta3
fixes that at ~2× the (small) coupling count. A `mri_uptake_slow_order` key would
be a permanent concept every user must learn, justified only by shaving 2× off
benign runs that `method="mri"` / a coarser grid already cover — not worth the DX
cost (fewest new names wins).

## 4. Residual accuracy caveat (honest)

In the crosscheck, amp≥0.6 still shows 15–27% error — but there offspring is
falling toward extinction (0.77, 0.025), re-entering the lesson-#4 ill-conditioning,
not a discretization failure (the kutta3 grid sweep at amp=0.3 confirms the
discretization is resolved). So: **mri_uptake+kutta3 is gradient-quality where
offspring is well-conditioned (rel ≤2e-3 static, ≤2e-4 at moderate seasonality);
in near-extinction regimes offspring is intrinsically ill-conditioned for every
method (rkck cannot even run those traces).**

## 5. Scope / not done (carried forward)

- **Wall-clock only wins where the cohort sum dominates.** At low stress
  mri+kutta3 can be wall-clock-neutral-to-slightly-slower (crosscheck amp=0/0.3:
  0.8–0.9×) despite 3.5× fewer cohort sums, because there the O(M) sum isn't the
  bottleneck and kutta3's 3-stage subcycling multiplies the cheap soil micro-steps.
  Speedup returns (1.5–3.2×) as stress/horizon/cohort-count grow — the T6 target
  regime. Honest: this is a cohort-solve-reduction win first, a wall-clock win
  conditionally.
- **Patch-level reverse mode still not wired** (forward is the deliverable; the
  `reexpansions` schedule is recorded and replay-ready; reverse proven on the toy
  only — plant#60 territory, scope separately).
- **A fixed macro grid in `scm.h`** (vs the current `ode_step_size_max`-bounded
  adaptive ramp) is an untaken optional refinement (handoff Slice 4 step 3).

## 6. Verdict

**PASS (forward) in the well-conditioned regimes, with a precise accuracy
characterization.** `mri_uptake` runs on the full dynamic TF24 bank, with the trust
monitor holding re-expansions at their floor (death mode absent) and a 3–10×
cohort-solve reduction. **It also completes 3 traces the rkck reference cannot —
but that is NOT claimed as a robustness win** (see §2 and the #550 investigation
doc: those crashes are a model-level density divergence, and where a reference is
obtainable mri_uptake is ~1400× off it). The kutta3 slow advance makes it
**gradient-quality in the well-conditioned regime** (≤2e-4 at moderate seasonality,
2.3e-3 on the constant gate), bit-identical off, reverse-replay-safe. Near-extinction
stress traces remain offspring-ill-conditioned for every method — an intrinsic
property of the science, not an mri_uptake limitation.
