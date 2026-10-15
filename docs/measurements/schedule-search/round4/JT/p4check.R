# p4check.R NAME T0: one step's c (TF24_cost_scale, eps) with the integral of F by
# trapezoid on 24 and 96 intervals and by Simpson on 96, and which rows carry it.
O <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/JT_out"
a <- commandArgs(TRUE); nm <- a[1]; T0 <- as.numeric(a[2])
src <- readLines("/home/user/plant-dev/docs/measurements/schedule-search/round4/JT/p4F.R")
i <- grep("^res <- list\\(\\)", src); eval(parse(text = src[1:(i - 1)]))
x <- readRDS(file.path(O, paste0("P4_lam_", nm, ".rds"))); tn <- names(x$gradient); k <- which(tn == "1.TF24_cost_scale")
sc <- x$theta[k] / x$J / 0.0196115
s <- which.min(abs(st$t0 - T0)); t0 <- st$t0[s]; h <- st$h[s]
je <- which(abs(tr$t - (t0 + h)) < 1e-9 * max(1, t0)); je <- je[je > 1 & abs(tr$t[je - 1] - t0) < 1e-9 * max(1, t0) & wd[je] == wd[je - 1]][1]; js <- je - 1
while (hp$ode_size < wd[js]) { nb <- nb + 1; hp$introduce_new_node(1, times[nb]) }
y0 <- tr$state[[js]]; y1 <- tr$state[[je]]; r0 <- rates(y0, t0); r1 <- rates(y1, t0 + h)
herm <- function(u) (2*u^3 - 3*u^2 + 1) * y0 + (u^3 - 2*u^2 + u) * h * r0 + (-2*u^3 + 3*u^2) * y1 + (u^3 - u^2) * h * r1
Fk <- function(u) Fat(herm(u), t0 + u * h)[, k]
lm <- lam_at(t0 + h, wd[js]); w <- wd[js]
ug <- seq(0, 1, length.out = 97); G <- sapply(ug, Fk)
quad <- h * (bb[1] * G[, 1] + bb[2] * Fk(0.3) + bb[3] * Fk(0.6) + bb[4] * Fk(0.875))
trap <- function(idx) { g <- G[, idx]; n <- length(idx) - 1; h * (rowSums(g) - 0.5 * (g[, 1] + g[, n + 1])) / n }
simp <- h * (G[, 1] + G[, 97] + 4 * rowSums(G[, seq(2, 96, 2)]) + 2 * rowSums(G[, seq(3, 95, 2)])) / (3 * 96)
for (lab in c("trap24", "trap96", "simp96")) { I <- switch(lab, trap24 = trap(seq(1, 97, 4)), trap96 = trap(1:97), simp96 = simp)
  E <- quad - I; ct <- lm * E * sc; nn <- (w - 10) / 9
  byvar <- tapply(ct[1:(w - 10)], rep(c("height","mortality","fecundity","area_heartwood","mass_heartwood","storage","offspring","int_est","int_est_mom"), nn), sum)
  cat(sprintf("%s: c %+.5f, soil %+.5f\n", lab, sum(ct), sum(ct[(w - 9):w]))); print(signif(byvar, 3)) }
cat(sprintf("step %.5f h %.2f d, roots %d\n", t0, h * 365, sum(abs(r$t0 - t0) < 1e-9)))
E <- quad - simp; ct <- lm * E * sc; top <- order(-abs(ct))[1:4]
cat("top rows:", top, " node", (top - 1) %/% 9 + 1, " var", (top - 1) %% 9 + 1, " c", signif(ct[top], 3), " lambda", signif(lm[top], 3), "\n")
rr <- r[abs(r$t0 - t0) < 1e-9, ]; cat("roots: node", rr$node + 1, " u", round(rr$u, 4), "\n")
for (q in top[1:2]) { nd <- (q - 1) %/% 9 + 1
  aux <- t(sapply(ug[seq(1, 97, 4)], function(u) { hp$set_ode_state(herm(u), t0 + u * h); r_ <- hp$ode_rates; n_ <- hp$species[[1]]$nodes[[nd]]$individual
    c(u = u, F = Fk(u)[q], storage = herm(u)[q], P = n_$aux("net_mass_production_dt"), fhi = n_$aux("arm_margin_dry"), rate = r_[q]) }))
  print(signif(aux, 4)) }
