# The founders' window split at the pilot's layer end: a05's committed error share and the
# check's added cost in the layer, the quiet middle, and after b1; also after 25.
source("/home/user/plant-dev/docs/measurements/schedule-search/round3/C/lib.R")
nodecost <- function(cd, S) { co <- coef(cd$rowsfit); run_cost(co[["n"]] + co[["life"]] * (H - S), TRUE) }
for (cs in TRAIN) { cd <- prepare(cs); p <- cd$pilot; pr <- a05_pair(p); Sc <- pr$Sc; Sk <- pr$Sk; l1 <- A05$layer_end(p)
  brk <- c(0, l1, p$b1 - 0.25, p$b1, 25, 40)
  add <- setdiff(round(Sk, 10), round(Sc, 10)); rem <- setdiff(round(Sc, 10), round(Sk, 10))
  ie <- interval_errors(cs, Sc, cd$dens, cd$shut); rg <- cut(ie$mid, brk); ac <- tapply(abs(ie$e), rg, sum); ac[is.na(ac)] <- 0
  net <- tapply(c(nodecost(cd, add), -nodecost(cd, rem)), cut(c(add, rem), brk), sum); net[is.na(net)] <- 0
  cat(sprintf("%-13s layer end %.2f b1 %.2f | regions %s\n   err share %s\n   check's net added cost %s (of %.0f)\n", cs, l1, p$b1, paste(levels(rg), collapse = " "),
    paste(sprintf("%.3f", ac / sum(ac)), collapse = " "), paste(sprintf("%.0f", net), collapse = " "), sum(net))) }
