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
