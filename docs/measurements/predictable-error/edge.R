# Split each level's drop map into panels at a creation-window edge (a node of
# the panel, or a neighbour, with establishment below 90% of the full-window
# weight) and interior panels; compare levels.
source("../adjmap/lib.R")
lv <- c(u108 = "map_e108", u215 = "map_e215", u429 = "map_e429")
res <- list()
for (k in names(lv)) {
  x <- run(lv[[k]]); J <- x$stand$J; b <- nd(x); j <- x$dropped
  full <- median(b$w[b$w > 0])
  edge <- pmin(b$w[j - 1], b$w[j], b$w[j + 1]) < 0.9 * full
  JnP <- sum(b$w * b$offspring)
  own <- own_drop(b, j) / JnP
  fe <- colSums(x$soil + x$light) / J
  early <- colSums((x$soil + x$light)[1:6, , drop = FALSE]) / J   # t < 10
  late <- colSums((x$soil + x$light)[7:8, , drop = FALSE]) / J    # t > 10
  res[[k]] <- c(n_edge = sum(edge), n_int = sum(!edge),
    field_edge = sum(fe[edge]), field_int = sum(fe[!edge]),
    abs_edge = sum(abs(fe[edge])), abs_int = sum(abs(fe[!edge])),
    late_edge = sum(late[edge]), late_int = sum(late[!edge]),
    early_edge = sum(early[edge]), early_int = sum(early[!edge]),
    own_edge = sum(own[edge]), own_int = sum(own[!edge]))
}
r <- do.call(rbind, res); print(signif(r, 3))
cat("\nratios (coarser / finer):\n")
print(round(rbind(`u108/u215` = r[1, ] / r[2, ], `u215/u429` = r[2, ] / r[3, ]), 2))
