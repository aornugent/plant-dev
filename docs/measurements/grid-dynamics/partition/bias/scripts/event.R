# The first mortality event (the dry spell 3.38-3.70) on short runs: each run's
# state at its end (a leg end) against the tol 1e-7 reference there, and the top
# layer's largest relative deficit inside the spell.
#
#   Rscript event.R name1 [name2 ...]     (out/<name>.rds and out/<name>_states.rds)
B <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/partition_bias"
D <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/ark"
ref <- readRDS(file.path(D, "ck_u108_1e-7.rds"))$st
ref_s <- readRDS(file.path(D, "ck_u108_1e-7_states.rds"))
w <- ref$time >= 3.36 & ref$time <= 3.72
f1 <- splinefun(ref$time[w], ref$soil_1[w], method = "fmm")
cat(sprintf("%-26s %6s %10s %10s %10s %10s %10s %10s %10s\n", "run", "steps", "t_end", "dmort1", "dmort2",
            "dstor1", "doff1", "dheight1", "soil1_min"))
for (nm in commandArgs(TRUE)) {
  o <- readRDS(file.path(B, "out", paste0(nm, ".rds")))
  s <- readRDS(file.path(B, "out", paste0(nm, "_states.rds")))
  te <- max(o$st$time)
  a <- s[[which.max(o$st$time)]]
  b <- ref_s[[which.min(abs(ref$time - te))]]
  stopifnot(abs(ref$time[which.min(abs(ref$time - te))] - te) < 1e-12, length(a) == length(b))
  i <- which(o$st$time >= 3.38 & o$st$time <= 3.70)
  d1 <- (o$st$soil_1[i] - f1(o$st$time[i])) / f1(o$st$time[i])
  cat(sprintf("%-26s %6d %10.4f %+10.2e %+10.2e %+10.2e %+10.2e %+10.2e %+10.2e\n", nm, nrow(o$st), te,
              a[2] - b[2], a[11] - b[11], (a[6] - b[6]) / b[6], (a[7] - b[7]) / b[7], (a[1] - b[1]) / b[1],
              if (length(i)) min(d1) else NA))
}
