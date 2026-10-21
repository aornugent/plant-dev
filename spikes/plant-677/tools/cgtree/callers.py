import sys, re, collections
sys.argv += []
exec(open(__file__.replace('callers.py','cgtree_lib.py')).read())
selfc, edges = parse(sys.argv[1])
pat = sys.argv[2]
for (a, b), (n, c) in sorted(edges.items(), key=lambda kv: -kv[1][1]):
    if re.search(pat, b): print(f"{c/1e6:9.1f}M x{n:<8} {short(a)}  ->  {short(b)}")
