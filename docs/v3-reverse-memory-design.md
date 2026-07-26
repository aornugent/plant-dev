# Reverse-mode memory: profile, decomposition, and the design that does the least

Session 20. The question: the SCM run tape OOMs, and "add checkpointing" was the
standing answer. This document profiles where the bytes actually go, then searches
the design space under `system-design` — with the explicit brief that checkpointing
may be a bandaid that lets clunky strategies stay clunky.

Everything numeric here is measured on this box (15 GB) via `PLANT_TAPE_STATS=1` and
the odelia toys, not extrapolated unless said so.

---

## 1. Profile

### 1.1 The tape is the memory, and its byte model is exact

`Tape::getMemory()` is reproduced to within 40 bytes, for every run of every
strategy, by

    bytes = 12 * ops + 8 * statements + 8 * slots

(12 = an 8-byte partial plus a 4-byte slot index; 8 = a statement record; 8 = one
derivative per slot). At TF24 `life=1` that is 4 445 422 996 B predicted against
4 445 422 996 B reported. The tape is ~88% of process RSS, and it is **fully
released between calls** (RSS returns to 0.13 GB), so there is no leak, no allocator
waste, and no accumulation across the five calls in `test-ad-tf24-scm-gradient.R`.

The failure is an ordinary kernel OOM: peak RSS 15.19 GB, `SIGKILL`, the `oom_kill`
counter increments, `dmesg` carries the victim record.

### 1.2 Cost per cohort-step, by strategy

Tape size tracks `steps × node-ODE-width` almost exactly, so the informative figure
is bytes per cohort-step.

| strategy | life | steps | width | tape | B/(step·width) | ops/stmt | byte split ops/stmt/deriv |
|---|---|---|---|---|---|---|---|
| K93 | 4 | 97 | 440 | 0.09 GB | 2 044 | 1.40 | 58 / 28 / 14 % |
| K93 | 40 | 158 | 685 | 0.23 GB | 2 150 | 1.40 | 58 / 28 / 14 % |
| K93 | **105.32** | 286 | 1 165 | **0.75 GB** | 2 252 | 1.40 | 58 / 28 / 14 % |
| FF16 | 4 | 95 | 602 | 1.53 GB | 26 793 | 1.45 | 54 / 25 / 21 % |
| FF16 | 40 | 235 | 903 | 9.02 GB | 42 522 | 1.45 | 54 / 25 / 21 % |
| FF16 | **105.32** | — | — | **OOM** | — | — | — |
| TF24 | 1 | 129 | 532 | 4.45 GB | 64 776 | 1.63 | 60 / 25 / 15 % |
| TF24 | 3 | 194 | 595 | 9.20 GB | 79 718 | 1.63 | 60 / 25 / 15 % |
| TF24 | **4** | — | — | **OOM** | — | — | — |

**K93 completes at its production patch lifetime in 0.75 GB.** So the engine is not
fundamentally broken. What differs is the recorded work per cohort-step:

    K93 2.15 KB  →  FF16 42.5 KB (20x)  →  TF24 79.7 KB (37x K93, 1.9x FF16)

K93 is closed-form rates plus the separable field. FF16 adds the **crown quadrature**
— a fixed-rule integral evaluated per cohort per rate call, each node a field read
plus an assimilation — and that alone is the 20×. TF24 adds the leaf on top for a
further 1.9×. **The leaf is the smaller multiplier.** The seam-deletion story was
wrong (FF16 never had a seam and OOMs the same way); so is "TF24's leaf is the
problem".

### 1.3 What the v3 scaling work achieved, and what it never measured

The design's scaling claim is real and still holds. Measured on the toys:

- a naive on-tape inner solve is iteration-dependent — 11 001 → 42 081 ops/solve as
  inner iterations go 20 → 60;
- the `implicit_value` (solve-off-tape) path is flat — **699 ops/solve** at
  `n_solves` 1, 10, 100;
- per-step cost is flat in step count — 42 918 → 42 610 ops/step over `n_steps`
  20 → 160.

So growth is linear in recorded work; there is no explosion mechanism left. What was
never measured is the **per-evaluation constant on the composition plant records**.
The two toys that certified "bounded" / "a few MB" each used a simpler shape:

| witness | composition | cost |
|---|---|---|
| `weibull_leaf_tape_profile` | one p\* node at a *known* p\*, no central difference | 11.7 KB/solve |
| `soil_leaf` | a lone `ci` node inside `ode_rates`, closed feedback loop, growing tape | 22.7 KB/plant-step |
| `pstar_ode_reprex` | **plant's actual shape**: `implicit_value` on a central difference whose every evaluation rebuilds the nested ψ_stem and ci nodes | **664 KB/step** |

The reprex now reports tape stats, so the multiplier decomposes (`n_steps=40`,
`nlayer=2`, ops/step): closed form **5 267** → p\* node without nesting **10 514** →
nested nodes with p\* frozen **16 009** → both, i.e. plant's shape, **42 742**
(8.1×). The central difference roughly doubles the nested content, exactly as
hypothesised.

Neither toy ever multiplied a per-solve cost by cohorts × steps. That product is the
whole problem.

### 1.4 Two leanness findings the profile hands us for free

**`ops/stmt` is 1.40–1.63.** XAD's expression templates fuse a whole *statement* into
one tape record; the AD literature's worked example is `w = ((a+b)*(c-d))^2` costing
4 partials + 1 statement when fused, versus 7 partials + 4 statements when split into
named intermediates. A ratio of 1.4 means the average recorded statement carries 1.4
operands — i.e. **plant's model code is written as long chains of named intermediate
active variables, which defeats the expression templates almost entirely.**
`assemble_leaf_from` is the type specimen: `const S eta_c_local = …; const S
area_leaf_local = …; const S mass_root_local = …;` — every line a statement and a
slot. Statements + derivatives are **40% of the tape bytes**.

**The crown quadrature is the FF16/TF24 hot spot**, not anything AD-specific — 20× on
its own.

### 1.5 The number that decides the design

For a discrete adjoint you re-record one step at a time from a stored step-start
state, so what must be stored is the **state trajectory**, not the tape:

| | TF24 `life=3` |
|---|---|
| whole-run tape | **9.20 GB** |
| state trajectory (194 steps × 595 states × 8 B) | **0.92 MB** |
| one step's tape (9.20 GB / 194) | **47.4 MB** |

The trajectory is **10 000× smaller than its own tape.** That single ratio settles
the compute-versus-storage question before any candidate is written.

---

## 2. Requirements ledger

- **R1 — exact trait gradients of the SCM's emergent outputs** (census
  LAI/biomass/basal-area, R0/offspring). Outputs m ≤ 3 today. Number of traits
  **k = unknown — ask.** The tests seed k=1. *This is the one quantity that decides
  whether reverse mode is needed at all* (§3).
- **R2 — run at production patch lifetime.** `max_patch_lifetime = 105.32` is FF16's
  own default. Measured: K93 0.75 GB ✓, FF16 **OOM**, TF24 OOM at life=4. Budget
  15 GB, and a gradient that consumes the whole box is not usable inside a
  calibration loop, so call the target **≤ 2 GB peak**. Required improvement at FF16
  life=105: **≥ 8×**; at TF24 life=105 (modelled as steps × width × 80 KB ≈ 29 GB;
  a life^0.66 fit on three points says ~94 GB — take 30–90 GB) **≥ 15–45×**.
- **R3 — DX = concept count.** 0 `xad::` tokens and 0 hand-written adjoints in a
  strategy TU. A fix that adds vocabulary to *strategy* code fails this even if it
  meets R2.
- **R4 — only `double` crosses the R boundary.**
- **R5 — value reproduction stays bit-exact** (already structural in
  `scm_jacobian`).

**Challenged upward:** R2 arrives as a solution-verb — "add checkpointing". The
outcome wanted is *a gradient that fits in memory at production lifetime*;
checkpointing is one mechanism for it, and §1.5 says it is the mechanism for the
opposite regime from ours. Second challenge: R1 needs its `k`. If k ≤ ~5, the floor
below meets everything and none of this is needed.

**Scarce resource:** peak tape bytes = *(recorded ops per cohort-step)* ×
*(steps × cohorts held simultaneously)*. Every past effort — `implicit_value`,
solve-off-tape, the toys — attacked the first factor. **Nothing in the design bounds
the second.** That is the gap.

---

## 3. The floor

**Forward mode. It already exists, and it uses no tape at all.**
`odelia::compute_jvp` is a tapeless forward dual (`xad::fwd`), currently used only as
the dot-product oracle. k traits = k forward runs at ~2–3× double cost each, **zero
tape bytes**, no new concept, no plant change. Wiring it to the SCM entry is one
`scm_jvp` function beside `scm_jacobian`.

Against the ledger: it meets **R2 outright and with infinite margin**, R3 (nothing
new in strategy code), R4, R5.

It fails R1 only on time, and only if k is large: cost is k × (2–3 ×
double-run) versus reverse's 1 ×. At k=5 that is ~10–15 double runs — for FF16 at
life=105, minutes, not hours.

**So the floor genuinely suffices for small k, and that is the kill question for the
entire reverse-mode edifice at SCM scale.** It must be answered before building
anything: *how many traits does a production gradient need?* If the answer is "a
handful, for selection gradients", ship the floor. If it is "tens, for calibration",
the floor's k× time is the ledger line that pays for a candidate below.

Note what the floor does *not* do: it gives no reverse-mode witness, so the
FD-verification programme (task #27) and the `⟨Jv,u⟩=⟨v,Jᵀu⟩` oracle still want a
working reverse path. That is a real requirement, but it is a *testing* requirement
satisfiable at short lifetimes, where reverse already works.

---

## 4. Candidates

**A [first thought] — checkpoint the run tape** *(move 4: trade compute for
storage)*.
Commitment: the tape holds only a window; discarded windows are recomputed on the
backward pass, via `xad::CheckpointCallback` + `insertCallback` /
`newNestedRecording` / `getAndResetOutputAdjoint` (`chkpt=0` today — entirely
unused). Pays for R2 by a factor set by the window count. Costs: a callback type, a
recompute schedule (Revolve or hand-rolled), a second control flow for the backward
pass, and **it leaves ops-per-cohort-step untouched** — the user's "lazy tape
management" objection, precisely. Wins when the trajectory is too large to store and
you must trade recompute for it.

**B — step-local VJP over a stored trajectory** *(move 6: Pólya with witnesses)*.
Commitment: **the tape never spans more than one step.** Forward: run in `double`,
storing step-start states (0.92 MB). Backward, for k = N…1: load state at t_{k-1},
record that one step active, seed the state adjoint λ_k, sweep, read λ_{k-1} and
accumulate ∂J/∂θ, `resetTo` the step's start position. XAD already exposes exactly
these primitives — `getPosition`, `resetTo`, `computeAdjointsTo`,
`clearDerivativesAfter` — so no `CheckpointCallback` is needed. Each step is
recomputed **exactly once**: the optimum, not a Revolve log-factor. Pays for R2 by
`steps` (129–300×): peak tape = one step = 47 MB at TF24 life=3, ~51 MB at FF16
life=105. Costs: a second driver in odelia, an explicit adjoint jump at cohort
introduction, and ~2× the active-run time. Three witnesses for one mechanism: it
subsumes the whole-run tape, the checkpointing question, *and* the
growing-tape-survives-resize special case. Wins when the trajectory is orders of
magnitude smaller than its tape — measured at 10 000×.

**C — make the strategies lean** *(move 7: amortize the per-item taping overhead)*.
Commitment: recorded ops per cohort-step is a model-code property and gets budgeted
like one. Three measured levers: fuse expressions so `ops/stmt` rises from 1.4
toward 4 (statements + derivatives are 40% of bytes → ~1.3×); make the interior p\*
stationarity residual analytic instead of a central difference of the full assembly
(reprex: 42 742 → 16 009 ops/step → **2.7×**, TF24 only); attack the crown
quadrature, which is FF16's entire 20× over K93. Pays for R2 by ~1.3× (FF16) to
~3.5× (TF24). Costs: touching model code in the hot path, and re-blessing nothing
(it is derivative-neutral). Wins when the per-item constant, not the count,
dominates — and it also buys *time*, which neither A nor B does.

### Pick by arithmetic

**Winner: the floor if k ≤ ~5; otherwise B, with C done regardless.**

- **A is dominated by B.** Both bound the tape; A pays a recompute factor ≥ 1 *and*
  a callback/schedule vocabulary to avoid storing a trajectory that costs 0.92 MB.
  Its "wins when" condition — trajectory too big to store — is false here by 10 000×.
  Eliminated on R2-with-least-machinery, not on taste.
- **C alone does not meet R2.** FF16 needs ≥ 8× and C gives it ~1.3×. It is not a
  competitor; it is orthogonal work that both other candidates benefit from.
- **B meets R2 with margin** (129–300× against a required 8–45×) and, uniquely,
  makes peak memory **independent of patch lifetime** — the only candidate whose
  scaling in the scarce resource is flat rather than merely smaller.
- **The floor beats B on every axis except time**, and time is the axis whose
  quantity is unknown. Hence the question, not a guess.

---

## 5. The commitment (B)

> **The tape never spans more than one integration step.** Reversal happens on the
> run's own recurrence, with AD used only inside a single step; what crosses between
> steps is a state adjoint vector of `double`, not tape.

**Kept true by:** the driver never holds a tape across a step boundary — it
`resetTo`s the step's start position after each sweep, so a tape spanning two steps
cannot be constructed. The state adjoint crossing the boundary is `std::vector<double>`,
so "carry an active value across a step" is not expressible in the type.

**Check against the four tests.** True in the real environment (plant's SCM already
segments itself — `run_next_impl` is literally `[grow][resize][integrate]`, and
`solver.advance_fixed(e.times)` already advances a given step list from a set state).
Breaking it makes the system worse, not merely different: a two-step tape reintroduces
lifetime-dependent memory, the exact defect. It removes categories of bugs rather than
relocating them — see §6. And the requirement change that kills it is named in §8.

## 6. What this settles

- **There is no growing tape.** The concern that "the odelia + SCM bridge / growing
  tape has never felt quite right" dissolves: a one-step tape cannot outlive a
  resize. `test-ad-growing-resize.R`'s whole subject — the tape surviving a mid-run
  `resize()` — becomes unreachable rather than verified, and `reserve_state` stops
  being a question.
- **No checkpoint schedule, no `CheckpointCallback`, no recompute policy.** The
  recompute factor is fixed at 1 by construction.
- **Peak memory stops depending on patch lifetime**, so R2 never has to be re-asked
  when someone raises `max_patch_lifetime`.
- **The census vector costs one backward pass, not three.** Three λ vectors are
  carried simultaneously and swept against each step's tape before `resetTo`.
- **Strategy code does not change at all** — B is entirely inside odelia's driver, so
  R3 is untouched.

## 7. What this makes hard

~2× the active-run wall time (each step's forward is recorded once more than today),
and the cohort-introduction boundary needs an explicit adjoint jump: a newborn's IC
reads the active stand, so the newborn's adjoint feeds back into the existing state's
adjoint at that instant. Today that is just more tape; under B it is a distinct term
that has to be right, and it is the one place B can be silently wrong. Cope by making
introduction its own recorded segment (it already is one) and gating it with a
short-lifetime AD-vs-AD comparison against the current whole-run tape, which stays
available as the oracle.

## 8. Kill condition

If per-cohort state grows until the stored trajectory is comparable to its tape,
B's premise (§1.5) fails and the right answer becomes **A** — trade that storage
back for recompute. Watch the ratio; it is 10 000× today. Separately, if k turns out
to be ≤ ~5 and stays there, **the floor** supersedes both and B is unnecessary
machinery.

---

## 9. Sequence

1. **Answer `k`.** One question, and it can retire most of this document.
2. **C, now, regardless of the answer** — it is what "set the strategies up for
   lean, fast reverse mode" actually means, it is derivative-neutral, and it buys
   time as well as bytes. Order by measured payoff: analytic p\* residual (2.7×,
   TF24), expression fusion (~1.3×, all strategies, and it is a style rule that
   stops the regression recurring), crown quadrature (FF16's 20× — profile before
   touching).
3. **Floor wiring** — `scm_jvp` beside `scm_jacobian`. Cheap, and it is the
   memory-free escape hatch plus an independent oracle whichever way (1) goes.
4. **B**, if `k` says so. Build it against the current whole-run tape as the
   correctness oracle at short lifetime, then delete nothing until the AD-vs-AD
   comparison is green at three lifetimes.

**Not recommended:** A, unless the §8 ratio moves.

## 10. Sources

Discrete adjoints per time step with stored/checkpointed states, rather than one
tape over the whole trajectory, are the standard treatment
([PETSc TSAdjoint](https://www.osti.gov/pages/servlets/purl/1885149);
[PNODE, a memory-efficient neural ODE framework based on high-level adjoint
differentiation](https://arxiv.org/pdf/2206.01298);
[Adaptive Checkpoint Adjoint](https://arxiv.org/pdf/2006.02493)).
The statement-fusion argument behind §1.4 is
[Efficient Expression Templates for Operator Overloading-based AD](https://arxiv.org/pdf/1205.3506)
and [CoDiPack](https://arxiv.org/pdf/1709.07229).
