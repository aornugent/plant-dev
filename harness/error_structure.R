# How the step-3 runs' errors scale with each knob, and where in birth date the
# node error lives. Every quantity is in units of its eps
# (docs/measurements/eps.csv).
#
#   [RUNS=docs/measurements/spot-check] [NUDGES=docs/measurements/nudges] \
#     Rscript harness/error_structure.R
here <- tryCatch(dirname(sys.frame(1)$ofile), error = function(e) "harness")
runs_dir <- Sys.getenv("RUNS", file.path(here, "..", "docs", "measurements", "spot-check"))
nudge_dir <- Sys.getenv("NUDGES", file.path(here, "..", "docs", "measurements", "nudges"))
eps <- read.csv(file.path(here, "..", "docs", "measurements", "eps.csv"))
eps <- eps[eps$unit != "curvature in lma", ]
main <- c("ln J", "lma", "a_dG2", "hmat", "stem_P50", "rho")
small <- c("a_st3", "a_d0", "omega", "a_l1")
records <- c(ld = "ld_3e-5", dry = "dry_base", epi = "epi_base", wet = "wet_base",
             const = "const_base")
tol_nudge <- c(ld = "ld_3.15e-5", dry = "dry_tol", epi = "epi_tol", wet = "wet_tol",
               const = "const_tol")

eps_of <- function(role, trait) {
  e <- eps$eps[eps$role == role & eps$trait == trait]
  if (length(e)) e[1] else NA
}
# ln J and every elasticity of both roles, over eps.
quantities <- function(x) {
  out <- c()
  for (role in c("stand", "invader")) {
    r <- if (role == "stand") "resident" else "invader"
    tr <- c("ln J", sub("^1[.]", "", names(x[[role]]$elasticity)))
    v <- c(log(x[[role]]$J), unname(x[[role]]$elasticity)) /
      vapply(tr, function(t) eps_of(r, t), 0)
    names(v) <- paste(r, tr)
    out <- c(out, v)
  }
  out[is.finite(out)]
}
run <- function(k) readRDS(file.path(runs_dir, paste0(k, ".rds")))
group <- function(nm) {
  t <- sub("^(resident|invader) ", "", nm)
  paste(ifelse(t %in% main, "main", ifelse(t %in% small, "small", "other")), sub(" .*", "", nm))
}
by_group <- function(v, f) tapply(v, group(names(v)), f)
q3 <- function(v) sprintf("%.3f", v)

cat("== Long drought, seed 31, 108 nodes: the nudges' spread at three tolerances\n")
set <- function(files) do.call(cbind, lapply(files, function(f) quantities(readRDS(f))))
files <- Sys.glob(file.path(nudge_dir, "ld_*.rds"))
tols <- as.numeric(sub("^ld_(.*)[.]rds$", "\\1", basename(files)))
s4 <- set(files[tols > 5e-5])
s5 <- set(files[tols < 5e-5])
s3 <- set(file.path(runs_dir, c("ld_2.85e-5.rds", "ld_3e-5.rds", "ld_3.15e-5.rds")))
k <- Reduce(intersect, list(rownames(s4), rownames(s3), rownames(s5)))
sd4 <- apply(s4[k, ], 1, sd); sd3 <- apply(s3[k, ], 1, sd); sd5 <- apply(s5[k, ], 1, sd)
steps <- function(f) readRDS(f)$steps
cat(sprintf("steps at 1e-4 and 1e-5: %d and %d, so steps go as tol^-%.2f\n",
            steps(file.path(nudge_dir, "ld_1e-4.rds")), steps(file.path(nudge_dir, "ld_1e-5.rds")),
            log10(steps(file.path(nudge_dir, "ld_1e-5.rds")) / steps(file.path(nudge_dir, "ld_1e-4.rds")))))
move <- abs(rowMeans(s4[k, ]) - rowMeans(s5[k, ]))
print(data.frame(
  row.names = names(by_group(sd4, median)),
  spread_1e4 = q3(by_group(sd4, median)), spread_3e5 = q3(by_group(sd3, median)),
  spread_1e5 = q3(by_group(sd5, median)), largest_1e4 = q3(by_group(sd4, max)),
  largest_1e5 = q3(by_group(sd5, max)),
  exponent = sprintf("%.2f", by_group(log10(sd4 / sd5), median)),
  bias_1e4_1e5 = q3(by_group(move, median)), largest_bias = q3(by_group(move, max))))

cat("\n== Dry, 108 nodes: one nudge at 3e-5 and one at 1e-5\n")
d3 <- set(file.path(runs_dir, c("dry_base.rds", "dry_tol.rds")))
d5 <- set(file.path(runs_dir, c("dry_1e-5.rds", "dry_1.05e-5.rds")))
k <- intersect(rownames(d3), rownames(d5))
n3 <- abs(d3[k, 2] - d3[k, 1]); n5 <- abs(d5[k, 2] - d5[k, 1])
cat(sprintf("the nudge's exponent in tol, median over quantities: %.2f\n",
            median(log(n3 / n5)[n5 > 0]) / log(3)))
cat(sprintf("the move from 3e-5 to 1e-5 over the nudge at 3e-5, median: %.2f\n",
            median(abs(d3[k, 1] - d5[k, 1]) / n3)))

cat("\n== The node axis at 3e-5: the move to 215 nodes against the tolerance nudge,\n")
cat("   and (Q54 - Q108)/(Q108 - Q215), about 4 on the square law, where the move is resolved\n")
for (r in names(records)) {
  base <- quantities(run(records[[r]])); nudge <- quantities(run(tol_nudge[[r]]))
  n215 <- quantities(run(paste0(r, "_n215")))
  k <- Reduce(intersect, list(names(base), names(nudge), names(n215)))
  snr <- abs(n215[k] - base[k]) / pmax(abs(nudge[k] - base[k]), 1e-12)
  line <- sprintf("%-5s move over nudge: median %.1f", r, median(snr))
  f54 <- file.path(runs_dir, paste0(r, "_n54.rds"))
  if (file.exists(f54)) {
    n54 <- quantities(readRDS(f54)); k <- k[k %in% names(n54) & snr >= 3]
    ratio <- (n54[k] - base[k]) / (base[k] - n215[k])
    line <- paste0(line, sprintf("; ratio over %d: below 0 on %d, 2.5-6 on %d, median %.1f",
                                 length(k), sum(ratio < 0), sum(ratio >= 2.5 & ratio < 6),
                                 median(ratio)))
  }
  cat(line, "\n")
}

# J is the sum over nodes of establishment weight times net reproduction ratio,
# up to a constant factor.
nodes_of <- function(x) {
  n <- x$stand$nodes; m <- min(length(n$establishment), length(n$nrr))
  data.frame(birth = n$birth[1:m], w = n$establishment[1:m], nrr = n$nrr[1:m])
}
cat("\n== Where the move from 108 to 215 nodes in J lives, as a fraction of J\n")
cat("   field: the change in net reproduction at the 108 nodes' births, on 108's weights\n")
cat("   quadrature: the 215-node integrand on its own nodes, less on the 108 nodes\n")
bands <- c(-1, 1, 3, 41)
for (r in c("ld", "dry", "epi", "wet")) {
  a <- nodes_of(run(records[[r]])); b <- nodes_of(run(paste0(r, "_n215")))
  m <- match(round(a$birth, 10), round(b$birth, 10))
  J <- sum(a$w * a$nrr)
  field <- tapply(a$w * (b$nrr[m] - a$nrr), cut(a$birth, bands, right = FALSE), sum) / J
  quad <- (tapply(b$w * b$nrr, cut(b$birth, bands, right = FALSE), sum) -
             tapply(a$w * b$nrr[m], cut(a$birth, bands, right = FALSE), sum)) / J
  cat(sprintf("%-4s net %+.4f | field %+.4f (b<1 %+.4f, 1-3 %+.4f, later %+.4f) | quadrature %+.4f (b<1 %+.4f, 1-3 %+.4f, later %+.4f)\n",
              r, sum(field) + sum(quad), sum(field), field[1], field[2], field[3],
              sum(quad), quad[1], quad[2], quad[3]))
}

cat("\n== The first node: its share of J and its net reproduction ratio on 54, 108, 215 nodes\n")
for (r in names(records)) {
  ks <- c(paste0(r, "_n54"), records[[r]], paste0(r, "_n215"))
  ks <- ks[file.exists(file.path(runs_dir, paste0(ks, ".rds")))]
  v <- vapply(ks, function(k) { n <- nodes_of(run(k)); c(n$w[1] * n$nrr[1] / sum(n$w * n$nrr), n$nrr[1]) }, c(0, 0))
  cat(sprintf("%-5s share %s | ratio %s\n", r, paste(sprintf("%.2f", v[1, ]), collapse = " / "),
              paste(sprintf("%.3g", v[2, ]), collapse = " / ")))
}

cat("\n== What the earliest nodes cost: a node's member evaluations go as the steps after its birth\n")
for (r in names(records)) {
  x <- run(records[[r]]); cost <- vapply(x$node_times, function(b) sum(x$stand$times > b), 0)
  cat(sprintf("%-5s born before 1: %d nodes, %.3f of the cost; before 3: %d, %.3f\n", r,
              sum(x$node_times < 1), sum(cost[x$node_times < 1]) / sum(cost),
              sum(x$node_times < 3), sum(cost[x$node_times < 3]) / sum(cost)))
}
