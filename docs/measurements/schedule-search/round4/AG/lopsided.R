# lopsided.R CASE: for a09 c and P's layouts, the establishment inside each interval
# under the instant gate g (lib19 pilot) and under E (g filtered on w = 0.05):
# u = establishment's mean position in its interval (0.5 = centred), and the share of
# establishment in intervals whose establishment is lopsided (|u - 0.5| > 0.25).
source("/home/user/plant-dev/docs/measurements/schedule-search/round4/AG/lib.R")
cs <- commandArgs(TRUE)[1]; cr <- creation_of(cs); w <- 0.05
crE <- cr; e <- cr$rate[1]; for (i in seq_len(nrow(cr))) { h <- cr$end[i] - cr$start[i]; e <- cr$rate[i] + (e - cr$rate[i]) * exp(-h / w); crE$rate[i] <- e }
for (v in c("a09c", "in10", "ins", "mid", "out10")) {
  S <- switch(v, a09c = sched(cs), ins = readRDS(file.path(POUT, "sched", sprintf("insc_%s.rds", cs))), readRDS(file.path(POUT, "sched", sprintf("%s_%s.rds", v, cs))))
  S <- S[S >= edge_table(cs)$b[1] - 1e-9 & S < 25]
  r <- sapply(list(g = cr, E = crE), function(c) { A <- anatomy(S, cs, c); m <- A$E > 0; c(lop = sum(A$E[m & abs(A$u - 0.5) > 0.25]) / sum(A$E[m]), wdev = sum(A$E[m] * abs(A$u[m] - 0.5)) / sum(A$E[m])) })
  cat(sprintf("%-6s n %3d | g: lopsided share %.3f, weighted |u - 1/2| %.3f | E: lopsided share %.3f, weighted |u - 1/2| %.3f\n", v, length(S), r[1, "g"], r[2, "g"], r[1, "E"], r[2, "E"])) }
