# Shared helpers for agent E: rain knots without loading plant, and run lookup.
DEV <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev"
AR <- file.path(DEV, "schedtest/adjmap/runs")
EO <- file.path(DEV, "schedtest/E_out")
local({ src <- readLines("/home/user/plant-dev/harness/long_drought.R"); i <- grep("^LIFETIME <-", src); j <- grep("^AK <- active_knots", src)
  eval(parse(text = src[i:(j - 1)]), envir = globalenv()) })
knots_of <- function(regime, seed = NULL) { scen <- regime
  if (!is.null(seed)) { scen <- sprintf("%s, seed %d", regime, seed); RAIN_SPECS[[scen]] <<- modifyList(RAIN_SPECS[[regime]], list(seed = seed)) }
  active_knots(scen) }
CASES10 <- c("episodic", "dry", "long-wet", "long-drought", "episodic-lma", "dry-flat", "ld-102", "ld-105", "dry-p50", "wet-adG2")
# a09 in the proper setting: long-drought records from the a09p reruns.
a09_file <- function(case, cf) { tag <- if (grepl("^l(d|ong-drought)", case)) "a09p" else "a09"; file.path(AR, sprintf("val_%s_%s_%s.rds", tag, cf, case)) }
