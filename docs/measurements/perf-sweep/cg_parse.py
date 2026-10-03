#!/usr/bin/env python3
"""Aggregate a callgrind output file by function symbol, ignoring the
fi=/fe= source-file splits that inlining produces.

Writes three TSVs next to the input:
  <out>.self.tsv   function, self Ir
  <out>.incl.tsv   function, inclusive Ir (self + calls to other functions)
  <out>.edges.tsv  caller, callee, calls, inclusive Ir of those calls
"""
import re
import sys
from collections import defaultdict

path = sys.argv[1]
stem = sys.argv[2] if len(sys.argv) > 2 else path

names = {}
name_re = re.compile(r"^\((\d+)\)(?: (.*))?$")


def resolve(s):
    s = s.strip()
    m = name_re.match(s)
    if not m:
        return s
    if m.group(2) is not None:
        names[m.group(1)] = m.group(2)
        return m.group(2)
    return names[m.group(1)]


self_cost = defaultdict(int)
edge_cost = defaultdict(int)
edge_calls = defaultdict(int)
fn = None
cfn = None
pending = None
total = 0

with open(path) as f:
    for line in f:
        if not line or line[0] == "\n":
            continue
        c = line[0]
        if c.isdigit() or c in "+-*":
            parts = line.split()
            if len(parts) < 2:
                continue
            cost = int(parts[1])
            if pending is not None:
                edge_cost[(fn, cfn)] += cost
                edge_calls[(fn, cfn)] += pending
                pending = None
            else:
                self_cost[fn] += cost
                total += cost
            continue
        if line.startswith("fn="):
            fn = resolve(line[3:])
        elif line.startswith("cfn="):
            cfn = resolve(line[4:])
        elif line.startswith("calls="):
            pending = int(line[6:].split()[0])
        elif line.startswith("summary:") or line.startswith("totals:"):
            pass

incl = defaultdict(int)
for k, v in self_cost.items():
    incl[k] += v
for (a, b), v in edge_cost.items():
    if a != b:
        incl[a] += v

with open(stem + ".self.tsv", "w") as o:
    for k, v in sorted(self_cost.items(), key=lambda kv: -kv[1]):
        o.write(f"{v}\t{k}\n")
with open(stem + ".incl.tsv", "w") as o:
    for k, v in sorted(incl.items(), key=lambda kv: -kv[1]):
        o.write(f"{v}\t{k}\n")
with open(stem + ".edges.tsv", "w") as o:
    for (a, b), v in sorted(edge_cost.items(), key=lambda kv: -kv[1]):
        o.write(f"{v}\t{edge_calls[(a, b)]}\t{a}\t{b}\n")
print(f"total self Ir {total}")
