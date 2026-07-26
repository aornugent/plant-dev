# The crashing traces are not weight blow-ups, and transporting mass does not fix them

*2026-07-26. Tests question 1 of [`oracle-consultation-hypersensitivity-extinction.md`](oracle-consultation-hypersensitivity-extinction.md)
— "is the pointwise density along characteristics simply the wrong dependent variable; is the fix a
conservative / mass-based representation?" — on a build where that reformulation already exists, and then
instruments the crashes it was supposed to fix. Two results. **(1)** The mass reformulation was built on
the AD line after an independent Oracle round prescribed it; opting TF24 onto it rescues none of five
crashing configurations and breaks one that previously completed. **(2)** More importantly: on this
branch's own build, instrumenting the crashing stress traces shows the cohort density **never diverges**
— it sits at `exp(−27)` on `long_horizon` and below `exp(0.01)` on `whiplash` while a soil layer goes to
`−190`, `+413`, `−916`. The failure is a positivity/stiffness failure in the fast block. The
size-density measure is a bystander.*

## 1. Why this was worth measuring

The consult's Q1 offers, as the leading reframe, "carry per-member integrated mass over its interval
rather than a pointwise weight, so the blow-up becomes a harmless concentration of a bounded quantity".
That idea is not untested in this project. A separate Oracle round on the AD line
(`docs/oracle/oracle-consultation-transport-compression.md` and its response, on
`claude/odelia-ad-tape-reverse-496fuf`) was given the same weight equation from the discretisation angle
and returned exactly that prescription —

> Transport `(x, log m)`. `dλ/dt = −r`: the compression cancels identically and is never formed. `λ` is
> monotone ⇒ no overflow, **any regime**.

— with the falsifiable prediction that "overflow vanishes identically in ALL regimes". It was built:
`odelia::mass_transport`, plant's `Node::on_mass_chart` / `Species::reconstruct_densities` /
`seed_newborn_log_mass`, and the mass-lumped competition census (`odelia#46`) that keeps the
reconstructed density `exp(λ)/Δx` out of the coupling field. K93 and FF16 run on it by default. **TF24
never got the marker**, so the reformulation the consult proposes as the answer to the blow-up had never
been pointed at the blow-up.

Two builds are involved, and the difference matters:

| line | plant | TF24 |
|---|---|---|
| multirate (this branch) | `c4845c4d` | **TF24@v3**: NSC storage (`#517`), soil clamps (`#549`), mortality bounded in `[a_dG1·e^−a_dG2, a_dG1]` |
| AD | `claude/odelia-ad-tape-reverse-496fuf` | pre-`#517`: no storage state, mortality `a_dG1·exp(−a_dG2·prod)` unbounded above |

## 2. Result A — the stress-bank crashes are soil failures, with the measure healthy

Instrumented this branch's own build (`PLANT_MASS_TRACE=1`: per derivs evaluation, the extremes of the
measure and every environment state — `scripts/tf24-mass-chart/bank_trace.R`). Both traces abort with
**"Detected non-finite contribution"**, the message
[`tf24-v2-T6-density-blowup-550-investigation-result.md`](tf24-v2-T6-density-blowup-550-investigation-result.md)
classifies as mode (1), *cohort density → +Inf poisoning the competition integral*.

`whiplash`, last four evaluations before the abort (soil = the five layer water contents, physical range
about `[0, 0.5]`):

| t | max log density | min gap | soil layers |
|---|---|---|---|
| 10.095490 | −1.678 | 1.62e-05 | 0.128, 0.211, 0.226, 0.234, 0.240 |
| 10.143233 | −1.941 | 1.62e-05 | **8.84**, 0.211, 0.225, 0.234, 0.239 |
| 10.286462 | −2.910 | 1.58e-05 | **−346**, **+312**, 0.224, 0.232, 0.237 |
| 10.477434 | +0.008 | 1.72e-05 | **+770**, **−1009**, **+337**, 0.230, 0.235 |

`long_horizon`:

| t | max log density | min gap | soil layers |
|---|---|---|---|
| 38.215608 | −26.94 | 3.24e-07 | 0.405, 0.199, 0.208, 0.214, 0.218 |
| 38.431213 | −28.09 | 3.14e-07 | **−191**, **+190**, 0.208, 0.213, 0.218 |
| 38.718686 | −24.67 | 3.46e-07 | **+413**, **−916**, **+507**, 0.213, 0.217 |

Read the density column. On `whiplash` the largest cohort density in the stand is about `exp(0)` — one —
at the moment of the abort; on `long_horizon` it is `exp(−27) ≈ 2e-12`, twelve orders *below* one and
thirty-nine below the guard's `log density > 50` ceiling. The minimum node gap is flat across the event
in both: no spacing collapse, no concentration. `Patch::check_finite_ode_state` runs at every derivs
evaluation and never fired on a density, which independently certifies that no node's density was
non-finite or above the ceiling. The guard that *does* fire tests the per-node contribution
`density · compute_competition(height)` (`species.h:240`); with the density finite and tiny, the
non-finite factor is **the per-individual competition effect**, evaluated against a soil state of `−916`.

What does move, in both traces, is a **soil layer leaving its physical range inside a step** (`8.84`
against a saturation of roughly 0.5; then `−191`). Once one layer is negative the inter-layer cascade
moves equal and opposite quantities between neighbours and the pair amplifies — `1e0 → 1e2 → 1e3` here,
and `1e6 → 1e108` in the reprex of §3 — until something is non-finite.

**This refutes the classification in `tf24-v2-T6-density-blowup-550-investigation-result.md` §1.** That
note assigned all three crashes to mode (1) on the strength of the *message*, and cancelled Oracle rung #5
(retrofit the exact drainage recession) as "a solver fix for a non-solver failure". Measured, the message
is not a diagnosis: mode (1) fires whenever *any* factor of the census edge is non-finite, and here the
density is not it. The failure is in the fast block, which is precisely what the recession retrofit
targets. **Rung #5's premise should be reinstated as open.**

## 3. Result B — the `#550` reprex completes on this build; it crashes on the older TF24, and there too the soil goes first

The reprex the consult's C1 is built on (TF24, `lma = 0.07`, 5 soil depths, rainfall
`0.4·sin(2πt) + 0.5`, `max_patch_lifetime = 30`) **completes on this branch's build**:
`offspring_production = 0.0043819176`, max log density `−1.33` throughout. plant's own test on this
commit says so in as many words — *"This regime used to blow up (#550) … Both are now fixed"* — and names
the original mechanism: the growth-dependent mortality `a_dG1·exp(−a_dG2·prod)` overflowing and running
the coupled `(log density, mortality)` ODE away. That is a **loss-term** overflow, not a compression
overflow.

On the AD line's pre-`#517` TF24 the same reprex still aborts, and the instrumented trace has the same
shape as §2: max log density `−1.05`, max log mass `0.08`, min gap flat at `4.7e-07` one evaluation
before the end; then layer 0 at `−0.357`, then `±1.8e+06`, then `±9.3e+107`, then `±inf`. The
`λ`-max cohort at that point carries a loss rate of **−1604 /yr** (`a_dG1 = 5.5`, so `exp(−a_dG2·prod)`
has reached ~292) — the unbounded-mortality channel the NSC pool later removed.

## 4. Result C — the mass chart rescues nothing and costs one configuration

One build, one variable: `Control$node_geometric_compression` off (the FD upwind stencil on
`log_density`) versus on (the log-mass chart). Three changes make "on" a fair test rather than a strawman,
on plant branch `claude/tf24-mass-chart-probe` (parent `claude/odelia-ad-tape-reverse-496fuf`):

1. `TF24_Strategy_` declares `using geometric_transport = void;` — the whole opt-in.
2. `Species::consumption_rate` forms each trapezium end on the chart as `(gap/Δx)·exp(λ)·rate`, the
   node-lumped edge `Species::census` already uses, so the soil coupling is not still a pointwise-density
   moment. Off the chart the original expression is kept term for term (see §6).
3. `Patch::check_finite_ode_state` guards the transported `λ` on the chart rather than the reconstructed
   density view, which is allowed to be large at a tiny spacing by construction.

With the flag off the patched build reproduces the unpatched abort **to the digit** (t = 19.173798), so
the chart is the only thing that moved.

| `max_patch_lifetime` | chart off | chart on |
|---|---|---|
| 20 | **completes**, offspring 1.18293e-09 | **abort** — non-finite contribution, t ≈ 3.7 |
| 25 | abort — soil, t = 13.140907 | abort — non-finite contribution |
| 30 | abort — soil, t = 19.173798 | abort — soil, t = 16.093227 |
| 40 | abort — soil, t = 14.102200 | abort — non-finite contribution |
| 50 | abort — soil, t = 7.184730 | abort — non-finite contribution |
| 70 | abort — soil, t = 7.187092 | abort — soil, t = 16.095026 |

Zero rescues out of five; the one configuration that survived on the production path dies on the chart.
The Oracle's "overflow vanishes identically in ALL regimes" is **refuted for TF24**, in the direction of
making things worse — and the mechanism of the new failure is instructive. At mpl = 20 the chart's own
state jumps from `λ = −0.12` to `λ = +231.9` in a single RK stage, on an established 6.5 m cohort (not a
newborn) whose loss rate is `−1605`: `λ` is monotone in exact arithmetic, but an explicit stepper on a
stiff negative rate is not, and the census then evaluates `exp(231.9)`. The chart moves the pathology; it
does not remove it, because the stiffness lives in the loss term `m`, which the chart keeps verbatim.

This extends the AD line's own Round 3 finding (`docs/oracle/oracle-consultation-index.md` there): the
chart is value-unstable at a growth-shutoff boundary, reproduced on FF16 under ordinary forcing. Round 3
asserted, without running it, that the chart "would not solve #550's model-side steepness". That is right
about the rescue and understates the cost.

## 5. Result D — tightening the integrator *does* help, so "the divergence is in the equations" is false

plant's guard text and `#552` both state that smaller steps do not help. On the AD build's crashing
reprex (mpl = 30, chart off), sweeping the integrator:

| `ode_tol_rel/abs` | `ode_step_size_max` | outcome |
|---|---|---|
| 1e-4 (default) | 5 | abort — soil, t = 19.173798 |
| **1e-6** | 5 | **completes**, offspring 1.0642e-08 (615 s) |
| **1e-6** | 0.05 | **completes**, offspring 1.06471e-08 (608 s) |
| 1e-8 | 5 | stops — "Cannot achieve the desired accuracy" |
| 1e-10 | 5 | stops — "Cannot achieve the desired accuracy" |

A 100× tighter tolerance converts the abort into a completed run, and two independent step-size regimes
agree on the answer to 5e-4 relative. That is the signature of an integrator failing a positivity
constraint, not of a divergence in the equations. (The 1e-8 and 1e-10 rows are the ordinary explicit-RK
accuracy floor at a non-smooth feature — a controlled stop, not a blow-up.)

**The same holds on this branch's own stress bank.** `whiplash`, which aborts at the default 1e-4 after
79 s at t = 10.48:

| `ode_tol_rel/abs` | outcome |
|---|---|
| 1e-4 (default, as run in the bank) | abort — non-finite contribution, t = 10.48 |
| **1e-6** | **completes** (538 s), offspring 3.8230283e-08 |

So one of the three "crashing" bank traces is not crashing on the model at all — it is crashing on the
integrator's tolerance. **`long_horizon` at 1e-6 was not run** (stopped for time; the 70 yr horizon at a
100× tighter tolerance is a long run). It is the obvious next data point, and `bank_trace.R` takes it
directly: `Rscript scripts/tf24-mass-chart/bank_trace.R long_horizon 1e-6 plant`.

## 6. Result E — the abort time is not reproducible under floating-point reassociation

Found by accident, and load-bearing for how any of these comparisons should be read. An intermediate
version of change (2) in §4 rewrote the *off-chart* trapezium from `gap·(c_{k−1} + c_k)` to
`gap·c_{k−1} + gap·c_k` — the same sum, a different rounding, nothing else changed.

| off-chart uptake reduction | abort |
|---|---|
| `gap·(c_{k−1} + c_k)` (original) | t = 19.173798 |
| `gap·c_{k−1} + gap·c_k` (reassociated) | t = 16.108785 |

**A pure floating-point reassociation moved the failure 3.07 simulated years earlier**; restoring the
association restored the abort time to the digit. Any claim of the form "scheme A survives to t and
scheme B does not" carries no information at the resolution we have been quoting.

## 7. Consequences

- **For the consult.** Q1 is answered — the conservative reformulation exists, is in production for two
  strategies, and does not address this failure. C1's premise ("the weight of a single member reaching
  +Inf while every other quantity stays finite, all `L` reservoir components finite") is **backwards** on
  every trace we can instrument: the reservoirs go first and the weights stay bounded. The consult must
  be corrected before it goes out; see the revision landed alongside this note.
- **For the ladder.** Rung #5 (exact drainage recession) was cancelled on a premise that measurement does
  not support. It, and any other fast-block positivity treatment (exact recession, a clamp-free
  positivity-preserving substep, an implicit or split treatment of the near-singular loss), is back on the
  table as the intervention aimed at what actually fails.
- **For the stress bank.** Its crashes are integrator failures in the fast block, on traces where the
  readout is already in the near-extinction regime. That reinforces `tf24-v2-T6-density-blowup-…`'s
  conclusion that the bank measures cost and monitor behaviour rather than accuracy — for a different and
  better-supported reason than the one recorded there.
- **Not affected.** Slice 1 (`newton_collar_solve`) rescuing `extended_drought` stands; it is a statement
  about the inner optimum's continuity, independent of all of the above.

## 8. Reproduction

```bash
# This branch's build (TF24@v3):
Rscript scripts/tf24-mass-chart/repro550.R FALSE 30 plant          # completes, 0.0043819176
PLANT_MASS_TRACE=1 Rscript scripts/tf24-mass-chart/bank_trace.R whiplash default plant 2>trace.err
PLANT_MASS_TRACE=1 Rscript scripts/tf24-mass-chart/bank_trace.R long_horizon default plant 2>trace.err
Rscript scripts/tf24-mass-chart/bank_trace.R whiplash 1e-6 plant   # the stepper test

# AD line, plant @ claude/tf24-mass-chart-probe, odelia @ claude/odelia-ad-tape-reverse-496fuf:
Rscript scripts/tf24-mass-chart/repro550.R FALSE 30 <path>         # abort t=19.173798
Rscript scripts/tf24-mass-chart/repro550.R TRUE  30 <path>         # chart: abort t=16.093227
Rscript scripts/tf24-mass-chart/mplsweep.R                         # the 20-70 sweep
```

The trace is `PLANT_MASS_TRACE=1` on the instrumented builds: one line per derivs evaluation with
`max λ`, `max log density`, the height and loss rate of the extreme node, the minimum node gap, and every
environment state. It is ~20 lines in `Patch::check_finite_ode_state` and worth keeping.
