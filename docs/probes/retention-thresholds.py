# Where each near-bound threshold bites on develop's retention curve.
#
# Report 5 section 5 imported a dead-gradient mechanism from another branch that
# attributes it to soil_psi_max_ = 1e3, a cap on matric potential. That member does
# not exist on develop; develop floors THETA inside psi_from_soil_moist instead:
#
#   const double t = std::max(soil_moist_, soil_moist_residual);   // 1e-2
#   return a_psi * std::pow(t/soil_moist_sat, -n_psi)/1e6;         // MPa
#
# Constants read from tf24_environment.h at develop. Run: python3 retention-thresholds.py

a_psi, n_psi, sat, res = 1.78e3, 6.57, 0.428, 1e-2
psi_crit = 5.9   # collar critical potential, MPa

psi = lambda th: a_psi * (max(th, res) / sat) ** (-n_psi) / 1e6
dpsi = lambda th: -n_psi * psi(th) / th if th > res else 0.0
theta_at = lambda p: sat * (p * 1e6 / a_psi) ** (-1 / n_psi)

print(f"{'theta':>7} {'psi (MPa)':>12} {'dpsi/dtheta':>14}   note")
for th in [0.428, 0.214, 0.200, 0.160, 0.133, 0.115, 0.100, 0.060, 0.020, 0.010, 0.005]:
    note = ("theta floored: dpsi/dtheta == 0" if th <= res else
            "psi > psi_crit: collar pins" if psi(th) > psi_crit else "")
    print(f"{th:7.3f} {psi(th):12.4g} {dpsi(th):14.4g}   {note}")

print(f"\ncollar pins (psi = {psi_crit} MPa)        at theta = {theta_at(psi_crit):.4f}")
print(f"the other branch's 1e3 MPa ceiling    at theta = {theta_at(1e3):.4f}  (absent on develop)")
print(f"develop's theta floor                 at theta = {res:.4f}")
print(f"\nmeasured operating minimum theta 0.133 -> psi = {psi(0.133):.3f} MPa,"
      f" margin to psi_crit = {psi_crit - psi(0.133):.2f} MPa")
