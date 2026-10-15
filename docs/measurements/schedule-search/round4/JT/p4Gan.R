# p4Gan.R: H2's prediction (P4_G_{A,B}) against the measured A - B and the stop's move, by window.
O <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/JT_out"
A <- readRDS(file.path(O, "P4_G_A.rds")); B <- readRDS(file.path(O, "P4_G_B.rds"))
cat("measured A-B along TF24_cost_scale -0.1758 eps; A's stop move (resolved - A) -0.0202\n")
for (v in c("c_all", "c_soil", "c_unsplit")) cat(sprintf("%-9s: pred A-B %+.4f (A %+.4f, B %+.4f); -A %+.4f\n", v, sum(A[[v]]) - sum(B[[v]]), sum(A[[v]]), sum(B[[v]]), -sum(A[[v]])))
brk <- c(0, 3.5, 5, 6.7, 8.25, 9.15, 9.678, 9.753, 10.04, 17, 25, 40)
f <- function(d, v) tapply(d[[v]], cut(d$t0, brk), sum)
tab <- data.frame(splice_share = c(NA, .16, 0, .09, 0, 0, .30, .04, .38, 0, 0))
for (v in c("c_all", "c_soil", "c_unsplit")) tab[[v]] <- round(f(A, v) - f(B, v), 4)
tab$lam1_med <- signif(tapply(abs(A$lam1), cut(A$t0, brk), median), 2); tab$h_med <- round(tapply(A$h_d, cut(A$t0, brk), median), 2); tab$switches <- tapply(A$n, cut(A$t0, brk), sum)
rownames(tab) <- levels(cut(A$t0, brk)); print(tab)
cat("\nlargest |c_unsplit| steps of A:\n"); print(head(A[order(-abs(A$c_unsplit)), ], 12), digits = 3)
