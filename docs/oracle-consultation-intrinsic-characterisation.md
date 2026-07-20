# The classifier ran, and it refutes the event program: a deep characterisation, no directed questions

A numerical-methods problem. No application context is given or needed. This **follows six prior
rounds** on the same initial-value problem; the settled structure is restated inline so this stands
alone. Last round you gave a build order whose **first measurement gate** (an instrumented
"shadow-monitor + branch-signature" run — your E1) was to decide whether the step-size collapse is
made of **removable isolated non-smoothnesses** or of **intrinsic fast structure**, with your stated
prior betting on *removable*. **We built exactly that instrument and ran it on the full bank. The
result is the opposite of the bet.** Below is not a defence of any candidate and not a set of directed
questions: it is the most complete, neutral characterisation of the system and its measured behaviour
we can give. Please **re-derive what is going on from the structure and the data**, rank the features
yourself, and reject our framing wherever the numbers warrant. We suspect we have been looking at this
through the wrong variable.

Per your own guidance to us: refutations of prior claims are stated bluntly, with numbers, and you are
invited to update.

---

## 1. The system (established across prior rounds; do not re-litigate)

Initial-value problem `y' = f(y,t;θ)`, `y ∈ ℝ^N`, on `[0,T]`, integrated by an **adaptive embedded
explicit RK** (Cash–Karp 4(5)) with a local-error controller; `10³–10⁵` accepted steps at a single
global step size. State splits into:

- a **large block `x ∈ ℝ^M`** (`M ≈ 50–800`, growing during the run as members are inserted on an
  adaptive schedule), each member `x_j` an independent low-dimensional sub-vector with an **ordered
  scalar member coordinate `ξ_j`** and a non-negative **weight `ρ_j`**;
- a **small block `u ∈ ℝ^L`, `L = 5`**, an ordered chain of scalar reservoirs.

Coupling:
```
p_j*     = argmax_p  P(p ; x_j, u, s(x))          fixed-iteration derivative-free bracketing search
ẋ_j      = g(x_j, u, s(x), p_j*)                                        j = 1..M
a_ℓ(x,u) = Σ_j ρ_j · c_ℓ(ξ_j, u, p_j*),   ℓ = 1..L          (channel 1: x→u, expensive, O(M))
u̇_ℓ      = b_ℓ(t) + T_ℓ(u) − a_ℓ(x,u)                                  (small-block balance)
s(x)     = cheap scalar aggregate of the whole large block             (channel 2: x→x, flat in M)
```

- **Channel 1 `a` (x→u):** a density-weighted quadrature `∫ c(ξ,u,p(ξ)) ρ(ξ) dξ`; each `c_ℓ(ξ_j,u,p_j*)`
  is a byproduct of the same per-member solve that yields `ẋ_j`, so `a` costs the full O(M) solve set,
  and re-evaluating `a` at a new `u` (x held) still re-runs the M solves.
- **Channel 2 `s(x)` (x→x):** all-to-all among members through one cheap scalar; carries no
  `u`-dependence; cost flat in M.
- **`b_ℓ(t)`** is an external forcing entering only reservoir `ℓ=1` (a piecewise-smooth scalar with
  known feature times); `T_ℓ(u)` is an ordered inter-reservoir transfer (reservoir `ℓ` loses to `ℓ+1`
  only; no back-transfer) plus a **near-singular self-loss** on each reservoir with exponent `q ≈ 16`
  (`loss_ℓ ∝ u_ℓ^{q}`), positivity-clamped at a floor `u_min`.
- **The inner control `p_j*` is an argmax**, deliberately solved by a **fixed-iteration golden-section
  bracketing search** (not Newton/Brent) so that `p_j*` is a smooth fixed-iteration function of its
  inputs (a reverse-mode tape differentiates through it). `∂P/∂p` is available exactly (IFT). The
  member solve internally selects among a small set of **feasibility branches** before the search:
  a switch-off exit (member becomes inert), a zero-flux exit, a **degenerate-bracket** exit
  (feasible interval `[a_j,b_j]` collapses to a point), and the normal full search.
- **The moving interior threshold.** `c_ℓ(ξ,u,·)` is smooth on one side of a boundary in `(ξ,u)` and
  **identically zero** on the other (the member "switches off" and draws nothing). The switch-off test
  is a **reduction over the reservoir components accessible to the member**: the member switches off
  only when a scalar `w(u) := max_ℓ (−m_ℓ(u_ℓ))` (the *least-extreme* accessible reservoir, mapped
  through a monotone `m_ℓ`) crosses a fixed constant `w_crit`. I.e. a member switches off only when
  **every** accessible reservoir is past the boundary; one benign reservoir keeps it on.
- **Downstream:** reverse-mode gradients (a tape over every RK stage) of a scalar functional `J`
  (a density-weighted reduction over the members, `J = Σ tw_j · φ(x_j)`) w.r.t. a small `θ`; the
  gradient must match a finite difference of the solver as run.

**Established quantitative facts (prior rounds, still standing):** `J` is ~**10× hypersensitive** to
coupling error, with **~23% spread** between independently converged schemes at large `M`; global
explicit RK reaches converged `J` at modest tolerance and cost and only fails ~3 decades past
`J`-convergence at a resolution (`h_min`) wall; **~27–35% of step *attempts* are rejected**
(rejection-bisection overhead); scattered minimum steps `~10⁻⁸..10⁻⁹ · T`; a fast/slow `(x,u)`
decomposition was retired last round (the frozen-`x` decomposition is ~24% wrong in `J` before any
approximation — the accuracy limit lives in advancing `x`, not `u`); member-reduction of channel 1 is
`<0.5%` on a prescribed set but `25–279%` on the evolved set (`ρ` is highly skewed and evolves).

---

## 2. The instrument we built (your E1 / build-order #2, verbatim)

A per-accepted-step monitor, off by default and **bit-identical when off** (verified: forward solution
unchanged to the last digit). At each accepted step it records, from state already computed for that
step (no extra member solves):

- **event-surface margins** — per reservoir `u_ℓ − u_min` (clamp), `u_sat − u_ℓ` (upper clamp), the
  self-loss ceiling margin, the external-forcing-excess margin; the **switch-off margin `w_crit − w(u)`**
  (the least-extreme accessible reservoir vs the threshold); and the **argmax feasible-interval width
  `b_j − a_j`**;
- **branch signatures** — an integer histogram over the member solve's feasibility branches
  (switch-off / zero-flux / degenerate-bracket / full-search), refreshed every RHS sweep, aggregated
  across members per step.

Attribution (run offline on the saved per-step data, so the logic is iterable without re-running the
expensive monitored sims): each accepted step is tagged **hard** if its step size is in the bottom
quartile or it had ≥1 rejection; a step is **event-adjacent** if any margin sits in the bottom decile
of its own distribution or any branch/clamp signature flips vs the neighbouring step (±1-step window).
Rejections (which share their start time with the accepted step that follows) are mapped onto that
step. Gate metric: **enrichment** `P(event-adjacent | hard)` vs `P(event-adjacent | easy)`, plus the
fraction of rejection attempts within ±1 step of any signature flip.

---

## 3. What we measured (the payload; several items refute prior claims)

Full bank: five long sequences, `10³–10⁵` steps each, converged tolerance, plus a purpose-built
extreme case (below). All runs **bit-identical with the monitor off**.

**(R1) The step-collapse does not co-locate with any event surface.** Across all sequences the
fraction of **rejection attempts** (the 27–35% overhead) within ±1 step of *any* branch/clamp
signature flip is **2–4% (median 2%)**. The hypothesised removable events are not where the collapse
is.

**(R2) The event surfaces barely fire.** The member-solve branch histogram is **≥ 99.7% the single
full-search branch** in every sequence. The switch-off branches fire on **< 0.5%** of member solves.
The **degenerate-bracket branch (the argmax hitting its bound) never fires — 0 occurrences** in any
sequence. The upper/lower reservoir clamps and the forcing-excess switch **never fire** (0). So the
three a-priori suspects from last round — serial threshold crossings, argmax rides its bound,
un-hypothesised internal-solve branches — are all near-empty.

**(R3) The switch-off threshold is nearly unreachable by construction.** Its margin `w_crit − w(u)`
never falls below **≈ 0.79** (in the most extreme case below; median closest across the bank ≈ 5.5, on
a scale where 0 is the switch). Mechanism: `w(u)` is the *least-extreme accessible reservoir*; in the
5-reservoir chain the terminal reservoir `u_L` stays permanently benign because its only sinks are
(i) the self-loss `∝ u_L^{q}` with `q≈16`, which **collapses as `u_L` relaxes toward benign** (the
loss rate vanishes long before `u_min`), and (ii) channel-1 draw `a_L`, which **ceases when `ρ`
collapses** (next item). So `u_L` asymptotes to a benign plateau, `w(u)` never reaches `w_crit`, and no
member switches off even under indefinitely sustained extreme forcing.

**(R4) A self-limiting feedback removes the stress before the event can fire.** We built an extreme
case: external forcing `b_1(t)` set to a moderate level for `~4/20` of the horizon, then **identically
zero for the remaining `~12/20`**. Even so: the terminal reservoir drains only to a benign plateau
(R3), while the **total member weight `Σρ_j` peaks early and then decays to ~0** — the large block
*empties itself* (members' `ρ_j → 0` and they exit) as the leading reservoirs deplete, via a slow
`x`-side balance unrelated to the switch. Because `Σρ_j → 0`, channel-1 draw `a → 0`, which *protects*
the terminal reservoir, which keeps the switch off. The configuration that would trigger the dominant
hypothesised event **dismantles itself first**. (Budget over that case: input flux `4.0`, self-loss
out the terminal reservoir `1.5` (38%), channel-1 draw `2.4` (60%); leading-reservoir potential
reaches `~5.3` (essentially `w_crit`) while the terminal reservoir holds `~0.37`.)

**(R5) The one variable that weakly predicts the collapse is continuous, not an event.** The strongest
correlate of `log(step size)` across sequences is the **argmax feasible-interval width `b_j − a_j`**
(Spearman `ρ ≈ +0.24 … +0.42`: narrower bracket → smaller step), with the reservoir-depletion margins
next (`ρ ≈ +0.4`, mutually collinear — they are all monotone in the same depletion). All correlations
are weak (`|ρ| ≤ 0.42`). The bracket **narrows continuously but never collapses to the degenerate
point** (R2: that branch never fires) — a continuous narrowing of the inner problem's feasible set, not
a discrete bound-hit. `n_reject` correlates with **no** margin (`|ρ| < 0.11`).

**(R6) Refutation of "track the control to delete the argmax class."** Last round proposed replacing
the argmax `p_j*` by a differential state `p` tracked as `ṗ = k·∂P/∂p` (gradient ascent toward the
optimum, "smooth by construction, deletes the whole class"). We built it. At the **shipped default gain
`k=1` and every larger gain we tried (`k = 1, 8, 64, 256`) it fails hard** on every non-trivial
sequence: during fast `u`-motion the tracked `p` leaves the feasible domain of the member solve and the
solve's internal bracketing gets a non-bracketing interval (no root) → abort. It **completes only at
`k → 0` (no tracking) or with the exact argmax.** The failure is **non-monotonic in the gain**, so it
is not simple lag that faster tracking cures: `k` sets the state's rate *across* steps, but the tracked
`p` is a slow ODE state evaluated against a *within-step* fast-moving `u`, and nothing constrains it to
the feasible set. Tracking the control, as posed, is not a free removal — it needs a feasibility
projection the argmax does implicitly.

**(R7) The verdict on the gate.** With the monitor's attribution: **candidate-intrinsic dominates.**
`P(event-adjacent | hard) ≈ P(event-adjacent | easy)` (enrichment lift `≈ 0.8–1.0`, i.e. **no
enrichment**; hard steps are, if anything, *less* event-adjacent). Your stated prior for this gate was
that event-attributable would dominate. **It does not.** The step-collapse is broadband: small steps
and rejections are spread through the quiet intervals with all event margins bounded away from zero and
no signature flips.

---

## 4. Structural features — any may be load-bearing or incidental; we do not know which

The two coupling channels (`a`: x→u, O(M), `u`-dependent; `s(x)`: x→x, cheap, `u`-independent); the
inner argmax `p_j*` (fixed-iteration for tape-smoothness; exact `∂P/∂p`; a small set of feasibility
branches, of which only the full-search branch is measurably exercised); the **argmax feasible-interval
`[a_j,b_j]` that narrows continuously toward but never reaches degeneracy** (the one weak step-size
predictor); the moving switch-off threshold that keys on the **least-extreme accessible reservoir** and
is therefore nearly unreachable while any reservoir stays benign; the terminal reservoir held benign by
a self-loss that **vanishes with depletion** (`q≈16`) and by channel-1 draw that **vanishes with `ρ`**;
the **self-limiting `x`-side feedback** that empties the large block (`Σρ_j → 0`) under sustained
forcing, removing the stress that would trigger the switch; the near-singular self-loss with exponent
`q≈16` and its positivity clamp (never engaged); the ordered one-way inter-reservoir transfer (no
back-transfer, no cross-reservoir equilibration); the external forcing `b_1(t)` piecewise-smooth with
known feature times entering only reservoir 1; the timescale separation `~10²–10³` between `u` (fast,
forced) and `x` (slow); the single global step size; the skewed evolving weight profile `ρ` (mass in a
few members; many `ρ_j → 0`); the member schedule placed to resolve `x(t)`, not `∫c·ρ`; the all-`M`
floor per RHS evaluation; the ~10× amplification of coupling error into `J` and the ~23% inter-scheme
spread; the reverse-mode tape whose cost tracks accepted steps; the argmax not an AD citizen (adjoint
via envelope-FD; no forward Jacobian of `f`); the fact that the collapse is broadband and continuous,
weakly tracking only the inner feasible-interval width and reservoir depletion; the ~27–35% rejection
fraction that co-locates with **nothing** we can log.

---

## 5. Facts an answer can rely on

- The monitor is bit-identical off; the attribution runs offline on saved per-step data, so any
  attribution logic you propose we can test in minutes without re-running the sims.
- Event surfaces fire on <0.5% of member solves; the degenerate-argmax and clamp surfaces fire **never**;
  rejections co-locate with signature flips at the **2%** level.
- The switch-off threshold is not reached even under indefinitely sustained extreme forcing, for the
  structural reason in R3/R4 (a benign terminal reservoir + a self-emptying large block).
- The exact-argmax solve is robust; the tracked-control surrogate is not (R6).
- `a(x,u)` is only obtainable via the M member solves; the `ẋ_j` require all M regardless of how `u` is
  advanced (a floor common to every scheme). No forward-mode Jacobian of `f` exists.
- `J` amplifies coupling error ~10×; approximate schemes must be judged in `J`-units.
- The member mesh is refined to resolve `x(t)`; `J` depends on `∫c·ρ`. A full-`M` evaluation of both
  channels is free at every macro-stage boundary.
- A documented, controlled change of discretisation (or of the functional) is acceptable if the forward
  solution and the reverse-mode gradient stay correct.

---

## 6. Refutations of specific prior-round claims (stated with numbers, per your guidance)

1. **"If candidate-intrinsic dominates, [I] bet against it, given the geography."** Measured:
   candidate-intrinsic dominates; enrichment lift ≈ 0.8–1.0 (no enrichment). *The bet loses.*
2. **"The threshold boundary sweeps as `u` drifts, so heavy-member crossings happen serially — many
   scattered small-step episodes from one moving surface."** Measured: the threshold is nearly
   unreachable (R3); switch-off branches fire <0.5%; the scattered small steps are **not** at threshold
   crossings.
3. **"Argmax solutions ride their bounds."** Measured: the degenerate-bracket branch fires **0 times**;
   the interval narrows continuously but never hits the bound.
4. **"Un-hypothesised surfaces — branches inside the member solves — are where the residual hides."**
   Measured: the branch histogram is ≥99.7% a single branch; there is no branch chatter to hide in.
5. **"Tracked-`p` first — free removal of the argmax class."** Measured: it fails at the default gain
   and all larger gains (R6); not free.
6. **Still-open from last round (not refuted, not yet tested):** the adjoint envelope-at-fixed-`p*`
   correctness concern (your E4 — the possibly-dropped `(∂c/∂p)(∂p*/∂u)` term). We have not run it yet.

---

## 7. The one question

Given the complete structure in §1 and §4 and the measured behaviour in §3 — **what is actually
setting the step size, and where (if anywhere) is the leverage?** The event program was predicated on a
removable-event geography that the instrument says is not there; the collapse is broadband and
continuous, tracking only weakly the inner feasible-interval width and reservoir depletion; the
dominant hypothesised event is unreachable by construction and self-limited by the large block; and the
one control-smoothing remedy is numerically infeasible as posed. Rank the features in §4 for us. Tell
us whether the residual is intrinsic fast structure any same-order method must resolve, or whether it
is an artefact of a representational choice we have not questioned (the fixed-iteration inner search and
its continuously-narrowing feasible interval; the member mesh refined for the wrong functional; the
single global step; the functional `J` itself, taken as given). If there is a cheap discriminating
measurement that would localise it, name it — we will run it before building anything.
