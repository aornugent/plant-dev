# The driver's runs per record: unweighted, rule A, rule A with each cap (and the
# thinned schedule where run). Rows are the members on each accepted step, as
# harness/rows.R counts them; forward is the member evaluations, rejected
# attempts included. Savings are against the record's unweighted run, and the
# share given up is (S_rule - S_capped) / S_rule against the uncapped rule run
# with the same nodes.
#
#   Rscript drv_table.R
D <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev"
P <- file.path(D, "phase1c")
eps_lnJ <- 0.0252373006179605
runs <- list(
  "long-drought" = c(unweighted = "rej/tied_3e-5_soil1", "rule A" = "window/drv/long-drought_rule",
                     "A, cap 7" = "phase1c/drv/long-drought_ruleA_h7", "A, cap 10" = "phase1c/drv/long-drought_ruleA_h10",
                     "A, cap 15" = "phase1c/drv/long-drought_ruleA_h15", "A, cap 22" = "phase1c/drv/long-drought_ruleA_h22",
                     "A, cap 26" = "phase1c/drv/long-drought_ruleA_h26",
                     "unweighted, cap 15" = "phase1c/drv/long-drought_base_h15",
                     "A thinned" = "window/drv/long-drought_rule_thin",
                     "A thinned, cap 15" = "phase1c/drv/long-drought_ruleA_thin_h15"),
  "long-wet" = c(unweighted = "window/drv/long-wet_base", "rule A" = "window/drv/long-wet_rule",
                 "A, cap 15" = "phase1c/drv/long-wet_ruleA_h15", "A, cap 22" = "phase1c/drv/long-wet_ruleA_h22",
                 "A, cap 26" = "phase1c/drv/long-wet_ruleA_h26",
                 "unweighted, cap 15" = "phase1c/drv/long-wet_base_h15",
                 "A thinned" = "window/drv/long-wet_rule_thin",
                 "A thinned, cap 15" = "phase1c/drv/long-wet_ruleA_thin_h15"),
  episodic = c(unweighted = "window/drv/episodic_base", "rule A" = "window/drv/episodic_rule",
               "A, cap 7" = "phase1c/drv/episodic_ruleA_h7", "A, cap 10" = "phase1c/drv/episodic_ruleA_h10",
               "A, cap 15" = "phase1c/drv/episodic_ruleA_h15", "A, cap 20" = "phase1c/drv/episodic_ruleA_h20",
               "A, cap 22" = "phase1c/drv/episodic_ruleA_h22", "A, cap 26" = "phase1c/drv/episodic_ruleA_h26",
               "unweighted, cap 15" = "phase1c/drv/episodic_base_h15",
               "A thinned" = "window/drv/episodic_rule_thin",
               "A thinned, cap 15" = "phase1c/drv/episodic_ruleA_thin_h15"))
for (r in names(runs)) {
  cat(sprintf("\n== %s\n", r))
  cat(sprintf("%-18s %6s %6s %8s %9s %7s %7s %7s %7s %13s %4s %4s %13s %10s %8s\n", "run", "acc", "rej",
              "rows", "forward", "S_rows", "S_fwd", "gu_rows", "gu_fwd", "longest (t)", ">15", ">26", "J", "J moves", "eps"))
  x <- list()
  for (k in names(runs[[r]])) {
    f <- file.path(D, paste0(runs[[r]][[k]], ".rds"))
    if (file.exists(f)) x[[k]] <- readRDS(f)
  }
  base <- x$unweighted
  rows_of <- function(y) sum(as.numeric(y$st$M))
  for (k in names(x)) {
    y <- x[[k]]; hd <- y$st$h * 365
    S <- c(1 - rows_of(y) / rows_of(base), 1 - y$counts$members / base$counts$members)
    ref <- if (grepl("thinned, cap", k)) x[["A thinned"]] else if (grepl("^A, cap", k)) x[["rule A"]] else NULL
    gu <- if (is.null(ref)) c(NA, NA) else {
      Sr <- c(1 - rows_of(ref) / rows_of(base), 1 - ref$counts$members / base$counts$members)
      (Sr - S) / Sr
    }
    a <- y$attempts
    cat(sprintf("%-18s %6d %6d %8.0f %9.0f %6.1f%% %6.1f%% %6.1f%% %6.1f%% %5.1f d (%5.2f) %4d %4d %13.9f %+10.2e %8.4f\n",
                k, nrow(y$st), a[["rejected_inaccurate"]] + a[["rejected_thrown"]], rows_of(y), y$counts$members,
                100 * S[1], 100 * S[2], 100 * gu[1], 100 * gu[2], max(hd), y$st$time[which.max(hd)],
                sum(hd > 15 * (1 + 1e-9)), sum(hd > 26 * (1 + 1e-9)), y$J, y$J / base$J - 1,
                abs(log(y$J / base$J)) / eps_lnJ))
  }
  # Where each capped program first departs from its uncapped rule run.
  for (k in grep("cap", names(x), value = TRUE)) {
    ref <- if (grepl("thinned", k)) x[["A thinned"]] else if (grepl("^unweighted", k)) x[["unweighted"]] else x[["rule A"]]
    a <- ref$st; b <- x[[k]]$st; n <- min(nrow(a), nrow(b))
    d <- which(a$time[1:n] != b$time[1:n] | a$h[1:n] != b$h[1:n])[1]
    cat(sprintf("   %-18s %s; steps at the cap: %d\n", k,
                if (is.na(d)) "identical to the uncapped run" else
                  sprintf("as the uncapped run to t = %.3f, then departs", if (d > 1) b$time[d - 1] else 0),
                sum(abs(b$h * 365 - as.numeric(sub(".*cap ", "", k))) < 1e-9)))
  }
}
