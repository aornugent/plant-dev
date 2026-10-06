# Plain's spread under seven tol nudges at 1e-4 and at 1e-5 (reverse mode,
# docs/measurements/nudges), in eps/3 with the 0.01 floor: how the kink-dominated
# spread falls as the steps at the crossings shorten.
d <- "/home/user/plant-dev/docs/measurements/nudges"
eps <- read.csv("/home/user/plant-dev/docs/measurements/eps.csv")
epsof <- function(role, tr) {
  e <- eps$eps[eps$role == role & eps$trait == tr]
  if (!length(e) || is.na(e)) e <- 0.01
  max(e, 0.01)
}
spread <- function(base, nud, role) {
  runs <- lapply(c(base, nud), function(t) readRDS(file.path(d, sprintf("ld_%s.rds", t))))
  el <- sapply(runs, function(r) r[[role]]$elasticity)
  tr <- sub("^1\\.", "", rownames(el))
  e3 <- sapply(tr, function(t) epsof(if (role == "stand") "resident" else "invader", t)) / 3
  mv <- apply(abs(el[, -1] - el[, 1]), 1, max) / e3
  sdv <- apply(el, 1, sd) / e3
  steps <- sapply(runs, `[[`, "steps")
  list(max = setNames(mv, tr), sd = setNames(sdv, tr), steps = steps)
}
for (role in c("stand", "invader")) {
  a <- spread("1e-4", c("9.5e-5", "9.7e-5", "9.85e-5", "1.015e-4", "1.03e-4", "1.05e-4"), role)
  b <- spread("1e-5", c("9.5e-6", "9.7e-6", "9.85e-6", "1.015e-5", "1.03e-5", "1.05e-5"), role)
  cat(sprintf("\n== %s: steps at 1e-4 %s, at 1e-5 %s\n", role,
              paste(range(a$steps), collapse = "-"), paste(range(b$steps), collapse = "-")))
  keep <- c("d_I", "a_dG1", "a_dG2", "lma", "a_st1", "a_st2", "storage_relaxation_offset", "rho", "a_d0")
  print(round(cbind(max_1e4 = a$max[keep], sd_1e4 = a$sd[keep], max_1e5 = b$max[keep], sd_1e5 = b$sd[keep],
                    ratio_sd = a$sd[keep] / b$sd[keep]), 3))
  top <- order(-a$max)[1:8]
  cat("largest at 1e-4:\n"); print(round(cbind(max_1e4 = a$max[top], max_1e5 = b$max[top], sd_ratio = a$sd[top] / b$sd[top]), 3))
  cat(sprintf("traits over 1 (eps/3): 1e-4 %d, 1e-5 %d; median sd ratio (traits with sd_1e4 > 0.1): %.2f\n",
              sum(a$max > 1), sum(b$max > 1), median((a$sd / b$sd)[a$sd > 0.1])))
}
