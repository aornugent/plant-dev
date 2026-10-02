# The probe's predictions against the measured field parts.
#
#   Rscript compare.R COARSE_REF FINE_REF SWEEP.rds [SOURCE.rds]
A <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/adjmap"
.libPaths(c(file.path(A, "lib"), .libPaths()))
suppressMessages(library(plant))
source(file.path(A, "harness", "node_parts.R"))
args <- commandArgs(TRUE)
ca <- readRDS(args[1]); cb <- readRDS(args[2]); sw <- readRDS(args[3])
src <- if (length(args) >= 4 && file.exists(args[4])) readRDS(args[4]) else NULL
options(width = 160)

a <- nodes_of(ca); b <- nodes_of(cb)
pm <- panel_moves(a, b)
Jn <- sum(a$w * a$offspring)   # J / (S_D * birth rate): the units of nodes_of
J <- ca$stand$J
pc <- function(x, d = Jn) 100 * x / d

cat(sprintf("coarse %d nodes J %.8f; fine %d nodes J %.8f\n", nrow(a), J, nrow(b), cb$stand$J))
if (!is.null(sw$base)) cat(sprintf("probe build's coarse run: J %.10f (%s the reference), %d steps (ref %d)\n",
                                   sw$base$J, if (identical(sw$base$J, J)) "identical to" else sprintf("%+.2e from", sw$base$J - J),
                                   sw$base$steps, length(ca$stand$times)))

meas_field <- sum(pm$field); meas_interp <- sum(pm$interpolation)
cat(sprintf("measured: field %+.4f%%, interpolation %+.4f%%, establishment %+.5f%%; field b<0.5 %+.4f%%\n",
            pc(meas_field), pc(meas_interp), pc(sum(pm$establishment)), pc(sum(pm$field[pm$birth < 0.5]))))

if (!is.null(sw$light)) {
  L <- sw$light; S <- sw$soil   # [band, panel], in units of J
  P <- ncol(L)
  pb <- head(a$birth, -1)       # each panel's lower node
  cat(sprintf("sweep: %.0f s cpu (%.0f wall), base forward %.0f s cpu; peak %.0f MiB\n",
              sw$sweep_cpu, sw$sweep_wall, sw$base$cpu, sw$sweep_peak_mb))
  cat(sprintf("predicted: light %+.4f%%, soil %+.4f%%, total %+.4f%% of J  (measured field %+.4f%%; ratio %.3f)\n",
              100 * sum(L) / J, 100 * sum(S) / J, 100 * (sum(L) + sum(S)) / J, pc(meas_field),
              (100 * (sum(L) + sum(S)) / J) / pc(meas_field)))
  cat(sprintf("  source panels born before 0.5: light %+.4f%%, soil %+.4f%%\n",
              100 * sum(L[, pb < 0.5]) / J, 100 * sum(S[, pb < 0.5]) / J))
  bands <- c(-Inf, sw$bands, Inf)
  bl <- sprintf("t in [%g, %g)", head(bands, -1), bands[-1])
  cat("  by time band (light, soil, % of J):\n")
  print(data.frame(band = bl, light = 100 * rowSums(L) / J, soil = 100 * rowSums(S) / J), digits = 3, row.names = FALSE)
  cut_b <- cut(pb, c(-1, 0.5, 1, 3, 10, 41), right = FALSE)
  cat("  by the source panel's birth band (light, soil, % of J):\n")
  print(data.frame(light = tapply(colSums(L), cut_b, sum) * 100 / J,
                   soil = tapply(colSums(S), cut_b, sum) * 100 / J), digits = 3)
  cat("  first panels (light, soil, % of J):\n")
  print(data.frame(panel = 1:8, lo = pb[1:8], light = 100 * colSums(L)[1:8] / J, soil = 100 * colSums(S)[1:8] / J,
                   at = sw$at[1:8], weight = sw$weight[1:8]), digits = 4, row.names = FALSE)
}

# The interpolation part from the coarse run's own nodal offspring: the finer
# node's offspring by the curvature through the neighbours either side
# (averaged), in log or linear space, at its establishment weight.
interp_est <- function(a, at, wf, log_space) {
  x <- a$birth; y <- a$offspring; n <- length(x)
  f <- if (log_space) log(pmax(y, 1e-300)) else y
  dd <- function(i) ((f[i + 2] - f[i + 1]) / (x[i + 2] - x[i + 1]) - (f[i + 1] - f[i]) / (x[i + 1] - x[i])) / (x[i + 2] - x[i])
  vapply(seq_along(at), function(p) {
    if (!is.finite(at[p]) || p + 1 > n || !is.finite(wf[p])) return(0)
    m <- at[p]; lam <- (m - x[p]) / (x[p + 1] - x[p])
    c2 <- c(if (p > 1) dd(p - 1), if (p + 2 <= n) dd(p))
    fm <- (1 - lam) * f[p] + lam * f[p + 1] + mean(c2) * (m - x[p]) * (m - x[p + 1])
    ym <- if (log_space) exp(fm) else fm
    wf[p] * (ym - ((1 - lam) * y[p] + lam * y[p + 1]))
  }, 0)
}
if (!is.null(sw$at) && !isTRUE(sw$mode == "drop")) {
  ab <- if (!is.null(sw$base$nodes)) nodes_of(list(setting = ca$setting, stand = list(nodes = sw$base$nodes))) else a
  for (ls in c(TRUE, FALSE)) {
    ie <- interp_est(ab, sw$at, sw$weight, ls)
    cat(sprintf("interpolation part from one run (%s): %+.4f%% (measured %+.4f%%; ratio %.3f); b<0.5 %+.4f%% (measured %+.4f%%)\n",
                if (ls) "log" else "linear", pc(sum(ie)), pc(meas_interp), sum(ie) / meas_interp,
                pc(sum(ie[head(ab$birth, -1) < 0.5])), pc(sum(pm$interpolation[pm$birth < 0.5]))))
  }
}

if (!is.null(src)) {
  base <- nodes_of(list(setting = ca$setting, stand = list(nodes = src$base$nodes)))
  for (ch in c("light", "soil")) {
    if (is.null(src[[ch]])) next
    pert <- nodes_of(list(setting = ca$setting, stand = list(nodes = src[[ch]]$nodes)))
    d <- base$w * (pert$offspring - base$offspring)
    cat(sprintf("source %s: J %+.4f%% of J; receivers' field part %+.4f%% (b<0.5 %+.4f%%); establishment %+.5f%%\n",
                ch, 100 * (src[[ch]]$J - src$base$J) / src$base$J, pc(sum(d)), pc(sum(d[base$birth < 0.5])),
                pc(sum((pert$w - base$w) * pert$offspring))))
    rel <- (pert$offspring - base$offspring) / base$offspring
    cat("   first nodes' offspring move (%):", sprintf("%.2f", 100 * head(rel, 8)), "\n")
  }
  cat("   measured first nodes' field part of their own (%):", sprintf("%.2f", 100 * head(pm$field / (a$w * a$offspring), 8)), "\n")
}
