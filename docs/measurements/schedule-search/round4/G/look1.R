# look1.R: which quantities carry error, and how much of each case's error is one shape.
OUT <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/G_out"
X <- readRDS(file.path(OUT, "errs.rds")); m <- X$meta; E <- X$E
v <- m$kind == "val" & !grepl("bug|n1|n2", m$alg) & abs(m$tol - 1e-4) < 1e-9
cat("val runs at 1e-4:", sum(v), "\n")
A <- abs(E[v, ]); ok <- apply(A, 1, function(r) all(!is.na(r) & r < 50))
cat("runs with a blown quantity (>50 eps):", sum(!ok), rownames(A)[!ok], "\n")
A <- A[ok, ]; mv <- m[v, ][ok, ]
s <- data.frame(q = colnames(A), max = apply(A, 2, max), p90 = apply(A, 2, quantile, 0.9), med = apply(A, 2, median),
  frac_over_third = colMeans(A > 1/3), frac_over_half = colMeans(A > 0.5))
s <- s[order(-s$p90), ]; print(format(s, digits = 2), row.names = FALSE)
cat("\nquantities never over eps/3 in any val run at 1e-4:", sum(s$max < 1/3), "of", nrow(s), "\n")
cat("\nper case: worst quantity and its share of runs where it is the worst\n")
for (cs in unique(mv$case)) { a <- A[mv$case == cs, , drop = FALSE]; w <- colnames(a)[apply(a, 1, which.max)]
  t <- sort(table(w), decreasing = TRUE); cat(sprintf("%-13s n=%2d  %s\n", cs, nrow(a), paste(sprintf("%s:%d", names(t), t), collapse = " "))) }
# SVD per case of signed errors
cat("\nper case: share of sum of squares in the first 1,2 singular directions (signed errors, all case runs, |e|<50)\n")
for (cs in unique(m$case)) { e <- E[m$case == cs & apply(abs(E), 1, max) < 50 & !m$pin, , drop = FALSE]; e <- e[complete.cases(e), , drop = FALSE]
  if (nrow(e) < 4) next; d <- svd(e)$d^2; cat(sprintf("%-13s n=%3d  %.2f %.2f %.2f\n", cs, nrow(e), d[1]/sum(d), sum(d[1:2])/sum(d), sum(d[1:3])/sum(d))) }
