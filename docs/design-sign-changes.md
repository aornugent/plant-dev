# Sign changes in net production: the problem as mathematics, and the options

This note restates the per-node sign-change problem as mathematics, from
`docs/geometry.md` and the record. It then sets out what a design search
found.
- *How the search ran:* under the system-design skill's deep search, with five
  proposers, each blind to the others and each on one framing move, plus the
  first thought, all judged by a separate agent with kill authority.
- *Its files* are in `measurements/sign-changes/design-search/`: the ledger,
  the six candidates, the judge's verdict, and every spike's script and log.

Section marks (§) are `grid-dynamics.md`'s.

**In short.**
- *The problem.* A step's error at a crossing is h²·a·ψ(u*). ψ averages to
  zero, so `J` is unharmed. Its derivative in θ is a staircase, and that is
  what the gradients and curvatures see.
- *The search.* Every design attacks one factor of that term: the kink a, the
  step h, or ψ, made zero or corrected.
- *The judge's ranking.*
  1. The incumbent's per-node cut, moved into plant, with the invader walks
     fixed and one detection rule: about 490 lines against 1722.
  2. A closed-form correction from values the step already rated: about 250
     lines and 0.9% of a run, unmeasured on TF24. It takes first place if one
     two-hour check on TF24 holds.
- *Halving the steps that hold a sign change* meets R1 and R2 on TF24 in about
  110 lines. It loses on runtime per pass: a forward costs 10–13.5%, against
  the 6% bar.

## 1. The problem as mathematics

### The rates and their one switch

- *The state* is y = (x_1, …, x_N, s): about 108 node blocks of about 20
  components each, then the soil and the accumulators.
- *The rates* are dx_i/dt = F(x_i, E(y,t), t; θ, σ(P_i)) and ds/dt = G(y, t; θ).
  - E is the field every node reads: the light knots and the soil's water
    potentials.
  - P_i is node i's net production.
  - σ(P) = (P + √(P² + η²))/2 is TF24's smooth positive part, with
    η = 1e-4 kg/yr.
- *σ is the only switch at the step's scale.* Growth and the storage pool read P
  through it, and F, P and G are otherwise smooth there.
- *σ is analytic, but its bend sits in the band |P| < η.* A node crosses the
  band in τ = η/|dP/dt|, so κ = h/τ says how sharp the bend is at the step's
  scale.
  - Over the 9247 node steps the incumbent cut, κ has median 4.9e4.
  - 7% of them have κ below 10, carrying 0.3% of a J-weighted proxy
    (`design-search/spikes/typical/census.log`).
  - So nearly every crossing is a kink at any step size.
- *The width is part of the model.* ln J is 2.55559, 2.53914 and 2.31110 at
  η = 1e-5, 1e-4 and 1e-3 (§18).

### The continuous map is smooth

- In the sharp limit the field is continuous across each surface {P_i = 0},
  and only its Jacobian jumps.
- So the saltation matrix is the identity, the sensitivities are continuous,
  and ln J is C² in θ wherever every crossing is transversal.
- Only where a dip's two crossings merge (a tangency) does ln J lose
  smoothness, and that loss is the model's own.

### The discrete map carries a staircase

On a frozen mesh Cash–Karp samples σ(P_i) at six stage abscissae a step. Let
a be the jump in the rate's time derivative at a crossing, and u* the
crossing's place in the step.
- *The local error* is h²·a·ψ(u*). ψ is piecewise quadratic in u*, with breaks
  at the stages, and its mean over u* is zero.
  - On Cash–Karp's weights the mean is −2e-12, against a largest value of
    0.016 (`design-search/orchestrator/psi_check.R`).
  - So across about 9000 crossings the value errors cancel, and the kink
    costs `J` nothing measurable.
- *Its θ-derivative is a staircase.* It jumps by b_k·h·a·dt*/dθ each time the
  crossing passes a stage that carries weight: c = 3/10, 3/5 and 7/8, with
  risers of 0.40, 0.21 and 0.29 a·h.
  - Any knob nudge reshuffles every u*. So the gradients' spread under nudges
    is the variance of a sum of O(h) risers, and the heaviest crossings
    dominate it.
  - A chord at r averages the staircase over ±r.

### What the objectives ask of it

- *Reproducible gradients (R1).* With `OBJECTIVES.md`'s 0.01 floor on ε:
  - plain at `1e-4` moves a_dG1 1.05 ε/3 on the driver's meshes, its only
    failure;
  - on plant's own controller it moves up to 1.65 ε/3, with four traits over 1.
  - §11's d_I 1.261 used d_I's unfloored ε of 0.00047. Floored, it is 0.06.
- *Stable curvatures at r = `1e-2` (R2).* Plain's second difference spreads
  0.56ε against a bar of ε/3. This is the line that binds.
- *Continuous on a frozen mesh (R3):* no jump above 1e-8 in ln J.
- *The sweep differentiates the run's own map (R4).*
- *J′ = J on the diagonal (R7).* The incumbent misses it: its invader walks
  are unsplit, so ln J′ − ln J is 6.97e-5 at θ₀ on the 40-year stand
  (`measurements/sign-changes/curvature_rows.log`) and 3.0e-5 on 8 years.
- *The least runtime at matched error (R8).* The bar is the incumbent's
  forward +6.0% and sweep +7.3%.
- *The least code (R9).* The incumbent is 1722 lines in 26 files, and its
  review asked to rethink the orchestration.

So a treatment must shrink the staircase's spread by at least 1.7×, keep the
map smooth in θ, and stay exact under the sweep.

### Prices

- A node rating, with its leaf solve, costs about 15 µs.
- A row costs about 4.4 ms, about 290 node ratings.
- A gradient run pays every row about seven times: the forward, its sweep, and
  an invader's walk and its sweep.
- *Long drought:* the 9247 node crossings fall in 726 steps (4.9% of rows),
  about 12.7 to a crossing step.
  - 99.85% are one transversal crossing.
  - 14 are pairs inside a step, 12 of them at a rain pulse's onset.
  - Nodes 1–4 hold 86% of `J`.
- *Episodic:* 623 steps (6.7%) hold a sign change, about 8 nodes each
  (`design-search/judge/m3/episodic.log`).

## 2. The design space, read off the error term

Each family of designs attacks one factor of h²·a·ψ(u*).

| factor | how | where it stands |
|---|---|---|
| a, the kink | widen σ until steps resolve it | dead: the J-carrying crossings need η ≈ 0.8 kg/yr, four decades up, and one decade already moves ln J by 9ε |
| h at crossings | a tighter tol everywhere | tol about 4.8e-5 for R2: +12% on every pass (inferred); `1e-5`: +41% |
| | global step ends at crossings | 2.9–3.3× plain (archive, T12) |
| | halve only the steps that hold a sign change | C and E; measured on TF24 |
| ψ, made zero | cut the node's step at its crossing and integrate it again in pieces | the incumbent; A, D and F |
| ψ, its leading term subtracted | a closed-form correction from values the step already rated | B |
| the average | chords at a wider r | helps R2 alone (plain at `3e-2`: 0.10ε); R1 still fails |

## 3. The candidates

| | move | mechanism | evidence | cost per pass | lines | verdict |
|---|---|---|---|---|---|---|
| A [first thought] | one mechanism for every pass | one templated cut routine in odelia | none | about 4% | about 240 | killed: R7 fails silently; its sketch detects at the end before the end is rated, and drops the search the pulse pairs need |
| B | weaken exactness | add h·(∂F/∂σ)·K, where K is σ's quadrature error along the dense output's P | toy: nudge range 37× narrower than plain's, as narrow as a cut; TF24: K off 11% in J's window, against the dense output only | 0.9% | about 250 | survives, unmeasured on TF24 |
| C | batch across the population | halve every step that holds a sign change | TF24: a_dG1 0.43 ε/3, R2 0.249ε, R4 1.6e-5 | forward +9.7–10.4% (+13.5% episodic), replays +4.8–5.2% (+6.7%) | about 110 | killed on R8 per pass |
| D | move the boundary | the cut owned by plant; odelia exposes the dense output and integration in pieces | inherits the incumbent's TF24 record | the incumbent's | about 540 | survives; first with E's walker fix and F's bracket rule |
| E | decide offline | halve the crossing steps in the program (as C) | toy | as C | about 135 | halving killed; its fallback, the walker fix, is kept |
| F | fast path for the typical case | the incumbent with one bracket rule | census of all 9247 cuts | the incumbent's | about 1650 | killed on R7 and R9; its census and bracket rule kept |

- *The floor:* plain integration at the tol where R2 passes. It costs +12% on
  every pass (inferred), so it fails R8.
- *Halving's convergence.* Two proposers reached halving independently. The
  judge reads that as evidence that it is the least mechanism meeting R1 and
  R2 at `1e-4` on long drought. Both priced it on long drought's clustering,
  at θ₀ and at `1e-4`, so it is also a shared blind spot:
  - episodic clusters less, and halving costs more there;
  - at `3e-4` halving's R2 is predicted at 0.35–0.43ε;
  - its halves are fixed at θ₀, while about 650 crossings change step at
    ±1e-2.

## 4. The verdict, provisional on one measurement

**First: D with the walker fix and the single bracket rule.** It is the
incumbent's per-node cut, re-homed and trimmed.
- *odelia knows steps; plant knows nodes.* odelia gains one hook, called after
  a finished step, and makes its dense output and its integration in pieces
  public. Detection, location, the five field reads, the pieces, the record and
  the implicit cut move into plant's `Patch`. The cross-package interface
  goes: `RatesParts`, `part_reads`, `part_rates`, `sign_values_in`,
  `taped_split` and the runtime refusals.
- *Walks stop splitting.* Each walk adds the resident's recorded end change,
  bit-exact as (walk unsplit − resident unsplit) + resident split.
  - J′ = J on the diagonal, at no runtime cost.
  - Off the diagonal the invader takes the resident's correction (3e-5 to 7e-5
    in ln J′), and its own crossings stay untreated, as today.
- *One detection rule:* a bracket is two readings of opposite sign. The
  stages' signs and a golden search beside the reading nearest zero supply the
  brackets.
- *Counts* are taken when a step commits. The incumbent counts before the
  validity check (`ode_step.hpp:588`).
- *Size and cost:* about 490 lines (inferred), against the incumbent's 1722.
  The cost is the incumbent's: 3.6% of a seven-pass run, 3.9% on episodic.

**Second, and first if M2 holds: B, the closed-form correction.**
- *What changes:* nothing is located, cut or integrated again. The kink's
  leading error term is corrected from the net production the step already
  rated at its six stages and its end.
- *How:*
  - P̂(u) is the derivative of the step's own dense output.
  - K = ∫σ(P̂) − Σ b_i σ(P_i).
  - The end gains h·K·∂F/∂σ, and is rated again.
- *Cost and size:* 0.9% a pass and about 250 lines. It deletes about 1.4k of
  the incumbent's lines. Walks run the same correction, so invaders' own
  crossings are treated too.
- *Its risks:*
  - at saturating pulse onsets the cubic misses about half of K;
  - steps at crossings are longer than its argument assumed (hL up to 0.56);
  - TF24 must supply ∂F/∂σ. Kept by hand, that is a second source of truth;
    forward-mode AD on the strategy's own templated rates would avoid it
    (not costed).

**Halving is your trade, not a winner.**
- *Against D with the walker fix,* it costs +2.3% of a seven-pass run (+3.8% on
  episodic), and +4.4 points on the forward (+7.0 on episodic).
- *In exchange* it has about 380 fewer lines. It also leaves the gradients'
  error at the kink's order, not the method's, so a looser tol is out of reach.

## 5. What decides it

Pre-registered by the judge (`design-search/judge/verdict.md` §8).
- **M2(a). B's leading term on TF24.** About two hours: a probe of about 30
  lines in plant that exposes TF24's ∂rates/∂σ, and no odelia change.
  - *The measurement:* integrate each crossing node finely in its recorded
    field, and compare plain's local error with h·B·K on long drought and
    episodic.
  - *B dies* if the J-weighted residual exceeds 30% of plain's error. B
    predicts about 12%.
- **M2(b). B's build gate.** About 250 lines, measured on plant's controller:
  - seven nudges and the quarter-spacing shift, over 48 floored traits;
  - R2 as both a second difference and a chord;
  - J′ = J;
  - bisection across a passage and a pair's birth.
  - B wins if every trait moves under 0.7 ε/3, R2 is under 0.25ε both ways,
    J′ = J to the bit, and no jump exceeds 1e-8. Otherwise D stands.
- **M1. Does the cut buy `3e-4`?** About an hour on the current build, with no
  rebuild: seven tolerances around `3e-4` and the shift, on plant's
  controller.
  - This matters more than either treatment's own cost. `3e-4` is about 1.2×
    fewer steps on every pass.
  - Whatever wins must be compared with the other at matched error, not at
    matched tol, as `OBJECTIVES.md` asks.
  - Run the same test on B once it is built.

## 6. Questions for you, each with its default

1. *R4.* Must the sweep return the derivative of the run's own map, or a
   gradient within ε of the converged one? Default: the run's own map.
2. *R7.* Must J′ equal J to the last bit? Default: yes, which the walker fix
   makes free. Should invaders' own crossings be treated? Only B treats them,
   within its 0.9%.
3. *R8.* Is the bar per pass or per run? Default: per pass, which rules out
   halving. Would you take halving's trade (above) for 380 fewer lines?
4. *R12.* May odelia say "node"? Default: no. Under the default, D's
   placement keeps nodes in plant.
5. *Predictable gradients.* `OBJECTIVES.md` asks that error fall with each knob
   at its order, and the ledger checked that for `J` alone. Should it hold for
   the gradients? Halving fails it; the cut passes, and B is unmeasured.
   Default: yes.
6. *Across the radius.* Must R1 hold across the resident's ±10%, as "Shared"
   implies? Treatments fixed at θ₀ decay there; ones that detect again on
   every replay do not. Default: yes.

## 7. Names

Every finalist's names say what happens, per `AGENTS.md`, and none keeps
`parts`.
- *D, in plant:*
  - `split_step`, the odelia hook, held by a concept;
  - `node_split {node, cuts, slopes, at_cuts, ratings}`;
  - `field_at` and `node_rates_in_field`;
  - `ode_splits_by_node`.
- *D, in odelia:* `dense_state` and `integrate_pieces`, made public. If any
  per-block name stays in odelia, F's renames apply:
  - `part` becomes `block`;
  - `part_split` becomes `block_cuts`;
  - `split_record` becomes `cuts_by_block`;
  - `unsplit_end` becomes `end_before_cuts`.
- *B:*
  - `ReadsPositivePart`, the odelia concept: `sign_values`,
    `positive_part_width`, `add_positive_part_errors`;
  - `positive_part_errors`;
  - `end_before_correction`;
  - `corrected_steps`;
  - `TF24_Strategy::positive_part_slopes`;
  - `ode_correct_positive_part`.

## 8. The refactor to the plant-owned cut, mapped

The user took the defaults to §6 and the plant-owned cut, for TF24 alone. This
section maps the change onto the stack's issue branches before any code moves.
It supersedes §7's names for D.

### Who owns what

- *Plant owns the cut:* which node to try, the field a node reads, rating a
  node in that field, the pieces, and the record. One plant body serves the
  forward, at double, and the sweep, at the active scalar. So the two passes
  cannot disagree about how a node is split, which was the review's first
  finding.
- *odelia owns the step:*
  - the dense output, the quartic through five reads, integration in pieces,
    and finding a sampled value's sign changes, all as numerics on the step
    just taken;
  - when the System is asked, the end rated again, the counts, and what a walk
    does.
- *A walk takes the recorded run's splits.* For each block the resident split,
  the walk's end becomes (walk's unsplit end − resident's unsplit end) +
  resident's split end. On the diagonal that is the resident's end bit for bit.
  Off it, the invader carries the resident's correction, and its own crossings
  stay untreated, as today.

### The data, first

In `ode_interface.hpp`, replacing `part_split`'s parallel arrays:

```cpp
// Where a block's sign value crossed zero, as a fraction of the step, its slope
// in that fraction there, and the rating the crossing was located at.
template <class Values> struct sign_change {
  double u = 0.0;
  double slope = 0.0;
  Values rating{};
};

// What a step recorded for one block it split: which block, where its components
// start and what they were at the end before the split, its sign changes, then
// each rating its pieces made, in order.
template <class Values> struct split_block {
  std::size_t block = 0;
  std::size_t first = 0;
  std::vector<double> unsplit;
  std::vector<sign_change<Values>> sign_changes;
  std::vector<Values> ratings;
};
```

- `solved_row` keeps `unsplit_end`, the evaluation at the end before the
  split, and holds `std::vector<split_block<Values>> split_blocks`.
- `taken_step<S>` is the step just taken, handed to the System. It holds
  references to the start state, the stage rates, the end's rate before the
  split, the end, and the sign values at the start, the five stages and the
  end (empty at an active scalar). Its members are
  `dense_state(u, first, out)`, `field_at(u, reads, out)`,
  `integrate_pieces(first, cuts, rate, own)` and `sign_changes(block, value_at)`.
- `SplitsSignChanges`, at double, asks for `sign_values(out)` and
  `split_sign_changes(step, record) -> bool`. The bool is true where the System
  rated anything, so the end is rated again.
- An active System asks for `split_as_recorded(step, record)`. Its absence on a
  System that splits is a compile error at the sweep, not a runtime refusal.

### What goes

- *From odelia:*
  - `RatesParts`, `part_width`, `part_reads` and `part_rates`;
  - `Step::split`, whose orchestration goes to plant and whose numerics go to
    `taken_step`;
  - `taped_split`;
  - `split_record` and its `searched` and `least_rate*` fields;
  - `end_sign_values`;
  - the parts-times-width layout check;
  - the runtime refusal in the sweep.
- *From plant:*
  - `field_recorded`, since walks never ask the System to split;
  - the dead `keep_field` restore;
  - the birth-date loop in a node rating, if a test shows it redundant;
  - the restated read layout, in favour of TF24's `cohort_reads`;
  - `r_ode_split_record`. `ode_splits` becomes the per-node counts, and their
    sum is the total.
- *From phylloptim (#17):*
  - the bisection's budget check, which can never fire;
  - the history comment carrying issue tags.

### What changes behaviour, each in its own commit with its measured effect

1. One rule finds a pair inside a step (F). The stage reading leaning furthest
   to the other sign is read on the dense output, with a golden search beside
   it if needed. It replaces the deepest-stage and nearest-zero rules.
2. Splits are counted when their step is committed (`push_step`), not before
   the validity check.
3. A walk takes the recorded run's splits, so J′ = J to the bit on the
   diagonal.
4. A node's field is TF24's cohort reads, water potentials in place of
   moisture.
5. TF24f opts out, by deleting its inherited `sign_value_aux()`. Splits under
   `ode_method = "rodas"` are refused when the run is set up, where they were
   skipped silently.
6. A cut whose slope reads exactly zero is held in the sweep, which otherwise
   stopped there.

### The sequence

There are no PRs yet. Each issue branch is rebuilt as a few single-purpose
commits on its base and force-pushed with lease, after the incumbent heads are
tagged so recorded measurements stay fetchable.

| branch (issue) | commits | gate |
|---|---|---|
| `ODELIA-53` (#53) | the step handed to the System, its numerics moved verbatim; then one pair rule; then counts at commit; then walks take recorded splits | odelia's suite; the first commit bit for bit against the incumbent's toy runs |
| `ODELIA-54` (#54) | the sweep rates the end reached first, then asks the System to replay | sweep against central differences on the toy |
| `PLANT-100` (#100) | the phylloptim pin to 0.9.1 | bit for bit |
| `PLANT-102` (#102) | TF24 nodes split in plant, with TF24f out, Rodas refused and counts per node; then the field as cohort reads | below |
| `PLANT-103` (#103) | the replay at the active scalar, with a zero slope held | below |
| `PHYLLOPTIM-17` (#17) | the budget check, the history comment, version 0.9.1 | phylloptim's suite |

The plant-dev harness readers of `ode_splits` and `ode_split_record`
(`run_record.R`, `walk_identity.R`, `equilibrium.R`, `final.R`) change with
`PLANT-102`. The gates are registered before the runs as the seventeenth
extension of `measurements/sign-changes/prereg.txt`:
- off, every run repeats bit for bit, FF16 included;
- the moved code repeats the incumbent's split run bit for bit: ln J
  2.539137243542 on the pinned program, and the sweep's lma elasticity;
- each behaviour change moves ln J by its measured amount, under 1e-8 for the
  pair rule and the cohort reads, and the 32-point scan still finds no pair
  uncut;
- J′ = J bit for bit at θ′ = θ;
- the incumbent's gates still hold:
  - J 10× nearer the reference at `1e-4`;
  - S4 within 2e-3;
  - the curvature at r = `1e-2` within 0.05ε of −43.44;
  - forward ≤ +6% and sweep ≤ +7.3% against plain, timed alone;
- a walk's extra end rating on each split row is measured.

### Size, estimated by file (hand-written code, tests aside)

| | incumbent | after |
|---|---|---|
| odelia `ode_step.hpp` | +514 | about +275: the view and its numerics, about 110 lines of sign changes kept, the sweep's call |
| odelia `ode_interface.hpp`, `ode_solver*.hpp` | +114 | about +100: the record, the concept, the hook, counts at commit, walks |
| plant `patch.h`, `species.h`, `scm.h`, strategies, control | +180 | about +200: the orchestration moves in, and the read layout and the record's R binding go |
| total | about 810 | about 575 |

What shrinks most is not the line count:
- one orchestration instead of two;
- four System methods that let odelia drive plant's internals become two calls
  that hand plant the step;
- the record is one vector of crossings per block;
- counts are taken where steps commit;
- J′ = J holds on the diagonal;
- three silent paths are gone: TF24f's unrecorded optimiser, Rodas, and a zero
  slope.

### Questions, each with its default

1. Rebuild the branches as fresh commits and force-push with lease, after
   tagging the incumbent heads (`sign-changes-incumbent` on odelia `1e5a2d7`
   and plant `91098156`)? Default: yes.
2. Tangent walks keep refusing a run that split, unchanged. Default: yes.
3. Take the cohort reads only if the gates above still hold. Default: yes.
