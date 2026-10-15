# p4F.R NAME: for each step of run NAME (JT_out/P4_traj_NAME.rds, roots in P4_traj_NAME.err)
# holding f_hi sign changes: F = d(rates)/d(traits) at the RKCK fifth-order stage times
# (b != 0) and on a 25-point grid across the step (Hermite states), and the step's
# quadrature error E = h * sum(b_i F_i) - trapezoid(F). Saves JT_out/P4_F_NAME.rds.
O <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/JT_out"
nm <- commandArgs(TRUE)[1]; ngrid <- as.integer(Sys.getenv("NGRID", "24"))
src <- readLines("/home/user/plant-dev/docs/measurements/schedule-search/round4/JT/probe.R")
Sys.setenv(PIN = "", LIB = file.path(dirname(O), "libJTstop"))
i <- grep("^scm\\$record_trajectory", src); eval(parse(text = src[1:(i - 1)]))
tr <- readRDS(file.path(O, paste0("P4_traj_", nm, ".rds")))$traj
L <- grep("^JTROOT", readLines(file.path(O, paste0("P4_traj_", nm, ".err"))), value = TRUE)
r <- as.data.frame(do.call(rbind, lapply(strsplit(L, " "), function(z) { v <- z[-1]; setNames(as.numeric(v[seq(2, length(v), 2)]), v[seq(1, length(v), 2)]) })))
st <- unique(r[, c("t0", "h")]); st <- st[order(st$t0), ]
wd <- vapply(tr$state, length, 0)
hp <- do.call(plant:::Patch, types)(p, mkenv(scen), ct); nb <- 0
cc <- c(0, 0.3, 0.6, 0.875); bb <- c(37/378, 250/621, 125/594, 512/1771)
Fat <- function(y, t) { hp$set_ode_state(y, t); plant:::ladder_rhs_trait_jacobian_forward_tf24(hp) }
rates <- function(y, t) { hp$set_ode_state(y, t); hp$ode_rates }
LL <- grep("^LAMBDA", readLines(file.path(O, paste0("P4_lam_", nm, ".txt"))), value = TRUE)
lam <- lapply(strsplit(LL, " "), function(z) as.numeric(z[-1]))
lam_t <- vapply(lam, `[`, 0, 2); lam_w <- vapply(lam, length, 0) - 3
lam_at <- function(t, w) { i <- which(abs(lam_t - t) < 1e-8 * max(1, t) & lam_w == w); if (length(i)) lam[[i[1]]][-(1:3)] else NULL }
res <- list()
for (s in seq_len(nrow(st))) {
  t0 <- st$t0[s]; h <- st$h[s]
  je <- which(abs(tr$t - (t0 + h)) < 1e-9 * max(1, t0))
  je <- je[je > 1 & abs(tr$t[je - 1] - t0) < 1e-9 * max(1, t0) & wd[je] == wd[je - 1]]
  if (!length(je)) { cat("no rows for step at", t0, "\n"); next }
  je <- je[1]; js <- je - 1
  while (hp$ode_size < wd[js]) { nb <- nb + 1; hp$introduce_new_node(1, times[nb]) }
  if (hp$ode_size != wd[js]) { cat("width mismatch at", t0, "\n"); next }
  y0 <- tr$state[[js]]; y1 <- tr$state[[je]]; r0 <- rates(y0, t0); r1 <- rates(y1, t0 + h)
  herm <- function(u) (2*u^3 - 3*u^2 + 1) * y0 + (u^3 - 2*u^2 + u) * h * r0 + (-2*u^3 + 3*u^2) * y1 + (u^3 - u^2) * h * r1
  ug <- seq(0, 1, length.out = ngrid + 1)
  Fg <- lapply(ug, function(u) Fat(herm(u), t0 + u * h))
  Fs <- c(list(Fg[[1]]), lapply(cc[-1], function(u) Fat(herm(u), t0 + u * h)))
  quad <- h * Reduce(`+`, Map(`*`, Fs, bb))
  trap <- h * (Reduce(`+`, Fg) - 0.5 * (Fg[[1]] + Fg[[ngrid + 1]])) / ngrid
  rr <- r[abs(r$t0 - t0) < 1e-9, ]
  E <- quad - trap; w <- wd[js]; soil <- (w - 9):w; lm <- lam_at(t0 + h, w)
  res[[length(res) + 1]] <- list(t0 = t0, h = h, width = w, n = nrow(rr), u = rr$u, node = rr$node,
    up = sum(rr$v1 > rr$v0), E_soil = E[soil, ], dF_soil = Fg[[ngrid + 1]][soil, ] - Fg[[1]][soil, ],
    lam_soil = if (!is.null(lm)) lm[soil], c_all = if (!is.null(lm)) colSums(lm * E),
    c_soil = if (!is.null(lm)) colSums(lm[soil] * E[soil, , drop = FALSE]))
  if (s %% 10 == 0) { cat(s, "of", nrow(st), t0, "\n"); saveRDS(res, file.path(O, paste0("P4_F_", nm, ".rds"))) }
}
saveRDS(res, file.path(O, paste0("P4_F_", nm, ".rds"))); cat("done\n")
