# Assembly on a consumer–resource example

The worked example of the assembly report (`docs/review/assembly-report.html`). It is
MacArthur competition for d resources with k = 50 traits:
- x places a species' uptake on the resource axis;
- v scales uptake at a cost;
- 48 physiological traits w have an optimum fixed by x.

Every quantity has a closed form, so the algorithms can be checked against algebra.

```
Rscript spikes/assembly-example/assembly.R > spikes/assembly-example/assembly.txt
```

Base R, about 4 minutes; almost all of it is the one-shot route's 2,000-step pair.
`assembly.txt` is the output.

## Primitives

All routes call two primitives, and the script counts both:
- **`resident()`** stands for one taped run of the residents. It returns:
  - the field;
  - each resident's F, g (the field cut) and S (the adjoints the cut zeroes);
  - ∂R/∂N and ∂R/∂θ (the sweeps).
- **`invader()`** stands for one invader evaluation in a held field.

`curvature()` stands for k probes of the invader gradient. It is counted as k evaluations.

## Routes

| route | d = 2 (vs hand algebra) | d = 3, unequal supply |
|---|---|---|
| lean: column generation, one rank-d complementarity problem per pass | 9 resident runs, 2,674 invader evaluations; exact to 3.5e-14 | 27 runs, 5,456 evaluations; 3 species |
| one-shot (`field-cut.md`): to the branching point, split, the pair | 2,182 runs; pair unconverged after 2,000 steps (\|g\| 9e-4) | — |
| FitMax with Newton equilibria, residents not evolved | 20 runs; residents off their peaks (\|g\| ≈ 1) | 20 runs; 2 species, \|g\| ≈ 1 |

The FitMax route is a mock of regnans's default. Its birth threshold and copy rule are
assumed, not read from regnans.
