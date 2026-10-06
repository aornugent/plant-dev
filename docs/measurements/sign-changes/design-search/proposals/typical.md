## Triage: 3 — it sets odelia's System concept, which plant consumes, and what a recorded row carries into the sweep; R4 and R12 arrive partly as mechanisms.

## Requirements ledger
R1: elasticities move < ε/3 under seven tol nudges and a quarter-spacing shift, at 1e-4 — plain 1.261 (d_I), incumbent 0.282.
R2: curvature chords reproducible within ε/3 from r ≈ 1e-2 — plain 0.56ε, incumbent 0.05ε.
R3: no jump > 1e-8 in ln J as a sign change passes a step or a pair merges, over the radius (resident ±10%).
R4: sweep within 2e-3 of central differences (challenged in the ledger).
R5: ln J within 0.025, its error falling with tol.  R6: no throw over the box.
R7: J′ = J to the last bit on the diagonal. (Challenged upward: invader walks stay unsplit, so with the resident split J′ differs by ≈3e-5 in ln J at 1e-4, ≈0.001ε — the incumbent too. Is bit-equality required with splits on? Default here: no; walks stay unsplit.)
R8: least runtime at matched error; bar forward +6.0%, sweep +7.3%.
R9: least code and reader load; incumbent odelia +1117/−30, plant +605/−37.
R10: off is bit-identical. R11: cuts counted per node. R12: odelia knows components, not nodes. R13: the model's rates, η = 1e-4.
Ledger correction: 1.6's "417 node steps hold a pair" is the search's count; the final build's split log holds 14 pairs in 12 steps.
Scarce resource: reader load. The whole treatment costs 3.6% of a gradient run (+6.0% of the forward and +7.3% of the 2.6-forward sweep, in a 7-forward run), so runtime has at most that to win, while its code is ~1.7k lines in 26 files under a "rethink the orchestration" verdict.

## The floor
Plain at 1e-4 — fails R1: d_I 1.261 vs < 1 (ε/3); fails R2: 0.56ε vs < 1/3 at r = 1e-2. Plain at 1e-5 fails R8: 1.30× the incumbent.

## Candidates (one move, two constructions)
The typical sign change (census of 9247 cut node steps, long drought, 1e-4): 99.85% are one crossing with net production of opposite signs at the step's two ends; κ = h|dP/dt|/η has median 4.9e4, 7% below 10 carrying 0.3% of the weight proxy (share·h·|ΔP|)²; u* is uniform; steps median 1 day; nodes 1–4 hold 86% of J and 25 node steps half the proxy. Net production is curved on the step's scale: q = P″h/P′ median 0.36, 0.58 on the 300 heaviest, 1.53 in steps opening at a rainfall knot. The rest: 14 pairs (12 opening at a knot, 2 slow bumps), no triple. Episodic rain: 6210 cuts; constant rain: 41, none on a node holding ≥ 1e-3 of J.

A [first thought] Closed-form fast path: subtract the kink's quadrature error, J₁h²ψ₁(u*) + J₂h³ψ₂(u*)/2, its slope and curvature jumps read from three ratings a side at u* ± ke (e = 0.01), which read no jump where the band is resolved or a dip is narrower than e. Commitment: a fast single crossing is never re-integrated. Pays for R1/R2: leaves 0.2–3% of the kink's spread for q ≤ 0.65, 5–17% at q ≈ 1–1.5 (toys). Costs: ψ₁, ψ₂, a six-rating stencil; ~16 ratings a zero against 26, about 1–2% of a gradient run saved (inferred). Bad at: dips near birth — at width 0.019 against the stencil's 0.06 its error is 16× plain's, and two ratings a side leave a jump of 7.9e-4 at a dip's birth against plain's 3.6e-7 (toy units); slow crossings (κe < 1) fall to plain. Wins when: runtime is scarce and every record's weighted crossings are isolated and fast.

B The cut as the only mechanism: the typical shape is one bracket [0, 1]; the rare shape becomes two brackets through one detector rule, then takes the same locate and pieces. Commitment: every cut comes from a bracket. Pays for R1/R2/R3 as measured: 0.282, 0.05ε, jumps ≤ 4.7e-10. Costs: 26 ratings a crossing. Wins when: reader load is scarce and records vary.

Winner: B — beats the floor on R1 (0.282 vs 1.261) and R2 (0.05ε vs 0.56ε), and plain at 1e-5 on R8 (0.77×). A loses on R9 (a second body of theory for 1–2% of a gradient run) and on R2/R3 robustness at every dip's birth; sending pairs to the cut instead jumps, wherever a pair turns into a single crossing, by A's residual: 0.9–1.7e-8 on node 5's measured 5.8e-7 kink, at R3's 1e-8.

So the move leads back to the incumbent's per-node cut: the typical crossing is fast but curved, the rare one narrow, and only a piece boundary at each zero is exact for both. Its two paths collapse into one, because the general case costs 0.04% of a forward (417 searches, 14 pairs × 2 locates).

## The commitment
Every cut comes from a bracket — two readings of net production of opposite sign on the step's dense output — and is located and integrated the same way whatever the shape.
Kept true by: `locate` takes only a bracket (a, va, b, vb with va·vb < 0); the pieces take only the sorted cuts; the detector outputs only readings. A cut without a bracketed sign change, or a second integration path, has no entry point. Check: true on all three records (41 to 9247 cuts a run); a cut off the zero reads the turn off-centre (the sweep 7.5e-3 off with cuts held); it removes per-shape paths and the jumps between them; runtime becoming scarce kills it.

## Kill question
Assumption whose falsity makes this unnecessary: the kinks carry the gradients' nudge spread at 1e-4.
Verdict: survives — they are 70–85% of plain's spread (§11); plain fails R1 at 1.261, the cut passes at 0.282. The move's sharper assumption, that only re-integration meets R1/R2, is false on isolated fast crossings (A); the cut survives on dips near birth and on R9.

## What survives deletion
- dense output → R1 (locate), R8 (reads)
- bracket from the ends' signs → R1 (99.85% of cuts)
- one detector rule → R3 (a pair cut once jumped 5.8e-7)
- `locate` and its slope → R1, R4
- pieces with the step's tableau, rated in the field read at u = 0, ¼, ½, ¾, 1 → R1, R8 (sweep 14.7% → 7.3%)
- end rated again → R1
- record (cuts, slopes, ratings at cuts, piece ratings, end before cuts) and an implicit node per cut → R4
- cuts per node → R11; off switch → R10
Deleted: the incumbent's second detector rule, `searched`, the slowest-crossing record (no ledger line).

## What this settles
- No closed form, ψ, stencil, or κ or q threshold: the cut is exact to the method's order at any speed and curvature.
- No pair path: a pair is two typical brackets.
- No speed class (κ < 10: 7% of cuts) and no weight class (nodes under 1e-3 of J: 51% of cuts, 0.66% of J), so no pilot.
- Inside a step one decision moves with θ — whether a dip is seen — and a cut makes it continuous up to the piece boundary's own jump.

## What this makes hard
- Runtime: 26 ratings a crossing, 3.6% of a gradient run. Cope: a weight class from a pilot (≥ 1e-3 of J keeps 49% of the cuts on long drought, 60% on episodic, none on constant), or A off the knot steps.
- Honest to its readings only: a step whose ends differ and that also holds a dip is cut once (none in two 32-point scans). Retrofit trigger: a scan showing more sign changes than cuts; then re-read where a piece's own stage takes the other sign.
- Invader walks stay unsplit (R7).
- A tangency's jump depends on how soon the search sees the dip: 4.7e-10 at width 0.0025, growing as w³ if seen later.

## Kill condition
Runtime becomes scarce (the 3.6% must go) on records whose weighted crossings are isolated and fast → A, with B kept in steps opening at a rainfall knot; a step-level guard flips only where both reduce to the plain step.

## The design
odelia, `Step::split`, after each kept or pinned step:
1. Readings: each block's net production at the step's ends (the first-same-as-last start and the end rating), both on the trajectory.
2. Brackets: opposite signs give [0, 1]. Alike: take the stage reading leaning furthest toward the other sign; if it holds that sign, or lies within 2% of the readings' spread of zero, read the dense output there and golden-search beside it if needed (≤ 4 readings); a reading of the other sign at u_m gives [0, u_m] and [u_m, 1]. This one rule replaces the incumbent's deepest-stage and nearest-zero rules.
3. `locate` (Illinois regula falsi on the dense output) in each bracket; slope by central difference.
4. `integrate_pieces` between consecutive cuts, each rating in the quartic through the five reads.
5. Rate the end again if any block was cut; record; the sweep tapes the pieces and the implicit cuts as now.
plant: unchanged in substance.
Names: none new. For R9 and R12: `part` → `block` (the components one sign value governs), `part_split` → `block_cuts`, `split_record` → `cuts_by_block`, `unsplit_end` → `end_before_cuts`, and one concept in place of `RatesParts` and `SplitsSignChanges`, the double-only split an `if constexpr`. (If R12 yields upward, odelia may say node.)
Size: odelia ≈ +1065/−30, plant ≈ +585/−37 — the incumbent less ~70 lines (second rule ~35, `searched` ~10, slowest crossing ~25).

## Spike files (scratchpad/design/spikes/typical/)
- `census.R`, `census.log`: 9247 cut node steps: 9233 one crossing with opposite-sign ends, 14 pairs in 12 steps; κ median 4.9e4, 7% below 10 with 0.3% of the weight proxy; u* uniform; 25 node steps hold half the proxy.
- `weight.R`, `weight.log`: nodes 1–4 hold 86% of J; nodes ≥ 1e-3 of J hold 49% of the cuts and 99.3% of J.
- `pairs.R`, `pairs.log`: 12 of 14 pairs open at a rainfall knot (dips 0.004–0.45 of a step); 2 are slow bumps with both ends negative.
- `linearity.R`, `linearity.log`: q = P″h/P′ median 0.36 over single cuts, 0.58 on the 300 heaviest.
- `knot_class.R`, `knot_class.log`: steps opening at a knot hold 983 single cuts, q median 1.53, 6.3% of the proxy; elsewhere q median 0.34.
- `toy_fastpath.R`, `.log`: frozen-mesh gradient spread: plain ∝ h, one-term closed form ∝ h² (44–150× below plain), the cut 660–8000× below.
- `toy_curvature.R`, `.log`: closed form with exact jumps leaves 0.8–3% (one term), 0.2–1.5% (two terms) of plain's spread for q ≤ 0.65; the cut ≤ 0.02%.
- `toy_stencil.R`, `.log`: jumps read from three ratings a side reproduce the exact-jump residuals.
- `toy_birth.R`, `.log`: at a dip's birth two ratings a side leave 7.9e-4 against plain's 3.6e-7; two terms are exact for wide dips but 16× worse than plain at width 0.019.
- `bank_splits.R`, `.log` (`fwd_constant`, `fwd_episodic`): constant rain cuts 41 node steps, none on a node with ≥ 1e-3 of J; episodic 6210 (60% on such nodes), its slowest crossing on a node with 1.4% of J.
