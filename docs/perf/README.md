# What a stand gradient costs

The reverse sweep over a century stand costs about **2.3 times** what the same
fixture cost at the pre-merge triple, and this directory is the measurement
that says where. Read it before proposing a performance change to the leaf or
the tape: five plausible mechanisms are refused below with the measurement that
refuses each, and two more were fixed and are gone.

⚠️ **Every number here is the same fixture.** A figure taken on another stand
is not comparable, and the ratio in particular is understated by a short one --
the field build is O(knots x cohorts), so anything scaling with cohort count is
invisible until the stand is long. The fixture is
`scripts/forward-century-schedule.rds`, transplanted by
`scripts/profile-stand-reverse.R`: one species, `max_patch_lifetime` 105.32,
169 nodes, 3378 accepted steps.

⚠️ **These counts must match, or two runs are not doing the same work** and no
comparison between them means anything: `rate_evaluations` 20268, `placements`
2330530, `swept_ranges` 169, `metrics` 3, recordings swept 3548, `refusal` none,
`keeps_states` TRUE. They were identical across every state measured here,
which is what makes the wall-clock differences attributable at all.

## Where it stands

| state | gradient | tape statements | per placement |
| --- | --- | --- | --- |
| pre-merge triple | 124.14 s | 3,391,426,386 | 1455.22 |
| before the two changes below | ~415 s | 8,140,296,822 | 3492.90 |
| **current** | **~286 s** | 8,140,841,678 pushed, 4.46e9 surviving | 1912.30 surviving |

Two factors multiply, and separating them is the whole point: statements grew
**2.40x** and the cost of each grew about **1.39x**, which is the 3.34x the
wall clock showed. The second factor is not a mystery to chase -- a tape that
grew mostly in statement COUNT costs more per unit of arithmetic, because
slot issuing and chunk crossing are charged per statement whatever its operand
count. Operations per statement fell 1.659 to 1.358 across the same interval.

The pre-merge triple is superproject `b457864b`: plant `c085582d`, odelia
`fec3b00d`, phylloptim `33e00485`. ⚠️ The merge itself, plant `5bde7727`, **does
not build** against either its own pins or newer siblings, and no superproject
commit records the seven commits after it -- so the interval `c085582d ..
c49da429` cannot be narrowed by measurement.

## What was fixed

**The seed's slope, plant `4646febe`.** `seed_geometry` closes the implicit
function theorem on `height_0`, and it took the slope by rebinding the whole
strategy to a tangent. A rebind CONSTRUCTS one, and constructing a
`TF24_Strategy` constructs its `Leaf`, whose constructor builds two
vulnerability curves at an incomplete gamma per knot, 400 knots each --
which `assign_from` then overwrites with `leaf = src.leaf`. On the
rate-evaluation path that ran about a hundred thousand times a gradient: 82.4 s,
21.6% of the gradient, and 100% of the long-double `pow` in the profile.
`prepare_strategy` takes the tangent once now. **Interleaved: 87.03 s, 23.3%.
All 138 gradient entries bit-identical.**

**The leaf's rows, phylloptim `44caeb9`.** The five `odelia::implicit_value`
sites used the three-argument overload, which leaves the residual on the
caller's tape for the outer sweep to walk once per output. They pass their
inputs now, so odelia sweeps each residual once locally and rewinds it. This
does NOT record less -- pushed statements moved by +0.0067% -- it stops the
outer sweep walking 1580.83 statements per placement. **Interleaved: 52.9 s,
12.7%. Worst entry moved 2.6e-11, below the leaf solver's own ~1e-9 floor.**

⚠️ `SupplyDraw` had to gain `for_each_active` for that. A shape
`odelia::ode::visit_active` cannot open is skipped in silence, and here that
arrives as an exact zero in a gradient column rather than as an error.

## Where the remaining time is

`docs/perf/values/statements-by-region.txt` attributes the +2037.68 statements
per placement across the three calls of the leaf boundary in
`TF24_Strategy::record_leaf_outputs`. The regions sum exactly to the recording
total, and the per-placement deltas sum to the established figure.

| region | pre/placement | before/placement | delta | share |
| --- | --- | --- | --- | --- |
| `supply_draw_at` | 214.32 | 144.80 | **-69.53** | -3.4% |
| `collar_at` | 118.81 | 1554.42 | +1435.61 | 70.5% |
| `outputs_at` | 88.62 | 775.22 | +686.60 | 33.7% |
| rest of the recording | 1033.46 | 1018.46 | -15.00 | -0.7% |

`Leaf::collar_coords_at` -- the nested `implicit_value` solves for sigma and ci,
called once per placement from each of `marginal_at` and `profit_at` -- went
**29.99 to 608.94 statements a call**, and alone is **68.2%** of the growth.
Every placement on this fixture is Interior, so the `bound_at` branches never
run and all of `collar_at` is the interior closure.

The supplied-rows change collapses `collar_at` to 1.20 statements a placement
and leaves `outputs_at` at 747.61, because `profit_at`'s result feeds the
objective and cannot be rewound. So `outputs_at` is now the whole remaining
excess, and `collar_coords_at` is the whole of `outputs_at`.

⚠️ **THAT GROWTH IS THE PRICE OF A CORRECTNESS FIX, NOT WASTE.** The residuals
hold the collar passive (`const S held(to_passive(collar))`) and the collar's
response is supplied as an analytic slope beside each value -- `CollarCoords`
carries a value-and-slope pair per coordinate where it carried a bare scalar.
Letting the residual see a live collar puts two values of dsigma/dcollar into
one object: measured, the lift said 0.6913 for dci/dcollar where the slope
beside it said 0.6382, and dM/dcollar came out an eighth of its size. Deleting
the slope block restores that defect. The lever is to compute those slopes
without recording them, not to stop computing them.

**One narrow thing is actionable without a model decision.** At the pre-merge
triple the assimilation slope A' came from a TAPELESS TANGENT through the same
kernel the residual calls (`assim_colimited_kernel<tangent>` with
`derivative_along`). It is now `assim_slope_at<S>` at the active scalar --
a second definition of one function, free to disagree with it while staying
finite, which is the substitution `phylloptim`'s own `leaf_model.hpp` forbids.

**The harder half needs a model decision.** `V` and `dci_dp` multiply
`step = collar - held`, so unlike `implicit_value`'s `dF/dy` -- whose own trait
dependence is second order and is correctly a `double` -- their trait rows enter
at first order. Which of those rows are real is a question about the model. The
anchor idiom already in that function (`S(value) + (recip - S(to_passive(recip)))`)
is the shape of a fix: supply the value at `double`, attach only the rows wanted.

## Refused, with the measurement that refuses it

| proposal | why not |
| --- | --- |
| the vulnerability curve's resolution grew | `ncontrol_default` went 1600 to 400, a 4x reduction |
| the schedule change added ranges to sweep | one row per instant BATCHES introductions, and the fixture is one species |
| `Internals` became a template | it was already templated at the pre-merge triple |
| the uptake path went from `double` to active | the pre-merge triple ran `uptake_impl<T>` at the active scalar too; the `uptake_impl<double>` that went was `uptake_at`, the R-facing probe. `supply_draw_at` now records 69.53 statements a placement FEWER |
| XAD or its storage flags changed | vendored `inst/include/XAD/` is byte-identical across the merge, and `XAD_NO_THREADLOCAL` / `XAD_USE_STRONG_INLINE` are unchanged in both packages |
| more of the leaf runs at the active scalar | functions templated on `T` FELL, 48 to 35 in `leaf_model.hpp` and 13 to 6 in `roots.hpp` |
| preaccumulate the whole leaf region | odelia has the primitive and its rule is that it pays when the consumer sweeps more often than the region has outputs. The leaf has six outputs, the stand seeds three metrics. Measured at 2544 walks against 1440 inline |
| the slot high-water mark is the hidden cost | `resetTo` does not lower `maxDerivative_` and `XAD_TAPE_REUSE_SLOTS` is off, so the derivative array stays sized by the peak -- measured, 19.3 s, 5.1% |
| `promote_double<false>` on the incomplete gamma | 3.97x faster and it MOVES THE SCIENCE: 135 of 138 entries, worst 6.707e-03 relative, against a base-vs-base control of 0.000e+00. 88 of them exceed 1e-4 |

⚠️ **The gradient amplifies a rounding change by about thirteen orders.** A
1-5 ULP change at a curve knot (~7e-16) reaches 1.271e-10 at a solved leaf
operating point and 6.707e-03 at the census gradient. The gradient suite is
blind to it -- it passed `pass=684 fail=0` while 135 of 138 entries moved --
because the one test carrying a captured reference compares a difference of
whole runs at a 2e-3 floor on its own fixture. **So a value comparison against
`values/current.tsv` is the guard, and the suite is not.**

## Reproducing

`values/` holds the 138 gradient entries at `%.17g` for three states:
`before.tsv`, `after-supplied-rows.tsv`, and `current.tsv`, which is plant
`4646febe` + phylloptim `44caeb9` + odelia `307428f`. The three differ only in
the two lines naming `forward_s` and `gradient_s`, so the values are
reproducible run to run and a diff of the `G` lines is exact.

```sh
R_LIBS="<your lib>:$(Rscript -e 'cat(paste(.libPaths(),collapse=":"))')" \
  OPENBLAS_NUM_THREADS=1 MODE=values ARM=mine \
  Rscript docs/perf/tools/century-gradient.R > /tmp/mine.txt
python3 docs/perf/tools/compare-gradient.py docs/perf/values/current.tsv /tmp/mine.txt
```

The comparator counts finite entries before comparing any value, because
`identical(NaN, NaN)` is TRUE in R and a bit-identity check otherwise passes
against an all-NaN gradient. It reports DROPPED ROWS separately -- an exact zero
where the reference is non-zero -- because that, and not a wrong number, is what
a missing supplied row looks like.

`MODE=time` on the same script reports the four counts beside the timing.
⚠️ Interleave the arms in one sitting: absolute seconds drift 10-30% between
sittings, and `forward_s` is the control -- it held to 1.8% across the pairs
quoted above.

`tools/tape-counter.patch` counts tape statements, which is the quantity that
decides whether a change records less or merely sweeps less. XAD exposes
`getNumStatements()` and `getNumOperations()`, but the recordings are taken
inside odelia and plant never sees the return -- so the patch shadows the
INSTALLED `odelia/adjoint.hpp` into `plant/src/tapeshadow/` and adds
`-Itapeshadow` to `plant/src/Makevars`, which wins because R places
`PKG_CPPFLAGS` before `LinkingTo`'s include path. ⚠️ `resetTo` TRUNCATES the
counters, so on any build that rewinds, a counter read at the end of a transpose
reports what SURVIVED and not what was pushed; tally the rewinds too or the two
sides are not like for like.

⚠️ **Rebuild deliberately.** `R CMD INSTALL --preclean` was observed rebuilding
3 of 25 objects after a header edit, reporting `DONE`, and leaving 22 objects
compiled against the old header. `rm -f src/*.o src/*.so` first, and count the
compile lines: a real plant build prints about 25 and every one should end at
`-O2` with no `-O0`.
