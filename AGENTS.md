# Developer Guide for Agents (plant-dev Workspace)

This repository (`aornugent/plant-dev`) is a meta-repository (superproject) used to manage local development across the `traitecoevo` family of R packages: `odelia`, `plant`, `phylloptim`, `regnans`, `logpile`.

## Session Start (do this first, every session)

Four documents, and between them they are the whole design. Read them in this
order.

1. **[`docs/design/principles.md`](docs/design/principles.md)** — what a change
   here is judged against, and what has caught a defect that reading did not.
2. **[`docs/design/reverse-mode.md`](docs/design/reverse-mode.md)** — what the
   gradient computes, which five properties of the model force its shape, the
   forward and backward walks, and the alternatives it refuses with the
   measurement that refuses each. Read the refusals before proposing a
   simplification.
3. **[`docs/design/refusal.md`](docs/design/refusal.md)** — how the answer says
   that a point has no derivative. This one crosses all three packages and is the
   subtlest thing here.
4. **[`docs/design/leaf-derivatives.md`](docs/design/leaf-derivatives.md)** — why
   the leaf's rows are supplied rather than recorded, what the implicit function
   theorem needs, and what makes a point inadmissible.

**[`docs/perf/`](docs/perf/README.md) is the fifth, and only for performance
work.** Where the stand gradient's time goes now, the levers left and what each
is worth, six mechanisms refused with the measurement that refuses each, and the
gradient values a change has to reproduce. Three of its warnings generalise past
performance. ⚠️ **Cost is operations times the price of one, AND BOTH HALVES
MOVE** -- removing 1219 tape statements a placement changed the gradient by
nothing while a curve dismissed at four statements was a quarter of the
instructions, and then, with the arithmetic lean, a third of the leaf's
statements was a quarter of the gradient's time. Neither half can be read
without the other, and `callgrind` is exact where seconds on this fixture have
moved 81% for one binary. ⚠️ **A copy of an active scalar is a recorded
statement**, so `const T x = cond ? a : b;` over two actives costs one and
`const T&` costs none. ⚠️ And the gradient carries a rounding change AT A CURVE
KNOT through thirteen orders to the census metrics while the suite stays green,
so a value comparison against `docs/perf/values/current.tsv` is the guard rather
than a green run.

⚠️ **Set up the loop before starting.** A private R library, a `-fsyntax-only`
translation unit over the path you are changing, and a standalone probe for
anything about the tape. The first is hazard 4 below; the second is what makes a
rename across sixty sites a thirty-second check rather than a twenty-minute one;
the third is because a claim about the automatic-differentiation library's
behaviour is a measurement and not an argument.

⚠️ **Where a document and the code disagree about a symbol, the code is right.
Where they disagree about a decision, that disagreement is the finding.** Name a
symbol rather than a line number when you cite one: half the code citations in the
records these four replaced were wrong, five naming a file that no longer existed
and one off by 595 lines.

**Two bodies of earlier writing are in the git history rather than the tree.** The
nine reports under `docs/reports/00` through `09` stated what TF24 is, the algebra
of its derivatives, what a correct implementation must satisfy, and the ecology
behind the numbers, refereed against `plant`'s `develop` rather than against any
branch. Alongside them sat the design records this work was planned in. Recover
one when a question about the MODEL rather than the code comes up, and read it as
of its own date:

```sh
git log --diff-filter=D --name-only -- docs/reports docs/design   # the removing commits
git show <commit>^:docs/reports/00-tf24-dependency-map.md
```

## Remote Development
Add the sibling package repos to the session's GitHub scope so their issues and PRs are readable — `git submodule update --init` clones the
code, but issue/PR access is a separate grant:

1. Initialize submodules: `git submodule update --init --recursive`
2. Add each fork to the session scope (via `add_repo`): `aornugent/odelia` and
   `aornugent/plant`. Work items like `odelia#19` live in these trackers, not in
   `plant-dev`, so without this step the issues are inaccessible.

Each submodule also has an `upstream` remote configured pointing to the official `traitecoevo` repository (`traitecoevo/plant`, `traitecoevo/odelia`, etc).

System deps and R packages are installed by the environment setup script — you don't need to install them by hand.

## CRITICAL: Write Permissions
**Agents do NOT have push access to the `traitecoevo` organization repositories.** 

You must never attempt to push directly to `traitecoevo/*` remotes.

## Workflow for Agents
1. **Branching**: When starting work on a feature or bugfix, navigate into the relevant submodule directory (e.g., `cd plant`) and create a new branch.
2. **Committing**: Make your changes and commit them normally within the submodule.
3. **Pushing Changes**: Push your branches to the `origin` remote, which points to the `aornugent` fork (e.g., `git push origin my-feature`).
4. **Updating the Meta-Repo**: After pushing commits in a submodule, navigate back to the root of `plant-dev`. You will see that the submodule pointer has changed in `git status`. Add and commit this hash update in `plant-dev`, and push it to `origin` (`aornugent/plant-dev`).
5. **Propagating Upstream**: To get changes into the official `traitecoevo` repositories, you must instruct the user to create a Pull Request on GitHub from the `aornugent` fork to the `traitecoevo` upstream.

## Upstream Synchronization
To sync a submodule with the official repository, fetch and merge from the `upstream` remote, then push to the `origin` fork:
```bash
cd <submodule>
git fetch upstream
git merge upstream/master # (or main)
git push origin master
```

## Local Development
Iterate with `pkgload::load_all()` (or `devtools::load_all(".")`) rather than a full install — it picks up live R edits without a reinstall/reload cycle:
```r
library(odelia)              # must be a real install — see caveat
pkgload::load_all("plant")
pkgload::load_all("logpile")
```
`load_all()` still compiles a package's own C++ on first load / after C++ edits, so a `plant` C++ change is still a real (incremental) compile.

**Caveat — load `odelia` with `library()`, never `load_all()`.** `plant` resolves `odelia`'s compiled XAD `Tape` symbols at load time via `odelia`'s `.onLoad` (which needs a real installed package). Under `load_all("odelia")` this breaks with `undefined symbol: ...xad4Tape...`. So reinstall `odelia` (`install.packages("odelia", repos=NULL, type="source")`) after editing its C++, and `load_all()` freely for `plant`/`logpile`.

If a rebuild throws `undefined symbol` on load, clear stale build artifacts first: `rm -f src/*.o src/*.so` in the package dir, then reinstall.

### ⚠️ The build reports success without saying what it built

Seven hazards that cross a package boundary. None of them produces an error, and the
first two have each cost a session. Do these unconditionally rather than when
something looks wrong, because nothing will look wrong.

**1. A `phylloptim` header edit is invisible to `plant` until `phylloptim` is
reinstalled.** `plant` compiles `phylloptim`'s headers from the **installed** library
via `LinkingTo`, not from your working tree — and editing them moves no `.cpp`
timestamp in `plant`, so `make` finds nothing to do, the build succeeds, and the
`.so` goes on running the **old model**. The only symptom is numbers that do not
match what you just wrote. After any `phylloptim/inst/include/` edit:

```sh
rm -f phylloptim/src/*.o phylloptim/src/*.so plant/src/*.o plant/src/*.so
R CMD INSTALL --no-multiarch --preclean phylloptim
R CMD INSTALL --no-multiarch --preclean odelia          # see 2
cd plant && R_MAKEVARS_USER=/tmp/mk-O2 Rscript -e 'pkgbuild::compile_dll(".", debug = FALSE)'
```

where `/tmp/mk-O2` is any file holding the two lines below. ⚠️ **Both halves of
that invocation matter and each fails silently.** `compile_dll` defaults to
`debug = TRUE`, which is `-O0 -UNDEBUG`: about five times slower, and it moves
the trajectory as well, because floating-point contraction differs between
optimisation levels. And R places `PKG_CXXFLAGS` before its own `-O`, so the
package's own Makevars cannot raise it -- a user Makevars is the only thing that
wins. Confirm by grepping the build log for `-O2` and for `-O0`.

```make
CXXFLAGS = -O2 -g0 -DNDEBUG
CXX20FLAGS = -O2 -g0 -DNDEBUG
```

The same trap exists one level down inside `phylloptim` itself: R does not track
header dependencies, so `R CMD INSTALL` after editing `inst/include/` reuses a stale
`src/RcppR6.o` and the R layer runs the old model. `--preclean` is what avoids it.

**2. Installing `phylloptim` can replace the `odelia` fork with upstream's, and the
error names neither package.** `phylloptim/DESCRIPTION` carries
`Remotes: traitecoevo/odelia@v0.2.1`, so a **dependency-resolving** installer
(`install.packages(".")`, `devtools::install()`, `pak`) fetches upstream odelia over
the locally built fork. Upstream's carries none of the reverse-mode surface the
sweep calls, so the next `plant` build fails on a name that has been in your tree
all along — in a session that never touched odelia. Six occurrences across three
sessions.

`R CMD INSTALL` does **not** resolve `Remotes` and is therefore the safe form. Verify
after any `phylloptim` install, against the **version**, which is what the pin names and
is the one thing about the fork that cannot be renamed:

```sh
Rscript -e 'cat(as.character(packageVersion("odelia")))'
# 0.2.1 is what the pin fetches, i.e. upstream won; the fork is 0.3.1 or later
```

⚠️ **Do not put a symbol back here.** This check used to grep
`solve_adjoint_over_widenings` out of `sweep.hpp`, and the recording track renamed the
concept to `insertion` — so the check reported "not the fork" against a correctly
installed fork, every time, for anyone who ran it. A guard that always fails is one
people learn to ignore. The version moves when the package is rebuilt and never when a
name inside it changes, which is the property wanted.

**3. The XAD storage-class flags must pair between `plant` and `odelia`, and a
mismatch is undetectable.** Both `src/Makevars` set `-DXAD_NO_THREADLOCAL
-DXAD_USE_STRONG_INLINE`; XAD's active tape is a `__thread` variable defined in
odelia and read from plant, and **a storage-class mismatch does not change the
mangled name**, so the linker resolves it and the behaviour is undefined. Change one
and you must change the other.

`phylloptim/src/Makevars` sets neither, and is **exempt** — it uses `xad::fwd` only
and never references `Tape` or `xad::adj`, and forward mode is tapeless. That
exemption is silent: **the moment `phylloptim` gains a reverse-mode path it needs both
flags, and nothing will say so.**

**4. The installed library is shared, and another session can move it under you.**
`plant` compiles against the *installed* `odelia` headers, and every worktree and
background job on the machine installs into the same library, so what you see is a
compile error naming a symbol that has been in your tree all along. **Check before you
measure**: grep the installed headers for something only your branch has, immediately
before a build and again before a timing — a number taken across a swap is
unattributable and nothing announces the swap. Or take yourself out of the race and
install your `odelia` into a private library, ahead of the shared one:

  ```sh
  mkdir -p /tmp/mylib
  R_LIBS="/tmp/mylib:$HOME/R/x86_64-pc-linux-gnu-library/4.6" \
    R CMD INSTALL -l /tmp/mylib odelia
  # then export that same R_LIBS for every build, Rscript and test run
  ```

  Use `R_LIBS`, which *prepends*. `R_LIBS_USER` **replaces** the user library and
  hides Rcpp, BH, testthat and everything else with it.

**5. Build at `-O2` deliberately** — `pkgbuild::compile_dll()` appends
`-UNDEBUG -g -O0` *after* any user `CXXFLAGS`, so the last `-O` wins and a `Makevars`
asking for `-O2` is silently overridden. Pass `debug = FALSE` and confirm one compile
line in the log ends at `-O2` with no trailing `-O0`.

**6. A build can report success without compiling anything.** `make` does not track
the headers under `inst/include/` as prerequisites, so editing one leaves every object
file looking current: `compile_dll` then does nothing, prints nothing, and **exits 0**.
An empty build log is the tell — a real build of `plant` prints about 25 compile lines.
Compare `plant/src/plant.so`'s mtime against the header you edited before believing any
result, and `rm -f src/*.o src/*.so` after a header change rather than trusting the
incremental path.

The same shape reaches the checks: `odelia/tests/standalone/Makefile` carries its own
`CXXSTD` and does not follow the packages' `CXX_STD = CXX20`. Below C++20 every
`concept` in the core reads as `'concept' does not name a type` and the hundred errors
after the first are cascade. It sat at C++17 and had therefore not run since the core
gained concepts. **A guard that does not compile is a guard that does not run.**

**7. Adding a MEMBER to `odelia/interpolator.hpp` is an ABI break, and the segfault it
causes names a different file.** `drivers.hpp` embeds an interpolant, so its `sizeof` is
part of odelia's ABI — and odelia's own suite compiles the leaf-thermal example with
`sourceCpp` and **caches the resulting `.so`**, which is then reused against a freshly
installed odelia. Grow the interpolant and the cached library reads the wrong offsets:
`memory not mapped` inside `LeafSolver_value_and_gradient`, in a file with nothing to do
with interpolation, **and it passes when run on its own** — which is exactly what
`test-example-leaf-ad.R`'s known intermittent looks like. Prefer reading data into the
spans over storing another vector; if a member must be added, print
`sizeof(hermite_interpolator<double>)` against the installed header before and after.

## Testing plant — a short feedback loop

The main cost is the **C++ rebuild** for any change.

⚠️ **`pkgbuild::compile_dll()` DEFAULTS TO `debug = TRUE`, WHICH BUILDS AT `-O0`
WITH `-UNDEBUG -Wall -pedantic`.** It is 5x slower to run and it MOVES THE
TRAJECTORY -- an -O0 build of plant solved a shaded stand in 680 s against 126 s
and recorded 10879 steps against 11722, because `-O0` does not contract `a*b + c`
into an FMA. Both readings were nearly attributed to the change under test.
**Pass `debug = FALSE`, and read the `-O` flags out of the build log before
comparing a run against a recorded number.**

⚠️ **`pkgload::load_all()` AFTER A HEADER EDIT RUNS `R CMD INSTALL --preclean`,
WHICH DELETES `plant/src/*.o`.** It compares the newest source against the
library, so a one-line comment in a header is enough — and the cached objects
`pkgbuild::compile_dll()` left are gone, so the next build is a full one whatever
you do next. Two full rebuilds were spent this way. **Finish editing, then build,
then run**: never edit a header between `compile_dll()` and the script that loads
it. Where a header edit is unavoidable mid-loop, rebuild deliberately with
`Rscript -e 'pkgbuild::compile_dll("plant")'` before the run, so the cost is paid
once and visibly rather than inside a script that looks like it is only loading.

`plant` carries about 3,960 testthat assertions across 75 files, and running all of
them per edit is wasteful. The gradient suite is the expensive tier at 18 files;
everything else is 57 files. ⚠️ **Both tier timings want re-measuring at `-O2`
before you rely on either** — the figures this file used to give were taken at a
debug optimisation level, which is about five times slower and moves the
trajectory as well.

⚠️ **The cost of a file is decided by the patch lifetime its fixture runs, not by
which tier it is in.** Every TF24 stand crosses a stiffness cliff a little past a
lifetime of 3, so a single file outside the expensive tier can take longer than
the whole of it. Measured on one stand at TF24's default leaf mass per unit area:

| patch lifetime | 3 | 3.1 | 3.25 | 3.5 | 4 | 5 |
| --- | --- | --- | --- | --- | --- | --- |
| accepted steps | 205 | 215 | **842** | 3324 | 6068 | 9576 |
| seconds | 2.7 | 3.0 | 20.1 | 89.5 | 167.6 | 267.1 |

⚠️ **BUT THE LIFETIME IS A PROXY, AND THE THING TO COUNT IS THE INTRODUCTIONS.**
The two are confounded above, because the DEFAULT schedule is derived from the
lifetime and it is the schedule that does the work. Held at lifetime 5, varying
only how many of that schedule's 88 introductions are kept:

| introductions | 2 | 6 | 12 | 22 | 44 | 88 |
| --- | --- | --- | --- | --- | --- | --- |
| accepted steps | 136 | 140 | 146 | 156 | 178 | **9881** |
| seconds | 0.1 | 0.3 | 0.4 | 0.7 | 1.5 | **288** |

The cliff is between 44 and 88, and the cost per cohort-step FALLS across the
whole range, 0.47 ms to 0.19 ms — so it is the solver taking 55x the steps rather
than the arithmetic getting slower.

`test-events.R` is the case to know, and it is not this branch's doing. One of its
26 blocks — *"pulses wet the soil during a run"* — is the whole of its cost; the
other thirteen measured are milliseconds each. It clears `node_schedule_times`
meaning to shorten the run, which makes `add_strategies` regenerate the DEFAULT
schedule for a lifetime-5 patch: 88 introductions. The same recipe at two
introductions is 0.1 s. The file is byte-identical to `develop`,
`node_schedule_times_default` is unchanged, and under the height-linear
configuration `stem_hydraulics.h` states is bit-identical to the pre-#617 model
the same fixture takes 9019 steps against 9881 — ten per cent, not fifty-five
times.

So when a test is unexpectedly slow, count its introductions first.

Tiers of the loop, cheapest first:

1. **Per edit — the one file for the component you touched.** Tests map 1:1 to
   components by filename, so this is unambiguous; almost every file is < 2 s.
   ```r
   testthat::test_file("plant/tests/testthat/test-scm.R")
   ```
2. **Cross-cutting change — a filtered family.** `filter` matches the file-name
   stem after stripping `test-`/`.R` (a case-sensitive regex):
   ```r
   testthat::test_dir("plant/tests/testthat", filter = "strategy",  # test-strategy-*.R
                      stop_on_failure = FALSE)
   ```
3. **Fast pre-commit sweep — the 62 files that are not gradient files:**
   ```sh
   scripts/run-tests.sh '^test-gradient' "" invert
   ```
   ⚠️ **This launches every file at once with no concurrency cap**, so on a small
   machine it is not a sweep but a thrash: 57 processes on four cores completed
   none in fifty minutes. And `test-events.R` runs at a lifetime of 5 and does
   not finish at all. Run it where there are cores, or name a smaller family.
4. **The gradient ladder — 15 files, 553 checks, 58 s in one process.** It prints
   what each file claims and which of the four references answers it, and refuses
   to run if a file has no entry:
   ```sh
   cd plant && Rscript scripts/run-gradient-ladder.R              # all of it
   cd plant && Rscript scripts/run-gradient-ladder.R one-cohort   # one file
   ```
   The same files by pattern, to get the concurrency instead of the commentary:
   ```sh
   scripts/run-tests.sh '^test-gradient-ladder'
   ```
   *Structure, no trajectory, and where the assurance is concentrated* — the
   exhaustive block Jacobian and its rank structure, the same Jacobian at the
   states a trajectory reached, ten injected corruptions, the water channel's
   factorisation, and the completeness reference. Under 20 s; run it per edit.
   ```sh
   scripts/run-tests.sh 'gradient-ladder-(injection|one-cohort|factorisation|declared-zero)'
   ```
5. **The surface tier, which is not the ladder and costs sixteen times as much.**
   `demo`, `incidence` and `parity` ask where the model goes and whether the
   gradient follows — scope, not correctness — and they are 945 s against the
   ladder's 58.
   ```sh
   scripts/run-tests.sh '^test-gradient-(demo|incidence|parity)'
   ```
   ⚠️ **DO NOT REACH FOR `^test-gradient`.** It matches all eighteen, so it puts
   those three in front of the ladder and is what makes the ladder look like a
   ten-minute suite. The cost is fixture construction, not checking: parity's five
   blocks are 329.0, 0.0, 0.1, 0.0 and 0.0 s, because the first builds every stand
   and the rest read a cache. `scripts/run-tests.sh` sets `PLANT_TEST_CACHE` so
   the second run of a tier reads that cache from disk instead — 403 s to about 2.
   Its key is an md5 of the built library and the files defining the fixture, so a
   rebuild is never answered from an older build's entry.

**Read those figures as CPU, not as wall clock, and run the suite with
`scripts/run-tests.sh`.** `testthat`'s own parallel workers cannot see a
`pkgload::load_all()`ed package, so a `test_dir()` has to run serial and its wall time
is its CPU time. One R process per file gets the concurrency back — `load_all()` costs
about two seconds per process and the files are independent — so **the number that
decides how long a run takes is the slowest single file, not the total**: sixteen cores
run the whole ladder in about a minute. The script names any file that produced no
result line, which is the one way this loses information a `test_dir()` would not: a crashed
process is otherwise silent.

```sh
scripts/run-tests.sh '^test-gradient-ladder'        # all fifteen
scripts/run-tests.sh 'gradient-ladder-(injection|one-cohort|factorisation|declared-zero)'
scripts/run-tests.sh '^test-gradient' "" invert     # the 57 other files
```

**Set `PLANT_TEST_LIB` to a private library holding your `odelia` build**, which
is how you stay out of the race described above; it is prepended, so the user
library is still visible.

### ⚠️ What makes a timing here worthless

Three ways to measure this suite and learn nothing. Two of them cost this session
a claimed regression that did not exist.

- **`plant/src/plant.so` has to be there first.** `pkgbuild::compile_dll` does not
  reliably leave it in `src/`; `pkgload::load_all("plant")` is what puts it there.
  Without it **every one of the parallel processes compiles plant itself**, which
  both collides on the install lock and means the number you took was N builds.
  Run one `load_all` and confirm the file exists before timing anything.
- **One suite at a time.** The runner launches every file with `&` and waits, with
  no concurrency cap, so a second suite halves the cores. And wall time is bounded
  by the slowest single file, not the total — which is why a per-tier CPU figure
  tells you nothing about wall time, and why a stale file count invalidates the
  comparison entirely.
- **`pgrep -c R` does not count R processes.** It matches any process whose name
  contains `R`, and reports tens where one is running. Use `pgrep -x R`.

And a claim about speed needs a *control*: the same file, both sides, interleaved
in one session. A figure from this file is not a control — it is a figure from
whenever it was last true.

⚠️ **A wall-clock delta below about 3% is not evidence here, whatever the
control says.** A same-source, same-core, byte-identical A/B on the century
fixture reproduced a 2% gradient gap between two installed copies of the same
tree, and a fresh copy of the slower one was fast. So verify a performance claim
by a **counted** quantity — tape statements, placements, row counts, rate
evaluations — and treat a timing as a sanity check on the count, never as the
finding.

⚠️ **`identical(NaN, NaN)` is TRUE in R, so a bit-identity check passes against
an all-NaN answer.** Every such check on the century fixture's gradient passed
for as long as the fixture existed, against a gradient that was entirely
not-a-number. Count the finite entries and assert the count before comparing
values, in any test that claims two runs agree.

**One suite fails, and it is named below; any other failure is yours.** Read the
SKIP count alongside the failures: a test that stops running looks exactly like a
test that passes, so a skip where there was none is a guard that stopped guarding.
`test-stochastic-patch-runner.R` is the one file whose PASS count varies run to run.

⚠️ **`test-model-version.R` reports `fail=4`, and that is the expected state
until a version is declared.** Its snapshot records the scientific surface each
model promises to keep, and three defaults have moved on this branch — the leaf's
vulnerability-curve resolution, the new `gradient_curvature_floor`, and TF24's
trait names under the (P50, c) reparameterisation. The four diffs are that change
asking to be acknowledged. Clearing them needs a `scientific_version` decision for
TF24 and then `testthat::snapshot_accept("model-version", "plant/tests/testthat")`,
in that order. ⚠️ Do not accept the snapshot to make a run green: accepting is how
a real change to a model's science gets waved through, and the whole point of the
guard is that somebody names the version.

⚠️ **Count the RESULT lines, because a crashed file is not a failing file.** The runner
prints one `RESULT` line per file and the totals are a sum of those -- so a run where ten
of eighteen ladder files segfaulted printed `pass=242 fail=45` and read, at a glance, as a
suite with some failures rather than one that mostly died. The ladder is 18 files: check
that 18 reported before reading the totals.

⚠️ **And a segfaulting suite WEDGES rather than failing fast.** `core_pattern` pipes to
apport, which stalls dumping a ~100 MB R process, so the crashed workers sit in
`futex_wait_queue` at nil CPU and the runner's `wait` never returns -- no totals, no
error, just silence. Kill the crashed workers to get the totals out. `pgrep -x R` finds
them, and note that a `pgrep` whose own pattern appears in its command line matches
itself, which is the same trap as `pgrep -c R`.

## Testing phylloptim

The C++ suite is the fast loop and needs no R at all:

```sh
make -C phylloptim/tests/cpp CXX=g++            # builds and runs test_leaf and test_golden
make -C phylloptim/tests/cpp CXX=g++ bench_solve bench_gradient   # CI builds these too
```

`test_golden` must be run from `tests/cpp` — it looks for `golden/operating_points.tsv`
relative to the working directory and reports it MISSING from anywhere else.

The golden file is bit-exact only on macOS/arm64, where it was generated, so the
comparison that means anything depends on where it runs — and `make` now picks it:
bit-exact there, `--cross-platform` everywhere else. **A failure is a real signal on
either.** This used to read "`make` failing on that target alone is not a regression",
which was true of the bit-exact run on Linux and taught everyone to ignore the one
guard that could speak: two commits stated that the operating-point surface had moved
and that the file re-blessed, neither re-bless landed, and the staleness sat unread.

⚠️ **The R suite needs the package namespace as its parent environment, and without it a
third of the suite reports as broken code.** Several tests call internals by name, so a plain
`test_dir()` reports *"could not find function"* — which reads like a missing binding and is a
missing environment. The wrong invocation fails in bulk while the right one passes clean,
so the failures name the environment rather than any model.

```sh
Rscript -e 'library(phylloptim)
  testthat::test_dir("tests/testthat",
    env = new.env(parent = asNamespace("phylloptim")), stop_on_failure = FALSE)'
```

## Testing odelia

```r
library(odelia)
testthat::test_dir("odelia/tests/testthat",
                   env = new.env(parent = asNamespace("odelia")))
```

**Both halves of that `env` matter and each fails differently.** A plain
`test_dir()` cannot see the `.Call` wrappers several tests invoke by name, and
reports them as *"could not find function"* — an error that looks like broken code
and is broken invocation. Passing `asNamespace("odelia")` itself instead of a child
fails at the first helper with *"cannot add bindings to a locked environment"*.

**The suite compiles its probes with `sourceCpp`, and a probe that does not agree with
the shipped library fails in ways that read as unrelated.** Two settings have to match
`src/Makevars`, and they live in different places. The XAD defines
(`XAD_NO_THREADLOCAL`, `XAD_USE_STRONG_INLINE`) come from `odelia_cppflags()` in
`tests/testthat/helper-load-odelia.R` and nowhere else; a probe missing them links
against a symbol of the same mangled name in the other storage class. The standard
cannot go there — `PKG_CPPFLAGS` is placed before R's own `-std=`, which then wins — so
it stays a `// [[Rcpp::plugins(cpp20)]]` line inside each probe, and any probe including
an odelia header that names a concept needs it.


## What continuous integration covers, and what it does not

Each package checks itself: `R-CMD-check` on three operating systems in `plant`
and `odelia`, and in `phylloptim` a pair of workflows kept deliberately apart so
that one of them builds `inst/include/` on runners with no R and can therefore
notice an Rcpp include creeping into a model header.

⚠️ **Every one of those filters names the long-lived branches only, so a push to
a feature branch runs nothing and its failures wait for the pull request, where
they arrive together.** Expect no per-push signal at all while working on a
feature branch. Widening those filters is a maintainer's decision rather than
something to do while landing a feature, because it changes how continuous
integration behaves for everyone working in the package on every branch; raise it
upstream if you want it. ⚠️ Note while you are there that
`phylloptim/.github/workflows/cpp-tests.yml` records the same class of defect
from the other direction: its filter named a branch that repository does not
have, so it sat unexercised from the day it was added until the first pull
request. A trigger filter is one of the things that fails by doing nothing.

⚠️ **AND NOTHING CHECKS THE COMBINATION, which is the one thing no per-package
job can.** `plant/DESCRIPTION` pins its siblings exactly — `LinkingTo: odelia
(== …), phylloptim (== …)` — so a partial landing fails at build rather than at
run time. That declaration is unverified: each package's own checks resolve
`Remotes` and install whatever those name, which is not necessarily what this
superproject's submodule pointers say. So the combination is yours to check by
hand, in dependency order, per the rebuild recipe above.

Two specific things go unchecked as a result, and both are worth doing before a
landing:

* **That every pinned version is the version installed.** Compare
  `plant/DESCRIPTION`'s `LinkingTo` against `packageVersion()` for each sibling.
* **That every `Remotes:` entry names a ref that still resolves.**
  `plant/DESCRIPTION` and `phylloptim/DESCRIPTION` both pin `ad/v3-forward`, a
  branch on a fork. Those resolve today and stop resolving the moment the branch
  is merged and deleted, at which point neither package can be installed and the
  error names a ref rather than a cause. Point them at a tag or at a default
  branch as part of landing. `git ls-remote --exit-code <url> <ref>` is the check.

## What is named once, and where

Facts this codebase used to spell in several places, each now with one home. Every one
of them was a place two spellings could disagree while both compiled.

- **The AD library is named in `odelia` and nowhere else.** Scalars come from
  `active_scalar<T>`, `adjoint_tape<T>` and `tangent_scalar<T>`; the two things done to
  a tangent come from `seed_direction` and `derivative_along` in `odelia/tangent.hpp`, a
  header apart from the reverse-mode one so a package with no tape is not handed a name
  for one. Those accessors exist because **one library accessor spells a tangent's
  direction AND an adjoint's accumulator** — on the wrong scalar the same statement
  seeds a slot no forward pass reads, and nothing raises. They refuse it instead.
  Reading a value at a boundary is `util::to_passive`, which strips every layer, not the
  library's one-layer accessor: the two differ at the nested scalar a forward-over-
  reverse check runs on.
- **Interpolation is `odelia/interpolator.hpp`.** The order is set by the source, not
  chosen: a cubic is what two exact channels support and a quintic what three do, and
  `set_data` has one signature per order so the wrong number of channels does not
  compile. A curve and its derivative are one table — tabulate the lowest derivative
  anyone reads and take the higher ones from the same polynomial.
- **A census metric is the strategy's**, declared by `census_metrics()` beside
  `state_names()` and read by index out of `Internals`. Nothing outside the model names
  a metric, and a metric crosses to R as a name rather than a position.
- **`HEIGHT_INDEX`, `MORTALITY_INDEX` and `FECUNDITY_INDEX` are a claim about every
  model's first three state slots** that about fifty readers make. `check_state_layout`
  checks it, from each model's `refresh_indices()` where the map that would falsify it is
  built; `test-state-layout.R` hands the checker a broken layout, because a test that
  only builds models would pass whether or not the check existed.
- **A batch of transpose rows is `odelia::ode::adjoint_rows`**, one width for every row, so
  a ragged batch is not a shape a caller can build.

## Code style

Match the existing header core exactly: when editing a file, continue it;
when creating a file, first read the two most similar existing headers and
write as their continuation. The exemplar at the end covers the greenfield
case. What must stay true in this codebase: only `double` crosses the R
boundary — active (AD) types are C++-internal, created and destroyed inside
one call.

### Never (comments)

- No process history: issue tags (`RIF-`, `ODELIA-`), "renamed from",
  "successor to", "used to be", doc-section references (`§`), plan-item numbers.
  A *live* cross-package dependency is not history and belongs in the comment —
  "bumping this invalidates logpile's cache" is a fact about today.
- No metaphor or borrowed mechanism words: write what happens ("record", not
  "flush"); never `frozen`/`live`/`flush`/`pipeline`/`handshake`. Single words
  count. ⚠️ **The ban is on the metaphor, not the word.** `resident` and
  `mutant` are adaptive dynamics' own nouns and this package exports
  `add_mutant`, `run_mutant`, `remove_residents`; a `surface` can be the soil
  surface; a `branch` can be a root-find's. Read the sentence before editing it.
- No decorative nouns ("contract", "oracle", "machinery", "the whole point"),
  no section banners. Never define a thing by what it isn't — but a second
  sentence that heads off a specific misreading is not that, and is often the
  load-bearing half ("not by differencing the times, because …").
- Never longer than two lines unless spelling out a genuine silent-failure
  hazard. If a comment exists to decode a name, rename instead.
- **A comment that justifies a design is a claim.** Write it so a reader can
  check it, and state a hazard as a prohibition rather than as its own history:
  "DO NOT change this to by-value and move, because …", not "this used to be
  by-value and move".

### Never (code)

- No parallel near-copy of an existing type or path; modify what exists.
- No re-implementing what vendored XAD provides.
- No runtime capability flags or SFINAE detection structs. A compile-time
  **choice** is a concept plus `if constexpr`; a compile-time **refusal** is a
  concept inside a `static_assert`. Both are concepts, only one has a branch —
  and `if constexpr (!C) { static_assert(false); }` is ill-formed in C++20 even
  in the discarded branch, so writing a refusal that way needs a helper for a
  false predicate, which is the machinery this rule exists to avoid.
- No storing what can be derived; no passing a count that can disagree with
  its source of truth.
- No dropping a guarantee (bounds check, cleanup path) during a refactor; no
  demo code compiled into the shipped .so; no dead files after a rename.
- **Never let a function or lambda that returns an AD value use a deduced return
  type.** XAD operators return *expression templates* holding references to their
  operands, so a deduced return type hands the caller references to temporaries
  and by-value parameters that die on return. The caller then materialises a
  dangling expression and records whatever the reused stack now holds as a tape
  slot; the reverse sweep dereferences it and segfaults far from the cause.
  Valgrind cannot see it — the dangling storage is stack, not heap. Declare the
  scalar return type (`-> S`, `-> T`) on every such lambda, including one-line
  helpers. This cost a session to find (plant TF24's `anchor` supplied-derivative
  lambda). The one structural defence is `odelia::implicit_value`'s `static_assert`
  on its
  residual's return type, which turns the mistake into a compile error at the
  one site that most invites it.

      // BAD  -- returns a dangling expression template
      auto anchor = [](double v, S x) { return S(v) + (x - to_passive(x)); };
      // GOOD -- the same arithmetic, materialised while its operands are alive
      auto anchor = [](double v, const S& x) -> S { return S(v) + (x - to_passive(x)); };

  The two forms differ only in `-> S` and taking `x` by reference, and that is
  the whole lesson: the fix is the declared return type, not a helper.

### Defaults to unlearn

Each BAD below is the habit to suppress; write the GOOD form.

**Narrating rationale.** State the thing; one clause of why at most.
```cpp
// BAD
// The active solver is cached on the double Solver object and reused, so an
// optimiser loop amortizes it (tape included) rather than rebuilding each
// call. Reuse is pure speed: values are re-seeded every call and per-call
// state is handed in by the caller, so a stale cache can never change a
// number.
```
```cpp
// GOOD
// R holds only the double Solver; these helpers differentiate on the active
// solver (the double System lifted via rebind_from) and return doubles.
```

**Documenting process instead of the thing.**
```cpp
// BAD
// value + least-squares gradient on the double handle (RIF-1): the
// double-handle successor to the retired LeafSolver_fit ...
```
```cpp
// GOOD
// Value + least-squares gradient on the double handle. Observations are
// passed per call and owned by the functional; the solver holds no
// calibration state.
```

**Banners and grand nouns.**
```cpp
// BAD
// ---- AD input contract ---------------------------------------------------
// AD input contract: seed one active parameter or initial-state value by
// index.
```
```cpp
// GOOD
// The differentiable inputs, in the order DifferentiationTargets indexes
// them: parameters (sigma, R, b) then initial state (y0, y1, y2).
```

**Formalising states that don't exist.**
```cpp
// BAD
enum class ReplayMode { Idle, Recording, ReplayLive, ReplayFrozen };
ReplayMode mode_;
```
```cpp
// GOOD
bool recording = false;
bool replaying() const { return !recording && has_recording(); }
```

**A per-item special case where a mechanism scales.**
```cpp
// BAD
void set_param(int i, T v) {
  switch (i) {
    case 0: sigma = v; break;
    case 1: R     = v; break;
    case 2: b     = v; break;
    default: util::stop("set_param: index out of range");
  }
}
```
```cpp
// GOOD
std::vector<T*> ad_parameters() { return {&sigma, &R, &b}; }
// (and keep the guarantee: callers bounds-check against .size())
```

### Exemplar — write new files indistinguishable from this

*(Composite from reviewed code; replace with a real excerpt from the header
core when landing this.)*

```cpp
// A one-state canopy that relaxes toward the light it captures -- the
// demonstrator for record -> replay, which Lorenz and leaf_thermal don't
// exercise.
template <typename T>
class CanopySystem {
public:
  // The single differentiable input; this canopy has no seedable initial
  // state.
  std::vector<T*> ad_parameters() { return {&gain_}; }

  void derivs(double t, const std::vector<T>& y, std::vector<T>& dydt) {
    // Plain double, off the tape: the background is fixed on a replay pass,
    // so d(rate)/d(bg) is structurally zero.
    const double bg_light = stage_light_.at(stage_);
    dydt[0] = gain_ * captured(bg_light) - y[0];
  }

  // On the replay pass, let a Replayable System restore what it recorded for
  // this step; a no-op otherwise.
  void replay_step(int step) {
    if constexpr (Replayable<CanopySystem>) load_recorded(step);
  }

private:
  T gain_{0.5};
  std::vector<double> stage_light_;  // this step's light at each of the six
                                     // RK stages
  int stage_{0};
};
```

```cpp
// Value + least-squares gradient on the double handle. Observations are
// passed per call and owned by the functional; the solver holds no
// calibration state.
template <class System>
Rcpp::List Solver_gradient(SEXP double_solver, Rcpp::NumericVector obs) {
  auto* solver = get_solver<System>(double_solver);
  solver->tape->activate();
  tape_scope<Tape> running{*solver->tape};  // activates unless something else
                                            // holds it; releases where it took it
  const std::size_t codomain = functional.codomain();
  auto jacobian =
      xad::computeJacobian(inputs, forward, codomain, solver->tape.get());
  return to_r_list(jacobian);  // only doubles cross the boundary
}
```