# q4_edge.R: does the edge-node geometry (a priori) or the run's own node curvature at
# edges (in-run) predict the error along M, within case and leave-one-case-out?
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/common.R")
d <- readRDS(file.path(OUT, "q4_model2.rds"))$d
d <- d[d$tol >= 1e-4 & d$build == "L19", ]
d$zEC <- d$edgeC2 / d$Jp^0.6; d$zIC <- d$insC2 / d$Jp^0.6
cat(nrow(d), "runs at 1e-4 / 3e-4, lib19\n")
cat("within-case correlation of error along M with: edge term (node at edge x h_end^2) | inset term (h_end^2 without edge node) | in-run edge curvature\n")
for (cs in ALL) { j <- d$case == cs; if (sum(j) < 8) next
  cat(sprintf("  %-13s n %3d | %+.2f | %+.2f | %+.2f | sd along M %.2f\n", cs, sum(j), cor(d$alongM[j], d$zEC[j]), cor(d$alongM[j], d$zIC[j]), cor(d$alongM[j], d$curE[j], use = "complete"), sd(d$alongM[j]))) }
r <- rep(NA, nrow(d)); r0 <- r; fm <- alongM ~ 0 + zEC + zIC + curE
for (cs in unique(d$case)) { tr <- d$case != cs; m <- lm(fm, d[tr, ]); r[!tr] <- d$alongM[!tr] - predict(m, d[!tr, ]); r0[!tr] <- d$alongM[!tr] - mean(d$alongM[tr]) }
cat(sprintf("LOCO: along-M residual rms %.2f (edge + inset + in-run curvature) against %.2f (training mean); raw rms %.2f\n", sqrt(mean(r^2, na.rm = TRUE)), sqrt(mean(r0^2)), sqrt(mean(d$alongM^2))))
print(round(coef(summary(lm(fm, d))), 4))
cat("\nsingle-predictor LOCO (through the origin), along-M residual rms (training-mean baseline 0.82):\n")
for (x in c("zEC", "zIC", "curE", "edgeC2", "zE")) { r <- rep(NA, nrow(d)); sl <- c()
  for (cs in unique(d$case)) { tr <- d$case != cs; m <- lm(as.formula(paste("alongM ~", x)), d[tr, ]); r[!tr] <- d$alongM[!tr] - predict(m, d[!tr, ]) }
  cat(sprintf("  %-7s %.2f | cor over all runs %+.2f\n", x, sqrt(mean(r^2, na.rm = TRUE)), cor(d$alongM, d[[x]], use = "complete"))) }
