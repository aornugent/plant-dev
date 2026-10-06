# The clean sheet: the blind agent's report

An agent given `requirement.md` and the base commits (odelia `a62e97c`, plant
`4555ea13`), never the diff, sketched the least code that meets it. Its report,
as returned:

Clean sheet, sketched against base odelia a62e97c and plant 4555ea13. The idea: after the five stages, each crossing node's block is integrated again in pieces using the step's tableau. Each break sits where the evaluation that starts the next piece reads P = 0. The field is interpolated through the step's own stage reads. The row keeps the breaks, their slopes and the leaf points. A walk in a recorded field holds the breaks; the sweep moves them by the implicit function theorem (IFT).

1. Parts. odelia (says block/piece, never node; R12):
- ode_interface.hpp: add split_values_t<System> (empty by default, like solved_values_t :176-185) and solved_row::split (:224-228). The record then travels on the existing scratch->row->seed path (ode_solver_internal.hpp:206,:316; ode_solver.hpp:217).
  New concept SplitsSteps<System>: readings(std::vector<S>&) and split_step(split_view&).
- ode_step.hpp: stage_state/step_end take any block length and a scalar h (today they use `size` and a double h, :170-208). New on Step:
  stage_weights(u): Lagrange weights over the abscissae {0, ah} (:265), exactly 0/1 at them. This is the dense output of per-stage values.
  piece(x, k1, u_a, u_b, rates, x_b, err): one tableau step of a block over [u_a,u_b] of the step, through rates(i, u_i, x_i, out).
  locate(g, a, b): a bracketed root to full precision. sign_changes(v[6]): roots in (0,1) of the stage interpolant.
  step() takes reads after each stage and after the end evaluation, forms yerr first, writes step_end into ytmp, calls split_step, swaps, then
  evaluates the end (:131-144). whole_step (:242-257) takes reads after k1 and each stage, then calls split_step on the active System.
- ode_solver_internal.hpp: readings_in travels with dydt_in (:294,:762,:770); push_step moves `split` onto every row; new rows().
plant:
- Control::split_crossings = false. SplitsCrossings<T> := same_as<T, TF24_Strategy<value_type>> gates Patch's two new members; TF24f is
  another type, so it never qualifies. Setting the flag on any other model is refused.
- Patch::readings: environment.cohort_reads (light knots + layer psi, tf24_environment.h:271-296), then each node's P (tf24_strategy.h:1916).
- Patch::split_step owns which nodes, their field sum_j w_j(u) R_j, the pieces, the write-back of the block and its summed piece error, and the record.
  A node in a field: scratch environment set_cohort_reads, time t+u*h; scratch node set_ode_state -> compute_rates -> ode_rates
  (node.h:260-265,:410), inside a solved_scope on its strategy (ode_interface.hpp:457). Block = the node's leading state_size+1 components
  (+log_density on the height coordinate). The newest node's establishment pair comes from the newborn (species.h:819-823) and stays unsplit.
- SCM::split_counts(): per species x node, the number of accepted rows whose `split` names it.

2. Record. solved_row::split = vector<node_split<leaf_solved_points::points>>, one type at every scalar (as at patch.h:293-297). Per split node:
- species, node: indices at that row's width.  places: breaks u_r in (0,1), ascending, as fractions of the row's step.
- slopes: dG_r/du at each break, with drivers and leaf points held. This is the IFT denominator.
- solved: leaf points (tf24_strategy.h:488-495) of each evaluation, in order: per piece its 5 stages, then the evaluation at its break.
Not recorded: piece fields (interpolated again from the recorded stage `field`s in a walk, rebuilt on the tape in a sweep), P reads,
piece states, counts, and whether the row replays or is its own (that is the slot's field != nullptr test, patch.h:983-986).

3. A step that holds a sign change.
- Forward (also pinned and tangent replays, which build their own field): candidates are nodes whose six P reads lie within their spread of zero.
  G_r(u) := the node's P at the start of the next piece, after a tableau piece from break r-1 to u. Split iff G(0)G(1) < 0
  (G(1) is P at the unsplit end: one evaluation), or a dip from sign_changes is confirmed by G at its midpoint.
  u_r = locate(G_r), run on a scratch copy of the strategy. G_r(u_r) is then re-run on the species' own strategy: its end state and rates
  start the next piece, and its points are stored. The slope comes from a central difference. Then the last piece runs; block and error
  replace end/yerr, and the end evaluation runs at the treated state. Breaks enter as implicit_value<S>(u_r, slope, G_r) (implicit_node.hpp:164-198).
- Walk in the recorded field (invasion): nothing is located. Each entry's node (same species and node index; skipped if absent) is
  integrated in pieces at the recorded places, in the interpolant of the walk's stage reads. Those reads are the recorded fields to every digit
  (patch.h:996-997, resource_spline.h:148-150). Its leaf points are solved again into its own row.
  J' = J: identical traits and schedule give the same x0, k1 block, reads and places, and the species' strategy sees the forward's
  sequence of evaluations (locating ran on the copy). So every piece, every leaf solve and J repeat bit for bit.
- Sweep: whole_step tapes k1, the stages (active reads) and step_end. Then, per entry: an own row takes u_r = implicit_value(u_rec,
  slope_rec, G_r) with G_r taped at S(u_rec); an invasion row holds u_r, as its walk did. The pieces at u_r load the recorded points
  (the row is const, so solved_scope loads: ode_interface.hpp:460-464). Each break moves by -G_theta/G_u.

4. Size: about 235 hand-written lines. odelia: ode_interface ~15, ode_step ~85, ode_solver_internal ~14, ode_solver ~3. plant: control ~4,
tf24_strategy ~4, patch ~100, scm ~10.
Names -> ledger line: split_crossings (off by default, bit for bit when off); SplitsCrossings (TF24 only, not TF24f);
SplitsSteps, split_view, split_step (the user's split, R12); split_values, solved_row::split, node_split (its record, reused by walk and sweep;
R4, R7); readings, readings_in (its field, active on the tape; R4); stage_weights (dense output); piece (a block in pieces);
locate, sign_changes (locating, pairs included); rows, split_counts (counted per node per run).
R8: the forward adds ~80 node evaluations per split node-step, mostly inside locate: ~1.2 ms x 9247 ~ 11 s, about 3% of 14844 x 6 x 4.4 ms.
The sweep adds ~17 taped node evaluations per entry, under 2%.

5. Where a competent implementation could go silently wrong, and the structure that prevents it.
- Break and slope (R1-R4). A break at the reads' root leaves the next piece's first evaluation reading sigma on whichever side
  the misfit falls, which is a stage-sized gradient jump at each flip. A full dP/du in the IFT leaves part of the kink term uncancelled:
  the leaf takes drivers as doubles (tf24_strategy.h:2287-2306, tf24_environment.h:414-424), so a moving piece time reaches the tape
  only through states and field weights. Structure: G_r is the evaluation the next piece starts from, so its root pins that reading at
  P = 0 (sigma' = 1/2 for every theta). rates() takes the drivers' time as a double, separate from the field position, so the slope's
  difference holds exactly what the tape holds. What remains: a piece's c=1 stage sits near the kink, but it reaches the result only through
  the 7/8 stage (253/4096 h, ode_step.hpp:281), which is O(h^2) below the old jumps.
- J' = J (R7). Locating must not touch state that later evaluations read, and an entry must reach the same node of the same step.
  Structure: locating uses a scratch strategy and environment. Only recorded evaluations touch the species' strategy, in record order,
  in forward and walk alike. The entry travels in solved_row, which the walk already seeds each step from. Held-or-own is that same field test.
- Off, and at a step's edges (bit identity, R3). The pass writes only the blocks it split; ytmp-and-swap and yerr-first are the same arithmetic.
  The weights are exact at the abscissae and positions are u_a + c_i(u_b - u_a), so a piece over [0,1] reproduces the unsplit block.
  The G(0)G(1) < 0 test flips exactly as a break reaches 0 or 1. Not held by structure: a pair born at a tangency (dG/du -> 0; pairs
  closer than a floor stay unsplit) moves J by a truncation-sized step.
