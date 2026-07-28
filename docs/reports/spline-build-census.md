# Light interpolant build census

Counters on `ResourceSpline::compute_environment` (plant at develop `96941d3b`),
reported to stderr on process exit when `PLANT_SPLINE_STATS` is set. Report 03
section 5.5 records the measurements.

Add to `inst/include/plant/resource_spline.h`: two call counters and two elapsed-time
accumulators, incremented in the two arms of

```cpp
if (rescale & spline_rescale_usually) { rescale_spline(...); }
else                                  { construct_spline(...); }
```

plus the knot count after each build, dumped from a static object's destructor.

Measured, TF24 `max_patch_lifetime = 105.32`, 2 829 accepted steps, 59.5 s run:

| path | calls | total | per call | knots |
|---|---|---|---|---|
| `construct_spline` | 144 | 0.021 s | 143.0 us | — |
| `rescale_spline` | 20 160 | 3.895 s | 193.2 us | 65 |
| both | 20 304 | 3.916 s (6.6% of the run) | | |

The 7.13 ratio of rescales to accepted steps is the Runge-Kutta stage multiplier:
`Patch::set_ode_state` rebuilds the field at every stage because the field depends on
state.

Same build caveat as the leaf census: develop's plant does not compile against the
installed odelia without `PKG_CPPFLAGS += -include XAD/XAD.hpp`, because
`odelia/ode_util.hpp` reaches `xad::value` with no XAD include.
