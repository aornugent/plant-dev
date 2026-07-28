# Is the zero-flux leaf state the limit of the transpiring state?
#
# set_leaf_states_rates_from_psi_stem has two branches:
#   psi_upstream >= psi_stem  ->  ci_ = gamma_*umol_per_mol_to_Pa, transpiration_ = 0
#   otherwise                 ->  ci_ = psi_stem_to_ci(...), i.e. the root of
#                                 A_net(ci)*umol_to_mol = gc*(ca-ci)/atm
#
# As gc -> 0+ the second branch's root goes to where A_net(ci) = 0, NOT to
# gamma_ (where A_gross = 0, so A_net = -R_d). If so the two branches disagree
# by exactly R_d and the objective jumps by R_d at the zero-flux boundary.
#
# This checks all three numbers against develop.
#   Rscript scripts/branch_limit_probe.R

suppressMessages({ library(odelia); pkgload::load_all("plant", quiet = TRUE) })

umol_per_mol_to_Pa <- 0.1013

l <- Leaf(vcmax_25 = 100, jmax_25 = 100 * 167, c = 2.04, b = 3, psi_crit = 5,
          root_c = 2.65, root_b = 1.29,
          root_psi_crit = 1.29 * (log(1 / 0.05))^(1 / 2.65),
          beta2 = 1, a = 0.3, curv_fact_elec_trans = 0.7, curv_fact_colim = 0.99,
          GSS_tol_abs = 1e-10, vulnerability_curve_ncontrol = 100,
          ci_abs_tol = 1e-8, ci_niter = 1000, g1_TF24 = 46.32995,
          beta_R_H = 3.4e3, beta_R_V = 9.4e4)
th <- 0.000157; h <- 5
l$set_physiology(area_leaf = 0.05, mass_root_prop = 1, rho = 608, a_bio = 0.0245,
                 PPFD = 900, psi_soil = 2.0, soil_depth = 1,
                 leaf_specific_conductance_max = 1 * th / h, atm_vpd = 2, ca = 40,
                 sapwood_volume_per_leaf_area = th * h, leaf_temp = 25,
                 atm_o2_kpa = 21, atm_kpa = 101.3)

gstar <- l$gamma_ * umol_per_mol_to_Pa
Rd    <- l$R_d_
vc    <- l$vcmax_
et    <- l$electron_transport_
km    <- l$km_
curv  <- 0.99

cat("=== 1. the no-flux branch's ci, and R_d ===\n")
cat(sprintf("gamma_ = %.6f  ->  gamma_*umol_per_mol_to_Pa = %.6f   (probe shelf ci: 4.3306)\n",
            l$gamma_, gstar))
cat(sprintf("vcmax_ = %.6f   R_d_ = vcmax_*0.015 = %.6f          (probe profit jump: 1.5000)\n",
            vc, Rd))
cat(sprintf("net assimilation at ci = gstar: %.8f  (should be exactly -R_d)\n",
            l$assim_colimited(gstar)))

cat("\n=== 2. the limit of the transpiring branch: where net assimilation is zero ===\n")
f <- function(ci) l$assim_colimited(ci)
ci_net0 <- uniroot(f, c(gstar + 1e-9, l$assim_max_ * 0 + 39.9), tol = 1e-12)$root
cat(sprintf("root of A_net(ci) = 0 (numeric): ci = %.6f            (probe live-branch ci: 5.4910)\n",
            ci_net0))

# closed form: A_net = 0  <=>  ar*ae - R_d*(ar+ae) + curv*R_d^2 = 0, with
#   ar = vc*(ci-g)/(ci+km),  ae = (et/4)*(ci-g)/(ci+2g)
# multiplied out this is a quadratic in ci.
A <- vc * (et / 4) - Rd * (vc + et / 4) + curv * Rd^2
B <- -2 * gstar * vc * (et / 4) - Rd * (vc * (2 * gstar - gstar) + (et / 4) * (km - gstar)) +
     curv * Rd^2 * (km + 2 * gstar)
C <- gstar^2 * vc * (et / 4) + Rd * gstar * (vc * 2 * gstar + (et / 4) * km) +
     curv * Rd^2 * km * 2 * gstar
disc <- B^2 - 4 * A * C
if (disc >= 0) {
  r <- (-B + c(-1, 1) * sqrt(disc)) / (2 * A)
  cat(sprintf("closed-form quadratic roots: %s\n", paste(sprintf("%.6f", r), collapse = ", ")))
} else cat("closed-form: negative discriminant\n")

cat("\n=== 3. the predicted jump ===\n")
cat(sprintf("A_net(no-flux branch) - A_net(limit of flux branch) = %.8f - %.8f = %.8f\n",
            l$assim_colimited(gstar), l$assim_colimited(ci_net0),
            l$assim_colimited(gstar) - l$assim_colimited(ci_net0)))
cat(sprintf("R_d_ = %.8f\n", Rd))
cat("hydraulic_cost_TF(psi_stem) is continuous across the boundary, so the profit\n")
cat("jump equals this assimilation jump.\n")
