# The reverse sweep on TF24: its cost per row, and the spread canopy's slowdown

**Configuration.** TF24 SCM, one species, `lma = 0.32`, lifetime 40, long
drought aligned (a zero-depth pulse at each of the 2931 active knots), birth-date
coordinate, from `harness/long_drought.R`.
- *Builds:* the baseline is `lib_guard` (plant `7dbd87c3`, odelia `a05f5c2`,
  `-O2 -g`). The spread build is `canopy-spread.md`'s `lib3` with
  `PLANT_PROBE_SPREAD=8`.
- *Tolerance:* `ode_tol_rel = ode_tol_abs = 1e-3` unless stated; also `3e-5` with
  the tied absolute tolerance.
- *The sweep* is `stand_gradient`'s reverse pass of `J` after a recorded forward.
- *The cut* is `perf-rhs-profile.md`'s: 54 nodes and lifetime 5, with 1495
  accepted steps, 40 073 rows and 464 insertion rows.

**Measurement.**
- *Instructions* are from callgrind, with only the sweep instrumented.
- *Time per phase* (recording, reverse, insertion rows) is from a shim on XAD's
  tape (`tapestats.cpp`), split by instructions within each phase.
- *CPU* is `proc.time()` user seconds.

The scripts and tables are in `perf-sweep/`; its last section says which
command reproduces each number.

## Key numbers

| | |
|---|---|
| **The sweep against a forward** | 2.70 plain forwards at u108 and `1e-3`; 2.52–2.63 recorded forwards at `3e-5` |
| **Why** | 0.83 as many member evaluations per row (6.33 against 7.63), each costing 3.26 times as much (43.0 µs against 13.2 µs) |
| A taped member evaluation at its recorded point | 32.2 µs, 2.4 times a whole forward evaluation with its search; 953 statements, 1665 operations, about 33 KB of tape |
| The leaf's searches in the sweep | none: all six stages load recorded operating points (`perf-adjoint.md`'s re-solved first stage is older code) |
| The inner problem's derivatives | one implicit-function solve per root, five per member evaluation, never taped iterations; 37% of the instructions |
| Insertion rows | 19.6% of the sweep at u108; 2931 of the 3039 are zero-depth pulses, identity maps that each pay two rebinds |
| The crown's light quadrature on the tape | 17% of the instructions, about 60% of a member's tape |
| The spread canopy | +8% at `1e-3` and +2.8% at `3e-5` (u108), all in the field build. The 1.7–3.4× was wall clock under load, and at u429 the light field's fallback path |
| **A factor of two** | identity rows not splitting the descent (−19%), crown light off the tape (−20–24%), the collar's slope stored (−8.5%): 47–51% together |

## 1. Cost per row by component

The cut, `1e-3`. Time is measured per phase and split by instructions within
it (`out/final_table_cut.txt`):

| component | baseline instructions per row | share | µs per row | share | spread instructions per row | µs per row |
|---|---|---|---|---|---|---|
| (a) the leaf's searches | 0 | 0 | 0 | 0 | 0 | 0 |
| (b) the member rates, re-evaluated and taped | 766k | 27.3% | 80.7 | 24.0% | 762k | 80.6 |
| · of which the crown's light quadrature (QK21) | 480k | 17.1% | 50.6 | 15.1% | 476k | 50.3 |
| (c) the reverse interpretation | 360k | 12.8% | 26.0 | 7.7% | 428k | 30.7 |
| (d) the inner problem's derivatives | 1045k | 37.1% | 110.0 | 32.8% | 1046k | 110.6 |
| · of which the collar's slope by central difference | 217k | 7.7% | 22.8 | 6.8% | 217k | 22.9 |
| (e) the fields on the tape: light, newborn, soil | 344k | 12.3% | 36.2 | 10.8% | 545k | 57.6 |
| (f) loads and state scatter | 12k | 0.4% | 1.2 | 0.4% | 12k | 1.2 |
| (g) insertion rows | 282k | 10.1% | 81.0 | 24.2% | 284k | 82.8 |
| **total** | **2.81 M** | | **335** | | **3.08 M** | **364** |

- *(d) is one implicit-function solve per root.* Each member evaluation has five:
  the collar's marginal, then two inner roots inside it, then the same two again
  for the profit at the held collar. The collar's slope, the solve's divisor,
  costs two extra double evaluations that re-run the nested roots.
- *(e) is fixed per step,* so it is about 3% at u108.
- *(g) costs more time than instructions:* each insertion row rebinds the whole
  patch to the active scalar twice (at low IPC, rebuilding every leaf's tables)
  and evaluates the stand twice at double.

## 2. Why 2.7 forwards

At u108 and `1e-3`, the forward makes 7.63 member evaluations per row: six per
attempt over 1.27 attempts per accepted step, plus each leg's start evaluated
twice. The sweep makes 6.33. Each of the sweep's costs 43.0 µs against the
forward's 13.2 µs:
- 32.2 µs taping the member at its recorded point;
- 4.1 µs the reverse;
- 8.6 µs insertion rows;
- 1.3 µs fixed per step.

0.83 × 3.26 = 2.70, the measured ratio. The cost per evaluation dominates, and
within it the tape's size.

## 3. The spread canopy's slowdown

- *Intrinsically small:* +8% at `1e-3` on the cut and at u108, and +2.8% at u108
  and `3e-5`. All of it is the field build on the tape and its reverse: 116 more
  statements per member evaluation and 13% more tape.
- *Not reproduced in CPU at u108:* `canopy-spread.md`'s 2.0× was wall clock under
  load. Its forwards were 1.65 times slower in wall time with equal CPU.
- *The u429 cliff is the light field's fallback path.* The field is one prefix
  pass over its 65 knots only while the nodes' heights run tallest first.
  Otherwise every knot walks every node on the tape, and the spread walks 16 point
  crowns per node.
  - In the u429 spread forward at `3e-5`, heights run tallest first at 18.8% of
    the states. From t = 6.9 to 40, nodes 74 and 75 are out of order by at most
    1.2 mm.
  - The surviving sweep steps there tape 40 M statements and 1.36 GB per step,
    14.2 times the regular tape. That fits the +2.2 GB and 8120 s of
    `canopy-spread.md`.
  - At u108 the order held at every state, for both builds and tolerances.
  - The lumped build takes the same path, at a sixteenth of the cost. On the cut
    without pulses its heights were out of order from t = 3.8.
- *The cure:* an ordering test with a tolerance, or a sort and then the prefix
  pass. It removes the cliff in both builds.

## 4. Where a factor of two could come from

At u108 and `1e-3`, ranked by gain:

1. *Not splitting the descent at identity insertion rows,* the zero-depth pulses:
   about 19% (27% on the cut). Low effort, in odelia or in how plant records stops.
   Cloning the leaf rather than rebuilding its tables would cut what remains of
   each rebind by two thirds.
2. *The crown's light quadrature off the tape:* crown-mean light at double,
   recorded as one statement with its partials. About 20–24% with its reverse;
   moderate effort.
3. *The collar's slope stored with the recorded collar,* instead of two double
   evaluations: about 8.5%. Low to moderate effort; the slope divides the
   implicit-function solve, so its accuracy needs checking.
4. *The implicit-function solve's hold and restore inlined:* about 4%.
5. *One set of collar coordinates per member evaluation,* not two: about 4%.
6. *The feasible-bracket roots skipped on replay:* about 3%.

The first three take 47–51% of the sweep, about 2×; all six, about 2.5×.

Not levers: the re-solved first stage (gone), taped inner iterations (none),
checkpointing (each step is re-recorded once from stored states), and reusing the
tape across stages (each stage is different arithmetic). The reverse, 9–10% of
the time, shrinks only with the tape.

## 5. The rebinds at the introductions, on the split build

Long drought at u108 and `1e-4` under the tied tolerance, on the split build
(odelia `1e5a2d7`, plant `91098156`), the knots already step targets (#96).
Plain's sweep of its own pinned program took 63483 samples at 250 Hz
(`sign-changes/sweep_profile.txt`, `dev/p21/prof_ab_plain`), 5288 of them, 8.3%,
outside its step loop:
- 3016 (4.8%) rebinding the patch to the active scalar, once for each range and
  once for each introduction's own map, so about twice an introduction. Of it,
  2104 rebuild the strategy, 1802 of those the leaf's cumulative vulnerability
  integrals (incomplete gamma functions) for the roots and the transpiration
  stream, and 779 copy the parameters.
- About 1730 (2.7%) transpose the introductions' maps, each a taped evaluation of
  the stand.

The introductions are the insertion rows that remain, and §4's note under its
first item applies to them: cloning the leaf rather than rebuilding its tables
would take about two thirds of each rebind, about 3% of the sweep. The split's
sweep pays the same.

## Not reached

- *The whole-run u429 factor and the lumped comparator:* about 2–2.5 h of CPU
  for the spread sweep alone.
- *A refused gradient:* at u108 with `ode_tol_rel = ode_tol_abs = 1e-3`, both
  builds refuse `J`'s gradient, so its row is `NaN`. The sweep still descends to
  row 0, so the timings stand. The refusal's reason was not read. The
  spot-check's and ε's gradients, at `3e-5` and `1e-4` under the tied tolerance,
  answered.
- *`J` at u108 is 12.662,* not `perf-adjoint.md`'s: the model has changed since
  `6613dd24`.

## Reproducing

From `perf-sweep/`, with `DEV` the scratchpad's `dev/`. `job.sh <tag> <lib>
<spread|-> <script> [VAR=...]` runs a script under nice into `logs/<tag>.log` and
`out/<tag>.rds`.
- *CPU on the cut:* `bash q_cut.sh`.
- *Callgrind:* `bash sp_cg.sh guard5 $DEV/lib_guard - 5` and `bash sp_cg.sh
  spread5 $DEV/comb/lib3 8 5`, then `cg_parse.py`, `cg_sweep.py`,
  `cg_compare.py` and `final_table.sh` into `out/`.
- *The shim:* build with `g++ -O2 -shared -fPIC -o tapestats.so tapestats.cpp
  -ldl`, and run with `LD_PRELOAD=tapestats.so` (see `sp_tape.R`). The runs are
  `q3.sh` (`tape5_*`, `u108_*`), `q4.sh` (the cut without pulses), `q5.sh`
  (`t3e5_u108_*`) and `q6.sh` (u429, cut off at 174 steps); `tape_summary.R`
  summarises each.
- *The fallback path:* `fallback_compare.R`; the heights' order along a run:
  `sp_order.R`.
