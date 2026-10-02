# The soil chain alone as a warm start for the coupled run: how well its step
# program predicts the coupled one's, interval by interval and in the first step
# after each knot, and what the chain alone costs in C++ against the coupled
# forward.
#
#   [FORWARD_S=114.8] Rscript harness/warm_start.R chain.rds run.rds
#
# chain.rds is harness/soil_chain.R's OUT and run.rds harness/ark_prototype.R's,
# on the same record; a run saved before the driver kept its record's knots is
# long drought's. FORWARD_S is the coupled forward's wall clock in plant, by
# default replay_timing.R's at 108 uniform nodes and the tied 3e-5.
here <- tryCatch(dirname(sys.frame(1)$ofile), error = function(e) "harness")
args <- commandArgs(TRUE)
ch <- readRDS(args[1])
x <- readRDS(args[2])
ld <- readRDS(file.path(here, "..", "docs", "measurements", "spot-check", "ld_3e-5.rds"))
stopifnot(is.null(x$regime) || x$regime == ch$regime)
DAY <- 1 / 365
knots <- sort(unique(if (is.null(x$knots)) ld$knots else x$knots))
rain <- if (is.null(x$rain)) ld$rain else x$rain
rain_at <- function(t) rain[pmin(pmax(floor(t / DAY + 1e-9) + 1, 1), length(rain))]
runs <- list(chain = data.frame(t0 = ch$rows[, 1], h = ch$rows[, 2]),
             coupled = data.frame(t0 = x$st$time - x$st$h, h = x$st$h))
starts <- c(0, knots)
runs$chain$ratio <- ch$rows[, 3]
runs$coupled$ratio <- x$st$er
ends <- c(knots, Inf)
per <- lapply(runs, function(d) {
  iv <- findInterval(d$t0 + 1e-12, knots)
  first <- !duplicated(iv) & abs(d$t0 - starts[iv + 1]) < 1e-9
  # The longest step its error would have passed, from the 5th-order local
  # error, and never past the next knot; a step clipped to the knot passed.
  room <- ends[iv + 1] - d$t0
  clipped <- abs(d$h - room) < 1e-9
  longest <- ifelse(clipped, room, pmin(room, d$h * (1.1 / pmax(d$ratio, 1e-300))^(1 / 5)))
  list(n = tabulate(iv + 1, length(starts)), first = setNames(d$h[first], iv[first]),
       longest = setNames(longest[first], iv[first]))
})
n <- lapply(per, `[[`, "n")
cat(sprintf("== %s and %s: %d and %d accepted steps\n", basename(args[1]), basename(args[2]),
            nrow(runs$chain), nrow(runs$coupled)))
cat(sprintf("steps per interval: chain %.2f, coupled %.2f; correlation %.2f; intervals within one step %.0f%%\n",
            mean(n$chain), mean(n$coupled), cor(n$chain, n$coupled),
            100 * mean(abs(n$chain - n$coupled) <= 1)))
k <- intersect(names(per$chain$first), names(per$coupled$first))
r <- per$coupled$first[k] / per$chain$first[k]
wet <- rain_at(starts[as.integer(k) + 1] + DAY / 2) > 0
cat(sprintf("first accepted step after a knot, coupled over chain, 10/25/50/75/90%%: %s; within a factor of 2: %.0f%%; median on rain intervals %.2f, dry %.2f\n",
            paste(signif(quantile(r, c(.1, .25, .5, .75, .9)), 2), collapse = " "),
            100 * mean(r > 0.5 & r < 2), median(r[wet]), median(r[!wet])))
seed <- pmin(per$chain$first[k], per$coupled$longest[k] / (1 - 1e-12)) / per$coupled$longest[k]
cat(sprintf("the chain's first step as the coupled run's first attempt: passes at %.0f%% of knots; where it passes, it is 10/50/90%% %s of the longest that would\n",
            100 * mean(seed <= 1), paste(signif(quantile(seed[seed <= 1], c(.1, .5, .9)), 2), collapse = " ")))
own <- per$coupled$first[k] / per$coupled$longest[k]
cat(sprintf("  the coupled run's own first accepted step there, after any rejections, is 10/50/90%% %s of it\n",
            paste(signif(quantile(own, c(.1, .5, .9)), 2), collapse = " ")))

# One Cash-Karp attempt on the chain, timed in C++: six rate evaluations, each
# five power laws and the rain's Hermite interpolant, and the stage sums.
if (!is.null(ch$rejected) && requireNamespace("Rcpp", quietly = TRUE)) {
  tab <- new.env()
  sys.source(file.path(here, "ark436.R"), envir = tab)
  Rcpp::cppFunction(includes = "#include <chrono>\n#include <algorithm>", '
double attempt_ns(NumericMatrix A, NumericVector b, NumericVector d, NumericVector c,
                  NumericVector tk, NumericVector sk, NumericVector mk, int n) {
  const double theta_s = 0.428, K_sat = 163.0411, q = 2 * 6.57 + 3, dz = 0.3;
  auto rain = [&](double t) {
    const int i = std::min<long>(std::max<long>(
        std::upper_bound(tk.begin(), tk.end(), t) - tk.begin() - 1, 0), tk.size() - 2);
    const double w = tk[i + 1] - tk[i], u = (t - tk[i]) / w, u2 = u * u, u3 = u2 * u;
    return std::max(0.0, (2 * u3 - 3 * u2 + 1) * sk[i] + (u3 - 2 * u2 + u) * w * mk[i] +
                         (-2 * u3 + 3 * u2) * sk[i + 1] + (u3 - u2) * w * mk[i + 1]);
  };
  auto rates = [&](const double* th, double t, double* out) {
    double flow[5];
    for (int l = 0; l < 5; ++l)
      flow[l] = K_sat * std::pow(std::min(std::max(th[l], 0.0), theta_s) / theta_s, q);
    out[0] = (rain(t) * std::max(0.0, 1 - std::pow(th[0] / theta_s, 8)) - flow[0]) / dz;
    for (int l = 1; l < 5; ++l) out[l] = (flow[l - 1] - flow[l]) / dz;
  };
  double y[5] = {0.214, 0.214, 0.214, 0.214, 0.214}, k[6][5], yi[5], sink = 0, t = 0;
  const double h = 1e-3, T = tk[tk.size() - 1];
  const auto start = std::chrono::steady_clock::now();
  for (int a = 0; a < n; ++a) {
    for (int s = 0; s < 6; ++s) {
      for (int l = 0; l < 5; ++l) {
        yi[l] = y[l];
        for (int j = 0; j < s; ++j) yi[l] += h * A(s, j) * k[j][l];
      }
      rates(yi, t + c[s] * h, k[s]);
    }
    for (int l = 0; l < 5; ++l) {
      double dy = 0, e = 0;
      for (int s = 0; s < 6; ++s) { dy += b[s] * k[s][l]; e += (b[s] - d[s]) * k[s][l]; }
      y[l] = std::min(std::max(y[l] + h * dy, 0.05), 0.42);
      sink += e;
    }
    t += h;
    if (t >= T) t = 0;
  }
  const double ns = std::chrono::duration<double, std::nano>(
      std::chrono::steady_clock::now() - start).count();
  return sink == 12345.678 ? -1 : ns / n;
}')
  tk <- c(knots[knots > 0 & knots < 40], 40)
  tk <- c(0, tk)
  ns <- attempt_ns(tab$ACK, tab$bCK, tab$dCK, tab$cCK, tk, rain_at(tk), rep(0, length(tk)), 2e6L)
  attempts <- nrow(ch$rows) + ch$rejected
  forward <- as.numeric(Sys.getenv("FORWARD_S", "114.8"))
  cat(sprintf("the chain alone in C++: %d attempts at %.0f ns each, %.1f ms, %.1e of a %.1f s forward\n",
              attempts, ns, attempts * ns * 1e-6, attempts * ns * 1e-9 / forward, forward))
}
