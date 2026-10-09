# Judge: building a run's schedule on the birth-date coordinate

## Scarce resource

**Mine (written before reading the sealed sentence or any proposal).** The scarce resource is rows per evaluation on the one shared grid, because an analysis pays them about 84 times.
- An analysis is 83.6 forward-equivalents at one core and k = 1 (`equilibrium/costs.log`). The figure 60 is four-core wall-clock, not rows.
- u108 errs 2.72ε on long drought. By the square law, R1 needs about 108·√2.72 = 178 nodes, or the u108+u215 pair at 3.06 times the rows.
- Building and checking a grid (window, diagnosis, one finer rung) costs about 3 forwards, at most 4% of an analysis.
- Node error is about 100 times the time error, so those rows are bought by node placement, not by the tolerance.

**Sealed.** "Rows spent on the node axis, per unit of certified node error, amortised over an analysis." It counts certification, at about 0.75 of a run, as a node-axis cost paid again on every run.

**Resolution.** The two agree on what is scarce: node rows, multiplied by about 84. They disagree on certification. Whether certification is paid on every evaluation or once per grid is exactly challenge 2 below, and it sets the price:
- If every evaluation carries its own companion, it pays the pair at 3.06F against 2.06F for u215 alone, which is +49% on every evaluation.
- If a recorded estimate suffices, certification is about 25F once per grid, 8–20% of an analysis.

Two corrections to the sealed sentence:
- The reference analysis takes its gradients by differences of walks, so "×7 per gradient run" applies only to the report and to sweep-based analyses.
- "60–84" should read 84 in rows.

## Common figures

**F, the rows of one spread u108 forward** (bounded Cash–Karp at `3e-5` with the window):

| | long drought | episodic |
|---|---|---|
| soil share 0, the ladder setting where every node error was measured (`node-axis/cost_ld.log`, `soil-alone/report.log`) | 0.637M | 0.416M |
| soil share 0.1, what `control_tf24()` ships today (`soil-alone/report.log`) | 0.373M | 0.230M |

- The ledger's 962 505 rows is the obsolete tied baseline, run without the window or the bound.
- The ratio between the two settings applies to every design alike, so I price in F and give rows on both bases.
- In F, the rungs cost u54 0.49, u215 2.06 and u429 4.26 (measured), and u857 about 8.8 (×2.06 per halving, extrapolated).

**Analysis.** 83.6 forward-equivalents (`costs.R`, floor, k = 1):
- 52 resident forwards for b*: 4 cold candidates × 6, 6 near ones × 4, and 2 Jacobian sides × 2.
- 31.6 walk-equivalents for gradients and the Hessian, both by differences.

Every design also pays:
- the report: one gradient run, 7 forwards (1 + 2.6 + 0.8 + 2.6) on its answer rung. B, C and D left it out; it is not "paid alike", because it scales with the rung;
- each check rung: 7 with gradients, or 13.8 with two corner invaders.

**Today** is `control_tf24`, a 54-node pilot, `control_window`, u108 by hand and `diagnose_scm` once: 96.1F. Its answer errs 2.72ε raw, or 1.22ε on its own u54+u108 extrapolation, so it **fails R1**.

**Errors** (ε, largest over 98 quantities, from `ladder_ld.log` and `ladder_wet.log`; ln J recomputed from the logs' J):

| | long drought | long-wet |
|---|---|---|
| u108 | 2.72 | 3.31 |
| u215 | 0.707 | 0.882 |
| 108+215 extrapolated | 0.174 | 0.090 |
| 54+108 extrapolated | 1.22 | – |
| ln J at u54 / u108 / u215 | 2.11 / 0.21 / 0.06 | 2.67 / 0.43 / 0.10 |

- The 108+215 extrapolation is 0.152ε on long drought against D's own finest extrapolation. 0.174ε is against the median of the three arms.
- Median ratios: (54, 108, 215) 4.98 on long drought (6 of 96 negative) and 5.78 on long-wet; (108, 215, 429) 3.92 and 3.78. ln J's own (54, 108, 215) ratio is 12.8 on long drought.

**Episodic.**
- The moves +0.0058, +0.0076 and +0.0016 are in J (`ladder_why.R` reads `$stand$J`). With J about 1.98, they are 0.12ε, 0.15ε and 0.03ε in ln J, so ln J at u108 is within about 0.3ε.
- The gradients' ratio over (108, 215, 429) is 0.77 for the resident and −0.01 for the invader; their companions report 0.19 and 0.00 of the error.
- No gradient has been run at u857.

**Re-priced, per analysis:**

| | long drought F | rows (share 0 / tf24) | episodic F | rows (share 0 / tf24) | claimed |
|---|---|---|---|---|---|
| today | 96 | 61M / 36M | 96 | 40M / 22M | fails R1 |
| A | 115 (+14 Hessian = 128) | 82M / 48M | 310 (+58 Hessian) | 153M / 85M | 115 / 311 ✓ |
| B | 212 | 135M / 79M | 914 | 380M / 210M | 184 / 786 |
| C | 376 | 239M / 140M | 777 (pair (215, 429), uncertified) | 323M / 179M | 315 / 646 |
| D | 303 (292 with thinning) | 193M / 113M | 1300 | 541M / 299M | 258 / 1102 |

The pair everywhere by hand, with no gate, costs 281F on long drought.

## Per proposal

**A: ε owed by the answer.** Its long-drought and first-episodic figures recompute exactly.

Errors found:
1. Its "rung remembered" episodic price of 216F breaks its own "kept true by", which says the search rung is `every_other()` of the answer rung. Followed, the search runs at u429 and costs 488F. Kept at u108, the rule must be restated.
2. It omits re-walking the classification Hessian on the answer rungs: 3.85 walk-units × 3.55 = +13.7F on long drought, +58F on episodic.
3. Its rows use the share-0 basis while it keeps share 0.1.

**Kill question.** Can a search evaluation be less accurate than the answer, because re-measuring at the final θ repairs it? It **survives**, on ledger facts:
- ln J at u108 errs at most 0.43ε (about 0.3ε on episodic). With a slope of −1.65, b* moves at most 0.0065 in ln b, which 2 secant runs on the pair recover.
- The selection gradient at u108 errs at most 2.72ε. For `lma`'s invader that is about 0.54 against ε = 0.20. Over the convergence Jacobian of −91 (`grid-dynamics.md` §19), the singular point moves about 0.006 in ln `lma`, far inside ±10%. One Newton step on the pair, about 19F, repairs it.

Exposure: on episodic its first check, (54, 108, 215), is unmeasured. If it passes by accident, A accepts a pair whose companion reports 0.19 of the error. **Survives.**

**B: built once at θ₀, a recorded correction.**

Errors found:
1. It omits the N rung's gradient run at θ₀ and the report: 184 → 212F.
2. On episodic it lands on N = 857 run alone: 914F, against 786F claimed.
3. It says gradients "must come from the sweep" but prices the analysis that takes them by differences (83.6, against 94.6 with sweeps). The clash is avoidable: add the recorded elasticity correction to the differenced gradients.
4. Its one drift proxy is ln J, lumped, at `1e-3` on the aligned forcing. In the ±10% box it drifts −3% to +30%, against a kill threshold of 30%: zero margin.

**Kill question.** Its threshold is ε/3. The ledger's R1 bar is ε, and raw u215 already sits at 0.707ε and 0.882ε. So drift threatens B's estimate (R8), not R1. **Survives**, second.

**C: the uniform pair, admitted by its third rung.**

Errors found:
1. Its check leaves out the u108 and u215 sweeps and the corner walks (+39F) and the report (+21F): 315 → 376F.
2. Its "today" is the pair-everywhere floor, not today's u108 path.
3. On episodic it runs the coarser two rungs of the first passing triple, (215, 429). Their gradients are uncertified, because u857 is unrun. The analogous pair on long drought, (54, 108) under a median ratio of 4.98, errs 1.22ε. C's L2 band rejects it only at 1.27 against 1.25.

**Kill question.** Its fail-fast cost is verified: on episodic, stage J fails at ln J ratio 0.76 and wastes 1F. **Survives**, third:
- It costs +24% over a coarse gate on long drought, ε's own climate.
- Its episodic lead of 777F against 1300F is conditional on that pair certifying.

**D: one lattice of edges, halved.**

Errors found:
1. It labels the ladder's rows "soil alone"; they are share 0.
2. It omits the gate's sweeps and the report: 258 → 303F.
3. On episodic, "e = 0.021ε" treats J moves as ln J moves; it is 0.011ε.

**Consistency.** The lattice is justified by "the estimate stays true on every schedule actually used", for non-uniform nested schedules. Its own ledger's graded nested ladder sits at ratio 2.76 with companions 0.65–0.80, and constant's ladder at 1.65. No non-uniform nested schedule has a measured honest estimate. Both witnesses are unmeasured: rule A's thinning (4 points, measured lumped against unweighted runs) and the caller's constant edges.

On uniform nodes D is the floor plus a θ₀ gate. That is its own kill condition 3, half met: the user kept full walks. **Killed.** Its derivation of times from a base is grafted below.

## Challenges for the human

1. **ε owed by the reported answer, not by every search evaluation** (A C1–C2; implicit in B's "54–72 ε-bearing"). R1's text says "the converged answer". OBJECTIVES does not say every run. **Ranking dependence: total.** Accepted, A wins at 128F on long drought. Refused, A dies and B leads at 212F.
2. **R4/R8: a companion per run, or a recorded estimate** (A C1, B 1, D C2). **Total dependence.** If a companion is required per run, A and B die, and C with a coarse gate leads at 303F on long drought.
3. **R0 "together"** (B 2, C 1). Fix the tolerance at `3e-5` with the window and search only the introductions; item 8's 100:1 node-to-time error supports this. No dependence: all four do it.
4. **The constant record's front: supplied by the caller or placed by a rule** (A C3, D C1, against B's and C's rules). B's and C's thresholds are unmeasured. If a rule is required, graft C's jump split onto the winner, predicted at 90M rows on constant against 40M by hand. The ranking on the pulsed records does not move.
5. **"Constant takes no pilot"** (C 2; dissolved by A, where the window is read from the first run). No dependence: it is 1.9% of rows on constant.
6. **R8's radius is unmeasured** (B 3). Every design reports a distance it cannot score. Measurement 4 below gives the radius.
7. **The ledger's R7 figure of 962 505 rows is stale** (a correction, not a challenge). Use 0.637M, or 0.373M as shipped.

## Names

- **A view type is warranted.** `species.h` forms a node and its next node by hand at five sites (311, 324, 355, 883, 923). It computes the width at four (313, 325, 335, 925) and the shares at three (312, 325, 335). The open interval (back, `new_node`) is formed three times. A and B counted three sites; D's five is right.
- **`BirthInterval`: pass.** **`Interval`: fail.** "interval" already names the walk's span (`node_schedule.h`), the disturbance interval (`parameters.h`) and odelia's interpolators' time intervals, so it does not say which axis.
- **`establishment_shares()`: pass.** **`shares()`: fail.** "Share" already means `share_left`, the soil's uptake share of 0.1, and an invader's share of J′.
- **`for_each_crown(visit)`: pass.** It continues the `for_each_*` visitor convention. **`crowns(visit)`: fail**, because it reads as a getter.
- **`top_powers`, for the field and the function: pass.** **`powers`: fail**, because it does not say powers of what. `n_moments` becomes `n_top_powers`.
- **`height_coefficients`: pass.** It frees "weights", which collides with establishment weights.
- **Kept:** `interval_establishment_moment` (a true first moment, unlike `mom`) and `crowns_per_interval`.
- **Phrases.** "Exact counts" becomes "establishment shares", and "crown spread" becomes "the interval's crowns". The noun "pilot" is deleted.
- **A's `next_introductions`: fail**, because it names the loop's position, not its content. With the graft it disappears: the climb is `halvings + 1`. **A's `answer` column: fail**; take D's `extrapolated`.
- **D's `edges`: fail.** It is a mesh word, and the objects are the base introductions. **`halvings`: pass.**
- **`walk_grid`, `build_grid`, `run_extrapolated`: pass.**

## Ranking and recommended design

1. **A, with grafts** (if challenges 1 and 2 are accepted).
2. **B** (1 refused, 2 accepted).
3. **C, with D's coarse gate** (2 refused).
4. **D: killed.**

**Commitment.** ε is owed by the reported answer. Every evaluation runs on one nested ladder: the search on the companion rung, the answer on the pair, extrapolated and checked.

**Kept true by:**
- `Parameters` carries the base introductions and `halvings`, and `introduction_times(base, halvings)` derives the times. A schedule that is not a nested bisection cannot be expressed.
- The search rung and `diagnose_scm`'s companions are `halvings − 1` and `halvings − 2` of the same base, so they cannot disagree with the run about which nodes they share.
- `refine_schedule()` keeps refusing the birth date, so no indicator places a node.
- Each search evaluation returns its rung and the grid's last verdict, labelled as such.

**Grafts:**
1. **From D: times from (base, halvings).** On a non-uniform caller base (constant's 150 times), A's index-halving merges cells h and 4h. Their error ratio is then 125/65 = 1.9, not 4, so the /3 estimate is wrong (R4 on constant). Cost: one name and one function, zero rows on uniform, and the answer on constant two halvings above the base.
2. **From C: the staged check.** The stand's ln J ratio over the three rungs comes from forwards first, and sweeps run only if it passes. It only fails fast: constant passes on J and fails on its gradients. On episodic it cuts A from 310F to 263F (R7). No new name.
3. **From D: the column name `extrapolated`.**
4. **Conditional, from C: the fine third rung in the answer's check,** if measurement 1 shows the coarse gate passing on episodic. It costs +29.8F on long drought, taking A to 158F, still the cheapest.

**Not grafted:**
- B's applied correction: its proxy drifts 30%, and R1 does not need it.
- D's thinning: no measured nested non-uniform lattice passes the gate.

**Price.**

| | long drought | episodic |
|---|---|---|
| this design | 128F = 48M rows at today's 0.373M | 321F = 74M |
| C, the cheapest per-run-companion design | – | 777F |

On long drought it costs 1.34 times today's failing path. The tolerance is chosen by a fixed rule. Constant needs the caller's base, or graft C's jump split.

## Kill-condition map

**B** wins when:
- every evaluation owes ε but may carry a recorded estimate;
- the elasticities' correction drifts under 30% across ±10% for the resident and ×0.5–×2 for invaders.

It costs 1.65 times A on long drought (212F against 128F).

**C** wins when:
- every evaluation must carry its own companion, and the workload is episodic-like;
- the (215, 429) pair certifies at u857.

Then it costs 777F against 1300F for the lattice. With D's coarse gate it costs 303F on long drought.

**D** wins when two or more non-uniform schedules ship, each passing the ratio gate on the spread:
- rule A's dyadic thinning (worth about 4%, 11F an analysis);
- constant's halved base.

**A dies** when either of these happens:
- the human refuses challenge 1 or 2;
- the u108 search needs more continuation candidates on the pair than the margin allows: more than 2 on long drought (about 19F each), more than 5.6 on episodic (about 82F each), where 5.6 = (777 − 321)/82.

## Measurements that settle it

Rows are given at share 0, then at today's `control_tf24` setting.

1. **The coarse (54, 108, 215) gate on episodic and dry.** u54 gradient runs, reusing the node-rule u108 and u215 runs: 2.9M (1.7M). It settles A's and B's episodic exposure, D's kill condition 1, and whether C's fine gate is worth +73F per analysis on long drought.
2. **Episodic gradients at u857, stand and invader:** 25.6M (14.2M). It settles every design's episodic rung, and whether C's (215, 429) pair is honest.
3. **A's steering error.** The u108-versus-pair selection gradient at θ₀, divided by −91, gives the shift in the singular point. It costs 0 rows if the node-axis RDS under `$DEV/pf_nodes` survive, else 13.6M (8.0M). A full u108 search, then the pair at its θ*, costs 67M (39M). It settles A's continuation count.
4. **Drift of a recorded correction across θ:** B's protocol, with resident `lma` and `hmat` at ×0.95 and ×1.1, and invaders at ×0.5 and ×2, at u108 and u215. 81M (47M). It settles B against A, and gives R8's radius for every design.
5. **The quarter-spacing nudge on long drought at u108, unmeasured there:** 8.9M (5.2M). It matters only if search runs owe R2.
6. **Constant's base halved twice (Gbf16 × 1, 2, 4), with gradients:** about 8.8M. It settles whether graft 1 buys R4 on constant, and challenge 4.
