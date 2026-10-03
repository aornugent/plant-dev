#!/usr/bin/env python3
"""The sweep's instructions by component, from cg_parse.py's TSVs of a callgrind
run with instrumentation on for stand_gradient() alone (sp_cg.sh).

usage: cg_sweep.py <stem> <rows> <sweep_cpu_s>
Each row of the table is a disjoint part of the collected total. Member-rate
components are measured over every TF24_Strategy<active>::compute_rates call
(members and the boundary node's newborn) and apportioned to members by call
count; the boundary node is its own row.
"""
import re
import sys
from collections import defaultdict

stem, rows, cpu = sys.argv[1], float(sys.argv[2]), float(sys.argv[3])

selfc, incl = {}, {}
for line in open(stem + ".self.tsv"):
    v, k = line.rstrip("\n").split("\t", 1)
    selfc[k] = int(v)
for line in open(stem + ".incl.tsv"):
    v, k = line.rstrip("\n").split("\t", 1)
    incl[k] = int(v)
edges = []
for line in open(stem + ".edges.tsv"):
    v, c, a, b = line.rstrip("\n").split("\t", 3)
    edges.append((int(v), int(c), a, b))
total = sum(selfc.values())

A = "xad::AReal<double, 1ul>"
PA = f"plant::Patch<plant::TF24_Strategy<{A} >, plant::TF24_Environment<{A} > >::"
SA = f"plant::Species<plant::TF24_Strategy<{A} >, plant::TF24_Environment<{A} > >::"
STA = f"plant::TF24_Strategy<{A} >::"
NA = f"plant::Node<plant::TF24_Strategy<{A} >, plant::TF24_Environment<{A} > >::"


def match(rx):
    r = re.compile(rx)
    found = {k for k in incl if r.search(k)}
    return found | {a for a, t in stub_target.items() if t in found}


# PLT stubs are named by address and differ between builds: a stub is folded
# into the one function it calls, so a callee pattern matches its stubs too.
stub_target = {}
for v, c, a, b in edges:
    if a.startswith("0x") and not b.startswith("0x"):
        stub_target.setdefault(a, set()).add(b)
stub_target = {a: next(iter(t)) for a, t in stub_target.items() if len(t) == 1}


def into(callee_rx, caller_rx=None):
    """Inclusive cost and calls of the matching callees, counted on edges from
    callers outside the set (and, if given, matching caller_rx)."""
    s = match(callee_rx)
    cr = re.compile(caller_rx) if caller_rx else None
    v_tot, c_tot = 0, 0
    for v, c, a, b in edges:
        if b in s and a not in s and (cr is None or cr.search(a)):
            v_tot += v
            c_tot += c
    return v_tot, c_tot


def show(name, v, calls=None):
    per_row = v / rows
    us = v * cpu / total / rows * 1e6
    c = f"{calls:>9d}" if calls is not None else " " * 9
    print(f"{name:<58s} {v / 1e9:8.3f} G {100 * v / total:6.2f}% {per_row / 1e3:8.1f} k {us:8.1f} us {c}")
    return v


print(f"total collected {total / 1e9:.3f} G Ir over {rows:.0f} rows: {total / rows / 1e6:.3f} M Ir per row; "
      f"native sweep {cpu:.2f} s -> {total / cpu / 1e9:.2f} G Ir/s, {cpu / rows * 1e6:.1f} us per row")
print(f"{'component':<58s} {'Ir':>10s} {'share':>7s} {'Ir/row':>10s} {'us/row':>11s} {'calls':>9s}")

# Top level.
derivs_act, n_derivs = into(r"^void odelia::ode::derivs<plant::Patch<plant::TF24_Strategy<xad::AReal")
step_adj, n_steps = into(r"^void odelia::ode::Step<.*>::step_adjoint\(")
step_derivs, _ = into(r"^void odelia::ode::derivs<plant::Patch<plant::TF24_Strategy<xad::AReal",
                      r"::step_adjoint\(")
tableau = step_adj - step_derivs
reverse, n_rev = into(r"^void odelia::ode::internal::sweep_each_seed<")
rebind, n_rebind = into(r"Patch<plant::TF24_Strategy<double>, plant::TF24_Environment<double> >::rebind_from<xad::AReal")
leaf_ctor_in_rebind, _ = into(r"^phylloptim::Leaf::Leaf\(\)")
be_at, n_be = into(r"^void odelia::ode::be_at_step<")
asys_dtor, _ = into(r"^odelia::ode::active_system<.*>::~active_system\(\)")
asys_rel, _ = into(r"^odelia::ode::active_system<.*>::release\(\)")

# Inside the active rate evaluations.
st_all, n_st_all = into("^" + re.escape(STA) + r"compute_rates\(")
st_mem, n_mem = into("^" + re.escape(STA) + r"compute_rates\(", "^" + re.escape(SA) + r"compute_rates\(")
bnd, n_bnd = into("^" + re.escape(NA) + r"compute_initial_conditions\(")
f_excl, _ = into("^" + re.escape(PA) + r"compute_environment_excl_capturing\(\)$")
f_close, _ = into("^" + re.escape(PA) + r"compute_environment_closing\(\)$")
cons, _ = into("^" + re.escape(SA) + r"consumption_rate\(")
soil, _ = into(r"^plant::TF24_Environment<xad::AReal<double, 1ul> >::compute_rates\(")
noderates, _ = into("^" + re.escape(NA) + r"compute_node_rates\(", "^" + re.escape(SA) + r"compute_rates\(")
estab, _ = into("^" + re.escape(STA) + r"establishment_probability\(")

# Member components, over every strategy call, apportioned to members below.
rlo, _ = into("^" + re.escape(STA) + r"record_leaf_outputs\(")
collar, _ = into(r"^xad::AReal<double, 1ul> phylloptim::Leaf::collar_at<")
curv, _ = into(r"^double phylloptim::Leaf::marginal_collar_slope<")
outs, _ = into(r"^phylloptim::Leaf::LeafOutputs<xad::AReal<double, 1ul> > phylloptim::Leaf::outputs_at<")
draw, _ = into(r"^phylloptim::Leaf::SupplyDraw<xad::AReal<double, 1ul> > phylloptim::Leaf::supply_draw_at<")
qk, _ = into(r"^xad::AReal<double, 1ul> plant::quadrature::QK::integrate<plant::TF24_Strategy<xad::AReal")
place, _ = into("^" + re.escape(STA) + r"net_mass_production_dt\(.*\)::\{lambda")
local_sweep, n_local = into(r"^xad::Tape<double, 1ul>::computeAdjointsTo\(unsigned int\)$",
                            r"implicit_value|preaccumulate")
held_slots, n_held = into(r"^xad::Tape<double, 1ul>::derivative\(unsigned int\)$",
                          r"implicit_value|preaccumulate")

f = st_mem / st_all if st_all else 0.0
leaf_rest = rlo - collar - curv - outs - draw
strat_rest = st_all - rlo - qk - place

parts = []
print("-- active rate evaluations (step stages, insertions, census): "
      f"{derivs_act / 1e9:.3f} G over {n_derivs} evaluations")
print(f"   members: {n_mem} member evaluations; strategy calls {n_st_all} (boundary newborns {n_st_all - n_mem})")
parts.append(show("(a) leaf re-solve at the active scalar (searches)", 0))
parts.append(show("(b1) member placement at double (set_physiology+replay)", f * place))
parts.append(show("(b2) member taped arithmetic, crown light QK21 reads", f * qk))
parts.append(show("(b3) member taped arithmetic, rest of the strategy", f * strat_rest))
parts.append(show("(d1) curvature dM/dp by central difference, double", f * curv))
parts.append(show("(d2) collar IFT: residual M taped (+sigma, ci IFTs)", f * collar))
parts.append(show("(d3) profit at the held collar (+sigma, ci IFTs)", f * outs))
parts.append(show("(d4) supply draw on the tape (5 layers)", f * draw))
parts.append(show("(d5) carry rows, root network, rest of the leaf", f * leaf_rest))
parts.append(show("(e1) light field build on the tape (65 knots)", f_excl + f_close))
parts.append(show("(e2) boundary newborn, 2 per evaluation", bnd, n_bnd))
parts.append(show("(e3) soil: uptake sums and soil rates", cons + soil))
other_eval = derivs_act - sum(parts) - (st_all - st_mem - (bnd - (st_all - st_mem)) * 0) + 0
# What the evaluation holds beyond the rows above: state scatter, node rates,
# establishment, checks. The boundary node's strategy calls are inside `bnd`.
other_eval = derivs_act - (st_mem + bnd + f_excl + f_close + cons + soil)
parts.append(show("(f1) state scatter, node rates, checks", other_eval))
print("-- around the evaluations")
parts.append(show("(b4) Cash-Karp tableau on the tape", tableau, n_steps))
parts.append(show("(c) outer reverse interpretation (incl. adjoint zeroing)", reverse, n_rev))
parts.append(show("(g1) active-system rebinds at range starts", rebind, n_rebind))
parts.append(show("(g2) be_at_step double evaluations", be_at, n_be))
parts.append(show("(g3) active_system release and destructors", asys_dtor + asys_rel))
parts.append(show("(g4) remainder (insertion maps, census seeds, R)", total - sum(parts)))
print(f"{'sum of rows':<58s} {sum(parts) / 1e9:8.3f} G")
print("-- cross-cuts (already inside the rows above)")
show("   of (g1): phylloptim::Leaf() constructors (tables)", leaf_ctor_in_rebind)
show("   IFT local sweeps (computeAdjointsTo from implicit_value)", local_sweep, n_local)
show("   IFT input-slot bookkeeping (Tape::derivative calls)", held_slots, n_held)
for name, rx in [("operator new", r"^operator new\(unsigned long\)$"),
                 ("operator delete", r"^operator delete\(void\*, unsigned long\)$"),
                 ("memset", r"^__memset"), ("memcpy/memmove", r"^__mem(cpy|move)"),
                 ("libm pow/exp/log", r"^(pow|exp|log)(@@GLIBC.*)?$")]:
    v, c = into(rx)
    show(f"   {name}", v, c)
