# Strip competition out of both solvers and compare a single individual's growth.
# SCM with birth_rate_y ~ 0 and IBM with one individual per 1e5 m2 both have an
# essentially open canopy, so any difference in height(age) is pure integration.
source("probes/lib.R"); setwd("/home/user/plant-dev")
TEND <- 3.0
p0 <- add_strategies(scm_base_parameters("TF24","TF24_Env"), trait_matrix(0.1978791,"lma"))
tt_full <- p0$node_schedule_times[[1]]

## --- SCM, open canopy: track the node introduced at t = 0 ----------
scm_open <- function(tol = NULL, birth = 1e-6) {
  p <- p0; p$max_patch_lifetime <- TEND
  p$node_schedule_times <- list(tt_full[tt_full <= TEND])
  p$strategies[[1]]$birth_rate_y <- birth
  ct <- Control(); ct$node_density_in_birth_date <- TRUE
  if (!is.null(tol)) { ct$ode_tol_rel <- tol; ct$ode_tol_abs <- tol }
  scm <- scm_collect(p, "TF24", ct)
  tm <- vapply(seq_along(scm$history), function(k) scm$history[[k]]$time, 0)
  h  <- vapply(seq_along(scm$history), function(k) {
          sp <- scm$history[[k]]$species[[1]]
          if (length(sp$nodes) == 0) NA_real_ else sp$nodes[[1]]$individual$state("height") }, 0)
  a  <- vapply(seq_along(scm$history), function(k) {
          sp <- scm$history[[k]]$species[[1]]
          if (length(sp$nodes) == 0) NA_real_ else sp$nodes[[1]]$individual$compute_competition(0) }, 0)
  lai<- vapply(seq_along(scm$history), function(k)
          scm$history[[k]]$species[[1]]$compute_competition(0), 0)
  ok <- !is.na(h); data.frame(t = tm[ok], h = h[ok], a = a[ok], lai = lai[ok])
}

## --- IBM, open canopy: one individual per 1e5 m2 -------------------
ibm_open <- function(tol = NULL, area = 1e5) {
  p <- p0; p$patch_area <- area; p$max_patch_lifetime <- TEND
  ct <- Control(); if (!is.null(tol)) { ct$ode_tol_rel <- tol; ct$ode_tol_abs <- tol }
  ty  <- plant:::extract_RcppR6_template_types(p, "Parameters")
  obj <- do.call(plant:::StochasticPatchRunner, ty)(p, Environment("TF24"), ct)
  sc  <- plant:::NodeSchedule(1); sc$max_time <- TEND
  sc$set_times(seq(0, TEND, by = 0.02), 1); obj$node_schedule <- sc
  tm <- c(); h <- c(); a <- c(); lai <- c()
  snap <- function() { sp <- obj$patch$species[[1]]
    if (length(sp$individuals)) {
      tm <<- c(tm, obj$patch$time)
      h  <<- c(h, sp$individuals[[1]]$state("height"))
      a  <<- c(a, sp$individuals[[1]]$compute_competition(0))
      lai<<- c(lai, sp$compute_competition(0)/area) } }
  snap(); while (!obj$complete) { obj$run_next(); snap() }
  ok <- !duplicated(tm); data.frame(t = tm[ok], h = h[ok], a = a[ok], lai = lai[ok])
}

## --- free growth in a fixed open environment -----------------------
free_open <- function() {
  env <- Environment("TF24"); env$set_fixed_environment(1.0, 150)
  times <- seq(0.02, TEND, by = 0.02)
  ind <- TF24_Individual(p0$strategies[[1]])
  ind$set_state("storage", 3.841082e-07)      # the SCM's birth store
  r <- grow_individual_to_time(ind, times, env)
  data.frame(t = times,
             h = vapply(r$individual, function(i) i$state("height"), 0),
             a = vapply(r$individual, function(i) i$compute_competition(0), 0), lai = 0)
}

S4 <- scm_open(NULL); S8 <- scm_open(1e-8)
I4 <- ibm_open(NULL); I8 <- ibm_open(1e-8)
FR <- free_open()
cat(sprintf("max LAI seen: SCM %.3e   IBM %.3e  (both effectively open)\n\n",
            max(S4$lai), max(I4$lai)))
g <- c(0.25, 0.5, 0.75, 1, 1.25, 1.5, 2, 2.5, 3)
ip <- function(d, col) approx(d$t, d[[col]], g, rule=2)$y
cat(sprintf("%6s | %9s %9s %9s %9s %9s | %8s %8s\n","age",
    "h SCM1e-4","h SCM1e-8","h IBM1e-4","h IBM1e-8","h free","SCM/IBM","SCM/free"))
hs <- ip(S4,"h"); hs8 <- ip(S8,"h"); hi <- ip(I4,"h"); hi8 <- ip(I8,"h"); hf <- ip(FR,"h")
for (i in seq_along(g))
  cat(sprintf("%6.2f | %9.5f %9.5f %9.5f %9.5f %9.5f | %8.4f %8.4f\n",
      g[i], hs[i], hs8[i], hi[i], hi8[i], hf[i], hs[i]/hi[i], hs[i]/hf[i]))
cat("\n")
as <- ip(S4,"a"); as8 <- ip(S8,"a"); ai <- ip(I4,"a"); ai8 <- ip(I8,"a"); af <- ip(FR,"a")
cat(sprintf("%6s | %11s %11s %11s %11s %11s | %8s %8s\n","age",
    "a SCM1e-4","a SCM1e-8","a IBM1e-4","a IBM1e-8","a free","SCM/IBM","SCM/free"))
for (i in seq_along(g))
  cat(sprintf("%6.2f | %11.4e %11.4e %11.4e %11.4e %11.4e | %8.4f %8.4f\n",
      g[i], as[i], as8[i], ai[i], ai8[i], af[i], as[i]/ai[i], as[i]/af[i]))
saveRDS(list(S4=S4,S8=S8,I4=I4,I8=I8,FR=FR), "probes/out/41-open.rds")
