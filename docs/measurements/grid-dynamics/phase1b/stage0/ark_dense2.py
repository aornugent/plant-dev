"""ARK4(3)6L[2]SA, continued: (a) Kennedy & Carpenter's (2003) published dense
output, as recalled (b*_ij, theta^1..theta^3 on the six stages), checked against
the coupled conditions; (b) an order-4 extension with one extra explicit stage
Y8 = y0 + h sum_j (aE_8j kE_j + aI_8j kI_j) over stages 1-7, whose row makes its
column's part outside the seven stages' span parallel to the one obstruction v;
the extension is then unique, C1, and its order-5 error is reported.

  python3 stage0/ark_dense2.py > stage0/ark_dense2.txt
"""
import sys, io, contextlib, math
from fractions import Fraction as F
sys.path.insert(0, __file__.rsplit("/", 1)[0])
with contextlib.redirect_stdout(io.StringIO()):
    import ark_dense as ad
AE, AI, b, d, c = ad.AE, ad.AI, ad.b, ad.d, ad.c
CT, cphi, cgamma, csigma, corder = ad.CT, ad.cphi, ad.cgamma, ad.csigma, ad.corder
system, solve_general, rank = ad.system, ad.solve_general, ad.rank

def section(s):
    print("\n" + "=" * 78 + "\n" + s + "\n" + "=" * 78)

def worst_cont(As, coef, pmax):
    return max(abs(float(v)) for p in range(1, pmax + 1) for t in CT[p] for v in ad.cont_res(As, coef, t))

def norms(As, coef, th, order):
    return ad.norm_at(As, coef, th, order), ad.norm_at(As, coef, th, order, "explicit")

# ---------------- (a) K&C's dense output ----------------
section("(a) Kennedy & Carpenter's dense output for ARK4(3)6L[2]SA (b*_ij as recalled)")
bstar = [
    [F(6943876665148, 7220017795957), F(-54480133, 30881146), F(6818779379841, 7100303317025)],
    [F(0), F(0), F(0)],
    [F(7640104374378, 9702883013639), F(-11436875, 14766696), F(2173542590792, 12501825683035)],
    [F(-20649996744609, 7521556579894), F(174696575, 18121608), F(-31592104683404, 5083833661969)],
    [F(8854892464581, 2390941311638), F(-12120380, 966161), F(61146701046299, 7138195549469)],
    [F(-11397109935349, 6675773540249), F(3843, 706), F(-17219254887155, 4939391667607)]]
As6 = [AE, AI]
kc = [[F(0)] * 6] + [[bstar[i][k] for i in range(6)] for k in range(3)]
print("sum_j b*_ij - b_i (b(1) = b): %.2e" % max(abs(float(sum(bstar[i]) - b[i])) for i in range(6)))
print("largest coupled residual, order <= 2: %.2e, order <= 3: %.2e, order <= 4: %.2e" %
      (worst_cont(As6, kc, 2), worst_cont(As6, kc, 3), worst_cont(As6, kc, 4)))
db1 = [sum((k + 1) * bstar[i][k] for k in range(3)) for i in range(6)]
print("b'(1) on the six stages (C1 would need the end's rate, which it does not use):",
      ["%.3f" % float(x) for x in db1])
for th in (0.25, 0.5, 0.75):
    n4 = norms(As6, kc, th, 4)
    print("  theta %.2f: order-4 norm all colourings %.4e, all-explicit %.4e" % (th, n4[0], n4[1]))

# ---------------- (b) one extra stage for order 4 ----------------
section("(b) order 4 with one extra explicit stage (rows over stages 1-7, a_88 = 0 in both parts)")
AE7, AI7 = ad.with_fsal(AE, b), ad.with_fsal(AI, b)
rows7, rk7 = system([AE7, AI7], 4)
n = len(rows7)

def floatmat(M):
    return [[float(x) for x in row] for row in M]

# projection onto the complement of the seven stages' columns (floats suffice here)
def lstsq_proj(M, r):
    MT = list(zip(*M))
    G = [[sum(a * bb for a, bb in zip(ci, cj)) for cj in MT] for ci in MT]
    g = [sum(a * bb for a, bb in zip(ci, r)) for ci in MT]
    x = gauss(G, g)
    return [r[i] - sum(M[i][j] * x[j] for j in range(len(x))) for i in range(len(r))]

def gauss(A, y):
    A = [row[:] + [v] for row, v in zip(A, y)]
    m = len(A)
    for col in range(m):
        p = max(range(col, m), key=lambda i: abs(A[i][col]))
        A[col], A[p] = A[p], A[col]
        for i in range(m):
            if i != col:
                f = A[i][col] / A[col][col]
                A[i] = [a - f * bb for a, bb in zip(A[i], A[col])]
    return [A[i][m] / A[i][i] for i in range(m)]

M7f = floatmat(rows7)
v = lstsq_proj(M7f, [float(x) for x in rk7[2]])
nv = math.sqrt(sum(x * x for x in v)); v = [x / nv for x in v]
for k in (3, 4):
    rk = lstsq_proj(M7f, [float(x) for x in rk7[k]])
    print("theta^%d residual = %.6f v (orthogonal remainder %.2e)" %
          (k, sum(a * bb for a, bb in zip(rk, v)) * nv / nv, math.sqrt(max(0.0, sum(x * x for x in rk) - sum(a * bb for a, bb in zip(rk, v)) ** 2))))

def column(a8E, a8I):
    """The extra stage's column over the order-4 conditions (exact)."""
    AE8 = [row[:] + [F(0)] for row in AE7] + [a8E + [F(0)]]
    AI8 = [row[:] + [F(0)] for row in AI7] + [a8I + [F(0)]]
    rows8, rk8 = system([AE8, AI8], 4)
    return [r[7] for r in rows8], rows8, rk8, AE8, AI8

def construct(c8):
    # a8 = base + sum_k t_k e_k: base c8 e1 in both parts; e_k keep the row sums.
    base = [F(c8)] + [F(0)] * 6
    dirs = []
    for part in (0, 1):
        for j in range(1, 7):
            e = [F(0)] * 7; e[0] = F(-1); e[j] = F(1)
            dirs.append((part, e))
    col0 = [float(x) for x in column(base, base)[0]]
    D = []
    for part, e in dirs:
        aE = [x + y for x, y in zip(base, e)] if part == 0 else base
        aI = [x + y for x, y in zip(base, e)] if part == 1 else base
        colk = [float(x) for x in column(aE, aI)[0]]
        D.append([a - bb for a, bb in zip(colk, col0)])
    # Q P col = 0 with P the complement projection and Q removing v: minimum-norm t.
    def QP(x):
        r = lstsq_proj(M7f, x)
        pv = sum(a * bb for a, bb in zip(r, v))
        return [a - pv * bb for a, bb in zip(r, v)]
    q0 = QP(col0)
    Qd = [QP(dk) for dk in D]                     # 12 columns
    # min ||t|| s.t. sum_k t_k Qd_k = -q0 : t = Qd^T (Qd Qd^T)^+ (-q0), via normal eqs on the
    # span (ridge-regularised a hair for the rank deficiency of the 14-row system)
    m = len(q0)
    G = [[sum(Qd[k][i] * Qd[k][j] for k in range(12)) + (1e-14 if i == j else 0.0) for j in range(m)] for i in range(m)]
    z = gauss(G, [-x for x in q0])
    t = [sum(Qd[k][i] * z[i] for i in range(m)) for k in range(12)]
    aE = [float(x) for x in base]; aI = [float(x) for x in base]
    for tk, (part, e) in zip(t, dirs):
        tgt = aE if part == 0 else aI
        for j in range(7):
            tgt[j] += tk * float(e[j])
    aEf = [F(x) for x in aE]
    aIf = [F(x) for x in aI]
    aEf[0] += F(c8) - sum(aEf); aIf[0] += F(c8) - sum(aIf)   # exact row sums
    col, rows8, rk8, AE8, AI8 = column(aEf, aIf)
    pc = lstsq_proj(M7f, [float(x) for x in col])
    along = sum(a * bb for a, bb in zip(pc, v))
    off = math.sqrt(max(0.0, sum(x * x for x in pc) - along ** 2))
    # the order-4 weights, degree 4, by least squares on the 8-stage system (floats)
    M8f = floatmat(rows8)
    MT = list(zip(*M8f))
    G8 = [[sum(a * bb for a, bb in zip(ci, cj)) for cj in MT] for ci in MT]
    coef = [[F(0)] * 8]
    worst_r = 0.0
    for k in range(1, 5):
        rk = [float(x) for x in rk8[k]]
        x = gauss(G8, [sum(a * bb for a, bb in zip(ci, rk)) for ci in MT])
        worst_r = max(worst_r, max(abs(sum(M8f[i][j] * x[j] for j in range(8)) - rk[i]) for i in range(len(rk))))
        coef.append([F(xx) for xx in x])
    return dict(c8=c8, aE=aEf, aI=aIf, along=along, off=off, coef=coef, lsq=worst_r, As=[AE8, AI8])

best = None
for c8 in (F(1, 4), F(2, 5), F(1, 2), F(3, 5), F(3, 4)):
    r = construct(c8)
    if r is None:
        print("c8 = %s: no order-4 solution" % c8)
        continue
    As8, coef = r["As"], r["coef"]
    n5 = norms(As8, coef, 0.5, 5)
    db1 = [sum(k * ck[i] for k, ck in enumerate(coef)) for i in range(8)]
    r["n5"] = n5
    print("c8 = %-4s: column along v %.3g, off v %.1e; order-4 residual %.1e (lsq %.1e); C1 (b'(1) - e7) %.1e; row norms |aE| %.2f |aI| %.2f; "
          "order-5 norm at 1/2: all %.4e, explicit %.4e; |b(theta)| coefficients max %.2f" %
          (c8, r["along"], r["off"], worst_cont(As8, coef, 4), r["lsq"],
           max(abs(float(db1[i] - (1 if i == 6 else 0))) for i in range(8)),
           math.sqrt(sum(float(x) ** 2 for x in r["aE"])), math.sqrt(sum(float(x) ** 2 for x in r["aI"])),
           n5[0], n5[1], max(abs(float(x)) for ck in coef for x in ck)))
    if r["lsq"] < 1e-9 and (best is None or n5[0] < best["n5"][0]):
        best = r

print("\nfor scale, order-5 norms at 1/2: ARK's propagated solution b: all %.4e, explicit %.4e; CK's quartic %.4e; DP's contd5 %.4e"
      % (ad.weights_norm([AE, AI], b, 5), ad.weights_norm([AE, AI], b, 5, "explicit"), 1.2862e-3, 4.0426e-4))

section("The extra stage and the order-4 weights for harness/ark436.R (stages 1-6, the end, the extra stage)")
print("# c8 = %s; its rows over stages 1-7 (the end is stage 7), explicit then implicit part" % best["c8"])
print("cARK8 <- %s" % best["c8"])
print("aE8 <- c(" + ", ".join("%.17g" % float(x) for x in best["aE"]) + ")")
print("aI8 <- c(" + ", ".join("%.17g" % float(x) for x in best["aI"]) + ")")
print("BARK4_8 <- rbind(")
print(",\n".join("  c(" + ", ".join("%.17g" % float(x) for x in best["coef"][k]) + ")" for k in range(1, 5)) + ")")
