# Adaptive schedule refinement in both coordinate systems.  The competition
# error is now measured over whichever abscissa the competition integral uses;
# the reproduction error was already measured over introduction times.
suppressMessages(library(plant)); setwd("/home/user/plant-dev")
cfg <- list(K93 = trait_matrix(0.059,"b_0"), FF16 = trait_matrix(0.0825,"lma"),
            TF24 = trait_matrix(0.1978791,"lma"))
for (nm in names(cfg)) {
  for (bd in c(FALSE, TRUE)) {
    p <- add_strategies(scm_base_parameters(nm, paste0(nm,"_Env")), cfg[[nm]])
    ct <- Control(); ct$node_density_in_birth_date <- bd
    n0 <- length(p$node_schedule_times[[1]])
    t0 <- Sys.time()
    ok <- tryCatch({
      scm <- run_scm(p, Environment(nm), ct, collect = FALSE, refine_schedule = TRUE)
      sprintf("offspring=%-12.6g  schedule %d -> %-5d  steps=%-6d  %5.1fs",
              scm$offspring_production, n0,
              length(scm$parameters$node_schedule_times[[1]]),
              length(scm$ode_times), as.numeric(difftime(Sys.time(), t0, units="secs")))
    }, error = function(e) paste("ERROR:", conditionMessage(e)))
    cat(sprintf("%-5s %-11s %s\n", nm, if (bd) "birth-date" else "height", ok))
    flush.console()
  }
}
