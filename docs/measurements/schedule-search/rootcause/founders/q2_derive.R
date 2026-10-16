# q2_derive.R: the interpolation part against the derivation. For a founders' window of
# spacing h over fate nrr(b) = exp(g(b)), ln J's interpolation part is
# (h^2/12) * share_F * <g'^2 + g''> (E nrr-weighted mean over [0, b1)); for a pure
# exponential of scale L this is (h/L)^2 share_F / 12. kappa = measured / (h/L)^2 share/12.
suppressMessages(source("/home/user/plant-dev/harness/schedule/evaluate.R"))
FO <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/founders"
S <- readRDS(file.path(FO, "q2_shape.rds"))
cat("case | I(f32) measured (eps) | (h/L)^2 share/12 with L of the first fifth | kappa | with <g'^2+g''> from the f64 nodes | ratio\n")
for (cs in names(S)) { s <- S[[cs]]; b <- s$b; g <- s$g; b1 <- pilot_edges(cs)$b1; h <- b1 / 32
  x <- readRDS(file.path(ADJ, sprintf("lat_%s_f64_l70.rds", cs)))$stand; n <- x$nodes; m <- length(n$birth); w <- n$establishment[1:m]
  i <- which(n$birth < b1 - 1e-9); f <- n$nrr; A <- sum(w * f)
  gp <- c(NA, (g[-(1:2)] - g[1:(length(g) - 2)]) / (b[-(1:2)] - b[1:(length(b) - 2)]), NA)
  gpp <- c(NA, diff(diff(g)) / diff(b)[-1]^2, NA)
  k <- 2:(length(g) - 1); curv <- sum(w[i][k] * f[i][k] * (gp[k]^2 + gpp[k])) / A    # share-weighted <g'^2 + g''>
  I32 <- 4 / 3 * s$parts["interp"]
  L <- -1 / mean(diff(g[b < b1 / 5]) / diff(b[b < b1 / 5]))
  pred1 <- (h / L)^2 * s$share / 12; pred2 <- h^2 / 12 * curv
  cat(sprintf("%-13s %.4f | %.4f | %.2f | %.4f | %.2f\n", cs, I32 / 0.025, pred1 / 0.025, I32 / pred1, pred2 / 0.025, I32 / pred2)) }
