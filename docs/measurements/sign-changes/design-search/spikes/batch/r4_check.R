# R4's check on each arm at 1e-4: the sweep's elasticity in lma against the
# central difference of ln J at lma (1 +- 1e-3) on the same frozen program
# (bar 2e-3). Then m4's second differences, to read how the spread falls with m.
R <- "runs"
for (m in c(1, 2)) {
  g <- readRDS(file.path(R, sprintf("g_m%d_1e-4.rds", m)))$stand
  Jp <- readRDS(file.path(R, sprintf("f_m%d_1e-4_lma0.001.rds", m)))$stand$J
  Jm <- readRDS(file.path(R, sprintf("f_m%d_1e-4_lma-0.001.rds", m)))$stand$J
  cd <- (log(Jp) - log(Jm)) / (log1p(1e-3) - log1p(-1e-3))
  ad <- g$elasticity[["1.lma"]]
  cat(sprintf("m%d: sweep %.6f, central difference %.6f, gap %.2e (bar 2e-3)\n", m, ad, cd, ad - cd))
}
# R4 as the record ran it: a central difference of half-width 1e-6 at the trait.
g <- readRDS(file.path(R, "g_m2_1e-4.rds"))$stand
Jp <- readRDS(file.path(R, "f_m2_1e-4_lma1e-6.rds"))$stand$J
Jm <- readRDS(file.path(R, "f_m2_1e-4_lma-1e-6.rds"))$stand$J
cd <- (log(Jp) - log(Jm)) / (log1p(1e-6) - log1p(-1e-6))
cat(sprintf("m2, half-width 1e-6: sweep %.6f, central difference %.6f, gap %.2e (bar 2e-3)\n",
            g$elasticity[["1.lma"]], cd, g$elasticity[["1.lma"]] - cd))
