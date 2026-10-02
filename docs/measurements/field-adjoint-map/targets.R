# Reproduce the measured targets (field / interpolation parts, per node) from the
# reference runs, and save the per-node field parts for later comparison.
A <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/adjmap"
.libPaths(c(file.path(dirname(A), "lib_guard"), .libPaths()))
suppressMessages(library(plant))
source(file.path(A, "harness", "node_parts.R"))
R <- function(f) readRDS(file.path(A, "ref", f))
runs <- list(u108 = R("ld_3e-5.rds"), u215 = R("ld_n215.rds"), u429 = R("ld_u429_full.rds"),
             G1 = R("ld_G1_full.rds"), G2 = R("ld_G2_full.rds"))
for (n in names(runs)) cat(sprintf("%-5s nodes %d J %.8f steps %d tol %g\n", n, length(runs[[n]]$node_times),
                                     runs[[n]]$stand$J, length(runs[[n]]$stand$times), runs[[n]]$setting$tol))
pairs <- list(c("u108", "u215"), c("u215", "u429"), c("G1", "G2"))
out <- list()
for (pr in pairs) {
  a <- nodes_of(runs[[pr[1]]]); b <- nodes_of(runs[[pr[2]]])
  pm <- panel_moves(a, b); J <- sum(a$w * a$offspring)
  own <- a$w * a$offspring
  cat(sprintf("%s -> %s: J_a %.6f J_b %.6f move %+.4f%% | field %+.4f%% (b<0.5 %+.4f) | interp %+.4f%% (b<0.5 %+.4f) | estab %+.5f%%\n",
              pr[1], pr[2], J, runs[[pr[2]]]$stand$J, 100 * (runs[[pr[2]]]$stand$J - runs[[pr[1]]]$stand$J) / J,
              100 * sum(pm$field) / J, 100 * sum(pm$field[pm$birth < 0.5]) / J,
              100 * sum(pm$interpolation) / J, 100 * sum(pm$interpolation[pm$birth < 0.5]) / J,
              100 * sum(pm$establishment) / J))
  rel <- pm$field / own
  cat("  first nodes' field part of their own (%):", sprintf("%.2f", 100 * head(rel, 8)), "\n")
  out[[paste(pr, collapse = "_")]] <- cbind(pm, own = own, J = J)
}
saveRDS(out, file.path(A, "targets.rds"))
