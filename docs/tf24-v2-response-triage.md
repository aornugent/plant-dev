# Triage of the v2 Oracle response — falsifier ladder (2026-07-21)

Response: `oracle-consultation-fundamentals-v2-response.md`. Rule (handoff / consult
guide §7): **reduce each claim to the cheapest falsifiable test; run the falsifier
before building.** The Oracle itself ordered the battle cheapest/most-decisive-first
and flagged that **four of five run offline on already-saved fields**. Below: each
claim, its owned falsifier, the machinery it reuses, and the outcome that would kill
or fund it.

## The reframe in one line

κ≈10 (9b) is not just WR's killer — it is the **loop gain** behind the whole §7
graveyard AND behind 9c. With gain-10 feedback, inter-mesh ΔJ is dominated by the
**global field shift** each mesh induces, not local interpolation defect — which is
why a *local* surplus indicator anti-correlates (−0.56…−0.86) with actual inter-mesh
error (§9c). The error has moved off the time axis (integrator can't reach it) onto
the **measure granularity** (heavy atoms) and the **feedback resolvent** `(I−T′)⁻¹`.

## Concession condition (what defeat looks like, stated up front)

The forward J-convergence question is **genuinely closed at this J** (deliverable =
a certified band / redefined observable) **iff all three hold**:
1. spec(T′) has an eigenvalue **near +1** (fixed point ill-conditioned), AND
2. J **invariant** under heavy-atom splitting (granularity innocent), AND
3. J **ripple-dependent** (needs the fast texture).

Nothing measured so far says this. Each test below can flip one leg.

## The ladder (cheapest/most-decisive first; ★ = offline on saved fields)

### T1 ★ — Arnoldi on T′ (claim 2). **DONE (2026-07-21): Outcome A.** `tf24-v2-T1-arnoldi-result.md`
ρ(T′)≈7–8 (WR dead), but nearest eigenvalue to +1 is a real mode at distance ~0.05–0.2
(conditioning ~5–22, noise-limited); **nothing at +1** → fixed point well-conditioned,
continuum J exists & stable, **9c is protocol**. Leg 1 of the concession falsified.


- **Question:** distance of spec(T′) from **+1**, since fixed-point conditioning is
  `‖(I−T′)⁻¹‖`. κ≈10 is only a directional norm along `a*`; the spectrum is the real
  answer. (Note: `|λ|≈10` far from +1 in modulus is *good* conditioning — WR-as-
  iteration diverges, but the fixed point is well-posed unless a λ sits near +1.)
- **Falsifier / outcomes:** **A** — eigenvalues clustered away from +1 → fixed point
  well-conditioned, continuum J exists & is stable, **9c non-convergence is protocol**
  (→ T5 splitting). **B** — an eigenvalue near +1 → J not a stable observable, no mesh
  converges it, deliverable is a banded/redefined J.
- **Machinery:** generalize 9b `sweep_once(δ)` (one T application along `a*`) to
  `Tprime(v)` = (T(a*+εv) − T(a*))/ε for arbitrary direction v; Arnoldi 15–25 sweeps
  on saved fields. Byproduct: dominant modes = the resolvent weights the placement
  indicator needs. **Script:** `arnoldi_spectrum.R`.

### T2 ★ — Insertion-transient audit (claim 4 companion).
- **Question:** does each member insertion inject a `u`-transient, and does **total
  injected mass grow with mesh density**? If yes, that alone explains "refinement
  makes it worse."
- **Falsifier:** log the `u` perturbation attributable to each insertion at mesh N vs
  2N; sum. Growing with density → insertions are a mesh-dependent artifact (→ measure-
  preserving birth via splits). Flat → insertions innocent.
- **Machinery:** reference run + per-insertion `u` before/after (needs a light probe;
  R-level if insertion times + cached `u` suffice, else a small plant hook).

### T3 ★ — Common-field ΔJ decomposition (claim 3).
- **Question:** split the 9–45% family disagreement into **quadrature-at-fixed-field**
  (placement genuinely matters) + **field shift** (κ-amplified feedback; placement
  innocent) + **survivor flips** (branch structure).
- **Falsifier:** solve mesh 2N as probes on mesh N's frozen field; compare to the
  self-consistent 2N solve; lineage-match across the pair. Caveat: probe error is
  O(weight fraction) (9a) → heavy-atom terms carry a known band; correct those with
  participant re-solves.
- **Machinery:** 9a ghost/replay (`run_mutant` on a frozen cache).

### T4 ★ — Filtered-field probe (claim 5). **DONE (2026-07-21): arbitrage confirmed.** `tf24-v2-T4-filtered-field-result.md`
J invariant (≤3%) removing all `u`-texture below ~2 days; +14% weekly; 2.3× monthly;
blows up seasonal. Member block over-resolved ~30–100×; needs only the weekly-and-slower
envelope of `u`. Licenses averaged member advance given a cheap `a(u)` refresh → pairs
with T6. (Open-loop; ±κ caveat; one sequence.)


- **Question:** is the O(M) block being integrated at the *fast* block's resolution
  for no J benefit? Advance probes against **low-pass-filtered** `(u,s)(t)` over a
  cutoff sweep; watch J-contributions vs cutoff (±κ band).
- **Falsifier:** J-contribution flat above some cutoff → ripple phase J-irrelevant →
  averaged member advance licensed (members at macro steps, `u` sub-cycled), full-M
  solves drop 10–100×. J-contribution cutoff-sensitive → members need the texture
  (leg 3 of concession).
- **Machinery:** 9a probe against a filtered replay field. Confirm closed-loop as a
  model variant where only `g` sees filtered `u`.

### T5 — Heavy-atom splitting study (claim 4). *(a few forward solves)*
- **Question:** is τ_ins the wrong convergence axis? Skewness is emergent (max ρ_j
  ~0.3–0.4 at every density); refinement never splits heavy atoms. 9a shows a single
  atom's self-consistency matters at O(its weight fraction).
- **Falsifier:** take the finest mesh, split the top handful of atoms 2- and 4-ways
  (ρ/k children + small ξ-jitter — jitter load-bearing) across a jitter-scale sweep;
  watch J. Movement → **true convergence axis found**; invariance → granularity
  innocent (leg 2 of concession) → blame flips/insertions.

### T6 — Newton-on-g offline falsifier (claim 6). *(then bench build if it survives)*
- **Question:** does Newton on the branch-**death** condition (an eqn with a real
  root, unlike ∂P/∂p=0 at a corner) give an analytic 5×5 ∂a/∂u for a cheap `a(u)`
  refresh — the thing §7 could never supply?
- **Falsifier (before building):** walk the saved reference trajectory, count how
  often a 2nd-order trust monitor would demand re-expansion. Every fast step near
  bounds + bounds dominate → dies as its ancestors did. Otherwise → build at bench
  scale. Standalone value: ~32→~15–20 units/eval, removes the τ-floor (retires the
  2.4× J(τ) flip as a solver artifact).

## Re-ranked standing levers (claim 7)
rmax↔(ρ, threshold-distance) weighted-norm join **priority drops** (mesh owns 9–45%
of J; steps own ~30% of cost). Setup caching, safeguarded fixed-count Newton batching
(preserves lockstep), rejection salvage, multi-block near-ceiling guard: all stand.

## Execution order chosen
T1 first (most decisive + machinery already built + gates interpretation of T2–T5),
then T3/T4 (reuse 9a), then T2, then T5 (forward solves), then T6. All of T1–T4 are
offline on saved fields.
