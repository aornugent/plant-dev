res <- readRDS(sprintf("/tmp/front/%s.rds", Sys.getenv("CASE", "closed")))
d <- as.data.frame(res$species)
d <- d[!is.na(d$density), ]
eta <- 12; eta_c <- 1 - 2/(1 + eta) + 1/(1 + 2*eta); rho <- 608
d$Smax <- 0.1 * d$area_sapwood * d$height * eta_c * rho
d$r <- d$storage / d$Smax
d$mu <- 0.01 + 5.5 * exp(-20 * d$r)
d$x <- d$net_mass_production_dt / 1e-4
d$tau_eps <- d$Smax / 1e-4
d$age <- d$time - d$time[match(d$node, d$node)]  # placeholder
birth <- tapply(d$time, d$node, min); d$age <- d$time - birth[as.character(d$node)]
cat("ln R:", log(res$net_reproduction_ratios), "\n")
# per cohort summary
s <- do.call(rbind, lapply(split(d, d$node), function(z) {
  z <- z[order(z$time), ]
  dt <- c(diff(z$time), 0)
  data.frame(node = z$node[1], birth = z$time[1], hmax = max(z$height),
             Pmin = min(z$net_mass_production_dt),
             yrs_neg = sum(dt[z$net_mass_production_dt < 0]),
             yrs_absx_lt10 = sum(dt[abs(z$x) < 10]),
             yrs_r_lt_0.15 = sum(dt[z$r < 0.15]),
             rmin = min(z$r), M_end = tail(z$mortality, 1),
             fec_end = tail(z$offspring_produced_survival_weighted, 1),
             h_at_cross = { i <- which(z$net_mass_production_dt < 0)[1]; if (is.na(i)) NA else z$height[i] },
             Smax_eps_at_cross = { i <- which(z$net_mass_production_dt < 0)[1]; if (is.na(i)) NA else z$tau_eps[i] })
}))
s$share <- s$fec_end / sum(s$fec_end)
options(width = 200)
print(s[seq(1, nrow(s), 4), ], digits = 3)
cat("cohorts ever P<0:", sum(s$yrs_neg > 0), "of", nrow(s), "\n")
cat("RV share from cohorts ever P<0:", sum(s$share[s$yrs_neg > 0]), "\n")
# snapshot of the stand at a few patch ages: height, P, r, mu, light
for (tt in c(5, 10, 20, 30, 40)) {
  z <- d[abs(d$time - tt) < 0.19, ]
  z <- z[order(-z$height), ]
  cat("\n== patch age", tt, "\n")
  print(z[seq(1, nrow(z), length.out = min(nrow(z), 12)),
          c("node", "age", "height", "net_mass_production_dt", "x", "r", "mu", "Smax", "tau_eps", "assimilation", "log_density")], digits = 3)
}
saveRDS(list(d = d, s = s), sprintf("/tmp/front/%s_an.rds", Sys.getenv("CASE", "closed")))
