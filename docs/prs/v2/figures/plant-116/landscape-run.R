# plant-116: invader fitness across lma multipliers at the resident's
# equilibrium birth rate b* (from newton.csv, ode_tol 1e-6), on one build.
# Each invader is the resident's strategy with lma alone scaled, every other
# parameter held at the resident's (no hyperparameter map), so the sweep's
# lma column is the slope of this curve. Each takes the resident's recorded
# steps (run_mutant). With
# GRADIENT=1 (B95) the sweep's d ln R0'/d ln lma is taken at a few multipliers.
#   PLANT_LIB=<lib> [GRADIENT=1] Rscript landscape-run.R
here <- "/home/user/plant-dev/docs/prs/v2/figures/plant-116"
source(file.path(here, "fixture.R")); load_plant()
nw <- read.csv(file.path(here, "newton.csv")); nw <- nw[nw$tol == 1e-6, ]
bstar <- nw$b[nrow(nw)]
build <- basename(Sys.getenv("PLANT_LIB"))
resident <- fitness_stand_run(fitness_stand_parameters(bstar), 1e-6, record = TRUE)
cat(sprintf("%s: b* %.10g, resident J %.12g, R0 %.12g, steps %d\n", build, bstar,
            resident$offspring_production, resident$net_reproduction_ratios,
            length(resident$ode_times) - 1))
grad <- Sys.getenv("GRADIENT") == "1"
at_grad <- c(0.6, 0.8, 0.95, 1, 1.02, 1.05, 1.25, 1.6)
m <- sort(unique(round(c(exp(seq(log(0.5), log(2), length.out = 41)),
                         seq(0.95, 1.10, by = 0.0025), 0.7, 0.9, 1.1, 1.4, at_grad), 10)))
invader <- function(x) {
  q <- fitness_stand_parameters(1)
  q$strategies[[1]]$pars$lma <- q$strategies[[1]]$pars$lma * x
  q
}
rows <- list()
for (x in m) {
  t0 <- proc.time()
  r <- tryCatch({
    resident$record_trajectory <- grad && any(abs(x - at_grad) < 1e-12)
    resident$run_mutant(invader(x))
    resident$net_reproduction_ratios
  }, error = function(e) { cat(sprintf("  x%.3f: %s\n", x, conditionMessage(e))); NA })
  slope <- NA; fd <- NA
  if (!is.na(r) && isTRUE(resident$record_trajectory)) {
    gi <- stand_gradient(resident, metrics = "1.net_reproduction_ratio", traits = "1.lma")
    lma <- invader(x)$strategies[[1]]$pars$lma
    slope <- lma * gi$gradient[[1]] / gi$value[[1]]
    # A central difference of invasions in ln lma, step 1e-4, on the same recording.
    resident$record_trajectory <- FALSE
    lnr <- vapply(c(1, -1), function(s) {
      resident$run_mutant(invader(x * exp(s * 1e-4)))
      log(resident$net_reproduction_ratios) }, 0)
    fd <- (lnr[[1]] - lnr[[2]]) / 2e-4
  }
  rows[[length(rows) + 1]] <- data.frame(build = build, bstar = bstar, multiplier = x,
    R0 = r, lnR0 = log(r), dlnR0_dlnlma = slope, central_difference = fd,
    cpu_s = sum((proc.time() - t0)[c("user.self", "sys.self")]))
}
d <- do.call(rbind, rows); print(d[!is.na(d$dlnR0_dlnlma) | abs(d$multiplier - 1) < 1e-9, c("multiplier", "R0", "lnR0", "dlnR0_dlnlma", "central_difference")])
f <- file.path(here, "landscape.csv")
write.table(d, f, sep = ",", row.names = FALSE, append = file.exists(f), col.names = !file.exists(f))
