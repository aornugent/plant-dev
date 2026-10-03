# Each run's soil against the tol 1e-7 reference over the whole run, at its step
# ends: the top layer's relative difference by phase (steps in a dry spell, with
# no rain over the step, against the rest), and the member steps' lengths there.
#
#   Rscript soil_whole.R run1.rds [run2.rds ...]
D <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev"
ref <- readRDS(file.path(D, "ark", "ck_u108_1e-7.rds"))
rs <- ref$st
f <- lapply(1:3, function(l) splinefun(rs$time, rs[[paste0("soil_", l)]], method = "fmm"))
# The daily record the driver splines (value at knot d is rain[d + 1]), from a
# run whose OUT kept it.
rain <- readRDS(file.path(D, "split", "out", "mono_3e-5.rds"))$rain
dry_over <- function(t0, t1) {
  d0 <- floor(t0 * 365 + 1e-9); d1 <- ceiling(t1 * 365 - 1e-9)
  # dry: the record is zero at every knot from one before the span to one after
  all(rain[max(1, d0):(d1 + 2)] == 0)
}
cat(sprintf("%-26s %6s %8s %8s | %-28s | %-28s | %s\n", "run", "steps", "J-J*", "dry", "soil_1 rel diff: dry med/q05",
            "wet med/q05", "dry steps: median days / q90"))
for (fn in commandArgs(TRUE)) {
  # a bare name is a spike run (split/out) or one of this study's (partition_bias/out)
  if (!file.exists(fn)) {
    cand <- file.path(D, c("split/out", "partition_bias/out"), paste0(fn, ".rds"))
    fn <- cand[file.exists(cand)][1]
  }
  o <- readRDS(fn); st <- o$st
  t0 <- st$time - st$h
  dry <- mapply(dry_over, t0, st$time)
  d1 <- (st$soil_1 - f[[1]](st$time)) / f[[1]](st$time)
  q <- function(x) sprintf("%+.1e / %+.1e", median(x), quantile(x, 0.05))
  cat(sprintf("%-26s %6d %+8.1e %8.2f | %-28s | %-28s | %.2f / %.2f\n", sub("\\.rds$", "", basename(fn)), nrow(st),
              (o$J - 12.6687135) / 12.6687135, mean(dry), q(d1[dry]), q(d1[!dry]),
              median(st$h[dry]) * 365, quantile(st$h[dry], 0.9) * 365))
}
