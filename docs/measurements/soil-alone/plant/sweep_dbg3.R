suppressMessages(library(plant))
p0 <- scm_base_parameters("TF24", "TF24_Env")
p0$max_patch_lifetime <- 3
p0$patch_type <- "fixed"
lma <- 0.1978791
p <- add_strategies(p0, trait_matrix(lma, "lma"))
env <- function() {
  e <- Environment("TF24")
  t <- seq(0, 3, length.out = 601)
  e$extrinsic_drivers_set_variable("rainfall", t, 0.25 * (1 + 0.95 * sin(2 * pi * t)))
  e
}
ctrl <- function(share, split) {
  x <- control_tf24(1e-4, Control(node_density_in_birth_date = TRUE, ode_split_sign_changes = split))
  x$ode_soil_alone_share <- share
  x
}
with_lma <- function(x) { q <- p; s <- q$strategies[[1]]; pars <- s$pars; pars$lma <- x; s$pars <- pars; q$strategies[[1]] <- s; q }
check <- function(share, split) {
  run <- run_scm(p, env(), ctrl(share, split), record_trajectory = TRUE)
  replay <- function(q) {
    scm <- plant:::SCM("TF24", "TF24_Env")(q, env(), plant:::empty_events(), ctrl(share, split))
    sched <- scm$node_schedule
    sched$all_times <- run$node_schedule$all_times
    sched$set_ode_steps(run$ode_times, run$ode_step_sizes, run$ode_alone_slopes, run$ode_alone_steps)
    scm$node_schedule <- sched
    scm$run()
    sum(scm$offspring_production)
  }
  sw <- plant:::census_trait_gradient_tf24(run, "offspring_production")$gradient[[1]][match("1.lma", plant:::census_trait_names_tf24(run))]
  cds <- sapply(c(1e-5, 1e-6, 1e-7), function(r) { d <- r * lma; (replay(with_lma(lma + d)) - replay(with_lma(lma - d))) / (2 * d) })
  cat(sprintf("share %.1f split %d: alone rows %d/%d splits %d  swept/cd - 1 at r = 1e-5, 1e-6, 1e-7: %s\n", share, split,
              sum(lengths(run$ode_alone_steps) > 0), length(run$ode_times), sum(run$ode_splits),
              paste(sprintf("%+.2e", sw / cds - 1), collapse = " ")))
}
check(0, TRUE); check(0.1, TRUE)
