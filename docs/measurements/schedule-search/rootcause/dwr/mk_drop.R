# mk_drop.R CASE: the virtual coarsening of res, region by region. Every other node of the
# founders' window, of each spell's interior run, and of late; and res2x's dropped closing
# offsets. Writes dwr/sched/dropA_CASE.rds (dropped node indices from one, their region and
# era, the coarse schedule) and the coarse schedule alone for the runner's COARSE.
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/p50/mk_reg.R")
DW <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/dwr"
dir.create(file.path(DW, "sched"), showWarnings = FALSE)
cs <- commandArgs(TRUE)[1]
R <- regions(cs); S <- R$S; n <- length(S)
idx <- function(x) match(round(x, 8), round(S, 8))
every_other <- function(i0, i1) if (i1 - i0 >= 2) seq(i0 + 1, i1 - 1, by = 2) else integer(0)
# Runs of consecutive intervals carrying one of the labels, as node index ranges.
runs_of <- function(labs) { k <- which(R$lab %in% labs); if (!length(k)) return(list())
  br <- c(0, which(diff(k) > 1), length(k)); lapply(seq_len(length(br) - 1), function(r) { kk <- k[(br[r] + 1):br[r + 1]]; c(idx(R$lo[min(kk)]), idx(R$hi[max(kk)])) }) }
drop <- integer(0); reg <- character(0)
add <- function(d, g) { drop <<- c(drop, d); reg <<- c(reg, rep(g, length(d))) }
for (r in runs_of("F")) add(every_other(r[1], r[2]), "F")
for (r in runs_of(c("Ia", "Ib", "Ic"))) add(every_other(r[1], r[2]), "I")
for (r in runs_of("L")) add(every_other(r[1], r[2]), "L")
r2 <- file.path(CL, "sched", sprintf("res2x_%s.rds", cs))
if (file.exists(r2)) { X <- sort(readRDS(r2)); gone <- which(!(round(S, 8) %in% round(X, 8)))
  stopifnot(all(round(X, 8) %in% round(S, 8))); add(setdiff(gone, drop), "C") }
o <- order(drop); drop <- drop[o]; reg <- reg[o]
stopifnot(!anyDuplicated(drop), all(drop > 1), all(drop < n), all(diff(drop) >= 2))
b <- S[drop]; era <- ifelse(reg != "I", reg, ifelse(b < 10, "Ia", ifelse(b < 17, "Ib", "Ic")))
coarse <- S[-drop]
saveRDS(list(case = cs, S = S, drop = drop, region = reg, era = era, coarse = coarse), file.path(DW, "sched", sprintf("dropA_%s.rds", cs)))
saveRDS(coarse, file.path(DW, "sched", sprintf("coarseA_%s.rds", cs)))
saveRDS(S[-drop[reg == "I"]], file.path(DW, "sched", sprintf("coarseI_%s.rds", cs)))  # the interiors alone, for drop1
cat(sprintf("%s: res %d nodes; dropped %d: %s\n", cs, n, length(drop), paste(sprintf("%s %d", names(table(era)), as.integer(table(era))), collapse = ", ")))
w <- R$hi - R$lo; cat(sprintf("intervals: %s\n", paste(sprintf("%s %d (median %.0f d)", names(table(R$lab)), as.integer(table(R$lab)), tapply(w, R$lab, median) * 365), collapse = ", ")))
