# plant-dev: guide for agents

plant-dev is a superproject that holds the `traitecoevo` family of R packages as git submodules, so they can be developed and tested together.

Each package has its own guide, which loads from the package's `.claude/CLAUDE.md` when you work on its files. That guide is the authority on the package's facts: layout, build, tests and hazards. This file covers what no single package can: how the packages fit together here, the local build loop, and how work moves between forks, upstream and plant-dev. Its *Engineering principles* and *Code style* apply to every package; where a package guide's style or comment rules differ, follow this file.

## The packages

| Package | Default branch | Depends on |
|---|---|---|
| `odelia` | `master` | — |
| `phylloptim` | `master` | `odelia` (C++ headers) |
| `plant` | `develop` | `odelia`, `phylloptim` (C++ headers; `phylloptim` only at compile time) |
| `regnans` | `master` | `plant`, `odelia` (R) |
| `logpile` | `main` | `plant` (R) |

Build and install in the table's order. Each submodule's `origin` is the `aornugent` fork, and its `upstream` is the `traitecoevo` repository of the same name. `.gitmodules` holds the URLs.

Everything else at the root:
- `docs/principles.md`: the engineering principles below, in full.
- `OBJECTIVES.md`: the requirements TF24's schedule and step controller are judged against.
- `docs/schedule/`: the TF24 node-schedule refine loop (`refine.md`), its time axis, validation bank and vignette; the code is `harness/schedule/`.
- `docs/review/`: the derivatives of the eco-evolutionary loop, selection read at observed sites, the theory behind them and the annotated literature.
- `harness/`: the reusable R drivers (see `harness/README.md`). Raw measurements, PR drafts and one-off drivers are on the tag `archive/trusting-curie`, which open PRs' figures link to, so keep the tag.

## Session start

1. Run `git submodule update --init --recursive`; a plain clone leaves the submodules empty.
2. In a cloud session that provides `add_repo`, add each package's `aornugent` fork to the session's GitHub scope. Work items like `odelia#19` live in those trackers, and cloning the code does not grant access to their issues.

## Building and loading

Iterate with `pkgload::load_all()` rather than a full install. It picks up R edits without a reinstall, and still compiles a package's own C++ incrementally after C++ edits.

```r
library(odelia)              # a real install: see below
pkgload::load_all("plant")
pkgload::load_all("logpile")
```

Load `odelia` with `library()`, never `load_all()`. `plant` resolves odelia's compiled XAD `Tape` symbols through odelia's `.onLoad`, which needs a real installed package; under `load_all("odelia")` loading fails with `undefined symbol: ...xad4Tape...`. After editing odelia's C++, reinstall it with `install.packages("odelia", repos = NULL, type = "source")`.

If a rebuild fails to load with `undefined symbol`, the package's object files are stale: run `rm -f src/*.o src/*.so` in the package and reinstall.

## Testing plant

Most of the cost of a test run is the C++ rebuild and three slow files, so scope each run to what you changed. Paths are from the plant-dev root.

- **Build optimised once.** Run `cd plant && make` (`-O2`); `load_all()` then reuses that build. A bare `load_all()` builds unoptimised, which makes the slow files several times slower. Editing a header in `plant/inst/include/` recompiles nearly all of `plant/src`, because the strategy and environment core is header-only.
- **Run tests serially under `load_all()`.** plant's `DESCRIPTION` turns on parallel tests, but the parallel workers load plant in fresh processes, which fails under `load_all()` with `attempt to use zero-length variable name`. Set `Sys.setenv(TESTTHAT_PARALLEL = "false")`. Parallel runs work only from an installed package (`cd plant && make test`, which is what CI does).
- **Pick the tier for the change:**
  1. *Per edit:* the one test file for the component you touched; tests map to components by file name, and almost every file takes under 2 s. `testthat::test_file("plant/tests/testthat/test-scm.R")`.
  2. *A cross-cutting change:* a family, e.g. `testthat::test_dir("plant/tests/testthat", filter = "strategy", stop_on_failure = FALSE)`. `filter` is a case-sensitive regex on the file name without `test-` and `.R`.
  3. *Before committing:* everything except the three slow files, about 45 s:
     ```r
     d <- "plant/tests/testthat"
     f <- setdiff(list.files(d, "^test-.*\\.[Rr]$"),
                  c("test-mutant.R", "test-strategy-tf24.R", "test-strategy-tf24f.R"))
     for (x in f) testthat::test_file(file.path(d, x))
     ```
  4. *Before pushing:* the full suite, about 3 min serially on an `-O2` build, or `cd plant && make test`.
- **The three slow files** are `test-mutant.R` (about 80 s; the resident and mutant density machinery), `test-strategy-tf24.R` (about 45 s) and `test-strategy-tf24f.R` (about 20 s; both TF24 hydraulics). Run them before committing only when you touched what they cover.
- **Whenever numerics could move,** run the FF16 bit-identity guard (`test-strategy-ff16.R` and `test-strategy-ff16-reference-comparison.R`, a few seconds). A changed reference number means bit-identity broke. This applies to any change to a strategy, an environment, the ODE path, or anything the active scalar `S` passes through.

## Git workflow

Work is tracked as issues in each package's `aornugent` tracker. Each issue gets one branch and one PR, so the mapping stays unambiguous.

- **Push only to `origin`, the `aornugent` fork.** Agents have no push access to `traitecoevo`. Opening a PR on `traitecoevo` from a fork branch is the user's call: do it only when asked.
- **Bring the fork level with upstream before branching.** A branch cut from a fork that is behind carries upstream's missing commits into its PR, and edits text upstream has already changed:
  ```bash
  cd <package>
  git fetch upstream
  git merge --ff-only upstream/<default-branch>   # from the table above
  git push origin <default-branch>
  ```
- **Name the branch after the issue** (e.g. `ODELIA-1`), and **title the PR by what it changes.** The packages squash-merge, so the title becomes a permanent commit subject; the issue link belongs in the body.
- **Tests land in the same PR** as the change they cover.
- **Stack dependent issues.** Branch each PR from the one it builds on and target that branch, so reviewers see only the increment and the PRs merge in order. Independent issues branch from the default branch.
- **Fix in the branch that owns the issue.** When review changes something already in a stack, amend that issue's branch rather than adding a fix on top, which would break the one-PR-per-issue mapping. Then rebase the branches above it with `git rebase --update-refs` (Git ≥ 2.38), and force-push each one with `--force-with-lease`. Every descendant must be pushed, and a conflict can cascade upward, so do it deliberately.
- **Bump plant-dev's pointer after a submodule PR merges.** `git status` at the root then shows the submodule as modified; commit that change and push it to `aornugent/plant-dev`. Don't commit a pointer to an unmerged feature branch.

## Engineering principles

These apply to every change in every package. The full text, with the reasoning behind each, is in `docs/principles.md`; read it before designing or reviewing a change.

The project's skills put them to work: design a change with `system-design`, review one with `code-review`, and find the cause of a failure with `systematic-debugging`. Use these, not similarly named skills from elsewhere.

- **Be lazy on the maintainer's behalf.** Writing code is cheap for you, which makes over-engineering easy. Aim for the most result with the least code; if a human would find the code exhausting to maintain, it is a bad solution.
- **Subtract before you add.** Look for removals before additions, and remove before you build, because a simpler base makes the next addition smaller. Design for observed use, not speculative cases, and add no validator, guard or option the requirement doesn't demand.
- **Minimise reader load.** Count the layers between a question and its answer, and the hidden state a reader must hold. Collapse wrappers with one caller and layers that pass arguments through unchanged; prefer returns to mutation and derived values to synchronised copies. The test: can a new reader answer "where does X come from?" and "what can change X?" in under 30 seconds?
- **Data structures first, and model the domain.** Choose the types before the logic. Encode the domain in a structure (a state machine, a typed record, a lookup table) rather than in conditionals spread across files. The tell that you skipped this is a feature that adds one more branch to an existing chain, or a second boolean that must stay in sync with the first.
- **Consolidate decisions.** Make each choice once, behind one source of truth, and pass the result. Don't thread a new signal through layers when a more direct path exists.
- **Write for a reader who wasn't there.** Comments, commit messages, PRs, issues and reviews are read by people who never saw your session. Write them in complete sentences that stand alone (`.claude/output-styles/longhand.md`).

## Code style

Match the code around you. When editing a file, continue it; when creating one, first read the two most similar existing files and write as their continuation. One invariant holds across the packages: only `double` crosses the R boundary, and active (AD) types are created and destroyed inside one C++ call.

### Never (comments)

- No process history: issue tags (`RIF-`, `ODELIA-`), "renamed from",
  "successor to", doc-section references (`§`), or mentions of other repos.
- No metaphor or borrowed mechanism words: write what happens ("record", not
  "flush"). See *Naming* below; the same rule applies to identifiers.
- No decorative nouns ("contract", "surface", "oracle"), no section banners.
  Never define a thing by what it isn't.
- Never longer than two lines unless spelling out a genuine silent-failure
  hazard. If a comment exists to decode a name, rename instead.

### Never (code)

- No parallel near-copy of an existing type or path; modify what exists.
- No re-implementing what vendored XAD provides.
- No runtime capability flags or SFINAE detection structs — a concept +
  `if constexpr`.
- No storing what can be derived; no passing a count that can disagree with
  its source of truth.
- No dropping a guarantee (bounds check, cleanup path) during a refactor; no
  demo code compiled into the shipped .so; no dead files after a rename.

### Naming

A name is the first documentation a reader gets, and usually the only part they
read. Name a thing for what it concretely is or does, in the words of the domain or
of the code it lives in, so a reader can predict its behaviour from the name alone.
These rules come from a review of odelia's reverse-mode API (traitecoevo/odelia#66),
where every name below misled the people who used it:

| Rule | Misleading | Concrete |
|---|---|---|
| A function named for an action performs it, and returns what the name suggests. | `solve_adjoint()` solves nothing and returns a segment count; R's `$fit()` fits nothing | `sweep_adjoint()`; `$loss_and_gradient()` |
| The name reads in the right direction and role. | `rebind_from<U>()` is this System on scalar `U` | `rebind<U>()` |
| Don't reuse a library's or the domain's word for something else. | `active_scalar`, where XAD's "active" means either AD mode; `resident`/`mutant` for anything but established and invading strategies | `adjoint_scalar`, pairing with `tangent_scalar` |
| One word per concept. | eight names for the backward pass; "recording", "record", "rec", "history", "trajectory" and "prev_steps" for the kept rows | one name each, used everywhere |
| One concept per word. | `range` for a sweep segment and also, in `AdjointRangeError`, an overflow | segments; `AdjointOverflowError` |
| Overloads that behave differently get different names. | `advance_recorded`, whose two overloads differ in whether solved values are loaded | `advance_schedule(schedule)`, `replay(recording)` |
| Don't coin a vocabulary beside an existing one. | `instruction` / `program_from` beside "schedule" and "recording" | `schedule_row` / `schedule_from` |
| Say the unit, the scale or the kind when the type doesn't. | `ic`; `set_target(times = ...)` taking a replay schedule, not observation times | `initial_state`; a name for the schedule argument |

Before coining a name, search the packages for the concept: if it already has a
name, use it, and if it has several, that is a rename to propose, not a reason to
add another. A comment that exists to decode a name means the name is wrong.

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

## Writing in this guide

This file is read in full at the start of every session, as current instructions, by a reader who cannot tell which parts are out of date. When you change it, the principles above apply, and three more:
- If something here turns out to be wrong, replace it; the story of how you found out belongs in the PR.
- Point to where a value lives (`.gitmodules`, a `DESCRIPTION`, a Makefile target) instead of copying the value, and leave out anything a fresh clone cannot resolve.
- Put a package's facts in that package's guide, where its own contributors see them.
