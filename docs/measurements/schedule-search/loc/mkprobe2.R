# Tail edges dropped only after b = 25 or b = 30, on c05_graded's committed schedule.
source("/home/user/plant-dev/harness/schedule/lattice.R"); L <- file.path(DEV, "schedtest/loc")
for (case in c("dry", "episodic")) { S <- readRDS(file.path(L, sprintf("loc_c5g_c_%s.rds", case))); e <- round(pilot_edges(case)$edges, 10)
  for (t in c(25, 30)) { x <- S[!(round(S, 10) %in% e & S > t)]; saveRDS(x, file.path(L, sprintf("probe_noedge%d_%s.rds", t, case)))
    cat(sprintf("%s after %d: %d edges dropped of %d nodes\n", case, t, length(S) - length(x), length(S)), file = stderr()) } }
