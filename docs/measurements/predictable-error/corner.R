# At each opening and shutting (pA4L), the slope of log fate across birth date on
# the closed side (from the nodes in the gap) and on the open side.
x <- readRDS("../placed2/runs/pA4L_episodic.rds"); n <- x$stand$nodes; m <- length(n$birth)
b <- n$birth; lf <- log(pmax(n$nrr, 1e-12)); cnt <- n$establishment[1:m]
cr <- x$stand$creation; op <- cr$rate > 0.01; r <- rle(op); e <- cumsum(r$lengths)
ed <- data.frame(t = cr$end[e][-length(e)], kind = ifelse(r$values[-length(r$values)], "shuts", "opens"))
ed <- subset(ed, t > 2 & t < 30)
sl <- function(i) if (length(i) >= 2) coef(lm(lf[i] ~ b[i]))[2] else NA
res <- t(sapply(seq_len(nrow(ed)), function(k) {
  t <- ed$t[k]; w <- 0.06
  before <- which(b > t - w & b < t); after <- which(b > t & b < t + w)
  c(t = t, before = sl(before), after = sl(after))
}))
res <- data.frame(kind = ed$kind, res)
res$jump <- res$after - res$before
print(aggregate(cbind(before, after, jump) ~ kind, res, median))
cat("share of openings where the slope falls across the edge (a peak):", mean(res$jump[res$kind == "opens"] < 0, na.rm = TRUE), "\n")
cat("share of shuttings where the slope rises across the edge:", mean(res$jump[res$kind == "shuts"] > 0, na.rm = TRUE), "\n")
cat("median |slope jump| at edges", median(abs(res$jump), na.rm = TRUE), "; median |slope| inside windows",
    median(abs(diff(lf)/diff(b))[cnt[-m] > 0.5 * max(cnt)], na.rm = TRUE), "per year of birth date\n")
