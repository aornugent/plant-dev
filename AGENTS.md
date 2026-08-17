# Developer Guide for Agents (plant-dev Workspace)

This repository (`aornugent/plant-dev`) is a meta-repository (superproject) used to manage local development across the `traitecoevo` family of R packages: `odelia`, `plant`, `phylloptim`, `regnans`, `logpile`.

## Session Start (do this first, every session)

Read the reference material. It divides into two layers, and the division is what keeps it true:

**The model — what TF24 is.** Its referee is `plant`'s `develop`. These name no code and no
commit, and a claim in them is wrong if the model disagrees with it, not if some branch does.

- [`docs/reports/00-tf24-dependency-map.md`](docs/reports/00-tf24-dependency-map.md) — **the
  first reading.** Its physical reading gives the five facts TF24's gradient follows from, its
  end-to-end walk states the flow forwards and backwards in prose, and §6 classifies every
  partial. Read it before the others; they are its detail.
- [`docs/reports/05-reverse-mode-mathematics.md`](docs/reports/05-reverse-mode-mathematics.md)
  — **the derivatives**, and what a correct implementation of them must satisfy. Read it
  beside report 00: 00 states the dependency structure and where each partial goes, 05 states
  the algebra.
- [`docs/reports/06-what-the-gradient-means.md`](docs/reports/06-what-the-gradient-means.md)
  — the ecology behind those derivatives, section for section, and what it would be wrong
  to conclude from a number this machinery produces. Read it if you are deciding whether a
  defect matters, and read its closing section as the domain that must accompany any number
  the machinery produces.

**The design — what follows from the model.** Its referee is the mathematics plus the objective:
correct, performant and stable reverse-mode gradients of a TF24 stand, with the feedbacks through
light and soil intact.

- [`docs/reports/01-cohort-granular-reverse-sweep.md`](docs/reports/01-cohort-granular-reverse-sweep.md)
  — the decomposition that makes peak memory one cohort-step, its forced ordering, and what it
  demands of the model it decomposes.
- [`docs/reports/02-leaf-implicit-node.md`](docs/reports/02-leaf-implicit-node.md) — the leaf as
  one node whose local Jacobian is supplied, and the contract a boundary carrying it must meet.
- [`docs/reports/03-light-interpolant-value-and-slope.md`](docs/reports/03-light-interpolant-value-and-slope.md)
  — what the light field has to be for its transpose to be local, exact and refinable.
- [`docs/reports/07-structure-worth-exploiting.md`](docs/reports/07-structure-worth-exploiting.md)
  — where the system is narrower than it looks, and what each narrowing buys. Its test is
  whether resident trait gradients, calibration, invasion and equilibrium are one machinery
  with different adapters. Read it before scoping any cost work, or any interface.

- [`docs/reports/04-before-the-plant-exists.md`](docs/reports/04-before-the-plant-exists.md) —
  parameterisation, construction and the inflow boundary: the three places upstream of a
  cohort's rates where a derivative is decided, and where an imposed zero is
  indistinguishable from a channel the model does not have. Read it before touching a
  derived quantity, a declared zero, or the seed.

**None of these tracks progress**, and none is edited to record what has been built. If a report
disagrees with the code, one of them is wrong and the disagreement is the finding. Report 04's
number was previously vacant: it had argued which discretisation the density's compression term
should use, and the birth-date coordinate removed that question rather than settling it — what
survives of the original is report 00 §4.4, and the number now carries the subject above.

`docs/archive/` holds documents whose conclusions are stale, superseded or
configuration-dependent. **Do not design from them.**

Then, add the sibling package repos to the session's GitHub
scope so their issues and PRs are readable — `git submodule update --init` clones the
code, but issue/PR access is a separate grant:

1. Initialize submodules: `git submodule update --init --recursive`
2. Add each fork to the session scope (via `add_repo`): `aornugent/odelia` and
   `aornugent/plant`. Work items like `odelia#19` live in these trackers, not in
   `plant-dev`, so without this step the issues are inaccessible.

Each submodule also has an `upstream` remote configured pointing to the official `traitecoevo` repository (`traitecoevo/plant`, `traitecoevo/odelia`, `traitecoevo/logpile`).

System deps and R packages (including `gh`, `logger`, and `RcppR6`) are installed by the environment setup script — you don't need to install them by hand.

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

**The installed library is shared, and another session can move it under you.**
`plant` compiles against the *installed* `odelia` headers, and every worktree and
background job on the machine installs into the same library. So a second session
working on `odelia` replaces yours mid-run, and what you see is a compile error
naming a symbol that has been in your tree all along — a defect in someone else's
branch wearing your code's face. It happened twice in one hour during the reverse-
pass work, once *during* a build.

Two habits make it survivable:

- **Check before you measure.** Grep the installed headers for something only your
  branch has, immediately before a build and again before a timing or a test run.
  A number taken across a swap is unattributable, and nothing announces the swap.
- **Or take yourself out of the race.** Install your `odelia` into a private
  library and put it *ahead* of the shared one:

  ```sh
  mkdir -p /tmp/mylib
  R_LIBS="/tmp/mylib:$HOME/R/x86_64-pc-linux-gnu-library/4.6" \
    R CMD INSTALL -l /tmp/mylib odelia
  # then export that same R_LIBS for every build, Rscript and test run
  ```

  Use `R_LIBS`, which *prepends*. `R_LIBS_USER` **replaces** the user library and
  hides Rcpp, BH, testthat and everything else with it.

## Testing plant — a short feedback loop

`plant` carries about 3700 testthat assertions across 68 files, but running all of
them per edit is wasteful. Measured at `-O2`: the gradient ladder is **1172 s of CPU
over 13 files**, everything else is **339 s over 55**, and no file outside the ladder
exceeds 63 s.

**Read those as CPU, not as wall clock. Run them with `scripts/run-tests.sh`,
which is the preferred way to run this suite** — one R process per file, so **the
number that decides how long a run takes is the slowest single file, not the
total**, and it works under `load_all()`, which `testthat`'s own parallel workers
do not (see below). Measured on sixteen cores, the whole ladder is **17 s of
wall** that way. The CPU figure was 719 s before three files of about 700 s each
were split and the sweeps they repeated were shared; what bought that was
rebalancing and de-duplication, not removing a single check.

Two costs to scope against, then: the **C++ rebuild** for any change, and **the
ladder** for anything touching the reverse sweep. (Build / `load_all` /
odelia-reinstall mechanics are under *Local Development* above; paths below are from
the `plant-dev` root.)

**Build at `-O2` deliberately: `pkgbuild::compile_dll()` defaults to `-O0`.** It appends
`-UNDEBUG -g -O0` *after* any user `CXXFLAGS`, so the last `-O` wins and a `Makevars` asking for `-O2`
is silently overridden — a timing taken that way measures the debug build, which is roughly twice as
slow. Pass `debug = FALSE`:

```sh
cd plant   # or a develop worktree
R_MAKEVARS_USER=/path/to/Makevars-O2 Rscript -e 'pkgbuild::compile_dll(".", debug = FALSE)'
```

with `Makevars-O2` holding `CXX20FLAGS = -O2 -DNDEBUG -g0`. Confirm it took by checking that the
compile line for one translation unit in the log ends at `-O2` with no trailing `-O0`.

**The per-iteration tax is the rebuild, not the tests.** An R-only change under
`pkgload::load_all("plant")` skips compilation; a C++ change recompiles
incrementally — but the strategy/environment core is header-inline, so editing a
header in `plant/inst/include/` invalidates every translation unit that includes
it and triggers a near-full `plant/src` recompile. Build optimised once
(`cd plant && make`, `-O2`), then `load_all()` reuses that `.so`; a bare
`load_all()` without `make` builds unoptimised and makes every slow test several
times slower (the difference between a ~3 min suite and the ">8 min" quoted in
an earlier handover note, now recoverable from `archive/v3-docs-and-probes`).

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
3. **Fast pre-commit sweep — everything except the ladder (86 s of wall, 55/68
   files):**
   ```sh
   scripts/run-tests.sh '^test-gradient' "" invert
   ```
4. **The gradient ladder, in three tiers.** Its files are named so the pattern
   selects a tier, and the whole ladder is 17 s of wall run this way.

   *Structure, no trajectory (~40 s of CPU, a few seconds of wall).* Where the
   assurance is concentrated: the exhaustive block Jacobian and its rank structure,
   the same Jacobian at the states a trajectory reached, ten injected corruptions,
   the water channel's factorisation, and the completeness reference. Run this per
   edit.
   ```sh
   scripts/run-tests.sh 'gradient-ladder-(injection|rung3|factorisation|declared-zero)'
   ```
   *Trajectory (~1130 s of CPU, 17 s of wall).* floor, identity, rung4, columns,
   rung5, recruit, sweep, switches — accumulation across cohorts and species, the
   stage recursion, introductions, the boundary channels, and refusal. Run before
   landing sweep work.
   ```sh
   scripts/run-tests.sh '^test-gradient'
   ```
   *One file when you know what you touched.* `identity` for anything that changes
   how a sweep is decomposed; `recruit` for the inflow boundary; `columns` for the
   per-column contraction; `switches` for a channel's route to a census.

**Always cheap, run it when numerics move:** the FF16 bit-identity guard
(`test-strategy-ff16.R` ~4 s, plus `test-strategy-ff16-reference-comparison.R`)
is the tripwire for the scalar-templating AD work — a changed reference number
means bit-identity broke. Include it in tiers 1–2 whenever you touch a strategy,
environment, the ODE path, or anything the active scalar `S` threads through.

**What the ladder's cost actually is, so it can be scoped rather than guessed.** A
sweep of one four-node stand at the fixtures' two-year lifetime is **43.6 s**, one
trajectory tangent column is **4.8 s**, and building the stand is **0.13 s** — the
run is free and the sweep is everything. Sweeping one metric costs the same as
sweeping three, so the record is shared across them already. The cost is linear in
the fixture's step count: 102 steps at lifetime 2 against 35 at lifetime 0.5, 43.6 s
against 14.1 s. So a ladder file's runtime is its sweep count times 43.6 s, and
nothing else moves it. **Memoising the stands is not a speedup** — it was tried and
measured at 3.6 s of 2333 s, because the run was never the cost. What did work was
sharing one sweep per fixture between the checks that only READ it
(`ladder_shared()`), and putting the checks whose assertion is an exact identity or a
limit on a short fixture: neither re-blesses anything, because bit-identity and a
limit do not depend on run length.

**And the stand fixtures damp what they measure, which bears on what the slow tier is
worth.** A run stand sits at a reserve-gate slope of **0.040** against the declared
floor of 0.4, and at a relative reserve of 0.45 to 0.56 against the band 0.02 to
0.30, where a constructed patch sits at 0.99. So every growth-mediated channel is
tested at about a tenth of its sensitivity on a stand and at full sensitivity on a
patch. The regime table reports both rather than enforcing the stand's, and any
margin taken on a stand carries that qualification.

**The heaviest non-ladder files, and what they cover:** `test-census.R` (63 s),
`test-strategy-tf24.R` (59 s), `test-density-coordinate.R` (33 s),
`test-tf24-arid-corner.R` (32 s), `test-canopy-methods.R` (26 s). Editing K93 or FF16
plumbing does not require paying the TF24 ones.

**Six files fail on `ad/v3-forward` for reasons that predate the gradient work**
and are not a signal about a sweep change. Counts measured at `plant@cdf3f0c9`,
so a differing count is yours:

| file | fails | what |
|---|---|---|
| `test-leaf.r` | 5 | lines 620, 704, 705, 706, 865 |
| `test-strategy-tf24.R` | 2 | line 83; and the yml agreement, below |
| `test-strategy-tf24f.R` | 1 | line 86 |
| `test-stochastic-patch.R` | 3 | a range over an empty competition interval |
| `test-stochastic-patch-runner.R` | 1 | misses its seeded baseline |

**`test-strategy-tf24.R`'s second failure is newly visible, not new.** Its parameter probe is
compiled by `sourceCpp` and was missing two things every such probe needs — the include paths of
the packages `plant` LinkingTo's, and `// [[Rcpp::plugins(cpp20)]]`, which cannot go in
`PKG_CPPFLAGS` because R places those before its own `-std=` and wins. So it failed to build and
both checks it gates skipped. With it building, one passes and one reports that `vcmax_25` and
`jmax_25` are registered as AD parameters while the test's `omitted` list says they are not. That
disagreement is being fixed on a parallel branch and lands with the opaque node item; leave it
failing until then. **A probe that does not compile is a check that does not run — and it reports
as a skip, which reads like a choice.**

**`test-mutant.R` was on this list for two failures and should not have been.** They did not
predate the gradient work: the environment cache that feeds an invasion run was reached through
solver hooks that a refactor stopped calling, so it filled nothing and every case errored. Listing
them here as expected is what kept that quiet once the suite began reporting it. The unreachable
half is deleted and the file now skips, carrying its expected fitnesses as the specification for
the replay pass that replaces it — see report 09 §10. **A failure written down as expected stops
being read; prefer a skip that names what it waits for.**

The first three were absent from this list and cost a session's worth of doubt to
attribute. `test-stochastic-patch-runner.R`'s pass count varies run to run; its
one failure does not.

**`testthat`'s parallel workers cannot see a `pkgload::load_all()`ed package**, so
every invocation below needs `TESTTHAT_PARALLEL=false` — which makes a single
`test_dir()` serial, and its wall time its CPU time.

**Get the concurrency back by running one R process per file rather than one
`test_dir()`, and use `scripts/run-tests.sh` to do it.** `load_all()` costs about
two seconds per process and the files are independent, so fanning them out is
nearly free and wall time becomes the slowest single file.

```sh
scripts/run-tests.sh '^test-gradient-ladder'        # the whole ladder
scripts/run-tests.sh 'gradient-ladder-(injection|rung3|factorisation|declared-zero)'
scripts/run-tests.sh '^test-gradient' "" invert     # the 55 non-ladder files
```

The first argument is an extended regex over the file names, so it selects a tier
the same way `testthat`'s own `filter` does; `invert` runs everything that does
*not* match. It prints a line per file and a total, exits non-zero if anything
failed, and **names any file that produced no result line** — a crashed process
is otherwise silent, which is the one way this loses information that
`test_dir()` does not. Logs go to a temporary directory it prints, or to a second
argument if you pass one.

**Set `PLANT_TEST_LIB` to a private library holding your `odelia` build**, which
is how you stay out of the race described above; it is prepended, so the user
library is still visible.

**Measured on sixteen cores: the whole gradient ladder is 17 s of wall this way,
against about twenty minutes serial**, and the 55 non-ladder files are 86 s
against about six minutes.

## Testing odelia — and the two ways it lies to you

`odelia` must be installed rather than `load_all()`ed (see *Local Development*), so
run its suite against the install, in an environment that can see the package's
internals:

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

**The suite compiles its probes with `sourceCpp`, and a probe that does not agree
with the shipped library fails in ways that read as unrelated.** Two settings have
to match `src/Makevars`: the XAD defines (`XAD_NO_THREADLOCAL`,
`XAD_USE_STRONG_INLINE`) and the C++20 standard. A probe missing the first links
against a symbol of the same mangled name in the other storage class — *"TLS
reference ... mismatches non-TLS definition"*. A probe missing the second reads
every `concept` in odelia's headers as a syntax error — *"'concept' does not name a
type"*. **The two are set in different places and only one of them can be
shared.** `odelia_cppflags()` in `tests/testthat/helper-load-odelia.R` carries the
include path and the defines, and a new probe takes those from there and nowhere
else. The standard cannot go there — `PKG_CPPFLAGS` is placed before R's own
`-std=`, which then wins — so it stays a `// [[Rcpp::plugins(cpp20)]]` line inside
each snippet. A probe including any odelia header that names a concept needs it.

At `odelia@d1af586` the suite is **397 passing, 0 failing, 3 skipped**.

**One known intermittent crash, and it is not yours.** `test-example-leaf-ad.R`
takes a `memory not mapped` fault inside `LeafSolver_value_and_gradient` about
once in five full-suite runs, and never when that file is run on its own. If a run
aborts there, re-run before investigating; if you are changing the leaf example or
the AD driver, run the whole suite several times, because once is not evidence.

## Profiling — read the method before taking a number

**[`docs/leaf-rows-cost.md`](docs/leaf-rows-cost.md) is the method**, and its §1 is
the part to read first: three measurements are needed and any two of them mislead,
because **share = count × price** and unit costs here differ by more than an order
of magnitude. Rank by share, never by a count and never by a profiler's own
attribution — at `-O2` an inlined callee has no frame of its own and its samples
land on its caller. §2 states which lever is worth pulling, §3 is the measured
distribution, §4 the remaining levers ranked by it, and §5 what not to do.

**The current distribution, so it can be scoped without re-measuring:** the gradient
is **9.7 forward runs** at century scale and flat across run length. The largest
single cost is the leaf's supplied derivative rows at **35.9%** of a profile — AD-only,
so nothing in the sweep touches it — and **16.3%** of that is one root-find re-run per
perturbation, which §4.1 says is a legitimate per-family hoist. XAD's machinery is
**~17%**, down from ~30% before one recording came to span a step.

**`scripts/profile-gradient.sh` is the harness**, and it automates the four guards
§1 lists:

```sh
PLANT_TEST_LIB=<your lib> scripts/profile-gradient.sh scripts/profile-stand-gradient.R
```

It samples with gperftools' `libprofiler` (`perf` is unusable wherever
`kernel.perf_event_paranoid` > 2, which is the default here), resolves with
`google-pprof`, and prints a flat profile and a by-function one. Three things it
knows that cost a session each to find:

- **`libprofiler` is `LD_PRELOAD`ed onto the R *binary***, not the `R` wrapper and
  not `Rscript`: via those the first `SIGPROF` arrives during the exec chain and
  kills the process.
- **Profile an INSTALLED plant, never a `load_all`ed one.** `pkgload` maps its own
  copy of `plant.so` and unlinks it while it is still mapped, so the profile's maps
  entry reads `plant.so (deleted)` — and **no archived copy can be substituted for
  it**, because the map entry is what is wrong rather than the file. Every sample
  inside plant then resolves to a bare hex address. Install with
  `R CMD INSTALL -l $PLANT_TEST_LIB plant`.
- **Refine the schedule in a separate process.** Refinement bisects on
  trait-dependent errors and re-runs the whole model many times — measured at
  **206 s against a ~30 s run at century scale** — so a profile including it spends
  half its samples in the forward model, and a gradient-to-run ratio computed
  against it flatters the sweep by using many runs as the denominator.
  `scripts/profile-stand-gradient.R` caches the refined parameters beside its output
  and says so when it had to refine.

`google-pprof` comes from the `google-perftools` package, which the `-dev` libs do
not pull in; install it explicitly.

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
  tape_guard<Tape> guard{solver->tape.get()};  // deactivates on every exit,
                                               // exceptions included
  const std::size_t codomain = functional.codomain();
  auto jacobian =
      xad::computeJacobian(inputs, forward, codomain, solver->tape.get());
  return to_r_list(jacobian);  // only doubles cross the boundary
}
```

## PR workflow

Work is tracked as **issues** — a numbered work item in a submodule's tracker, or an
entry in the session task list. PRs are opened
against the submodule's `origin` fork (`aornugent/*`); propagation to the `traitecoevo`
upstream is a separate, user-driven step (see *Workflow for Agents* above).

- **One PR per issue.** Each PR is a small, self-contained change that closes exactly one
  issue. Name the branch and PR after the issue (e.g. `ODELIA-1`, `PLANT-4`) so the
  mapping is unambiguous.
- **Stacked diffs where issues depend on each other.** When working through several
  interdependent issues at once, which is the common case — branch each PR on top of the one it builds on rather than off the base
  branch, and target that parent branch. Reviewers then see only the incremental diff and
  the PRs merge in order down to the submodule's default branch (`master`/`main`).
  Independent issues branch straight off the default branch and can merge in any order.
- **Fix in the branch that owns the issue; don't stack a fix on top.** When review or a
  later finding changes something already in the stack, land the change on the branch for
  the issue it belongs to (amend or add a commit there), not as a new branch on top. A
  fix stacked above the code it corrects breaks the one-PR-per-issue mapping and muddies
  the incremental upstream PRs. Only branch anew when the change is genuinely new scope.
- **Rebase the stack with `--update-refs`.** Amending an underlying branch moves the
  merge-base of everything above it, so those branches must be rebased onto the new tip.
  `git rebase --update-refs` (Git ≥ 2.38; or `git config rebase.updateRefs true`) advances
  all the intermediate stacked branch refs in one pass; then force-push each descendant
  with `--force-with-lease`. The cost is remembering to push *every* descendant and
  resolving a conflict that can cascade upward — not deep surgery, but do it deliberately.
- **Tests land with the component they cover** — not as a separate follow-up PR. Each
  change ships its own coverage in the same PR that adds it.
- **Bump the meta-repo pointer as each lands.** Submodule work lives on a feature branch
  and its per-issue children; after a submodule PR merges, update the `plant-dev`
  submodule pointer (see *Updating the Meta-Repo* above) so the superproject tracks the
  new commit.
