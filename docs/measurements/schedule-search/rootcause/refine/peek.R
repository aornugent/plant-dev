# peek.R CASE TOL TARGET RUNS: the tool's state after RUNS runs from stored runs, with each
# run's true worst error against the case's reference.
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/refine/lib.R")
a <- commandArgs(TRUE); cs <- a[1]; tol <- as.numeric(a[2]); tg <- as.numeric(a[3]); n <- as.integer(a[4])
REQ <- tempfile(); cr <- case_of_refine(cs, tol); R <- ref_ladder(cs)
t <- refine_schedule(cr, target = tg, max_runs = n, noise = if (tol >= 1e-4) 0.024 else 0.012)
print(t$history); print(t$regions)
e <- (t$answer - R$ref) / EPS; o <- order(-abs(e))[1:8]
print(round(rbind(err = e[o], est = t$estimate[o], E1 = t$E1[o]), 3))
for (g in names(t$moves)) cat(g, sapply(t$moves[[g]], function(m) sprintf("rms %.3f max %.3f (%s)", sqrt(mean(m^2)), max(abs(m)), Q[which.max(abs(m))])), "\n")
