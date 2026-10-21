# FF16 adjoint cost (traitecoevo/plant#677): spikes

The FF16 reverse pass divided by its own forward run, for one species. The first
four columns are callgrind instructions per step at `max_patch_lifetime` 8, with
one census metric. The last two are wall-clock seconds at lifetime 30,
interleaved against the baseline in one sitting.

| arm | gradient / step | sweep / step | ratio, 1 metric | ratio, 5 metrics | seconds, 1 metric | seconds, 5 metrics |
| --- | --- | --- | --- | --- | --- | --- |
| A: develop, odelia 0.7.3 | 49.7M | — | 24.7x | — | — | — |
| B: plant#679, odelia 0.8.0 | 29.6M | 6.49M | 14.5x | — | 14.0-15.4x | 26.3-29.4x |
| + fold the crown shape (patch 1) | 22.1M | 4.55M | 10.8x | — | 9.0-9.9x | 17.8-18.5x |
| + stop recording copies (patch 2) | 19.5M | 3.98M | 9.6x | — | — | — |
| + two statements per crown node (patch 3) | 17.7M | 3.46M | 8.7x | 16.4x | 8.1x | 15.4-16.0x |

The forward run is the same in every arm from B down, because the patches touch
only the active path. Against B, every gradient entry stays finite and none
drops to zero; the worst relative change is 2.6e-12 and the median is 3e-15.

## Why FF16's ratio is high and TF24's is not

TF24's forward run is 90% `solve_leaf`, with `toms748_solve` alone at 62%. Its
replay loads the solved leaf instead of solving it again. Per step, TF24's
gradient costs 120M instructions and FF16's 30M, but TF24's forward costs 43M
and FF16's 2M. Take the leaf solve out of TF24's forward and its ratio would be
about 28x. FF16 has nothing to drop from its replay: every flop of its rate
evaluation becomes a tape statement.

## What each patch removes, per rate evaluation at 91 nodes

`tools/probe.cpp` records one rate evaluation of a real patch state and counts
statements by region. A statement with one operand and a multiplier of 1 is
counted as a copy.

- **Patch 1.** The crown nodes sit at `h * s_j`, so `q`'s shape factor is a
  per-node constant, because `eta` carries no gradient column. A crown integral
  drops from 193 statements to 85.
- **Patch 2.** Copies of active values. Kernel arguments taken by value were 21
  copies per node. The others: the aux reads in `compute_rates` and
  `compute_competition_and_slope`, `Node::height()` returning by value,
  `Q_and_q` arguments, and temporaries written into `Internals`, which are now
  moved. Copies fall from 7,180 to about 1,800 per evaluation.
- **Patch 3.** The light read takes the fraction, so `h * s_j` is not recorded
  on its own. The leaf rate is accumulated in one expression. A crown node drops
  from 85 statements to 43.

## Measured and not worth it here

**Preaccumulating the crown** (odelia patch 1, `preaccumulated<S>(body)`) is
correct: its rows match the inline sweep exactly. It cuts the sweep per metric
from 3.46M to 2.45M instructions per step. But its local sweep adds the same
1.0M per step to recording, so it breaks even at one metric and saves about
(k - 1) x 1.0M per step at k metrics. As written it also paid for TLS scratch
(11% of instructions) and XAD re-initialising its derivative array on every
local sweep.

## What is left

Measured on the patch-3 build, per rate evaluation:

| region | statements |
| --- | --- |
| field build | 6,407 |
| rates | 7,125 |
| loading the state | 1,106 |
| writing the rates out | 637 |

About 3,100 of these statements are still copies, and most are on odelia's side
or at its interface with plant:

| source | copies per evaluation | where |
| --- | --- | --- |
| `hermite_spline::set_data` | 387 per build, 774 in all | odelia |
| loading the stage state into the patch | 637 | odelia's stepper would need to move it |
| `ode_rates` writing the rates out | 637 | plant |

With five metrics the sweep is half the process, at about 38 instructions per
statement. odelia's vector-width measurement (`ode_interface.hpp`) was taken on
TF24, not on FF16.

## Reproducing

Build each arm into its own library and load it with `R_LIBS`. Apply the
patches on `pr679` (`git fetch upstream pull/679/head`) with plant's pins
relaxed to odelia >= 0.8.0 and phylloptim >= 0.10.3. Run `rm -f src/*.o
src/*.so` before every build: R does not track header dependencies, and one
stale build here reproduced its baseline exactly. Use `tools/guard.R` and
`tools/cmp.R` for values, `tools/prof3.R` under callgrind for instructions
(`METRICS=all` for five metrics), and `tools/wall.R` interleaved for seconds.
