# Would one directional difference along the reported gradient flag a blown-up run?
# Predicted d lnJ / d s along u = el / |el| (s a step in ln theta) is |el|; the forward
# map's own slope along u is el_true . u, read here off a sane run of the same case.
R <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/adjmap/runs/"
O <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/D_out/"
el <- function(n) { f <- if (file.exists(paste0(O, n, ".rds"))) paste0(O, n, ".rds") else paste0(R, n, "_long-drought.rds"); readRDS(f)$stand$elasticity }
truth <- el("f_n2")
for (n in c("val_a10n1_c", "val_a10bug_c", "val_a10s_c", "val_a10n2_c", "val_a09s_c", "f_n1")) {
  e <- el(n); u <- e / sqrt(sum(e^2))
  cat(sprintf("%-14s |el| %9.2f  true slope along u %7.2f  ratio %.4f\n", n, sqrt(sum(e^2)), sum(truth * u), sqrt(sum(e^2)) / sum(truth * u)))
}
