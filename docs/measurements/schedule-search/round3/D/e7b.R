O <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/D_out/"
for (r in c("e7_n1g", "e7_n2")) {
  s <- readRDS(paste0(O, r, ".rds"))$soilwin; s <- s[s$h > 0, ]
  cat("==", r, ": steps", nrow(s), " with R>1:", sum(s$R > 1), " max R", round(max(s$R), 2),
      " min z", round(min(s$z), 2), "\n")
  # product of R from each step to 37.0750 (what the adjoint picks up walking back from 37.075)
  for (rng in list(c(37.0475, 37.0575), c(37.0685, 37.0750), c(37.0750, 37.0820))) {
    i <- s$t0 >= rng[1] & s$t0 < rng[2]
    cat(sprintf("  [%.4f, %.4f): %d steps, log10 prod R %.2f, theta1 range %.4f-%.4f, step-to-step |dtheta1| median %.4f\n",
        rng[1], rng[2], sum(i), sum(log10(abs(s$R[i]))), min(s$theta1[i]), max(s$theta1[i]),
        median(abs(diff(s$theta1[i])))))
  }
}
