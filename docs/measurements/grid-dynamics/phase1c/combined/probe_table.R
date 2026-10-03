# The episodic probes: which part of the combined setting makes plant refuse the
# stand's gradient.
C <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/phase1c/combined/full"
for (f in list.files(C, "^probe_.*\\.rds$", full.names = TRUE)) {
  x <- readRDS(f); h <- diff(x$times) * 365
  cat(sprintf("%-26s J %.9f, %5d steps, longest %4.1f d | gradient finite %2d of %d | refusal: %s\n", basename(f), x$J,
              length(x$times), max(h), sum(is.finite(x$gradient)), length(x$gradient),
              if (is.null(x$refusal) || !any(nzchar(x$refusal))) "none" else substr(paste(x$refusal, collapse = " | "), 1, 180)))
}
