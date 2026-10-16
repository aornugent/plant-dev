# q3_fd.R: Q3d. Per-cohort sensitivity of fate to root_P50 (field included): s(b) =
# (ln nrr at root_P50 x 1.02 - ln nrr at base) / ln 1.02, from the fate-map forward runs
# (cl_map_CASE, cl_mapp_CASE). Over each long spell's last 36 d (3-d grid) its second
# difference per day^2 (median |.| over [-36, -12] and [-12, 0]) and its rise over the
# gap's first 10 d; per case, medians over edges.
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/closing/lib.R")
out <- list()
for (cs in c("dry", "long-wet")) { a <- rd(sprintf("cl_map_%s", cs)); p <- rd(sprintf("cl_mapp_%s", cs)); b <- a$stand$nodes$birth
  stopifnot(max(abs(b - p$stand$nodes$birth)) < 1e-12); s <- (log(p$stand$nodes$nrr) - log(a$stand$nodes$nrr)) / log(1.02)
  et <- edge_table(cs); ce <- et[!et$opening & et$b > PIL[[cs]]$b1 & et$spell > 60, ]
  R <- do.call(rbind, lapply(ce$b, function(c0) { o <- seq(-36, 0, by = 3); v <- sapply(o, function(d) { j <- which(abs(b - (c0 + d / 365)) < 1e-6); if (length(j)) s[j[1]] else NA })
    if (anyNA(v)) return(NULL); k2 <- diff(v, differences = 2) / 9; mid <- o[2:(length(o) - 1)]
    g <- sapply(c(2, 7), function(d) { j <- which(abs(b - (c0 + d / 365)) < 1e-6); if (length(j)) s[j[1]] else NA })
    data.frame(case = cs, edge = c0, gap = ce$gap[ce$b == c0], s36 = v[1], s12 = v[o == -12], s0 = v[length(v)], s_gap7 = g[2],
      k_far = median(abs(k2[mid < -12])) * 1e3, k_near = median(abs(k2[mid >= -12])) * 1e3, k_sgn = mean(sign(k2))) }))
  out[[cs]] <- R; print(format(R, digits = 3), row.names = FALSE)
  cat(sprintf("%s: %d edges | median |s| at c-36 %.3f, c %.3f | rise c-12 -> c %.3f | median |curvature| 1e-3/d^2: far %.4f near %.4f (near/far %.2f) | mean sign of curvature %+.2f\n\n",
    cs, nrow(R), median(abs(R$s36)), median(abs(R$s0)), median(R$s0 - R$s12), median(R$k_far), median(R$k_near), median(R$k_near / R$k_far), mean(R$k_sgn))) }
d <- out$dry; w <- out[["long-wet"]]
cat(sprintf("dry / long-wet: median |curvature| over the last 36 d %.2f x (far %.2f x, near %.2f x)\n", median(c(d$k_far, d$k_near)) / median(c(w$k_far, w$k_near)), median(d$k_far) / median(w$k_far), median(d$k_near) / median(w$k_near)))
