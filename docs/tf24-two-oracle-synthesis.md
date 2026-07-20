# Two Oracles on the fundamentals elicitation — synthesis & triage

> Both responses to `oracle-consultation-fundamentals.md`, side by side:
> the **ongoing** Oracle (8 rounds of established context,
> `-response-ongoing.md`) and a **fresh** Oracle (zero context,
> `-response-fresh.md`). The user's question: *"unpack what they found …
> identify where your elicitation was misleading or where the previous
> Oracle had established context."* Saved 2026-07-20.

---

## TL;DR

- **Both converge on the same four items** (gradient seam, J-geometry,
  multi-block robustness, M^1.4 scaling) with near-identical mechanisms and
  fixes. That convergence is real signal — a context-carrying and a
  zero-context reasoner independently landed on the same shortlist.
- **The ongoing Oracle accepted "numerics closed."** The fresh Oracle
  refused the frame: it noticed the whole experiment ledger (§6) only ever
  varied the *integrator* against a *frozen problem statement*, and named
  five never-varied "soft joints." That is the sharpest divergence and it
  is **context-attributable**: the ongoing Oracle inherited the 8-round
  frame that the problem is fixed and only the integrator is in play.
- **The fresh Oracle's headline (forcing node lattice) rests on a false
  premise I put in the elicitation.** §4 said "fine piecewise-linear node
  grid"; the code uses a **C² cubic spline** (verified). The specific
  order-drops-to-2 mechanism is wrong. But a *weaker, untested* version
  survives (see §2 below), so it is neither cleanly confirmed nor cleanly
  refuted.

---

## 1. Where they converge (both Oracles, independently)

| item | ongoing Oracle | fresh Oracle | verdict |
|---|---|---|---|
| **A · gradient seam** | bordered fold system `{R=0, ∂R/∂v=0}`, safeguarded Newton from the bracket, `p*` as an IFT node; adjoint gains dropped term exactly; validate vs re-solving FD; retires `τ`. | IFT on the branch-death condition `g(p,state)=0` (a fold `F_r=0` or a domain-boundary exit), `∂p*/∂state = −g_state/g_p`; same validation; retires `τ`. | **Same object, same fix.** Both solve for `p*` via the *branch/fold condition*, not `∂P/∂p=0`. Highest-confidence item. Model-owner (plant#60 / task #23). |
| **C · multi-block overflow** | NaN-unsafe `rmax>1.1` is false for NaN → accept/grow → poison; NaN-guard + growth clip from logged reservoir margins; **recession map as a *robustness* lever** (removes `u^q` from RK stages, positivity by construction). | false-negative error estimate at the fast-block stability ceiling; reject-on-non-finite + cap `h` at the `L×L` reservoir bound / 291× coupling; same recession-map role. | **Same diagnosis, same fixes.** NaN-guard is one line and both name it first. |
| **D · M^1.4 & the ~30% rejection** | ~M^0.4 in eval count = extreme-value growth of the max-norm; **norm-argmax log** (round 8, still unrun) is the instrument; J-relevance-weighted norm flattens the exponent; then parallelise (embarrassingly parallel member sweep). | identical: rmax-component **identity churn** is the one-query test; RMS / adjoint-weighted norm; goal-oriented / dual-weighted-residual using the tape; parallelise + rejection salvage. | **Same.** Both name the goal-oriented (J-weighted) norm as *the only lever that reduces accepted steps*. |
| **B · J geometry** | intrinsic piecewise-C¹ across an absorbing (extinction) boundary; **mollify** the survival entry (width budgeted against the 23% spread) + **moment-aware insertion** (`ρ·|c|`, `φ·ρ`) + run the long-flagged M-refinement certification. | same class; **lineage-decomposition experiment** first (is `ΔJ` a handful of survival flips or diffuse?) → then mollify *or* report sharp-J + flip inventory. | **Same class, model-side.** Fresh adds a concrete test *before* the fix; ongoing goes straight to the fix. |
| retired stays retired | PI controller, event program, decomposition/MRI, collocation-of-`a`, warm-Newton-on-`∂P/∂p` | same list retired; adds caveats (see divergences) | agree |
| **patch library** | "single most valuable reusable artifact this program has produced." | "the only admissible oracle for any future claim." | **both name it the top artifact** |

**Read:** the four-item shortlist is robust. A and C are cheap and
well-specified; D has a free instrument already designed (norm-argmax log)
and unrun; B is a model-owner decision.

---

## 2. Where they diverge — and why

### D1 · The frame: "numerics closed" (context) vs "the ledger only tested integrators" (fresh)

The single deepest split. The ongoing Oracle opens with *"the
characterisation closes the numerics … the global adaptive explicit RK is
at the efficient frontier."* The fresh Oracle opens its second pass with
*"the record doesn't actually prove what it feels like it proves … every
entry in §6 is a search over integrators against a frozen problem
statement."* It names five never-varied joints: **forcing representation,
inner-solve equation, measure representation, error norm, observable
definition.**

**This is context, not disagreement.** The ongoing Oracle helped *build*
the 8-round frame in which the problem statement is fixed and only the
integrator is in play; it reasons inside that frame and correctly reports
the frame is exhausted. The fresh Oracle, cold, treats the frame itself as
the untested variable. Both are right about their own question. The useful
consequence: **the remaining forward levers, if any, live in the problem
statement, not the stepper** — which is where the fresh Oracle's stones 1,
3, 4 point.

### D2 · Stone 1 (forcing node lattice) — false premise, but a live residual

Fresh Oracle's headline; ongoing Oracle silent on it. Its premise:
*"§4 says … a fine piecewise-linear node grid … piecewise-linear means a C¹
discontinuity of f at every node."*

**Premise is false — verified in code.** `extrinsic_drivers_set_variable`
→ `Function(x,y)` → `Interpolator::init` → `basic_spline::set_points(x,y)`
with default `cubic_spline = true`. The driver is a **C² cubic spline**, not
piecewise-linear. So the specific mechanism (order-5 → local O(h²) at C¹
kinks; the 32×≈√tol match) **does not apply** as stated. The `47×` wall is
*not* explained by C¹ kinks.

**The premise came from my elicitation.** §4 line 208 literally says "a
fine piecewise-linear node grid," contradicting §1's own "C² spline." This
is the concrete instance of *"where your elicitation was misleading"*: I
inverted the forcing representation, and the fresh Oracle spent its
highest-ranked stone proposing a fix (switch to the C² spline) we **already
ship by default** — and its test (b) ("rerun with the C² spline option")
is backwards (linear is the option, spline is the default).

**But a weaker version survives and is untested.** A C² cubic spline still
has a **discontinuous third derivative at every daily knot**, so an order-5
method cannot achieve full order across knots (drops toward ~order 4, milder
than the Oracle's order-2). The daily-knot spacing (~3×10⁻³ yr) is ~10×
below the median step. Two facts keep this alive:
  1. The measured wall (`47×` over 3 decades ⇒ effective order ≈ 1.8) is
     *worse* than clean order 5 (would be 4×) **and worse than even the
     order-2 C¹-kink prediction (32×)**. Something is capping the effective
     order below 5 and it is unexplained.
  2. **No instrument ever logged distance-to-knot.** The clip and the
     classifier only ever looked at *value-change features* (a sparse
     subset: `y[i] != y[i-1]`, so a dry spell contributes none). Every daily
     spline knot is a C²-knot with a jumping 3rd derivative that neither
     instrument measured. The fresh Oracle's observation *"no instrument
     ever looked at the grid nodes"* is **correct even though the
     continuity class is C² not C¹.**

→ **Triage: premise refuted, residual open.** The node-distance enrichment
test (below) is cheap and still worth running before we accept "forward
numerics closed" unconditionally.

### D3 · The inner solve as a *speed* lever (fresh) vs accuracy/gradient-only (context)

Fresh stone 2 sells Newton-on-`g` as a **triple win including speed**
(per-member ~32→~20 units; ~3–4 evals to 1e-12 vs ~14 golden-section to
1e-3). The ongoing Oracle treats the *same fix* as **item A, accuracy +
gradient only, "cost near neutral,"** because it already knows the
τ-invariance result (tightening inner tol leaves the outer rejection
fraction unchanged; enrichment ≈ 1).

**Both can hold.** τ-invariance says *inner tolerance* doesn't drive *outer
step rejection* — it does **not** say the per-member solve cost is fixed.
Newton-on-`g` could cut the constant factor of each member solve (fewer
objective evals per solve) even though it won't change the step count. The
τ-sweep never measured per-eval cost. So the fresh Oracle's speed claim is
a *different axis* the ongoing Oracle's context foreclosed. Testable.

### D4 · Implicit methods: un-retired as a near-ceiling mode (fresh) vs firmly retired (context)

Fresh stone 6: the Jacobian is an **arrow matrix** (M independent blocks
bordered by L+1 dense rows/cols for `u`,`s`) → Woodbury/block-elimination
factors it in O(M), and stone 2 makes the border analytic → implicit is
un-retired *at linear cost with clean Jacobians*, deployed **only near the
stability ceiling** (multi-block). The ongoing Oracle keeps implicit
retired flatly ("no stability limit to sell").

Context call: the ongoing Oracle knows RODAS lost 20–50× and that there's
no *global* stability margin — both true. The fresh Oracle's claim is
*narrower* (implicit only in the multi-block near-ceiling exception), which
the ongoing Oracle's blanket retirement doesn't directly rebut — but the
ongoing Oracle covers the same exception with the **recession map** (item
C), which is simpler. Mild divergence; recession-map probably wins on DX.

### D5 · Genuinely new fresh-Oracle moves the ongoing Oracle never raised

- **Stone 3 — interpolate the control *field*, not the members.** Keep all
  M atoms; at each RHS eval, solve the exact argmax at m synthetic nodes in
  member-feature space, interpolate `p*` across members (field is smooth to
  the floor), evaluate each member's `g,c` at its interpolated control;
  exact solves for the <0.5% near switch-off. **Distinct from the retired
  collocation**, which subsampled *members* (fatal — heavy atoms must be in
  the sample). This subsamples *solves*, not members. Not refuted by any
  prior round.
- **Stone 4 — remesh the measure.** The 23% inter-scheme spread may be
  *measure-discretization* error (different insertion histories → different
  discrete measures) wearing an integrator costume. Test: remesh a pair of
  schemes onto a common node set every K steps (guard-band the near-
  threshold atoms) and see if the spread collapses below 23%. This is the
  fresh Oracle's most original contribution and it directly attacks item B's
  23% from a different direction than mollification.

Both are context-blind spots of the ongoing Oracle: it accepted the member
mesh as fixed and looked only at *where* to insert, never at *remeshing*
or *field-interpolation of the control*.

---

## 3. Where the ongoing Oracle's context clearly *helped*

- **Retired its own two framings** ("mid-run step collapse," "rejection =
  overhead") with the exact data that killed them (min-h = start-up step;
  enrichment ≈ 1; PI +13–29%). A fresh reasoner cannot retract positions it
  never held.
- **Sharper gradient locator**: the bordered fold system `{R=0, ∂R/∂v=0}`
  is a more precise statement of the same object the fresh Oracle called
  `g` — because it tracked the corner discovery across rounds.
- **Correct model-owner vs solver boundary** (item B is a science
  decision) — a judgment that needs project context.
- **Closed ledger with tombstones** — the retired-approaches table is only
  writable by someone who watched each die.

## 4. Where the ongoing Oracle's context *hurt* (frame lock-in)

- Missed stones 1, 3, 4, 6 entirely — all live *outside* the integrator,
  which its "numerics closed" frame had ruled out of scope.
- Declared the ~30% rejection "measured-optimal, nothing to find." The
  fresh Oracle offers a concrete alternative (max-norm extreme-value → a
  J-weighted norm that *could* cut accepted steps) that the "at the floor"
  verdict forecloses without testing.

---

## 5. Ranked cheap tests (§7 discipline: falsify before building)

Ordered by information-per-cost. None is a build.

1. **Node-distance enrichment (settles stone 1's residual).** From saved
   `results/classifier_raw/` step data: distance from each rejected /
   small-decile step to the nearest *daily spline knot* (not value-change
   feature); enrichment vs accepted steps. If rejections cluster at knots →
   the daily lattice caps the effective order and "numerics closed" is
   premature. If flat → stone 1 is fully dead. **Offline, minutes, free.**
2. **rmax-component identity churn (settles D + confirms both Oracles).**
   One field per attempted step: which component achieves rmax. Churn ⇒
   extreme-value story ⇒ a J-relevance-weighted norm is worth building.
   This is the round-8 norm-argmax log, still unrun. **One log field.**
3. **Effective-order probe.** Re-fit the tolerance→cost wall; confirm the
   ~1.8 effective order and check whether a *smoother* driver (fewer knots
   / a smoothed spline) moves it. Cheap; directly tests the D2 residual.
4. **ΔJ lineage decomposition (fresh's B-test).** Pair two converged
   schemes at M≈350, match by insertion lineage, split ΔJ into matched
   drift vs unmatched survival flips. Tells us if 23% is diffuse
   conditioning or finitely many bits — decides mollify-vs-inventory.
5. **E4 / adjoint FD (item A, task #23).** The one high-value correctness
   test still unrun. Model-owner (plant#60).

Builds (all gated on the above, several model-owner): the fold-locator IFT
node (A); NaN-guard + growth clip (C, cheapest, lowest-risk — arguably
ship-worthy on its own); mollified J + moment-aware insertion (B,
model-side); J-weighted norm (D, if test 2 confirms churn); remesh probe
(fresh stone 4, if test 4 says the spread is measure-side).

---

## 6. The one-line answer to the user's question

**Where the elicitation misled:** §4 called the forcing "piecewise-linear"
when it is a C² cubic spline — inverting the representation and sending the
fresh Oracle's top-ranked stone at a fix we already ship. (Fix the
elicitation before any future send.)

**Where prior context showed:** the ongoing Oracle's "numerics closed"
verdict, its self-retractions, and its precise fold-locator are all
downstream of the 8-round frame — which also blinded it to the four
problem-statement levers (forcing knots, control-field interpolation,
measure remeshing, arrow-Jacobian implicit) that the zero-context Oracle
surfaced because it never accepted the frame.
