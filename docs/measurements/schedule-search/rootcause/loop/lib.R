# lib.R: the loop round's cases, layout E6+, runner and scoring data.
# E6+ at scale s: a09's graded build at s x h (the builder's range cap scaled by s too), late
# edges (b > 25) left out, E6's 12-d inset on every edge before 25 (never scaled), plus a node
# at each edge before b = 10: every closing edge, and every opening edge whose gap before and
# spell after are both at least 2 d (U's rule). edges = FALSE, s = 1 is E6's committed schedule.
Sys.setenv(BG = 90, R = 1.6)
suppressMessages(source("/home/user/plant-dev/docs/measurements/schedule-search/round4/P/lib.R"))
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/heldout/cases.R")
SP <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad"
LO <- file.path(SP, "deep/rootcause/loop")
BANK <- c("episodic", "dry", "long-wet", "long-drought", "episodic-lma", "dry-flat", "ld-102", "ld-105", "dry-p50", "wet-adG2")
HELD <- names(HO)
late_out <- function(S, p) { late <- round(p$edges[p$edges > 25], 10); S[!(round(S, 10) %in% late)] }
ep_sched <- function(cs, s = 1, edges = TRUE, tcut = 10) {
  p <- pilot_of(cs); h <- alg$hfun_of(p); cap0 <- cap_of
  cap_of <<- function(p, lo, hi) s * cap0(p, lo, hi); on.exit(cap_of <<- cap0)
  S <- as.numeric(inset_rule(late_out(build_graded(p, function(b) s * h(b)), p), cs, d = 12))
  if (!edges) return(S)
  et <- edge_table(cs); et <- et[et$b < tcut, ]
  add <- et$b[!et$opening | (et$gap >= 2 & et$spell >= 2)]
  add <- add[vapply(add, function(x) all(abs(S - x) > 1e-9), TRUE)]
  S <- sort(c(S, add)); stopifnot(all(diff(S) > 1e-6)); S }
# Each case's record, seed, trait move and weight file (the runners' spec).
SPEC <- c(list(
  episodic = list(rec = "episodic", seed = "", trait = "", weight = "episodic"),
  dry = list(rec = "dry", seed = "", trait = "", weight = "dry"),
  `long-wet` = list(rec = "long-wet", seed = "", trait = "", weight = "long-wet"),
  `long-drought` = list(rec = "long-drought", seed = "", trait = "", weight = "long-drought"),
  `episodic-lma` = list(rec = "episodic", seed = "", trait = "lma=0.25", weight = "episodic"),
  `dry-flat` = list(rec = "dry-flat", seed = "", trait = "", weight = "dry"),
  `ld-102` = list(rec = "long-drought", seed = "102", trait = "", weight = "long-drought"),
  `ld-105` = list(rec = "long-drought", seed = "105", trait = "", weight = "long-drought"),
  `dry-p50` = list(rec = "dry", seed = "", trait = "root_P50=0.2", weight = "dry"),
  `wet-adG2` = list(rec = "long-wet", seed = "", trait = "a_dG2=0.25", weight = "long-wet")), HO)
# References and E6 as built: the bank from the proxies round's ladder file, the held-out
# cases from the held-out round's scores (flat-al1125 on its three-rung reference).
LAD <- readRDS(file.path(SP, "deep/rootcause/proxies/lad.rds"))
Q <- LAD$Q; EPS <- LAD$EPS[Q]; M <- LAD$M_unit[Q]
HOS <- readRDS(file.path(SP, "deep/rootcause/heldout/score857.rds"))
ref_of <- function(cs) if (cs %in% BANK) LAD$L[[cs]]$ref[Q] else HOS$keep[[cs]]$ref[Q]
qv <- function(x) { q <- quantities(x); if (!all(Q %in% names(q))) return(NULL); q[Q] }
e6_of <- function(cs) {
  if (cs %in% BANK) { r <- LAD$L[[cs]]$runs; return(list(qc = r$c$q[Q], qf = r$f$q[Q], rc = r$c$rows, rf = r$f$rows, s = r$f$proxy / r$c$proxy, Sc = r$c$S)) }
  xc <- HO_RUN(paste0("e6_c_", cs)); xf <- HO_RUN(paste0("e6_f_", cs))
  list(qc = qv(xc), qf = qv(xf), rc = xc$stand$rows, rf = xf$stand$rows, s = HOS$keep[[cs]]$s, Sc = xc$node_times) }
cost <- function(rows) run_cost(rows, TRUE)
# The node-drop map's virtual coarsening (the dwr round's mk_drop2 rule): keep the first and
# last node, every edge node and the node nearest each edge on either side; drop every other
# node between kept ones. Regions: F before the inset node ahead of b1, L after the first
# node past the last opening edge before 25, Cz within 36 d before a closing edge, G in a
# gap, I otherwise.
drop_set <- function(cs, S) { p <- pilot_of(cs); et <- edge_table(cs); n <- length(S)
  keep <- c(1L, n, which(vapply(S, function(x) any(abs(et$b - x) < 1e-9), TRUE)))
  for (e in et$b) { lo <- which(S < e - 1e-9); hi <- which(S > e + 1e-9)
    if (length(lo)) keep <- c(keep, max(lo)); if (length(hi)) keep <- c(keep, min(hi)) }
  keep <- sort(unique(keep))
  drop <- unlist(lapply(seq_len(length(keep) - 1), function(r) { i0 <- keep[r]; i1 <- keep[r + 1]
    if (i1 - i0 >= 2) seq(i0 + 1, i1 - 1, by = 2) else integer(0) }))
  bF <- max(S[S < p$b1 - 1e-9]); op <- sort(et$b[et$opening]); cl <- sort(et$b[!et$opening])
  late0 <- min(S[S > max(op[op < 25]) + 1e-9])
  reg <- vapply(S[drop], function(b) { if (b < bF) return("F"); if (b > late0) return("L")
    nc <- cl[cl > b]; po <- op[op < b]; pc <- cl[cl < b]
    if (length(pc) && (!length(po) || max(pc) > max(po))) return("G")
    if (length(nc) && min(nc) - b <= 36 / 365) return("Cz"); "I" }, "")
  list(drop = drop, region = reg, coarse = S[-drop]) }
# ln J's own error from one map run, by region and in total (eps of ln J): e = D/3, D the
# virtual move = own part (the coarse hats over the run's own fates) + field part (the drop
# columns / J).
hatw <- function(bc, bf, wf) { W <- numeric(length(bc)); j <- findInterval(bf, bc, rightmost.closed = TRUE); j[j < 1] <- 1; j[j >= length(bc)] <- length(bc) - 1
  t <- pmin(pmax((bf - bc[j]) / (bc[j + 1] - bc[j]), 0), 1)
  for (f in seq_along(bf)) { W[j[f]] <- W[j[f]] + wf[f] * (1 - t[f]); W[j[f] + 1] <- W[j[f] + 1] + wf[f] * t[f] }; W }
map_lnJ <- function(x, reg) { if (is.null(x$light)) return(NULL); n <- x$stand$nodes; m <- length(n$birth); b <- n$birth; w <- n$establishment[1:m]; g <- n$nrr
  J <- x$stand$J; u <- EPS[["lnJ"]]; dr <- x$dropped
  own <- function(k) { bc <- b[-dr[k]]; kc <- match(round(bc, 8), round(b, 8)); log(sum(hatw(b[kc], b, w) * g[kc])) - log(sum(w * g)) }
  fld <- (colSums(x$light) + colSums(x$soil)) / J
  gs <- c(sort(unique(reg)), "all")
  vapply(gs, function(r) { k <- if (r == "all") rep(TRUE, length(dr)) else reg == r; (own(k) + sum(fld[k])) / u / 3 }, 0) }
# A run's schedule and its map's coarser schedule, as the runner reads them.
prep <- function(cs, S, name) { d <- drop_set(cs, S); saveRDS(S, file.path(LO, "sched", paste0(name, ".rds")))
  saveRDS(d$coarse, file.path(LO, "sched", paste0(name, "_coarse.rds"))); invisible(d) }
