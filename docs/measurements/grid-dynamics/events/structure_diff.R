# How the split's structure changes between lma and lma (1 +- r) on the 1e-4
# grid: the (row, member) pairs split at one and not the other, classed as a
# crossing that moved to the next or previous step, or a dip whose two crossings
# appear or vanish together; and what that costs J, as the re-detected split's J
# less the frozen structure's at the same lma.
#   Rscript structure_diff.R [r ...]
E <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/events"
R <- file.path(E, "runs")
rs <- commandArgs(TRUE); if (!length(rs)) rs <- c("1e-4", "-1e-4", "1e-3", "-1e-3", "1e-5", "-1e-5")
J_of <- function(tag) {
  l <- readLines(file.path(R, paste0(tag, ".log")), warn = FALSE)
  as.numeric(sub("^J to every digit ", "", grep("^J to every digit", l, value = TRUE)))
}
base <- readRDS(file.path(R, "sl_1e-4.rds"))
key <- function(d) paste(d$row, d$member)
for (r in rs) {
  f <- file.path(R, sprintf("sl_lma_%s.rds", r))
  if (!file.exists(f)) next
  x <- readRDS(f)
  gone <- base[!key(base) %in% key(x), ]; new <- x[!key(x) %in% key(base), ]
  # a crossing that moved by one step: the same member and direction in the
  # neighbouring row
  moved <- 0; dips <- 0; other <- 0
  used <- logical(nrow(new))
  for (i in seq_len(nrow(gone))) {
    k <- which(!used & new$member == gone$member[i] & abs(new$row - gone$row[i]) == 1 & new$down == gone$down[i])
    if (length(k)) { used[k[1]] <- TRUE; moved <- moved + 1 }
  }
  pair_of <- function(d) {
    # a down and an up crossing of one member in the same or neighbouring rows
    n <- 0
    for (m in unique(d$member)) {
      dm <- d[d$member == m, ]
      if (nrow(dm) >= 2 && any(dm$down == 1) && any(dm$down == 0) && diff(range(dm$row)) <= 1) n <- n + 1
    }
    n
  }
  unmatched_gone <- gone[!sapply(seq_len(nrow(gone)), function(i) any(new$member == gone$member[i] & abs(new$row - gone$row[i]) == 1 & new$down == gone$down[i])), ]
  unmatched_new <- new[!used, ]
  cat(sprintf("r %s: base %d splits, here %d; %d gone, %d new; %d moved one step; unmatched %d gone, %d new (dips among them: %d gone, %d new)\n",
              r, nrow(base), nrow(x), nrow(gone), nrow(new), moved, nrow(unmatched_gone), nrow(unmatched_new),
              pair_of(unmatched_gone), pair_of(unmatched_new)))
  if (nrow(unmatched_gone)) print(unmatched_gone[, c("row", "member", "down", "uc", "P0", "P1", "h")], row.names = FALSE)
  if (nrow(unmatched_new)) print(unmatched_new[, c("row", "member", "down", "uc", "P0", "P1", "h")], row.names = FALSE)
  sp <- tryCatch(J_of(sprintf("sp_lma_%s", r)), error = function(e) NA)
  fp <- tryCatch(J_of(sprintf("fp_lma_%s", r)), error = function(e) NA)
  cat(sprintf("  J re-detected %.15g, frozen %.15g: the structure's change moves J by %.3g (%.3g relative)\n",
              sp, fp, sp - fp, sp / fp - 1))
}
