# Scores resize.R (and its base) on the training five; the uses' schedule is charged to use, not find.
source("/home/user/plant-dev/harness/schedule/anyscore.R")
a <- commandArgs(TRUE); env <- new.env(); sys.source(a[1], env)
one <- function(st) { STRESS <<- st; if (!is.null(env$USE_COST)) env$USE_COST$v <- c(); r <- evaluate_any(function(ctx) env$algorithm(ctx))
  adj <- if (!is.null(env$USE_COST)) sum(env$USE_COST$v) else 0; list(T = r$T - adj, ok = r$feasible, r = r) }
z <- one(0); tab <- z$r$table; print(tab[, c("case", "T", "worst", "C1", "C2", "C3", "C5")], row.names = FALSE)
cat(sprintf("T %.0f (uses charged to use), feasible %s\n", z$T, z$ok))
d <- as.integer(Sys.getenv("STRESS", "5")); oks <- sapply(seq_len(d), function(s) one(s)$ok); cat(sprintf("robust: %d of %d draws\n", sum(oks), d))
