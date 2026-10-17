# mk_drop3.R CASE: omit-one map sets for the committed run val_insk_c_CASE. Every node but the
# first and last is dropped in one of two map runs (odd: nodes 2, 4, ...; even: 3, 5, ...), so
# no two drops in a run are adjacent and each column is that node's omit-one field part with
# its neighbours kept. Writes dwr/sched/{times,pin,coarse}_o1{a,b}_CASE and the node roles
# (role_CASE.rds): F / Ia / Ib / Ic / L / Cz / G interior drops of the every-other subset
# (mk_drop2's rule), and the edge nodes: Ci (inset before a closing edge after b1), Bi (before
# b1), Oi (after an opening edge in (b1, 25)).
suppressMessages(source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/p50/lib.R"))
DW <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/dwr"
cs <- commandArgs(TRUE)[1]; run <- paste0("val_insk_c_", cs)
S <- sort(readRDS(run_file(run))$node_times); n <- length(S)
et <- edge_table(cs); b1 <- PIL[[cs]]$b1; op <- sort(et$b[et$opening]); cl <- sort(et$b[!et$opening])
keep <- c(1L, n)
for (e in et$b) { lo <- which(S < e - 1e-9); hi <- which(S > e + 1e-9)
  if (length(lo)) keep <- c(keep, max(lo)); if (length(hi)) keep <- c(keep, min(hi)) }
keep <- sort(unique(keep))
eo <- unlist(lapply(seq_len(length(keep) - 1), function(r) { i0 <- keep[r]; i1 <- keep[r + 1]
  if (i1 - i0 >= 2) seq(i0 + 1, i1 - 1, by = 2) else integer(0) }))
bF <- max(S[S < b1 - 1e-9]); late0 <- min(S[S > max(op[op < 25]) + 1e-9])
lab_of <- function(b) { if (b < bF) return("F"); if (b > late0) return("L")
  nc <- cl[cl > b]; po <- op[op < b]; pc <- cl[cl < b]
  if (length(pc) && (!length(po) || max(pc) > max(po))) return("G")
  if (length(nc) && min(nc) - b <= 36 / 365) return("Cz")
  if (b < 10) "Ia" else if (b < 17) "Ib" else "Ic" }
role <- rep(NA_character_, n); role[eo] <- vapply(S[eo], lab_of, "")
for (c0 in cl) { j <- max(which(S < c0 - 1e-9)); if (j > 1 && j < n) role[j] <- if (abs(c0 - b1) < 1e-9) "Bi" else if (c0 < 25) "Ci" else role[j] }
for (o in op[op > b1 & op < 25]) { j <- min(which(S > o + 1e-9)); if (j < n) role[j] <- "Oi" }
for (k in c("a", "b")) { d <- if (k == "a") seq(2, n - 1, by = 2) else seq(3, n - 1, by = 2); tg <- paste0("o1", k)
  saveRDS(S[-d], file.path(DW, "sched", sprintf("coarse_%s_%s.rds", tg, cs))); saveRDS(S, file.path(DW, "sched", sprintf("times_%s_%s.rds", tg, cs)))
  cat(run_file(run), "\n", file = file.path(DW, "sched", sprintf("pin_%s_%s.txt", tg, cs))) }
saveRDS(list(case = cs, run = run, S = S, role = role, eo = eo), file.path(DW, "sched", sprintf("role_%s.rds", cs)))
cat(sprintf("%s: %d nodes; roles %s\n", cs, n, paste(sprintf("%s %d", names(table(role)), as.integer(table(role))), collapse = ", ")))
