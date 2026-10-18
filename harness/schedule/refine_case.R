# Refine one case's schedule and save the result:
#   Rscript harness/schedule/refine_case.R CASE SCALE DIR
DEV <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev"
LIB <- file.path(DEV, "schedtest/adjmap/libS")
Sys.setenv(PLANT_LIB = LIB)
source("/home/user/plant-dev/harness/long_drought.R")
source("/home/user/plant-dev/harness/schedule/refine.R")
weight <- function(w) file.path(DEV, "window/rule_A", sprintf("weight_%s.rds", w))
SPECS <- list(
  dry = list(regime = "dry", trait = "", weight = weight("dry")),
  `long-wet` = list(regime = "long-wet", trait = "", weight = weight("long-wet")),
  `episodic-lma` = list(regime = "episodic", trait = "lma=0.25", weight = weight("episodic")),
  `dry-flat` = list(regime = "dry-flat", trait = "", weight = weight("dry")),
  `epi-adG208` = list(regime = "episodic", trait = "a_dG2=-0.2", weight = weight("episodic")))
a <- commandArgs(TRUE); case <- a[1]; scale <- as.numeric(a[2]); dir <- a[3]
spec <- c(SPECS[[case]], seed = "31", lib = LIB)
fit <- refine_schedule(spec, file.path(dir, case), scale)
saveRDS(fit, file.path(dir, case, "fit.rds"))
cat(sprintf("%s: %s after %d passes, worst bound %.2f (%s), %d nodes\n", case, fit$status, length(fit$history),
            max(fit$bound), names(fit$bound)[which.max(fit$bound)], length(fit$schedule$nodes)))
