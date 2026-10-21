# Prices, the equilibrium manifold, and small steps toward H1 and H2

This answers four questions raised after `frontier.md`: what the field hook is,
what following the equilibrium needs, whether the adjoint as a price belongs in
the representation, and which small steps prepare for H1 and H2 while the
machinery is still being made rigorous.

## 1. What the "field hook" is

There is no general hook. Two spikes exist, each exposing one slice of the
sweep's adjoints for one purpose. Neither is merged.

- **The introduction hook** (`../measurements/perf-adjoint.md` §3.2, plant
  6613dd24).
  - It takes the shipped sweep one range at a time and reads the adjoint of the
    full state at every introduction row: λ_k, the value of a newborn by birth
    date.
  - Its rows satisfy exact identities: the adjoint of a node's initial mortality
    is −d_k, its direct share of J, to 1e-14.
  - It costs 1.01–1.05 shipped sweeps.
- **The field probe** (`../measurements/field-adjoint-map.md`, plant 7dbd87c3).
  - It adds one coefficient per (source panel, time band, channel). The
    coefficient is zero in the forward run, and scales a chosen defect added to
    the field: light at its knots, or soil depletion per layer.
  - The sweep's gradient in a coefficient is the field adjoint contracted with
    that defect, ⟨∂J/∂E, δE⟩, over that panel and band.
  - It predicted the field part of `J`'s change at 0.991–1.000×, and the
    invader's `lma` elasticity's field part at 0.94–0.99×.
  - It costs +12% of a sweep. With every coefficient at zero, results are
    bit-identical.
  - It is a directional probe: it answers "how much does this perturbation of
    the field matter", not "what is the sensitivity at every field element".

The sensitivity function S(z, a) of `frontier.md` needs more than the probe. The
invader reads the field as plain doubles, so its sweep differentiates nothing in
it. S needs the field values each evaluation reads to be inputs on the
invader's tape, with their adjoints collected per recorded slot.

## 2. Following the equilibrium: what it needs

**The design** (`../measurements/regnans-roadtest/rootcause/` §7; regnans PR
#89 has the algebra):
- The state is (θ, ln b), and the constraint is F = ln J − ln b = 0.
- The tangent is d ln b*/dθ = −F_θ/F_{ln b}.
- Each step is a predictor and one corrector run.
- The step length is set by the residual of F the gradient can tolerate: |F| <
  0.02 on long drought, from E5's dg/d ln b.
- Events along the curve:
  - a fold, where F_{ln b} → 0 (the edge of viability);
  - a singular point, where g = 0;
  - a change of sign in the invader's curvature, or in dg/dθ along the curve
    (branching or repelling).

**Does it change the adjoint implementation? No change is required.**
- F_θ and F_{ln b} come from one resident sweep: the trait columns and the
  birth-rate column, both built.
- g comes from an invader at θ′ = θ and its sweep, built.
- The derivative of g along the curve comes from chords: one more invader sweep
  at a moved θ or b.
- Worth checking before relying on chords: whether one sweep serves several
  invaders in one run on the #116 design. The old walk could not (`theory.md`
  0.3 lists it as needing the walked-patch fix).
- A second reverse pass over the resident's tape would give g without an invader
  run (an estimated 0.3 forwards). That is an optimisation, not a requirement.

**Does it change the scheduling algorithm? Yes, in three ways.**
1. **What it judges.**
   - The refine guarantees the resident's elasticities and chords.
   - Following the curve uses F, F_θ, F_{ln b} and the invader's g. The first
     three are resident quantities the refine already covers.
   - The invader's g is not covered, and converges differently: at 108
     introductions it is 5.4 ε off while ln J is 0.3 ε off (E2). The refine should
     judge g in the evolving traits, with its own ε (invader `lma` 0.20).
2. **Where it is built.**
   - The roadtest refined at a pilot's guess b₀. On constant rain that guess was
     36 times too low, and the grid had to be rebuilt.
   - Along a curve, the grid should be built once the first equilibrium is
     reached, then held.
3. **How far it holds.**
   - Following the curve needs a radius: how far in θ, and in ln b, the grid's
     bound holds before a rebuild. The refine returns a grid at a point, with no
     radius.
   - OBJECTIVES already asks for this ("Diagnosed": the distance from θ₀ against
     the grid's radius). The manifold makes it operational: the radius is the
     step-length limit and the rebuild trigger.

## 3. The adjoint as a price: should the representation hold it?

**Yes: as the dual of the recording, opt-in, and labelled by what it is the
price of.**

**Why it belongs in the representation.**
- A recording is rows: each step, the state it reached, and per evaluation slot
  the solved values and the field.
- A sweep walks those rows in reverse and computes, at every row, the adjoint of
  the state: the marginal value of each state component for the metric. It then
  discards them.
- Every analysis in `frontier.md` is a contraction of those adjoint rows with
  something:
  - the attribution of g by birth date, patch age and state: with ∂G/∂θ′;
  - the value of a newborn by birth date: with an introduction's map;
  - the field sensitivity S: with the field's inputs;
  - the schedule's error map: with a field defect;
  - tests of EEO criteria: with the leaf's controls.
- Today each of these needs its own spike. A recording that can keep its adjoint
  rows replaces them with one representation: the primal rows and their prices,
  aligned row for row.
- This is the domain's own structure. In demography the dual of the population
  state is reproductive value. In optimal control the costate is the price of a
  state.

**What it must say precisely, or it will be misread.**
1. **Whose price.**
   - An invader's adjoint, with the field held, is its own marginal reproductive
     value times survivorship.
   - A resident's adjoint, with the field responding, adds the externality on
     everyone else.
   - The same numbers mean different things, so a kept adjoint carries which
     sweep and which metric produced it (ln J or ln R′).
2. **Per what.**
   - A node's adjoint is per unit of that node's state, which is weighted by the
     node's density and quadrature weight.
   - Prices per individual divide those out. That is a derived view, not stored.
3. **Where.**
   - The discrete adjoint at step boundaries is the costate, to the scheme's
     order. Within a step, at stages, it is not.
   - At an insertion row the adjoint is wide above it and narrow below it. Both
     are meaningful: the wide one carries the newborn's value.
4. **Cost.**
   - One adjoint row per recorded row is about the size of the recorded states.
     Opt-in keeps the default sweep as it is.
   - Field adjoints add one value per field input per slot: about the field's
     share of a recording, 3.5%.

**Where it lives.**
- *odelia:* the sweep keeps the adjoint at each row it crosses, wide and narrow
  at insertions, when asked. This is generic and model-free, the same layer that
  walks the rows.
- *plant:*
  - field adjoints per slot, for invaders, with the field as an input on the
    tape;
  - the per-individual view, dividing out density and quadrature weight;
  - the R accessors.

**How it is checked**, each an exact identity or an independent measurement:
- **Sum rule.** Contracting the adjoint rows with ∂G/∂θ′ and summing reproduces
  the sweep's g.
- **Mortality identity.** The adjoint of a node's initial mortality is −d_k.
  This already passes on the introduction spike.
- **Injection.** Perturbing one state component at one row, by a replay, changes
  the metric by the adjoint times the perturbation.
- **Field contraction.** Predicting the field part of a grid change, as the
  probe did at 0.99–1.00×.
- **Envelope theorem.** Freezing the leaf's operating point leaves the invader's
  g unchanged (`theory.md` C.4).

## 3a. What field sensitivities require

**What S is.**
- S is ∂ ln R′/∂(field) for an invader reading the resident's recorded field.
- In the code, each rate evaluation reads a `recorded_field` (`patch.h`): the
  light interpolant's knots, values and slopes over height, and the soil water
  per layer. There are six per step, in `field_row`.

**Why it is absent.** An invader installs the field from doubles
(`Patch::compute_environment`, the `field_run` branch: `r_init_interpolators`,
`set_ode_state`). On its tape the field is a constant.

**Two ways to get it.**
- **A, banded S through coefficients (plant only).**
  - Zero-valued coefficients appended to `ad_parameters()`, one per band: light
    by height band × patch-age band, and soil water by layer × patch-age band.
  - Each scales the installed field in its band by (1 + c).
  - The sweep's existing parameter gradient returns them beside the trait
    columns, as elasticities d ln R′/d ln(field in band).
  - This is the field probe's mechanism (`field_probe.patch`: +12% of a sweep,
    bit-identical at zero), without its node-defect logic.
- **B, per-slot S: the field adjoint row (plant and odelia).**
  - The installed field values become tape inputs at every evaluation, and their
    adjoints are read after each step's reverse pass.
  - This needs a generic odelia hook for per-step inputs. It is the dual of
    `field_row`, and belongs with the adjoint-rows spike.

**What either needs to be trusted.**
1. **The direct check.** An invader in a given field is an exact function of it.
   Scaling one band by 1% and rerunning the invader tests S's prediction exactly
   and cheaply.
2. **The same quadrature guarantees as g,** since S is a sum over the invader's
   introductions.
3. **One-sided values at the kinks:** the light floor, and the leaf's regime
   switches.
4. **Impacts alongside sensitivities.**
   - S's own singular spectrum depends on the units and banding of field space.
     The basis-free object is Meszéna's pairing, A_ij = ⟨S_i, I_j⟩, of invader
     sensitivities with resident impacts.
   - A resident's impact on the field, with respect to its abundance, is the
     difference between two recorded resident fields at b* e^{±0.03}.
   - The resident's own ⟨S, I⟩ must equal F_{ln b} (I3; −1.75 on long drought).
     So the check and the science quantity are one calculation.

Route A plus impacts is enough for the H1 and H2 pilot and the I3 check. Route B
follows if the adjoint-rows spike shows the dual representation is clean.

## 4. Spectral structure is easy at the scale H1 and H2 need

- `frontier.md` §4.4 described matrix-free spectra. Those are needed only for
  spectra over all 50 traits' second derivatives.
- H1 and H2 need the spectrum of a library of sensitivity functions: S for about
  twenty strategies. That is a thin matrix, twenty columns of field length.
- Its singular values come from the 20 × 20 Gram matrix of inner products, which
  is ordinary linear algebra.
- Coarse-graining the field into patch-age bands and channels (light by height
  band, water by layer) keeps the vectors interpretable and the cost trivial.

## 5. Small steps, rigour first

Each step stands alone and is useful even if H1 and H2 come to nothing.

1. **Settle the run's accuracy and cost.**
   - Rerun E2 at an absolute tolerance of 1e-4. This decides whether a run costs
     48 s or 77 s on long drought.
   - Measure TF24's sweep against a run on regnans's footing. This answers the
     premise of regnans PR #87.
2. **Bring the invader's g under the scheduling guarantees.**
   - Apply the nudge tests to g in all traits on two or three climates: `tol`
     ±5%, introductions moved by a quarter of their spacing.
   - Add g in the evolving traits to the refine's judged set.
   - Have the refine return a radius.
3. **Keep the adjoint rows (odelia, opt-in).** Checked by the sum rule, the
   mortality identity and injection. This replaces the introduction spike.
4. **Field adjoints for invaders (plant).** Checked by field contraction and the
   envelope test. This replaces the field probe.
5. **A pilot for H1 and H2.**
   - Compute S for five strategies along `lma` (× 0.5 to × 2) on long drought and
     on episodic, coarse-grained into bands.
   - Look at the Gram spectrum.
   - This shows whether the field's effective dimension is small, and whether
     variability changes it, before any larger library is built.

Following the equilibrium waits on steps 1–2, and lands through regnans #89.
