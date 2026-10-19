The leaf's forward solve returns an operating point in two places where its derivative path refused. Past the root curve's dry end the forward reads the table's tangent, or its cap, while the derivative rows threw `stem_curve_domain`. Where the feasible collar interval collapses to a point, the forward holds the collar at its midpoint, while `collar_at()` refused it as `determined`. A caller that differentiates a stand (plant's TF24 gradient) meets both on dry rainfall records, and its whole gradient is refused.

The rows are now the derivatives of what the forward returns. Past the dry end they are the last knot's tangent with G's rows at that knot, then G(inf), with `dG/db = Gamma(1 + 1/c)` and a digamma row in `c`; the conductivity floor has no row. At a collapsed interval they are the mean of the two bounds' rows, with the stem at `psi_crit` and no response to the collar, and a stem optimum inside the interval is refused by name. Both bounds of a collapsed interval are first refined to collar precision with `polish_bracket_bound`, as a fixed bound already is, so such a collar moves by up to 2.8e-7 MPa, and a stem conductance of 1e-30 now solves instead of being refused. `uniroot()` now refuses a bisection that reaches its iteration limit (`>=`, as in `uniroot_smooth()`); its `>` check could not fire. The golden outputs are byte-identical.

Closes #18, closes #19

🤖 Generated with [Claude Code](https://claude.com/claude-code)

https://claude.ai/code/session_016CzJXviWCsP18qwJ8cuPwz
