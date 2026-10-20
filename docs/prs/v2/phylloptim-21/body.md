The leaf's solve returns an answer in two dry-soil cases where its
derivatives were refused, so a caller that differentiates a stand,
such as plant's TF24 gradient, had its whole gradient refused there.
First, past the root vulnerability curve's last knot, the solve reads
the curve's integral along its last tangent and then at its limit,
while the derivatives threw `stem_curve_domain`. Second, when the
range of feasible collar water potentials narrows to less than
`GSS_tol_abs`, the solve holds the collar at the middle of the range,
while `collar_at()` refused that case as `determined`.

The derivatives are now those of the values the solve returns. Past
the last knot, the integral's trait derivatives are its derivatives
at the knot, and past the limit those of the limit. When the collar
range has closed, the collar's derivatives are the average of its two
ends' derivatives, and the stem is held at `psi_crit`. Both ends of a
closed range are first refined to the collar's precision, so such a
collar can move by up to 7.6e-5 MPa. `uniroot()` now refuses a
bisection that reaches its iteration limit.

Closes #18, closes #19
