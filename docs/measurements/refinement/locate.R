# Locate a front by bisection on short forward runs: the first neighbour pair
# after day 1 whose sign-change counts differ, refined with 8 nodes per round
# until the pair is closer than 1/512 day.  Rscript locate.R TAG [TRAIT_REL]
args <- commandArgs(TRUE); tag <- args[1]; rel <- if (length(args) > 1) args[2] else ""
D <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev"
H <- "/home/user/plant-dev"; F <- file.path(D, "schedtest/front"); setwd(H)
run <- function(times, name, life) {
  tf <- file.path(F, paste0(name, "_times.rds")); saveRDS(times[times < life], tf); out <- file.path(F, paste0(name, ".rds"))
  env <- c(sprintf("PLANT_LIB=%s/lib_109", D), "REGIME=constant", "TOL=3e-5", "ATOL=1e-4", "WEIGHT_SOIL=10",
           sprintf("WEIGHT=%s/window/rule_A/weight_constant.rds", D), "WEIGHT_MAX=100", "HMAX=15", "SHARE=0.1", "SPLIT=1",
           "FORWARD=1", sprintf("LIFETIME=%g", life), sprintf("TIMES=%s", tf), sprintf("OUT=%s", out), if (nzchar(rel)) sprintf("TRAIT_REL=%s", rel))
  system2("env", c(env, "Rscript", file.path(H, "harness/run_record.R")), stdout = file.path(F, paste0(name, ".log")), stderr = file.path(F, paste0(name, ".log")))
  readRDS(out)$stand
}
times <- sort(unique(c(seq(0, 60, by = 2) / 365, seq(0, 53 * 40 / 54, length.out = 54)))); life <- as.numeric(Sys.getenv("LIFE", "2")); round <- 0
repeat {
  round <- round + 1
  x <- run(times, sprintf("%s_r%d", tag, round), life); b <- x$nodes$birth; s <- x$splits
  k <- which(b < 1 & seq_along(b) < length(b))
  j <- k[which(s[k + 1] != s[k])[1]]
  if (is.na(j)) { cat(tag, "no front found in round", round, "\n"); break }
  w <- (b[j + 1] - b[j]) * 365
  cat(sprintf("%s round %d: %d nodes, counts %d -> %d between days %.5f and %.5f (%.5f d)\n", tag, round, length(b), s[j], s[j + 1], 365 * b[j], 365 * b[j + 1], w))
  if (w < 1 / 512) break
  times <- sort(unique(c(times, seq(b[j], b[j + 1], length.out = 10))))
}
saveRDS(list(lo = b[j], hi = b[j + 1], rounds = round, times = times), file.path(F, paste0(tag, "_front.rds")))
