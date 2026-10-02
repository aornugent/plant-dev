# T3 (the cure, priced on the driver): pics_3e-5 against the same command line
# with CHAIN_GUARD (t3_driver.patch): before each step's first attempt, the soil
# chain alone takes one Cash-Karp step from the coupled soil state at the
# proposed size and shrinks it by the rejection law while its ratio exceeds the bar.
#   nice -n 10 Rscript DEV/rej_class/t3_guard_report.R guard_pics_3e-5 guard_pi_3e-5 guard_odelia_3e-5 > DEV/rej_class/t3_guard_report_all.txt
# (t3_guard_report.txt is an earlier version's output with guard_pics_3e-5 alone.)
O <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/rej_class"
D <- dirname(O)
source(file.path(D, "pi", "analyse.R"))
lev <- c("knot", "overshoot", "stability", "crossing", "empty pool", "other")
summarise <- function(x) {
  run <- x$run; d <- classify(run, x$a)
  r <- d[d$rej, ]
  first_day_soil <- sum(r$cls == "other" & r$since > 0.001 & r$since <= 1 & r$part == "soil")
  data.frame(run = x$name, J = sprintf("%.9f", run$J), err = sprintf("%+.2e", run$J / J_STAR[["long-drought"]] - 1),
             accepted = sum(!d$rej), rejected = sum(d$rej), member_evals = run$counts$members,
             in_rejected = sprintf("%.1f%%", 100 * sum(r$members) / run$counts$members),
             first_day_soil_other = first_day_soil,
             t(setNames(as.vector(table(factor(r$cls, lev))), lev)), check.names = FALSE)
}
P0 <- P
rows <- list(summarise(load_run("pics_3e-5")), summarise(load_run("pi_3e-5")))
P <- O
for (n in commandArgs(TRUE)) rows[[length(rows) + 1]] <- summarise(load_run(n))
tab <- do.call(rbind, rows)
print(tab, row.names = FALSE)
for (j in 1:2) {
  cat(sprintf("\nagainst %s: member evaluations %s\n", tab$run[j],
              paste(sprintf("%s %+.2f%%", tab$run, 100 * (tab$member_evals / tab$member_evals[j] - 1)), collapse = "; ")))
  cat(sprintf("against %s: accepted steps %s\n", tab$run[j],
              paste(sprintf("%s %+.2f%%", tab$run, 100 * (tab$accepted / tab$accepted[j] - 1)), collapse = "; ")))
}
