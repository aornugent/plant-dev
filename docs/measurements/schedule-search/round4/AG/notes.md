# AG: P's edge mechanism and inset rule under the averaged establishment gate (round 4)

Question: P found on lib19 (instantaneous gate) that a node at an establishment edge is
itself the main error source, and that insetting each spell's outermost nodes ~12 d
cuts dry's error in half. Does the mechanism, and the rule, hold under the averaged gate
(`b3a33626`, window 0.05 yr), and what rule holds under both?

Scripts beside this file; runs, schedules and the build under
`scratchpad/dev/schedtest/AG_out/`; the port's worktree `AG_src/plant`; the lib
`adjmap/libAG`.

## 1. The port (scratch build, not pushed, on no issue branch)

Worktree `AG_src/plant`, detached at `fa9afe76` (lib19's plant), `git cherry-pick -x
b3a33626` → local commit `61b0b3fe`. `6613dd24` (the recaptured whole-run reference) not
taken: it touches only a test data file captured on the gate's own base, and the stack's
references were re-blessed for exact counts and the crown spread, so it would not apply.

The stack (PLANT-93..110) carries rebased equivalents of all 13 commits the gate sits on
(`e77f3859`..`bb1d8a8a` ↔ `61af9238`..`4f8d9ad5`), so the conflicts are only with what
the stack added since: exact counts on the birth-date coordinate (`bae2dd9a`), the field
build that skips the newborn's rates (`df844b46`), the storage offset and roundoff
versions, splits, the soil subsystem.

Conflicts and resolutions (code):

1. `tf24_strategy.h` scientific_version: stack is at v13 (storage offset v12, roundoff
   v13); the gate becomes **v14** (TF24f v14.1).
2. `node.h`: the gate splits `compute_initial_conditions` into `compute_rates_at_birth`
   + `seat_at_birth(…, pr_estab)`; the stack added the birth-date branch
   (`set_birth_density`, no pr_estab) inside it. Merged: `seat_at_birth` holds the
   stack's body, its height branch seats mortality/density at the passed pr_estab
   instead of re-reading the instant gate. Birth-date branch unchanged.
3. `species.h`, the substantive one. On the stack's birth-date path pr_estab enters only
   as the newest node's interval-establishment rate (`set_interval_establishment_rate`
   in `compute_boundary_rates`); the gate's design seats the boundary node at E. The
   faithful translation: **the newest interval's exact integral integrates E, not g**
   (`newborn_establishment()` returns E for an EstablishesOverWindow strategy, g
   otherwise), and E's rate `(g − E)/window` is set in `compute_boundary_rates`, where
   the newborn is evaluated in the whole field (the gate put it in
   `compute_boundary_node`, which the stack now uses only for the field build). The field
   build (`compute_boundary_node`) keeps the stack's birth-date shortcut and seeds the
   height path at E.
4. `species.h` `start_establishment_window`: the gate read the boundary node's last
   evaluation; the stack's field build no longer computes the newborn's rates on the
   birth-date path, so the aux it would read is stale. It now evaluates the newborn's
   rates itself (`individual.compute_rates`) before reading the gate.
5. `patch.h` `node_ode_size`: the gate summed `n * node_type::ode_size()` (static on its
   base); on the stack a node's size depends on the coordinate, so it is each species'
   `ode_size()` less `window_size`.
6. `patch.h` `ode_state_valid`: stack's loop by node `ode_size()` kept, plus a skip of
   `window_size` after each species.
7. `patch.h` splits (not in the gate; the stack's): `split_sign_changes` and
   `take_recorded_splits` advanced `first` by node widths only; now past each species'
   E entry too (no effect with one species; kept so the layout is right).
8. `scm.h` census sweep: the gate's transposition of the first state's E seating
   called `set_state_and_boundary`, which the stack folded into `set_ode_state`
   (which builds the field); renamed.
9. `R/scm_support.R` `make_initial_state`: stack's birth-date branch kept, species' own
   entries appended per chunk as the gate does. `R/RcppR6.R`: stack's hash. NEWS: gate's
   entry above the stack's, versions renamed.

Tests: `_snaps/model-version.md`, `helper-gradient-ladder.R`, `test-census.R`,
`test-gradient-ladder-introductions.R`: stack's side taken (the gate's hunks there are
about the height-coordinate boundary density seated at E, which the stack's birth-date
tests no longer read); fixed afterwards only where the new state's layout fails them.
`test-patch.R`: stack's `cmp$ode_size` plus the gate's `beside_size`.

Known approximation (not in the gate, which predates splits): when the newest node
splits, its substeps hold E at the value the step's last evaluation left rather than
E at the substep's instant. Measured below how often the newest node splits.

Not ported / not checked: invaders' walks (residents only here).

## Pre-registrations

- V1 (build + tests): the gate's own test file passes after adapting its height-path
  seeding test to the birth-date coordinate; test-patch / test-species / test-census /
  introductions pass or fail only on the snapshot (version + new parameter); FF16 guard
  bit for bit (FF16 compiles the old path: `window_size` 0, no extra rate).
- V2 (forward, dry, a09 c schedule on libAG): E's 10–90% rise at openings has median
  ≈ 40 d (w ln 9 = 40.1 d for a step in g held constant), against the instant gate's
  sub-day; ln J moves by about +1% (the commit: +1.26% converged on long drought).

## 0. Offline preview (no run): lib19's pilot gate g(t) filtered on w = 0.05 yr

`filter.R`: E from the pilot's creation record by the exact solution per step. Between
b1 and 25:

| case | ∫E vs ∫g | E inside g's gaps | g edges → E edges (rate > 0.01) | g gaps E never leaves (E > 0.01 throughout) | E at closing edges (g 1 d before) |
|---|---|---|---|---|---|
| dry | −0.1% | 6% | 96 → 10 | 43 of 48 (median gap 25 d) | 0.84 (0.51) |
| episodic | 0.0% | 5% | 60 → 20 | 20 of 30 (44 d) | 0.89 (0.51) |
| episodic-lma | −0.1% | 4% | 44 → 10 | 17 of 22 (57 d) | 0.88 (0.55) |
| long drought | 0.0% | 7% | 106 → 6 | 50 of 53 (16 d) | 0.88 (0.64) |

So under the gate the establishment weight is continuous with kinks (E′ jumps by Δg/w at
each g-edge); its maximum sits AT each closing edge (g falls through a spell as the soil
dries, E lags it) and decays over ~18 d into the gap. The weight is now densest exactly
where P measured the fate curving most (closing edges, both sides). A pilot on libAG
with P's threshold keeps only the long dry seasons as edges.

Consequences predicted before any run (H_gate):
- The fate profile near g-edges is a property of the weather after birth, not of the
  gate, so P's layer (ln nrr +0.03 over a spell's last 10 d, +0.065 over a gap's first
  10 d) should reappear nearly unchanged on libAG.
- What changes is the weight: a gap interval now carries 4–7% of all establishment, born
  where the fate moves fastest. P's inset rule (gap = one interval between nodes 12 d
  inside each spell) spans that tail with one hat; out10 (a node 10 d into the gap),
  which P found harmful, should now help or be neutral at closing edges.

### V1 result (build + tests): holds

Built `-O2`, 2 jobs, into `adjmap/libAG` (lib19 copied; odelia 0.5.0 and phylloptim 0.9.3
unchanged; DESCRIPTION's LinkingTo phylloptim set to 0.9.3 for the build only, restored).
Serial, against the installed libAG (`AG_out/tests.R`):

- `test-tf24-establishment-window.R` 6/6 pass after two test-only adaptations: (a) the
  layout test took the node size from a height-coordinate `Node` (8) while its patch is
  on the birth-date coordinate (9); now read off the patch's own newborn. (b) "a node is
  seeded at the average": on the birth-date path there is no `log_density` and mortality
  starts at 0, so it now checks what the port does there — at every recorded state the
  newest interval's establishment rate equals the state's E, to 1e-14 (and E ranges
  < 0.1 to > 0.99). **The window column against a whole-run central difference and the
  forward tangent passes unchanged** (the first-state transposition works on the stack).
- `test-patch.R` 21/21, `test-species.R` 21/21, `test-census.R` 10/10,
  `test-gradient-ladder-introductions.R` 13/13 (stack's version plus the gate's layout
  hunk for a newcomer pushed between a species' nodes and its E; the gate's hunks about a
  boundary density seated at E were height-path content and are not taken),
  `-recruit` 3/3, `-first-range` 3/3, `test-model-version.R` 8 (4 snapshot skips).
- `test-strategy-tf24.R` 19/19, `test-strategy-tf24f.R` 11/11 (both touched by the gate).
- FF16 guard: `test-strategy-ff16.R` and the reference comparison pass; and **bit for
  bit**: a two-species FF16 SCM on both coordinates gives `identical()` offspring
  production, ode_times and final state on lib19 and libAG (`ff16bit.R`).

Harness: `adj_run.R`'s `per_node()` reshapes `species$ode_state` assuming nodes only and
fails on libAG after the run; my copy `AG_out/ag_run.R` reads the nodes' share (and
records E(t) with `EREC=1`). The first AG_a09c_dry attempt died there (forward done,
1.5 min, counted against the budget).

## 2–3. Pre-registrations: references and the mechanism under the gate (dry first)

Runs on libAG, a09's committed dry schedule (`AG_a09c_dry`, TOL 1e-4) and P's own variant
schedules (`P_out/sched/{in10,out10,mid,in3}_dry.rds`, identical node sets to P's lib19
runs), against the libAG reference (u215, u429 at TOL 3e-5, extrapolated). M is P's lib19
in10 move on dry (the hydraulic direction: a_l1, root_P50, omega, root_c, stem_c,
storage_relaxation_offset, ln J).

- G0 (references): the libAG reference's own estimate (u215→u429 move/3) is ≤ 0.3ε on
  dry, as lib19's; ln J of u429 is 0.5–1.5% above lib19's (commit: +1.26% converged on
  long drought).
- G1 (fate, `layer.R` on AG_a09c/AG_in10/AG_out10): the per-recruit fate near g-edges is
  set by the weather after birth, not the gate: closing edges ln nrr edge − 10 d inside
  +0.03 ± 0.01, 10 d into the gap − edge +0.065 ± 0.02 (lib19 +0.032, +0.065).
- G2 (a09 c dry on libAG): the edge-node bias is partly cancelled. On the spell side the
  hat over-reads (anchored at the high edge value, as on lib19); on the gap side the tail
  (E ≈ 0.84 at the edge, decaying over 18 d, 6% of all establishment) is read by a hat
  from the edge to the next spell's node, which under-reads its rising fate. Predict the
  a09 c error projects on −M at 0.3–0.9 (lib19 1.22) and worst error ≤ 0.94 (60%).
- G3 (in10 on libAG): still moves along M (corr with lib19's M > 0.7), but helps less:
  the inset node now also anchors the gap-tail hat lower. Worst error ≥ 0.5 (lib19 0.36);
  rms not below 0.2 (55%).
- G4 (out10 on libAG): a node 10 d into the gap now represents establishing recruits (the
  tail), so out10 is no longer harmful: rms error ≤ the base's + 0.02 (lib19: +0.04)
  (55%).

### V2 result (forward, AG_a09c_dry): holds

`opening.R`: over the 25 openings into spells longer than 60 d, E's 10–90% rise has median
**35.5 d** (30.7–42.2) against the instant gate's 0.08 d (commit: 0.058 → 39.8 d on its
stand; the step-response value is w ln 9 = 40.1 d, shorter here because g itself sags as
the spell's soil dries). E on libAG tracks the offline filter of lib19's pilot g to rms
0.009 (corr 0.9997). J 1.19095 → 1.21479 (**+2.0%**, ln J +0.0198 = 0.79ε) on the same
schedule; steps 5585 → 5448, rows 591k → 581k; CPU 330 → 382 s (load differs).

Held-E bound (`edgesteps.R`, AG_a09c_dry): splits happen where a young node's net
production changes sign, i.e. at g-edges, where the controller already takes short
steps: the step containing a g-edge is median 0.47 d (90% 2.0 d, max 2.6 d), E changes
over it by median 0.009 (max 0.11), so holding E costs at most ~dE·h/2 ≈ 2e-3 d of
establishment per edge (worst 0.15 d) against ~10 d per spell. Negligible except at a
worst-case edge, and only if the newest node is the one split there.

### First mechanism number (no reference needed): in10's move is gate-independent

`moves.R dry`: AG_in10_dry − AG_a09c_dry on libAG against P_in10_dry − val_a09_c_dry on
lib19: max 0.69 vs 0.66, rms 0.206 vs 0.217, ln J +0.120 vs +0.146; **projection 0.91,
corr 0.96**. Same quantities, same signs (storage_relaxation_offset +, root_P50 −, a_l1 −,
stem_c −, root_c +, omega +). Moving each g-edge node 10 d into its spell does the same
thing under both gates: the averaged gate's tail into the gap (6% of establishment) does
not change what the spell-end interval's hat does. (My back-of-envelope in G2/G3, that
the tail's under-read would oppose it, is not borne out at this order.)

### G1 result (fate layer, `layer.R dry AG_a09c AG_in10 AG_out10`): holds

Closing edges: ln nrr edge − 10 d inside **+0.032** (lib19 +0.032), base hat at 10 d
inside − truth +0.023 (+0.023), 10 d into gap − edge **+0.062** (+0.065). Opening edges
+0.020 / −0.008 / −0.009 (+0.020 / −0.008 / −0.007). The per-recruit fate near g-edges is
the weather's, identical under both gates.

out10 move on libAG (`moves.R`): rms 0.190 (lib19 0.115), ln J −0.052 (+0.030), a_l1 +0.57
(−0.04), omega −0.53 (−0.35), root_P50 +0.46, stem_c +0.35; larger than on lib19 and
roughly opposite to in10. The node 10 d into the gap now carries the tail's weight.

### G0, G2–G4 results (dry, libAG reference)

`cmp.R dry AG_a09c_dry AG_in10_dry AG_out10_dry`. Reference own estimate (u215→u429
move/3) max **0.13ε** (G0 holds); window elasticity 0.0099 (a09 c reads it within 0.11 of
its 0.01 floor ε). u429 ln J is +0.0182 (0.73ε) above the lib19-era u429; elasticities
move up to 2.6ε (root_P50), rms 0.65ε: **the gate changes the answer by more than ε, so
lib19 references cannot score libAG runs.**

| run (libAG, dry) | worst error | rms | ln J err | error projected on −M19 | move proj. on M19 (corr) |
|---|---|---|---|---|---|
| a09 c (edge nodes) | 0.66 (a_l1) | 0.225 | −0.267 | **0.86** (lib19 1.22) | — |
| in10 | 0.51 (storage_relaxation_offset) | 0.169 | −0.147 | **−0.05** | 0.91 (0.96) |
| out10 | 1.23 (a_l1) | 0.400 | −0.319 | 1.69 | −0.83 (−0.94) |

- G2 holds (projection 0.86 within 0.3–0.9; worst 0.66 ≤ 0.94): the edge-node bias is
  there, ~70% of lib19's size. Lib19's base was −1.22 M + rms 0.145.
- G3 mixed: worst 0.51 (≥ 0.5 as predicted), but rms 0.169 (predicted ≥ 0.2: refuted);
  in10 lands at the error-free point along M almost exactly (−0.05), i.e. the
  error-free inset on libAG is ≈ 10 d (p(10) = 0.91 ≈ 0.86), against ≈ 12–15 d on lib19
  (p ≈ 1.22). Residual after in10: storage_relaxation_offset +0.51, stem_c −0.35.
- G4 refuted: a node 10 d into the gap is still harmful, more so than on lib19 (rms
  0.225 → 0.400; lib19 0.302 → 0.338). The tail's recruits are better represented by
  the edge node's hat than by a node in the gap's steep fate.

Mechanism verdict on dry: **the same mechanism, ~70% of the size**. The averaged gate
moves no establishment out of the spell end, it adds a tail after it; the spell-end
hat anchored at the high fate value at the edge still over-reads.

Edges (`gedges.R`): g recovered from the libAG E record exactly per step,
g = (E1 − E0 q)/(1 − q), q = e^(−h/w), has **96 edges, the lib19 pilot's 96** (median
offset 0.00 d, 90% < 1 d, one at 6.7 d). E itself crosses 0.01 at only 10. So the
edges this mechanism needs are the fate's, i.e. the rain's: they are g's, the same
under both gates. A libAG pilot must report g (directly or inverted from E), not E's
threshold crossings; with g, a lib19 pilot and a libAG pilot give the same edges and the
pilot needs no change.

## 4. Pre-registration: the rule as a pair under the gate

Rule (P's `inset_rule`, unchanged): edges are the instant gate's g-edges (the same on
lib19 and libAG, above); each spell's outermost nodes 12 d inside it; a spell under 25 d
one centre node; everything else a09's. Runs: P's own schedules `insc_`/`insf_<case>`
(same node sets as P's lib19 pairs) on libAG, against a09's pair on libAG, scored as
loc/val.R scores (`AG/val.R`: ALG a09_late shrink from the pilot proxy, R = 1.6,
libAG references). On lib19 (P, `sum_ins.R`): dry worst 0.94 → 0.34, long drought
0.57 → 0.37, episodic-lma (commits fine) 0.41 → 0.45, all pass.

- R1 (dry ins c on libAG): 12 d is just past libAG's error-free inset (~10 d), so the
  error projects on −M19 at −0.1 to −0.3; worst ≤ 0.55, rms ≤ 0.19.
- R2 (pairs on dry, long drought, episodic-lma): the inset pair passes C1–C5 on all
  three on libAG, with the same commit decision as a09's libAG pair; worst error ≤ a09's
  on dry and long drought; T (rows) 5–12% under a09's libAG pair, as on lib19.
- R3 (a09 pairs on libAG): pass on all three; their committed worst errors are below
  lib19's (the bias is ~70% the size).

### mid on libAG dry (P's mid_dry schedule, 122 nodes): the best layout under the gate

`cmp.R dry AG_a09c_dry AG_mid_dry`: **worst 0.30 (root_P50), rms 0.100, ln J +0.02**
(a09 c 0.66 / 0.225 / −0.27; in10 0.51 / 0.169); rows 581k → 421k (−28%), CPU −24%. Its
move projects on M19 at only 0.59 (corr 0.75); against P's lib19 mid move, 0.38 (corr
0.84): lib19 mid moved ln J +0.53 and overshot (worst 0.60, −0.46 M), libAG mid moves ln
J +0.29 and lands near the truth (error on −M19 +0.27, i.e. slightly short).

Why (hypothesis H_cont, consistent with the numbers but not separately tested): mid's
overshoot on lib19 is the strip between the inset node and the edge, read with the gap
interval's hat, which on lib19 holds establishment only in that strip (lopsided, the
crown spread smearing it over the whole interval). Under the gate establishment runs on
through short gaps (E > 0.01 through 43 of 48 of dry's gaps), so the gap interval holds
establishment at both ends and through the middle, and a hat across it is a fair reading.
The first-order term that made mid's pair misread on lib19 should shrink with it.

- P_AG1 (mid pair on libAG dry, AG_midf_dry = P's midf2 schedule): the mid check's error
  projects on −M19 within 0.2 of the mid c's (+0.27), so the pair reads little of it;
  passes C1–C5 coarse, est worst ≤ 0.5; T 25–30% under a09's libAG pair (60%).

H_cont, offline (`lopsided.R dry`, b1–25; establishment's mean position u in its
interval; "lopsided" = |u − ½| > ¼):

| layout | n | g: lopsided share | g: mean abs(u − ½) | E: lopsided share | E: mean abs(u − ½) |
|---|---|---|---|---|---|
| a09 c | 141 | 0.000 | 0.006 | 0.027 | 0.031 |
| in10 | 140 | 0.011 | 0.010 | 0.017 | 0.027 |
| ins (12 d) | 120 | 0.014 | 0.012 | 0.018 | 0.027 |
| mid | 94 | 0.038 | 0.034 | **0.012** | 0.032 |
| out10 | 141 | 0.001 | 0.032 | 0.004 | 0.037 |

Partial support only: mid's lopsided share falls 3× under E, but the mean offset does
not change; and under E every layout carries ~3% lopsided establishment (a09's gap
intervals now hold the tail beside the edge node). Not a sufficient explanation of mid's
improvement; left as a hypothesis.

### Long drought (libAG, proper setting)

Reference own estimate 0.14ε. AG_a09c_long-drought: J 12.7024 → 12.8602 (**+1.24%**; the
commit reports +1.26% converged on this stand), E opening 10–90% median 35.0 d (instant
0.08 d), E against the filtered lib19 pilot rms 0.007; g-edges from E: 106 of the
pilot's 106 (median 0.00 d, one at 4.8 d). a09 c error: worst 0.55 (a_l1), rms 0.180,
ln J −0.116 (lib19: 0.57 / 0.172).

### Episodic-lma (libAG)

Reference (u215, u429) own estimate **0.32ε**, looser than dry's and long drought's
(0.13, 0.14): errors under ~0.3ε on this case are within the reference's own error.
AG_a09c_episodic-lma: worst 1.40 (TF24_cost_scale), rms 0.737, ln J −0.373 (lib19 c 1.29
/ 0.690): a09 commits fine there under both gates. Its committed error is not the edge
mechanism (P's inset c on lib19 is 1.24 / 0.655 too).

Not run: the episodic references (u215/u429). The budget went to the rule pairs; no
episodic run uses them.

### R1/R2 result on dry: the 12 d inset pair FAILS C3 under the gate

`val.R dry` (libAG): AG_insc_dry / AG_insf_dry (P's insc/insf schedules, 149/212 nodes):
commits coarse, **worst 0.47 (storage_relaxation_offset), rms 0.140** (a09 c 0.66 /
0.225), C1 C2 C5 pass, **C3 fails: 2 of 9 read** (misses lma, a_l1,
storage_relaxation_offset, k_I, TF24_cost_scale, jmax_25, R_d_25), read median 1.85,
corr(est, err) 0.79. T 1090 (rows model).

Along M: c −0.07 (the committed run sits at the error-free point, R1 holds: worst ≤ 0.55,
rms ≤ 0.19, projection in −0.1..−0.3 just missed), **f −0.31**. On lib19 the same pair
read c +0.14, f −0.05. The 12 d inset over-corrects the check more than the committed
run under the gate, so c − f carries ~+0.24 along M that c's error does not: every
quantity on M is over-read (estimate ~2× error). The failure is on the safe side (the
estimate over-states), but it is a C3 failure and the pair's estimate is not predictive.

Mechanism of the failure (hypothesis H_scale, to check against a09 f on libAG): the
inset's correction and the edge bias it cancels scale differently with the spacing under
the two gates. A fixed d that cancels the bias at one spacing leaves residuals of
opposite sign at c and f unless d is at the error-free point of BOTH spacings; under
lib19 12 d was (c +0.14, f −0.05), under the gate (optimum ≈ 10 d at c's spacing) it is
not.

### R3 result on dry: a09's own pair also FAILS C3 under the gate

`val.R dry`: AG_a09c_dry / AG_a09f_dry: commits coarse, worst 0.66, C1 C2 C5 pass, **C3 5 of
8** (misses a_dG1, a_dG2, root_P50), read 0.89, corr(est, err) 0.80. Along M: c 0.86,
**f 0.62, a ratio 1.39** where lib19's was 1.22 / 0.56 = 2.18 (second order). Under the
gate part of the edge bias does not shrink when the check refines.

H_tail: that part lives in the intervals that span a g-gap. `gaps.R`: in a09's c and f
they are **identical** (dry 48 of 48, long drought 53/53, episodic-lma 22/22: the check
never refines a shut gap). On the instant gate they hold no establishment; under the
gate they hold the tail, **6.0% (dry), 6.4% (long drought), 4.2% (episodic-lma) of all
establishment** (P's inset: 14–17%), born where the fate is steepest. Their error is the
same in c and f, so the pair cannot read it. Splitting the dry bias on M as X (shared) +
Y (second order, c/f 2.18): X ≈ 0.42, Y ≈ 0.44.

Candidate rule for both gates (R_both): a09's layout (edge nodes at the g-edges, which
both gates share) and **a check that refines every interval carrying establishment on
the model's own weight**, gap-spanning ones included (here: bisected). On lib19 those
intervals carry none, so R_both is a09 there (10 of 10 pass, measured); it needs no
lib19 run.

Plan change: the inset pair on episodic-lma (2 runs) is dropped (the inset already fails
under the gate on dry); the mid check on dry moves to last, as a spare.

- T1 (AG_a09fg_<case>: a09 f + each gap-spanning interval bisected; `mkgap.R`; dry
  232 → 280 nodes, long drought 233 → 286, episodic-lma 182 → 204), paired with
  AG_a09c_<case>, s from the pilot proxy as a09 scores: on dry the check's error on −M19
  falls from 0.62 to ≤ 0.45 and the pair passes C1–C5 with read median 0.8–1.25. On long
  drought the pair passes (whatever a09f's libAG pair does). On episodic-lma it commits
  fine and passes, as a09's. Refuted if dry's check error on −M19 stays ≥ 0.55 (the
  unread part is elsewhere).
- T2: T rises by the check's extra rows only: dry +6–9% over a09's libAG pair.

### R2 on long drought: the inset pair passes under the gate

AG_insc/insf_long-drought: commits coarse, **pass**, worst 0.28 (storage_relaxation_offset),
rms 0.103 (a09 c 0.55 / 0.180), C3 vacuous (nothing over ε/3), read 1.07, corr 0.91;
T 1291 (rows). lib19: pass, 0.37 / 0.113. Long drought's gaps are short (median 16 d)
and its a09 bias small, so the shared tail stays under ε/3.

### T1 result (dry): refuted

AG_a09c_dry / AG_a09fg_dry (check + 48 gap bisections, 280 nodes): commits coarse, C3
still 5 of 8 (misses a_l1, a_dG1, root_P50), read 0.80; the check's error on −M19
0.62 → **0.67** (predicted ≤ 0.45). Refining the gap-spanning intervals in the check does
not reach the part of the error c and f share. T 1309 (+7%).

### Where the libAG pairs lose the edge term (`misread.R`, `refM.R`, dry)

Split along unit M (P's lib19 in10 move) and off it: off M the libAG a09 pair shrinks at
second order (c/f rms 2.19; lib19 2.01) and reads well. Along M it does not:

| along unit M, from u429 (ε) | lib19 | libAG |
|---|---|---|
| u215 | −0.75 | −0.99 |
| extrapolated reference | +0.25 | +0.33 |
| a09 c / f | −1.56 / −0.58 | −0.95 / −0.59 |
| inset c / f | +0.04 / +0.32 | +0.44 / +0.78 |
| inset's correction I = ins − a09, c / f | 1.60 / 0.90 | **1.39 / 1.37** |
| mid c | +0.93 | −0.08 |

On lib19 the edge bias and the inset's correction both shrink when the check refines
(c/f 2.2 and 1.8): they live in the spell-end interval, whose length the check halves.
Under the gate the a09 bias shrinks only 0.36 between c and f, and the inset's
correction **not at all**: the edge term has moved into something c and f share. That
explains both C3 failures: a09's pair reads half its M part (est 0.62 of 1.28); the
inset's pair reads its check's overshoot as an error of c.

Two candidates for the shared part: (a) the gap-spanning intervals (identical in c and
f), but bisecting them (T1) did not move it; (b) the reference: if uniform schedules
converge along M more slowly than second order under the gate, the extrapolation sits
in the wrong place along M and both runs share that offset.

- P_ref (AG_ref_dry_u857, TOL 3e-5): along M from u429, u857 lands at +0.15..+0.35
  (second order from u215's −0.99), and the u429/u857 reference within 0.15 of the
  u215/u429 one (+0.33): the reference is sound and the shared part is the runs' (60%).
  If u857 lands beyond +0.5 the uniform ladder converges at first order along M under
  the gate and the reference, not the schedules, holds the shared part.

Plan: a09fg long drought (already launched) finishes; the mid check on dry is dropped;
u857 dry and a09's check on episodic-lma run last.

### R3 on long drought: a09's pair passes under the gate

AG_a09c/a09f_long-drought: coarse, **pass**, worst 0.55, rms 0.180, C3 4 of 4, read 1.03,
corr 0.96; T 1390. The inset pair (above) passes too, T 1291 (−7%). So far the gate's
failures are dry's, the case with the most and longest-lived edges (96 edges, median
gap 25 d; long drought's median gap is 16 d).

T1 on long drought: AG_a09fg (286 nodes) pairs pass as a09's does; check rms 0.088 → 0.078,
corr(est, err) 0.96 → 0.99, T 1390 → 1499 (+8%). Marginal; not a fix.

### R3 on episodic-lma: a09's pair passes under the gate

AG_a09c/a09f_episodic-lma: commits **fine**, pass, worst 0.45 (vcmax_25), C3 19 of 19,
read 1.16, corr 1.00; T 744 (lib19: fine, pass, 0.41, 20/20, T 755). This case's
committed error is not the edge term, under either gate.

`need.R` (dry, along unit M, reference = u215/u429 extrapolated): what the edge bias
needs cancelled (reference − a09 run) against what an inset delivers (inset run − a09
run at the same spacing):

| | need c | need f | c/f | in3 c | in10 c | ins12 c | ins12 f | ins12 c/f |
|---|---|---|---|---|---|---|---|---|
| lib19 | 1.81 | 0.83 | 2.18 | 0.37 | 1.49 | 1.61 | 0.90 | 1.78 |
| libAG | 1.28 | 0.92 | 1.39 | — | 1.35 | 1.38 | **1.38** | **1.01** |

On lib19 a fixed 12 d inset delivers nearly what each spacing needs (both shrink ~2×),
so c and f are both left near zero along M and the pair reads the rest. Under the gate
the same inset delivers the same 1.38 at both spacings while the need falls 1.28 → 0.92:
c is cancelled (−0.10), f over-cancelled (−0.46), and c − f reads a phantom.

### P_ref result (AG_ref_dry_u857): holds; the reference is sound

`ladder.R`: along unit M the uniform ladder moves +0.988 (u215 → u429) then +0.173 (u429 →
u857), ratio **5.7** (second order or better); off M rms 0.129 → 0.048 (2.7); ln J +0.059
→ +0.038 (1.55). ref(u429, u857) − ref(u215, u429): **−0.10 along M**, rms 0.053, max 0.16
(TF24_cost_scale); its own estimate 0.04ε. Rescored on ref(u429, u857)
(`AGREF=429_857 val.R dry`): a09 pair worst 0.78, C3 5/8 (fail); inset pair worst 0.61,
C2 and C3 fail (3/9); a09fg C3 5/8 (fail); mid c worst 0.38, rms 0.120 (still the most
accurate committed run). Same verdicts. Under the gate a uniform ladder (nodes anywhere,
gaps refined with everything else) converges along M at second order; a09's edge-anchored
c → f converges there at first order (1.39). The shared part is the schedules', not
the reference's.

## Last run: the mid pair under the gate (P_AG1, restated)

mid is the spacing-proportional extreme (outer nodes h′/2 inside; P's midf2 schedule for
the check), the fixed inset the other. Along M (ref u215/u429): mid c −0.08 (ref +0.33,
so under-corrected by 0.41; lib19 mid over-corrected by 0.68).

- P_AG1′ (AG_midf_dry): mid's correction scales with h, so the check delivers less than
  c does: mid f along M between −0.4 and −0.1, both runs on the same (under-corrected) side
  of the reference. Its committed errors are small (worst 0.30–0.38), so C3 has few
  quantities over ε/3: the pair passes C1–C5, commits coarse, T ≈ 900 (a09's libAG pair
  1220, −25%) (60%). Refuted if the check lands beyond the reference (over-corrected) and
  C3 fails, as the fixed inset's did.
