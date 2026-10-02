# Rscript same.R a.rds b.rds: the largest relative difference in each per-node
# vector of two invader_nodes.R runs (0 means bit-identical).
f <- commandArgs(TRUE)
a <- readRDS(f[1]); b <- readRDS(f[2])
rel <- function(x, y) if (length(x) != length(y)) NA else max(c(0, abs(x - y) / pmax(abs(x), 1e-300)))
for (role in c("stand", "minus", "plus")) {
  na <- if (role == "stand") a$stand else a$invader[[role]]
  nb <- if (role == "stand") b$stand else b$invader[[role]]
  cat(sprintf("%-6s J %.12g vs %.12g | max rel diff: establishment %.3g, nrr %.3g, J %.3g\n", role, na$J, nb$J,
              rel(na$establishment, nb$establishment), rel(na$nrr, nb$nrr), rel(na$J, nb$J)))
}
