import numpy as np
from scipy.optimize import brentq
np.set_printoptions(precision=4, suppress=True)
tz = np.trapezoid if hasattr(np, "trapezoid") else np.trapz

# 1. within-crown offset, mean-light model: U ~ e^{-x} on depth x in [0,X], Z uniform
def dc(X):
    x = np.linspace(0, X, 20001); u = np.exp(-x); u /= tz(u, x)
    return tz(u * x, x) / X - 0.5
for X in [0.5, 1, 2, 4]:
    print("dc", X, round(dc(X), 4), "approx -X/12", round(-X / 12, 4))

# 2. acclimation: V = I^gamma, theta = th_top * I / V, u = q V th/(1+th)^2
def delta(gamma, th_top, X=2.0):
    x = np.linspace(0, X, 20001); I = np.exp(-x)
    V = I ** gamma; th = th_top * I / V
    u = V * th / (1 + th) ** 2; u /= tz(u, x)
    return tz(u * x, x) / X - 0.5
print("gamma \\ th_top", [1, 3, 10, 30, 100])
for g in [0, 0.25, 0.5, 0.75, 1.0]:
    print(g, [round(delta(g, t), 3) for t in [1, 3, 10, 30, 100]])
for t in [3, 10, 30, 100]:
    try:
        print("gamma* th_top", t, round(brentq(lambda g: delta(g, t), 0, 0.999), 3))
    except Exception:
        print(t, "none")
for X in [1, 2, 3, 4]:
    print("X", X, "delta(gamma=0,th=30)", round(delta(0, 30, X), 3), "gamma=1", round(delta(1, 30, X), 3),
          "gamma*", round(brentq(lambda g: delta(g, 30, X), 0, 0.999), 3))
