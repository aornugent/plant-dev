# Sign changes in net production: the problem as mathematics, and the options

This note restates the per-node sign-change problem as mathematics, from
`docs/geometry.md` and the record. It then sets out what a design search
found.
- *How the search ran:* under the system-design skill's deep search, with five
  proposers, each blind to the others and each on one framing move, plus the
  first thought, all judged by a separate agent with kill authority.
- *Its files* are in `measurements/sign-changes/design-search/`: the ledger,
  the six candidates, the judge's verdict, and every spike's script and log.

A bare section mark (§) is `grid-dynamics.md`'s in sections 1 to 5, and this
note's own from section 6 on.

**In short.**
- *The problem.* A step's error at a crossing is h²·a·ψ(u*). ψ averages to
  zero, so `J` is unharmed. Its derivative in θ is a staircase, and that is
  what the gradients and curvatures see.
- *The search.* Every design attacks one factor of that term: the kink a, the
  step h, or ψ, made zero or corrected.
- *The judge's ranking.*
  1. The incumbent's per-node cut, moved into plant, with the invader walks
     fixed and one detection rule: about 490 lines against 1722.
  2. A closed-form correction from values the step already evaluated: about 250
     lines and 0.9% of a run, unmeasured on TF24. It takes first place if one
     two-hour check on TF24 holds.
- *Halving the steps that hold a sign change* meets R1 and R2 on TF24 in about
  110 lines. It loses on runtime per pass: a forward costs 10–13.5%, against
  the 6% bar.
- *Built* as the plant-owned split (§8) and closed out (§9). Across the bank of
  rainfall records J′ = J to the bit, the sweep matches central differences,
  and `ln J` lies 3 to 13 times nearer the reference than without splits. A
  walk now integrates an invader's own nodes in pieces where the run split.

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

- Evaluating one node's rates, with its leaf solve, costs about 15 µs.
- A row costs about 4.4 ms, about 290 such node evaluations.
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
| ψ, its leading term subtracted | a closed-form correction from values the step already evaluated | B |
| the average | chords at a wider r | helps R2 alone (plain at `3e-2`: 0.10ε); R1 still fails |

## 3. The candidates

| | move | mechanism | evidence | cost per pass | lines | verdict |
|---|---|---|---|---|---|---|
| A [first thought] | one mechanism for every pass | one templated cut routine in odelia | none | about 4% | about 240 | killed: R7 fails silently; its sketch detects at the end before the end is evaluated, and drops the search the pulse pairs need |
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
  bit-exact as (walk's end before the split − resident's) + resident's split end.
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
  evaluated at its six stages and its end.
- *How:*
  - P̂(u) is the derivative of the step's own dense output.
  - K = ∫σ(P̂) − Σ b_i σ(P_i).
  - The end gains h·K·∂F/∂σ, and its rates are evaluated again.
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

### Vocabulary

One word per thing. "Rating" is retired: the split work coined it for three
different things, none of which it named.
- It meant evaluating the whole System's rates ("the end rated again").
- It meant evaluating one node's rates in a supplied field ("a node rating").
- It meant what such an evaluation solved for, as stored ("ratings",
  `at_cuts`).

| word | what it is | in code |
|---|---|---|
| evaluation | one call of the System's right-hand side at a state and time: build the field, compute every node's and the soil's rates | `derivs` (unchanged) |
| a node's rates in a field | one node's right-hand side, with the field supplied, not built; it also returns the node's net production | `node_rates_in_field` (plant; was `part_rates`) |
| solved values | what an evaluation's inner searches found (each leaf's operating point, the newborn's height) and the field it built, stored so a replay or the sweep loads them instead of searching again | `solved_values_t`, `solved_row` (unchanged); a record's field is `solved` |
| net production | TF24's P, which growth and the storage pool read through the smooth positive part | `net_mass_production_dt` (unchanged) |
| sign value | the value a System reports for each block after every evaluation, at whose zero the block's rates change form; TF24's is net production | `sign_values` (unchanged) |
| sign change | a zero of a block's sign value inside a step: its fraction u of the step, the slope in u there, and what the evaluation at u solved for | `sign_change {u, slope, solved}` (was the parallel `cuts`, `slopes` and `at_cuts`) |
| block, node | the components split together; odelia says block and never node, and plant says node | was `part` |
| split | integrating one block over a step in pieces that meet at its sign changes | `split_block`, `split_sign_changes`; "cut" leaves the code |
| piece | one interval of a split, integrated with the step's tableau | `integrate_pieces` (unchanged) |
| the end before the split | the state the tableau reaches before any block is split; its evaluation supplies the dense output's end rates | `at_state_before_split` (that evaluation's solved values); was `unsplit_end`, a name by negation. `state_before_split`, a block's components there, went with the carry (§9) |
| the field at five fractions | the field a node reads (the light field's knot data, then the soil's state) sampled at u = 0, ¼, ½, ¾ and 1 on the dense output, and the quartic through the samples at any u | odelia: `sample_fractions`, `sample_at`; plant: `sample_field`, `field_samples`; was `read_fractions`, `reads_at` |
| the step just taken | what odelia hands the System after a step: start state, stage rates, the end's rates before the split, the end and the sign values; with the dense output, the quartic, integration in pieces and the sign-change finder | `taken_step` |
| recorded row | the row of the resident's recording that a walk follows | the walk's `seed` parameter becomes `recorded`, since "seed" also names an adjoint seed |
| taking the recorded splits | a walk's split: each node the run split, of every invader laid out as the run's one species, integrated in pieces at the run's sign changes, held, in the run's recorded field samples (§9; it replaced carrying the run's move) | `take_recorded_splits` (plant) |
| split as recorded | the sweep's split: at the recorded sign changes, each moving with the parameters by the implicit function, with the pieces' evaluations loading the forward's solved values | `split_as_recorded` (plant), `implicit_value` (odelia, unchanged) |
| splits by block | committed split steps, counted per block; plant reports them per node | `splits_by_block()`, `SCM$ode_splits` |

- One coupling the names do not show: evaluating a node's rates leaves the
  System at that node's state, not the step's end.
  - So `split_sign_changes` returns whether it evaluated anything, and odelia
    then evaluates the end's rates again.
  - That matters because the row's state is read off the System.
- *Retired names:* `part`, `part_width`, `part_reads`, `part_rates`,
  `RatesParts`, `part_split`, `cuts`, `slopes`, `at_cuts`, `ratings`,
  `unsplit_end`, `read_fractions`, `reads_at`, `split_record`, `searched`,
  `least_rate*`, `field_recorded`, `taped_split`, `require_unsplit` and
  `ode_split_record`.

### Who owns what

- *Plant owns the split:* which node to try, the field a node reads, the
  node's rates in that field, the pieces, and the record. One plant body serves the
  forward, at double, and the sweep, at the active scalar. So the two passes
  cannot disagree about how a node is split, which was the review's first
  finding.
- *odelia owns the step:*
  - the dense output, the quartic through five reads, integration in pieces,
    and finding a sampled value's sign changes, all as numerics on the step
    just taken;
  - after the System is asked, the end's rates evaluated again; the counts;
    and when a walk takes the recorded splits.
- *A walk takes the recorded run's splits.* (Replaced in §9: a walk now
  integrates the invader's own nodes in pieces where the run split.) For each
  node the resident split, the walk's end becomes (the walk's end before the
  split − the resident's) + the resident's split end. On the diagonal that is
  the resident's end bit for bit. Off it, the invader carries the resident's
  correction, and its own crossings stay untreated, as before.
  - *Plant maps it,* because only plant knows which invader node copies which
    resident node. A walk of several invaders lays its state out unlike the
    resident's, so a position check in odelia would carry the correction onto
    none of them, and the answer would hang on the batching.
  - Every invader species with as many nodes as the resident at that row takes
    the resident node's correction. The resident must have one species; a run
    of several carries none, since no invader node is then known to copy one of
    its nodes.

### The data, first

In `ode_interface.hpp`, replacing `part_split`'s parallel arrays:

```cpp
// Where a block's sign value crossed zero, as a fraction of the step, its slope
// in that fraction there, and what the evaluation at that fraction solved for.
template <class Values> struct sign_change {
  double u = 0.0;
  double slope = 0.0;
  Values solved{};
};

// What a step recorded for one block it split: which block, where its components
// start and what they were at the end before the split, its sign changes, then
// what each evaluation in its pieces solved for, in order.
template <class Values> struct split_block {
  std::size_t block = 0;
  std::size_t first = 0;
  std::vector<double> state_before_split;
  std::vector<sign_change<Values>> sign_changes;
  std::vector<Values> solved;
};
```

- `solved_row` holds `at_state_before_split` (what the evaluation at the end
  before the split solved for) and `std::vector<split_block<Values>>
  split_blocks`.
- `taken_step<S>` is the step just taken, handed to the System. It holds
  references to the start state, the stage rates, the end's rate before the
  split, the end, and the sign values at the start, the five stages and the
  end (empty at an active scalar). Its members are
  `dense_state(u, first, out)`, `sample_at(u, samples, out)`,
  `integrate_pieces(first, split_at, rates, own)` and
  `sign_changes(block, value_at)`.
- `SplitsSignChanges`, at double, asks for `sign_values(out)`,
  `split_sign_changes(step, record) -> bool` and `take_recorded_splits(recorded,
  run_end, y)`. The bool is true when the System evaluated any node's rates, so
  odelia evaluates the end's rates again. A walk at another scalar, which has no
  `take_recorded_splits`, refuses a row that split; it would otherwise walk the
  step unsplit.
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
  - the birth-date loop in `node_rates_in_field`, if a test shows it
    redundant;
  - the restated read layout, in favour of TF24's `cohort_reads`;
  - `r_ode_split_record`. `ode_splits` becomes the per-node counts, and their
    sum is the total.
- *From phylloptim (#17):*
  - the history comment carrying issue tags.
  - The bisection's budget check could never fire. It stays and now fires
    (`>=`, as `uniroot_smooth()`'s), since the check is a guarantee.

### What changes behaviour, each in its own commit with its measured effect

1. One rule finds a pair inside a step (F). Of the readings at the ends and at
   the four stages strictly inside, the one leaning furthest to the other sign
   is read on the dense output, with a golden search beside it if needed. It
   replaces the deepest-stage and nearest-zero rules. *Built:* it moves nothing
   on the pinned program, and on a toy it finds a dip the two rules missed, a
   stage reading just short of zero where the dense output holds the other
   sign. The ends must be among the readings: seven of long drought's 14 pairs
   sit beside a near-zero start.
2. Splits are counted when their step is committed (`push_step`), not before
   the validity check. *Built*, with a toy that refuses a split end once.
3. A walk takes the recorded run's splits, so J′ = J to the bit on the
   diagonal. *Built:* to the bit on long drought, alone and as the middle of
   three invaders.
4. A node's field is TF24's cohort reads, water potentials in place of
   moisture. *Out:* it moved ln J by +1.07e-6 and split 11 node steps more,
   against a gate of 1e-8.
5. TF24f opts out, by deleting its inherited `sign_value_aux()`. *Built.*
   Splits under `ode_method = "rodas"` were to be refused when the run is set
   up, but plant cannot select the Rosenbrock stepper, so there is nothing to
   refuse. The tangent walks' refusal moved into odelia, where a walk at another
   scalar refuses a row that split.
6. A sign change whose slope reads exactly zero is held in the sweep, which
   otherwise stopped there. *Built*; no TF24 run here produces one.

### The sequence

Each issue branch was rebuilt as single-purpose commits on its base and
force-pushed with lease. The incumbent heads are kept on the branches
`archive/sign-changes-incumbent` of odelia and plant, since the proxy refuses
tag pushes.

| branch (issue) | commits | gate |
|---|---|---|
| `ODELIA-53` (#53) | `dc40d5f` the step handed to the System, its numerics moved verbatim, and walks that take the recorded splits; `480417a` one pair rule; `b907afb` counts at commit; `3e831d6` a walk at another scalar refuses a row that split | odelia's suite; the toys' runs bit for bit against the incumbent's |
| `ODELIA-54` (#54) | `1dc9efe` the sweep evaluates the end before the split, then asks the System to split as recorded | the toy against central differences; its adjoints bit for bit against the incumbent's |
| `PHYLLOPTIM-17` (#17) | `7230dcb` the budget check fires, the history comment goes, version 0.9.1 | phylloptim's suite |
| `PLANT-100` (#100) | `ed372143` the pin to phylloptim 0.9.1 | bit for bit |
| `PLANT-101` (#101) | `4103c0aa`, rebased onto it, its title and comments in the vocabulary above | bit for bit |
| `PLANT-102` (#102) | `b23cbb98` TF24 nodes split in plant, TF24f out, counts per node, walks carried onto each invader | the seventeenth extension; plant's suite |
| `PLANT-103` (#103) | `90db1450` the split at the active scalar, through the forward's body, a zero slope held | the seventeenth extension; plant's suite |

The plant-dev harness readers of `ode_splits` and `ode_split_record` changed
with `PLANT-102` (`run_record.R`, `walk_identity.R`); `final.R` reads the
incumbent's saved runs and is left as it was. The gates were registered as the
seventeenth extension of `measurements/sign-changes/prereg.txt`, and all hold
but the cohort reads':
- the forward and the sweep repeat the incumbent's to the bit on the pinned
  program: offspring production 12.6687361894839, 9247 node steps split on the
  same nodes, and all 50 gradient entries (the elasticity in `lma`
  −8.276268316). The incumbent's accuracy gates (J 10× nearer the reference at
  `1e-4`, S4, the curvature at r = `1e-2`) hold with them, by identity;
- off, every run repeats the incumbent's off to the bit, forward and sweep;
- J′ = J to the bit, alone and among three invaders;
- the forward costs 3.3% more than plain's and the sweep 2.2% more, alone and
  alternating; a walk of a split recording 2.9% more a row (one run each);
- plant's full suite passes on `PLANT-102` (4732 expectations) and `PLANT-103`
  (4733), but for `test-mutant.R`'s two FF16 expectations, which fail on the
  base too, and `test-control.R`'s list of Control's fields, which lacked the
  switch; the list is fixed in `PLANT-102` and passes.

### Size, by file (hand-written code, tests aside)

| | incumbent | rebuilt |
|---|---|---|
| odelia `ode_step.hpp`, `ode_interface.hpp`, `ode_solver*.hpp` | +598 −30 | +494 −41 |
| plant `patch.h`, `species.h`, `scm.h`, strategies, control | +172 | +321 |
| total | about 770 | about 815 |

The estimate of 575 was wrong. The orchestration moved into plant rather than
shrinking, and plant gained the walk's mapping onto invaders, which the plan
had placed in odelia. What shrinks is not the line count:
- one orchestration instead of two, the forward and the sweep sharing one body;
- the three methods by which odelia drove a node (`part_width`, `part_reads`
  and `part_rates`) become three that hand plant a step or a row
  (`split_sign_changes`, `take_recorded_splits` and `split_as_recorded`), so
  odelia no longer reads plant's layout;
- the record is one vector of crossings per block;
- counts are taken where steps commit;
- J′ = J holds on the diagonal, for every invader on the resident's schedule;
- two silent paths are gone: TF24f's unrecorded optimiser and a zero slope; a
  walk at another scalar now refuses where it walked a split step unsplit.

### Settled

- *The branches.* Each issue branch is rebuilt from its base as fresh,
  single-purpose commits and force-pushed with lease. The incumbent heads are
  kept on `archive/sign-changes-incumbent` first, so the measurements that cite
  them stay fetchable. The user left the organisation to us.
- *Tangent walks* keep refusing a run that split, now in odelia.
- *The cohort reads* went in only if the gates held; they did not, and are out.
- *The walk's mapping is plant's.* A walk of several invaders lays its state out
  unlike the resident's, so odelia cannot tell which invader node copies which
  resident node. Plant splits that node of every invader species with the
  resident's node count at that row, where the resident split it (§9; it
  carried the resident's correction there before); the resident must have one
  species, and a run of several keeps no splits for a walk. Several resident
  species would need each invader tied to the species it copies: the trigger
  for extending it.

## 9. Closing out: the review, the bank, the cost, the next steps

The rebuilt stack was reviewed under the code-review skill, run on the bank of
rainfall records, profiled again, and walked through the spec's next steps.
- *The bank* found the invader at `lma` × 2 failing its walk.
  - On long-wet and long drought the split caused it: the walk carried the
    run's move onto a state of another scale. That changed one decision: a
    walk now integrates an invader's own nodes in pieces where the run split.
    It replaces §8's *A walk takes the recorded run's splits*, the vocabulary's
    old *taking the recorded splits*, and `state_before_split`.
  - On episodic and dry the walk fails by itself, with splits or without: one
    of the stand's steps is longer than the invader's pools can take. The
    spec's 15-day cap removes it.
- *The review* asked for that change and for comments the cold read misread.
  Both are made.
- *The cost:* the split is 4.8% of the forward's samples and 3.0% of the
  sweep's, nearly all of it what the method must compute. Nothing changed.
- *The next steps:* four are one place and five leaky, each leaky one for want
  of one guard.

### The heads

| branch (issue) | head | since §8 |
|---|---|---|
| `ODELIA-53` (#53) | `c14ebfd` | the hooks' comments say what the bodies do (`237915b`); a walk splits its own blocks where the run split them (`c14ebfd`) |
| `ODELIA-54` (#54) | `9144d99` | the sweep hands the System the row's samples too |
| `PHYLLOPTIM-17` (#17) | `300d229` | the root-finder's stopping comment says what it tests |
| `PLANT-100` (#100) | `ed372143` | unchanged |
| `PLANT-101` (#101) | `4f8f7a2b` | its comments say what the bodies do |
| `PLANT-102` (#102) | `a2cb3df2` | its comments say what the bodies do (`abf3eba8`); the walk in pieces (`a2cb3df2`) |
| `PLANT-103` (#103) | `ae675637` | the sweep reads the row's samples, and a walk's sweep tapes its pieces |

### The walk, changed

- *What failed.* The eighteenth extension's G1 (`measurements/sign-changes/
  prereg.txt`). The invader at `lma` × 2, walked on the split base, raised on
  every record the carrying build reached: on long-wet at year 6.49, its
  density overflowing (log density 5.1e11); on long drought at 27.73 (7.1e4);
  on episodic at 2.96 (2.9e6). On `test-scm.R`'s three-year seasonal stand the
  same invader's fitness came out −3.9e-16. On the fixed build long-wet and
  long drought run, and episodic and dry raise (dry at 35.53): those two are
  the walk's own (below).
- *Why, on long-wet* (D1 and D3, registered before their runs; `walk_x2.R`,
  `walk_x2.log`, `d3.log`):
  - On plain's stand the walk runs (J′ 2.158e-21). Capping steps at 15 days
    does not help: the split stand's walk fails at the same instant.
  - Walked on the split stand without the carried move, it runs (J′
    2.158e-21). So the carried move sets the blow-up off.
  - The move was the run's, from its end before the split to its end after it,
    added to the invader's node. At twice the run's `lma` the invader starves:
    it holds about 1e-8 of storage where the run's moves reach 3e-4. 55 of 466
    moves left its storage below zero, which a walk's fixed steps never refuse.
    At year 6.482 the oldest node's storage went from −1.5e-6 to −2.6e-4, and
    the next step its density overflowed.
- *The change.* The run's row keeps the field at the five sample fractions,
  each sample in its own slot, as an evaluation keeps its field. An invasion
  takes those fields as it takes the stages'. A walk of a step the run split:
  1. ends the step at the state before the split, evaluated as the run's was;
  2. integrates each node, of every invader laid out as the run's one species,
     in pieces at the run's sign changes, held, with its own rates in the run's
     field;
  3. records the blocks it split. They count, and its sweep tapes them with
     the sign changes held.
  - `state_before_split` goes, and so does the carry. The run's own strategy
    still walks back to its fitness to the bit, alone and as the middle of
    three invaders.
  - It is the clean sheet's walk (*The review*, below). R7 and R3 could not
    tell it from the carry; OBJECTIVES' *never fails* could.
- *Verified* on the fixed build (`walk_fix.log`):
  - the stand's forward on the pinned program repeats to the bit (offspring
    production 12.6687361894839, 9247 node steps split). The split stands of
    long-wet, long drought and episodic, run on both builds, agree to the bit,
    so their stand results stand;
  - on long-wet the walk at `lma` × 2 runs: J′ 2.157625e-21, against
    2.157656e-21 beside the unsplit run;
  - in plant's tests, on the seasonal stand, the far invader's fitness is the
    one it has beside the unsplit run, within 1e-3 where the split moves the
    run's own by 4e-4. An invader at 1.5 × `lma` walked there sweeps to its
    central differences within 1e-6.
- *Episodic's and dry's failures are the walk's own* (D4, registered before
  its runs; `d4.log`).
  - On plain's stand the same walk fails at the same instant: on episodic with
    the same log density to every printed digit (2906420.333211 at year
    2.962963), on dry at year 35.5349 (log density 67.94 against the split
    stand's 67.91).
  - Episodic's stands take a step of 27.08 days to year 2.953 and dry's one of
    26.93 days to 35.512, the longest in each run. Cash–Karp is unstable on a
    pool past 3.73 relaxation times: 26.1 days for this invader's
    (`grid-dynamics.md` §8). Long-wet's and long drought's longest steps are
    21.2 and 25.1 days.
  - Capped at 15 days, the floor's cap, the walk runs on both stands: on
    episodic J′ 9.741109e-20 beside plain's and 9.741115e-20 beside the
    split's, as phase 1c found under rule A (9.7e-20); on dry 9.767685e-21 and
    9.766992e-21.
  - So G1 holds on both under the cap the spec already sets (item 7), and fails
    without it, whether or not the run splits.

### The review

Under the code-review skill at tier 3, for the odelia–plant boundary: a clean
sheet and a cold read, each by an agent blind to the diff. The record is
`measurements/sign-changes/review/`.
- *Verdict:* approve with changes, both made: the comments the cold read
  misread, and the walk.
- *The clean sheet,* from §8's ledger alone: about 235 lines, against the
  stack's 410 in odelia and 300 in plant. It differs in four places.
  1. *The field.* The sketch reads the stage reads' interpolant; the stack
     builds the field at five fractions on the dense output. The five samples
     hold `ln J` within 2.4e-9 of a field built at every evaluation. Explicit
     stages are first-order values of the state, so the stage reads hold the
     field to O(h²) between the abscissae (unmeasured). Kept.
  2. *The break.* The sketch puts it where the next piece's first evaluation
     reads P = 0; the stack at the zero on the dense output. The sketch's
     locate integrates a piece per iterate, six evaluations against one. Its
     reason is a misfit flipping that reading across the switch. That needs a
     hard switch, and TF24's positive part is smooth. Kept. It stays a
     candidate for R2's untraced residue, which falls like 1/r, as kinks in
     J(θ) would.
  3. *The walk.* The sketch integrates the invader's own nodes in pieces at the
     run's breaks; the stack carried the run's move. Taken (above).
  4. *The record.* The sketch keeps no state; the stack now keeps the five
     samples, and no longer the state before the split.
- *The cold read* predicted each of 39 elements from its signature before
  reading its body. 11 missed, and each comment now says what the body does.
  The misses that are behaviour, not wording, are the finding and the question
  below.
- *Decisions reopened:*
  - D1, plant orchestrating the split, and D2, the whole end evaluated again:
    settled by the user's decision with R12, and by R4.
  - D3, five samples a split step: settled by R8 (2% of the split's cost).
  - D4, the carried walk: overturned by the bank.
  - D5, a run of several species dropping its splits silently, and D6, no
    split outside Cash–Karp, silently: the question and the finding below.
- *What must always be true:* the sweep tapes the map the forward took, a
  walk's included. Structure keeps it:
  - one plant body at either scalar (`sample_field`, `node_value_at`,
    `split_node`);
  - the forward's sign changes and solved values replayed in order, their
    count checked.
  One convention is left: `split_sign_changes` returns true wherever it moved
  the System's state, which plant ties to whether it sampled.
- *Finding.* Splits stop silently outside Cash–Karp. Merging `ark-step` and
  `ark-soil` makes that reachable: a run asking for ARK and splits would split
  nothing, with every number finite. With that merge, plant refuses
  `ode_split_sign_changes` under any `ode_method` but rkck, where Control is
  checked.
- *Question, with its default.* Why does a run of several species drop its
  splits for a walk silently? Default: keep dropping them, and report it with
  R8's diagnostics when they are built.

### The bank

The eighteenth extension (`measurements/sign-changes/prereg.txt`; `bank.log`,
from `bank.R` over `bank.sh`'s runs): every record at seed 31, 108 uniform
nodes, the tied tolerance at `1e-4`, with splits and without; the split base
and its nudge on the fixed build.

| record | node steps split | G1 | G2, J′ − J | G3, sweep − central difference | G4, `ln J` − reference, split / plain | G5, resident entries over ε/6, split / plain (largest) |
|---|---|---|---|---|---|---|
| constant | 41 | holds | 0 | −3.6e-6 | 1.4e-9 / 1.6e-9 | 0 / 0 (0.000ε / 0.000ε) |
| long-wet | 8972 | holds | 0 | 8.5e-4 | 6.2e-6 / 3.5e-5 | 0 / 1 (0.04ε / 0.25ε) |
| episodic | 6210 | × 2 raises, uncapped | 0 | 1.6e-3 | −3.6e-6 / 2.8e-5 | 0 / 9 (0.08ε / 0.44ε) |
| dry | 9000 | × 2 raises, uncapped | 0 | 1.0e-3 | −1.8e-5 / 5.7e-5 | 0 / 5 (0.14ε / 0.37ε) |
| long drought | 9247 | holds | 0 | 1.3e-3 | 2.8e-6 / 3.7e-5 | 0 / 9 (0.09ε / 0.52ε) |

- *G1, never fails.* Every run finishes, every walk at `lma` × 0.5 runs with its
  gradient, and so does × 2 on constant, long-wet and long drought. On
  episodic and dry the walk at × 2 raises with splits or without, on one step
  of about 27 days, and runs under the 15-day cap (D4, above).
- *G2, J′ = J,* to the bit on every record.
- *G3, the sweep is the split map's derivative:* within S4's 2e-3 of the
  replays' central difference in `lma` on every record.
- *G4, `ln J` against the split at `1e-6`.* On every record that crosses, the
  split lies 3 to 13 times nearer than plain, and at `1.05e-4` too, as
  expected on episodic, dry and long drought. Every error is at most 0.003ε.
  Constant rain crosses at 41 node steps, and the two arms are alike.
- *G5, the nudge.* Each entry's move under `tol` × 1.05, in units of its ε
  as `spot_check.R` reads it (without OBJECTIVES' floor of 0.01, so stricter).
  The split's resident moves no entry past ε/6 on any record, against up to 9
  of 49 for plain's (0.52ε). Its invader at θ′ = θ moves none on the four
  records that cross, against up to one for plain's (0.30ε). On constant the
  invader's gradient is −1.4e17 on both arms, the uniform nodes' artefact
  already on record (`measurements/spot-check.md`), and the nudge moves it by
  about 1e13ε on both.
- *G6, the splits and the cost:* the node steps split are in the table; the
  phase times in `bank.log` ran beside up to six other jobs, so they are
  reported, not compared.
- *The invader's gradient, under the walk's change* (D5 and D5b, registered
  before their runs; `d5.log`). J′ = J holds to the bit, but at θ′ = θ the
  walk's change moves the invader's gradient by up to 0.38ε (episodic's
  `root_P50`; 0.07ε on long-wet, 0.017ε on long drought). Each walk's
  gradient at `1e-4` lies nearer the run at `1e-5` made its own way, so
  neither reference settles which is nearer the limit.
  - Post hoc: on 43 of 48 entries the two approach each other from opposite
    sides between `1e-4` and `1e-5`, their gap falling to a median 0.32 of
    itself.
  - If each error falls by that factor, their meeting point puts the walk in
    pieces within 0.12ε (median 0.010ε) and the carrying walk within 0.26ε
    (median 0.017ε). Both lie within ε/3; the walk in pieces about twice as
    near.

### The cost

Profiles of long drought's pinned program at `1e-4`, by gperftools, beside the
bank's jobs (`rebuilt_profile.txt`, `rebuilt_profile.sh`):
- The split is 4.8% of the forward's samples: the pieces 45%, locating the sign
  changes 38%, the end evaluated again 17%. Nearly all of it is leaf solves.
- Locating, 1.8% of the forward, is the one share the method leaves to choose,
  through its iterations. Nothing changed.
- In the sweep the split tapes 3.0% of the samples. The reverse pass over what
  it taped runs inside the tape's own frames, which the profile does not place.
- A walk now pays for its pieces: 3.3% of a walk's samples and 2.4% of its
  sweep's.
- The bank's phase times ran beside up to six other jobs, so they are reported,
  not compared.

### The next steps, walked through the split

The review's change simulation walks a planned change through the code and
lists every site it must edit or remember. It classifies the change:
- *one place:* the edit alone suffices;
- *leaky:* the edit is in one place, but it must remember a fact from
  elsewhere that nothing at the edit site shows;
- *shotgun:* several edits must agree.

The first review, of the incumbent, called two changes leaky.
- *Splitting invaders,* because the split rebuilt the field from the System's
  own state, while an invader reads a recorded one.
- *The multirate soil,* because the split read the soil from the step's own
  interpolation.
- Node rule D was one place.

Walked again through the rebuilt code:

| next step (the spec's item) | what the split needs of it | class |
|---|---|---|
| 5, the soil stepped on its own (multirate) | `sample_field` reads every component, the soil's too, through `taken_step::dense_state`, the members' Cash–Karp step. The soil's samples must come from its own inner steps, as item 5 says, and `SplitsSignChanges` names Cash–Karp's `taken_step` | leaky: the multirate step must serve the whole state's dense output, the soil's from its inner steps. *Designed* to close by structure: `taken_step::dense_state` serves the block from the predictor's samples at the five fractions, and `sample_field` does not change (`design-soil-alone.md`) |
| 6, node rule D | a block is a node, and nothing counts nodes. The split samples the field five times a split step, not once an evaluation, so the spread's 16-point crowns cost it five field builds a split step | one place |
| 6, the invader's own sparser introductions | `take_recorded_splits` finds the invader's copy of a run's node by position, where the invader has the run's node count; a thinned invader matches none and walks unsplit, silently | leaky |
| 7, the window's weight and the 15-day cap | splits run after the error estimate keeps a step, whatever set its size; the cap is also what episodic's and dry's walks at `lma` × 2 need (D4) | one place |
| 8, R8's diagnostics | the per-node counts are there (`SCM$ode_splits`), walks' included | one place |
| ARK for the constant record (`ark-step`, `ark-soil`) | `split()` runs only under Cash–Karp and returns silently otherwise | leaky: a run asking for both splits nothing, with every number finite (the review's finding). *Moot:* ARK retires, since the soil stepped on its own matches it under constant rain (`measurements/soil-alone/`, S3) |
| several resident species (regnans's assembly) | `run_mutant` drops a run's blocks and samples when it has several species, and `take_recorded_splits`'s layout match assumes one | leaky: two sites encode one resident species |
| invaders split at their own sign changes | a walk's pieces read the run's recorded samples; its own sign changes would be found in them and moved in its sweep by the implicit function, as `split_as_recorded` does for a non-zero slope. odelia must hand the walk every step, not only those the run split | leaky; not planned |
| the acceptance suite | the switch is a Control field; the split's own tests are in odelia and `test-scm.R` | one place |

- *Leaky, then, means a fact to remember at the edit,* which each leaky row
  names. Each takes one guard where the fact lives:
  - the multirate soil: the step type the concept names gives the whole
    state's dense output;
  - sparser introductions: the walk finds the run's node by its birth date, not
    its position, and refuses an invader it cannot map;
  - ARK: the refusal in the finding above;
  - several resident species: each invader tied to the species it copies (§8,
    *Settled*).
- *Splitting invaders is no longer leaky as the first review found it.* The
  split no longer rebuilds the field from the System's own state: a walk reads
  the run's samples. What stays leaky is splitting at the invader's own sign
  changes, which no planned step needs.
