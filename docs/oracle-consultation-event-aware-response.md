# Oracle response — build the localizer and the classifier together; the same instrument decides removable-vs-intrinsic and then removes what's removable

*Response to `oracle-consultation-event-aware.md`. Recorded verbatim (lightly reformatted). Hypotheses
+ a build order with its own falsifiable tests — §7 of the consult guide applies: run the cheap
classifier/Q3 tests before the build.*

## Reframe — the residual's geography is a clue

The residual clusters in **quiet, low-forcing intervals near `u_min`** — exactly where (i) the clamp
and near-singular self-loss live, (ii) the threshold boundary in `(ξ,u)` **sweeps as `u` drifts, so
heavy-member crossings happen serially** — many scattered small-step episodes from *one moving
surface* — and (iii) argmax solutions ride their bounds. All three a-priori suspects predict the
observed geography. Honest prior: the residual is mostly the state-dependent class **plus possibly
un-hypothesized surfaces of the same kind — branches *inside* the member solves** (bracketing-search
regime flips, min/max selections, feasibility switches inside `P`), and only a minority is genuine
smooth fast structure. But that is a prior; the design makes it a measurement.

## Q2 (gates everything) — the shadow-monitor run, then arc-length attribution

**(a) Localisation is a logging problem before a root-finding problem.** One instrumented forward pass
per bank sequence with a *shadow monitor*: at every accepted step log all cheap event functions — per
heavy member `g_j = threshold(ξ_j,u)` (0 solves; restrict to top-h by `ρ_j·|c_j|` + a "rising"
watchlist since ρ evolves), clamp margins `u_ℓ − u_min`, argmax-bound margins (byproducts of solves
already done), forcing-kink proximity — **and a branch signature from inside each member solve** (which
bracket/regime/min-branch it landed in — an integer vector, free). Sign changes and signature flips
between consecutive accepted steps time-stamp every crossing of every hypothesized *and*
un-hypothesized surface, to within a step, zero extra solves.

**(b) The attribution test — removable vs intrinsic.** For each small-step episode, episodes
bracketing a sign change / signature flip are **event-attributable**; episodes with no flip in the
watch set are **candidate-intrinsic**. Then the discriminator (cheap — episodes are isolated):
re-integrate candidate-intrinsic windows with (i) 10× tighter tolerance and (ii) a **smooth-arc test**:
fit dense output of `u` and heavy `c_j` across the episode with one high-order polynomial.
**Intrinsic fast structure refines like a smooth feature (error ∝ h^p, poly fits); an undetected kink
refines like a discontinuity (error stuck at O(h·jump), residual concentrated at a point).** That
point is a new event surface — find its mechanism in the branch signatures. This is the **go/no-go**:
if candidate-intrinsic dominates after signature-augmented attribution (Oracle bets against, given the
geography), event handling buys only the rejection overhead (~30%, still a cheap subset worth doing);
if event-attributable dominates, proceed to the full construction.

## Q1 — construction: step-*to*-event, dense-output location, hot restart + a "proximity governor"

Classical hybrid-systems discipline (Shampine–Thompson event location; Hairer–Nørsett–Wanner II.6;
CVODES/IDAS rootfinding) with three problem-specific adaptations:

- **Core loop.** Take a normal adaptive step. **Accept first, then check events** on the embedded
  dense output (endpoints + 2–3 interior samples, ≈ free). If a sign change is bracketed: locate the
  root on dense output (Brent on the interpolant — polynomial evals, 0 member solves), truncate the
  step at `t*`, take the state from dense output at `t*`, apply the transition (branch switch / clamp
  engage / pin), and **restart with full stage recomputation — never reuse stages/FSAL across an
  event** (the naive order-killer). Each arc then sees a smooth RHS → design order everywhere; the
  only first-order contamination (integrating across a kink) never happens.
- **Proximity governor (drives the 30% toward zero).** Rejections come from the controller
  *discovering* a kink inside a trial step. Pre-empt: from logged margins and their drift rates `ġ_j`
  (free from dense output), bound time-to-nearest-event and cap the trial step at ~1.2× it, so the
  event lands *inside* a step where dense output brackets it. Converts rejection bisection (O(M)×5–15
  probes) into one dense-output root solve (0 solves). Forcing kinks: **clip trial steps to the known
  kink table — a five-line change worth shipping today**, removes the measured 4–31% share outright.
- **Watch-set economics.** Monitor the h heavyweights exactly; for the tail monitor the aggregate
  proxy (ξ-band within a margin of the threshold, ρ-weighted); let sub-tolerance crossings pass
  unlocated. Principled criterion: **an event is worth locating iff its RHS jump × step size exceeds
  the local error tolerance** — make the watch-set threshold exactly that, adaptively.
- **Adjoint.** Event times are active scalar-IFT nodes (transversality; graze → flag); the tape gets
  the Leibniz jump `(f⁺−f⁻)ᵀλ·t̄*` once the truncated-step length is active. Located time pass-1
  recorded / pass-2 polished; watch-set membership/decisions `decide()`-fenced. Net: **strictly
  better** — shorter tape, no rejected-work pollution, and event times restore the schedule
  sensitivity the frozen-schedule contract drops at kinks (round-5's largest caveat term).

## Q3 — the multi-block blow-up: three hypotheses, one afternoon

Do not assume it is the same disease.
- **H1 undetected-crossing integration:** an explicit step straddles a large-ρ crossing/clamp engage,
  takes a huge wrong increment near the singular self-loss, diverges. **Test:** rerun with shadow
  monitor + conservative proximity governor (cap only, no location); if the blow-up vanishes → H1.
- **H2 genuine coupled-mode instability:** several blocks sharing one `u` create feedback whose
  effective stiffness scales with block count; aggregate loop gain can cross the explicit stability
  boundary though each single-block run is accuracy-limited. **"Implicit refuted" was measured on
  single-block systems and does not automatically transfer.** **Test:** at the blow-up, estimate the
  dominant eigenvalue of the `L×L` effective `∂u̇/∂u` (FD through the full RHS at frozen x, a few
  O(M·#blocks) evals); if `h·|λ|` sits at the explicit boundary → H2, cure = a stiff treatment **of
  `u` alone along the shared-`u` axis** (the one legitimate, now-targeted return of the implicit idea).
- **H3 clamp interaction:** multiple blocks driving `u` into the clamp simultaneously → sliding mode
  the explicit method chatters on. Cure = pinned-mode (active-set) integration (Q4).
- **Cheap first cut, no new runs:** the step-attempt log around the failure — `h` collapsing smoothly
  → H2; `h` jumping after one anomalous accept → H1; clamp-margin sign oscillating → H3.

## Q4 — chattering: three switches, three answers

- **`u`-clamp:** a genuine unilateral constraint → **sliding-mode / active-set integration** (pin the
  component, integrate the reduced system, release on exact `u̇_ℓ^{free} > 0`), not hysteresis-as-hack
  (hysteresis only guards measure-zero graze). Pinned intervals: established zero-adjoint-through-
  projection.
- **interior `c`-threshold:** mollification is principled *if* the hard switch is a model
  idealization, and the leak is **budgetable**: mollified width `w` perturbs `J` by ≈ (band mass) ×
  (c-jump) × O(w); pick `w` so 10× that bound < gradient tol, **measure dJ/dw once**, document as a
  declared model change. If smoothing is forbidden: **event clustering** — > k light-member crossings
  per step handled as one aggregate located event (jumps sum; individual sub-tol times don't matter).
- **argmax bound:** take the **tracked-control variant** — measured-acceptable, smooth by
  construction, deletes the whole class incl. chattering; lag enters J at a budgeted level.
- **Priority:** tracked-p first (free removal); clamp active-set second (correctness near `u_min`,
  likely implicated in Q3/H3); threshold mollify-or-cluster third (sized by the shadow census).

## Q5 — ranking

**Load-bearing:** 0-solve event functions vs O(M) rejection probes (the whole economic case);
quiet-interval clustering (relocates residual onto the state class + near-`u_min` machinery); the ~30%
rejection fraction (a guaranteed, event-independent win via the governor — pays for the build alone);
skewed ρ (small watch set); insertions-already-handled (one class free). **Incidental / already
banked:** forcing-kink share (small, trivially removed); the 1e-8·T minimum (a symptom; the design
removes its cause); the exact residual split (the shadow run makes it a measurement). **Promoted by the
data:** the multi-block failure — the only *correctness* item, may reopen a targeted stiff treatment
along the shared-`u` axis.

## Q6 — still missing

Unchanged frontier behind the time-stepper: the **member mesh is refined for `x(t)` while `J` hangs on
`∫c·ρ`** (coupling-weighted refinement indicator + M-refinement certification of J — highest-leverage
accuracy work; the event machinery cleans the *time* axis precisely to expose the member axis as the
real one); and **J's conditioning** (10× amplification + 23% spread → barely an observable;
reformulation worth more than further numerics, a model-side call). **Addition:** the **branch
signatures inside the member solves** — the solves have been treated as atomic, but their internal
branches are candidate event surfaces of exactly the dominant class; the signature log is the first
instrument that can see them, and if the residual survives watch-set attribution, that is where it
hides.

## Build order (verbatim)

1. **Forcing-kink step clipping — today.**
2. **Shadow-monitor + signature logging run — the classifier, days.**
3. **Proximity governor — kills most of the 30%.**
4. **Dense-output location + restart** for the heavy-member threshold; **clamp active-set**; **tracked-p**
   replacing the argmax-bound class.
5. **The Q3 afternoon** on the multi-block failure before scaling multi-block runs.
6. **Back to the member mesh and J**, which the cleaned time axis will finally let you measure honestly.
