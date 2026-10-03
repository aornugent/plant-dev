#!/usr/bin/env python3
"""The sweep's cost per row by component, both builds: instructions from
callgrind (cg_sweep.py), wall time from the tapestats shim's phases, each
phase's time split over its components by their instructions.

usage: final_table.py <cg_stem> <tape_summary.rds-derived phases json> ...
  (run through final_table.sh, which extracts the phases with R)
"""
import json
import subprocess
import sys
import os

here = os.path.dirname(os.path.abspath(__file__))


def cg(stem, rows, cpu):
    out = subprocess.run([sys.executable, f"{here}/cg_sweep.py", stem, str(rows), str(cpu)],
                         capture_output=True, text=True, check=True).stdout
    comp = {}
    for line in out.splitlines():
        if line[:1] == "(":
            f = line[58:].split()
            comp[line[:58].strip()] = float(f[0]) * 1e9
    return comp


def table(stem, phases, rows):
    c = cg(stem, rows, phases["cpu"])
    evalk = [k for k in c if k[:3] in ("(b1", "(b2", "(b3", "(d1", "(d2", "(d3", "(d4",
                                         "(d5", "(e1", "(e2", "(e3", "(f1", "(b4")]
    gapk = [k for k in c if k[:3] in ("(g1", "(g2", "(g3")]
    ev_ir = sum(c[k] for k in evalk)
    gap_ir = sum(c[k] for k in gapk)
    t_eval = phases["step_rec"] + phases["ins_rec"]
    t_rev = phases["step_sweep"] + phases["ins_sweep"]
    t_gap = phases["gap_at_insertions"]
    t_other = phases["wall"] - t_eval - t_rev - t_gap
    us = {}
    for k in c:
        if k in evalk:
            us[k] = t_eval * c[k] / ev_ir
        elif k in gapk:
            us[k] = t_gap * c[k] / gap_ir
        elif k.startswith("(c)"):
            us[k] = t_rev
        elif k.startswith("(g4"):
            us[k] = t_other
        else:
            us[k] = 0.0
    tot_ir = sum(c.values())
    return {k: (c[k] / rows, 100 * c[k] / tot_ir, 1e6 * us[k] / rows, 100 * us[k] / phases["wall"])
            for k in c}, tot_ir / rows, 1e6 * phases["wall"] / rows


rows = float(sys.argv[1])
specs = json.loads(sys.argv[2])
res = []
for spec in specs:
    res.append((spec["name"],) + table(spec["stem"], spec["phases"], rows))
print(f"rows {rows:.0f}")
for name, t, ir_row, us_row in res:
    print(f"{name}: {ir_row / 1e6:.3f} M Ir per row, {us_row:.1f} us per row (wall)")
hdr = "component".ljust(58) + "".join(f" | {n[:14]:>14s} Ir/row  share   us/row  share" for n, *_ in res)
print(hdr)
for k in res[0][1]:
    line = k.ljust(58)
    for name, t, *_ in res:
        ir, sh, us, ush = t.get(k, (0, 0, 0, 0))
        line += f" | {ir / 1e3:12.1f} k {sh:5.1f}% {us:7.1f} {ush:5.1f}%"
    print(line)
