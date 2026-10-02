# Do the soil's first-day rejections and the members' class switches fall after
# the same rain onsets? Per onset knot (interpolant 'starts'): any first-day
# class switch, the first-day soil-bound 'other' rejections, the dry spell before
# it and the top layer's moisture at the knot.
#   nice -n 10 Rscript DEV/rej_class/t2_knots.R > DEV/rej_class/t2_knots.txt
O <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/rej_class"
x <- readRDS(file.path(O, "t2_attempts_probe_pics_3e-5.rds"))
q3 <- function(x, p = c(.1, .5, .9)) paste(signif(quantile(x, p, na.rm = TRUE), 3), collapse = " / ")
x$cs <- !is.na(x$class_switch) & x$class_switch > 0
fd <- x$since > 0.001 & x$since <= 1
B <- x$rej & x$cls == "other" & fd & x$part == "soil"
on <- x[x$after == "starts" & x$since <= 1 & x$t0 > 0, ]
knots <- sort(unique(on$knot))
k_sw <- tapply(on$cs & on$since > 0.001, on$knot, any)
k_rej <- tapply(B[x$after == "starts" & x$since <= 1 & x$t0 > 0], on$knot, sum)
th1 <- tapply(on$theta1, on$knot, function(v) v[1])
# The dry spell before each knot: days since the previous wet knot value.
rain <- readRDS(file.path(dirname(O), "pi", "runs", "pics_3e-5.rds"))$rain
DAY <- 1 / 365
wet_days <- which(rain > 0) - 1               # knot indices with rain at the knot
ki <- round(as.numeric(names(k_sw)) / DAY)
dry <- vapply(ki, function(i) { p <- wet_days[wet_days < i]; if (length(p)) i - max(p) else NA }, 0)
cat(sprintf("onset knots: %d; with a first-day class switch: %d\n", length(k_sw), sum(k_sw)))
for (lab in c("with a switch", "without")) {
  z <- if (lab == "with a switch") k_sw else !k_sw
  cat(sprintf("  %s: %d knots, soil 'other' rejections %d (%.2f a knot); dry days before, 10/50/90%%: %s; theta1 at the knot: %s\n",
              lab, sum(z), sum(k_rej[z]), mean(k_rej[z]), q3(dry[z]), q3(th1[z])))
}
