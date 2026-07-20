# Supplementary correction to the fundamentals elicitation

> A short erratum + one question, addressed to the **fresh-context** Oracle
> that answered `oracle-consultation-fundamentals.md`. It corrects one
> factual error in that document that your highest-ranked finding depended
> on, and asks whether — with the correction applied — any leverage
> remains, in your finding or anywhere you can now see. No other framing is
> changed; the rest of the elicitation stands.

---

## The erratum

Your ranked-first finding ("the forcing node lattice is the prime suspect
for the entire broadband accuracy limit") read, correctly, that §4 of the
document described the drivers as running through "a fine piecewise-linear
node grid, a few hundred nodes per time unit," while §1 described `b(t)` as
a `C²` spline. **§1 is correct; §4 was wrong.** The two sentences
contradicted each other and you reasonably built on the §4 wording. The
error is ours, and we owe you the true state of the code:

- The driver is a **cubic spline** (`C²`), evaluated through a standard
  tridiagonal cubic-spline interpolant. This is the **default and the only
  representation any measured sequence in the record used.**
- Piecewise-linear interpolation exists but is a **non-default option that
  was never exercised** in any benchmark. So your test (b) — "rerun with
  the `C²` spline option already in the code" — is inverted: the spline is
  what already ran; linear is the unused switch (and would be *worse*, not
  better).
- The knots are the raw forcing samples (a few hundred per time unit, i.e.
  roughly daily over multi-year horizons), so the *knot count and spacing*
  you inferred (~3×10⁻³, ~10× below the median step) are right; only the
  **continuity class** was wrong (`C²`, not `C⁰`/`C¹`).

Consequences for the finding, as we see them — and we want your read, not
our conclusion:

1. **The specific mechanism you gave is refuted.** "Order-5 crossing a `C¹`
   kink drops to local `O(h²)`" does not operate: `b` is `C²`, there is no
   `b'` jump at a knot. The clean numeric coincidences you noted (kink-
   limited `√tol` ⇒ ~32× vs measured 47×) therefore lose their basis.

2. **But two of your observations survive the correction, and leave a
   genuine puzzle we cannot close:**
   - A cubic spline is only `C²`: its **third derivative jumps at every
     knot.** The solution `u` is then `C³` with a jumping fourth derivative
     at each knot, so an order-5 method still **cannot achieve full order
     across a knot** — it should top out near order 4 there. Your structural
     point ("the grid nodes are a broadband non-smoothness no instrument
     ever measured") is therefore **correct as stated** — our clip and our
     classifier only ever logged *value-change feature* times (knots where
     the sampled value changes), never the dense set of spline knots, of
     which every one carries a `b'''` jump even inside a smooth dry spell.
   - **The measured "wall" is unexplained by any of the three stories.**
     Past the tolerance at which `J` has converged, tightening tolerance a
     further 3 decades costs ~47× work for no `J` change. As a work–
     precision slope that is an effective order of ≈1.8 — *worse* than clean
     order 5 (would be ~4×), worse than your order-2 `C¹`-kink prediction
     (~32×), and worse than the order-4 a `C²`-knot would predict (~5.6×).
     Something is limiting the broadband effective order below 2 on a `C²`
     forcing, and the discrete events that could do it (the Filippov corner
     / switch-off surfaces) were measured to fire <0.5% of steps and *not*
     to co-locate with the rejections. We do not have a mechanism.

## The question

Given the correction — forcing is `C²` cubic spline, not piecewise-linear,
and the residual puzzle above:

1. **Does your forcing finding retain any leverage in its corrected form?**
   If the dense spline-knot lattice (jumping `b'''`, unmeasured by any
   instrument) can still cap the achievable order — or if the sub-order-2
   wall points at a different broadband non-smoothness we have not named —
   what is the cheapest measurement that would confirm or kill it? (We can
   log distance-from-each-step to the nearest *spline knot*, offline and
   free, from saved per-step data.) Conversely, if the correction kills the
   finding outright, say so plainly — a retired stone is as useful to us as
   a live one.

2. **Do your other original findings survive the correction unchanged?**
   Three of them did not depend on the forcing representation and are the
   ones a zero-context reading surfaced that our context-bound analysis had
   ruled out of scope — we want to make sure the erratum does not
   accidentally discredit them:
   - interpolating the *control field* across members while keeping all `M`
     atoms (distinct from the member-subsampling we retired);
   - **remeshing the measure** to test whether the 23% inter-scheme spread
     is measure-discretisation rather than time-integration error;
   - the **arrow-structured Jacobian** un-retiring implicit methods at
     `O(M)` cost as a near-ceiling stability mode.
   Are any of these strengthened, weakened, or newly connected now that the
   forcing is known to be `C²`?

3. **With the record corrected, is there hidden leverage we have still not
   surfaced?** You observed that the experiment ledger only ever varied the
   *integrator* against a frozen problem statement, and named five soft
   joints (forcing, inner equation, measure, norm, observable). The forcing
   joint is now corrected. Of the remaining four — and of anything the
   corrected record newly exposes — where, ranked by information-per-cost
   with a falsifier attached, would you look next? We are specifically
   trying to avoid declaring the forward problem closed one correction too
   early.
