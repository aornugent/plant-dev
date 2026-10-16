# What node placement alone can do for the founders' own (interpolation) error in ln J,
# against Simpson and log-fate interpolation, offline on the f64 lattice fate shapes.
# Establishment is taken as uniform over [0, b1) (it is nearly so before b1).
FO <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/founders"
sh <- readRDS(file.path(FO, "q2_shape.rds")); E <- 0.025
err <- function(x, f, share, rule = "hat") {
  # relative error of the integral of nrr over [0, b1), times the founders' share, in eps
  tru <- integrate(f, 0, max(x), subdivisions = 2000)$value
  y <- f(x); h <- diff(x)
  est <- switch(rule,
    hat = sum(h * (head(y, -1) + tail(y, -1)) / 2),
    log = sum(h * (head(y, -1) - tail(y, -1)) / log(head(y, -1) / tail(y, -1))),
    simpson = { stopifnot(length(h) %% 2 == 0); i <- seq(1, length(h), 2)
      sum(h[i] / 3 * (y[i] + 4 * y[i + 1] + y[i + 2])) })
  share * (est / tru - 1) / E }
grade <- function(f, b1, n) {          # equal h^3 f'' per interval (optimal for the hat rule)
  bb <- seq(0, b1, length.out = 4001); d2 <- abs(diff(f(bb), differences = 2)) / diff(bb)[1]^2
  w <- c(d2, d2[length(d2)])^(1 / 3); cw <- c(0, cumsum(w)) / sum(w)
  x <- approx(cw, bb, seq(0, 1, length.out = n + 1), ties = mean)$y; x[1] <- 0; x[n + 1] <- b1; x }
original <- function(b1) {             # node_schedule_times_default's spacing inside [0, b1)
  t <- 0; x <- 0
  while (t < b1) { dt <- if (t > 0) 2^floor(log2(t * 0.2)) else 0; t <- t + min(max(dt, 1e-5), 2); x <- c(x, t) }
  x[length(x)] <- b1; x }
cat(sprintf("%-13s %5s | %-26s | %-26s | %s\n", "case", "b1", "hat: uniform 12 / 17 / 48", "graded 12 / 17", "Simpson 12 | log 12 | original (n)"))
for (cs in names(sh)) {
  s <- sh[[cs]]; b1 <- max(s$b) + diff(s$b)[1]
  fit <- splinefun(s$b, s$g, method = "natural"); f <- function(b) exp(fit(pmin(b, max(s$b))))
  u <- function(n) seq(0, max(s$b), length.out = n + 1)
  o <- original(max(s$b))
  cat(sprintf("%-13s %5.2f | %+7.3f %+7.3f %+7.3f | %+7.3f %+7.3f        | %+7.4f | %+7.4f | %+7.4f (%d)\n",
    cs, b1, err(u(12), f, s$share), err(u(17), f, s$share), err(u(48), f, s$share),
    err(grade(f, max(s$b), 12), f, s$share), err(grade(f, max(s$b), 17), f, s$share),
    err(u(12), f, s$share, "simpson"), err(u(12), f, s$share, "log"),
    err(o, f, s$share), length(o) - 1)) }
