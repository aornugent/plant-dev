tz <- function(y, x) sum(diff(x) * (head(y, -1) + tail(y, -1)) / 2)
dc <- function(X) { x <- seq(0, X, length = 20001); u <- exp(-x); u <- u / tz(u, x); tz(u * x, x) / X - 0.5 }
for (X in c(0.5, 1, 2, 4)) cat("dc", X, round(dc(X), 4), "approx", round(-X / 12, 4), "\n")
delta <- function(gamma, th_top, X = 2) {
  x <- seq(0, X, length = 20001); I <- exp(-x); V <- I^gamma; th <- th_top * I / V
  u <- V * th / (1 + th)^2; u <- u / tz(u, x); tz(u * x, x) / X - 0.5
}
ths <- c(1, 3, 10, 30, 100)
cat("gamma rows, th_top cols", ths, "\n")
for (g in c(0, .25, .5, .75, 1)) cat(g, round(sapply(ths, function(t) delta(g, t)), 3), "\n")
for (t in c(3, 10, 30, 100)) {
  r <- try(uniroot(function(g) delta(g, t), c(0, 0.999))$root, silent = TRUE)
  cat("gamma* th_top", t, if (is.numeric(r)) round(r, 3) else "none", "\n")
}
for (X in c(1, 2, 3, 4)) cat("X", X, "d(g0)", round(delta(0, 30, X), 3), "d(g1)", round(delta(1, 30, X), 3),
  "g*", round(uniroot(function(g) delta(g, 30, X), c(0, .999))$root, 3), "\n")
# Chesson overlap for two fully overlapping (pi=1/2) aligned crowns with offset delta: rho = 1/(1+2 delta)
for (d in c(0.129, 0.05, 0, -0.05, -0.156)) cat("delta", d, "rho", round(1 / (1 + 2 * d), 3), "\n")
