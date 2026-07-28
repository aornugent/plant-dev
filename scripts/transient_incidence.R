# The same discrete-structure census, on the rainfall transients built to stress
# the solver rather than on the model's benign default driver.
#
# The default driver keeps soil moisture in [0.214, 0.311] (psi_soil 0.015-0.17
# MPa) -- wet. These traces are 94-98% dry days with dry runs of one to three
# years, so they take the soil somewhere the default never goes. Any statement
# about what TF24's discrete constructs never reach has to be made here.
#
# Counts, per scenario:
#   transpiration == 0        the zero-flux branch inside the objective
#   psi_stem - |collar|       distance (MPa) from that branch
#   E_up_ < 0                 root-mediated redistribution
#   net_mass_production <= 0  the growth gate (report 2 C1)
#
#   Rscript scripts/transient_incidence.R <scenario> [tol]

suppressMessages({ library(odelia); pkgload::load_all("plant", quiet = TRUE) })
a <- commandArgs(TRUE); scen <- a[1]; tol <- as.numeric(a[2]); life_override <- as.numeric(a[3])
if (is.na(tol)) tol <- 1e-4

s <- readRDS(sprintf("scripts/tf24-benchmarks/data/%s.rds", scen))
# bank rain is mm/day at daily nodes t = (0:(nd-1))/365 years; the environment's
# "rainfall" driver is m/yr.
nd <- length(s$rain)
tt <- (0:(nd - 1)) / 365
rr <- s$rain * 365 / 1000
# pad the driver past the horizon: the solver queries slightly beyond
# max_patch_lifetime and the interpolator does not extrapolate.
tt <- c(tt, max(tt) + c(1, 2, 10) / 365); rr <- c(rr, rep(0, 3))

p0 <- scm_base_parameters("TF24", "TF24_Env")
if (!is.na(life_override)) s$life <- life_override
p0$max_patch_lifetime <- s$life
p <- add_strategies(p0, trait_matrix(0.1978791, "lma"))
env <- Environment("TF24")
env$extrinsic_drivers_set_variable("rainfall", tt, rr)
ctrl <- Control(); ctrl$ode_tol_rel <- tol; ctrl$ode_tol_abs <- tol

t0 <- Sys.time()
res <- tryCatch(run_scm(p, env, ctrl, collect = TRUE, refine_schedule = FALSE),
                error = function(e) { cat(sprintf("FAILED: %s\n", conditionMessage(e))); NULL })
el <- as.numeric(Sys.time() - t0, "secs")
if (is.null(res)) quit(status = 0)

d <- as.data.frame(res$species)
d <- d[is.finite(d$transpiration) & is.finite(d$opt_psi_stem), ]
n <- nrow(d)
margin <- d$opt_psi_stem + d$opt_root_psi
sm <- as.data.frame(res$env$soil_moist)
th <- sm[[ncol(sm)]]
a_psi <- env$a_psi; n_psi <- env$n_psi; th_sat <- env$soil_moist_sat
psi_of <- function(x) a_psi * (pmax(x, 1e-2) / th_sat)^(-n_psi) / 1e6

cat(sprintf("\n### %s  life %.0f, tol %.0e, %.1f s, %d records, %d steps, offspring %.4g\n",
            scen, s$life, tol, el, n, nrow(res$steps), sum(res$offspring_production)))
cat(sprintf("soil theta  min %.4f  median %.4f  max %.4f\n", min(th, na.rm = TRUE),
            median(th, na.rm = TRUE), max(th, na.rm = TRUE)))
cat(sprintf("psi_soil    max %.4f MPa (at theta_min), median %.4f\n",
            psi_of(min(th, na.rm = TRUE)), psi_of(median(th, na.rm = TRUE))))
cat(sprintf("zero-flux branch (transpiration == 0) : %6d  (%.4f%%)\n",
            sum(d$transpiration == 0), 100 * mean(d$transpiration == 0)))
cat(sprintf("transpiration < 1e-12                 : %6d  (%.4f%%)\n",
            sum(d$transpiration < 1e-12), 100 * mean(d$transpiration < 1e-12)))
cat(sprintf("redistribution (E_up_ < 0)            : %6d  (%.4f%%)\n",
            sum(d$E_up_ < 0), 100 * mean(d$E_up_ < 0)))
cat(sprintf("growth gate (net_mass_prod <= 0)      : %6d  (%.4f%%)\n",
            sum(d$net_mass_production_dt <= 0), 100 * mean(d$net_mass_production_dt <= 0)))
cat("margin psi_stem - |collar| (MPa) quantiles:\n")
print(signif(quantile(margin, c(0, 1e-4, 1e-3, .01, .1, .5, 1)), 4))
cat(sprintf("margin < 1e-3 (GSS_tol_abs): %d;  < 1e-2: %d\n",
            sum(margin < 1e-3), sum(margin < 1e-2)))
