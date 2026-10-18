# Review: `docs/design-refine-schedule.md`

## Verdict: approve with changes

The core holds. Both the clean sheet and the measurements reach the same estimator: breakpoints
as nodes at both ends of each spell, an even number of intervals per spell, and one pinned
replay with every other interior node removed, divided by 3. The design also knows three things
the clean sheet got wrong: where the curvature rises before a shutting, why the ages come from
T(t), and that spell ends move between passes. What must change is around that core:

1. The design keeps none of OBJECTIVES' invaders, curvatures, stability or shared grid.
2. The clause "each run's own spell ends" rules out the shared grid that those objectives need.
3. The public name is already taken by a flag, a C++ method and a logpile request key.
4. The 0.88ε hold does not cover what the design says it covers.

Would we build it differently now, knowing what the rounds taught? Yes, in three ways:

- Refine at θ₀, then return a fixed schedule that every later run around θ₀ replays on.
- Use one scale in place of a stored count per spell.
- Remove the doubling mode.

None of these changes the estimator.

## Triage: 3 — `refine_schedule(p)` becomes plant's public call for converged runs, and the name is already in use: a `run_scm()` argument, an `SCM` method on FF16, K93, TF24 and TF24f, and a key in logpile's request schema and fingerprints.

Subject and method: the design (its tool, data shapes and loop), with
`docs/vignettes/node-schedules.Rmd` as its account for users. The review follows
`.claude/skills/code-review/`, applied to a design rather than a diff.

- No code exists yet. Each "kept true by structure" claim is checked against the design's own
  text, the vignette, the code it would replace, and the measurements
  (`rootcause/evidence/notes.md` rounds 1–5; `rootcause/coldread/notes.md`).
- Round 5 has only pre-registrations so far (R5g–R5q, no results). Anything that rests on it is
  marked **[round 5]**.
- Evidence labels: "R12" means evidence round result R12; "E1–E4" are the evidence notes'
  questions.

## Ledger

From the design (source: design doc):
- **R1** Converged by default. Every quantity is within its ε_q, with no knob to tune.
- **R1′** Any simulation length. No rule names an absolute birth date or age.
- **R2** Honest. Each run reports its own error estimate per quantity, not one borrowed from
  another schedule.
- **R3** Never fails, including near extinction.
- **R4** Cheap. The fewest rows at ε. E6 costs its committed run plus a 1.55× check.
- **R5** Diagnosed. Each run reports where its remaining error is.

From `OBJECTIVES.md` (source: objectives). These lines are missing from the design's ledger:
- **O1** Residents **and invaders** (×0.5–×2 of the resident): `ln J`, elasticities **and
  curvatures**.
- **O2** Stable. Three tests:
  - reproducible: nudging tol by ±5%, or the introductions by a quarter of their spacing, moves
    the answer by less than ε/3;
  - continuous in θ and θ′ on one grid;
  - predictable: the error falls at each knob's order.
- **O3** Shared. One grid serves each local analysis around θ₀, and big steps rebuild it.
- **O4** Diagnosed. Each run reports its error estimate, **θ's distance from the grid's θ₀
  against the grid's radius**, and its failures.

From `AGENTS.md` and the user's principles (source: project guide):
- no parallel near-copy of an existing path;
- do not store what can be derived;
- no count that can disagree with its source;
- plain words, and no process history;
- the user's principles: Subtract Before You Add, Minimize Reader Load, Model the Domain.

### Check against the design doc

**The commitment has decayed to convention.** No code exists, and the design's own text already
breaks each of its three "kept true by structure" lines:

1. **"The schedule is (breaks, density)."**
   - This leaves out the count per spell, which step 6 scales.
   - The vignette's `fit$schedule` holds breakpoints, counts and node times. The node times are
     stored beside the values they are derived from.
2. **"Each spell gets an even number of intervals."**
   - This is false for short spells, which get one interval under the design's own rule.
   - Step 6 has no "keep counts even"; only the vignette has it.
   - "No removed node sits off centre" holds by share of the density. But the factor 1/3 is
     exact only for the centre by width (see the vignette's own off-centre formula). The two
     differ wherever the graded density doubles within 18 days.
3. **"No other node class."**
   - The stall boundary is a second kind of breakpoint. It is found another way: five
     bisection runs on a count that today's runs do not record.
   - Short spells are a class of spell with their own rule.
   - Step 2's "late cut" at t₉₀ drops the spell ends after it. Layout B, which the evidence
     ran, made the stretch after t₉₀ one panel. That breaks "each run's own spell openings and
     ends".

**Nouns.**
- The design has no "what survives deletion" list. It also lacks the floor, the kill question,
  "what this makes hard" and the kill condition that the system-design output asks for. So
  every noun must justify itself.
- Nouns that no ledger line holds:
  - `where`: R5 names it, but no step computes it;
  - `history`; doubling; "share of the J window"; map; probe; parity replay;
  - "a node's cost": only candidate A uses it;
  - process names: E6, a09, `b = 10`, 17, 20, 25, insets, strips, edge layers, layout,
    C2/C3/C4.
- One concept has four names: shutting, end, edge, c.
- One word has three meanings: count means nodes, intervals, or establishment.

## Clean sheet

A blind subagent wrote `review/clean-sheet.md` from R1–R5 and the earlier rounds' notes,
without the evidence round. Its parts:

- **`nested_schedule(pilot, s)`**:
  - fixed nodes at 0, at every o, at every c, and at c − 12 d;
  - each stretch gets 2·⌈m/2⌉ intervals of equal measure at one scale s;
  - no interval is wider than 80 d;
  - fronts become breakpoints.
- **`removal_error(run)`**: one pinned replay of the parent, divided by 3. The unseen parts are
  reported as stated bounds: the 12-d strips, and the tolerance.
- **`run_to_target`**:
  - stop when every |e_q| ≤ 0.85ε;
  - otherwise rebuild at s·(0.85ε/max|e|)^½;
  - at most 3 passes, with a flag at the cap.
- **Location**: the existing node-drop map, used for reporting only.

That is about 130 lines of R and three new names. Like the design, it leaves the shared grid
out: "that belongs to the shared-grid objective, not to R1–R5". So the gap in the ledger came
from the requirement both were given, not from how the design was written.

**Gap.** Concepts the design has that the clean sheet lacks:

| # | Concept | Settled? |
|---|---|---|
| 1 | Spell ends re-read from each run | Settled for refining by R1. Ends move a median 0.48 d between passes, and the first spell's end by 12 d (`estimate-shortfall.md`). The strip's error grows as d² in the distance (E3). The clean sheet takes the ends from the pilot only. Unsettled for use around θ₀ → **Q1** |
| 2 | A stored count per spell | The clean sheet uses one scale s and derives the counts → **Q2** |
| 3 | Density graded into the last ~3 weeks before a shutting, with 2 more intervals per replayed spell | Settled over the clean sheet's fixed c − 12 d node by R15/R17: the rise is 15–21 d wide at half height and 21–32 d at onset, wider than a 12-d strip, and it has no fixed date. R16: 0.79 → 0.36ε, replay at 0.97 of the error. Dry only so far **[round 5]** |
| 4 | Ages from T(t) | Settled by R1′ with R7. a09's measure, which the clean sheet uses as if it held no ages, does hold absolute ages: the cap switch at 20 y, the late edges at 25 y, the eras at 10 y |
| 5 | Short spells left unreplayed, a J-share rule, and a bound | Settled for cost by R4. Giving every spell a midpoint (layout D′) costs 1.15–1.74× E6's rows (R10). The bound does not work → **Q9** |
| 6 | Stall boundary placed by five bisection runs | The clean sheet takes fronts from neighbouring nodes' counts on each run, with no extra runs → **Q11** |
| 7 | Doubling as a second mode | Not in the clean sheet → **Q3** |
| 8 | `where`, with no mechanism | The clean sheet uses the existing node-drop map → **Q8** |

Concepts the clean sheet has that the design lacks:

- **A cap on interval width (80 d, so merged intervals stay ≤ 160 d).** The square law fails
  at 198–224 d (h5), and layouts without closing nodes left 12–32 intervals over 160 d (R3)
  → **Q10**.
- **A pass cap with a number, and a returned flag.** The design gives neither (minor finding 13).
- **The unseen parts reported as named bounds.** See the Keeper section.

## Prediction record

**Honesty.** A grep for headings showed six body lines before the predictions were written:
R4's text, three rows of the evidence table, and part of "Still open". I also read the first
line of each numbered step as part of the design's public part. I wrote twenty predictions from
the headings, the commitment, the numbered steps and the tool line. The misses below are a lower
bound.

1. **`count`**
   - Predicted: a node count per spell.
   - Actual: four uses that disagree:
     - the commitment says "node count";
     - the structure line says "even number of intervals";
     - the vignette says "count of intervals";
     - the domain section uses "count" for the establishment count in an interval.
   - The measured parity hole (R1 G2a; 17 of dry's 70 shutting strips never merged, R11) came
     from this same slip between nodes and intervals in the earlier draft.
2. **The commitment's structure line**
   - Predicted: "(breaks, density)" lists everything stored.
   - Actual: it leaves out the count per spell, which is the only thing the loop scales.
3. **`where`**
   - Predicted: OBJECTIVES' diagnostic, θ against θ₀ and the grid's radius.
   - Actual: R5, "where its remaining error is". No step of the algorithm produces it. The
     vignette adds a reverse sweep that costs 7.5% of a run and covers `ln J` only.
   - OBJECTIVES' distance from θ₀ has no field at all.
4. **T(t) ages**
   - Predicted: a cumulative density used to place nodes.
   - Actual: the share of J still to be produced. It sets three calendar times that "replace
     b = 10", "17 and 20" and "25". Those are constants of retired builders, and a new reader
     cannot decode them.
5. **Steps 3 and 5**
   - Predicted: one tolerance.
   - Actual:
     - step 3 runs at 3e-5;
     - step 5 justifies the 0.88ε hold at 1e-4;
     - "Still open" says the choice is open.
   - The steps cannot be implemented as written.
6. **`answer`**
   - Predicted: `ln J` and the elasticities; unclear whether invaders and curvatures are in it.
   - Actual: "the run is the answer" and "every quantity", with no list. Invaders and
     curvatures are never mentioned.
7. **Failure**
   - Predicted: a returned flag.
   - Actual: G5 says "a cap reports a failure", through no named field.
8. **`refine_schedule(p)`**
   - Predicted: one argument. The vignette calls `refine_schedule(p, mkenv("episodic"))`.
   - A reader who knows plant predicts the existing `run_scm(refine_schedule = TRUE)` and
     `SCM::refine_schedule()`, which bisect flagged nodes for every strategy. The design
     replaces them without saying so.
9. **Short spells**
   - Predicted: one interval each, and reported.
   - Actual: also "leave out spells below a share of the J window". Out of what, the replay or
     the schedule? These spells hold 23–71% of establishment.
   - G2 says they are "bounded". "Still open" and the vignette say no bound works.
10. **Doubling**
    - Not among the numbered steps, yet it is a second loop mode, and G1 depends on it.
11. **Stall boundary**
    - Predicted: re-read each run, like the other breakpoints.
    - Actual: five forward bisection runs on a counter that runs do not record. It is not
      among the numbered steps, and the design does not say whether it is redone each pass.

## Decisions reopened

**D1: chose breakpoints at both spell ends, re-read from each run, over openings only (layout
D).**
- **Both ends: settled by R1.** Measured worst errors fell from 3.36 / 1.13 / 3.24ε (R11) to
  0.79 / 0.47 / 0.76ε (R12). The replay went from 0.21–0.44 of the error to 0.75–0.87.
- **Re-read each run, rather than fixed once the schedule converges:**
  - settled while refining at one θ: ends move a median 0.48 d between passes, and the strip's
    error goes as d²;
  - UNSETTLED for any use beyond that run (O2, O3, curvatures, invaders) → **Q1**.

**D2: chose a stored count per spell over one scale N, with each spell's even count derived as
2·⌈N·∫ρ/2⌉.**
- Even counts: settled by R2 (G2a measured).
- Storing a count per spell: UNSETTLED → **Q2**.
  - Under the chosen candidate B, which only scales, the counts per spell follow from
    (breaks, ρ, N).
  - The only reason to store them is "make sure the binding spells' counts change".
  - Storing them gives counts that can disagree with their source (AGENTS.md). The clean sheet
    uses one scale.

**D3: chose the pinned replay over a second, looser run made without pinning** (OBJECTIVES:
"a second, looser run estimates a run's error").
- Settled by R2 and R4:
  - the replay has no step noise (G3, from the code);
  - it costs 0.53–0.64 of a run against 1 (R11, R12);
  - it reads 0.75–0.97 of the error, with cosine 0.88–0.98 (R12, R16).
- The clean sheet reached the same choice.

**D4: chose uniform scaling over allocating by measured error (candidate A), but kept doubling
as a second mode beside it.**
- Scaling: settled. Candidate A saved 4.1% of rows, and the clean sheet agrees.
- Two modes rather than one (scaling only): UNSETTLED → **Q3**.
  - Doubling's nesting fails once spell ends are re-read (D1).
  - Its estimate carries step noise.
  - Doubling also under-read the order-1 component (R14).

**D5: chose a fixed 0.88ε hold at 1e-4 over running at 3e-5 and stopping at ε.**
- Settled for cost by R4: 0.70 of the cost of 3e-5 (R14, inferred), with the bias measured on
  five cases.
- But step 3 still runs at 3e-5.
- And the hold's derivation covers only the bias, not the replay reading low → **Q4**
  (structural finding 5).

Not among the five largest decisions:

- **Grading as a density shape, not as fixed nodes.**
  - Settled over a node at c − t_r: R15 found no fixed date.
  - Settled over the clean sheet's c − 12 d strip: the rise is wider than that.
  - Rests on one dry run so far **[round 5]**.
- **Ages from T(t).** Settled by R1′ and R7 on the bank. Not measured at any lifetime other
  than 40.

## Change simulation

**(a) Another strategy (FF16, or a new TF variant) with different non-smooth points.** Edit
sites:

1. **Step 1's breakpoint reader.** Spells are read from TF24's establishment record: P at seed
   height and the top soil layer. FF16 has no water and no spells.
2. **Stall boundary.** It needs a count of P sign changes per node, recorded by the strategy's
   C++. Each strategy would need a new record.
3. **Step 2's grade.**
   - Its width is t_r = o·ln(a_st3·a_dG2) (R17), built from TF24's storage parameters.
   - The height of 2.2 and the 2 extra intervals per spell were measured on TF24's dry case.
4. **Step 5's hold.** The 0.11ε bias was measured on five TF24 cases.
5. **The ε table.** `eps-spread.md` covers TF24 at lma 0.32 only. Without a table, "converged
   by default" has no meaning.
6. **The quantity list.** It holds TF24's 46 elasticities.
7. **What the change must know about, even for TF24 alone:**
   - plant:
     - `run_scm(refine_schedule =)` and `SCM::refine_schedule()` (C++, all four strategies);
     - `R/benchmark.R`;
     - the tests `test-schedule-build.R` and `test-strategy-tf24f.R`;
   - logpile:
     - `resolve_control` in `fingerprint.R`;
     - the control names in `manifest.R`;
     - the call in `solver.R`.

The generic parts need no edit: the removal, the factor 1/3, even counts, and the loop.

**Shotgun.** A strategy's facts sit in steps 1, 2 and 5 and in a data file, and nothing in the
design gathers what a strategy must supply. This is the existing path, not a guess about the
future: plant ships four strategies, and today's `refine_schedule` serves all of them.

**(b) A user wants the curvatures converged too.** Edit sites:

1. **The quantity list and the ε table.** Curvature ε values exist in
   `design-grid-controller.md`: 1.2 and 4.0 for lma's curvature.
2. **Two runs per curvature.** Each curvature is a chord of two gradient runs at θ·e^{±r}.
   - Under "each run's own spell ends", the two runs have different breakpoints, and their
     counts may differ too. Traits move spells: episodic has 84 edges at θ₀ and 64 at lma ×1.25
     (`refinement.md`).
   - The chord then takes the difference of two schedules.
   - Both runs need one fixed schedule, which contradicts the commitment.
3. **The estimate.** Two replays, one pinned to each run, double the cost of the replay.
   - The 0.88 hold was derived from the gradients' bias and replay ratio, and nothing measures
     it for a chord.
   - The two runs take different steps. Their step noise (rms 0.023ε at 1e-4) is divided by 2r
     in the chord.
4. **√-scaling and the factor 1/3.** Both assume order 2. The order of the curvature's
   integrand near a shutting has not been measured.
5. **The shapes of `answer` and `estimate`.**

**Leaky, and it breaks the commitment.** OBJECTIVES asks for curvatures, so this is planned work.

## What must always be true

Every interval the answer sums over is either merged exactly once by the replay, or belongs to
a named part whose error is added to the reported estimate. **Kept true by: convention.**

How convention fails here:
- the even-interval rule exists only in prose, and step 6 leaves it out;
- short spells have one interval, and their bound does not work;
- the tolerance bias is covered by a constant measured on five cases, and nothing reports it.

A structural form exists:
- **Store the number of pairs m per spell, so intervals = 2m.** An odd count then cannot be
  written down.
- **Derive the node times and the removal from one function of (breaks, ρ, m).** The removal is
  that function with each pair merged.
- **Give short spells m = 0 and one interval.**
- **Return an estimate with a required term for what the replay does not see.** That term
  covers short spells and tolerance, so it cannot be left out.

That gives one structure where there are now three rules to remember (structural finding 6).

## Structural findings

1. **The ledger drops OBJECTIVES lines without saying so.**
   - R1–R5 leave out:
     - O1's invaders and curvatures;
     - all of O2: reproducible, continuous, predictable;
     - O3, the shared grid.
   - R5's "where the error is" replaces O4's distance from θ₀.
   - `docs/handover.md` still names `design-grid-controller.md` as the design for these
     objectives, and neither design document names the other.
   - **What this makes harder:** the next local analysis (a fitness landscape, a selection
     gradient, a curvature). The tool returns one converged run, with no grid to reuse and no
     distance to report, so each analysis must later be built around it.
   - **Simpler:** carry O1–O4 into the ledger. State which of them this design pays for, and
     which it leaves to the grid-controller design.

2. **"Each run's own spell ends" rules out one shared grid, curvature chords, invaders and
   continuity.**
   - Breakpoints and counts move with θ: episodic goes from 84 edges to 64 at lma ×1.25. So two
     runs at nearby θ use two schedules.
   - **What this makes harder:**
     - building a fitness landscape on one grid;
     - computing a curvature chord;
     - keeping O2's continuity.
   - **Why:** the answer jumps whenever a count or a spell changes.
   - **Simpler:**
     - re-read the ends only while refining at θ₀;
     - return the converged schedule as fixed;
     - every later run at θ replays on it and reports its estimate and its distance from θ₀;
     - a big step rebuilds.
   - The cost of not re-reading: ends move a median 0.48 d. The strip's error grows as d², so
     this is small at 0.48 d. It is not measured at θ ±10% or at ×0.5–×2.

3. **Invaders with θ′ ≠ θ have no breakpoints of their own.**
   - Invaders are walked only at the resident's birth dates; libS refuses any other date (R8).
   - An invader's establishment depends on its own P at seed height, so its spell ends differ
     from the resident's.
   - No measurement covers θ′ ≠ θ. The invader in `eps-spread.md` has θ′ = θ.
   - **What this makes harder:** trusting the invaders' elasticities, whose ε are 0.20 for lma
     and 0.050 for a_dG2.
   - **Why:** an interval across an invader's spell end reads the gap's curve. That is E3's
     mechanism, where the error is 2–33× what a node at c gives.
   - **Simpler:** either
     - make the schedule's breakpoints the union of the resident's spell ends and those of the
       analysis's invaders, using one forward walk per invader set; or
     - measure that the invaders' spell ends coincide with the resident's.

4. **The public name collides with existing code, and the design lists none of the edit
   sites.**
   - `refine_schedule` is today:
     - an argument of `run_scm()`;
     - an `SCM` method on FF16, K93, TF24 and TF24f, a C++ bisection on per-node error;
     - a key in logpile's request schema: the default in `resolve_control`, the control names
       in `manifest.R`, and the call in `solver.R`. Through these it reaches request
       fingerprints.
   - `harness/schedule/refine.R` defines a third `refine_schedule(case, start = "E6", ...)`.
   - The design says only "the role refine_schedule had".
   - **What this makes harder:** replacing the old path.
   - **Why:**
     - a reader of plant expects the old behaviour;
     - logpile's cached requests change meaning without any signal.
   - **Simpler:** keep one path (AGENTS.md: no parallel near-copy).
     - List the edit sites.
     - Replace the C++ refine and the flag in the same change.
     - Change logpile's key, and say that this changes the fingerprints.

5. **The 0.88ε hold does not cover what step 5 says it covers.**
   - Step 5: the replay "cannot see the tolerance's bias, ≤ 0.11ε, and estimates 0.75–0.97 of
     the error".
   - Take the lowest replay ratio, 0.75. An estimate of 0.88ε then means an interpolation error
     of 0.88/0.75 = 1.17ε. Adding the 0.11ε bias gives 1.28ε.
   - 0.88 = 1 − 0.12 covers the bias alone; R14 derives it that way.
   - "Never accepts a run over ε" has not been tested on the chosen layout. Every run in rounds
     2–4 was within ε, so no false accept could occur. R5k tests it **[round 5]**.
   - **What this makes harder:** trusting R1.
   - **Why:** the stop tests an estimate that reads low.
   - **Simpler:** either
     - hold at (1 − 0.11) × 0.75 ≈ 0.67ε, which costs about √(0.88/0.67) ≈ 1.15× the nodes; or
     - keep 0.88 and send R1's wording back to the user as a question.

6. **The commitment is kept by convention (Keeper).**
   - Every implementer must remember three facts:
     - the even-interval rule;
     - the short-spell exception;
     - the tolerance reserve.
   - **What this makes harder:** each later edit to step 6 or step 2.
   - **Why:** nothing stops an odd count, and nothing makes a reported estimate include the
     unseen parts.
   - **Simpler:** store pair counts, and give the estimate a required unseen term. See the
     Keeper section.

7. **A strategy's facts are scattered (change simulation (a), shotgun).**
   - They are the spell reader, the stall counter, t_r and the grade height, the hold, the ε
     table and the quantity list.
   - **What this makes harder:** keeping today's FF16/K93/TF24f users of `refine_schedule`
     working.
   - **Why:** six places must agree, across steps 1, 2 and 5 and a data file.
   - **Simpler:** state in the design what a strategy supplies, in one place: its breakpoints
     from a run, its grade, its ε table. A strategy without spells has one spell
     [0, horizon] and no grade.
   - The second use is already there: plant's four strategies call today's refine.

## Minor findings

Statements the measurements contradict or do not support:

1. **Step 4: "the replay costs about 0.6–0.8 of a run".** Measured: 0.53–0.64 of a run's CPU
   (R11, R12).
2. **"When doubling is enough … 0.024 rms of step noise".**
   - 0.024 is the step noise of the nudge at 1e-4. At 3e-5, the tolerance step 3 uses, it is
     0.004–0.012 (R14).
   - Doubling's estimate also missed the order-1 component (R14).
   - With ends re-read, a doubled run is not the earlier run's removal case.
3. **Domain section: "its curvature rises tenfold within 2–3 weeks".**
   - Fate's own curvature rises 1.3–5× inside the spell.
   - 10–44× holds only for stencils that cross c.
   - The sensitivities rise 6–17× (R4, R13, R15).
   - The cold read fixed this in the vignette; the design still has it.
4. **"8–23% more nodes than E6".**
   - True for layout B.
   - The chosen layout, graded with 2 more intervals, has 56% more on dry (Bga: 232 against
     149, R16).
   - The G5 layouts, built but not yet run, have 38–68% more **[round 5]**.
5. **Evidence table: "never accepts a run over ε".** Not tested: no run of layout B, Bg or Bga
   was over ε.
6. **G2: "short spells are bounded".** The proposed bound under-covers by 5–50× (R12). No bound
   works.
7. **G4: "no rule holds an absolute age".**
   - The run's tolerance weight file sits on a fixed 0–40 y grid. R7 lists it for replacement.
   - T(t) has not been measured on any lifetime other than 40.
8. **"Still open: take the grading's width from the first run".**
   - R17 found that the width follows t_r = o·ln(a_st3·a_dG2): the ratios are 0.74–1.10. That
     formula needs only parameters, not a run.
   - Drought length does not predict the width.
   - The run that would tell t_r apart from a constant is R5g/h **[round 5]**.
9. **Step 2: "two more intervals per spell".** The evidence added them to replayed spells only
   (R16).
10. **The short-spell figures (23–71% of establishment, 0.5–6.6% of J, 1–19% of the error).**
    These were measured on layout D's panels with fewer than 2 interior nodes, not under the
    design's short-spell rule (∫ρ₀ ≤ 1).
11. **Step 2's grading rests on one dry run (R16).** Episodic-lma missed the same component and
    was not rerun **[round 5]**.
12. **Stall boundary.**
    - Resolving the front fixes the invader (order 4.31) but not the resident (1.89)
      (`refinement.md`).
    - The founders' approach to the front needs grading of its own, and step 2 has none.

Other:

13. **R4's cost covers one pass.**
    - The design does not estimate how many passes start from the first density, nor give a
      number for the pass cap.
    - Each extra pass spends a run plus its replay, about 1.6 runs (G1).
14. **Doc wording.**
    - "Map" is used in two rows of the evidence table but never defined in the design.
    - "A node's cost depends on its birth date" belongs to candidate A. Delete it.
15. **Reader load.**
    - Process names (E6, a09, `b = 10`/17/20/25, C2/C3/C4, layout, insets, strips) and
      metaphors ("the field", "reads") add to it.
    - The cold read already removed these from the vignette.
16. **Fields left undefined.**
    - The design never says what `schedule` and `history` contain.
    - The vignette's `schedule` stores node times beside the values they come from.

## Questions with defaults

Unanswered, each default becomes a finding in the next review of this design.

- **Q1.** Why re-read spell ends on every run, rather than only while refining at θ₀ and then
  fixing the schedule?
  - Default: fix it after refining. Every later run around θ₀ replays on the fixed schedule and
    reports its estimate and its distance from θ₀.
- **Q2.** Why store a count per spell rather than one scale N, with the even counts per spell
  derived from it?
  - Default: store (breaks, ρ, N).
  - To force a change, raise N until the binding spell's count moves.
- **Q3.** Why keep doubling beside scaling?
  - Default: delete the doubling paragraph and G1's exception for it.
- **Q4.** Does R1 mean the true error is under ε, or the estimate?
  - Default: the true error.
  - Hold at 0.67ε, at 1e-4, and make step 3 say 1e-4.
- **Q5.** Are invaders with θ′ ≠ θ among "every quantity"?
  - Default: yes, as OBJECTIVES says.
  - The breakpoints then include the invaders' spell ends.
- **Q6.** Are curvatures in `answer`?
  - Default: yes, as OBJECTIVES says.
  - Each comes from two runs on one fixed schedule, which needs Q1's default.
- **Q7.** What is the tool's scope, and what happens to the existing `refine_schedule`?
  - Default: one path.
    - Replace the C++ refine, the `run_scm` flag and logpile's key in one change.
    - Strategies without spells get one spell [0, horizon] and no grade.
- **Q8.** What computes `where`?
  - Default: no new mechanism.
    - `where` is the existing node-drop map's split of `ln J` by spell, which adds 5–8% to a
      sweep.
    - Add O4's distance from θ₀ and the failures.
- **Q9.** Why a bound and a J-share rule for leaving short spells out, rather than a fixed
  reserve?
  - Default: short spells keep one interval.
  - Their measured maximum, 0.10ε (R12), goes into the hold beside the tolerance bias.
  - No code for a bound.
- **Q10.** Why no cap on interval width?
  - Default: cap intervals at 80 d, so that the removal's merged intervals stay within the
    160 d where the square law was measured to hold.
- **Q11.** Why place the stall boundary with five separate bisection runs, rather than from
  neighbouring nodes' sign-change counts on each refining run?
  - Default: take it from each run's own counts, with no extra runs.
  - This still needs the per-node counter, which today's runs do not record.
