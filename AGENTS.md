# Developer Guide for Agents (plant-dev Workspace)

This repository (`aornugent/plant-dev`) is a meta-repository (superproject) used to manage local development across the `traitecoevo` family of R packages: `logpile`, `plant`, and `odelia`.

## Workspace Structure
- `logpile/`: Submodule pointing to `https://github.com/aornugent/logpile.git`, default branch `main`
- `plant/`: Submodule pointing to `https://github.com/aornugent/plant.git`, tracks `develop` (pinned via `branch = develop` in `.gitmodules`)
- `odelia/`: Submodule pointing to `https://github.com/aornugent/odelia.git`, default branch `master`

Each submodule also has an `upstream` remote configured pointing to the official `traitecoevo` repository (`traitecoevo/plant`, `traitecoevo/odelia`, `traitecoevo/logpile`).

## Repo Setup
Submodules are not populated by a plain `git clone` of `plant-dev`. After cloning, run:
```bash
git submodule update --init --recursive
```
`plant` depends on `odelia` (C++ headers via `LinkingTo`), and `logpile` depends on `plant` (R `Imports`). Build/install in that order: `odelia` → `plant` → `logpile`.

`plant`'s `develop` branch (as of the sync in mid-2026) replaced the archived-from-CRAN `loggr` package with `logger`, and requires `RcppR6` (also archived from CRAN) to regenerate C++/R glue code when strategy classes change. Since neither is on CRAN for current R, install from source:
```r
# loggr replacement is now `logger`, on CRAN — installs normally.
# RcppR6 (only needed if you edit inst/RcppR6_classes.yml or add/change strategies):
remotes::install_github("richfitz/RcppR6")
```

## Local Development (preferred over `install.packages`)
For iterating on one or more packages simultaneously, use `pkgload`/`devtools` instead of a full source install for `plant` and `logpile` — it avoids the full `R CMD INSTALL` + fresh-session reload cycle and lets `logpile` see live edits to `plant`'s R code without reinstalling:
```r
library(odelia)              # must be a real install — see caveat below
pkgload::load_all("plant")
pkgload::load_all("logpile")
```
or equivalently `devtools::load_all(".")` from within each package directory. `load_all()` still compiles a package's own C++ sources on first load / after editing them (via `pkgbuild`), so a `plant` C++ change is still a real (if incremental) compile — `load_all` mainly saves the reinstall/reload round-trip, not the compile itself.

**Caveat — `odelia` must be `library()`-loaded, not `load_all()`-ed.** `plant`'s C++ links against `odelia`'s compiled XAD `Tape` symbols at *load* time rather than *link* time on Linux/macOS: odelia's `.onLoad` re-`dyn.load()`s its own shared object with `local = FALSE` to expose those symbols process-wide (see `odelia/R/dll-load.R`, `odelia/ARCHITECTURE.md`, tracked upstream as `traitecoevo/odelia#29`). That mechanism resolves `odelia`'s compiled `.so` via `system.file("libs", package = "odelia")`, which only finds a real installed package — under `pkgload::load_all("odelia")` it resolves to the wrong (or a mismatched) binary and `plant`'s `load_all()` then fails with `undefined symbol: ...xad4Tape...`. Practical result: reinstall `odelia` (`install.packages("odelia", repos=NULL, type="source")`) whenever you change its C++, but `load_all()` freely for `plant`/`logpile` R-code iteration on top of it.

Only fall back to `install.packages(<dir>, repos=NULL, type="source")` (or `R CMD INSTALL`) for `plant`/`logpile` when you need the package actually installed into the library — e.g. testing as a dependent package would see it, or after `RcppR6` regenerates C++ glue code and you want a clean recompile. If a stale rebuild produces `undefined symbol` errors on load, clear the gitignored build artifacts first: `rm -f src/*.o src/*.so` inside the package directory, then reinstall.

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
