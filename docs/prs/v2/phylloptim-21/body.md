The leaf's forward solve returns an operating point in two places
where its derivative path refused. Past the root curve's last knot
(6.89 MPa for plant's TF24 root) the forward reads the root table's
tangent and then its cap, G(inf), while the derivative rows threw
`stem_curve_domain`. Where the feasible collar interval is narrower
than `GSS_tol_abs`, the forward holds the collar at the midpoint of
its bounds, while `collar_at()` refused it as `determined`. plant's
TF24 gradient reaches both in dry soil, and refuses whole there.

The rows are now the derivatives of what the forward returns. Past the
last knot the root integral's trait rows are G's at the knot, then
G(inf)'s past the cap; the conductivity read there has none. At a
collapsed interval the collar's rows are the mean of its two bounds',
the stem is held at `psi_crit` with no response to the collar, and a
stem optimum inside its interval is refused by name. Both bounds are
refined to collar precision first, so such a collar moves (by up to
7.6e-5 MPa at plant's settings) and a stem conductance of 1e-30 now
solves. `uniroot()` refuses a bisection that reaches its iteration limit.

Closes #18, closes #19
