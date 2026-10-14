# Every saved long-drought-family run with a gradient: its worst |quantity - reference| in eps.
suppressMessages(source("/home/user/plant-dev/harness/schedule/anyscore.R"))
R <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/adjmap/runs/"
f <- list.files(R, "(long-drought|ld-10[25])")
rows <- NULL
for (x in f) {
  r <- tryCatch(readRDS(file.path(R, x)), error = function(e) NULL)
  if (is.null(r$stand$elasticity)) next
  case <- if (grepl("ld-102", x)) "ld-102" else if (grepl("ld-105", x)) "ld-105" else "long-drought"
  q <- tryCatch(quantities(r), error = function(e) NULL); ref <- tryCatch(reference(case), error = function(e) NULL)
  if (is.null(q) || is.null(ref)) next
  k <- intersect(names(q), names(ref)); e <- (q[k] - ref[k]) / eps_vec(k)
  rows <- rbind(rows, data.frame(run = x, case = case, split = r$setting$env[["SPLIT"]], tol = r$setting$tol,
                                 worst = max(abs(e[-1])), lnJ = e[1], maxel = max(abs(r$stand$elasticity))))
}
rows <- rows[order(-rows$worst), ]
options(width = 200); print(rows[, c("run", "split", "tol", "worst", "lnJ", "maxel")], digits = 3, row.names = FALSE)
cat("runs", nrow(rows), "; worst > 1 eps:", sum(rows$worst > 1, na.rm = TRUE), "; > 0.33:", sum(rows$worst > 1/3, na.rm = TRUE), "\n")
