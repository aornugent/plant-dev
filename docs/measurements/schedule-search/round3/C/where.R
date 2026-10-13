# Where the check's added cost and the committed error sit, by birth-date region, for a05.
source("/home/user/plant-dev/docs/measurements/schedule-search/round3/C/lib.R")
nodecost <- function(cd, S) { co <- coef(cd$rowsfit); run_cost(co[["n"]] + co[["life"]] * (H - S), TRUE) }
brk <- function(b1) c(0, b1, 10, 20, 25, 40)
for (cs in TRAIN) { cd <- prepare(cs); p <- cd$pilot; pr <- a05_pair(p); Sc <- pr$Sc; Sk <- pr$Sk
  add <- setdiff(round(Sk, 10), round(Sc, 10)); rem <- setdiff(round(Sc, 10), round(Sk, 10))
  ie <- interval_errors(cs, Sc, cd$dens, cd$shut); iek <- interval_errors(cs, Sk, cd$dens, cd$shut)
  rg <- cut(ie$mid, brk(p$b1)); rgk <- cut(iek$mid, brk(p$b1))
  ac <- tapply(abs(ie$e), rg, sum); ak <- tapply(abs(iek$e), rgk, sum)
  addc <- tapply(nodecost(cd, add), cut(add, brk(p$b1)), sum); addc[is.na(addc)] <- 0
  cat(sprintf("%-13s c %.0f, check adds %d nodes (%.0f s), removes %d\n", cs, cost_of(cd, Sc), length(add), sum(nodecost(cd, add)) - sum(nodecost(cd, rem)), length(rem)))
  cat("  region      ", sprintf("%9s", levels(rg)), "\n  err share   ", sprintf("%9.2f", ac / sum(ac)), "\n  shrink      ", sprintf("%9.2f", ak / ac),
      "\n  added cost  ", sprintf("%9.0f", addc), "\n") }
