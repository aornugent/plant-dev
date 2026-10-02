# The attempts that hold a class switch in the probe run: what binds them, how
# often they are rejected, and the soil's ratio in them against the chain alone's.
#   nice -n 10 Rscript DEV/rej_class/t2_switch_attempts.R > DEV/rej_class/t2_switch_attempts.txt
O <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/rej_class"
x <- readRDS(file.path(O, "t2_attempts_probe_pics_3e-5.rds"))
side <- readRDS(file.path(O, "runs", "side_probe_pics_3e-5.rds"))
q3 <- function(x, p = c(.1, .5, .9)) paste(signif(quantile(x, p, na.rm = TRUE), 3), collapse = " / ")
x$cs <- !is.na(x$class_switch) & x$class_switch > 0
band <- cut(x$since, c(-Inf, 0.001, 1, 10, Inf), labels = c("on a knot", "first day", "1-10 days", "over 10 days"))
cat("attempts with a class switch, by band: count, rejected share, members switching per attempt (median)\n")
for (b in levels(band)) {
  z <- x$cs & band == b
  cat(sprintf("  %-12s %4d attempts, rejected %.1f%% (all attempts there: %.1f%%), switching members median %g\n",
              b, sum(z), 100 * mean(x$rej[z]), 100 * mean(x$rej[band == b]), median(x$class_switch[z])))
}
cat("binding part of attempts with a switch, accepted / rejected:\n")
print(table(x$part[x$cs], ifelse(x$rej[x$cs], "rejected", "accepted")))
cat("binding part of all first-day attempts, accepted / rejected:\n")
fd <- band == "first day"
print(table(x$part[fd], ifelse(x$rej[fd], "rejected", "accepted")))
z <- x$cs & band == "first day" & x$part == "soil"
cat("\nfirst-day soil-bound attempts with a switch:\n")
y <- x[z, c("t0", "h", "since", "n_since", "rej", "cls", "ratio", "chain", "layer", "chain_layer", "class_switch", "x_soil")]
y$h <- y$h * 365
print(y, digits = 3, row.names = FALSE)
cat("\nall soil-bound attempts with a switch (any band): coupled ratio", q3(x$ratio[x$cs & x$part == "soil"]),
    "; chain alone", q3(x$chain[x$cs & x$part == "soil"]), "; n", sum(x$cs & x$part == "soil"), "\n")
cat("onset knots with any switch in their first day:", length(unique(x$knot[x$cs & band == "first day"])),
    "; first-day attempts with a switch per such knot, median",
    median(table(x$knot[x$cs & band == "first day"])), "\n")
