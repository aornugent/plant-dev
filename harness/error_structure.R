# How the step-3 runs' errors scale with each knob, and where in birth date the
# node error lives. Every quantity is in units of its eps
# (docs/measurements/eps.csv).
#
#   [RUNS=docs/measurements/spot-check] [NUDGES=docs/measurements/nudges] \
#     [GRIDS=docs/measurements/creation-grid] Rscript harness/error_structure.R
here <- tryCatch(dirname(sys.frame(1)$ofile), error = function(e) "harness")
runs_dir <- Sys.getenv("RUNS", file.path(here, "..", "docs", "measurements", "spot-check"))
nudge_dir <- Sys.getenv("NUDGES", file.path(here, "..", "docs", "measurements", "nudges"))
grid_dir <- Sys.getenv("GRIDS", file.path(here, "..", "docs", "measurements", "creation-grid"))
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
    if (is.null(x[[role]]$elasticity)) next
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

source(file.path(here, "node_parts.R"))
cat("\n== Where the move from 108 to 215 nodes in J lives, as a fraction of J\n")
cat("   field: the change in net reproduction at the 108 nodes' births, on 108's weights\n")
cat("   quadrature: the 215-node integrand on its own nodes, less on the 108 nodes\n")
for (r in c("ld", "dry", "epi", "wet")) {
  p <- node_parts(nodes_of(run(records[[r]])), nodes_of(run(paste0(r, "_n215"))), c(-1, 1, 3, 41))
  field <- p$field; quad <- p$quad
  cat(sprintf("%-4s net %+.4f | field %+.4f (b<1 %+.4f, 1-3 %+.4f, later %+.4f) | quadrature %+.4f (b<1 %+.4f, 1-3 %+.4f, later %+.4f)\n",
              r, sum(field) + sum(quad), sum(field), field[1], field[2], field[3],
              sum(quad), quad[1], quad[2], quad[3]))
}

cat("\n== The first node: its share of J and its net reproduction ratio on 54, 108, 215 nodes\n")
for (r in names(records)) {
  ks <- c(paste0(r, "_n54"), records[[r]], paste0(r, "_n215"))
  ks <- ks[file.exists(file.path(runs_dir, paste0(ks, ".rds")))]
  v <- vapply(ks, function(k) { n <- nodes_of(run(k)); c(n$w[1] * n$offspring[1] / sum(n$w * n$offspring), n$nrr[1]) }, c(0, 0))
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

cat("\n== Long drought at 3e-5 on node ladders that nest: (Q1 - Q2)/(Q2 - Q3), 4 on the\n")
cat("   square law, where the finer move is at least three times the tolerance nudge\n")
ladders <- list(
  "uniform 108, 215, 429" = c(file.path(runs_dir, c("ld_3e-5.rds", "ld_n215.rds")),
                              file.path(grid_dir, "ld_u429_full.rds")),
  "graded G1, G2, G3" = file.path(grid_dir, c("ld_G1_full.rds", "ld_G2_full.rds", "ld_G3_full.rds")))
base <- quantities(run(records[["ld"]])); nudge <- quantities(run(tol_nudge[["ld"]]))
for (l in names(ladders)) {
  if (!all(file.exists(ladders[[l]]))) next
  q <- lapply(ladders[[l]], function(f) quantities(readRDS(f)))
  k <- Reduce(intersect, c(lapply(q, names), list(names(nudge))))
  k <- k[abs(q[[2]][k] - q[[3]][k]) >= 3 * abs(nudge[k] - base[k])]
  ratio <- (q[[1]][k] - q[[2]][k]) / (q[[2]][k] - q[[3]][k])
  cat(l, "\n")
  print(data.frame(resolved = c(by_group(ratio, length)), median = q3(by_group(ratio, median)),
                   below_0 = c(by_group(ratio < 0, sum)), in_2.5_6 = c(by_group(ratio >= 2.5 & ratio < 6, sum)),
                   coarsest_move = q3(by_group(abs(q[[1]][k] - q[[2]][k]), max))))
  m <- k[sub("^(resident|invader) ", "", k) %in% main]
  cat("  main:", paste(sprintf("%s %.2f", m, ratio[m]), collapse = ", "), "\n")
}

cat("\n== Long drought at 3e-5: each ladder's coarse and fine rung against the graded\n")
cat("   ladder's extrapolation from G2 and G3. D halves uniform's spacing before the\n")
cat("   first gap; De adds the gap's edges to D; Gn takes them out of graded.\n")
cat("   ratio: coarse error over fine, where the coarse is over 0.05 eps, 4 on the\n")
cat("   square law. companion: 4/3 of the move over the coarse error, 1 when honest.\n")
pairs <- list(uniform = file.path(runs_dir, c("ld_3e-5.rds", "ld_n215.rds")),
              D = file.path(grid_dir, c("ld_D1_full.rds", "ld_D2_full.rds")),
              De = file.path(grid_dir, c("ld_De1_full.rds", "ld_De2_full.rds")),
              Gn = file.path(grid_dir, c("ld_Gn1_full.rds", "ld_Gn2_full.rds")),
              graded = file.path(grid_dir, c("ld_G1_full.rds", "ld_G2_full.rds")))
G23 <- lapply(file.path(grid_dir, c("ld_G2_full.rds", "ld_G3_full.rds")), function(f) quantities(readRDS(f)))
ref <- G23[[2]] + (G23[[2]] - G23[[1]]) / 3
for (l in names(pairs)) {
  if (!all(file.exists(pairs[[l]]))) next
  x <- lapply(pairs[[l]], readRDS)
  q <- lapply(x, quantities)
  k <- Reduce(intersect, list(names(q[[1]]), names(q[[2]]), names(ref)))
  e1 <- abs(q[[1]][k] - ref[k]); e2 <- abs(q[[2]][k] - ref[k]); big <- e1 > 0.05
  role <- sub(" .*", "", k)
  med <- function(v, s) tapply(v[s], role[s], median)
  cat(sprintf("%-7s %d and %d nodes\n", l, length(x[[1]]$node_times), length(x[[2]]$node_times)))
  print(data.frame(coarse = q3(med(e1, TRUE)), fine = q3(med(e2, TRUE)),
                   resolved = c(tapply(big, role, sum)), ratio = q3(med(e1 / e2, big)),
                   companion = q3(med(abs(q[[1]][k] - q[[2]][k]) * 4 / 3 / e1, big))))
}

cat("\n== Long drought at 3e-5: where J's move between nested rungs lies in birth date,\n")
cat("   panel by panel (node_parts.R's panel_moves), in percent of J. top: the field\n")
cat("   part at the first two nodes over their own contribution, in percent.\n")
source(file.path(here, "node_parts.R"))
moves <- list("uniform 108 -> 215" = file.path(runs_dir, c("ld_3e-5.rds", "ld_n215.rds")),
              "uniform 215 -> 429" = c(file.path(runs_dir, "ld_n215.rds"), file.path(grid_dir, "ld_u429_full.rds")),
              "D 118 -> 235" = file.path(grid_dir, c("ld_D1_full.rds", "ld_D2_full.rds")),
              "graded 125 -> 248" = file.path(grid_dir, c("ld_G1_full.rds", "ld_G2_full.rds")),
              "graded 248 -> 494" = file.path(grid_dir, c("ld_G2_full.rds", "ld_G3_full.rds")))
bands <- c(-1, 0.5, 1, 3.5, 6, 10, 41)
for (l in names(moves)) {
  if (!all(file.exists(moves[[l]]))) next
  a <- nodes_of(readRDS(moves[[l]][1])); b <- nodes_of(readRDS(moves[[l]][2]))
  pm <- panel_moves(a, b); J <- sum(a$w * a$offspring)
  band <- cut(pm$birth, bands, right = FALSE)
  f <- function(v) paste(sprintf("%+.3f", 100 * tapply(v, band, sum) / J), collapse = " ")
  cat(sprintf("%-19s field %+.3f (%s) | interpolation %+.3f (%s) | top %.2f, %.2f\n", l,
              100 * sum(pm$field) / J, f(pm$field), 100 * sum(pm$interpolation) / J, f(pm$interpolation),
              100 * pm$field[1] / (a$w[1] * a$offspring[1]), 100 * pm$field[2] / (a$w[2] * a$offspring[2])))
}
cat("   bands:", paste(levels(cut(0, bands, right = FALSE)), collapse = " "), "\n")

cat("\n== Long drought at 3e-5: where the invader's lma elasticity moves between nested\n")
cat("   rungs (node_parts.R's elasticity_moves on harness/invader_nodes.R runs).\n")
cat("   check: the central difference's move against the sweep's.\n")
inv <- list("uniform 108 -> 215" = c("inv_u108", "inv_u215", file.path(runs_dir, c("ld_3e-5.rds", "ld_n215.rds"))),
            "uniform 215 -> 429" = c("inv_u215", "inv_u429", file.path(runs_dir, "ld_n215.rds"), file.path(grid_dir, "ld_u429_full.rds")),
            "graded 125 -> 248" = c("inv_ld_G1", "inv_ld_G2", file.path(grid_dir, c("ld_G1_full.rds", "ld_G2_full.rds"))),
            "graded 248 -> 494" = c("inv_ld_G2", "inv_ld_G3", file.path(grid_dir, c("ld_G2_full.rds", "ld_G3_full.rds"))))
sweep_lma <- function(f) { e <- readRDS(f)$invader$elasticity; e[[grep("lma$", names(e))]] }
for (l in names(inv)) {
  f <- c(file.path(grid_dir, paste0(inv[[l]][1:2], ".rds")), inv[[l]][3:4])
  if (!all(file.exists(f))) next
  em <- elasticity_moves(readRDS(f[1]), readRDS(f[2]))
  band <- cut(em[, "birth"], bands, right = FALSE)
  g <- function(v) paste(sprintf("%+.4f", tapply(v, band, sum)), collapse = " ")
  cat(sprintf("%-19s move %+.4f (sweep %+.4f) | field %+.4f (%s) | establishment %+.4f | interpolation %+.4f (%s)\n",
              l, sum(em[, -1]), sweep_lma(f[4]) - sweep_lma(f[3]), sum(em[, "field"]), g(em[, "field"]),
              sum(em[, "establishment"]), sum(em[, "interpolation"]), g(em[, "interpolation"])))
  top <- head(order(-abs(rowSums(em[, -1]))), 4)
  cat("   largest:", paste(sprintf("b %.3f %+.4f", em[top, "birth"], rowSums(em[top, -1, drop = FALSE])), collapse = ", "), "\n")
}
cat("   bands:", paste(levels(cut(0, bands, right = FALSE)), collapse = " "), "\n")

cat("\n== Long drought: the crown overlap, neighbouring nodes' height gap over the\n")
cat("   crown's top layer h/eta, at most, among the nodes born before 0.5 at each time\n")
cat("   and before 3.5 at time 5; heights from G1 interpolated in birth date\n")
cat("   (harness/layer_heights.R)\n")
lay_file <- file.path(grid_dir, "layer_ld_G1.rds")
if (file.exists(lay_file)) {
  lay <- readRDS(lay_file)
  overlap <- function(s, t, before) {
    i <- which.min(abs(lay$grid - t)); h <- lay$height[i, ]; ok <- !is.na(h)
    b <- s[s <= max(lay$times[ok]) & s < before]
    hh <- approx(lay$times[ok], h[ok], b)$y
    max((head(hh, -1) - tail(hh, -1)) / (head(hh, -1) / lay$eta))
  }
  grids <- c(u108 = file.path(runs_dir, "ld_3e-5.rds"), u215 = file.path(runs_dir, "ld_n215.rds"),
             u429 = file.path(grid_dir, "ld_u429_full.rds"),
             setNames(file.path(grid_dir, sprintf("ld_%s_full.rds", c("D1", "D2", "G0", "G1", "G2", "G3"))),
                      c("D1", "D2", "G0", "G1", "G2", "G3")))
  tt <- c(0.5, 1, 2, 3, 5, 12)
  tab <- t(vapply(grids, function(f) {
    s <- readRDS(f)$node_times
    c(vapply(tt, function(t) overlap(s, t, 0.5), 0), overlap(s, 5, 3.5))
  }, numeric(length(tt) + 1)))
  colnames(tab) <- c(sprintf("t %g", tt), "t 5, b < 3.5")
  print(round(tab, 2))
}

cat("\n== Long drought at 3e-5: each answer with the next coarser rung as its companion,\n")
cat("   in eps, over the 45 quantities outside the small four. estimate: a third of the\n")
cat("   move from the companion; safe: the estimate at least the error; extrapolated:\n")
cat("   the answer plus a third of that move. cost: member steps of both runs.\n")
member_steps <- function(x) sum(vapply(x$node_times, function(b) sum(x$stand$times > b), 0))
answers <- list(G1 = c("ld_G0_full", "ld_G1_full"), G2 = c("ld_G1_full", "ld_G2_full"),
                u215 = c("ld_3e-5", "ld_n215"), u429 = c("ld_n215", "ld_u429_full"),
                D2 = c("ld_D1_full", "ld_D2_full"), De2 = c("ld_De1_full", "ld_De2_full"),
                Gn2 = c("ld_Gn1_full", "ld_Gn2_full"))
where <- function(k) file.path(if (k %in% c("ld_3e-5", "ld_n215")) runs_dir else grid_dir, paste0(k, ".rds"))
rows <- list()
for (a in names(answers)) {
  f <- vapply(answers[[a]], where, "")
  if (!all(file.exists(f))) next
  x <- lapply(f, readRDS); q <- lapply(x, quantities)
  k <- Reduce(intersect, list(names(q[[1]]), names(q[[2]]), names(ref)))
  k <- k[!(sub("^(resident|invader) ", "", k) %in% small)]
  role <- sub(" .*", "", k)
  err <- abs(q[[2]][k] - ref[k]); est <- abs(q[[2]][k] - q[[1]][k]) / 3
  ex <- abs(q[[2]][k] + (q[[2]][k] - q[[1]][k]) / 3 - ref[k])
  for (r in c("resident", "invader")) {
    s <- role == r
    if (!any(s)) next
    rows[[length(rows) + 1]] <- data.frame(answer = a, role = r, max = q3(max(err[s])), median = q3(median(err[s])),
      estimate = q3(median(est[s] / err[s])), safe = sprintf("%d/%d", sum(est[s] >= err[s]), sum(s)),
      extrapolated_max = q3(max(ex[s])), extrapolated_median = q3(median(ex[s])),
      cost = sprintf("%.3g", member_steps(x[[1]]) + member_steps(x[[2]])))
  }
}
print(do.call(rbind, rows), row.names = FALSE)
worst <- c(u108 = "ld_3e-5", u215 = "ld_n215", u429 = "ld_u429_full", G0 = "ld_G0_full",
           G1 = "ld_G1_full", G2 = "ld_G2_full", D1 = "ld_D1_full", D2 = "ld_D2_full")
cat("   the worst error of each grid:", paste(vapply(names(worst), function(g) {
  q <- quantities(readRDS(where(worst[[g]])))
  k <- intersect(names(q), names(ref)); k <- k[!(sub("^(resident|invader) ", "", k) %in% small)]
  e <- abs(q[k] - ref[k]); sprintf("%s %.2f (%s)", g, max(e), names(e)[which.max(e)])
}, ""), collapse = "; "), "\n")

cat("\n== Long drought at 3e-5: what the first gap's edges move at the first rung, in eps,\n")
cat("   over the quantities outside the small four\n")
for (pr in list(c("ld_D1_full", "ld_De1_full"), c("ld_G1_full", "ld_Gn1_full"))) {
  f <- file.path(grid_dir, paste0(pr, ".rds"))
  if (!all(file.exists(f))) next
  q <- lapply(f, function(x) quantities(readRDS(x)))
  k <- intersect(names(q[[1]]), names(q[[2]]))
  k <- k[!(sub("^(resident|invader) ", "", k) %in% small)]
  d <- abs(q[[1]][k] - q[[2]][k]); e <- abs(q[[1]][k] - ref[k])
  role <- sub(" .*", "", k)
  cat(sprintf("%s against %s: %s\n", pr[2], pr[1], paste(sprintf("%s moves median %.4f, max %.4f, against an error of median %.3f",
      c("resident", "invader"), tapply(d, role, median)[c("resident", "invader")], tapply(d, role, max)[c("resident", "invader")],
      tapply(e, role, median)[c("resident", "invader")]), collapse = "; ")))
}

cat("\n== Long drought, uniform 108 -> 215 forward with the crown shape eta changed\n")
cat("   (harness/crown_eta.R): the field part at the first two nodes over their own\n")
cat("   contribution, in percent, and both parts in percent of J\n")
for (e in c(6, 12, 24)) {
  f <- file.path(grid_dir, sprintf("eta%d_u%d.rds", e, c(108, 215)))
  if (!all(file.exists(f))) next
  a <- nodes_of(readRDS(f[1])); b <- nodes_of(readRDS(f[2]))
  pm <- panel_moves(a, b); J <- sum(a$w * a$offspring); own <- a$w * a$offspring
  cat(sprintf("eta %2d: J %.4f | top %.2f, %.2f | field %+.3f | interpolation %+.3f\n", e,
              readRDS(f[1])$stand$J, 100 * pm$field[1] / own[1], 100 * pm$field[2] / own[2],
              100 * sum(pm$field) / J, 100 * sum(pm$interpolation) / J))
}
