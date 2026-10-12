# The wiggle in late births' root_P50 derivative of fate: its period on the finest grid,
# against the rainfall's season.
S <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest"; Q <- file.path(S, "placed2/runs")
p <- readRDS(file.path(Q, "rp_Hoea2_0.02_dry.rds")); q <- readRDS(file.path(Q, "rp_Hoea2_-0.02_dry.rds"))
b <- p$stand$nodes$birth; d <- (log(p$stand$nodes$nrr) - log(q$stand$nodes$nrr)) / 0.04; w <- head(p$stand$nodes$establishment, -1)
k <- b > 3.6 & b < 30 & w > 0 & is.finite(d)
g <- seq(4, 30, by = 5 / 365); y <- approx(b[k], d[k], g)$y
y <- y - stats::filter(y, rep(1, 147) / 147, sides = 2)   # remove the trend over ~2 years
y <- y[is.finite(y)]; sp <- spec.pgram(y, taper = 0.1, plot = FALSE, detrend = TRUE)
per <- 5 / 365 / sp$freq; o <- order(-sp$spec)[1:5]
cat("dominant periods of the late births' d ln nrr / d ln root_P50 (years):", paste(sprintf("%.2f", per[o]), collapse = " "), "\n")
cat(sprintf("detrended amplitude (sd) %.3f against the level %.3f; eps %.4f\n", sd(y), mean(d[k]), 0.01075))
r <- p$rain; doy <- (seq_along(r) - 1) %% 365
m <- tapply(r, cut(doy, seq(0, 365, by = 30.4), include.lowest = TRUE), mean); cat("rain by month (mm/d):", paste(sprintf("%.2f", m), collapse = " "), "\n")
