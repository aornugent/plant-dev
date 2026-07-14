# A self-consistent coupling node: our solution, and the invariant we're reaching for

For feedback from both prior respondents. The domain stays general and mathematical;
the concrete system is named only so the invariant has something to bind to: an
interpolator primitive (`odelia`) and two coupled environment fields built on it (a
light field and a water/soil field) in a size-structured solver (`plant`).

---

## 1. The system (recap, general terms)

Reverse-mode AD gradient `dM/dθ` of a functional `M` of a growing ensemble of
characteristics that couple **only** through shared low-rank fields. Each field `S`
is a `k`-knot reconstruction (`k ≈ 17`, knot positions fixed) of an aggregate the
ensemble itself generates: `a(z) = Σⱼ wⱼ κ(z, xⱼ, stateⱼ; θ)` (a quadrature over the
ensemble), `s(z) = ψ(a(z); θ)` (here `ψ = exp`, Beer's law), reconstructed to the
spline `S`. Each characteristic reads `S` **at its own coordinate** `xᵢ` — both the
**value** `S(xᵢ)` (enters its rates) and the **slope** `∂S/∂x(xᵢ)` (the transport
term). So every characteristic is simultaneously a **source** and a **reader** of the
field, at a moving coordinate. There will be a second such field (water) with the same
structure. The forward value of the transport term is a stability-mandated finite
difference; only its derivative is in question.

Correctness bar: the reverse gradient must match a converged finite difference of the
model actually run, for **both** parameter classes at once — *trajectory-moving*
(direct-effect: strongly move `xᵢ`) and *coupling-only* (whole effect through the
field; a null-channel parameter with true sensitivity ≈ 0 exposes any spurious term).

---

## 2. What we established, by experiment

A single per-step object controls everything: the θ-sensitivity of the field read
(value and slope) injected into the transport-term derivative. We measured every
treatment against a converged FD on the two-cohort census (truth: direct `b_0 ≈ 319`;
coupling null-channel `k_I ≈ 0.144`).

| treatment of the field-read θ-sensitivity | direct params | coupling / null-channel |
|---|---|---|
| **drop** (freeze query, no coupling θ) | ✓ ~0.2% | ✗ **189×, wrong sign** |
| **keep** (analytic coupling θ, frozen query) | ✗ **2.3×** | ✓ ~5% |
| keep + reader-motion (un-freeze query fully) | ✗ **0.26×, sign flip** | ✓ ~5% |
| **cavity, read-point** (analytic self-subtraction `E·e^{comp_self}`) | ✗ 1.5× | ✓ **5–7%** |
| **cavity, deposit-level** (downdate self AT KNOTS, re-spline) | ✓ **~1%** | ✗ **k_I 94% low** |

Three findings are now firm:

1. **The error is a faithfulness bug, not a numerical one.** Forward values are
   bit-identical, forward-JVP = reverse-VJP to machine precision, yet reverse ≠ FD by
   an O(1) factor that doesn't shrink with FD step. That is categorically "the tape
   linearizes a function other than the one it evaluated" — our value uses a robust
   FD-stencil transport term but the injected derivative comes from a different
   (analytic) construction.

2. **Self-reference is the load-bearing structure.** The spurious signal for a
   trajectory-moving parameter is the characteristic reading the *slope of its own
   imprint* on the coarse field as it moves — a self-force. Leave-one-out fixes it,
   but only when done at the **deposit level** (downdate the source's own contribution
   at the knots and re-reconstruct); the analytic read-point cavity is quantitatively
   incomplete because the reconstruction *smears* each source across knots, so
   analytic-self ≠ reconstructed-self.

3. **The two cavity variants fix opposite classes — and that is the crux.**
   Deposit-level LOO makes the direct params machine-close (`b_0` 1%) but drives the
   coupling null-channel `k_I` to ~0 (94% low), because a clean self-exclusion also
   removes the characteristic's **genuine** self-coupling — the `O(k/N)` self-term,
   which at `N = 2` is most of `k_I`'s signal. Keeping self (no cavity) matches
   finite-N FD on `k_I` but leaves the direct params 2.3× hot.

So there is a single self-block that is **spurious for one channel and genuine for the
other**, and no single treatment of it satisfies both. This is the real obstruction,
and it is where the two philosophies we were given diverge:

- **"faithful discrete adjoint of the model-as-run"**: the finite-N model *does* let a
  characteristic feel its own field-gradient, so FD (`k_I ≈ 0.144`) is truth and the
  self-term must be **kept**; the direct-param overshoot must then be cured *without*
  removing self (e.g. by a stencil whose exact adjoint is well-conditioned and a query
  read that carries its motion).
- **"cavity / mean-field"**: the self-force is a coarse-grid artifact (Detweiler–
  Whiting, PIC self-force, propagation-of-chaos), the correct gradient is the
  self-excluded one (`k_I ≈ 0.008`), and finite-N FD is *not* the gold standard for
  coupling-only parameters.

Our measurements confirm each philosophy is internally consistent (deposit-LOO
realizes the second; a faithful un-frozen stencil would realize the first) and that
they are **mutually exclusive under the current architecture**, which reads the value
and the slope through *separate, self-smeared* constructions.

---

## 3. The invariant we're reaching for

We think the robustness/performance/stability we want is not a fix to any one term but
a **structural invariant on how anything couples through a reconstructed field** — one
that, once imposed, makes the light field, the water field, and every future coupled
field correct by construction. Our candidate, stated for critique:

> **All coupling flows through an explicit low-rank node — the `k`-knot vector `c` —
> and every consumer reads it only as a transpose-exact linear functional of `c`.**
> Four properties are then structural, not per-site conventions:
>
> 1. **One reconstruction, one transpose.** Value, slope, and the curvature the adjoint
>    needs are all read from the *same* `c` through stored basis rows `B, B', B''`; the
>    reverse rule is the exact transpose (gather-from-readers → transposed solve →
>    scatter-to-sources). Faithfulness is automatic because there is only one function.
> 2. **Smoothness ≥ highest derivative read.** The reconstruction is at least one order
>    smoother than the deepest derivative any consumer takes (the transport term
>    reaches the field's second derivative, so the node is `C²`+), and the deposit is
>    `C¹` in source position — so no read is a difference of a difference and no
>    quantity blows up as `k` refines.
> 3. **Self-exclusion is a source-identity mask on the node, applied identically to
>    every channel.** Because each source's contribution to `c` is explicit (a rank-1
>    block), "leave-one-out" is one structural downdate `c^{−i} = c − depositᵢ`,
>    applied the same way to the value read and the slope read — never per-channel,
>    never analytic-at-the-read-point.
> 4. **Stability from smooth deposition, not from a switch.** The transport value is
>    stabilized by the node's own smoothing (deposition order / knot filtering), which
>    is differentiable, rather than by a non-differentiable upwind/limiter stencil
>    whose exact adjoint staircases.

The single remaining **modeling decision** — keep or drop the `O(k/N)` self-coupling —
becomes an explicit, uniform property of the mask (include or exclude the diagonal
block), not an accident of which term happened to be frozen. That is the crux we could
not make principled *without* the explicit node: the self-block was implicit and
smeared, so we kept re-deriving it inconsistently.

---

## 4. What we're asking

1. **Is the invariant in §3 the right one — necessary and sufficient — for a coupled
   reconstructed field to be simultaneously faithful, well-conditioned, and stable?**
   Is anything missing, or over-specified (e.g. is the `C²`+ requirement real given the
   slope is read as a secant, or does the secant let us drop an order)?

2. **The self-block decision (§2.3 / finite-N).** Is the `O(k/N)` self-coupling that a
   characteristic exerts on its own field-gradient **genuine physics of the model-as-run
   that a faithful adjoint must keep** (so finite-N FD is truth and the direct-param
   overshoot must be cured another way), or a **coarse-grid self-force to be excluded**
   (so the deposit-level cavity is right and finite-N FD is not the reference for
   coupling-only parameters)? Both respondents' frameworks were internally consistent;
   we need the tie-broken, ideally by a property of the *continuum* limit the discrete
   solver approximates rather than by taste.

3. **If keep-self is correct**, what is the well-conditioned, faithful realization of
   the transport-term derivative that does **not** remove self — i.e. an on-tape
   differentiation of the actual (smoothed) stencil with the query read carrying its
   motion — and why did our un-frozen-query experiment overshoot (0.26×, sign flip)
   rather than land on FD? Is that overshoot a second faithfulness bug (the secant
   value and the analytic query-motion belonging to different reconstructions), which
   the single-reconstruction invariant would remove?

4. **Does the invariant compose to the second (water) field for free**, including the
   case where that field carries its own ODE state (memory), so its self-block downdate
   must act over history — and is the affine/superposition self-downdate the only
   closed form, or is there a general one?
