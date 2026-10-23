# A leaf table for one trait vector (pool row TRAIT_ROW; row 1 is the
# resident) over (light, psi_shallow, psi_deep, height), filled by plant's own
# leaf through Individual$compute_rates and read by multilinear interpolation.
# Reports its error in P against the live optimisation along the logged calls
# of that trait vector, at several grid sizes. Writes table_<n>_<psi0>_r<row>.bin
# for the in-run check (lnR.sh).
source("/home/a/dev/plant-dev/.claude/worktrees/agent-a9f1c333a8d4c65ef/spikes/leaf-table/common.R")

ROW <- as.integer(Sys.getenv("TRAIT_ROW", "1"))
TAG <- paste0(if (Sys.getenv("LMA_SHIFT", "-1") == "0") "open_" else "", "r", ROW)
TR <- pool_traits(ROW)

d <- readRDS(file.path(TMP, "inputs.rds"))
d <- d[apply(d[paste0("psi", 1:5)], 1, max) < 100, ]  # rejected-stage probes
d <- d[abs(d$vcmax_25 - TR[["vcmax_25"]]) < 1e-6 & abs(d$lma - TR[["lma"]]) < 1e-9, ]
d$psi_d <- vapply(seq_len(nrow(d)), function(k)
  deep_psi(d$height[k], unlist(d[k, paste0("psi", 1:5)]), d$rooting_depth_max[k]), 0)

# Axes on a transformed scale: light as is, soil potentials by asinh(psi/PSI0)
# (log in the wet end, linear in the dry end where P moves most), height by log.
# Bounds pad the observed range of the pinned runs.
PSI0 <- as.numeric(Sys.getenv("PSI0", "1"))
tp <- function(psi) asinh(psi / PSI0)
itp <- function(x) PSI0 * sinh(x)
AX <- list(light = c(0.08, 1), lpsi1 = tp(c(1e-4, 8)), lpsid = tp(c(1e-4, 6)),
           lh = log(c(0.3, 20)))
cat("row", ROW, "calls", nrow(d), " observed: light", range(d$light), " psi1",
    range(d$psi1), " psi_d", range(d$psi_d), " h", range(d$height), "\n")

build_table <- function(n, traits) {
  f <- leaf_eval_factory(tf24_strategy_at(traits))
  g <- Map(function(r, k) seq(r[1], r[2], length.out = k), AX, n)
  grid <- expand.grid(g)
  L <- grid$light; p1 <- itp(grid$lpsi1); pd <- itp(grid$lpsid); h <- exp(grid$lh)
  P <- vapply(seq_len(nrow(grid)), function(k)
    f(L[k], c(p1[k], pd[k], pd[k], pd[k], pd[k]), h[k])[["P"]], 0)
  list(axes = g, P = array(P, dim = lengths(g)))
}

interp <- function(tab, X) {
  # X: matrix with columns on the transformed scale, in axis order.
  nd <- length(tab$axes)
  lo <- matrix(0L, nrow(X), nd); fr <- matrix(0, nrow(X), nd)
  for (j in seq_len(nd)) {
    a <- tab$axes[[j]]; k <- length(a)
    x <- pmin(pmax(X[, j], a[1]), a[k])
    i <- pmin(findInterval(x, a, all.inside = TRUE), k - 1)
    lo[, j] <- i; fr[, j] <- (x - a[i]) / (a[i + 1] - a[i])
  }
  dims <- dim(tab$P); stride <- c(1, cumprod(dims)[-nd])
  out <- 0
  for (c in 0:(2^nd - 1)) {
    bits <- as.integer(intToBits(c))[seq_len(nd)]
    idx <- 1 + colSums(t(lo - 1 + matrix(bits, nrow(X), nd, byrow = TRUE)) * stride)
    w <- 1
    for (j in seq_len(nd)) w <- w * if (bits[j]) fr[, j] else 1 - fr[, j]
    out <- out + w * tab$P[idx]
  }
  out
}

X <- cbind(d$light, tp(d$psi1), tp(d$psi_d), log(d$height))
res <- list()
GRIDS <- list(c(12, 12, 8, 12), c(20, 20, 12, 20), c(32, 32, 16, 32))
if (nzchar(Sys.getenv("GRIDS"))) GRIDS <- GRIDS[as.integer(strsplit(Sys.getenv("GRIDS"), ",")[[1]])]
for (n in GRIDS) {
  t0 <- proc.time()[["elapsed"]]
  tab <- build_table(n, TR)
  secs <- proc.time()[["elapsed"]] - t0
  # The open stand has no logged calls: build only.
  e <- if (nrow(d) > 0) interp(tab, X) - d$P else NA_real_
  r <- data.frame(row = ROW, psi0 = PSI0, grid = paste(n, collapse = "x"),
                  points = prod(n), build_s = secs, rms = sqrt(mean(e^2)),
                  p99 = unname(quantile(abs(e), 0.99, na.rm = TRUE)), max = max(abs(e)),
                  bias = mean(e), rms_rel = sqrt(mean(e^2)) / sqrt(mean(d$P^2)))
  print(r)
  res[[length(res) + 1]] <- r
  saveRDS(list(tab = tab, err = e, d = d),
          file.path(TMP, sprintf("table_%d_%g_%s.rds", prod(n), PSI0, TAG)))
  # For the in-run check: key, psi0, dims, axes, values (light fastest).
  con <- file(file.path(TMP, sprintf("table_%d_%g_%s.bin", prod(n), PSI0, TAG)), "wb")
  writeBin(as.double(c(TR[["vcmax_25"]], PSI0, length(n), n, unlist(tab$axes), tab$P)), con)
  close(con)
}
saveRDS(do.call(rbind, res), file.path(HERE, sprintf("table_accuracy_%s.rds", TAG)))
