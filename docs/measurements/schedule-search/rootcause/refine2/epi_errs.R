suppressMessages(source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/refine/lib.R"))
O <- file.path(SP, "refine/s05/epi-adG208"); R <- ref_ladder("epi-adG208"); cat("rungs", R$rungs, "\n")
L <- function(n) qv(readRDS(file.path(O, paste0(n, ".rds"))))
e <- sapply(c("level0", "level1", "level2", "level0_replay", "level1_shortback", "level2_shortback", "level0_on_level1_steps"), function(n) (L(n) - R$ref) / EPS)
f1 <- readRDS(file.path(SP, "refine/s1/epi-adG208.rds")); h <- f1$history[[1]]
s1err <- (h$answer[Q] - R$ref) / EPS
d <- data.frame(q = Q, e0 = e[, 1], e1 = e[, 2], e2 = e[, 3], r01 = e[, 1] / e[, 2], r12 = e[, 2] / e[, 3],
  est_rep = (e[, 4] - e[, 1]) / 3, est01 = (e[, 1] - e[, 2]) / 3, est12 = (e[, 2] - e[, 3]) / 3,
  s1_err = s1err, s1_est = h$estimate[Q], s1_read = h$estimate[Q] / s1err, own = R$own)
d <- d[order(-abs(d$e1)), ]; options(width = 220); print(format(d, digits = 2), row.names = FALSE)
saveRDS(list(e = e, R = R), "errs.rds")
