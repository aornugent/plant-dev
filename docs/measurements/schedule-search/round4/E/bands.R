# Rows and steps by patch age band and by what ended each step (committed runs).
source("/home/user/plant-dev/docs/measurements/schedule-search/round4/E/common.R")
res <- readRDS(file.path(EO, "steps.rds"))
br <- c(0, 5, 10, 20, 25, 30, 33, 40)
for (k in grep(" c$", names(res), value = TRUE)) { d <- res[[k]]; d$band <- cut(d$start, br, right = FALSE)
  tot <- sum(d$alive); cat(sprintf("\n%s  rows %.0f\n", k, tot))
  m <- with(d, tapply(alive, list(band, cls), sum)); m[is.na(m)] <- 0
  n <- with(d, tapply(alive, list(band, cls), length)); n[is.na(n)] <- 0
  hm <- with(d, tapply(h * 365, band, median))
  print(cbind(round(100 * m / tot, 1), steps = rowSums(n), knot_steps = n[, "knot"], med_h_d = round(hm, 2), rows_pct = round(100 * rowSums(m) / tot, 1))) }
