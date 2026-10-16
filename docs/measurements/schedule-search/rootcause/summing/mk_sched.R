# mk_sched.R: the layouts. L = the committed schedule (insc, 12-d inset) with its founders'
# nodes in [0, bF] (bF the inset node beside b1) replaced by 12 equal intervals; H2 = every
# interval of L halved, H4 = every interval of H2 halved, C2 = every other node of L (the
# last kept). In L no node sits inside a gap: each gap interval runs from the closing
# spell's inset node (c - 12 d) to the next spell's (a + 12 d) and holds both edge strips.
# L's pairs (from node 0) get a region: F founders (both intervals before bF); K a gap
# interval paired with the closing spell's last interval (pair [., c - 12 d, a + 12 d]);
# P a gap interval paired with the opening spell's first interval (pair [c - 12 d,
# a + 12 d, .]); I the other pairs before 25; Z the rest (late, and the odd trailing
# interval). Windows (PLANT_SIMPSON values): founders = 0:bF; one region = its pairs' spans;
# nogap = F, I and Z. L_R = L with region R's pairs' intervals halved.
suppressMessages(source("/home/user/plant-dev/docs/measurements/schedule-search/round4/P/lib.R"))
SU <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/summing"
FO <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/founders"
CS <- c("dry", "episodic-lma", "long-wet", "dry-flat", "dry-p50")
halve <- function(S) sort(c(S, (head(S, -1) + S[-1]) / 2))
gap_intervals <- function(S, cs) { et <- edge_table(cs); lo <- head(S, -1); hi <- S[-1]
  vapply(seq_along(lo), function(i) any(et$b > lo[i] + 1e-9 & et$b < hi[i] - 1e-9), TRUE) }
# Region per interval of S from its pair's region; pairs from node 0, j = 1, 3, ...
pair_regions <- function(S, cs, bF) { n <- length(S); g <- gap_intervals(S, cs); reg <- rep("Z", n - 1); pr <- NULL
  for (i in seq(1, n - 2, by = 2)) { r <- if (S[i + 2] <= bF + 1e-9) "F" else if (g[i + 1]) "K" else if (g[i]) "P" else if (S[i + 2] <= 25 + 1e-9) "I" else "Z"
    reg[i:(i + 1)] <- r; pr <- rbind(pr, data.frame(b0 = S[i], b1 = S[i + 1], b2 = S[i + 2], region = r)) }
  list(reg = reg, pairs = pr, gap = g) }
win <- function(pr) paste(sprintf("%.10f:%.10f", pr$b0, pr$b2), collapse = ",")
rules <- list(); info <- list()
for (cs in CS) { S <- readRDS(file.path(POUT, "sched", sprintf("insc_%s.rds", cs))); b1 <- pilot_edges(cs)$b1
  saveRDS(S, file.path(SU, "sched", sprintf("insc_%s.rds", cs)))
  bF <- max(S[S <= b1 + 1e-9]); rest <- S[S > bF + 1e-9]
  L <- c(seq(0, bF, length.out = 13), rest); stopifnot(all(diff(L) > 1e-7))
  f12 <- file.path(FO, "sched", sprintf("ladT12_%s.rds", cs)); if (file.exists(f12)) stopifnot(identical(readRDS(f12), L))
  H2 <- halve(L); H4 <- halve(H2); C2 <- L[seq(1, length(L), by = 2)]; if (tail(C2, 1) != tail(L, 1)) C2 <- c(C2, tail(L, 1))
  for (nm in c("L", "H2", "H4", "C2")) saveRDS(get(nm), file.path(SU, "sched", sprintf("%s_%s.rds", nm, cs)))
  PR <- pair_regions(L, cs, bF); reg <- PR$reg; prL <- PR$pairs
  for (R in c("F", "K", "P", "I")) { m <- reg == R; saveRDS(sort(c(L, (head(L, -1)[m] + L[-1][m]) / 2)), file.path(SU, "sched", sprintf("L%s_%s.rds", R, cs))) }
  rules[[cs]] <- c(founders = sprintf("0:%.10f", bF), sapply(c("F", "K", "P", "I", "Z"), function(R) { x <- prL[prL$region == R, ]; if (nrow(x)) win(x) else "none:0" }),
    nogap = win(prL[prL$region %in% c("F", "I", "Z"), ]))
  stopifnot(all(prL$b0[prL$region == "F"] >= 0), max(prL$b2[prL$region == "F"]) <= bF + 1e-9, sum(prL$region == "F") == 6)
  info[[cs]] <- list(b1 = b1, bF = bF, L = L, reg = reg, pairs = prL, gap = PR$gap)
  h <- diff(L) * 365; hr <- prL$b2 - prL$b1; hl <- prL$b1 - prL$b0
  cat(sprintf("%-12s b1 %.3f bF %.3f | nodes L %d H2 %d H4 %d C2 %d (insc %d) | gap intervals %d | pairs F %d K %d P %d I %d Z %d (trailing interval: %s)\n",
    cs, b1, bF, length(L), length(H2), length(H4), length(C2), length(S), sum(PR$gap),
    sum(prL$region == "F"), sum(prL$region == "K"), sum(prL$region == "P"), sum(prL$region == "I"), sum(prL$region == "Z"), if (length(L) %% 2 == 0) "yes" else "no"))
  for (R in c("K", "P", "I")) { m <- prL$region == R; rr <- hr[m] / hl[m]
    cat(sprintf("   %s pairs: widths (d) median %.0f + %.0f; width ratio h2/h1 median %.2f, outside [1/2, 2] in %d of %d\n", R, median(hl[m]) * 365, median(hr[m]) * 365, median(rr), sum(rr > 2 | rr < 0.5), sum(m))) }
}
saveRDS(list(rules = rules, info = info), file.path(SU, "sched", "layout.rds"))
# Rule files: "case window" lines for run.sh's RULE given per case.
for (r in c("founders", "F", "K", "P", "I", "Z", "nogap")) writeLines(sprintf("%s %s", CS, vapply(CS, function(cs) rules[[cs]][[r]], "")), file.path(SU, "sched", sprintf("rule_%s.txt", r)))
