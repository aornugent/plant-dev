# Q1: the per-node removal move, edges against interior nodes, by band and edge type.
source("/home/user/plant-dev/docs/measurements/schedule-search/round3/B/lib_b.R")
X <- all_maps(); M <- X$M; ET <- X$ET
saveRDS(X, "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/B_maps.rds")
M$b1 <- vapply(M$case, function(cs) ET[[cs]]$b1[1], 0); M$band <- band_of(M$birth, M$b1)
M$type <- ifelse(is.na(M$edge), "interior", "edge"); M$pass <- as.integer(sub(".*_p", "", M$run))
cat(sprintf("map runs %d, dropped nodes %d, of them edges %d\n", length(unique(M$run)), nrow(M), sum(M$type == "edge")))
q <- function(v, p) if (length(v)) quantile(v, p, names = FALSE) else NA
tab <- function(D, lab) { cat("\n==", lab, "\n")
  for (cs in names(CASES)) for (bd in levels(M$band)) for (tp in c("edge", "interior")) { z <- D[D$case == cs & D$band == bd & D$type == tp, ]
    if (!nrow(z)) next; a <- abs(z$m)
    cat(sprintf("%-13s %-6s %-8s n %4d | |m| med %.4f p90 %.4f max %.3f | sum|m| per run %.3f | <eps/50 %3.0f%% <eps/200 %3.0f%%\n", cs, bd, tp, nrow(z), median(a), q(a, .9), max(a),
      sum(a) / length(unique(z$run)), 100 * mean(a < 0.02), 100 * mean(a < 0.005))) } }
tab(M[M$pass == 0, ], "first pass of each start rule (s16, dft, th0, u108e, lma variants)")
tab(M, "all passes")
# Edge attributes, edges before 25, all passes pooled
Ed <- M[M$type == "edge" & M$birth < 25, ]
Ed <- cbind(Ed, do.call(rbind, lapply(seq_len(nrow(Ed)), function(i) ET[[Ed$case[i]]][Ed$edge[i], c("opening", "gap", "spell", "loff")])))
saveRDS(Ed, "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/B_edges.rds")
cat("\n== edges before 25, by attribute (all passes, all cases)\n")
sm <- function(g, lab) { for (lv in levels(g)) { a <- abs(Ed$m[g == lv]); if (!length(a)) next
  cat(sprintf("%-8s %-12s n %4d |m| med %.4f p90 %.4f max %.3f <eps/50 %3.0f%%\n", lab, lv, length(a), median(a), q(a, .9), max(a), 100 * mean(a < 0.02))) } }
sm(factor(ifelse(Ed$opening, "opening", "closing")), "type")
sm(cut(Ed$gap, c(0, 3, 10, 30, 90, 1e5)), "gap d")
sm(cut(Ed$spell, c(0, 3, 10, 30, 90, 1e5)), "spell d")
sm(cut(Ed$loff, c(-100, -3, -1, 0, 1, 3, 100)), "ln off/med")
sm(cut(pmin(Ed$h1, Ed$h2) * 365, c(0, 3, 10, 30, 90, 1e5)), "min h d")
# geometry-free density: d = m / (3 h1 h2 (h1 + h2)), eps per y^3
Ed$d <- Ed$m / (3 * Ed$h1 * Ed$h2 * (Ed$h1 + Ed$h2))
cat("\n|d| (eps/y^3) of edges by band:\n"); print(tapply(abs(Ed$d), list(Ed$case, band_of(Ed$birth, Ed$b1)), median))
I <- M[M$type == "interior" & M$birth < 25, ]; I$d <- I$m / (3 * I$h1 * I$h2 * (I$h1 + I$h2))
cat("|d| of interior nodes by band:\n"); print(tapply(abs(I$d), list(I$case, band_of(I$birth, I$b1)), median))
