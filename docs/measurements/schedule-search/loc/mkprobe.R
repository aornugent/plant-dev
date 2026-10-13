# Probes that open what the scorer forbids, on c05_graded's committed schedule:
# tail edges dropped (b > 20), and the 10-20 band thinned (every other non-edge node).
source("/home/user/plant-dev/harness/schedule/lattice.R"); L <- file.path(DEV, "schedtest/loc")
for (case in commandArgs(TRUE)) { S <- readRDS(file.path(L, sprintf("loc_c5g_c_%s.rds", case))); e <- round(pilot_edges(case)$edges, 10)
  noedge <- S[!(round(S, 10) %in% e & S > 20)]
  mid <- which(S >= 10 & S < 20 & !(round(S, 10) %in% e)); wide <- S[-mid[seq(1, length(mid), by = 2)]]
  saveRDS(noedge, file.path(L, sprintf("probe_noedge_%s.rds", case))); saveRDS(wide, file.path(L, sprintf("probe_wide_%s.rds", case)))
  cat(sprintf("%s: base %d nodes, tail edges dropped %d, 10-20 thinned %d; widest interval in 10-20 %.0f d\n", case, length(S), length(S) - length(noedge), length(S) - length(wide),
    max(diff(wide[wide >= 9.9 & wide <= 20.1])) * 365), file = stderr()) }
