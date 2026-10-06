# Judge's verdict: sign changes in TF24's net production

## 1. Scarcity

**Mine** (`judge/scarcity.md`, written before the sealed one): runtime inside the ~5% of steps that hold crossings is scarce. R8's bar (about 264k node ratings) over the 726 crossing steps buys about 1.2 extra rows per crossing step, or 28 node ratings per crossing node step. That is 7x under tol 1e-5 and 30–40x under global step ends. Within it a treatment must buy R2's 40% cut (0.56 → under 0.33 ε), with lines (R9) as the competing budget.

**Sealed:** runtime is slack for a treatment confined to the node (28 ratings against the 12 it needs) and binding for anything that touches rows (600–900 rows in all). The scarce thing is discrete decisions, times the passes that repeat them.

**Reconciliation.** The arithmetic agrees (1.2 × 726 ≈ 880 rows). The candidates' counts show where each sentence binds.
- Halving spends two rows per crossing step on the forward (1452 on long drought; 1246 on episodic, whose budget is about 370–550) and one on every later pass (726; 623). The row budget breaks on the forward, and on episodic on every pass.
- Node-level designs never touch rows, and for them the sealed sentence holds. The cut makes about 9200 decisions per pass and pays in lines. B makes one switch per node step and pays one evaluation per crossing step.
- So decisions are scarce for node-level designs and rows for step-level ones, and the candidates sit along that trade.

## 2. Shared arithmetic, recomputed

- **R1's floor applies.** `eps-spread.md` uses the larger of each ε and 0.01, so d_I's 1.261 becomes 0.06 ε/3.
  - On the driver's programs, plain fails on a_dG1 alone (1.049).
  - On plant's own controller (`docs/measurements/nudges`), plain moves 1.65 ε/3, with four traits over 1.
  - Every R1 number for the cut and for halving comes from the driver's meshes.
- **R2.** Every R2 figure is a second difference of ln J over three tolerances; R2 is worded as a chord. For the cut the two agree (−43.459 against −43.458, §19). For halving the chord is unmeasured.
- **Nudges.** No one, the incumbent included, has run the quarter-spacing shift.
- **Halving's forward costs +10.4%, not C's +8.4%.** The halves add 5.2% of member evaluations (rp_h1 to rp_h2), and the discarded attempt adds as much again.
- **New (mine, `judge/m3/`).** I replayed episodic's recorded 1e-4 program, after validating the script on long drought (718 crossing steps against the record's 726).
  - On episodic, 623 of 9247 steps hold a sign change (6.7%), with about 8–10 crossing nodes each against 12.7 on long drought.
  - Halving there costs +6.7% on every replay and sweep, and +13.5% on the forward.

**Overheads, in % (episodic in brackets).** A run weighs the forward 1, the sweep 2.6, the walk 0.8 and the walk's sweep 2.6.

| design | per pass (forward / replays) | resident run | seven passes |
|---|---|---|---|
| incumbent, or D with E's walker fix | 6.0 / 7.3 (6.5 / 7.9) | 6.9 (7.5) | 3.6 (3.9) |
| D as written (walks split too) | walk 7.5, its sweep 7.3 | 6.9 | 7.1 (7.7) |
| halving (C, E) | 10.4 / 5.2 (13.5 / 6.7) | 6.6 (8.6) | 5.9 (7.7) |
| B | 0.9 (about 1.1) | 0.9 | 0.9 |

I score R8 per pass, as written. The bar is silent on invader passes, because the incumbent skipped them and failed R7, so I charge a walk at the forward's absolute overhead.

## 3. Per candidate

**A [first thought]: killed.**
- Its ~4% cost checks out.
- *Mechanism clash:* it detects by an "end sign difference" before the evaluation that rates that end.
- *Regressions:* its four-sample cubic replaces the golden search §18 needed for pulse-onset pairs (dips 0.004–0.45 of a step wide). It locates on that cubic, beside a leaf class-switch kink that sits a median 0.26 d before upward crossings.
- *Kill question:* as A framed it ("false if a cheaper treatment meets R1 and R2"), it is false on TF24: halving meets both (0.43, 0.249).
- *Ledger:* R7 fails silently. Nothing is measured.

**B: survives, unmeasured on TF24.**
- One extra evaluation per crossing step, 0.9%, checks out.
- *K's error:* 11% rms in J's window and 25% over all crossing node steps, taken against the dense output's K rather than the true path.
- *Clash, not fatal:* its sufficiency argument uses the 3e-5 median step (0.57 d). Its own 1e-4 replay reports 0.85 d, and a third of its crossing node steps exceed 1.7 d. So hL is 0.12–0.28 at the median and above 0.56 for a filling pool on that third: short of its kill condition (hL ≈ 1), but well past the 0.08–0.19 it states.
- Its "1.2e-8 residual" is a fit residual on a toy, not a jump.
- *Kill question:* "the spread is the kinks'" survives (70–85%).
- *R9:* `positive_part_slopes` is a second, hand-kept source of the rates' dependence on σ.

**C: killed, on three grounds.**
1. Its forward cost (+8.4%) contradicts its own count of two rows per crossing step (10.4%), in the very line it contests.
2. R8 fails as written (10.4% against 6.0%).
3. Under the resident-run scoring it chose by default, it fails on episodic (8.6% against 7.5%).
- Its TF24 numbers stand as the evidence on halving: a_dG1 0.427, R2 0.249, R4 1.6e-5.
- "Steps shrink as √tol" contradicts its own log, which shows tol^0.30.
- *Kill question:* "a tight global tol costs more than the bar" survives, and the same bar fails C.

**D: survives, and wins with E's walker fix.**
- *Arithmetic:* the invader cost of 3.6% of a run checks out (7.5% is the forward's 6.0 over a 0.8 walk), as do the 45 MB record (I get 41) and `Step::split`'s size (232 lines against its 236). The −36% in lines is inferred.
- *Gaps in its search:* it never priced halving, and it dismissed "the caller" with the unfloored 1.261.
- *Kill question:* "the kink must be treated node by node" survives on verified facts. Halving meets R1 and R2 but loses R8 (§4). Only B, unverified, could make it false.

**E: halving killed; its default-answer design dominated.**
- Its +10% and +5.1% are right, and it routes R8 upward correctly.
- Its toy inferences are superseded (R2 0.15 inferred, 0.249 measured).
- *Kill question (crossings cluster):* holds on long drought. Its episodic line cited the record's total steps, not its crossing steps. With my count, a row per crossing step costs about 30 node ratings per crossing node step on replays against the cut's 26, and about 60 on the forward.
- *Default answer:* the incumbent with walkers adding the resident's recorded end changes. It meets every line but deletes nothing.

**F: killed.**
- R7 fails, by its default.
- On R9 it keeps 96% of the incumbent, where D carries the same algorithm and measurements in an inferred 64%.
- *Kill question:* survives, but it tests whether any treatment is needed, not F.
- What survives is its census (99.85% single brackets, κ median 4.9e4, 14 pairs) and its single bracket rule, which folds into D.

**Ledger, line by line.** P pass, F fail, U unknown; "inh." means inherited from the incumbent's TF24 record.

| | A | B | C | D | E (halving) | F |
|---|---|---|---|---|---|---|
| R1 | U | U (toy only) | P 0.43 (driver) | P 0.17 inh. | P (C's) | P inh. |
| R2 | U | U | P thin 0.249; chord U | P 0.05 | P thin | P |
| R3 | U (no search) | U, likely | P by structure | P (2 choices bisected) | P by structure | P |
| R4 | U | U | P 1.6e-5 | P 2.7e-4 | P | P |
| R5 | U | P (toy) | P | P | P | P |
| R6 | U | U (pools) | P | P | P | P |
| R7 | F | P, invaders too | P | P (inferred) | P | F |
| R8 (per pass) | P | P 0.9% | F 10.4% forward | P at the bar | F 10–13.5% forward | P |
| R9 | ~240 lines, 5 names | ~250, 10 names, hand slopes | ~110, 7 | ~540, +9/−18 | ~135, 6 | ~1650 |
| R10, R12, R13 | P | P | P | P | P | P |
| R11 | P | U | P | F→fix | P | F→fix |

The R11 failure is verified: `ode_step.hpp:588` counts splits inside `Step::split`, which runs before the validity check.

## 4. Ranking

**The floor fails.** Plain fails R1 (1.05 on the driver's meshes, 1.65 on plant's) and R2 (0.558 against 0.333). At about 4.8e-5 (inferred), where R2 passes, it costs +12% on every pass.

1. **D with E's walker fix, plus F's single bracket rule.** It passes every line on numbers inherited from TF24. R7 and R9 are inferred.
2. **B.** It takes first place if M2 passes. On R8 it costs 0.9% of a run against 3.6%. On R9 it needs about 250 lines against about 490, with no location, field reads, implicit node or pieces.

**Eliminated:**
- Halving (C, E), on R8. Against D with the walker fix it loses per pass and over seven passes everywhere, and on episodic under every scoring. It wins only the resident run on long drought, by 0.3 points.
- A and F, on R7.

## 5. Combinations

**D with E's walker fix beats each alone.**
- *The fix:* walks stop re-splitting. Each adds the resident's recorded end change, made bit-exact as (walk_unsplit − resident_unsplit) + resident_split.
- *R8:* seven passes cost 3.6% (episodic 3.9%) against D's 7.1% (7.7%).
- *R6:* walks gain no new failure path.
- *R9:* D drops its walk path, `step_splits.field` and the 45 MB record. With F's single bracket rule that is about 490 lines, about 350 fewer than E's default design.

**C with E** is one mechanism; pairing them changes no ledger line.

**The halving convergence is evidence and a shared blind spot.** It is evidence that halving is the least mechanism that meets R1 and R2 at 1e-4 on long drought. But both proposers priced it on long drought's clustering, at 1e-4, on the driver's meshes and at θ₀ only. Episodic breaks it. At 3e-4, where its staircase grows as tol^0.3–0.5, R2 is predicted at 0.35–0.43.

## 6. Winner

**D, with E's walker fix and F's single bracket rule.** It is provisional: M2 decides it against B.

## 7. Flags on the winner

1. It wins only because B is unverified. Run M2 before building it.
2. It does the most: about 490 lines (inferred), and it moves location, the five-fraction field and the implicit cuts into plant. Its own kill condition names the trigger: a second System that cuts.
3. Off the diagonal, the walker fix gives the invader the resident's correction (about 3e-5 to 7e-5 in ln J′, none in the gradients). Invaders' own crossings stay untreated, as today. Say so to the user.
4. Count splits at commit (R11).
5. R3 rests on two bisected choices. E's toy shows choices remade per run jumping to 9.6e-8 on coarse steps, so bisect every choice within ±1e-3 at the build gate.
6. Re-measure the cut's R1 on plant's controller, with the shift.
7. Its 0.06–0.28 ε/3 margin is what `geometry.md` plans to spend on 3e-4 and graded nodes. M1 tests that.

## 8. Decisive measurements, pre-registered

**M2: D against B.** Run the cheapest kill first.
- *(a) A local check on TF24.* Add TF24's ∂rates/∂σ (about 30 lines). In B's R replay, integrate each crossing node finely in the recorded field, then compare plain's local error with h·B·K on long drought and episodic.
  - B dies if the J-weighted residual exceeds 30% of plain's error; B predicts about 12%.
  - Cost: about 2 h, with no odelia change.
- *(b) B's build gate, if (a) passes.* About 250 lines, run on plant's controller:
  - seven nudges plus the shift, over 48 floored traits;
  - R2 by both second difference and chord;
  - J′ = J, and bisection across a passage and a pair's birth.
  - B wins if every trait moves under 0.7 ε/3, R2 is under 0.25 ε both ways, J′ = J to the bit, and no jump exceeds 1e-8. Otherwise D stands.

**M1: does the cut buy 3e-4?** Run lib_rr with the split on, at seven tolerances around 3e-4 plus the shift, on plant's controller. Measure R1 and R2.
- If it passes, the winner runs at 3e-4 (about 1.2x fewer steps on every pass). Halving, predicted to fail R2 there, then matches it under no scoring.
- If it fails, 1e-4 stands.
- Cost: about 1 h, with no build.

**M4 and M5,** only if the user takes E's trade: halving's R2 by chord on plant's controller (M4), and its R1 at θ₀ × 1.1 on θ₀'s grid (M5). Its halves are fixed at θ₀, and about 650 crossings already change step at ±1e-2.

## 9. Losing candidates' "wins when", verbatim

- **A:** "full order at the cut is needed, that is, when a cheaper treatment leaves the gradient's nudge spread above eps/3 at 1e-4 or the r = 1e-2 chord above eps/3."
- **B:** it states none. Its kill condition: "P read other than through the smooth positive part. A σ-reading component that is fast (hL ≈ 1 at crossings). Steps at crossings too long for a cubic (rule A's late 15-day steps)."
- **C:** "Wins when two rows per crossing step buy R1–R2, as measured."
- **E:** "Wins when crossings cluster. On long drought, 9247 node crossings sit in about 726 of 14 840 steps, 12.7 per step. So a row per crossing step costs about what the incumbent spends there: 1.1 rows per split step in its forward, 1.5 in its sweep (measured)."
- **F:** "Wins when: reader load is scarce and records vary."

## 10. Challenges to the user, deduplicated

**From the candidates:**
1. *R4:* is the exact derivative of the run's own map required, or a gradient within ε of the converged one? The default is exact.
2. *R7 (D, F, B, C):* must J′ = J to the last bit, or is about 1e-5 enough? The walker fix makes the bit-exact answer free. Should invaders' own crossings be treated? Only B treats them, within its 0.9%.
3. *R8 (C, E):* is the bar per pass, or a run's total? E's trade, repriced:
   - halving costs +2.3% of a seven-pass run more than D with the walker fix (+3.8% on episodic);
   - on the forward it costs +4.4 points more (+7.0 on episodic);
   - in exchange, it has about 380 fewer lines.
4. *R1 (C):* does the 0.01 floor apply? Yes, per `OBJECTIVES.md`.
5. *R12 (F):* may odelia say "node"?

**From the judge (upward):**
6. *Predictable gradients:* R5 asks that error fall with tol for J only. Halving leaves the gradients' error at the kink's order (a slope of about 1/5 in tol), while the cut restores the method's order. Should R5 cover gradients?
7. *Accuracy across the radius:* R1 is checked only at θ₀. Must it hold across the resident's ±10%, as "Shared" implies? Treatments fixed at θ₀ decay there; ones that re-detect on every replay do not.
8. *The R8 bar:* restate it for designs that meet R7, since the incumbent that set it did not.
