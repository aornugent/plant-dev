# Localise the SCM/IBM individual-growth gap: are the RATES different at an
# identical state, or is the integration different?  Take the SCM's own node
# state and (a) recompute its height rate in a fixed open environment, (b)
# re-integrate it with plant's single-individual runner.
source("probes/lib.R"); setwd("/home/user/plant-dev")
TEND <- 3.0
p0 <- add_strategies(scm_base_parameters("TF24","TF24_Env"), trait_matrix(0.1978791,"lma"))
tt <- p0$node_schedule_times[[1]]; tt <- tt[tt <= TEND]

p <- p0; p$max_patch_lifetime <- TEND; p$node_schedule_times <- list(tt)
p$strategies[[1]]$birth_rate_y <- 1e-6
ct <- Control(); ct$node_density_in_birth_date <- TRUE
scm <- scm_collect(p, "TF24", ct)
tm <- vapply(seq_along(scm$history), function(k) scm$history[[k]]$time, 0)

env <- Environment("TF24"); env$set_fixed_environment(1.0, 150)
s1  <- p0$strategies[[1]]
nms <- TF24_Individual(s1)$ode_names
cat("ode_names:", paste(nms, collapse=" "), "\n\n")

grab <- function(k) {
  sp <- scm$history[[k]]$species[[1]]
  if (!length(sp$nodes)) return(NULL)
  sp$nodes[[1]]$individual
}
cat("=== rate('height') at the SCM's own node state, SCM env vs fixed open env ===\n")
cat(sprintf("%8s %10s %14s %14s %8s | %14s %14s\n",
    "time","height","dh/dt SCM","dh/dt fixed","ratio","storage SCM","dS/dt SCM"))
for (tgt in c(0.05, 0.25, 0.5, 1, 1.5, 2, 2.5, 3)) {
  k <- which.min(abs(tm - tgt)); ind <- grab(k); if (is.null(ind)) next
  st <- vapply(nms, function(n) ind$state(n), 0)
  i2 <- TF24_Individual(s1)
  for (n in nms) i2$set_state(n, st[[n]])
  i2$compute_rates(env)
  cat(sprintf("%8.3f %10.5f %14.6e %14.6e %8.4f | %14.4e %14.4e\n",
      tm[k], ind$state("height"), ind$rate("height"), i2$rate("height"),
      ind$rate("height")/i2$rate("height"), ind$state("storage"), ind$rate("storage")))
}

cat("\n=== re-integrate the SCM's birth state with plant's individual runner ===\n")
k0 <- which(vapply(seq_along(scm$history), function(k) length(scm$history[[k]]$species[[1]]$nodes) > 0, TRUE))[1]
ind0 <- grab(k0); t0 <- tm[k0]
st0 <- vapply(nms, function(n) ind0$state(n), 0)
cat(sprintf("SCM node-1 state at t=%.6g: %s\n", t0,
    paste(sprintf("%s=%.6e", nms, st0), collapse="  ")))
i3 <- TF24_Individual(s1); for (n in nms) i3$set_state(n, st0[[n]])
times <- seq(0.02, TEND - t0, by = 0.02)
r <- grow_individual_to_time(i3, times, env)
hh <- vapply(r$individual, function(i) i$state("height"), 0)
aa <- vapply(r$individual, function(i) i$compute_competition(0), 0)
hs <- approx(tm, vapply(seq_along(scm$history), function(k) {
        ii <- grab(k); if (is.null(ii)) NA_real_ else ii$state("height") }, 0),
      times + t0, rule = 2)$y
as <- approx(tm, vapply(seq_along(scm$history), function(k) {
        ii <- grab(k); if (is.null(ii)) NA_real_ else ii$compute_competition(0) }, 0),
      times + t0, rule = 2)$y
cat(sprintf("%8s %12s %12s %8s | %12s %12s %8s\n",
    "age","h SCM","h re-int","ratio","a SCM","a re-int","ratio"))
for (tgt in c(0.25,0.5,1,1.5,2,2.5,2.98)) {
  i <- which.min(abs(times - tgt))
  cat(sprintf("%8.2f %12.5f %12.5f %8.4f | %12.4e %12.4e %8.4f\n",
      times[i], hs[i], hh[i], hs[i]/hh[i], as[i], aa[i], as[i]/aa[i]))
}

cat("\n=== SCM node-1 ode_state vs its individual's states (layout check) ===\n")
k <- which.min(abs(tm - 1)); sp <- scm$history[[k]]$species[[1]]
os <- sp$ode_state
cat("species ode_size =", sp$ode_size, " n nodes =", length(sp$nodes),
    " per-node =", sp$ode_size/length(sp$nodes), "\n")
cat("node ode_names  :", paste(plant:::Node("TF24","TF24_Env")(s1)$ode_names, collapse=" "), "\n")
cat("first 8 of species ode_state:", paste(sprintf("%.6e", head(os, 8)), collapse=" "), "\n")
ind <- grab(k)
cat("node-1 individual states    :",
    paste(sprintf("%s=%.6e", nms, vapply(nms, function(n) ind$state(n), 0)), collapse=" "), "\n")
cat("node-1 log_density          :", sp$log_densities[1], "\n")
