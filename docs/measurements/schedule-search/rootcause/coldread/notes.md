# Cold read: docs/vignettes/node-schedules.Rmd

Lens: Cold Reader (`.claude/skills/code-review/lenses.md`, Lens 1), applied to a
document. Read only the title, "The whole thing" with its code block, the section
headings, the loop diagram and the "What it adapts to" table before writing the
predictions below. Honesty: I had not read the body, the design note or any
measurement note when these were written.

## 1. Predictions from the surface (written before the body)

Title and opening:

- P1 **Schedule.** A node schedule is the set of birth dates at which cohorts are
  introduced, treated as the points of a quadrature rule for an integral over
  birth date (J, offspring per recruit summed over births). It is fully described
  by breakpoints plus a density; nothing else.
- P2 **Breakpoint.** A birth date where a recruit's fate (its lifetime offspring
  as a function of birth date) has a kink, not a jump. Nodes are placed exactly
  on it so no interval straddles a kink. Found by one forward run.
- P3 **Node density.** Number of nodes per unit birth date on each stretch
  between breakpoints. Not uniform: higher where fate curves. Nodes are evenly
  spaced inside a stretch, since "density" and "even number of intervals" are
  what the loop scales.
- P4 **Replay.** Re-run the same simulation, reusing the run's own ODE steps
  (same step sequence, no new step control), but with half the nodes (every
  other one between breakpoints) dropped. Cheaper than a full run.
- P5 **Error estimate.** (half-node answer − full answer) / 3 is the error of the
  full answer; this is Richardson for a second-order rule (2² − 1 = 3). Applies
  to every quantity: ln J, gradients, curvatures.
- P6 **Loop stopping.** Stops when every quantity's estimate is under its ε, or
  when a pass cap is hit (reported as failure). Guarantee: the returned answer
  carries an estimate under ε for every quantity.
- P7 **Loop scaling.** Counts per spell multiply by 1.1 × sqrt(worst/ε), rounded
  to even, which on a second-order rule lands the worst ratio near 1/1.21.
- P8 **First run.** About 100 evenly spaced introductions, forward only (no
  reverse pass, no gradients); it yields openings and shuttings of establishment,
  sign-change counts (of something; maybe establishment rate or fate slope), the
  offspring curve and the remaining share of J.
- P9 **"Spell".** A spell is a stretch between an opening and the next shutting:
  a window when establishment is possible. Every breakpoint is an opening or a
  shutting.
- P10 **Doubling.** If every count doubles, the old run is exactly the new run
  with every other node removed, so no replay is needed; the cost is 0.024 rms
  step noise, because the step sequences differ.
- P11 **No user tolerance.** The user does not set ode_tol or a node count; the
  ε table fixes everything.
- P12 **Map.** fit$where is a per-birth-date (or per-interval) share of J's
  error, from the replay; "the map's split names the channel" means the map can
  be split into light and water contributions.
- P13 **Section "What a node is".** Defines a node as a cohort introduced at one
  birth date and followed to the end of the run, and its weight in the quadrature.
- P14 **Section "Where fate curves: the node density".** Says where the density
  is raised and how it is set before any error is measured.
- P15 **Section "Traits".** How gradients/elasticities with respect to traits use
  the same schedule; maybe how carbon versus hydraulic traits bind.
- P16 **Section "Still being tested".** Lists unmeasured parts: the map-following
  density, perhaps the second replay.

Table rows:

- T1 **Opens and shuts.** Breakpoints sit where establishment opens or shuts;
  these depend on rainfall and the stand's uptake; found by the first run.
- T2 **Where fate curves.** The density is raised in first cohorts, the
  understory, the weeks before each shutting, and late births.
- T3 **How large the error is.** Error varies ~100× across trait × climate; no
  fixed schedule fits, so each run is measured by its replay.
- T4 **Which quantities bind.** The binding quantity differs: carbon-trait
  gradients bind in the first cohorts, hydraulic-trait gradients in the
  understory; each has its own ε.
- T5 **Interactions.** Light and water couple cohorts, so a local error spreads
  to all; the replay is a whole-system rerun so it captures that, and the map
  can be split by light vs water.
- T6 **Node cost.** Early-born nodes live the whole simulation, so cost more; the
  first density is lower early, or accounts for that.
- T7 **Simulation length.** The first density's "ages" (how long each node is
  followed?) come from the share of J still to be produced: a node born late
  need only be followed as long as J is still accruing. Possibly nodes are
  dropped once they no longer contribute.
- T8 **How sure an estimate is.** Near extinction or when the estimate is close to
  ε, a second replay on the other half of nodes (the odd ones) gives a second
  estimate.

Return value:

- R1 `refine_schedule()` returns a list with `answer` (ln J and its gradient from
  the last run; perhaps curvatures too, since the objectives ask for them),
  `estimate` (per-quantity error, from the last run's replay), `where` (error
  map over birth date). Presumably also the schedule itself and a failure flag,
  but the surface does not show them.

## 2. Verification against the body (written before the design note and measurements)

| # | verdict | the surface says / the body says |
|---|---|---|
| P1 schedule | hit, partial | Body agrees a schedule is breakpoints + density. But the density has internal structure the two-part summary hides: a shape (offspring-curve grading, two ages, the pre-shutting taper, "two more intervals" per spell) times a per-spell count that the loop scales. |
| P2 breakpoint | **miss** | Surface: "the births at which a recruit's fate changes slope abruptly". Body: at a shutting "fate stays continuous, but it curves sharply ... So a shutting is a breakpoint too" (l.95-103). The constant-rain stall is a near-step in value (survival 0.63 to 0.02 across 0.03 days, l.108), not a slope change. And l.285 says "fate's slope jumps only at openings", which contradicts l.105 "On constant rain there is one more slope jump". |
| P2b "a first run finds them" | **miss** | Body: on constant rain the stall needs "five rounds of forward runs" (l.119); the first run places only 75-89% of shuttings within a day (l.118), and nothing says what happens to the rest. |
| P3 density | **miss** | Surface reads as "how closely nodes are spaced" on a stretch, i.e. one spacing per stretch. Body: nodes are "placed to share the density equally" (l.175), so the density is a function within a stretch and nodes equidistribute it; the loop scales a per-spell count, not the density. |
| P4 replay | hit | Same steps, every other node between breakpoints removed. Cost is given twice and differently: 0.6-0.8 of a run (l.198) and 0.55-0.64 (l.288). |
| P5 error = change / 3 | hit | l.166. Holds only for centred pairs (l.174-179); the surface does not say the factor depends on placement. |
| P6 loop guarantee | **miss** | Surface: "every quantity under its ε? yes: this run is the answer", "It stops at each quantity's ε". Body: the replay reads 0.75-0.87 of the error (l.185), cannot see the tolerance error (l.201) or short spells (l.203, "No bound for it works yet"), and a reserve of 0.88ε is proposed (l.281). The answer is not guaranteed under ε; the test is on an under-read estimate. |
| P7 scaling | hit, with a hole | 1.1 × √(worst/ε) assumes the square law, but the body names components that halve rather than quarter (l.189-190) and late intervals that "leave the square law" (l.147). The "It stops" argument does not hold for them; only the pass cap does. |
| P8 first run | hit | ~100 even introductions, forward only, sign-change counts of P per node, establishment rate per step. |
| P9 spell | hit, late | "Spell" is defined only at l.123, after "closed gap" (l.99) and "gate" (l.96). l.264 reuses "spell" for a period an individual spends at P < 0, a different thing. Unclear whether the stall breakpoint splits a spell for the even-count rule. |
| P10 doubling | hit | l.236-237, l.213-214. But the loop as drawn scales by 1.1 × √ratio, not by 2, so this second estimate is not normally available. |
| P11 no user tolerance | hit, wording | "Tolerance" means three things: the per-quantity ε (l.33 "over its tolerance"), the ODE tolerance (l.201, 280), and "no tolerance from the user" (l.238). |
| P12 map | **miss** | Diagram: "replay ... ──► error of each quantity and the map of J's error". Body: the map comes "from its own reverse sweep" for 7.5% more than the run (l.207-208), not from the replay. How it is computed is not said. |
| P13 node | hit, partial | A node is a birth instant; the interval carries count and linear fate. Heading in the opening list says "what a node does"; the section is "What a node is". |
| P14 density section | hit on intent, short on rule | Four shapes are listed, but the rule turning them into a density is given only for the offspring grading and the two ages, without a formula. |
| P15 traits | partial | Body: traits move the breakpoints; a shared schedule's error costs a replay. Nothing about which traits bind where. |
| P16 still being tested | hit | Also holds a "Settled so far" list that restates (and contradicts) earlier sections. |
| T1 | hit | |
| T2 | hit | |
| T3 "about 100×" | **miss (not in body)** | The body never gives this figure or its source. |
| T4 which quantities bind | **miss** | Table: "hydraulic traits in the understory". Body puts the hydraulic and storage sensitivity in "the last three weeks before each shutting" (l.141, 191-193); the understory section is about leaf-area over-count carried by the first cohorts. "Carbon traits in the first cohorts" is not stated in the body. |
| T5 | hit | The split comes from the reverse-sweep map, not the replay. |
| T6 node cost | **miss** | Table: node cost is answered by "the first density". Body (l.150-151) says cost falls with birth date ("the rows it adds", rows undefined) but never says how cost enters the first density. |
| T7 ages | **miss (word)** | "Ages" reads as how long a node is followed. Body: two calendar times (onset of offspring production, 90% of J produced) that mark where spacing changes (l.153-157). |
| T8 second estimate | **miss, direct contradiction** | Table: "a second replay on the other nodes". Body l.211-214: "Removing the even nodes instead of the odd ones does not give a second estimate ... A second estimate needs a second schedule". |
| R1 return | **miss** | `fit$answer` is "ln J and its gradient"; the objectives need curvatures and the body never mentions them. `fit$where` is described as from the replay context but comes from the reverse sweep. The pass-cap failure (l.240-241) and the final schedule appear nowhere in the return. |

Count: 25 predictions (16 P, 8 T, 1 R); 10 clear misses (P2, P2b, P3, P6, P12, T3, T4, T6, T8, R1), 1 word miss (T7), and 6 partial hits with holes.

### Where a reader must hold state or jump back

- "fate" (l.26) is never defined as a number. l.54 says it is "survival, size and output"; l.92 then quotes "fate's slope" in "per day" with no unit or quantity. A reader must guess fate = lifetime offspring per recruit.
- "J" is used from l.38 and l.57 without definition.
- "ε" is used from l.229 (and "tolerance" at l.33) without a value or source; the vignette never says ε differs per quantity until the table.
- "edge" (l.114, 184, 287) means opening-or-shutting; never defined.
- "spell" defined at l.123; needed at l.99 ("closed gap"), l.145, l.170.
- "the square law" (l.147, 239) must be connected back to "width²" at l.63.
- "dry", "long-wet", "episodic", "dry-flat", "constant rain", "the ten-case bank", "lma ×1.25" are cases from the harness, never introduced.
- "the layout" (l.184), "region replays" (l.278), "fate maps" (l.277), "fixed rules" (l.158), "the finest run" (l.118), "the first tests" (l.173): process history a new reader cannot resolve.
- "rows" (l.151): rows of what (ODE state? tape?).
- "θ" (l.270), "a_bio", "a_y", "a_dG1", "a_dG2", "hmat", "root_P50", "the storage offset": parameter names with no gloss.
- "first moment" (l.53): of the establishment rate over the interval; why it is needed (weights for the linear fate) is left to the reader.
- l.194-197 repeats the density rule from l.143-145; l.285-288 repeats l.170-173 and l.198 with other numbers. A reader has to reconcile three copies.

### Terms used before they are defined

fate (26 → never), J (38 → never), tolerance/ε (33, 229 → never), closed gap (99 → 124), gate (96 → never), spell (first use and definition l.123; earlier text at l.99 needs it), edge (114 → never), square law (147 → implied by 63), field (182 → never; l.253), map (207; promised at l.40), reverse sweep (207 → never).

### Metaphors and borrowed mechanism words

- "gate" (l.96, 99): write "establishment shuts".
- "closed gap" (l.99, 124): write "the stretch with no establishment".
- "the field" (l.182-183, 193, 253): write "the light and water every cohort meets".
- "travels", "carries" (l.67, 182, 193, 209, 253): write "changes the light and water of every other cohort".
- "reads"/"read the error at 0.75" (l.179, 185, 197, 213, 278, 286): write "the estimate was 0.75 of the error".
- "names the channel" (l.253): write "says whether the error acts through light or water".
- "live"/"lives" (l.150, table l.254): banned word; write "is integrated for the rest of the run".
- "earn" J (l.131, 146): write "produce".
- "waits for rain" (l.90), "a smaller copy" (l.137), "stalls" (l.107), "leave the square law" (l.147), "lands" (l.158), "graded/grading" (l.153, 276), "bank" (l.158), "candidate answer" (l.235).
- Heading "The whole thing" is informal; "What it adapts to" uses "it" for an unnamed controller.

## 3. The representation

Verdict: **the framework is nearly right but misnamed, and three parts are bolted on.**

- The opening defines a breakpoint as a slope jump. The body then needs breakpoints that
  are not slope jumps (every shutting) and one that is a near-step in value (the
  constant-rain stall). The concept the body actually uses is: *the ends of each spell
  of establishment, plus any birth date where a cohort's P sign-change count differs
  from its neighbour's.* That is a support boundary (count goes to zero outside a spell)
  plus a fate discontinuity. Stated that way, shuttings need no special case and the
  opening slope jump is a fact about openings, not the reason for breakpoints. As written,
  "shuttings need breakpoints" reads as an exception the framework does not explain.
- Bolted on: (a) "each spell gets two more intervals" for the pre-shutting grading — an
  additive count rule beside a multiplicative density; (b) the stall's five rounds of
  forward runs, which are not in the loop diagram; (c) the reverse-sweep map, a second
  error mechanism beside the replay, whose use (density following it) is still untested;
  (d) the ODE tolerance and its 0.88ε reserve, an error the framework does not see.
- Left unexplained but needed: how breakpoints are located from the first run (search
  method, what is done with the 11-25% of shuttings more than a day out); the first
  density's formula (grading by offspring curve, how cost enters, how the two ages shape
  it, the starting total); what parity rule applies when a stall breakpoint lies inside
  a spell; what a spell too short for two intervals gets; the pass cap; the ε values and
  which quantities (gradients in which traits; curvatures?) are tested; how the map is
  computed; how "replay on its own steps" works when the replay has fewer ODE states.
- Could a reader implement the loop? The loop itself (run, replay, test, scale √ratio×1.1,
  keep even) yes. The inputs to it, no: they would have to guess breakpoint location,
  the first density, short-spell handling, the cap and the ε table. Every later section
  follows from "count × linear fate quadrature with even pairs", but the schedule
  construction is described by its measured effects rather than its rule.

## 4. Claims against the measurements

Read after sections 1-3 were written: `docs/design-refine-schedule.md`; `rootcause/evidence/notes.md`
rounds 1-4 (round 5 is pre-registered only, no results, and was being written while I read);
the summaries of `closing/`, `h5/`, `founders/`, `p50/`, `dwr/`, `single/`, `refine/`, `u/`,
`heldout/`, plus `loop/`, `proxies/`, `moved/` and `synthesis.md` where a number led there.
Several numbers come from notes the vignette's header comment does not list:
`docs/measurements/breakpoints.md`, `refinement.md`, `estimate-shortfall.md`,
`traits/results.txt` and `docs/dynamics.md`.

Verdicts: **S** supported, **M** misquoted (right figure given), **St** stale (a later round
replaced it), **U** unsupported (no source, or the sources disagree). "Partly" means the
figure is right but the vignette states it more widely than the source does.

### Claims the framework rests on

| claim | line | source | verdict |
|---|---|---|---|
| Fate's slope jumps at every opening: +0.5e-3/d before, −2.2e-3/d after, all 22 openings on dry | 88-93 | h5 O1 (medians +0.51e-3 / −2.18e-3; the slope changes sign on 22/22); evidence E1 (κ 12-67×, ratio 1.8-3.3) | S. The figures are medians, not each edge's slope |
| At a shutting fate stays continuous | 95 | evidence E1/R4 (no corner at c) | S |
| "Within 2-3 weeks of the gate shutting, fate's curvature rises tenfold" | 96 | evidence R4: inside the spell, fate's curvature rises only **1.3-5×** (leaf-area proxy up to 16×). The 10-44× is for stencils that cross c and so read the gap; the hydraulic sensitivity rises 11-14× | M |
| The hydraulic sensitivity "changes fastest 9-12 days before the gate shuts, set by the seedling's starting reserves" | 96-98 | closing Q3d (a turn about 9-12 d before c). Evidence R13/R15 replaced it: the curvature rises from ~27 d and stays on a plateau over the last 3-18 d, highest at 3-6 d (dry 6.1×, long-wet 17×); R16: "not a slope jump at a fixed birth date". The reserves mechanism: closing Q2 | St (the position); S (the reserves) |
| An interval reaching across the shutting is set by its last node's distance from c, not by the spacing | 99-101 | evidence E3/R6 (grows as d² in the last node's distance; a node at c cuts it 2-33×) | S |
| Shuttings need breakpoints: with openings alone worst 3.4ε and the replay read a fifth to two fifths; with both edges 0.47-0.79ε | 103, 285-287 | evidence R11 (3.36 / 1.13 / 3.24; read 0.21-0.44), R12 (0.79 / 0.47 / 0.76) | S |
| "fate's slope jumps only at openings" | 285 | evidence E1 (kinks only at openings) | S for kinks, but it contradicts l.105 ("one more slope jump" on constant rain) |
| Constant rain: "one more slope jump"; survival 0.63 → 0.02 across 0.03 d | 105-109 | breakpoints.md: a **steep front**, smooth at 1/2048-d spacing; survival 0.63 → 0.02 within 0.032 d (S); net reproduction moves only 20% across it. refinement.md: resolving it brings the invader to the square law but not the resident | M (it is a front, not a slope jump); the survival figure S |
| Cohorts born in the first 23.5 days reach the canopy; later ones' P falls below zero and comes back | 106-107 | refinement.md (front at 23.524 d; cohorts after it first cross zero after year 10); traits/results (counts 0 → 2) | S |
| Fate changes slope only where a cohort's sequence of P sign changes differs from its neighbour's | 111-112 | dynamics.md (theory: breakpoints are births on the switching surface and grazings) | U as a measurement: a theory claim |
| The sign-change counts change across every pair of neighbours that straddles an edge | 114 | none. Edges are found from the creation record (breakpoints.md); evidence R15: no saved run records per-node P sign changes (`splits` is not one) | U |
| On constant rain the counts go 0 → 2 at the stall | 115 | traits/results.txt, dynamics.md (all settings 0 → 2) | S |
| "Both kinds are found the same way" | 111 | breakpoints.md and refinement.md: edges from the establishment record of one run; the front by five bisection passes over sign-change counts | M. Two methods, which the next sentences in fact describe |
| First run on ~100 even introductions: 98-100% of openings and 75-89% of shuttings within a day of the finest run's | 117-118 | breakpoints.md (uniform 108; within 3 days 93-97%) | S. Unsaid: estimate-shortfall.md finds shuttings **move with the grid** (median 0.48 d, the founders' shutting by 12 d), so a breakpoint fixed from the first run is not where the final run shuts |
| Five rounds of ~100-node forward runs place the stall to 0.0003 d | 119-120 | refinement.md | S. Not in the design, and not in the loop diagram |
| The closed gap holds no establishment, so it needs no node | 123-124 | breakpoints.md (gap nodes carry no count; J changes 2e-6) | S |
| Even counts: with an odd count one interval per spell goes unmerged; "that hid most of the error before each shutting in the first tests" | 170-173 | evidence R11: of dry's 70 shutting strips 14 were merged, **17 were unmerged by parity, 39 sat in spells with no interior node**. The first tests failed mainly because shuttings were not nodes | M (parity hid about a quarter; the "most" was missing nodes) |
| Equal shares put every removed node at the centre of what it merges, where 1/3 holds | 174-176 | design ("no removed node sits off centre"); estimate-shortfall.md derives 1/3 for the **midpoint in width**. Equal shares of a graded density are not midpoints where the density changes 2× within 18 days | U as reasoning. In practice the read on the graded layout was 0.97 (evidence R16, one run on dry) |
| Off-centre factor (l³ + (1 − l)³)/(3l(1 − l)) | 177 | estimate-shortfall.md | S |
| Schedules built by adding nodes next to existing ones read a third to a half | 178-179 | estimate-shortfall.md (overall ≈ 0.33: 0.056/0.170 episodic, 0.131/0.391 dry; central panels 0.54-0.82) | S (about a third) |
| The replay shares the run's steps | 180-181 | evidence R1 (`PIN`, step times `identical()`) | S |
| Read 0.75-0.87, "correlation" 0.88-0.97, on dry, long-wet, episodic-lma; never passed a run over ε | 184-186 | evidence R12 | S for the figures, but they are **cosines** over 46 elasticities, not correlations; and every round-2 run was within ε, so "never passed a run over ε" was not tested there. The vignette's own layout (graded, +2 intervals) has one read: 0.97 on dry |
| All regions at once = sum of each alone ("correlation 1.000") | 186-187 | single, evidence R1 (cos 1.000, rms 0.002ε, dry, E6's layout) | S (cosine) |
| Still missed: root_P50 and the storage offset, ±0.4-0.6ε, "read near zero" | 188-189 | evidence R12: dry +0.41 / −0.49 read −0.03 / −0.04; episodic-lma +0.47 / **−0.63** read +0.05 / **−0.29** | M (0.41-0.63; episodic-lma's storage offset was read at half, not near zero) |
| It halves when the counts double, "so it sits at a fixed birth date that intervals reach across" | 189-190 | R14 (halves, dry only) inferred a fixed-position feature; R15/R16 then found no fixed date, only curvature over three weeks. The next bullet in the vignette says so | St (the fixed date); S (halving, dry) |
| A graded density + two intervals per spell removes it: root_P50 +0.41 → −0.05, storage offset −0.49 → −0.11, read 0.97 | 194-197 | evidence R16 | S, on **dry, one run**. episodic-lma had the same miss and was not rerun. The two extra intervals go to replayed spells only |
| Replay cost 0.6-0.8 of a run | 198 | design step 4 (an estimate). Measured: 0.55-0.64 CPU (R12), 0.53-0.62 (R11), rows 0.57-0.78 (R3 model) | St / M (0.55-0.64). l.288 has it right, so the vignette gives two figures |
| Tolerance error invisible to the replay; run at ε/10 (3e-5) | 201-202 | evidence R1 (G6b), refine (3e-5 floor 0.004-0.012 rms) | S in rms. "ε/10 (3e-5)" reads as if ε/10 were 3e-5; ln J's ε is 0.025 |
| Short spells: much of the establishment, 0.5-6.6% of J, error 0.05-0.10ε, no bound works | 203-205 | evidence R3/Q4 (23-71% of establishment, 0.5-6.6% of J, for layout D's panels with < 2 interior nodes over 18 pilots); R12 (true error 0.052-0.102; the bound is 5-50× short) | S. The vignette never says what a short spell gets (design: one interval, not replayed) |
| Parity: removing the even nodes is not a second estimate (read a third on dry) | 211-214 | evidence R12 (0.37, cos 0.29) | S. **The table row at l.256 says the opposite** |
| Every full run is a candidate answer | 235 | design G1 | S, but the replay (0.55-0.64 of a run) is made only to be compared with |
| Doubling: the previous run estimates the new one; step noise 0.024 rms | 236-237 | R14 (B2 reads B at 1.04); refine: 0.024 is the **1e-4** nudge floor, and at the 3e-5 the loop runs it is **0.004-0.012** | M (the noise figure is for the other tolerance) |
| It stops: on the square law each scaling cuts the worst ratio by the square of the scale | 239-241 | evidence G6a: rounding up leaves 46-92% of spells' counts unchanged at ×1.25; the design adds "make sure the binding spells' counts change", which the vignette leaves out. Order-1 components (R14) and wide late intervals break the square law | U as stated (needs the forced count change) |
| The density can follow the map; "still being measured" | 242-243 | design candidate A: per-region allocation saved 4.1% of rows (proxies); loop route B, map-led, passed only 13 of 18 because the map ranks by ln J (loop). The design chose B, scale only | St (it was measured and not adopted) |

### Density, ages and costs

| claim | line | source | verdict |
|---|---|---|---|
| Interval error ≈ count × width² × curvature; falls four-fold when spacing halves | 63-64 | founders (h²/12 rule within 5%), p50 (interiors 4.77), evidence R5 (own part order 1.6-2.0) | S for the smooth parts. Whole runs fall at order 1.0-2.9 under fixed-strip layouts (u, h5) |
| Regions add within 0.04ε | 65-66 | p50 (rms 0.039, dry); dwr (≈ 0.02ε) | S (rms, dry) |
| A local error spreads to all cohorts through light and water | 67-68 | dwr, p50, founders | S |
| Births before the first shutting earn 70-97% of J; decay length 0.4-1.2 y; reason: later reproduction against disturbance and drought mortality | 131-134 | founders (share 0.70-0.97; L first fifth 0.42-1.15 y; 61-84% of the fall from later reproduction) | S |
| Understory leaf area convex in birth date; over-count 0.5-1.1% (3-4% in the first years) | 136-139 | p50 (0.5-1.1%; 3-4% in **years 4-6**) | S |
| "The soil then runs drier for everyone" | 139-140 | contested: p50 found the soil layers agree to 1e-5 and inferred **light** [i]; dwr's map says soil; evidence R8: "the two cannot both be right", no run separates the channels | U |
| The first cohorts carry most of it as extra drought mortality | 140 | p50 (founders 80% of the field part; 86% of it in drydowns) | S |
| Before each shutting the sensitivity curves 3-12× harder than a month earlier | 141-143 | evidence R13/R15 on dry (root_P50 6-8×, storage offset up to 12×); long-wet root_P50 up to **17×** | S on dry; M if meant generally |
| Every seedling born there empties its reserves | 143 | evidence R15 (r_min 0.00004-0.001 for every cohort within 36 d of c) | S |
| Density rises ~2× over the last 18 d, tapering to 1 by 27, with two more intervals per spell | 143-145 | evidence R16, design "still open" | S (dry, one run) |
| Late intervals wider than ~110-160 d leave the square law on the traits acting through the soil | 146-148 | 160 d is h5's limit **before b = 20**, not for late births; 110 d is proxies' validity check, which u then found "separates nothing" and h5 said to recalibrate; "traits acting through the soil": no source | M / U |
| An early node is carried for the rest of the run, so its rows fall with birth date | 150-151 | loop (added early nodes "live through most steps"); design | S |
| First density "graded by the offspring curve"; ages from T(t): onset and t₉₀ | 153-157 | design step 2. **The design also uses t₅₀** (16-24 y, replacing the 17- and 20-y ages: the cap switch and the fate reference window); the vignette drops it | St / incomplete |
| On the bank these land at ~10 and 23-29 y | 158 | evidence R7 (T(10) = 1 on all ten; t₉₀ 22.9-28.8 y) | S |
| In a shorter run they move earlier | 159 | evidence R7 showed the birth-date window shrinking on lifetime 9-20 runs (R(b), 14.4 y at lifetime 20); T(t)'s ages were not computed on a short run | partly S (inferred) |
| Node cost answered by "the first density" (table) | 254 | the cost term belongs to candidate A (count from the map and each node's cost); the chosen design's first density has no cost term | St |

### The map, tolerance, traits, table

| claim | line | source | verdict |
|---|---|---|---|
| Map from the run's own reverse sweep: J's error by stretch to 0.03ε, for 7.5% more | 207-208 | loop (×1.105 of the sweep, +7.5% of the run; reads true ln J to 0.03ε **at s = 1**, misses up to 0.5ε at 1.6×); evidence R2 (on dry-flat's interiors map and replay agree to 0.001ε while both read 1.9× the truth) | partly S (the 0.03ε holds only near the committed spacing, and only for ln J) |
| The map's light/water split says which way the error goes ("names the channel") | 209, 253 | design table: "Not yet checked against a run that separates the channels"; evidence R8: "a claim, not yet a diagnostic" | U |
| Error size varies ~100× across trait × climate | 251 | synthesis.md: the h² constant varies ~100× **in the raw proxy**; normalised by J much less | partly S |
| Carbon traits bind in the first cohorts, hydraulic in the understory | 252 | founders (carbon-balance axis), p50 (root_P50 in the interiors) | S in the sources; but the body never says it, and evidence round 4 puts the hydraulic and storage error in the last three weeks before shuttings |
| "how sure an estimate is → a second replay on the other nodes" | 256 | evidence R12; the vignette's own l.211-214 | **contradicted** (St: it was the earlier design's parity claim, refuted in round 2) |
| Stall at day 23.6; lma ×0.8 / ×1.25 → 27.1 / 18.9; hmat ×0.8 / ×1.25 → 45-50 / 10-12 | 267-268 | traits/results.txt, dynamics.md, refinement.md (23.524; 27.125 / 18.875; 45.0-50.4; hmat ×1.25 counts change over 9.9-10.9, bisected to 10.85) | S, except hmat ×1.25 is 9.9-10.9 (M) and "23.6" disagrees with l.106's "23.5" (23.524 bisected; 23.563 on the 1/16-d scan) |
| A schedule refined at one θ serves nearby θ but the error grows as θ moves | 270 | moved (growth 0.81-3.90; the error constant itself grows; the reserve 0-0.74) | partly S (it can also shrink) |
| A moved trait's error costs one replay to measure | 271-272 | moved: the parent's estimate reads θ₀'s error, not the moved one; a replay shares a run's steps, so measuring at θ needs a **run at θ plus its replay** (≈ 1.6 runs) | U |
| dry-flat's understory: region replays read 1.9× | 278 | evidence R9 (×1.7-1.9) | S |
| Tolerance: 3e-5 costs 1.4× the steps; 1e-4 at 0.88ε covers the bias (≤ 0.11ε) for 0.7 of the cost | 280-282 | evidence R14 (1.40-1.45×; max 0.108 on five cases; reserve 0.12ε; 0.70) | S (five cases only) |
| Even counts merge every interval; replay 0.55-0.64 of a run | 288 | evidence R12 | S (except short spells, which are not replayed) |
| Return value: answer, estimate, where | 37-40 | design: `list(schedule, answer, estimate, where, history)` | incomplete: no schedule, no history, no failure report |

### Tally

About 60 claims checked. Misquoted: 10 (fate curvature tenfold; constant-rain "slope jump";
"found the same way"; parity hid "most" of the error; missed component's size and read; step
noise 0.024; 110-160 d; hmat ×1.25; 3-12× if read generally; replay cost at l.198). Stale: 6
(9-12 d turn; "fixed birth date"; replay cost 0.6-0.8; map-following density "still being
measured"; node cost in the first density; second replay on the other nodes) plus the missing
t₅₀ age. Unsupported: 7 (sign-change counts change at every edge; slope changes "only where"
as a measured fact; the equal-share = centre argument; soil channel for the understory; the
map's channel split; "it stops" without the forced count change; one replay for a moved θ).

### What the sources add to the representation verdict

- **Shuttings move with the schedule.** estimate-shortfall.md: closings move between grids
  (median 0.48 d, the founders' shutting by 12 d), openings do not. A shutting depends on the
  stand's uptake, so a breakpoint "never moved" from the first run's shutting can sit off the
  final run's shutting; evidence E3 shows the error grows as d² in that distance.
  breakpoints.md also notes a run can place an edge node itself as it happens. Neither the
  design nor the vignette mentions either.
- **The front is outside the design.** The design's breakpoints are the first run's opening
  and shutting edges only. The constant-rain front and its five bisection passes come from
  breakpoints.md / refinement.md, so in the vignette they are a second breakpoint kind
  without a step in the loop.
- **The stated framework and the built one differ.** The design's commitment is "breakpoints
  + a count per spell, nodes at equal shares of a density"; the vignette's opening says
  "breakpoints + a node density". The per-spell count is what the loop scales, and the
  vignette never names it until the loop diagram.

## 5. What to change, ranked

1. **Fix the table's last row.** "A second replay on the other nodes" contradicts the body
   (l.211-214) and evidence R12. Write: "a second schedule: the previous run, when a step
   doubles every count".
2. **Redefine a breakpoint in the opening.** "Births where a recruit's fate is not smooth
   enough for one interval: each opening and shutting (the ends of a spell of
   establishment) and any front where neighbours' P sign-change counts differ." Then drop
   "slope jump" for the constant-rain front (it is a steep front, l.105), remove the
   contradiction with l.285, and say the front needs its own passes (l.119), shown in the
   loop diagram.
3. **Say that shuttings move with the schedule** and what the loop does about it (re-read
   the edges from each run, or place them in the run). As written, "a breakpoint is never
   moved" plus "a first run finds them" hides a measured error source.
4. **Correct the numbers the framework rests on:** fate's curvature before a shutting
   (1.3-5×, not tenfold; the tenfold is the hydraulic sensitivity); drop the 9-12 d turn and
   the "fixed birth date" (l.190), which round 4 replaced; parity hid about a quarter of the
   shutting error, missing nodes the rest (l.173); replay cost 0.55-0.64 at l.198; step
   noise 0.004-0.012 at 3e-5 (l.237); the missed component 0.41-0.63ε, and episodic-lma's
   storage offset read at half (l.188).
5. **State the guarantee honestly.** The replay reads 0.75-0.97 of the error, cannot see the
   tolerance or short spells, and the grading fix is one run on dry. Say "under ε" is a test
   on an estimate that reads low, name the reserve (0.88ε at 1e-4, or 3e-5), and add the
   forced count change the design needs for "it stops".
6. **Name the per-spell count** in the opening two-part definition (or make it three parts),
   and give the first density's rule: the offspring grading, the three ages (onset, **t₅₀**,
   t₉₀), the pre-shutting taper, two more intervals per replayed spell, and what a short
   spell gets (one interval, not replayed).
7. **Remove stale design options:** node cost in the first density (table l.254) and "the
   density can follow the map ... still being measured" (l.242): both were candidate A,
   measured and not chosen.
8. **Downgrade the map's channel split** (l.209, l.253) to "proposed, not yet checked", and
   give the soil-or-light question for the understory (l.139) as open.
9. **Fix the moved-θ claim** (l.271): checking a moved θ costs a run there plus its replay,
   and the error constant itself grows with the trait (moved round), so the shared grid needs
   a reserve or an estimate at the worst θ.
10. **Define before use and remove metaphors:** J, fate (as a number with units), ε (per
    quantity, with its source), edge, spell, the cases (dry, long-wet, episodic-lma ...);
    replace gate, closed gap, field, travels/carries, reads, channel, live(s), earn; say
    "cosine" not "correlation"; replace "ε/10 (3e-5)". Show `schedule`, `history` and the
    failure report in the return value, and say whether curvatures are in `answer`.
