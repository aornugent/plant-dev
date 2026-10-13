# Parse ODELIA_ADJOINT_TRACE lines: step, range, t, h, worst |lambda|.
read_trace <- function(f) {
  l <- grep("^ODELIA_ADJOINT_TRACE", readLines(f), value = TRUE)
  m <- regmatches(l, regexec("step (\\d+) of \\[(\\d+), (\\d+)\\] t=(\\S+) h=(\\S+) worst \\|lambda\\| (\\S+)", l))
  d <- as.data.frame(do.call(rbind, lapply(m, function(x) as.numeric(x[-1]))))
  names(d) <- c("k", "lo", "hi", "t", "h", "worst"); d
}
