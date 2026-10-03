# Short runs against the tol 1e-7 reference: at each introduction time and leg
# end a run reaches, the relative difference of each node's nine components and
# of the soil layers.
#
#   Rscript early.R name1 [name2 ...]
#
# Each name has out/<name>.rds (OUT) and out/<name>_states.rds (STATES).
B <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/partition_bias"
D <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/ark"
ref_t <- readRDS(file.path(D, "ck_u108_1e-7.rds"))$st$time
ref_s <- readRDS(file.path(D, "ck_u108_1e-7_states.rds"))
NODE <- c("height", "mortality", "fecundity", "area_hw", "mass_hw", "storage", "offspring", "I", "N")
times <- seq(0, 107 * 40 / 108, length.out = 108)
at <- function(tt, st_t, states) {
  i <- which(abs(st_t - tt) < 1e-12)
  if (!length(i)) return(NULL)
  states[[max(i)]]
}
options(width = 220)
for (nm in commandArgs(TRUE)) {
  o <- readRDS(file.path(B, "out", paste0(nm, ".rds")))
  s <- readRDS(file.path(B, "out", paste0(nm, "_states.rds")))
  st_t <- o$st$time
  cat(sprintf("== %s: J %.9f, %d steps to t = %.4f\n", nm, o$J, nrow(o$st), max(st_t)))
  for (tt in times[times > 0 & times <= max(st_t) + 1e-9]) {
    a <- at(tt, st_t, s); b <- at(tt, ref_t, ref_s)
    if (is.null(a) || is.null(b)) next
    nn <- (length(a) - 10) %/% 9
    for (j in seq_len(nn)) {
      idx <- 9 * (j - 1) + 1:9
      d <- (a[idx] - b[idx]) / pmax(abs(b[idx]), 1e-300)
      cat(sprintf("  t %.4f node %d: %s\n", tt, j,
                  paste(sprintf("%s %+.2e", NODE, d)[c(1:3, 6:9)], collapse = "  ")))
    }
    sl <- length(a) - 9:5
    cat(sprintf("  t %.4f soil: %s\n", tt, paste(sprintf("%+.2e", (a[sl] - b[sl]) / b[sl]), collapse = " ")))
  }
}
