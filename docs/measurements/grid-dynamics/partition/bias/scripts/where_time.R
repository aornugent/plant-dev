# When a run's first nodes part from the tol 1e-7 reference: at the times both
# land on, nodes 1..6's mortality (absolute difference, so a relative change in
# survival), storage, height and offspring (relative), and the soil (relative).
#
#   Rscript where_time.R run_out.rds run_states.rds out_table.rds
args <- commandArgs(TRUE)
D <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/ark"
ref_t <- readRDS(file.path(D, "ck_u108_1e-7.rds"))$st$time
ref_s <- readRDS(file.path(D, "ck_u108_1e-7_states.rds"))
run_t <- readRDS(args[1])$st$time
run_s <- readRDS(args[2])
key <- function(x) round(x * 1e9)
common <- intersect(key(run_t), key(ref_t))
ir <- match(common, key(ref_t)); iu <- match(common, key(run_t))
rows <- list()
for (k in seq_along(common)) {
  a <- run_s[[iu[k]]]; b <- ref_s[[ir[k]]]
  if (length(a) != length(b)) next
  nn <- (length(a) - 10) %/% 9
  row <- c(t = run_t[iu[k]], M = nn)
  for (j in 1:6) {
    if (j > nn) { row <- c(row, setNames(rep(NA, 5), paste0("n", j, c("_mort", "_stor", "_h", "_off", "_mortref")))); next }
    i0 <- 9 * (j - 1)
    row <- c(row, setNames(c(a[i0 + 2] - b[i0 + 2], (a[i0 + 6] - b[i0 + 6]) / abs(b[i0 + 6]),
                             (a[i0 + 1] - b[i0 + 1]) / b[i0 + 1],
                             (a[i0 + 7] - b[i0 + 7]) / max(abs(b[i0 + 7]), 1e-300), b[i0 + 2]),
                           paste0("n", j, c("_mort", "_stor", "_h", "_off", "_mortref"))))
  }
  sl <- length(a) - 9:5
  row <- c(row, setNames((a[sl] - b[sl]) / b[sl], paste0("soil_", 1:5)))
  rows[[length(rows) + 1]] <- row
}
tab <- as.data.frame(do.call(rbind, rows))
saveRDS(tab, args[3])
cat(sprintf("%d common times\n", nrow(tab)))
grid <- c(0.5, 1, 2, 3, 4, 5, 6, 7, 7.5, 8, 8.5, 9, 9.5, 10, 10.5, 11, 12, 14, 16, 18, 19, 20, 21, 22, 23, 25, 28, 31, 32, 33, 34, 35, 37, 39.6)
pick <- unique(vapply(grid, function(g) which.min(abs(tab$t - g)), 1L))
options(width = 250)
print(signif(tab[pick, c("t", "n1_mort", "n2_mort", "n3_mort", "n4_mort", "n1_off", "n2_off", "n3_off",
                         "n1_stor", "n3_stor", "n1_h", "n3_h", "soil_1", "soil_3", "soil_5")], 3), row.names = FALSE)
