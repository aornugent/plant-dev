# Developer Guide for Agents (plant-dev Workspace)

This repository (`aornugent/plant-dev`) is a meta-repository (superproject) used to manage local development across the `traitecoevo` family of R packages: `logpile`, `plant`, `phylloptim`, and `odelia`.

## Session Start (do this first, every session)
Before doing anything else, add the sibling package repos to the session's GitHub
scope so their issues and PRs are readable — `git submodule update --init` clones the
code, but issue/PR access is a separate grant:

1. Initialize submodules: `git submodule update --init --recursive`
2. Add each fork to the session scope (via `add_repo`): `aornugent/odelia`,
   `aornugent/plant`, and `aornugent/phylloptim`. Work items like `odelia#19` live in
   these trackers, not in `plant-dev`, so without this step the issues are inaccessible.

## Workspace Structure
- `logpile/`: Submodule pointing to `https://github.com/aornugent/logpile.git`, default branch `main`
- `plant/`: Submodule pointing to `https://github.com/aornugent/plant.git`, tracks `develop` (pinned via `branch = develop` in `.gitmodules`)
- `phylloptim/`: Submodule pointing to `https://github.com/aornugent/phylloptim.git`, default branch `master`
- `odelia/`: Submodule pointing to `https://github.com/aornugent/odelia.git`, default branch `master`

Each submodule also has an `upstream` remote configured pointing to the official `traitecoevo` repository (`traitecoevo/plant`, `traitecoevo/phylloptim`, `traitecoevo/odelia`, `traitecoevo/logpile`).

System deps and R packages (including `gh`, `logger`, and `RcppR6`) are installed by the environment setup script — you don't need to install them by hand.

## Repo Setup
Submodules are not populated by a plain `git clone` of `plant-dev`. After cloning, run:
```bash
git submodule update --init --recursive
```
Dependency order is `odelia` → `phylloptim` → `plant` → `logpile` (`phylloptim` links `odelia`'s C++ headers; `plant` links `odelia`'s and `phylloptim`'s headers; `logpile` imports `plant`). Build/install in that order. `plant` links `phylloptim` at compile time and only `Suggests` it, so — unlike `odelia` — it need not be loaded at `plant` runtime.

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

## Testing plant — a short feedback loop

`plant` carries ~2000 testthat assertions across 42 files, but running all of
them per edit is wasteful. The cost is dominated by the **C++ rebuild** and by
**three slow files**; scope every run to what you changed. (Build / `load_all` /
odelia-reinstall mechanics are under *Local Development* above; paths below are
from the `plant-dev` root.)

**The per-iteration tax is the rebuild, not the tests.** An R-only change under
`pkgload::load_all("plant")` skips compilation; a C++ change recompiles
incrementally — but the strategy/environment core is header-inline, so editing a
header in `plant/inst/include/` invalidates every translation unit that includes
it and triggers a near-full `plant/src` recompile. Build optimised once
(`cd plant && make`, `-O2`), then `load_all()` reuses that `.so`; a bare
`load_all()` without `make` builds unoptimised and makes every slow test several
times slower (the difference between a ~3 min suite and the >8 min it takes
unoptimised).

**Run tests serially in the dev loop.** `plant/DESCRIPTION` sets
`Config/testthat/parallel: true`, but the parallel workers `loadNamespace("plant")`
in fresh subprocesses, which fails under `load_all()` (`attempt to use
zero-length variable name`). So set `Sys.setenv(TESTTHAT_PARALLEL = "false")` (as
the AD handover already does). File-parallelism only works from an *installed*
package (`cd plant && make test`, or CI) — it is not a lever for interactive
work. That leaves **test selection** as the real lever, and the runtime is
heavily skewed (serial, `-O2`):

| Files | Serial cost | What |
|---|---|---|
| 3 heavy | **~143 s (76%)** | `test-mutant.R` (82 s, several full `run_scm`), `test-strategy-tf24.R` (43 s, TF24 hydraulics), `test-strategy-tf24f.R` (19 s) |
| ~6 medium | ~28 s | `test-patch.R` 10 s, `test-initial-state.R` 6 s, `test-individual.R` 4 s, `test-strategy-ff16.R` 4 s, `test-canopy-methods.R` 4 s, `test-stochastic-patch-runner.R` 2 s |
| ~33 rest | ~17 s | each **< 1 s** |

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
3. **Fast pre-commit sweep — everything except the 3 heavies (~45 s, 39/42 files):**
   ```r
   d <- "plant/tests/testthat"
   f <- setdiff(list.files(d, "^test-.*\\.[Rr]$"),
                c("test-mutant.R", "test-strategy-tf24.R", "test-strategy-tf24f.R"))
   for (x in f) testthat::test_file(file.path(d, x))
   ```
4. **Full serial sweep before you push — ~3 min on an `-O2` build.** The heavy
   files exist for a reason; never let a branch land without them. Or run the
   installed parallel path — `cd plant && make test` — which is what CI does.

**Always cheap, run it when numerics move:** the FF16 bit-identity guard
(`test-strategy-ff16.R` ~4 s, plus `test-strategy-ff16-reference-comparison.R`)
is the tripwire for the scalar-templating AD work — a changed reference number
means bit-identity broke. Include it in tiers 1–2 whenever you touch a strategy,
environment, the ODE path, or anything the active scalar `S` threads through.

**Only pay for the heavy files when you touched what they cover:** `test-mutant.R`
for resident/mutant density machinery, and the two TF24 files for TF24/leaf
hydraulics. Editing K93 or FF16 plumbing does not require paying their ~143 s.

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
- No runtime capability flags or SFINAE detection structs — a concept +
  `if constexpr`.
- No storing what can be derived; no passing a count that can disagree with
  its source of truth.
- No dropping a guarantee (bounds check, cleanup path) during a refactor; no
  demo code compiled into the shipped .so; no dead files after a rename.

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

Work is tracked as **issues** — a numbered work item in a submodule's tracker. PRs are opened
against the submodule's `origin` fork (`aornugent/*`); propagation to the `traitecoevo`
upstream is a separate, user-driven step (see *Workflow for Agents* above).

- **One PR per issue.** Each PR is a small, self-contained change that closes exactly one
  issue. Name the branch and PR after the issue (e.g. `ODELIA-1`, `PLANT-4`) so the
  mapping is unambiguous.
- **Stacked diffs where issues depend on each other.** When working through several
  interdependent issues at once — a common case — branch each PR on top of the one it
  builds on rather than off the base
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
