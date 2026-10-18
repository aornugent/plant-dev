# Evidence for the refine-schedule design (`docs/design-refine-schedule.md`)

Subject: check the design's guarantees G1–G6 against the code and the saved runs, and
settle E1–E4, Q4 and "any length" from the library of saved runs before any new run.
Every prediction is written here, with a probability, before the analysis or run it
concerns. Scripts are in this directory; outputs in
`scratchpad/deep/rootcause/evidence/`. **[m]** measured, **[i]** inferred (derivation,
reading or estimate). Errors are in each quantity's ε (`docs/measurements/eps-spread.md`).

## Summary (written last)

**Round 5 (R17–R19).** The grading's width is not a first-run quantity: it is how long a newborn's
reserves last once its production turns negative, t_r = storage_relaxation_offset ·
ln(a_st3 · a_dG2) = 19.4 d (the pool decays with e-fold time o after P < 0, whatever the
seedling's size). t_r predicts every measured half-rise width within 26% (14.4–21.4 d on dry,
long-wet, dry-p50 and dry-flat; sensitivities and ln J's integrand alike); per zone the width does
not follow the drought's length (ρ −0.14 over 38 zones of 14–75 d droughts); a map with the offset
doubled doubles it (×2.2–2.4 against ×2.0 predicted), though the profile becomes a hump about
0.6 t_r before c. The height (g ≈ 2–2.4) has no first-run predictor and was held at dry's. The
layout graded by t_r (G5), at 1e-4 with every quantity held to 0.88ε, passes C1–C5 on dry,
long-wet, episodic-lma, dry-flat and held-out epi-adG208: worst 0.30–0.56ε (E6 committed
0.35–1.29), read 0.82–1.17, root_P50 and the storage offset ≤ 0.23ε, short spells 0.05–0.22ε,
1.38–1.68× E6 committed's nodes, run + replay 0.92–1.10× E6 committed + check. Sixteen runs;
92 predictions in all, 56 held.

**Round 4 (dry; R15, R16).** The storage offset's order-1 component is not a slope jump at a
fixed birth date: no reserve threshold is crossed between neighbours (every cohort near a
shutting empties its reserves) and no cohort reaches the parked hazard. Its sensitivity
curves hardest over the last ~3 weeks before each shutting (wider than root_P50's), its
interpolation part is small, so the error is field. Adding two intervals per replayed spell,
graded into those three weeks by the measured curvature (+49 nodes), takes the storage offset
−0.49 → −0.11 and root_P50 +0.41 → −0.05, worst 0.36 (E6 committed 0.35), with the replay
reading 0.97 and passing C1–C5; at 1e-4 run + replay would cost about E6's committed + check
[i]. `splits` is not a switch counter. Three more runs; 75 predictions in all, 41 held.

**Round 3 (dry; R13, R14).** Offline, the removal under-reads the shutting zones'
root_P50 interpolation error under B's near-uniform density (0.56–0.75 per zone); grading
by the measured curvature, κ^(1/3) over the last 18–27 d, brings it to 0.90–1.14. In runs:
the doubled run reads B's error at 1.04 (cos 0.97), so the reference is right, but the
root_P50 / storage-offset component only halves per doubling (order ≈ 1). The graded layout
(+3 nodes) cuts root_P50 0.41 → 0.15 and its replay reads it, passing C1–C5; the storage
offset (−0.37) is still missed. At 1e-4 the graded layout would cost ≈ 1.23× E6 committed
and run + replay ≈ 2.0 against E6's 2.4 [i]; 1e-4 with a fixed 0.12ε tolerance reserve
serves, a per-run nudge does not pay. Three more runs; 66 predictions in all, 34 held.

**Round 2 (layout B: both edges as breakpoints, even counts, short spells left at one
interval, ages from T(t), 3e-5; R12).** All three runs are within ε (worst 0.79 dry, 0.47
long-wet, 0.76 episodic-lma; E6 committed 0.35, 0.36, 1.29). The odd replay reads 0.75–0.87
with cos 0.88–0.97 and no false accept; C2–C5 pass on long-wet and episodic-lma, and dry
fails C3 on a root_P50 / storage_relaxation_offset component (0.4–0.6ε) that the replay
does not see. The even replay is not a second estimate of the same error (cos 0.29 with it on
dry, 0.50ε from the odd one), contradicting the design's and the vignette's parity claim; the
proxy bound for short spells under-covers 5–50×, though their error is ≤ 0.10ε. Cost: real
rows 1.57–1.73× E6 committed (1.40–1.45× from the tolerance), 0.62–0.71× E6 committed + check.
Ten more runs (one stopped and relaunched after an ATOL slip); 57 predictions in all, 31 held.

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

## Round 2: the revised layout (coordinator's request after R11)

## Pre-registration 9 (before building layout B or any of its runs)

Layout B (`layoutB.R`), as the revised design reads: breakpoints at 0 and every edge,
opening and shutting, up to t₉₀; edges after t₉₀ are not breakpoints and the late stretch is
one panel to the horizon. ρ₀ = a09's graded density with the 20-y ages (100-d cap switch,
fate reference window) moved to t₅₀; t₅₀ and t₉₀ from each case's committed run's T(t)
(dry 17.5 / 25.3, long-wet 17.3 / 23.7, episodic-lma 24.1 / 28.8 y; R7). A panel with
∫ρ₀ ≤ 1 keeps one interval (a short spell, not replayed); every other panel gets an even
interval count at equal ρ₀-mass. Runs on libS, E6 committed setting but TOL 3e-5 (run and
replay alike): run B, the odd replay (every panel's 1st, 3rd, … interior node removed, which
merges every interval of every even panel), on dry also the even replay (2nd, 4th, …; it
merges the middle pairs only and leaves each panel's two end intervals as they are).

**The short spells' bound, fixed now.** B_q = 2·|e_q|·P_short/P_rep, e_q the odd replay's
estimate and P the a09 proxy (Σ over intervals of ∫ pilot-offspring^0.6 × width²) of the
short spells' single intervals and of the replayed spells' intervals; the factor 2 covers the
proxy's measured misread (median ×1.37). **Their true error** needs one more run per case:
run B with every short spell bisected (unpinned, since the new births are not steps of run
B), e_short = (4/3)(Q_B − Q_bis), with 3e-5's step noise (0.004–0.012 rms) in it. Ten runs in
all; at most two R processes of mine at once.

| # | prediction | P |
|---|---|---|
| B1 | run B's worst error ≤ 1ε on at least 2 of 3 cases | 55% |
| B2 | run B's worst error ≤ E6 committed's (0.35, 0.37, 1.29) on at least 2 of 3 | 35% |
| B3 | the odd replay passes C2 and C3 at ε on at least 2 of 3 | 50% |
| B4 | its read (median est/err over \|err\| > 0.2) lies in [0.7, 1.4] on at least 2 of 3 | 50% |
| B5 | no case has C5 passing while C1 fails (no false accept) | 70% |
| B6 | run B's rows are 1.0–1.5× E6 committed's on all three, and below E6 committed + check | 55% |
| B7 | dry: the even replay's estimate has cos ≥ 0.8 with the odd one's over the 46 elasticities, and the even/odd ratio of rms lies in [0.4, 1.0] (it merges fewer intervals) | 45% |
| B8 | the bound B_q covers \|e_short\| in every quantity where \|e_short\| > 0.1ε, on at least 2 of 3 | 45% |
| B9 | the short spells' true error is ≤ ε/3 in every quantity on all three | 50% |
| B10 | nothing throws | 90% |
| B11 | the replay costs 0.55–0.8 of the run's CPU | 65% |

Process slip: the first launch of `run2.sh` changed ATOL to 3e-5 along with TOL (ATOL is the
absolute tolerance's factor on TOL; the setting keeps 1e-4). Both runs were stopped after
20 s, their files deleted, and the lanes relaunched with ATOL 1e-4.

### R12. Layout B at 3e-5: run, odd replay, even replay (dry), short-spell bisection (`run2.sh`, `score_b.R`) [m]

Ten gradient runs on libS, all exit 0; each replay on its run's exact steps. err against
refine's references (dry and long-wet the bank's, episodic-lma u429 → u857).

| | dry | long-wet | episodic-lma |
|---|---|---|---|
| nodes B (E6 c) | 183 (149) | 170 (157) | 146 (120) |
| short spells / replayed spells | 27 / 22 | 29 / 19 | 6 / 20 |
| worst err (q) / rms | **0.79** (a_l1) / 0.26 | **0.47** (a) / 0.12 | **0.76** (vcmax_25) / 0.40 |
| E6 committed worst / rms | 0.35 / 0.16 | 0.36 / 0.09 | 1.29 / 0.68 |
| ln J err / odd estimate | −0.258 / −0.247 | +0.011 / +0.052 | −0.229 / −0.190 |
| estimate max, cos(err, est), read | 0.79, 0.88, 0.87 | 0.35, 0.93, 0.75 | 0.64, 0.97, 0.82 |
| C1 C2 C3 C5 (C3 misses) | ✓ ✓ ✗ ✓ (2/9) | ✓ ✓ ✓ ✓ (0/1) | ✓ ✓ ✓ ✓ (2/26) |
| rms(err − est) | 0.12 | 0.05 | 0.12 |
| rows B / E6 c / E6 c + f (real rows) | 1.73 / 0.71 | 1.63 / 0.65 | 1.57 / 0.62 |
| steps B / E6 c (3e-5 against 1e-4) | 1.41 | 1.45 | 1.40 |
| rows at one tolerance (rows model on the pilot's steps) | 1.21 | 1.11 | 1.12 |
| CPU run / replay (s) | 308 / 191 (0.62) | 346 / 221 (0.64) | 159 / 87 (0.55) |
| short spells' true error, max (q) | 0.091 (stem_c) | 0.052 (root_P50) | 0.102 (root_P50) |
| their bound 2·\|e\|·P_short/P_rep, max | 0.013 | 0.010 | 0.002 |

- **Every run is within ε, and episodic-lma's is better than E6's** (0.76 against 1.29),
  but dry and long-wet are less accurate than E6 committed (0.79, 0.47 against 0.35, 0.37)
  with more nodes: the edge nodes bring back the error along M (a_l1 +0.79) that E6's inset
  cancels, as the h5 round found for its rule N.
- **The odd replay is honest in size and direction but misses one component.** Reads
  0.75–0.87, cos 0.88–0.97, no false accept. What it misses is root_P50 and
  storage_relaxation_offset: dry +0.41 / −0.49 against estimates −0.03 / −0.04; episodic-lma
  +0.47 / −0.63 against +0.05 / −0.29. Not the short spells (≤ 0.10ε there), not the
  tolerance floor (0.004–0.012 rms) [m]; the candidates left are the reference (dry's own move
  0.11ε) and the shutting side, where the hydraulic sensitivity's turn sits at a fixed 9–12 d
  before c, so a merged interval ending at c reads it off the square law (the closing
  round's δ(h − δ)) [i].
- **The even replay is not a second estimate of the same thing.** With an even interval
  count it removes the 2nd, 4th, … node, merges only each spell's middle pairs, and leaves
  both end intervals as they were. On dry it reads 0.37 of the error with cos 0.29, points
  along root_P50 −0.47 / omega +0.34, and differs from the odd replay by rms 0.17ε, max 0.50ε.
- **The short spells' error is small but the proxy bound does not cover it**: true error
  0.05–0.10ε (under ε/3 on all three), bound 0.002–0.013ε, 5–50× short.
- **Cost.** Run + replay ≈ 1.6 runs of B ≈ 2.5–2.8 E6 committed runs in real rows, close to
  E6's committed + check (2.4–2.6); most of B's excess is the tolerance (1.40–1.45× steps),
  the rest the edge nodes (×1.11–1.21 at one tolerance).

Scored: B1 holds (3/3 within ε); B2 refuted (1/3); B3 holds (long-wet, episodic-lma); B4
holds (3/3); B5 holds; B6 refuted (real rows 1.57–1.73× E6 committed, under E6 c + f); B7
refuted (cos 0.63); B8 refuted (the one quantity over 0.1ε uncovered; bound 5–50× short);
B9 holds (max 0.10); B10 holds; B11 holds (0.55–0.64).

**Against the revised design and vignette.**
- *Contradicted:* the parity replay. Both documents say removing the even nodes gives a
  second estimate that differs by 0–0.08ε. That number came from the omit-one maps on E6's
  layout. With even counts the even removal covers different intervals (it never merges a
  spell's end intervals), and on dry it differs by up to 0.50ε. A symmetric second estimate
  needs another construction (e.g. a second run with nodes shifted by half a share).
- *Contradicted:* "a bound for short spells" as proposed: the proxy-scaled bound
  under-covers 5–50×. The short spells' error itself is small here (≤ 0.10ε).
- *Contradicted in size:* "the breakpoints cost one node per edge, the same count as E6's
  insets". B has 8–23% more nodes than E6 committed (×1.11–1.21 rows at one tolerance), and
  3e-5 adds 1.40–1.45× steps.
- *Not borne out at full strength:* the replay reading 0.92–1.02 (a model of the
  interpolation part). Real reads are 0.75–0.87 and dry fails C3 on the root_P50 /
  storage_relaxation_offset component.
- *Borne out:* both edges as breakpoints (worst errors 0.47–0.79ε against D's 1.1–3.4ε, no
  false accept), even counts (every interval merged), the replay's cost (0.55–0.64), 3e-5's
  floor, and ages from T(t) (the layout ran with no absolute age).

Added to the scored table below: B1–B11.

| # | P | result |
|---|---|---|
| B1 | 55% | holds (3/3) |
| B2 | 35% | refuted (1/3) |
| B3 | 50% | holds (2/3) |
| B4 | 50% | holds (3/3) |
| B5 | 70% | holds |
| B6 | 55% | refuted (1.57–1.73) |
| B7 | 45% | refuted (cos 0.63) |
| B8 | 45% | refuted |
| B9 | 50% | holds (≤ 0.10) |
| B10 | 90% | holds |
| B11 | 65% | holds (0.55–0.64) |

## Round 3: grading the density toward each shutting (coordinator's request after R12)

## Pre-registration 10 (before `grade.R`)

Offline, on the closing fate maps (dry 7 and long-wet 10 covered long-spell zones; 3-d nodes
over each spell's last 120 d, root_P50 × 1.02 twins), integrands G (ln J) and G·s
(root_P50's elasticity; storage_relaxation_offset has no map, so root_P50 stands for the
missed component). For each zone: B's own nodes inside the covered window (from the first
kept node, so the odd removal is the one B's replay made), the interpolation error of B and
of its removal over [start, c], and the removal's read (Q_removed − Q_B)/3 against B's own
error. Then a graded density: ρ = ρ₀ · g(d), d the distance to c, g = (κ(d)/κ_far)^(1/3)
from the maps' median curvature profile of G·s (equal error per interval for a hat rule),
capped at the profile's own maximum, κ_far its median over 30–60 d before c; the count at
equal ρ-mass, even.

| # | prediction | P |
|---|---|---|
| R3a | under B's uniform density the removal reads the root_P50 interpolation error of the shutting zones at < 0.7 or > 1.4 on at least one case | 55% |
| R3b | the curvature profile rises over the last 12–21 d, and g reaches 2–3 at c | 50% |
| R3c | under the graded density the read lies in [0.8, 1.25] on both cases, and the zones' root_P50 interpolation error falls at least 2× | 45% |
| R3d | grading adds 1–3 nodes per long-spell shutting (dry: + 25–75 nodes over B) | 55% |

### R13. The shutting zones offline, uniform against graded (`grade.R`) [m, model]

Curvature profile of G·s (median over zones, relative to 30–60 d before c), and the grade
g = κ^(1/3):

| d before c (days) | 3–6 | 9 | 12 | 15 | 18 | 21 | 24 | 27 | ≥ 30 |
|---|---|---|---|---|---|---|---|---|---|
| dry κ (g) | 6.1 (1.83) | 5.6 (1.78) | 5.2 (1.73) | 4.4 (1.63) | 2.7 (1.39) | 1.6 (1.18) | 1.4 (1.11) | 1.3 (1.10) | 1 |
| long-wet κ (g) | 17.0 (2.57) | 14.4 (2.43) | 11.3 (2.25) | 7.1 (1.93) | 4.1 (1.60) | 2.8 (1.41) | 2.1 (1.27) | 1.6 (1.18) | 1 |

Interpolation part over [c − 117 d, c] of the fully covered zones (dry 20, long-wet 17):

| | dry: B | dry: graded | long-wet: B | long-wet: graded |
|---|---|---|---|---|
| intervals in these spells | 72 | 112 | 58 | 90 |
| root_P50 error (sum; sum of \|·\|) | −0.125 (0.125) | −0.044 (0.044) | −0.006 (0.011) | −0.0001 (0.004) |
| removal read, root_P50: on the sum / zone median | 0.75 / 0.75 | 0.90 / 0.90 | 0.33 / 0.56 | (sum ≈ 0) / 1.14 |
| ln J error; read on the sum / zone median | +0.024; 1.00 / 0.94 | +0.010; 0.74 / 0.72 | +0.011; 0.79 / 0.79 | +0.004; 1.04 / 1.00 |

- Under B's near-uniform spell density the removal under-reads the root_P50 interpolation
  error before shuttings (0.56–0.75 per zone): the merged interval ending at c spans the
  curvature's rise. Grading by κ^(1/3) over the last ~3 weeks cuts that error 2.7–2.9× and
  brings the read to 0.90 (dry) and 1.14 (long-wet), for +2 intervals per long-spell shutting.
- This is the interpolation part only, and on dry it is −0.125 against the missed
  component's +0.41 (opposite sign, the field carries the rest), so whether the grading fixes
  the run needs the run.
- Scored: R3a holds (long-wet 0.33 / 0.56); R3b refuted (the rise spans 18–27 d, but dry's g
  is 1.83 at c); R3c holds on the zone medians (0.90, 1.14; errors 2.9× and 2.7× smaller;
  long-wet's summed error cancels to ~0, so its summed read means nothing); R3d holds (+2.0
  and +1.9 per shutting).

## Pre-registration 11 (before building the dry layouts and the three runs)

Runs on dry, libS, TOL 3e-5, as round 2: **B2** (B with every panel's count doubled at the
same ρ₀ quantiles, so B is exactly B2's removal case; B's error ≈ (4/3)(Q_B − Q_B2), with
3e-5's step noise); **Bg** (B with ρ₀ × g(d) toward every shutting breakpoint, dry's profile
above; counts even, one-interval spells by the same rule); **Bg's odd replay**.

| # | prediction | P |
|---|---|---|
| R3e | (4/3)(Q_B − Q_B2) matches B's reference error within 0.15ε in both root_P50 (+0.41) and storage_relaxation_offset (−0.49): the reference is right and B's replay read that component off the law | 45% |
| R3f | Bg's root_P50 and storage_relaxation_offset errors are each ≤ 0.25ε and its worst ≤ B's 0.79 | 40% |
| R3g | Bg's replay passes C2 and C3 at ε with a read in [0.8, 1.25] | 45% |
| R3h | Bg has 20–60 more nodes than B (183) | 55% |
| R3i | B2's own error (against the reference) has worst ≤ 0.35 | 50% |

Schedules built (before any run): B2 318 nodes, nested over B (B is exactly its odd
removal); Bg 186 nodes (B + 3), rows model ×1.23 E6 committed (B ×1.21, B2 ×2.10). Grading
B's own ρ₀ rarely moves a spell's even count (the grade adds ~0.2 interval of mass per spell),
so Bg mostly redistributes B's nodes toward each shutting. The offline model above had given
each graded spell its own even ceiling of the graded mass, +2 intervals per spell. The same
model with the count held (`grade_fixed.R` in the scratchpad): dry root_P50 interpolation
error −0.125 → −0.096, read 0.75 → 0.97 (zone median 0.96); long-wet zone read 0.56 → 0.78.
So Bg tests the read at almost no cost; the error itself falls little. R3h is refuted by the
schedule (+3, not 20–60).

### R14. Round 3 runs on dry: B2 (doubled), Bg (graded) and its replay (`run3.sh`, `score_r3.R`) [m]

Three gradient runs, libS, 3e-5, all exit 0; Bg's replay on Bg's exact steps.

| | ln J | root_P50 | storage_rel._offset | a_l1 | omega | TF24_cost_scale | a | worst | rms |
|---|---|---|---|---|---|---|---|---|---|
| B: error | −0.26 | +0.41 | −0.49 | +0.79 | −0.31 | +0.45 | −0.48 | 0.79 | 0.26 |
| B: odd replay | −0.25 | −0.03 | −0.04 | +0.79 | −0.09 | +0.33 | −0.46 | | |
| B: (4/3)(Q_B − Q_B2) | −0.27 | +0.26 | −0.34 | +0.92 | −0.32 | +0.55 | −0.52 | | |
| B2: error | −0.05 | +0.21 | −0.23 | +0.10 | −0.07 | +0.04 | −0.09 | 0.23 | 0.075 |
| Bg: error | −0.25 | +0.15 | −0.37 | +0.78 | −0.11 | +0.44 | −0.45 | 0.78 | 0.23 |
| Bg: odd replay | −0.21 | +0.12 | −0.06 | +0.72 | −0.13 | +0.28 | −0.41 | | |

- **The reference is right; the component is off the square law.** The doubled run reads
  B's error with cos 0.97, read 1.04, rms(err − est) 0.06; root_P50 and
  storage_relaxation_offset come within 0.15ε. But that component only halves per doubling
  (+0.41 → +0.21, −0.49 → −0.23: order ≈ 1) while the rest falls 5–8× (a_l1 +0.79 → +0.10,
  ln J −0.26 → −0.05). Between B and its removal it barely moves, between B2 and B it moves:
  the signature of a fixed-position feature that intervals straddle (the shutting turn,
  δ(h − δ)), not of a wrong reference. The doubling pair's estimate of B2 itself reads
  0.02–0.08ε on those quantities against 0.15–0.23 (rms ratio 0.90 overall; all under ε/3).
- **Grading moves root_P50, not the storage offset.** Bg (B's nodes redistributed toward
  each shutting by κ^(1/3), +3 nodes) cuts root_P50 from +0.41 to +0.15 and its replay now
  reads it (+0.12); storage_relaxation_offset stays −0.37 and its replay still reads −0.06.
  Bg passes C1–C5 at ε (C3 1 of 8 missed, within the allowance), read 0.83, cos 0.945; worst
  0.78 (a_l1, which the replay reads: +0.72).
- Scored: R3e holds at the boundary (both 0.15ε); R3f refuted (storage offset 0.37); R3g holds
  (C2, C3 pass, read 0.83); R3h refuted by the schedule (+3); R3i holds (0.23).

**Cost [m at 3e-5; i at 1e-4].** Nodes: Bg 186, B 183, E6 committed 149 (+25%); grading adds
3. Real rows at 3e-5: Bg 1.75× E6 committed at 1e-4, 0.72× E6 committed + check; run +
replay ≈ 1.75 × 1.62 = 2.8 E6 committed runs against E6's 2.4. At 1e-4 the steps are E6's
(B's 3e-5 runs took 1.40–1.45× E6's steps), so Bg would cost about 1.23× E6 committed (rows
model) and run + replay about 2.0, under E6's 2.4.

**Would 1e-4 plus a tolerance term serve?** [m from earlier rounds; i for the rule.] The 5%
nudge at 1e-4 measures step noise: rms 0.023–0.024ε, max 0.08, along M 0.06–0.09 (h5, closing
rounds). The tolerance's bias, 1e-4 against 3e-5 on one schedule (refine round, five cases),
is rms 0.003–0.028, max 0.013–0.108. Measuring the nudge on each run costs a full unpinned run
(0.7 of a 3e-5 run), so 1e-4 + a measured nudge costs more than 3e-5 alone. A fixed reserve
does serve: 1e-4 with every quantity held to ε − 0.12ε (the largest measured shift, 0.108,
plus margin) costs 0.70 of the 3e-5 runs and, on dry, still leaves Bg's worst error (0.78)
under the reduced target. The reserve is measured on five cases only; refresh it with one
nudge per case, not one per run.

**Against the revised design and vignette (round 3).**
- *Contradicted:* "order 2 inside a spell" once both edges are breakpoints. On dry the
  root_P50 / storage-offset component falls at order ≈ 1, so a removal's /3 cannot read it
  and doubling under-reads it too ("When doubling is enough" holds for B, read 1.04, but its
  estimate of the doubled run misses the same component).
- *Partly borne out:* grading toward each shutting by the measured curvature (κ^(1/3) over
  the last 18–27 d) fixes root_P50 and the replay's read of it at +3 nodes, but not the
  storage offset. Whatever carries the storage offset is still unlocated: the shutting turn
  in a trait the maps did not difference is the first candidate.

| # | P | result |
|---|---|---|
| R3a | 55% | holds |
| R3b | 50% | refuted (g 1.83 at c on dry) |
| R3c | 45% | holds on zone medians |
| R3d | 55% | holds (+2 per shutting, model) |
| R3e | 45% | holds at the boundary (0.15ε) |
| R3f | 40% | refuted (storage offset 0.37) |
| R3g | 45% | holds (read 0.83) |
| R3h | 55% | refuted (+3 nodes) |
| R3i | 50% | holds (0.23) |

## Round 4: locating the storage offset's order-1 component (coordinator's request after R14)

Code read before the predictions (libS `tf24_strategy.h`): the storage rate is
(charge·(1 − r) − drain·r) / (1 + relaxation_rate · storage_relaxation_offset); mortality
is d_I + a_dG1·exp(−a_dG2·r), smooth in r, with one hard switch: a cohort whose cumulative
mortality reaches `establishment_failure_hazard` (750) is parked at rate 0. The only
per-node switch record in saved runs is `splits` (steps split at a sign change of net
production, per node).

## Pre-registration 12 (before `twin.R` runs and before any per-node record is read)

One forward run on the closing fate map's schedule (dry, 1172 nodes, libS, 1e-4) with
storage_relaxation_offset × 1.02, keeping each node's peak drydown hazard (from its
mortality's increments, less d_I) and so its lowest relative reserve
r_min = −ln(h_max/a_dG1)/a_dG2. s_sro(b) = (ln nrr_twin − ln nrr_base)/ln 1.02 against
`cl_map_dry`.

| # | prediction | P |
|---|---|---|
| R4a | s_sro's non-smooth part (κ at h = 3 d) is largest within 15 d before shuttings, not in spell interiors | 55% |
| R4b | s_sro has a slope jump (\|Δ²_2h\|/\|Δ²_h\| ≤ 2.8 at h = 3 d) where neighbouring cohorts' r_min crosses 0.15, on at least half of the covered spells | 25% |
| R4c | s_sro's curvature rises toward c more steeply than root_P50's (κ at c over κ at 30–60 d at least 2× root_P50's ratio, 6.1) | 50% |
| R4d | per-node `splits` changes between neighbours only next to pilot edges (≥ 90% of changes within one node of an edge) on the u857 references | 50% |
| R4e | no saved per-node record marks a reserve threshold (the code has no such switch) | 80% |

### R15. The storage offset's sensitivity on the fate map (`twin.R`, `twin_analyze.R`, `splits.R`) [m]

One forward run (1172 nodes, 474 s): J 1.19165 against the base 1.20262, so
d ln J / d ln storage_relaxation_offset = −0.46 on dry.

- **No reserve threshold is crossed between neighbours.** In all 20 covered shutting zones
  every cohort's peak drydown hazard is at the ceiling, r_min = 0.00004–0.001 from 36 d
  before c to c: every cohort near a shutting empties its reserves, so all neighbours sit on
  the same side of 0.15. No cohort reaches the parked hazard (max cumulative mortality 14–19
  against 750). The hypothesis's switch does not occur here (R4b refuted).
- **s_sro's curvature rises earlier and wider than root_P50's.** Curvature of G·s relative to
  30–60 d before c: storage offset 2.5 at 24 d, 3.9 at 21 d, 6.7–12 over 3–18 d (a plateau,
  11.6 at c), with a dip below 1 over 27–39 d; root_P50 1.3 at 24 d, rising to 6–8 over 3–12 d.
  Slope-jump candidates (κ > 5× the zone median with ratio ≤ 2.8) are not concentrated near c
  (storage offset: 7 within 15 d, 59 farther out, where the curvature is small and noisy). So
  near shuttings the storage offset's integrand is smooth but curved over about three weeks,
  not kinked (R4a holds as a curvature statement; R4c refuted narrowly, 11.6 against the 12.2
  needed).
- **Its interpolation part is small and read with the wrong sign.** Over the covered zones the
  interpolation error of G·s_sro is +0.026ε under B, and B's removal reads −0.35 of it; graded
  at the same count +0.013ε (read −0.12); graded with two more intervals +0.003ε. The missed
  −0.49 on dry is therefore field, not the interpolation of fate's sensitivity, and the maps
  (which hold fate, not leaf area or uptake) cannot place it.
- **Per-node records.** `splits` is a cumulative count of split steps, not a count of sign
  changes: it changes between neighbours next to an edge 47–75% of the time and away from edges
  for the rest (flat-al1125 119 of 360 changes, dry-lma125 119 of 226, dry map 52 of 146), so
  it does not mark switches cleanly (R4d refuted). Nothing records reserves or a mortality
  regime per node (R4e holds). A counter that would: per node, the number of P sign changes
  (not split steps), and the birth-ordered sequence of drydowns in which r fell below a set
  level, both recorded in the forward run; for the field, per node the time-integrated
  leaf area and uptake its interval contributes, whose curvature in birth date is what the
  storage offset's field error is made of.

**Located?** Not as a slope jump at a fixed birth date. What the data place: the storage
offset's per-cohort sensitivity curves hardest over the last ~3 weeks before each shutting
(wider than root_P50's), its interpolation part there is small, and B2 shows its total halves
per doubling. Whether its field part lives in those same three weeks is the one thing a run can
answer cheaply: B with two more intervals per replayed spell, graded toward each shutting by
max(κ_root_P50, κ_sro)^(1/3). If the storage offset falls as in B2 (−0.49 → −0.23) at +2 nodes
per spell instead of doubling everything, it lives there.

## Pre-registration 13 (before building Bga and its two runs)

Bga: B with each replayed spell's count raised by 2, placed at equal mass of ρ₀·g(d), g =
max of the two grades above (root_P50 from R13, storage offset from R15); one-interval spells
unchanged; dry, libS, 3e-5; then its odd replay.

| # | prediction | P |
|---|---|---|
| R4f | Bga's storage_relaxation_offset error is ≤ 0.25ε (B −0.49, Bg −0.37, B2 −0.23) | 40% |
| R4g | Bga's root_P50 error is ≤ 0.15ε | 55% |
| R4h | Bga's replay passes C2, C3 and C5 at ε with a read in [0.8, 1.25] | 45% |
| R4i | Bga has 35–55 more nodes than B (183) | 60% |

### R16. Bga on dry: two more intervals per spell, graded into the last three weeks (`run3.sh Bga`, `score_r3.R`) [m]

| dry | nodes | ln J | root_P50 | storage offset | a_l1 | TF24_cost_scale | a | worst | rms |
|---|---|---|---|---|---|---|---|---|---|
| E6 committed (1e-4) | 149 | −0.15 | −0.31 | | | | −0.35 | 0.35 | 0.16 |
| B | 183 | −0.26 | +0.41 | −0.49 | +0.79 | +0.45 | −0.48 | 0.79 | 0.26 |
| Bg (redistributed) | 186 | −0.25 | +0.15 | −0.37 | +0.78 | +0.44 | −0.45 | 0.78 | 0.23 |
| B2 (every count doubled) | 318 | −0.05 | +0.21 | −0.23 | +0.10 | +0.04 | −0.09 | 0.23 | 0.075 |
| **Bga** | **232** | −0.07 | −0.05 | **−0.11** | +0.36 | +0.28 | −0.25 | **0.36** | 0.13 |
| Bga, odd replay | | −0.06 | +0.00 | −0.04 | +0.31 | +0.21 | −0.24 | | |

- **The order-1 component lives in the last ~3 weeks before each shutting, field part
  included.** Two more intervals per replayed spell placed there (+49 nodes) take the storage
  offset from −0.49 to −0.11 and root_P50 from +0.41 to −0.05, more than doubling every count
  does (B2: −0.23, +0.21, at +135 nodes).
- **The replay is honest on Bga**: read 0.97, cos 0.976, C1–C5 pass (C3 0 of 1); worst 0.36
  (a_l1), next to E6 committed's 0.35.
- Cost: Bga 232 nodes (E6 committed 149, +56%); real rows at 3e-5 2.21× E6 committed, 0.91×
  E6 committed + check; at 1e-4 (rows model) 1.53× E6 committed, so run + replay ≈ 2.45 E6
  committed runs, level with E6's committed + check (2.43), with the run's own honest
  estimate in place of the pair [i].
- Scored: R4f holds (−0.11); R4g holds (−0.05); R4h holds (read 0.97); R4i holds (+49).

**Answer to step 3.** No fixed birth date to add as a breakpoint was found (no kink, no reserve
crossing). One more grading does remove it: density toward each shutting by
max(κ_root_P50, κ_storage-offset)^(1/3) over the last 24–27 d (g ≈ 2 over the last 18 d), with the
spell's count raised so the grading adds nodes rather than only moving them (+2 intervals
per replayed spell; dry +49 nodes, 22 replayed spells). Equivalently, a node density that
follows the measured curvature profile rather than a09's spacing in the last three weeks.

| # | P | result |
|---|---|---|
| R4a | 55% | holds as curvature (largest within 3–18 d), not as a kink |
| R4b | 25% | refuted (every cohort near c empties its reserves) |
| R4c | 50% | refuted narrowly (11.6 against 12.2) |
| R4d | 50% | refuted (47–75% of changes next to edges) |
| R4e | 80% | holds |
| R4f | 40% | holds (−0.11) |
| R4g | 55% | holds (−0.05) |
| R4h | 45% | holds (read 0.97) |
| R4i | 60% | holds (+49) |

## Round 5: the grading from the first run, and the real test (coordinator's request after R16)

Code read before the predictions (libS `tf24_strategy.h`, storage rate): once net production P
is negative the charge is ≈ 0 and the drain is −P, so dS/dt = −drain·r / (1 + (drain/S_max)·o),
o = storage_relaxation_offset. In a seedling drain/S_max is hours⁻¹, so dr/dt ≈ −r/o: **after
P turns negative every seedling's relative reserve decays with the same e-fold time o (7 d),
whatever its size or drain**. While P > 0 the growth gate is ≈ 1 above r ≈ 0.4, so the charge is
small and growth dilutes r from the newborn's a_st3 = 0.8 toward ≈ 0.4–0.5 [i, from the rate
form]. Hazard a_dG1·exp(−a_dG2·r) reaches a_dG1/e at r = 1/a_dG2. So the candidates:

- **t_r (parameters):** how long a newborn's reserves last once P < 0, from a_st3 to the hazard's
  e-fold point: t_r = o · ln(a_st3 · a_dG2) = 7 · ln 16 = **19.4 d** [i] (epi-adG208: 17.8 d;
  lma, hmat, root_P50, a_l1 do not enter).
- **t_e (first run / storage trajectories):** days from the shutting until the cohort born at
  the shutting reaches r = 1/a_dG2; t_r plus the delay before its P turns negative.
- **L (first run):** the drought's length, days from the shutting to the next opening.

**Measured width.** Per profile (curvature of G·s or G in 3-d bins of days before c, relative to
its 30–60 d median, running median of 3), g = max(κ, 1)^(1/3); W½ = the largest d where g is
still ≥ (1 + g_max)/2, g_max the largest g within 21 d; W_on = the largest d ≤ 45 where g ≥ 1.08.
Height = g_max. On the median profiles already published (R13, R15) these are W½ ≈ 16–21 d,
W_on ≈ 25–29 d, g_max 1.9–2.5; those are not predictions. Per zone the same, on each zone's own
profile. References' integrands (u429/u857, 34/17-d uniform spacing) cannot resolve a 25-d rise
[m: spacing]; the res runs (`cl_res_*`, nodes at c − {36, 28, 21, 15.5, 11, 7.5, 4.5, 2, 0} d on
dry, dry-p50, dry-flat, long-wet) give G's profile on two more cases, coarsely.

## Pre-registration 14 (before `r5_width.R` and before any per-zone profile is read)

| # | prediction | P |
|---|---|---|
| R5a | per-zone W½ does not track the drought length: \|Spearman ρ(W½, L)\| < 0.3, pooled over dry and long-wet root_P50 zones | 60% |
| R5b | per-zone height does track it: ρ(g_max, L) > 0.3 (pooled) | 45% |
| R5c | t_e on dry (traj map, cohorts born at c on its 4 edges) is 15–30 d on every edge with a gap > 30 d | 50% |
| R5d | G's own median profile (ln J's integrand, maps) has W½ within 30% of root_P50's on both dry and long-wet | 40% |
| R5e | on the res runs G's W½ on dry-p50 and dry-flat is within 30% of dry's (same res grid) | 50% |
| R5f | t_r predicts W½ within 30% on every per-case profile, the res-run ones included | 60% |

### R17. The rise's width and height against the candidates (`r5_width.R`) [m]

| profile (median over zones) | zones | W½ (d) | W_on (d) | g_max | W½ / t_r |
|---|---|---|---|---|---|
| dry, root_P50 | 20 | 17.5 | 29.7 | 1.92 | 0.90 |
| dry, storage offset | 20 | 21.4 | 26.3 | 2.09 | 1.10 |
| dry, G (ln J) | 20 | 14.6 | 20.8 | 1.87 | 0.75 |
| long-wet, root_P50 | 18 | 15.9 | 32.4 | 2.43 | 0.82 |
| long-wet, G | 18 | 16.7 | 25.3 | 1.92 | 0.86 |
| res grid, G: dry / dry-p50 / dry-flat / long-wet | 24 / 24 / 35 / 28 | 14.4 / 15.6 / 15.3 / 16.8 | (grid ends at 36 d) | 1.77 / 1.66 / 1.76 / 1.98 | 0.74 / 0.80 / 0.79 / 0.87 |

- **The width is the same on every case and does not follow the drought.** Per zone, root_P50's
  W½ has median 16.9 d (IQR 15.5–19.5, 38 zones); its rank correlation with the drought length L
  is −0.14 pooled (dry −0.29, long-wet −0.04), and dry's short-gap zones (< 20 d) are as wide as
  its long-gap ones (19.3 against 16.8 d). The storage offset's zones correlate +0.39 with L, but
  span only 18–22 d. G's own rise has the same width as root_P50's (14.6 against 17.5 dry, 16.7
  against 15.9 long-wet), so the res runs' G profiles extend the check to dry-p50 and dry-flat:
  15.3–15.6 d, against dry's 14.4 on the same grid.
- **t_r = o·ln(a_st3·a_dG2) = 19.4 d predicts every W½ within 26%** (ratios 0.74–1.10, median
  0.85). L does not predict it (zones of 14–75 d droughts have one width); t_e is t_r plus a day
  (below), so it adds nothing a first run is needed for.
- **t_e on the traj map** (dry, 4 edges): a cohort born at c reaches r = 0.05 at 20 d after c
  on both long-gap edges (gaps 65, 75 d) and 25 d on the 29-d gap; cohorts born 12–36 d
  before c enter the drought at r 0.24–0.28 and reach 0.05 at 15–22 d. Before a 14-d gap the
  cohort born at c never empties (rain returns first). Reserves are spent within days of birth
  in the last weeks of a spell (r < 0.3 four days after birth at c − 12 d), so the advantage a
  late birth carries into the drought is its unspent seed reserve [m for r, i for the reading].
- **The height has no first-run predictor here.** Per zone g_max (median 2.26 for root_P50)
  correlates +0.14 with L pooled (G: +0.55; dry's short-gap zones 1.56 against 2.18, long-wet's
  2.69 against 2.67). Per case it is 1.9–2.4 for the sensitivities, 1.7–2.0 for G. A fixed
  height, the dry profile's (max of root_P50 and storage offset, g ≈ 2.2 at c), is what the run
  below uses.
- References' integrands (34/17-d uniform spacing) cannot resolve the rise [m: spacing].

Scored: R5a holds (ρ −0.14); R5b refuted (ρ +0.14); R5c holds (20, 20 d); R5d holds (0.83, 1.05);
R5e holds (1.08, 1.06 × dry's); R5f holds (0.74–1.10).

**How t_r behaves across cases and traits [i].** It holds no record quantity, so it is the
same on every rainfall record; it moves only with storage_relaxation_offset (linearly),
a_st3 and a_dG2 (logarithmically). lma, hmat, root_P50, a_l1 leave it unchanged (dry-p50's
res width 15.6 against dry's 14.4 agrees); a_dG2 ×0.8 shortens it 8% (17.8 d), which no run
here can resolve. A test that would separate t_r from "a constant that happens to fit": a
fate map with the storage offset doubled, where t_r predicts a width of about 2×.

## Pre-registration 15 (before the doubled-offset map run is launched)

One forward run (`twin.R`, dry, the closing fate map's schedule, 1e-4, the map's setting) with
storage_relaxation_offset × 2 (t_r 38.8 d). G's profile on it (ln J's integrand) against the
base map's, both with the far window moved to 60–100 d (so a doubled rise is not in it), W½ by
the same rule with g_max taken within 42 d and W read out to 80 d.

| # | prediction | P |
|---|---|---|
| R5g | G's W½ at the doubled offset is 1.5–2.5× the base map's | 45% |
| R5h | it is at least 1.25× the base's (the width moves with the offset at all) | 65% |

## Pre-registration 16 (before any run of the real test; layouts built by `layout5.R`)

Layout **G5** per case: B's breakpoints and ρ₀ (ages from T(t); epi-adG208 takes episodic's
t₅₀/t₉₀, 17.9/25.3 y [i], having no node-record run), graded toward each shutting by dry's
measured grade (max of root_P50's and the storage offset's κ^(1/3)) stretched by
t_r(case)/t_r(dry), two more intervals per replayed spell, even counts, one-interval short
spells. The reconstruction of Bga's grade gives Bga's panel counts exactly on dry (232 nodes)
with node positions within 1.5 d of Bga's [m]. Held-out case: **epi-adG208** (episodic,
a_dG2 ×0.8: the drydown trait, the only held-out move that changes t_r; E6 committed's worst
error is root_P50 0.39; reference u215 → u429, own move 0.14ε).

| case | t_r (d) | nodes G5 (B, E6 c) | replayed / short spells | rows model × E6 c |
|---|---|---|---|---|
| dry | 19.4 | 232 (183, 149) | 23 / 26 | 1.53 |
| long-wet | 19.4 | 217 (170, 157) | 22 / 26 | 1.41 |
| episodic-lma | 19.4 | 201 (146, 120) | 23 / 3 | 1.53 |
| dry-flat | 19.4 | 271 (227, 191) | 20 / 65 | 1.40 |
| epi-adG208 | 17.8 | 195 (149, 134) | 18 / 12 | 1.38 |

Runs (`run5.sh`), libS, E6 committed's setting at TOL **1e-4**: G5, its pinned odd replay G5o,
and G5b (every short spell bisected, unpinned) for the short spells' true error
e_short = (4/3)(Q_G5 − Q_G5b), which carries 1e-4's step noise (≈ 0.024ε rms). Scored against
the references (`refine/lib.R` ref_ladder) with every criterion at **0.88ε**: C1 |err| ≤ 0.88;
C2 est > 0.22 where |err| > 0.44; C3 sign and ×½–×2 on quantities where max(|err|, |est|) >
0.29, at most max(1, 20%) missed; C4 no throw; C5 every |est| ≤ 0.88.

| # | prediction | P |
|---|---|---|
| R5i | every case's worst error ≤ 0.88ε | 50% |
| R5j | the replay passes C1–C5 at 0.88ε on at least 4 of 5 | 55% |
| R5k | no false accept (C5 passing while C1 fails) on any case | 75% |
| R5l | read (median est/err over \|err\| > 0.2) in [0.8, 1.25] and cos ≥ 0.9 on at least 4 of 5 | 40% |
| R5m | dry: G5 at 1e-4 against Bga at 3e-5 differs by ≤ 0.15ε in every quantity | 55% |
| R5n | root_P50 and the storage offset are each within 0.3ε on every case | 50% |
| R5o | real rows of G5 ≤ 1.6× E6 committed on every case, and G5 + replay ≤ E6 committed + check on at least 3 of 5 | 45% |
| R5p | the short spells' true error ≤ ε/3 in every quantity on every case | 55% |
| R5q | nothing throws | 90% |

### R18. The doubled storage offset doubles the width (`run5_map.sh`, `r5_sro2.R`) [m]

One forward run, 1172 nodes, 515 s, exit 0 (J 0.747 against 1.203). G's rise before dry's 20
covered shuttings, far window 60–100 d:

| | W½ median profile (d) | W½ per zone, median (IQR) | W_on | g_max |
|---|---|---|---|---|
| storage offset 7 d (t_r 19.4) | 14.9 | 16.0 (14.2–22.3) | 18 | 1.70 |
| storage offset 14 d (t_r 38.8) | **36.0** | **34.7** (31–46) | 42 | 1.69 |
| ratio | **2.42** | 2.17 | 2.3 | 1.0 |

- **The width follows the storage offset, as t_r says (×2.0 predicted, ×2.2–2.4 measured).**
  Together with R17 (no dependence on the drought, on root_P50 ×1.2, or on the record) this
  makes t_r the grading's width, not a constant that happens to fit dry.
- **The shape stretches but does not simply rescale.** At 14 d the curvature is a hump: 1.9 over
  the last 12 d, 4.8 at 21–24 d, back to 1.1 by 45 d; at 7 d it is highest at c (4.9 over 3–6 d).
  So a template stretched by t_r overweights the last days when t_r grows; the hump sits near
  0.6 t_r before c [i]. The height (g_max) is unchanged.
- Scored: R5g holds (2.42, at the top of 1.5–2.5); R5h holds.

### R19. The real test: G5 at 1e-4 on five cases (`layout5.R`, `run5.sh`, `score_r5.R`) [m]

Fifteen gradient runs on libS at 1e-4, all exit 0; every replay on its run's exact steps.
Errors against the references (dry, long-wet, dry-flat the bank's; episodic-lma u429 → u857;
epi-adG208 u215 → u429, own move 0.14ε); criteria at 0.88ε.

| | dry | long-wet | episodic-lma | dry-flat | epi-adG208 (held out) |
|---|---|---|---|---|---|
| nodes G5 / E6 c / E6 f | 232 / 149 / 219 | 217 / 157 / 234 | 201 / 120 / 182 | 271 / 191 / 258 | 195 / 134 / 205 |
| worst err (q) / rms | **0.33** (a_l1) / 0.11 | **0.33** (a) / 0.08 | **0.54** (lma) / 0.28 | **0.56** (a) / 0.16 | **0.30** (a_l1) / 0.09 |
| E6 committed worst / rms | 0.35 / 0.16 | 0.36 / 0.09 | 1.29 / 0.68 | 0.58 / 0.18 | 0.39 / 0.14 |
| root_P50 / storage offset err | +0.00 / −0.12 | −0.03 / +0.07 | −0.07 / −0.23 | −0.09 / −0.15 | −0.05 / −0.10 |
| estimate max / cos / read | 0.33 / 0.95 / 1.01 | 0.27 / 0.99 / 0.84 | 0.47 / 1.00 / 0.83 | 0.43 / 0.96 / 0.82 | 0.35 / 0.71 / 1.17 |
| rms(err − est) | 0.046 | 0.014 | 0.049 | 0.050 | 0.059 |
| C1 C2 C3 C4 C5 at 0.88ε (C3 misses) | ✓✓✓✓✓ (0/1) | ✓✓✓✓✓ (0/1) | ✓✓✓✓✓ (0/15) | ✓✓✓✓✓ (0/4) | ✓✓✓✓✓ (0/1) |
| short spells' true error, max (q) / rms | 0.10 (root_P50) / 0.03 | 0.05 (root_P50) / 0.02 | 0.09 (storage offset) / 0.02 | 0.22 (a_l1) / 0.07 | 0.16 (TF24_cost_scale) / 0.06 |
| cos(est, err − short spells' error) | 0.96 | 0.98 | 1.00 | 0.94 | 0.96 |
| real rows G5 / E6 c | 1.60 | 1.47 | 1.66 | 1.48 | 1.48 |
| G5 + replay / E6 c | 2.66 | 2.47 | 2.61 | 2.62 | 2.38 |
| G5 + replay / (E6 c + check) | 1.09 | 0.99 | 1.02 | 1.10 | 0.92 |
| replay share of the run: CPU / rows | 0.58 / 0.66 | 0.60 / 0.68 | 0.51 / 0.57 | 0.66 / 0.77 | 0.54 / 0.60 |
| steps / E6 c's | 1.06 | 1.05 | 1.10 | 1.06 | 1.08 |

- **Every case is within 0.88ε, the replay reads it, and nothing is falsely accepted.** Worst
  0.30–0.56ε, at or below E6 committed's on all five (episodic-lma 0.54 against 1.29). Read
  0.82–1.17, cos 0.95–1.00 except epi-adG208 (0.71), whose errors are all small (≤ 0.30) and
  whose unread part is its short spells: against the error less the short spells', cos is 0.96.
- **The shutting component stays fixed on new records and on the held-out trait.** root_P50
  and the storage offset are within 0.23ε everywhere (B at 3e-5 had them at 0.4–0.6 on dry and
  episodic-lma).
- **dry at 1e-4 against Bga at 3e-5:** max 0.10ε (TF24_cost_scale), rms 0.03: inside the
  0.12ε reserve, with a reconstructed grade that moves nodes by up to 1.5 d.
- **Short spells:** true error 0.05–0.22ε, under ε/3 on all five, but larger on dry-flat (65
  short spells) and epi-adG208 than the 0.05–0.10 of round 2's three cases. Each estimate
  carries 1e-4's step noise (≈ 0.024 rms).
- **Cost.** G5 has 1.38–1.68× E6 committed's nodes and 1.47–1.66× its real rows (steps only
  1.05–1.10×: the excess is nodes). Run + replay is 0.92–1.10× E6 committed + check, so level
  with E6's pair, with the run's own estimate and E6 committed's accuracy or better.

Scored: R5i holds (≤ 0.56); R5j holds (5/5); R5k holds; R5l holds (read 5/5 in band, cos ≥ 0.9
on 4/5); R5m holds (0.10); R5n holds (≤ 0.23); R5o refuted (rows 1.60 and 1.66 on dry and
episodic-lma; run + replay under E6's pair on 2 of 5); R5p holds (≤ 0.22); R5q holds.

| # | P | result |
|---|---|---|
| R5a | 60% | holds (ρ −0.14) |
| R5b | 45% | refuted (ρ +0.14) |
| R5c | 50% | holds (20, 20 d) |
| R5d | 40% | holds |
| R5e | 50% | holds |
| R5f | 60% | holds (0.74–1.10) |
| R5g | 45% | holds (2.42) |
| R5h | 65% | holds |
| R5i | 50% | holds (≤ 0.56) |
| R5j | 55% | holds (5/5) |
| R5k | 75% | holds |
| R5l | 40% | holds |
| R5m | 55% | holds (0.10) |
| R5n | 50% | holds (≤ 0.23) |
| R5o | 45% | refuted |
| R5p | 55% | holds (≤ 0.22) |
| R5q | 90% | holds |

**Against the design and the vignette (round 5).**
- *Contradicted:* design, "The breakpoints cost one node per edge. With a09's density the
  layout has 8–23% more nodes than E6's committed run." With the grading and its two intervals
  per spell, which the design now commits to, the layout has 38–68% more nodes (1.47–1.66× real
  rows); run + replay is still level with E6's pair (0.92–1.10).
- *Contradicted across traits:* vignette, "The density rises about 2× over the last 18 days,
  tapering to 1 by 27, and each spell gets two more intervals for it." (and the design's "about
  2× over 18 days tapering to 1 by 27"). That holds for storage_relaxation_offset = 7 d; the
  width is t_r = o·ln(a_st3·a_dG2) and doubles with o (R18), so the days must be t_r's.
- *Contradicted in size:* design, "their true error was 0.05–0.10ε on the three cases", and the
  vignette's "their error was 0.05–0.10ε": on dry-flat and epi-adG208 it is 0.22 and 0.16ε.
- *To change, not contradicted:* "Open: take the grading's width from the first run": it comes
  from the parameters, not the first run; nothing in the first run (drought length, record)
  moves it. The vignette's "set by the seedling's starting reserves" is right in kind; the
  quantity is how long they last once production turns negative. Algorithm step 3 ("run at a
  tolerance whose own error is under ε/10 (3e-5)") is not needed: 1e-4 with 0.88ε passed
  everywhere, as the design's "Still open" proposes.
- *Borne out:* the replay's read with the grading (0.82–1.17), no false accept, "at 1e-4, run
  plus replay ≈ E6's committed plus check" (0.92–1.10), the replay's cost (0.51–0.66 of a run in
  CPU, 0.57–0.77 in rows).
