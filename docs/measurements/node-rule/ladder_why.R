# Why episodic's and constant's ladders miss (prereg.txt, the ladders' results),
# from ladder.sh's and episodic.sh's runs.
#   DEV=... PLANT_LIB=... Rscript docs/measurements/node-rule/ladder_why.R   # from plant-dev's root
local({
  source("harness/long_drought.R")
})
D <- Sys.getenv("DEV")
L <- file.path(D, "node_rule", "ladder", "runs")
E <- file.path(D, "node_rule", "episodic", "runs")
J <- function(dir, name) readRDS(file.path(dir, paste0(name, ".rds")))$stand$J
cat("== episodic: J on each uniform rung, and each move over the next\n")
for (b in list(c("spread", L, "u%d_episodic", E, "spread_u857_episodic"),
               c("lumped", E, "lumped_u%d_episodic", E, "lumped_u857_episodic"))) {
  j <- c(vapply(c(108, 215, 429), function(n) J(b[2], sprintf(b[3], n)), 0), J(b[4], b[5]))
  m <- diff(j)
  cat(sprintf("   %s: %s; moves %s; ratios %s\n", b[1], paste(format(j, digits = 10), collapse = ", "),
              paste(sprintf("%+.6f", m), collapse = ", "), paste(sprintf("%.2f", m[-3] / m[-1]), collapse = ", ")))
}
cat("== the field's part: each of the coarse rung's nodes' nrr moving at its coarse weight\n")
for (rec in c("episodic", "dry", "long-wet")) {
  r <- lapply(c(c = 108, m = 215, f = 429),
              function(n) readRDS(file.path(L, sprintf("u%d_%s.rds", n, rec)))$stand$nodes)
  nrr <- sapply(names(r), function(k) r[[k]]$nrr[match(r$c$birth, r[[k]]$birth)])
  w <- r$c$establishment[seq_along(r$c$birth)]
  f <- c(sum(w * (nrr[, "m"] - nrr[, "c"])), sum(w * (nrr[, "f"] - nrr[, "m"])))
  cat(sprintf("   %-9s moves %+.4g then %+.4g, ratio %.2f\n", rec, f[1], f[2], f[1] / f[2]))
}
cat("== each record's dry spells, in days\n")
for (rec in c("episodic", "dry", "long-wet")) {
  z <- rle(rain_record(rec) == 0); d <- z$lengths[z$values]
  cat(sprintf("   %-9s mean %.1f, median %.0f, 90th percentile %.0f\n", rec, mean(d), median(d),
              quantile(d, 0.9)))
}
cat("== constant's graded rungs: the front refined, the bulk shared\n")
G <- file.path(D, "window", "t", "graded")
for (g in c("Gbf8", "Gbf16", "Gbf32")) {
  t <- readRDS(file.path(G, sprintf("t_const_%s.rds", g)))
  cat(sprintf("   %-5s %3d introductions, %3d of them before 1 year; after it %d, spaced %.3g to %.3g years\n",
              g, length(t), sum(t < 1), sum(t >= 1), min(diff(t[t >= 1])), max(diff(t[t >= 1]))))
}
t16 <- readRDS(file.path(G, "t_const_Gbf16.rds")); t32 <- readRDS(file.path(G, "t_const_Gbf32.rds"))
q <- readRDS(file.path(D, "node_rule", "ladder", "t_const_Gbf16_q.rds"))
cat(sprintf("   the introductions after 1 year are the same on Gbf16 and Gbf32: %s; the shift moves one by up to %.0f days\n",
            identical(t16[t16 >= 1], t32[t32 >= 1]), 365 * max(q - t16)))
