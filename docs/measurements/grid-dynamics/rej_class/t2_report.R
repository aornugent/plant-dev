# T2: leaf-class switches inside attempts, from the probe build's run of
# pics_3e-5's command line (t2_run.sh probe_pics_3e-5).
#   nice -n 10 Rscript DEV/rej_class/t2_report.R > DEV/rej_class/t2_report.txt
# Class codes (phylloptim OperatingPointKind): 0 Unsolved, 1 Interior,
# 2 BoundarySoil, 3 BoundaryCrit, 4 BoundaryRootCrit, 5 Determined,
# 6 HydraulicShutdown, 7 ShadeDeath, 8 Prescribed, 9 SolverRefused, 10 NonFiniteGradient.
O <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/rej_class"
D <- dirname(O)
KIND <- c("Unsolved", "Interior", "BoundarySoil", "BoundaryCrit", "BoundaryRootCrit", "Determined",
          "HydraulicShutdown", "ShadeDeath", "Prescribed", "SolverRefused", "NonFiniteGradient")
source(file.path(D, "pi", "analyse.R"))   # load_run(), classify(); runs nothing without args
share <- function(x) sprintf("%.1f%% (%d/%d)", 100 * mean(x, na.rm = TRUE), sum(x, na.rm = TRUE), sum(!is.na(x)))
q3 <- function(x, p = c(.1, .5, .9)) paste(signif(quantile(x, p, na.rm = TRUE), 3), collapse = " / ")

# Reproduction against the lib_v12t run.
ref <- load_run("pics_3e-5")
P <- O   # load_run() reads P/runs/NAME.rds and P/runs/att_NAME.rds
pr <- load_run("probe_pics_3e-5")
cat(sprintf("J: lib_v12t %.9f, lib_probe %.9f (identical: %s)\n", ref$run$J, pr$run$J, identical(ref$run$J, pr$run$J)))
cat("attempts, lib_v12t:", paste(names(ref$run$attempts), ref$run$attempts, sep = "=", collapse = " "), "\n")
cat("attempts, lib_probe:", paste(names(pr$run$attempts), pr$run$attempts, sep = "=", collapse = " "), "\n")
cat(sprintf("member evaluations: %d against %d\n", pr$run$counts$members, ref$run$counts$members))
same_log <- nrow(ref$a) == nrow(pr$a) && identical(as.matrix(ref$a[, 1:18]), as.matrix(pr$a[, 1:18]))
same_st <- identical(ref$run$st, pr$run$st)
cat(sprintf("attempt log's 18 columns identical: %s; accepted steps identical: %s\n", same_log, same_st))
stopifnot(same_log)

a <- pr$a
x <- readRDS(file.path(O, "t1_pics_3e-5.rds"))   # T1's per-attempt table, row for row
stopifnot(nrow(x) == nrow(a), identical(x$t0, a$t0), identical(x$h, a$h))
DAY <- 1 / 365
rain <- pr$run$rain
ki <- round(x$knot / DAY)
y_here <- rain[ki + 1]; y_next <- rain[ki + 2]
x$after <- ifelse(y_here == 0 & y_next > 0, "starts", ifelse(y_here > 0 & y_next == 0, "stops",
                  ifelse(y_next > y_here, "rises", ifelse(y_next < y_here, "falls", "flat"))))
x$cs <- a$class_switch > 0
side <- readRDS(file.path(O, "runs", "side_probe_pics_3e-5.rds"))
first_day <- x$since > 0.001 & x$since <= 1
on_knot <- x$since <= 0.001 & x$t0 > 0
B <- x$rej & x$cls == "other" & first_day & x$part == "soil"

cat("\n== Class switches inside an attempt (any member, any stage or the end, against its class at the start)\n")
cat("first-day soil-bound 'other' rejections:", share(x$cs[B]), "\n")
cat("base rates, first-day attempts:\n")
cat("  accepted, all:", share(x$cs[first_day & !x$rej]), "\n")
cat("  accepted, soil-bound:", share(x$cs[first_day & !x$rej & x$part == "soil"]), "\n")
for (k in c("starts", "rises")) {
  cat(sprintf("  '%s' knots: rejected soil 'other' %s | accepted soil-bound %s\n", k,
              share(x$cs[B & x$after == k]), share(x$cs[first_day & !x$rej & x$part == "soil" & x$after == k])))
}
cat("  matched by accepted steps since the knot (1-4), 'starts' and 'rises' knots, soil-bound: rejected | accepted\n")
for (s in 1:4) {
  m <- first_day & x$part == "soil" & x$after %in% c("starts", "rises") & x$n_since == s & x$try == 1
  cat(sprintf("    step %d: %s | %s\n", s, share(x$cs[m & B]), share(x$cs[m & !x$rej])))
}
cat("by taxonomy class, rejected (all bands) | for 'other', beyond the first day:\n")
for (cl in c("knot", "overshoot", "stability", "crossing", "empty pool", "other")) {
  z <- x$rej & x$cls == cl
  if (sum(z)) cat(sprintf("  %-10s %s\n", cl, share(x$cs[z])))
}
cat(sprintf("  other, beyond the first day: %s\n", share(x$cs[x$rej & x$cls == "other" & !first_day])))
cat(sprintf("  accepted, all attempts: %s; accepted, on knots: %s; accepted, beyond the first day: %s\n",
            share(x$cs[!x$rej]), share(x$cs[!x$rej & on_knot]), share(x$cs[!x$rej & !first_day & !on_knot])))

cat("\n== H1's sharp test: does a switch inside raise the coupled ratio over the chain alone's?\n")
for (lab in c("with a switch", "without")) {
  z <- B & (if (lab == "with a switch") x$cs else !x$cs)
  if (!sum(z)) next
  rr <- x$chain[z] / x$ratio[z]
  cat(sprintf("  rejected, %s (%d): chain alone over coupled %s; within x2 %.1f%%; chain alone > 1.1 on %.1f%%\n",
              lab, sum(z), q3(rr), 100 * mean(rr > 0.5 & rr < 2), 100 * mean(x$chain[z] > 1.1)))
}
for (lab in c("with a switch", "without")) {
  z <- first_day & !x$rej & x$part == "soil" & (if (lab == "with a switch") x$cs else !x$cs)
  rr <- x$chain[z] / x$ratio[z]
  cat(sprintf("  accepted soil-bound, %s (%d): chain alone over coupled %s\n", lab, sum(z), q3(rr)))
}

cat("\n== The switches in the first-day soil-bound 'other' rejections\n")
sb <- side[side$row %in% which(B), ]
cat(sprintf("%d member switches in %d attempts; members per attempt with any, 10/50/90%%: %s\n",
            nrow(sb), length(unique(sb$row)), q3(as.vector(table(sb$row)))))
tr <- table(paste(KIND[sb$from + 1], "->", KIND[sb$to + 1]))
print(sort(tr, decreasing = TRUE))
cat("where in the step (fraction at the first stage that differs):", q3(sb$at), "\n")
cat("switching members' birth times, 10/50/90%:", q3(sb$birth), "| net production at the start:", q3(sb$P0), "\n")
sa <- side[side$row %in% which(first_day & !x$rej & x$part == "soil"), ]
cat("for comparison, accepted first-day soil-bound attempts:\n")
print(head(sort(table(paste(KIND[sa$from + 1], "->", KIND[sa$to + 1])), decreasing = TRUE), 8))

cat("\n== When members switch class after a rain onset (accepted steps' switches, by the knot's day-after change)\n")
acc_rows <- which(!x$rej)
sw <- side[side$row %in% acc_rows, ]
sw$since <- x$since[sw$row] + sw$at * x$h[sw$row] / DAY
sw$after <- x$after[sw$row]
for (k in c("starts", "rises")) {
  z <- sw$after == k & sw$since <= 1
  cat(sprintf("  '%s': %d switches within the day; since the knot in delta, 10/50/90%%: %s\n", k, sum(z), q3(sw$since[z])))
  print(head(sort(table(paste(KIND[sw$from[z] + 1], "->", KIND[sw$to[z] + 1])), decreasing = TRUE), 6))
}
out <- cbind(x, class_switch = a$class_switch, cs_member = a$cs_member, cs_birth = a$cs_birth,
             cs_from = a$cs_from, cs_to = a$cs_to)
saveRDS(out, file.path(O, "t2_attempts_probe_pics_3e-5.rds"))
