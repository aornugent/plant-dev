# Replace the seasonal regime's rows of a package's reference-gradient.tsv with
# those of a seasonal-only capture, in place and in order.
# Usage: python3 splice_seasonal.py CAPTURE_DIR PACKAGE_REFERENCE_DIR
import sys, os
cap, ref = sys.argv[1], sys.argv[2]
for name in ("reference-gradient.tsv",):
    old = open(os.path.join(ref, name)).read().splitlines()
    new = open(os.path.join(cap, name)).read().splitlines()
    assert old[0].split("\t") == new[0].split("\t"), name
    fresh = [l for l in new[1:] if l.split("\t")[0] == "seasonal"]
    assert len(fresh) == len(new) - 1, name
    idx = [i for i, l in enumerate(old) if l.split("\t")[0] == "seasonal"]
    assert idx == list(range(idx[0], idx[0] + len(idx))), name
    assert len(idx) == len(fresh), (name, len(idx), len(fresh))
    out = old[:idx[0]] + fresh + old[idx[-1] + 1:]
    open(os.path.join(ref, name), "w").write("\n".join(out) + "\n")
    print(name, "replaced", len(fresh), "rows")
