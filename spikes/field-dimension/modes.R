# Where the leading field modes sit: the making side's light and water modes
# by patch age and height (or depth), and the sensing side's leading modes
# against the pool's traits.
#   Rscript modes.R long-drought
here <- "/home/a/dev/plant-dev/.claude/worktrees/workflows/spikes/field-dimension"
regime <- commandArgs(TRUE)[1]
x <- readRDS(file.path(here, sprintf("field_dimension_%s.rds", regime)))
m <- x$making
s <- x$sensing
age_bins <- cut(m$tgrid, c(-1, 5, 10, 20, 30, 41), labels = c("0-5", "5-10", "10-20", "20-30", "30-40"))
h_bins <- cut(m$hgrid, c(-1, 2, 5, 10, 15, 20, 31), labels = c("0-2", "2-5", "5-10", "10-15", "15-20", "20-30"))
share <- function(U) {
  E <- U^2
  t(sapply(split(seq_along(m$tgrid), age_bins), function(i)
    sapply(split(seq_along(m$hgrid), h_bins), function(j) sum(E[i, j]))))
}
cat("== ", regime, "\n")
cat("light mode 1, share of energy (rows patch age, cols height m):\n"); print(round(share(m$UL1), 3))
cat("light mode 2:\n"); print(round(share(m$UL2), 3))
cat("light mode 1/2 right vectors (perturbations):\n")
print(round(setNames(data.frame(m$VL[, 1:2], row.names = x$cols), c("L1", "L2")), 3))
W1 <- m$UW1^2
cat("water mode 1 share by age x depth:\n")
print(round(t(sapply(split(seq_along(m$tgrid), age_bins), function(i) colSums(W1[i, , drop = FALSE]))), 3))
cat("water mode 1 right vector:\n"); print(round(setNames(m$VW[, 1], x$cols), 3))
cat("base light at ages 5,10,20,30 (heights 0,2,5,10,15,20):\n")
ti <- sapply(c(5, 10, 20, 30), function(a) which.min(abs(m$tgrid - a)))
hi <- sapply(c(0, 2, 5, 10, 15, 20), function(h) which.min(abs(m$hgrid - h)))
print(round(m$L0[ti, hi] , 3))
cat("sensing: pool traits (ln, rel. resident) against left modes 1-3:\n")
print(round(cbind(x$pool, Phi0 = s$Phi0, u1 = s$U[, 1], u2 = s$U[, 2], u3 = s$U[, 3]), 3))
cat("correlation of u2, u3 with pool traits:\n")
print(round(cor(x$pool[, ], s$U[, 2:3]), 2))
