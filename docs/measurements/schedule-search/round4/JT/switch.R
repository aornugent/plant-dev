# switch.R: the number of nodes (and the seedling) whose stem sits at psi_crit
# (Interior -> BoundaryCrit) on a fine Hermite grid of A's states. Args: T0 T1 DT
O <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/JT_out"
arg <- as.numeric(commandArgs(TRUE)); x <- readRDS(file.path(O, "JT1_A.rds"))
src <- readLines("/home/user/plant-dev/docs/measurements/schedule-search/round4/JT/probe.R")
Sys.setenv(PIN = file.path(dirname(O), "P_out/runs/P_ins3c_dry.rds"))
i <- grep("^scm\\$record_trajectory", src); eval(parse(text = src[1:(i - 1)]))
out <- list(); j0 <- grep("^# A patch carrying", src); j1 <- grep("^nsoil <-", src); eval(parse(text = src[j0:j1]))
st <- x$steps; tt <- sapply(st, `[[`, "time"); res <- NULL
for (t in seq(arg[1], arg[2], by = arg[3])) {
  j <- max(which(tt <= t)); a <- st[[j]]; b <- st[[j + 1]]; h <- b$time - a$time; u <- (t - a$time) / h
  y <- (2*u^3 - 3*u^2 + 1) * a$state + (u^3 - 2*u^2 + u) * h * a$rates + (-2*u^3 + 3*u^2) * b$state + (u^3 - u^2) * h * b$rates
  hp$set_ode_state(y, t); r <- hp$ode_rates; sp <- hp$species[[1]]
  ps <- vapply(sp$nodes, function(n) n$individual$aux("opt_psi_stem"), 0)
  res <- rbind(res, data.frame(t = t, pinned = sum(ps >= max(ps) - 1e-6 & max(ps) > 5.9), seed_pinned = sp$new_node$individual$aux("opt_psi_stem") > 5.9198))
}
print(res[c(TRUE, diff(res$pinned) != 0), ]); saveRDS(res, file.path(O, "switch_A.rds"))
