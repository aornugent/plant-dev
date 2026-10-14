# e5.R RUN: eigenvalues of the rates' state Jacobian at each recorded state of RUN's
# window (JT1_*), z = h*mu for the step taken from it, and the stiffest modes' make-up.
O <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/JT_out"
nmrun <- commandArgs(TRUE)[1]
x <- readRDS(file.path(O, paste0(nmrun, ".rds")))
src <- readLines("/home/user/plant-dev/docs/measurements/schedule-search/round4/JT/probe.R")
Sys.setenv(PIN = file.path(dirname(O), "P_out/runs/P_ins3c_dry.rds"))
i <- grep("^scm\\$record_trajectory", src); eval(parse(text = src[1:(i - 1)]))
out <- list(); j0 <- grep("^# A patch carrying", src); j1 <- grep("^nsoil <-", src); eval(parse(text = src[j0:j1]))
st <- x$steps; tt <- sapply(st, `[[`, "time"); on <- x$ode_names
lab <- c(paste0(rep(on, 56), "#", rep(1:56, each = 9)), paste0("env", 1:10))
res <- list()
for (j in seq_along(st)) {
  if (j == length(st)) break
  h <- tt[j + 1] - tt[j]; if (h <= 0) next
  hp$set_ode_state(st[[j]]$state, tt[j])
  Jm <- plant:::ladder_rhs_state_jacobian_forward_tf24(hp)
  e <- eigen(Jm); mu <- e$values; k <- which.min(Re(mu))
  v <- abs(e$vectors[, k]); top <- order(-v)[1:3]
  dg <- diag(Jm); kd <- order(dg)[1:3]
  res[[length(res) + 1]] <- data.frame(t = tt[j], h_d = h * 365, mu_min = Re(mu[k]), mu_im = Im(mu[k]), z = h * Re(mu[k]),
    n_unstable = sum(Re(h * mu) < -3.73), mode = paste(lab[top], collapse = ","), stiffdiag = paste(sprintf("%s:%.0f", lab[kd], dg[kd] * h), collapse = ","))
}
r <- do.call(rbind, res); options(width = 250); print(r, digits = 4)
saveRDS(r, file.path(O, paste0("e5_", nmrun, ".rds")))
