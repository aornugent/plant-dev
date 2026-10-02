# The drop probe on the finer run (exact states of the nodes the coarser grid
# lacks) against the measured field parts, whole and by panel group.
#
#   Rscript compare_drop.R DROP.rds COARSE_REF FINE_REF [PLAIN1.rds ...]
A <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/adjmap"
.libPaths(c(file.path(A, "lib"), .libPaths()))
suppressMessages(library(plant))
source(file.path(A, "harness", "node_parts.R"))
args <- commandArgs(TRUE)
dr <- readRDS(args[1]); ca <- readRDS(args[2]); cb <- readRDS(args[3])
a <- nodes_of(ca); b <- nodes_of(cb)
pm <- panel_moves(a, b); Jn <- sum(a$w * a$offspring)
J <- dr$base$J
# field part = fine - coarse on the coarse nodes, so the drop probe's (coarse
# field - fine field) on the fine run enters with its sign reversed
L <- -colSums(dr$light); S <- -colSums(dr$soil)
cat(sprintf("drop probe on %d nodes (J %.10f), %.0f s sweep cpu: light %+.4f%%, soil %+.4f%%, total %+.4f%% (measured field %+.4f%%; ratio %.3f)\n",
            length(dr$at), J, dr$sweep_cpu, 100 * sum(L) / J, 100 * sum(S) / J, 100 * (sum(L) + sum(S)) / J,
            100 * sum(pm$field) / Jn, (sum(L) + sum(S)) / J / (sum(pm$field) / Jn)))
bands <- c("<0.5", "0.5-1", "1-2", "2-3", "3-5", "5-10", "10-20", ">20")
cat("  by time band:\n")
print(rbind(light = setNames(round(-100 * rowSums(dr$light) / J, 4), bands),
            soil = setNames(round(-100 * rowSums(dr$soil) / J, 4), bands)))
# each coarse panel's finer node, by its index in the finer schedule
fine_birth <- dr$times
panel_of <- findInterval(fine_birth, a$birth)
dropped <- which(is.finite(dr$at))
for (f in args[-(1:3)]) {
  x <- readRDS(f)
  bx <- nodes_of(list(setting = list(lifetime = 40), stand = list(nodes = x$base$nodes)))
  pmx <- panel_moves(a, bx)
  extra <- setdiff(round(bx$birth, 10), round(a$birth, 10))
  panels <- findInterval(extra, a$birth)
  j <- dropped[panel_of[dropped] %in% panels]
  cat(sprintf("%s: panels %s; measured field %+.4f%%; drop probe for those nodes: light %+.4f%%, soil %+.4f%%, total %+.4f%% (ratio %.3f)\n",
              basename(f), paste(range(panels), collapse = "-"), 100 * sum(pmx$field) / Jn,
              100 * sum(L[j]) / J, 100 * sum(S[j]) / J, 100 * sum(L[j] + S[j]) / J,
              (sum(L[j] + S[j]) / J) / (sum(pmx$field) / Jn)))
}
