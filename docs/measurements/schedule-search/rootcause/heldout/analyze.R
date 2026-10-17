# analyze.R: from score.rds (and score857.rds): per case, the check's true error ratio
# against the committed run's (slope of e_f on e_c through 0, over |e_c| > 0.2) beside the
# a09 shrink s and 1/1.6^2, and the slope a perfect read would need; the stress draws'
# failure split by criterion. Usage: Rscript analyze.R [857]
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/heldout/cases.R", local = TRUE)
tag <- if (length(commandArgs(TRUE))) commandArgs(TRUE)[1] else ""
S <- readRDS(file.path(HO_OUT, sprintf("score%s.rds", tag))); K <- S$keep; TB <- S$tab
out <- do.call(rbind, lapply(names(K), function(cs) { k <- K[[cs]]; m <- abs(k$ec) > 0.2
  sl <- if (sum(m) >= 2) sum(k$ef[m] * k$ec[m]) / sum(k$ec[m]^2) else NA
  data.frame(case = cs, n_big = sum(m), s_a09 = k$s, slope_fc = sl, r2_law = 1 / 1.6^2, read_if_s_true = (1 - sl) / (1 - k$s),
    cos_fc = sum(k$ef * k$ec) / sqrt(sum(k$ef^2) * sum(k$ec^2))) }))
print(out, digits = 3)
cat("\nstress (coord / jit) pass rates in the table: st_coord, st_jit; per criterion C3:", "\n")
print(TB[, c("case", "Wc", "rms_c", "Wf", "commit", "pass", "fails", "st_coord", "st_coord_C3", "st_coord_C1", "st_jit", "st_jit_C3")], digits = 3)
