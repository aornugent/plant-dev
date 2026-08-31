# Developer Guide for Agents (plant-dev Workspace)

This repository (`aornugent/plant-dev`) is a meta-repository (superproject) used to manage local development across the `traitecoevo` family of R packages: `odelia`, `plant`, `phylloptim`, `regnans`, `logpile`.

## Session Start (do this first, every session)

Read [`docs/design/principles.md`](docs/design/principles.md). It carries the rules
this work is judged by and a map of the other documents, saying which one is live.

**Then read the first two sections of
[`docs/design/two-paths.md`](docs/design/two-paths.md)** -- "Where this got to" and
"What is left". That objective is delivered bar one item, and those two sections say
which item and what else is open in the records. The rest of that file, and every
other document here, is the record: kept for why a shape is what it is rather than for
anything outstanding.

⚠️ **Set up the loop before starting.** A private R library, a `-fsyntax-only`
translation unit over the path you are changing, and a standalone probe for anything
about the tape. `two-paths.md`'s "A loop worth keeping" says why each; the first is
hazard 4 below, and the second is what makes a rename across sixty sites a
thirty-second check instead of a twenty-minute one.

⚠️ **Read a record as of its own date.** Several of them narrate a past state in the
present tense, and three function names they use exist in no code file. Where a
document and the code disagree about a symbol, the code is right; where they disagree
about a *decision*, that disagreement is the finding.

**The nine reports that used to be listed here are gone from the tree and live in the git
history.** `docs/reports/00` through `09` stated what TF24 is, the algebra of its
derivatives, what a correct implementation must satisfy, and the ecology behind the
numbers -- refereed against `plant`'s `develop` rather than against any branch. Recover
one when a question about the MODEL rather than the code comes up:

```sh
git log --diff-filter=D --name-only -- docs/reports   # the commit that removed them
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
cd plant && R_MAKEVARS_USER=<O2 makevars> Rscript -e 'pkgbuild::compile_dll(".", debug = FALSE)'
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

`plant` carries about 3,960 testthat assertions across 75 files, but running all of
them per edit is wasteful. The gradient ladder is the expensive tier — 18 files,
**61 s of wall** measured at `-O2` — and everything else is 57 files and about
90 s. No single file outside the ladder is slow enough to matter.

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
3. **Fast pre-commit sweep — everything except the ladder (86 s of wall, 57/75
   files):**
   ```sh
   scripts/run-tests.sh '^test-gradient' "" invert
   ```
4. **The gradient ladder, in three tiers.** Its files are named so the pattern
   selects a tier, and the whole ladder is about a minute of wall run this way.

   *Structure, no trajectory (~40 s of CPU, a few seconds of wall).* Where the
   assurance is concentrated: the exhaustive block Jacobian and its rank structure,
   the same Jacobian at the states a trajectory reached, ten injected corruptions,
   the water channel's factorisation, and the completeness reference. Run this per
   edit.
   ```sh
   scripts/run-tests.sh 'gradient-ladder-(injection|rung3|factorisation|declared-zero)'
   ```
   *Trajectory — the bulk of the ladder's cost.* floor, identity, rung4, columns,
   rung5, recruit, sweep, switches — accumulation across cohorts and species, the
   stage recursion, introductions, the boundary channels, and refusal. Run before
   landing sweep work.
   ```sh
   scripts/run-tests.sh '^test-gradient'
   ```
   *One file when you know what you touched.* `identity` for anything that changes
   how a sweep is decomposed; `recruit` for the inflow boundary; `columns` for the
   per-column contraction; `switches` for a channel's route to a census.


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
scripts/run-tests.sh '^test-gradient-ladder'        # the whole ladder
scripts/run-tests.sh 'gradient-ladder-(injection|rung3|factorisation|declared-zero)'
scripts/run-tests.sh '^test-gradient' "" invert     # the 57 non-ladder files
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

**Every suite passes, so any failure is yours.** Read the SKIP count alongside the
failures: a test that stops running looks exactly like a test that passes, so a skip
where there was none is a guard that stopped guarding. `test-stochastic-patch-runner.R`
is the one file whose PASS count varies run to run.

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
  "successor to", doc-section references (`§`), or mentions of other repos.
- No metaphor or borrowed mechanism words: write what happens ("record", not
  "flush"); never `frozen`/`mutant`/`live`/`resident`. Single words count.
- No decorative nouns ("contract", "surface", "oracle"), no section banners.
  Never define a thing by what it isn't.
- Never longer than two lines unless spelling out a genuine silent-failure
  hazard. If a comment exists to decode a name, rename instead.

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