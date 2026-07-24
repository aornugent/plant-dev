# v3 — reverse-mode AD for plant × odelia: the complete design

The single source a new session reads to understand the coupled system and the
design, end to end, without oversimplifying. Derivations are cited to `design.md`,
the deepenings (`deepenings/`), the oracle responses (`oracle/oracle-response-*`),
and source (`plant/`, `odelia/`); this doc is self-contained on the *understanding*
and the *plan*. No history — only what is true and what to build.

---

## 0. Objective and the one invariant
- **DX = concept count.** A plant strategy author writes only scalar-generic
  closed forms + a few declarations: **0 `xad::` tokens, 0 hand-written adjoints
  in a strategy TU.** (design.md R1.)
- **Coverage.** FF16, K93, TF24, TF24f — and future strategies — get exact
  reverse-mode trait gradients of the SCM's emergent outputs (census LAI/biomass/
  basal-area, R0/offspring), with memory bounded to a useful patch life.
- **The invariant that protects it (the scarce resource):** *hand-written-adjoint
  correctness*. Every hand reverse rule is a silent gradient-bug site — value-exact,
  passes every double test, wrong only in the gradient. **The whole system has
  exactly TWO hand adjoints — the `separable_field` transpose and the
  `register_implicit` IFT — each self-checked by the dot-product oracle
  `⟨Jv,u⟩=⟨v,Jᵀu⟩`. Zero in strategies.** (design.md §1.)
- **Only `double` crosses the R boundary.** The tape is anchored on the C++
  Solver; R never holds an active type.

**Status in one line:** FF16 + K93 gradients done and FD-verified, zero tape code
— the proof the target shape exists. TF24/TF24f compile and reproduce the double
value, but their gradient still runs through an accidental hand-written seam.
**v3 = bring TF24 onto the same primitives FF16/K93 already use.**

---

## 1. The odelia primitive set (all BUILT; the model calls them as plain functions)
The engine is ~6 primitives. FF16/K93 use them with no tape awareness; TF24 must.

- **`separable_field<S,R>`** (`odelia/separable_field.hpp`) — a one-sided coupling
  field from a rank-R separable kernel `κ(z,x)=Σ_p a_p(z)·b_p(x)`. R descending
  suffix scans `B_p(z)=Σ_{x_j≥z} b_p(x_j)m_j` give `A(z)=Σ a_p B_p` and the exact
  moving-query slope `∂A/∂z=Σ a_p′ B_p`. Its reverse is the *one* hand transpose,
  dot-product self-checked. Model supplies `a_p(z)`, `b_p(x)`, and `κ_direct` for
  the init-time `Σ a_p b_p == κ` check.
- **`mass_transport`** (`odelia/mass_transport.hpp`) — the log-mass chart. Carry
  `λ_i = ℓ_i + log Δx_i`; `dλ/dt = −loss`. The compression `C=∂ₓg` **cancels
  identically and is never formed**; `λ` is monotone (no overflow). `cohort_spacing`
  is the one neighbour-difference operator; density is the read-side view
  `exp(λ)/Δx`. `log_{mass,density}_from_{density,mass}` are the inverse maps.
- **`implicit_value<S>(y*, F, expect=any)`** (`odelia/implicit_node.hpp`) — a value
  `y*` solved OFF the tape (root/optimum), made differentiable by the IFT
  `dy*/dp = −(∂F/∂p)/(∂F/∂y)`. `F(S y)` reads the active parameters from scope (no
  marshalled input vector); `∂F/∂y` is a double central difference at `y*`; the
  `S(y*)−corr+to_passive(corr)` idiom is the value-grafting move worth the name
  `graft_value`, and it composes across reverse/forward/nested modes. The optional
  `expect` (`denom_sign::positive|negative|any`) asserts invertibility — at a fold
  `∂F/∂y→0` this node divides by ≈0 (the b1 blow-up), so declaring the sign makes it
  a loud stop instead of a silent garbage gradient. **This is the single IFT
  primitive (decision 2026-07-24).** TF24 uses it for every leaf node (ci, ψ_stem,
  p\* interior, p\* bound). The former `register_implicit` (explicit-vector +
  forward-mode + `supplied_derivative` injection) had **zero production callers** and
  was **deleted**; its `sign(∂F/∂y)` guard — the one feature worth keeping — was
  **ported** here as `expect`. This was *not* a merge: the two mechanisms differed,
  so a merged function would only relocate the switch. Its example/test now exercise
  `implicit_value` across double/forward/reverse plus the guard.
- **`incomplete_gamma<S>(a,x)`** (`odelia/incomplete_gamma.hpp`) — the lower
  incomplete gamma via convergent series; the exact `S` closed form of the Weibull
  hydraulic integral `∫exp(−(|ψ|/b)^c)` = `(b/c)·γ(1/c,(m/b)^c)`, with elementary
  `∂/∂x` and series `∂/∂s`. Replaces every leaf/soil hydraulic spline read.
- **`decide` / `diagnostic` / `smooth_positive` / `is_finite`** (`odelia/decide.hpp`,
  `ode_util.hpp`) — the value firewall. `decide(pred)` records a value-dependent
  branch on the double pass and replays it frozen; `diagnostic(x)` is a dead
  (off-tape) read; `smooth_positive` is a C∞ `max(0,·)` with a declared radius.
- **`Solver` + `compute_jacobian`/`compute_gradient`/`compute_jvp`** (`odelia/
  gradient.hpp`, `ode_solver.hpp`) — the driver. `compute_jvp` is the tapeless
  forward dual; together with the reverse driver it is the FD-free dot-product
  oracle. The functional is any pure reduction of the replayed state.

**Build/link contract (ARCHITECTURE.md):** the XAD `Tape` runtime is compiled
**once** in odelia (`extern template` + `src/Tape.cpp`), one `active_tape_` per
process; consumers link it via the global `.onLoad` + a real NAMESPACE import
(macOS/Linux) or `src/Makevars.win` (Windows). v3 adds no new instantiated scalar
type (it uses the already-instantiated `xad::adj<double>::active_type`), so it does
**not** touch this contract. Do not make `Tape` header-only or change the
instantiation set.

---

## 2. The AD workflow (AUTODIFF.md)
- **Two orthogonal axes.** *Replay* — what adaptive structure the System records on
  a double pass and replays frozen on the active pass (L1 step schedule, L2 node
  positions, L3 background values). *Functional* — what scalar the run reduces to.
  Independent.
- **Record → replay.** Run adaptively once in `double` (discover + record L1/L2/L3);
  on the active pass, replay pinned on the recorded grid so no adaptive branching
  hits the tape; one reverse sweep. `recorded_steps()` is the **single** source of
  the replay grid.
- **The System contract (to be differentiable):** `value_type=S`; `rebind`/
  `rebind_from` (copy config *values only* onto S2); `ad_parameters()`/
  `ad_initial_state()` (ordered handles the driver seeds). Plus, for adaptive
  backgrounds, the `Replayable` hooks (`record_stage`/`record_ode_step`/
  `replay_step`/`has_recorded_field`).
- **Resident vs mutant = data-presence, not a mode.** L3 empty ⇒ recompute the
  background active (self-shading feedback flows). L3 populated ⇒ read frozen
  double (derivative zero by construction). Residents first; mutant/invasion (L3)
  deferred.
- **The reset-timing / grounding rule (load-bearing, bites TF24 — §4.4):** the
  driver seeds params *then* calls `reset()`. **Any parameter-derived precompute
  must be re-derived in `reset()` (or `prepare_strategy`), not at construction**,
  or its derivative is zero on the tape and every channel through it is silently
  severed. Same failure shape as populating L3.

---

## 3. The SCM and its two engine-owned couplings
The runnable is `SCM<T,E>`: cohorts (`Node`s) introduced on a schedule, integrated
as characteristics of the size-density PDE; the state grows mid-run (`resize()`),
and a newborn's IC reads the current active stand (`density = birth·pr_estab/g`).
The census functional is the mass-weighted population reduction
`Σ_i n_i·ψ(state_i)`. Two couplings are engine-owned, identical across strategies:

**3.1 Light field + `dg/dh` (deepening-6).** A cohort of size `x` shades query
height `z` by `κ(z,x)=m(x)·Q(z/x)`, `Q(u)=(1−u^η)²`, `m(x)=(π/4)x²` (K93) or
`area_leaf(x)` (FF16/TF24). Expand `Q` → **rank-3 separable**; `L(z)=Σ_p a_p(z)B_p(z)`
and `∂L/∂z=Σ_p a_p′(z)B_p(z)` are exact scan reads; `E(z)=exp(−k_I·L)` is the
openness. The **C¹ double-diagonal zero** `κ(x,x)=κ_z(x,x)=0` makes `∂L/∂z`
continuous as the query passes a cohort height — no diagonal special-casing (near-
diagonal catastrophic cancellation is caught by an optional direct-band `δ`). The
density-transport term `∂ₓg = ∂g/∂h|_E + ∂g/∂E·(∂L/∂z)·(dE/dL)` is then all
closed-form/scan — **but it is not fed to the rate at all**: the mass chart carries
it via `Δx`, so `dg/dh` needs **zero per-strategy AD**. **TF24 reads the shared
field** (`get_environment_at_height`) → its light derivative rides the scan for
free; TF24's MeanLight double-integration is an accidental cleanup, not a gap.

**3.2 Density transport / the mass chart (deepening-6, transport oracle).** Transport
`λ=ℓ+logΔx`; `dλ/dt=−loss`; `∂ₓg` cancels identically. **Rule: use the SAME `Δx`
(cohort_spacing) in transport, in the density view, and in every Δx-weighted
reduction** — the cancellation holds in the parameter-derivative only if the two
discretisations are literally one operator. **Rule: a rate defined as a numerical
derivative must be computed from active (taped) quantities — any private numeric
probe of an active field severs the tape** (this was the old `growth_rate_gradient`
bug). Insertion needs one model decision: a newborn gets a **mass** `m₀ = influx
density × cell width`, not an `ℓ`. **TF24 must declare `using geometric_transport`**
(one marker, like FF16/K93) or its census gradient drops the density-transport
channel.

---

## 4. The leaf — the coupled inner system (the part not to oversimplify)
TF24's growth reads a leaf whose operating point is a **3-deep nested double solve**
(`leaf_model.cpp`, 1490 lines, entirely `double`): outer golden-section max of
profit `W(p)=assim−cost` over root-collar potential `p` → mid transpiration
inversion `ψ_stem` → inner stomatal `ci` root. The gradient must thread this
without templating the solver.

**The chosen design (p2c candidate B), kept true by structure.** *The leaf solver
runs in `double`; `S` is carried only by the closed-form output map and by each
solved root registered as an IFT node.* Enforced because `util::golden_section_max`
/ `util::uniroot_smooth` have **double-only signatures** — an active scalar cannot
enter the iteration; taping it is inexpressible. **Consequence: no OOM.** The solver
is never recorded; only the output map + injected IFT edges touch the tape. (The
alternatives fail: templating the whole leaf puts the fold branch-switch on the
tape *and* records a huge per-solve tape; the shipped local-tape seam records the
assembly needlessly — candidate A's cost.)

The whole tape-aware solve surface is **two scalar IFTs** (N_ci, N_p\*) — everything
else is closed-form / Leibniz / reduction.

**4.1 N_ci — the stomatal root (deepening-1).** Residual `A(ci)·umol_to_mol −
gc(ψ_stem,q)(ca−ci)·inv_atm = 0`, denominator `A′·umol_to_mol + gc·inv_atm > 0`
(sign-definite). `register_implicit`. Wraps `psi_stem_to_ci`.

**4.2 N_ψstem — transpiration inversion (deepening-1).** *Not* an optimum: a
closed-form spline composition `ψ_stem = P(E_up(−q)/k_max + S(q))`; the inverse
`psi_from_transpiration` is a scalar `implicit_value` root (denominator
`k_max·exp(−(ψ_stem/b)^c) > 0`, sign-definite and regular — an inversion, not a
fold; annotated leaf_model.h:266). The soil-layer-crossing kink is a Leibniz
breakpoint. **Witnessed standalone (2026-07-24):** `weibull_leaf`'s
`weibull_leaf_stem_demo` restores this node between the collar optimum and the `ci`
root (the full nest `p → ψ_stem → ci`); `d(ψ_stem)/dθ`, `dp*`, and `dprofit` all
FD-match across the four traits (reld ≤5e-5).

**4.3 N_p\* — the collar optimum, the one genuinely hard piece.** `p*` maximises
`W(p)`. **The envelope asymmetry (do not simplify away):** at an interior optimum
`∂W/∂p=0`, so *profit* is insensitive to `dp*/dσ` — **but transpiration, ci,
ψ_stem, and per-layer uptake are non-stationary in `p`**, so they need `dp*/dσ`
even at a perfect optimum. Freezing `p*` inside them drops an O(1) term. So `dp*/dσ`
must be computed correctly. Three intrinsic regimes (parametric optimisation;
oracle Q3):
- **Interior-stationary:** `dp*/dσ = −P_pσ/P_pp`.
- **Bound/fold** (`p*` pinned at `bound_b` where the stem hits ψ_crit): a
  **branch-death** condition, `dp*/dσ = −F_σ/F_p`.
- **Tracked** (TF24f): `p` is an ODE state, evaluated off the optimum.

**Proven standalone; the denominator needs no help (2026-07-24).** A plant-free
leaf harness (odelia example `weibull_leaf`, §4.6) certified all three regimes vs
a re-optimising Gate-0 FD. Finding that changes the plan: the interior node's
denominator `P_pp` computed by `implicit_value`'s **own nested central difference
is accurate to <0.1%** at every interior operating point (trait *and* per-soil-layer
channels). A once-floated "supply `P_pp` from analytic `dprofit_droot_collar_psi`"
overload was built, shown to give an identical answer, and **deleted** (unneeded
name). The "~14% too large" that motivated it was a **near-fold point misclassified
as interior** (`∂W/∂p ≠ 0` there) — where the interior formula itself is wrong and
the analytic denominator does *not* fix it either (both give the same ~1.9× miss).
The cure for the dry region is the **regime detector switching to the bound node**,
not a better denominator. Bound-regime soil/trait channels verify to ≤1e-7 (traits)
and exact (soil layers, no profit central-difference).

**The precise node (p2c refinement 1):** at the fold `dF/dci → 0`, so a naïve
`implicit_value` on the ci-residual **divides by ≈0 — this is the b1 blow-up.** The
correct N_p\* is `implicit_value` on the **branch-death condition `g(p*)=∂F/∂ci=0`**,
whose denominator `dg/dp* ≈ −1.0004` is **regular**; interior uses the stationarity
IFT. The regime is selected structurally — whether the double solve returns `p*`
interior or at `bound_b` (equivalently, the oracle's read-the-branch-flag-at-the-
bracket-ends). **This regime detector is "the one genuinely new concept" the design
admits.**

**Doctrine B (oracle inner-argmax — governs verification, do not relitigate):** the
golden section returns a **staircase** `p̂(σ)=A+γ_ω(B−A)` — affine within a
comparison cell (slope carries *no* profit info), jumps at cell boundaries (where
the optimum-tracking lives). So differentiate the **ideal converged optimum**, not
the solver path. `register_implicit` on the branch-selected residual at the loose
`p̂` gives that ideal derivative with a **documented O(10τ) value offset** — the
standard adjoint posture. **Do not chase the AD/FD ≈ 0.8×/1.6× ratio; it is a
reference artifact and must not close.** The correctness anchor is a **tight-inner-τ
frozen-schedule FD** (or a wide-δ multi-cell secant) — never a loose-τ swept
plateau (that measures the within-cell artifact).

**The optional Newton polish (oracle Q2), which is *more* than a gradient fix:**
keep bracketing for global localisation + branch detection, then 3–4 safeguarded
Newton steps on the active condition using the closed-form `Leaf::
dprofit_droot_collar_psi` (**already present, unused**), to `|p̂−p*|~1e-12`. Cost
≈9–13 obj-evals vs ≈16. This (a) makes value and derivative describe one object,
(b) collapses the loose-GSS staircase ripple that drives the forward controller's
rejection storm and non-monotone `J(τ)`, and (c) **can retire the regime detector
itself** (p2c kill condition: if the ci solve is Newton-reformulated so `p*` is a
genuine interior optimum). It **moves the value O(τ)**, so it is a flagged
forward-quality upgrade — candidate next default — **not required** for a correct
gradient. Minimum for a correct gradient = branch-flag selection + fold-IFT,
forward bit-identical.

**4.4 The hydraulic transport — why `incomplete_gamma` is MANDATORY.** TF24's
parameter-derived precompute lives in the **double splines** (`set_physiology`:
`transpiration_from_psi`, `root_vuln_integral_from_psi`, …), which the commitment
keeps `double`, so `reset()` cannot re-derive them in `S`. Therefore any seeded
**hydraulic** param reaching the operating point *through a spline* — `root_b`/
`root_c` (vulnerability), `b`/`c`/`K_s` (transpiration) — is **silently severed**
(the reset-timing rule, §2) unless re-expressed analytically in `S`.
`incomplete_gamma` is that re-expression (already at leaf_model.h:158). The double
splines survive as the value-path fast lookup; the active path never reads them for
a seeded-param derivative. Not a cleanup — a prerequisite for the hydraulic-param
channel.

**Scoped precisely by the standalone proof (2026-07-24).** The re-expression is
*already live* for the stem channel: `leaf_output::cumulative_vuln<S>` and
`transpiration<S>` are S-templated on `b/c`, and the example verifies the
`incomplete_gamma` value, its Leibniz `d/dx`, and — the one channel no tape library
supplies — the **shape `d/dc` (series)** to machine precision (reld ~1e-10). The
**only** remaining severance is one signature: `leaf_output::soil_uptake` takes
`root_b/root_c` as **`double`**, so `d(E_up)/d(root_c)` is structurally `0` today.
Widening it to `S root_b/root_c` (identical body, same `incomplete_gamma`) recovers
the exact gradient. So the "MANDATORY re-expression" reduces, in practice, to a
signature widening plus passing the active `p.root_b/p.root_c` in `assemble_leaf_from`.

**4.5 Crown quadrature (deepening-2).** MeanLight/CrownCentre = one leaf solve at a
scan-based reduction; DeepCrown = one solve per quadrature node. Both are **Kind-C
taped reductions over fixed double bounds** (the integrand `q(z/H)·L(z)` is C¹ by
the double-zero) — no breakpoints. The decomposed nodes remove the current
`util::stop("deep-crown not implemented")` (it becomes a reduction of node
evaluations).

**4.6 Standalone concept-proof (vendored; run before the plant wiring).** All of the
above was verified *off the SCM* before touching plant, on a real leaf and on a
plant-free miniature:
- **plant-linked Gate-0 certs** (scratchpad; interior/bound `p*` nodes × trait +
  per-soil-layer channels; the full `assemble_leaf_from` chain with the envelope
  asymmetry) — every channel matches a re-optimising FD; layer-0 and profit to
  machine precision, the envelope-asymmetry consumption channel to ~5e-4.
- **`odelia` example `weibull_leaf`** (`inst/examples/weibull_leaf_interface.cpp`,
  `test-example-weibull-leaf.R`) — a self-contained, plant-free leaf with the *same
  primitive composition*, checked AD-vs-FD in odelia's own CI. It now witnesses **all
  three hard cases** the composition must survive (26 assertions):
  - **interior optimum** (`weibull_leaf_demo`) — `incomplete_gamma` hydraulics + nested
    `ci` `implicit_value` + `p*` `implicit_value` on the stationarity residual + the
    envelope asymmetry (`dW/dθ` direct-only, `d(E_up)/dθ` carries `dp*`);
  - **bound/fold** (`weibull_leaf_bound_demo`) — `p*` pinned at a hydraulic bound
    `p_crit` solved by a **branch-death `implicit_value`** (residual `cond(p)−k_crit`,
    regular denominator, §4.3). Because `dW/dp ≠ 0` at the bound, the profit gradient
    *itself* carries `dp*/dθ` — the case the interior demo cannot show, matched to FD
    on every channel;
  - **two-layer soil feedback** (`weibull_leaf_soil_demo`) — per-layer uptake with the
    layer-crossing breakpoint, the spatial `ψ_0/ψ_1` channels and per-layer sinks
    `dE_i/dθ` (the historic sign-error site, §5) FD-verified and sign-checked;
  - **full 3-deep nest** (`weibull_leaf_stem_demo`) — the transpiration inversion
    `ψ_stem` (§4.2) restored between the collar optimum and the `ci` root (`p → ψ_stem
    → ci`), a second `implicit_value` with a regular sign-definite denominator; the
    three outputs FD-match on all four traits;
  - **tape-memory bound** (`weibull_leaf_tape_profile`) — the load-bearing OOM proof:
    the `implicit_value` (solve-off-tape) path records a tape **exactly independent of
    the inner solver's iteration count** (~1.6k ops per leaf solve), while a naive
    on-tape solve grows with iterations, costs ~26× more per solve, and returns a
    *wrong* zero gradient (frozen-bracket record — the doctrine-B staircase). This is
    the direct confirmation that the design bounds the tape that status-quo TF24 blows
    up on.
  - **resistance-network uptake, bound-continuity, and value-graft** (added
    2026-07-24 after cross-referencing the toy against `assemble_leaf_from`) — the
    three surfaces the clean demos above under-witnessed but TF24 relies on:
    `weibull_leaf_uptake_network_demo` ports the *real* `leaf_output::soil_uptake`
    (3-branch Darcy flux, mean-conductivity `cumulative_vuln` integral split at 0,
    gravity head) with `root_b`/`root_c` **seeded** — certifying the exact channel
    the signature widening (§4.4) restores, `d(E_up)/d(root_c)` through the series;
    `weibull_leaf_bound_continuity_demo` pins p\* by the `E_up(p)=demand` continuity
    residual (TF24's `E_column` bound, regular denominator) rather than the toy's
    `cond−k_crit`; `weibull_leaf_graft_demo` witnesses the `anchor(leaf.profit_,·)`
    value-graft — raw assembled value equals the double truth at the correct anchor,
    diverges at a wrong one (the guard discriminates), derivative survives the swap.
    All FD-match. So the wiring's three "re-certify, don't assume" Gate-0 checks are
    now proven standalone; the composition is *identical* to `assemble_leaf_from`.
  **Takeaways that shaped §4.1–4.4:** no new odelia primitive is required, no
  denominator overload; the whole TF24 re-expression reduces to one `soil_uptake`
  signature widening + routing the active hydraulic params, and every inner solve
  (ci, ψ_stem, p\* interior, p\* bound) is an `implicit_value` node, not new
  machinery. **What the example still does NOT witness** (so the plant wiring must
  cover it directly): the SCM-level tape-over-time interaction — `geometric_transport`,
  the census reduction, and the soil sub-cycle adjoint over the *growing* state. The
  per-leaf tape is proven bounded; how those bounded leaf tapes accumulate across
  cohort-steps × layers × the resize path is the one memory question the static leaf
  cannot answer, and is deferred (treated separately per the plan).

---

## 5. The soil coupling — a two-way feedback loop (deepening-3)
Bidirectional inside the ODE: soil state `θ_i → ψ_soil[i]=a_ψ(θ/θ_sat)^{−n}`
(closed form, stiff as a layer dries) → the leaf reads `ψ_soil`, builds per-layer
uptake `E_i` and `E_up=ΣE_i` → `E_i` is the soil sink `dθ_i/dt=(in−K(θ_i)−E_i)/dz`
→ next step's `θ`. **The adjoint of a feedback loop is a feedback loop** — this is
the dry-end-hypersensitive channel (κ≈10, 50–291× amplification) where a sign
error became the 1e14 blow-up.

`E_i` is an **antiderivative difference**: mean root conductivity
`(G(a)−G(b))/(a−b)` with `G(m)=∫₀^m exp(−(s/b)^c)ds` = an `incomplete_gamma`. Its
partials are **exact Leibniz endpoint terms** `dG/d(endpoint)=f_r(endpoint)` — no
FD, no hand IFT. The layer-crossing (`P_x_r` passes `ψ_soil[i]`) is a **breakpoint
node** (exact Leibniz jump). So `dsoil_consumption_dpsi_collar_perlayer`, the
per-layer FD partials, and `soil_consumption_active_` all delete; the water-limited
feedback differentiates structurally. Soil is **active integrated state** (its
env carries `ode_size>0`), the multirate sub-cycle on the forward-only track; its
adjoint rides tape-as-run.

**Witnessed standalone (2026-07-24).** The soil sub-cycle adjoint cannot be tested
without a sink — the loop has no dynamics until a leaf reads `ψ_soil` — so it is
witnessed *coupled to the toy leaf*, off the SCM: the odelia example `soil_leaf`
(`inst/examples/soil_leaf_interface.cpp`, `test-ad-soil-leaf.R`) integrates a
per-layer soil-water ODE whose potential drives the leaf's `incomplete_gamma`
uptake, which is the soil sink (the closed feedback loop), with a `ci`
`implicit_value` node **inside** `ode_rates` and a consumer introduced mid-run (the
growing tape). Reverse `d(final biomass)/d(kmax, c)` matches a re-integrating FD to
<1e-9 (the shape `c` flows entirely through the feedback), the active value
reproduces the double run bit-for-bit, and the tape stays a few MB. So the
**feedback-loop adjoint, node-in-rates, and resize path are correct together**
before the plant wiring; what `soil_leaf` omits is the light field + density
transport + census layered on at full SCM scale (§9).

---

## 6. TF24f — tracked collar, same object (deepening-5)
TF24f appends `q` as a slow ODE state `dq/dt = k·G(q)` (`G=dW/dq`, the **same
reduced gradient** as N_p\*). At the demographic steady state `k·G=0 ⇒ G=0 ⇒ q=q*`
— the profile is identical to TF24; the difference is a **finite relaxation
eigenvalue `k·(dG/dq)`** (stable, since `dG/dq<0`) that changes `λ` and `dλ/dθ`.
**One object, three uses:** base TF24 roots `G` (N_p\*), TF24f integrates `k·G`, the
fixed point pins `q` by `G=0`. No parallel machinery.

---

## 7. Discontinuities — honesty, not smoothing (deepening-2/4)
- **Leaf shut-down early-exit** (soil drier than ψ_crit, etc.): profit **jumps ≈1.46**
  in one step (Gate-0 measured) — a **true hydraulic-failure discontinuity**, NOT a
  kink. For the transient gradient at a fixed operating point, `decide()` selects the
  smooth side (one-sided derivative exact); the boundary is measure-zero. **No
  Leibniz/breakpoint term applies** (there is no finite jump-slope) — treating it as
  a continuous kink would be a silent bug. At a fixed point sitting on such a cliff,
  `dλ/dθ` is genuinely undefined — an **honesty-refuse point**, monitored, not
  averaged through.
- **Net-production sign branch** `if(net>0){grow}else{zero}` — a genuine kink at the
  carbon compensation point; the subgradient is documented. (FF16 uses
  `smooth_positive`; TF24's is the hard gate.)
- **`height_max = max` over cohorts** (light-spline domain) — a `decide()` replayed
  argmax.

---

## 8. Correctness & verification (do not trust the wrong reference)
- **Gate-0, not census FD.** Verify at a single leaf/cohort with a clean δ-swept FD.
  `compute_competition(0)` census FD is %-noisy and has repeatedly misled.
- **`⟨Jv,u⟩=⟨v,Jᵀu⟩` is self-consistency, not correctness** — forward and reverse can
  traverse the same lossy representation and agree while both wrong.
- **The tight-τ frozen-schedule anchor** is the correctness bar for the leaf p\*
  (doctrine B, §4.3). Do not chase the loose-FD ratio.
- **Each IFT node ships its own IFT-vs-FD self-check at Gate-0** (N_ci vs a central
  FD of `psi_stem_to_ci`; N_p\* vs a central FD of the golden-section optimum).

---

## 9. What is done · the TF24 gap · deferred
- **Done, FD-verified:** FF16 + K93 full-SCM resident gradients (census + R0), zero
  tape code.
- **Done, value-only:** TF24/TF24f compile + reproduce the double value; gradient runs
  through the seam (not certified).
- **Concept proven standalone (2026-07-24, §4.3/§4.6):** every leaf node
  (interior/bound `p*`, `ci`, `ψ_stem`), the `incomplete_gamma` hydraulic channels,
  and the envelope asymmetry are FD-verified off the SCM. The vendored `weibull_leaf`
  odelia example now durably witnesses the **interior, bound/fold, two-layer soil
  feedback, and full 3-deep nest (with the `ψ_stem` inversion)** cases (no new
  primitive, no denominator overload), *and* the **tape-memory bound** that is the
  crux: the solve-off-tape node path records a tape independent of solver iterations
  (~1.6k ops/solve) where a naive on-tape solve is ~26× larger per solve and grows
  with iterations — so the design provably bounds the tape that status-quo TF24 blows
  up on. **Primitive decision (§1): `implicit_value` for every node; no merge;
  `register_implicit` is a deletion candidate.** **Mechanical for the leaf's
  inner-solve gradient** (steps 1–4). The soil sub-cycle adjoint, a leaf node living
  inside `ode_rates`, and the growing-tape/resize path are now **witnessed together
  standalone** by the `soil_leaf` odelia example (§5) — FD-matched, value-exact, tape
  bounded. **The one remaining thing no durable test yet answers** — the residual
  wiring risk — is the *full* SCM composition at scale: the light field + density
  transport (`geometric_transport`) + census reduction layered on top of the soil
  feedback simultaneously, over many cohort-steps. Each of those is FF16/K93-proven
  or `soil_leaf`-proven *separately*; their simultaneous interaction on TF24 is what
  the plant wiring itself exercises. Not a design gap — an integration checkpoint.
- **The gap (v3 Phase 1 — finish p2c candidate B for TF24):**
  1. **Widen `leaf_output::soil_uptake`** to take `S root_b/root_c` (identical body;
     `cumulative_vuln`/`transpiration` are already S-templated) and pass the active
     `p.root_b/p.root_c` in `assemble_leaf_from`. This *is* the "`incomplete_gamma`
     re-expression" in practice (§4.4) — the kernels already use it; only the
     signature severs.
  2. **N_ci** (§4.1) and **N_ψstem-inverse** (§4.2) as `register_implicit`/
     `implicit_value` nodes (proven in the certs).
  3. **N_p\*** on stock `implicit_value`: interior = stationarity residual
     (nested-FD denominator, proven adequate); bound = the regime-detected
     continuity/branch-death residual with a regular denominator (§4.3); reuse `G(q)`
     for TF24f.
  4. Per-layer uptake `E_i` as the `incomplete_gamma` antiderivative-difference with
     Leibniz partials + layer-crossing breakpoints (§5).
  5. Declare `geometric_transport` for TF24 (§3.2).
  6. **Delete** the seam: local tape, `supplied_derivative` marshalling, `chain_sign`,
     whole-leaf snapshot, `soil_consumption_active_`, the nested-FD `p*`,
     `dprofit_droot_collar_psi` (falls out of the nodes — but keep it as the double
     value-path/regime helper if convenient),
     `dsoil_consumption_dpsi_collar_perlayer`.
  - **Memory is by construction** (§4): the solver is never recorded; the tape holds
    the closed-form output map + a handful of injected edges + the `incomplete_gamma`
    series — FF16-like, checkpointable. The only figure worth one confirming
    measurement post-decomposition is the `incomplete_gamma` series × soil layers ×
    cohort-steps.
  - **Optional Phase 1b:** the Newton polish (§4.3) — forward-quality flag that also
    retires the regime detector.
- **Deferred (real, out of scope for the resident census gradient):** mutant/invasion
  (L3 frozen field); IC gradients; the fixed-point / Eulerian-BVP layer + eigenvalue
  module for regnans selection gradients (where the honesty-refuse points, §7, live).
- **Consolidations:** ✅ `register_implicit` **deleted**, its `sign(∂F/∂y)` guard
  **ported** onto `implicit_value` as the optional `expect` argument (§1) — one IFT
  primitive now. Remaining ride-alongs: name `graft_value`; surface the dot-product
  oracle at the R boundary; move the `rebind_from` completeness guard into odelia.

---

## 10. Canonical doc set
Read this doc for the whole picture. Derivations, if needed: `design.md`
(what/why), `deepenings/deepening-{1,3,6,2-4-5}` (per-component math),
`oracle/oracle-response-{inner-argmax-adjoint,transport-compression}` (the
verification doctrine and the mass chart), `p2c-leaf-adjoint-design.md` (the leaf
system-design), `odelia/AUTODIFF.md` + `ARCHITECTURE.md` (the AD workflow + the
link contract), `build-plan.md` (the test-cited status matrix). Everything else is
in `archive/`.
