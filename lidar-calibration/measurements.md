# Measurements — faithful tests on the real plant SCM

*The measurement phase (`HANDOFF.md` step ≥1). Every entry is a **faithful** test on the full coupled
system (real plant SCM output, no proxy — `guide.md` §7), arbitrating an Oracle hypothesis or a foundation
claim. Newest first. Scripts live in the session scratchpad; findings are recorded here because scratchpad is
ephemeral.*

---

## M1 — The quotient check: is the age-resolved size-density self-similar? (2026-07-19)

**Question (highest-value lead, `foundation.md` "candidate breakthrough" + `response-quotients.md` §2).** Does
`S`'s image lie on a low-dimensional set — concretely, do the age-resolved size-densities `f_t(h)` superpose
under a shift/scale (self-similar growth), giving a low-dim quotient coordinate `Ψ`? If yes, the difficulty
partly dissolves (mean-based surrogates could revive); if the multimodality obstructs it, that obstruction
*is* the structure.

**Setup.** One faithful SCM solve, `TF24` strategy, `lma = 0.07`, `max_patch_lifetime = 40`, soil 5 depths at
0.3, rainfall `0.30·sin(2πt)+1.0` (an oscillation — see caveats), `birth_rate = 20`. State `u` = the
age-resolved size-density (`expand_state(res)$species`: per-cohort `height`, patch-weighted `density`, over
`time` = patch age). ~50–82 cohorts per age; one solve ≈ 29 s. Test = weighted deciles of the height
distribution per patch age, standardized by (median, IQR); a pure shift/scale family ⇒ standardized deciles
constant across age (`sd_across_age → 0`). Scripts: `quotient_check.R`, `quotient_components.R`.

**Result — the naive single-template quotient is REFUTED, but a component-wise one is SUPPORTED.**

1. **Single-template shift/scale: refuted.** Across all ages the standardized deciles are *not* constant —
   `sd_across_age` reaches **59** on the upper decile. The raw densities show why: early ages (0.25–1.0) are a
   single growing unimodal pulse, but from ~age 1.5 a **second component** switches on — an understory mass
   pinned at the 0.40 m seedling floor under a canopy pulse that pulls away to ~17.9 m. A single location/scale
   registration cannot represent a two-component density; the "collapse" fails *specifically at and after the
   bimodality onset*, not in the growing phase. This is the Oracle's §3(c) "discrete fibers create
   multimodality, not dimension reduction" and `foundation.md`'s "component separation only at maturity" — now
   measured, not asserted.

2. **Component-wise quotient: supported.** Split the density at `h = 2 m` into an **understory atom** (recruits
   near 0.40 m) and a **canopy pulse** (`h ≥ 2 m`). The canopy pulse's shape is **nearly age-invariant**:
   standardized q25/q75/q90 have `sd_across_age` of **0.058 / 0.058 / 0.086** across ages 0.75→40 (vs. 0.44 /
   0.44 / 59 for the whole density). The pulse drifts only slowly — mild increasing right-skew with maturity
   (std q75 +0.10→+0.24, std q90 +0.11→+0.31) — and its lower tail (q10, `sd 0.88`) is ragged at the boundary
   with the understory. So the canopy component *is* approximately a shift/scale family.

3. **The collective coordinates.** The whole age-structure is well described by a **small set of collective
   coordinates** rather than ~50–80 cohorts:
   - **canopy median height** `canH_med(age)`: monotone, saturating 2.5 → 17.9 m (17.15/17.50/17.66/17.74/
     17.83/17.90 at ages 12/18/24/28/34/40) — the developmental "clock"/shift coordinate; the canopy also
     *tightens* into a near-monolayer (canopy IQR → 0.004 m at maturity);
   - **understory mass fraction** `π_u(age)`: smooth-ish partition coordinate, 1.0 (all recruits) → dips as the
     first cohort clears 2 m → refills to ~0.82–0.85 at maturity;
   - a **self-similar canopy pulse shape** (item 2) and an **understory atom** near a fixed height (~0.40 m).

   That is ~2 varying coordinates + 2 near-fixed shapes — a low-dimensional `Ψ`, on a **curved** manifold (the
   second component switches on nonlinearly ⇒ the linear width `R̂` will exceed the intrinsic dim `r̂`, the
   Oracle's §2 `r̂ ≪ R̂` regime).

**What this means for the goal.** If `S` genuinely factors through a ~3-dim `Ψ = (canopy height, understory
fraction, pulse/atom shapes)`, then the lidar operator `H` acts on `Ψ`, and the effective dimension the data
can see is small and *interpretable* — the transferable-manifold thread (thread 2) gets a concrete candidate
`Ψ`. It also sharpens the operator question: canopy height and canopy-layer tightness are exactly what a
canopy-height-distribution `H` reads well, while the understory atom sits under the canopy where lidar is
occluded — a first, concrete guess at a *spoken-never-heard* direction (thread 1 / `response-quotients.md` §1).

**Caveats — do not over-read (single operating point).**
- **One `(θ, c)`.** This is the quotient *at one trait value and one rainfall scenario*. The load-bearing
  question is **transferability**: does the same `Ψ` (canopy height + understory fraction + fixed shapes) hold
  **across θ and across c**, and is it `c`-invariant? That needs the multi-solve sweep (M2, not yet run) — it
  is the difference between "the state is low-dim here" and "the calibration payoff is real."
- **Rainfall transient.** The `sin(2πt)` rainfall I imposed injects oscillations into `π_u` (0.14/0.36/0.14
  during the transition); a constant or realistic-series rainfall would give a cleaner `π_u(age)`. Hygiene fix
  for M2.
- **Degenerate metric flagged.** The scripts also print `template collapse = 1 − SS_res/SS_tot`; this is
  **uninformative** (with the template set to the column mean, `SS_res ≡ SS_tot`, so it is identically 0). The
  evidence above rests only on `sd_across_age` of the standardized deciles and the raw decile trajectories, not
  on that line.
- Split height `h = 2 m` is a hand-picked antimode; robustness to the split (and an adaptive antimode) is a
  cheap follow-up.

**Feeds:** the **quotient candidate `Ψ`** for M2 (transferability sweep across θ and c) and for the impersonation
test `τ` (`response-quotients.md` §6). Does *not* yet touch the operator `H` — that is the `H′`-cost gate,
still the decisive fork for the affordability of the whole attribution scheme.
