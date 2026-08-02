# Baseline SCM runs on develop@141dc8df, one species each, default schedule.
suppressMessages(library(plant))
setwd("/home/user/plant-dev")
dir.create("probes/out", showWarnings = FALSE, recursive = TRUE)

cfg <- list(
  TF24 = list(env = "TF24", trait = trait_matrix(0.1978791, "lma"), ind = TF24_Individual),
  FF16 = list(env = "FF16", trait = trait_matrix(0.0825,    "lma"), ind = FF16_Individual),
  K93  = list(env = "K93",  trait = trait_matrix(0.059,     "b_0"), ind = K93_Individual)
)

for (nm in names(cfg)) {
  cc <- cfg[[nm]]
  p <- add_strategies(scm_base_parameters(nm, paste0(nm, "_Env")), cc$trait)
  t0 <- Sys.time()
  scm <- run_scm(p, Environment(cc$env), Control(), collect = FALSE,
                 refine_schedule = FALSE)
  n_ode <- length(scm$ode_times)
  res <- run_scm(p, Environment(cc$env), Control(), collect = TRUE,
                 refine_schedule = FALSE)
  el <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  res$height_0 <- cc$ind(p$strategies[[1]])$state("height")
  res$model <- nm
  saveRDS(res, sprintf("probes/out/baseline-%s.rds", nm))
  cat(sprintf("%-5s offspring=%-10.6g ode_times=%-6d recorded=%-5d nodes=%-5d h0=%.4f  %.1fs\n",
              nm, res$offspring_production, n_ode,
              length(unique(res$species$time)), max(res$species$node),
              res$height_0, el))
  flush.console()
}
