# The storage bound and the growth gate's width

Three pieces of work on TF24's NSC storage block. They share a subject and the
order below is forced: each changes what the next one measures.

The block is `inst/include/plant/models/tf24_strategy.h:1516-1580`. It is
templated on `S`, so it is on the tape. **Issues #609 and #610 cite
`src/tf24_strategy.cpp`, which does not exist on this branch** — their line
references are stale, and #610's deliverable "confirm which audit sites are on
the AD tape" is answered for this site by the template parameter.

---

## 1. What is established

Measured on a single species — `ladder_traits()$fast`, birth rate 1.10 — with
`Control(node_density_in_birth_date = TRUE)`, the schedule refined once by
`run_scm(refine_schedule = TRUE)` and fixed thereafter. Relative reserve is
`min(max(storage, 0) / storage_capacity, 1)` per cohort at the terminal state;
gate slope is `G(1-G)/0.25`, the logistic's slope as a share of its slope at the
band's centre.

| lifetime | cohorts | min r | median r | max r | fraction r > 0.99 | median dG/dr |
|---|---|---|---|---|---|---|
| 2 | 81 | 0.445 | 0.558 | 0.560 | 0.000 | 4.01e-02 |
| 5 | 88 | 0.445 | 0.747 | 0.747 | 0.000 | 6.20e-03 |
| 10 | 97 | 0.037 | 0.814 | 0.815 | 0.000 | 3.15e-03 |
| 25 | 109 | 0.097 | 0.894 | 0.894 | 0.000 | 1.43e-03 |
| 50 | 126 | 0.165 | 0.956 | 0.957 | 0.000 | 7.65e-04 |
| **105.32** | **169** | 0.129 | **1.000** | **1.000** | **0.527** | **4.94e-04** |

Five readings, and the third is the one that decides the work.

**The distribution of relative reserve across a stand is the number report 06
§11 records as never reported.** It is the table above.

**At the production lifetime the clamp binds on more than half the stand.**
`r = min(storage / storage_max, 1)` is exactly 1 for 53 per cent of cohorts, so
`∂r/∂S` is exactly zero for them. Mortality reads `r` directly, so the severance
reaches the density and therefore every census metric — not a diagnostic slot.

**No fixture in the ladder reaches this.** Its stands sit at `r` between 0.44 and
0.56, where the clamp is three orders from binding. The severance is reachable
only by run length, which is why it survived a green suite.

**The gate's slope falls eighty-fold over the same range**, and monotonically.
That is not a defect: `dG/dr → 0` as `r → 1` is the model stating that growth is
production-limited rather than reserve-limited. It is recorded here because it
sets what a growth-mediated trait row is worth at production, and because the
ladder's vacuity guard reads this quantity and will always fail at scale.

**The storage state is not bounded above.** Nothing caps `S`; `r` clamps the
read. Above capacity a cohort accumulates carbon that no consumer sees, and on a
downturn draws on a buffer larger than its stated capacity. #609 notes the
pathology; the table above is its incidence.

---

## 2. Task A — does the gate's width change the answer?

`storage_gate_width = 0.1` is a plain member at `tf24_strategy.h:806`, beside
`storage_prod_eps`. Its centre `a_st2` is a registered differentiable parameter
and carries a row. So the gradient reports where the gate sits and not how sharp
it is, for a curve with two degrees of freedom.

Report 06 §7 rules on the same shape for the vulnerability curve: a curve has the
degrees of freedom a physiologist measures, and a sensitivity taken with one of
them held fixed answers a counterfactual. The question here is whether the width
is a degree of freedom at all, and it is settled by measurement.

**Run.** On a small fixture — seconds, not a production stand — take the trait
gradient at `storage_gate_width` of 0.1, 0.05, 0.025 and 0.0125, holding
everything else fixed, and tabulate the trait rows against the width.

**Two outcomes, and they need different work.**

- **The rows converge.** The width is a mollifier and the small-width limit is
  the model. Record the knee, quote the residual at the shipped value as a bias
  in report 06 §11, and leave the width unregistered.
- **The rows do not converge.** The width is doing modelling work. It needs a
  row, or the logistic needs replacing by a form whose shape follows from
  something measured. Either is a modelling decision rather than a numerics one.

**The fixture must be small and must not be a production stand.** The question is
whether the answer *moves* with the width, not what it is at scale; a production
stand costs hours per point and sits where the gate is saturated, which is the
least informative place to ask.

**Do this before Task B.** Option 4 changes the distribution of `r` and therefore
where on the gate the stand sits, so a width measured after it prices a different
configuration.

**Deliverable.** A table of trait rows against width, and a stated verdict.

---

## 3. Task B — adopt #609 Option 4

The charge/drain split, as the issue specifies it, in two commits.

**B1 — refactor, limiters at 1, assert bit-identical.** The split is exact:

```
charge - drain = Ppos(1 - G) - (Ppos - P) = P - Ppos·G = net_flux
```

so with both limiters set to 1 the rate is unchanged. Assert that, rather than
arguing it.

**B2 — switch the limiters on.** This is a change to the forward model, not a
refactor.

Three hazards, in the order they will be met.

**B2 changes production behaviour for half the stand.** The fill limiter caps `S`
at capacity where nothing currently does, and §1 measures 53 per cent of cohorts
above or at it at 105.32 years. That is a science change: re-bless the forward
model, and raise it with the model's owner before landing rather than after.

**The `min(r, 1)` clamp must be removed, not left in place.** Once the fill
limiter makes `S = S_max` a boundary the exact flow does not cross, the clamp is
dead code that silently re-arms if the limiter is ever weakened. #609 argues the
clamp is unreachable because `S_max` is non-decreasing; that argument covers
`r > 1` and not `r = 1` exactly, which is what §1 measures binding.

**The `(storage + gate_ref) > 0.0` guard becomes properly dead**, and the
`std::max(state, 0.0)` read-clamp becomes unnecessary. Both should go with the
change that makes them so, per #610's own criterion that a bound be enforced by
the form rather than by a clamp.

---

## 4. Task C — re-measure, and what counts as done

Re-run §1's table after B2, at the same lifetimes and on the same fixture.

**The acceptance criterion is not that a test passes.** It is:

- the fraction at `r > 0.99` at 105.32 years falls off the clamp, from 0.527;
- the median `r` at 105.32 years is strictly below 1;
- the storage state is bounded above by capacity, checked on the state rather
  than on the read;
- the census is re-blessed, with the movement recorded in the change that causes
  it rather than in a standing test.

Report the new table beside §1's. A change that moves the clamp's incidence
without moving the census is not possible here — half the stand sits on it — so a
census that does not move is evidence the limiter is not engaged.

---

## 5. What this work does not address

**The gate's saturation is not a defect and is not in scope.** A small
`dG/dr` at high reserve is the model's own answer. What follows from it is a
testing matter — the ladder must not read that quantity as a vacuity guard on a
production stand — and not a change to the block.

**Nor is the cost of the gradient.** A recorded cohort block costs 2.3 ms
against 18 microseconds for the same rates in plain double, and the storage
block is a small share of either. Measured separately: the recorded operation
count does not drive that cost, so making this block cheaper to record buys
nothing. Change it for the severance in §1, not for speed.

---

### Provenance

Measured at `444bcf1a` on `ad/v3-forward`, loaded with `pkgload::load_all` after
`pkgbuild::compile_dll(debug = FALSE)`. Terminal-state classification per cohort
via `ladder_block_value_tf24`; reserve and gate slope via
`ladder_relative_reserve` and `ladder_reserve_gate_slope`. Every figure is a
terminal-state read: the sweep evaluates at every step and every stage, so the
incidences above are lower bounds on what a gradient meets.
