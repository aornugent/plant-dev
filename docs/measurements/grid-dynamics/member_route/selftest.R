# Checks before any measurement:
#  1. the field's reconstruction: resident steps re-taken from the rebuilt start
#     state, in the driver's arithmetic, reproduce the recorded end states;
#  2. the species route rates a member exactly as a standalone node does, and a
#     resident-trait member rated in the field exactly as the resident patch
#     rates its own node;
#  3. the methods as implemented reproduce harness/stability.R on y' = -y/tau;
#  4. the cost of a field and of a member rating.
#   PLANT_LIB=$DEV/lib_guard Rscript selftest.R
source("/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/spike_methods/snap/spike_lib.R")
cat("recording", REC, ":", K, "steps; nodes", nk[1], "to", nk[K], "\n")

# 1. The driver's combine(), and one Cash-Karp step of the whole resident.
combine <- function(y, a, k, h) {
  nz <- which(a != 0)
  if (length(nz) == 1L) return(y + a[nz] * h * k[[nz]])
  s <- a[nz[1]] * k[[nz[1]]]
  for (m in nz[-1]) s <- s + a[m] * k[[m]]
  y + h * s
}
tab <- TABLEAU$ck
check_steps <- c(1L, k_intro[c(2, 40, 80)], which.max(st$h * (t_beg > 25)), K)
for (k in check_steps) {
  pd <- get_patch(nk[k], "d")
  y <- y_beg(k)
  h <- st$h[k]
  kk <- list(pd$derivs(y, t_beg[k]))
  for (i in 2:6) kk[[i]] <- pd$derivs(combine(y, tab$A[i, ], kk, h), t_beg[k] + tab$c[i] * h)
  y1 <- combine(y, tab$b, kk, h)
  cat(sprintf("step %5d (t %.4f, %.2f d, %d nodes%s): re-taken end %s the recording (largest difference %.3g)\n",
              k, t_beg[k], h * 365, nk[k], if (k %in% k_intro) ", after an introduction" else "",
              if (identical(y1, states[[k]])) "IDENTICAL to" else "differs from", max(abs(y1 - states[[k]]))))
}
# The rainfall-free field patch builds the same field.
pf <- get_patch(nk[K], "f"); pd <- get_patch(nk[K], "d")
stopifnot(identical(pf$derivs(states[[K]], t_end[K])[1:(9 * nk[K])], pd$derivs(states[[K]], t_end[K])[1:(9 * nk[K])]))
cat("constant-rain field patch: members' rates identical to the record's patch\n")

# 2. Members: species route against standalone nodes, and the resident's own node.
tau <- 30.5
Y <- list()
for (i in seq_along(INV)) {
  Y[[i]] <- matrix(0, 7, 0)
  for (j in c(5, 20, 60)) Y[[i]] <- add_member(i, Y[[i]], times[j], j)
}
fld <- field_at(tau)
# advance the members crudely so their states are not initial ones
for (n in 1:3) { R <- rates_at(tau, Y, fld); Y <- lin(Y, 0.01, 1, list(R)) }
R <- rates_at(tau, Y, fld)
worst <- 0
for (i in seq_along(INV)) for (m in seq_len(ncol(Y[[i]]))) {
  nd <- INV[[i]]$nodes[[m]]
  nd$ode_state <- c(Y[[i]][, m], 0, 0)
  nd$compute_rates(fld$env, fld$pr)
  worst <- max(worst, max(abs(nd$ode_rates[1:7] - R[[i]][, m])))
}
cat("species route against standalone nodes: largest difference", worst, "\n")
# a resident-trait invader at the recorded state of resident node j, at a recorded time
k <- step_of(30.5); kk <- k
sd <- step_data(kk)
res <- make_invader("lma=1")
INV[["lma=1"]] <- res
i1 <- length(INV)
yres <- states[[kk]]
pd <- get_patch(nk[kk], "d")
d <- pd$derivs(yres, t_end[kk])
fld1 <- field_at(t_end[kk], sd)
Ym <- matrix(0, 7, 0)
for (j in c(3, 30, nk[kk])) Ym <- add_member(i1, Ym, times[j], j)
for (m in 1:3) Ym[, m] <- yres[9 * (INV[[i1]]$node[m] - 1) + 1:7]
Yl <- vector("list", i1); for (i in seq_len(i1)) Yl[[i]] <- matrix(0, 7, 0); Yl[[i1]] <- Ym
R1 <- rates_at(t_end[kk], Yl, fld1)[[i1]]
for (m in 1:3) {
  j <- INV[[i1]]$node[m]
  ref <- d[9 * (j - 1) + 1:7]
  cat(sprintf("resident node %d at t %.4f: invader route against the patch's own rates, largest relative difference %.3g\n",
              j, t_end[kk], max(abs(R1[, m] - ref) / pmax(abs(ref), 1e-300))))
}
# the resident's own introduced node against a resident-trait member seeded in the field
j <- 50
yj <- y0_intro[[j]][9 * (j - 1) + 1:7]
Yb <- add_member(i1, matrix(0, 7, 0), times[j], j)
cat(sprintf("node %d at birth: seeded member against the resident's introduced node, relative differences %s\n",
            j, paste(sprintf("%.2g", abs(Yb[, 1] - yj) / pmax(abs(yj), 1e-300)), collapse = " ")))
INV[["lma=1"]] <- NULL

# 3. The methods on y' = -y/tau (every state), against harness/stability.R.
lin_rates <- function(tau_s) function(t, Yx, fld = NULL) {
  out <- lapply(Yx, function(m) -m / tau_s)
  attr(out, "msg") <- lapply(Yx, function(m) rep(NA_character_, ncol(m)))
  out
}
old_cap <- capacity
capacity <- function(i, h) rep(1, length(h))
Y1 <- list(matrix(1, 7, 1))
for (dd in c(15, 26)) {
  f <- lin_rates(TAU_S)
  K0 <- f(0, Y1)
  res <- list(CK = step_erk(TABLEAU$ck, 0, dd * DAY, Y1, K0, f),
              DP = step_erk(TABLEAU$dp, 0, dd * DAY, Y1, K0, f),
              Tsit = step_erk(TABLEAU$tsit, 0, dd * DAY, Y1, K0, f),
              SSPRK = step_ssprk(0, dd * DAY, Y1, K0, f),
              RODAS = step_rodas(0, dd * DAY, Y1, K0, f, rodas_prep(0, Y1, K0, f, NULL)))
  cat(sprintf("y' = -y/7d, %g-day step, lowest stage / result: %s\n", dd,
              paste(sprintf("%s %+.2f / %+.3f", names(res),
                            vapply(res, function(r) min(vapply(r$Ys, function(y) y[[1]][6, 1], 0)), 0),
                            vapply(res, function(r) r$Y1[[1]][6, 1], 0)), collapse = ", ")))
}
capacity <- old_cap

# 4. Cost.
INV <- lapply(INVADERS, make_invader)
names(INV) <- INVADERS
Y <- list()
for (i in seq_along(INV)) {
  Y[[i]] <- matrix(0, 7, 0)
  for (j in MEMBERS[times[MEMBERS] < 30]) Y[[i]] <- add_member(i, Y[[i]], times[j], j)
}
cat("members per invader:", vapply(Y, ncol, 0), "\n")
sd <- step_data(step_of(30.2))
t0 <- proc.time()[["elapsed"]]
for (n in 1:50) fld <- field_at(30.2 + n * 1e-5, sd)
t1 <- proc.time()[["elapsed"]]
for (n in 1:50) R <- rates_at(30.2, Y, fld)
t2 <- proc.time()[["elapsed"]]
cat(sprintf("ms per field %.2f, per rating of %d members %.2f\n", (t1 - t0) / 50 * 1e3,
            sum(vapply(Y, ncol, 0)), (t2 - t1) / 50 * 1e3))
