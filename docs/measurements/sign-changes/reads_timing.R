# The split's costs timed again on one core (prereg.txt, fourteenth extension).
#   OUTD=... Rscript reads_timing.R
OUTD <- Sys.getenv("OUTD")
run <- function(f) readRDS(file.path(OUTD, paste0(f, ".rds")))
secs <- function(f, phase, what = "secs") run(f)$phases[[phase]][[what]]
verdict <- function(holds, fails) if (holds) "holds" else if (fails) "fails" else "neither"
show <- function(x) paste(sprintf("%.1f", x), collapse = ", ")

for (what in c("secs", "cpu_secs")) {
  g <- sapply(1:6, function(i) secs(sprintf("grad_s%d", i), "stand_gradient", what))
  p <- sapply(1:6, function(i) secs(sprintf("plain_s%d", i), "stand_gradient", what))
  q <- mean(g) / mean(p) - 1
  pairs <- g / p - 1
  cat(sprintf("S5 on %s (at most 6%% over plain's): split %s; plain %s: %+.1f%%%s\n", what,
              show(g), show(p), 100 * q,
              if (what == "secs") paste0(", ", verdict(q <= 0.06, q >= 0.09)) else ""))
  cat(sprintf("  each pair %s%%; their mean %+.1f%%, sd %.1f%%\n",
              paste(sprintf("%+.1f", 100 * pairs), collapse = ", "),
              100 * mean(pairs), 100 * sd(pairs)))
}

for (what in c("secs", "cpu_secs")) {
  fw <- sapply(1:2, function(i) secs(sprintf("fwd_f%d", i), "stand_run", what))
  fb <- sapply(1:2, function(i) secs(sprintf("fwdprev_f%d", i), "stand_run", what))
  fp <- sapply(1:2, function(i) secs(sprintf("fwdplain_f%d", i), "stand_run", what))
  f <- mean(fw) / mean(fp) - 1
  cat(sprintf("F on %s (at most 4%% over plain's): split %s; PREV %s; plain %s: %+.1f%%%s; PREV %+.1f%% over plain's\n",
              what, show(fw), show(fb), show(fp), 100 * f,
              if (what == "secs") paste0(", ", verdict(f <= 0.04, f > 0.06)) else "",
              100 * (mean(fb) / mean(fp) - 1)))
}
cat(sprintf("J: split %.12f, PREV %.12f, plain %.12f\n", run("fwd_f1")$stand$J,
            run("fwdprev_f1")$stand$J, run("fwdplain_f1")$stand$J))
