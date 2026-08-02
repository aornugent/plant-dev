# TF24's storage state leaves [0, S_max].  Capacity for a seedling is ~1e-6 while
# ode_tol_abs is 1e-4, so the error controller does not constrain the state at
# all.  If that is the cause, tightening the absolute tolerance should remove the
# excursion.
suppressMessages(library(plant)); setwd("/home/user/plant-dev")
p <- add_strategies(scm_base_parameters("TF24","TF24_Env"), trait_matrix(0.1978791,"lma"))
s1 <- p$strategies[[1]]
for (tol in c(1e-4, 1e-6, 1e-8)) {
  ct <- Control(); ct$ode_tol_abs <- tol
  t0 <- Sys.time()
  r <- run_scm(p, Environment("TF24"), ct, collect = TRUE, refine_schedule = FALSE)
  d <- r$species
  al <- plant:::TF24_strategy_expand_allometry(s1, d$height, d$area_heartwood, d$mass_heartwood)
  Smax <- s1$pars$a_st1 * al$mass_sapwood
  cat(sprintf("ode_tol_abs=%-6g offspring=%-11.6g  min storage=%-11.4g  frac<0=%.4f  min S/Smax=%-9.4g  max S/Smax=%.4f  %5.1fs\n",
      tol, r$offspring_production, min(d$storage), mean(d$storage < 0),
      min(d$storage/Smax), max(d$storage/Smax),
      as.numeric(difftime(Sys.time(), t0, units="secs"))))
  cat(sprintf("            median Smax=%.4g  (ode_tol_abs is %.3g x median capacity)\n",
              median(Smax), tol/median(Smax)))
  flush.console()
}
