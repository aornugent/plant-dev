"""Continuous extensions of ARK4(3)6L[2]SA, in exact rational arithmetic.

The pair's tableaux are parsed from harness/ark436.R (AE explicit, AI implicit,
shared b, d and cc). One set of weights b(theta) serves both parts. A stage's
weights satisfy the additive pair's conditions: every tree with each non-root
vertex coloured E or I, the edge into a vertex using that vertex's tableau.

  python3 stage0/ark_dense.py [path/to/ark436.R] > stage0/ark_dense.txt

Questions: an order-4 (and order-3) extension from the six stages; from the six
plus the step's end (stage 7, Y7 = y1, row b in both tableaux, k7 = f(y1) whole);
the family's dimension; the C1 member least in order-5 error at theta = 1/2.
"""
import re, sys, math, io, contextlib
from fractions import Fraction as F
from itertools import product

sys.path.insert(0, __file__.rsplit("/", 1)[0])
with contextlib.redirect_stdout(io.StringIO()):
    import tableau_algebra as ta
trees_of_order = ta.trees_of_order
tableau_ck, with_fsal = ta.tableau_ck, ta.with_fsal

# The published coefficients are long rational approximations: the pair's own
# conditions hold to about 1e-27, not exactly. So the linear algebra pivots on
# magnitude and treats anything under TOL as zero.
TOL = F(1, 10 ** 15)

def rref_tol(M, ncols):
    M = [row[:] for row in M]
    rows = len(M)
    piv, r = [], 0
    for col in range(ncols):
        if r == rows:
            break
        p = max(range(r, rows), key=lambda i: abs(M[i][col]))
        if abs(M[p][col]) < TOL:
            for i in range(r, rows):
                M[i][col] = F(0)
            continue
        M[r], M[p] = M[p], M[r]
        pv = M[r][col]
        M[r] = [x / pv for x in M[r]]
        for i in range(rows):
            if i != r and M[i][col] != 0:
                f = M[i][col]
                M[i] = [a - f * bb for a, bb in zip(M[i], M[r])]
        piv.append(col)
        r += 1
    return M, piv

def rank(M):
    return len(rref_tol(M, len(M[0]))[1])

def solve_general(M, rhs):
    """A particular solution and a null-space basis of M x = rhs (to TOL), or None."""
    cols = len(M[0])
    R, piv = rref_tol([row[:] + [v] for row, v in zip(M, rhs)], cols)
    for i in range(len(piv), len(R)):
        if abs(R[i][cols]) >= TOL:
            return None
    x = [F(0)] * cols
    for i, cidx in enumerate(piv):
        x[cidx] = R[i][cols]
    null = []
    for fcol in [cc_ for cc_ in range(cols) if cc_ not in piv]:
        v = [F(0)] * cols
        v[fcol] = F(1)
        for i, cidx in enumerate(piv):
            v[cidx] = -R[i][fcol]
        null.append(v)
    return x, null

def worst(As, w, p, rhs_theta=None):
    """Largest |sum w_i Phi_i(t) - 1/gamma(t)| over the coupled trees of order p."""
    return max(abs(float(sum(wi * x for wi, x in zip(w, cphi(As, t))) - F(1, cgamma(t)))) for t in CT[p])

path = sys.argv[1] if len(sys.argv) > 1 else \
    "/home/user/plant-dev/.claude/worktrees/agent-a8bbf38e99929db61/harness/ark436.R"
src = open(path).read()

def frac(s):
    s = s.strip()
    return F(s) if "/" not in s else F(int(s.split("/")[0]), int(s.split("/")[1]))

def parse():
    AE = [[F(0)] * 6 for _ in range(6)]
    AI = [[F(0)] * 6 for _ in range(6)]
    for m in re.finditer(r"(AI|AE)\[(\d+),\s*(?:1:(\d+)|(\d+))\]\s*<-\s*(c\(([^)]*)\)|[-\d/]+)", src):
        name, i = m.group(1), int(m.group(2)) - 1
        vals = [frac(v) for v in (m.group(6).split(",") if m.group(6) is not None else [m.group(5)])]
        A = AE if name == "AE" else AI
        for j, v in enumerate(vals):
            A[i][j] = v
    vec = {}
    for name in ("b", "d", "cc"):
        m = re.search(r"^%s\s*<-\s*c\(([^)]*)\)" % name, src, re.M)
        vec[name] = [frac(v) for v in m.group(1).split(",")]
    return AE, AI, vec["b"], vec["d"], vec["cc"]

AE, AI, b, d, c = parse()

# ---------- coloured trees ----------
# A coloured tree: tuple of (colour, subtree) children; the root's colour is
# immaterial with shared weights. Colours 0 (E) and 1 (I).
def coloured(shape):
    if shape == ():
        return [()]
    child_options = []
    for ch in shape:
        child_options.append([(col, sub) for col in (0, 1) for sub in coloured(ch)])
    out = set()
    for combo in product(*child_options):
        out.add(tuple(sorted(combo)))
    return sorted(out)

def ctrees(n):
    out = []
    for s in trees_of_order(n):
        out.extend(coloured(s))
    return out

def corder(t):
    return 1 + sum(corder(sub) for _, sub in t)

def cgamma(t):
    g = corder(t)
    for _, sub in t:
        g *= cgamma(sub)
    return g

def csigma(t):
    s, seen = 1, {}
    for ch in t:
        seen[ch] = seen.get(ch, 0) + 1
    for (col, sub), m in seen.items():
        s *= math.factorial(m) * csigma(sub) ** m
    return s

def cphi(As, t):
    s = len(As[0])
    v = [F(1)] * s
    for col, sub in t:
        w = cphi(As, sub)
        A = As[col]
        Aw = [sum(A[i][j] * w[j] for j in range(s)) for i in range(s)]
        v = [v[i] * Aw[i] for i in range(s)]
    return v

def all_explicit(t):
    return all(col == 0 and all_explicit(sub) for col, sub in t)

CT = {n: ctrees(n) for n in range(1, 6)}

def system(As, pmax):
    """Distinct conditions up to order pmax: rows Phi(t), r_k[t] = 1/gamma if |t| = k."""
    seen, rows, rk = set(), [], {k: [] for k in range(1, pmax + 1)}
    for p in range(1, pmax + 1):
        for t in CT[p]:
            ph = cphi(As, t)
            key = (tuple(round(float(x), 14) for x in ph), cgamma(t))
            if key in seen:
                continue
            seen.add(key)
            rows.append(ph)
            for k in range(1, pmax + 1):
                rk[k].append(F(1, cgamma(t)) if k == p else F(0))
    return rows, rk

def weights_ok(As, w, pmax):
    return all(sum(wi * x for wi, x in zip(w, cphi(As, t))) == F(1, cgamma(t))
               for p in range(1, pmax + 1) for t in CT[p])

def cont_res(As, coef, t):
    """coef[k][i]: weight i's theta^k coefficient; the polynomial residual of tree t."""
    ph = cphi(As, t)
    poly = [sum(ck[i] * ph[i] for i in range(len(ph))) for ck in coef]
    p = corder(t)
    while len(poly) <= p:
        poly.append(F(0))
    poly[p] -= F(1, cgamma(t))
    return poly

def peval(poly, x):
    return sum(cf * x ** k for k, cf in enumerate(poly))

def norm_at(As, coef, th, order, which="all"):
    tot = 0.0
    for t in CT[order]:
        if which == "explicit" and not all_explicit(t):
            continue
        e = peval(cont_res(As, coef, t), F(th)) / csigma(t)
        tot += float(e) ** 2
    return math.sqrt(tot)

def weights_norm(As, w, order, which="all"):
    tot = 0.0
    for t in CT[order]:
        if which == "explicit" and not all_explicit(t):
            continue
        e = (sum(wi * x for wi, x in zip(w, cphi(As, t))) - F(1, cgamma(t))) / csigma(t)
        tot += float(e) ** 2
    return math.sqrt(tot)

def section(s):
    print("\n" + "=" * 78 + "\n" + s + "\n" + "=" * 78)

def fmt(x):
    return str(x)

# ---------- checks ----------
section("ARK4(3)6L[2]SA as parsed from " + path)
print("coloured trees by order:", {n: len(CT[n]) for n in CT})
print("row sums against c, largest deviation: AE %.2e, AI %.2e" %
      (max(abs(float(sum(AE[i]) - c[i])) for i in range(6)), max(abs(float(sum(AI[i]) - c[i])) for i in range(6))))
print("AI's last row equals b (stiffly accurate):", AI[5] == b)
As6 = [AE, AI]
print("b, largest coupled residual by order 1-5:", ["%.1e" % worst(As6, b, p) for p in range(1, 6)])
print("d, largest coupled residual by order 1-4:", ["%.1e" % worst(As6, d, p) for p in range(1, 5)])
for nm, A in (("AE", AE), ("AI", AI)):
    c2 = [sum(A[i][j] * c[j] for j in range(6)) - c[i] ** 2 / 2 for i in range(6)]
    c3 = [sum(A[i][j] * c[j] ** 2 for j in range(6)) - c[i] ** 3 / 3 for i in range(6)]
    print(f"{nm}: C(2) residual by stage {[float(x) for x in c2]}")
    print(f"{nm}: C(3) residual by stage {[float(x) for x in c3]}")
print("order-5 norms of b (all colourings / all-explicit): %.4e / %.4e" %
      (weights_norm(As6, b, 5), weights_norm(As6, b, 5, "explicit")))
print("estimate d: order-4 norms (all / explicit): %.4e / %.4e" %
      (weights_norm(As6, d, 4), weights_norm(As6, d, 4, "explicit")))

def analyse(As, label, pmax):
    rows, rk = system(As, pmax)
    s = len(As[0])
    print(f"\n{label}, order {pmax}: {len(rows)} distinct conditions on {s} weights; rank {rank(rows)}")
    ok = True
    for k in range(1, pmax + 1):
        sol = solve_general(rows, rk[k])
        print(f"  theta^{k} part solvable: {sol is not None}" + (f"; null space {len(sol[1])}" if sol else ""))
        ok = ok and sol is not None
    if not ok:
        MT = [list(col) for col in zip(*rows)]
        lw = solve_general(MT, [F(0)] * len(MT))[1]
        polys = []
        for w in lw:
            poly = [F(0)] + [sum(wi * ri for wi, ri in zip(w, rk[k])) for k in range(1, pmax + 1)]
            if any(x != 0 for x in poly):
                polys.append(poly)
        print(f"  {len(polys)} independent solvability polynomials; e.g.",
              " + ".join(f"({float(x):.4g}) th^{k}" for k, x in enumerate(polys[0]) if x != 0) if polys else "")
        # common roots in (0, 1): sample
        if polys:
            grid = [i / 1000 for i in range(1, 1000)]
            vals = [max(abs(float(peval(p, F(g).limit_denominator(1000)))) for p in polys) for g in grid]
            near = [g for g, v in zip(grid, vals) if v < 1e-12]
            print("  theta in (0, 1) where all vanish (to 1e-12 on a 1/1000 grid):", near[:10])
    return ok, rows, rk

section("Q1: the six stages alone, one set of weights for both parts")
ok6_4, _, _ = analyse(As6, "six stages", 4)
ok6_3, _, _ = analyse(As6, "six stages", 3)

section("Q2: the six stages and the step's end (Y7 = y1 in both tableaux, k7 = f(y1))")
AE7 = with_fsal(AE, b)
AI7 = with_fsal(AI, b)
As7 = [AE7, AI7]
ok7_4, rows74, rk74 = analyse(As7, "seven stages", 4)
ok7_3, rows73, rk73 = analyse(As7, "seven stages", 3)

def c1_family(As, rows, rk, pmax, deg):
    """C1 member: b(theta) = sum_{k=1..deg} beta_k theta^k, M beta_k = r_k (k <= pmax,
    and M beta_k = 0 for k > pmax), b'(0) = e1, b(1) = b7, b'(1) = e7."""
    s = len(As[0])
    nU = s * deg
    R, rhs = [], []
    for k in range(1, deg + 1):
        for r, row in enumerate(rows):
            v = [F(0)] * nU
            for i in range(s):
                v[s * (k - 1) + i] = row[i]
            R.append(v)
            rhs.append(rk[k][r] if k <= pmax else F(0))
    b7 = b + [F(0)] * (s - 6)
    for i in range(s):
        v = [F(0)] * nU; v[i] = F(1); R.append(v); rhs.append(F(1) if i == 0 else F(0))
    for i in range(s):
        v = [F(0)] * nU
        for k in range(1, deg + 1):
            v[s * (k - 1) + i] = F(1)
        R.append(v); rhs.append(b7[i])
    for i in range(s):
        v = [F(0)] * nU
        for k in range(1, deg + 1):
            v[s * (k - 1) + i] = F(k)
        R.append(v); rhs.append(F(1) if i == s - 1 else F(0))
    return solve_general(R, rhs)

def coef_of(x, s, deg):
    return [[F(0)] * s] + [x[s * (k - 1): s * k] for k in range(1, deg + 1)]

def minimise(As, x0, null, s, deg, which, th=0.5, order=5):
    """The member of x0 + span(null) least in the order-`order` norm at th (least squares)."""
    if not null:
        return x0
    def resid_vec(x):
        coef = coef_of(x, s, deg)
        out = []
        for t in CT[order]:
            if which == "explicit" and not all_explicit(t):
                continue
            out.append(peval(cont_res(As, coef, t), F(th)) / csigma(t))
        return out
    r0 = resid_vec(x0)
    cols = []
    for v in null:
        x1 = [a + bb for a, bb in zip(x0, v)]
        r1 = resid_vec(x1)
        cols.append([a - bb for a, bb in zip(r1, r0)])
    # normal equations, exact
    G = [[sum(ci[k] * cj[k] for k in range(len(r0))) for cj in cols] for ci in cols]
    g = [-sum(ci[k] * r0[k] for k in range(len(r0))) for ci in cols]
    mu = solve_general(G, g)[0]
    return [x0[j] + sum(mu[q] * null[q][j] for q in range(len(null))) for j in range(len(x0))]

def report(As, coef, s, label):
    def worst_cont(pmax):
        return max(abs(float(v)) for p in range(1, pmax + 1) for t in CT[p] for v in cont_res(As, coef, t))
    b1 = [sum(ck[i] for ck in coef) for i in range(s)]
    db1 = [sum(k * ck[i] for k, ck in enumerate(coef)) for i in range(s)]
    print(f"{label}: largest residual, order <= 3: {worst_cont(3):.1e}, order <= 4: {worst_cont(4):.1e}; "
          f"b(1) - b: {max(abs(float(b1[i] - (b[i] if i < 6 else 0))) for i in range(s)):.1e}; "
          f"b'(0) = e1: {coef[1] == [F(1)] + [F(0)] * (s - 1)}; b'(1) - e{s}: "
          f"{max(abs(float(db1[i] - (1 if i == s - 1 else 0))) for i in range(s)):.1e}")
    for th in (0.25, 0.5, 0.75):
        print("   theta %.2f: order-5 norm all colourings %.4e, all-explicit %.4e; order-4 norm all %.4e, explicit %.4e"
              % (th, norm_at(As, coef, th, 5), norm_at(As, coef, th, 5, "explicit"),
                 norm_at(As, coef, th, 4), norm_at(As, coef, th, 4, "explicit")))

section("Q3: the families and their C1 members")
s = 7
results = {}
for pmax, deg in ((4, 4), (4, 5), (3, 3), (3, 4)):
    sol = c1_family(As7, rows74 if pmax == 4 else rows73, rk74 if pmax == 4 else rk73, pmax, deg)
    print(f"\nC1 member of order {pmax}, degree {deg} in theta, seven stages: exists {sol is not None}"
          + (f"; free parameters {len(sol[1])}" if sol else ""))
    if sol:
        # the leading error: order 5 for an order-4 member, order 4 for an order-3 one
        lead = pmax + 1
        for which in ("explicit", "all"):
            x = minimise(As7, sol[0], sol[1], s, deg, which, order=lead)
            coef = coef_of(x, s, deg)
            report(As7, coef, s, f"  least {which} order-{lead} norm at 1/2")
            results[(pmax, deg, which)] = coef

# The cubic Hermite through y0, f0, y1, f(y1), as weights on the seven stages.
e = lambda i: [F(1) if j == i else F(0) for j in range(7)]
b7 = b + [F(0)]
herm = [[F(0)] * 7, e(0), [3 * b7[j] - 2 * e(0)[j] - e(6)[j] for j in range(7)],
        [e(0)[j] + e(6)[j] - 2 * b7[j] for j in range(7)]]
section("For scale: the cubic Hermite (any pair), CK's quartic, ARK's own estimate")
report(As7, herm, 7, "cubic Hermite on ARK")
A, bck, dck, cck = tableau_ck()
print("CK quartic: order-5 norm at 1/2 %.4e; CK estimate's order-5 norm %.4e" %
      (ta.err5_norm(with_fsal(A, bck), ta.CK_COEF, 0.5), ta.err5_norm_weights(A, dck)))
print("ARK estimate d: order-4 norm all %.4e, explicit %.4e (its leading term; d is order 3)" %
      (weights_norm(As6, d, 4), weights_norm(As6, d, 4, "explicit")))

section("Q4: could one extra stage reach order 4? The order-4 parts' least-squares residuals on the seven stages")
def lsq_residual(M, r):
    """r minus its least-squares projection on M's columns (floats, normal equations in Fractions)."""
    MT = [list(col) for col in zip(*M)]
    G = [[sum(a * bb for a, bb in zip(ci, cj)) for cj in MT] for ci in MT]
    g = [sum(a * bb for a, bb in zip(ci, r)) for ci in MT]
    sol = solve_general(G, g)
    x = sol[0]
    return [r[i] - sum(M[i][j] * x[j] for j in range(len(x))) for i in range(len(r))]
res = [lsq_residual(rows74, rk74[k]) for k in (2, 3, 4)]
print("residual norms of the theta^2, theta^3, theta^4 parts: " +
      ", ".join("%.3e" % math.sqrt(sum(float(v) ** 2 for v in rv)) for rv in res))
# the residuals' own rank: 1 would let one new column (one extra stage) close them all
def gram_rank(vs, tol=1e-9):
    basis = []
    for v in vs:
        w = [float(x) for x in v]
        for q in basis:
            p = sum(a * bb for a, bb in zip(w, q))
            w = [a - p * bb for a, bb in zip(w, q)]
        nrm = math.sqrt(sum(a * a for a in w))
        scale = math.sqrt(sum(float(x) ** 2 for x in v)) or 1
        if nrm > tol * scale:
            basis.append([a / nrm for a in w])
    return len(basis)
print("rank of the three residuals (1 would admit a single extra stage):", gram_rank(res))

# K&C's published dense output can be checked here by entering its b*_ij (theta^1..theta^3).
def rform(coef, name, s):
    print(f"{name} <- rbind(")
    rows = []
    for k in range(1, len(coef)):
        rows.append("  c(" + ", ".join("%.17g" % float(v) for v in coef[k]) + ")")
    print(",\n".join(rows) + ")")
section("Weights for harness/ark436.R (row m: the theta^m coefficient of each stage's weight, stages 1-6 and the end)")
for key, coef in results.items():
    print(f"\n# order {key[0]}, degree {key[1]}, C1, least {key[2]} order-{key[0] + 1} error at theta = 1/2")
    rform(coef, "BARK%d_%d_%s" % key, 7)
