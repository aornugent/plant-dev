# Summarise traj_<TAG>.rds: per cohort of variant 1 (P unscaled), the hazard
# accrued while reserves were low, and d H / d eps from variants 2 and 3
# (P x (1 +- d)), split over time.
#   Rscript traj_summary.R closed 1,8
a <- commandArgs(TRUE)
x <- readRDS(file.path("/home/a/.claude/jobs/9d586e52/tmp/breakeven", paste0("traj_", a[1], ".rds")))
d <- x$traj
coh <- as.integer(strsplit(if (length(a) > 1) a[2] else "1", ",")[[1]])
eps <- x$scales[2] - 1
cat("lnR':", x$lnR, "\n")
for (k in coh) {
  v <- lapply(1:3, function(i) d[d$variant == i & d$cohort == k, ])
  b <- v[[1]]
  cat(sprintf("\ncohort %d, born %.3f\n", k, b$birth[1]))
  dH <- (v[[2]]$H - v[[3]]$H) / (2 * eps)
  dlnF <- (log(v[[2]]$fecundity) - log(v[[3]]$fecundity)) / (2 * eps)
  sel <- unique(round(seq(1, nrow(b), length.out = 41)))
  print(data.frame(t = b$time[sel], h = b$height[sel], r = b$r[sel],
                   mu = b$mu[sel], H = b$H[sel], net = b$net[sel],
                   gross_over_net = (b$gross / b$net)[sel],
                   dH_deps = dH[sel], dlnFec_deps = dlnF[sel],
                   dlnh_deps = ((log(v[[2]]$height) - log(v[[3]]$height)) / (2 * eps))[sel],
                   dr_deps = ((v[[2]]$r - v[[3]]$r) / (2 * eps))[sel],
                   dlnS_deps = ((log(v[[2]]$storage) - log(v[[3]]$storage)) / (2 * eps))[sel]),
        digits = 3)
}
