# Why a thinned walk's J' misses the emulation (prereg.txt, "The thinning",
# results): test-mutant.R's three-year seasonal TF24 stand, splits on and off,
# each invader walked on every introduction and on every second and third; then
# thin_<rec>.rds's merged intervals against the full walk's sums.
#   DEV=... Rscript docs/measurements/node-rule/merged.R    # from plant-dev's root
D <- Sys.getenv("DEV")
library(plant, lib.loc = file.path(D, "lib_109"))
source("docs/measurements/pathfinders/invader-thinning/emulate.R")
per_node <- function(scm, q) {
  sp <- scm$patch$species[[1]]
  state <- matrix(sp$ode_state, ncol = sp$size, dimnames = list(sp$new_node$ode_names))
  b <- sp$node_times
  list(birth = b, w = sp$establishment_weights, nrr = sp$net_reproduction_ratio_by_node,
       pd = sp$patch_densities, E = state["interval_establishment", ],
       M = state["interval_establishment_moment", ], S_D = q$strategies[[1]]$pars[["S_D"]],
       br = vapply(b, function(t) sp$extrinsic_drivers$evaluate("birth_rate", t), 0))
}
T_END <- 3
p0 <- scm_base_parameters("TF24", "TF24_Env")
p0$max_patch_lifetime <- T_END
p0$patch_type <- "fixed"
p <- add_strategies(p0, trait_matrix(0.1978791, "lma"))
times <- p$node_schedule_times[[1]]
for (split in c(TRUE, FALSE)) {
  env <- Environment("TF24")
  t <- seq(0, T_END, length.out = 601)
  env$extrinsic_drivers_set_variable("rainfall", t, 0.25 * (1 + 0.95 * sin(2 * pi * t)))
  ctrl <- Control(node_density_in_birth_date = TRUE, ode_split_sign_changes = split)
  scm <- run_scm(p, env, ctrl, record_trajectory = TRUE)
  for (lma in c(1, 0.5)) {
    q <- p
    q$strategies[[1]]$pars$lma <- lma * p$strategies[[1]]$pars$lma
    scm$run_mutant(q)
    nd <- per_node(scm, q)
    for (by in c(2, 3)) {
      keep <- seq(1, length(times), by = by)
      q$node_schedule_times <- list(times[keep])
      scm$run_mutant(q)
      own <- per_node(scm, q)
      ends <- c(keep[-1], length(times) + 1)
      d <- abs(own$E / mapply(function(i, j) sum(nd$E[i:(j - 1)]), keep, ends) - 1)
      cat(sprintf("splits %-5s lma x%-3g every %d: establishment of %d of %d intervals off the full walk's sums by over 1e-14, up to %.1e; J' against the emulation %+.1e, against its own nodes' %+.1e\n",
                  split, lma, by, sum(d > 1e-14), length(d), max(d),
                  sum(scm$offspring_production) / J_of(nd, keep) - 1,
                  sum(scm$offspring_production) / J_of(own, seq_along(keep)) - 1))
      q$node_schedule_times <- list(times)
    }
  }
}
T_END <- 40
for (key in c("epi", "ld")) {
  x <- readRDS(file.path(D, "node_rule", "thin", sprintf("thin_%s.rds", key)))
  for (rule in x$rules) {
    r <- t(vapply(names(x$cases), function(k) {
      a <- x$cases[[k]]$full$nodes; b <- x$cases[[k]][[rule]]
      if (is.null(b$nodes)) return(rep(NA_real_, 4))
      kp <- b$keep; ends <- c(kp[-1], length(a$birth) + 1)
      Em <- mapply(function(i, j) sum(a$E[i:(j - 1)]), kp, ends)
      merged <- ends - kp > 1
      c(identical(b$nodes$E[!merged], Em[!merged]), max(abs(b$nodes$E[merged] / Em[merged] - 1)),
        max(abs(b$J / J_of(b$nodes, seq_along(kp)) - 1)), max(abs(b$J / J_of(a, kp) - 1)))
    }, numeric(4)))
    cat(sprintf("%-3s %-10s establishment against the full walk's sums: unmerged identical in %d of %d, merged up to %.1e; J' against its own nodes' up to %.1e, against the emulation up to %.1e\n",
                key, rule, sum(r[, 1], na.rm = TRUE), sum(!is.na(r[, 1])), max(r[, 2], na.rm = TRUE),
                max(r[, 3], na.rm = TRUE), max(r[, 4], na.rm = TRUE)))
  }
}
