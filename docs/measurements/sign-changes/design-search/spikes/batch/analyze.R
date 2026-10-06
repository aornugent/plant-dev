# The nudge spread of plain reverse-mode elasticities on the driver's seven
# programs (m1), against the same programs with every crossing step cut into m
# equal steps (m2, m4): the largest move from the 1e-4 run over the six nudges,
# in eps/3 (eps from eps.csv, floored at 0.01 as OBJECTIVES.md sets it; the
# ledger's d_I figure is unfloored, shown apart). Then the second differences
# of ln J in ln lma at r = 1e-2 over the three tolerances 9.5e-5, 1e-4, 1.05e-4.
eps <- read.csv("/home/user/plant-dev/docs/measurements/eps.csv")
epsof <- function(tr, floor = TRUE) {
  e <- eps$eps[eps$role == "resident" & eps$trait == tr]
  if (!length(e) || is.na(e)) e <- 0.01
  if (floor) max(e, 0.01) else e
}
tols <- c("1e-4", "9.5e-5", "9.7e-5", "9.85e-5", "1.015e-4", "1.03e-4", "1.05e-4")
R <- "runs"
load_arm <- function(m, suffix = "") {
  f <- file.path(R, sprintf("g_m%s_%s%s.rds", m, tols, suffix))
  ok <- file.exists(f)
  runs <- lapply(f[ok], readRDS)
  ok2 <- vapply(runs, function(r) !is.null(r$stand$elasticity), TRUE)
  list(tols = tols[ok][ok2], runs = runs[ok2])
}
spread <- function(arm, floor = TRUE) {
  if (length(arm$runs) < 2 || arm$tols[1] != "1e-4") return(NULL)
  el <- sapply(arm$runs, function(r) r$stand$elasticity)
  tr <- sub("^1\\.", "", rownames(el))
  e3 <- vapply(tr, epsof, 0, floor = floor) / 3
  mv <- apply(abs(el[, -1, drop = FALSE] - el[, 1]), 1, max) / e3
  setNames(mv, tr)
}
arms <- list(m1 = load_arm(1), m2 = load_arm(2), m4 = load_arm(4), split = load_arm(1, "_split"))
cat("runs per arm:", paste(names(arms), vapply(arms, function(a) length(a$runs), 0), collapse = ", "), "\n")
for (a in names(arms)) if (length(arms[[a]]$runs)) {
  J <- vapply(arms[[a]]$runs, function(r) r$stand$J, 0)
  st <- vapply(arms[[a]]$runs, function(r) length(r$stand$times), 0)
  sw <- vapply(arms[[a]]$runs, function(r) r$phases$stand_gradient$cpu_secs, 0)
  cat(sprintf("%-5s J-J* rel (1e-4 run) %+.2e; steps %s; sweep cpu s %s\n", a, J[1] / 12.6687125607 - 1,
              paste(st, collapse = " "), paste(round(sw), collapse = " ")))
}
S <- lapply(arms, spread)
S <- S[!vapply(S, is.null, TRUE)]
if (length(S)) {
  tab <- do.call(cbind, S)
  key <- c("a_dG1", "storage_relaxation_offset", "a_dG2", "TF24_cost_scale", "a_l1", "a_st2", "a", "lma", "d_I")
  cat("\nlargest move over the nudges, eps/3 (floored eps):\n")
  print(round(tab[intersect(key, rownames(tab)), , drop = FALSE], 3))
  cat("\nper arm: traits over 1 and over 0.5; median; max (trait)\n")
  for (a in colnames(tab)) cat(sprintf("%-5s over1 %d over0.5 %d median %.3f max %.3f (%s)\n", a,
    sum(tab[, a] > 1), sum(tab[, a] > 0.5), median(tab[, a]), max(tab[, a]), rownames(tab)[which.max(tab[, a])]))
  if (all(c("m1", "m2") %in% colnames(tab))) {
    r <- tab[, "m1"] / tab[, "m2"]
    big <- tab[, "m1"] > 0.3
    cat(sprintf("\nm1/m2 ratio over traits with m1 > 0.3 (%d): median %.2f, range %.2f-%.2f\n", sum(big),
                median(r[big]), min(r[big]), max(r[big])))
  }
  Su <- lapply(arms, spread, floor = FALSE)
  Su <- Su[!vapply(Su, is.null, TRUE)]
  cat("\nd_I unfloored (the ledger's measure):", paste(names(Su), round(vapply(Su, function(s) s[["d_I"]], 0), 3), collapse = ", "), "\n")
}
# Second differences of ln J in ln lma, r = 1e-2, against each tolerance's own r = 0 run.
eps_curv <- 1.17
sd2 <- function(m, tt) {
  f0 <- file.path(R, sprintf("g_m%d_%s.rds", m, tt))
  if (!file.exists(f0)) f0 <- file.path(R, sprintf("f_m%d_%s_lma0.rds", m, tt))
  fp <- file.path(R, sprintf("f_m%d_%s_lma0.01.rds", m, tt))
  fm <- file.path(R, sprintf("f_m%d_%s_lma-0.01.rds", m, tt))
  if (!all(file.exists(c(f0, fp, fm)))) return(NA)
  l <- vapply(list(fm, f0, fp), function(f) log(readRDS(f)$stand$J), 0)
  xm <- log(1 - 0.01); xp <- log(1 + 0.01)
  2 * ((l[3] - l[2]) / xp - (l[2] - l[1]) / (-xm)) / (xp - xm)
}
cat("\nsecond difference of ln J in ln lma at r = 1e-2 (eps 1.17; converged -43.45):\n")
for (m in c(1, 2, 4)) {
  v <- vapply(c("9.5e-5", "1e-4", "1.05e-4"), function(tt) sd2(m, tt), 0)
  if (all(is.na(v))) next
  cat(sprintf("m%d: %s; spread %.3f eps; mean off converged %.3f eps\n", m,
              paste(sprintf("%.3f", v), collapse = " "), diff(range(v, na.rm = TRUE)) / eps_curv,
              (mean(v, na.rm = TRUE) + 43.45) / eps_curv))
}
