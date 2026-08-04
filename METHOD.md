# Method: how to verify, build and measure in this project

`NEXTSTEPS.md` says what to build. This says how to know you built it. Read this
before you write a gate, take a measurement, or send work to a subagent.

Nearly every rule below traces to one mistake, made repeatedly: **a gate that
measured the quantity its author was thinking about, rather than the quantity that
moves when the feared thing happens.** Section 1 is that mistake and its counter.

---

## 1. The one rule about gates

**A gate must name the quantity that moves when the feared thing happens.**

Five gates in this project could not fail. Each was written by someone who
understood the change:

| the gate | what it could not see |
|---|---|
| `template class TF24_Strategy<active>` as the active-build census | it never instantiates `Individual`, so it was blind to the container holding the state that the recorded cohort step — `Individual::compute_rates` at the active scalar type, recorded for one cohort at one Runge-Kutta stage — differentiates |
| a reused tape's adjoints against a single call's | `newRecording()` leaves the adjoints **correct** while leaking a derivative slot per input per call. The discriminator was the recording **size** |
| an FF16/K93 tripwire without `add_strategies` | both models ran with no strategies, so it printed no numbers at all |
| a type assertion that the transport probe returns `S` | it passes with the inner lambda at `-> double`, because the difference quotient deduces its result from the point, not from the integrand |
| "no errors in `resource_spline.h`" | measured through the type being changed rather than through the type that consumes it |

Three rules follow, in increasing order of what they cost to learn.

**1. Run the gate on the unmodified tree first, and confirm it prints a number you
recognise.** This kills the first three above in ten seconds each. Asking "how
could this pass vacuously" is not enough, because you answer it from the same
understanding that wrote the gate.

**2. Census from the outermost consumer inward.** A strategy-level probe cannot see
the container. A container-level probe cannot see the R boundary above it. Five for
five in this project; the last instance found the **entire light channel** silently
passive — 65 knot values and 65 slopes — invisible from one level down. And a
member template is gated only by **naming it**: explicit instantiation of a class
template instantiates its non-template members only.

**3. When the failure is a derivative reading zero, the gate has to be a
derivative.** A type assertion witnesses the shape of a channel and never its
content. Where a derivative is not available, **constrain the callee instead of
asserting at the call** — a `requires` clause finds every site, an assertion finds
the site you thought of. That is what turned a failed transport gate into
`integrand_of`.

### Exactly zero is the worst failure mode, because it reads as an answer

Two ways to get one: registering a tape's inputs after `newRecording()`, and a
`double` intermediate anywhere on a channel. **For every gate, ask what it reports
when the channel under test returns exactly zero.** Where the answer is "it
passes", add an explicit assertion that the adjoint is **not** zero.

Eleven trait columns read exactly zero for two waves behind a green suite, a clean
leaf gate and V1 at 3.33e-15.

### A plausible constant factor is worse than an exact zero

A stale divisor put a uniform **2 percent** on every uptake row: every entry
finite, every sign right, the ratios stable across rows. A zero looks like nothing;
2 percent looks like a result, and nothing in its shape asks to be looked at.

### A correct caveat is also a correct-sounding excuse

Four instruments were pointed at that 2 percent defect and none stopped it. The
second is the one to remember: the corpus correctly records that a finite
difference cannot referee the leaf's rows — so a reader handed a real disagreement
could cite the corpus, accurately, to dismiss it. **A document that records why an
instrument cannot answer a question has handed the next reader a citation for
ignoring the answer.**

### A gate built out of the thing it tests cannot fail

Two instances. One compared an accumulator against a rearrangement of the
adjoint's own per-cohort sweeps and passed on broken code. One predicted a waist
coefficient from a pair that was itself wrong by 47 times, and both sides agreed
because both came from the same poisoned source.

### A gate's configuration must be a file in the tree

Not a paragraph. A headline verification number had to be retracted because its
state and its seed lived in an uncommitted R driver. **"A measurement carries its
configuration" is not satisfied by prose.**

### A gate seeded at hand-built states is not a statement about production

Three instances. A collar-curvature gate registered a real defect at 1.06e-05
among neighbours reading 1e-11 and was dismissed — because at its hand-built
states the defect is **1700 times smaller** than at a state the model visits. Say
which state a gate was seeded at.

---

## 2. When a disagreement is the reference and not the subject

**Sweep the difference step and look for a plateau.** A bad reference *improves* as
the step grows while a clean row degrades, and **no plateau at all means the
reference**. One row that looked like a four-order missing term was five entries of
a non-Lipschitz `y_end`: `sqrt(62.42² + 13.78² + 45.07² + 29.84² + 32.70²) = 89.87`,
five numbers that mean nothing. With the reference repaired, all 64 rows closed with
no tolerance widened.

**A tolerance loosened for speed can make a model non-differentiable.** Loosening
an iterative tolerance is safe for a value and can be fatal for a derivative, and
the check is a **jitter measurement, not a residual** — a residual is what passed.
Measured: the spread of one step's `y_end` over 1e-5 input displacements is
1.141e-03 at production against 1.586e-10 at `GSS_tol_abs = 1e-6`, where the true
derivative is 9.21e-08. The noise exceeded its own signal by nine orders.

**Two forward kinks are places where a finite difference is not the reference.** At
`z == height_max` the field reduction switches off, so a central difference of the
tallest cohort's height reports exactly **half**. A soil layer sitting exactly at
`soil_moist_residual` has a discontinuous rate, so a difference there reads
−6.7e+07 against a correct adjoint of 0.

**A relative `lma` step of 2e-7 flips a 105-year stand between alive and
identically zero.** So no re-run finite difference can referee this gradient at
production. The forward tangent is the referee.

**State the definition of a relative error beside it.** `|a-b|/|b|` and
`|a-b|/max(|a|,|b|)` give two different diagnoses of "rel 1": under the first, `a`
is negligible against `b`; under the second, one side is exactly zero.

---

## 3. Standing hazards

**Tape and active scalars.**

- Register a tape's inputs **before** `newRecording()`, or the adjoints are
  silently zero.
- **No active value may outlive a recording.** `clearAll()` resets the slot counter,
  so an active object held across **any** loop that records more than once aliases
  whatever takes its slot next. The signature is the same at every granularity: the
  first recording correct, the later ones with most rows exactly zero and a few
  spuriously large, nothing thrown.
  **This project has two such loops and only one of them is fixed.**
  `Patch::cohort_block_adjoint` loops over cohorts and copies a never-recorded
  template for each one, which is correct. `SCM::census_state_adjoint` loops over
  functionals and builds its copy once, outside the loop, which is
  `NEXTSTEPS.md` Task 15. When you read a measured signature of this defect, **say
  which loop it was measured on**: a per-cohort signature and a per-functional
  signature look identical and have different fixes.
- Never give a deduced return type to anything returning an active value: XAD
  operators return expression templates holding references to their operands. And
  beware `-> double` on a lambda in templated code, which silently passivates.
- A finite difference of a recorded cohort step **cannot** referee a supplied input.
  The supplied derivative is `value + sum_i partial_i * (x_i - to_passive(x_i))`, zero
  in value by construction, so the forward value of the recorded cohort step does not
  change when a row is wrong.

**Numerics.**

- `fl(fl(t + h) - t) != h`. A step size is not recoverable by differencing
  recorded times; at `t` near 100 the low four decimal digits are gone. Record `h`.
- `0.0 * NaN` is NaN. `layer_flux_partials` returns NaN at a branch kink, so a
  multiplication removed "because one factor is zero" changes NaN to 0.0 silently
  and a test using `==` accepts it. Compare bit patterns.

**Code shape.**

- **Two like-typed positional arguments of unrelated meaning** are a silent-swap
  hazard. This shipped a regression once: a meaning changed then reverted left one
  caller mismatched, it compiled, and a model's offspring went silently to zero.
- **Function-pointer identity is not a discriminator** in a header-inline codebase
  without LTO — the weak-symbol addresses do not merge across translation units.
- A member's **return type is formed at class instantiation**, so an ordinary
  member returning a strategy-dependent type breaks every model that lacks it.
  Bodies are lazy; return types are not. Use a defaulted template parameter.

---

## 4. The build, and the two greps that confirm it took

```sh
make RcppR6 && make attributes          # both should report up to date
rm -f src/*.o src/*.so                  # not optional -- see below
R_MAKEVARS_USER=scripts/build/Makevars-O2 R CMD INSTALL --library=<fresh> .
```

- `grep -c -- '-O0' <log>` must read **0**, and the `.so` is about 5.6 MB. Append
  `|| true`: `grep -c` exits 1 when the count is 0, so the success condition
  returns a failing shell status.
- **`rm -f src/*.o src/*.so` is correctness, not hygiene.** R's make does not track
  header dependencies and this core is header-inline, so a header edit otherwise
  fails to compile in and the build silently measures the old code.
- **Never `pkgload::load_all` for a measured run.** It forces its own `-O0 -g`
  build and ignores `R_MAKEVARS_USER` (a 36 MB `.so` against 5.6 MB), and mixing a
  non-`NDEBUG` `.so` with an `-DNDEBUG` `sourceCpp` corrupts the heap. The hazard
  is conditional on the `.so` being stale — with a fresh one, `load_all` skips the
  build — so it is the wrong tool and **not** an automatic explanation for a slow
  measurement. Twice a slow number was attributed to it and twice that was wrong.
- **`library(odelia)` from a real install, never `load_all`.** plant resolves
  odelia's compiled XAD `Tape` symbols at load time.
- **Verify an install by grepping the installed artifact, never the log**, and grep
  for **the symbol the build needs**. A library recorded as "installed and
  verified" lacked `solve_adjoint`; the certifying grep had been for `step_sizes`,
  which passed. Five packets paid for builds they did not need.
- **Check which library the build used**, which is a different question:
  `grep -o "\-I'[^']*odelia[^']*'" <log> | sort -u`.
- **A mid-write `.so` loads and returns plausible wrong numbers** —
  `42.366121223872653 / 5042` against a true `42.176246845059751 / 5105`. Never
  build in a worktree anything else is touching, and **a verification worktree must
  not be one you have been experimenting in**.
- If a number moves unexpectedly, clean-rebuild and re-measure **before** believing
  or reporting it.

**Running the suite.** `library(plant)` then
`attach(asNamespace("plant"), name = "plant-internals")`, or the corpus errors about
117 times on `could not find function "SCM"`. Set `TESTTHAT_PARALLEL="FALSE"`;
`test_dir` goes parallel by default and `callr` cannot start a subprocess here. A
bare `testthat::test_file()` gives no package namespace and can report
`FAIL 0 | PASS 0` at **exit 0**, which is a false pass — use
`test_dir(dir, package =, load_package = "installed")`. **A suite count carries its
invocation**: the same tree reads 2 857 or 2 924 depending on the loading mode.

**Measuring.**

- Absolute times belong to the machine and to its current load. Only **same-session
  ratios** transfer. The same tree at `-O2` has run a production lifetime in 89.9 s,
  102.9 s and 86.1 s.
- A production run is about 90 s idle and about **7 minutes** under a wave of
  builds. Cost a gate for the contended case.
- `/usr/bin/time` is not installed, and an in-process `VmHWM` read returns the
  shell's value. `pgrep -f "Rscript <script>"` matches the bash wrapper first: it
  read 4 976 kB where the R process read 274 900 kB. Poll
  `/proc/<child pid>/status` from outside.
- `pkill -f` and `pgrep -f` match the shell running them. Kill by PID. `pgrep -x
  Rscript` reads empty because the process renames itself; use `pgrep -x R`.
- A single Bash call is capped at 600 s. Long work needs detach plus successive
  waits, which **does** make progress across tool rounds.
- R buffers `cat` to a redirect. Poll for the process to exit; do not read progress
  out of the file.
- `grep -c` over compiler output stops being a count as soon as `-fmax-errors`
  bails. Read the raw error list, and pass `-fmax-errors=200`.
- For a compile-only question use `-fsyntax-only` on one translation unit: about
  7 s against about ten minutes for a clean build.

---

## 5. The reference numbers, and the arm that discriminates

**Three models, three configurations, and mixing them has caused a false alarm.**

| model | configuration | value | steps |
|---|---|---|---|
| TF24 | `max_patch_lifetime = 105.32`, `lma = 0.1978791`, `Control()`, `refine_schedule = FALSE` | `42.411799695604159` | 4 644 |
| FF16 | `scripts/build/ff16k93.R`, its own trait and hyperpar, default lifetime, `sum(offspring_production)` | `19.834058960443031` | 209 |
| K93 | the same script, its own trait and hyperpar | `0.030538172107758225` | 240 |

**FF16 is the only discriminating arm.** K93 returns the identical value under
either configuration, so it caught neither the offspring-to-zero regression nor a
configuration false alarm. Dropping K93 costs little; dropping FF16 costs the
tripwire. **Run the cross-model tripwire on every merge, not at phase end** — a
green TF24 suite is not evidence about the shared canopy.

These are the **pre-#590** numbers. #590 moves TF24 offspring to about 400.9, so
they are the baseline to re-take, not to defend.

**The `test-scm.R` numbers are the branch's and not the ones #585 accepted**, measured
on `p3/wave5` at `d3392ea3` with odelia `a3bcf58`: one-species offspring `16.88458559`,
`ode_times[100]` `4.215204677`, two-species `11.99577762` and `16.47192484`, 307
accepted steps. Upstream records `16.88950` and 293 steps as its references for the same
assertions. **Both are right, for different trees.** Every forward-model change of
`7b5012c2` is present in the merged tree, so the branch's numbers are not a lost fix —
they are the branch's own scalar templating and fused light reduction. Which commit
moves them has not been measured; do not write a cause for it here until it is.

**Two branches hold the provenance of a measurement and must not be deleted.**
`p3/tangent-referee` carries `6b0a49fb`, the whole-run tangent reference Task 0 starts
from. `p3/trait-mask` carries `5fb631a1` and `1a06e4c5`, which are Measurements F and
G of `NEXTSTEPS.md`.

**A baseline is a property of a commit, a configuration, and the script that
produced it.** Quote all three or the number means nothing. A composite forward
change below about **0.15 percent** in offspring needs a mechanism, not a
before-and-after pair — that is what the adaptive controller re-rolls by between
two builds of one tree.

---

## 6. Where the harnesses are

| what | where | reads |
|---|---|---|
| the pinned build flags | `plant/scripts/build/Makevars-O2` | — |
| the style sweep | `plant/scripts/build/style-sweep.sh <worktree> <base>` | candidates, not verdicts |
| the cross-model tripwire | `plant/scripts/build/ff16k93.R <worktree> [tag]` | §5's FF16 and K93 rows |
| the active-instantiation probe | `plant/scripts/tf24-active-probe.cpp` | **2**, both `prepare_strategy` / `height_seed` refusals. Any other number is the finding. About 7 s |
| the decomposition, one recorded cohort step, knot accumulation | `plant/scratch/wire_gates.cpp` with `plant/scripts/v1-driver.R` | V1 normwise 3.33e-15 at lifetime 2 |
| the leaf's own invariants | `plant/scratch/leaf_jac_gate.cpp` | stationarity, continuity, the waist, `FULLSOLVE`. 0 non-finite rows |
| one step's adjoint | `plant/scripts/v3-driver.R` | all 64 rows close, worst 1.36e-02 |
| the whole-run gradient | `plant/scripts/stand-gradient-smoke.R` | it returns; it is slow |
| the forward tangent referee | `p3/tangent-referee`, `scripts/tangent-reference-driver.R` | the only valid referee at production |

Build recipes for the two `scratch/` harnesses are in `plant/scratch/README.md`.
Both belong in `scripts/`, which is owed.

**Two traps in the harnesses themselves.** `block_vjp`'s output-adjoint seed is
length **12** for TF24, not 11; a length-11 seed reliably corrupts the heap. And
`test-census.R` **must be excluded** from every suite run — `filter = "^census$",
invert = TRUE` — until the gradient is fast; a count taken with it excluded is not
a full-suite result and must not be presented as one.

**A configuration can fail to take, and this one moves a timing by 18 times.**
Assigning `p$node_schedule_times` without verifying silently runs the default,
denser schedule. **Confirm by the node count: 8 nodes and `ode_size` 73 pinned at
lifetime 0.2, against 65 unpinned; 141 and 1137 at the production default.**
`length(scm$state$node_schedule_times[[1]])` discriminates nothing.

**To change a trait, use `add_strategies(p, trait_matrix(v, "lma"))`.** Writing
`pars[["lma"]]` does not recompute the derived strategy quantities. Two committed
scripts do this and any figure taken through them is suspect.

---

## 7. Reviewing your own work

- **Re-run every gate yourself**, in your own worktree. An agent's "tests pass" is
  unverified until its output appears in your session. Where you choose not to
  re-run something, **say so** rather than implying you did.
- **Hold your own edits to the same discipline**, including a merge conflict you
  resolved by hand.
- **Compute the merge base again after every fetch.** A stale base showed 47
  changed files where upstream changed 24, and sent a reviewer hunting for fixes the
  branch already had.
- **Read the diff, not the file.** Current state is self-justifying; it never shows
  the guarantee that was dropped mid-refactor. A `resize` where `assign` was meant
  discarded fifteen correct rows.
- **What a deletion affects is prose as well as code.** Nothing about a comment's
  line changes when the code it describes is deleted, so every grep passes it. Three
  comments survived telling readers to prefer a path that had been removed.
- **Count multiplicities, not just correctness.** `1 + max_soil_layer` calls, twice
  for each recorded cohort step, is 12 — and every one of them is individually correct.
- **Ask what a function is a function *of*.** Partitioning one function by which
  arguments its work depends on found that 98 percent of a reverse pass was a
  Jacobian being rebuilt for a seed it did not use.
- **Verify an explanation, not only a number.** A reassuring account of the failure
  mode you fear most deserves *more* scrutiny than an alarming one: an alarming
  account gets checked because it demands action, and a reassuring one closes the
  question. Thirteen exactly-zero columns arrived with a plausible explanation that
  one `grep` refuted.
- **A row is not a column.** An attribution carried from a row disagreement to a
  column disagreement, joined only by a shared index, was wrong.
- **Cite a symbol, not a line.** Every line citation in the design documents had
  drifted while every claim they supported was still true. For archaeology, cite a
  commit and a path. For a number, cite the command that produced it.
- **Some invariants are properties of the merge, not of any branch.** `grep -r
  'xad::' plant/inst plant/src` returned five lines on every branch in isolation and
  nothing on the merged tree.
- **When something contradicts the plan, that is the finding and it outranks the
  task.** Write it down before continuing.

---

## 8. Deviations from ASD-STE100

`NEXTSTEPS.md` is written in Simplified Technical English. This document is not:
it is written for a reader deciding how to work rather than following a procedure,
and it uses ordinary English throughout.
