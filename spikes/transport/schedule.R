# The node schedule as a quantisation of the birth-date measure. Within a patch, birth
# date s in [0, 40] has density rho(s), and a seed born at s meets the field y(s), which
# moves fast while the canopy closes. M nodes cut [0, 40] into cells; each cell keeps
# its exact mass and the field at its centroid. Three placements at equal M:
# uniform, geometric from the start, and n(s) ~ rho^(1/3) |y'|^(2/3).
#
#   Rscript schedule.R > schedule.txt
source("lib.R")
options(digits = 5, width = 140)

rho <- function(s) exp(-s / 15) / (15 * (1 - exp(-40 / 15)))
yfun <- function(s) 8 * exp(-s / 0.4) + 2 * sin(s / 3)
dy <- function(s) -8 / 0.4 * exp(-s / 0.4) + 2 / 3 * cos(s / 3)

quant <- function(edges) {
  edges <- unique(edges); M <- length(edges) - 1; mass <- ybar <- numeric(M)
  for (i in 1:M) {
    s <- seq(edges[i], edges[i + 1], length.out = 201)
    w <- rho(s) * diff(range(s)) / 200; w[c(1, 201)] <- w[c(1, 201)] / 2
    mass[i] <- sum(w); ybar[i] <- sum(w * yfun(s)) / sum(w)
  }
  ok <- mass > 0
  list(Y = matrix(ybar[ok]), K = mass[ok] / sum(mass[ok]))
}
equi <- function(M, dens) {
  s <- seq(0, 40, length.out = 400001); c <- cumsum(dens(s)); c <- c / tail(c, 1)
  e <- approx(c, s, xout = seq(0, 1, length.out = M + 1), ties = "ordered", rule = 2)$y
  e[1] <- 0; e[M + 1] <- 40; e
}
geometric <- function(M, h0 = 0.05)
  c(0, 40 * (exp(seq(0, log(1 + 40 / h0), length.out = M)) - 1) / (40 / h0))

grid <- matrix(seq(-5, 12, by = 0.005))
fine <- quant(seq(0, 40, length.out = 8001))
truth <- assemble(fine$Y, fine$K, grid)
Ltrue <- loglik(truth$P, truth$k, fine$K)
cat(sprintf("The community on the fine measure (8000 cells): %d species at S = %s, weights %s\n",
            nrow(truth$S), paste(sprintf("%.3f", sort(truth$S)), collapse = ", "),
            paste(sprintf("%.3f", truth$P[order(truth$S)]), collapse = ", ")))
cat("Each schedule's community is judged on the fine measure: its loss in regional log-yield,\n")
cat("its species count, and the largest error in a species' trait when the counts agree.\n\n")
score <- function(edges) {
  q <- quant(edges); e <- assemble(q$Y, q$K, grid)
  k <- kernel(phi(e$S, fine$Y))
  dS <- if (nrow(e$S) == nrow(truth$S)) max(abs(sort(e$S) - sort(truth$S))) else NA
  sprintf("%9.2e %2d %8.3f", Ltrue - loglik(e$P, k, fine$K), nrow(e$S), dS)
}
cat(sprintf("%4s | %-22s | %-22s | %-22s\n", "M", "uniform", "geometric (h0 0.05)", "rho^1/3 |y'|^2/3"))
for (M in c(6, 12, 24, 48, 96)) {
  cat(sprintf("%4d | %s | %s | %s\n", M, score(seq(0, 40, length.out = M + 1)), score(geometric(M)),
              score(equi(M, function(s) rho(s)^(1/3) * abs(dy(s))^(2/3) + 1e-9))))
}
