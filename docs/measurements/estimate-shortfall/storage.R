# Storage of the panel's cohorts over time: first, middle and last cohort, and where
# along birth date its rate of change switches sign at each time.
x <- readRDS(commandArgs(TRUE)[1]); b <- x$times; g <- x$grid; s <- x$all$storage; h <- x$all$height
i <- which(g >= 11 & g <= 23)
ds <- apply(s, 2, function(v) c(NA, diff(v)))
for (k in i[seq(1, length(i), by = 10)]) { sw <- which(diff(sign(ds[k, ])) != 0)
  cat(sprintf("t %.2f: storage %.4f / %.4f / %.4f (first/mid/last) | growth sign switches along b at: %s | height %.2f-%.2f\n", g[k], s[k, 1], s[k, 50], s[k, 100],
    if (length(sw)) paste(round(b[sw], 3), collapse = " ") else "-", min(h[k, ]), max(h[k, ]))) }
