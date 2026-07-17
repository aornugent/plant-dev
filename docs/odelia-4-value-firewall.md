# odelia design #4 — the value() firewall + the AD-guard treatment (P1d)

Fourth component of the odelia design journey (`design.md` P1d). Under the system-design skill. This is
the **structural enforcement** the earlier three designs keep *asserting* ("no `xad::value` in the
model," "no mutable cache," "the kink manifest"). It also answers the standing question: survey **every**
AD guard the touchpoint catalog identified and improve its odelia treatment.

Grounded in odelia's current treatment — `to_passive` (a blunt value-strip) and `is_finite(double)` (a
**double-only** overload) — and the catalog's four-kind classification (barrier taxonomy §11; XII.3).

## Triage: 3
odelia public API + a CI-enforced discipline over every model TU. Consumers: all four strategies.

## The barrier taxonomy (the frame — every value-touch is one of four kinds)
The firewall is not a patch-per-site; every place a barrier touches a value falls into exactly one kind,
treated at its **definition**, so the sanctioned surface is O(1) in strategy count:
- **Kind A — off the derivative** (finiteness/NaN guards, `stop` text, indices, selectors). *This
  component's scope.* Treat with `is_finite` (ADL), `decide`, `diagnostic`.
- **Kind B — on the derivative, off-tape** (inner solves). → the **implicit-node** (odelia #2).
- **Kind C — on the derivative, on-tape** (rate arithmetic, **smoothed kinks**, min/max subgradients).
  → stays `S`; **the smoothed-kink treatment (`smooth_positive`) is this component's, per the note below.**
- **Kind D — the operation *is* a derivative** (a sampled `.deriv()`, an FD stencil). → the **exact
  object** (scan, odelia #1; γ node, odelia #3). Never differenced.

## Requirements ledger
- **R-noleak — no raw `xad::value`/`to_passive` in Model or Numerics; CI-enforced.** *Witness:* v1 has
  **77 `to_passive`** + scattered `xad::value` (species.h ×7, node.h ×6, patch.h ×5). A raw strip is
  *silent detachment* — the exact failure mode this project hit repeatedly. Target: **0**; the grep is
  the gate.
- **R-guard — a finiteness/NaN guard works at `double` and active with no strip, and never throws on an
  active intermediate.** *Witness:* odelia `is_finite(double)` is double-only → forces a `to_passive` to
  guard an `S`; the catalog lists ~6 guard sites (`check_finite_ode_state`, `compute_competition`,
  K93-OOB, `check_initial_density_rates`, `mortality_dt`, …).
- **R-branch — a value-dependent branch is deterministic across record and replay, and one-sided at a
  boundary.** *Witness:* the **measured hydraulic-failure discontinuity** (Gate-0 B, a ~1.46 profit jump)
  + the mass-chart makes the gradient-run forward **non-bit-identical** to the plain double (0.169%), so
  a naive value-branch near a boundary could flip between record and replay.
- **R-kink — a rate-path kink is smoothed by one canonical, declared-corner-radius primitive**, not
  per-strategy hand-rolled clamps with magic constants. *Witness (the note):* `util::smooth_positive`
  is a plant util applied with scattered magic radii (`growth_eps=1e-4`, `mortality_eps=1e-5`); the
  net-production sign branch is a hard un-smoothed kink.
- **R-nocache — no `mutable` active-`S` cache keyed on exact `double` compare.** *Witness:*
  `psi_soil_cache_` (Q8), `cached_driver_` — stale/tape-poison hazards.

**Scarce resource:** *model-author working memory* + *hand-adjoint correctness* — a mis-taken value is a
silent detached derivative (value-exact, gradient-wrong). The firewall's job is to make that
**inexpressible**, not merely discouraged.

## The floor
**Keep `to_passive` + `is_finite(double)`; audit by convention.** *Fails R-noleak* (77 intent-free
strips; a grep can't tell a safe read from a dropped derivative because `to_passive` carries no intent),
*R-guard* (double-only `is_finite`), *R-branch* (no recorded branch), *R-kink* (scattered magic radii).
The floor *is* the v1 leak.

## Candidates
- **A [first thought]** (move 6, Pólya — one intent-carrying surface replaces the strip-scatter):
  `is_finite` → **ADL scalar-generic**; two value-taking functions **`decide(pred)`** (a recorded,
  replayed branch) and **`diagnostic(expr)`** (a dead read); one canonical **`smooth_positive(x, r)`**
  with a *declared* corner radius; `to_passive`/`xad::value` **grep-banned** in Model+Numerics (demoted
  to odelia-internal). *Pays* all five lines. *Costs:* three model-facing names + the CI grep.
- **B** (move 3, move the boundary — audit `to_passive`): keep `to_passive`, add the ADL `is_finite`,
  grep-audit `to_passive` by hand. *Fails R-noleak/R-branch:* `to_passive` carries **no intent** — the
  audit can't distinguish a recorded branch, a dead diagnostic, and a bug; and there is no recorded
  branch. Lighter by two names, but the intent — the whole point — is missing.
- **C** (move 1, weaken — drop `decide`): ADL `is_finite` + `diagnostic` + `smooth_positive`, **no
  `decide`** (value-branches stay plain, lean on bit-identity). *Fails R-branch:* the mass-chart shift
  makes the gradient forward non-bit-identical, so a boundary branch can flip between record and replay
  (the Gate-0 B discontinuity is the witness). Correct in the interior, wrong at the boundary — silently.

**Winner: A.** Eliminations: **B** — `to_passive` cannot carry intent, so R-noleak's grep is toothless
and R-branch is unmet; **C** — no `decide` means a boundary branch can fork under the 0.169% shift
(witnessed). A is the least surface that makes every Kind-A misuse *inexpressible*.

## The commitment
**A model takes a value only through `decide` (a recorded, replayed, one-sided branch), `diagnostic` (a
dead read, off the tape), or `is_finite` (ADL, no strip); it smooths a rate-path kink only through the
canonical `smooth_positive(x, r)` with a declared radius. Raw `xad::value`, `to_passive`, hand-rolled
clamps, and mutable active-`S` caches are inexpressible in Model and Numerics.**

**Kept true by structure:** a CI `grep` bans `xad::value`/`to_passive` outside odelia's Kernel TUs (the
same gate `design.md` §10 already names); `decide`/`diagnostic`/`smooth_positive`/`is_finite` are the
only value-facing functions the model surface exports; `is_finite`/`isfinite` resolve by ADL
(`xad::isfinite` for active, `std::isfinite` for `double`) so a guard needs no strip. `decide` records
its chosen branch on pass 1 and replays it on pass 2 (a bool/int per decision, like an L2 position), so
"the branch forked between record and replay" cannot occur even under the mass-chart shift or at a
discontinuity — the gradient is the one-sided branch derivative by construction.

## Kill question
**Assumption whose falsity makes the firewall unnecessary:** *every value-touch in a model is one of the
four kinds* (so `decide`/`diagnostic`/`is_finite`/`smooth_positive` + "stays `S`" cover them all, and no
raw strip is ever legitimately needed in a model).

**Verdict: survives.** The catalog's exhaustive sweep (XII.3, VIII.5 closure) classifies every AD-hostile
site into the four kinds; Kind A is guards/selectors (decide/diagnostic/is_finite), Kind C on-tape (stays
`S`, kinks via smooth_positive), Kind B inner solves (implicit-node), Kind D derivative-ops (exact
object). No fifth kind was found. A legitimate raw strip survives **only inside an odelia Kernel** (e.g.
the implicit-node forming double partials at the operating point) — which is exactly where the grep
allows it. So the model never needs one.

## The AD-guard survey (every catalog site → its treatment; the user's ask)
| Site (catalog) | Kind | v1 treatment | v2 treatment (improvement) |
|---|---|---|---|
| `is_finite`/`stop` guards: `check_finite_ode_state`, `compute_competition`, K93-OOB, `check_initial_density_rates`, `mortality_dt`, `height_seed`, `load_ode_step`, `trapezium`, `set_mutant` | A | `is_finite(double)` + `to_passive` strip; `stop` reads value | **ADL `is_finite`** (no strip) + `diagnostic(value)` in the `stop` message; the condition never taints the tape |
| Node survival squash `if(!is_finite(survival)) survival=0` | A | hard branch | `decide(is_finite(survival))` (recorded; the NaN branch is measure-zero) |
| Shading-model dispatch | A | `switch` on a config enum | unchanged — bound once at `prepare_strategy`; a **config** selector, not a per-call value-branch (no `decide` needed) |
| PPA layer index `floor(τ/…)` | A | `floor` on a value | `decide` (recorded per-call layer index) |
| **K93 growth `smooth_positive(growth,1e-4)`, mortality `smooth_positive(μ,1e-5)`** | **C** | plant `util::smooth_positive` + **magic per-strategy radii** | **canonical odelia `smooth_positive(x, r)`** with `r` a **declared model parameter** (one subgradient definition; radii named, not magic) |
| **Net-production sign branch** `if(net_prod>0){…}else{zero all rates}` | **C (kink)** | hard un-smoothed branch (compensation-point kink) | model's choice, **declared**: `decide` (recorded, one-sided) *or* `smooth_positive` the whole-block switch — surfaced in the kink manifest with a verdict |
| Leaf shut-down early-exits (the hydraulic-failure discontinuity) | A (branch at a true jump) | hard branch, hand-frozen | `decide` — records the double-pass side, replays it; the gradient is the one-sided branch derivative, and the module **refuses** at a crossing (honesty condition), never averages |
| Resource-spline floor/cap `max(0,·)`/`→1.0` | C/D | on the sampled spline | moot on the coupling path (the **scan** is exact, odelia #1); the fallback interpolator keeps `smooth_positive` for its floor |
| `height_max = max` over cohorts | A | `std::max` (spline-domain bound) | moot for the scan (no spline domain); if a rate reads it, `decide` (recorded argmax) |
| `Internals::auxs` store | (store) | `vector<double>` | **must be `S`** (a templating requirement, not the firewall) — `height→area_leaf→rate` flows through it |
| `psi_soil_cache_`, `cached_driver_` (mutable exact-compare) | (store) | `mutable vector<S>`, exact-compare invalidation | **banned** (R-nocache): recompute `ψ(θ)` (cheap; odelia #3 deletes the cache) — no active value is ever cached on an exact-`double` key |

## What survives deletion
- **`decide` / `diagnostic`** → R-noleak + R-branch + R-guard (the model's only value-reads).
- **ADL `is_finite`** → R-guard (retires odelia's double-only overload + the strip-to-guard pattern).
- **canonical `smooth_positive(x, r)`** → R-kink (one subgradient definition; declared radii).
- **the CI `xad::value`/`to_passive` grep** → R-noleak (the enforcement; the 77 strips → 0 in models).
- **Deleted/demoted:** `to_passive` model-facing use (→ odelia-internal only); the double-only
  `is_finite`; the magic per-strategy clamp radii; the mutable exact-compare caches (R-nocache).

## What this settles
- Every Kind-A value-touch in a model is `decide`/`diagnostic`/`is_finite`; every rate-path kink is
  `smooth_positive` with a named radius — the kink/guard manifest (`design.md` §11) is now **structural**
  (a reviewed verdict per site *and* an inexpressible-misuse guarantee), not a checklist.
- A dropped/detached derivative from a raw strip is a **compile/CI failure** (the grep), not a silent
  wrong number — retiring the single largest v1 debt class (Cluster 2 in the catalog).

## What this makes hard
- **A model that genuinely needs a raw value on the tape path** (not a branch, not a diagnostic): there
  is none in the four kinds — but if one appears, it is a new-kind signal, not a `to_passive` escape;
  route it through a named odelia Kernel (where the grep allows the strip) and record why.
- **A boundary where `decide`'s recorded side is the *wrong* science** (a genuine bifurcation the model
  should resolve, not freeze): `decide` gives the one-sided derivative; the honesty-condition monitor
  must flag the crossing (as with the eigenvalue gap). `decide` is correct *off* the measure-zero set;
  it does not claim to differentiate *through* a true jump.

## Kill condition
A fifth kind of value-touch appears that is neither off-derivative (A), on-tape (C), an inner solve (B),
nor a derivative-operation (D) → the taxonomy (and this firewall's coverage) needs revisiting. None found
across the catalog's exhaustive sweep.

## The design (interface)
```cpp
// odelia — the model-facing value firewall (the ONLY value-reads a model may use)
namespace odelia::guard {
  template <class T> bool is_finite(const T& x)          // Kind A: ADL; no strip
      { using std::isfinite; return isfinite(x); }        //   xad::isfinite for active, std for double

  template <class T> bool decide(const T& predicate);     // Kind A branch: record the chosen side on
                                                          //   pass 1, replay it on pass 2 (one-sided,
                                                          //   fork-proof under the mass-chart shift)
  template <class T> double diagnostic(const T& x);       // Kind A dead read: off the tape (stop text,
                                                          //   finiteness ceilings, R facades)
  template <class T> T smooth_positive(const T& x, double r);  // Kind C: canonical smoothed max(0,x),
                                                          //   corner radius r DECLARED by the model
}
// to_passive / xad::value: retained ONLY inside odelia Kernel TUs; CI-grep-banned in Model + Numerics.
```
`decide` rides the existing record/replay channel (odelia #28): the chosen branch is a recorded datum
per accepted step, replayed on the active pass — the same mechanism as L2 positions, so no new
machinery. `diagnostic` and `is_finite` are pure; `smooth_positive` is on-tape `S` arithmetic.

**Boundary with the journey:** this is the enforcement layer under #1/#2/#3 — it makes their "no
`xad::value`," "no hand partial injection," "no `psi_soil_cache`" claims true by construction rather than
by assertion. It builds no new numerics; it constrains the model surface.
