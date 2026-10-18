# Total calls into each function of a callgrind profile, matched by a name pattern.
#   python3 cg_calls.py FILE PATTERN...
import re, sys, collections
names, calls = {}, collections.Counter()
cfn = None
for line in open(sys.argv[1], errors="replace"):
    m = re.match(r"c?fn=\((\d+)\)(?: (.*))?", line)
    if m:
        if m.group(2): names[m.group(1)] = m.group(2).strip()
        if line.startswith("cfn="): cfn = m.group(1)
        continue
    m = re.match(r"calls=(\d+)", line)
    if m and cfn is not None:
        calls[cfn] += int(m.group(1)); cfn = None
for pat in sys.argv[2:]:
    for k, n in calls.items():
        nm = names.get(k, "?")
        if re.search(pat, nm): print(f"{n:>12} {nm[:170]}")
