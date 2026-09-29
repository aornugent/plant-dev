# Oracle response: the time integration

Reply to `oracle-consultation-solver-performance.md` as it stood at `bbba8d1`, captured
verbatim. What was tested against it is in `docs/handover.md`. The reply to the earlier
statement is `oracle-response-solver-performance-0acfa2a.md`.

---

## Short version

The tolerance is on the wrong object, twice over.

`J`'s time error is set by the members' switching times — about 9 000 kinks at `P_j = 0` in ~900 clusters, one cluster in the first `δ` or two after each forcing pulse ends — which the pair steps across mid-step. No tolerance on a state norm controls the error of a kink crossed at an unknown fraction of a step; that error is `O(h²·[slope jump])` with a sign set by where the kink fell, and `h` at those crossings is set by the stops, the stability boundary and the growth clamp, not by `tol` (steps grow as `tol^-0.10`). Hence T2.

The cost is set by the chain's stability during pulses forcing a full member sweep at every chain stage, although the members' increment over a leg needs a handful of samples of a smooth input. Hence 64% of evaluations on the `δ`-legs.

So: treat the switching times as events (locate them and step onto them, or re-integrate the switching member locally); treat the chain as a cheap, finely resolved *input* to the members rather than a state on the same step; and judge error in `J` with the costates the sweep already computes. Tolerance and step size become consequences.

## 1. Known class, standard treatments, what is load-bearing

T2–T8 are three textbook phenomena superposed.

**(a) A piecewise-smooth right-hand side integrated without event location.** With `ε = 1e-4` against `|Ṗ| ≈ 1.35e3`, the turn of `P⁺` is `5e-5 δ` wide, below `h_min`; to the integrator `P⁺` is `max(P, 0)`, a `C⁰` kink in `Ẏ`, `ẋ` and `Ṡ`. The inner problem's class switches and its clamp add more of the same kind. A Runge–Kutta step crossing a kink at fraction `θ` of the step has local error `≈ h²·[jump in slope]·K(θ)`, `K` a Peano-kernel factor of either sign; the embedded difference does not see it, because both formulas are fitted to a smooth function that is not there. With slope jump `≈ |Ṗ|·fG/ν ~ 1e3` and `h = 5.5δ`, `h²·1e3·K` is a few tolerance weights at `1e-4` — T4's 3.46, with true/estimate of 4.6 on the crossing steps and 0.45 on the rest. Because `h` at the crossings shrinks only as `tol^0.2` at best, the error follows `tol` only once `tol` is small enough to shorten steps everywhere (`1e-5`). T5 is the confirmation: force the crossing steps to `0.05δ` and proportionality returns. References: Gear & Østerby 1984; Enright, Jackson, Nørsett & Thomsen 1988; Shampine & Thompson 2000; Hairer–Nørsett–Wanner I, ch. II on discontinuities. Treatment: locate the switching time on an interpolant and end the step there. The crossings are transversal (`|Ṗ|` median `1.35e3`) and `P` does not feed back on its own switch, so this is plain event location, not a Filippov sliding mode — unless the 3 241 "within `0.05δ`" pairs are re-crossings of the *same* member rather than neighbours in a cluster; check that, and check that crossings were counted on the trajectory rather than between stage evaluations `0.1h` apart.

**(b) Stability-limited explicit stepping of a mildly stiff component.** `h|λ|/β ≥ 0.5` on 55% of steps, median `ρ = 0.044`, 18% rejections that vanish when the boundary is respected (T6): the standard signature. During pulses the chain sits near `v ≈ 0.9`, `|λ| ≈ 2–5e3`, so a `δ`-leg is `hλ ≈ 5–10` and takes 2.66 steps, each a full sweep. T6 shows this costs a great deal and does nothing to `J`.

**(c) Slow states driven by a fast input.** A member's increment is a quadrature of `g(φ(v(t)), …)` along the chain's trajectory, with `φ ∝ v^-6.57` amplifying. A stiff solver that damps the chain's transient instead of resolving it (T7's `11.2δ` step at `hλ = 21`) integrates every member against a wrong input, and an ESDIRK's embedded estimate at `hλ ≫ 1` through a `v^16` nonlinearity is not to be trusted (Shampine & Baca 1984; Hairer–Wanner II, ch. IV): 0.75 against 11.5. The earlier prediction failed because it treated stiffness as the chain's problem. The chain's transient is the members' input.

Standard treatments for (b) and (c): multirate with the *cheap* part fast and the *expensive* part slow (MIS, Knoth–Wolke / Schlegel et al. 2009; MRI-GARK, Sandu 2019 — designed for exactly this configuration), or stabilised explicit RK (RKC, ROCK — Abdulle 2002) if a single-rate scheme must be kept; and for the question "what should the tolerance measure", goal-oriented error estimation with the adjoint (Cao & Petzold 2004).

Load-bearing for `J`'s time error: the `P = 0` kinks and their clustering after each pulse; the post-pulse chain decay through `v^-6.57`, which sets `|Ṗ| ~ 1e3` and makes chain-transient errors expensive (T7); the knot stops, because the pulses are `3–4δ` wide and `~800` of them are missed otherwise (T8); the controller's insensitivity to `tol`; a max-norm in which the chain's error, forgotten within its own relaxation time, sets `ρ` while `J`'s error lives in `Y` and `F`. Incidental: the value of `ε` (any `ε ≪ δ|Ṗ|` is equivalent); the clamp and inflow switch at `v = 1`; the pool guard (throws cost ~1%); the open panel; `Φ`'s sliding knots (`C¹`); `ẽ`'s `C¹` kink; never removing members.

Load-bearing for cost: chain stiffness during pulses multiplied by single-rate coupling; one step per leg as a floor; boundary rejections; the cold-start inner solve (a constant factor); the event-handling cost, which the cluster structure sets; and ×3.5 through the sweep (H4).

## 2. Integration between stops

Keep an explicit pair on smooth pieces and make the pieces smooth:

1. **Detection.** Every evaluation already returns `P_j`, the class and `P_new`; add the clamp's status. A sign or indicator change between a step's start and end (or across its stages) flags an event.
2. **Location.** Root-find on the step's free Hermite interpolant, with a few single-member evaluations to refine (`~1e-4` of a sweep per event). Place the stop at `P = −η`, a hair past the crossing, so the evaluation at the stop is unambiguously on the new branch (see §4).
3. **Handling.** (A) *Safe:* make `t_c` a stop; the step ends there, the proposal carries. About one extra accepted step per crossing: `9 200 × ~320 ≈ 3e6`, roughly `8e6` in total at `tol = 1e-4` — half of T5, with the same error behaviour. (B) *Per cluster:* stop at the cluster's first crossing, then cap `h ≤ 0.05δ` until its last member has crossed (T5 shows `0.05δ` suffices down to `1e-5`): `+4 600` steps, `~6.5e6`. (C) *Member-local:* re-integrate only the switching member's nine components over `[t_n, t_c]` and `[t_c, t_n+h]` against `φ(t)` and `Φ(t)` interpolated over the step, ~12 evaluations of one member; on cluster steps, re-run the cheap chain with the corrected draw and take one corrector sweep. The corrector is needed only if `c_ℓj` kinks at the crossing, i.e. if the class switch coincides with `P = 0` — the class readings tell you. Cost `≈ +0.4e6`.
4. **The chain resolved where it is fast.** In the first `~0.3δ` after a pulse starts and the first `~2δ` after it ends, the transient must be inside the step's resolution. Pulse boundaries are known in advance and `λ` is a free reading, so either cap `h` there or micro-step the chain (§3).
5. **The pool.** `Ṡ` is linear in `S` given `P`; replace its explicit stage with the exact-in-`S` exponential update. Positivity at any `h`, throws gone, and the `7δ` drain after a switch-off no longer limits gap steps.

With that, the estimator is the honest one T4 measured on non-crossing steps, and T5 supplies the constant: `J`'s error `≈ 0.1–0.3·tol`, so `tol ≈ 3e-4` for `1e-4`.

What it can guarantee: local error control never bounds a global error. But the sweep computes `∂J/∂y(t_n)` at every accepted step — that is what a costate is — so `ΔJ ≈ Σ_n λ_nᵀ e_n` is an a posteriori estimate at no cost, conservative since `e_n` is the fourth-order formula's error while the fifth is propagated. Report it per run and drive `tol` from it. That is the certificate the tolerance was standing in for.

## 3. The floor, and exploiting the time scales

The structure that sets the floor: `~800` pulses, each with a rise transient (`~0.3δ`), a body (3–4 `δ`-legs), a decay to a switch-off cluster (`1–2δ`) and a gap. The members need about one fifth-order step per body leg (`φ(t)` is smooth within a leg — `v_eq ∝ s^{1/16}` follows the cubic closely), two steps down the decay to the cluster, one or two after. That is `~40` sweeps per pulse, `~3e4` sweeps, `≈ 1.7e6` member evaluations cold-start, plus events under (C). So about `2e6` for a reliable `1e-4`, against `4.6e6` unreliable now and `1.6e7` for T5. Warm-starting the inner solve from the member's last accepted solution (same `1e-10` convergence; solutions from rejected attempts never seed) is worth a further 2–3×, to `~1e6`. Estimates, to be checked on the driver; the ladder to get there:

- **Events alone (§2):** `6.5–8e6`, reliable. Do this first regardless.
- **ROCK4 (or RKC) in place of Cash–Karp**, `s` chosen per step from the chain's diagonal reading so one step spans a leg (`hλ ≈ 5–10 → s = 4–6`; stability interval `≈ 0.35 s²` for ROCK4, `≈ 0.8 s²` for ROCK2). Same recording shape (one row, `s` evaluations), boundary rejections gone, roughly ×0.6. Caveat: a stabilised method damps the chain's transient rather than resolving it — the T7 lesson — so measure the members' increment across a pulse start.
- **Multirate, MIS/MRI-GARK form.** Slow partition: members, accumulators, moments — one sweep per slow stage. Fast partition: the chain, integrated between slow stages with its own cheap steps at a tight tolerance (`1.4e3` instructions each; in gaps the loss has the closed form `v ← (v^{1−q} + (q−1)kh)^{−1/(q−1)}`, or use `u = v^{1−q}`, in which free decay is linear). The draw enters the fast integration as the MRI interpolant of the slow-stage values in *time* — never re-evaluating members in the fast loop (T10 row 1's mistake, which is not MIS) and never linearising `a` in `v` (rows 4–5: a `v^-6.57` dependence extrapolated affinely across a pulse). Knots, the floor and the clamp become chain-only stops. Macro step: at most a leg inside pulses, across knots wherever `s` is smooth through them (the three low-forcing stretches, if the record is a smooth hump there rather than spikes), and ended by member events. Beyond ROCK this removes the chain's accuracy from the members' controller, allows macro steps across knots, and resolves the post-pulse transient by construction.
- **Member-local events (C) and warm starts** take it to `~1e6`.

On "exploiting the difference in time scales": yes, but the property to exploit is that the chain is *cheap*, not that it is fast. The members' own scales (`x`, `F` over `70δ` and more; `S` at `7δ`) allow long macro steps in gaps only once their input is smooth, which is what event location provides. The floor is one inner solve per member per sample the pulse response needs, times `~800` pulses; nothing in the stepping scheme changes that count.

## 4. What `dJ/dθ` needs

- With no evaluation straddling a switch, H2's branch-following is exact and the local error is a smooth function of the state. The frozen-grid derivative (H1) is then the exact gradient of a discrete `J` whose error is `O(h^p)` with an `O(h^p)` θ-derivative: it converges with `J`. Without event handling, the crossing error `h²·[jump]·K(θ_c)` has θ-derivative `h·[jump]·K'·dt_c/dθ` — one order worse, random sign. The gradient is currently converging more slowly than `J`.
- No event-sensitivity term is required: the vector field is `C⁰` at the crossing, so trajectory sensitivities are continuous through it and a located `t_c` is legitimately a constant of the recording. This holds only while nothing jumps at an event — the pool guard and the `m` ceiling are the places to keep it so.
- Landing at `P = −η` matters: an evaluation exactly on a class boundary takes whichever branch the solver returns, and the one-sided IFT derivative then flips with `θ`, putting `O(weight)` jumps in the gradient.
- Multirate and member-local pieces: micro steps, interpolant coefficients and the local rows go on the recording as recorded arithmetic (or the chain is recomputed forward in the sweep from the recorded macro state — it is cheap); the sweep's cost stays `~2.5×` the forward evaluations.
- For the optimiser: freeze the whole grid — steps, stops, micro grid — across consecutive gradients while the a posteriori estimate stays under tolerance, and re-adapt only when it does not. Between re-adaptations `J(θ)` is smooth and the gradient exact.

## 5. Order of measurement on the test bed

1. Locate-and-stop (A) at `P_j = 0`, the class, the clamp and `P_new`, landing at `P = −η`, no refusals: expect T5's errors at roughly half its cost.
2. The same with (B).
3. Recount crossings on step ends or the interpolant; check whether class switches coincide with `P = 0` (decides whether (C) needs the corrector).
4. Measure `|a_ℓ| / (k v_ℓ^q + in_ℓ)` along the run and the smoothness of `a(t)` within and across legs (decides the macro step in the multirate scheme).
5. ROCK4 with `s` from the diagonal reading, then the multirate split, then warm starts.
