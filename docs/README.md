# AD engine design (plant × odelia)

**What.** A design for exact reverse-mode **trait/parameter gradients** of the `plant` SCM's emergent
outputs (LAI, biomass, basal area, offspring/R0) — built on a small general-purpose AD engine in
`odelia` so `plant` strategies contain **zero tape-aware code** and stay readable as science.

**Why.** A validated prototype exists (traitecoevo/plant#553) — it is the **specification and regression
oracle**, not the code that ships. This design reaches the same gradients with a small engine surface, a
clean `System` interface, and the transported-state / coupling machinery owned by odelia.

## Read in this order

1. **[`design.md`](./design.md)** — the authoritative design. Requirements + personas, the two-axis
   framing (replay × functional), the M/N/K architecture + engine primitives, the L0–L3 replay levels,
   dg/dh + the mass chart, the inner solves, the R boundary + emergent functional, the Control/caching
   contract, the verification trust model + regression witnesses, and scope/known edges.
2. **[`build-plan.md`](./build-plan.md)** — the phased, parallelizable build order to plant#52 parity and
   the fixed-point layer: the delivery ladder, standing guards, Phases 0–3, the multirate track, the port
   map, and the scope fences.

### Detailed appendices (per-component derivations `design.md` links)
- [`deepening-6-light-coupling.md`](./deepening-6-light-coupling.md) — K93/FF16 light coupling + dg/dh.
- [`deepening-1-leaf-residuals.md`](./deepening-1-leaf-residuals.md) — the TF24 leaf inner solves (N1, N3).
- [`deepening-3-soil-coupling.md`](./deepening-3-soil-coupling.md) — the two-way soil↔leaf coupling.
- [`deepening-2-4-5.md`](./deepening-2-4-5.md) — crown quadrature, leaf early-exits, TF24f in the BVP.
- [`phase0-results.md`](./phase0-results.md) — F1/E2 + the two Gate-0 checks (the evidence trail).

### Design inputs (the external-reasoner consultations)
- [`oracle-consultation-index.md`](./oracle-consultation-index.md) — the running catalogue + measurement trail.
- `oracle-ad-design-consultation.md`, `oracle-followup-{1,2}-*.md`, `oracle-consultation-{soil-subsystem,tf24-coupled}.md` — the statements and responses.
- [`oracle-consultation-guide.md`](./oracle-consultation-guide.md) — general practice for framing a hard problem to an external reasoner.

### Archive
[`archive/`](./archive/) holds the prototype-era ("surgical changes to plant") design set that this
engine design supersedes — infrastructure design, record/replay, R interface, the implementation design,
the touchpoint catalog, the work-breakdown issues, the handover, the census-gradient standalone, and the
v2 engine surface design. Kept for provenance and for the load-bearing detail folded forward into
`design.md`/`build-plan.md`. **Not the current design** — start with `design.md`.

## Glossary
- **SCM** — plant's Solver for Characteristics Method: a size- and patch-structured cohort population,
  cohorts introduced on a schedule, stepped by an adaptive ODE solver. The **Patch** is the state being
  integrated — already an `odelia::ode::Solver` System.
- **Resident vs mutant** — resident/total differentiates *with* self-feedback (a trait re-shades the
  stand); mutant/invasion is a rare mutant's fitness gradient against a frozen resident canopy (the
  selection gradient). Same engine, the L3 replay variant.
- **Replay levels L0–L3** — the four adaptive constructions frozen to their recorded placement so the run
  is differentiable: L0 cohort schedule, L1 ODE steps, L2 quadrature/interpolator knots, L3 resident
  canopy. See `design.md` §4.
- **The mass chart** — transport log-mass (`dλ/dt=−r`), which removes the density-transport term `∂ₓg`
  from the model rate (carried instead by the cohort-spacing geometry).
- **Reverse-mode AD / XAD / tape** — records operations, sweeps backward for all input derivatives from
  one output; optimal here (many params, few metrics). **XAD** is the library odelia vendors and compiles
  once.
