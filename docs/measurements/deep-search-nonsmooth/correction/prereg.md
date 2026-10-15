# A derivative-only correction at the leaf's switch: offline test (registered before the runs)

## The idea

The forward is accurate where the leaf switches. The rate is continuous there, and its
O(h²) error is one the tolerance sees. Only the derivative carries the O(h·jump) error:
the integrator's quadrature of a jump at fraction u of a step,

  E = h·ΔG·φ(u),  φ(u) = Σ_{c_i>u} b_i − (1 − u),

where G is the soil rate's total sensitivity.

So the fix need not spend any forward work. At each located switch, the sweep can
subtract the step's quadrature error. On the tape, that is a term whose value is zero and
whose derivative is −h·φ(u)·[r_new − r_old] at the switch point:
- r_new and r_old are the switching node's contribution to the soil's rates on its two
  arms. The two arms agree in value there and differ in slope.
- In reverse mode the term changes the step's transposed Jacobian, so no forward
  sensitivity is needed.

**What it would cost.**
- The forward: unchanged, bit for bit, except for locating each node's zero. Locating
  uses one-node evaluations, as the split already does.
- The sweep: two one-node evaluations per switch.
- Rows: none.

The deep search's P4 priced this at "+83% of the sweep" by counting two *full*
evaluations per switch. A one-node evaluation is about 1/149 of a full one on dry.

**Estimate:** 14 728 switches × 2 ≈ 200 full-evaluation equivalents against the sweep's
≈ 28 700, so +0.7% of the sweep. Locating them is about +1% of the forward. In all, about
+1% of a gradient run, or less with the targeted rule.

**What it gives up.** The corrected gradient is the leading-order derivative of the
continuous model at these points. It is not the derivative of the run's discrete map, so
central differences of the run's own map miss it by Σc (R6 must change).

## Evidence already in hand

JT part 4 (H2) computed exactly this quantity offline along `TF24_cost_scale`: the
step's quadrature error of the soil rows of G, contracted with the adjoint. Σc(A) − Σc(B)
= −0.173ε, against the measured A − B of −0.176ε. Correcting both runs would therefore
leave about 0.003ε of the 0.176ε nudge on that trait.

## The test: the same computation for every trait

For each of the 50 traits:
- pinned forwards of A (3e-4) and B (2.85e-4) at θ(1 ± 1e-4), as
  `round4/JT/p4G.R` does for `TF24_cost_scale`;
- G at each switch step from central differences;
- E per step;
- c = (θ/J/ε)·λᵀE, with λ from `P4_lam_{A,B}`.

Then:
- **the corrected nudge:** the rms over traits of (A − B) − (Σc(A) − Σc(B));
- **the corrected error against the reference:** each run's gradient minus its Σc,
  against the stopped 3e-5 reference of `lean/` (L1). Uncorrected: A 0.0094, B 0.0428;
  stopped at 3e-4, 0.0205.

*Predicted:*
- the corrected nudge rms ≤ 0.006 (65%);
- the corrected B's error against the reference ≤ 0.015 (60%);
- the corrected A's error stays ≤ 0.012 (70%).

If the corrected nudge stays above 0.012, something besides the quadrature of G's jumps
at the leaf's switches carries the jitter on the other traits, and the correction alone
is not enough.

The ideal correction uses the exact E. The implemented one would use the leading-order
h·ΔG·φ(u) per node, so this test is an upper bound on what it can do.
