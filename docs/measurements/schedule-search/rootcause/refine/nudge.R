# nudge.R: the noise floor at 3e-5 (S1 at 3e-5 against S1 at 3.15e-5, flat-al1125 and
# ld104-p50125), and S1 at 3e-5 against S1 at 1e-4 on every 3e-5 case run so far.
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/refine/lib.R")
for (cs in c("flat-al1125", "ld104-p50125")) { S <- e6_runs(cs)$S1; a <- read_run(rf_name(cs, 3e-5, S), S); b <- read_run(paste0("nudge_", cs), S)
  if (is.null(a) || is.null(b)) next; d <- (qv(b) - qv(a)) / EPS
  cat(sprintf("%-14s nudge 5%%: rms %.4f, max %.3f (%s), along M %+.3f\n", cs, sqrt(mean(d^2)), max(abs(d)), Q[which.max(abs(d))], sum(d * M))) }
for (cs in c(BANK, HELD)) { e <- e6_runs(cs); a <- read_run(rf_name(cs, 3e-5, e$S1), e$S1); if (is.null(a)) next
  d <- (qv(a) - qv(e$x1)) / EPS; R <- ref_ladder(cs); e1 <- (qv(e$x1) - R$ref) / EPS; e3 <- (qv(a) - R$ref) / EPS
  cat(sprintf("%-14s S1 3e-5 - 1e-4: rms %.3f max %.3f (%s) along M %+.3f | W 1e-4 %.3f, W 3e-5 %.3f\n", cs, sqrt(mean(d^2)), max(abs(d)), Q[which.max(abs(d))], sum(d * M), max(abs(e1)), max(abs(e3)))) }
