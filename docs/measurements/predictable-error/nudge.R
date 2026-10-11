src <- readLines("../placement/score.R")
eval(parse(text = src[1:grep("^fmt <-", src)]))
Q <- file.path(D, "schedtest", "placed2", "runs")
g <- function(k) quantities(rd(Q, paste0(k, "_episodic")))
cmp <- function(a, b) {
  qa <- g(a); qb <- g(b); k <- intersect(names(qa), names(qb)); k <- k[!endsWith(k, nuisance)]
  m <- abs(qa[k] - qb[k]) / eps_vec(k)
  sprintf("%-14s vs %-8s median %.3f  90%% %.3f  max %.3f  ln J %.4f", a, b, median(m), quantile(m, .9), max(m), m[["resident ln J"]])
}
for (pr in list(c("pAL_up", "pAL"), c("pAL_dn", "pAL"), c("pAL_up", "pAL_dn"), c("pA2L_up", "pA2L"),
                c("pAL", "pA2L"), c("pA2L", "pA4L"), c("pA", "pA2"), c("pA2", "pA4"))) cat(cmp(pr[1], pr[2]), "\n")
