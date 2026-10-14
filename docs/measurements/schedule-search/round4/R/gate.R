# gate.R RUN.rds...: G's quadrature gate (G/alias.R) on the intervals that integrate
# the rain. A substepped row integrates it over its substeps, a coupled row over the
# step. For each interval, the Cash-Karp 5th- and 4th-order quadratures of the rain
# against its exact integral (three-point Gauss-Legendre on each piece between daily
# knots, exact for the cubic). "steps" is G's original reading: every main step.
O <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest"
if (!nzchar(Sys.getenv("PLANT_LIB"))) Sys.setenv(PLANT_LIB = file.path(O, "libR"))
suppressMessages(source("/home/user/plant-dev/harness/long_drought.R"))
cc <- c(0, 1/5, 3/10, 3/5, 1, 7/8)
b5 <- c(37/378, 0, 250/621, 125/594, 0, 512/1771)
b4 <- c(2825/27648, 0, 18575/48384, 13525/55296, 277/14336, 1/4)
gl_x <- c(-sqrt(3/5), 0, sqrt(3/5)); gl_w <- c(5/9, 8/9, 5/9)
quad <- function(rf, a, b) {
  h <- b - a; r <- matrix(rf(rep(a, each = 6) + cc * rep(h, each = 6)), 6)
  list(q5 = h * colSums(b5 * r), q4 = h * colSums(b4 * r))
}
exact <- function(rf, a, b) {
  pieces <- lapply(seq_along(a), function(i) {
    k <- (ceiling(a[i] * 365 + 1e-9):floor(b[i] * 365 - 1e-9)) / 365
    k <- k[k > a[i] & k < b[i]]; e <- c(a[i], k, b[i]); cbind(i, head(e, -1), e[-1]) })
  p <- do.call(rbind, pieces); m <- (p[, 2] + p[, 3]) / 2; r <- (p[, 3] - p[, 2]) / 2
  v <- matrix(rf(rep(m, each = 3) + gl_x * rep(r, each = 3)), 3)
  as.numeric(tapply(r * colSums(gl_w * v), p[, 1], sum))
}
for (f in commandArgs(TRUE)) {
  x <- readRDS(f); reg <- x$setting$regime; seed <- x$setting$seed
  scen <- sprintf("%s, seed %d", reg, seed); RAIN_SPECS[[scen]] <- modifyList(RAIN_SPECS[[reg]], list(seed = seed))
  e <- mkenv(scen); rf <- function(t) pmax(0, e$extrinsic_drivers_evaluate_range("rainfall", t))
  t <- x$stand$times; sz <- x$stand$sizes; se <- x$stand$substep_ends; n <- length(t)
  ia <- ib <- numeric(0); sa <- t[-n]; sb <- t[-1]
  for (k in 2:n) {
    ends <- se[[k]]
    if (length(ends)) { ia <- c(ia, t[k - 1] + c(0, head(ends, -1)) * sz[k]); ib <- c(ib, t[k - 1] + ends * sz[k]) }
    else { ia <- c(ia, t[k - 1]); ib <- c(ib, t[k]) }
  }
  k <- active_knots(scen); inside <- sum(vapply(k, function(z) any(sa < z - 1e-12 & sb > z + 1e-12), TRUE))
  for (win in list(c(0, 1e9), c(25.2, 39.5))) {
    rd <- function(a, b) { w <- a >= win[1] & b <= win[2]; a <- a[w]; b <- b[w]
      q <- quad(rf, a, b); ex <- exact(rf, a, b)
      c(n = length(a), exact = sum(ex), rk5 = sum(q$q5), miss = sum(abs(q$q5 - ex)), seen = sum(abs(q$q5 - q$q4))) }
    g <- rd(ia, ib); s <- rd(sa, sb)
    cat(sprintf("%-22s [%5.1f,%5.1f] rain-intervals %6d: exact %.4f rk5 %.4f sum|rk5-exact| %.2e (seen %.2e) | main steps %5d: sum|rk5-exact| %.3f (seen %.3f)\n",
      basename(f), win[1], min(win[2], max(t)), g["n"], g["exact"], g["rk5"], g["miss"], g["seen"], s["n"], s["miss"], s["seen"]))
  }
  cat(sprintf("%-22s knots %d, of which inside a main step %d; rows substepped %.1f%%\n", basename(f), length(k), inside,
    100 * mean(lengths(se[-1]) > 0)))
}
