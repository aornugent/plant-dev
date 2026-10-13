# Q1/Q2: the merge probes against the maps. Per probe: removed and added nodes, the
# measured move of every quantity, and ln J's move predicted from the maps two ways:
# (A) each removed edge's own map move, rescaled to this geometry; (B) the open-weighted
# h^3 functional over each merged span, with d from the maps around it.
source("/home/user/plant-dev/docs/measurements/schedule-search/round3/B/lib_b.R")
suppressMessages(source("/home/user/plant-dev/harness/schedule/evaluate.R"))
EXCLUDED <- c(EXCLUDED, "rooting_depth_max")
X <- readRDS("/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/B_maps.rds"); M <- X$M
SEG <- list(); dcal <- list()
for (cs in c("dry", "long-drought")) { seg <- open_segs(cs); SEG[[cs]] <- seg; z <- M[M$case == cs, ]
  G <- vapply(seq_len(nrow(z)), function(i) Eopen(z$birth[i] - z$h1[i], z$birth[i] + z$h2[i], seg) - Eopen(z$birth[i] - z$h1[i], z$birth[i], seg) - Eopen(z$birth[i], z$birth[i] + z$h2[i], seg), 0)
  z$G <- G; z$d <- ifelse(G > 1e-12, z$m / G, NA); dcal[[cs]] <- z }
saveRDS(dcal, "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/B_dcal.rds")
dloc <- function(cs, b, k = 7) { z <- dcal[[cs]]; z <- z[!is.na(z$d) & z$G > 1e-9, ]; u <- tapply(z$d, round(z$birth, 6), median)
  bb <- as.numeric(names(u)); median(u[order(abs(bb - b))[1:k]]) }
mapA <- function(cs, b, h1, h2) { z <- dcal[[cs]]; z <- z[!is.na(z$edge) | TRUE, ]; i <- which(abs(z$birth - b) < 1e-6); if (!length(i)) return(NA)
  G <- Eopen(b - h1, b + h2, SEG[[cs]]) - Eopen(b - h1, b, SEG[[cs]]) - Eopen(b, b + h2, SEG[[cs]]); median(z$d[i], na.rm = TRUE) * G }
pr <- list(c("probe_mg10", "dry", "loc_mg10_dry"), c("probe_mgs10", "dry", "loc_mgs10_dry"), c("probe_mgt10", "dry", "loc_mgt10_dry"), c("probe_mk10", "dry", "loc_mk10_dry"),
  c("probe_mg0-10_10", "dry", "loc_mg0-10_10_dry"), c("probe_mg10-40_10", "dry", "loc_mg10-40_10_dry"), c("probe_mg5.5-5.7_10", "dry", "loc_mg5.5-5.7_10_dry"),
  c("probe_mg10", "long-drought", "loc_mg10_long-drought"), c("probe_mgs10", "long-drought", "loc_mgs10_long-drought"),
  c("probe_mg10", "dry-flat", "loc_mg10_dry-flat"), c("probe_mgs10", "dry-flat", "loc_mgs10_dry-flat"))
res <- list()
for (p in pr) { cs <- p[2]; base <- if (cs == "long-drought") "fx_a04t_c_long-drought" else sprintf("val_a04t_c_%s", cs)
  xb <- rd(file.path(AR, paste0(base, ".rds"))); xp <- rd(file.path(AR, sprintf("%s_%s.rds", p[1], cs)))
  if (is.null(xb) || is.null(xp) || is.null(xp$stand$elasticity)) { cat(p[1], cs, "missing\n"); next }
  S0 <- sort(xb$node_times); S1 <- sort(xp$node_times); rm0 <- S0[!(round(S0, 9) %in% round(S1, 9))]; ad <- S1[!(round(S1, 9) %in% round(S0, 9))]
  qb <- quantities(xb); qp <- quantities(xp); k <- intersect(names(qb), names(qp)); mv <- (qp[k] - qb[k]) / eps_vec(k)
  out <- sprintf("%-20s %-13s removed %3d added %2d rows %.3f | lnJ %+.4f | elas max %.2f (%s) rms %.3f", p[1], cs, length(rm0), length(ad), xp$stand$rows / xb$stand$rows,
    mv["lnJ"], max(abs(mv[-1])), names(which.max(abs(mv[-1]))), sqrt(mean(mv[-1]^2)))
  if (cs %in% names(SEG)) { seg <- SEG[[cs]]
    # (A) own map moves of the removed nodes at the base geometry
    A <- vapply(rm0, function(b) { i <- match(round(b, 9), round(S0, 9)); mapA(cs, b, S0[i] - S0[i - 1], S0[i + 1] - S0[i]) }, 0)
    # (B) spans of S0 between nodes kept in S1: merged with added nodes considered
    keep <- S0[round(S0, 9) %in% round(S1, 9)]; Bm <- 0; spans <- 0
    for (i in seq_len(length(keep) - 1)) { a <- keep[i]; c <- keep[i + 1]; inside0 <- S0[S0 > a + 1e-12 & S0 < c - 1e-12]; if (!length(inside0)) next
      spans <- spans + 1; S1s <- S1[S1 >= a - 1e-12 & S1 <= c + 1e-12]
      e1 <- sum(vapply(seq_len(length(S1s) - 1), function(j) Eopen(S1s[j], S1s[j + 1], seg), 0)); e0 <- sum(vapply(c(a, inside0, c)[-1], function(x) 0, 0))
      s0 <- c(a, inside0, c); e0 <- sum(vapply(seq_len(length(s0) - 1), function(j) Eopen(s0[j], s0[j + 1], seg), 0))
      Bm <- Bm + dloc(cs, (a + c) / 2) * (e1 - e0) }
    out <- paste0(out, sprintf(" || map A %+.4f (%d of %d covered) | h3 B %+.4f over %d spans", sum(A, na.rm = TRUE), sum(!is.na(A)), length(A), Bm, spans)) }
  cat(out, "\n"); res[[paste(p[1], cs)]] <- list(mv = mv, rm = rm0, ad = ad) }
saveRDS(res, "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/B_probes.rds")
