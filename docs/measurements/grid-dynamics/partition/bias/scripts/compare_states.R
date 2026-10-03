# A run's states against the tol 1e-7 reference at the times both land on (the
# knots and introductions): each of the first nodes' nine components and the soil,
# as relative differences, on a coarse time grid and at a few named times.
#
#   Rscript compare_states.R run_out.rds run_states.rds [label]
#
# run_out.rds is the OUT of a stepper run (its st holds each accepted step's
# time); run_states.rds its STATES file.
args <- commandArgs(TRUE)
D <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/ark"
ref_t <- readRDS(file.path(D, "ck_u108_1e-7.rds"))$st$time
ref_s <- readRDS(file.path(D, "ck_u108_1e-7_states.rds"))
run_t <- readRDS(args[1])$st$time
run_s <- readRDS(args[2])
label <- if (length(args) > 2) args[3] else basename(args[1])
common <- intersect(round(run_t, 12), round(ref_t, 12))
ir <- match(common, round(ref_t, 12)); iu <- match(common, round(run_t, 12))
NODE <- c("height", "mortality", "fecundity", "area_hw", "mass_hw", "storage", "offspring", "I", "N")
rel <- function(a, b) (a - b) / pmax(abs(b), 1e-300)
rows <- list()
for (k in seq_along(common)) {
  a <- run_s[[iu[k]]]; b <- ref_s[[ir[k]]]
  if (length(a) != length(b)) next
  nn <- (length(a) - 10) %/% 9
  row <- c(t = common[k], M = nn)
  for (j in 1:min(3, nn)) {
    idx <- 9 * (j - 1) + 1:9
    v <- rel(a[idx], b[idx]); names(v) <- paste0("n", j, "_", NODE)
    row <- c(row, v)
  }
  sl <- length(a) - 9:5
  v <- rel(a[sl], b[sl]); names(v) <- paste0("soil_", 1:5)
  row <- c(row, v)
  rows[[length(rows) + 1]] <- row
}
all_names <- unique(unlist(lapply(rows, names)))
tab <- do.call(rbind, lapply(rows, function(r) { x <- setNames(rep(NA_real_, length(all_names)), all_names); x[names(r)] <- r; x }))
tab <- as.data.frame(tab)
cat(sprintf("%s: %d common times\n", label, nrow(tab)))
grid <- c(0.01, 0.05, 0.1, 0.2, 0.3, 0.37, 0.5, 0.74, 1, 1.5, 2, 3, 5, 8, 10, 15, 20, 25, 30, 35, 39.9)
pick <- unique(vapply(grid, function(g) which.min(abs(tab$t - g)), 1L))
show <- c("t", "n1_height", "n1_mortality", "n1_fecundity", "n1_storage", "n1_offspring",
          "n2_height", "n2_mortality", "n2_offspring", "n3_height", "n3_offspring", "soil_1", "soil_3")
show <- intersect(show, names(tab))
options(width = 250)
print(signif(tab[pick, show], 3), row.names = FALSE)
if (length(args) > 3) saveRDS(tab, args[4])
