import sys, re, collections
exec(open(__file__.replace('ledger.py','cgtree_lib.py')).read())
rows = [
 ("crown (rows, double math + record)", r"FF16_Strategy<xad::AReal<double, 1ul> >::assimilation_deep_crown_rows\("),
 ("  record_rows (all callers)",         r"internal::record_rows<"),
 ("node rates, whole (active)",          r"FF16_Strategy<xad::AReal<double, 1ul> >::compute_rates\("),
 ("Node::compute_node_rates",            r"Node<plant::FF16_Strategy<xad::AReal.*::compute_node_rates\("),
 ("field: excl (field_splits etc.)",     r"Patch<plant::FF16_Strategy<xad::AReal<double, 1ul> >, plant::FF16_Environment<xad::AReal<double, 1ul> > >::compute_environment_excl_capturing\(\)$"),
 ("  field_splits_nodes",                r"Species<plant::FF16_Strategy<xad::AReal.*::field_splits_nodes\("),
 ("  split_with_rows",                   r"::split_with_rows<"),
 ("field: closing",                      r"Patch<plant::FF16_Strategy<xad::AReal<double, 1ul> >, plant::FF16_Environment<xad::AReal<double, 1ul> > >::compute_environment_closing\(\)$"),
 ("boundary nodes",                      r"Patch<plant::FF16_Strategy<xad::AReal<double, 1ul> >, plant::FF16_Environment<xad::AReal<double, 1ul> > >::compute_boundary_nodes\(\)$"),
 ("Patch::set_ode_state (active)",       r"Patch<plant::FF16_Strategy<xad::AReal.*::set_ode_state<"),
 ("rebind_from (double -> active patch)",r"::rebind_from<"),
 ("Patch::reset (active)",               r"Patch<plant::FF16_Strategy<xad::AReal.*::reset\(\)$"),
 ("apply_insertion",                     r"::apply_insertion<"),
 ("sweep: computeAdjointsToImpl",        r"Tape<double, 1ul>::computeAdjointsToImpl\("),
 ("step_adjoint",                        r"Step<.*>::step_adjoint\("),
 ("solve-level state_and_parameter_adjoints", r"^odelia::ode::state_and_parameter_adjoints<.*Solver<"),
 ("sweep_each_seed (step)",              r"sweep_each_seed<"),
]
for path in sys.argv[1:]:
    selfc, edges = parse(path)
    inc = collections.defaultdict(lambda: [0, 0])
    for (a, b), (n, c) in edges.items():
        if a == b: continue
        inc[b][0] += n; inc[b][1] += c
    tot = sum(selfc.values())
    print(f"== {path}: {tot/1e6:.0f}M")
    for label, pat in rows:
        ms = [f for f in inc if re.search(pat, f)]
        n = sum(inc[f][0] for f in ms); c = sum(inc[f][1] for f in ms)
        print(f"  {label:42s} calls {n:>9}  {c/1e6:8.1f}M {100*c/tot:5.1f}%  {c/max(n,1):10.0f}/call  [{len(ms)} fns]")
