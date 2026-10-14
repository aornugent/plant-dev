# mkwide.R F: a09's c and f schedules rebuilt with every interior spacing x F (BG, the founders' layer
# and window, and the founders' cap), then late edges left out (a09_late) and the 12 d inset applied.
# F = 1 must reproduce a09's schedules.
source("/home/user/plant-dev/docs/measurements/schedule-search/round4/P/lib.R")
fac <- as.numeric(commandArgs(TRUE)[1]); cases <- commandArgs(TRUE)[-1]; if (!length(cases)) cases <- ALL
Sys.setenv(BG = 90 * fac, LAYER = 24 / fac, R = 1.6)
w <- new.env(); sys.source("/home/user/plant-dev/docs/measurements/schedule-search/any/a05_fill.R", w)
cap_of <<- function(p, lo, hi) ifelse(hi <= p$b1 + 1e-9, fac * p$b1 / 12, ifelse(lo < 20, 100 / 365, 280 / 365))
w$capf <- function(p, b) if (b < p$b1) fac * p$b1 / 12 else if (b < 20) 100 / 365 else 280 / 365
for (cs in cases) { p <- pilot_of(cs); h <- w$hfun_of(p); Sc <- build_graded(p, h); Sk <- w$fill(p, h, Sc, build_graded(p, function(b) h(b) / w$R))
  late <- round(p$edges[p$edges > 25], 10); Sc <- Sc[!(round(Sc, 10) %in% late)]; Sk <- Sk[!(round(Sk, 10) %in% late)]
  if (fac == 1) { a <- sched(cs, "c"); b <- sched(cs, "f"); cat(sprintf("%-13s reproduce a09: c %d/%d max diff %.1e, f %d/%d max diff %.1e\n", cs, length(Sc), length(a), if (length(Sc) == length(a)) max(abs(Sc - a)) else NA, length(Sk), length(b), if (length(Sk) == length(b)) max(abs(Sk - b)) else NA)); next }
  Ic <- as.numeric(inset_rule(Sc, cs)); If <- as.numeric(inset_rule(Sk, cs)); tag <- sprintf("w%g", fac * 100)
  saveRDS(Ic, file.path(POUT, "sched", sprintf("%sc_%s.rds", tag, cs))); saveRDS(If, file.path(POUT, "sched", sprintf("%sf_%s.rds", tag, cs)))
  I0c <- readRDS(file.path(POUT, "sched", sprintf("insc_%s.rds", cs))); I0f <- readRDS(file.path(POUT, "sched", sprintf("insf_%s.rds", cs)))
  cat(sprintf("%-13s x%.2f: c %d (inset %d), f %d (inset %d) | proxy c %.3f (inset %.3f), shrink %.2f\n", cs, fac, length(Ic), length(I0c), length(If), length(I0f), proxy(cs, Ic), proxy(cs, I0c), proxy(cs, If) / proxy(cs, Ic))) }
