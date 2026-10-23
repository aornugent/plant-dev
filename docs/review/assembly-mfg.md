# Assembly as a mean-field game

**Status.** A proposal, not built.
- **Derived from** TF24's rates (`plant/inst/include/plant/models/tf24_strategy.h`,
  `compute_rates`, `net_mass_production_dt` and the shading aggregation) and from the reverse
  mode we already have.
- **Being built:** the reference community it must be checked against
  (`spikes/reference-community/`, in progress).
- **Being measured:** the leaf profile it depends on (`spikes/leaf-table/`, in progress).
- **Builds on:** `assembly-geometry.md` §4b–4c (the duality between niche and field, and
  response conservation).

**The claim.**
- The ESS community is the equilibrium of a mean-field game on the plant's own state space,
  height × patch age, coupled through the field.
- **A backward sweep prices every strategy at once,** and a forward sweep makes the field.
  Species are the distinct optimal paths through that space.
- **The cost scales with the grid,** not with species × traits.
- **Plant's resident run, cut sweep and g** become the game's exact components, so they serve
  as the corrector, not the solver.

## 1. The inner loop: one plant in a held field

The individual state has six variables: height, mortality, fecundity, heartwood area,
heartwood mass and storage. Mortality and fecundity are accumulators, so four drive the
dynamics. At each rate evaluation:
1. **The field enters through a small local environment:**
   - the crown's leaf-area-weighted mean light, L̄(h, t) = ∫ light(z, t) q(z | h) dz (the default
     mean-light model);
   - the soil water potentials ψ(t), one per layer.

   Climate drivers (VPD, CO₂, leaf temperature) are exogenous and shared.
2. **The leaf solves an inner hydraulic profit optimisation** at (L̄, ψ, climate). It returns net
   production per leaf area P, and transpiration by layer.
3. **Everything else is demography given P:**
   - growth flux P⁺·G(S/S_max), split by height between growth and reproduction;
   - heartwood turnover, which runs regardless of carbon;
   - storage as a first-order filter on production;
   - mortality from relative reserves.

**Unrolling the reverse mode.**
- Along each cohort, the costates λ(t) are reproductive values. The field adjoint the cut
  zeroes is

    S(z, t) = Σ_cohorts w_c λ_c(t) ∂rates/∂L̄ · q(z | h_c(t))  (plus the analogous water term).

- **A strategy's niche is its reproductive-value-weighted crown profile along its own growth
  trajectories,** a corridor through (height, patch age). The few corridors a field offers are
  why d is small (≈ 3 open, ≈ 4–5 closed, `spikes/field-dimension-066/`).
- **The traits do three things.** They fix a policy (how production splits between growth and
  reproduction as a function of height), a production surface (the leaf traits), and an
  allometry. In a held field, the costates are the value of being at height h at age a under
  that policy:
  - the resident's reverse pass is a backward value sweep for a fixed policy;
  - the cut is "hold the mean field".

**Leverage at the level of the inner loop:**
- **Leaf traits act only through P(L̄, ψ),** so a table over light × soil water could replace
  the live optimisation everywhere. This is being measured.
- **Invader cohorts are independent once the field is held,** and so is the cut sweep. One
  evaluation parallelises by cohort, which shortens pricing's critical path.

## 2. The outer loop

Drop the fixed policy for the best-response step and ask for the best policy over the plant's
own state in the field: a backward dynamic program on a height × patch-age grid,

  V\*(h, a) = max over growth and reproduction [ reproduction now + survival · V\*(h′, a + Δa) ].

- **One sweep prices every strategy.** The maximum over birth ages of V\* at the seedling is
  the best invasion fitness available in that field: Ψ(y) of the duality, computed by a sweep
  instead of a search over traits.
- **The forward sweep:** plants following the optimal policy give a density over (h, a). Its
  leaf area by height gives the light field by Beer–Lambert, and its uptake by layer the water
  field.
- **The ESS community is the fixed point of the two sweeps.** That is a mean-field game
  (Lasry & Lions 2007; Huang, Malhamé & Caines 2006): backward value, forward density, coupled
  through the field.
- **The fixed point lives in field space,** of dimension d, so damped fictitious play or Newton
  with the field Jacobian applies.
- **Species are not an unknown.** Where V\* ties across paths, the equilibrium population splits.
  The number of species is the number of distinct optimal characteristics, at most d.
- **Traits are not searched.** Each corridor's policy is projected onto TF24's traits by one
  local fit per species.

**Earlier results in this frame:**

| Earlier result | In the game |
|---|---|
| Ψ(y), the conjugate and the atlas (`assembly-geometry.md` §4b) | V\* at the seedling in field y; the atlas becomes a sweep per field point |
| stable games, convexity, Chesson's stabilisation (§2) | Lasry–Lions monotonicity: a unique equilibrium, and fictitious play converges |
| response conservation (§4c) | corridors fixed while supply rescales densities, until one is abandoned |
| the site residual and the Fenchel–Young gap | the gap in policy space between an observed trajectory and the optimal policy of V\*(h, a; E_site) |

## 3. What needs what

| Role | Done by | Exact? |
|---|---|---|
| discovering corridors; a global bound on invasion fitness | the dynamic program on a reduced plant | approximate: a relaxation |
| the best response | ascent over function-valued policies: allocation as a curve π(h), one TF24 invader run plus adjoint sweep per step, ∂ ln R′/∂π(h) at every height at once | exact, but local |
| field consistency | resident runs | exact |
| certification | the cut on a held, certified schedule | exact |

**A reduced plant is needed only for the dynamic program.**
- TF24's state is not Markov in height alone: heartwood follows the leaf-area history, and
  storage follows recent production, slowly in drought.
- The reduced plant only proposes corridors and bounds. It never sets the answer.

**The function-valued policy needs a plant change:** allocation taken as an input curve over
height. Only doubles cross the R boundary.

## 4. What it makes hard, by construction

1. **The relaxation gap.** A flexible policy can do what TF24's parametric family cannot:
   condition on patch age, change leaf traits through life. The game's community is
   optimistic, an upper bound on invasion fitness. Restricting the policy to feedback on height
   narrows the gap but turns the best response into a policy shared across birth ages.
2. **The reduced plant must reproduce TF24.** Storage may need its own dimension in long
   droughts.
3. **Leaf traits become a menu of production surfaces:** a finite set of table entries, or a
   low-dimensional family.
4. **Water's daily forcing makes the patch-age grid fine.**

## 5. Tests, in order

1. **The leaf profile and table** (`spikes/leaf-table/`, done 24 Oct, closed canopy):
   - **The leaf optimisation is 91% of a TF24 run.** One invader evaluation makes 1.5 M leaf
     solves at 8.8 µs, 71% of it in the root-collar potential's root-finder.
   - **Soil compresses to two numbers:** the top layer and a conductance-weighted mean of the
     deeper ones. Error in P is 0.004 rms, against 0.29 for one weighted mean.
   - **A table cannot replace the leaf where the answer must be exact.** The finest table
     (32 × 32 × 16 × 32, 0.1% rms in P) still moves ln R′ by −0.007 to −0.86, because its small
     bias meets a large sensitivity, ∂ ln R′/∂ ln P of 49 to 7.6e3. Holding 1e-3 needs P's bias
     below about 1.6e-5 relative.
   - **The table suits the approximate roles:** the reduced plant's production for the dynamic
     program, and screening invader signs where |ln R′| is well above 0.05. It would make an
     invader 5–10× faster.
   - **The exact route:** seed the root-finder from a small table of the solved potential, an
     estimated 2–4× with P exact.
   - **`run_mutant` re-runs the resident at every call,** re-solving every leaf: 4.1 M solves,
     about 39 s of each call's 54 s. Replaying the resident's recording instead would be the
     largest single saving for pricing.
   - **One case needs looking into:** the closed-canopy identity invader's ln R′ moves 0.07 for a
     1e-5 change in P. Fitness that sensitive near break-even affects every method here.
2. **The first TF24 reference community** (`spikes/reference-community/`, in progress). A
   singular strategy in lma, rho and vcmax_25 on the closed canopy, by the one-shot step with
   the cut on a held schedule; classified by H and J; the coalition if it branches. Nothing like
   it exists yet: regnans's plant singularity tests are FF16, and the roadtest only projected a
   one-trait case.
3. **The reduced plant:** does it reproduce the 48-invader pool's ln R′ in recorded fields to
   about 0.05? If not, the dynamic program is out, and the exact function-space best response
   carries the game alone.
4. **The dynamic-program bound on recorded fields** against the pool's best invader in each
   field: its tightness, and whether its corridors match the winners (strategies 9 and 28).
5. **The game's fixed point against the reference community:** traits after projection, field,
   species count, and the corrector runs needed.
