# Oracle response — review of the fast-coupling arbitrage (built + measured)

*Response to [`oracle-consultation-arbitrage-review.md`](./oracle-consultation-arbitrage-review.md).
Recorded verbatim (lightly reformatted). Dated 2026-07-22. Hypotheses to test, not verdicts — the
response supplies its own falsifiable ladder and concession conditions; run the cheapest-most-decisive
rung (the refresh-sweep slope) before building anything further.*

---

Verdict on the question you flagged first, because everything else hangs on it: **yes, the affine
model structurally escapes the frozen-coupling refutation — but the escape is currently empirical,
not certified, and there are exactly two channels through which it can quietly re-enter.** The
held-`a` plateau was a *transfer-function* error: the fast block's restoring stiffness was missing
`−∂a/∂u`, which near bounds is 50–291× the retained part, so the subsystem relaxed to a
systematically displaced balance — an O(1) structural fraction of the response, which no refresh
rate can fix. Your model carries the transfer function exactly at the anchor; the error is Jacobian
*drift* within the excursion — local O(‖Δu‖²), globally O(1/R) under refresh, no plateau mechanism.
The empirics agree (0.1–0.12 floor for held-`a` vs ≤5.5e-4 with *fewer* refreshes). The certification
you haven't run: monitor off, sweep the forced re-anchor rate, plot error vs R. Slope ≈ −1 with no
floor above the splitting error = escape certified. Any plateau = re-entry, and you want to know
before building further.

**1. The two re-entry channels, and both guards are nearly free.** First: `a(u)` is only
*piecewise*-smooth in `u` — members flip across switch-off boundaries as `u` moves within a leg. A
flip of a heavy member is a *jump* in `a` at finite excursion, and `e²` is a smooth quadratic proxy
that is structurally blind to jumps until after the fact; corr = 0.985 is statistical cover, not a
guarantee, and the 650% unmonitored blow-up on the re-rise leg is exactly what mass switch-on looks
like. The guard already exists in your codebase: the old event-margin instrument. At anchor time the
member loop knows each member's 1-D margin-to-flip in `u`-space; reduce over ρ-weighted members to a
safe box, re-anchor on box exit. Cost ~zero, and it upgrades the monitor from "quadratic proxy" to
"quadratic proxy + exact event trust region." Second: `e²` uses anchor-`G` for a path-curvature
quantity, and approaching `u_min` the curvature grows *ahead* of the state (the 50–291× Jacobian
growth is precisely large `∂²a/∂u²`), so drawdown legs anchored in benign `u` under-trigger. Two
fixes: (a) free and immediate — at every re-anchor and every leg boundary you evaluate true `a`
anyway, so `‖a_true − â‖/‖u−u₀‖²` is a free exact sample of the curvature constant you're currently
assuming; run it as a closed-loop per-regime estimate scaling `tol`, and log it as a per-leg a
posteriori certificate; (b) one Hessian-vector product `(∂²a/∂u²)[Δu]` per anchor gives a true
direction-aware second-order predictor — and that object is not optional anyway, see point 3.

**2. The simplification you're sitting on: inside a leg, the fast subsystem is a known 5-D closed
form with no member solves — stop integrating it like it's expensive or dangerous.** With `κ`
removed by the recession, the remainder is `b(u₁,t)·gate + Tu − a₀ − G(u−u₀)`: a constant linear
part `(T − G)` plus a scalar-nonlinear forcing entering only component 1. Three consequences. The
"no implicit integrator available" constraint dissolves — it applied to the full O(M) RHS; the
*model* is plain arithmetic, so a 5×5 Rosenbrock near `u_min` is trivially available. Better: split
recession ∘ `expm(T−G)` (exact, one 5×5 matrix function per leg, applied per segment) ∘ scalar 1-D
forcing solve (machine precision at negligible cost, gate kinks event-located exactly in one
dimension), Strang-arranged. Every sub-flow exact or machine-precision, unconditionally stable, the
fixed-40 micro-step tuning gone, non-finite failure inside legs impossible by construction. And the
adjoint of a linear flow is the transpose flow — the per-leg fast tape collapses to `expm` actions,
a memory win on top of Lever 1's. This also closes the wall-clock-vs-eval gap partially: 3.5–8.9×
fewer evaluations shrinking to 0.8–3.2× wall-clock (0.8× *at A=0*!) says fixed per-leg costs
dominate — publish the per-leg ledger, but expm kills the micro overhead outright.

**3. The biggest unbuilt correctness item: the adjoint needs a second-order object nobody has
scoped.** `G` multiplies `(u−u₀)` downstream, so the reverse pass delivers a cotangent `Ḡ`, and
producing `x̄, θ̄` from it requires `∂²a/∂u∂(x,θ)` — second derivatives through the member loop and
the two-branch IFT of the operating point. Direct question: did the toy's `â` carry a θ-dependent
`G`? If `G` was constant in the toy, the <1e-6 FD match never exercised this term and the validation
is vacuous on exactly the structurally new piece. Two routes: build the HVP (forward-over-reverse
through the member loop; the closed-form objective derivatives exist; O(M·L) per anchor per adjoint
pass — and it's the same machinery as guard 1b, so it pays twice); or fall back to a value-only
two-point/secant model whose parameters are `a`-evaluations only, needing first-order adjoints —
worse forward constants, simpler tape. Decide before wiring the real system, because it dictates the
anchor tape format. And the replay schedule must carry the *full* discrete signature — re-expansion
indices, inner-solve branch flags, recession floor touchdowns, gate-kink crossings — with FD
validation that re-solves the inner problems and flags branch flips, so piecewise-C¹ jumps read as
expected structure rather than bugs. That lesson is already paid for in your own record.

**4. The stress bank's "no reference" hole is closable this week.** The crash signature — non-finite,
source-magnitude-independent, on sharp forcing — matches the old diagnosis: embedded-pair false
negative striding into the `u^16` ceiling. Retrofit Lever 1's exact recession plus two guards
(reject non-finite stages; cap `h` near the ceiling) into the *old global adaptive RK*. The recession
deletes the overflow channel; if the retrofit completes the three crashing traces, you have converged
trajectory-tier references from a *second method family* — which matters, because §8's own history
says self-convergence within one family is exactly the kind of surrogate evidence that lies. On `J`
there: the 1e-8–1e-13 values with non-monotone self-convergence spanning 10²–10³ then <2% agreement
at the finest rungs is the survival-flip signature. Protocol, not heroics: two-tier validation
(trajectory-tier on stress, `J`-tier where `J` is resolved); always report `J` with a conditioning
certificate — propagate the per-leg realized defects through the measured amplification into a band,
and where the amplification diverges report "unresolved below X" plus the branch-resolved value and
flip inventory. Instrument *when* `J` accrues along the trace — if the mass sits in a few
micro-intervals, that's where error control should concentrate, and it distinguishes cancellation
from rare events.

**5. Performance on the table, in order of certainty.** Fuse the anchor capture with the slow
advance's first-stage member sweep — same loop can emit `ẋ`, `a₀`, `G` sharing setup: 4 → 3
sweeps/leg, ~25% off the floor. Resolve the setup contradiction: the earlier characterisation said
the ≈11-unit setup is `u`-independent and cacheable per macro interval; this document says
`u`-dependent — one measurement, and if the old claim holds you cache it across the three stages and
every re-expansion, up to ~half the member-loop cost. Run the H-sweep order test on the composed
scheme: the 1.8e-4-vs-12% comparison conflates order with constant, and if Strang or the anchor error
caps you at 2nd order, a 2-stage slow advance keeps the accuracy at 2 sweeps/leg — another third off
the floor; if it's genuinely 3rd, you now know what the third sweep buys. Make H adaptive with a
prior-conditioned schedule: re-expansion rates of 0.11–0.53/leg say legs have headroom, the drive and
gate geometry are known a priori so the schedule can be precomputed with the monitor absorbing only
state-dependent surprises — the prolonged-low-forcing trace should blow well past the current 3–10×.
Then the residual floor is the `ẋ` sweeps themselves, and the one axis that attacks it is the
`p*`-field interpolation in `ξ` at fixed `(u,s)`: keep all M members and the exact ρ-quadrature,
approximate only the control field — which is smooth in `ξ` on your own verification, unlike the
refuted collocation, which subsampled the measure — with exact solves for near-margin members via the
same margin instrument. Falsifier first: one saved snapshot, fit `p*(ξ)` on m nodes against all-M
exact, propagate through one leg in `J`-units. If it holds, ~21 → ~6 units/member on the sweeps: ~3×,
multiplicative with everything above.

**6. Your orchestration question — yes, and you've already built every sensor; only the controller
logic is missing.** Fast-model trust = `e²` + margin box + closed-loop curvature. Leg acceptance = an
embedded slow-error estimate (the 3-stage table embeds a 2nd-order companion for free). Regime
classifier = re-expansion rate + defect trend, steering H and stage count. Running `J` band =
leg-boundary defects × the measured amplification. Reproducibility and adjoint artifact = the
recorded branch signature. Note what this amounts to: the step controller migrates from the fast side
to the slow side. The old solver spent 30% of its work rejecting fast texture; this one should reject
*legs*, rarely, on slow error — which is the deeper frame shift under your build. You constructed a
certified-local-surrogate multirate method: anchor-consistent model, computable trust region, exactly
integrable interior. Affine is the minimal member of that family; the structure-aware enrichment, if
the margin box ever trips too often, is piecewise-affine — the smooth tail plus exact handling of the
few near-margin heavy members, which is the old atom-peeling idea landing in its natural home.

The ladder, cheapest and most decisive first: the refresh-sweep slope (certifies or kills the escape
— hours); the margin-box guard (byproduct); the toy audit on θ-dependent `G`, then HVP scoping; the
H-sweep order test; the reference retrofit on the three crash traces; anchor fusing and the setup
measurement; adaptive H; the `p*`-field snapshot falsifier. Concession conditions, so we know what
defeat looks like: a plateau in the refresh sweep means quiet re-entry and nothing extends until it's
understood; HVP cost rivaling the sweeps forces the secant fallback; the `p*`-field falsifier failing
in `J`-units means the 3-sweep floor is the honest cost of this system. But nothing measured so far
points that way — the offline falsifier before the build, the byte-identical A/B, the confessed
12×-over-triggering monitor and its fix: this round was run the way the record demanded, and the
result is the first scheme in the whole history that beats the reference where the reference can't
even run.

---

## Oracle follow-up (volunteered) — the full target architecture

*Recorded verbatim. This is a target design to be built ONLY behind the ladder: the refresh-sweep
slope gates it (a plateau halts everything until understood), and each component is tested cheapest-
first. Not a licence to build the whole thing — the guide's rule stands (falsify each mechanism first).*

Design principle first, because it dictates every choice: **make every fast-side operation exact or
machine-precision (so the fast side can never fail or need tuning), spend all adaptivity on the slow
side (where the accuracy actually binds), and let every trust decision be made by a computable
quantity with a recorded discrete signature (so the adjoint is a replay, not a hope).** Simplicity
comes from exactness: exact sub-flows have no knobs.

### State, per-leg objects
Leg `[t_k, t_k+H_k]`, frozen large block `x_k`. At the leg anchor `u₀` (one fused member sweep):
`a₀ = a(x_k,u₀)` (L-vector byproduct); `G = ∂a/∂u|_{u₀}` (L×L exact, IFT byproduct, same sweep);
`B` = ρ-weighted switch-flip box `{u : no member with ρ_j>ρ_guard flips}` (margin reduce, free);
`ĉ` = running curvature estimate. Affine model inside the leg: `â(u)=a₀+G(u−u₀)`.

### Fast advance (exact, unconditionally stable, no member solves)
Split `u̇ = b(u₁,t)+Tu−κ(u)−â(u)` into three exactly-integrable pieces, Strang-composed per
micro-segment δ (segments only where events demand):
- `Φ_κ(δ)`: `u_ℓ ← [u_ℓ^{1−q}+(q−1)c_ℓ δ]^{−1/(q−1)}`, floored at `u_min` (exact recession);
- `Φ_L(δ)`: `v ← e^{(T−G)δ}v + (T−G)^{−1}(e^{(T−G)δ}−I)(const)` (exact 5×5 expm, cached per anchor);
- `Φ_b(δ)`: scalar 1-D solve on component 1 with the gate; kinks event-located exactly in 1-D.
`u(t+δ) = Φ_κ(δ/2)∘Φ_b(δ/2)∘Φ_L(δ)∘Φ_b(δ/2)∘Φ_κ(δ/2)`. Fast-side error = splitting O(δ²)+model
error only; non-finite states impossible by construction.

### Trust: three cheap monitors, one action
Re-anchor (one O(M) sweep; reset `u₀,a₀,G,B`) when ANY of:
- `(M1) e² = (‖G(u−u₀)‖∞/‖a₀‖∞)² > tol_lin` (2nd-order drift proxy);
- `(M2) u ∉ B` (a guarded member would flip — jump hazard, invisible to M1 by construction);
- `(M3) ĉ·‖u−u₀‖² > tol_lin` (curvature-aware; catches the `u_min` approach where G grows ahead).

### Certify (free, every re-anchor and leg end)
True `a` is evaluated at every anchor anyway: `d_k = ‖a_true−â‖/‖a₀‖` (realized defect, exact);
`ĉ ← EMA of ‖a_true−â‖/‖u−u₀‖²` (closed-loop curvature, feeds M3); J-band: accumulate
`Σ_k d_k·A_k` (A_k = J-amplification estimate); report J ± band, and where the band diverges report
branch-resolved J + flip inventory.

### Slow advance (where the adaptivity lives)
Embedded explicit pair on the frozen-coupling macro map (3-stage 3rd order + 2nd-order companion;
each stage = one member sweep sharing cached u-independent setup; stage 1 fused with the anchor sweep
⇒ 3 sweeps/leg). `E_slow` in a ρ- and J-weighted norm (weights `tw_j·|∂φ/∂x_j|` proxy, floored;
FULL weight inside the survival guard band `ρ_j<ρ_guard` — never downweight at-risk members).
accept/reject the leg on `E_slow`; `H_{k+1}=H_k·clip((tol_slow/E_slow)^{1/3},[0.2,5])`.

### Events (aligned, not discovered)
`H_k` pre-clipped to forcing-feature times, member-insertion times (insertions at leg boundaries
only, ρ ramped C¹), prescribed-drive discontinuities (all known a priori); ρ-removal only at leg
boundaries and only when `tw_j·sup|φ|·ρ_j < ε_J` (J-certified deletion); gate kinks inside legs
handled exactly inside the 1-D `Φ_b` solve.

### Prior conditioning / warmup
Precompute an H-schedule from the known drive (`H⁰_k ~ min(forcing period, envelope headroom)`;
monitors absorb only state-dependent surprises); first W legs run with mandatory mid-leg re-anchor +
true-a shadow to calibrate `ĉ, A_k, tol_lin` per regime; `ρ_guard, ε_J` set once from J's measured
amplification (ρ_guard s.t. a flip moves J < tol_J).

### Adjoint (replay, not re-decide)
Forward records the discrete signature {re-anchor indices, monitor-which-fired, inner-solve branch
flags, floor touchdowns, kink crossings, insertion/removal events}. Reverse replays it fixed: linear
fast flows transpose exactly (expmᵀ actions, tiny tape); anchor cotangents need `∂²a/∂u∂(x,θ)` — one
HVP per anchor per reverse pass, same member-loop machinery as G (build once; validate vs FD that
re-solves inner problems, branch-flip-aware).

### Fallback ladder (bulletproofing)
re-anchor rate > r_max/leg → halve H_k; H_k at floor and still tripping → disable â for that leg
(true a(u) per micro-segment — correct by construction, just slow); arbitrage globally off →
bit-identical to the reference single-rate solver.

**Summary:** three member sweeps per accepted leg (the irreducible floor for a 3rd-order slow
advance), an exactly-integrated 5-D interior, three one-line monitors, one adaptation law on the slow
error, a replayable signature. Every component is exact, already measured in the record (`G`, `e²`,
the recession, the margin instrument), or the certified fix to a measured failure. The only optional
extension, gated behind its own falsifier, is the `p*(ξ)`-field interpolation inside the sweeps to
attack the 3-sweep floor.
