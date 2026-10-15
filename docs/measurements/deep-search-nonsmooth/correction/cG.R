# cG.R TRAIT RUN UP DN OUT: round4/JT/p4G.R along any trait. For each step of RUN (A or B)
# holding f_hi sign changes, G = df/dtheta along the trajectory by central differences of
# f on the two pinned trajectories UP, DN at theta(1 +- 1e-4) (theta + -1e-4 where theta
# is 0), each at its own theta; E = h sum(b_i G(c_i)) - trapezoid(G, 48 intervals); and
# c = (theta/J/eps) lambda^T E at the step's end over the soil rows (also all rows, and
# the rows of nodes whose net production keeps its sign, as p4G.R). Writes OUT.
suppressMessages(source("/home/user/plant-dev/harness/schedule/evaluate.R"))
O <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/JT_out"
a <- commandArgs(TRUE); trait <- a[1]; nm <- a[2]; f_up <- a[3]; f_dn <- a[4]; f_out <- a[5]
ngrid <- 48; rel <- 1e-4
src <- readLines("/home/user/plant-dev/docs/measurements/schedule-search/round4/JT/probe.R")
Sys.setenv(PIN = "", LIB = file.path(dirname(O), "libJTstop"), TRAIT_REL = "")
i <- grep("^scm\\$record_trajectory", src); eval(parse(text = src[1:(i - 1)]))
th <- p$strategies[[1]]$pars[[trait]]; stopifnot(length(th) == 1)
dth <- if (th == 0) rel else rel * th
mk <- function(s) { q <- p; s_ <- q$strategies[[1]]; s_$pars[[trait]] <- th + s * dth; q$strategies[[1]] <- s_; do.call(plant:::Patch, types)(q, mkenv(scen), ct) }
hu <- mk(1); hd <- mk(-1)
xu <- readRDS(f_up); xd <- readRDS(f_dn); tu <- xu$traj; td <- xd$traj
stopifnot(isTRUE(xu$same_times), isTRUE(xd$same_times), identical(tu$t, td$t))
L <- grep("^JTROOT", readLines(file.path(O, paste0("P4_traj_", nm, ".err"))), value = TRUE)
r <- as.data.frame(do.call(rbind, lapply(strsplit(L, " "), function(z) { v <- z[-1]; setNames(as.numeric(v[seq(2, length(v), 2)]), v[seq(1, length(v), 2)]) })))
st <- unique(r[, c("t0", "h")]); st <- st[order(st$t0), ]
wd <- vapply(tu$state, length, 0); nb <- 0
LL <- grep("^LAMBDA", readLines(file.path(O, paste0("P4_lam_", nm, ".txt"))), value = TRUE)
lam <- lapply(strsplit(LL, " "), function(z) as.numeric(z[-1])); lam_t <- vapply(lam, `[`, 0, 2); lam_w <- vapply(lam, length, 0) - 3
lam_at <- function(t, w) { i <- which(abs(lam_t - t) < 1e-8 * max(1, t) & lam_w == w); if (length(i)) lam[[i[1]]][-(1:3)] else NULL }
x <- readRDS(file.path(O, paste0("P4_lam_", nm, ".rds")))
sc <- (if (th == 0) 1 else th) / x$J / eps_of(trait)
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
  G <- function(u) (U$f(u) - D$f(u)) / (2 * dth)
  ug <- seq(0, 1, length.out = ngrid + 1); Gg <- sapply(ug, G)
  quad <- h * (bb[1] * Gg[, 1] + bb[2] * G(0.3) + bb[3] * G(0.6) + bb[4] * G(0.875))
  E <- quad - h * (rowSums(Gg) - 0.5 * (Gg[, 1] + Gg[, ngrid + 1])) / ngrid
  lm <- lam_at(t0 + h, w); if (is.null(lm)) next
  soil <- (w - 9):w; keep <- rep(!(U$flip | D$flip), each = 9)
  ct <- lm * E * sc
  res[[length(res) + 1]] <- data.frame(t0 = t0, h_d = h * 365, n = sum(abs(r$t0 - t0) < 1e-9), flips = sum(U$flip),
    c_all = sum(ct), c_soil = sum(ct[soil]), c_unsplit = sum(ct[soil]) + sum(ct[1:(w - 10)][keep]),
    lam1 = lm[w - 9], dG1 = Gg[w - 9, ngrid + 1] - Gg[w - 9, 1], E1 = E[w - 9] * sc)
}
d <- do.call(rbind, res)
saveRDS(list(trait = trait, run = nm, theta = th, dth = dth, sc = sc, J_up = xu$J, J_dn = xd$J, J = x$J,
  fd_el = (xu$J - xd$J) / (2 * dth) * (if (th == 0) 1 else th) / x$J / eps_of(trait), steps = d), f_out)
cat(sprintf("%s %s: %d steps, sum c_soil %+.5f, c_all %+.5f, c_unsplit %+.5f\n", trait, nm, nrow(d), sum(d$c_soil), sum(d$c_all), sum(d$c_unsplit)))
