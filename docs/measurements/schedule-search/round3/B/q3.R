# Q1 (a09 geometry) and Q3: each edge of a09's committed schedule (before 25), its
# single-removal move of ln J predicted from the maps' d and a09's own neighbours; then a
# greedy, cluster-aware thinning (each step re-prices the merged span with the
# open-weighted h^3 functional) and the rows it saves by rows = a n + c sum(39.6 - b).
source("/home/user/plant-dev/docs/measurements/schedule-search/round3/B/lib_b.R")
suppressMessages(source("/home/user/plant-dev/harness/schedule/anyscore.R"))
X <- readRDS("/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/B_maps.rds"); M <- X$M
KEEP_BAND <- as.numeric(Sys.getenv("TAU1", 0.005)); BUDGET <- as.numeric(Sys.getenv("BUDGET", 0.05)); CAP <- Sys.getenv("CAP", "1") == "1"
dcal <- list(); for (cs in names(CASES)) { seg <- open_segs(cs); z <- M[M$case == cs, ]
  z$G <- vapply(seq_len(nrow(z)), function(i) Eopen(z$birth[i] - z$h1[i], z$birth[i] + z$h2[i], seg) - Eopen(z$birth[i] - z$h1[i], z$birth[i], seg) - Eopen(z$birth[i], z$birth[i] + z$h2[i], seg), 0)
  z <- z[z$G > 1e-10, ]; z$d <- z$m / z$G; dcal[[cs]] <- z }
dfun <- function(cs) { z <- dcal[[cs]]; u <- tapply(z$d, round(z$birth, 6), median); bb <- as.numeric(names(u))
  if (Sys.getenv("DMODE") == "band") { b1 <- edge_table(cs)$b1[1]; g <- band_of(bb, b1); bm <- tapply(u, g, median); return(function(b) bm[[as.character(band_of(b, b1))]]) }
  function(b) { i <- which(abs(bb - b) < 1e-6); if (length(i)) return(u[[i[1]]]); median(u[order(abs(bb - b))[1:7]]) } }
tot <- c(n0 = 0, rows0 = 0, rows1 = 0)
for (cs in names(CASES)) { cd <- prepare(case = cs); co <- coef(cd$rowsfit); seg <- open_segs(cs); df <- dfun(cs); ET <- edge_table(cs)
  S <- sort(readRDS(file.path(LOC, sprintf("loc_a09_c_%s.rds", cs)))); isE <- vapply(S, function(s) min(abs(ET$e - s)) < 1e-6, TRUE)
  cand <- which(isE & S < 25)
  single <- vapply(cand, function(i) df(S[i]) * Emerge(S, S[i - 1], S[i + 1], seg), 0) / 1  # eps of ln J
  q <- abs(single)
  cat(sprintf("\n%-13s a09 nodes %d, edges<25 %d | single-removal |m|: med %.4f, <eps/50 %.0f%%, <eps/200 %.0f%%, sum of those <eps/50 %.4f\n", cs, length(S), length(cand), median(q), 100 * mean(q < 0.02), 100 * mean(q < 0.005), sum(q[q < 0.02])))
  # greedy cluster-aware thinning
  T <- S; spent <- 0; removed <- c()
  cap <- function(a, c) { if (!CAP) return(TRUE); h <- c - a; if (a < 20) h <= 100 / 365 + 1e-9 else h <= 280 / 365 + 1e-9 }
  repeat { idx <- which(round(T, 10) %in% round(S[cand], 10)); if (!length(idx)) break
    cost <- vapply(idx, function(i) { a <- T[i - 1]; c <- T[i + 1]; if (!cap(a, c)) return(Inf)
      df(T[i]) * (Eopen(a, c, seg) - Eopen(a, T[i], seg) - Eopen(T[i], c, seg)) }, 0)
    k <- which.min(abs(cost)); if (!is.finite(cost[k]) || abs(cost[k]) > KEEP_BAND || spent + abs(cost[k]) > BUDGET) break
    spent <- spent + abs(cost[k]); removed <- c(removed, T[idx[k]]); T <- T[-idx[k]] }
  r0 <- co[1] * length(S) + co[2] * sum(H - S); r1 <- co[1] * length(T) + co[2] * sum(H - T)
  ETr <- ET[match(round(removed, 10), round(ET$e, 10)), ]
  cat(sprintf("  greedy (per-step <= %.3f eps, total <= %.3f eps): removed %d edges (%.0f%% of edges<25), predicted |dlnJ| %.4f eps | rows %.0f -> %.0f (%.1f%%) | a %.0f c %.0f\n",
    KEEP_BAND, BUDGET, length(removed), 100 * length(removed) / length(cand), spent, r0, r1, 100 * (1 - r1 / r0), co[1], co[2]))
  cat(sprintf("  removed by band: %s | by adjacent gap: %s | by spell: %s\n", paste(table(band_of(removed, ET$b1[1])), collapse = "/"),
    paste(table(cut(ETr$gap, c(0, 3, 10, 30, 1e5))), collapse = "/"), paste(table(cut(ETr$spell, c(0, 3, 10, 30, 1e5))), collapse = "/")))
  tot <- tot + c(length(S), r0, r1)
  saveRDS(T, sprintf("/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/B_thin_%s_%g_%g%s.rds", cs, KEEP_BAND, BUDGET, Sys.getenv("DMODE"))) }
cat(sprintf("\nTOTAL rows %.0f -> %.0f (%.1f%%)\n", tot[2], tot[3], 100 * (1 - tot[3] / tot[2])))
