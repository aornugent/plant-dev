#!/usr/bin/env python3
"""Two cg_sweep.py tables side by side: per-row instructions and microseconds
per component, and the second build's change.

usage: cg_compare.py <stemA> <rowsA> <cpuA> <stemB> <rowsB> <cpuB>
"""
import subprocess
import sys

import os
here = os.path.dirname(os.path.abspath(__file__))


def table(stem, rows, cpu):
    out = subprocess.run([sys.executable, f"{here}/cg_sweep.py", stem, rows, cpu],
                         capture_output=True, text=True, check=True).stdout
    head, comp = out.splitlines()[0], {}
    for line in out.splitlines():
        if len(line) > 60 and line[:58].strip() and " G " in line[58:]:
            f = line[58:].split()
            try:
                comp[line[:58].strip()] = (float(f[0]), float(f[3]), float(f[5]))  # G, k/row, us/row
            except (ValueError, IndexError):
                continue
    return head, comp


ha, a = table(*sys.argv[1:4])
hb, b = table(*sys.argv[4:7])
print("A:", ha)
print("B:", hb)
print(f"{'component':<58s} {'A k/row':>9s} {'B k/row':>9s} {'B-A k/row':>10s} {'A us':>7s} {'B us':>7s}")
for k in a:
    if k not in b:
        continue
    print(f"{k:<58s} {a[k][1]:9.1f} {b[k][1]:9.1f} {b[k][1] - a[k][1]:10.1f} {a[k][2]:7.1f} {b[k][2]:7.1f}")
