"""Stage 0, exact rational arithmetic.

(b) Dormand-Prince 5(4): the order conditions of b (order 5), bhat (order 4,
    not 5), the row sums, FSAL, and the continuous extension of Hairer's contd5
    (order-4 conditions as polynomial identities in theta, and its Hermite ends).
(a) Cash-Karp: is there an order-4 continuous extension b(theta) from the six
    stages alone, and from the six stages plus k7 = f(y1) (a7j = b_j, c7 = 1)?
    If so, the C1 quartic one (b(0)=0, b'(0)=e1, b(1)=b, b'(1)=e7) and its
    free parameter, chosen to minimise the order-5 error norm at theta = 1/2.

    python3 tableau_algebra.py > tableau_algebra.txt
"""
from fractions import Fraction as F
from itertools import combinations_with_replacement
import math

# ---------- rooted trees up to order 5 ----------
# A tree is a sorted tuple of its children (trees); () is the single node.
def trees_of_order(n, memo={}):
    if n in memo:
        return memo[n]
    if n == 1:
        memo[1] = [()]
        return memo[1]
    out = set()
    # partitions of n-1 into children orders
    def parts(m, maxp):
        if m == 0:
            yield []
            return
        for p in range(min(m, maxp), 0, -1):
            for rest in parts(m - p, p):
                yield [p] + rest
    for part in parts(n - 1, n - 1):
        # choose a tree for each part, unordered
        def build(idx, acc):
            if idx == len(part):
                out.add(tuple(sorted(acc)))
                return
            for t in trees_of_order(part[idx]):
                build(idx + 1, acc + [t])
        build(0, [])
    memo[n] = sorted(out)
    return memo[n]

def order(t):
    return 1 + sum(order(c) for c in t)

def gamma(t):
    g = order(t)
    for c in t:
        g *= gamma(c)
    return g

def sigma(t):
    s = 1
    seen = {}
    for c in t:
        seen[c] = seen.get(c, 0) + 1
    for c, m in seen.items():
        s *= math.factorial(m) * sigma(c) ** m
    return s

TREES = {n: trees_of_order(n) for n in range(1, 7)}

def phi(A, t):
    """Elementary weights Phi_i(t), i = 1..s, for the tableau A (list of rows)."""
    s = len(A)
    v = [F(1)] * s
    for c in t:
        w = phi(A, c)
        Aw = [sum(A[i][j] * w[j] for j in range(s)) for i in range(s)]
        v = [v[i] * Aw[i] for i in range(s)]
    return v

def residuals(A, b, p):
    """sum_i b_i Phi_i(t) - 1/gamma(t) for every tree of order p."""
    return [sum(bi * x for bi, x in zip(b, phi(A, t))) - F(1, gamma(t)) for t in TREES[p]]

# ---------- exact linear algebra ----------
def rref(M):
    M = [row[:] for row in M]
    rows, cols = len(M), len(M[0])
    piv = []
    r = 0
    for c in range(cols):
        p = next((i for i in range(r, rows) if M[i][c] != 0), None)
        if p is None:
            continue
        M[r], M[p] = M[p], M[r]
        pv = M[r][c]
        M[r] = [x / pv for x in M[r]]
        for i in range(rows):
            if i != r and M[i][c] != 0:
                f = M[i][c]
                M[i] = [a - f * b for a, b in zip(M[i], M[r])]
        piv.append(c)
        r += 1
        if r == rows:
            break
    return M, piv

def rank(M):
    return len(rref(M)[1])

def solve_general(M, rhs):
    """A particular solution and a null-space basis of M x = rhs, or None."""
    cols = len(M[0])
    aug = [row[:] + [r] for row, r in zip(M, rhs)]
    R, piv = rref(aug)
    if cols in piv:
        return None
    x = [F(0)] * cols
    for i, c in enumerate(piv):
        x[c] = R[i][cols]
    free = [c for c in range(cols) if c not in piv]
    null = []
    for f in free:
        v = [F(0)] * cols
        v[f] = F(1)
        for i, c in enumerate(piv):
            v[c] = -R[i][f]
        null.append(v)
    return x, null

def fmt(x):
    return str(x) if isinstance(x, F) else repr(x)

# ---------- tableaux ----------
def tableau_ck():
    A = [[F(0)] * 6 for _ in range(6)]
    A[1][0] = F(1, 5)
    A[2][:2] = [F(3, 40), F(9, 40)]
    A[3][:3] = [F(3, 10), F(-9, 10), F(6, 5)]
    A[4][:4] = [F(-11, 54), F(5, 2), F(-70, 27), F(35, 27)]
    A[5][:5] = [F(1631, 55296), F(175, 512), F(575, 13824), F(44275, 110592), F(253, 4096)]
    b = [F(37, 378), F(0), F(250, 621), F(125, 594), F(0), F(512, 1771)]
    d = [F(2825, 27648), F(0), F(18575, 48384), F(13525, 55296), F(277, 14336), F(1, 4)]
    c = [F(0), F(1, 5), F(3, 10), F(3, 5), F(1), F(7, 8)]
    return A, b, d, c

def tableau_dp():
    A = [[F(0)] * 7 for _ in range(7)]
    A[1][0] = F(1, 5)
    A[2][:2] = [F(3, 40), F(9, 40)]
    A[3][:3] = [F(44, 45), F(-56, 15), F(32, 9)]
    A[4][:4] = [F(19372, 6561), F(-25360, 2187), F(64448, 6561), F(-212, 729)]
    A[5][:5] = [F(9017, 3168), F(-355, 33), F(46732, 5247), F(49, 176), F(-5103, 18656)]
    b = [F(35, 384), F(0), F(500, 1113), F(125, 192), F(-2187, 6784), F(11, 84), F(0)]
    A[6][:6] = b[:6]
    bh = [F(5179, 57600), F(0), F(7571, 16695), F(393, 640), F(-92097, 339200), F(187, 2100), F(1, 40)]
    c = [F(0), F(1, 5), F(3, 10), F(4, 5), F(8, 9), F(1), F(1)]
    dd = [F(-12715105075, 11282082432), F(0), F(87487479700, 32700410799),
          F(-10690763975, 1880347072), F(701980252875, 199316789632),
          F(-1453857185, 822651844), F(69997945, 29380423)]
    return A, b, bh, c, dd

def with_fsal(A, b):
    s = len(A)
    A7 = [row[:] + [F(0)] for row in A] + [b[:] + [F(0)]]
    return A7

# polynomial coefficient vectors: b_i(theta) = sum_k coef[k][i] theta^k, k = 0..deg
def cont_residuals(A, coef, pmax):
    """For each tree up to pmax, the polynomial sum_i b_i(theta) Phi_i(t) -
    theta^|t|/gamma(t), as its coefficient list."""
    out = {}
    for p in range(1, pmax + 1):
        for t in TREES[p]:
            ph = phi(A, t)
            poly = [sum(ck[i] * ph[i] for i in range(len(ph))) for ck in coef]
            while len(poly) <= p:
                poly.append(F(0))
            poly[p] -= F(1, gamma(t))
            out[t] = poly
    return out

def poly_eval(poly, x):
    return sum(c * x ** k for k, c in enumerate(poly))

def err5_norm(A, coef, theta):
    """2-norm of the order-5 local error coefficients of the continuous
    extension at theta: (1/sigma(t)) (sum_i b_i(theta) Phi_i(t) - theta^5/gamma(t))."""
    tot = 0.0
    for t in TREES[5]:
        ph = phi(A, t)
        val = sum(poly_eval([ck[i] for ck in coef], F(theta)) * ph[i] for i in range(len(ph)))
        e = (val - F(theta) ** 5 / gamma(t)) / sigma(t)
        tot += float(e) ** 2
    return math.sqrt(tot)

def err5_norm_weights(A, w):
    tot = 0.0
    for t in TREES[5]:
        ph = phi(A, t)
        e = (sum(wi * x for wi, x in zip(w, ph)) - F(1, gamma(t))) / sigma(t)
        tot += float(e) ** 2
    return math.sqrt(tot)

def section(title):
    print("\n" + "=" * 78 + "\n" + title + "\n" + "=" * 78)

# =============================================================================
section("Trees: number of rooted trees by order " +
        str({n: len(TREES[n]) for n in range(1, 6)}))

# ---------------------------- (b) Dormand-Prince ----------------------------
section("(b) Dormand-Prince 5(4), the coefficients as given")
A, b, bh, c, dd = tableau_dp()
rs = [sum(row) - ci for row, ci in zip(A, c)]
print("row sums minus c (all zero?):", all(x == 0 for x in rs))
print("FSAL row 7 equals b:", A[6][:6] == b[:6] and b[6] == 0)
for p in range(1, 6):
    r = residuals(A, b, p)
    print(f"b, order {p}: {len(r)} conditions, all exact: {all(x == 0 for x in r)}")
for p in range(1, 6):
    r = residuals(A, bh, p)
    print(f"bhat, order {p}: {len(r)} conditions, all exact: {all(x == 0 for x in r)}"
          + ("" if p < 5 else f"; residuals {[fmt(x) for x in r]}"))
r6 = residuals(A, b, 6)
print(f"b, order 6: {sum(x != 0 for x in r6)} of {len(r6)} conditions fail (so b is exactly order 5)")
print("error coefficient norms, order 5: bhat (the estimate's leading term) %.4e" %
      err5_norm_weights(A, bh))
tot6 = math.sqrt(sum(float(e / sigma(t)) ** 2 for t, e in zip(TREES[6], r6)))
print("order 6 error coefficient norm of b (the propagated solution): %.4e" % tot6)

# Dense output b_i(theta) from contd5.
def dp_dense_coef(b, dd):
    # b_i(theta) = th b_i + th(1-th)(d1i - b_i) + th^2(1-th)(2b_i - d1i - d7i) + th^2(1-th)^2 dd_i
    s = 7
    coef = [[F(0)] * s for _ in range(5)]
    for i in range(s):
        e1 = F(1) if i == 0 else F(0)
        e7 = F(1) if i == 6 else F(0)
        # th b
        coef[1][i] += b[i]
        # th(1-th)(e1 - b) = (th - th^2)(e1 - b)
        coef[1][i] += e1 - b[i]
        coef[2][i] -= e1 - b[i]
        # th^2(1-th)(2b - e1 - e7) = (th^2 - th^3) q
        q = 2 * b[i] - e1 - e7
        coef[2][i] += q
        coef[3][i] -= q
        # th^2(1-th)^2 dd = (th^2 - 2th^3 + th^4) dd
        coef[2][i] += dd[i]
        coef[3][i] -= 2 * dd[i]
        coef[4][i] += dd[i]
    return coef

coef = dp_dense_coef(b, dd)
res = cont_residuals(A, coef, 5)
ok4 = all(all(x == 0 for x in res[t]) for p in range(1, 5) for t in TREES[p])
print("\ncontd5 dense output: order-4 continuous conditions hold identically in theta:", ok4)
b0 = [sum(ck[i] * 0 ** k for k, ck in enumerate(coef)) for i in range(7)]
b1 = [sum(ck[i] for ck in coef) for i in range(7)]
db0 = [coef[1][i] for i in range(7)]
db1 = [sum(k * ck[i] for k, ck in enumerate(coef)) for i in range(7)]
print("  b(0) = 0:", all(x == 0 for x in b0), "; b(1) = b:", b1 == b,
      "; b'(0) = e1:", db0 == [F(1)] + [F(0)] * 6, "; b'(1) = e7:", db1 == [F(0)] * 6 + [F(1)])
fail5 = [t for t in TREES[5] if any(x != 0 for x in res[t])]
print(f"  order-5 conditions failing (so the extension is exactly order 4): {len(fail5)} of {len(TREES[5])}")
for th in (0.25, 0.5, 0.75):
    print("  order-5 error norm at theta = %.2f: %.4e  (ratio to the estimate's %.3f)" %
          (th, err5_norm(A, coef, th), err5_norm(A, coef, th) / err5_norm_weights(A, bh)))
DP_COEF = coef

# ------------------------------ (a) Cash-Karp ------------------------------
section("(a) Cash-Karp: simplifying assumptions")
A, b, d, c = tableau_ck()
for i in range(6):
    C2 = sum(A[i][j] * c[j] for j in range(6)) - c[i] ** 2 / 2
    C3 = sum(A[i][j] * c[j] ** 2 for j in range(6)) - c[i] ** 3 / 3
    print(f"stage {i+1}: C(2) residual {fmt(C2)}, C(3) residual {fmt(C3)}")
print("sum_i b_i a_i2 =", fmt(sum(b[i] * A[i][1] for i in range(6))),
      "; sum_i d_i a_i2 =", fmt(sum(d[i] * A[i][1] for i in range(6))))
for p in range(1, 6):
    print(f"b order {p} exact: {all(x == 0 for x in residuals(A, b, p))};"
          f" d order {p} exact: {all(x == 0 for x in residuals(A, d, p))}")
print("estimate's order-5 error norm (d): %.4e" % err5_norm_weights(A, d))

def cont_system(A, pmax):
    """Rows: trees up to pmax; M[t][i] = Phi_i(t); r_k[t] = 1/gamma(t) if |t| = k."""
    rows, rk = [], {k: [] for k in range(1, pmax + 1)}
    for p in range(1, pmax + 1):
        for t in TREES[p]:
            rows.append(phi(A, t))
            for k in range(1, pmax + 1):
                rk[k].append(F(1, gamma(t)) if k == p else F(0))
    return rows, rk

section("(a) Cash-Karp, six stages: an order-4 continuous extension?")
M6, rk6 = cont_system(A, 4)
print("rank of the 8 x 6 order-4 system:", rank(M6))
for k in range(1, 5):
    sol = solve_general(M6, rk6[k])
    print(f"  theta^{k} part solvable: {sol is not None}")
# At which theta is M b = r(theta) solvable? r(theta) = sum_k theta^k r_k.
# Left null space of M6: w with w^T M6 = 0; solvable iff w^T r(theta) = 0.
MT = [list(col) for col in zip(*M6)]
lw = solve_general(MT, [F(0)] * len(MT))
for w in lw[1]:
    poly = [F(0)] + [sum(wi * ri for wi, ri in zip(w, rk6[k])) for k in range(1, 5)]
    if any(x != 0 for x in poly):
        print("  a left null vector gives the solvability polynomial in theta:",
              " + ".join(f"({fmt(x)}) th^{k}" for k, x in enumerate(poly) if x != 0))
        # roots in (0, 1): poly / theta^2 is quadratic here
        q = poly[2:]
        while q and q[-1] == 0:
            q.pop()
        if len(q) == 3:
            a2, a1, a0 = q[2], q[1], q[0]
            disc = a1 * a1 - 4 * a2 * a0
            rts = [(-a1 + sgn * math.sqrt(float(disc))) / (2 * float(a2)) for sgn in (1, -1)]
            print("  roots of poly / theta^2:", ["%.6f" % x for x in rts])

section("(a) Cash-Karp with k7 = f(y1): an order-4 continuous extension?")
A7 = with_fsal(A, b)
M7, rk7 = cont_system(A7, 4)
print("rank of the 8 x 7 order-4 system:", rank(M7))
ok = True
for k in range(1, 5):
    sol = solve_general(M7, rk7[k])
    print(f"  theta^{k} part solvable: {sol is not None}; null space dimension "
          f"{len(sol[1]) if sol else '-'}")
    ok = ok and sol is not None
null = solve_general(M7, [F(0)] * len(M7))[1]
print("  null vector(s):", [[fmt(x) for x in v] for v in null])
bmd = [bi - di for bi, di in zip(b, d)] + [F(0)]
print("  is b - d (k7 weight 0) in the null space:",
      all(x == 0 for x in [sum(row[i] * bmd[i] for i in range(7)) for row in M7]))

# The C1 quartic: b(theta) = sum_{k=1..4} beta_k theta^k, beta_k in Q^7.
# Unknowns x = (beta_1, ..., beta_4) (28). Constraints:
#   M7 beta_k = r_k (k = 1..4); beta_1 = e1; sum beta_k = b7; sum k beta_k = e7.
section("(a) Cash-Karp with k7: the C1 quartic family")
b7 = b + [F(0)]
nU = 28
rows, rhs = [], []
def unit(k, i):
    v = [F(0)] * nU
    v[7 * (k - 1) + i] = F(1)
    return v
for k in range(1, 5):
    for r, row in enumerate(M7):
        v = [F(0)] * nU
        for i in range(7):
            v[7 * (k - 1) + i] = row[i]
        rows.append(v); rhs.append(rk7[k][r])
for i in range(7):
    rows.append(unit(1, i)); rhs.append(F(1) if i == 0 else F(0))
for i in range(7):
    v = [F(0)] * nU
    for k in range(1, 5):
        v[7 * (k - 1) + i] = F(1)
    rows.append(v); rhs.append(b7[i])
for i in range(7):
    v = [F(0)] * nU
    for k in range(1, 5):
        v[7 * (k - 1) + i] = F(k)
    rows.append(v); rhs.append(F(1) if i == 6 else F(0))
sol = solve_general(rows, rhs)
print("C1 quartic exists:", sol is not None)
x0, nullq = sol
print("free parameters in the C1 quartic family:", len(nullq))

def coef_of(x):
    return [[F(0)] * 7] + [x[7 * (k - 1): 7 * k] for k in range(1, 5)]

# minimise the order-5 error norm at theta = 1/2 over the free parameter(s)
# (a quadratic in mu): sample three points, take the vertex.
def norm_mu(mu, th=0.5):
    x = [x0[j] + sum(F(mu[q]).limit_denominator(10**12) * nullq[q][j] for q in range(len(nullq)))
         for j in range(nU)]
    return err5_norm(A7, coef_of(x), th)
if len(nullq) == 1:
    f0, f1, fm = norm_mu([0]) ** 2, norm_mu([1]) ** 2, norm_mu([-1]) ** 2
    a2 = (f1 + fm - 2 * f0) / 2; a1 = (f1 - fm) / 2
    mu_star = -a1 / (2 * a2)
    print("mu minimising the order-5 norm at theta = 1/2: %.10f" % mu_star)
    # a simple rational near the optimum, for the record
    mu_r = F(mu_star).limit_denominator(1000)
    x = [x0[j] + mu_r * nullq[0][j] for j in range(nU)]
else:
    mu_r = None
    x = x0
CK_COEF = coef_of(x)
res = cont_residuals(A7, CK_COEF, 5)
print("chosen mu (rational):", fmt(mu_r))
print("order-4 continuous conditions hold identically:",
      all(all(v == 0 for v in res[t]) for p in range(1, 5) for t in TREES[p]))
bb0 = [sum(ck[i] for ck in CK_COEF) for i in range(7)]
print("b(1) = b:", bb0 == b7, "; b'(0) = e1:", CK_COEF[1] == [F(1)] + [F(0)] * 6,
      "; b'(1) = e7:", [sum(k * ck[i] for k, ck in enumerate(CK_COEF)) for i in range(7)] == [F(0)] * 6 + [F(1)])
print("b_2(theta) identically zero:", all(ck[1] == 0 for ck in CK_COEF))
for th in (0.25, 0.5, 0.75):
    print("  order-5 error norm at theta = %.2f: %.4e  (ratio to the estimate's %.3f)" %
          (th, err5_norm(A7, CK_COEF, th), err5_norm(A7, CK_COEF, th) / err5_norm_weights(A, d)))
print("\nCK C1 quartic weights b_i(theta) = sum_k beta_k[i] theta^k (exact):")
for k in range(1, 5):
    print(f"  theta^{k}:", [fmt(v) for v in CK_COEF[k]])
print("as doubles (for the driver):")
for k in range(1, 5):
    print(f"  theta^{k}: c(" + ", ".join("%.17g" % float(v) for v in CK_COEF[k]) + ")")

# the cubic Hermite's order-5... (it is order 3): its order-4 residual norm at 1/2, for scale
section("For scale: DP's contd5 and the CK quartic, order-5 error norm over theta")
for th in (0.1, 0.25, 0.5, 0.75, 0.9):
    print("  theta %.2f: DP %.4e   CK %.4e" % (th, err5_norm(tableau_dp()[0], DP_COEF, th),
                                              err5_norm(A7, CK_COEF, th)))
print("estimates' order-5 norms: DP bhat %.4e, CK d %.4e" %
      (err5_norm_weights(tableau_dp()[0], tableau_dp()[2]), err5_norm_weights(A, d)))
print("propagated solutions' order-6 norms: DP b %.4e, CK b %.4e" % (
    math.sqrt(sum(float(e / sigma(t)) ** 2 for t, e in zip(TREES[6], residuals(tableau_dp()[0], tableau_dp()[1], 6)))),
    math.sqrt(sum(float(e / sigma(t)) ** 2 for t, e in zip(TREES[6], residuals(A, b, 6))))))
