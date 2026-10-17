# mk_regions.R CASE RUN: dwr/mk_drop2.R's every-other drop set on the run RUN's node times,
# labelled by region (F, Ia, Ib, Ic, L; Cz and G where they occur). Writes single/sched/:
# drop_CASE.rds (S, drop, region), times_CASE.rds, pin_CASE.txt, and coarse_G_CASE.rds per
# region G and for I = Ia + Ib + Ic (R0's schedules).
suppressMessages(source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/p50/lib.R"))
SO <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/single"
a <- commandArgs(TRUE); cs <- a[1]; run <- a[2]
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
saveRDS(list(case = cs, run = run, S = S, drop = drop, region = lab, keep = keep), file.path(SO, "sched", sprintf("drop_%s.rds", cs)))
saveRDS(S, file.path(SO, "sched", sprintf("times_%s.rds", cs)))
cat(run_file(run), "\n", file = file.path(SO, "sched", sprintf("pin_%s.txt", cs)))
for (g in c(unique(lab), "I")) { k <- if (g == "I") lab %in% c("Ia", "Ib", "Ic") else lab == g
  if (any(k)) saveRDS(S[-drop[k]], file.path(SO, "sched", sprintf("coarse_%s_%s.rds", g, cs))) }
cat(sprintf("%s (%s): %d nodes, %d kept, %d dropped: %s | median interval %.0f d\n", cs, run, n, length(keep), length(drop),
            paste(sprintf("%s %d", names(table(lab)), as.integer(table(lab))), collapse = ", "), median(diff(S) * 365)))
