> **ARCHIVED 2026-07-29 — not a source of truth. See [`../audit-2026-07.md`](../audit-2026-07.md).**
>
> The session task list. **Its live items are now
> [`../build-plan.md`](../build-plan.md) §5 and [`../tf24-correctness.md`](../tf24-correctness.md);
> its closed items are wrong.**
>
> The specific hazard: the "Closed this session" section records item **52** as having
> found the collar operating point at the `ci`-branch corner in "**every sampled state** …
> It is the ordinary case, so report 5 §3 is load-bearing", and item **60** builds on that.
> Report 06 measured **zero** corner incidence in 10 153 production records, with a
> minimum margin of 0.02688 MPa — 27× `GSS_tol_abs` — and the margin *growing* as the soil
> dries. The claim came from a degenerate single-layer probe; see the banner on
> `corner-and-envelope-result.md`.
>
> Also stale here: item **49**'s framing (freezing the operating point costs the
> derivative) inverts the measured production result; item **55**'s soil-smoothing
> question is answered by report 06 §9b's measurement of develop's two smoothing scales;
> item **58**'s recorded moisture threshold (θ = 0.1246) was derived through
> `soil_moist_from_psi`, which is wrong by 8.19× (`tf24-correctness.md` P0.3).
>
> Its four "retire or re-establish" entries were a good instinct and the audit agrees
> with all four.

# Open items

The session task list, written down so it is visible. Grouped by the component it lands in, so
it triages against the code rather than against the reports. Numbers are the session task IDs.

**Audited for relevance, not just transcribed.** Four inherited items do not survive that audit
and sit at the bottom under *retire or re-establish* rather than mixed in with live work — two of
them name things that no longer exist in the code.

**Ranked first**, because each closes a branch of the design space rather than opening one:

| | item | why first |
|---|---|---|
| **60** | water channel's argmax-motion share, on a real patch | the remaining half of `plant#60`; decides which channel the design must prioritise |
| **57** | NaN-fallback incidence in `dprofit_droot_collar_psi` | the primitive report 5 recommends inherits a finite difference here; if frequent, the recommendation weakens |
| **58** | shutdown margin under shallower rooting / drier driver | the whole "kinks are unreached" licence rests on a 6% margin from one trait set |
| **59** | vulnerability curve's domain edge | forward-model correctness, silent and sign-wrong; independent of everything else |

---

## `Leaf` operating point

**60. Water channel's argmax-motion share on a real transpiring patch state.** Task 49 settled
the carbon channel (89–100% lost by freezing `p*`) but its single-layer probe is degenerate for
uptake — `soil_consumption_` measures 1e-13 to 6e-11 there, exactly the objection on
`plant#60`. Use a real stand with frozen canopy light, per cohort per layer, re-solved versus
frozen. Watch the same trap: `dp*/dψ = 1` means a frozen evaluation crosses the `ci` branch and
the difference diverges as 1/step; use `ci` (4.33 vs 5.49) to reject crossings. Prediction worth
testing rather than assuming: with `p*` tracking soil one-for-one the driving gradient is nearly
invariant, so uptake's *absolute* error from freezing may be small even at 100% relative.

**57. How often does `dE_from_soil_dpsi_collar` return NaN on a production run?** develop's
analytic profit gradient is analytic *except* at soil-layer crossings, where it falls back to a
central difference at `h = 1e-6`. Unmeasured. Also revives a claim the requirements doc recorded
as fixed. If frequent, the locator sits on an FD of a function containing inner root-finds.

**53. Re-validate the uptake Jacobian's interior branch at production inner tolerance.**
Validated at 1e-12; develop runs `GSS_tol_abs = 1e-3` and `ci_abs_tol = 1e-6`. The interior
response is itself a finite difference of the analytic gradient.

**32, 33. TF24f tracked collar** — close the 2.9e-4 δ-independent residual; fold the tracked
collar into `assemble_leaf_from`. `tf24f_strategy.h` is on develop so both refer to real code, but
they are **downstream of a live defect**: `plant#61` records TF24f aborting on every hard scenario
at its shipped `k_acclim = 1` default, because the tracked potential leaves the feasible
leaf-solve domain. Polishing its gradient channel before that has a feasibility guard is
premature. Keep, blocked.

## `TF24_Environment` soil block

**58. Shutdown pinning margin under a shallower rooting depth and a drier driver.** develop
reaches `psi_crit` at θ = 0.1246 against a measured minimum of 0.133 — 2.05 MPa, or 6% in
moisture, on one trait set. Shutdown keys on the **wettest** rooted layer, so a cohort that does
not reach the wet bottom layer shuts down far sooner. Use the transients now in `scripts/`.

**59. Does the root vulnerability curve's domain edge get crossed?** Beyond its fitted domain
`root_vuln_from_psi` extrapolates **negative** → negative conductivity → negative-but-finite
`r_R` → wrong-sign `E_i`, which the `isfinite(E_up_)` net cannot catch. Guarded in one of three
branches. The domain is a fixed 100-point grid, so reachability is a comparison. Correctness
before gradients. Raised on `plant#62`.

**55. Decide what the survival/shutdown threshold needs — smoothing may be the wrong fix.**
Re-scoped twice. Mollification is off the critical path for *convergence* (100% coupling-field
shift) and on it for *differentiability* (the Leibniz term, 5–6 orders). And for TF24
specifically the graceful mechanism already exists in `r_R`, so the shutdown may be a solver
guard rather than a biological switch — a question for the hydraulics owner, raised on
`plant#62`. Do not add a smoothing scale until that is answered.

## Light field — report 3

**50. Attribute the 91% of `rescale_spline`'s 193.2 µs that is unaccounted for.** Cohort sweep
15 µs + band solve 2.6 µs = 17.6 µs of 193.2. The no-LTO explanation was tested and **rejected**.
Collapses report 3's +0.33%…+5.3% bracket, and worth 3.5 s of a 59.5 s run for develop alone.

**51. Re-run the matched-knot interpolant comparison on a real production knot set.** Report 3's
central claim — that the Hermite beats the cubic on develop's existing 65 knots — is measured on
a synthetic stand with *uniform* knots. This is its falsifier.

**46. Fix the light field for per-species eta** (rank 3·n_eta grouping). Blocks the two
multi-species user stories.

## Node schedule / measure

**54. Retarget the refinement criterion at the coupling field, not reproduction.** Measured:
freezing the soil and adding 1.5× cohorts moves R0 ~0%; letting them feed back moves it 69–84%.
The current heuristic flags cohorts by contribution to reproduction, which is already converged,
and anti-correlates with the true error. Prerequisite: a multi-level field-shift sequence.

**27. FD-verify the TF24 full-SCM gradient — at life ≥ 12, not life ≥ 4.** Premise corrected: R0
is on the noise floor below ~12 yr (1.1e-15 at 3 yr vs 2.7e-7 at 12). Needs both tolerance
families converged, a well-conditioned regime (*not* the transients — they are near-extinction by
construction), and an FD that re-solves the inner problem.

## Transport term — report 4

**Routes A/B/C unmeasured.** And C3's coupling: `GSS_tol_abs` and `node_gradient_eps` are tied
through the argmax staircase, which develop's own comment names without recording. Now sharper —
task 52 showed the argmax sits at a corner, so what the stencil differences when the search is
replaced is an open question with unknown sign.

## Verification surface

**44, 45. The R0 restore path** is unexercised and has no public route for the birth stamps —
both still true, but sequenced; see "retire or re-establish" below.

**48. Produce the kink manifest.** Specified long ago, never made. Report 5 §5 is the soil half.

## Engine — report 1

**35. Step-local reverse sweep.** Report 1's subject, so live — but **its stated blocker is
stale.** It reads "BLOCKED on leaf ownership (see `docs/HANDOFF.md` OPEN)"; that file exists in
neither repo, and the leaf-ownership question was resolved by measurement (the restore path
already gives a leaf consistent with the unit, making it a design choice rather than a blocker).
Re-file without the blocker.

**47. What the calibration user story needs from the `Functional` contract.** Live and
independent — the one story a plain-valued trajectory breaks, since `least_squares` reads
intermediate history as active values.

**43. First plant witness — K93 step-local sweep.** Live in that nothing has run in plant at all,
so report 1 has no end-to-end witness. But it is a *K93* task against a standing instruction to
focus on TF24, so it competes poorly unless wanted specifically as the cheapest first witness.

*(4 and 34 were here; both are under "retire or re-establish" below.)*

## odelia

**56. Run the full odelia suite against the non-finite step guard.** The guard and its 12
assertions are written and green individually; the changes sit uncommitted in `odelia/` by
request. The guard is provably inert on finite input, but that is an argument, not a test run.

---

## Retire or re-establish

Inherited items that do not survive an audit. Left visible rather than silently dropped — "a
recorded blocker outlived its fix across four documents" is this project's own cautionary tale —
but none should be picked up as written.

**34. "Phase-1 Step 4b — delete residual accretion."** The term *residual accretion* appears
nowhere in plant's `inst/` or `src/`. Whatever it named has been renamed or removed. **Retire**
unless someone can say what it refers to.

**4. "Retire the mutant-only records off the resident/gradient path."** `is_mutant_run` is live in
`patch.h` at four sites, so the mechanism exists — but the claim that mutant-only *records* sit on
the resident path has never been verified against current code, and the wording predates several
rewrites of that path. **Re-establish before acting:** read the resident path and state what is
actually recorded that need not be.

**44, 45. The R0 restore path.** Both still literally true — `set_birth_state` is called by no
test and has no public route for the birth stamps. But they are downstream of a larger problem:
R0's *value* is wrong at develop's default inner tolerance and does not converge under schedule
refinement (report 5 §6). Exercising a restore path for a quantity that is not yet a converged
number is work in the wrong order. **Keep, sequenced after 27 and 54.**

---

## Closed this session

**49. Is the frozen-operating-point adjoint first-order wrong at the corner?** Answered, and it
understates: the argmax-motion term is **89–100%** of `d(profit)/d(psi_soil)`, growing toward
100% as the soil dries. Freezing loses the derivative, not a correction.
`corner-and-envelope-result.md`.

**52. How often is the operating point at the corner?** Answered: **every sampled state** — zero
of six show a gradient sign change. It is the ordinary case, so report 5 §3 is load-bearing. The
slope is state-dependent (−1.3 to −13.4, growing with dryness), so the quoted −8.8 is one point
on a curve.

Both raised a new obstacle for the proposed fix: because the gradient is one-signed *across* `p*`,
there is **no sign change at the corner to bracket**. Whether a bracketing root-find locates it is
now a question the primitive has to answer.
