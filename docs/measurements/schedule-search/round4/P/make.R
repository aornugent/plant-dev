# Writes agent P's schedule variants of a09's committed schedules to P_out/sched/.
source("/home/user/plant-dev/docs/measurements/schedule-search/round4/P/lib.R")
dir.create(file.path(POUT, "sched"), showWarnings = FALSE)
out <- function(name, S) { saveRDS(S, file.path(POUT, "sched", paste0(name, ".rds"))); S }
a <- commandArgs(TRUE); cs <- a[1]; S0 <- sched(cs)
V <- list(out10 = shift_edges(S0, cs, 10, "out"), in3 = shift_edges(S0, cs, 3, "in"), in20 = shift_edges(S0, cs, 20, "in"), in10 = shift_edges(S0, cs, 10, "in"), out3 = shift_edges(S0, cs, 3, "out"), out30 = shift_edges(S0, cs, 30, "out"))
for (v in names(V)) { S <- out(sprintf("%s_%s", v, cs), V[[v]]); A <- anatomy(S[S < 25], cs); x <- exposure(A)
  cat(sprintf("%-8s %-10s n %3d proxy %.3e (base %.3e) | Xg %.4f Xs %.4f mixed %d\n", v, cs, length(S), proxy(cs, S), proxy(cs, S0), x[1], x[2], x[3])) }
S <- out(sprintf("mid_%s", cs), spell_mid(S0, cs)); A <- anatomy(S[S < 25], cs); x <- exposure(A)
cat(sprintf("%-8s %-10s n %3d proxy %.3e | Xg %.4f Xs %.4f mixed %d\n", "mid", cs, length(S), proxy(cs, S), x[1], x[2], x[3]))
