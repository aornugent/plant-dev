# An error indicator from inside one run: the birth-date integrand f = rate * nrr from the
# run's own nodes, its local second difference, and sum h^3 |f''| / 12 relative to the integral.
source("/home/user/plant-dev/docs/measurements/schedule-search/round4/F/lib.R")
indicator <- function(x, shut, upto = 25) { n <- x$stand$nodes; S <- n$birth; m <- length(S)
  h <- diff(S); w <- c(h[1] / 2, (head(h, -1) + tail(h, -1)) / 2, h[m - 1] / 2); f <- n$establishment[1:m] / w * n$nrr
  Q <- sum(n$establishment[1:m] * n$nrr)
  i <- 2:(m - 1); f2 <- 2 * ((f[i + 1] - f[i]) / h[i] - (f[i] - f[i - 1]) / h[i - 1]) / (h[i] + h[i - 1])
  hh <- (h[i] + h[i - 1]) / 2; ok <- S[i] < upto & shut(S[i]) < 0.5 & shut(S[i - 1] + 1e-9) < 0.5 & shut(S[i + 1] - 1e-9) < 0.5
  sum(hh[ok]^3 * abs(f2[ok]) / 12) / Q }
rows <- list(); for (cs in ALL) { P <- pair(cs); rows[[cs]] <- data.frame(case = cs, I = indicator(P$xc, P$p$shut), If = indicator(P$xf, P$p$shut),
  rms = sqrt(mean(P$ec^2)), worst = max(abs(P$ec)), lnJ = abs(P$ec["lnJ"]), rmsf = sqrt(mean(P$ef^2))) }
d <- do.call(rbind, rows); d$I <- signif(d$I, 3); d$If <- signif(d$If, 3); d[, 4:7] <- round(d[, 4:7], 3); print(d, row.names = FALSE)
cat("cor(log I, log rms) over ten:", round(cor(log(d$I), log(d$rms)), 2), "; f/c indicator ratio", paste(round(d$If / d$I, 2), collapse = " "), "\n")
for (u in list(c("F_use_dryp50", "dry", "dry-p50"), c("F_use_lma", "episodic", "episodic-lma"))) { A <- pair(u[2]); B <- pair(u[3]); x <- readRDS(file.path(R, paste0(u[1], ".rds")))
  q <- quantities(x); k <- intersect(B$k, names(q)); eu <- (q[k] - B$ref[k]) / eps_vec(k)
  cat(sprintf("%s on %s's grid: indicator ratio theta1/theta0 %.2f (own-pilot shut), rms error ratio %.2f, worst ratio %.2f\n", u[3], u[2],
    indicator(x, B$p$shut) / indicator(A$xc, A$p$shut), sqrt(mean(eu^2)) / sqrt(mean(A$ec[k]^2)), max(abs(eu)) / max(abs(A$ec[k])))) }
