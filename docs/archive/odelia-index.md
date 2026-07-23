# The odelia AD engine — design index + concept audit

Ties the six odelia design notes to the build plan and the existing odelia surface, and — applying the
system-design + code-review lens to the *proposal itself* — settles the concept set and names so a reader
learns as few, as intuitive, concepts as possible. **This concept table is authoritative;** where an
appendix note (#1–#6, the deepenings) uses a superseded name, the map below reconciles it.

## The concept audit (fewest, most intuitive names)

The code-review principle: an abstraction must *reduce* complexity, and a name must earn itself by
removing a category of bugs — not relocate complexity into a noun. Inventorying what I introduced and
pruning:

### Dropped (a name that didn't earn itself)
| Dropped noun | Why it went | What replaces it |
|---|---|---|
| **`StateView`** | a monolith over reads that are either **pushed rate arguments** (`x`, `A`, `ψ_soil`) or a single field evaluator; the only genuine pull is the crown reading the field at several heights | the rate receives its inputs as arguments; the crown calls **`A.at(z)`** on the field; the census functional uses odelia's existing state accessors |
| **`TransportGeometry`** | the model never touches it; it is a *fixed rule*, not a policy object (#1) — naming it makes a reader learn a concept for "how the engine transports" | described as the **mass-transport rule** inside the one transport helper (log-mass; density from neighbour-secant spacing) |
| **`TransportedPopulation`** / **`CouplingField`** (as classes) | the SCM System already holds its cohort state; these were classes for what are really two *operations* over it | the two engine operations below |

### The engine surface (odelia dev learns these; the model never sees them)
| Concept | What it is | Was |
|---|---|---|
| **`separable_field`** | builds the coupling field `A` from the model's separable factors over the cohorts — exact, non-adaptive; its reverse is the one hand-written transpose (dot-product self-checked) | "the scan" / scan-coupling (#1) |
| **the field `A`** | what `separable_field` produces; the model reads its value and `A.at(z)` (crown). A plain readable, not a "view" | `CouplingField`/`StateView` (#1) |
| **mass transport** | the helper that sets `log_density_dt` from the neighbour secant of the growth rate (the mass chart: transport log-mass, derive density from spacing) — one engine rule, deletes `node.h::growth_rate_gradient` + the `species.h` loop | `TransportGeometry` (#1) |
| **`register_implicit`** | register an inner solve as a residual + a double solver; the engine forms the IFT partials and injects them (reuses `supplied_derivative` internally) | implicit-node (#2) |
| **`incomplete_gamma`** | the exact Weibull antiderivative `∫exp(−(|ψ|/b)^c)` (value + `∂/∂x` + `∂/∂s`); bounds the **whole leaf hydraulic transport** — soil vulnerability *and* stem `transpiration_from_psi` are the same family — collapsing all four leaf splines to exact reads (odelia #7 §C) | the "γ node" (#3) |
| **`decide` / `diagnostic`** | the two value-reads a model may make: a recorded, replayed branch; a dead (off-tape) read | value firewall (#4) |
| **`is_finite` / `smooth_positive`** | ADL scalar-generic finiteness; the canonical smoothed `max(0,·)` with a declared radius | firewall (#4) |

### The model surface (a plant author writes only these — science, plus one declaration)
| Concept | What it is |
|---|---|
| the rate functions | plant's own science names (`size_dt`, `mortality_dt`, `fecundity_dt`, …) reading the field `A` and their own state — **nothing new; plant keeps its names** |
| the **separable coupling declaration** | the one genuinely new model declaration: how the shading kernel splits (`κ(z,x)=Σ_p query_factor_p(z)·source_factor_p(x)`). **Settled (odelia #7 §D):** `query_factors(z)` / `source_factors(x)` (naming the role each half depends on) + `competition_direct(z,x)` for the init self-check — replacing the mathy `kernel_a/kernel_b` placeholder. |
| `register_implicit`, `decide`, `diagnostic`, `is_finite`, `smooth_positive`, `incomplete_gamma` | the engine primitives above, called from model code as plain functions |

**Net new names a reader must hold:** `separable_field` + the field `A`, the mass-transport helper,
`register_implicit`, `incomplete_gamma`, and the firewall verbs — mostly *operations*, two *nouns*
(`A`, `separable_field`), and the two the user flagged (`TransportGeometry`, `StateView`) are **gone**.

## The seven design notes → what each settles
| # | Note | Settles | Build-plan label |
|---|---|---|---|
| 1 | [transport spine](./odelia-1-transport-spine.md) | `separable_field` (exact field `A`) + mass transport; deletes `growth_rate_gradient` + the compression loop | P1b (separable field) + P1e (transport) |
| 2 | [implicit-node](./odelia-2-implicit-node.md) | `register_implicit`; deletes the ~150-line FD leaf seam + hand IFTs | P1a |
| 3 | [soil coupling](./odelia-3-soil-coupling.md) | `incomplete_gamma`; soil as active state; deletes the uptake FD seam + the ψ cache | P1c + deepening-3 |
| 4 | [value firewall](./odelia-4-value-firewall.md) | `decide`/`diagnostic`/`is_finite`/`smooth_positive`; the full AD-guard survey | P1d |
| 5 | [existing pieces](./odelia-5-existing-pieces.md) | audit of Solver/driver/functionals/IC/interpolator/L0-L1 | the "Existing engine pieces" build-plan section |
| 6 | [boundary/tape/checkpoint](./odelia-6-boundary-tape-checkpoint.md) | no `Runnable` (call-site comment); `reserve_state` deletion candidate; checkpointing measure-gated | same section |
| 7 | [representation + TF24 trace](./odelia-7-tf24-trace.md) | the representation guarantee (read-side views); a full TF24/TF24f bounding trace; QK templated (not moved); `incomplete_gamma` widened to the leaf transport; the settled coupling-declaration name; the census experiment scoped | verifies P1a–e cover TF24 |

## The two tape-aware Kernels (the scarce resource, bounded)
Across the whole design there are exactly **two hand-written adjoints** — the **`separable_field`** transpose and the
**`register_implicit`** dense IFT solve — each self-checked by the `compute_jvp` dot-product oracle
(`⟨Jv,u⟩=⟨v,Jᵀu⟩`). Everything else (mass transport, `incomplete_gamma`, the firewall) is either the same
operator forward/reverse or ordinary taped arithmetic. **Zero hand adjoints in strategies.**

## What is already built in odelia (no new design)
Solver + the gradient driver (`compute_jacobian`/`compute_gradient`/`compute_jvp`), functionals as pure
reductions, record/replay (L1 schedule + the interpolator, now the non-separable fallback), IC seeding
(`ad_initial_state`; plant#499 landed the plant side), growing-dimension (works — `reserve_state` a
deletion candidate). AUTODIFF.md is odelia's own account.

## Reading order
`design.md` (the what/why) → `build-plan.md` (the how/order) → this index (the concept set) → the six
notes for derivations. The deepenings (`deepening-*.md`) hold the per-component math; `phase0-results.md`
holds the evidence.
