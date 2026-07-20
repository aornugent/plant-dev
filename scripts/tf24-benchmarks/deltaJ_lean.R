# Leanest lineage decomposition: ONE scenario, short horizon, TWO modest fixed
# meshes (default pattern vs 2x-densified). One R session. Answers only the
# qualitative question: is the inter-mesh J spread concentrated at a few lineage
# ages (survival bits) or diffuse across the member axis?

options(pkg.build_extra_flags = FALSE)
suppressMessages({
  library(odelia); pkgload::load_all("/home/user/plant-dev/plant",
                                     export_all = TRUE, quiet = TRUE)
})
cat("loaded\n"); flush(stdout())
datadir <- "/home/user/plant-dev/scripts/tf24-benchmarks/data"
outdir  <- "/home/user/plant-dev/scripts/tf24-benchmarks/results"
nm <- "intense_storms"; years <- 10

b <- readRDS(file.path(datadir, paste0(nm, ".rds")))
nd <- min(length(b$rain), round(years * 365))
rain <- b$rain[seq_len(nd)]; times <- (0:(nd - 1)) / 365; tmax <- max(times)
mkenv <- function() { e <- Environment("TF24")
  e$extrinsic_drivers_set_variable("rainfall", times, rain); e }
mkpars <- function() { p <- scm_base_parameters("TF24"); p$max_patch_lifetime <- tmax
  add_strategies(p, trait_matrix(0.0825, "lma"), birth_rate = 1) }
ctrl <- control(ode_method = "rkck", ode_tol_rel = 1e-6, ode_tol_abs = 1e-6)

densify <- function(t, k) { if (k <= 1) return(t); out <- numeric(0)
  for (i in seq_len(length(t)-1)) out <- c(out, seq(t[i], t[i+1], length.out=k+1)[-(k+1)])
  c(out, t[length(t)]) }

run_fixed <- function(sched) {
  scm <- SCM("TF24","TF24_Env")(mkpars(), mkenv(), ctrl)
  scm$set_node_schedule_times(list(sched)); scm$run()
  sp <- scm$patch$species[[1]]
  list(J=sum(scm$offspring_production), tau=sp$node_times,
       fec=sp$net_reproduction_ratio_by_node, pdens=sp$patch_densities)
}

scm0 <- SCM("TF24","TF24_Env")(mkpars(), mkenv(), ctrl); scm0$run()
base <- scm0$patch$species[[1]]$node_times
cat("base n:", length(base), " J0:", sum(scm0$offspring_production), "\n"); flush(stdout())
A <- run_fixed(base)                 # coarse (default pattern)
cat("A done n:", length(A$tau), " JA:", A$J, "\n"); flush(stdout())
B <- run_fixed(densify(base, 2))     # 2x densified
cat("B done n:", length(B$tau), " JB:", B$J, "\n"); flush(stdout())

gA_n <- A$fec*A$pdens; gB_n <- B$fec*B$pdens
grid <- seq(0, tmax, length.out=4000)
gA <- approx(A$tau, gA_n, grid, rule=2)$y
gB <- approx(B$tau, gB_n, grid, rule=2)$y
dG <- gA - gB; ad <- abs(dG); tot <- sum(ad)
cum <- cumsum(sort(ad, decreasing=TRUE))/tot
fa <- function(p) which(cum>=p)[1]/length(cum)
o <- order(ad, decreasing=TRUE)
saveRDS(list(nm=nm, years=years, base=base, A=A, B=B, grid=grid, gA=gA, gB=gB, dG=dG),
        file.path(outdir, "deltaJ_lean.rds"))
cat(sprintf("\nRESULT %s(%dyr): nA=%d nB=%d  relAB=%.3f\n", nm, years,
    length(A$tau), length(B$tau), abs(A$J-B$J)/A$J))
cat(sprintf("axis_50=%.3f axis_80=%.3f axis_90=%.3f  cancel=%.3f\n",
    fa(0.5), fa(0.8), fa(0.9), abs(sum(dG))/tot))
cat(sprintf("top |dG| lineage ages: %s (tmax=%.1f)\n",
    paste(round(grid[o[1:5]],2), collapse=", "), tmax))
cat("ALLDONE\n")
