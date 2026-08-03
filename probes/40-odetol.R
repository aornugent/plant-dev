# The SCM's nodes are TALLER at a given age than the same individual grown free
# in a fully open canopy -- impossible unless it is numerical.  Default ODE
# tolerances are loose (rel=abs=1e-4, max step 5 y) and the birth-date schedule
# leaves a long unbroken integration interval early on.  Sweep the tolerance.
source("probes/lib.R"); setwd("/home/user/plant-dev")
AGES <- c(1, 1.5, 2, 2.5, 3); TEND <- 3.5

p0 <- add_strategies(scm_base_parameters("TF24","TF24_Env"), trait_matrix(0.1978791,"lma"))
tt_full <- p0$node_schedule_times[[1]]
cat("full schedule: n =", length(tt_full), " n<=3.5 =", sum(tt_full <= TEND), "\n")
cat("schedule times <=3.5:", paste(sprintf("%.5g", tt_full[tt_full <= TEND]), collapse=" "), "\n\n")

scm_lai <- function(ctrl, trunc = TRUE, tt = NULL) {
  p <- p0
  if (is.null(tt)) tt <- tt_full
  if (trunc) { p$max_patch_lifetime <- TEND; tt <- tt[tt <= TEND] }
  p$node_schedule_times <- list(tt)
  scm <- scm_collect(p, "TF24", ctrl)
  tm <- vapply(seq_along(scm$history), function(k) scm$history[[k]]$time, 0)
  la <- vapply(seq_along(scm$history), function(k)
    scm$history[[k]]$species[[1]]$compute_competition(0), 0)
  vapply(AGES, function(a) la[which.min(abs(tm - a))], 0)
}
ctl <- function(bd = TRUE, tol = NULL, smax = NULL) {
  ct <- Control(); ct$node_density_in_birth_date <- bd
  if (!is.null(tol))  { ct$ode_tol_rel <- tol; ct$ode_tol_abs <- tol }
  if (!is.null(smax)) ct$ode_step_size_max <- smax
  ct
}

cat("=== does truncating the SCM schedule at 3.5 change ages<=3? ===\n")
v <- scm_lai(ctl(), trunc = TRUE)
cat(sprintf("truncated, default tol : %s\n", paste(sprintf("%.6f", v), collapse=" ")))
cat(sprintf("stored full run (n=141): %s\n\n",
    paste(sprintf("%.6f", readRDS("probes/out/excess-scm.rds")$scm[["141"]][1:5]), collapse=" ")))

cat("=== ODE tolerance sweep, birth-date SCM, schedule truncated at 3.5 ===\n")
cat(sprintf("%-12s %-10s %s\n", "tol", "max step", paste(sprintf("%10s", sprintf("L(%.1f)",AGES)), collapse=" ")))
for (tol in c(1e-4, 1e-5, 1e-6, 1e-7, 1e-8)) {
  t0 <- Sys.time(); v <- scm_lai(ctl(TRUE, tol))
  cat(sprintf("%-12.0e %-10s %s   (%.0fs)\n", tol, "default",
      paste(sprintf("%10.6f", v), collapse=" "),
      as.numeric(difftime(Sys.time(), t0, units="secs")))); flush.console()
}
for (smax in c(0.05, 0.01)) {
  t0 <- Sys.time(); v <- scm_lai(ctl(TRUE, 1e-8, smax))
  cat(sprintf("%-12.0e %-10g %s   (%.0fs)\n", 1e-8, smax,
      paste(sprintf("%10.6f", v), collapse=" "),
      as.numeric(difftime(Sys.time(), t0, units="secs")))); flush.console()
}

cat("\n=== same sweep with a finer node schedule (all midpoints, twice) ===\n")
mid <- function(x) sort(unique(c(x, (head(x,-1)+tail(x,-1))/2)))
tt2 <- mid(mid(tt_full))
for (tol in c(1e-4, 1e-8)) {
  v <- scm_lai(ctl(TRUE, tol), tt = tt2)
  cat(sprintf("n=%-4d tol=%-8.0e %s\n", sum(tt2 <= TEND), tol,
      paste(sprintf("%10.6f", v), collapse=" "))); flush.console()
}

cat("\n=== IBM, regular arrivals A=64, same tolerance sweep ===\n")
run_reg <- function(area, seed, ctrl) {
  set.seed(seed); p <- p0; p$patch_area <- area; p$max_patch_lifetime <- TEND
  dt <- 1/area; aa <- seq(0.5*dt, TEND, by = dt)
  ty  <- plant:::extract_RcppR6_template_types(p, "Parameters")
  obj <- do.call(plant:::StochasticPatchRunner, ty)(p, Environment("TF24"), ctrl)
  sc <- plant:::NodeSchedule(1); sc$max_time <- TEND; sc$set_times(aa, 1)
  obj$node_schedule <- sc
  tm <- c(); la <- c()
  snap <- function() { sp <- obj$patch$species[[1]]
    tm <<- c(tm, obj$patch$time); la <<- c(la, sp$compute_competition(0)/area) }
  snap(); while (!obj$complete) { obj$run_next(); snap() }
  ok <- !duplicated(tm); approx(tm[ok], la[ok], AGES, rule=2)$y
}
for (tol in c(1e-4, 1e-6, 1e-8)) {
  ct <- Control(); ct$ode_tol_rel <- tol; ct$ode_tol_abs <- tol
  LL <- t(vapply(1:2, function(k) run_reg(64, 5550000+64000+k, ct), numeric(5)))
  cat(sprintf("tol=%-8.0e %s\n", tol, paste(sprintf("%10.6f", colMeans(LL)), collapse=" ")))
  flush.console()
}
