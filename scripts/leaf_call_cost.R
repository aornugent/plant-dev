#   Rscript scripts/leaf_call_cost.R
#
# What the leaf's three entry points cost per call, which is what prices the reverse
# pass's boundary bundle and the collar polish.
#
# CONFIGURATION. plant develop 141dc8df, odelia 854a8e18, built -O2 -DNDEBUG via
# pkgbuild::compile_dll(debug = FALSE). One Leaf at the parameters below, five soil
# layers, area_leaf 2.0, uniform root mass, psi_soil 0.05 to 0.25 MPa, open sky.
# Timings are R-side loops, so each carries one RcppR6 call; the bare field read
# measures that overhead and it is subtracted in the results.
#
# RESULTS, microseconds per call, measured then net of the 5.77 us call:
#   find_root_collar_psi, GSS_tol_abs 1e-3    15.97   10.2
#   the same at 1e-1                          11.35    5.6
#   evaluate_root_collar_psi                   6.74    1.0
#   dprofit_droot_collar_psi                     --    3.5
# So the bundle (four to six dprofit) is 14 to 21 us against a 10.2 us solve, and
# loosening the bracket pays 4.6 us against about 14 us of Newton.

