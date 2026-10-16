# mk_q4.R CASE: Q4's strip-only ladders. Zones: each closing edge c after b1 whose committed
# inset node sits 12 d inside and whose spell's last interval [p, c - 12 d] lies inside the
# spell; the zone is [p, c]. Everything outside the zones is the committed schedule.
#   edgN  : the edge c a node and [p, c] cut into N equal intervals (N = 2, 3, 5: the
#           coarse, committed and fine rungs of the proposed representation);
#   insx  : the inset rule at 1.6x: c - 19.2 d, end interval as is (it cannot widen past p);
#   insf  : the inset rule at 1/1.6: c - 7.5 d, [p, c - 7.5] cut at <= h_end / 1.6;
#   resZ  : the reference: the edge a node and [p, c] cut into 15 intervals (~5 d).
# The committed rung of the inset ladder is the committed run itself (val_insk_c).
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/closing/lib.R")
zones <- function(cs, S) { et <- edge_table(cs); b1 <- PIL[[cs]]$b1; op <- et$b[et$opening]; ce <- et[!et$opening & et$b > b1, ]
  do.call(rbind, lapply(ce$b, function(c0) { j <- max(which(S < c0)); a <- max(c(b1, op[op < c0])); if (j < 2) return(NULL)
    if (abs((c0 - S[j]) * 365 - 12) > 0.01 || S[j - 1] <= a + 1e-9) return(NULL); data.frame(c = c0, p = S[j - 1], j = j) })) }
variant <- function(S, Z, kind) { keep <- rep(TRUE, length(S)); keep[Z$j] <- FALSE; add <- c()
  for (i in seq_len(nrow(Z))) { p <- Z$p[i]; c0 <- Z$c[i]; L <- (c0 - p) * 365; he <- L - 12
    add <- c(add, switch(kind,
      edg2 = p + (1:2) * (c0 - p) / 2, edg3 = p + (1:3) * (c0 - p) / 3, edg5 = p + (1:5) * (c0 - p) / 5, resZ = p + (1:15) * (c0 - p) / 15,
      insx = c0 - 19.2 / 365,
      insf = { d <- 7.5; m <- ceiling((L - d) / (he / 1.6) - 1e-9); p + (1:m) * (L - d) / m / 365 })) }
  sort(c(S[keep], add)) }
if (sys.nframe() == 0) for (cs in commandArgs(TRUE)) { S <- sort(rd(sprintf("val_insk_c_%s", cs))$node_times); Z <- zones(cs, S)
  cat(sprintf("%s: %d zones, Z median %.0f d [%.0f, %.0f]; committed %d nodes |", cs, nrow(Z), median((Z$c - Z$p) * 365), min((Z$c - Z$p) * 365), max((Z$c - Z$p) * 365), length(S)))
  for (k in c("insx", "insf", "edg2", "edg3", "edg5", "resZ")) { V <- variant(S, Z, k); stopifnot(all(diff(V) > 0.5 / 365)); saveRDS(as.numeric(V), file.path(CL, "sched", sprintf("%s_%s.rds", k, cs))); cat(sprintf(" %s %d", k, length(V))) }
  cat("\n") }
