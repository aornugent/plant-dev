# q1_conv.R: empirical order of convergence per quantity on every doubling ladder, from
# the moves between successive levels (reference-free), and the error at each level.
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/common.R")
L <- list()
for (cs in c("dry", "episodic", "episodic-lma", "long-drought", "long-wet")) {
  L[[paste0("lat-founders/", cs)]] <- sprintf("lat_%s_f%d_l70", cs, c(8, 16, 32, 64))
  L[[paste0("lat-late/", cs)]] <- sprintf("lat_%s_f16_l%s", cs, c("140", "70", "35", "17.5")) }
for (cs in c("dry", "episodic", "long-wet")) { L[[paste0("uniform/", cs)]] <- sprintf("u%d_%s", c(108, 215, 429), cs)
  L[[paste0("graded-m/", cs)]] <- sprintf("m_th0%s_%s", c("", "2", "4"), cs) }
L[["uniform/episodic2"]] <- c("u215_episodic", "u429_episodic", "u857_episodic")
L[["uniform/long-drought"]] <- sprintf("ld_D_u%d", c(54, 108, 215, 429))
L[["graded-e/dry"]] <- c("e_dyg_dry", "e_dyg2_dry", "e_dyg4_dry"); L[["graded-e/episodic"]] <- c("e_ep54g_episodic", "e_ep54g2_episodic", "e_ep54g4_episodic")
L[["graded-e2/episodic"]] <- c("e_epe_episodic", "e_epe2_episodic", "e_epe4_episodic"); L[["graded-e/long-drought"]] <- c("e_ldg_long-drought", "e_ldg2_long-drought", "e_ldg4_long-drought")
L[["graded-e/long-wet"]] <- c("e_lwg_long-wet", "e_lwg2_long-wet", "e_lwg4_long-wet")
L[["graded-B/long-drought"]] <- sprintf("ld_B_G%d", 1:3); L[["graded-BD/long-drought"]] <- sprintf("ld_BD_G%d", 1:3)
L[["graded-B/long-wet"]] <- sprintf("wet_B_G%d", 1:3); L[["graded-BD/long-wet"]] <- sprintf("wet_BD_G%d", 1:3)
L[["uniformAG/dry"]] <- sprintf("AG_ref_dry_u%d", c(215, 429, 857))
have <- function(nm) any(TAB$name == nm & TAB$grad & !TAB$bad)
HYD <- c("a_l1", "root_P50", "omega", "root_c", "stem_c", "storage_relaxation_offset")
res <- list(); perq <- list()
for (ln in names(L)) { nm <- L[[ln]]; if (!all(vapply(nm, have, TRUE))) { cat("skip", ln, "\n"); next }
  qs <- lapply(nm, function(n) { id <- TAB$id[TAB$name == n & TAB$grad & !TAB$bad][1]; qof(id)[Q] / EPS })
  cs <- sub("^.*/", "", ln); cs <- sub("2$", "", cs); bld <- if (grepl("AG", ln)) "AG" else "L19"
  ref <- REF[[bld]][[cs]]
  errs <- lapply(qs, function(q) if (!is.null(ref)) q - ref[Q] / EPS else NA)
  for (i in seq_len(length(qs) - 2)) {
    d1 <- qs[[i + 1]] - qs[[i]]; d2 <- qs[[i + 2]] - qs[[i + 1]]
    r <- sum(d1 * d2) / sum(d1^2); cosv <- sum(d1 * d2) / sqrt(sum(d1^2) * sum(d2^2))
    big <- abs(d1) > 0.25; pq <- ifelse(sign(d1) == sign(d2), log2(abs(d1) / abs(d2)), NA)
    res[[paste(ln, i)]] <- data.frame(ladder = ln, step = i, case = cs, n = paste(vapply(nm[i:(i + 2)], function(n) TAB$n[TAB$name == n][1], 1), collapse = "/"),
      d1_rms = sqrt(mean(d1^2)), d2_rms = sqrt(mean(d2^2)), cos = cosv, p_pooled = if (r > 0) -log2(r) else NA,
      lnJ_d1 = d1["lnJ"], lnJ_d2 = d2["lnJ"], p_lnJ = pq["lnJ"], n_big = sum(big), n_flip = sum(big & sign(d1) != sign(d2)),
      p_med = median(pq[big], na.rm = TRUE), p_q25 = quantile(pq[big], 0.25, na.rm = TRUE), p_q75 = quantile(pq[big], 0.75, na.rm = TRUE),
      p_hyd = median(pq[big & names(pq) %in% HYD], na.rm = TRUE), p_rest = median(pq[big & !names(pq) %in% c(HYD, "lnJ")], na.rm = TRUE),
      M_d1 = sum(d1 * M_unit), M_d2 = sum(d2 * M_unit), row.names = NULL)
    perq[[paste(ln, i)]] <- data.frame(ladder = ln, step = i, q = Q, d1 = d1, d2 = d2, p = pq, row.names = NULL) }
  if (!is.null(ref)) cat(sprintf("%-26s err rms by level: %s | lnJ %s\n", ln, paste(sprintf("%.3f", vapply(errs, function(e) sqrt(mean(e^2)), 0)), collapse = " "),
    paste(sprintf("%+.2f", vapply(errs, function(e) e["lnJ"], 0)), collapse = " "))) }
R1 <- do.call(rbind, res); P1 <- do.call(rbind, perq)
saveRDS(list(R1 = R1, P1 = P1), file.path(OUT, "q1_conv.rds"))
options(width = 220); print(format(R1, digits = 2), row.names = FALSE)
# Is the order the same per quantity? Across ladder steps with a big first move.
pq <- aggregate(p ~ q, P1[abs(P1$d1) > 0.25 & !is.na(P1$p), ], function(x) c(n = length(x), med = median(x), q25 = quantile(x, 0.25), q75 = quantile(x, 0.75)))
print(pq[order(pq$p[, "med"]), ], digits = 2)
