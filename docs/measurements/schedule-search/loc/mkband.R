# mkband.R CASE...: G0 with every interval in one birth band bisected, for the bands
# F = [0, b1), A = [b1, 10), B = [10, 20); C = G0, so each run's map drops exactly the
# new midpoints. Prints one job line per band for one.sh.
source("/home/user/plant-dev/harness/schedule/lattice.R"); L <- file.path(DEV, "schedtest/loc")
for (case in commandArgs(TRUE)) { G <- readRDS(file.path(L, sprintf("G0_%s.rds", case))); b1 <- pilot_edges(case)$b1
  cs <- case_of(case); extra <- paste(c(if (cs$trait != "") paste0("TRAIT_REL=", cs$trait), if (cs$set == "pf") "SHARE= SPLIT=0"), collapse = " ")
  for (bd in list(F = c(0, b1), A = c(b1, 10), B = c(10, 20))) NULL
  bands <- list(F = c(0, b1), A = c(b1, 10), B = c(10, 20))
  for (n in names(bands)) { r <- bands[[n]]; mid <- (G[-1] + G[-length(G)]) / 2; lo <- G[-length(G)]
    add <- mid[lo >= r[1] - 1e-9 & lo < r[2] - 1e-9]
    S <- sort(unique(round(c(G, add), 10))); f <- file.path(L, sprintf("band%s_%s.rds", n, case)); saveRDS(S, f)
    cat(sub(" +$", "", sprintf("loc_band%s_%s %s MODE=map TIMES=%s COARSE=%s %s", n, case, cs$rec, f, file.path(L, sprintf("G0_%s.rds", case)), extra)), "\n", sep = "") } }
