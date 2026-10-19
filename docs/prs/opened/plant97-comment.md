### Merge order
Stacked: #94 (exact establishment counts) ← this ← #114 (crossed crowns) ← #115 (TF24's soil substeps) ← #116 (TF24 fitness). The numbers below were measured on develop + this commit; the reference rows are re-captured on #94 + this commit.

### The problem, in the model's terms
- A seedling's pool relaxes at `λ = (charge + drain)/storage_max`, up to 1444 /yr (about 6 h), against daily forcing.
- On develop's 40-year long-drought stand (108 introductions, birth date, `ode_tol` 1e-3), the resident throws 993 stages below empty, and every invader tried fails: lma ×2 at its first step, ×0.9 and ×1.2 later, each on the stage check.

### What changes
- The pool's relaxation rate becomes `λ/(1 + λ·o) ≤ 1/o`. At `o` = 7 d, explicit Cash–Karp steps are stable to 3.73·o (about 26 d) and stay non-negative to 2.16·o (about 15 d).
- After production turns negative a seedling has `drain/storage_max` of order 1/hours, so its relative reserve r follows `dr/dt ≈ −r/o`. Its reserves fall from `a_st3` to the hazard's e-folding point `1/a_dG2` in `o·ln(a_st3·a_dG2) = 7 d × ln 16 = 19.4 d`, whatever its size. With `o = 0` that time is `storage_max/drain`: hours, and set by size.
- Without the stage check, a stage below empty is an overshoot: its rates stay finite and point back into the domain, so the error estimate rejects it like any inaccurate step.
- One state still reaches the domain check: the step's end, through `Patch::ode_state_valid()`. The adaptive stepper rejects a bad end; a step of fixed size is subdivided; an invasion, which must take the resident's steps, fails by name.

### Measured on develop + this commit
40-year long-drought stand (`harness/long_drought.R`), one run at a time. A separate build counted thrown stages and refused step ends; it is not part of the PR.

| 108 introductions, birth date, tol 1e-3 | v11 (offset 0, check on) | offset only (check on) | this PR |
|---|---|---|---|
| offspring production `J` | 13.348750 | 13.773991 (+3.19%) | 13.762608 (+3.10%) |
| accepted steps | 10 550 | 9 329 | 9 262 |
| stages thrown (resident) | 993 | 192 | 0 |
| step ends refused | 0 | 0 | 25 |
| wall time | 191 s | 169 s | 168 s |
| invader lma ×2 on the resident's steps | refused at its first step | refused at its first step | runs (`J′` 1.9e-21) |
| invaders lma ×0.9, ×1.2 | fail on the stage check | — | run (`J′` 61.0, 0.076) |
| invader lma ×0.7 | fails in the leaf solve (`stem_curve_domain`) | same | same |

- ×0.7 fails in phylloptim's leaf solve in all three builds, so that failure is not the pool's; the TF24 fitness PR (#116) runs it (`J′` 464.3).
- On the test fixture's birth-date stand, invaders ×0.7 and ×2 run; at a zero offset ×2 overflows its density (new test).
- With exact establishment counts, `J` moved +2.0/+2.6/+2.7% at 108/215/429 introductions, and `dJ/d lma` from −168.556 to −195.988 by adjoint (central difference −168.462 → −195.975), with `dJ/d offset` = −22.074. Those were measured on an earlier build of the same change.

### What it costs
- Model: +23/−26 lines in `tf24_strategy.h`: one parameter added, the stage check deleted. Bindings +5/−1, generated.
- Runtime: 12% less wall time on long drought (191 → 168 s), with 12% fewer accepted steps.
- References re-captured:
  - "offspring arrival" five-year values. Height coordinate: 24.321 → 18.598 (−23.5%) and 18.543 → 14.104 (−23.9%). Birth date: 219.27 → 212.02 (−3.3%) and 34.588 → 32.987 (−4.6%). The height coordinate's probe magnifies any change to the pool.
  - TF24's seeded stochastic count, 77 → 79 (77 at a zero offset, now tested).
  - The model-version snapshot (v12, v12.1, the new parameter).
  - `reference-gradient.tsv`, with `scripts/capture-reference-gradient.R`: 30 new rows for the new column; 91 of 1380 rows move by more than 1e-3 of their metric's scale. The largest are `theta` and `omega` on `leaf_area` on the drought and seasonal stands (seasonal species 2 `theta` 239.06 → −1511.01): these stands' seedlings are where the divisor matters, and `theta` sets the storage capacity it reads. Every moved row's finite differences converge (spread ≤ 1.1 on values of order 1e3), and the whole-run check passes against the reverse sweep.
  - The capture script called `census_metric_names_tf24()` without the run since #658; its unused metric count is dropped (−1 line).
- TF24f's convergence check now compares against TF24 at `tol` 1e-6: at the default tolerance, TF24's own error (0.21%) exceeds TF24f's lag at `k_acclim` = 100 (0.04%).

### Tests
- New: the divisor's form against a hand computation (1e-12) with the offset binding; the relaxation rate falling from about 380 to 55 /yr against `1/o` = 52; a negative offset refused; a stage below empty with finite rates that refill the pool; invaders ×0.7 and ×2 on the run's steps, and ×2 overflowing at a zero offset.
- The relaxation-time and height-linear tests are set at a zero offset, so they still test what they did.
- Full serial suite on develop + this commit, `-O2`, odelia 0.7.3, phylloptim 0.10.2: 5461 passed, 0 failed, 4 skipped. FF16's bit-identity checks pass.

### For review
1. Is 7 days acceptable as the default? It is a declared parameter, `o = 0` recovers v11's rates, and it sets every TF24 number.
2. Is the step-end check in `Patch::ode_state_valid()` enough without a stage check? The adaptive path rejects, a fixed-size step subdivides, and an invasion fails by name.
3. The re-captured gradient rows on `theta` and `omega` (drought, seasonal): converged differences of the new model, not noise.

---
_Generated by [Claude Code](https://claude.ai/code)_
