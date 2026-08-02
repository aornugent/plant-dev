# Forward runs of both coordinate choices.  The default must reproduce develop
# exactly; the birth-date arm is the same model without the change of variables.
suppressMessages(library(plant)); setwd("/home/user/plant-dev")
cfg <- list(TF24 = trait_matrix(0.1978791,"lma"),
            FF16 = trait_matrix(0.0825,"lma"),
            K93  = trait_matrix(0.059,"b_0"))
ref <- c(TF24 = 42.14017, FF16 = 19.82440, K93 = 0.03054660)

for (nm in names(cfg)) {
  p <- add_strategies(scm_base_parameters(nm, paste0(nm,"_Env")), cfg[[nm]])
  for (bd in c(FALSE, TRUE)) {
    ct <- Control(); ct$node_density_in_birth_date <- bd
    t0 <- Sys.time()
    scm <- run_scm(p, Environment(nm), ct, collect = FALSE, refine_schedule = FALSE)
    el <- as.numeric(difftime(Sys.time(), t0, units="secs"))
    off <- scm$offspring_production
    tag <- if (bd) "birth-date" else "height    "
    chk <- if (!bd) sprintf("  (develop %.6g, delta %.3g)", ref[nm], off - ref[nm]) else ""
    cat(sprintf("%-5s %s offspring=%-11.6g steps=%-6d %5.1fs%s\n",
                nm, tag, off, length(scm$ode_times), el, chk))
    flush.console()
  }
}
