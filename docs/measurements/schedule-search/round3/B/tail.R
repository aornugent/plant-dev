# The tail-edge probes against the maps: ln J's predicted move (open-weighted h^3 with the
# maps' d) beside the measured move of ln J and of the elasticities.
source("/home/user/plant-dev/docs/measurements/schedule-search/round3/B/lib_b.R")
suppressMessages(source("/home/user/plant-dev/harness/schedule/evaluate.R")); EXCLUDED <- c(EXCLUDED, "rooting_depth_max")
X <- readRDS("/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/B_maps.rds"); M <- X$M
for (cs in c("dry", "episodic")) { seg <- open_segs(cs); z <- M[M$case == cs, ]
  z$G <- vapply(seq_len(nrow(z)), function(i) Eopen(z$birth[i] - z$h1[i], z$birth[i] + z$h2[i], seg) - Eopen(z$birth[i] - z$h1[i], z$birth[i], seg) - Eopen(z$birth[i], z$birth[i] + z$h2[i], seg), 0)
  z <- z[z$G > 1e-10, ]; z$d <- z$m / z$G; u <- tapply(z$d, round(z$birth, 6), median); bb <- as.numeric(names(u)); dl <- function(b) median(u[order(abs(bb - b))[1:7]])
  for (pp in list(c("val_probe_tol1e4", "val_probe_noedge25"), c("val_probe_noedge25", "val_probe_noedge"), c("val_probe_tol1e4", "val_probe_noedge"))) {
    xb <- readRDS(file.path(AR, sprintf("%s_%s.rds", pp[1], cs))); xp <- readRDS(file.path(AR, sprintf("%s_%s.rds", pp[2], cs)))
    S0 <- sort(xb$node_times); S1 <- sort(xp$node_times); keep <- S0[round(S0, 9) %in% round(S1, 9)]; pred <- 0
    for (i in seq_len(length(keep) - 1)) { a <- keep[i]; c <- keep[i + 1]; s0 <- S0[S0 >= a - 1e-12 & S0 <= c + 1e-12]; if (length(s0) <= 2) next
      pred <- pred + dl((a + c) / 2) * (Eopen(a, c, seg) - sum(vapply(seq_len(length(s0) - 1), function(j) Eopen(s0[j], s0[j + 1], seg), 0))) }
    qb <- quantities(xb); qp <- quantities(xp); k <- intersect(names(qb), names(qp)); mv <- (qp[k] - qb[k]) / eps_vec(k); o <- order(-abs(mv[-1]))[1:2] + 1
    cat(sprintf("%-9s %-19s -> %-19s tol %g/%g removed %d | lnJ pred %+.4f meas %+.4f | elas max %.2f (%s), over 0.1: %d\n", cs, pp[1], pp[2], xb$setting$tol, xp$setting$tol, length(S0) - length(keep), pred, mv["lnJ"],
      max(abs(mv[-1])), paste(sprintf("%s %+.2f", k[o], mv[o]), collapse = ", "), sum(abs(mv[-1]) > 0.1))) } }
