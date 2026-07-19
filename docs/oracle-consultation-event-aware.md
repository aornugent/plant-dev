# Follow-on: event-sizing measured — best-practice event-aware integrator design?

A numerical-methods question. No application context is needed or given. This **follows six prior
rounds** on the same IVP; the last round retired the fast/slow block decomposition and proposed a
**temporal** one — piecewise-smooth arcs separated by located events, on the *same* global adaptive
explicit RK. We have now **measured where the controller actually collapses its step** across a bank
of increasingly hard forcing sequences. The measurement **partly refutes the assumed event budget**
(one proposed event class is already handled; the forcing-kink class is a minority) and localises the
collapse to the **state-dependent crossings**. We want best-practice **event-aware integrator design**
for this structure — and, if the data say the residual is mostly intrinsic and event-handling buys
little, say so.

## Settled from prior rounds (treat as established; do not re-litigate)

IVP `y' = f(y,t;θ)`, `y ∈ ℝ^N`, adaptive embedded explicit RK, single global step, `10³–10⁵` steps.
`y = [ large block x ∈ ℝ^M (M ≈ 50–800, several independent such blocks may share one u) | small
block u ∈ ℝ^L, L ≤ 5 ]`. Reverse-mode gradient of a scalar functional `J` w.r.t. small `θ`; adjoint
cost tracks accepted steps; `J` amplifies coupling error ~10×.

- Two couplings: `a_ℓ(x,u) = Σ_j ρ_j c_ℓ(ξ_j, u, p_j*)` (expensive, O(M) byproduct of per-member
  solves; `ξ_j` ordered member coordinate, `ρ_j ≥ 0` a **skewed** weight; `p_j*` an argmax by
  fixed-iteration bracketing) feeding `u̇ = b(u,t) − a`; and `s(x)` (cheap size-only aggregate)
  feeding `ẋ_j`. `u̇` also carries a near-singular self-loss and a clamp at `u_min`.
- **The step collapse is accuracy-driven, not stability-driven; it is kink-localisation, not fast
  smooth motion** (prior round): 10⁻⁸·T-scale steps at scattered isolated points, an `h_min` wall that
  is a resolution limit, and a decomposition that freezes `x` while sub-cycling `u` exactly is still
  24% wrong in J — so the macro structure lives in `x`'s motion, punctuated by events.
- **The event functions are decoupled from the expensive RHS:** a member's threshold crossing is a
  scalar test on `(ξ_j, u)` (0 member solves); a forcing kink is a table lookup; an argmax-bound flip
  is 1 member solve. The controller instead locates each by **rejection bisection at O(M) per probe**.
- The three candidate event classes: **forcing kinks** in `b(·,t)` (known times); **member
  insertions** (an adaptive schedule we control); **state-dependent crossings** — a moving interior
  threshold where `c_ℓ(ξ,u,·)` switches to 0 (position depends on `ξ` and `u`), the argmax bound, and
  the `u`-clamp at `u_min`. A **tracked-control** variant (`ṗ_j = k ∂P/∂p`, a smooth differential
  state) is available and removes the argmax-bound class at a measured-acceptable lag.

## What we measured (the payload; some refutes the assumed budget)

Bank of six forcing sequences of increasing harshness (a forcing-magnitude ramp low→high; a long
70-unit horizon; an embedded severe multi-year low-forcing spell; sparse-but-intense bursts; a
multi-block run; and alternating extreme high/low-forcing years). Global adaptive explicit RK at converged-J
tolerance, with a per-attempt step log (start time, trial size, accepted/rejected). "Small" =
smallest decile of accepted step size; attribution = proximity (≤ one forcing-sample interval) to a
known surface.

| sequence | reject fraction | min h / T | small@kink | small unattributed |
|---|---:|---:|---:|---:|
| ramp | 0.308 | 4.0e-8 | 0.04 | 0.96 |
| long horizon | 0.272 | 1.4e-8 | 0.31 | 0.69 |
| embedded low-forcing spell | 0.293 | 3.3e-8 | 0.02 | 0.98 |
| sparse intense bursts | 0.292 | 5.0e-8 | 0.03 | 0.97 |
| multi-block | **0.347 → non-finite** | 2.5e-8 | 0.00 | 1.00 |
| alternating extremes | 0.281 | 0.18 | — | 0.82 |

1. **~27–35% of all step attempts are rejected and retried smaller** — one in three O(M) RHS
   evaluations is discarded to rejection bisection. Uniform across sequences.
2. **The step collapses to ~1e-8·T at scattered points**, confirming isolated non-smoothness.
3. **Forcing kinks explain a minority** of the collapse (4–31% of small steps), and the share
   **tracks forcing-event frequency** (0.31 on the high-forcing long horizon; 0.02 on the low-forcing
   spell). The small steps cluster **in the quiet, low-forcing intervals — away from kinks.**
4. **Member insertions explain ~0**: the integrator already places insertions on step boundaries. One
   proposed removable class is **already handled**.
5. **70–98% of the collapse is unattributed to the a-priori surfaces**, sitting in the quiet /
   near-`u_min` regime → dominated by the **state-dependent crossings** (interior `c`-switch threshold,
   argmax bound, `u`-clamp). We have **not yet split this residual into removable events vs genuine
   intrinsic fast structure** — that is the open measurement.
6. **The multi-block run goes non-finite** (integration blows up) at the highest reject fraction — an
   instability, not merely a slowdown, when several large blocks share one `u`.

## Structural features — any may be load-bearing or incidental; we do not know which

Event functions decoupled from the O(M) RHS (0–1 solves) vs rejection bisection at O(M)/probe; skewed
`ρ` (so the injected kink at a crossing scales with `ρ_j` → only heavy members are controller-visible
→ small event set); the moving interior `c`-switch threshold in `(ξ,u)`; the argmax bound (removable
by the tracked-control variant); the `u`-clamp / near-singular self-loss at `u_min`; forcing kinks at
known times; insertions already on boundaries; ~30% rejection fraction; 1e-8·T scattered minimum step;
the quiet-interval clustering of small steps; the non-finite failure under several shared-`u` blocks;
`J`'s 10× amplification; adjoint cost tracking accepted steps; the free full-M evaluation available at
every macro boundary; a documented discretisation change acceptable if forward and reverse stay
correct.

## Facts an answer can rely on

- Event functions cost 0–1 member solves; a rejection-bisection probe costs O(M). Skewed `ρ` makes the
  controller-visible event set small.
- Forcing-kink times are known a priori; insertions are already step boundaries; the argmax-bound class
  can be removed by the smooth tracked control.
- A full-M evaluation of both couplings is free at every macro boundary.
- The step limit is accuracy-driven (implicit stepping refuted); the collapse is isolated
  non-smoothness, not smooth stiffness.
- The reverse-mode adjoint must stay a faithful FD of the solver as run; active event times restore the
  schedule sensitivity a frozen schedule drops.

## Questions (open; please rank the features and reject the framing if the data warrant)

1. **Best-practice event-aware design for this structure.** Given event functions cost 0–1 solves and
   a rejection probe costs O(M), and given the collapse is dominated by state-dependent crossings in
   quiet intervals: what is the right construction — step-to-event with dense-output root location and
   restart? continuous event detection without shortening the step? How to keep design order across
   arcs, and how to drive the ~30% rejection fraction toward zero without under-resolving genuine
   structure?
2. **The residual is state-dependent crossings, not kinks or insertions.** What is the cheapest way to
   (a) **localise** the interior `c`-switch threshold, the argmax bound, and the `u`-clamp on dense
   output, and (b) **separate removable events from intrinsic fast structure** within the 70–98%
   residual — the measurement that tells us whether event-handling is worth building?
3. **The non-finite failure under several shared-`u` blocks:** is this an undetected discontinuity the
   explicit RK integrates across (curable by events), or a distinct stability failure (curable only by
   a stiff/robust sub-step or a state projection)? What cheap test distinguishes them?
4. **Chattering:** members oscillating across the interior threshold, and the `u`-clamp engaging/
   releasing. Hysteresis, event clustering, or a **declared mollification** of the switch below
   `J`-sensitivity (a model-side smoothing) — which, given `J`'s 10× amplification makes a mollified
   width leak into the gradient?
5. Which measured fact is **load-bearing** for the design, and which is incidental?
6. **What are we missing** — e.g. that the member mesh is refined for `x(t)` while `J` depends on
   `∫ c·ρ`, so the accuracy axis is the discretisation not the time-stepper; or that the functional is
   so sensitive it should be reformulated rather than resolved.
7. A **cheap discriminating experiment** for the design you judge best — before we build it.
