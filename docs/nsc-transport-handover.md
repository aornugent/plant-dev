# Handover: the cohort density transport term under a carried state

How to pick this work up without redoing it. Written at the end of the session that produced
[report 13](reports/13-carried-state-invalidates-the-compression-term.md).

## 1. Where things are

| | |
|---|---|
| Analysis | [`docs/reports/13-…`](reports/13-carried-state-invalidates-the-compression-term.md) — self-contained, read this first |
| Same work, framed against the original issue | [`docs/reports/12-…`](reports/12-the-compression-term-is-a-change-of-variables.md) |
| Prior reports, superseded in their conclusions | [`docs/reports/10-…`](reports/10-density-transport-and-carried-physiology.md), [`11-…`](reports/11-cohort-counts-and-the-meaning-of-density.md) |
| Reference | [`docs/reference/stefaniak-et-al-2026-…pdf`](reference/stefaniak-et-al-2026-storage-strategies-egusphere-2026-1474.pdf) |
| Probes and raw outputs | [`probes/`](../probes), indexed in [`probes/README.md`](../probes/README.md) |
| Implementation | `plant` branch `claude/nsc-density-measurements-efiolz`, off `develop` at `141dc8df` |
| This superproject | branch `claude/plant-storage-scm-analysis-efiolz` |

Reports 10 and 11 are kept for provenance. **Two of report 11's central claims are refuted** — the
omitted term does not diverge at a growth stall, and the reserve-dilution effect is not a defect
separate from the omitted term — so do not build on them without reading report 13 §2 and
Appendix D.

## 2. Rebuilding the environment

```bash
git submodule update --init --recursive
apt-get install -y libuv1-dev poppler-utils        # fs/pkgload need libuv; poppler for the PDF
Rscript -e 'install.packages(c("testthat","pkgload"), repos="https://cloud.r-project.org")'
cd plant && git checkout claude/nsc-density-measurements-efiolz
export MAKEFLAGS=-j4 && R CMD INSTALL --no-multiarch --no-docs .
```

Five things that will otherwise cost time:

- **Clear `src/*.o` after any header change that alters a struct layout.** Adding a field to `Control`
  and rebuilding without clearing produced `*** stack smashing detected ***`, because translation
  units disagreed on `sizeof(Control)`.
- **Run tests through `pkgload::load_all(".", export_all = TRUE)`, not against the installed
  package.** The suite reaches internal symbols; `test_dir` on the installed package fails with
  dozens of "could not find function". Set `TESTTHAT_PARALLEL=false`.
- **Regenerate bindings after touching `inst/RcppR6_classes.yml`**: `Rscript -e 'RcppR6::RcppR6()'`.
- **`testthat` deduplicates same-named `test_that` blocks in a loop.** Name them
  `sprintf("... (%s)", x)` or only the first strategy's assertions are counted.
- **Do not pipe a long background job through `tail`** — it buffers and you see nothing until exit.
  Redirect to a file instead.

Baselines to confirm the build is right, all bit-identical with the flag off: TF24
`42.140173575095666`, FF16 `19.824404152971322`, K93 `0.030546647025066698`.

## 3. What is settled — do not re-derive or re-measure

- **The transport term is the total derivative of growth along a cohort's trajectory**, and the
  Jacobian it computes cancels in both integrals the model forms (report 13 Appendix A). Derived, not
  measured; no need to revisit.
- **The single-individual perturbation is fully resolved and still wrong.** Converged to five decimal
  places across five decades of step size, 55 times its own variation away from the required
  quantity (Appendix B). **An analytic or AD derivative therefore cannot help** — this closes off the
  most obvious line of attack.
- **The mechanism is the perturbation direction**, not physiological divergence between neighbours;
  neighbours in the damaging interval are identical to four decimal places in reserve fraction (§2).
- **The omitted term does not diverge at a growth stall.** `∂g/∂S` carries a factor of `g` that
  cancels. Predicted zero, measured `1.1 × 10⁻¹¹` (Appendix D).
- **Schedule resolution is not the cause of the 6–21% excess over the individual-based ensemble.**
  At least 94% survives refinement to 561 introductions (§6.2). Do not re-run this.
- **No cohort crossing occurs in a constant environment** (Appendix D); one cell of the seasonal
  sweep does cross (§6.3).
- **The correction is bit-identical with the flag off** and the suite passes: 2 363 assertions,
  48 files.
- **Wall-clock figures in reports 10 and 11 are not trustworthy** — taken on a contended machine. The
  measured speed-up is 1.91x at 141 introductions and 2.39x at 281, at a fixed schedule (§6.5). The
  per-step component is a stable 1.5x; the step-count component grows with resolution.

## 4. What is open, in the order worth attacking

**1. The 6–21% excess over the individual-based ensemble is unexplained.** The only named remaining
candidate is that the mean over stochastic replicates of a nonlinear functional is not the
deterministic value. The experiment: re-run `probes/12-oracle.R` at patch areas 256 and 1024 m² with
two or three replicates and see whether the ensemble mean rises toward the deterministic value as the
population grows. Cost scales roughly quadratically with area — 64 m² took about 10 minutes per
replicate — so budget several hours and run it detached. If the mean does rise, the excess is
explained and the corrected solver is vindicated outright; if it does not, something outside both
candidates is in play.

**2. Cost at matched accuracy.** §6.4 compares the two coordinates at equal `schedule_eps`, and they
reach different accuracies, so the comparison does not answer whether the corrected coordinate is
cheaper end to end. The experiment: bisect `schedule_eps` separately per arm until each lands within
a fixed tolerance of its own converged value, then compare node counts and runtime. This is the
measurement that decides whether the correction is a performance win or only a correctness one.

**3. The height-ordered early exit in `Species::compute_competition`.** `if (h0 < height) break;` and
the `height_max()` early return assume descending heights. §6.3 found 66 crossings under a
full-amplitude light cycle, so this is reachable, not theoretical. Out-of-order cohorts can terminate
the loop early and silently drop contributions. Fix before anyone runs a seasonal regime in anger.

**4. TF24's storage state leaves `[0, S_max]`.** Diagnosed as a single-step overshoot that the clamp
then pins (§6.1). Tightening the tolerance is not a remedy — depth improves 813-fold, frequency does
not move. The fix is to make the rate restoring below zero by gating on the **unclamped** state so a
negative value produces a positive rate. That changes TF24's numerics and needs a
`scientific_version` bump. Independent of everything else here.

**5. Re-measure the storage pull request's headline.** It reports single-species reproduction
dropping "~9× (227 → 25)". The post-storage figure is computed with the invalid term. No run was made
at that configuration; do it in both coordinates before the number is relied on.

**6. Multi-species.** Everything here is single-species. The competition integral sums over species,
so nothing in the derivation changes, but it has not been run.

**7. Fix `stochastic_schedule()`.** It passes `patch_area` into `stochastic_arrival_times()`'s
`delta_t` slot, so arrival rates never scale with area. Passing it by name is the one-line fix, but
`test-stochastic-patch-runner.R` runs at `patch_area = 50` with seed-pinned expectations and becomes
about fifty times heavier; re-tune that file in the same change. The probes build their own schedule
and are unaffected.

**8. If the coordinate becomes the default rather than an option**, delete
`Node::growth_rate_gradient`, `Individual::growth_rate_given_height` and the four `node_gradient_*`
`Control` fields, which all become dead, and regenerate the FF16 reference baselines — FF16 and K93
move by `1.2 × 10⁻³` and `1.4 × 10⁻⁴`, small but above a bit-identity tripwire.

## 5. Reproducing any figure

Run from the `plant-dev` root with `plant` installed from the branch above. `probes/lib.R` holds the
shared helpers: a collecting SCM whose per-step `Patch` and `Environment` can be interrogated, and
`patch_operators()`, which evaluates the three candidate compression estimates on one patch state.

| script | produces |
|---|---|
| `01-baseline.R` | the three baselines |
| `03-conserve2.R`, `04-driftrate.R` | Appendix C's conservation drift and its scaling |
| `05-divergence.R`, `06-analytic.R` | the closed form for the omitted term |
| `07`, `08`, `09` | the three estimates through the run, and the recruitment window |
| `12-oracle.R` | the individual-based ensemble |
| `13-arms.R`, `14-refine.R` | forward runs and midpoint refinement in both coordinates |
| `16-eps.R` | Appendix B's step-size study |
| `17-stand.R`, `18`, `19` | stand structure and the oracle comparison |
| `21`, `22`, `23` | §1's within-TF24 decoupling control |
| `24`–`29` | §6's five follow-through items |

Large collected histories are gitignored; rerun `01-baseline.R` to regenerate them.

**Two measurement conventions that matter.** Refinement is by midpoint insertion into
`node_schedule_times`, never `refine_schedule = TRUE`, so both coordinates see byte-identical
schedules at each level. And timings are only meaningful on an idle machine — check
`ps -eo cmd | grep -c '[e]xec/R'` returns zero first; the repeat spread should be about 1%, and if it
is not, something else is running.
