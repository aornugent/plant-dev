# Every number the report quotes, from the saved outputs.
A <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/adjmap"
.libPaths(c(file.path(A, "lib"), .libPaths()))
suppressMessages(library(plant))
source(file.path(A, "harness", "node_parts.R"))
R <- function(f) readRDS(file.path(A, f))
ex <- function(f) file.exists(file.path(A, f))
nd <- function(x) nodes_of(list(setting = list(lifetime = 40), stand = list(nodes = x)))
pairs <- list(u108 = c("ref/ld_3e-5.rds", "ref/ld_n215.rds", "out/sweep_u108.rds", "out/drop_u215.rds"),
              u215 = c("ref/ld_n215.rds", "ref/ld_u429_full.rds", "out/sweep_u215.rds", "out/drop_u429.rds"),
              G1 = c("ref/ld_G1_full.rds", "ref/ld_G2_full.rds", "out/sweep_G1.rds", "out/drop_G2.rds"))
cat("== J's field part: measured, one coarse run (order 1), one finer run (drop), in % of J\n")
for (n in names(pairs)) {
  f <- pairs[[n]]
  a <- nodes_of(R(f[1])); b <- nodes_of(R(f[2])); pm <- panel_moves(a, b); Jn <- sum(a$w * a$offspring)
  meas <- 100 * sum(pm$field) / Jn; mint <- 100 * sum(pm$interpolation) / Jn
  s <- R(f[3]); o1 <- 100 * (sum(s$light) + sum(s$soil)) / s$base$J
  line <- sprintf("%-5s measured field %+.4f interp %+.4f | order1 %+.4f (light %+.4f soil %+.4f) ratio %.3f",
                  n, meas, mint, o1, 100 * sum(s$light) / s$base$J, 100 * sum(s$soil) / s$base$J, o1 / meas)
  if (ex(f[4])) {
    d <- R(f[4]); dr <- -100 * (sum(d$light) + sum(d$soil)) / d$base$J
    line <- paste(line, sprintf("| drop %+.4f (light %+.4f soil %+.4f) ratio %.3f | sweep cpu %.0f fwd %.0f",
                                dr, -100 * sum(d$light) / d$base$J, -100 * sum(d$soil) / d$base$J, dr / meas,
                                d$sweep_cpu, d$base$cpu))
  }
  cat(line, "\n")
}
cat("== cost, u108: forward / plain sweep / probe sweep (CPU s, peak MiB)\n")
s0 <- R("out/sweep0_u108.rds"); s1 <- R("out/sweep_u108.rds")
cat(sprintf("forward %.0f; plain sweep %.0f s %.0f MiB; probe sweep %.0f s %.0f MiB (%+.0f%%); traits identical %s\n",
            s0$base$cpu, s0$sweep_cpu, s0$sweep_peak_mb, s1$sweep_cpu, s1$sweep_peak_mb,
            100 * (s1$sweep_cpu / s0$sweep_cpu - 1), identical(s0$traits, s1$traits)))
