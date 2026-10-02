# Where the members' crossings of P = 0 fall, from harness/ark_prototype.R's
# CROSS_LOG on uniform 108: their count, the steps that hold them, and the span
# of their clusters (crossings of one direction within two days of the last),
# for every member and for members born early on steps before a time. Capping
# the steps across a cluster at 0.05 days costs its span over 0.05 days.
# Then, from the driver's logs in DRIVER, J against long drought's reference
# and the member evaluations with that cap (SWITCH_DAYS=0.05) applied to every
# member, to members born before 3.6 (SWITCH_BORN), and on steps before t = 25
# (SWITCH_UNTIL), under plant's default absolute tolerance.
#
#   [DRIVER=docs/measurements/grid-dynamics] Rscript harness/crossings.R cross.rds
DAY <- 1 / 365
U108 <- seq(0, 107 * 40 / 108, length.out = 108)
x <- readRDS(commandArgs(TRUE)[1])
born <- U108[x$member]
spans <- function(k) {
  s <- 0
  n <- 0
  for (down in c(TRUE, FALSE)) {
    t <- sort(x$t[k & x$down == down])
    if (!length(t)) next
    cluster <- cumsum(c(1, diff(t) > 2 * DAY))
    s <- s + sum(tapply(t, cluster, function(v) diff(range(v))))
    n <- n + max(cluster)
  }
  c(clusters = n, days = s / DAY)
}
sets <- list("every member" = rep(TRUE, nrow(x)),
             "born before 3.6" = born < 3.6,
             "born before 3.6, before t = 25" = born < 3.6 & x$t < 25,
             "born before 10, before t = 25" = born < 10 & x$t < 25)
for (s in names(sets)) {
  k <- sets[[s]]
  sp <- spans(k)
  cat(sprintf("%-31s %5d crossings (%4.1f%%) on %4d steps; %3d clusters spanning %5.1f days, %5.0f steps at 0.05 days\n",
              s, sum(k), 100 * mean(k), length(unique(x$row[k])), sp[["clusters"]], sp[["days"]],
              sp[["days"]] / 0.05))
}

driver_dir <- Sys.getenv("DRIVER", file.path("docs", "measurements", "grid-dynamics"))
J_ref <- 12.6687135  # Cash-Karp at 1e-8 (docs/design-grid-controller.md)
logged <- function(f, pattern) {
  l <- paste(readLines(file.path(driver_dir, paste0(f, ".log"))), collapse = "\n")
  as.numeric(regmatches(l, regexec(pattern, l))[[1]][2])
}
runs <- c("none" = "ck_u108_%s", "every member" = "sw05_u108_%s",
          "born before 3.6, before t = 25" = "swk_u108_%s",
          "every member, before t = 25" = "swt_u108_%s", "born before 3.6, at every time" = "swb_u108_%s")
for (r in names(runs)) {
  cells <- vapply(c("1e-3", "3e-4", "1e-4"), function(t) {
    f <- sprintf(runs[[r]], t)
    if (!file.exists(file.path(driver_dir, paste0(f, ".log")))) return("")
    sprintf("%+.2e (%.2fe6)", logged(f, "J ([0-9.]+),") / J_ref - 1,
            logged(f, "member evaluations ([0-9]+)") / 1e6)
  }, "")
  cat(sprintf("%-31s %s\n", r, paste(sprintf("%-20s", cells), collapse = " ")))
}
