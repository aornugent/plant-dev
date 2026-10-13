# How an edge's removal move scales with its neighbours: the same edge dropped in
# several map runs with different neighbour spacings. And dry's edges near 5.4.
X <- readRDS("/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/B_maps.rds"); M <- X$M; ET <- X$ET
E <- M[!is.na(M$edge) & M$birth < 25, ]; E$key <- paste(E$case, E$edge)
E$G3 <- 3 * E$h1 * E$h2 * (E$h1 + E$h2); E$G1 <- E$h1 * E$h2 / (E$h1 + E$h2)
fit <- list(); for (k in unique(E$key)) { z <- E[E$key == k & abs(E$m) > 1e-4, ]; z <- z[!duplicated(round(z$G3, 12)), ]
  if (nrow(z) >= 2 && diff(range(log(z$G3))) > 0.3) fit[[k]] <- c(s3 = unname(coef(lm(log(abs(m)) ~ log(G3), z))[2]), s1 = unname(coef(lm(log(abs(m)) ~ log(G1), z))[2]), n = nrow(z), med = median(abs(z$m)), samesign = abs(mean(sign(z$m))))
}
F <- do.call(rbind, fit); cat(sprintf("edges with >=2 geometries: %d\n", nrow(F)))
cat("slope of log|m| on log(3 h1 h2 (h1+h2)) [1 = smooth h^3 law]:\n"); print(quantile(F[, "s3"], c(.1, .25, .5, .75, .9)))
cat("slope on log(h1 h2 / (h1+h2)) [1 = a corner, first order]:\n"); print(quantile(F[, "s1"], c(.1, .25, .5, .75, .9)))
big <- F[F[, "med"] > 0.01, , drop = FALSE]; cat(sprintf("edges with median |m| > 0.01: %d; slope s3 median %.2f, s1 median %.2f; sign consistent %.0f%%\n", nrow(big), median(big[, "s3"]), median(big[, "s1"]), 100 * mean(big[, "samesign"] == 1)))
# Interior nodes for comparison
I <- M[is.na(M$edge) & M$birth > M$b1 & M$birth < 20, ]; I$key <- paste(I$case, round(I$birth, 6))
fi <- c(); for (k in unique(I$key)) { z <- I[I$key == k & abs(I$m) > 1e-4, ]; G3 <- 3 * z$h1 * z$h2 * (z$h1 + z$h2); ok <- !duplicated(round(G3, 12))
  if (sum(ok) >= 2 && diff(range(log(G3[ok]))) > 0.3) fi <- c(fi, coef(lm(log(abs(z$m[ok])) ~ log(G3[ok])))[2]) }
cat(sprintf("interior nodes b1-20 with >=2 geometries: %d, slope s3 quartiles %s\n", length(fi), paste(round(quantile(fi, c(.25, .5, .75)), 2), collapse = " ")))
cat("\ndry edges 5.2-5.8 in the maps (move in eps, neighbours in days):\n")
z <- M[M$case == "dry" & !is.na(M$edge) & M$birth > 5.2 & M$birth < 5.8, ]
print(data.frame(run = z$run, b = round(z$birth, 4), h1 = round(z$h1 * 365, 1), h2 = round(z$h2 * 365, 1), m = signif(z$m, 3), own = signif(z$own, 3)), row.names = FALSE)
print(ET$dry[ET$dry$e > 5.2 & ET$dry$e < 5.8, ])
