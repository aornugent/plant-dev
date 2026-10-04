# The scan (prereg.txt, third extension): node steps whose dense output shows a
# different number of sign changes, at u = k/32, than the detection cut.
#   R=... Rscript scan.R
R <- Sys.getenv("R")
STAGES <- c(0.2, 0.3, 0.6, 0.875)  # strictly inside the step
read_log <- function(r) {
  f <- file.path(R, sprintf("scan_%s.txt", r))
  x <- read.table(f, fill = TRUE, col.names = paste0("V", 1:11), colClasses = "character")
  num <- function(v) suppressWarnings(as.numeric(v))
  splits <- x[x$V1 == "split", ]
  splits <- data.frame(t0 = num(splits$V2), p = num(splits$V4), n = num(splits$V5),
                       u1 = num(splits$V6), u2 = num(splits$V7))
  s <- x[x$V1 == "scan", ]
  s <- data.frame(t0 = num(s$V2), h = num(s$V3), p = num(s$V4), cuts = num(s$V5),
                  changes = num(s$V6), u_first = num(s$V7), u_last = num(s$V8),
                  v0 = num(s$V9), v1 = num(s$V10), other = num(s$V11))
  # A missed pair spans from inside (u_first - 1/32, u_first] to inside
  # (u_last - 1/32, u_last]: a stage between u_first and u_last - 1/32 is surely
  # inside it, one in neither bracket is surely outside.
  inside <- function(a, b) sapply(seq_along(a), function(i) any(STAGES >= a[i] & STAGES <= b[i]))
  s$stage_inside <- ifelse(inside(s$u_first, s$u_last - 1 / 32), "yes",
                    ifelse(inside(s$u_first - 1 / 32, s$u_last), "edge", "no"))
  list(splits = splits, scan = s)
}
L <- setNames(lapply(c("0", "1e-3", "-1e-3"), read_log), c("0", "1e-3", "-1e-3"))

for (r in names(L)) {
  s <- L[[r]]$scan
  cat(sprintf("\n== r = %s: %d node steps split, %d whose scan disagrees\n", r,
              nrow(L[[r]]$splits), nrow(s)))
  if (nrow(s)) {
    print(table(cuts = s$cuts, changes = s$changes))
    m <- s[s$changes > s$cuts, ]
    cat(sprintf("missed pairs: %d; a stage surely inside %d, at a bracket's edge %d, none %d\n",
                nrow(m), sum(m$stage_inside == "yes"), sum(m$stage_inside == "edge"),
                sum(m$stage_inside == "no")))
    cat(sprintf("their widths in the step (between the brackets): median %.3f, max %.3f;",
                median(m$u_last - m$u_first + 1 / 32), max(m$u_last - m$u_first + 1 / 32)))
    cat(sprintf(" the far sign's deepest value: median %.2g, max %.2g\n",
                median(abs(m$other)), max(abs(m$other))))
    cat(sprintf("  step at day %8.2f, %.2f d long: node %3d, the pair inside u %.3f to %.3f, P %.3g at the start, %.3g at the end, %.3g on the far side\n",
                365 * s$t0, 365 * s$h, s$p + 1, s$u_first - 1 / 32, s$u_last, s$v0, s$v1, s$other), sep = "")
  }
}

# P8: the six pairs the logged diffs show split at one r and not the other, each
# looked for on the scan at the r where it was not split (node = p + 1).
pairs <- data.frame(
  node = c(7, 10, 24, 70, 74, 5, 5),
  t0 = c(4.8712, 19.5342, 14.8164, 34.3315, 27.6575, 17.1443, 17.1479),
  missing_at = c("0", "0", "1e-3", "0", "0", "1e-3", "1e-3"))
cat("\nP8: each pair on the scan where the detection did not split it\n")
for (i in seq_len(nrow(pairs))) {
  s <- L[[pairs$missing_at[i]]]$scan
  hit <- s[s$p == pairs$node[i] - 1 & abs(s$t0 - pairs$t0[i]) < 5e-5, ]
  cat(sprintf("  node %3d step at %.4f, r = %-5s: %s\n", pairs$node[i], pairs$t0[i], pairs$missing_at[i],
              if (nrow(hit)) sprintf("cuts %d, changes %d, between u %.3f and %.3f, stage inside: %s",
                                     hit$cuts[1], hit$changes[1], hit$u_first[1] - 1 / 32, hit$u_last[1],
                                     hit$stage_inside[1])
              else "not on the scan"))
}
s0 <- L[["0"]]$scan
cat(sprintf("\nP9: at r = 0, node steps with a pair the detection missed %d (bar >= 20); cut a pair the scan does not show %d (bar < 5)\n",
            sum(s0$changes > s0$cuts), sum(s0$cuts > s0$changes)))
