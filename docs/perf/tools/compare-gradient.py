import io, sys
def load(p):
    d = {}
    for ln in io.open(p, encoding="utf-8", errors="replace"):
        if ln.startswith("G\t"):
            _, m, t, v = ln.rstrip("\n").split("\t")
            d[(m, t)] = float(v)
    return d
base, test = load(sys.argv[1]), load(sys.argv[2])
if set(base) != set(test):
    print("KEY MISMATCH: base %d, test %d" % (len(base), len(test)))
    print("  only in base:", sorted(set(base)-set(test))[:5])
    print("  only in test:", sorted(set(test)-set(base))[:5])
same = sorted(set(base) & set(test))
print("entries compared      %d" % len(same))
bits = sum(1 for k in same if base[k] == test[k])
print("bit-identical         %d / %d" % (bits, len(same)))
# A dropped row is the failure mode: exact zero in test where base is non-zero.
dropped = [k for k in same if test[k] == 0.0 and base[k] != 0.0]
print("DROPPED ROWS (test==0, base!=0)  %d %s" % (len(dropped), dropped[:6] if dropped else ""))
gained = [k for k in same if base[k] == 0.0 and test[k] != 0.0]
print("newly non-zero                   %d %s" % (len(gained), gained[:6] if gained else ""))
rel = []
for k in same:
    b, t = base[k], test[k]
    if b == t: continue
    denom = abs(b) if b != 0 else 1.0
    rel.append((abs(b-t)/denom, k, b, t))
rel.sort(reverse=True)
if rel:
    print("moved                 %d" % len(rel))
    print("largest relative diffs:")
    for r, k, b, t in rel[:6]:
        print("   %-9.3e  %-18s %-24s %.17g -> %.17g" % (r, k[0], k[1], b, t))
    over = sum(1 for r,_,_,_ in rel if r > 1e-4)
    print("entries moving > 1e-4  %d" % over)
else:
    print("no entry moved: the switch is bit-identical")
