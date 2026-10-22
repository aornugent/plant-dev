# The field cut: g from the resident's own tape

A toy that proves the claim of `docs/review/assembly.md` §2: one recording of the resident,
swept twice, gives F_θ (field kept) and g (field cut). g equals the invader's gradient at
θ′ = θ, bit for bit. `one_shot` then uses that recording to find singular strategies without
an equilibrium loop (`docs/review/field-cut.md`).

```
make CXX=g++ ODELIA=/home/a/dev/plant-dev/odelia && ./field_cut && ./one_shot
```

`toy.hpp` holds the stand (m species) and the cut sweep. `one_shot.txt` is `one_shot`'s output
(about 10 minutes, almost all of it the nested iteration on two species).

`ODELIA` points at an odelia checkout (this worktree's submodule is not initialised).
`CXX=g++` because the environment's default compiler is not installed. The Makefile compiles
odelia's `src/Tape.cpp` with odelia's flags.

## The toy

- 24 cohorts; 480 fixed RK4 steps; 1,920 field builds; 1.08 million tape statements.
- Traits: growth, shade mortality, allocation to reproduction, leaf area; and ln b.
- Each cohort has height, log survival and cumulative offspring. Soil water W is its own ODE
  state.
- The field at each rate evaluation: each cohort's shading density (carrying b), its height
  (a copy), and W as read. Light at z is exp(−k Σ D_j σ((H_j − z)/ε)).
- Output: F = ln J − ln b.

## Result (22 Oct, rerun from a clean build)

| input | F_θ (field kept) | g (cut) | g (invader) | cut vs invader |
|---|---|---|---|---|
| growth | −0.302 | 19.69 | 19.69 | 0 |
| shade mortality | −0.157 | −2.081 | −2.081 | 0 |
| allocation | 3.851 | −30.41 | −30.41 | 0 |
| leaf area | −0.251 | 6.996 | 6.996 | 0 |
| ln b | −0.699 | 0 | — | — |

- **Finite differences** agree with both routes to 1e-8–1e-10 at a step of 1e-7.
- **ln R′(θ′ = θ) = F** exactly.
- **The adjoints zeroed by the cut** are the invader's d ln R′/d(field) for all 67,559 field
  values, to 0. The field hook comes free.
- **Step by step** (one recording per step, as odelia sweeps), the results agree with the
  whole tape to 1e-15.
- **Cost:** stepwise, the cut pass costs 0.99 of the kept pass. The invader route costs
  4.6–5.4× a cut pass.

## The mechanism

1. **While recording,** after each field is built and before any read, store
   `tape.getPosition()` and the field values' slots.
2. **Pass 2:** for each mark, last to first: `computeAdjointsTo(mark)`; read, then zero,
   `tape.derivative(slot)`; `resetTo(mark)`. Finish with `computeAdjoints()`.

This is the pattern odelia's `implicit_value` already uses
(`inst/include/odelia/implicit_node.hpp`). Pitfalls:

- **The cut pass consumes the recording.** Without the truncation, swept statements are
  re-walked and g is NaN. So the cut sweep is a recording's last; odelia clears the tape every
  step anyway. A public sweep between two positions in XAD would lift this.
- **The mark must sit after the field's last definition and before its first read,** and must
  list everything readers touch.
- **A reader keeps its own position;** only the field's values are cut.

## One recording per evolutionary step (`one_shot`)

A leaf cost on the leaf-area trait (`Setup::leaf_cost`, 0 in `field_cut`) gives an interior
singular strategy. Allocation and leaf area evolve; the routes are compared to |F| < 1e-10,
|g| < 1e-8:

| route | one species | two species, split at the branching point |
|---|---|---|
| nested, iteration ln b ← ln b + F | 280 runs + 13 recordings | 19,080 runs + 48 recordings |
| nested, Newton on taped ∂F/∂ln b | 46 recordings | failed: ∂F/∂ln b near-singular after the split |
| one recording per step, b predicted along δθ by F_θ | **14 recordings** | **47 recordings** |
| the same without F_θ | 62 recordings | — |

- The routes agree to about 1e-8.
- The one-species point is a convergence-stable branching point.
- One cut sweep of F₁ + F₂ gives both species' g, equal to each invader's to 0.0.

For what plant and odelia would change (`patch.h`'s `compute_environment`, a field-value
visitor, cut seeds in odelia's sweeps), see `docs/review/assembly.md` §7.
