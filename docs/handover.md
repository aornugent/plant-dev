# Handover

## Principles

The user's, verbatim. They apply to all work here.

### Laziness Protocol

Apply when refactoring, evaluating diff size, or tempted to add abstractions, layers, or signal threading. Bias toward deletion and the smallest change that solves the problem

Writing code is cheap for you, which makes over-engineering easy. Counter it by borrowing a human maintainer's fatigue. Aim for the most result with the least code and complexity.

- **Prefer deletion.** When asked to refactor or improve, look for removals before additions.
- **Maintain a flat call hierarchy.** Avoid deep call chains. A rich interface that hides substantial work is not a deep call chain. If answering a question requires tracing through more than 3 files or layers, flatten it.
- **Consolidate decisions.** Do not repeat the same choice in several places. Put it behind one source of truth and pass the result as a simple flag.
- **Minimize the diff.** Make the smallest change that solves the problem. Fewer lines beat "elegant" boilerplate.
- **Question the threading.** If a task asks you to pass a new signal through types, schemas, pipelines, or similar layers, stop and look for a more direct path.
- **Sweat the small leaks.** Remove tiny pass-throughs, representation leaks, and duplicated choices before they spread. Small leaks compound into permanent coordination costs.

**Prime directive:** If a human developer would find the code exhausting to maintain, it is a bad solution. Be lazy. Stay simple.

### Subtract Before You Add

Apply when sequencing an addition, refactor, or rewrite. Remove dead weight, redundant validators, and stub references first, then build on the simpler base.

When evolving a system, remove complexity first, then build. Deletion gives you a simpler base, which makes the next addition smaller and less brittle.

**Why:** Adding to a complex system compounds complexity. Removing first cuts the surface area, reveals the essential structure, and usually makes the next design obvious. Default to subtraction.

Make simplification a continual investment. Leave the design slightly simpler and more capable behind the same or smaller surface than you found it.

**The pattern:**
- Sequence removal before construction
- Cut before you polish (get to the minimum before investing in quality)
- Design for observed usage, not speculative edge cases
- No speculative validators, parsers, or guards beyond what the spec demands
- Out-of-spec features drag validators behind them. Persistence, retry-on-startup, and schema migration each need guards to defend their inputs.
- Simplify prompts (remove redundant instructions, excessive templates)
- When a reference has no novel content, delete it rather than leaving a stub

### Minimize Reader Load

Apply when reviewing or shaping code that's hard to trace. Count layers between question and answer, and hidden state in the reader's head; collapse one-caller wrappers and shrink mutable scope.

Maintainability is the work a reader must do to understand code. Track two axes:
1. **Layers to trace.** How many indirections sit between the question and the answer.
2. **State to hold.** How much hidden or mutable context the reader must keep in their head.

**Why:** Code is read far more than it is written. LOC, cyclomatic complexity, and "clean architecture" are proxies. Reader load is the thing that matters. The two axes are independent. A flat file with 50 globals can be as hard to reason about as a 6-layer adapter stack. Guard both. This is the human analog of Guard the Context Window: working memory is finite for readers too.

**The pattern:**
- **Collapse layers** that do not earn their keep: wrappers with one caller, adapters with no second implementation, indirection introduced for a future that never came. Inline them.
- **Make adjacent layers change the abstraction.** A layer that repeats the same methods and arguments adds reader load without compression. Collapse pass-through layers.
- **Demand interface compression.** A broad interface that hides little complexity makes readers learn both the surface and the implementation. Prefer boundaries that hide meaningful decisions.
- **Shrink state scope:** prefer pure functions (returns over mutations), locals over fields, fields over module state, and module state over globals. Derive instead of sync.
- **Name the invariant at the boundary,** not in every consumer, so the reader learns it once.
- Before adding a layer or a piece of state, ask: does this reduce reader load somewhere else by at least as much?

**The test:** Can a new reader answer "where does X come from?" and "what can change X?" in under 30 seconds? If not, cut layers or cut state.

### Foundational Thinking

Apply before writing logic: choosing core types and data structures, sequencing scaffold-vs-feature work, asking what concurrent actors share. Get the data structures right so downstream code becomes obvious

**Code-level decisions** protect simplicity. Over-engineering is often a premature decision that closes doors. The right foundational data structure keeps doors open.

**Data structures first.** Get the data shape right before writing logic. The right shape makes downstream code obvious. Define core types early, trace every access pattern, and choose structures that match the dominant paths. A data-structure change late is a rewrite. Early, it is often a one-line diff.

At code level, DRY the structure, not every line. Types and data models should converge. Three similar statements still beat a premature abstraction. Prefer explicit over clever. Test behavior and edge cases, not line counts.

**Concurrency corollary.** Before sharing state between actors, ask "what happens if another actor modifies this concurrently?" If not "nothing", isolate.

**Scaffold first.** If something helps every later phase, do it first. Ask "does every subsequent phase benefit from this existing?" CI, linting, test infrastructure, and shared types are scaffold. Sequence for option value: setup before features, tests before fixes. Keep commits small and single-purpose.

Each increment should land a coherent abstraction or deepen one that exists. Do not spread a new capability across callers as special-case coordination.

Subtraction comes before scaffolding: remove dead weight first, then lay foundations. 

### Model the Domain

Apply when writing stateful logic, or when code branches a lot or repeats a shape assumption across files. Encode the domain in a structure instead of scattered conditionals.

Encode the real domain in a data structure instead of scattering it across conditionals.

**Why:** Scattered booleans, repeated shape assumptions, and branching spread across files are accidental complexity. A structure that matches the domain makes invalid states unrepresentable and deletes branches. Choosing it at write time is cheap; recovering it later reads as a refactor and gets deferred.

**Reach for structures like these:**

- A state machine instead of scattered booleans, phases, or lifecycle checks.
- A typed object/model instead of loose parameters or repeated shape assumptions.
- A map, registry, lookup table, or discriminated union instead of branching spread across files.
- A reducer or command/event model instead of ad hoc state mutations.
- A module organized around one body of domain knowledge instead of a sequence such as load, validate, transform, and save. Execution order is not ownership.
- A small module boundary that gathers repeated behavior, ownership, or invariants.
- A queue, cache, index, graph/tree, or normalized collection where the data access pattern calls for it.
- Any other structure that fits. The list above covers the common cases only. When none fits, work out what the code must never allow and how the data gets read, then find the structure that encodes exactly that.

Do not force an abstraction. Prefer boring code if the current shape is already clear, local, and unlikely to grow. Be skeptical of an abstraction that adds indirection without removing branches, duplicated rules, invalid states, or lifecycle risk.

The tell that you skipped this is a new feature that grows an existing if/else chain by one more branch, or a second boolean that must stay in sync with the first. Temporal decomposition is another tell. Phase-named modules repeat the same domain rules across steps.

## Progress against the design

The goal is `OBJECTIVES.md`. The design is `docs/design-grid-controller.md`:
its search under the system-design skill, what it rests on, and the arc from
here to finished. The assessment that led to it is `docs/assessment.md`, whose
steps the sections below record. `docs/geometry.md` puts the problem in one
picture: spaces, metrics, error and stability, the laws that price the mesh,
and the frontier they draw, with its operating point (§6).

| the arc | state |
|---|---|
| 1a. the chain's weight and treatment | done: the ×10 weight passes for both roles (−20.7%); the implicit chain passes at `1e-5` for the resident (−36.8%), and saves 60% under constant rain; next, the chain alone's estimate in ARK's norm (`grid-dynamics.md` §10) |
| 1b. the pair and its interpolant | done: keep Cash–Karp, with its own free fourth-order extension for events (5.9% of a forward); Dormand–Prince is worse on TF24 and is dropped (`grid-dynamics.md` §11) |
| 1c. invaders under long steps | done: keep the 15-day cap, on the floor too; no invader sub-steps under Cash–Karp; the cap under Dormand–Prince is open (`grid-dynamics.md` §8) |
| 3, brought forward | done: a weight per state in odelia's controller and plant's patch, the mechanism of the chain's weight and the window's (`state-weights` on both forks); plant reproduces the driver's weighted runs bit for bit |
| 1a, round two | done: the implicit chain with the chain alone's soil estimate passes at `3e-5` for the resident (−44.3%; −67% under constant rain); the explicit weight's ceiling is ×20 (`grid-dynamics.md` §10) |
| 1c, combined | done: soil ×10 with rule A and the 15-day cap, under a bound of 100 on every weight (`ode_weight_max`), is Cash–Karp's setting: every gradient finite, every walk run, 31–34% of a gradient run saved, the accuracy and nudge tests passed (`grid-dynamics.md` §8). Unbounded, the product weight (1000) let soil stages reach the potential ceiling in accepted steps |
| ARK on three records | arkc with the walks saves 42–55% of a gradient run and never fails, but at `3e-5` misses the accuracy bar on long drought and episodic (0.36–0.40ε). Refuted: the soil's weight sets it. At `1e-5` the long-drought error falls 3.1×, a smooth bias from ARK's fourth order, so at matched error bounded Cash–Karp wins on the pulsed records and ARK's place is constant rain (`grid-dynamics.md` §10) |
| ARK built | the implicit chain in odelia and plant (`ark-step`, `ark-soil`), the driver's arkc bit for bit at three tolerances, both roles' gradients finite; next, arkc on the pulsed records with walks (`grid-dynamics.md` §10) |
| invader thinning | parked until the schedule rules are built: an invader's members thinned by its own share of `J′` under the root law, emulated exactly, keep 53–66% of its walk and sweep at ≤ 0.17ε in `ln J′`; the selection gradient and the diagonal unmeasured (`grid-dynamics.md` §14) |
| the soil stepped on its own | Done on the driver. Where the uptake is under 10% of the soil's budget, the soil is integrated on its own under an extrapolated uptake, with a corrector. The registered version fails its pass on `J` by 2.6% on episodic. With the coupling's error judged at the members' weight, it passes every criterion on both records and saves 29–41% of rows at matched error in `J`, though that error stops falling below `3e-5`. The user decided it joins the build, with its tuning left to the later scheduling heuristics (the design doc's 1e and phase 3, item 2; `grid-dynamics.md` §15) |
| the node axis on long-wet and long drought | Done. Spread uniform nodes report their own error on both records (square-law ratios, companions reporting 0.95 and 0.98 of the error); graded nodes, lumped or spread, do not (companions 0.65–0.80). The spread's two-rung extrapolation is the cheapest answer with an honest estimate. Thinning after b = 10 fails with the spread as lumped. Sorting the crowns before the light field's sum costs nothing, while walking every node costs 23% of a forward (`grid-dynamics.md` §16) |
| next | Nothing is running. The events design goes to the Oracle first: `docs/oracle-consultation-events.md` asks how to build per-member events for the resident's second derivatives and for the invader optimising loop, in the strategy consult's thread. It is checked against the record and scanned for domain words, and waits for the user to send it. Phase 3 can start with the multirate soil step and the spread; the crowns' height sort gets its own design turn first; the chosen rule's remaining ladders (dry, episodic, the constant record) wait |
| the acceptance suite | designed in the spec: the objectives as bounded tests against brute-force references, in tiers; its build is held until the user starts it |
| 2. the node axis | Decided: D, the spread, goes into the build, and B stays an option to consider later (§16). The height sort is agreed in principle and gets its own design turn. The chosen rule's ladders on dry, episodic and the constant record are not run |
| 3. the build | can start: the multirate soil step and the spread are now decided in, beside the items phase 1 settled. The events still need their design, and the spread's finest rungs wait for the height sort's design turn |
| 4. on the bank | the finish line |
| after: performance | the sweep's three changes (about 2×) and the warm start, profiled, not built |

The assessment's steps, done: ε (step 1); the enablers, a setting and `PLANT-98`
(step 2); the floor spot-checked (step 3); the headroom's causes on both axes,
with both grid replies and the strategy reply tested (step 4); the curvature
ladder at seed 31 (step 5).

**Step 1: done.** Eight daily-weather seeds of long drought, run with
`harness/run_record.R` (`ATOL=1`) on v12t at `tol = 1e-4` with 108 uniform nodes. The table
is `docs/measurements/eps-spread.md`, and `docs/assessment.md`'s step 1
summarises it.
- ε is 0.025 in `ln J`. For elasticities it is 0.087 (`lma`) and 0.019
  (`a_dG2`) for residents, and 0.20 and 0.050 for invaders, and never under
  0.01 (`OBJECTIVES.md`).
- At seed 31 the setting is inside ε for `ln J`, `lma` and `a_dG2`, by about 30×
  in time and 2.4–6× in nodes.
- Eleven moves exceed ε, ten of them in elasticities below 0.1 in size. The
  resident's `a_st3` moves by 2.3 sd between 108 and 215 nodes.
- The invader's elasticities are 2.7–4.5 times the resident's for `lma` and
  `a_dG2`, and finite differences confirm both.
- So on this climate accuracy mostly does not bind at these settings. Steps 3 and 4
  ask how far each axis loosens within ε, and whether other regimes bind sooner.
- *Curvatures, measured after* with `harness/curvature.R`: `lma`'s own curvature
  has ε 1.2 for residents and 4.0 for invaders, from chords over ±1e-2 on one
  grid. `OBJECTIVES.md` does not carry them yet; that is the user's edit.

**Step 2 (a), the pool's tolerance: a setting.** With `ode_tol_abs =
1e-4·ode_tol_rel` on v12t, `J`'s error on long drought is within 0.46·tol from
`1e-3` to `3e-5`. At `1e-4` it is +3.7e-5, against +8.1e-4 at plant's default.
Its nudges' median is +3.8e-5 with standard deviation 1.6e-5, against the
driver's per-pool scale's −4.0e-5 and 1.2e-5. It costs about 10% more than
the per-pool scale and needs no code. Step 3 re-checks it on the bank,
by `docs/assessment.md`'s decision rule.

**Step 2 (b), the stage guard: `PLANT-98`, aornugent/plant#98.**
- The change deletes TF24's stage check and `storage_domain_tol`, and keeps the
  refusal of a step whose end leaves a pool below zero.
- The three tests that expected `storage is negative` now state what happens.
- The measurements are in `docs/assessment.md`'s *(b) as measured*:
  bit-identical where the guard never fired, and invaders from `lma` ×0.7 to ×2
  reproducing the probe build's guard-off runs exactly.
- A walk commits a stage far below empty. At a zero offset on the height
  coordinate, one invader fails because its density overflows.
- The whole-run gradient reference is recaptured, because one refused attempt set
  the base run's steps on its drought and seasonal stands. The other three are
  bit-identical, and both builds agree at `tol = 1e-6`.
- Full serial suite: 4663 pass and 4 fail before the recapture. Two are the known
  panels, and two are the whole-run rung's, which then passes.

**Step 4.** The consultation,
`docs/archive/oracle-consultation-grid-controller.md`, went before M8 carried ε.
The reply is `docs/archive/oracle-response-grid-controller.md`, and
`docs/assessment.md`'s *The reply's tests* has what was measured, with a verdict
in *Where the reply leaves the design*: the kink binds curvatures and the
resident's nudges, both have a fix that needs no code, and the reply's remedy is
worth at most the cost of the tighter tolerance.
- *Its claim holds:* on one grid, a curvature taken between the gradient's jumps
  is off at any tolerance. In `lma` at seed 31 it is 34% below the smooth value
  for the resident and 3% for the invader: 13ε and 1.4ε. A chord over ±1e-2, less
  its `O(δ²)` term from the second difference of `ln J`, is within 0.2ε for both.
- *The chain's margin buys no radius,* for 9.6% more member evaluations. Walks
  from `lma` ×0.9 to ×1.1 keep `J` within 1.2e-4 with or without it. Their
  error ratios reach 13–130, set by the pools, so the walked ratio is no radius
  diagnostic.
- *The split's first cut does not make `J` smooth.* The driver's `LOCAL`, with
  each crossing found anew at each θ, brings the chord at 1e-3 nearer the wide
  one. But four crossings change step and a grazing dip disappears within 1e-4
  of θ₀, and `J` jumps by 1.7e-6 there. The reply's version, a fixed event
  structure differentiated through the crossing times, is an implementation in
  odelia's sweep, not a test.
- *The floor's grid holds the resident's gradients from `lma` ×0.95 to ×1.1,*
  all 48 elasticities within ε of runs adaptive there, but not at ×0.9, where
  two exceed ε and fifteen ε/3 (`docs/assessment.md`, step 4(c)). `J` agrees to
  7.2e-5 throughout.
- *Deleting the end-state refusal changes nothing here:* the one attempt per
  run it refuses, the error test rejects anyway at the same retry size, so the
  seven nudges come out bit for bit the same.
- *Not yet tested:* nodes at the creation spans' edges, adjoint-weighted control,
  the pool as `asinh`, and a warm-started inner solve.
  - Long drought has 56 gaps in creation, so edge nodes alone are about 114,
    more than the 108 uniform ones whose error is 4.5× inside ε.
  - Steps more than 10 days after rain are 23% of member evaluations and mostly
    pool-bound, so a pool variable saves at most about that here.
  - The inner solve is 85% of instructions by our own profile, so a warm start
    is the largest lever left; testing it means counting evaluations inside
    phylloptim's solve.

**Step 4, the second reply.** The follow-up with step 3's measurements went to
the Oracle. Its reply, the second in
`docs/archive/oracle-response-grid-controller.md`, reads the creation axis as
a canopy: a first-mover layer at each window's opening, the windows' edges, and
a fate front between canopy and understory. Its experiments 1, 3 and 4 are in
`docs/measurements/creation-grid.md`, and `docs/assessment.md`'s *Where the
second reply leaves the design* has the verdict.
- *The constant record is resolved.* Creation runs past the founders' front, to
  5.20 and again from 11.11, so the reply's rule as written is 14% high. With the
  first window graded from a day, the understory represented at any spacing and
  nodes every 1/16 day around the front, 150 nodes converge `J` at 289.274, the
  resident's `lma` elasticity at −6.94 and the invader's at −186.2. The schedule
  is `harness/graded_times.R`'s `const_Gbf16`.
- *The invader's cliff there is the model's, and smooth* once the front is
  resolved: `(ln J′)″ ≈ −2.5e4`, so its slope changes by its own size over
  |g|/|g′| = 0.0075 in `ln lma`.
- *On long drought uniform nodes are on the square law from 108,* for `J`
  (ratio 4.3) and for the resident's gradients. The 54-node rung was what fit no
  power law. The 215-node companion estimates the 108-node error to 1.18 times
  for the resident.
- *On uniform nodes the invader's gradients are on no power law:* on 33 of 44
  quantities the move from 215 to 429 reverses the move from 108 to 215, and the
  companion overstates their error 2.3-fold.
- *On the reply's graded ladder they are on the square law,* as are `J` and the
  resident's: 39 of the invader's quantities resolved, median ratio 3.9–4.0, one
  below zero, and the 125-node grid's companion estimates its error to 1.01
  times. Grading wins on the invader's gradients at a matched cost from about 250
  nodes (0.040ε against 0.25ε), and loses on `J`. On wet only `J` was graded; its
  ratio reaches 3.59 by 986 nodes.
- *Its mechanism for the first-mover layer's width fails:* members born before
  3.1 on long drought all end at the canopy height, while their net reproduction
  e-folds every 0.43–0.9.
- *Not run:* the sweep's panel estimate (it needs the sweep's adjoints of the
  field intermediates) and the self-term (a change in plant).

**Step 4, what sets the node error.** On long drought, from splits of each move
panel by panel, the gap's edges in and out, the crowns' overlap at the top, and
the invader's gradient by node (`docs/measurements/creation-grid.md`, *What sets
the node error on long drought*).
- *Two errors of opposite sign,* both from interpolating in birth date a profile
  that falls by e every `L`: the interpolant of net reproduction lies above it,
  and the coarser hats over-count the stand's water use
  (`docs/measurements/field-adjoint-map.md`).
- *On uniform nodes both sit at the layer's top,* where neighbouring nodes are
  2.8–4.8 crowns' top layers apart in height in the first half year. The
  invader's `lma` elasticity there is +0.30 in one and −0.29 in the other at 108
  nodes. By 215 → 429 the first has fallen 11-fold and the second 4.2-fold, so
  their difference changes sign: the reversals.
- *The graded opening shrinks them 8- and 40-fold.* From an overlap of 1.15 or less at
  the top, every quantity of both roles is on the square law and the companion
  reports 1.0–1.2 of the error; from 1.85 up it under-reports the invader's,
  0.24–0.75.
- *The gap's edges do not matter,* to 0.05ε.
- *So the proposal is B:* the graded first window, refinement only by halving,
  the coarser rung as companion, and the extrapolation reported. G1 and G2
  together give the invader's median error 0.006ε for 3.81e6 member steps.
- *The node splits now weight each node by the density of patches of its age.*
  The earlier tables left it out; no recorded part moved by more than 0.04% of
  `J`.

**The grid's cost and error, debugged** (`docs/grid-dynamics.md`). From the runs
on disk and a few driver probes:
- *What a gradient run pays.* About seven forwards: the forward, two sweeps of
  2.6 and the invader's walk of 0.8. The walk and the sweeps pay rows, the
  members on each accepted step; rejections and the forward's cost per
  evaluation are paid once. So rows come first, then the sweep's cost per row,
  the forward's per row, and rejections last. `harness/rows.R` scores a driver
  run so. Most results below were first scored on the forward and on `J`, whose
  error is 2000 times inside ε; the gradients' spread under nudges is what
  binds.
- *The sweep's cost per row is its tape* (`docs/measurements/perf-sweep.md`). It
  does no searches, and its inner derivatives are one implicit-function solve
  per root, but a member taped at its recorded point costs 2.4 forward
  evaluations. Three changes would halve it: not splitting the descent at the
  zero-depth pulses (19%), the crown's light quadrature off the tape (20–24%)
  and the collar's slope stored (8.5%).
- *The steps are the soil's accuracy through each rain-rate change.* That
  accuracy reaches `J` in proportion: a soil weight ×10 looser saves about 5%
  at a matched error. With the chain explicit the record predicts the cost but
  offers no cheap lever.
- *The soil chain sets the steps on its own:* alone, with no uptake, it takes
  16 447 of the coupled run's 17 684. With the soil and accumulators out of the
  norm the members need 9176 steps and 41% fewer member evaluations, but the
  explicit soil is then unstable. The chain implicit and out of the norm
  together is untested: the strategy reply's first lever, which it prices at
  1.6–1.9× on everything that walks rows.
- *The rejections near knots are the controller's carried proposal.* The soil
  chain alone's first step after each knot, as the seed, removes 85% of them and
  saves 3.5% of the forward for 2.4e-4 of a forward, but adds 1.4% rows, so a
  gradient run comes out even (§12). A seed from the last knot of the same kind
  costs a gradient run 12.9%.
- *The step-size law* (§7). On the soil chain alone a PI law leaves 6 of the
  constant record's 1009 rejections. On the coupled driver PI with the chain
  seeds saves 3.1% of the forward at `3e-5`, and 10.6% on the constant record.
  In rows it loses: PI turns rejections into accepted steps, 7.3% more rows, so
  a gradient run costs 5.8% more on long drought and 1.0% less on the constant
  record. What remains are the crossings' rejections and 798 soil-bound ones in
  the first day after a knot. Those are the chain's own transient, not class
  switches: the chain alone reproduces 98% of them, and a guard that steps it
  from the current state before each attempt removes them. Under odelia's law
  the guard saves 10.4% of the forward for 1.9% more rows, so a gradient run
  comes out even. On the chain alone the error is proportional to tol under
  either law, so the sign changes of `J`'s error are the crossings'.
- *The window as a rule* (§8). A 54-node pilot at `1e-3` reads R(t) within 10%
  on every record. Weighting the tolerance by it, with nodes thinned after the
  window, saves 21–28% of a forward and as many rows, every quantity of both
  roles moving at most 0.08ε. But on episodic the lma ×2 invader's walk raises:
  its pools are unstable on Cash–Karp steps past 3.73τ_s, 26 days, and rule A's
  are 31–38. The cure is the invader's own sub-steps where `h/τ_eff > 2`, with a
  15-day cap as the safety net; untested.
- *The invader's first replay repeats the resident's forward,* about 12% of a
  run with every gradient. Fixed on `PLANT-99` (#99): the first replay halves,
  for 130 MB more held after a recorded forward.
- *The constant record's steps are bound by the soil's stability,* not its
  accuracy: 83% start within 0.8 of the explicit limit, and held under it the
  rejections fall from 739 to 52. There the implicit soil pays (ARK, −66% member
  evaluations, `J` within 4e-7), where step 4 found it does not on long drought.
- *One window of the goal on every record:* 1–99% of `J` is earned between
  t ≈ 11–14 and 29, while three fifths of the pulsed records' member-steps come
  after t = 25. On long drought every tolerance ×100 after 25 saves 27% of
  member evaluations, and nodes born after 25 thinned fourfold save 12% of
  member-steps, each moving no quantity by more than 0.07ε.
- *The sign-change refusal limited to steps before t = 25* keeps its `J` for 43%
  less cost; limited to the cohort that earns `J`, it leaves 40% of the error.
- *The field adjoint map works* (`docs/measurements/field-adjoint-map.md`):
  dropping every other node of the held run, it predicts the field part at
  0.99–1.00× for `J` and 0.94–0.99× for the invader, for +12% of a sweep. `J`'s
  field part is water; the invader's is light.
- *The per-member split cures the gradients* (§11). With an interpolant of the
  step's order (a quintic) it costs 10.2% of a forward's leaf solves, cuts the
  gradients' spread under ±5% nudges 3.4–6.4×, and `J`'s error falls with the
  tolerance. A cubic interpolant makes `J` worse. Its cost in the sweeps is not
  measured: the reply counts it under 2% on a free fourth-order interpolant,
  against +10–20% with the midpoint.
- *The partitioned step is killed* (§13). Holding the collar across a member
  step under-draws the dry spells' water budget at first order. The corrections'
  drift to about −5e-4 was root-caused: they are consistent, but no norm
  measured the coupling's error, so the dry spells' steps stayed long (a median
  of 1.33 days at `1e-6`) as the tolerance tightened. With that error in the
  members' norm the scheme converges, at 0.39–1.85 of the monolith's leaf
  solves, so it stays dead: in the dry spells the coupling is an algebraic loop,
  and the gain was in the rain intervals, where an implicit chain takes it.
- *Open:* grid-dynamics' *Next probes*, ordered by the cost above.

**The events consult and its reply** (`docs/oracle-consultation-events.md`,
sent at `2363155`, and `docs/oracle-response-events.md`). What the reply
proposes:
- *For the resident's gradients and curvatures, events, in four stacked
  changes.*
  1. Events in the forward step: Cash–Karp's quartic, two cuts where a member's
     `P` dips inside a step, each sub-step on one branch of the positive part
     (`P⁺ = P` on one side of the crossing and 0 on the other), and the member's
     rates re-evaluated at its corrected end state.
  2. The multirate soil's inner steps recorded and held fixed in replays.
  3. The sweep's sub-step rows, with the cut times frozen.
  4. Curvatures by forward second differences at a perturbation near `1e-2`,
     which need no sweep.

  Class switches become events, behind a flag, only if a scan over the
  perturbation size shows a bias of order ε.
- *Why one branch per sub-step.* With the smooth positive part on both sides,
  a sweep that freezes the cut time is wrong at first order in the step,
  because the cut's own derivative carries the kink. With one branch per side
  the rates agree at the cut, so the cut time enters `J` only at the pair's
  order and the sweep can freeze it. This is the standard sensitivity of an
  event whose right-hand side is continuous, so it is a choice for the build
  rather than a claim to test.
- *For the invader loop, no events.* The invader keeps walking the resident's
  steps, and refines a member inside a step only when its own error estimate or
  its pool asks. The diagonal keeps the resident's program. Thinning starts at a
  fixed distance, `|ln θ′/θ| > 0.1`. Each evaluation reports its error estimate,
  for a trust-region optimiser that tightens it near convergence.
  - The selection gradient at `θ′ = θ` could come from the resident's own sweep,
    as a second adjoint with the field's response cut out.
  - Forward-only walks along that gradient would find positive fitness without
    an invader sweep whenever the ray succeeds, and sweeps would be the
    exception.
- *An identity for the invader workflow,* where the resident is solved to
  equilibrium. Equilibrium belongs to the invader workflow only, not to the
  resident workflow (the user, after the reply). On the diagonal,
  `∂J′/∂θ′ + ∂J′/∂θ = 0`, so the environment's response gradient is minus the
  selection gradient. Of the three second derivatives there, one follows from
  the other two.

Where the record disagrees with the reply:
- *Events are still needed for "predictable", whatever the curvatures need.*
  Bounded Cash–Karp's error in `J` falls more slowly than `tol` on long drought
  (4.3×, 2.0× and 1.7× per step against 3×), and changes sign between `1e-4`
  and `3e-5` on episodic (`q3_report.log`).
- *The chord's noise was sized with the invader's gradient jumps,* 3e-5 of the
  gradient. The resident's are about 1e-3 of it (`assessment.md`, step 5), so
  the unsplit chord is off by about ±1 at `1e-2`. That strengthens the case for
  second differences over chords for a single curvature. Chords still give a
  whole row of the Hessian, and their noise with events is unmeasured.
- *The fan-out's cost assumed about 45 splits per crossing step.* The record has
  9–13: 9235 crossings in 859 steps on long drought, 6206 in 662 on episodic,
  and 9233 in 726 unweighted. So the field reads' fan-out in the sweep is about
  a quarter of its estimate.
- *The quartic's own gate is unmeasured.* The reply says the quartic passes
  "halve only the crossing steps; the residual falls at the pair's order", but
  only the cubic was halved (as `h⁴`).
- *The invader's curvature without events is answered by the record*
  (`assessment.md`, step 5). At a perturbation of `1e-3` its second difference
  is within 0.5 of the smooth value (0.13ε). At `1e-2` the `O(u²)` term costs
  3.9 (1.0ε), because `J′` has large higher derivatives. So invaders take
  `1e-3`, or the combination `2(ln J)″ − chord`, rather than `1e-2`.
- *The loop's cost.* The reply puts most of it in the invaders: tens at 3.4
  forwards each, against a few resident forwards to equilibrium and one
  gradient. That holds for a resident of one kind. With several kinds, each
  resident run grows with the kinds and its equilibrium becomes a fixed point
  in several input rates, so the balance moves toward the resident, as the user
  expects. Forward-only invader walks, at 0.8 of a forward, move it further.

The reply's own test (`grid-dynamics.md` §17). With splits at crossings found
again on each replay, forward second differences give `lma`'s curvature
reproducibly from a perturbation of `1e-2` up: 0.05ε under the ±5% nudges at
`1e-2`, and 0.002ε at `3e-2`. Without splits they fail at `1e-2` (0.56ε) and
pass at `3e-2` (0.10ε). So events stay in the resident's build for the
curvatures as well as for predictability.

Three checks the user asked for after the reply:
- *Class switches are not the soil's instability.* The soil instability the
  record found is the chain's own transient. The 798 soil-bound rejections in
  the first day after a knot, which the strategy reply had read as class
  switches, are the drainage power law switching on as a rain onset fills the
  top layers; 1 of 793 held a class switch (`grid-dynamics.md` §7).
  - Class switches are something else: a member's leaf optimisation leaves the
    interior of its search interval for its lower end, where `P < 0` in 99.8% of
    member-states. Each is a kink in that member's inner solution, and so in its
    draw on the soil, its net production and its pool's rate. They appear in
    23–34% of the members' own rejections.
  - In the curvature scan they are the leading candidate for the split's
    residue below a perturbation of `1e-2`, since the soil's clamps are never
    met on accepted steps. That residue fades by `1e-2`.
  - So splits at class switches are not needed for the curvature route. They
    stay an option for smaller perturbations, or for a pointwise second-order
    sweep, which would carry every unlocated kink's bias.
- *Per-member splits with the spread rule (D).*
  - *Consistent by construction.* The driver evaluates a split member with
    plant's own field construction, from the interpolated state of every member
    (`patch_node_rates_tf24`). So the spread and the height sort reach a split
    member's field reads as they reach any evaluation, once one plant build
    carries both.
  - *A cost to measure.* Each split member's evaluation rebuilds the whole
    field, set against a single member's inner solve. Under D the field holds
    16 point crowns per introduction, so at 429 introductions a rebuild may cost
    several inner solves. The split's 4.1% of a forward, measured lumped at 108,
    could then grow, and so could the field's fan-out in the sweep. One field
    shared per sub-stage time, or field values interpolated from the step's
    ends, would bound it.
  - *A gain.* Splits make `J`'s time error fall with `tol`, so D's two-rung
    estimate of the node error stays clean as `tol` loosens. Moving the error
    budget toward nodes (`geometry.md` §6) needs exactly that.
  - *Not yet run together.* The split's single-member evaluation and the spread
    with the sort live in separate plant probe builds. One build with both,
    running the curvature scan and the nudges at 108 and 215 introductions,
    would test the consistency and the cost.
- *"Events" is taken, twice over.*
  - plant already has `Events` and `EventLog` (`plant/events.h`, `#632`):
    discrete actions at a time (resource pulses, climate extremes, harvest,
    node introduction) that stop the integrator, change the patch and are
    logged. Their names are a stable R-facing API.
  - dust2's events (`mrc-ide/dust2`, `inst/include/dust2/continuous/events.hpp`)
    are the same kind, triggered by the state. A test function's root is found
    on the step's interpolant, the whole step is cut short there, and an action
    changes the state, as in its bouncing ball. Even its events with no action
    stop the step and are recorded.
  - Per-member splits do none of that: no action, no jump in the state or the
    adjoint, no stop for the global step, one member at a time, thousands per
    run. So the build should not call them events.
  - Proposed, for the user: a *crossing* is the located time where a member's
    net production changes sign, and a *split* re-integrates that member on
    sub-steps either side of it. Our docs also use *thinning* for dropping node
    introductions, which in forestry is a harvest; *sparser introductions*
    would avoid that clash.

**The strategy consult and its reply** (`docs/oracle-consultation-strategy.md`,
its addenda, and `docs/oracle-response-strategy.md`). What it changed:
- *The forward was being optimised* while the sweeps are 74% of a gradient run,
  and changes were scored on `J`, where nothing binds. Rows and the sweep's
  cost per row come first now.
- *One-variable tests missed a two-bound interaction:* held to the norm, the
  implicit chain keeps its steps, and out of the norm the explicit chain is
  unstable. The pair is untested.
- *Two results listed as unexplained were explained by the record:* the
  invader's failing walk (its pools' stability) and ARK's error (below 1e-4 of
  ε, from an embedded estimate that misjudges stiff components). Its third, the
  first-day rejections as class switches, is refuted: they are the chain's own
  drainage switching on (`grid-dynamics.md` §7).
- *A scheme that does not converge is a defect until shown otherwise:* the
  partition's drift was one, in its error control rather than its corrections.
  The same blind spot awaits the chain out of the norm, so that test must show
  convergence over tolerances.
- *One object serves events, invaders and long steps:* a continuous extension of
  the global step, of its order (grid-dynamics, *Where the results point*).
- *Reframings:* the inner solve warm-started as an index-1 algebraic variable;
  bias against noise across records; the Hessian's cost, about 68 forwards by
  chords for five traits in both roles.
- *Next, with the user:* a design for the controller, and the chain implicit
  and out of the norm on the driver, scored in rows and the gradients' spread.

**Step 3: the floor, checked run by run.** A bank of references was too slow
(about 100 CPU hours). Each grid now carries a tolerance companion (×1.05,
every quantity under ε/6) and a node companion, and a spot-check on constant,
wet, episodic and dry tests that check (`harness/run_record.R`, which saves
everything a later analysis reads, and `harness/spot_check.R`). The runs are
committed in `docs/measurements/spot-check/`.
- At `3e-5` on 108 nodes the tolerance check passes on episodic, fails by one
  quantity on wet and long drought (the resident's `a_dG1`, 0.23–0.24ε against
  ε/6), and fails on dry.
- The node companion on 54 nodes is too coarse to decide 108 on any record.
- The 215-node rung decides it. 108 nodes keeps the main traits within ε on long
  drought and episodic (at most 0.65ε), but not the invader's `lma` on wet
  (1.19ε), and dry's resident sits at 0.94ε. Small elasticities (`a_st3`, `a_d0`,
  `omega`, `a_l1`) exceed their ε on every record, by up to 71ε.
- Dry at `1e-5` passes the tolerance check but for one quantity just over it
  (0.178ε against ε/6).
- So on wet and dry the check points to `1e-5` on 215 nodes, about 2.5× the
  cost of `3e-5` on 108. It has not been run as one setting, and `1e-5` not on
  wet.
- *The constant record, resolved* (`harness/first_panel.R`). Nothing thins its
  stand, so only the founders survive, the cohorts born in the first 23 days.
  Uniform nodes lump them into the first node, which shades itself and levels
  off around `hmat`, on the steep reproduction switch. So its `J` (1.2 on 108)
  and the invader's −1.4e17 are artefacts. With the first spacing split 8–128
  ways `J` is 288–292, the resident's `lma` elasticity −7.1 and the invader's
  −194. Those splits miss the founders' front; step 4's second reply converges
  them (above).
- *How each error scales,* from the runs on disk (`harness/error_structure.R`):
  the time axis is cheap to brute-force (steps as tol^−0.15, the resident's
  nudge spread as tol^0.6–0.8). The node axis carries 4–46× more error at
  `3e-5`, off any power law on 54, 108 and 215 nodes; on 108, 215 and 429 it is on
  the square law for `J` and the resident (above). Its move lives in births before 3 (9 of 108 nodes,
  16% of the cost), as two parts of 1–3% of `J` that cancel to 0.3–0.7%. On the
  constant record the first node is all of `J`: the founders, lumped.

**Step 3, the first measurement before it.** Seven tolerances within ±5% of
`1e-4` on long drought at seed 31 (`docs/assessment.md`, *Measured so far*).
`ln J` moves by 1.6e-5, and the invader's elasticities by at most 0.32 of ε/3. The resident's move by more
than ε/3 on five of 48, all of the pool's mortality and cost: `a_dG1` 1.65,
`d_I` 1.61, the relaxation offset 1.38, `a_dG2` 1.21 and `TF24_cost_scale`
1.17 times. So brute force at the step-2 setting fails the first test for the
resident. At `1e-5` everything passes, the resident's largest move 0.17 of ε/3,
for 42% more steps. The loosest passing tolerance is step 3's to find on the
bank, and it prices the reply's remedy.

### The code

On `aornugent/plant`, over `develop`'s `95256cf3`:

| branch | head | what | on | odelia |
|---|---|---|---|---|
| `PLANT-93` (PR #94, open) | `bae2dd9a` | exact counts; 1 commit | `develop` | `be3e2cb` |
| `offspring-adjoint` (#91) | `5a37615e` | the reverse sweep, TF24 v11; 14 commits | `PLANT-93` | `be3e2cb` |
| `PLANT-95` (#95) | `25e21a70` | exact invader replay; 5 commits | `offspring-adjoint` | `a05f5c2` |
| `PLANT-96` (#96) | `855f64ee` | zero pulses as step targets; 1 commit | `PLANT-95` | `a05f5c2` |
| `PLANT-97` (#97) | `b4b5febf` | the pool's relaxation offset, TF24 v12; 1 commit | `PLANT-95` | `a05f5c2` |
| `PLANT-98` (#98) | `7dbd87c3` | the pool's stage guard out; 1 commit | `PLANT-97` | `a05f5c2` |
| `PLANT-99` (#99) | `457f08bb` | the first invasion walks a recorded run without repeating it; 1 commit | `PLANT-98` | `a05f5c2` |
| `state-weights` (no issue yet) | `4555ea13` | the soil's, the accumulators' and a schedule's weights in the step-size control, and a bound on each state's; 2 commits | `PLANT-99` | odelia `state-weights`, `a62e97c` |
| `ark-soil` (no issue yet) | `4dc59a40` | TF24's soil drainage and infiltration stepped implicitly under `ode_method = "ark"`; 1 commit | `state-weights` | odelia `ark-step`, `f11e753` |

- odelia 0.5.0 is `claude/trusting-curie-4i9n3l` and phylloptim 0.9.0 is
  `378b083`, both unreleased. A branch builds only against its own odelia.
- odelia's `state-weights` (`a62e97c`, on `a05f5c2`) lets a System weigh each
  component's error level, through a concept; plant's `state-weights` needs it.
  - The control fields are `ode_weight_soil`, `ode_weight_accumulator`,
    `ode_weight_times`, `ode_weight_factors` and `ode_weight_max`. Their
    defaults reproduce every run bit for bit.
  - The private library `$DEV/lib_sw` holds both.
  - The branches await issues and PRs, the user's call.
- odelia's `ark-step` (`f11e753`, on `state-weights`) adds `Method::ark` and the
  `HasStiffBlock` concept; plant's `ark-soil` needs it. `$DEV/lib_ark` holds
  both, with phylloptim `378b083`.
- No PR is open for `offspring-adjoint` or `PLANT-95` to `PLANT-99`; opening them
  is the user's call. #96 is independent of #97 and #98, and all three edit the
  top of `NEWS.md`.
- `plant-dev`'s pointers (plant `6613dd24`, odelia `be3e2cb`) stay until #94
  merges; odelia's moves with plant's.
- `harness/ark_prototype.R` is the R driver. It reproduces plant's run bit for
  bit, and carries the step rules measured so far as options: the per-pool
  scale, the crossing cap, the onset cap, the transit cap and the crossing
  correction.

### Before the design

- Steps 1–3 of the earlier plan are #96, #97 and #95.
- The IMEX stepper was killed at its prototype. The records are the archived
  scopes in `docs/archive/`.
- Debugging on the driver then found what the spec's *What the design rests
  on* lists.
- The consultation behind that is
  `docs/archive/oracle-consultation-solver-performance.md`, with the fifth reply
  in `docs/archive/oracle-response-solver-performance.md` and the earlier ones
  in its history. It framed the gradients for a calibration,
  which is not the scope, so its precision budgets do not apply.

### Outstanding

- **The constant record's spot-check runs are on uniform nodes,** so their `J`
  and gradients are artefacts. The resolved schedule exists now, `const_Gbf16`
  (150 nodes, step 4's second reply); what remains is its tolerance companion.
  - What remains there is the model's: the invader's landscape is a smooth cliff
    at θ′ = θ, `J′` 938, 289.3 and 0.0017 at `lma` e^{−0.01}, ×1 and e^{+0.01},
    with |g|/|g′| = 0.0075. ε and the continuity test apply there as everywhere.
    A grid serves its radius, so an analysis whose range is wider takes several
    grids or a finer one, with brute force the fallback (`OBJECTIVES.md`,
    *Shared*).
- **The invader's grid radius over ×0.5–×2 is measured on no record,** only the
  resident's (×0.95–×1.1 on the floor's grid, `docs/assessment.md` step 4(c)).
  On long drought the invader's slope in `ln lma` changes by its own size over
  about 0.18 (`|g|/|g′|` from the eight seeds' means), a quarter of ln 2. Phase
  4 measures it first; the optimising loop's cost depends on how many resident
  runs an analysis takes.
- **The node rule, B, is measured on long drought only.** Its constants (an
  opening of 0.03 growing by 1.11, a cap of 0.37) need no pilot there, but wet's
  graded `J` reaches the square law only past 494 nodes, and wet's, dry's and
  episodic's gradients on graded ladders are not run. Next: the graded ladder on
  each, with the crowns' overlap at the top from `layer_heights.R`.
- **D, a canopy that cannot comb, has run** (`docs/measurements/canopy-spread.md`).
  Each panel's leaf area spread over its members' heights removes the top's
  field anomaly, and spread uniform nodes report their error on long drought:
  ratios 3.6–3.9 and companions 0.93–1.09 over 49 quantities, and the invader's
  `lma` on two more seeds. Single spread rungs are coarse, so the rule reports
  the two-rung extrapolation. Wet and dry are not run to u429, the constant
  record still needs front nodes. The resident's sweep ran 1.7–3.4× slower:
  in CPU the spread costs 3–8%, and the rest was load and, at u429, the light
  field's fallback path when two nodes' heights fall out of order by a
  millimetre, which the lumped build takes too at a sixteenth of the cost
  (`docs/measurements/perf-sweep.md`). Whether to change plant's birth-date competition sum for it is
  the user's call.
- **De2's and Gn2's invader phases were lost to a restart;** their coarse rungs
  settle the edges, so they were not rerun.
- **Whether to build a node rule for records whose canopy is never thinned:**
  graded windows and a split at the front. The constant record needs it and the
  pulsed records do not. Here the front came from a pilot, where neighbours'
  mortality integrals at the end differ 70-fold across it; how early a run shows
  it is not measured.
- **The small elasticities' misses at 108 nodes.** Elasticities' ε is now at
  least 0.01 (`OBJECTIVES.md`). At a tenth of their spread, `a_st3`, `a_d0`,
  `omega` and `a_l1` missed on every record, though no small elasticity's
  108-node error exceeds 0.012. With the 0.01, three quantities still miss
  outside wet and the constant record, each by under 1.6×, and nine of wet's
  invader's (`docs/measurements/spot-check.md`).
- **Clean-up,** each fixed in the branch that owns it, then `git rebase
  --update-refs` and a `--force-with-lease` push of every moved branch:
  - odelia's `test-implicit-value.R` has 5 errors: its snippet passes a braced
    list to a `std::span` parameter, which this compiler refuses.
  - `test-mutant.R`'s "mutant method works" fails on FF16's ten-mutant panels,
    which are pinned to `develop`.
  - Test comments record history or stale numbers: "offspring arrival" in
    `test-strategy-tf24.R`, the seeded-baseline narrative in
    `test-stochastic-patch-runner.R`, and the `k_acclim` offspring table in
    `test-strategy-tf24f.R`.
  - `NodeSchedule` keeps the pinned steps and their R interface (#95, *Kept*).
  - TF24's `scientific_version` log is history by design; whether it stays is
    the user's call.
- **A refused gradient:** at u108 with `ode_tol_rel = ode_tol_abs = 1e-3`, both
  `lib_guard` and the spread build refuse `J`'s gradient (`NaN`), though the
  sweep runs to its end. The reason was not read
  (`docs/measurements/perf-sweep.md`).
- **A replayed step program is not exact.** Setting a run's own `p$ode_times` and
  `p$ode_step_sizes` reproduces `J` only to +5.1e-8 (long drought, seed 31, `tol =
  1e-4`, v12t), where `run_scm`'s documentation says the replay is exact. Not yet
  looked at.
