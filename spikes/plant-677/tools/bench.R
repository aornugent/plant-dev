suppressMessages(library(plant))
tm <- function(expr, n = 3) {
  e <- substitute(expr); f <- parent.frame()
  min(replicate(n, system.time(eval(e, f))[["elapsed"]]))
}

ff16 <- function(lifetime) {
  p <- scm_base_parameters("FF16")
  p$max_patch_lifetime <- lifetime
  p <- add_strategies(p, trait_matrix(0.0825, "lma"), birth_rate = list(1))
  list(p = p, env = NULL, ctrl = Control(node_density_in_birth_date = TRUE))
}
tf24 <- function(lifetime) {
  p <- scm_base_parameters("TF24")
  p$max_patch_lifetime <- lifetime
  p <- add_strategies(p, trait_matrix(0.0825, "lma"), hyperpar = TF24_hyperpar,
                      birth_rate = 1)
  env <- Environment("TF24")
  env$extrinsic_drivers_set_constant("rainfall", 1)
  list(p = p, env = env, ctrl = Control(node_density_in_birth_date = TRUE))
}

args <- commandArgs(TRUE)
models <- if (length(args)) args else c("FF16", "TF24")
for (m in models) {
  lifetimes <- if (m == "FF16") c(8, 30) else c(2, 5)
  for (L in lifetimes) {
    s <- if (m == "FF16") ff16(L) else tf24(L)
    run <- tm(run_scm(s$p, s$env, s$ctrl))
    scm <- run_scm(s$p, s$env, s$ctrl, record_trajectory = TRUE)
    met <- names(stand_census(scm))[1]
    g1 <- tm(stand_gradient(scm, metrics = met))
    n_steps <- length(scm$ode_times)
    n_coh <- scm$patch$species[[1]]$size
    cat(sprintf("%-4s L=%-3g steps=%-5d cohorts=%-4d run=%.3fs pass=%.3fs ratio=%.1fx  run/step=%.1fus pass/step=%.1fus\n",
                m, L, n_steps, n_coh, run, g1, g1 / run,
                1e6 * run / n_steps, 1e6 * g1 / n_steps))
  }
}
