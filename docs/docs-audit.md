# Docs and comments: what one session's debugging left stale

**What this is.** The residue of the session that closed the gradient suite's
last eight failures — every documentation and comment defect it turned up and
did **not** fix, with the measurement that supersedes each. It is a work list,
not a survey: see *Coverage* at the end for what was never looked at.

**Why it is a file rather than a set of edits.** Three of these want numbers
that only exist on macOS/arm64, and two want a decision about a fixture's
intent. Guessing at either is how a guide acquires a figure nobody re-derived.

---

## A. Superseded by measurement

### A1. The test-timing tiers are wrong, and one sentence is flatly false

`AGENTS.md:219-221`

> the gradient ladder is the expensive tier — 18 files, **61 s of wall** measured
> at `-O2` — and everything else is 57 files and about 90 s. **No single file
> outside the ladder is slow enough to matter.**

The last sentence is false. `test-events.R` does not finish in twenty minutes at
its own fixture's settings, and the cause is a cliff in patch lifetime that every
lifetime-5 TF24 stand crosses. At TF24's default `lma`, one stand:

| lifetime | 3 | 3.1 | 3.25 | 3.5 | 4 | 5 |
| --- | --- | --- | --- | --- | --- | --- |
| steps | 205 | 215 | **842** | 3324 | 6068 | 9576 |
| seconds | 2.7 | 3.0 | 20.1 | 89.5 | 167.6 | 267.1 |

**The job.** Re-cut the tiering with the cliff named, and say which files cross
it. The 61 s / 90 s figures also predate this and want re-measuring at `-O2`.
⚠️ Do not simply raise the numbers: the useful statement is *which* files run a
stand past lifetime 3 and why that is expensive, which is
`d(mortality_dt)/d(storage)` at 2.019e+07 — see `docs/design/measurements.md`.

### A2. phylloptim's cross-platform section reads as current and is not

`phylloptim/.claude/CLAUDE.md:430-540` (the tables at 438-442, the headroom claim at 521)

The section reports `profit` at 1.86e-07 and "the other eight" at 9.02e-06
against tolerances of 1e-05 and 5e-03, argues that "the inherited tolerances are
generous rather than wrong" with "roughly 285× of headroom", and tells the reader
CI compares "with `--cross-platform` elsewhere" as though that passes.

Measured on this box after the stem-table inversion:

| file | beyond cross-platform tolerance | worst |
| --- | --- | --- |
| `operating_points.tsv` | **222 of 576 points** | argmax-derived **0.624** (tol 0.005); profit **4.84e-05** (tol 1e-05) |
| `psi_stem_optima.tsv` | **60 of 5184 rows** | 0.624, all `collar`-route wet-bound pins |

Both classes now exceed their tolerances, so the headroom argument, the
per-class figures, and the "what this file used to say" narrative built on them
are all stale together.

**The job.** Two steps, in order. Until the goldens are re-blessed on
macOS/arm64, the section should say they are **known-stale from a deliberate
results change** rather than reading as a description of the present. Then
re-cut the figures from the regenerated files. ⚠️ This section has already been
wrong twice by reading a truncated failure list as a distribution, and it says so
itself — a third pass must read the **summary** line.

### A3. A plan that reasons from 100 knots

`plant/notes/penman-monteith/implementation-plan.md:109` — "over ~100 knots".

The shipped count is 400. The cost the plan reasons about moves with it:
`set_traits` with a curve rebuild is 110.9 → 440.4 µs, ×3.97 (interleaved, two
binaries from one tree). The solve is unchanged.

**The job.** One line, plus a check that nothing downstream in the plan turns on
the old figure.

---

## B. A hazard documented in a guide but not at the site

Each of these is a place where the code's behaviour is load-bearing and silent,
and where the only written account is now in a developer guide. A reader in the
file cannot see it.

### B1. `check_finite_ode_state` does not say what it declines to look at

`plant/inst/include/plant/patch.h:402-407` (the declaration; the body is at 695)

The comment names the two runaway modes it catches — a cohort density going
non-finite, and the environment's own states — and never says that the six slots
`Strategy::state_names()` declares and the node's two extras are **not**
examined. That gap is what let `mortality = -log(0)` run: every reader of the
hazard is guarded, so the forward model was correct and silent while the
trajectory it recorded could not be differentiated.

Now in `plant/agents.md`'s checklist. Not at the site.

### B2. `errlevel` has no comment, and its behaviour at a non-finite state is the point

`odelia/inst/include/odelia/ode_control.hpp:189`

    errlev = tol_rel * (a_y * abs(y) + a_dydt * abs(h * dydt)) + tol_abs

At `y = ±Inf` this is `Inf`, so `r = |yerr| / errlev` is 0 and **that component
cannot constrain the step however large its rate**. An infinite state entry
therefore buys silence from the controller. That is what a `-Inf` density
sentinel was doing for free, and why replacing it with a finite one needs the
rate parked explicitly (`Node::compute_rates`).

**The job.** Say it where `errlevel` is, in the register `ode_control.hpp`
already uses for the non-finite-ratio rejection twenty lines above.

### B3. The refusal contract predates a refusal that names no species

`plant/R/stand_gradient.R:79-85`

> A refused metric's whole row is `NaN`: a sum has no defined value with an
> undefined term, so refusal is metric-level and carries no localisation within a
> metric.

True, and now incomplete. The sweep's own refusal — the descent leaving the range
a double holds — carries `species = -1`, because what overflowed is an
intermediate of one recording spanning every cohort in every stage. A caller
reading this roxygen cannot tell that the `species` field may hold no location.
`test-gradient-parity.R`'s gate already asserts both cases.

**The job.** One sentence in the `@return`, and check `census_gradient.h`'s
`struct refusal` comment says the same thing (`census_gradient.h:21` reads "one
that happened always names one", which is no longer true).

---

## C. A fixture pinning what the model owns

### C1. `trait_matrix(1, "lma")`, undocumented and expensive

`plant/tests/testthat/test-events.R:241`

1 kg/m² is five times TF24's default (0.1978791) and four times the largest value
any other test in the suite uses — every one of those sits between 0.08 and 0.26.
It is also the only value at which recruits fail to establish in this stand, so
it may be deliberate: a suppressed canopy makes the water-balance assertions
cleaner. **Nothing says so.**

Measured: 14371 steps at a quarter-year against the default `lma`'s 82.

**The job.** Decide the intent and write it down. If deliberate, a comment saying
what the extreme value is buying. If not, it moves — and the pulses are at
t = 1, 2, 3, so a lifetime of 3.1 leaves a tenth of a year of margin and runs in
3.0 s against 267.1 s. ⚠️ Its assertions look trait-independent (conservation
identities), but that is a reading, not a measurement.

This is the pattern three fixtures showed this session, and it is worth stating
once: **a fixture that pins a number the model owns passes until the model's
value moves, and then reports the model's change as its own failure.** The
distinction that matters is whether the fixture is comparing against a *recorded
file* — where pinning is right, and phylloptim's C++ goldens pin their resolution
deliberately — or against *the model itself*, where it is not.

---

## D. Where a new refusal is explained

### D1. The range refusal cites no document

The leaf's curvature refusal ends "See `docs/design/one-program.md`". The
descent's range refusal explains its mechanism inline and points nowhere, though
`docs/design/measurements.md` now carries the measurement — λ reaching
4.99978e+281 on a stand that answers, and coming back.

**The job.** Decide whether the message should cite it. While there,
`one-program.md:443`'s risk register lists `sweep_range`'s width-mismatch refusal
as R4; `sweep_range` now has a second refusal and the register does not know.

---

## Coverage

⚠️ **This is one session's residue, not a sweep.** Everything above was found
while chasing a specific defect, so the absence of an item is not evidence.

**Looked at:** `AGENTS.md`, `plant/agents.md`, `phylloptim/.claude/CLAUDE.md`,
`docs/design/measurements.md`, and the specific comments and roxygen named above.

**Not looked at:** `odelia`'s `ARCHITECTURE.md`, `AUTODIFF.md` and
`RECORDED-DECISIONS.md`; `phylloptim`'s `README.md`, `COMPARISON.md`, `NEWS.md`,
`SURFACE-AUDIT.md` and vignettes; `plant`'s `NEWS.md`, skills and issue
templates; the other eight files under `docs/design/`; `docs/surface-audit.md`;
and every roxygen block except `stand_gradient`. A knot count and a shipped
default both moved this session, so the vignettes and `NEWS.md` are the likeliest
places for another stale figure.

**Already applied, not pending:** `docs/design/measurements.md`'s own corrections
from this session — the timing attribution that was the build's, the
`operating_points.tsv` reading that came from a grep missing its summary line,
and the two attributions retracted against a control build.
