# Method: how to verify, build and measure in this project

`NEXTSTEPS.md` says what to build. This says how to know you built it. Read this
before you write a gate, take a measurement, or send work to a subagent.

Nearly every rule below traces to one mistake, made repeatedly: **a gate that
measured the quantity its author was thinking about, rather than the quantity that
moves when the feared thing happens.** Section 1 is that mistake and its counter.

Sections 1 to 8 are technique: how to write a gate, which reference to trust, where the
harnesses live. **Section 9 is strategy** — which measurements the design needs, in what
order, and which of the existing ones to stop citing. Read section 9 before planning a wave;
read the rest before writing a line of it.

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

The rule is the most productive one here and two of its three recorded instances need
restating.

**Instance 1 stands.** A gate compared an accumulator against a rearrangement of the adjoint's
own per-cohort sweeps, and passed on broken code.

**Instance 2 is withdrawn, and its withdrawal is itself an example.** It held that a gate
predicted a waist coefficient from a pair wrong by 47 times, both sides agreeing because both
came from one poisoned source. **The 47 was never a measurement** — it is the justification
comment above the guard that captures the vulnerability grid before any perturbation, and the
grid is held, so the poisoning does not occur. A rule was illustrated with a number that
described the hazard a guard had already removed.

**Instance 3 is the one to remember, because it is structural rather than accidental.** The
curvature of the leaf's profit is measured by differencing **about the solved operating point** —
that is, only at points where a maximum was found, where the second-order necessary condition
already forces the sign the measurement reports. Negative at 52 of 52 states is what the sample
was constructed to find. Its sibling has the same shape: a stationarity identity used to referee
that same curvature is **formed from** it, so a wrong value cancels, and a real 2 percent defect
passed it bit-for-bit unchanged.

**So the test is not "could this gate pass vacuously" but "does this gate's population exclude
the failure".** A sample conditioned on success cannot see failure, however many points it has.

### Assigning a parameter by the obvious name can be a silent no-op

**A registered parameter lives one level below the strategy, at `pars$<name>`.** Assigning
`strategy$<name>` does not fail, does not warn, and does not reach the model: the R object is a list,
so the assignment **creates a new element** the C++ side never reads. Reading it back returns the
value you just set, so the obvious check passes too.

Measured: a sweep of the light extinction coefficient over a twelvefold range returned
$k_I\,\mathrm{LAI}$ identical **to four decimal places in every arm, with identical step counts.**
That reads as a striking ecological result — self-shading exactly cancelling a change in extinction —
and it means nothing was varied. With the assignment corrected, the same sweep spans 1.85 to 17.45
and crosses the threshold it was written to test.

**So any probe that varies a parameter needs two guards**, and both are cheap:

1. **Assert the parameter took**, by reading it back off the object the run will actually consume —
   not off the one you assigned to.
2. **Refuse to report an all-arms-identical result.** If every arm agrees to the printed precision
   *and* the step counts match, suspect the harness rather than the ecology, and say so in the
   failure message. Identical step counts are the tell: a real parameter change perturbs the adaptive
   controller.

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
production.

> **WARNING: the referee this section names does not exist.** "The forward tangent is the
> referee" was written against an intention. There is **no assembled forward tangent at the SCM
> level** — no `jacobian_vector_product`, no forward driver in `scm.h`; `forward_derivative`
> appears only inside `Leaf` as a local device. And the blessed whole-run tangent reference on
> `p3/tangent-referee` is on the **height** coordinate, which the gradient no longer supports,
> taken at a commit that is not an ancestor of the current tree. **So the gradient currently has
> no valid external reference at any level**, and building one is a prerequisite rather than a
> task. Section 9.1 designs it.

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
R_MAKEVARS_USER=/home/user/plant-dev/scripts/build/Makevars-O2 R CMD INSTALL --library=<fresh> .
```

- **The path must be absolute.** R builds from `src/`, so a relative `R_MAKEVARS_USER`
  resolves to nothing **and R reports no error** — it uses its own
  `-g -O2 -fno-omit-frame-pointer` instead. The file also lives at the workspace root and
  **not** inside the plant worktree, so a relative path fails there twice.
- `grep -m1 -o 'fpic.*' <log>` must show `-O2 -DNDEBUG -g0`. This is the gate that catches
  an ignored `R_MAKEVARS_USER`; the `-O0` grep below passes such a build.
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
| TF24 | `max_patch_lifetime = 105.32`, `lma = 0.1978791`, `Control()`, `refine_schedule = FALSE` | **does not reproduce — see below** | |
| FF16 | `scripts/build/ff16k93.R`, its own trait and hyperpar, default lifetime, `sum(offspring_production)` | `19.834058960443031` | 209 |
| K93 | the same script, its own trait and hyperpar | `0.030538172107758225` | 240 |

**FF16 is the only discriminating arm.** K93 returns the identical value under
either configuration, so it caught neither the offspring-to-zero regression nor a
configuration false alarm. Dropping K93 costs little; dropping FF16 costs the
tripwire. **Run the cross-model tripwire on every merge, not at phase end** — a
green TF24 suite is not evidence about the shared canopy.

**WARNING: the TF24 row does not reproduce and the recorded value is not usable.** It
records `42.411799695604159` over 4 644 accepted steps. Measured on `p3/wave5` at both
`d3392ea3` and the #590 merge `600e3ebd`, at the configuration stated in the row:
**`42.411495358228734` over 4 648 accepted steps.** The two trees agree with each other
to the last bit, so the difference belongs to the recorded number or to an unrecorded
part of its invocation, and not to either merge. Do not defend the recorded value and do
not gate against it. Take this arm again on a converged schedule and record what
produced it.

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

## 5b. Run one test file per R session

**Looping several test files in one R session produces false failures that look
exactly like a regression.** Measured: eight files in one session reported 14 failures
— locked-environment errors on `NodeSchedule$ode_step_sizes`, a NULL
`light_availability$state`, a second run failing to reproduce the first, and an offspring
production of `16.925` where the tree produces `16.884585587`. **Every one was cross-file
contamination and every one was a false alarm.** A reviewer who trusted that output would
have hunted a regression that does not exist.

Two separate harness facts, and you need both:

- One R session per file.
- `env = new.env(parent = asNamespace("plant"))` for any file that uses an unexported
  name — `test-scm.R` does — or you get "could not find function" errors that are also
  an artefact.

`AGENTS.md`'s test-selection tiers assume `test_file` per file, which is correct; the
hazard appears when someone writes a loop to save startup time.

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

---

## 9. The measurement programme

Sections 1 to 8 say how to take a measurement well. This says **which measurements the design
needs**, and it exists because the corpus was rebuilt rather than extended. The reason is worth
stating plainly: the existing measurements do not fail for being too few. They fail for being
carved wrong.

### 9.0 Eight ways a measurement in this project has failed

Each row has an instance, and every instance passed review at the time.

| failure | instance |
|---|---|
| **conditioned on the conclusion** — the population excludes the failure | profit's curvature differenced about *solved* operating points, where the second-order condition forces the sign. 52 of 52 is what the sample was built to find |
| **the statistic cannot see its subject** | per-layer hydraulic redistribution ruled unreached because *total* uptake never goes negative. The total is a sum; the phenomenon is per-layer negatives inside a positive total |
| **the axis never moved** | every incidence figure in the corpus, taken on a driver whose ground-level transmittance is 0.9997 and whose maximum soil potential *is* its initial state. "Incidence zero" was a property of the driver |
| **a comment read as a measurement** | four times, most damagingly a 47-fold error quoted from the justification comment above the guard that prevents it |
| **the amplified output measured, and the quantity reported** | mean-light bias quoted as 3.33, which is *lifetime offspring* — a per-plant carbon bias compounded through an establishment gate for twenty years. The carbon bias has never been measured |
| **no configuration, so no reproduction** | one measurement retired outright; one figure ("36 of 44") corresponds to nothing anywhere; one stated as 180 times where the arithmetic gives 65.7 |
| **a compensating pair fits every row** | the waist's two scalars are numerically collinear, so an error in one is absorbed by the other at about 1e5 and the joint residual is blind to it. The invariant checks one at the other's fixed value, not the pair |
| **the reference invalidated by its own scope** | the blessed tangent table is on a coordinate the gradient no longer supports, across a commit that is not an ancestor |

**The rule that follows, and it is the only one in this section.**

> **A measurement earns its place by being able to falsify a claim the design rests on.**

Two questions before taking one, in this order:

1. **What observation would refute the claim?** If nothing would, there is no measurement to take
   — there is a definition, and it belongs in a report.
2. **Can this instrument produce that observation?** If the instrument's population is conditioned
   on the claim holding, or its statistic aggregates away the failure, or its axis does not move
   where the failure lives — redesign the instrument. Do not take the reading and caveat it.

The second question is the one this project has skipped. Six of the eight failures above are
instruments that could not have produced a refutation, run carefully and reported honestly.

### 9.1 The reference problem, which gates most of the programme

**There is no valid external reference for this gradient today.** Four levels are available and
each refutes something different. State which level a claim is being checked at, because they are
not interchangeable.

| level | instrument | what it can refute | what it cannot |
|---|---|---|---|
| **L0** | closed form against a high-precision independent evaluation | an algebraic derivation | anything about the code path that consumes it |
| **L1** | a supplied derivative against the individual's own algebra | the leaf's hand-written rows | nothing, if checked against a difference of the step — see below |
| **L2** | a forward tangent through the same trajectory | the whole assembled gradient, at any lifetime | a term both modes impose identically |
| **L3** | a re-run finite difference of the census | the model-level answer | anything at production, and anything through a supplied derivative |

**Three constraints make this harder than it looks, and all three are established.**

- **A finite difference of the recorded step cannot see an error in a supplied derivative.** The
  grafting construction is exact in value, so perturbing an input changes the output through the
  solver rather than through the bracket carrying the derivative. **L1 must be checked against
  algebra, never against a difference of the step that consumes it.**
- **L3 is unavailable at production.** A relative `lma` step of 2e-7 moves a mature stand between
  alive and identically zero.
- **L2 shares one blind spot with the gradient by construction.** The seed height's derivative is
  imposed zero on *both* automatic paths, so a forward tangent cannot referee it. That term needs
  L3 at a lifetime small enough to survive a step, or a new instrument.

**So the first work item in the programme is not a measurement.** It is:

1. **Build the SCM-level forward tangent.** It is the referee this document already assumes. Until
   it exists, no claim about the assembled gradient can be checked at all.

   **The missing piece is a driver, not infrastructure — established by dry run.** `odelia`'s
   `ode_jacobian.hpp` already implements forward-mode: a twin system at
   `xad::fwd<value_type>::active_type` built through `rebind_from`, one state tangent seeded at a
   time, used today by the Rosenbrock stepper for its exact Jacobian. The double-to-active lift is
   proven in production. So this is about four packets rather than a project, and **two readings of
   it are open.** Integrating fresh at the tangent scalar from time zero passes through every
   introduction live and needs none of the reverse pass's widening machinery — that apparatus exists
   only to fill the backward sweep's storage gap. Re-binding a completed double trajectory mid-run
   would need the mirror of it, and about two packets more.

   **The one read that settles the estimate, and it needs no build:** whether the adaptive stepper
   and the node-schedule control logic are safe at a tangent scalar carried through cohort
   introductions. If a control decision compares an active quantity through an unguarded passive
   cast, the cheap reading is wrong. Do that read before writing any driver.

   **And a cheaper instrument may referee the same claims.** A hand-differentiated closed form on
   the two-cohort fixture is an L0/L1 check on a stand that is *by design* small enough to check by
   hand, so it may not need a general driver at all. A complex-step variant buys nothing, because the
   forward scalar is already exact at the same cost, and no Taylor-mode facility exists in `odelia`
   to build on.
2. **Bless a two-cohort stand on the birth-date coordinate**, small enough to check by hand, with
   its configuration as a file in the tree. This is the L2/L3 fixture and it is what makes "agrees
   to solver tolerance" a sentence with content.

**And re-bless the cross-model tripwire.** All three rows in section 5 are unusable: the TF24 row
does not reproduce, and FF16 and K93 are pre-#590 baselines to re-take rather than defend.

### 9.2 The axis problem: one fixture repairs eight measurements

**Every incidence figure in this corpus is a measurement of the default driver**, and that driver
never closes its canopy and never dries. Ground-level transmittance is 0.9997 — an open woodland.
Soil potential never goes drier than its own initial state.

This matters more than any single reading, because the five kinds of operating point are
**consecutive segments of one drydown**: an interior optimum while wet, a constrained optimum as
the stand dries and grows tall, a substituted point as the feasible window closes, a shutdown once
it is gone. A driver that stays wet visits the first and reports the rest as unreached.

**So build the driver set before taking any incidence figure.** Two fixtures:

- **A closed canopy.** Enough leaf area index that the light floor's lever is in range, since the
  floor and the interpolant's monotonicity guard fire together under one change in `k_I` and `k_I`
  is a registered free parameter a search will walk.
- **A real drydown**, traversing the four segments in order, deep enough to pass the root
  vulnerability grid's end — because that is where the plant-to-soil sink begins, and the ordinary
  dry-season profile reaches it while the plant stays alive.

Eight figures become meaningful only against these fixtures: every operating-point incidence, the
curvature question, the soil clamps, the frozen-reserve fraction, the pinned-bound counts, the
bracket trend, the wrong-way flux magnitude, and the refusal counters. Taking any of them on the
present driver produces a number about the present driver.

### 9.3 Distributions before incidences

An incidence answers one question on one driver. A distribution answers several and exposes the
next question. Four are missing, all cheap, and each one currently blocks a claim:

| distribution | what it decides |
|---|---|
| relative reserve `r` across a stand | whether the reserve gate — a mollifier occupying 40 percent of `r`'s domain — has replaced the model it smooths. Nothing else can tell |
| cohort height, at recruitment and after | whether recruits fall below the single-layer rooting depth, which decides whether a **derived, guaranteed** non-finite gradient row is reachable. **The cheapest item in the programme** |
| `k_I · LAI` over a run | how far the light floor's lever is from binding, and therefore whether an ascent run can walk into the severed region |
| cohort crossing, on the birth-date coordinate | how often the census quadrature sits on a non-monotone grid — the objective's own correctness, upstream of every derivative |

### 9.4 The core set: claim, falsifier, instrument

Each row is a claim the design rests on. **If the falsifier cannot be produced, the claim is not
supported — it is assumed.**

| # | design claim | what would refute it | instrument | level | blocked by |
|---|---|---|---|---|---|
| 1 | the gradient is a derivative of the model | disagreement beyond solver tolerance on a hand-checkable stand | forward tangent, two-cohort, birth-date | L2 | 9.1 — **instrument absent** |
| 2 | the objective is correct before any derivative | a census differing from the same census on a sorted grid | sort-and-compare at a crossed state | L3 | 9.3, to find a crossed state |
| 3 | every state the theory excludes is refused | a state in the no-derivative, exogenous or substituted classes returning a finite number | classifier counters, one per kind | — | 9.2 |
| 4 | the waist's second scalar is right **in the drying direction** | disagreement with the symmetry-breaking term computed directly, along the uniform direction | `Leaf::translation_partials` — **in the tree and unused** | L1 | — |
| 5 | profit's curvature does not vanish in the feasible region | a sign change | sweep `p` across the **whole** feasible interval at dry states | L1 | 9.2 |
| 6 | the field block is rank one on the birth-date coordinate | a second singular value above round-off | singular values of the block, both coordinates | L1 | — |
| 7 | the light row's width is bounded by the quadrature rule, not the canopy | a row wider than twice the rule's point count | column census per recorded step, **on the birth-date coordinate** | — | existing figure is height-coordinate |
| 8 | recording once and sweeping many is close to `F`-fold | sweep cost not dominated by record cost | record and sweep timings separately | — | the aliasing fix, and the driver API |
| 9 | the averaging bias is a scope limit of stated direction | — the direction is certain; the **magnitude** is unknown | deep-crown against mean light at fixed states, **forward** | L0/L1 | — |
| 10 | the parameterisation map expresses the model's sensitivity | a large fraction of the internal gradient orthogonal to the map's range | the orthogonal residual, per metric | — | the map itself |
| 11 | the potential cap's wrong-way flux is bounded | a per-layer consumption large against a healthy layer's uptake | minimum per-layer consumption and maximum layer potential over a rainfall series | — | 9.2 |
| 12 | the four field-reduction rows are short by a knowable amount | the allometric column disagreeing with a central difference by more than the missing channel predicts | one column against a difference | L3 | small lifetime |

**Row 4 is the highest value in the programme for its cost, and the dry run made it more lopsided,
not less.** The claim carries the only belowground competitive coupling in the model; the quantity is
a small difference of large quantities amplified fifteen- to twenty-six-fold; and the instrument that
computes it *directly* — `Leaf::translation_partials`, writing the uniform-drying response as itself
rather than by differencing — is in the tree. It is reachable only from a hand-compiled standalone
harness, not from R or any shipped path.

**And that harness already runs the wrong comparison.** It perturbs along the drying direction and
checks the **joint** prediction against a difference of the residual — which is exactly the residual
that cannot detect an error in the closed-form scalar, because a compensating pair fits every row. In
the shipped code that scalar is closed form and the other is a two-sided difference, and **the closed
one is never checked along the direction that matters.** So the fixture exists, wired to the one test
that cannot falsify the claim. Rewiring it is the measurement.

**Row 9 replaces a number rather than adding one, and its obvious fixture cannot fail.** The 3.33 is
a stand-level demographic amplification quoted where a per-plant carbon bias is meant. Both shading
modes run at plain double and cost hundredths of a second at one state, so the comparison is cheap —
**but the fixed environment the interface offers sets a *spatially constant* light level, and under
constant light the two modes are mathematically identical.** A dry run confirmed it empirically: every
output bit-identical, a clean "bias = 0" that would have read as a finding. That is §9.0's
axis-never-moved failure, caught before it was reported.

So row 9 carries a fixture requirement: **the field must vary with depth**, which means building it
through the canopy machinery rather than through the fixed-environment call. Still one state, still
cheap. The quadrature is confirmed apples-to-apples — the same rule and the same abscissae in both
modes — so the only difference is the number of hydraulic solves, which is inherent to the honest
calculation rather than a confound.

**Row 7's existing figure is withdrawn.** The 78-of-130 occupancy cites no script and none exists in
the tree; its structural twin was already retired for that. The *bound* is a read and stands; the
occupancy must be re-taken with a committed script on the birth-date coordinate.

**Rows 6 and 12 are unblocked, and cheaply.** One cohort's block can be assembled by twelve calls to
an existing `sourceCpp` probe with unit basis vectors — so the matrix is reachable without new
production code, which is the opposite of what row 6 assumed. Its output-adjoint argument must be at
least twelve long or it corrupts the heap.

### 9.5 What not to measure yet, and why

**The cost measurements.** Four of the seven lettered measurements exist to show that an
optimisation pays: the tabulation's cost, the masking spike, the tabulation guard. Each is real and
each is evidence for a task rather than understanding of the model — and **the value of making a
wrong gradient faster is not defined.** Re-take them once, after the correctness items close, on
the blessed configuration of 9.1. Until then they motivate tasks; they do not rank them.

**Anything on the height coordinate.** It is out of scope, the two coordinates are different
functions rather than two discretisations of one — one sensitivity differs by a quarter and another
**changes sign** — and a figure taken there cannot be carried across.

**Anything across the forward-model correctness merge.** It touches the census, the field build and
the leaf. Numbers either side of it are not comparable and the corpus has already produced one
false alarm that way.

### 9.6 The order

1. **Build the forward tangent and bless the small fixture** (9.1). Nothing in the correctness
   half of the programme can be checked without it.
2. **Row 4**, the directional check of the waist. It needs no new fixture and no new code, and it
   is the largest unquantified correctness risk in the leaf.
3. **The four distributions** (9.3). Cheap, and each unblocks a claim; the height distribution
   decides whether a guaranteed non-finite row is reachable.
4. **Build the driver set** (9.2). Every incidence figure waits on it, and taking them earlier
   produces numbers about the old driver.
5. **Rows 5, 3 and 11** against that driver, in that order — the curvature question first, because
   the operating-point selector's design depends on its answer.
6. **Rows 2, 6, 7 and 12**, which are independent of the driver and can run in parallel with it.
7. **Rows 8 and 10** last, because each waits on code the plan has not built.
