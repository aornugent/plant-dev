# Where the leading field modes sit: the making side's light and water modes
# by patch age and height (or depth), and the sensing side's leading modes
# against the pool's traits.
#   Rscript modes.R long-drought
here <- "/home/a/dev/plant-dev/.claude/worktrees/agent-aff6cbd1ac6c0084f/spikes/field-dimension-066"
case <- commandArgs(TRUE)[1]
x <- readRDS(file.path(here, sprintf("field_dimension_%s.rds", case)))
m <- x$making
s <- x$sensing
age_bins <- cut(m$tgrid, c(-1, 5, 10, 20, 30, 41), labels = c("0-5", "5-10", "10-20", "20-30", "30-40"))
h_bins <- cut(m$hgrid, c(-1, 2, 5, 10, 15, 20, 31), labels = c("0-2", "2-5", "5-10", "10-15", "15-20", "20-30"))
share <- function(U) {
  E <- U^2
  t(sapply(split(seq_along(m$tgrid), age_bins), function(i)
    sapply(split(seq_along(m$hgrid), h_bins), function(j) sum(E[i, j]))))
}
cat("== ", case, "\n")
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
cat("sensing: correlation of left modes 1-3 (and centred 1-2) with pool ln-traits and base ln R':\n")
U <- cbind(u1 = s$U[, 1], u2 = s$U[, 2], u3 = s$U[, 3], c1 = s$U_centred[, 1], c2 = s$U_centred[, 2])
print(round(cor(cbind(x$pool, Phi0 = s$Phi0), U), 2))
cat("R^2 of each left mode on the six ln-traits:\n")
print(round(apply(U, 2, function(u) summary(lm(u ~ x$pool))$r.squared), 2))
cat("sign of u1 across the pool (fraction positive):", mean(sign(s$U[, 1]) == sign(sum(s$U[, 1]))), "\n")
cat("right vectors, centred modes 1-2:\n"); print(round(setNames(data.frame(s$V_centred[, 1:2], row.names = x$cols), c("c1", "c2")), 3))
