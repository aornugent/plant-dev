# diffs.R: rms and along-M of the difference between two settings' runs, per case (eps).
suppressMessages(source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/common.R"))
SU <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/summing"
rd <- function(n, cs) { f <- file.path(SU, "runs", sprintf("%s_%s.rds", n, cs)); if (!file.exists(f)) NULL else readRDS(f) }
qv <- function(x) quantities(x)[Q] / EPS
pairs <- list(c("Lallnl", "Lall"), c("Lallm", "Lall"), c("Lallq", "Lall"), c("Lfoundersq", "Lfounders"), c("Lfoundersnl", "Lfounders"), c("LFallnl", "Lallnl"), c("LFall", "Lall"))
for (cs in c("dry", "episodic-lma", "long-wet", "dry-flat")) for (p in pairs) { a <- rd(p[1], cs); b <- rd(p[2], cs); if (is.null(a) || is.null(b)) next
  d <- qv(a) - qv(b); cat(sprintf("%-12s %-11s - %-10s rms %.3f worst %.2f along M %+.2f lnJ %+.3f\n", cs, p[1], p[2], sqrt(mean(d^2)), max(abs(d)), sum(d * M_unit[names(d)]), d["lnJ"])) }
