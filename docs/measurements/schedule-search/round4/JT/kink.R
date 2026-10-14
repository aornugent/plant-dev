# kink.R: the rates' TF24_cost_scale column (forward tangent) on a fine grid through one
# node's Interior -> BoundaryCrit switch (psi_stem reaching psi_crit), A's steps, Hermite
# states. Shows whether d(rate)/d(theta) jumps there. Args: NODE T0 T1 DT
O <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/JT_out"
arg <- commandArgs(TRUE); nd <- as.integer(arg[1]); t0 <- as.numeric(arg[2]); t1 <- as.numeric(arg[3]); dt <- as.numeric(arg[4])
x <- readRDS(file.path(O, "JT1_A.rds"))
src <- readLines("/home/user/plant-dev/docs/measurements/schedule-search/round4/JT/probe.R")
Sys.setenv(PIN = file.path(dirname(O), "P_out/runs/P_ins3c_dry.rds"))
i <- grep("^scm\\$record_trajectory", src); eval(parse(text = src[1:(i - 1)]))
out <- list(); j0 <- grep("^# A patch carrying", src); j1 <- grep("^nsoil <-", src); eval(parse(text = src[j0:j1]))
nm <- plant:::census_trait_names_tf24(scm); ic <- which(nm == "1.TF24_cost_scale")
st <- x$steps; tt <- sapply(st, `[[`, "time"); on <- x$ode_names
res <- NULL
for (t in seq(t0, t1, by = dt)) {
  j <- max(which(tt <= t)); a <- st[[j]]; b <- st[[j + 1]]; h <- b$time - a$time; u <- (t - a$time) / h
  y <- (2*u^3 - 3*u^2 + 1) * a$state + (u^3 - 2*u^2 + u) * h * a$rates + (-2*u^3 + 3*u^2) * b$state + (u^3 - u^2) * h * b$rates
  hp$set_ode_state(y, t); r <- hp$ode_rates
  n <- hp$species[[1]]$nodes[[nd]]$individual
  Jt <- plant:::ladder_rhs_trait_jacobian_forward_tf24(hp)[, ic]
  base <- (nd - 1) * 9
  res <- rbind(res, data.frame(t = t, psi_stem = n$aux("opt_psi_stem"), E = n$aux("transpiration"), P = n$aux("net_mass_production_dt"),
    d_height = Jt[base + 1], d_storage = Jt[base + 6], d_soil1 = Jt[length(Jt) - 9], d_soil1_rate = r[length(r) - 9]))
}
options(width = 200); print(res, digits = 5)
saveRDS(res, file.path(O, sprintf("kink_node%d.rds", nd)))
