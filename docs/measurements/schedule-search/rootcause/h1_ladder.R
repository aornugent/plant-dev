# h1_ladder.R: the three runs (coarse x, committed c, check f) as a ladder, without the
# reference. d1 = x - c, d2 = c - f (eps units). On the proxy's law d1/d2 = (1/s_c - 1)/(1 - s_f);
# the ratio measured (projected, <d1,d2>/|d2|^2) over that, per class, and cos(d1, d2).
# Also the error along M (the closing-edge direction) in each run.
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/common.R")
H1 <- file.path(OUT, "h1"); Z <- readRDS(file.path(H1, sprintf("h1_score_%s.rds", Sys.getenv("TAG", "insx")))); Q <- Z$Q; O <- Z$O
for (cs in O$case) { q <- Q[Q$case == cs, ]; o <- O[O$case == cs, ]; d1 <- q$ex - q$ec; d2 <- q$ec - q$ef
  want <- (1 / o$s_c - 1) / (1 - o$s_f); m <- M_unit[q$q]; m[is.na(m)] <- 0
  g <- function(j) if (sum(d2[j]^2) > 0) sum(d1[j] * d2[j]) / sum(d2[j]^2) / want else NA
  cosv <- function(j) sum(d1[j] * d2[j]) / sqrt(sum(d1[j]^2) * sum(d2[j]^2))
  cat(sprintf("%-13s law d1/d2 %.2f | measured/law: all %.2f leaf %.2f hyd %.2f other %.2f | cos all %.2f leaf %.2f hyd %.2f | rms d1 %.3f d2 %.3f | along M: x %+.2f c %+.2f f %+.2f; off-M rms x %.3f c %.3f f %.3f\n",
    cs, want, g(TRUE), g(q$cls == "leaf"), g(q$cls == "hydraulic"), g(q$cls == "other"), cosv(TRUE), cosv(q$cls == "leaf"), cosv(q$cls == "hydraulic"),
    sqrt(mean(d1^2)), sqrt(mean(d2^2)), sum(q$ex * m), sum(q$ec * m), sum(q$ef * m),
    sqrt(mean((q$ex - sum(q$ex * m) * m)^2)), sqrt(mean((q$ec - sum(q$ec * m) * m)^2)), sqrt(mean((q$ef - sum(q$ef * m) * m)^2)))) }
