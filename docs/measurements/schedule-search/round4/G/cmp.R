# cmp.R NEW BASE [CASE]: a G run (G_out/runs/NEW.rds) against a saved run (adjmap/runs/BASE.rds):
# cost, steps by age band, and each quantity's move in eps (and both errors when CASE is given).
suppressMessages(source("/home/user/plant-dev/harness/schedule/evaluate.R")); EXCLUDED <<- c(EXCLUDED, "rooting_depth_max")
a <- commandArgs(TRUE); O <- file.path(DEV, "schedtest/G_out"); AR <- file.path(DEV, "schedtest/adjmap/runs")
rd1 <- function(n) { f <- file.path(O, "runs", paste0(n, ".rds")); if (file.exists(f)) readRDS(f) else readRDS(file.path(AR, paste0(n, ".rds"))) }
x <- rd1(a[1]); y <- rd1(a[2]); br <- c(0, 2, 5, 10, 20, 25, 30, 35, 40)
sb <- function(z) tapply(z$stand$times[-1], cut(z$stand$times[-1], br, right = FALSE), length)
cat(sprintf("steps %d vs %d (%.3f) | rows %.0f vs %.0f (%.3f) | cpu %.1f vs %.1f | sweep %.1f vs %.1f | splits %d vs %d\n",
  length(x$stand$times), length(y$stand$times), length(x$stand$times) / length(y$stand$times), x$stand$rows, y$stand$rows, x$stand$rows / y$stand$rows,
  x$stand$cpu, y$stand$cpu, x$sweep_cpu %||% NA, y$sweep_cpu %||% NA, sum(x$stand$splits), sum(y$stand$splits)))
cat("steps by band new: ", sb(x), "\nsteps by band base:", sb(y), "\n")
if (is.null(x$stand$elasticity)) quit()
qx <- quantities(x); qy <- quantities(y); k <- intersect(names(qx), names(qy)); d <- (qx[k] - qy[k]) / eps_vec(k)
cat(sprintf("max |move| %.3f eps (%s); rms %.3f; ln J move %.4f eps; max |el| %.2f\n", max(abs(d)), k[which.max(abs(d))], sqrt(mean(d^2)), d["lnJ"], max(abs(x$stand$elasticity))))
o <- order(-abs(d))[1:6]; cat("largest:", paste(sprintf("%s %+.3f", k[o], d[o]), collapse = ", "), "\n")
if (length(a) >= 3) { cs <- a[3]
  ref <- if (!is.null(CASES[[cs]])) reference(cs) else { u <- quantities(readRDS(file.path(AR, sprintf("ref_%s_u215.rds", cs)))); v <- quantities(readRDS(file.path(AR, sprintf("ref_%s_u429.rds", cs)))); extrap(u[k], v[k]) }
  ex <- (qx[k] - ref[k]) / eps_vec(k); ey <- (qy[k] - ref[k]) / eps_vec(k)
  cat(sprintf("error vs reference: worst new %.3f (%s), base %.3f (%s)\n", max(abs(ex)), k[which.max(abs(ex))], max(abs(ey)), k[which.max(abs(ey))])) }
