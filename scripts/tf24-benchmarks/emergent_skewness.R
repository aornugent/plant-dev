# T5a (premise check for the reconciliation / Oracle claim 4): is the weight
# skewness EMERGENT -- i.e. does the heaviest atom's mass fraction stay ~constant
# as the member mesh is refined? If max weight fraction is invariant to N, then
# tau_ins refinement adds LIGHT members but never splits the heavy atoms, so it is
# the wrong convergence axis (retrodicts 9c non-convergence; motivates T5 splitting).
# Pure measurement: run default N, 2N, 4N; read per-node weights; report the top
# atom's fraction and the top-decile concentration. No new machinery.
options(pkg.build_extra_flags = FALSE)
suppressMessages({library(odelia); pkgload::load_all("/home/user/plant-dev/plant",
                                                     export_all = TRUE, quiet = TRUE)})
cat("loaded\n"); flush(stdout())
datadir <- "/home/user/plant-dev/scripts/tf24-benchmarks/data"
outdir  <- "/home/user/plant-dev/scripts/tf24-benchmarks/results"
ctrl <- control(ode_method = "rkck", ode_tol_rel = 1e-6, ode_tol_abs = 1e-6)
jobs <- list(intense_storms = 12, long_horizon = 30)

run_sched <- function(mkpars, mkenv, sched) {
  scm <- SCM("TF24","TF24_Env")(mkpars(), mkenv(), ctrl)
  scm$set_node_schedule_times(list(sort(unique(sched)))); scm$run()
  sp <- scm$patch$species[[1]]
  # two weight notions: raw patch density (rho) and the J-contribution g = nrr*rho
  list(J = sum(scm$offspring_production), tau = sp$node_times,
       rho = sp$patch_densities,
       g   = sp$net_reproduction_ratio_by_node * sp$patch_densities)
}
frac <- function(w) { w <- abs(w); w <- w[is.finite(w)]; s <- sum(w)
  if (s <= 0) return(c(max = NA, top10 = NA, top10pct = NA))
  wr <- sort(w / s, decreasing = TRUE)
  c(max = wr[1], top10 = sum(head(wr, 10)),
    top10pct = sum(head(wr, max(1, round(0.1 * length(wr)))))) }

for (nm in names(jobs)) {
  years <- jobs[[nm]]
  b <- readRDS(file.path(datadir, paste0(nm, ".rds")))
  nd <- min(length(b$rain), round(years*365))
  rain <- b$rain[seq_len(nd)]; times <- (0:(nd-1))/365; tmax <- max(times)
  mkenv  <- function(){ e <- Environment("TF24"); e$extrinsic_drivers_set_variable("rainfall", times, rain); e }
  mkpars <- function(){ p <- scm_base_parameters("TF24"); p$max_patch_lifetime <- tmax
    add_strategies(p, trait_matrix(0.0825,"lma"), birth_rate=1) }
  scm0 <- SCM("TF24","TF24_Env")(mkpars(), mkenv(), ctrl); scm0$run()
  base <- scm0$patch$species[[1]]$node_times; N <- length(base)
  cat(sprintf("\n== %s (%dyr, default N=%d) ==\n", nm, years, N))
  cat(sprintf("%-8s %-5s %-12s %-8s %-8s %-9s\n", "mult","M","J","max_rho","max_g","top10_g"))
  densify <- function(mult) {
    if (mult == 1) return(base)
    d <- numeric(0)
    for (i in seq_len(length(base)-1)) d <- c(d, seq(base[i], base[i+1], length.out = mult+1)[-(mult+1)])
    c(d, base[length(base)])
  }
  rows <- list()
  for (m in c(1,2,4)) {
    r <- run_sched(mkpars, mkenv, densify(m))
    fr <- frac(r$rho); fg <- frac(r$g)
    rows[[as.character(m)]] <- list(r=r, fr=fr, fg=fg)
    cat(sprintf("%-8d %-5d %-12.5e %-8.3f %-8.3f %-9.3f\n",
                m, length(r$tau), r$J, fr["max"], fg["max"], fg["top10"])); flush(stdout())
  }
  saveRDS(rows, file.path(outdir, paste0("emergent_skewness_", nm, ".rds")))
}
cat("ALLDONE\n")
