# FF16 adjoint cost (traitecoevo/plant#677): spikes

The FF16 reverse pass divided by its own forward run, for one species. The
middle columns are callgrind instructions per step at `max_patch_lifetime` 8.
The seconds column is the median of three runs at lifetime 30, interleaved
against B in one sitting.

| arm | ratio, 1 metric | ratio, 5 metrics | seconds, 5 metrics |
| --- | --- | --- | --- |
| A: develop, odelia 0.7.3 | 24.7x | — | — |
| B: plant#679, odelia 0.8.0 | 14.5x | — | 0.837 s (27x) |
| + plant 1: fold the crown shape | 10.8x | — | — |
| + plant 2: stop recording copies | 9.6x | — | — |
| + plant 3: two statements per crown node | 8.7x | 16.4x | — |
| + odelia 1: 12-byte operations, one clear per walk | 8.0x | 14.6x | — |
| + odelia 2: no `memmove` per statement | 7.5x | 14.1x | — |
| + odelia 3: a cubic's slope read at its value | 7.3x | 13.6x | — |
| + odelia 4, plant 4: move stage states | 7.2x | 13.4x | — |
| + odelia 5, plant 5: move knot data into the spline | 7.0x | 13.0x | — |
| + plant 6: one statement per half of a competition read | 6.7x | 12.3x | — |
| + odelia 6, plant 7: fewer field statements | **6.6x** | **12.0x** | **0.350 s (11x)** |

The double forward run is identical in every arm from B down: same values, same
step counts. Two kinds of change:

- **Odelia 1–4 and 6** only reorganise how the tape is stored or swept. The
  gradient is bit-identical to the arm above.
- **The plant patches and odelia 5** remove recorded copies, which changes the
  order adjoints are summed in. Against B, every entry stays finite and none
  drops to zero; the worst relative change is 2.6e-12.

Test files, each run on B and on the spike stack, with identical failure sets:

| suite | tests | failures | the same on B |
| --- | --- | --- | --- |
| odelia | 127 | 0 failed, 12 errors | yes: upstream's steady-state `sourceCpp` helpers do not compile |
| plant gradient, ladder, census, fitness and FF16 files | 160 | 3 | yes |
| plant strategy, canopy, patch, species, node and environment files | 171 | 2 | yes |

## Second round, at a representative fixture

⚠️ **Measure at lifetime 60, not 8.** At lifetime 8 the tallest FF16 plant is
about 1.2 m and the seedling about 0.39 m. A gradient run with a debug print
showed the seedling at 82% of the canopy top on average over all 881 rate
evaluations, so any lever that depends on canopy structure looks smaller
there than it is. The issue measured lifetimes of 8, 30 and 60. A probe
evaluated at one state, such as the end of a run, also misleads: weight the
evidence by the run.

Callgrind instructions per step and interleaved seconds, at lifetime 60:

| arm | ratio, 1 metric | ratio, 5 metrics | seconds, 1 metric | seconds, 5 metrics |
| --- | --- | --- | --- | --- |
| B | 14.5x | 29.5x | 0.56 s | 1.04 s (26x) |
| R12: the first round, plus plant 8 | 6.3x | 11.7x | 0.25 s | 0.41 s (10.7x) |
| **H2: + plant 9, odelia 7** | **5.8x** | **9.6x** | **0.22 s** | **0.33 s (8.8x)** |

- **Plant 8 comes from a liveness pass** (`tools/live.cpp`). It walks one
  evaluation's tape backwards from the rates and marks each statement dead or
  live, and live statements that depend on parameters alone. It found three
  things to fix:
  - a height above a crown recording zeros scaled by active factors
  - the height scan copying every node's height two or three times
  - the field without the boundary interval being built in full, although only
    the seedling reads it, at its own height
  Gradients are bit-identical.
- **Plant 9 supplies the crown integral's rows**, through odelia's own
  `record_with_derivatives`. The rows are computed in double, using odelia 7's
  `read_linear`, which returns a light read as its span's four coefficients
  and their weights. This is a hand-written adjoint of the leaf rate only; the
  spline's linear form stays in odelia. Values are bit-identical, rows move at
  rounding level, and plant's finite-difference FF16 gradient tests pass.

**Knot rows** (plant 10, odelia 8) put the crown's rows on each knot's value
and slope rather than on each span's four coefficients. Neighbouring spans
share a knot, so the rows roughly halve. At lifetime 60 the ratio goes from
5.82x to 5.75x for one metric and from 9.64x to 9.45x for five, and the sweep
per metric from 2.14M to 2.07M instructions per step. The span coefficients
are now read by nothing on the tape, so their 255 statements per evaluation
are recorded and dead. Removing them would mean `hermite_spline` deriving its
active coefficients from the knots rather than storing them.

**Field rows** (plant 11, odelia 9) supply the rows of `field_splits`, the
reduction that builds each knot's competition from the moment prefix sums. Each
knot's value and slope become one statement each, with rows on the prefix sums,
the height, and the two ends of the interval the crown crosses. The height's
row on the slope needs the weights' second derivative,
`CanopyShape::height_weight_curvatures`. Field statements fall from 2641 to
1811 per evaluation.

⚠️ **The first build of this was slower than the one before it** (6.35x for one
metric, against 5.75x). The rows were fine. The cost was in how they were
gathered: `push_back` onto a function-local `static std::vector` is not inlined,
because the compiler cannot see the capacity. That cost 199M instructions in
`emplace_back` alone, in the crown and in odelia's own gather. Writing by index
into scratch that is resized once removes it. odelia 9 also takes the rows as
two parallel arrays (`const S*` and `double`), which a caller can keep between
calls; a list of `input_and_derivative`, which holds references, cannot be
kept.

At lifetime 60:

| arm | ratio, 1 metric | ratio, 5 metrics | seconds, 1 metric | seconds, 5 metrics |
| --- | --- | --- | --- | --- |
| B | 14.5x | 29.5x | 0.55 s | 1.05 s |
| K: knot rows | 5.75x | 9.45x | 0.238 s | 0.343 s |
| **G2: + plant 11, odelia 9** | **5.50x** | **8.88x** | **0.208 s** | **0.321 s** |

The seconds are medians of three interleaved rounds (`tools/wall2.R`). The
forward run takes about 0.040 s, so G2 runs at about 5.2x for one metric and
8.0x for five. Values are bit-identical to K, and the gradient's worst
relative change against B is 2.3e-12. The test files give the same failure
sets as B.

Multi-species stands at lifetime 60, one interleaved run each:

| species | forward | all metrics, K | all metrics, G2 | per metric, K → G2 |
| --- | --- | --- | --- | --- |
| 1 | 0.04 s | 0.333 s | 0.323 s | 0.029 → 0.022 s |
| 2 | 0.08 s | 0.789 s | 0.749 s | 0.059 → 0.053 s |
| 4 | 0.15–0.20 s | 2.24 s | 1.98 s | 0.130 → 0.115 s |

The forward run varies by up to 30% between runs at four species, so compare
the seconds, not the ratios.

Multi-species stands at lifetime 60, interleaved (`tools/multi.R`), as of H2:

| species | metrics × columns | forward | 1 metric, B → H2 | all metrics, B → H2 |
| --- | --- | --- | --- | --- |
| 1 | 5 × 32 | 0.038 s | 14–15x → 5.7–5.8x | 25–30x → 8.6–8.8x |
| 2 | 7 × 64 | 0.075 s | 13–17x → 5.8–6.0x | 32–36x → 10.6–11.5x |
| 4 | 11 × 128 | 0.155 s | 17–18x → 5.6–6.1x | 51x → 13.4–14.1x |

Columns are close to free. Each extra metric is one more sweep, at about
0.7–0.9 of a forward run, where B paid 3–3.3.

## Third round: a ledger by region

Callgrind collected only inside `census_trait_gradient_ff16`
(`--toggle-collect=census_trait_gradient_ff16*`), parsed into calls and cost
per call (`tools/cgtree/ledger.py`), at lifetime 60, on arm C2 (G2 plus plant
12 and odelia 10). The sweep is split by each region's share of live
operations, from `tools/live2.cpp`. The gradient is 1968M instructions for one
metric and 3237M for five.

| region | calls | per call | 1 metric, recorded | 5 metrics, with its share of the sweep |
| --- | --- | --- | --- | --- |
| node rates without the crown | 58,180 | 4.9k | 285M | ~850M (26%) |
| the crown | 58,180 | 7.0k | 405M | ~815M (25%) |
| field builds | 1,232 | 383k | 474M | ~760M (23%) |
| per segment: two rebinds and an insertion | 118 | ~1.7M | ~200M | ~245M (8%) |
| sweep, all regions | 269 / 1,325 | 1.02M / 1.07M | 274M | 1411M (44%) |

What the counts say about the data model:

- **A node is introduced at almost every step.** There are 118 insertions in
  146 steps, so a segment is about one step. Each segment pays two
  `rebind_from` calls at 535k each, plus an insertion recorded and swept. That
  is construction plumbing: `Parameters` validation, the node schedule built
  again, a field build in `reset()`, about 160k `malloc` calls, and nodes
  introduced one at a time without a `reserve`.
- **The field is built 1,232 times for 876 rate evaluations.** The other 356
  builds come from `reset()` inside each rebind and from each insertion.
- **A crown's rows barely deduplicate.** A mid-canopy node's crown statement
  has 81 operations, 76 of them on knots. Its 21 points land in about 19
  different spans of the 64.
- **A node's other 34 statements carry about 94 operations,** about 40 of which
  read trait parameters directly. Three per node depend on the parameters
  alone and are recomputed for every node.

**The sweep is at its floor.** It costs about 10 instructions per statement
plus about 8.5 per live operation: a load, a multiply-add and a store at a
scattered slot.

**A sweep carrying several adjoints per slot saves nothing.** Measured on one
real step tape at lifetime 60, with 58k statements and 179k operations
(`tools/probe_lanes.cpp`), and bit-identical to XAD's own sweep:

| sweep | seconds |
| --- | --- |
| 5 scalar sweeps | 1.39 ms |
| one walk, 5 lanes per slot | 1.39 ms |
| one walk, 8 lanes, 5 used | 2.03 ms |

The work left per lane is the scattered update itself, and lanes do not remove
it. This replaces the lifetime-8 vector-mode figure in *Measured and
rejected*, with the same verdict.

**The crown's recording** (plant 12, odelia 10) went from 8,458 to 6,967
instructions per call:

- A crown's points read a knot range between its lowest and highest span, so
  rows are gathered over that range, without per-knot bookkeeping.
- Zero rows are not emitted.
- `record_with_derivatives` gathers in one pass. It tests finiteness through
  `d * 0.0 + x * 0.0`, which is zero exactly when both halves are finite and
  NaN otherwise. It falls back to the per-row test only to name the bad row.

Gradients are bit-identical to G2. In instructions this takes one metric from
5.50x to 5.24x and five from 8.88x to 8.62x. That is under what wall clock
resolves here: medians of 0.208 against 0.210 s, and 0.321 against 0.307 s.

What is left, by size at five metrics:

1. **Node rates without the crown (26%).** Hoist the parameter-only
   subexpressions out of the per-node path, and fold parameter products, so
   each node reads fewer parameter operands.
2. **The crown (25%).** Rows are now near what the knot grid implies. What
   remains is the double arithmetic of 21 Hermite reads per crown, at about
   1.4 times the forward crown.
3. **Field builds (23%).** Supply the crossing interval's competition as rows
   on the two nodes rather than recording it. Skip the 356 builds that no
   evaluation reads.
4. **Per-segment plumbing (8%).** Stop rebinding twice per segment, or make a
   rebind skip validation and the field build.

## What a statement costs (corrected)

- **XAD's bookkeeping is about 106 instructions per recorded statement.** The
  same kernel run taped and passive: `tools/floor2.cpp`.
- **A dead statement costs that at record time, and almost nothing to sweep.**
  Its adjoint is zero, so XAD skips its operations. Removing dead statements
  therefore moves the ratio less than the statement count suggests.
- **What scales with the number of metrics is live operations.** A light read
  is linear in four coefficients, so a crown block reads few distinct inputs
  many times. Supplying deduplicated rows cuts its sweep cost by about
  two-thirds.
- **Supplying rows saved nothing at record time.** A crown costs about 9.7k
  instructions computed in double plus about 79 rows, against about 10.1k for
  XAD to record its 43 statements. XAD's recording is efficient; the win is the
  sweep.

## Preaccumulation, priced exactly

Per crown, with the input scan and the local sweep made cheap:

| piece | instructions |
| --- | --- |
| recording the crown body (unchanged) | 10.3k |
| local sweep | 3.5k |
| hold, restore and compaction loops over about 79 inputs | 2.6k |
| input scan | 1.2k |
| `initDerivatives`, on each call, as new slots grow the array | about 1.6k |
| **saved on each metric's sweep** | **2.6k** |

So it breaks even at about three metrics, and even at its floor (about 4.5k
of overhead) at about two. Rejected in favour of supplied rows, which pay
nothing extra at record time.

## Why FF16's ratio is high and TF24's is not

TF24's forward run is 90% `solve_leaf`, which its replay loads instead of
solving again. FF16 has nothing to drop: every flop of a rate evaluation becomes
a tape statement. Per step, TF24's gradient costs more than FF16's; it is only
divided by a far larger forward run.

## Where the cost is now

Recording and sweeping both run at XAD's own floor per statement.
`tools/floor.cpp` measures that floor on two-statement kernels: about 124
instructions per statement to record (with the fix in odelia 2), and about 5 ns
per statement per seed to sweep. `tools/probe_sweep.cpp` shows the sweep is not
cache-bound: 4.9, 5.4 and 4.7 ns per statement per seed on tapes of 15k, 89k and
358k statements, with a 2 MiB L2. So the cost is roughly

> statements × (record + metrics × sweep)

and every remaining lever removes statements or operations.

Statements per rate evaluation at 91 nodes, after all patches: about 13k in
all.

| source | statements |
| --- | --- |
| crown quadrature (21 points × 2 statements × 92 nodes) | 3.96k |
| field reduction `field_splits` | 2.5k |
| the rest of the field build | 2.1k |
| non-crown rates | 3.1k |
| state load and rate write-out | 1.3k |

## Measured and rejected

| proposal | measurement |
| --- | --- |
| **Vector adjoints (`AReal<double, 5>`), one sweep for 5 metrics** | 1.5x slower to sweep (4.47 ms against 2.97 ms) on one step's tape, with identical adjoints. Recording costs the same. (`tools/probe_vec.cpp`, with XAD's tape compiled at width 5.) |
| **Preaccumulating the crown** (`odelia-preaccumulated/`) | Rows are exact. Its local sweep costs what each metric's sweep saves, so it breaks even at one metric and saves about 12% at five. Not worth the code. |
| **`XAD_TAPE_REUSE_SLOTS`** | Recording 64% slower; sweep 2% faster. |
| **Skipping zero multipliers inside XAD** | Every operation then pays a branch: the sweep falls 5.5% and recording rises 5.6%. The site that produced 90% of the zeros is fixed instead (odelia 3). |
| **Moving rates out of `Internals` on write-out** | Would save 637 copies per evaluation. Not done: a later reader of a moved rate would get its value without its derivative, with nothing raised. |

## What is left

- **The crown** is about 2 statements per quadrature point, which is XAD's
  minimum for that arithmetic.
- **The number of crown points** is `function_integration_rule` (QK21). That is
  a model accuracy decision, not a tape one.
- **The excluded field's spline** is built only for the boundary node, which
  reads at heights below its seed height: one or two spans of 64.
- **odelia 1** sets `XAD_REDUCED_MEMORY` in the vendored `XAD/Config.hpp`, so
  every package reading odelia's headers agrees on the tape layout.

## Reproducing

Build each arm into its own library and load it with `R_LIBS`. Run `rm -f
src/*.o src/*.so` before every build: R does not track header dependencies, and
one stale build here reproduced its baseline exactly.

- **plant:** apply `plant/` on `pr679` (`git fetch upstream pull/679/head`),
  with plant's pins relaxed to odelia >= 0.8.0 and phylloptim >= 0.10.3.
- **odelia:** apply `odelia/` on odelia `1e0f0f0`.
- **Values:** `tools/guard.R`, then `tools/cmp.R`.
- **Instructions:** `tools/prof3.R` under callgrind, with `METRICS=all` for five
  metrics.
- **Seconds:** `tools/wall.R`, interleaved.
- **Statements by region:** `tools/probe.cpp`.
- **Tests on both arms:** `tools/runtests.R`.
