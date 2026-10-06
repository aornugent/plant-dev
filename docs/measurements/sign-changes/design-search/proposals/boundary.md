# Move the system boundary: the cut leaves odelia's step for plant's patch

## Triage: 3 — the design changes the boundary between odelia and plant and the recorded row, which every TF24 gradient passes through. The requirements also arrived as a mechanism (the incumbent).

## Requirements ledger
R1–R13 are as in `ledger.md`. The numbers that bind:
- R1: nudge moves < ε/3 at `1e-4` (plain 1.261, incumbent 0.282).
- R2: 0.56ε / 0.05ε at r = 1e-2.
- R3: no jump > 1e-8.
- R4: sweep within 2e-3.
- R7: J′ = J to the last bit.
- R8: bar is forward +6.0%, sweep +7.3%.
- R9: the incumbent added 1722 lines in 26 files.
- R12: odelia knows no nodes.
- R13: the model's own rates.

R7 is challenged upward. The incumbent misses it: on an 8-year long-drought stand, ln J′ − ln J is 3.0e-5 with splits and exactly 0 without (spike). Is bit for bit needed, or about 1e-5 (1/800 of ε)? Default: bit for bit, at about +3.5% of a gradient run (inferred).

Scarce resource: the code where odelia and plant meet. R1 and R8 fix the arithmetic: a cut costs about 26 node ratings per crossing node step, against about 1200 for a global step end (T12) and +41% for tol `1e-5`. What remains to save is the code that tells a generic ODE library about nodes.

## The floor
Plain at tol `1e-5`, with no code. It fails R8: 1.41× plain against about 1.07 for a cut (the cut is 0.77 of the floor at matched stability). It also fails R1, which names `1e-4`.

## Candidates
Places the boundary could stand, priced:
- **The model.** Widening η helps only once κ = h|dP/dt|/η ≲ 1. In the toy the spread falls 28–1300× at κ ≤ 2.5, and at most 4.4× at κ ≥ 6. TF24's crossings that carry J sit at κ ≈ 8000, so resolving them needs η ≈ 0.8 kg/yr, four decades up. One decade already moves ln J by 9ε. A lag state leaves the spread at 0.6–1.3× plain's (toy), and branches move the curvature 8.2ε across r. Nothing goes to the user under R13.
- **The caller.** Chords at r = 3e-2 pass R2 for plain (0.10ε), but R1 still fails (1.261).
- **The mesh.** Global step ends cost 2.9–3.3× plain.
- **A library.** None cuts one block of components inside a global step under a reverse tape (inferred).
- **plant [chosen].**
  - Pays for R7 (an exact diagonal), R9 (about −36% lines and −18/+9 names, inferred) and R12. It keeps the incumbent's R1–R6 and resident R8, because the arithmetic is the same.
  - Costs: plant has to hold step numerics, and invader walks pay for their own cuts.
  - Wins when plant is the only home of Systems that cut, and invaders must repeat the resident exactly.

**This is the incumbent's per-node cut, integrated again in pieces.** It stays because every other place is priced out above. What moves is who owns it.

Winner: plant. Eliminations:
- the model fails R13 (≥ 9ε);
- the caller fails R1 (1.261) and R8 (1.41);
- the mesh fails R8 (2.9–3.3×);
- odelia, the incumbent's placement, fails R7 (3.0e-5) and R9.

## The commitment
odelia knows steps and plant knows nodes. Integrating a node across its own sign change is plant's work, done on a step that odelia has finished and handed over.

Kept true by: odelia's one new concept, `SplitsSteps`, whose one method `split_step` works as follows.
- It receives a finished step: start state, six stage rates, the end's rate, the end state and the row.
- It returns whether the System changed the end.
- The row carries a record whose type the System names.

odelia has no node, part or sign value it could name, so a node-level decision cannot be written there. A System without the method compiles the old step (`if constexpr`).

## Kill question
Assumption whose falsity makes this unnecessary: TF24's kink has to be cut at all, node by node.

Verdict: survives.
- The kink is narrower than any step (κ up to 1e4), so only cutting or resolving it removes the staircase (R1: 1.261).
- Resolving costs +41% or 2.9–3.3×, against +6–7% for a cut (R8).
- A resolvable width moves ln J by ≫ ε (R13).

The narrower risk, that the algorithm rather than its placement made the incumbent heavy, is half true. Detection, location, the pieces and the replay (about 400 lines) move across unchanged. What goes is the interface between the packages (about 300 lines, 18 names), and with it the diagonal error.

## What survives deletion
In odelia:
- `SplitsSteps`, `split_step`: R12 and R10.
- The row slot `unsplit_end` (kept): R4, since the dense output's end rate is taped from it; R7, since a walk evaluates the end there first.
- The row slot `splits`, of the System's type `step_splits`: R4.
- `solved_in`, the record behind `dydt_in`: R1, since the start's reading decides a single cut.
- `dense_state` and `integrate_pieces`, made public: R1; R9, so plant holds no copy of the tableau.

In plant:
- `Patch::split_step`: R1–R3.
- `node_split {node, cuts, slopes, at_cuts, ratings}`: R4.
- `step_splits {nodes, field}`, where `field` holds the five field reads: R7, since an invader cannot rebuild the resident's field.
- `field_at` and `node_rates_in_field`: R1.
- `ode_splits_by_node`: R11.
- `ode_split_sign_changes` and `NamesSignValue`, kept: R10.

Deleted, because no ledger line holds them: `RatesParts`, `SplitsSignChanges`, `part_split`, `part_width`, `part_reads`, `part_rates`, `sign_values`, `sign_values_in`, `end_sign_values`, `Step::split`, `taped_split`, `field_recorded`, `require_unsplit`, and `split_record`'s `searched` and `least_rate*`.

## What this settles
- odelia checks no layout (parts open the state, uniform width, parts × width ≤ size), and keeps no sign vector synced at three sites.
- A System that split at double but cannot rate a node at the active scalar cannot occur. One templated method serves every scalar, so the sweep's runtime refusal goes, and so does the tangent walks' refusal (inferred: the implicit node handles directions).
- J′ ≠ J on the diagonal cannot occur, because the walk splits from the resident's numbers.
- An invader's crossing inside a row the resident split is now cut, which answers R7's open question there.
- "How is a node cut?" is one plant function calling two pure odelia functions, not odelia → plant → odelia → plant.

## What this makes hard
- Plant's patch holds step numerics that a plant reader must learn: Illinois on the dense output, the implicit cut, the quartic field.
- A second System outside plant that needs cuts must write its own.
- R7's exact diagonal makes the invader's walk and sweep pay what the resident's do: about +3.5% of a gradient run (inferred: (0.8 × 7.5% + 2.6 × 7.3%) / 7). If R7 relaxes, drop that path (about 40 lines).
- Recorded evaluations carry each node's net production: about 45 MB on a 40-year run (inferred), unless cleared once the split is decided.
- An invader crossing in a row the resident did not split stays uncut. That is continuous (a passage moves ln J by 4.9e-11). Cutting it needs the field at five fractions on every row, about 0.1–0.2% of a forward (inferred).

## Kill condition
- A second odelia System outside plant needs per-component cuts. A generic mechanism then pays for itself, which is the incumbent's commitment: "odelia does the arithmetic, the model names the parts."
- Or the user puts a width the steps resolve into the model (R13), and the floor wins.

## The design
**odelia** (about 140 lines, against 628; inferred):
- `dense_state` and `integrate_pieces` become public: the step's own quartic and tableau.
- `split_step` runs after every step the error estimate keeps, every pinned step and every walked step.
  - When it returns true, odelia moves `at_state` to `unsplit_end` and evaluates the end again.
  - A walked row that holds an unsplit end is evaluated at both ends.
- The sweep tapes the stages and the end. On a split row it rates the unsplit end from its record, then calls `split_step` at the active scalar.
- `solved_in` is kept beside `dydt_in`.

**plant** (about 400 lines, against about 210; inferred):
- Each evaluation's record holds its nodes' net production.
- At double, for each node:
  - The readings at the start, the five stages and the end decide the cuts:
    - the two ends differ: one cut;
    - an interior stage has the other sign and the dense output confirms it: two cuts;
    - a reading lies within 2% of the spread: a golden search, then two cuts.
  - The field at u = 0, ¼, ½, ¾ and 1 is built once from the dense output. In a walk it is read from the resident's row.
  - Illinois locates each cut on the node's dense output, in the quartic through those five reads.
  - `integrate_pieces` integrates the node, which is written into y1 and recorded.
- At an active scalar the same method replays the record:
  - the field is taped (resident) or taken as recorded (invader);
  - each cut moves by odelia's implicit node;
  - the pieces are rated at the recorded ratings.
- Splits are counted per node, and the control flag opts in. FF16 has no `split_step`.

## Spike files (`spikes/boundary/`)
- `toy_kink.R`, `toy_kink.out`: growth reading σ(P), Cash–Karp on fixed meshes, eight nudges.
  - Plain's gradient spread is first order in h.
  - Widening η cuts the spread 28–1300× only at κ ≤ 2.5, and at most 4.4× at κ ≥ 6.
  - A lag state leaves it at 0.6–1.3× plain's.
  - A cut at the zero cuts it 1240–2550×.
- `diag_split_L8.rds`, `diag_plain_L8.rds` (and `.log`): 8-year long drought, 108 nodes, `1e-4`, `lib_rr`. The invader at the stand's own traits gives ln J′ − ln J = 3.04e-5 with splits (up to 2.1e-4 for a single node), and exactly 0 without.
- `inc_ode_step.hpp`: the incumbent's `ode_step.hpp`, extracted for line counts. `Step::split` is 236 lines, `taped_split` 65, `integrate_pieces` 34, `reads_at` 23, and the dense output 43.
