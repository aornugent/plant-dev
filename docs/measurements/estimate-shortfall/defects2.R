# Interpolation defects of the panel's cohort states at each time: dropping 8.148 from
# [7.985, 8.519] (C - P) against dropping the bisection nodes 8.067 and 8.333 (P - B),
# from the 2-day trajectories; and their ratio over time.
x <- readRDS(commandArgs(TRUE)[1]); b <- x$times; g <- x$grid
defect <- function(f, m, a, c) { fa <- approx(b, f, a, rule = 2)$y; fc <- approx(b, f, c, rule = 2)$y; fm <- approx(b, f, m, rule = 2)$y; l <- (m - a) / (c - a); fm - ((1 - l) * fa + l * fc) }
A <- 7.985226; M <- 8.148148; Z <- 8.518519
vars <- list(height = x$all$height, survival = exp(-x$all$mortality), storage = x$all$storage,
             proxy = exp(-x$all$mortality) * x$all$height^2)
for (nm in names(vars)) { v <- vars[[nm]]
  dC <- dB <- numeric(length(g))
  for (i in seq_along(g)) { f <- v[i, ]; if (anyNA(f)) { dC[i] <- dB[i] <- NA; next }
    dC[i] <- defect(f, M, A, Z); dB[i] <- defect(f, 8.066687, A, M) + defect(f, 8.333333, M, Z) }
  sel <- which(g %in% round(c(9, 9.5, 10, 10.5, 11, 12, 13, 14, 15, 17, 20, 23), 2) | apply(abs(outer(g, c(9, 9.5, 10, 10.5, 11, 12, 13, 14, 15, 17, 20, 23), "-")), 1, min) < 1e-6)
  cat(sprintf("\n%s: defect C / defect B over time\n", nm))
  print(data.frame(t = g[sel], dC = signif(dC[sel], 3), dB = signif(dB[sel], 3), ratio = round(dC[sel] / dB[sel], 2)), row.names = FALSE) }
