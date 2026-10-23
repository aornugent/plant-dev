rd <- function(f) tryCatch(readRDS(f), error = function(e) NULL)
for (g in c(0, 8)) {
  p <- rd(sprintf("/tmp/front/kept_%d_1.001.rds", g)); m <- rd(sprintf("/tmp/front/kept_%d_0.999.rds", g))
  if (!is.null(p) && !is.null(m)) cat("kept GEOM", g, " F+", p$F, " F-", m$F, " F_P (central, per unit dlnP)", (p$F - m$F) / 2e-3, "\n")
}
h <- lapply(c(o = "1", p3 = "1.001", m3 = "0.999", p4 = "1.0001", m4 = "0.9999"),
            function(s) rd(sprintf("/tmp/front/held8_%s.rds", s)))
if (!is.null(h$o)) {
  cat("held GEOM 8 INV_ALL: resident F", h$o$F, " identity lnR'", h$o$lnR, "\n")
  for (k in c("p3", "m3", "p4", "m4")) if (!is.null(h[[k]]))
    cat(k, " lnR'", h[[k]]$lnR, " dlnR'", h[[k]]$lnR - h$o$lnR, "\n")
  t <- h$o$node_times[[1]]; b0 <- h$o$by_node[[1]]
  if (!is.null(h$p3)) {
    i <- which(t < 1.2)
    print(signif(rbind(t = t[i], W = b0[i], dlnW_p3 = log(h$p3$by_node[[1]][i] / b0[i]), dlnW_m3 = log(h$m3$by_node[[1]][i] / b0[i])), 3))
  }
}
