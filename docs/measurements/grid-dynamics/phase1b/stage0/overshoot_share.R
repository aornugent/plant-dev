# How often each pair's accepted steps start past the h|lambda_soil| at which
# its own stages first go negative on a decaying mode (DP 1.038, CK 2.159;
# stage0/first_negative.txt), from the driver's saved step tables.
#   Rscript stage0/overshoot_share.R   (from phase1b/)
DEV <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev"
runs <- list(
  ck = c("1e-4" = file.path(DEV, "events/runs/v0_1e-4.rds"), "3e-5" = file.path(DEV, "seed/tied_3e-5.rds"),
         "1e-5" = file.path(DEV, "rej/tied_1e-5_soil1.rds")),
  dp = c("1e-4" = file.path(DEV, "phase1b/runs/dp_1e-4.rds"), "3e-5" = file.path(DEV, "phase1b/runs/dp_3e-5.rds"),
         "1e-5" = file.path(DEV, "phase1b/runs/dp_1e-5.rds")))
beta <- c(ck = 3.7343596, dp = 3.3065679)
neg <- c(ck = 2.159, dp = 1.038)
for (m in names(runs)) for (T in names(runs[[m]])) {
  st <- readRDS(runs[[m]][[T]])$st
  hl <- st$x_soil * beta[[m]]                       # h |lambda_soil| at each accepted step's start
  cat(sprintf("%s %s: %d steps; h|lambda_soil| past its first negative stage (%.3f): %.2f%%; past CK's (2.159): %.2f%%; past DP's (1.038): %.2f%%; median h %.3g days\n",
              m, T, nrow(st), neg[[m]], 100 * mean(hl > neg[[m]]), 100 * mean(hl > 2.159), 100 * mean(hl > 1.038),
              365 * median(st$h)))
}
