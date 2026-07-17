# odelia design #1 — the resident-census transport spine (canonical-state + charts + exact field)

First component of the odelia design journey (`design.md` P1b + P1e), under the system-design skill,
grounded in the *actual* v1 code (the plant#52→develop diff) and the Oracle catalog.

**Correction note.** An earlier draft of this doc demoted the scan to a deferred optimization, reusing
the existing interpolator + geometric-compression secant on the grounds that they are "validated." That
was wrong, and the reason is the whole point of v2: those mechanisms **are** the clunk. The plant#52 diff
shows the leak (32 files touch XAD; `xad::value` ×7 in `species.h`, ×6 in `node.h`, the baroque
forward-over-reverse `dg/dh` splice in `node.h::growth_rate_gradient`), and the Oracle's R2 explicitly
prescribes an **exact field object, never sampled differences** — the interpolator is the sampled
reconstruction R2 says to replace, and its frozen `∂A/∂z` (the C3 17× ripple) and the detached-secant
`dg/dh` are *documented biases*, not validations. This draft reinstates the scan as core.

## Triage: 3
odelia's public API; consumers are plant's four strategies + regnans. Full procedure.

## Requirements ledger
- **R1 — a model reads as science; zero XAD tokens, zero tape-aware transport/field code.** *Quantity
  (from the v1 diff):* today **32 files** touch `#include <XAD/…>`/`xad::`; `species.h` has 7 `xad::value`,
  `node.h` 6, `patch.h` 5; the `node.h::growth_rate_gradient` block is ~70 ln of forward-over-reverse
  (`rebind<Fwd>`, the detached secant, the `dgdh − value(dgdh) + fd_value` splice). Target: **0** in a
  strategy; the transport + field owned by odelia.
- **R2 — the coupling field and its derivatives are EXACT (representation-level), never sampled
  differences.** *Witness:* the field is a **closed-form separable sum** (rank-3 `κ(z,x)=m(x)(1−(z/x)^η)²`,
  derived against the real `canopy_shape.h`); v1 approximates it with an **adaptive spline** whose query
  derivative rippled **17×**, forcing the odelia#38 **freeze** (a documented bias). Oracle R2: "an explicit
  field object with exact representation-level derivatives … never sampled differences … no sampled-field
  differencing at any tier."
- **R-transport — dg/dh needs no per-strategy AD and no bias.** *Witness:* v1's `node.h` detaches the
  secant's θ-sensitivity (taping it "blows the census gradient up ~2.3×") and keeps a "tamer surrogate" —
  an explicit **bias-ledger entry**. The mass chart removes the term from the rate entirely.
- **R-view — the model reads state through a read-only view**, never a raw vector, never the tape.
- **R-grow — composes with the growing dimension** (`N≈10²–10³`, `reserve_state` keeps active slots put).
- **R5 — double path bit-identical, or one documented change** (the mass chart's ~0.169% K93 shift).

**Scarce resource:** *hand-written-adjoint correctness* jointly with *model-author working memory* (R1).
Note the scan adds **one** hand adjoint (its transpose) — priced below against the two biases + the leak
it removes.

## The floor
**Leave transport + field in plant, build nothing.** Keep `node_geometric_compression` (the secant
`dg/dh`) + the adaptive interpolator for `A`. *Fails R1, R2, R-transport:* it *is* the v1 state — the
32-file leak, the sampled-spline field, the frozen `∂A/∂z`, the detached-secant bias all remain. "It is
numerically validated" is true and irrelevant: v2 exists because it is clunky and leaky, not because it
is wrong. The floor loses on the three ledger lines that name the clunk.

## Candidates
- **A [first thought]** (move 6, Pólya): the full **canonical-state + charts + scan** — engine owns
  transported state, the mass-chart geometry, the exact separable field with `A`/`∂A/∂z`, **and** a menagerie
  of chart views (`log_density`, `S`, mass, …). *Pays* R1+R2+R-transport. *Costs:* the scan + its transpose,
  `TransportGeometry`, `StateView`, **plus views nobody reads yet**. *Wins when* every chart view is witnessed.
- **B** (move 3, move the boundary — *rejected earlier draft*): move transport to odelia (mass chart) but
  **reuse the interpolator for `A`**. *Fails R2:* the interpolator is the sampled reconstruction the
  Oracle says to replace; it keeps the frozen-`∂A/∂z` bias and the leak. Numerically works, but pays none
  of the three clunk lines for the field. **Eliminated.**
- **C** (move 5, optimize typical / detect rest): **exact separable scan for the field (the typical
  case) + mass chart for transport, both engine-owned; the interpolator retained ONLY as the
  non-separable `FlatTopSoftBox` fallback.** The model declares the separable factors `{a_p(z), b_p(x)}`
  and `g(x, A)`; reads via a **read-only `StateView`** (`x, density, mass, A, dA_dz, u`); the engine owns
  `{xᵢ, log mᵢ}` + `TransportGeometry` and applies `dg/dh`. *Pays* R1 (deletes the 70-line block + the
  compression loop; no XAD in strategies), R2 (exact field, no sampled differencing, no freeze), and
  R-transport (mass chart, no bias). *Costs:* two engine names (`TransportGeometry`, `StateView`) + the
  scan primitive + its **one** hand transpose (dot-product self-checked). *Wins when* the target kernel is
  separable — which K93/FF16/TF24 defaults are, by construction.

**Winner: C.** Eliminations: **B** fails R2/R-transport — it reuses the sampled reconstruction and both
documented biases, i.e. it is the clunk renamed; "validated" pays no ledger line. **A** over-builds the
view menagerie — build the reads witnessed (`x, density, mass, A, dA_dz, u`), add others on a witness;
`A` menagerie is the YAGNI trap. **The floor** is v1. C is the least design that pays R1+R2+R-transport:
the scan's single hand transpose is cheap against the two biases (17× ripple freeze, 2.3× detached
secant) and the 32-file leak it retires.

*Why the earlier demotion was wrong, precisely:* "no rate reads `∂A/∂z`" is a red herring — the field
**value** `A` and its parameter path `dA/dθ` run through the sampled interpolator regardless, and `dg/dh`
reads the slope via the **biased** secant. Exactness is about the field object, not about which read a
rate happens to make. Approximating a closed-form separable sum with an adaptive spline is the clunk;
the scan computes it exactly and drops the L2 record/replay machinery for the coupling path entirely.

## The commitment
**The engine owns the transported demographic state, its transport geometry (the mass chart), and the
coupling field as an EXACT object built from the model's separable factors — reads exact, derivatives
exact, no sampling, no XAD in the model.** A strategy declares `{a_p(z), b_p(x)}`, `g(x, A)`, `loss`,
`influx`; it reads a read-only `StateView`; it can neither write a density/transport rate, name a
transport derivative, nor difference a sampled field. dg/dh and the coupling field cease to exist on the
model surface — both are engine objects, identical for all separable strategies.

**Kept true by structure:** the strategy TU (a) is templated on opaque `S` and has **no `#include
<XAD/…>`** (enforced by the CI `xad::` grep the design already specifies — the 32-file leak becomes 0);
(b) sees the population only through `const StateView<S>&` with **no** `set_log_density_dt`, **no**
raw-field pointer, **no** interpolator handle — so "hand-write dg/dh," "freeze a sampled slope," and
"call `value()` on the field" are all *inexpressible*. The scan and the mass chart are odelia-owned
Kernels; each ships its dot-product self-check (`compute_jvp`, which already exists).

## Kill question
**Assumption whose falsity makes the scan unnecessary:** *the coupling kernel is non-separable for the
target modes* (so no exact closed-form field exists and the interpolator is unavoidable).

**Verdict: survives.** The four strategies' default modes use the shared `CanopyShape` kernel
`κ(z,x)=m(x)(1−(z/x)^η)²`, which is exactly rank-3 separable (deepening-6, derived against
`canopy_shape.h`); `m(x)` is the only per-strategy factor. Only `FlatTopSoftBox`/PPA are non-separable —
and they keep the interpolator fallback (that is *why* C retains it). So the exact field applies to every
default-mode consumer; the scan is not speculative.

## What survives deletion
- **The scan-coupling primitive** (separable `{a_p, b_p}` → suffix scans `B_p` → exact `A`, `∂A/∂z`;
  mirrored prefix-scan transpose; near-diagonal band) → R2 (exact field, retires the 17× freeze) + R1
  (the model declares factors, not a spline; no XAD).
- **`TransportGeometry`** (mass chart; the neighbour-secant spacing that makes `∂ₓg` vanish from the
  rate) → R-transport (deletes the `node.h` block + the `species.h` loop; no detached-secant bias) + R5.
- **`StateView<S>`** (`x, density, mass, A, dA_dz, u` — the witnessed reads) → R1/R-view.
- **`TransportedPopulation<S>`** (engine `{xᵢ, log mᵢ}` + resize hook) → R-grow + R1.
- **Retained, scoped:** the interpolator — as the non-separable fallback only (not on the separable
  coupling path). **Deleted/not built:** the chart-view menagerie beyond the witnessed reads;
  `TransportGeometry`-as-policy-object (one discretisation).

## What this settles
- `node.h::growth_rate_gradient` (~70 ln forward-over-reverse), the `species.h` compression loop, the
  frozen `get_environment_slope_at_height`, and the coupling-path interpolator **all delete**; the 32-file
  XAD leak → **0 in strategies** (R1).
- The coupling field is exact — the C3 freeze and the detached-secant `dg/dh` bias (17× / 2.3×) are both
  **gone**, not worked around (R2, R-transport).
- dg/dh is uniform across all four strategies with zero per-strategy code (R2/design).

## What this makes hard
- **A non-separable default mode** (if `FlatTopSoftBox` ever became a strategy's default): the exact field
  doesn't apply. *Cope:* the interpolator fallback is retained precisely for this; the `StateView.A()`
  read dispatches to it at strategy setup (a per-`ShadingModel` choice, not a hot-path branch).
- **A second hand adjoint** (the scan transpose) now exists — the scarce resource. *Cope:* it is
  dot-product self-checked at init (`⟨Jv,u⟩=⟨v,Jᵀu⟩`), and it is the *only* new one (the mass chart is
  the same operator forward/reverse, no transpose).

## Kill condition
The `CanopyShape` kernel stops being separable (a new canopy model whose default shading is not
`m(x)·(1−(z/x)^η)²`) → that mode uses the interpolator fallback; the scan stays for the separable
strategies. (This is the reverse of the earlier draft's trigger: separability is the witnessed norm, not
the exception.)

## The design (parts, flow, interfaces)

**Ownership** (extends AUTODIFF.md "System owns its background"; the Patch holds engine-owned components):

```cpp
// odelia Kernels — engine-owned, the only XAD-aware code
template <class S> class TransportedPopulation {           // held by the Patch
  void reserve(std::size_t n_max);                          // R-grow
  int  introduce(S x0, S log_m0);                           // active ICs read the active stand
  // after the model sets each cohort's g, the engine sets the transport rate:
  //   log_density_dt[i] = -TransportGeometry::compression(g, x, i) - loss[i]
  // TransportGeometry = neighbour secant of g over the SAME spacing the quadrature uses
  //   (mass chart: the term vanishes from the density rate; theta-derivative cancels structurally).
  StateView<S> view() const;                                // the model's ONLY window
};

template <class S> class CouplingField {                    // the EXACT separable field (R2)
  // built from the model's factors each stage over the active cohorts; NO sampling, NO knots, NO L2.
  void assemble(ArrayView<S> a_p_of_x /*b_p*/, ArrayView<S> mass);   // -> suffix scans B_p
  S    A   (S z) const;                                     //  Σ_p a_p(z) B_p         (exact)
  S    dA_dz(S z) const;                                    //  Σ_p a_p'(z) B_p        (exact; no freeze)
  // reverse = mirrored prefix scans; one hand transpose, dot-product self-checked.
};

template <class S> struct StateView {                       // read-only; no transport/field handle
  S x(int i), density(int i), mass(int i);
  S A(int i), A_at(S z), dA_dz_at(S z);                     // exact field reads
  const AuxView<S>& u() const;                              // soil / low-rank aux (deepening-3)
  // NO set_log_density_dt, NO interpolator handle, NO xad::value.
};
```

**What a strategy declares (the whole transport+field model surface):**
```cpp
template <class S> struct K93 {                             // FF16/TF24 identical shape; m(x) differs
  std::array<S,3> kernel_a(double z) const;                 // {1, -2 z^η, z^{2η}}
  std::array<S,3> kernel_b(S x)     const;                  // m(x)·{1, x^{-η}, x^{-2η}}
  S kernel_direct(double z, S x) const;                     // m(x)Q(z/x) — init-time Σ a_p b_p self-check
  S velocity(S x, S A, const Pars<S>&) const;               // g — reads the exact field value
  S loss(S x, S A, const Pars<S>&) const;                   // r
  S influx_mass(S x_b, const Pars<S>&) const;               // = birth_rate·pr_estab (design §6)
  // NO log_density rate, NO dg/dh, NO spline, NO XAD.
};
```

**Data flow (resident gradient, one RK stage):** the driver replays on the recorded L1 schedule; the
engine's `CouplingField` assembles `A` **exactly** from the active `{xᵢ, mass}` via the model's factors
(no interpolator, no recorded knots — the separable field is not an adaptive component, so **L2 disappears
from the coupling path**); the strategy's `velocity`/`loss` read `A`/`density`/`u` through the
`StateView`; the engine applies `TransportGeometry` to set `log_density_dt`. Reverse: the ordinary sweep,
plus the scan's mirrored-prefix transpose (self-checked); the mass chart needs no transpose.

**Boundary consequence (the v2 win the demotion would have lost):** because the separable field is exact
and non-adaptive, the resident coupling path carries **no L2 record/replay, no frozen-slope bias, and no
XAD in plant** — the three things the plant#52 diff shows as the v1 clunk. The interpolator survives only
where the kernel genuinely isn't separable.
