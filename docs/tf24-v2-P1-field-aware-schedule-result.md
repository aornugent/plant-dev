# P1 — static field-aware schedule shapes: NULL (uniform stays best; corroborates the feedback-dominated diagnosis)

*2026-07-21/22. First prototype off the offspring-convergence finding
(`tf24-offspring-convergence-finding.md`). The finding says the error is soil-water
field-shift concentrated at small τ_ins. Floor prototype: test whether a static
**dense-early** cohort schedule (power spacing `τ = T·u^p`, dense at small τ_ins) beats
uniform at matched count. `scripts/tf24-benchmarks/field_aware_min.R`, intense_storms
(12 yr), N=94, relerr vs a 2× uniform anchor.*

## Result

| schedule | relerr vs 2× uniform | note |
|---|---|---|
| default | 4.29 | overestimates ~5× (known) |
| uniform | 0.061 | today's best simple schedule |
| early1.5 (`u^1.5`) | 0.232 | worse |
| early2 (`u^2`) | 0.277 | worse |
| early3 (`u^3`) | 0.028 | better — but see caveats |

Timing side-finding: the 2× uniform reference took **561 s vs 111 s** for the default —
**dense uniform is ~5× the per-run cost** (not 2.6× as node-count scaling predicts):
uniform densification is solver-expensive (more rejected steps), not free.

## Reading — NULL for static shapes

The dense-early families are **non-monotonic** (early1.5/2 much worse, early3 better than
uniform). Against a backdrop where (i) J is hypersensitive and non-monotonic in the
schedule (the 9c signature), (ii) the reference is 2× **uniform**, which structurally
favours the uniform family (same shape — the reference-bias caveat rung 2 already hit),
and (iii) this is one scenario — **early3's single win is not a robust lever.** There is
no clean "denser-early converges faster" trend.

**This corroborates the finding rather than contradicting it.** The offspring error is
*feedback-dominated* (T3: 100% field-shift). A static schedule shape is a **local/blind
placement rule**, and local rules cannot see feedback-dominated error — exactly the
Oracle's claim-1 point (and why the g-mass indicator anti-correlated in rung 2). Moving
cohort *density* around in τ_ins does not target the thing that's wrong (the field's
convergence, which depends on the whole coupled solve), so it moves J erratically.

## Consequences for the prototype programme

- **Uniform remains the pragmatic simple best** (6% here vs default 429%), but it is
  *not* a convergence fix (still 6% off a mere 2× mesh) and dense uniform is
  solver-expensive.
- **A static field-aware shape is a dead end.** The real fix must be **goal-oriented,
  feedback-aware refinement** — place/refine where adding a cohort most changes the
  *self-consistent* field (resolvent-weighted, per Oracle claim 1 / T1's dominant modes),
  not by any fixed shape. That is a bigger build and, given ~110–560 s per full solve, an
  expensive one to run iteratively in this environment.
- **Cost reality:** full SCM solves are ~110 s (default) to ~560 s (2× uniform) at 12 yr;
  iterative schedule optimisation over the bank is hours of compute. Any refinement
  prototype must minimise the number of full solves (e.g. one probe pass, not a search).

## Honest caveats

- One scenario (intense_storms), one anchor (2× uniform, confounded and itself only 6%
  from being converged). A schedule-neutral reference (very dense, neutral family, or
  per-family self-convergence) would be needed to *rank* shapes cleanly — but the null
  read (no robust static lever) is the right conclusion for a floor prototype and matches
  the feedback-dominated mechanism.
