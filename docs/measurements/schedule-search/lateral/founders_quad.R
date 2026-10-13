# Founders' window: own-part quadrature error of fate interpolated linearly (the hat rule) vs
# log-linearly, at f = 8 and 16 nodes, against f = 64's nodes (log-linear) as truth. Fixed field
# (f64's fate), the pilot's creation rate. In eps of ln J (0.025).
suppressMessages(source("/home/user/plant-dev/harness/schedule/anysched.R"))
A <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/adjmap/runs"
for (cs in names(CASES)) { pe <- pilot_edges(cs); b1 <- pe$b1
  cr <- as.data.frame(readRDS(file.path(RUNS, paste0(case_of(cs)$pilot, ".rds")))$stand$creation)
  cf <- function(b) cr$rate[pmax(1, findInterval(b, cr$start))]
  x <- readRDS(file.path(A, sprintf("lat_%s_f64_l70.rds", cs))); b <- nd(x); J <- sum(b$w * b$offspring)
  w <- b[b$birth <= b1 + 1e-9, ]; if (abs(tail(w$birth, 1) - b1) > 1e-6) { cat(cs, "no node at b1\n"); next }
  u <- seq(0, b1, length.out = 20001); um <- (head(u, -1) + u[-1]) / 2; du <- diff(u); cu <- cf(um)
  I <- function(bb, g, log = TRUE) sum(cu * du * (if (log) exp(approx(bb, log(g), um)$y) else approx(bb, g, um)$y))
  tru <- I(w$birth, w$offspring)
  out <- sapply(c(8, 16, 32), function(f) { k <- seq(1, nrow(w), by = 64 / f); c(lin = (I(w$birth[k], w$offspring[k], FALSE) - tru) / J / 0.025,
      log = (I(w$birth[k], w$offspring[k], TRUE) - tru) / J / 0.025) })
  cat(sprintf("%-13s b1 %.2f  window share of J %.2f | hat f8 %+.2f f16 %+.2f f32 %+.3f | log-linear f8 %+.2f f16 %+.3f f32 %+.4f eps\n", cs, b1, tru / J,
    out[1,1], out[1,2], out[1,3], out[2,1], out[2,2], out[2,3])) }
cat("log-spline (fmm) interpolation of log fate:\n")
for (cs in names(CASES)) { pe <- pilot_edges(cs); b1 <- pe$b1
  cr <- as.data.frame(readRDS(file.path(RUNS, paste0(case_of(cs)$pilot, ".rds")))$stand$creation)
  cf <- function(b) cr$rate[pmax(1, findInterval(b, cr$start))]
  x <- readRDS(file.path(A, sprintf("lat_%s_f64_l70.rds", cs))); b <- nd(x); J <- sum(b$w * b$offspring)
  w <- b[b$birth <= b1 + 1e-9, ]
  u <- seq(0, b1, length.out = 20001); um <- (head(u, -1) + u[-1]) / 2; du <- diff(u); cu <- cf(um)
  tru <- sum(cu * du * exp(splinefun(w$birth, log(w$offspring), "fmm")(um)))
  e <- sapply(c(8, 16, 32), function(f) { k <- seq(1, nrow(w), by = 64 / f); (sum(cu * du * exp(splinefun(w$birth[k], log(w$offspring[k]), "fmm")(um))) - tru) / J / 0.025 })
  cat(sprintf("%-13s log-spline f8 %+.3f f16 %+.4f f32 %+.5f eps\n", cs, e[1], e[2], e[3])) }
