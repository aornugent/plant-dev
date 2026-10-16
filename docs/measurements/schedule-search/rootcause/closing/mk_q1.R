# mk_q1.R: Q1's schedules from each case's committed inset schedule (insk c = P's insc).
#   bisC  : every interval that ends at a spell's last node before a closing edge (after b1,
#           before 25) and lies inside that spell, bisected.
#   res   : every closing-edge region resolved: the last 36 d of each spell (the whole spell
#           when shorter) re-noded at c - {36,28,21,15.5,11,7.5,4.5,2,0} d (clipped to the
#           spell), plus c + 2 d, and c + 5, c + 10 d where the gap is longer than 25 d
#           (zero-weight probes of the gap side's fate).
#   res2x : as res with every other offset, c - {36,21,11,4.5,0} d, plus c + 2 d.
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/closing/lib.R")
OFF <- list(res = c(36, 28, 21, 15.5, 11, 7.5, 4.5, 2, 0), res2x = c(36, 21, 11, 4.5, 0))
closing_regions <- function(cs) { et <- edge_table(cs); b1 <- PIL[[cs]]$b1
  ce <- et[!et$opening & et$b > b1, ]; op <- et$b[et$opening]
  ce$a <- vapply(ce$b, function(c0) { o <- op[op < c0]; if (length(o)) max(o) else b1 }, 0); ce }
resolve <- function(S, cs, off, probes = TRUE) { ce <- closing_regions(cs); S <- sort(S); add <- c(); drop <- rep(FALSE, length(S))
  for (i in seq_len(nrow(ce))) { c0 <- ce$b[i]; a <- ce$a[i]; lo <- max(a, c0 - max(off) / 365)
    drop <- drop | (S > lo - 1e-9 & S <= c0 + 1e-9)
    nn <- c0 - off / 365; nn <- nn[nn >= lo - 1e-9]; if (a > c0 - max(off) / 365) nn <- c(nn, a)
    gp <- c(2, if (probes && ce$gap[i] > 25) c(5, 10)); gp <- gp[gp < ce$gap[i] - 3]
    add <- c(add, nn, c0 + gp / 365) }
  out <- sort(unique(round(c(S[!drop], add), 10))); out[c(TRUE, diff(out) > 0.5 / 365)] }
bisC <- function(S, cs) { ce <- closing_regions(cs); S <- sort(S); add <- c()
  for (i in seq_len(nrow(ce))) { j <- max(which(S < ce$b[i])); if (j > 1 && S[j - 1] > ce$a[i] + 1e-9) add <- c(add, (S[j - 1] + S[j]) / 2) }
  sort(c(S, add)) }
if (sys.nframe() == 0) for (cs in c("dry", "dry-p50", "dry-flat", "long-wet")) { S <- rd(sprintf("val_insk_c_%s", cs))$node_times
  B <- bisC(S, cs); Rr <- resolve(S, cs, OFF$res); R2 <- resolve(S, cs, OFF$res2x, probes = FALSE)
  for (k in c("bisC", "res", "res2x")) saveRDS(as.numeric(switch(k, bisC = B, res = Rr, res2x = R2)), file.path(CL, "sched", sprintf("%s_%s.rds", k, cs)))
  cat(sprintf("%-9s committed %d | bisC %d (+%d) | res %d | res2x %d | closing edges after b1 %d\n", cs, length(S), length(B), length(B) - length(S), length(Rr), length(R2), nrow(closing_regions(cs)))) }
