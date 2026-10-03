# The 1e-5 reference's own steps: how long they get, and how many exceed 15 and
# 22 days, against the 3e-5 runs' programs.
D <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev"
x <- readRDS(file.path(D, "phase1c/full/epi_1e-5.rds"))
h <- diff(x$stand$times) * 365
cat(sprintf("episodic 1e-5 (plant's control): %d steps, longest %.1f d at t = %.2f; over 15 d: %d; over 22 d: %d\n",
            length(h), max(h), x$stand$times[which.max(h)], sum(h > 15 + 1e-9), sum(h > 22 + 1e-9)))
for (f in c("window/drv/episodic_base", "phase1c/drv/episodic_ruleA_h15", "phase1c/drv/episodic_ruleA_h22")) {
  st <- readRDS(file.path(D, paste0(f, ".rds")))$st; hd <- st$h * 365
  cat(sprintf("%-32s %d steps, longest %.1f d; over 15 d: %d; over 22 d: %d\n", basename(f), nrow(st), max(hd),
              sum(hd > 15 + 1e-9), sum(hd > 22 + 1e-9)))
}
