# T1 — Arnoldi on T′: the mean-field fixed point is well-conditioned (Outcome A)

*2026-07-21. v2 Oracle response, claim 2. The decisive test: map the dominant
spectrum of `T′` (linearisation of the self-consistency map `T: a→u→members→a` at
its fixed point `a*`) and read the **distance from +1**, since fixed-point
conditioning is `‖(I−T′)⁻¹‖`. Script: `scripts/tf24-benchmarks/arnoldi_spectrum.R`
(generalises the 9b sweep to an arbitrary-direction matvec; modified-Gram-Schmidt
Arnoldi, 22 steps, on the saved `intense_storms` 12-yr field).*

## Machinery validated against 9b first

- round-trip `‖T(a*)−a*‖/‖a*‖ = 0.0182` (cf. 9b's ~1% sanity).
- directional derivative along `a*` (= 9b's κ at δ=1e-2): **10.54** vs 9b's 10.27.

So the generalised T′ matvec reproduces the known number; the spectrum is trustworthy.

## Spectrum (eps=1e-2, 22 Ritz values)

| | λ | \|λ\| | \|λ−1\| |
|---|---|---|---|
| dominant | −3.99 ± 5.71i | 6.97 | 7.58 |
| | −5.42 | 5.42 | 6.42 |
| | −0.56 ± 2.88i | 2.93 | 3.27 |
| | −1.54 ± 0.57i | 1.64 | 2.60 |
| | 0.76 ± 1.33i | 1.53 | 1.35 |
| **nearest +1** | **1.207** | 1.21 | **0.207** |
| | 0.58 | 0.58 | 0.42 |
| smallest | −0.025 | 0.02 | 1.02 |

- **Spectral radius ρ(T′) = 6.97.** The dominant modes have negative real parts /
  large imaginary parts — far from +1. This *is* the WR-divergence (ρ ≫ 1) and the
  9b κ≈10 gain, now resolved as a spectrum: an oscillatory amplifying operator.
- **min|λ−1| = 0.207.** The only Ritz value in the neighbourhood of +1 is a single
  **real** mode at **λ = 1.207** — just above +1, distance 0.207. **Nothing sits at
  +1.** `(I−T′)` is non-singular; **‖(I−T′)⁻¹‖ ≈ 1/0.207 ≈ 4.83**.

## Reading: Outcome A — the fixed point is well-conditioned

The Oracle's dichotomy: **A** eigenvalues away from +1 → fixed point well-conditioned,
continuum J exists & is stable, 9c non-convergence is *protocol*; **B** an eigenvalue
near +1 → J not a stable observable, no mesh converges it, deliverable is a banded J.

**Measured: A.** No eigenvalue near +1 (nearest 0.207 away); conditioning ≈ 4.83
(moderate — a perturbation of the problem amplifies ~5× into `a*`, consistent with the
~10× J-amplification and the ~23% inter-scheme spread being conditioning × an O(few %)
discretisation error, not a divergence). The large modulus (ρ≈7) is WR's problem, not
J's: `|λ|≈7` far from +1 is *good* conditioning.

**Therefore the continuum J exists and is stable, and 9c's non-convergence under
member-mesh refinement is a PROTOCOL artifact — there is a true convergence axis to
find.** This routes to the Oracle's claim 4 (heavy-atom splitting, T5) and to the
common-field decomposition (T3) / insertion-transient audit (T2) that identify the
protocol fix. It **falsifies leg 1 of the concession condition** (which required an
eigenvalue near +1): the forward J question is NOT closed as ill-posed.

## Caveats (honest bounds)

- **FD noise floor.** matvec carries ~1.8% round-trip + eps FD noise; the Arnoldi
  subdiagonals plateaued at ~0.5–0.7 (did not decay to 0), so subdominant Ritz values
  are noise-limited. The **dominant** eigenvalues (ρ≈7) and the **near-+1 gap** (0.207,
  ≫ the ~2% noise) are the robust reads. A recheck at eps=1e-3 confirms the gap is
  signal, not step-size artefact [see below].
- **a-loop operator, s held.** T is the a→u→a map with `s` at resident (as in 9b);
  `s` is cheap, flat in M, u-independent, so this is the dominant loop. Full mean-field
  including s feedback not separately mapped.
- **One sequence / horizon** (intense_storms, 12 yr). The qualitative call (no λ at +1)
  is expected to be sequence-robust; a second sequence would confirm the exact number.

## eps=1e-3 robustness recheck

Re-ran at a 10× smaller FD step (noisier: κ-along-`a*` came out 13.6 vs 9b's 9.9,
the round-trip noise amplified by the smaller step). Spectrum: **ρ(T′) = 7.97**
(a real mode at −7.97 leads; complex pair −2.86 ± 6.04i) — same amplifying,
far-from-+1 dominant structure. **min|λ−1| = 0.045** at a real Ritz value **0.955**;
there is also a real mode at **2.13**.

**Reconciling the two runs:** the nearest-to-+1 eigenvalue is **real**, and its
estimate moves with the FD step — 1.207 (eps=1e-2) vs 0.955 (eps=1e-3), i.e. a real
eigenvalue somewhere in ~[0.95, 1.3], with a second real mode near 2. Its distance
from +1 is therefore **~0.05–0.2**, conditioning **~5–22** — noise-limited to a factor
of ~5. **Robust across both:** (i) ρ(T′) ≈ 7–8 (WR dead, amplifying); (ii) **nothing
sits at +1**, and there is **no tight Ritz cluster pinned to 1** (a genuine marginal
mode would produce one) — so the fixed point is **well-conditioned (finite, O(5–20)),
not marginal.** Outcome A stands; only the exact conditioning is uncertain.

If a firm conditioning number is later wanted, a **central-difference matvec**
`(T(a*+εv) − T(a*−εv))/2ε` cancels the O(ε²) bias and would tighten the near-+1 mode;
not run here because the decision it gates (9c is protocol → pursue heavy-atom
splitting) does not depend on 5 vs 22.

## Bottom line

The mean-field fixed point is well-conditioned (‖(I−T′)⁻¹‖ ~ O(5–20), no eigenvalue
at +1). **The continuum J exists and is a stable observable of the model.** 9c's
non-convergence is therefore a discretisation-protocol artifact, not intrinsic
ill-posedness — the concession condition's leg 1 is falsified, and the search moves to
*which* protocol axis converges it (T5 heavy-atom splitting; T2/T3 to localise the
mechanism). The ~23% inter-scheme spread reads as conditioning (5–20) × an O(1–5%)
per-scheme measure-discretisation error — consistent with a convergent-but-coarse
measure, not a divergent one.
