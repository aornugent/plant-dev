#!/usr/bin/env python3
"""The callees of the functions matching a regex, by inclusive edge cost, with
the caller's self cost: what one function's inclusive cost is made of.

usage: cg_children.py <stem> <caller-regex> [n] [callee-regex]
"""
import re
import sys
from collections import defaultdict

stem, pat = sys.argv[1], re.compile(sys.argv[2])
n = int(sys.argv[3]) if len(sys.argv) > 3 else 25
cpat = re.compile(sys.argv[4]) if len(sys.argv) > 4 else None
selfc = {}
for line in open(f"{stem}.self.tsv"):
    v, k = line.rstrip("\n").split("\t", 1)
    selfc[k] = int(v)
total = sum(selfc.values())
incl = {}
for line in open(f"{stem}.incl.tsv"):
    v, k = line.rstrip("\n").split("\t", 1)
    incl[k] = int(v)
callers = [k for k in incl if pat.search(k)]
kids = defaultdict(lambda: [0, 0])
for line in open(f"{stem}.edges.tsv"):
    v, c, a, b = line.rstrip("\n").split("\t", 3)
    if a in callers and a != b:
        if cpat and not cpat.search(b):
            continue
        kids[b][0] += int(v)
        kids[b][1] += int(c)
tot_incl = sum(incl[k] for k in callers)
tot_self = sum(selfc.get(k, 0) for k in callers)
print(f"{len(callers)} callers, inclusive {tot_incl:,} ({100 * tot_incl / total:.2f}%), self {tot_self:,} ({100 * tot_self / max(tot_incl, 1):.1f}% of it)")
for k in callers[:4]:
    print(f"  caller: {k[:200]}")
for b, (v, c) in sorted(kids.items(), key=lambda kv: -kv[1][0])[:n]:
    print(f"{v:>16,d} {100 * v / max(tot_incl, 1):6.2f}% {c:>10d}  {b[:200]}")
