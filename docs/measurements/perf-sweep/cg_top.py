#!/usr/bin/env python3
"""Explore cg_parse.py output: top functions by inclusive or self Ir, optionally
filtered by a regex, with call counts from the edges.

usage: cg_top.py <stem> [incl|self] [regex] [n]
"""
import re
import sys
from collections import defaultdict

stem = sys.argv[1]
mode = sys.argv[2] if len(sys.argv) > 2 else "incl"
pat = re.compile(sys.argv[3]) if len(sys.argv) > 3 and sys.argv[3] else None
n = int(sys.argv[4]) if len(sys.argv) > 4 else 40

vals = {}
for line in open(f"{stem}.{mode}.tsv"):
    v, k = line.rstrip("\n").split("\t", 1)
    vals[k] = int(v)
calls = defaultdict(int)
for line in open(f"{stem}.edges.tsv"):
    v, c, a, b = line.rstrip("\n").split("\t", 3)
    if a != b:
        calls[b] += int(c)
total = sum(int(l.split("\t", 1)[0]) for l in open(f"{stem}.self.tsv"))
print(f"total self Ir {total:.4g}")
shown = 0
for k, v in sorted(vals.items(), key=lambda kv: -kv[1]):
    if pat and not pat.search(k):
        continue
    print(f"{v:>16,d} {100 * v / total:6.2f}% {calls[k]:>10d}  {k[:230]}")
    shown += 1
    if shown >= n:
        break
