# mk_drop2.R CASE RUN TAG: the virtual coarsening of an inset schedule (the saved run RUN's
# node times). Kept: the first and last node and the node nearest each edge on either side;
# within each run of nodes between kept ones, every other node is dropped. Each drop is
# labelled F (b < the inset node before b1), L (after the last opening edge's inset node),
# Cz (within 36 d before a closing edge), G (in a gap) or Ia/Ib/Ic (interior: b < 10, 10-17,
# 17-25). Writes dwr/sched/drop_TAG_CASE.rds and coarse_TAG_CASE.rds (the runner's COARSE)
# and coarse_TAG_REGION_CASE.rds with one region's drops alone (drop1).
suppressMessages(source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/p50/lib.R"))
DW <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/dwr"
a <- commandArgs(TRUE); cs <- a[1]; run <- a[2]; tag <- a[3]
S <- sort(readRDS(run_file(run))$node_times); n <- length(S)
et <- edge_table(cs); b1 <- PIL[[cs]]$b1
keep <- c(1L, n)
for (e in et$b) { lo <- which(S < e - 1e-9); hi <- which(S > e + 1e-9)
  if (length(lo)) keep <- c(keep, max(lo)); if (length(hi)) keep <- c(keep, min(hi)) }
keep <- sort(unique(keep))
drop <- unlist(lapply(seq_len(length(keep) - 1), function(r) { i0 <- keep[r]; i1 <- keep[r + 1]
  if (i1 - i0 >= 2) seq(i0 + 1, i1 - 1, by = 2) else integer(0) }))
stopifnot(all(diff(drop) >= 2), !any(drop %in% keep))
bF <- max(S[S < b1 - 1e-9]); op <- sort(et$b[et$opening]); cl <- sort(et$b[!et$opening])
late0 <- min(S[S > max(op[op < 25]) + 1e-9])
lab <- vapply(S[drop], function(b) {
  if (b < bF) return("F"); if (b > late0) return("L")
  nc <- cl[cl > b]; po <- op[op < b]; pc <- cl[cl < b]
  if (length(pc) && (!length(po) || max(pc) > max(po))) return("G")
  if (length(nc) && min(nc) - b <= 36 / 365) return("Cz")
  if (b < 10) "Ia" else if (b < 17) "Ib" else "Ic" }, "")
reg <- ifelse(lab %in% c("Ia", "Ib", "Ic"), "I", lab)
saveRDS(list(case = cs, run = run, S = S, drop = drop, region = reg, era = lab, coarse = S[-drop], keep = keep),
        file.path(DW, "sched", sprintf("drop_%s_%s.rds", tag, cs)))
saveRDS(S[-drop], file.path(DW, "sched", sprintf("coarse_%s_%s.rds", tag, cs)))
saveRDS(S, file.path(DW, "sched", sprintf("times_%s_%s.rds", tag, cs))); cat(run_file(run), "\n", file = file.path(DW, "sched", sprintf("pin_%s_%s.txt", tag, cs)))
for (g in unique(reg)) saveRDS(S[-drop[reg == g]], file.path(DW, "sched", sprintf("coarse_%s_%s_%s.rds", tag, g, cs)))
w <- diff(S) * 365
cat(sprintf("%s %s (%s): %d nodes, %d kept at edges/ends, %d dropped: %s | median interval %.0f d\n", cs, tag, run, n, length(keep), length(drop),
            paste(sprintf("%s %d", names(table(lab)), as.integer(table(lab))), collapse = ", "), median(w)))
