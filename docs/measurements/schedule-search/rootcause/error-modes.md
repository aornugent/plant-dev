# Error modes of the schedule algorithm: what can make its answer wrong or unpredictable

Evidence base for a cheaper guarantee than the check run. The algorithm under study is the
pair: a pilot finds the establishment edges and b1; a committed schedule is built from it;
a second, finer check gradient run (1.30–1.75× the committed run, `localised.md` "Where
the algorithms stand", "Lateral") gives each quantity's estimate move/(1 − s), s from the
pilot proxy (offspring^0.6·h³); the coarse run is committed unless an estimate exceeds ε.
The current rule is a09 with the 12-day inset in the committed run and a 12/R = 7.5-day
inset in the check, on libS without rain stops, tolerance 1e-4 (`loc/prereg.md` E6).

This document lists every way the record shows the answer, or its estimate, can be wrong
or move with incidental choices, whether or not a criterion ever failed. Logged criterion
failures are evidence inside the modes; the full list is in the appendix.

## Conventions

- Errors are in each quantity's ε against the case's reference. "Along M" is the
  projection on agent P's unit direction M (a_l1, root_P50, omega, root_c, stem_c,
  storage_relaxation_offset, ln J), fitted on dry, lib19.
- Evidence strength: **[M]** measured in the record; **[I]** inferred in the record from
  measurements; **[S]** speculative or untested in the record; **[ours]** this document's
  reading, not stated in the record.
- Libraries: pre-0.9.2 (phylloptim before the root-curve fix); lib18 (phylloptim 0.9.2);
  lib19 (0.9.3, the determined collar); libS (lib19 + plant#111, the soil substeps land
  on the rain's knots, no knot stops); libAG (lib19 + the averaged establishment gate,
  scratch build). "Legacy setting": long drought run without soil substeps or splits.
- Sources: `LOC` = `localised.md` (section title given); `PRE` = `loc/prereg.md`;
  `D` = `round3/D/notes.md`; `CTX` = `round3/CONTEXT.md`; `B3` = `round3/B/prereg.md`;
  `E`, `F`, `G`, `P`, `R`, `S`, `U`, `AG`, `JT` = `round4/<X>/notes.md`; `BRIEF n` =
  `harness/schedule/BRIEF.md` lesson n; `GEO §` = `docs/geometry.md`; `GD §` =
  `docs/grid-dynamics.md`; `DSB` = `docs/design-schedule-building.md`.

## Summary

| # | mode | order in node spacing | lives in (birth date / time) | single-run signal | designed out a priori |
|---|---|---|---|---|---|
| A1 | edge-node bias (fate's layer at edges) | 2nd (lib19) | spell-end intervals before closing edges, b1–17 | no amplitude; edges known from pilot | yes: inset |
| A2 | inset strip residual (same inset in both runs) | 0 in interior spacing | 12-d strips beside edges | no | yes: check inset 12/R |
| A3 | spacing-proportional inset overshoot (mid) | 1st | spell ends | no | yes: avoid, or read 1st order |
| A4 | founders' window quadrature | 2nd (ratio ~4.2) | b < b1, first-mover layer | pilot offspring curve predicts it | yes: graded layer |
| A5 | wide intervals off the square law | none above ~110 d | late spacing; via soil to founders | no | yes: range caps |
| A6 | node inside a shut gap | 1st in displacement | gaps beside establishing births | no | yes: placement rule |
| A7 | pre-asymptotic / non-power-law ladders | ~1st or none | graded/placed grids, lumped canopy | no | yes: edges, spread, caps |
| B1 | merged short gaps | 0 | gaps < 10 d, one-day spells | no | yes: don't merge early spells |
| B2 | late edges dropped / interval across an edge | 0 (shared) | b > 20–25 | no | yes: keep 20–25 |
| B3 | constant-rain fate front | needs 1/512 d | front, not in bank | pilot finds it | yes: front nodes |
| C1 | uneven shrink; proxy misplaces error | estimator | background vs founders | shrink per band computable | yes: uniform shrink (fill) |
| C2 | sign-mixed error across regions | estimator | before/after b1 | no | only via uniform shrink |
| C3 | check across merged spans | estimator | merged spans | no | yes: no merging before build |
| C4 | check built, then trimmed | estimator | merged regions | no | yes: trim pilot first |
| C5 | partial check (region left unrefined) | estimator | unrefined region | no | yes: refine or read shrink there |
| C6 | jitter amplified by 1/(1 − s) | random | where steps fall | no | partly: nesting, ratio size |
| C7 | commit gate and C3 fragility | discontinuous | decision | estimate itself | partly |
| D1 | leaf arm switch inside a step (derivative jitter) | 0 in nodes; O(h) in steps | closing edges after drydowns, b 3.5–17 | yes: f_hi roots, λ_soil bound | yes, in the stepper |
| D2 | averaged gate's knee in dE/dt | 0 in nodes | closing edges (libAG) | partly | yes: ETT or wider knee |
| D3 | tolerance error uneven between the pair | 0 in nodes | hydraulic direction | no | via D1/D2 fixes |
| D4 | net-production crossings | 0 in nodes | every member's sign change | yes: splits | yes: splits (setting) |
| E1 | rain knots aliased by RK stages | 0 in nodes | every knot-spanning step | yes: quadrature gate | yes: landed (#111) |
| E2 | stiff top soil under explicit steps | 0, heavy-tailed | heavy rain on wet soil | yes: h·stiffness, guards | yes: substeps / cap |
| E3 | loosened late tolerance | 0 | t > 25 | — | inert with knots |
| F | derivative refuses where forward caps | 0, step-sequence luck | dry stages inside steps | throws (visible) | yes: differentiate the cap |
| G1 | error moves with θ (grid radius) | case | uses at θ ≠ θ₀ | yes: \|ln J − ln J₀\| | no |
| G2 | trait at a model kink (rooting_depth_max) | none | θ₀ on min(·) | no | no (model) |
| G3 | large trait moves; unexplained lma error | case | founders, leaf traits | pilot J ratio flags | no |
| G4 | library/gate change moves the answer | — | everywhere | — | edges from g, not E |
| H | reference error | — | scoring floor | — | — |

## A. Node-placement error: shrinks with spacing, set by the layout

### A1. Edge-node bias

- **Mechanism.** Per-recruit fate curves sharply within 10–20 d of each establishment
  edge, mostly closing edges: on dry ln nrr rises +0.032 over a spell's last 10 d and
  +0.065 over a gap's first 10 d; opening edges +0.020 [M, `P` layer.R]. A node at the
  edge anchors the hat interpolant of the spell's end interval at that curved end; the
  hat 10 d inside reads +0.023 high [M]. Under exact counts an edge inside an interval
  costs nothing by itself: establishment is integrated exactly and only the nodes'
  representation of recruits errs [I from code, `P` arithmetic; M: dry-p50 on dry's grid,
  none of its edges a node, within 0.07ε of its own grid, `F` U1]. The edge layer is the
  weather's, identical under both gates (closing +0.032/+0.062 on libAG) [M, `AG` G1].
- **Order.** Second on lib19: the bias along M is 1.22 committed, 0.56 check, ratio 2.18
  for an open-spacing ratio 1.38 (1.90 squared) [M, `P` order.R]; halving a09's
  committed run shrinks it 3.47× rms against 4× [M, `PRE` N6]. Under the averaged gate
  the pair showed 1.39 [M, `AG` R3], read first as first order, but with the closing
  edges' jitter removed (ETT) the shrink is 1.88 against the sharp gate's 2.18 [M, `PRE`
  E3], and a09's layout quartered converges (rms 0.044, along M −0.12) [M, `PRE` L2]. The
  uniform ladder on libAG converges along M at ratio 5.7 [M, `AG` P_ref].
- **Where.** Spell-end intervals before closing edges, b1 to about 17. Bisecting one
  class of interval at a time on dry: before closing edges +1.04 along M (sharp), +0.82
  (averaged); after opening edges −0.14/−0.16 (the wrong way); gaps nothing [M, `LOC`
  "The pair's misreads"; `PRE` L1]. Error per interval rises toward each spell's closing
  edge: by quarter of the spell 0.5–0.9 → 1.1–2.6 of the median, Spearman 0.19–0.42,
  positive on all five training cases [M, `LOC` "Short shut gaps"]. It reaches the
  quantities through the water the founders see 10–20 years later [I, `BRIEF 5`].
- **Quantities.** Direction M. Removing the bias moves a_l1 and root_P50 down, omega
  and storage_relaxation_offset up, ln J up [M, `P` P6, on dry, episodic, long drought,
  dry-flat]. a09's committed error on dry = −1.22 M + residual rms 0.145: the bias is
  about 80% of its squared error [M, `P` proj.R]. libAG: 0.86 along M, about 70% of
  lib19's [M, `AG` G2].
- **Size on the bank.** a09 committed worst 0.41–0.95ε; with the 12-d inset 0.28–0.55ε,
  rms lower on 9 of 10 (dry 0.94 → 0.34, dry-flat 0.95 → 0.55, dry-p50 0.93 → 0.34,
  episodic 0.76 → 0.28) [M, `LOC` "12-day inset as a pair"]. Moving each edge node 10 d
  inside (in10) cuts dry from 0.94/0.302 to 0.36/0.153 [M, `P` P2].
- **Single-run signal.** None that gives its amplitude. The edges are known from the
  pilot (and from g, not E, under the averaged gate) [M, `AG` gedges.R]. J's adjoint map
  of per-node removal ranks the elasticities' edge cost backwards (removing an edge node
  moves elasticities toward the truth while ln J moves away) [M, `LOC` Round 3 B; `P`
  "Explains"]. An in-run quadrature estimate anti-correlates with the error (−0.45) [M,
  `F` Inversion 5].
- **A priori.** Yes, it is the layout's. The error-free inset depends on the gate and on
  the spacing: lib19 ≈ 12–15 d at the committed spacing and ≈ 11 d at the check's; libAG
  ≈ 9–10 d at the committed spacing, saturating by ~10 d ≈ 0.55 × establishment_window
  [M/I, `AG` need.R]. p(d) along M on dry: 0.25 (3 d), 1 (10 d), 1.68 (36 d) [M, `P` P5].

### A2. Inset strip residual: the same inset in both runs

- **Mechanism.** With a fixed 12-d inset in both runs, the strip between the inset node
  and the edge, read by the gap interval's hat, is identical in c and f, so its error
  shrinks by ~0 and the pair cannot read it [M, `P` task 2; `PRE` E4: ETT did not remove
  it, so it is not jitter].
- **Order.** Zero in the interior spacing; a function of the inset d, not a power law in
  d [M, `P` P5].
- **Where.** The 12-d strips beside each edge before 25.
- **Quantities and direction.** Two groups shrink differently. Hydraulic
  (root_P50, storage_relaxation_offset) f/c 0.6–0.8, read 0.4–0.5 (under-read); leaf
  (a, curv_fact_elec_trans, k_I, jmax_25, lma) f/c 0.21–0.26 against s = 0.42, read
  ×1.3–1.4 (over-read) [M, `P` task 2 diag_ins.R]. Along M c −0.20, f +0.07 under either
  gate once jitter is gone [M, `PRE` E3–E4].
- **Size.** dry-flat root_P50 err −0.40 (lib19), −0.44 (libS), est −0.13/−0.14: C3 5/6
  (lib19, inside the allowance), 5/7 (libS, fail); dry root_P50 −0.29 est −0.13 [M].
- **Single-run signal.** No; shared by construction.
- **A priori.** Yes. The check's inset scaled with its spacing (12/R = 7.5 d): dry-flat
  root_P50 reads 1.17; ten of ten pass, reads 0.83–1.18 [M, `PRE` E5–E6]. What remains is
  a mixed shrink: dry-flat storage_relaxation_offset over-read (err 0.10, est 0.43),
  a_dG2 ×1.98; C3 misses only where allowed (dry 4/5, dry-flat 6/7, dry-p50 3/4) [M].

### A3. Spacing-proportional inset overshoot ("mid")

- **Mechanism.** mid puts each spell's outermost nodes h′/2 inside (one node fewer per
  spell). It overshoots the error-free point along M by 0.46 on dry, and the overshoot
  moves with h [M, `P` P3, P7].
- **Order.** First: −0.46 → −0.32 along M for an open-spacing ratio 1.38 (ratio 1.44)
  [M]. A pair read with a second-order s reads it at about (1 − 0.72)/(1 − 0.42) ≈ 0.5
  (dry: estimate −0.25 for −0.46) [M/I, `P` P8].
- **Where.** Spell ends; case-dependent size.
- **Quantities.** Along M; on episodic-lma a_l1 overshoots +0.32 → −1.24 [M, `P` P9].
- **Size.** Passes dry, episodic, long drought, dry-flat (T −20 to −39%) but fails C3 on
  episodic-lma (a_l1 read 0.40, omega 0.33, storage_relaxation_offset wrong sign −0.16,
  vcmax_25 5.3) [M]. Under libAG mid's committed run is the most accurate (worst 0.30)
  but its check (the mid layout of a09's f, not a refinement of mid c) is worse off M
  than its committed run: C3 0/3, read −0.21 [M, `AG` P_AG1′].
- **Signal.** No.
- **A priori.** Yes: the first-order term is known by construction [ours].

### A4. The founders' window

- **Mechanism.** The founders earn 70–90% of J and fate falls steeply across the window
  [M, `BRIEF 4`]. The error follows the pilot's offspring curve: d ≈ 0.055·g′²·f/J (f
  offspring by birth date, g = ln f), within ×1.3 on dry and lma; the first panel reads
  lower on long-wet and long drought [M, `LOC` "The founders' window"].
- **Order.** Second (ratio ~4.2) [M, `BRIEF 4`].
- **Where.** b < b1, the first-mover layer until offspring falls 10-fold (1.1–2.1 y).
  J's map puts 0.55–0.81 of J's error there on lma ×1.25, long-wet, long drought [M,
  `LOC` "The other three training cases"].
- **Quantities.** lma and leaf traits in the lma case: lma ×1.25 lma elasticity 5.5ε at
  f = 8, 1.45 at 16, 0.49 at 32 [M, `BRIEF 4`].
- **Size.** 14% of T, 16–22 committed nodes [M]. A check that refines the founders by a
  different ratio misreads a founders-only quantity by up to ×1.5 [M scorer]. A late-only
  pair misses up to 0.25ε of founders' error [M scorer, `BRIEF 19`].
- **Signal.** The pilot's offspring curve predicts it; but the pilot has only five
  nodes there and did not separate lma ×1.25 from episodic [M, `BRIEF 10`]. No jitter
  and no tolerance error lives there [M, `PRE` X2, J0–J9].
- **A priori.** Yes; the layer's extent is a local optimum [M scorer]. b1 moves with the
  traits (lma ×1.25: 3.05 → 3.69) [M, `F`].

### A5. Wide intervals off the square law

- **Mechanism.** Late intervals over ~110 d are not on the square law for elasticities;
  their contribution can change sign between levels; 45–80 d intervals are [M, `BRIEF
  1`, root-p50.md]. Late births reach the founders through the soil (W6: thinning after
  b = 10 moved ln J 0.70ε though those births earn almost none of J) [M, `DSB` W6; `GD`
  §16].
- **Order.** None above the cap; second below.
- **Where.** b1–25 background; the field part (water) is what leaves the square law [M,
  `DSB` "What the tests settled"].
- **Quantities.** Late-binding: a_l1, storage_relaxation_offset, root_P50, a,
  curv_fact_elec_trans [M, `BRIEF 5`].
- **Size.** The 10–20 band at ~190 d: moves 0.77–0.91, worst 1.65–1.74 [M, `LOC`
  "Probes outside"]. The widest legal schedule errs 0.94–2.42ε [M scorer, `LOC` "Second
  lateral round"]. Checks against l = 140 read ratios near 1 or the wrong sign [M,
  `BRIEF 13`]. The scorer extrapolates its square law to 280-d intervals after 20, which
  carry 11–38% of its modelled error [I].
- **Signal.** No; the pair misreads it.
- **A priori.** Yes: the range caps (100 d before 20). Only 8–26 of ~110 open intervals
  sit within 10% of the cap [M, `F` anatomy.R].

### A6. A node inside a shut gap next to establishing births

- **Mechanism.** A node born in a shut gap is a full cohort facing the gap's conditions;
  next to establishing births it misrepresents their fate [I, `P` H_out].
- **Order.** First in the displacement [I].
- **Size.** out10 on dry: max 0.42 (stem_c), rms 0.302 → 0.338 [M, `P` P1]; on libAG
  rms 0.225 → 0.400, a_l1 1.23 [M, `AG` G4]. Old trapezium-era form: −11% J for a node on
  the ramp [M, archived].
- **A priori.** Yes: the inset rule puts no node in a gap or in the strip.

### A7. Pre-asymptotic and non-power-law ladders

- **Mechanism.** Before edges were nodes and late spacing was capped, placed ladders
  converged at about first order (episodic pA → pA2 → pA4 median ratio 2.15) and on
  episodic below u429 moves grew with refinement (order −0.38) [M, `DSB`]. Lumped
  uniform nodes are off any power law (negative ratios; invader a_l1 extrapolation off
  0.87–1.1ε); graded nodes' companions under-report by 20–35% under bounded Cash–Karp;
  spread uniform nodes report 0.95–0.98 [M, `GD` §16]. Cause: late spacing of 270–540 d
  and corners in fate at window edges; with edge nodes and late births every 34 d the
  ratio becomes 4.03 and (Q1 − Q2)/3 reads 1.32 against 4/3 [M, `DSB` "Why the error was
  not predictable"]. On long drought uniform nodes make two opposite errors at the
  first-mover layer's top whose difference changes sign with each halving [M, `GEO` §3].
- **A priori.** Yes; it is what the current rule's edges, caps and crown spread remove.
  Crowns swap height order only at ≥ 429 introductions (≤ 1.2 mm), fixed by sorting [M,
  `GD` §16].

## B. Errors that do not shrink with the spacing (shared by both runs)

### B1. Merged short gaps

- **Mechanism.** Spanning a shut gap under 10 d with one interval. Per-recruit fate
  changes only 0.001–0.002 across such gaps [M, `P` gaps.R] and the survival-jump
  hypothesis is refuted (|Δ ln offspring| ≤ 0.03) [M, `PRE` M1]. The record calls the
  remaining cost "not understood" [`LOC` "Where merging costs"]; P attributes merging's
  damage to the edge layer [I, `P`].
- **Order.** Zero: a merge error does not shrink as the spacing refines [I, `LOC`].
- **Where.** Dry's whole move comes from one pair of gaps (5.403, 5.416) that removed
  every edge of a one-day open spell where offspring per founder is 25× its median after
  b1 [M]. The 13 gaps after 10 move ≤ 0.02ε [M].
- **Quantities.** stem_c +0.24, TF24_cost_scale +0.17, both away from the reference
  (dry worst 0.97 → 1.03, a C1 breach on the probe) [M, `PRE` M1].
- **Size.** Merge all: dry 0.24ε, dry-flat 0.12ε, long drought 0.02ε; a spell keeps its
  start edge (SPELLS=1): 0.10, 0.04, 0.03ε for 11–24% of rows [M]. After b = 10 only
  (a10): ≤ 0.06ε on nine cases [M, `LOC` Round 3 real runs].
- **Signal.** No. A check that keeps the edges reads it at shrink 0 [I].
- **A priori.** Yes: merge only after 10 and only in the committed run, or not at all.

### B2. Late edges dropped; an interval across an edge

- **Mechanism.** Leaving edges out of both runs is shared error at shrink 0 [M, `LOC`
  Round 3 A]. The record states "an interval across an edge interpolates its counted
  cohorts from a node in the shut gap, a first-order error" [I, `LOC` "Probes outside"],
  which agent P later contradicts for edges alone (see Open questions).
- **Size.** Edges after 20 dropped: 10–14 quantities move > 0.1ε, max 0.27–0.34ε, rms
  error 0.31 → 0.33 (dry), 0.19 → 0.22 (episodic) [M]. After 25: ≤ 0.08ε, 6.5–10% of rows
  saved; after 30, nothing [M, `LOC` a04 at 1e-4].
- **A priori.** Yes: keep the 20–25 band; it is where 20–25 edges matter.

### B3. Constant-rain fate front

A front in survival ~0.01 d wide where neighbours split into canopy and understory;
converges by the square law with nodes every 1/512 d; the old reference is biased ~13ε;
the invader's elasticities 6–17ε off on placed grids [M, `DSB`; `BRIEF 7`]. Not in the
ten-case bank, though OBJECTIVES' bank includes constant rain. A pilot finds it [I,
`GEO` §1].

## C. Estimator errors: the pair misreads

The pair's estimate move/(1 − s) is honest only where the check shrinks every interval
carrying error by about one factor (`CTX` "Settled"; lesson 15 at the scale of one
record).

### C1. Uneven shrink; the proxy misplaces the error

- **Mechanism.** a04's ratio check (×1.6) leaves short spells between edges at one
  interval, so the background shrinks less than the founders: band shrinks 0.41 before
  b1, 0.59 to 10, 0.53 to 20, 0.33 after (dry-flat; 312 edges); 0.37–0.54 everywhere on
  dry, long-wet, episodic [M, `LOC` "Root cause: a04's check"]. The proxy puts 85% of
  dry-flat's committed error before b1, where a four-run fit puts ~25% (residual
  0.012ε) [M].
- **Size.** Real shrink 0.51–0.87 against the proxy's 0.433; median read 0.69,
  storage_relaxation_offset 0.41: C2 and C3 fail [M].
- **Signal.** The band shrinks are computable from the two schedules; where the error
  sits is not [ours].
- **A priori.** Yes: a05 bisects every wide interval the ratio leaves alone (band shrinks
  0.40–0.44, read 0.85, 12/12) [M]. "A spacing proxy cannot locate the error; it can only
  be made not to matter" [`DSB` "Where it landed"].

### C2. Sign-mixed error across regions

- **Mechanism.** Elasticity errors are sums of contributions of both signs that cancel
  about four-fold (magnitudes ~1.5ε, total 0.35ε) [M, `BRIEF 2`]. storage_relaxation_offset,
  a_l1 and stem_c carry opposite-sign error before and after b1 (storage −1.9 and +1.1)
  [M, `LOC` a04 root cause].
- **Size.** No single s reads them: s taken as the largest band shrink lifts the median
  read to 0.96 and passes C2 but C3 stays 7/10 [M]. A ratio per region gives estimate/error
  0.03–2.34 [M scorer]. J's error cannot carry an elasticity's remainder (per-band factors
  differ in sign by quantity) [M scorer]. A map-based check passes the scorer only because
  the scorer cannot see sign-mixed error inside a band; its real counterpart read 0.55 on
  episodic [M, `LOC` Round 3 C].
- **A priori.** Only through C1's remedy (every region shrinks alike).

### C3. A check laid out across merged spans

- **Mechanism.** Built on merged spans, the check refines less of some quantities' error
  per node than its spacing says; the proxy, seeing only spacing, cannot tell [I, `PRE`
  a08]. Consistent with error rising toward closing edges, not tested directly [S].
- **Size.** a07 long drought reads 0.65 (every top quantity shrinks ~0.6 against the
  proxy's 0.425); a08 0.66; a06's check takes a_l1 0.51 → 0.23, a08's 0.53 → 0.34 with as
  many nodes per band [M]. a08 dry fails C2 (root_P50 err 0.51, est 0.20); a07 escapes at
  err 0.47, est ~0.15 [M]. a09 (no merging) reads long drought 1.12 [M].
- **A priori.** Yes: no merging before the build.

### C4. A check built, then trimmed

a06 trimmed both finished schedules: the check's ratio and fill nodes stood for gaps
that no longer existed; band shrinks spread again (0.41–0.51 flat on dry-flat); C2 fails
(stem_c err 0.51, est 0.23) although trimming moved stem_c only +0.05 [M, `PRE` a07].
Fixed by trimming the pilot first (a07) [M].

### C5. A partial check

- a11 (check unrefined after 25): the whole-range proxy credits the unrefined late region
  with error, s rises 0.335 → 0.509 and episodic commits fine (T 874 against 720); fixed
  by reading s before 25 only [M, `PRE` a11]. Where a case commits fine its late error is
  kept (episodic-lma worst 0.41 → 0.69) [M].
- A late-only pair cannot see the founders' error (≤ 0.25ε) [M scorer, `BRIEF 19`];
  bisecting the top 80% of proxy error misses lma's late storage_relaxation_offset error
  (0/5) [M scorer, `LOC` Round 3 C].

### C6. Jitter amplified by 1/(1 − s)

- **Mechanism.** Each run carries its own step-sequence jitter (D1–D3). A non-nested pair
  shares none of it and the estimate carries the difference at 1/(1 − s) [M, `BRIEF 15`].
- **Size.** Real runs deviate from smooth fits by rms 0.04ε, one quantity in twenty near
  0.25ε [M, `BRIEF 15`]; the small diagonal step (22, 70)/(26, 59) failed C3 on episodic
  (root_P50 est −0.59, err +0.36) [M]. R = 1.4 fails 21 of 40 draws; R = 1.5, 1.4 pass 4/5
  [M scorer]. At 3e-4 the two runs' step sequences share nothing [M, `PRE` "shared
  cause"].
- **A priori.** Partly: a larger ratio divides the jitter; a nested check passes dry
  under both failing conditions but costs T 1195–1431 against 962–1220 and "reads nothing
  of the jitter" [M, `LOC` "The pair's misreads"]. Removing the jitter at source (D1, D2)
  is the fix the record chose.

### C7. The commit gate and C3's small samples

- The decision is discontinuous at ε: a07 episodic a_l1 coarse err 0.85, est 1.004 →
  commits fine (+26% T) [M]; c5t dry coarse err 0.97 → the move tipped 4/3 of it past ε,
  commits fine [M, `PRE` K2].
- A fine commit reads its estimate s/(1 − s)·d, so a shift at shrink 0 in the committed
  run lands in the fine run's read: dry with thinned committed run commits fine and fails
  C3 1/4 (stem_c +0.21–0.24) [M, `B3` X2]. A thinned committed run that commits coarse
  fails C1 (a_l1 1.01/1.00 against 0.97 unthinned) [M, `B3` X3].
- With few quantities over ε/3, one jitter miss fails C3: "commit the finer run fails C3"
  (2–4 quantities over ε/3) [M scorer]; mg5.5–5.7 C2 on storage_relaxation_offset (est
  0.243 against 0.25) [M, `B3`]. Over-reads count as C3 failures although safe [M].

## D. Derivative time-stepping error: does not shrink with node spacing

### D1. The leaves' arm switch inside a step (sharp gate)

- **Mechanism.** As the soil dries every resident's leaf moves from an Interior optimum to
  BoundaryCrit (psi_stem at psi_crit): on dry 48 of 56 nodes switch within 0.44 d
  (9.70296–9.70417), 0.7 d before the seedling's gate shuts [M, `JT` kink.R]. Net
  production (the optimised profit) stays smooth in θ; transpiration (the argmax) kinks,
  so the soil's rate sensitivity to TF24_cost_scale steps 0.0159 → 0 [M]. RKCK integrates
  the derivative's jump inside one 1.5–5-d step with error h·ΔG·φ(u), φ ∈ [−0.2, 0.2] set
  by where the stages fall; the forward's kink costs O(h²) [M/I, `JT` part 4]. The
  derivatives are exact for the discrete map (central differences on each run's steps
  match to 0.006–0.010ε while the two runs differ by 0.176ε) [M, `PRE` J15]. The total
  sensitivity's soil rows predict A − B = −0.173ε against −0.176 [M, `JT` H2].
- **Order.** Zero in node spacing; O(h) in step length, random in φ. Halving every
  interval leaves rms 0.057 unreached on the sharp gate (its jitter level) [M, `PRE` N6].
- **Where.** Drydowns ending at closing edges, b 3.5–17: none before 3.5, 16% in 3.5–5,
  9% in 6.7–8.25, 34% in 9.68–10.04 (30% in the 27 dry days 9.678–9.753 around the edge at
  9.711 after a 322-d spell), 38% in 10.04–17, none after 17 [M, `PRE` J0–J14]. Every
  drydown after 3.5 has a cluster; the soil adjoint's weight decides which show (spread
  in log10: λ_soil 1.22, φ 0.86, h 0.62, ΔG 0.47); after 25 λ_soil ≈ 0.004 [M, `JT`].
- **Quantities.** One direction across gates, layouts and tolerances (cosines 0.81–0.97):
  TF24_cost_scale, stem_c, a_l1, R_d_25 against root_P50, a_r1, a, curv_fact_elec_trans
  — the Interior / BoundaryCrit trait divide [M]. ln J moves ~3e-5ε [M].
- **Size.** ±5% tolerance nudge: rms 0.02–0.03 at 1e-4 [M, Round 3 A]; 0.048 at 3e-4
  (TF24_cost_scale 0.18ε), 2.7× the whole 1e-4 → 3e-4 change [M, `PRE` X1].
- **Single-run signal.** Yes. f_hi (the collar solve's marginal profit at the dry end) is
  computed on every solve, smooth through the switch, and its sign changes locate every
  switch (56/56 within ≤ 5 min) [M, `JT` S1]. The a-priori bound
  (θ/J/ε)·|λ_soil|·h·|ΔG|·0.2 ranks A's switch steps so the top 30 hold 90% of Σ|c| [M,
  `JT` part 4]; it needs the run's own sweep.
- **A priori.** Yes, in the stepper, not the schedule: a stop at the switch (nudge rms
  0.0020, +12.8% rows; on steps > 0.5 d 0.0081, +7.1%) or a split of the soil at the first
  and last switch (0.010, +8.5% evaluations, no extra rows) or ETT (0.025, +8.6% rows) [M,
  `JT` parts 2–3; `PRE` E1]. Splitting the switching node alone does nothing (0.044) [M].
  The record's verdict: "What a schedule controls (node spacing) is gate-robust already"
  [`LOC` "The pair's misreads"].

### D2. The averaged gate's knee in dE/dt (libAG only)

- **Mechanism.** Under the averaged gate the seedling gate's sensitivity g′(P)·∂P, a bump
  2–3 d wide before P = 0, enters the state E that seeds every newborn; 1.5–5-d steps
  sample it unresolved [I/M, `JT` S2, S4].
- **Size.** Nudge rms 0.110 at 1e-4 (TF24_cost_scale 0.42), 4× the sharp gate [M, `PRE`
  J11]. Halving made TF24_cost_scale 0.21 → 0.50 and storage −0.18 → −0.31 [M]. The arm stop
  leaves 0.095; cutting the gate's derivative too leaves 0.0285 (~70% is the gate) [M,
  `JT` S2, S4]. ETT gives 0.009 at +11.5% rows [M, `PRE` E2]. It failed every dry pair
  under the gate (a09 C3 5/8, inset 2/9, a09 + gap check 5/8) [M, `AG`]; with ETT a09
  passes 14/14 (read 1.04) and the inset 4/5 (read 1.36) [M, `PRE` E3].
- **Signal / a priori.** No sign change marks it; ETT (tolerance ×0.1 within 15 d of
  closing edges, known from the pilot) designs it out [M].

### D3. Tolerance error landing unevenly in the pair

- **Mechanism.** Tolerance error is flat to 1e-4 (≤ 0.06ε bias, the same in both runs),
  starts between 1e-4 and 3e-4 and lies along one hydraulic direction (stem_c,
  TF24_cost_scale, storage_relaxation_offset) at 0.17–0.35ε on dry and lma; it is not a
  power law and no s reads it [M, `LOC` Round 3 A]. Agent X showed the 3e-4 moves are
  jitter (D1), not a smooth function of tolerance [M, `PRE` X1].
- **Size.** a09 at 3e-4, legacy setting, ld-102: a_l1 read 0.14 against 0.42,
  TF24_cost_scale −0.42 against −0.11, C3 2/4 — gone in the proper setting [M, `PRE` F2].
  Inset at 3e-4 on dry: check moves rms 0.043 against committed 0.018 (a_l1 +0.06 → −0.13),
  leaf reads rise ×1.45–2.85, C3 6/10; dry-p50 4/5 [M, `P` task 3]. a09's own dry pair at
  3e-4 has unevenness rms 0.060 and survives by committing fine [M]. ATOL 1e-2: the check
  moves 0.38ε (stem_c) against 0.11ε committed, C3 at its limit 8/10 [M, `E`].
- **A priori.** Via D1/D2: the arm stop cuts the 3e-4 nudge 24× [M]; the stop at 3e-4 has
  not been run as a pair [S].

### D4. Net-production crossings

Kinks where a member's net production changes sign; a step straddling one loses order
and the gradient staircases on a frozen mesh; crossings were 70–85% of the gradients'
spread under nudges before events/splits, which cut it 3.4–6.4× [M, `GEO` §3; `GD`
§11]. Splits cut a ±5% nudge's jitter 3–6× (rms 0.02–0.04 against 0.08–0.13); long drought
in the legacy setting moved 0.24–0.52ε under nudges [M, `LOC` Round 3 A; `PRE` a10].
Storage reads net production through a positive part smoothed at 1e-4 where net
production is ~1e-2, a corner the existing split resolves [M, `JT` part 4]. Designed out
by the splits setting.

## E. Forcing and ODE discretisation

### E1. Rain knots aliased by the stages

- **Mechanism.** Rain is a floored cubic through daily values; a step across knots
  samples it at six stages, both embedded orders miss a one-day bump alike, so the error
  estimate is blind [M, `G` §4]. Knot-ending steps were 46–53% of steps and 47–56% of rows
  on rain-frequent records [M].
- **Size.** No knots at 1e-4: J 1.191 → 0.984 (7.6ε in ln J, up to 19ε in elasticities);
  1e-5 recovers 42% (error ∝ tol^0.24) [M, `E` E2, E4]. Late knots only: TF24_cost_scale
  0.73ε, root_P50 0.47 → 0.98; tightening the late tolerance ×10 made it worse (1.52ε,
  ln J −0.40ε) [M, `G` G1–G2]. The stops lived only in the harness: any TF24 run without
  them was silently ~17% off in J on dry [M, `E`].
- **Signal.** Yes: Σ|RK5 − exact| of the rain over the run's integration intervals, free
  from the accepted steps [M, `G`, `R` gate.R].
- **A priori.** Landed: plant#111, every knot-spanning step substeps the soil; moves
  ≤ 0.23ε, gate 1e-11, rows −10 to −27% [M, `S`]. Residues: the water-balance sums are
  main-step states and miss −3.1% of rain on dry [M, `S`]; a stiff store that passes a
  pulse as a spike narrower than a step is still missed (toy 4.2e-3 unchanged) [M, `R`];
  on a young stand at tight tolerance the free run needs more steps at matched error [M,
  `R`].

### E2. Stiff top soil under explicit steps

- **Mechanism.** Heavy rain on a near-saturated top layer gives ∂rate₁/∂θ₁ ≈ −1e4 to
  −3.6e4 /yr; RKCK is unstable past h·μ < −3.73 and the controller rides that limit, so
  the top layer chatters and the forward map is transiently chaotic (a 1e-10 trait change
  grows ×1e10 in 0.015 y); J survives because the forward saturates and forgets, but the
  exact derivative of that map is a product of per-step factors up to 1e8–1e10 [M, `D`
  E1–E12].
- **Order.** Zero in nodes; heavy-tailed in the realised step sizes, i.e. in schedule and
  tolerance (n1 at 1.05e-4 blew up, n2 at 0.95e-4 did not) [M].
- **Where.** A rain pulse at t ≈ 37.05–37.08 on long drought, injected into θ₁ and
  propagated back [M].
- **Quantities.** One trait direction v (omega, theta, a_bio, storage_relaxation_offset,
  a_r1, curv_fact_colim), correlation 0.988–0.9996 [M].
- **Size.** 2 gross blow-ups of 62 saved long-drought runs (elasticities to 2186; 33ε),
  1 mild (~0.5ε off neighbours); sub-ε contamination "likely more common and invisible"
  [M/S, `D` freq.R]. Silent: no refusal recorded.
- **Signal.** Yes: max h·stiffness over accepted steps; a directional difference along
  the reported gradient on one pinned forward (sane 1.0003–1.0005, n1 1.103, a10s 70.7;
  blind to error orthogonal to it); the soil adjoint's growth over 0.01 y [M, `D` guard].
- **A priori.** Yes: the soil's own substeps (SHARE = 0.1, the proper setting) cure it and
  halve long drought's CPU [M, `PRE` "soil's own substeps"]; D's cap at 3/stiffness (+5%
  steps) is in reserve for stiff steps the substeps do not take [M].

### E3. The loosened late tolerance

With knots, capping the late weight at 10 instead of 100 moves nothing (≤ 0.003ε) [M,
`G` G3], so the references' late setting is converged; without knots the late tolerance
interacts with E1. A weight frees stages as well as errors: soil ×10 times the window's
100 let accepted steps put a soil stage at the 1000 MPa ceiling, where the root curve's
derivative was refused [M, `GEO` §3].

## F. The derivative refuses where the forward answers

- **Root curve past its dry end.** The forward caps the root integral past 7.31 MPa; the
  derivative path had no cap and refused past P99 (6.89 MPa). The dry evaluations are
  stages inside accepted steps (no recorded state passes 5.17 MPa); replaying 1e-4's
  steps at 3e-5 refuses, 3e-5's at 1e-4 passes; the cap binds 2189 times on 1e-4's steps
  and never on 3e-5's [M, `LOC` "Root cause: long drought's sweep"]. Hit a04 at 1e-4
  on long drought and ld-105 (both runs) and episodic at 3e-4 (NaN). Fixed in phylloptim
  0.9.2 [M].
- **Determined collar.** At 3e-4 a stage reaches a collapsed collar interval; the forward
  sets the midpoint, the derivative had no case: every long-drought record refused. Fixed
  in 0.9.3 [M, `PRE` a09 at 3e-4]. The forward itself has a ×8 transpiration step across
  5e-5 MPa there (phylloptim#20); it did not show as a C1 failure [M, `PRE` H19-3].
- **Order / where / signal.** Not in spacing; decided by which step sequence lands a
  stage past the domain ("nothing in the model guarantees that at any tolerance"). Not
  silent: the run throws.
- **A priori.** Yes: differentiate what the forward evaluates; bound every weight and
  check stages against the domain [`GEO` §3].

## G. Case- and θ-dependent modes

### G1. The error moves with θ: a grid's radius

- **Mechanism.** Grid placement transfers: dry-p50 on dry's grid lands within 0.07ε of its
  own grid although none of its 102 edges before 25 is a node [M, `F` U1]. The error does
  not: it grows lopsidedly with lma (rms ×1.16 at ×1.1, ×1.29 at ×0.9, ×4.1 at ×1.25) [M].
- **Size.** θ₀'s estimate misreads θ₁'s error by 0.23–0.56ε at lma ±10%; episodic at lma
  ×0.9 on its committed grid errs 1.34ε on a_l1 where the find reported 0.85 (C1); the
  use's own pair would read 1.28 [M, `F`]. dry-p50 → dry: storage_relaxation_offset
  −0.31 → −0.53, θ₀'s estimate ~0, C2 fails in all seven designs [M, `LOC` Round 3 C].
  Across weather seeds the estimate does not transfer (reads −0.03 to 0.96) [M, `F`].
- **Signal.** Yes: |ln J(θ) − ln J(θ₀)|: holds at 0.19, misreads at 0.73–1.11, fails at
  4.15 [M, `F`]; built into diagnose_scm (`grid_distance`, d* = 0.5) [M, `U`]. The pilot
  flags lma ×1.25 (J ×0.016, proxy ×0.06) [M].
- **A priori.** No; a property of the case. Repairs: commit fine for the analysis (+16% T,
  passes at every radius point tested) or a commit margin (+5.0–6.5%) [M, `F`]. Tested on
  lma and root_P50 on two records; invaders untested.

### G2. A trait at a model kink

rooting_depth_max = 1.5 m, the soil column's depth; rooting depth is min(height, cap), so
θ₀ sits on a kink. The local slope falls 0.035 → 0.0125 over u = −1.5% → +1.5%; the
elasticity moves 0.3ε per 1% of the trait; 3 of 84 panels hold half its map; G0 +0.48
against lattice −0.02 [M, `LOC` "rooting_depth_max"]. Set aside, as recruitment_decay is.
Not designable by the schedule; a model question.

### G3. Large trait moves; episodic-lma's committed error

a09 commits fine on episodic-lma under both gates (committed worst 1.29 lib19, 1.40
libAG); its error "is not the edge term" (the inset's committed run errs 1.24 too) [M,
`AG`]. The scorer missed lma's committed run by 0.31 rms (max 0.57) [M, `LOC` c05 real
runs]. Mechanism unidentified; the founders' window (A4) is the record's candidate [S].

### G4. Library and gate changes move the answer

The averaged gate moves u429 by up to 2.6ε (root_P50), ln J +0.73ε: lib19 references
cannot score libAG runs [M, `AG` G0]. Edges must come from g: thresholding E finds 10 of
96 dry edges, inverting E per step finds all 96 [M, `AG` gedges.R].

## H. The references' own error

Held-out references extrapolate u215 → u429 with own estimates 0.10–0.24ε [M, `LOC` c05
real runs]; libAG references: dry 0.13ε (u857 confirms within 0.10 along M), long drought
0.14ε, episodic-lma 0.32ε [M, `AG`]. Long drought's splits reference agrees with the
no-splits one to 0.04ε (ld-102 0.031, ld-105 0.087) [M, `PRE` R1]. Errors under ~0.3ε on
episodic-lma are within the reference's error.

## Facts about predictability already in the record

**Measured orders.**
- Uniform spread ladders: ratio 3.72–4.42 (long-wet), 3.32–3.98 (long drought); companion
  0.95/0.98 [M, `GD` §16]. Graded ladders 2.76–3.26, companion 0.71/0.80 [M].
- Edge-aligned grids: ratios 3.7–4.2, estimate 1.23–1.32 against 4/3 [M, `DSB`].
- a09 committed → halved: 3.47× rms (sharp; 4 at second order), along M 2.18 for spacing
  ratio 1.38 [M]. Averaged gate: 1.39 raw, 1.88 with ETT; quartered converges to rms
  0.044 [M].
- Founders' window ~4.2 [M]. mid's overshoot first order (1.44 for 1.38) [M].
- G0 → G1 bisection: 4/3 of the move against G0's error, median 0.92–1.18; 108 of 113
  quantities over ε/3 within ×2, right sign [M, `LOC`].
- Tolerance: not a power law above 1e-4 (hydraulic direction) [M]; knot-free runs
  error ∝ tol^0.24 [M].

**The shrink s.** The pilot proxy's offspring^0.6·h³ shrink between the two schedules:
a09 0.33–0.42 [M, `P`]. Real shrinks: a04 on dry-flat 0.51–0.87 against 0.433 [M]; a05
0.46–0.70 [M]; c05_graded's nested check 0.19–0.39 against 0.25 [M]; a07 long drought
~0.6 against 0.425 [M]. Under the inset the read is not one shrink: leaf f/c 0.21–0.26,
hydraulic 0.6–0.8, against s = 0.42 [M].

**Reads.** Median estimate/error: c05_graded 0.82–1.11; a09 0.87–1.17; a05 0.85–1.21;
c5t 0.92–1.28; E6 rule 0.83–1.18 [M]. Extrapolating the pair, c − d/(1 − s), leaves worst
0.03–0.36ε against the coarse 0.43–1.29 — three times more accurate than either run [M,
`F` P3]. The scorer predicted c05_graded's real errors within 0.02–0.07ε rms (except lma,
0.31) [M]. a09's estimate correlates with its error 0.95–0.99; mid's 0.73–0.97 [M, `P`].

**Where the error concentrates.**
- The intervals before a closing edge carry most of the node error along M (classes add:
  sums +1.09 and +0.43 against the halvings' +1.28 and +0.49) [M, `PRE` L1, N6].
- About 80% of a09's committed squared error on dry is the edge bias [M].
- The check's added nodes Δ are 7.9% of T, 55–68% of them between b1 and 25, where 56–88%
  of the error is [M scorer, `LOC` Round 3 C].
- J's map puts 0.55–0.81 of J's error in the founders' window on three cases [M]; but
  ln J never binds (worst 0.37–0.39ε) [M].
- Each case's error is one shape: across 28–73 schedules the first singular direction
  carries 78–99% of the signed error, two carry 95–100%; two shapes recur (a light
  group: a, curv_fact_elec_trans, k_I, jmax_25; and a_l1); the same quantity binds in
  ≥ 90% of a case's runs; 11 of 47 quantities never exceed ε/3 [M, `G` §2].
- The derivative's jitter concentrates at closing edges after drydowns, weighted by the
  soil adjoint [M].

**Cost facts that bound a cheaper guarantee.** Edges are 37–88% of committed nodes and
carry 44–64% of the committed run's rows [M]; the committed schedule run three times is
66–70% of T and the check 30–34% [M]; every inversion that removed or cheapened the check
failed to give an honest elasticity estimate (uses as the check, an in-run estimate,
seeds, a pilot as the check, J's map) [M, `F`; `LOC` "Other algorithm families"].

## Reading for the user's argument [ours]

Modes that are the layout's or the estimator's (A1–A7, B1–B2, C1–C5) are fixed once the
rule is fixed: their size depends on the case, but their order, location and direction
are set by the algorithm, and each one the record found was designed out by changing the
rule, not by reading a run. The modes that are not are D1–D3 (step-sequence jitter, random
in φ; designable in the stepper and then bounded), E2 (heavy-tailed, cured by setting),
F (throws), and G1–G3 (the case and θ). D1 is the only random mode that touches the
pair's read at the current setting, and the record measured its residual after a stop
(rms 0.002–0.010). G1 is the one mode a check at θ₀ cannot cover at all, and the only one
with a cheap single-run signal already built.

## Appendix: every logged criterion failure, refusal, NaN and mis-commit

Mis-commit: coarse committed with error over ε, or fine committed when coarse sufficed.

| rule | case | tol | lib | event | quantities and numbers | mode | strength | source | fixed by |
|---|---|---|---|---|---|---|---|---|---|
| a04_proxy | long drought | 1e-4 | pre-0.9.2 | C4, both sweeps refused | root curve, x = 256 (31 MPa) | F | M | LOC root cause | phylloptim 0.9.2 |
| a04_proxy | ld-105 | 1e-4 | pre-0.9.2 | C4, refused | (ψ/b)^c = 5783 | F | M | LOC all ten | 0.9.2 |
| c05 probe | episodic | 3e-4 | pre-0.9.2 | NaN elasticities | (ψ/b)^c = 9.9 | F | M | LOC 3e-4 reopened | 0.9.2 |
| a04_proxy | dry-flat | 1e-4 | lib18 | C2, C3 | read 0.69; storage 0.41; real s 0.51–0.87 vs 0.433 | C1, C2 | M | LOC a04 root cause | a05 fill |
| a04, max-band s | dry-flat | 1e-4 | lib18 | C3 7/10 | opposite-sign storage, a_l1, stem_c | C2 | M | LOC a04 root cause | a05 |
| merge G = 10 probe | dry | 1e-4 | lib18 | worst 0.97 → 1.03 (C1 breach) | stem_c +0.24, TF24_cost_scale +0.17 | B1 | M | PRE M1 | SPELLS=1 / no merge |
| a06 | dry-flat | 1e-4 | lib18 | C2 | stem_c err 0.51, est 0.23 | C4 | M | LOC a06 | a07 |
| a07 | episodic | 1e-4 | lib18 | mis-commit fine | a_l1 coarse 0.85, est 1.004; T +26% | C7 | M | LOC a07 | — |
| a07 | long drought | 1e-4 | lib18 | pass, read 0.65 | shrink ~0.6 vs 0.425 | C3 | M | LOC a07 | a09 |
| a07 | dry | 1e-4 | lib18 | near C2 | root_P50 err 0.47, est ~0.15 | C3 | M | PRE a08 | a09 |
| a08 | dry | 1e-4 | lib18 | C2 | root_P50 err 0.51, est 0.20 | C3 | M | LOC a08 | a09 |
| c5t | dry | 1e-4 | lib18 | mis-commit fine | coarse 0.97; 4/3 move > ε | C7 | M | PRE K2 | — |
| B thinned (mg10, mk10) | dry | 1e-4 | lib18 | C3 1/4, committed fine | shift stem_c +0.21–0.24 carried by s/(1 − s)·d | C7, B1 | M | B3 X2 | not adopted |
| B thinned (mgs10, mgt10) | dry | 1e-4 | lib18 | C1, mis-commit coarse | a_l1 1.01 / 1.00 | B1, C7 | M | B3 X3 | not adopted |
| B (mg5.5–5.7) | dry | 1e-4 | lib18 | C2 | storage est 0.243 vs 0.25 | C7 | M | B3 | — |
| a09 | long drought, ld-102, ld-105 | 3e-4 | lib18 | refused / NaN | determined collar | F | M | PRE a09 at 3e-4 | phylloptim 0.9.3 |
| a09 | ld-102 | 3e-4 | lib19, legacy | C3 2/4 | a_l1 read 0.14 vs 0.42; TF24_cost_scale −0.42 vs −0.11 | D3, D4 | M | PRE a09 at 3e-4 | proper setting (F2) |
| a09, a10 | dry | 3e-4 | lib19 | commit fine (T +2%) | uneven tolerance error rms 0.060 inflates estimate | D3, C7 | I | P task 3 | — |
| a10 | long drought | 1e-4 | lib19, legacy | C3 3/5, read 1.62; 0.54ε off | TF24_cost_scale −0.54, a_l1 −0.50 | E2 | M | PRE a10 | SHARE 0.1 + splits |
| a10 n1 nudge | long drought | 1.05e-4 | lib18/19, legacy | silent blow-up | 41 of 46 elasticities > ε, up to 33ε | E2 | M | PRE N1, D | SHARE 0.1 |
| a10s | long drought | 1e-4 | lib19, splits, no SHARE | silent blow-up | elasticities to 2186 | E2 | M | PRE R2, D | SHARE 0.1 |
| a11, whole-range shrink | episodic | 1e-4 | lib18 | mis-commit fine | s 0.335 → 0.509; T 874 vs 720 | C5 | M | PRE a11 | shrink before 25 |
| a11 | episodic-lma | 1e-4 | lib18 | committed fine keeps late error | worst 0.41 → 0.69 | C5 | M | LOC Round 3 real runs | — |
| mid pair | episodic-lma | 1e-4 | lib19 | C3 | a_l1 0.40, omega 0.33, storage wrong sign, vcmax_25 5.3 | A3 | M | P P9 | not adopted |
| out10 | dry | 1e-4 | lib19 / libAG | worse | stem_c +0.42; rms 0.338 / 0.400 | A6 | M | P P1, AG G4 | rule |
| inset 12 d pair | dry (dry-p50 4/5) | 3e-4 | lib19 | C3 6/10 | leaf reads ×1.45–2.85; check rms 0.043 vs 0.018 | D1, D3, A2 | M | P task 3 | arm stop (nudge only) |
| a09 c | dry | 1e-4 | lib19 | ATOL 1e-2: C3 8/10 at limit | check stem_c 0.377ε | D3 | M | E | not adopted |
| no knot stops | dry | 1e-4 | lib19 | J −7.6ε, elasticities to 19ε | a_l1, TF24_cost_scale 18ε, a_dG2 −12ε | E1 | M | E E2 | plant#111 |
| knots before 25 only | dry | 1e-4 | lib18/19 | moves to 0.73ε | TF24_cost_scale −0.73, root_P50 → 0.98 | E1 | M | G G1, E E3 | plant#111 |
| late weight ×10, no late knots | dry | 1e-4 | lib18 | moves to 1.52ε | ln J −0.40ε, a_r1 +1.20 | E1 | M | G G2 | plant#111 |
| a09 pair | dry | 1e-4 | libAG | C3 5/8 | a_dG1, a_dG2, root_P50; M shrink 1.39 | D2 (+A1) | M | AG R3 | ETT (E3) |
| a09 + gap-bisected check | dry | 1e-4 | libAG | C3 5/8 | a_l1, a_dG1, root_P50 | D2 | M | AG T1 | ETT |
| inset 12 d pair | dry | 1e-4 | libAG | C3 2/9 (C2 too on u857 ref) | over-read ×~2 along M | D2, A2 | M | AG R1/R2 | ETT (E3) |
| mid pair | dry | 1e-4 | libAG | C3 0/3 | read −0.21; check worse off M | A3, D2 | M | AG P_AG1′ | — |
| arm stop | dry | 1e-4 | libAG | nudge bar missed | 0.095 vs ≤ 0.03 | D2 | M | JT S2 | ETT |
| inset 12 d pair | dry-flat | 1e-4 | libS | C3 5/7 | root_P50 err −0.44 est −0.14; a_dG2 0.19 est 0.40 | A2 | M | PRE K2–K3 | check inset 12/R (E6) |
| inset + ETT | dry-flat | 1e-4 | libS | C3 5/7 | root_P50 read 0.50 | A2 | M | PRE E4 | E6 |
| θ₀ estimate for a use | episodic, lma ×0.9 | 1e-4 | lib19 | C1 (use), C1/C3 (read) | a_l1 1.34ε vs reported 0.85 | G1 | M | F F_ref_l09 | commit fine (+16%) |
| θ₀ estimate for a use | dry, lma ×0.9; episodic lma ×1.1 | 1e-4 | lib19 | C2, C3 / C3 | misread 0.56ε; a, curv_fact, k_I double | G1 | M | F | — |
| θ₀ estimate for θ₁ | dry-p50 → dry, all seven designs; lma ×1.25 both ways | 1e-4 | lib18 | C2 | storage −0.31 → −0.53 | G1 | M | LOC Round 3 C | — |
| (22, 70)/(26, 59) pair | episodic | not recorded | earlier | C3 | root_P50 est −0.59, err +0.36 | C6 | M | BRIEF 15 | larger ratio |
| c05 probe, 10–20 at ~190 d | dry, episodic | 3e-5 | pre-0.9.2 | C1 breach (probe) | worst 1.74, 1.65 | A5 | M | LOC probes | range cap |
| c05 committed | lma ×1.25 | 3e-5 | pre-0.9.2 | scorer miss (R3) | 0.31 rms, max 0.57 | A4, G3 | M | LOC c05 real | — |
| G0 (map) | dry, episodic | 3e-5 | pre-0.9.2 | rooting_depth_max off | +0.48, +0.39 vs ~0 on lattice | G2 | M | LOC rooting_depth_max | set aside |
| default d108 | long drought, episodic, constant | 3e-5 | earlier | C1 | 4.8ε, 12.3ε, 115ε (invader) | A7, B3 | M | DSB | edges, caps |
| lumped uniform ladder | long-wet, long drought | 3e-5 | earlier | no power law | invader a_l1 0.87–1.1ε | A7 | M | GD §16 | crown spread |

## Open questions: where the record is silent or contradicts itself

1. **An edge inside an interval.** `LOC` "Probes outside" says an interval across an edge
   interpolates from a node in the shut gap, "a first-order error even where little is
   earned"; P says an edge inside an interval costs nothing by itself and the node at the
   edge is the error. The late-edge result (20–25 moved 0.27–0.34ε, after 25 ≤ 0.08ε)
   predates P and was not re-read under P's mechanism.
2. **The averaged gate's edge term.** AG concludes the edge bias converges at first order
   there and that a fixed inset's correction does not shrink (need 1.28/0.92, delivered
   1.38/1.38); X's L2 and E3 attribute both to jitter. The need table was not remeasured
   with ETT, and no in3/in5 ran on libAG.
3. **Why merging dry's one-day spell costs 0.24ε** is "not understood" in LOC; P's edge
   layer is offered as the explanation but not tested on that pair.
4. **The merged-span under-read** (a07 long drought 0.65, "the signature of a first-order
   part") is "consistent with error rising toward each spell's closing edge, not yet
   tested directly".
5. **Which switch clusters jitter.** JT's weight model reproduces the large windows but
   misses 3.5–5 (2% predicted vs 16%) and gets 6.7–8.25 the wrong sign; measured in
   9.6–9.8 only.
6. **The residual after the soil split** (0.01–0.02) is unexplained beyond "what the soil
   split does not reach" (68 steps whose soil was substepped are not split).
7. **No pair has run with the arm stop or soil split**, at 1e-4 or 3e-4; the stop's
   benefit is measured on nudges of committed runs only. The E6 rule at 3e-4 is not run.
8. **Episodic-lma's committed error** (worst 1.29–1.40, why a09 commits fine there) has no
   identified mechanism.
9. **Invaders** are untested throughout the schedule search (checked only in earlier
   records); the inset, the jitter and the radius are resident-only measurements.
10. **The radius** is measured on lma and root_P50 on two records; d* = 0.5 is a
    placeholder between 0.19 (holds) and 0.73 (misreads). `U` notes its test stand says
    nothing about d*'s value.
11. **Sub-ε stiff-soil contamination** is "likely more common and invisible"; its
    frequency in the proper setting (SHARE 0.1) is not measured beyond the fixed cases.
12. **Late square law.** The scorer extrapolates the square law to 280-d intervals after
    20; the real runs tested it only with late edges dropped after 25.
13. **Constant rain** is in OBJECTIVES' bank but not in the ten cases; its front and its
    invader reference are open.
14. **The check's cost** is quoted as 1.30–1.53 committed runs (a09, `LOC` 3e-4
    reopened) and 1.54–1.75 (the leader, `LOC` Lateral); the 1.55× in the brief sits
    between them, and which rule and library it refers to is not recorded.
15. **The water-balance sums** under libS are 3.1% short on dry; whether any reported
    quantity reads them is not stated.
16. **The rows model** understates real CPU by up to 20% on dry records against 4% on long
    drought (`F` P2), so cross-record T sums carry a record-dependent bias.
