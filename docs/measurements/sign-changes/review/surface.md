# The public surface of the stack under review (declarations and their comments only)

Context, one paragraph: odelia is a header-only ODE library (Cash–Karp with
error control, recorded rows, walks of a recording, a reverse sweep with XAD).
plant's Patch is an odelia System: its state is ~108 TF24 node blocks then the
soil. The stack lets a System integrate a block of a step again in pieces that
meet where the block's "sign value" (TF24: a node's net production) changes
sign inside the step, in the forward, in walks of a recording, and in the sweep.

## odelia (inst/include/odelia/)

ode_interface.hpp
1. `template <class Values> struct sign_change { double u = 0.0; double slope = 0.0; Values solved{}; };`
   // A zero of a block's sign value inside a step: its fraction u of the step, the
   // slope in u there, and what the evaluation at u solved for.
2. `template <class Values> struct split_block { std::size_t block = 0; std::size_t first = 0; std::vector<double> state_before_split; std::vector<sign_change<Values>> sign_changes; std::vector<Values> solved; };`
   // One block a step split, with its components at the end before the split.
   // `solved` holds what each evaluation in its pieces solved for, in order.
3. `solved_row<Values>` gains `Values at_state_before_split{}; std::vector<split_block<Values>> split_blocks;`
   // Where the step split a block: what the evaluation at the end before the split
   // solved for (the dense output reads its rates), and each block it split.

ode_step.hpp, inside `template <class System> class Step`:
4. `template <class S> struct taken_step { const Step& stepper; double time; double h; const std::vector<S>& y0; const std::vector<std::vector<S>>& k; const std::vector<S>& end_rate; std::vector<S>& y_end; const std::vector<double>* sign_values_in = nullptr; const std::array<std::vector<double>, 6>* sign_values = nullptr; ... };`
   // The step just taken, handed to a System that splits, which rewrites `y_end`
   // for each block it splits. The sign values are set at double only.
5. `static constexpr std::array<double, 5> taken_step::sample_fractions{0.0, 0.25, 0.5, 0.75, 1.0};`
   // Where a System samples what its blocks read, as fractions of the step. The
   // dense output is a quartic in u, so five fractions reproduce it.
6. `template <class U> void taken_step::dense_state(const U& u, std::size_t first, std::vector<S>& out) const;`
   // As many components from `first` as `out` holds, of the state at fraction u
   // of the step, on Cash-Karp's fourth-order continuous extension.
7. `template <class U> void taken_step::sample_at(const U& u, const std::array<std::vector<S>, 5>& samples, std::vector<S>& out) const;`
   // The quartic through samples taken at each of sample_fractions, at u.
8. `template <class U, class Rates> void taken_step::integrate_pieces(std::size_t first, const std::vector<U>& split_at, Rates&& rates, std::vector<S>& own) const;`
   // The block from `first` integrated over the step in pieces meeting at the
   // fractions `split_at`; `rates(u, own, out)` gives its rates at u.
9. `template <class Values, class ValueAt> std::vector<sign_change<Values>> taken_step::sign_changes(std::size_t block, ValueAt&& value_at) const requires std::same_as<S, double>;`
   // Where block `block`'s sign value changes sign in the step, once or as a pair.
   // `value_at(u, solved)` is the value at u, storing what it solved for if asked.
10. `taken_step<double> Step::taken(double time, double step_size, const state_type& dydt_out, state_type& y, const std::vector<double>& sign_values_in) const;`
   // The step just taken, which ended at `y` with rates `dydt_out`, at double.
11. `const std::vector<double>& Step::end_sign_values() const;` and `void Step::read_end_sign_values(const System& system);`
   // Each block's sign value where the step just taken ended, which the next step
   // starts from; read again after the end's rates are evaluated again.
12. concept, at namespace scope:
   // A System whose rates change form where a block's sign value changes sign: it
   // reports the sign values after every evaluation and splits the step just taken.
   // split_sign_changes must return true if it evaluated anything, which leaves the
   // System off the step's end. A walk hands take_recorded_splits the blocks the run
   // split and the run's end, to carry onto the walk's end `y`; the sweep hands the
   // System lifted to the active scalar the same blocks, to split_as_recorded.
   `template <typename System> concept SplitsSignChanges = std::same_as<typename System::value_type, double> && requires(System& s, const System& cs, std::vector<double>& y, const typename Step<System>::template taken_step<double>& step, std::vector<split_block<solved_values_t<System>>>& record, const std::vector<split_block<solved_values_t<System>>>& recorded, const std::vector<double>& run_end) { { cs.sign_values(y) } -> std::same_as<void>; { s.split_sign_changes(step, record) } -> std::same_as<bool>; { cs.take_recorded_splits(recorded, run_end, y) } -> std::same_as<void>; };`
13. In `Step::step_adjoint` (the sweep's step transposed): a System that splits must offer, at the active scalar, `split_as_recorded(taken_step<active>, const std::vector<split_block<...>>& recorded)`.

ode_solver_internal.hpp / ode_solver.hpp:
14. `const std::vector<std::size_t>& SolverInternal::splits_by_block() const;`
   // By block, the steps this run committed split since the last reset.
   `const std::vector<std::size_t>& Solver::splits_by_block() const;`
   // By block, the steps this run split at a sign change since the last reset.
15. `template <class Row = step_record<System>> void SolverInternal::step_by(System& system, double step_size, double reached, const Row* recorded = nullptr);`
   // `reached` is the time a recording says this step ended at; NaN accumulates.
   // `recorded` is the row a walk follows, for its evaluations and its splits.
16. private `void SolverInternal::split(System& system, double time_, double step_size);`
   // Hand the step just taken to a System that splits, and evaluate the end's rates
   // again if it evaluated anything. Cash-Karp only: Rosenbrock has no dense output.
17. private `template <class Row> void SolverInternal::take_recorded_splits(System& system, const Row& recorded, double time_, double step_size);`
   // A walk has the System carry the splits of the row it follows onto its end,
   // then evaluates the end's rates as the run did there.

## plant (inst/include/plant/)

patch.h
18. `template <typename T> concept NamesSignValue = requires(const T& s) { { s.sign_value_aux() } -> std::same_as<int>; };`
   // A strategy whose rates change form where one of its auxiliaries changes sign.
19. `using Patch::split_blocks = std::vector<odelia::ode::split_block<solved_values>>;`
   // What a step records of each node it split.
20. `void Patch::sign_values(std::vector<double>& out) const requires NamesSignValue<T>;`
   // Each node's net production after an evaluation, in the order ode_state writes
   // the nodes.
21. `template <class Step> bool Patch::split_sign_changes(const Step& step, split_blocks& record) requires NamesSignValue<T>;`
   // Integrates each node whose net production changed sign in the step just taken
   // in pieces between its sign changes; returns whether it evaluated anything.
22. `template <class Step> void Patch::split_as_recorded(const Step& step, const split_blocks& recorded) requires NamesSignValue<T>;`
   // The split the sweep takes: each recorded sign change moves with the parameters
   // as the zero of its node's net production, and each node is integrated again
   // in pieces between them, every evaluation loading what the run's solved for.
23. `void Patch::take_recorded_splits(const split_blocks& recorded, const std::vector<double>& run_end, std::vector<double>& y) const requires NamesSignValue<T>;`
   // A walk carries each node the run split onto that node of every species laid
   // out as the run's one: the walk's end, less the run's before the split, plus
   // the run's end.
24. private: `using field_samples = std::array<std::vector<value_type>, 5>;`
   // The field a node reads at each of a step's five sample fractions: the light
   // field's knot data, then the environment's own state.
   `template <class Step> void sample_field(const Step& step, field_samples& field);`
25. private: `template <class Step, class U> value_type node_value_at(const Step& step, const field_samples& field, size_t node, size_t first, size_t width, const U& u, double time) requires NamesSignValue<T>;`
   // A node's net production at fraction u of the step, its own components read
   // from the dense output and its field from the samples, evaluated at `time`.
26. private: `template <class Step, class U, class Solved> void split_node(const Step& step, const field_samples& field, size_t node, size_t first, size_t width, const std::vector<U>& split_at, Solved&& solved) requires NamesSignValue<T>;`
   // A node integrated again over the step in pieces meeting at `split_at`, each
   // evaluation inside the extent `solved()` opens; its end goes into the step's.
27. private: `value_type node_rates_in_field(size_t node, const std::vector<value_type>& own, const std::vector<value_type>& field, double time, std::vector<value_type>& rates) requires NamesSignValue<T>;`
   // One node's rates and net production in the field supplied, not built.

species.h
28. `template <typename It> It Species::set_node_ode_state(size_t j, It it);`
   // Node j's components alone, in the order set_ode_state writes them.
29. `void Species::compute_node_rates(size_t j, const environment_type& environment, double pr_patch_survival, double birth_rate);`
   // Node j's rates as compute_rates() leaves them, and no other node's but the
   // boundary node's when j is the newest, whose interval rate reads it.
30. private `void Species::compute_boundary_rates(const environment_type& environment, double pr_patch_survival, double birth_rate);`
   // The boundary node's rates in the field the nodes' rates were computed in, and
   // the newest node's interval rate, which reads them.
31. `void Species::compute_boundary_node(const environment_type& environment, double pr_patch_survival, double birth_rate);` (changed)
   // Evaluate the inflow boundary condition in the environment passed. Split out
   // of compute_rates() so the field build owns it and the field stops reading a
   // density carried from the previous evaluation. On the birth-date coordinate
   // the field reads only the newborn's size and the birth rate, so its rates are
   // left to compute_rates(), which takes them in the whole field.

node.h
32. `void Node::seat_birth_state(const environment_type& environment, double birth_rate);`
   // The boundary node as the field reads it on the birth-date coordinate: its
   // initial state, which sets its leaf area, and its density, the birth rate now
   // before any mortality. Its rates are not computed.

scm.h
33. `Rcpp::IntegerVector SCM::r_ode_splits() const;` (R: `SCM$ode_splits`)
   // By node in the order ode_state writes them, the steps the last run split at a
   // sign change of net production.
34. In `SCM::run_mutant` (the invasion walk's setup), for every recorded row:
   // An invader carries the split of the node it copies, which only a run of one
   // species names.

control.h
35. `bool Control::ode_split_sign_changes;` (default false)
   // Integrate each node in pieces between the sign changes of its net production
   // inside a step (TF24), in the field the step's dense output builds.

models/tf24_strategy.h, models/tf24f_strategy.h
36. `int TF24_Strategy::sign_value_aux() const;`
   // The auxiliary at whose sign change the rates change form: net production,
   // which the storage pool reads through its smooth positive part.
37. `int TF24f_Strategy::sign_value_aux() const = delete;` (TF24f derives from TF24)
   // Not split: sampling the field for a split seats the newborn, which runs this
   // strategy's leaf optimiser outside any recording.
38. `TF24_Strategy::height_seed()` at double now calls `phylloptim::util::uniroot(target, h0, h1, max_iterations)`
   // To roundoff, as the leaf's root-finds are: every node starts at this
   // height, so a tolerance would step offspring production as a trait moves.

## phylloptim (inst/include/phylloptim/uniroot.hpp)
39. `double uniroot(Function f, double min, double max, size_t max_iterations);` stops once the bracket's ends agree to roundoff; refuses (`stop_infeasible("root_find_iterations", ...)`) when the budget is spent.
