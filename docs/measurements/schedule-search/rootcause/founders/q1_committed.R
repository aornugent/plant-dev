# q1_committed.R: how much of the committed run's error (val_insk_c, libS, 1e-4) is the
# founders'. Founders' error = -4/3 x the move from bisecting every founders' interval.
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/common.R")
FO <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/founders"
rq <- function(f) { x <- readRDS(f); if (is.null(x$stand$elasticity)) return(NULL); quantities(x)[Q] / EPS }
rms <- function(x) sqrt(mean(x^2))
top <- function(x, n = 4) { o <- order(-abs(x))[1:n]; paste(sprintf("%s %+.2f", names(x)[o], x[o]), collapse = ", ") }
lat <- readRDS(file.path(FO, "q1_lattice.rds")); res <- list()
for (cs in ALL) { f <- file.path(FO, "runs", sprintf("fbis_%s.rds", cs)); if (!file.exists(f)) next
  b <- rq(f); if (is.null(b)) next
  c0 <- qn(sprintf("val_insk_c_%s", cs))[Q] / EPS; ref <- REF$L19[[cs]][Q] / EPS
  e <- c0 - ref; F <- -4 / 3 * (b - c0); rest <- e - F
  cl <- lat[[cs]]$eF16; cosl <- if (!is.null(cl)) sum(F * cl) / sqrt(sum(F^2) * sum(cl^2)) else NA
  c32 <- lat[[cs]]$eF32; cos32 <- sum(F * c32) / sqrt(sum(F^2) * sum(c32^2))
  cat(sprintf("%-13s err rms %.3f worst %.2f | founders' rms %.3f max %.2f lnJ %+.3f | share (proj) %4.0f%% |F|^2/|e|^2 %4.0f%% | rest rms %.3f worst %.2f | cos(F, lattice eF16) %+.2f eF32 %+.2f\n      F: %s\n",
    cs, rms(e), max(abs(e)), rms(F), max(abs(F)), F["lnJ"], 100 * sum(F * e) / sum(e^2), 100 * sum(F^2) / sum(e^2), rms(rest), max(abs(rest)), cosl, cos32, top(F)))
  res[[cs]] <- list(e = e, F = F) }
saveRDS(res, file.path(FO, "q1_committed.rds"))
