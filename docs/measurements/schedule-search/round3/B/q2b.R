A <- readRDS("/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/B_elmaps.rds")
for (st in unique(A$set)) { z <- A[A$set == st, ]; z <- z[order(-abs(z$dE)), ][1:8, ]
  cat("==", st, "\n"); print(data.frame(b = round(z$birth, 3), m = signif(z$m, 2), own = signif(z$own, 2), fld = signif(z$fld, 2), dE = signif(z$dE, 2), ratio = round(abs(z$dE) / z$mag, 1)), row.names = FALSE)
  b <- cut(z$birth, c(0, 3.6, 10, 20, 25, 41)); }
cat("\nshare of sum|dE| by band, and sum|m| by band:\n")
for (st in unique(A$set)) { z <- A[A$set == st, ]; g <- cut(z$birth, c(-1, 3.6, 10, 20, 25, 41), labels = c("<3.6", "3.6-10", "10-20", "20-25", ">25"))
  cat(sprintf("%-26s dE: %s | m: %s\n", st, paste(sprintf("%.2f", tapply(abs(z$dE), g, sum) / sum(abs(z$dE))), collapse = " "), paste(sprintf("%.2f", tapply(abs(z$m), g, sum) / sum(abs(z$m))), collapse = " "))) }
