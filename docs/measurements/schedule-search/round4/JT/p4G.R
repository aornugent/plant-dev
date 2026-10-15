# p4G.R NAME: for each step of run NAME holding f_hi sign changes, G = df/dtheta along the
# trajectory (TF24_cost_scale), by central differences of f on the two pinned
# trajectories at theta(1 +- 1e-4) (P4_traj_NAME_{up,dn}.rds), each at its own theta; the
# step's quadrature error E_G = h sum(b_i G(c_i)) - trapezoid(G, 48 intervals), and its
# contraction with lambda at the step's end: all rows, soil rows, and the rows of nodes
# whose net production keeps its sign over the step (the split takes the others).
O <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/JT_out"
nm <- commandArgs(TRUE)[1]; ngrid <- 48; rel <- 1e-4
src <- readLines("/home/user/plant-dev/docs/measurements/schedule-search/round4/JT/probe.R")
Sys.setenv(PIN = "", LIB = file.path(dirname(O), "libJTstop"), TRAIT_REL = "")
i <- grep("^scm\\$record_trajectory", src); eval(parse(text = src[1:(i - 1)]))
th <- p$strategies[[1]]$pars$TF24_cost_scale
mk <- function(f) { q <- p; s_ <- q$strategies[[1]]; s_$pars$TF24_cost_scale <- th * (1 + f); q$strategies[[1]] <- s_; do.call(plant:::Patch, types)(q, mkenv(scen), ct) }
hu <- mk(rel); hd <- mk(-rel)
tu <- readRDS(file.path(O, paste0("P4_traj_", nm, "_up.rds")))$traj; td <- readRDS(file.path(O, paste0("P4_traj_", nm, "_dn.rds")))$traj
L <- grep("^JTROOT", readLines(file.path(O, paste0("P4_traj_", nm, ".err"))), value = TRUE)
r <- as.data.frame(do.call(rbind, lapply(strsplit(L, " "), function(z) { v <- z[-1]; setNames(as.numeric(v[seq(2, length(v), 2)]), v[seq(1, length(v), 2)]) })))
st <- unique(r[, c("t0", "h")]); st <- st[order(st$t0), ]
wd <- vapply(tu$state, length, 0); nb <- 0
LL <- grep("^LAMBDA", readLines(file.path(O, paste0("P4_lam_", nm, ".txt"))), value = TRUE)
lam <- lapply(strsplit(LL, " "), function(z) as.numeric(z[-1])); lam_t <- vapply(lam, `[`, 0, 2); lam_w <- vapply(lam, length, 0) - 3
lam_at <- function(t, w) { i <- which(abs(lam_t - t) < 1e-8 * max(1, t) & lam_w == w); if (length(i)) lam[[i[1]]][-(1:3)] else NULL }
x <- readRDS(file.path(O, paste0("P4_lam_", nm, ".rds"))); sc <- th / x$J / 0.0196115
cc <- c(0, 0.3, 0.6, 0.875); bb <- c(37/378, 250/621, 125/594, 512/1771)
fr <- function(hp, y, t) { hp$set_ode_state(y, t); hp$ode_rates }
Pof <- function(hp) vapply(hp$species[[1]]$nodes, function(n) n$individual$aux("net_mass_production_dt"), 0)
res <- list()
for (s in seq_len(nrow(st))) {
  t0 <- st$t0[s]; h <- st$h[s]
  je <- which(abs(tu$t - (t0 + h)) < 1e-9 * max(1, t0)); je <- je[je > 1 & abs(tu$t[je - 1] - t0) < 1e-9 * max(1, t0) & wd[je] == wd[je - 1]]
  if (!length(je)) next
  je <- je[1]; js <- je - 1; w <- wd[js]
  while (hu$ode_size < w) { nb <- nb + 1; hu$introduce_new_node(1, times[nb]); hd$introduce_new_node(1, times[nb]) }
  if (hu$ode_size != w) next
  H <- function(tr, hp) { y0 <- tr$state[[js]]; y1 <- tr$state[[je]]; r0 <- fr(hp, y0, t0); P0 <- Pof(hp); r1 <- fr(hp, y1, t0 + h); P1 <- Pof(hp)
    list(f = function(u) { y <- (2*u^3 - 3*u^2 + 1) * y0 + (u^3 - 2*u^2 + u) * h * r0 + (-2*u^3 + 3*u^2) * y1 + (u^3 - u^2) * h * r1; fr(hp, y, t0 + u * h) }, flip = sign(P0) != sign(P1)) }
  U <- H(tu, hu); D <- H(td, hd)
  G <- function(u) (U$f(u) - D$f(u)) / (2 * rel * th)
  ug <- seq(0, 1, length.out = ngrid + 1); Gg <- sapply(ug, G)
  quad <- h * (bb[1] * Gg[, 1] + bb[2] * G(0.3) + bb[3] * G(0.6) + bb[4] * G(0.875))
  E <- quad - h * (rowSums(Gg) - 0.5 * (Gg[, 1] + Gg[, ngrid + 1])) / ngrid
  lm <- lam_at(t0 + h, w); if (is.null(lm)) next
  soil <- (w - 9):w; nn <- (w - 10) / 9; keep <- rep(!(U$flip | D$flip), each = 9)
  ct <- lm * E * sc
  res[[length(res) + 1]] <- data.frame(t0 = t0, h_d = h * 365, n = sum(abs(r$t0 - t0) < 1e-9), flips = sum(U$flip),
    c_all = sum(ct), c_soil = sum(ct[soil]), c_unsplit = sum(ct[soil]) + sum(ct[1:(w - 10)][keep]),
    lam1 = lm[w - 9], dG1 = Gg[w - 9, ngrid + 1] - Gg[w - 9, 1], E1 = E[w - 9] * sc)
  if (s %% 20 == 0) { cat(s, "of", nrow(st), t0, "\n"); saveRDS(do.call(rbind, res), file.path(O, paste0("P4_G_", nm, ".rds"))) }
}
saveRDS(do.call(rbind, res), file.path(O, paste0("P4_G_", nm, ".rds"))); cat("done\n")
