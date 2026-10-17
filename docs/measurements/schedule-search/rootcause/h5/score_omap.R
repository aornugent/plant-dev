# score_omap.R CASE: O1, fate and its root_P50 sensitivity across opening edges, from the
# forward fate maps h5_omap_CASE (base) and h5_omap@p_CASE (root_P50 x 1.02).
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/h5/lib.R")
cs <- commandArgs(TRUE)[1]; rdf <- function(nm) readRDS(file.path(H5, "runs", paste0(nm, ".rds")))
a <- rdf(sprintf("h5_omap_%s", cs)); pp <- rdf(sprintf("h5_omap@p_%s", cs)); b <- a$stand$nodes$birth
stopifnot(max(abs(b - pp$stand$nodes$birth)) < 1e-12)
g <- log(a$stand$nodes$nrr); s <- (log(pp$stand$nodes$nrr) - g) / log(1.02)
et <- edge_table(cs); op <- et[et$opening & et$b > pilot_of(cs)$b1 & et$gap > 8 & et$spell > 40, ]
cr <- creation_of(cs); prf <- function(t) cr$rate[pmax(1, findInterval(t, cr$start))]
off <- c(-6, -3, -1, 0, 1, 2, 3, 4.5, 6, 8, 10, 12, 15, 18, 22, 26, 30, 36)
R <- do.call(rbind, lapply(op$b, function(o) { j <- sapply(off, function(d) { i <- which(abs(b - (o + d / 365)) < 1e-6); if (length(i)) i[1] else NA }); if (anyNA(j)) return(NULL)
  G <- g[j]; S <- s[j]; at <- function(v, d) v[off == d]
  q <- function(v, m) unname(coef(lm(v[m] ~ off[m] + I(off[m]^2)))[3]) * 2            # second derivative, per d^2
  k_strip <- q(G, off >= 0 & off <= 12); k_far <- q(G, off >= 12)
  sl_l <- (at(G, -1) - at(G, -3)) / 2; sl_r <- (at(G, 2) - at(G, 0)) / 2; sl_spell <- (at(G, 12) - at(G, 0)) / 12
  ks_strip <- q(S, off >= 0 & off <= 12); ks_far <- q(S, off >= 12)
  s1 <- (at(S, 6) - at(S, 0)) / 6; s2 <- (at(S, 12) - at(S, 6)) / 6; s3 <- (at(S, 24 + 2) - at(S, 12)) / 14
  pm <- mean(prf(o + seq(5, 30) / 365))
  data.frame(edge = o, gap = op$gap[op$b == o], spell = op$spell[op$b == o], g_m3 = at(G, -3), g0 = at(G, 0), g12 = at(G, 12), g36 = at(G, 36),
    sl_gap = sl_l * 1e3, sl_o = sl_r * 1e3, sl_strip = sl_spell * 1e3, k_strip = k_strip * 1e4, k_far = k_far * 1e4,
    s_m3 = at(S, -3), s0 = at(S, 0), s6 = at(S, 6), s12 = at(S, 12), s36 = at(S, 36), sl_s_0_6 = s1 * 1e3, sl_s_6_12 = s2 * 1e3, sl_s_12_26 = s3 * 1e3,
    ks_strip = ks_strip * 1e4, ks_far = ks_far * 1e4, pr0.5 = prf(o + 0.5 / 365) / pm, pr1 = prf(o + 1 / 365) / pm, pr2 = prf(o + 2 / 365) / pm, pr4 = prf(o + 4 / 365) / pm) }))
op0 <- options(width = 250); print(format(R, digits = 3), row.names = FALSE)
cat(sprintf("\n%s: %d edges | O1a |k_strip| <= 2|k_far|: %d/%d (median ratio %.2f) | O1b |slope jump at o| < |slope at o|: %d/%d | O1c sensitivity slope sign change at 6 d (0-6 vs 6-12): %d/%d; |ks_strip| / |ks_far| median %.2f\n",
  cs, nrow(R), sum(abs(R$k_strip) <= 2 * abs(R$k_far)), nrow(R), median(abs(R$k_strip) / abs(R$k_far)), sum(abs(R$sl_o - R$sl_gap) < abs(R$sl_o)), nrow(R),
  sum(sign(R$sl_s_0_6) != sign(R$sl_s_6_12)), nrow(R), median(abs(R$ks_strip) / abs(R$ks_far))))
cat(sprintf("medians: ln nrr slope (1e-3/d) gap side %.2f, at o %.2f, over strip %.2f | curvature (1e-4/d^2) strip %.2f far %.2f | s at o-3/o/o+12/o+36: %.3f %.3f %.3f %.3f | pr after o vs spell mean: 0.5 d %.2f, 1 d %.2f, 2 d %.2f, 4 d %.2f\n",
  median(R$sl_gap), median(R$sl_o), median(R$sl_strip), median(R$k_strip), median(R$k_far), median(R$s_m3), median(R$s0), median(R$s12), median(R$s36), median(R$pr0.5), median(R$pr1), median(R$pr2), median(R$pr4)))
saveRDS(R, file.path(H5, sprintf("omap_%s.rds", cs)))
