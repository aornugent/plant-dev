# Developer Guide for Agents (plant-dev Workspace)

This repository (`aornugent/plant-dev`) is a meta-repository (superproject) used to manage local development across the `traitecoevo` family of R packages: `logpile`, `plant`, and `odelia`.

## Session Start (do this first, every session)
Before doing anything else, add the sibling package repos to the session's GitHub
scope so their issues and PRs are readable — `git submodule update --init` clones the
code, but issue/PR access is a separate grant:

1. Initialize submodules: `git submodule update --init --recursive`
2. Add each fork to the session scope (via `add_repo`): `aornugent/odelia` and
   `aornugent/plant`. Work items like `odelia#19` live in these trackers, not in
   `plant-dev`, so without this step the issues are inaccessible.

## Workspace Structure
- `logpile/`: Submodule pointing to `https://github.com/aornugent/logpile.git`, default branch `main`
- `plant/`: Submodule pointing to `https://github.com/aornugent/plant.git`, tracks `develop` (pinned via `branch = develop` in `.gitmodules`)
- `odelia/`: Submodule pointing to `https://github.com/aornugent/odelia.git`, default branch `master`

Each submodule also has an `upstream` remote configured pointing to the official `traitecoevo` repository (`traitecoevo/plant`, `traitecoevo/odelia`, `traitecoevo/logpile`).

System deps and R packages (including `gh`, `logger`, and `RcppR6`) are installed by the environment setup script — you don't need to install them by hand.

## Repo Setup
Submodules are not populated by a plain `git clone` of `plant-dev`. After cloning, run:
```bash
git submodule update --init --recursive
```
Dependency order is `odelia` → `plant` → `logpile` (`plant` links `odelia`'s C++ headers; `logpile` imports `plant`). Build/install in that order.

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

## C++ style (match the odelia/plant core)

New C++ should be indistinguishable from the existing core (Rich FitzJohn's). It is
terse, template-heavy, and comments the *why*, not the *what*.

- **Template on the scalar; alias the default.** Systems carry a `value_type`; numeric
  components template on the value scalar `S` with node/abscissa positions left
  `double`. Pin the production type with a `using` alias
  (`using Interpolator = basic_interpolator<double>;`) so every existing caller is
  untouched and only the AD path instantiates `S = active`.
- **Comments assume an expert reader.** Explain the tricky floating-point choice, the
  replay/freeze rationale, the issue or source reference (`#472`, GSL, a SO link) —
  never restate what the code plainly says. Clear names and structure carry the rest.
- **Comment the invariant, not the design's biography.** A comment states what must be
  true here and why — in one or two lines. It is not a changelog, a defence against a
  rejected alternative, or a pointer into the design docs. Process references (`RIF-3`,
  `odelia#19`, "was renamed from…") and internal doc section numbers **drift** the moment
  the code moves; a stable external anchor (`#472`, a GSL routine, a paper) does not.
  Rationale that spans more than a couple of lines belongs in the PR description or
  `docs/`, not the source.

  ```cpp
  // BAD — narrates the design's history and rejects an alternative the reader can't see:
  // "Replayable" names the recording contract -- distinct from the RIF-3 "cache", which
  // is the amortized tape/scratch (a speed optimisation), not this recording (a semantic
  // one). Completing the concept with the query is deliberate: derivs reads it, so
  // requiring it here rejects a half-implemented System at the concept boundary rather
  // than failing deep inside derivs.
  template <class S> concept Replayable = requires(S s, int stage) { ... };

  // GOOD — states what the concept is and what the query is for:
  // A System that records its adaptive node positions on the double pass and replays
  // them fixed on the active pass. has_recorded_field() routes frozen-field replay.
  template <class S> concept Replayable = requires(S s, int stage) { ... };
  ```

  ```cpp
  // BAD — a paragraph of provenance and a section cross-ref that will drift:
  // `least_squares` is the one prebuilt calibration instance. Unlike an emergent
  // functional it carries per-run data ... so calibration is just another functional,
  // not a special mode wired into the solver (ad-record-replay.md sec 8).
  struct least_squares { ... };

  // GOOD:
  // A calibration functional: holds measured data, scores the replayed trajectory
  // against it. The solver stores no fit state.
  struct least_squares { ... };
  ```
- **No boilerplate.** Reach for `util::stop` / `util::check_length` / `util::identical`
  over raw throws; keep functions small and single-purpose; select behaviour at compile
  time so an absent hook is a zero-cost no-op. For *new* opt-in hooks prefer C++20
  concepts + `if constexpr` over more `enable_if` SFINAE (the project is `CXX_STD =
  CXX20`).
- **Use the vendored XAD components; do not re-implement them.** odelia vendors XAD
  (`inst/include/XAD/`) — `computeJacobian`, `CheckpointCallback`, `computeAdjoints`,
  the `adj`/`fwd` drivers. Call these directly rather than hand-rolling the tape
  sweep, the adjoint loop, or the IFT edge. "Mirror the XAD pattern" means *invoke*
  the XAD facility, not copy its body. New AD code is glue around XAD, not a second
  AD engine (the whole thesis of the roadmap: one AD runtime, not a parallel stack).
- **`const` by default**, 2-space indent, header guards `ODELIA_<NAME>_HPP_`.
- **Surgical, in place.** Modify the type that already exists; do not add a parallel
  abstraction beside it. A header change ripples to everything that `LinkingTo` it, so
  treat it as a compile-time `breaking` / `cross-package` event.

## PR workflow

Work is tracked as **issues** — a numbered work item in a submodule's tracker, or an
entry in a planning doc such as [`docs/ad-issues.md`](docs/ad-issues.md). PRs are opened
against the submodule's `origin` fork (`aornugent/*`); propagation to the `traitecoevo`
upstream is a separate, user-driven step (see *Workflow for Agents* above).

- **One PR per issue.** Each PR is a small, self-contained change that closes exactly one
  issue. Name the branch and PR after the issue (e.g. `ODELIA-1`, `PLANT-4`) so the
  mapping is unambiguous.
- **Stacked diffs where issues depend on each other.** When working through several
  interdependent issues at once — the dependency chains in `docs/ad-issues.md` are the
  common case — branch each PR on top of the one it builds on rather than off the base
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
