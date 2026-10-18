# Evidence for the refine-schedule design (`docs/design-refine-schedule.md`)

Subject: check the design's guarantees G1–G6 against the code and the saved runs, and
settle E1–E4, Q4 and "any length" from the library of saved runs before any new run.
Every prediction is written here, with a probability, before the analysis or run it
concerns. Scripts are in this directory; outputs in
`scratchpad/deep/rootcause/evidence/`. **[m]** measured, **[i]** inferred (derivation,
reading or estimate). Errors are in each quantity's ε (`docs/measurements/eps-spread.md`).

## Summary (written last)

**Verdict.** The design's skeleton (a schedule as breakpoints plus a density, one pinned
replay with alternate nodes dropped as the run's own estimate) is sound where it is
applied: pinning shares every step, the drop of a smooth region reads its error at ×0.8–1.25,
and nothing in it needs an absolute age. Its one structural choice, breakpoints at opening
edges only, is wrong: the real test puts layout D's worst error at 3.4ε (dry), 1.1ε
(long-wet) and 3.2ε (episodic-lma), against E6 committed's 0.35 / 0.37 / 1.29, and the drop
reads a fifth of it and passes C5 on dry and long-wet. [m]

**Guarantees.**
- G3 holds by construction [code]: the replay takes the run's steps, sizes and soil
  substeps; a dropped node's birth stays a recorded step. Its blind side: the run's own
  tolerance error is in both and never estimated (up to 0.11ε at 1e-4, flat-al1125) [m].
- G2 has two holes [code; m]. (a) Parity: an even interior count leaves one interval per
  panel unmerged, the gap-crossing one (46% of panels with nodes; the founders' panel on dry
  and episodic-lma). The fix is an even interval count, not "at least two". (b) Panels with
  no interior node (54–96% of panels) are unseen. Together they hide 80% of the closing
  strips in the real runs.
- G4 is not a check of the law [m]: map and drop differ by the field's nonlinearity only
  (≤ 0.004ε at c, 0.03ε at 1.6× c); on dry-flat's interiors they agree to 0.001ε while the
  drop reads 1.9× the truth.
- G1 only in the narrow sense: ρ scaling is not nested, every non-final iteration is spent.
- G6: ⌈·⌉ leaves 46–92% of panels unchanged at ×1.25 (they hold 2–16% of the own error), and
  scaling by exactly √(ratio) lands on the boundary; needs a margin and a count that moves.
- G5 holds only once the builders' ages are replaced (below).

**E1** [m, u857/u429 references, 3-d maps]: kinks only at opening edges (|Δ²_2h|/|Δ²_h|
1.8–3.3, κ 12–67× the spell's); founders (first days included) and late smooth. But the
closing side is not "smooth enough": curvature rises an order within 2–3 weeks of c
(fate, leaf area, most of all the hydraulic sensitivities), and a hat across c reads the
gap's different curve on its chord. That is what the real runs pay for.
**E2/E4** [m, model and saved pinned drops]: the own part falls at order 1.6–2.0 and the
drop reads it at 0.71–0.90 on layout D, 0.92–1.02 once closing edges are breakpoints and
parity is clean; saved pinned drops read regions ×0.8–1.25 except dry-flat's interiors
(×1.9). For layout D as a whole the drop fails (R11).
**E3** [m model, m runs]: without a node at c, the strip error grows as d² in the last node's
distance (honest in order) but with the gap's lever: 2–4× (dry) to 8–33× (long-wet) a node
at c's, and layout D leaves the last node 50–170 d out. A density would need ~26 d (dry) to
~10 d (long-wet) spacing before every closing edge [i]. The design's retrofit (c − 12 d as a
breakpoint) leaves [c − 12, c] on the gap chord, unseen; the retrofit needed is c itself.
**Q4** [m]: panels with < 2 interior nodes are 54–96% of panels, 0.5–6.6% of J, 23–71% of
establishment, 1–19% of the own error. Covering every spell (D′: all edges breakpoints, even
counts) costs 1.15–1.74× E6's rows: the cope (leave out panels below a share of the J window)
is needed, and its unseen part must be bounded.
**Any length** [code; m]: H = 39.6, 20 (cap switch, fate reference window), 25 (late edges),
10/17 (eras), the tolerance weight's 0–40 y grid. Replace them from the J window by calendar
time T(t), the share of J still to be produced after t: onset (T < 1, ≈ 10 y), t₅₀
(16–24 y), t₉₀ (23–29 y, E6's 25), and H = 0.99 × lifetime. A birth-date share does not
travel (R(25) spans five decades). Shorter runs (lifetime 9–20) compress the window to 1–4 y;
longer runs need a longer rain record first.
**Probes** [m; code]: libS walks invaders only at the run's own birth dates (it refuses any
other), so a probe between nodes needs a code change; at own dates the walk reproduces the
run exactly and costs 1.66× a forward. The map's channel split says soil (58–89%) where p50
inferred light: unresolved, not yet a diagnostic. Parity (odd vs even maps) spreads 0–0.08ε:
a usable uncertainty, the size of the 1e-4 jitter.

**What ran.** Offline: 13 scripts over saved runs (minutes of CPU). Real: one forward and
two invader walks (dry-lma125; 2 min), and six gradient runs (layout D and its pinned drop on
dry, long-wet, episodic-lma; 12.5 min CPU; rows 0.57–0.85 of E6 committed's). No scratch
build, no install. Predictions: 46 registered, 25 held, 18 refuted, 3 not testable; one
process slip (`e1_side.R` ran before its line was written; that line is not scored).

**What the design should change.** (1) Closing edges are breakpoints too (one node per
edge, E6's count). (2) Each panel gets an even number of intervals, so the drop merges every
one. (3) Panels left without interior nodes by a J-window share rule, with their bound
reported. (4) G4 replaced by a parity replay or the measured ratio of two moves. (5) A
tolerance term, or a tolerance whose floor is under ε/10. (6) Scaling with a margin and a
rule that the binding panel's count moves. (7) Ages from T(t).

## Pre-registration 1 (before reading the pin code, the builders or any data for this round)

Context already read: the design, the closing, h5, dwr, single, u, heldout and refine notes.

**Guarantees, code reading.**

| # | prediction | P |
|---|---|---|
| G1a | The design's loop is not nested: scaling ρ and re-deriving ⌈∫ρ⌉ equal-share nodes moves every interior node, so no earlier run or drop is reused (every non-final iteration's 1.8 runs are spent) | 95% |
| G2a | Parity hole: in a panel with an even number of interior nodes, an alternate drop leaves one breakpoint-adjacent interval unmerged, so its error is not in the estimate (the design's "at least two interior nodes" does not close it; an odd count does) | 95% |
| G2b | On ρ₀ built from the bank pilots, between 35% and 65% of panels have an even interior count | 60% |
| G3a | The pinned replay (`PIN`) reuses the run's step times and its substep ends and input slopes, with no step control of its own, so run and drop share every step even when node sets differ | 85% |
| G3b | A dropped node's introduction time stays a step boundary in the replay (the step list is the run's) | 85% |
| G4a | Map and drop agree in ln J within 0.03ε per region on dry-flat's interiors while the drop's own estimate misses the ladder truth there by more than 0.05ε: their agreement does not test the asymptotic law | 80% |
| G4b | The map–drop gap in ln J is larger on the coarse run x than on the committed run c (it measures the field's nonlinearity, which grows with spacing) | 75% |
| G6a | Under ⌈·⌉ quantization, scaling a bank pilot's ρ₀ by s = 1.25 leaves at least 30% of panels' interior counts unchanged on dry-flat and dry | 70% |
| G6b | No term of the design covers ODE tolerance error: on the cases with 1e-4 and 3e-5 runs of one schedule, the tolerance shift of some quantity exceeds ε/10 on at least one case | 60% |

**Any length, code reading.**

| # | prediction | P |
|---|---|---|
| L1 | The pilot, a09 and E6 builders hold at least six absolute ages or day counts (b = 10, 17, 20, 25, the 12-d / 7.5-d insets, the range cap) | 85% |
| L2 | A replacement for b = 25 by the age at which the pilot's remaining offspring (J still to be earned after b) falls to a fixed share lands within ±3 y of 25 on at least 8 of the ten bank pilots with one share for all | 55% |

## Pre-registration 2 (before building the design's layout on any pilot)

Layout D, as I read the design: breakpoints 0, every pilot opening edge and the horizon;
ρ₀ = 1/h(b) of a09's graded build (BG 90, its caps) on open birth dates and 0 where
establishment is shut; each panel gets n = ⌈∫ρ₀⌉ intervals, so n − 1 interior nodes at
equal ρ₀-mass. Closing edges are no longer nodes, so a panel's last interval crosses the
gap. Built on the ten bank and eight held-out pilots (`layout.R`).

| # | prediction | P |
|---|---|---|
| Q4a | Panels with fewer than two interior nodes are ≥ 40% of panels on dry-flat and ≥ 20% on dry | 65% |
| Q4b | Those panels hold under 10% of the pilot's J on every bank case except dry-flat | 55% |
| Q4c | Panels with no interior node hold ≥ 2% of J on dry-flat | 50% |
| K0 | Layout D has fewer nodes than E6 committed on at least 7 of the 10 bank cases (it drops every closing edge node; E6's inset keeps one node per edge) | 60% |
| K1 | The drop (every other interior node removed in every panel) costs 0.55–0.80 of the run's rows by the rows model (design: about 0.8) | 65% |

## Pre-registration 3: E1 from the dense references' fates (before `e1_corners.R` is run)

Data: final node states of the uniform references, u857 (h = 17 d: flat-al1125,
episodic-lma, dry-lma125) and u429 (34 d: dry-p50, wet-hmat125, ld-105, epi-adG208).
y = ln nrr (fate) and, as a leaf-area proxy, ln(leaf area at ground × survival) at the
run's end. Per node j: Δ²_h, Δ²_2h and the non-smooth part κ = |Δ²_h − Δ²_2h/4| (O(h⁴) where
y is smooth on the scale 2h, ≈ |slope jump|·h/2 at a corner). Classes by what lies within
±2h: opening edge at the centre (±h/2), opening edge off-centre, closing edge only, gap
interior, founders (b < b1 − 2h), spell interior, late (b > 25).

| # | prediction | P |
|---|---|---|
| E1a | median κ in the opening-centre class ≥ 3× the spell-interior class's on every u857 case | 60% |
| E1b | the closing-edge class's median κ is within 2× of the spell-interior class's on every u857 case (fate smooth through c) | 55% |
| E1c | no class other than the two opening classes has median κ ≥ 3× the spell interior's on any of the seven cases | 45% |
| E1d | ratio of medians \|Δ²_2h\|/\|Δ²_h\| is in [3, 5] in the spell interior and in [1.2, 2.8] in the opening-centre class on the u857 cases | 50% |
| E1e | the founders' first nodes (b < 0.25 y) show κ ≥ 3× the spell interior's on at least one case (a steep start the spacing does not resolve) | 40% |

Process slip: `e1_side.R` (the same measure on stencils wholly inside a spell, ending within
2h before its closing edge or starting within 2h after its opening edge, against the deep
interior) was run before its prediction was written. The line I had drafted (E1s: before
closing edges the ratio in [3, 5] and κ within 3× the deep interior's on ≥ 5 of 7 cases,
55%) is kept out of the score.

**Pre-registration 3b (hydraulic sensitivity across edges; before `e1_turn.R`).** On the
3-d fate maps and their root_P50 × 1.02 twins (closing: dry, long-wet; opening: dry's
omap), s(b) = Δ ln nrr / ln 1.02 subsampled at h = 3, 6, 12, 24 d.

| # | prediction | P |
|---|---|---|
| E1f | dry, closing: centred in [c − 15, c − 6] d, the ratio \|Δ²_2h\|/\|Δ²_h\| has median ≤ 2.8 at h = 12 d (the turn acts as a corner at that spacing) and ≥ 3.2 at h = 3 d | 45% |
| E1g | the same on long-wet | 40% |
| E1h | dry, opening: s(b)'s κ in [o, o + 12 d] at h = 6 d within 3× of its κ over [o + 24, o + 48 d] (no sensitivity feature at openings beyond fate's own corner at o) | 55% |

**Pre-registration 3c: E3, the closing turn under layout D (before `e3_close.R`).** Own
part only (the hat against the integrand, pilot establishment density), on the fate maps'
long-spell closing zones (dry, long-wet): nodes at c − k·h over the 60 d before c, no node at
c, the last spell node's chord running to the next opening edge (a breakpoint). Integrands
G (ln J) and G·s (root_P50's elasticity).

| # | prediction | P |
|---|---|---|
| E3a | the own part's ratio err(2h)/err(h) is within [3, 5] for h from 6 to 24 d on dry's root_P50 (order 2 in the spell-side spacing, gap chord included) | 45% |
| E3b | summed over dry's covered zones, the root_P50 own part falls under ε/100 (so a total under ε/10 at the closing round's own:total ≈ 1:13) only at h ≤ 12 d | 50% |

**Pre-registration 4: the own (interpolation) part of layout D, from the references' fates
(before `own_model.R`).** A fate model per panel (a spline of ln nrr through the
reference's nodes inside each panel, so the only corners are at opening edges), times the
disturbance density; the establishment density is the pilot's creation rate rescaled to
the reference's exact count per reference interval. Own error of a schedule S =
ln(Σ W_i F(b_i) / ∫ e F) with W the hats' exact weights. Cases: flat-al1125, episodic-lma,
dry-lma125 (u857), dry-p50, wet-hmat125 (u429). Guard first: the model's own part of the
every-other subset of the reference equals the exact nested own part from the stored
weights within 10%.

| # | prediction | P |
|---|---|---|
| E2a | the drop's own estimate (Q_drop − Q_D)/3 reads layout D's own error within ×[0.7, 1.4] on at least 4 of 5 cases | 50% |
| E2b | layout D's own error falls by [3, 5]× from ρ₀ to 2ρ₀ on at least 4 of 5 cases | 50% |
| Q4d | panels with fewer than two interior nodes carry ≥ 30% of layout D's own error (sum of \|·\| by panel) on flat-al1125 and dry-lma125 | 50% |
| Q4e | the intervals the alternate drop never merges (even-count panels) carry ≥ 20% of the own error on at least one case | 50% |

**Pre-registration 5: any length (before `q6_window.R`).** R(b) = the share of the pilot's
J carried by recruits born after b (pilot's creation rate × log-interpolated fate).

| # | prediction | P |
|---|---|---|
| L3 | on the episodic runs at patch lifetime 20 (`rc_life20`), the share that puts the late cut at 25 on the bank lands it at ≤ 15 y | 60% |
| L4 | across the ten bank pilots, log10 R(25) spans less than 1.5 decades (so one share reproduces 25 within a few years) | 50% |

Added after `q6_window.R` (R(25) spans five decades over the bank; the late region's ln J
error on episodic-lma, −0.08ε, cannot come from a birth-date share of 1e-7, so late nodes act
through the field on everyone's later offspring), before `q6_time.R`: the J window by
calendar time, T(t) = share of J still to be produced after t, from the ten committed runs'
node records (offspring produced, survival weighted, at ~150 times).

| # | prediction | P |
|---|---|---|
| L5 | T(25) ≥ 5% on every bank case (a time window does not end near 25 y) | 60% |
| L6 | the birth date where T falls to 50% lies within ±4 y across the ten cases | 50% |

**Pre-registration 6: the map's channels and parity (before `q7_maps.R`).** The dwr round's
odd and even omit-one maps on the ten committed runs; regions by birth date (founders
b < b1, interiors b1–25, late ≥ 25), drops whose merged interval crosses a pilot edge left
out. Channel = the light and soil columns' sums; parity = odd against even drop set.

| # | prediction | P |
|---|---|---|
| Q7b | the soil channel carries > 70% of \|light\| + \|soil\| for both founders and interiors on ≥ 8 of 10 cases | 55% |
| Q7c | the odd and even maps' region estimates D/3 (own + field) agree within 25% or 0.02ε for founders and interiors on ≥ 8 of 10 cases | 50% |

**Pre-registration 7: probe nodes (before `probe.R`, one forward run and two walks).**
dry-lma125's E6 committed run re-run forward on libS (its saved J is the guard); then
invader walks with the resident's traits on the stored field: (i) at the run's own node
times, (ii) at the u857 reference's birth dates in 0–3 y and 4–12 y.

| # | prediction | P |
|---|---|---|
| Q7a1 | walk (i) reproduces the run's own node fates within 1e-8 relative | 70% |
| Q7a2 | walk (ii) costs ≤ 1.5× the stand's forward | 70% |
| Q7a3 | walk (ii)'s ln nrr second differences match the u857 reference's within 10% (rms of the difference over the rms of the reference's, spell-interior stencils) and its κ classes match (opening-centre κ ≥ 3× spell interior) | 60% |

## Results, in run order

### R1. The guarantees against the code (pin, drop, builders) [code; m where marked]

- **Pinning shares every step (G3a, G3b hold).** `PIN` hands the run's step times, step
  sizes, soil input slopes and substep ends to the replay (`adj_run_dwr.R`, lines 47–53).
  `NodeSchedule::program()` (libS `src/node_schedule.cpp` 176–200) walks the replay's
  introductions and, inside each introduction segment, pushes every recorded step with its
  recorded size and substeps, so a dropped node's introduction time stays a recorded step's
  end; nothing in the replay chooses a step. [m, single round] The all-regions drop equals
  the sum of per-region drops (cos 1.000, rms 0.002ε), as shared steps require.
- **But shared steps hide the tolerance error (G6b holds).** The run's own ODE error is in
  run and drop alike, so the estimate never sees it. [m, refine round] One schedule at 3e-5
  against 1e-4: flat-al1125 rms 0.028, max 0.108ε (TF24_cost_scale); ld104 0.004 / 0.019.
  The design's R1 ("every quantity within ε") needs a tolerance term the loop does not have.
- **Parity hole (G2a holds; G2b holds pooled).** With n interior nodes in a panel and the
  1st, 3rd, … dropped, n even leaves the panel's last interval (the one that crosses the
  gap to the next opening edge) unmerged, so its error is not in the estimate. "At least two
  interior nodes" does not close it; an odd n (an even number of intervals) does. [m,
  schedule] On layout D, 117 of 255 bank panels that have interior nodes have an even
  count (46%; per case 21–57%).
- **Not nested (G1a holds).** n = ⌈s∫ρ⌉ at equal ρ-mass moves every interior node when s
  changes, so a non-final iteration's run and drop are spent. G1 holds only in the narrow
  sense that the last run is the answer.
- **G6 stalls panel by panel (G6a holds).** At s = 1.25, 46–92% of panels keep their count
  (dry 80%, dry-flat 92%) [m, schedule]; they hold 1.4–7% of J and 2–16% of layout D's own
  error [m, model, R5], so the loop still moves, but "each scaling divides the worst ratio
  by s²" is false for any quantity whose error sits in such a panel.

### R2. The map does not test the asymptotic law (G4a, G4b hold) [m] (`g4.R`)

e = move/3 in ε of ln J; map = the single round's c = 0 map (δenv active, merged census);
drop = the pinned real drop R0; measured = the ladders' region error.

| case, run | region | map | drop | map − drop | drop − measured |
|---|---|---|---|---|---|
| dry, c | F / I / L | +0.119 / −0.234 / −0.011 | +0.118 / −0.232 / −0.011 | +0.001 / −0.002 / 0.000 | +0.016 / −0.010 / +0.001 |
| dry-flat, c | F / I | +0.193 / −0.169 | +0.190 / −0.167 | +0.004 / −0.001 | −0.001 / **−0.079** |
| episodic-lma, c | F / I / L | +0.071 / −0.268 / −0.080 | +0.072 / −0.266 / −0.084 | −0.001 / −0.002 / +0.004 | −0.010 / – / – |
| dry, x (1.6× c) | I / F | −0.534 / +0.256 | −0.561 / +0.286 | **+0.027 / −0.030** | – |

The map–drop gap is the field response's nonlinearity: ≤ 0.004ε at the committed spacing,
0.03ε at 1.6× (G4b). It is blind to the order: dry-flat's interiors agree to 0.001ε while the
drop reads 1.9× the ladder's error. A 0.03ε rule would flag x (whose estimates transfer to c
within 7%) and pass dry-flat. G4 as written is not a check of anything the loop needs.

### R3. Layout D on the 18 pilots (`layout.R`, `q4_panels.R`) [m, schedule and rows model]

| case | nodes D / E6 c | rows D / E6 c | panels | 0 / 1 interior | share < 2 | J in < 2 | establishment in < 2 | even panels | drop rows / run |
|---|---|---|---|---|---|---|---|---|---|
| episodic | 120 / 135 | 0.83 | 44 | 20 / 9 | 66% | 4.4% | 35% | 12 | 0.60 |
| dry | 143 / 149 | 0.85 | 71 | 40 / 9 | 69% | 1.1% | 34% | 17 | 0.68 |
| long-wet | 135 / 157 | 0.77 | 73 | 46 / 12 | 79% | 1.5% | 49% | 11 | 0.69 |
| long-drought | 137 / 155 | 0.79 | 77 | 51 / 12 | 82% | 2.9% | 55% | 10 | 0.70 |
| episodic-lma | 110 / 120 | 0.84 | 35 | 13 / 6 | 54% | 1.7% | 23% | 11 | 0.57 |
| dry-flat | 200 / 191 | 0.79 | 157 | 138 / 13 | 96% | 1.7% | 71% | 4 | 0.78 |
| ld-102 | 138 / 143 | 0.82 | 75 | 50 / 9 | 79% | 3.1% | 46% | 14 | 0.69 |
| ld-105 | 135 / 146 | 0.83 | 64 | 38 / 8 | 72% | 0.7% | 38% | 13 | 0.66 |
| dry-p50 | 149 / 153 | 0.84 | 78 | 48 / 8 | 72% | 1.2% | 34% | 17 | 0.69 |
| wet-adG2 | 135 / 158 | 0.76 | 78 | 53 / 12 | 83% | 1.5% | 56% | 8 | 0.70 |
| held-out (8) | 120–188 / 134–173 | 0.76–0.85 | 43–142 | | 61–94% | 0.5–6.6% | 28–64% | 6–14 | 0.59–0.76 |

- Q4a holds (dry-flat 96%, dry 69%); Q4b holds (bank J in < 2-node panels 0.7–4.4%); Q4c
  refuted (dry-flat's no-node panels hold 0.8% of J). K0 holds (9/10; dry-flat 200 > 191);
  K1 holds (0.57–0.78; the design's "about 0.8" is high).
- Most short panels are late or in dry-flat's 1–3-week spells: they hold a third to two
  thirds of establishment but little J, because late recruits' fate is small.
- **Wide intervals.** Without closing-edge nodes, 12–32 intervals per case exceed 160 d (the
  span past which order 2 failed in the h5 round), 1–9 of them before b = 20, holding
  0.1–5% of J (`extra.R`).

### R4. E1: where the integrands are not smooth (`e1_corners.R`, `e1_side.R`, `e1_turn.R`) [m]

Fate (ln nrr) by class, κ relative to the spell interior's, and |Δ²_2h|/|Δ²_h| (≈ 4 smooth,
≈ 2 at a corner on the centre):

| case (h) | opening centre: κ×, ratio | opening near: κ× | closing (stencil crosses c): κ×, ratio | founders: κ× | founders' first 0.25 y: κ× | late: κ× | spell: ratio |
|---|---|---|---|---|---|---|---|
| flat-al1125 (17 d) | 16, 2.2 | 10 | 11, 3.9 | 0.13 | 0.19 | 4.5 | 3.6 |
| episodic-lma (17 d) | 37, 3.3 | 24 | 18, 3.7 | 0.24 | 0.32 | 2.1 | 3.5 |
| dry-lma125 (17 d) | 67, 2.4 | 43 | 44, 3.8 | 0.42 | 0.13 | 2.8 | 4.1 |
| dry-p50 (34 d) | 12, 2.7 | 11 | 11, 5.4 | 0.16 | 0.09 | 1.0 | 3.8 |
| wet-hmat125 (34 d) | 34, 1.8 | 24 | 20, 7.1 | 0.39 | 0.48 | 1.0 | 4.4 |
| ld-105 (34 d) | 34, 2.1 | 21 | 16, 5.2 | 0.18 | 0.05 | 2.7 | 3.7 |
| epi-adG208 (34 d) | 27, 2.9 | 10 | 12, 3.9 | 0.12 | 0.10 | 1.3 | 4.1 |

The leaf-area proxy (ln(height)/a_l2 − mortality at the run's end) gives the same pattern.

- **Opening edges are corners** (ratio 1.8–3.3, κ 12–67×), as the h5 round found at 3 d.
- **Closing edges are not corners but are not smooth at these spacings either.** Stencils
  that cross c have κ 10–44× the spell interior's with ratio 3.7–7: curvature that changes
  within 2h. Wholly inside the spell, approaching c, the ratio is 3.2–4.8 and κ 0.6–4.6× the
  deep interior's, curvature 1.3–5× (fate) and up to 16× (leaf proxy): smooth but sharply
  curved, so a hat across c reads the gap's very different curve on its chord.
- **The founders (including their first days) and the late cohorts are smooth** (κ 0.05–0.5×
  and 1–4.5×). No other corner class appears.
- **The hydraulic sensitivity's closing turn is not a kink either** (`e1_turn.R`):
  |Δ²_2h|/|Δ²_h| centred at c − 12 d is 3.3 (dry) and 3.0 (long-wet) at h = 12 d, 3.8–5 at
  3 d; but κ at h = 12 d is 14× (dry) and 11× (long-wet) its value 60 d out, and the ratio
  centred at c − 24 d is 6.3 and 9.4: the curvature grows by an order within ~20 d of c.
  At the opening edge s(b) has a corner like fate's (ratio 1.9 at 3 d).
- Scored: E1a holds (16, 37, 67×); E1b refuted (closing κ 11–44×); E1c refuted (closing, b1
  and gap classes all ≥ 3×); E1d refuted (episodic-lma's opening ratio 3.25); E1e refuted
  (founders' first days 0.1–0.5×); E1f refuted (3.31 at h = 12 d); E1g refuted (2.97); E1h
  not testable (the opening map has no 5-point stencils past o + 6 d at h ≥ 6 d).

**E1 verdict:** "a corner only at opening edges" holds for kinks. It does not license
dropping closing edges as nodes: on the closing side the integrands (fate, leaf area, and
most of all the hydraulic sensitivities) curve an order of magnitude harder within 2–3 weeks
of c than inside the spell, and the gap's curve beyond c is different again.

### R5. The own part of layout D, its drop, and its order (`own_model.R`, `own_run.R`, `extra.R`) [m, model]

Guard: the model's own part of each reference's every-other subset against the exact
nested own part from the stored weights: 0.0338 / 0.0357, 0.0265 / 0.0278, 0.0209 / 0.0219,
0.2014 / 0.2026, 0.2908 / 0.2932 (within 5%; the model's fate between nodes is a spline).

| case | own error of D (ε ln J) | founders' panel | drop's estimate / own error | at 2ρ₀ | own(ρ₀)/own(2ρ₀) | 2ρ₀/4ρ₀ | 4ρ₀/8ρ₀ | \|own\| in < 2-node panels | in unmerged intervals | in intervals > 160 d |
|---|---|---|---|---|---|---|---|---|---|---|
| flat-al1125 | +0.315 | +0.302 | 0.90 | 0.93 | 3.71 | 3.63 | 4.04 | 2.7% | 1.2% | 1.1% |
| episodic-lma | +0.189 | +0.120 | 0.88 | 0.66 | 3.19 | 3.90 | 3.05 | 19.1% | 7.0% | 13.4% |
| dry-lma125 | +0.208 | +0.154 | 0.84 | 0.85 | 3.63 | 3.69 | 3.70 | 1.0% | 16.0% | 17.6% |
| dry-p50 | +0.336 | +0.228 | 0.71 | 0.80 | 3.59 | 3.71 | 3.45 | 1.0% | 20.9% | 17.2% |
| wet-hmat125 | +0.369 | +0.319 | 0.89 | 0.82 | 3.38 | 3.66 | 3.75 | 1.0% | 6.6% | 7.2% |

- The own part is near order 2 under ρ scaling (ratios 3.05–4.04, so order 1.6–2.0) and the
  drop reads it at 0.71–0.90: the drop's /3 assumes 4×, the own part grows 3.2–3.7× at ρ₀,
  so the estimate runs 10–30% low on this part alone. Scored: E2a holds (5/5 in [0.7,
  1.4]; dry-p50 at 0.709), E2b holds (5/5), Q4d refuted (1–19%), Q4e holds (dry-p50 21%,
  dry-lma125 16%).
- The founders' panel holds 64–96% of D's own error: ρ₀'s founders spacing (a09's b1/12–b1/24)
  is where the own error is.
- The model's own part is roughly half the story: the dwr maps put the field part at −28% to
  −68% of the founders' own part and 4–7× the interiors' own part, opposite in sign.

### R6. E3: the closing side under layout D (`e3_close.R`) [m, model; i where scaled]

Own part on the fate maps' long-spell closing zones (dry 7, long-wet 10 covered), nodes at
c − k·h, chord from the last spell node to the next opening edge; beside it the same with a
node at c.

| h (d) | dry ln J | dry root_P50 | dry root_P50, c a node | long-wet ln J | long-wet root_P50 | long-wet root_P50, c a node |
|---|---|---|---|---|---|---|
| 6 | 0.00002 | −0.00017 | −0.00010 | 0.00018 | −0.0013 | −0.00007 |
| 12 | 0.00009 | −0.00088 | −0.00038 | 0.00094 | −0.0067 | −0.00034 |
| 24 | 0.00045 | −0.0045 | −0.0015 | 0.0048 | −0.029 | −0.0014 |
| 48 | 0.0018 | −0.019 | −0.0053 | 0.020 | −0.109 | −0.0033 |
| layout D as built (last node 80 d before c, median) | +0.0029 | −0.030 | | +0.030 | −0.160 | |

- Without a node at c the strip before c is read on the chord to the next opening edge, and
  its own error grows at order 2.0–2.6 in the last node's distance h (E3a refuted narrowly:
  ratio 5.2 per doubling on dry). So the drop sees it, honestly in order.
- Its size is set by the gap's lever, not by local curvature: at the same h a node at c
  cuts it 2–4× on dry and 8–33× on long-wet.
- Layout D as built (ρ₀ = a09 without the closing nodes) leaves the last node 50–170 d before
  c. Over the covered zones alone the own part is −0.030ε (dry) and −0.160ε (long-wet) in
  root_P50. Scaled to all closing edges (×47/7, ×50/10) and by the closing round's
  total-to-own ratio (2.8 dry, 5 long-wet, per zone), that is of order 0.5ε (dry) and 4ε
  (long-wet) [i, crude].
- Spacing that brings that scaled total under ε/10 [i]: about 26 d before every closing
  edge on dry and 9–10 d on long-wet (+2 and +7 nodes per edge, +65% and +260% nodes). With a
  node at c, ρ₀'s own spell-end spacing (45–60 d) already does it on both. E3b refuted
  (the covered zones' own part is under ε/100 up to h ≈ 33 d on dry).
- The design's retrofit (c − 12 d as a breakpoint, no node at c) leaves [c − 12, c] on the
  gap chord between two breakpoints, an interval the drop never touches: −0.0009 (dry) and
  −0.0067ε (long-wet) own over the covered zones, ≈ 0.02ε and ≈ 0.17ε scaled [i]. The
  retrofit that removes the gap lever is c itself as a breakpoint (one node per closing edge,
  E6's count).

## Pre-registration 8: the minimal real test (before any of its runs)

What the offline evidence leaves open: E4 for layout D as a whole (field part, the closing
strip on the gap chord, the founders), and whether the closing-strip error the model
predicts is real. Runs: layout D at ρ₀ (all opening edges as breakpoints, a09's density,
closing edges not nodes) on dry, long-wet and episodic-lma, then its pinned drop (every
other interior node of each panel, `PIN` = the run), libS, the E6 committed setting
(KNOTS=0, 1e-4, weights, HMAX 15, SHARE 0.1, SPLIT 1), gradient on. Scored against the
references refine's `ref_ladder` uses; estimate e = (Q_drop − Q_D)/3; C1–C5 at ε as
`crit`. Six runs.

| # | prediction | P |
|---|---|---|
| D1 | layout D's worst error is above 1ε on long-wet | 55% |
| D2 | above 1ε on at least two of the three cases | 40% |
| D3 | the drop's estimate passes C2 and C3 at ε on at least 2 of 3 cases | 45% |
| D4 | the drop reads ln J's error within ×[0.6, 1.6] on at least 2 of 3 cases | 55% |
| D5 | long-wet's error is mostly hydraulic and the estimate's direction agrees with it (cos ≥ 0.8 over the 46 elasticities) | 45% |
| D6 | each drop costs 0.55–0.85 of its run's CPU | 70% |
| D7 | nothing throws | 90% |

### R7. Any length: the absolute ages and their replacements (`q6_window.R`, `q6_time.R`) [code; m]

Absolute ages and day counts in the pilot, a09 and E6 builders (L1 holds):

| where | constant | role | replacement |
|---|---|---|---|
| `pilot_edges`, `build_graded`, `check_range` | H = 39.6 y; edges kept in (0, 39.6) | the horizon | 0.99 × the stand's patch lifetime |
| `capf` / `cap_of` | 100 d before b = 20, 280 d after | spacing cap, and the age where it switches | switch at t₅₀ of the J window by time (bank 16–24 y); the caps themselves are spacings (keep) |
| `hfun_of` | `ref` = median ln nrr over (b1, 20) | the fate level that grades spacing | the same window ending at t₅₀ |
| `a09_late`, E6, `h5_sched` | late edges b > 25 left out | where edges stop being nodes | t₉₀ of the J window by time (bank 22.9–28.8 y) |
| `h5_sched` (U/T), dwr/refine regions | 10, 17, 25 (eras Ia/Ib/Ic, tcut) | era boundaries | onset of offspring production, t₅₀, t₉₀ |
| E6 inset | 12 d (committed), 7.5 d (check) | inset widths | seedling reserve time scale, not a patch age (keep, or drop with the insets) |
| `hfun_of` | BG 90 d, LAYER b1/24, cap b1/12, FALL 10 | spacing scales | already relative or a spacing |
| run setting | HMAX 15 d; the tolerance weight file `window/rule_A/weight_*.rds` on a fixed 0–40 y grid (1 → 100) | step control | the weight's time grid from the J window too |
| scorer (`anysched.R`) | bands (0, b1, 10, 40) | scoring only | – |

- **By birth date, a share threshold does not travel.** R(b), the share of J from recruits
  born after b, at 25 y spans five decades over the bank (log10 −3.9 to −9.0; L4 refuted).
  One share (the bank's median at 25) still lands the late cut at 19.8–26.9 y on the bank,
  9/10 within ±3 y (L2 holds; dry-flat 19.8), and 19.4–29.8 y over all 18.
- **By calendar time it does.** T(t), the share of J still to be produced after t, from the
  ten committed runs' node records: production starts after 10 y (T(10) = 1 on all ten),
  t₅₀ = 16.3–24.1 y, t₉₀ = 22.9–28.8 y, t₉₉ = 31.7–34.5 y. E6's 25 y is the bank's t₉₀;
  a09's 20 y sits between t₅₀ and t₉₀; 10 y is the onset. T(25) = 4.5–34% (L5 refuted
  narrowly: dry-flat 4.5%; L6 holds: t₅₀ within ±3.9 y). This is the window to use: a node
  born at b acts on J only through offspring produced after b (own fate and, through the
  field, everyone's), which is why the late region's ln J error on episodic-lma is −0.08ε
  while its birth-date share of J is 1e-7.
- **Shorter runs** (the saved episodic runs at patch lifetime 9–20 y): J collapses (1.8e-10 at
  9 y, 0.02 at 20 y) and the birth-date window shrinks with it (99% of J from recruits born
  before 0.7–3.9 y; at lifetime 20 the 25-y share lands at 14.4 y, L3 holds). With absolute
  ages a lifetime-20 run would have no late cut at all and a09's 100-d cap everywhere.
  **Longer runs** could not be checked cheaply: the rain record is 41 years
  (`harness/long_drought.R`), so a lifetime past 40 needs a longer record first.

### R8. Probes, the map's channels, parity (`probe.R`, `q7_maps.R`) [m; code]

**Probes (Q7a).** dry-lma125's committed run re-run forward on libS reproduces its saved J
`identical()` (0.011267443728; 47 s, 4057 steps). Walk (i), invaders with the resident's
traits at the run's own 139 birth dates, reproduces every node's fate `identical()` and J
(Q7a1 holds) and costs 79 s, 1.66× the forward (0.57 s a probe). Walk (ii), at the u857
reference's birth dates, is refused at once: "An invader is introduced at t=0.0463…, where
the run introduced no node" (libS `scm.h` 811–823: an invader's node is walked as a copy
of the run's node born on its date). So Q7a2 and Q7a3 cannot be scored: a probe at a birth
date the run did not introduce needs a code change (split a recorded step at the probe's
birth and walk from the stored field there), and the only probes possible today (zero-weight
resident nodes, as the closing maps' gap probes) work only where establishment is shut.
Even then a probe gives fate only; its elasticity integrands would need a sweep per probe.

**Channels (Q7b refuted).** Soil carries most of the field part everywhere, but not > 70%
on most cases: founders 58–89% soil, interiors 68–85% (both over 70% only on episodic,
dry, episodic-lma, dry-p50). On the cases the rounds know: the founders' error goes through
their own uptake drying the soil (founders round), and the map agrees (soil 77% on dry). The
interiors' understory: the p50 round inferred light at the founders' lower crowns, because
the soil layers agreed to 1e-5 [i]; the map says soil (81% on dry), weighting water at the
drydowns when it is short. The two cannot both be right and no saved run separates the
channels (A-type runs apply both at once), so the split is a claim, not yet a diagnostic.

**Parity (Q7c refuted).** Odd against even omit-one maps, region estimate D/3 in ε of ln J:

| | founders: odd / even | interiors: odd / even |
|---|---|---|
| episodic | −0.011 / −0.032 | −0.157 / −0.196 |
| dry | +0.108 / +0.082 | −0.250 / −0.234 |
| long-wet | +0.128 / +0.129 | −0.038 / −0.051 |
| long-drought | +0.099 / +0.091 | −0.066 / −0.083 |
| episodic-lma | +0.067 / +0.058 | −0.264 / −0.183 |
| dry-flat | +0.187 / +0.164 | −0.162 / −0.122 |
| ld-102 | +0.139 / +0.115 | −0.075 / −0.114 |
| ld-105 | +0.112 / +0.102 | −0.088 / −0.100 |
| dry-p50 | +0.105 / +0.075 | −0.259 / −0.279 |
| wet-adG2 | +0.171 / +0.166 | −0.041 / −0.040 |

Spread 0.000–0.081ε (median ≈ 0.02); both regions agree within 25% or 0.02ε on 4 of 10.
A parity replay is a usable uncertainty for the estimate, of the size of the 1e-4 jitter.

### R9. E2/E4 from the saved pinned drops (single, dwr rounds) [m, re-read]

The pinned drop's region estimate (own + field, all orders) against the ladders' measured
region errors, on E6's layout (so the edge strips are outside both):

| run | region | cos (46 elasticities) | slope truth/estimate | ln J estimate / truth |
|---|---|---|---|---|
| dry, c | founders / interiors / late | 0.985 / 0.935 / 0.97 | 1.01 / 1.07 / 1.26 | +0.118 / +0.102; −0.232 / −0.223; −0.011 / −0.012 |
| dry-flat, c | founders / interiors | 0.983 / 0.824 | 0.83 / 0.59 | +0.190 / +0.191; −0.167 / −0.089 |
| episodic-lma, c | founders (A ≈ R0) | 0.996 | 1.12 | +0.072 / +0.082 |
| dry, x (/1.6²) | interiors / founders | 0.96 / 0.98 | 0.98 / 1.22 | −0.22 / −0.22; +0.11 / +0.10 |

So on the h² regions the alternate drop reads the error honestly (×0.8–1.25) everywhere
except dry-flat's interiors, whose 42-d spells at 84 d are off the square law (×1.7–1.9
over-read). The uniform references' own ladders (17–68 d, no edge nodes at all) run at order
1.91 (flat-al1125) and 2.14 (episodic-lma), and dry-lma125's changes sign between rungs.

### R10. What closing breakpoints and clean parity cost (`layout_dp.R`) [m, schedule and rows model]

Layout D′: every edge a breakpoint (opening and closing, late ones included), a09's ρ₀,
every spell panel's interval count rounded up to even (so the alternate drop merges every
interval and every spell has an interior node), gap panels empty.

| | episodic | dry | long-wet | long-drought | episodic-lma | dry-flat | ld-102 | ld-105 | dry-p50 | wet-adG2 |
|---|---|---|---|---|---|---|---|---|---|---|
| nodes D′ / D / E6 c | 195 / 120 / 135 | 270 / 143 / 149 | 264 / 135 / 157 | 274 / 137 / 155 | 168 / 110 / 120 | 498 / 200 / 191 | 276 / 138 / 143 | 249 / 135 / 146 | 291 / 149 / 153 | 273 / 135 / 158 |
| rows × E6 c: D′ / D | 1.21 / 0.83 | 1.50 / 0.85 | 1.42 / 0.77 | 1.47 / 0.79 | 1.15 / 0.84 | 1.74 / 0.79 | 1.47 / 0.82 | 1.40 / 0.83 | 1.52 / 0.84 | 1.43 / 0.76 |
| spell panels with one interior node | 29 / 44 | 49 / 71 | 58 / 73 | 63 / 77 | 19 / 35 | 151 / 157 | 59 / 75 | 46 / 64 | 56 / 78 | 65 / 78 |

Full coverage is expensive because most spells are short: two thirds to all of the spell
panels exist only to hold the one node the drop needs. That is the price of G2 as stated;
a rule that leaves out panels below a set share of the J window (Q4's cope) is what makes it
affordable, and its unseen part is then what R5 measured (1–19% of the own error).

Own part of D′ against D on the five model cases (`own_dp.R`) [m, model]: the drop reads
D′'s own error at 0.92–1.02 (D: 0.71–0.90), D′'s own error falls 3.0–4.1× from ρ₀ to 2ρ₀,
and its size is 0.13–0.33ε against D's 0.19–0.37ε (the founders' panel dominates both).
Closing breakpoints plus clean parity are what make the own part's estimate honest.

### R11. The minimal real test: layout D at ρ₀ and its pinned drop (`run.sh`, `score_d.R`, `strip_status.R`) [m]

Six gradient runs on libS (E6 committed setting), all exit 0, each drop on its run's exact
steps (`identical()` step times). err in ε against refine's references; estimate
e = (Q_drop − Q_D)/3.

| case | nodes D / drop | rows D / E6 c | worst err (q) | rms | ln J err / est | est max | cos(err, est) | read | C1 C2 C3 C5 | E6 c worst / rms | CPU run / drop (s) |
|---|---|---|---|---|---|---|---|---|---|---|---|
| dry | 143 / 100 | 0.85 | **3.36** (root_P50) | 0.84 | −0.88 / −0.28 | 0.78 | 0.34 | 0.21 | ✗ ✗ ✗ ✓ (C3 19/24 miss) | 0.35 / 0.16 | 148 / 91 |
| long-wet | 135 / 96 | 0.79 | **1.13** (root_P50) | 0.33 | −0.23 / +0.04 | 0.34 | 0.63 | 0.26 | ✗ ✗ ✗ ✓ (7/9) | 0.37 / 0.09 | 162 / 100 |
| episodic-lma | 110 / 67 | 0.85 | **3.24** (root_P50) | 1.53 | −1.17 / −0.61 | 1.20 | 0.99 | 0.44 | ✗ ✗ ✗ ✗ (36/40) | 1.29 / 0.68 | 86 / 45 |

- Top errors: dry root_P50 +3.36, omega −2.51, root_c −1.76, a_dG2 +1.53, a_l1 +1.51;
  long-wet root_P50 +1.13, omega −0.79, a_dG2 +0.75, TF24_cost_scale −0.60; episodic-lma
  root_P50 +3.24, TF24_cost_scale −2.90, omega −2.81, r_l −2.57. The dry pattern is the
  closing round's closing-region signature (root_P50 +, omega −, root_c −), ten times larger:
  with no node at c, every closing strip is read on the chord to the next opening edge.
- **The drop misses it and, on dry and long-wet, says the run is within ε (C5 passes on a
  3.4ε error).** Only 14 of dry's 70 closing strips are merged by the drop (17 sit in
  even-count panels and are never merged, 39 in panels with no interior node); long-wet 16
  of 72; episodic-lma 11 of 34. The founders' panel is even on dry and episodic-lma, so b1's
  strip is unseen there too.
- Cost: the drop is 0.53–0.62 of its run's CPU (rows 0.57–0.69); layout D is 0.79–0.85 of E6
  committed's rows at 3–10× its worst error.
- Scored: D1 holds (1.13); D2 holds (3/3); D3 refuted (0/3); D4 refuted (ln J reads 0.31,
  −0.16, 0.52); D5 refuted (hydraulic, but cos 0.63); D6 refuted narrowly (episodic-lma
  0.53); D7 holds.

**What this settles.** E1's "closing edges are smooth, so they need no node" was the wrong
inference: smooth, but the hat across c reads the gap's curve, and the strip's error
(mostly field, through the strip cohorts' leaf area and uptake) dominates the run. E4 fails
for the design as built: the estimate sees a fifth of the strips. E3: a density cannot
resolve this at ρ₀; a node at c can (E6 does it with its inset node, at one node per edge).

## Predictions scored

| # | P | result |
|---|---|---|
| G1a | 95% | holds (code) |
| G2a | 95% | holds (code) |
| G2b | 60% | holds pooled (46%; per case 21–57%, 7/10 in band) |
| G3a | 85% | holds (code) |
| G3b | 85% | holds (code) |
| G4a | 80% | holds (dry-flat I: gap 0.001ε, drop − truth −0.079ε) |
| G4b | 75% | holds (x 0.027–0.030ε vs c ≤ 0.004ε) |
| G6a | 70% | holds (dry 80%, dry-flat 92%) |
| G6b | 60% | holds (flat-al1125 max 0.108ε) |
| L1 | 85% | holds |
| L2 | 55% | holds (9/10) |
| Q4a | 65% | holds |
| Q4b | 55% | holds |
| Q4c | 50% | refuted (0.8%) |
| K0 | 60% | holds (9/10) |
| K1 | 65% | holds (0.57–0.78) |
| E1a | 60% | holds |
| E1b | 55% | refuted |
| E1c | 45% | refuted |
| E1d | 50% | refuted |
| E1e | 40% | refuted |
| E1f | 45% | refuted |
| E1g | 40% | refuted |
| E1h | 55% | not testable |
| E3a | 45% | refuted narrowly (5.2) |
| E3b | 50% | refuted (≈ 33 d) |
| E2a | 50% | holds |
| E2b | 50% | holds |
| Q4d | 50% | refuted |
| Q4e | 50% | holds |
| L3 | 60% | holds |
| L4 | 50% | refuted |
| L5 | 60% | refuted narrowly |
| L6 | 50% | holds narrowly |
| Q7b | 55% | refuted |
| Q7c | 50% | refuted |
| Q7a1 | 70% | holds |
| Q7a2 | 70% | not scorable (walk refused) |
| Q7a3 | 60% | not scorable |
| D1 | 55% | holds (1.13) |
| D2 | 40% | holds (3/3) |
| D3 | 45% | refuted (0/3) |
| D4 | 55% | refuted (0/3) |
| D5 | 45% | refuted (cos 0.63) |
| D6 | 70% | refuted narrowly (0.53) |
| D7 | 90% | holds |
