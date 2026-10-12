# Edge travel with root_P50 (+-2%, same grid H), step resolution at the edges, and which
# side of each run's own edge H's nearest node falls.
S <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest"; Q <- file.path(S, "placed2/runs")
edges <- function(cr, th = 0.5) {
  op <- cr$rate > th; k <- which(diff(op) != 0)
  # interpolate the crossing of th between step midpoints
  m <- (cr$start + cr$end) / 2
  b <- m[k] + (th - cr$rate[k]) / (cr$rate[k + 1] - cr$rate[k]) * (m[k + 1] - m[k])
  data.frame(b = b, closing = op[k], step = (cr$end - cr$start)[k] * 365)
}
p <- edges(readRDS(file.path(Q, "rp_H_0.02_dry.rds"))$stand$creation)
m <- edges(readRDS(file.path(Q, "rp_H_-0.02_dry.rds"))$stand$creation)
h <- readRDS(file.path(S, "rp50/H_dry.rds")); b1 <- 3.529
cat(sprintf("edges +2%%: %d, -2%%: %d; step length at edges (d): median %.3f, q90 %.3f\n", nrow(p), nrow(m), median(p$step), quantile(p$step, .9)))
j <- vapply(p$b, function(z) which.min(abs(m$b - z)), 1L)
tr <- (p$b - m$b[j]) * 365; ok <- abs(tr) < 5 & p$closing == m$closing[j]
for (cl in c(TRUE, FALSE)) { s <- ok & p$closing == cl & p$b > b1
  cat(sprintf("%s: %d matched; travel over 4%% root_P50 (d): median |.| %.3f, q90 %.3f, max %.3f; sign + share %.2f\n",
    if (cl) "closings" else "openings", sum(s), median(abs(tr[s])), quantile(abs(tr[s]), .9), max(abs(tr[s])), mean(tr[s] > 0))) }
# side of the nearest node, for each run's own edges (late, closings and openings)
side <- function(e) { k <- vapply(e$b, function(z) which.min(abs(h - z)), 1L); d <- (h[k] - e$b) * 365
  shut <- ifelse(e$closing, d > 0, d < 0); data.frame(d = d, shut = shut, closing = e$closing, late = e$b > b1) }
for (nm in c("+2%", "-2%")) { s <- side(if (nm == "+2%") p else m); s <- s[s$late & abs(s$d) < 2, ]
  cat(sprintf("%s: nodes within 2 d of an edge %d; on the shut side %.0f%% (closings %.0f%%, openings %.0f%%); |offset| median %.3f d\n",
    nm, nrow(s), 100 * mean(s$shut), 100 * mean(s$shut[s$closing]), 100 * mean(s$shut[!s$closing]), median(abs(s$d)))) }
