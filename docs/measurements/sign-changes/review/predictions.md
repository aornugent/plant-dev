# Cold-reader predictions (written from surface.md only, before any body was read)

1. sign_change: plain aggregate; u strictly in (0,1); slope = d(sign value)/du at the zero (used later for an implicit-function step); solved = Values from the one evaluation at u.
2. split_block: block = node index; first = offset of its first component in y; state_before_split = y_end[first, first+width) before rewrite (size = width); sign_changes sorted by u; solved = one Values per stage evaluation (6 per piece), pieces in order.
3. solved_row gains at_state_before_split (Values of the end evaluation before any split, kept so dense output uses pre-split end rates) and split_blocks; both empty/default when the step did not split.
4. taken_step: non-owning view (dangles if args are temporaries); y_end is the only mutable member; sign_values_in = values at y0, sign_values[i] = values at stage i; both pointers null at the active scalar.
5. sample_fractions: constant {0,.25,.5,.75,1}; sampling a quantity LINEAR in the state there and calling sample_at reproduces dense_state exactly; for the (nonlinear) light field it is an approximation.
6. dense_state: writes out.size() components y(u)[first..] from y0 and the k stages only (never reads y_end, so rewrites don't affect it); u in [0,1]; u=0 gives y0; no resize, caller pre-sizes; templated U so u can be active.
7. sample_at: quartic Lagrange interpolation through the 5 samples at u, component-wise; out has samples[0].size() components (resized or pre-sized); sample_at(f_i, ...) == samples[i].
8. integrate_pieces: own is in/out-ish: initialised from y0[first, first+own.size()), integrated piece by piece over [0,s0],[s0,s1],...,[s_last,1] (one RK step per piece, no error control), own = block's state at u=1 on return; split_at must be sorted inside (0,1); empty split_at = one piece.
9. sign_changes: uses sign_values_in and the 6 stage sign values (no evaluation) to detect a single crossing (ends differ) or a pair (ends agree, an interior stage differs); root-finds each zero with value_at; slope from the root-finder/finite difference; empty vector, and no evaluation at all, when nothing changes sign; throws if the root-find fails.
10. taken: const, no side effects; wraps stored y0/k and the arguments; sign_values points at the Step's stage buffer.
11. end_sign_values: returns Step's stored end values (empty for non-splitting systems); read_end_sign_values: calls system.sign_values(buffer), mutates only the Step's buffer.
12. SplitsSignChanges: value_type double + const sign_values(out), split_sign_changes(step, record)->bool, const take_recorded_splits(recorded, run_end, y); split_as_recorded NOT in the concept; the `y` parameter of sign_values is actually an output buffer.
13. step_adjoint: for a SplitsSignChanges System, calls split_as_recorded only on rows whose split_blocks is non-empty; compile error if missing at the active scalar.
14. splits_by_block: counts per block of ACCEPTED steps that split (rejected trial steps never count); sized to the current block count, grows as blocks are added; zeroed by reset(); empty for non-splitting systems; Solver's forwards SolverInternal's.
15. step_by: one fixed step; time_ = reached when reached is finite, time_ += step_size when NaN; recorded == nullptr in a run, non-null in a walk; walk -> take_recorded_splits, run -> split.
16. split: builds Step::taken, calls system.split_sign_changes(step, row.split_blocks), stores at_state_before_split; if true, re-sets state to y, re-evaluates dydt_out, re-reads end sign values; under Rosenbrock it refuses (throws) rather than silently skipping.
17. take_recorded_splits (solver): no-op when recorded.split_blocks empty; otherwise calls system.take_recorded_splits(recorded.split_blocks, recorded end y, y) then re-evaluates the end loading the row's recorded solved values.
18. NamesSignValue: true iff strategy has a callable const sign_value_aux() returning int (an index into the aux vector); a deleted declaration makes it false.
19. split_blocks alias: plain alias.
20. Patch::sign_values: resizes out to the total node count (all species, ode_state order, boundary node excluded); copies cached aux[sign_value_aux()] from the last compute_rates; no evaluation.
21. split_sign_changes: per node calls step.sign_changes; for nodes with zeros samples the field (once), split_node, rewrites y_end, appends to record; returns false and evaluates nothing when no node changes sign.
22. split_as_recorded: active scalar; does not re-detect; for each recorded zero u_a = u_rec - value(u_rec)/slope (Newton/IFT so u carries parameter derivatives); re-integrates the node in pieces loading recorded solved values in order; mismatch in evaluation count throws.
23. Patch::take_recorded_splits: const; for each recorded block and each species s, y[s block] += run_end[block] - state_before_split; assumes every species has the run's node layout (out-of-range -> bounds error); empty recorded -> no-op.
24. sample_field: for each of the 5 fractions sets the WHOLE patch state to dense_state(u), builds the light field and env state, copies into field[i]; mutates the Patch (leaves it off the step's end; seats the newborn).
25. node_value_at: own = dense_state(u, first, width), field = sample_at(u, samples), returns node_rates_in_field(...); `time` = step.time + u*h passed by the caller; mutates the node/environment as a side effect.
26. split_node: integrate_pieces over split_at with rates from node_rates_in_field at sample_at(u); every evaluation inside the scope solved() returns (record in a run, load in the sweep); writes the node's end into step.y_end[first, first+width).
27. node_rates_in_field: sets node state = own, environment = field, computes this node's rates into `rates`, returns net production; mutates node and environment.
28. Species::set_node_ode_state: reads node j's ode_size components from it, returns it advanced by node j's width; touches no other node.
29. compute_node_rates: node j's rates; when j is the newest node (last pushed, j == size()-1) also the boundary node's rates; mutates only those nodes.
30. compute_boundary_rates: computes boundary (new_node) rates in env, then newest node's interval rate; mutates those two.
31. compute_boundary_node: on the birth-date coordinate only seats the birth state (no rates); otherwise also computes the boundary node's rates; called by the field build, not by compute_rates.
32. Node::seat_birth_state: sets the node's initial state from env (height seed -> leaf area) and density = birth_rate; computes no rates; mutates the node only.
33. SCM::r_ode_splits: IntegerVector copy of solver splits_by_block() from the last run; length = number of nodes (ode_state order); empty/zeros when the control is off.
34. run_mutant: for each recorded row, re-indexes the resident's split blocks onto the invader's copied nodes; if the run had >1 species the splits are dropped or it throws.
35. Control::ode_split_sign_changes: default false; when true with a strategy lacking sign_value_aux (FF16, TF24f) silently does nothing (or errors); with Rosenbrock errors.
36. TF24_Strategy::sign_value_aux: returns the aux index of net production (fixed constant or aux_index lookup).
37. TF24f sign_value_aux = delete: makes NamesSignValue false so TF24f never splits even with the control on.
38. height_seed: double path calls the no-tolerance uniroot; throws stop_infeasible when the budget is spent; result differs from before by < tolerance.
39. uniroot: requires f(min), f(max) of opposite sign (else throws); bisection/Brent until |max-min| <= few ulps (or f == 0 exactly); returns a bracket end/midpoint; throws stop_infeasible("root_find_iterations") when max_iterations reached.
