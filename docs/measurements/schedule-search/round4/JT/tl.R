# tl.R: A's pinned replay (lib19, forward), then at every recorded state the number of
# nodes whose stem sits at psi_crit (BoundaryCrit) and whose net production is negative.
# A step whose count changes holds that many arm switches. OUT=JT_out/tl_A.rds
S <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest"
Sys.setenv(LIB = file.path(S, "adjmap/lib19"), PIN = file.path(S, "P_out/runs/P_ins3c_dry.rds"))
src <- readLines("/home/user/plant-dev/docs/measurements/schedule-search/round4/JT/probe.R")
i <- grep("^nm <- plant:::census_trait_names_tf24", src); eval(parse(text = src[1:(i - 1)]))
rows <- scm$store_trajectory(); tt <- vapply(rows, `[[`, 0, "time"); wd <- vapply(rows, function(r) length(r$state), 0)
hp <- do.call(plant:::Patch, types)(p, mkenv(scen), ct); nb <- 0
res <- matrix(NA, length(rows), 4, dimnames = list(NULL, c("t", "crit", "neg", "nodes")))
for (k in seq_along(rows)) {
  while (hp$ode_size < wd[k]) { nb <- nb + 1; hp$introduce_new_node(1, times[nb]) }
  if (hp$ode_size != wd[k]) next
  hp$set_ode_state(rows[[k]]$state, tt[k]); r <- hp$ode_rates; nd <- hp$species[[1]]$nodes
  ps <- vapply(nd, function(n) n$individual$aux("opt_psi_stem"), 0); P <- vapply(nd, function(n) n$individual$aux("net_mass_production_dt"), 0)
  res[k, ] <- c(tt[k], sum(ps > 5.9198), sum(P < 0), length(nd))
  if (k %% 500 == 0) { cat(k, tt[k], "\n"); saveRDS(res, Sys.getenv("OUT")) }
}
saveRDS(res, Sys.getenv("OUT")); cat("done\n")
