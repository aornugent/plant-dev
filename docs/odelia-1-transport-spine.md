# odelia design #1 — the resident-census transport spine (canonical-state + charts; scan deferred)

First component of the odelia design journey (`design.md` §3 primitives P1b + P1e). Designed under the
system-design skill, grounded in the *actual* odelia AD surface (AUTODIFF.md, `CanopySystem`, the
interpolator, `reserve_state`) — not the catalog's reading of it. **Headline: applying the skill's floor
test to the real code demotes the scan-coupling primitive from core to a deferred, trigger-gated
optimization.** The resident-census spine is smaller than `design.md` committed.

## Triage: 3
odelia's public API; consumers are plant's four strategies + regnans. Expensive to reverse once models
declare against it. Full procedure.

## Requirements ledger
- **R1 — a model reads as science, zero tape-aware transport code.** *Quantity:* delete
  `node.h::growth_rate_gradient` (~70 ln active block) + the `species.h` geometric-compression loop
  (~15 ln) from plant; **0** transport-derivative tokens in a strategy.
- **R2 — dg/dh (the density-transport term) needs no per-strategy AD.** *Quantity:* correct for all four
  strategies (today: K93 only); zero per-strategy transport code.
- **R-view — the model reads state through a read-only view**, never a raw state vector, never the tape.
  *Quantity:* the reads a rate actually makes — `density(i)`, the coupling value `A(x_i)`, soil `u(ℓ)`.
- **R-grow — composes with the growing dimension.** *Quantity:* `N ≈ 10²–10³` cohorts, introduced
  mid-run; `reserve_state` already keeps active tape slots put across `resize()`.
- **R5 — double path bit-identical, or one documented change.** *Quantity:* the mass chart's neighbour-
  secant compression is the sole deviation (~0.169% K93 offspring, Gate-0 A), opt-in for gradient runs.

**Scarce resource:** *hand-written-adjoint correctness* (every human-written reverse rule is a silent
gradient-bug site) **jointly with model-author working memory** (R1). The design is measured by how few
tape-aware sites it creates and how small the model's surface stays.

**Challenged upward (confirm):** *I believe the requirement is "dg/dh correct + off the model surface,"
not "an exact separable-kernel field with `∂A/∂z`."* If so, the exact scan is not required by the
resident census — see the kill question. (design.md had the scan as core P1b; this challenges that.)

## The floor
**Leave transport in plant, build nothing new in odelia.** Keep the `node_geometric_compression` control
flag (the neighbour-secant `dg/dh`, already validated) + the existing interpolator for the coupling field
`A(z)` (active-recompute on frozen knots — the resident self-shading path `CanopySystem` demonstrates).

- *Numerically it suffices* for the resident census gradient: Gate-0 A showed the geometric-compression
  transport is bounded at the default clamp with the 0.169% shift; F1 showed the operator is faithful to
  8.6e-6; the interpolator carries `A`'s value with `dA/dθ` flowing through active recompute. **No rate
  reads `∂A/∂z`** (K93 reads `A` at its own height; FF16/TF24 crown integrals read `A(z)` at fixed-rule
  nodes) — so the interpolator's frozen query-derivative is never consumed, and its ripple (the old C3
  17×) cannot bite.
- **Fails R1:** the ~70-line `growth_rate_gradient` block + the `species.h` compression loop stay in
  plant — tape-aware transport code on the model surface. R1 is the project's central goal (plant as
  science, odelia as machinery); the floor leaves it unpaid.

## Candidates
- **A [first thought]** (move 6, Pólya): the full **canonical-state + charts + scan** of `design.md`.
  *Commitment:* the engine owns the transported state, its geometry, **and** an exact separable-kernel
  field with `∂A/∂z`. *Pays* R1+R2, and the scan makes `A`/`∂A/∂z` exact + deletes the interpolator from
  the coupling path. *Costs:* the scan **and its hand-written transpose** (spends the scarce resource),
  the `TransportGeometry`, the `StateView`, plus the many-view chart surface. *Wins when* a rate reads
  `∂A/∂z`, or `N` makes the per-stage interpolator recompute a measured bottleneck.
- **B** (move 3, move the boundary): move **only the transport identity** into odelia — the engine owns
  the transported demographic state `{xᵢ, log mᵢ}` and applies the **`TransportGeometry`** (neighbour-
  secant ↔ log-mass) to produce `log_density_dt`; the model declares `dx/dt = g` reading a thin
  **`StateView`** (`density`, `A`, `u`); the coupling value `A` is still the existing interpolator's
  active read. *Commitment:* transport is engine geometry, inexpressible in the model; `A` stays the
  interpolator. *Pays* R1 (deletes both plant blocks) + R2 (uniform, zero per-strategy) with the fewest
  new names; reuses the validated interpolator + secant. *Costs:* two new names (`TransportGeometry`,
  `StateView`); bad at a rate that needs the exact field slope. *Wins when* no rate reads `∂A/∂z` (the
  measured truth) and the interpolator's `A` suffices (validated).
- **C** (move 5, optimize typical / detect rest): **B + the scan as the separable fast-path** for `A`
  (interpolator retained as the non-separable `FlatTopSoftBox` fallback). *Commitment:* separable is the
  typical case, detected at strategy setup. *Pays* R1+R2 + performance. *Costs:* the scan + its hand
  transpose (the scarce resource) — but gated behind a measured perf need. *Wins when* the interpolator
  recompute is a measured bottleneck at large `N`.

**Winner: B.** Eliminations: **A** over-builds — the scan's distinctive capability (`∂A/∂z`, exact field)
is **unwitnessed**: no target rate reads the field slope (dg/dh is the secant, R2), so its hand transpose
spends the scarce resource for no ledger line. **C** adds the scan on a **rumored** perf need — no
measurement shows the interpolator recompute dominates; that is the retrofit trigger, not today's design.
B pays R1+R2 with two names, reusing validated machinery. (The floor loses only on R1 — it is otherwise
correct, which is why B reuses its internals rather than replacing them.)

## The commitment
**The engine owns the transported demographic state and its transport geometry; a strategy declares only
per-cohort rates that read a read-only `StateView`, and can neither write a density/spacing rate nor name
a transport derivative.** dg/dh ceases to exist on the model surface — it is `TransportGeometry`, applied
once by the engine, identical for all four strategies.

**Kept true by structure:** the strategy translation unit sees the population only through
`const StateView<S>&` (reads: `x`, `density`, `mass`, `A`, `u`); there is **no** `set_log_density_dt` and
**no** writable spacing/density handle in that view, so "hand-write a transport term" and "call `value()`
on a transported quantity" are *inexpressible* — not forbidden by comment. The engine's
`TransportedPopulation<S>` component (an odelia-owned member the Patch holds) computes `log_density_dt`
from the neighbour secant of the model's `g`; the model supplies `g`, never the transport of it.

## Kill question
**Assumption whose falsity makes B insufficient (and forces A/C):** *no target rate reads the coupling
field's spatial derivative `∂A/∂z`, and the interpolator's `A` value is accurate enough for the census
gradient.*

**Verdict: survives** — argued from ledger facts only. The four strategies' rates read the coupling
*value* `A`: K93 `−log(A)/k_I` at the plant's own height; FF16/TF24 crown integrals read `A(z)` at
fixed-rule `QK` nodes; TF24 mean-light reads `∫A(z)q dz`. **None differentiates `A` w.r.t. the query
position on the rate path.** The density-transport `∂ₓg` is carried by the `TransportGeometry` secant
(R2), validated (F1 8.6e-6; Gate-0 A). The interpolator carries `A` to its construction tolerance, the
same the double run uses, and `dA/dθ` flows through active recompute (resident self-shading). So B's
scope holds for every witnessed consumer; A/C's extra machinery is unpaid.

## What survives deletion
- **`TransportGeometry`** (the neighbour-secant ↔ log-mass pairing) → R1 (deletes the plant compression
  loop) + R2 (uniform dg/dh) + R5 (the 0.169% documented shift is *this*).
- **`StateView<S>`** (read-only reads: `x`, `density`, `mass`, `A`, `u`) → R1 (the model's whole
  population-read surface; makes tape-aware transport inexpressible) + R-view.
- **`TransportedPopulation<S>`** (engine-owned `{xᵢ, log mᵢ}` + the resize hook) → R-grow (composes with
  `reserve_state`) + R1 (owns what the model must not).
- **Deleted / not built:** the **scan-coupling primitive** (no `∂A/∂z` witness — deferred to the kill
  condition); the multi-view chart menagerie (`log_density`, `S`, `∂A/∂z` views — build the three reads
  witnessed, add others on a witness); `TransportGeometry`-as-policy-object (one discretisation — a fixed
  pairing until a second appears).

## What this settles
- `node.h::growth_rate_gradient` and the `species.h` geometric-compression loop **delete** from plant;
  no strategy contains transport-derivative code (R1).
- dg/dh is correct for all four strategies with **zero per-strategy work** (R2) — it is one engine
  identity, not a per-model port (today's K93-only limitation ends).
- **No scan primitive, no exact-field machinery, no second hand-written adjoint** is built for the
  resident census — the scarce resource is spent only on the `TransportGeometry` secant (which is not
  even an adjoint — it is the same discrete operator forward and reverse, so its θ-derivatives cancel
  structurally; the census-gradient correctness rides that cancellation, not a transpose).

## What this makes hard
- **A strategy whose rate reads the field slope `∂A/∂z`** (a light-gradient-sensitive physiology): B
  can't serve it — it would need the scan (candidate C/A). *Cope:* the retrofit is additive — the scan
  is a new `StateView.dA_dz()` read backed by the separable factors; nothing in B forecloses it.
- **Very large `N` where the per-stage interpolator recompute dominates** the resident forward+reverse
  cost. *Cope:* candidate C — the separable scan as the fast-path for `A`, interpolator kept as the
  non-separable fallback; gated on a profile, not assumed.

## Kill condition
A target rate reads `∂A/∂z` on the differentiated path, **or** a profile shows the interpolator's
per-stage `A` recompute dominates the resident gradient cost → promote the **scan** (candidate C: the
separable fast-path + `StateView.dA_dz()`), which candidate A/`deepening-6` already specifies (rank-3
`{a_p(z), b_p(x)}`, the mirrored prefix/suffix transpose, the C¹ double-zero, the near-diagonal band).
The design hands off to that spec unchanged; only the trigger was missing.

## The design (parts, flow, interfaces)

**Ownership (extends AUTODIFF.md's "System owns its background").** The Patch (the odelia System) holds
an engine-owned `TransportedPopulation<S>` for its cohort demographic state, exactly as `CanopySystem`
holds its own state + record/replay:

```cpp
// odelia — the engine-owned transported population + its read surface
template <class S>
class TransportedPopulation {                 // held by the Patch (the System)
public:
  void reserve(std::size_t n_max);            // R-grow: pre-size; resize() keeps active slots put
  int  introduce(S x0, S log_m0);             // a cohort enters (active ICs read the active stand)
  // engine applies the transport geometry after the model sets per-cohort g:
  //   log_density_dt[i] = -TransportGeometry::compression(g, x, i) - r[i]
  // TransportGeometry = the neighbour secant (g[lo]-g[hi])/(x[lo]-x[hi]); one operator,
  // shared with the quadrature spacing, so its theta-derivative cancels (mass chart).
  StateView<S> view() const;                  // the model's ONLY window on the population
};

template <class S>
struct StateView {                            // read-only; no transport handle exists
  S x(int i) const;                           // cohort size
  S density(int i) const;                     // n_i  (= exp(log m_i) / spacing, engine-derived)
  S mass(int i) const;                        // log-mass chart quantity
  S A(int i) const;                           // coupling field value at cohort i's height
  S A_at(S z) const;                          // coupling value at an arbitrary height (crown reads)
  const AuxView<S>& u() const;                // soil / low-rank aux state (deepening-3)
  // NO dA_dz(), NO set_log_density_dt(): inexpressible until the kill condition fires.
};
```

**What a strategy declares (the whole model-facing surface for transport):**
```cpp
template <class S> struct K93 {                         // FF16/TF24 identical shape
  S velocity(S x, S A, const Pars<S>&) const;           // g  — reads the field VALUE, not its slope
  S loss    (S x, S A, const Pars<S>&) const;           // r  — mortality/turnover
  S influx_mass(S x_b, const Pars<S>&) const;           // boundary law (= birth_rate*pr_estab; §design 6)
  S sample_map(S L) const { return exp(-k_I * L); }     // Ψ (Beer-Lambert), if the field is a sum
  // NO log_density rate, NO dg/dh, NO xad::value — the transport is the engine's.
};
```

**Data flow (resident gradient pass, one RK stage):** the driver replays on the recorded schedule
(L1); at each stage the Patch's `TransportedPopulation` holds the active `{xᵢ, log mᵢ}`; the coupling
field `A` is recomputed active on the frozen interpolator knots (L2 — the existing path, self-shading
flows); the strategy's `velocity`/`loss` read `A`/`density`/`u` through the `StateView` and return `g`,
`r`; the engine applies `TransportGeometry` to set `log_density_dt` (no model code). The reverse sweep is
the ordinary tape sweep — **no new hand adjoint**, because the secant is the same operator forward and
reverse.

**The coupling field `A`.** Unchanged from today: the interpolator, recomputed active on recorded knots
for residents (L3 empty). The `StateView.A()/A_at()` are thin reads over it. This is the deliberate reuse
that keeps candidate A's scan out of the spine.

**Boundaries with the rest of the journey:** the soil `u()` (deepening-3) and the leaf inner solve
(deepening-1) are separate components; this spine only fixes transport + the field read. The implicit-node
primitive (P1a) is independent and unaffected.
