# One record on 108 uniform nodes, plain and with the first node spacing split K
# ways: J; the cohorts that keep pace with the first, as the last birth date
# whose mortality integral ends within 1 of the first node's; the first node's
# height at the end against hmat; and
# the resident's and, with INVADER=1, the invader's lma elasticity, the
# invader's both swept and from J' at lma e^{+-D} on one recording.
#
#   PLANT_LIB=... [REGIME=constant] [K=32] [TOL=3e-5] [INVADER=1] [D=1e-3] \
#     Rscript harness/first_panel.R
local({
  here <- tryCatch(dirname(sys.frame(1)$ofile), error = function(e) "harness")
  source(file.path(here, "long_drought.R"))
})
regime <- Sys.getenv("REGIME", "constant")
k <- as.integer(Sys.getenv("K", "32"))
tol <- as.numeric(Sys.getenv("TOL", "3e-5"))
invader <- Sys.getenv("INVADER") == "1"
d <- as.numeric(Sys.getenv("D", "1e-3"))
knots <- active_knots(regime)

parameters <- function(times) {
  p <- scm_base_parameters("TF24")
  p$max_patch_lifetime <- LIFETIME
  p <- add_strategies(p, trait_matrix(LMA0, "lma"))
  p$node_schedule_times <- list(times)
  p
}
# lma alone, as the sweep's column is, not through the traits derived from it.
with_lma <- function(p, u) {
  s <- p$strategies
  s[[1]]$pars$lma <- s[[1]]$pars$lma * exp(u)
  p$strategies <- s
  p
}
ct <- control()
ct$ode_tol_rel <- tol
ct$ode_tol_abs <- 1e-4 * tol
ct$node_density_in_birth_date <- TRUE
elasticity <- function(scm, J) {
  stand_gradient(scm, metrics = "offspring_production")$gradient["offspring_production", "1.lma"] *
    LMA0 / J
}

for (split in unique(c(1L, k))) {
  times <- uniform_times(108)
  if (split > 1) times <- sort(c(times, seq_len(split - 1) * times[2] / split))
  p <- parameters(times)
  ev <- if (length(knots)) events(events_default(p), pulse_rows(sort(unique(knots)))) else
    events(events_default(p))
  scm <- run_scm(p, mkenv(regime), ct, events = ev, record_trajectory = TRUE)
  J <- sum(scm$offspring_production)
  sp <- scm$patch$species[[1]]
  state <- matrix(sp$ode_state, ncol = sp$size)  # one column per node: height, mortality, ...
  stopifnot(isTRUE(all.equal(state[1, ], sp$heights)))
  last <- max(which(state[2, ] - state[2, 1] < 1 & sp$node_times < 1))
  hmat <- p$strategies[[1]]$pars$hmat
  a_f2 <- p$strategies[[1]]$pars$a_f2
  cat(sprintf("%s, %d nodes (first spacing split %d): J %.6g\n", regime, length(times), split, J))
  cat(sprintf("  keeping pace with the first node: born by %.4f, the next born %.4f; first node %.2f m against hmat %.2f, so it puts %.3g of its production into seed\n",
              sp$node_times[last], sp$node_times[last + 1], state[1, 1], hmat,
              1 / (1 + exp(a_f2 * (1 - state[1, 1] / hmat)))))
  cat(sprintf("  resident lma elasticity %.4g\n", elasticity(scm, J)))
  if (invader) {
    Jinv <- function(u) { scm$run_mutant(with_lma(p, u)); sum(scm$offspring_production) }
    Jp <- Jinv(d); Jm <- Jinv(-d); J0 <- Jinv(0)
    cat(sprintf("  invader: J' at lma e^-D, 1, e^+D %.6g %.6g %.6g; elasticity from them %.4g, swept %.4g\n",
                Jm, J0, Jp, (log(Jp) - log(Jm)) / (2 * d), elasticity(scm, J0)))
  }
}
