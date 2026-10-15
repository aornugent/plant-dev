# Judge's verdict: how odelia should represent the points where a System's rates are not smooth

Read: `ledger.md`, the system-design skill and its deep-search role, `OBJECTIVES.md`,
`docs/handover.md` "Principles", then (in that order) my scarcity derivation
(`judge_scarcity_draft.md`, written before anything else was opened), `sealed_scarcity.md`,
P1–P5, P2's spike outputs, JT notes parts 1–4 (E4, E6, S1–S4, P3-S1..S3, H2),
`kinks/inventory.md`, `design-grid-controller.md` "Why the cuts move", odelia
`origin/ODELIA-55` (`cb4d262`) and plant `PLANT-110` (`7ab43139`). Nothing was built or run.
Labels: **(m)** measured, with its source; **(e)** estimated; **(j)** derived here.

## 1. The verdict

- **On the ledger as written, the floor wins.** The floor is the forward stop with held
  ends: the forward ends a step at the first and last zero of f_hi in each cluster, and
  every later pass treats those ends as ordinary row ends. P3 names it the floor, and P2
  (C), P1 (B) and P5's core (B without its relocation) are the same design with
  different declarations. It is the only design with a measured R1 (0.0020 against 0.006)
  and a measured R3 (+12.8% rows against +14%).
- **Two amendments, both taken from losing proposals.**
  - Use P5's one reading with two parts (`sign_readings{blocks, shared}`), not a second
    parallel list. P3's `stop_values` and P2's index convention would add that list.
  - Count the cut attempt in `step_outcomes` (P1), so that `attempts()` stays the sum of
    the outcomes. JT's build counted it nowhere.
- **P5's relocation is killed** (§3, P5).
- **On the domain question, no proposal has the whole representation.**
  - Each has one part. P2 has the physical account, P1 the taxonomy, P5 the placement
    rule, and P1's rejected A (P2's E) the carrier.
  - Put together, they give a representation that holds up (§6, the judge's own).
  - It does not survive its kill question on the brief as written: R2 asks only for
    continuity, and held ends meet that by estimate. It wins if the user reads R2 as
    resolution at θ′, or if one cheap measurement (§5) shows held ends losing R1's bar
    within the 1e-2 chord.

## 2. Scarce resource

**Mine (written before reading the sealed sentence or any proposal):**

> Whole-stand rows near the switch. The stand switches as one cluster, so about two row
> ends per switching step settle R1, but they use 12.8 of R3's 14 points, leaving ~1.2
> points for everything else. A held row end is fixed at θ₀ while the cluster moves with
> θ′, so the same ends must also serve every θ′ on the grid (R2/R7). Held ends cannot do
> that unless the cluster's movement over one analysis stays inside the margin they
> leave. The cheap resource is the soil: its substeps cost evaluations, not rows.

**The orchestrator's (sealed):**

> Step ends in the drying windows. Each step end costs a retake (~12 evaluations) and
> sweep rows, so a resolution must cost a fixed number of step ends per cluster, not one
> per sign change.

**Agreement.** Both say the cost is set per cluster, not per sign change (14 728 changes
in 234 of 4786 steps). The "about 12 evaluations per retake" checks against the JT
part-3 table.

**Disagreement, stated:**
1. *The sealed sentence prices one run; mine also prices θ′.*
   - The ledger's R2 and R7 make one grid serve a whole analysis.
   - A row end placed at θ₀'s zero is a resource that goes stale as θ′ moves.
   - P2's spike measures how fast: 0.28 d per 1% of a trait, against a 0.44-d core.
   - This is the load-bearing question the proposals split on (§5). The sealed sentence
     does not see it.
2. *"Step ends" names the treatment, not the resource.*
   - Pieces inside a row (P1-A, P2-E, P4-B) spend evaluations, not step ends.
   - Phrased as step ends, the scarcity rules them out before they are priced.
   - Priced, they are not more expensive (§6).
3. *Three other derivations differ:*
   - P4: rows in the passes that never differentiate (walks, adaptive secant forwards).
   - P3: row ends, at most one change in 22 (≈ 670 ends of budget).
   - P1 and P2: rows.
   - P5's scarcity sentence is the sealed sentence word for word. P5 was written in the
     orchestrator's context, so its agreement with the orchestrator is not independent
     evidence.

## 3. Per-proposal verdicts

### P1: one account of where time is divided (winner B: a declared list `sign_auxes{aux, ends_step}`; the stop; ends held)

**Arithmetic.** The ledger numbers match the JT notes. Recomputed:
- A: +18 evaluations a bracketed row (234 × 18 = 4212, 14.7% of 28 716) ✓.
- B: +22.5% forward evaluations ((548 + 530) × 6 / 28 716) ✓.
- One slip: the ¼:¾ weighting gives B 14.3% only if the sweep pays +11.5% (steps). The
  sweep pays per row, so it pays +12.8%, which puts B at **15.2%** against A's 14.7%. A
  is then slightly cheaper in P1's own model, and "for the same evaluations" no longer
  holds. A's elimination rests on lines alone.
- P1 does not flag that A's +14.7% per pass is above 14%, if R3 is read in evaluations.

**Kill question** ("a K point inside a step leaves an O(h) gradient error the controller
cannot buy back within R3"): survives. The ledger supports it: 0.048 against 0.006, and
ETT at 0.025 for +8.6%.

**Code.** All checks pass:
- `attempts()` is the sum of the outcomes.
- `step_by` and `step_to` cannot reach a step-end call.
- `choose_substeps` does call its landing points `stops`, though they include stage and
  sample fractions as well as knots.
- The 19.6%-of-sweep and ×0.758-rows numbers are in `perf-sweep.md` and `localised.md`.

**The finding against it.**
- The commitment derives placement from range: "a stop whose range is the whole state
  ends a row, and every pass after the forward holds it."
- P1's own taxonomy says placement should follow how the stop arose (chosen, known or
  located). The project's rule for split cuts says the same ("Why the cuts move").
- P1's first kill condition is "the f_hi zeros move by more than the cluster's width over
  the ±10% resident radius". P2's spike has now measured it: 2.5–3.2 d median at 10%,
  against 0.44 d.
- So by P1's own map, B hands off to A.

**Verdict:** survives the arithmetic, but is displaced as P1's winner by its own measured
kill condition. A is P1's successor and is the carrier of §6. As a declaration, B is the
most general of the five (several points, of either reach), at the most names (6).

### P2: move the boundary (winner C: located once by the forward, then an ordinary step end)

**Arithmetic.**
- The spike tables match `edges.out`, `edges_pilot_ref.out` and `ramp.out` exactly:
  0.28 / 0.29 / 0.08 at 1%, 0.95 / 0.74 / 0.57 at 10%.
- The label "A's switches outside the reference's brackets" is reversed in the θ′ rows:
  the script counts θ′'s roots outside θ₀'s bracket. The prose uses it correctly.
- Cost: +19.9% forward evaluations ✓; gradient run about +15% ✓ (I get +15.5%,
  counting the 530 discarded attempts at about 1.9 ms per evaluation).
- One weak inference, in candidate A: "representing the cluster exactly as a ramp would
  cut its error by about half". The half is relative to a single jump. Today's 51-node
  staircase already behaves like the ramp, so the ramp representation would buy close
  to nothing. This strengthens A's elimination rather than weakening it.

**Kill question** ("R1's 0.006 bar is needed"): survives, with the challenge logged (Q1).

**Code.** `instruction` carries only time, size, insertion flag and substeps ✓, and
`advance_recorded` never reaches the accept path ✓.

**The soft clash.**
- P2 justifies holding ends where split cuts move: "a step end at a cluster's edge carries
  about 1/N of the cluster's jump".
- Its own spike says that at the ledger's chord step (1e-2) the held edge carries
  **8–29%** of the cluster, not 1/N ≈ 2%, and at 10% it carries 57–95%.
- P2 states this as a price ("resolution fades beyond about 0.5%"), because it reads R2 as
  continuity only.
- That reading is the only thing standing between P2's commitment and its own data.

**Verdict:** survives. It has the clearest statement of the floor and the best domain
account (§6), and it states its limit honestly.

### P3: branches as data (winner: the floor; C staged behind U1)

**Arithmetic.**
- Per-flip jump: 0.9 × 0.17 / 30 = 0.0051ε; / 0.04 → 0.125ε; × 0.25 / 51 → 6e-4ε ✓.
- That uses the *typical* top-30 cluster and the *mean* stage weight.
- The ledger's bar is on the largest jump. The 9.70 window's run errors of −0.042ε and
  +0.023ε (E4) put its coefficient at 0.2–0.6ε, and the largest weight is 0.40. That gives
  0.002–0.005ε, about 8× P3's figure, as P1 and P2 found. Still under 0.01ε.
- **A clash with measured data.** P3's floor passes R2-as-roughness only "unless τ is above
  about 25 d" (its formula: 0.002ε·√τ). P2's spike measures τ = 25–29 d. So P3's own
  formula puts the floor at about 0.010ε, the bar.
- That uses the 0.44-d row's flip size. Once the cluster has moved into 2-d rows, the flip
  is 6e-4ε and the formula gives about 0.045ε.
- The random-walk model also assumes mixed signs. A common shift of the cluster moves
  every flip in one direction (§5), so the true change is a drift, not a √n sum.
- P3's A bias with the measured τ: K·τΔ = 0.6–1.9 ε/d × 27 d × 0.1 = **1.6–5ε** at ±10%.
  Holding branches is far worse than P3 thought. A stays eliminated.

**Kill question** ("the switch moves the gradient through the soil, which every node
reads"): survives, by P3-S1 (0.044), P3-S2 (0.010) and the stop (0.0020).

**Code.** Checks out:
- `store_into` clears the list.
- A walk seeds `solved_scratch_` from the record, and plant's store clears it, so the walk
  searches again.
- `solve_leaf` places where a point was loaded.

**Verdict:**
- The floor survives if R2 is per jump.
- P3's claim that the floor passes R2 *as roughness* is refuted by its own formula with
  P2's τ.
- U1 is the wrong test for the question in §5: a quadratic fit absorbs a smooth drift.

### P4: pieces only in passes that differentiate (winner B)

**Arithmetic.**
- The cost model reproduces the ledger: 61.9 / 161.8 / 223.7 s.
- +111 150 rows is 12.2% of the gradient run's 908 988 ✓, and +24.9 s is 11.1% ✓.
- The 84-forward reference analysis does use adaptive secant runs (`design-workflows.md`
  line 137) ✓.

**Two mislabels on the winner's key line.**
1. R1 is listed as "0.0020 (m)". That was measured for the stop: exact zeros (≤ 0.0012 of
   the step, regula falsi) and a controller that restarts at the cut. P4 places its
   brackets by linear interpolation between six readings up to 0.3 h apart (≈ 0.6 d in a
   2-d step, against a 0.44-d core). Its own body says "expect 0.002–0.004 (e)". The (m)
   is borrowed.
2. "A misplaced cut costs at most one node's share × 0.098·h_piece" is wrong.
   - A first edge placed early by δ leaves the ramp's kink inside the middle piece, near
     its start, at an error of about b₁·h·(δ/W)·ΔG.
   - That is linear in the share of the cluster δ spans, not one node's share.

**Kill question** ("the repair matters only to passes that differentiate through the
resident's soil"): survives.
- It follows from R7 (no feedback) and H2 (λ_soil carries it).
- Every proposal reaches it independently: no proposal needs anything in the invader's
  walk for #10.

**Code.** Every name P4 cites exists:
- `error_index` and `no_component` on `step_record`;
- `forget_error_component` in `step_to` and `step_by`;
- `sweep_each_seed`, `restore_on_exit`, `sweep_range`, `refine_schedule`;
- the comment on `schedule()`.

One flag: `schedule()` feeds `get_times` and the schedule written back into Parameters,
so the pieces become visible to R. P4 flags this itself.

**R2.** Replays hold the pieces, so P4 has the same radius as the floor.

**Verdict:** survives, conditional on R3 per analysis (Q3) and the R6 challenge (Q6). Its
R1 is less supported than the floor's, and its sweep steps a forward inside itself, which
adds reader load.

### P5: step ends at shared sign changes, located ends relocated (winner B, revised)

**Ledger.**
- P5 renumbers the brief's requirements (its R2 is cost), and drops the brief's R2
  (continuous on one grid) and R5's "one account" as numbered lines. This is a sideways
  edit, which the skill forbids.
- Its floor is ETT rather than the stop. That is legal but unusual.

**Arithmetic.** Fallback location: 530 × 4 / 32 500 = 6.5% ✓.
- The margin rationale is sound in mechanism. The end evaluation is the next step's first
  stage, the sweep loads its arm, and c = 1 has weight 0.
- But the measured 0.0020 used **no margin** (JT's root in (1e-6, 1 − 1e-6)), so P5's
  margin and its location by polynomial (G0) are unmeasured changes to the measured
  design.

**Code.**
- A retaken step does write the same scratch row (`solved_scratch_` is reset in
  `stepper_step`) ✓.
- With no open list, `leaf_solved_points` stores and loads nothing ✓.
- Forward stores, sweep loads, walk searches again ✓.
- The final-step path leaves `step_size_last` unchanged ✓.
- Rosenbrock takes no splits ✓.

**Field-vs-field clashes, which kill the relocation:**
1. *Kept true by* says "`SolverInternal::step` is the one place that ends steps". §4 has
   `step_by` (pinned replays) end rows at relocated zeros. The structure named to keep the
   commitment does not hold it.
2. The relocation is justified by "continuity in the traits over the analysis (±10%,
   chords)". Its carrier, a row end moved between two held neighbours, cannot follow a
   shift past the neighbouring held end.
   - At 10% the median shift is 2.5–3.2 d (90%: 7.4–11.8 d), against steps of about 2 d.
   - The number of clusters changes (79–92 against 83).
   - So the mechanism cannot reach the regime that justifies it.
3. The selection rule, "the zero nearest the recorded end", can jump between nodes when
   two zeros straddle the recorded end. That is a discontinuity in the end time, which
   R2 forbids. The first zero over the nodes (a minimum of continuous functions) would be
   continuous.
4. The design does not say what the replay does when θ′ moves the zero past the row's own
   end. Then the zero is not on "its own step".

**The overstated claim**, "past the margin the error is 0.1·h·ΔG again": §5 settles it.
It is correct per node and in the limit, and overstated for the cluster at small shifts.

**Verdict:**
- The relocation is killed.
- The held core is the floor, and its `sign_readings{blocks, shared}` is the best
  declaration of the five. It replaces the existing vector rather than adding a sibling,
  and has no index convention.
- P5's review sentence, "the draft made a located point into a row end, then held it as a
  chosen one", is the most important observation in the five documents (§6).

## 4. The record of each proposal against the ledger

| | R1 nudge | R3 rows / forward evals / gradient-run time | R2 per jump | resolution at θ′ (held radius) | R4 names | R6 | R9 |
|---|---|---|---|---|---|---|---|
| Floor (P3; P2-C) | 0.0020 (m) | +12.8% (m) / +20% (m) / ≈ +15.5% (j) | ≤ 0.005ε (e) | 8–29% of switches leak at 1e-2, 57–95% at 1e-1 (m, spike) | 3 | exact | no time term |
| P1-B | as floor | as floor; weighted 15.2% (j) | as floor | as floor | 6 | exact | no |
| P5-B, relocation removed | as floor if G0 passes (unmeasured) | as floor | as floor | as floor | 2–3 | exact | no |
| P4-B | 0.002–0.004 (e; mislabelled m) | gradient run +12.2% rows (e); forwards and walks +0 | ≤ 0.0012ε (e) | as floor (pieces held) | 5 | ≈ 0.001ε off (e, challenged) | no |
| Judge's §6 (P1-A, P2-E) | E6: 36×, within 0.002ε of refined (m, on pinned rows); unmeasured as built | +0 rows / ≈ +12% (j) / ≈ +11–13.5% (j) | ≤ 0.005ε (e) | follows the zeros at any θ′ (e) | 3–4 | exact | time term from `implicit_value` |

**Rank.**
1. The floor, amended.
2. P1-B: same numbers, twice the names.
3. P4-B: wins only under per-analysis R3.
4. P5 with relocation is killed. P3-A, P1-C, P2-A, P2-B, P2-D, P4-A, P4-C, P4-D and P5-A
   are eliminated by their own documents, with arithmetic that checks.

The judge's §6 design is not ranked as a survivor. It fails its kill question on the brief
as written (§6), and it is the named successor.

## 5. The settled question: a pinned replay of θ₀'s grid at θ′, and a leaf switch that has left a recorded step end

**What is measured.**

- **How far the cluster moves** (P2's spike; adaptive runs, controller noise ≤ 0.03 d at
  ×1.001). The shift is linear in the trait:

  | Trait change | Median shift | 90% |
  |---|---|---|
  | 0.1% | 0.028 d | — |
  | 1% | 0.25–0.29 d | 0.58–0.84 d |
  | 10% | 2.5–3.2 d | 7.4–11.8 d |

  So τ = dt*/d ln θ ≈ 25–29 d.
- **How much leaves θ₀'s bracket** (±0.1 d). The share of θ′'s switches outside it is 0
  at 0.1%, 8–29% at 1% and 57–95% at 10%. At 10% the cluster count changes (79–92 against
  83).
- **Exact bracketing works on fixed rows** (E6). Pinned rows given boundaries exactly at
  the switches cut the window's jitter 36×, and each run lands within 0.002ε of its
  refined answer. This is the measured value of having the ends where the zeros are.
- **Holding a located division at θ₀ costs first-order error** (the project's own
  measurement, `design-grid-controller.md`). Split cuts held instead of moved put the
  sweep 7.5e-3 off central differences in `lma` (≈ 0.09ε). The reason given: "held while θ
  moves the zero, the rating reads the turn off-centre with a stage's weight".
- **The cut itself.** JT's stop cut at the root with no margin, and measured 0.0020.

**What is estimated.**
- *Per-crossing jump* (each node whose zero crosses a stage or a held end):
  - P3: 1.4e-4–6e-4ε (typical cluster, mean weight).
  - P4: ≤ 0.0012ε.
  - P1 and P2: ≤ 0.005ε (largest cluster, largest weight).
  - The bar is on the largest, so take ≈ 0.005ε. That passes "no jump above 0.01ε" at
    149 nodes, and fails (≈ 0.014ε) on a 54-node grid.
- *Drift (j).*
  - The jump is not the whole effect. A node whose zero has moved a fraction u past a held
    end contributes h·ΔG_node·φ(u), with φ(u) = Σ_{c_i>u} b_i − (1 − u).
  - Just past the end, φ = −b₁ = −37/378 (P5's mechanism). φ crosses zero at u ≈ 0.1 and
    reaches +0.2 at u = 0.3.
  - So the held-grid gradient returns to today's unresolved error in proportion to the
    share of the cluster that has crossed. The return is continuous (a staircase of small
    jumps) but one-signed per cluster.
  - At 1e-2 that share is 8–29%. For the largest cluster (coefficient 0.2–0.6ε) this is of
    order 0.003–0.017ε. Over the 30 clusters that matter it is likely of order 0.01ε.
  - That is comparable to R1's 0.006 bar, and it is a drift that a chord of gradients at
    u = 1e-2 reads as curvature.
  - By 10% the held grid carries an unresolved run's error: anywhere from 0.003ε (run A's
    own) to 0.18ε (run B's).

**Each proposal's claim, judged.**
- *P2* ("1% moves the cluster 0.28 d; 8–29% outside"): measured and right. Its "price, not
  kill" holds only under R2-as-continuity.
- *P3* ("one flip moves the gradient 1.4e-4–6e-4ε"): right for typical flips, low by about
  8× for the largest. More important, it measures the wrong quantity: what goes wrong at
  θ′ is the accumulated drift, which its √n model cancels and the data do not.
- *P5* ("past the margin, the first stage reads the old arm, and the error is 0.1·h·ΔG
  again"): right per node, and right for the cluster once the whole cluster has crossed
  (≈ one cluster width, about 1.5–5% of a trait). For a shift of minutes it is overstated:
  only the nodes whose zeros crossed contribute.
- *"Why the cuts move"*: applies unchanged. A held end at a moved zero reads it off-centre
  with b₁. The difference from a split cut is how much jump sits at the end: a whole node's
  for a split cut, a growing share of the cluster's for a stop end.

**Settled.**
- Held ends keep their benefit for central differences at 1e-4 and Jacobians at 1e-3
  (shift ≈ 0.003–0.03 d, nothing leaks).
- They keep only part of it for chords at 1e-2.
- They keep none of it across the resident's ±10%. There the gradient is continuous,
  within ε of the converged value, and as jittery as today.
- Whether "part" at 1e-2 passes depends on a number nobody has measured.

**The cheapest decisive measurement (≈ 3 runs, ≈ 15 min at -O2).** Use the stopped dry run
(libJTstop, `JT8_ins_3e-4_stop`), TF24_cost_scale × 1.01:
1. A detection-only forward at θ′ (`JT_STOP=0`), to log θ′'s roots.
2. A pinned replay and sweep of the stopped run's rows, held, at θ′.
3. The same rows with each cut end moved to θ′'s first or last root (E6's `mkstops.R`
   already rewrites pins this way), replayed and swept at θ′.

The rms difference of (2) and (3) over the 50 traits, in ε, isolates exactly the held-end
error.
- **≤ 0.006:** held ends serve the chord step, and the floor stands.
- **> 0.006:** they do not, and §6's trigger is met.

Repeat at ×0.99 if the first result is near the bar. P2's gate 3 and P3's U1 (21 replays,
≈ 1.5 h) test smoothness, so they would pass a smooth drift. They do not decide this.

## 6. The domain model

**What each proposal contributes.**
- **P1, "a stop with range and placement".** The right two attributes. Origin (chosen,
  known or located) should decide what a later pass does, and reach should decide which
  integrator lands on it. P1 then lets range decide placement (whole-state stops held).
  That reintroduces exactly the special case the taxonomy should remove.
- **P2, "the soil's sensitivity is a ramp; only its two edges are real".** The best
  physical account.
  - On the birth-date coordinate the switch is a front t_s(b). Its 51 node jumps sample a
    ramp in the soil's integrand.
  - That explains every measured treatment:
    - bracketing the edges works (0.0020; E6, 36×);
    - a piece per sign change does not (0.018);
    - the node split does not (0.044);
    - smoothing does not, because W/h is set by the controller (the averaged gate, and
      the ramp spike).
  - Two caveats:
    - The edges are kinks only where the front's extreme falls at the edge of the age
      range. At an interior extreme of t_s(b) the edge rises as a square root. Untested.
    - Stragglers (8 of 56 nodes 1.9 d ahead at 9.70) bend the ramp.
  - P2's own spike shows the ramp moves bodily with θ. Its account therefore implies the
    edges are θ-dependent located points, and its commitment (held) contradicts that.
- **P3, branches as data.** Classifying what each pass holds and what it decides again is
  useful. Holding branches is a dead end (1.6–5ε of bias at ±10% with the measured τ).
  P3's reach rule, "a branch change ends a piece of the blocks that read it", is the right
  rule.
- **P4, pieces only in passes that differentiate.** A cost allocation, not a domain
  representation. Its true core (invaders carry no λ_soil, so they need nothing for #10)
  follows from reach once reach is stated as "the blocks a pass integrates".
- **P5, located ends follow their zeros.** The right placement rule, attached to the
  wrong carrier. A row end cannot move past its held neighbours.

**What is still missing.**
- The record has a type for "a time that is a function of θ" only at one node's reach
  (`split_block`/`sign_change`, located again by `split()` in `step_by`, moved by
  `implicit_value`).
- At whole-state reach the only container is `instruction{time, step_size}`, which is a
  number.
- Every held-end design stores a located time as a number. That is the modelling error the
  user senses. P5 named it, and its fix (a flag on the number) cannot carry it far.

**The judge's own representation** (marked as the judge's; not proposed by P1–P5 in this
form).

> A point located from the state is a time that moves with θ, where a rate read by some
> blocks changes form. It divides the integration of every block that reads that rate
> within the step, and every pass that integrates those blocks finds it again at its own θ.
> Rows end only where the controller chose or a schedule fixed.

- **Data structure.**
  - Widen `split_block{block, first, sign_changes, solved}` from one node's block to the
    blocks that read the value: one node, or the whole state.
  - The System declares each value with whether it is read by its own block only or by
    every block (P5's `sign_readings{blocks, shared}` already has that shape).
  - odelia divides the row at each zero for an own-block value, as today. For a shared
    value it divides the row at the first and last zero over the nodes, which are P2's two
    edges. Each edge is a minimum or maximum of continuous functions, so it is continuous
    in θ.
- **What it removes or makes unnecessary:**
  - the stop's retake in `step()`;
  - P1's `ended_at_first_`;
  - P5's `ends_at_sign_change` and its relocation in `step_by`;
  - P4's pieces in `schedule()`;
  - the soil split as a separate case (P3-S2's 0.010 is this rule with the reach set
    wrong: the nodes read the soil but were not divided);
  - the distinction between "row ends at zeros" and "cuts at zeros".

  What is left is two kinds of division, by origin: held (chosen or known: controller
  ends, Events, insertions, rain knots) and located (moved).
- **What follows from it without extra code:**
  - *R2's radius.* The edges follow the zeros at any θ′. When a front crosses a held row
    end, a piece shrinks to zero length continuously.
  - *R9.* `implicit_value` on a moved division gives Δf·dt*/dθ for a J, and zero for a K.
  - *R7.* A walk does not integrate the soil, so #10 divides nothing in a walk.
  - *R5.* One account, with two origins.
  - *R8.* The per-node split is the one-block case, unchanged.
- **Price (j).**
  - Forward: one whole attempt plus 17 evaluations in three pieces a bracketed row
    (P3-S2's 5 + 6 + 6). That is ≈ +12% forward evaluations against the floor's +20%, with
    no retakes.
  - Sweep: ≈ +9% (taping 17 evaluations instead of 6 on 234 rows). Rows: +0.
  - Gradient run: ≈ +11–13.5%, against the floor's ≈ +15.5%.
  - Replays at θ′: ≈ +12–14% (the floor: +12.8%).
  - Lines: ≈ +150 over the floor (P1 ≈ 280, P2 ≈ 300 for the whole design). The cost is a
    nested whole-state piece in Step, the record, the sweep and the walk.
  - R1 as built is unmeasured. E6 (m) is the closest evidence: exact boundaries on fixed
    rows, 36×.
- **Kill question.** The assumption whose falsity makes it unnecessary: *some pass on one
  grid needs the switch resolved at a θ′ farther from θ₀ than held ends reach.*
  - From ledger facts alone, that assumption is **not established**. The brief's R2 bar is
    "no jump above 0.01ε", which held ends meet by estimate (≤ 0.005ε). Accuracy within ε
    holds unresolved, and OBJECTIVES allow "several grids or a finer one" where a grid's
    radius is short.
  - **Verdict: it dies on the brief as written.** It wins when any of these holds:
    - Q2 is answered "resolution at θ′";
    - §5's measurement exceeds 0.006 at 1e-2;
    - a J kind appears on accepted stages (Q7);
    - R3 is read as time, and the floor's ≈ +15.5% fails where this design's ≈ +12%
      passes (Q4).
  - Building the floor first loses little. The floor's f_hi in phylloptim, its declaration
    and its location rule are reused. Only the retake path (≈ 30–40 lines) is thrown away.

## 7. Questions for the user (each challenge raised upward across P1–P5, with my recommended default)

| # | Question | Raised by | Default I recommend |
|---|---|---|---|
| Q1 | Is R1's bar 0.006 (a third of the tolerance's own move, so a looser companion run estimates the error), or OBJECTIVES' ε/3 (0.33, already met today at max 0.176)? Is the tolerance companion consumed (`diagnose_scm` estimates only the introductions knob)? | P2 (kill condition: at ε/3 doing nothing wins), P5, P4 | **Keep 0.006.** OBJECTIVES' Predictable names every knob, and the controller chooses introductions and steps together. |
| Q2 | Is R2 a bar per jump, a bar on total roughness over one analysis step, or resolution at θ′ (gradients at θ′ as accurate as a fresh run's)? | P1, P2, P3; implicit in P5's G7 | **Per jump ≤ 0.01ε, plus a measured and reported radius** (OBJECTIVES: Diagnosed). Upgrade to resolution within the 1e-2 chord if §5's measurement exceeds 0.006. That is the trigger for §6. |
| Q3 | Is R3 per gradient run or per analysis (84 forwards, mostly adaptive secant runs and walks that never differentiate the resident)? | P4 | **Per run**, with the per-analysis cost reported. If per analysis, P4-B and §6 both beat the floor. |
| Q4 | Is R3 counted in rows or in time? The floor is +12.8% in rows and ≈ +15.5% in time, counting its 530 discarded attempts. | P1, P2 (consistency passes) | **Rows**, as written, with time reported. If time, first skip cuts in attempts under 0.25 d (243 of 530; unmeasured nudge). |
| Q5 | Does R4 cover holding a point's branch in later passes, or only detecting, locating and stopping with one member? | P3 | **Detect, locate and stop.** No branch holding (it is a dead end, §3, P3). |
| Q6 | Must R6 hold strictly for the run that built the grid? Under P4 that sweep is ≈ 0.001ε off its own forward. | P4 | **Strict.** The floor and §6 both meet it exactly. |
| Q7 | R9: how often do J kinds (#13, #14, #19) occur in **accepted** rows on each bank record, now that phylloptim 0.9.3 differentiates a Determined collar? Should #13 (an artefact of the 1e-3 MPa tolerance) be made continuous at source? | P1–P5; P3 on #13 | **Measure the census before any J handling.** If #13 appears, fix it at source. |
| Q8 | Every number is from libD (a step ends at every rain knot). Re-measure the stop's nudge and cost on libS (#274, knot pulses dropped, rows ×0.758) before landing? | P1, P5 | **Yes.** #274 first. The 1.2-point R3 margin may not hold on libS. |
| Q9 | Is an in-sweep error estimate wanted (+9.5% of the sweep), or is the companion run enough once jitter is below the bar? | P4 | **Companion only.** |

## 8. Kill-condition map (each losing candidate's "wins when")

| Candidate | Wins when |
|---|---|
| Doing nothing (P2's floor) | Q1 is answered ε/3 |
| §6, the judge's representation (= P1-A, P2-E) | Q2 means resolution at θ′; or §5's measurement > 0.006 at 1e-2; or J kinds on accepted stages; or R3 is read as time |
| P1-B (declared list with `ends_step`) | Several points of both reaches must be declared at once. Its declaration is the most general. |
| P1-C (walks relocate their own splits) | Invader chords are measured to jump |
| P2-A (the ramp in the model) | The transition is naturally several steps wide (≳ 0.7 step) |
| P2-B (the pilot's times) | A workflow always replays before it sweeps, so the times are exact |
| P2-D, P3-S2 (soil split) | Rows are scarcer than the bar and 0.010 suffices |
| P3-B (every change ends a row) | Changes number fewer than ≈ 670 a run |
| P3-C (held branches plus located stop ends) | U1 fails. Superseded by §6, which needs no held branches. |
| P4-B (pieces only where differentiated) | Q3 is per analysis and most passes are walks or adaptive secants |
| P4-P (pieces in the schedule; the gradient from a replay) | Q6 is strict under P4 |
| P4-A, P5-C (selection by the adjoint) | Bank rows exceed +14%, or every pass sweeps the resident anyway |
| P4-C (correction term) | Kinks are isolated and the consumer wants the continuous model's gradient |
| P4-D, P5's floor (tighter tolerance near edges, ETT) | The point is a W, not a K (the averaged gate's knee: 0.009 at +11.5% rows) |
| P5-A (modes, guards, actions) | An action triggered by the state arrives (thinning at a basal-area bound), or jumps dominate |
| P5-B with relocation | Killed. Its rule (located ends follow zeros) is carried by §6. |
