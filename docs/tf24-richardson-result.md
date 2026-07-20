# Ladder rungs 2 + 4-tail — Richardson certification and the tolerance band

> The two offline rungs of the correction-response ladder. Both came back
> negative-but-decisive. Script: `scripts/tf24-benchmarks/richardson_J.R`.
> 2026-07-20.

## What ran

One sequence (bursty forcing), horizon ~10 time units. A **nested fixed
schedule family** {47, 93, 185 members} (subsample ⊂ base ⊂ 2×-densify), all
at `τ_ode = 1e-6`; plus the finest mesh re-run at the production `τ_ode = 1e-4`
for the tolerance band.

## Results

| mesh (fixed) | J (τ_ode=1e-6) |
|---|---|
| 47 | 4.852e-8 |
| 93 | 2.826e-8 |
| 185 | 1.065e-8 |

- **Convergence order p ≈ 0.20.** J roughly *halves* with each mesh doubling;
  the successive differences barely shrink (|ΔJ| 2.03e-8 then 1.76e-8, ratio
  1.15). Richardson extrapolation gives a **negative J\*** (−1.06e-7) —
  nonsense for a positive functional. **The fixed-densification family is not
  in the asymptotic regime**; Richardson cannot certify J on it.
- **Tolerance band: J@1e-4 vs J@1e-6 = 61 % apart** on the 185-mesh.

## Reading — both negatives are the *same* confound, and it is the point

Both results are dominated by one fact already on the table: **the fixed
schedule is catastrophically under-resolved in the measure** (the production
default is ~6× off; here J is still changing ~2× per doubling at 185). On such
an unconverged measure, *everything* moves J — mesh density and ODE tolerance
alike. So:

1. **The Oracle's "free Richardson" move does not work on the fixed family.**
   J on uniform fixed densification is not asymptotic (p≈0.2), because
   **placement, not count, is what converges the measure** — the adaptive
   refiner's 173→320 pair was only 2.3 % apart at similar counts, while fixed
   47→185 spans a factor of ~5 in J. The refiner is doing essential work that
   uniform refinement does not replicate. The Oracle intended Richardson on the
   *refined* pairs; I substituted fixed densification because a third *refined*
   point needs the >15-min refiner. **So the "free this afternoon" certificate
   is not actually free** — it needs either the slow refiner extended to a
   third point, or the ghost-based goal-oriented placement the Oracle proposed
   (its item 2), which is now the load-bearing route, not the fallback.

2. **The tolerance-band check is confounded and must be redone on a converged
   mesh.** The 61 % here is *not* evidence against "production runs at the loose
   tol edge" — it is the unconverged measure amplifying every knob. The
   original "3 decades of tol for no J change" was measured on the converged
   production config; this test cannot speak to it. The clean version needs an
   adaptively-refined (converged) measure held fixed while only `τ_ode` varies
   — deferred until a converged measure is cheap to obtain (i.e. after the
   ghost/goal-oriented placement exists).

## Consequence for the ladder

- Rung 2's "free Richardson" half is **struck** (fixed family non-asymptotic;
  refined family not cheaply extendable). Its other half — **goal-oriented
  placement from a single solve + ghost sweep** — is promoted from "nice" to
  **the** certification route, because uniform refinement demonstrably does not
  converge the measure at feasible counts.
- This *sharpens* the case that the **measure axis is the main event and is
  genuinely hard**: it is not merely "needs more members," it is "needs the
  right members," and the only cheap way to find them (per the Oracle) is the
  ghost probe. That elevates the **ghost-member capability** (ladder item 1)
  from high-value to the **prerequisite** for certifying J at all.
- The tol-band question is **unresolved, not answered** — re-run on a converged
  measure before claiming production sits at the loose edge.
