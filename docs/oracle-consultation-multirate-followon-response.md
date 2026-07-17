# Oracle response — follow-on: re-derive strategy from the cost structure

*Response to [`oracle-consultation-multirate-followon.md`](./oracle-consultation-multirate-followon.md).
Recorded verbatim (lightly reformatted). Dated 2026-07-17. Hypotheses to test, not verdicts; the
response supplies ranked experiments E1–E4 — run E1 (setup decomposition) first, it sizes everything.*

---

## Headline strategy

The probes **relocate** the problem. Probe A kills "make the argmax cheap along the u-path"
(continuation warm-start — owned/struck below). Probe B says **the fast dynamics never needed M
members**. And the cost decomposition hides an unexploited number: **setup ≈ 11 of ≈ 21 — the dominant
per-member cost is `u`-dependent preparation, not optimization.** Any scheme touching members at `u`'s
fast rate pays `setup × (members touched) × (micro rate)`; that product is the whole game. Make every
factor small: **m ≈ 15–20 members** (Probe B), **argmax → evaluation at a tracked control** (the Probe-A
alternative, endorsed and sharpened), **setup paid once per micro stage**. MRI survives as skeleton; the
fast RHS changes species.

## 1. What Probe A refutes (and the prior advice it kills)

Continuation warm-starting of the member solves is refuted at the root, not the tuning: Newton on
`∂P/∂p=0` diverges over realistic micro excursions because `p*(u)` moves by order-of-range while `P`'s
domain edge (bound-ward) closes in — the basin shrinks exactly where the excursion goes. The production
bracketing search is fixed-cost by design. So dense-in-`u` exact re-optimization is dead as the primary
mechanism. **Not** refuted: evaluating `c(x_j,u,p_j)` at a *given* `p_j` (setup + one objective ≈ 15.6,
no search, no divergence). The fragility lives entirely in re-solving the argmax → remove the argmax
from the fast loop.

## 2. Tracked controls: promote `p_j` from argmax to slow state

Carry `ṗ_j = k·∂P/∂p(p_j; x_j, u, s)` as a differential state.
- **Deletes the fragile object.** No micro-rate optimization anywhere; `c` evaluated at the current
  `p_j` (a state); `∂P/∂p` exact/cheap (IFT). The bracketing search survives only for **initialization**
  (member birth / run start), where its fixed-iteration smoothness-in-inputs still earns its keep.
- **Lag is a knob with the right sign.** `k` = tracking bandwidth; a tracked `p` low-passes the true
  `p*(u)` during fast excursions. A documented, controlled discretization change; physically a finite
  adaptation rate is often more defensible than instantaneous re-optimization. Set `k` from a measured
  `p*`-tracking-error-vs-`k` sweep against tight truth.
- **Reverse mode simplifies.** Tracked `p_j` is ordinary tape history — no per-evaluation IFT argmax
  node; only needs `∂P/∂p` smooth on the tape (guaranteed) and one more derivative order in `P` for its
  adjoint (closed form via the same inner-root IFT).

Cost catch: naively M tracked controls stepped at the micro rate → `M × setup × micro-rate` again (now
for `∂P/∂p` instead of the objective). Escape = Probe B applied to the **controls**, not just the coupling.

## 3. The m-member fast subsystem (the core proposal)

Build the fast block as a small self-contained ODE on the quadrature members only:
```
fast state:  u ∈ ℝ^L,  {p̂_n}_{n=1..m} at fixed node coordinates x̂_n     (dim L + m ≈ 20–25)
micro RHS:   u̇   = b(u,t) − Σ_n W_n · c(x̂_n, u, p̂_n)
             p̂̇_n = k · ∂P/∂p(p̂_n; x̂_n, u, ŝ)
```
`x̂_n` node coordinates per smooth piece (§5 kinks); `W_n` quadrature weights (active functions of the
member coordinates); `ŝ` the cheap aggregate on its slow interpolant (frozen-per-leg, taped passive).
The full-M `x_j` stay on the slow MRI-leg clock as before; the full-M controls `p_j` are also slow —
tracked at the macro rate (drivers `x_j,s` slow; the `u` they read = micro solution at macro abscissae),
or re-optimized once per macro stage where the ≈21 is already paid for `ẋ_j`.

**Cost per micro RHS:** `m × (setup + one gradient-eval) ≈ 20 × ~15 ≈ 300` units, vs `M × 21 ≈
1,700–17,000` for naive exact refresh. Micro-rate cost is now **flat in M**; beats the global solver by
1–2 orders across the M range.

**Setup amortization within a micro stage:** the ≈11 setup is per `(member, u)`-pair; a multi-stage
micro method re-evaluates at several `u`'s/step, paying setup each time. **If setup splits into
`u`-dependent and `(x,p)`-dependent parts, cache the latter per node per leg.** Else prefer micro
methods stingy with RHS evals (low-stage Rosenbrock-W with the small dense Jacobian of the (L+m) system;
`∂/∂p̂` of the coupling and `∂²P/∂p²` diagonal blocks from exact IFT partials, recorded passive per the
W-property rule).

**Consistency:** at each macro stage check `Σ_n W_n c(x̂_n,u,p̂_n)` matches the full-M aggregate to
quadrature tolerance (free — both computed); record the residual, let pass 1 refine `m` if it drifts.
This doubles as the interpolation-error monitor at the near-singular end where Probe B converged slower.

## 4. Where this leaves the architecture

MRI skeleton unchanged. Inner stepper unchanged in kind (kink-split, evented clamp with active
event-length roots, desingularized coordinate, Rosenbrock-W) but integrating an (L+m)-dim state instead
of L. Coupling treatment **replaced**: no continuation-warm-started exact refresh (Probe A), no
per-micro-step full-member anything; collocation upgraded from *interpolating coupling values* to
**co-integrating the interpolant's nodes as dynamical members**. Tape: micro loop = m small closed-form
rate evals + one small linear solve/step; all argmax IFT machinery retreats to initialization (and macro
stages if the solved bulk is kept). Nesting improved. Gradient notes: (i) `W_n` active (freezing drops
sensitivity); (ii) node placement `x̂_n` schedule-like (pass-1 choose, pass-2 passive, FD-injected);
(iii) `k`-lag makes `p̂` dynamical — FD validation must use the same `k`; (iv) members crossing regime
boundaries are C7-class events in the member coordinate — split the quadrature at the crossing (active
root of the boundary condition), restoring convergence and carrying the Leibniz jump exactly.

## 5. What we're missing / where the framing bends

1. **The setup number is the biggest unexamined lever.** ~70% of a coupling evaluation is preparation
   whose reuse structure is uncharacterized. If setup is affine/low-rank in `u` (u-dependent tables/roots
   reusable across members), the m-member micro RHS drops toward `m × 4.6`. **One afternoon of profiling
   with a two-way (member × u) cost breakdown; do it before sizing anything.**
2. **Probe A's divergence is a physics warning, not just Newton.** `p*(x,u)` is nearly non-smooth in `u`
   near `u_min`; the solved-argmax variant would put a near-kink inside the fast dynamics — so tracked-`p`
   isn't merely cheaper, it's the **smoother, better-posed** dynamical model near the bound. Expect large
   *genuine* gradient sensitivities there (`∂²P/∂p²`-small directions), not pathology.
3. **You may be over-solving the bulk.** If m members suffice for the coupling, ask what accuracy the M
   individual `ẋ_j` need between output times — if `g(x_j,…)` is as smooth in the member coordinate as `c`,
   the same quadrature logic could advance a reduced set and interpolate member trajectories, making even
   the macro floor `o(M)`. Bigger surgery (changes what the population is; touches moment-functional
   weights) — flagged, not recommended, but it's the natural end-state of this axis.
4. **The exact-gradient constraint binds less than it appears.** Dropped schedule sensitivity, frozen
   node placement, passive W-Jacobians are already accepted; the tracked-`p` lag and m-member reduction
   are the same class (controlled forward-model discretization choices, exact gradient for the scheme as
   run). The binding constraint is **smoothness-on-the-tape of everything active** — why the fixed-iteration
   search (kept at init) and the tracked-`p` rate (smooth by construction) are the right citizens, and why
   the one thing to police is the regime-boundary crossings of §4(iv).

## Experiments, ranked

- **E1 — setup decomposition profile** (two-way member × u cost breakdown). Decides the micro-RHS cost
  model. *Do first, before sizing anything.*
- **E2 — `k`-sweep** of tracked-`p` vs solved-`p*` truth on recorded episodes; sets the lag, validates
  the variant change.
- **E3 — windowed (L+m)-system prototype** vs tight-tolerance truth across the stiff regimes that
  previously plateaued — the **go/no-go**.
- **E4 — taped window:** adjoint vs frozen-record FD, plus gradient-vs-`m` and gradient-vs-`k` sweeps —
  certifies the accepted value-errors don't amplify in the gradient.

---

## Our reading / mapping to the real system

- **Tracked control = TF24f exactly** (`ṗ = k·dprofit`, evaluate not optimise; `k_acclim`). The Oracle
  independently re-derived TF24f as the *better-posed* fast model near the dry bound — strong convergence.
- **m-member fast subsystem** = co-integrate the soil states with the tracked collar potentials of only
  `m ≈ 15–20` collocation cohorts; the full stand's cohorts stay on the macro clock.
- **E1 (do first):** is the ≈11 per-cohort `set_physiology`/prepare `u`(=ψ_soil)-dependent (redo per
  micro-step) or member-dependent (cache once per leg)? If member-dependent dominates, the micro RHS is
  cheap and the whole scheme sizes down.

## E1 measured (2026-07-17) — `scripts/tf24-multirate/e1_setup_decomp.R` — FAVORABLE

Two-way (member × θ) cost breakdown, R-level (µs); the decisive question resolves in the scheme's favour.

- **R→C++ dispatch overhead ≈ 4.7 µs/call.** The earlier "setup ≈ 11" was roughly half Rcpp marshalling
  artifact; real C++ costs are smaller. (The C++ hot loop pays none of it.)
- **`set_physiology` is flat in `vulnerability_curve_ncontrol`** (10→2000 ctrl pts: ~21 µs constant) —
  the vulnerability curve is built at construction, not per call. **Flat in soil-layer count** too
  (1/5/20 layers: 21.0/22.4/22.2 µs). Its cost is fixed per-call work + the temperature/photosynthesis
  Arrhenius block, which the code **already caches** (`photo_temp_cached_`, θ-independent), plus
  `electron_transport` from the **leg-frozen PPFD**. ⇒ the "setup" is **member/env-dependent and
  cacheable once per leg**, *not* θ-dependent.
- **The θ-dependent per-micro-step work is cheap and bounded by L:** evaluate (soil-side
  `prepare_collar_solve` + one objective) ≈ 5 µs and `dprofit` ≈ 7 µs (R-level, 5 layers) → ~2–5 µs real
  C++; both scale with soil-layer count (L ≤ 5), not with member attributes.

**Verdict:** setup is **u-INDEPENDENT and cacheable per leg** — the Oracle's biggest worry (setup ×
members × micro-rate) is defused: only the small θ-dependent evaluate+gradient is paid per micro-step,
and plant's existing cache guards (`photo_temp_cached_`, `use_precomputed_z_soil_mid_`) are the natural
seam. Combined with Probe B (m ≈ 15–20 members), the m-member fast subsystem's micro-RHS is genuinely
cheap: `m × (θ-dependent evaluate + gradient) ≈ 20 × ~(2–5 µs)` per micro-step, flat in M. The scheme
sizes down as hoped.

**Next:** E2 (`k`-sweep: tracked-`p`/TF24f vs solved-`p*` truth on recorded episodes — set the lag,
validate the variant), then E3 (windowed `(L+m)` prototype vs tight truth on the stiff regimes that
plateaued — the go/no-go).
