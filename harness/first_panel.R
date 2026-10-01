# One record on 108 uniform nodes, plain and with the first node spacing split K
# ways, or on the schedule in TIMES alone: J; the cohorts that keep pace with the
# first, as the last birth date whose mortality integral ends within 1 of the
# first node's; the first node's height at the end against hmat; and
# the resident's and, with INVADER=1, the invader's lma elasticity, the
# invader's both swept and from J' at lma e^{+-D} on one recording. U and M add
# residents and invaders across lma on the last schedule, each invader with the
# slope of ln J' from the resident's.
#
#   PLANT_LIB=... [REGIME=constant] [K=32] [TIMES=times.rds] [TOL=3e-5] [INVADER=1] \
#     [D=1e-3] [U=-0.02,0.02] [M=0.5,0.99,1.01,2] Rscript harness/first_panel.R
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

split_times <- function(split) {
  times <- uniform_times(108)
  if (split > 1) times <- sort(c(times, seq_len(split - 1) * times[2] / split))
  times
}
schedules <- if (nzchar(Sys.getenv("TIMES"))) list(readRDS(Sys.getenv("TIMES"))) else
  lapply(unique(c(1L, k)), split_times)
for (times in schedules) {
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
  cat(sprintf("%s, %d nodes (first spacing %.3g): J %.6g\n", regime, length(times), times[2], J))
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

# On the split schedule: the resident at lma e^u for each u in U, and invaders at
# lma x m for each m in M on the resident's recording, with the birth date before
# which 90% of their J comes.
before_90 <- function(sp) {
  w <- c(sp$establishment_weights, 0)[seq_len(sp$size)] * sp$net_reproduction_ratio_by_node
  sp$node_times[which(cumsum(w) / sum(w) >= 0.9)[1]]
}
for (u in as.numeric(strsplit(Sys.getenv("U"), ",")[[1]])) {
  q <- with_lma(p, u)
  r <- run_scm(q, mkenv(regime), ct, events = ev)
  cat(sprintf("  resident at lma e^%+.4f: J %.6g, 90%% from births before %.4f\n",
              u, sum(r$offspring_production), before_90(r$patch$species[[1]])))
}
for (m in as.numeric(strsplit(Sys.getenv("M"), ",")[[1]])) {
  scm$run_mutant(with_lma(p, log(m)))
  Jm <- sum(scm$offspring_production)
  cat(sprintf("  invader at lma x%.5g: J' %.6g, slope of ln J' from the resident's %.4g, 90%% from births before %.4f\n",
              m, Jm, log(Jm / J) / log(m), before_90(scm$patch$species[[1]])))
}
