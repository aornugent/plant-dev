# Developer Guide for Agents (plant-dev Workspace)

This repository (`aornugent/plant-dev`) is a meta-repository (superproject) used to manage local development across the `traitecoevo` family of R packages: `logpile`, `plant`, and `odelia`.

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

## Landing a stack of PRs

Feature work is often split into a **stack** of dependent PRs (`A ← B ← C`, each
targeting the branch below it) so each stays small and independently reviewable,
and they land as incremental PRs to `traitecoevo`. Landing a stack has one sharp
edge worth stating plainly:

- **Never squash-merge (or rebase-merge) a PR that has other PRs stacked on it,
  and never squash-merge as a way to "land the stack".** A squash-merge creates a
  brand-new commit on the base and marks the PR **merged**. That has two
  irreversible consequences: (1) the merged branch's real commits are no longer
  ancestors of the base, so every PR stacked above it goes to a conflicted /
  "dirty" state and must be rebased with the old commits dropped; and (2) **a
  merged PR cannot be reopened** — if you revert the base branch afterwards, the
  PR stays closed-as-merged and the work needs a *new* PR. (Learned the hard way:
  a squash-merge of the base PR, then a revert, orphaned the base PR permanently.)

- **Action reviews in place, keep the stack intact.** Apply review changes on the
  branch that owns the code (amend the branch's commit, or add a fixup), then
  cascade with `git rebase --onto <new-base> <old-base> <branch>` (or
  `git rebase --update-refs` across the whole stack) so each descendant re-parents
  onto its updated base. Force-push each branch (`git push -u --force-with-lease
  origin <branch>`); the open PRs recompute their diffs against the moved bases and
  stay clean. Build/test at each level — a header change in odelia's core ripples
  to every dependent branch at **compile** time.

- **When it's genuinely time to merge the whole stack to `master`/`develop`**, land
  bottom-up, one PR at a time, using **merge commits** (or fast-forward) so each
  merged branch stays an ancestor of the next PR's base. Retarget the next PR's
  base only after its predecessor is merged. Squash, if wanted, is only safe on the
  **top** PR of a stack (nothing depends on it).

## Upstream Synchronization
To sync a submodule with the official repository, fetch and merge from the `upstream` remote, then push to the `origin` fork:
```bash
cd <submodule>
git fetch upstream
git merge upstream/master # (or main)
git push origin master
```
