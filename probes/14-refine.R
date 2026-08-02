# Refinement by midpoint insertion, so both arms see byte-identical schedules at
# each level.  A quantity converging to its own limit under refinement is being
# integrated accurately; one that keeps moving is not.
suppressMessages(library(plant)); setwd("/home/user/plant-dev")
midpoints <- function(tt) sort(unique(c(tt, (head(tt,-1) + tail(tt,-1)) / 2)))

cfg <- list(TF24 = trait_matrix(0.1978791,"lma"),
            FF16 = trait_matrix(0.0825,"lma"),
            K93  = trait_matrix(0.059,"b_0"))
res <- list()
for (nm in names(cfg)) {
  p0 <- add_strategies(scm_base_parameters(nm, paste0(nm,"_Env")), cfg[[nm]])
  tt <- p0$node_schedule_times[[1]]
  for (lev in 0:2) {
    if (lev > 0) tt <- midpoints(tt)
    p <- p0; p$node_schedule_times <- list(tt)
    for (bd in c(FALSE, TRUE)) {
      ct <- Control(); ct$node_density_in_birth_date <- bd
      t0 <- Sys.time()
      scm <- run_scm(p, Environment(nm), ct, collect = FALSE, refine_schedule = FALSE)
      el <- as.numeric(difftime(Sys.time(), t0, units="secs"))
      res[[length(res)+1]] <- data.frame(model = nm, level = lev, n_intro = length(tt),
        birth_date = bd, offspring = scm$offspring_production,
        steps = length(scm$ode_times), secs = el)
      cat(sprintf("%-5s lev%d n=%-4d %s offspring=%-12.6g steps=%-6d %6.1fs\n",
                  nm, lev, length(tt), if (bd) "birth" else "height",
                  scm$offspring_production, length(scm$ode_times), el))
      flush.console()
    }
  }
}
saveRDS(do.call(rbind, res), "probes/out/refine.rds")
