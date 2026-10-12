# The soil's root_P50 derivative around the year-26 spike, per grid, and the soil itself.
S <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest"; Q <- file.path(S, "placed2/runs"); u <- 0.02
tt <- seq(25.9, 26.4, by = 2 / 365)
rd <- function(g, s) readRDS(file.path(Q, sprintf("rp_%s_%s_dry.rds", g, s)))
f <- function(x) { k <- !duplicated(x$time, fromLast = TRUE); sapply(1:5, function(j) approx(x$time[k], x$theta[k, j], tt, rule = 2)$y) }
out <- data.frame(day = round(tt * 365 - 26 * 365, 1))
for (g in c("Ho", "Hoea", "Hoea2", "Hocw", "H", "Hea")) { a <- f(rd(g, "0.02")$stand$soil); b <- f(rd(g, "-0.02")$stand$soil)
  out[[paste0(g, "_d1")]] <- round((a[, 1] - b[, 1]) / (2 * u), 4) }
a <- f(rd("Ho", "0.02")$stand$soil); out$theta1 <- round(a[, 1], 4); out$theta5 <- round(a[, 5], 4)
r <- rd("Ho", "0.02")$rain; out$rain <- r[pmin(length(r), floor(tt * 365) + 1)]
print(out)
