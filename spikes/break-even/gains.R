# d ln R' / d ln P from the +-eps pairs in every scan_*.rds, with ln R' at
# eps = 0 and, per invader, the first cohort's share of R'.
#   Rscript gains.R > results/gains.txt
D <- "/home/a/.claude/jobs/9d586e52/tmp/breakeven"
out <- list()
for (f in list.files(D, "^scan_.*\\.rds$")) {
  if (grepl("smoke", f)) next
  r <- readRDS(file.path(D, f))
  if (length(r$row) == 1) r$row <- rep(r$row, length(r$eps))
  for (rw in unique(r$row)) {
    i <- which(r$row == rw)
    e <- r$eps[i]
    i0 <- i[e == 0][1]
    c0 <- r$cohorts[[i0]]
    s <- c0$w * c0$pd * c0$R_c
    for (h in sort(unique(abs(e[e != 0])))) {
      ip <- i[e == h][1]; im <- i[e == -h][1]
      if (is.na(ip) || is.na(im)) next
      out[[length(out) + 1]] <- data.frame(
        scan = sub("^scan_(.*)\\.rds$", "\\1", f), case = r$case, row = rw,
        every = r$every, tol = r$tol,
        gate = if (nzchar(r$gate)) r$gate else "0.1",
        storage_eps = if (nzchar(r$storage_eps)) r$storage_eps else "1e-4",
        F = r$F, lnR = r$lnR[i0], eps = h,
        gain = (r$lnR[ip] - r$lnR[im]) / (2 * h),
        asym = (r$lnR[ip] - r$lnR[i0]) / (r$lnR[i0] - r$lnR[im]),
        first_share = s[1] / sum(s))
    }
  }
}
g <- do.call(rbind, out)
options(width = 200)
print(g, digits = 4, row.names = FALSE)
write.csv(g, "/home/a/dev/plant-dev/.claude/worktrees/agent-a3c3295eb8ad97b06/spikes/break-even/results/gains.csv", row.names = FALSE)
