# Where in time the grids' root_P50 derivatives of soil water differ: Ho vs Hocw and the
# Ho ladder, on a daily grid, against time since the last closing.
S <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest"; Q <- file.path(S, "placed2/runs"); u <- 0.02
tt <- seq(0, 40, by = 1 / 365)
ds <- function(g) { a <- readRDS(file.path(Q, sprintf("rp_%s_0.02_dry.rds", g)))$stand$soil; b <- readRDS(file.path(Q, sprintf("rp_%s_-0.02_dry.rds", g)))$stand$soil
  f <- function(x, j) { k <- !duplicated(x$time, fromLast = TRUE); approx(x$time[k], x$theta[k, j], tt, rule = 2)$y }
  sapply(1:5, function(j) (f(a, j) - f(b, j)) / (2 * u)) }
d0 <- ds("Ho"); dw <- ds("Hocw"); d1 <- ds("Hoea"); d2 <- ds("Hoea2")
cr <- as.data.frame(readRDS(file.path(Q, "rp_Ho_0.02_dry.rds"))$stand$creation); pos <- cr$rate > 0; k <- which(diff(pos) != 0); cl <- cr$end[k][pos[k]]
since <- vapply(tt, function(t) { x <- t - cl[cl <= t]; if (length(x)) min(x) * 365 else NA }, 1)
open <- pos[pmax(findInterval(tt, cr$start), 1)]
lay <- 1  # surface layer first; all layers summed below
for (nm in c("Hocw - Ho", "Hoea - Ho", "Hoea2 - Hoea")) {
  D <- switch(nm, "Hocw - Ho" = dw - d0, "Hoea - Ho" = d1 - d0, "Hoea2 - Hoea" = d2 - d1); m <- rowSums(abs(D))
  bins <- cut(ifelse(open, -1, since), c(-2, 0, 2, 7, 30, 90, 1e5), labels = c("open", "shut 0-2 d", "shut 2-7 d", "shut 7-30 d", "shut 30-90 d", "shut >90 d"))
  s <- tapply(m, bins, sum) / sum(m)
  cat(sprintf("%-13s share of |difference| by state: %s; by period: <3.5 y %.2f, 3.5-10 y %.2f, 10-20 y %.2f, >20 y %.2f; peak at t = %.2f\n", nm,
    paste(sprintf("%s %.2f", names(s), s), collapse = ", "), sum(m[tt < 3.5]) / sum(m), sum(m[tt >= 3.5 & tt < 10]) / sum(m), sum(m[tt >= 10 & tt < 20]) / sum(m), sum(m[tt >= 20]) / sum(m), tt[which.max(m)])) }
cat(sprintf("share of days: open %.2f\n", mean(open)))
# against time to the next closing and since the last, whatever the state; and the signed
# difference integrated by year
nextc <- vapply(tt, function(t) { x <- cl[cl > t] - t; if (length(x)) min(x) * 365 else NA }, 1)
D <- dw - d0; m <- rowSums(abs(D))
cat("Hocw - Ho, share of |difference| by time to the next closing (d):\n"); print(round(tapply(m, cut(nextc, c(0, 8, 32, 90, 365, 1e5)), sum) / sum(m), 2))
cat("by time since the last closing (d):\n"); print(round(tapply(m, cut(since, c(0, 8, 32, 90, 365, 1e5)), sum) / sum(m), 2))
cat("days in each, to next:\n"); print(round(table(cut(nextc, c(0, 8, 32, 90, 365, 1e5))) / length(tt), 2))
yr <- floor(tt); cat("signed difference by year, layer 1 to 5 summed (x1e3):\n"); print(round(tapply(rowSums(D), yr, mean) * 1e3, 2))
