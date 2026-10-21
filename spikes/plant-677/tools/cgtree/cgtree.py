# Top-down inclusive tree with call counts from a raw callgrind file.
import sys, re, collections
def short(n):
    n = re.sub(r'\(.*', '', n)              # drop argument lists
    n = re.sub(r'<[^<>]*>', '', n); n = re.sub(r'<[^<>]*>', '', n); n = re.sub(r'<[^<>]*>', '', n); n = re.sub(r'<[^<>]*>', '', n)
    return n.replace('xad::AReal','A')[-90:]
def parse(path):
    names = {}; selfc = collections.Counter(); edges = collections.defaultdict(lambda: [0, 0])
    fn = None; cfn = None; calls = None
    def nm(tok, rest):
        m = re.match(r'\((\d+)\)\s*(.*)', rest)
        if m:
            if m.group(2): names[m.group(1)] = m.group(2)
            return names[m.group(1)]
        return rest
    for line in open(path):
        line = line.rstrip('\n')
        if line.startswith('fn='): fn = nm('fn', line[3:]); continue
        if line.startswith('cfn='): cfn = nm('cfn', line[4:]); continue
        if line.startswith('calls='): calls = int(line[6:].split()[0]); continue
        if line and (line[0].isdigit() or line[0] in '+-*'):
            parts = line.split()
            if len(parts) < 2: continue
            c = int(parts[1])
            if calls is not None:
                e = edges[(fn, cfn)]; e[0] += calls; e[1] += c; calls = None
            else:
                selfc[fn] += c
    return selfc, edges
selfc, edges = parse(sys.argv[1])
root = sys.argv[2]; total = float(sys.argv[3]); thr = float(sys.argv[4]) if len(sys.argv) > 4 else 0.01
kids = collections.defaultdict(list)
for (a, b), (n, c) in edges.items(): kids[a].append((b, n, c))
roots = [f for f in set(selfc) | set(kids) if re.search(root, f)]
def walk(f, n, c, depth, seen):
    print(f"{'  '*depth}{c/1e6:9.1f}M {100*c/total:5.1f}%  x{n:<9} {c/max(n,1):10.0f}/call  {short(f)}")
    if f in seen or depth > 14: return
    s = selfc.get(f, 0)
    if s/total >= thr and kids[f]: print(f"{'  '*(depth+1)}{s/1e6:9.1f}M {100*s/total:5.1f}%  (self)")
    for b, n2, c2 in sorted(kids[f], key=lambda x: -x[2]):
        if c2/total >= thr: walk(b, n2, c2, depth+1, seen | {f})
for r in roots[:1]:
    walk(r, 1, sum(c for _, _, c in kids[r]) + selfc.get(r, 0), 0, set())
