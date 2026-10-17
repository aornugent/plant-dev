# mk_reg.R CASE [k]: region refinements on top of the closing round's res schedule.
# Regions (boundaries at res's own nodes, so the regions are disjoint and should add):
#   O  opening side (Os the strip, Ofirst the first interval): for each opening edge o in (b1, 25) whose spell res did not resolve
#      whole, the strip [o, o + 12 d] (nodes o, o + {12/k ...}: the strip cut into k) and the
#      spell's first interval [o + 12 d, x2] cut into k.
#   I  spell interiors: every res interval from x2 to the closing region (c - 36 d) cut into k;
#      I_a / I_b / I_c restrict to interval midpoints in (b1, 10), [10, 17), [17, 25).
#   L  late: every interval with lo >= the last opening edge's inset node (no closing edge
#      before 25 after it), cut into k.
#   B  the b1 closing edge resolved as res resolves the others (res's offsets and probes).
#   F  the founders' intervals (hi <= the inset node beside b1) cut into k.
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/p50/lib.R")
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/closing/mk_q1.R", local = TRUE)
cut_k <- function(lo, hi, k) if (k <= 1) numeric(0) else lo + (hi - lo) * seq_len(k - 1) / k
regions <- function(cs) { S <- sort(readRDS(file.path(CL, "sched", sprintf("res_%s.rds", cs)))); et <- edge_table(cs); b1 <- PIL[[cs]]$b1
  op <- et$b[et$opening & et$b > b1]; cl <- et$b[!et$opening]; lo <- head(S, -1); hi <- S[-1]; n <- length(lo)
  lab <- rep("C", n)  # default: inside res's resolved closing regions, gaps and probes
  bF <- max(S[S < b1 - 1e-9]); lab[hi <= bF + 1e-9] <- "F"
  lastO <- max(op); late0 <- lastO + 12 / 365
  for (o in op) { c1 <- min(cl[cl > o]); ins <- o + 12 / 365; j <- which(abs(lo - ins) < 1e-6)
    if (!length(j)) next  # spell resolved whole by res (node at o, no inset node)
    lab[which(hi > o + 1e-9 & lo < o + 1e-9)] <- "Os"  # the gap interval that holds the strip [o, o + 12 d]
    if (o >= lastO - 1e-9) next
    x2 <- hi[j]; lab[j] <- "O1"; zc <- c1 - 36 / 365
    k <- which(lo >= x2 - 1e-9 & hi <= zc + 1e-9 & lab == "C"); m <- (lo[k] + hi[k]) / 2
    lab[k] <- ifelse(m < 10, "Ia", ifelse(m < 17, "Ib", "Ic")) }
  lab[lo >= late0 - 1e-9] <- "L"
  list(S = S, lo = lo, hi = hi, lab = lab, b1 = b1, op = op) }
refine <- function(cs, region, k) { R <- regions(cs); S <- R$S; add <- c()
  if (region == "B") { et <- edge_table(cs); b1 <- R$b1; c0 <- sort(rd5(sprintf("val_insk_c_%s", cs))$node_times)
    gap <- et$gap[abs(et$b - b1) < 1e-9 & !et$opening]; nn <- b1 - OFF$res / 365; gp <- c(2, if (gap > 25) c(5, 10)); gp <- gp[gp < gap - 3]
    S <- S[!(S > b1 - 36 / 365 + 1e-9 & S <= b1 + 1e-9)]; return(sort(unique(round(c(S, nn, b1 + gp / 365), 10)))) }
  want <- switch(region, O = c("Os", "O1"), I = c("Ia", "Ib", "Ic"), Ofirst = "O1", region)
  for (i in which(R$lab %in% want)) {
    if (R$lab[i] == "Os") { o <- R$op[R$op > R$lo[i] & R$op < R$hi[i]]; add <- c(add, o, cut_k(o, R$hi[i], k)) }
    else add <- c(add, cut_k(R$lo[i], R$hi[i], k)) }
  out <- sort(unique(round(c(S, add), 10))); out[c(TRUE, diff(out) > 0.5 / 365)] }
if (sys.nframe() == 0) { a <- commandArgs(TRUE); cs <- a[1]; R <- regions(cs)
  w <- R$hi - R$lo; cat(sprintf("%s: res n %d | intervals by region: %s\n", cs, length(R$S), paste(sprintf("%s %d (median %.0f d)", names(table(R$lab)), as.integer(table(R$lab)), tapply(w, R$lab, median) * 365), collapse = ", ")))
  for (sp in a[-1]) { rg <- sub("[0-9]+$", "", sp); k <- as.integer(sub("^[A-Za-z_]+", "", sp)); if (is.na(k)) k <- 1
    X <- refine(cs, rg, k); saveRDS(as.numeric(X), file.path(P5, "sched", sprintf("%s_%s.rds", sp, cs))); cat(sprintf("  %-4s n %d (+%d)\n", sp, length(X), length(X) - length(R$S))) } }
