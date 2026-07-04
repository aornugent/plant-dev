# Developer Guide for Agents (plant-dev Workspace)

This repository (`aornugent/plant-dev`) is a meta-repository (superproject) used to manage local development across the `traitecoevo` family of R packages: `logpile`, `plant`, and `odelia`.

## Workspace Structure
- `logpile/`: Submodule pointing to `https://github.com/aornugent/logpile.git`
- `plant/`: Submodule pointing to `https://github.com/aornugent/plant.git`
- `odelia/`: Submodule pointing to `https://github.com/aornugent/odelia.git`

Each submodule also has an `upstream` remote configured pointing to the official `traitecoevo` repository.

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
- **No boilerplate.** Reach for `util::stop` / `util::check_length` / `util::identical`
  over raw throws; keep functions small and single-purpose; select behaviour at compile
  time so an absent hook is a zero-cost no-op. For *new* opt-in hooks prefer C++20
  concepts + `if constexpr` over more `enable_if` SFINAE (the project is `CXX_STD =
  CXX20`).
- **`const` by default**, 2-space indent, header guards `ODELIA_<NAME>_HPP_`.
- **Surgical, in place.** Modify the type that already exists; do not add a parallel
  abstraction beside it. A header change ripples to everything that `LinkingTo` it, so
  treat it as a compile-time `breaking` / `cross-package` event.

## PR workflow (the odelia AD surface)

- **One PR per issue** (ODELIA-1, ODELIA-2, …) — each a small, self-contained change.
- **Stacked diffs** where the issues depend on each other: branch each on top of the
  one it builds on (ODELIA-2 off ODELIA-1, …) and target that branch, so reviewers see
  only the incremental diff and the PRs merge in order down to `master`.
- **Tests land with the component they cover.** The ODELIA-4/4b test items are not a
  separate PR; each driver/edge ships its own coverage in the same PR that adds it.
- Submodule work lives on `claude/odelia-surface` and per-issue children; bump the
  `plant-dev` submodule pointer as each lands.
