# Every quantity of both roles in eps (docs/measurements/eps.csv), between pairs
# of full-gradient replays, as harness/window_test.R scores them: rule A and the
# capped programs against the unweighted run, the unweighted run capped against
# the unweighted run (the cap's own move), and rule A capped against the
# unweighted run capped (the weight's move under the cap). Each move is also set
# against long drought's +-5% tolerance nudge at 3e-5 for that quantity
# (nudge_spread.R). Then every invader walk, its J' and whether it raised, with
# its ln J' move against the unweighted run's invader.
#
#   Rscript quantities.R
D <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev"
WT <- "/home/user/plant-dev/.claude/worktrees/agent-a12cdeaf09a1e3e8a"
source(file.path(D, "phase1c/nudge_spread.R"))  # eps, eps_of, quantities, nudge
eps_lnJ <- eps$eps[eps$role == "resident" & eps$trait == "ln J"]
main <- c("ln J", "lma", "a_dG2", "hmat", "stem_P50", "rho")
f_of <- function(p) file.path(D, p)
files <- list(
  "long-drought" = list(unweighted = f_of("window/full/ld_pin_base.rds"), "rule A" = f_of("window/full/ld_pin_rule.rds"),
                        "A, cap 15" = f_of("phase1c/full/ld_h15.rds"), "A, cap 22" = f_of("phase1c/full/ld_h22.rds"),
                        "A, cap 26" = f_of("phase1c/full/ld_h26.rds"),
                        "unweighted, cap 15" = f_of("phase1c/full/ld_base_h15.rds")),
  "long-wet" = list(unweighted = file.path(WT, "docs/measurements/spot-check/wet_base.rds"),
                    "rule A" = f_of("phase1c/full/wet_ruleA.rds"),
                    "A, cap 15" = f_of("phase1c/full/wet_h15.rds"), "A, cap 26" = f_of("phase1c/full/wet_h26.rds"),
                    "unweighted, cap 15" = f_of("phase1c/full/wet_base_h15.rds")),
  episodic = list(unweighted = f_of("window/full/epi_pin_base.rds"), "rule A" = f_of("window/full/epi_pin_rule.rds"),
                  "A, cap 15" = f_of("phase1c/full/epi_h15.rds"), "A, cap 22" = f_of("phase1c/full/epi_h22.rds"),
                  "A, cap 26" = f_of("phase1c/full/epi_h26.rds"),
                  "unweighted, cap 15" = f_of("phase1c/full/epi_base_h15.rds")))
pairs <- list(c("unweighted", "rule A"), c("unweighted", "A, cap 15"), c("unweighted", "A, cap 22"),
              c("unweighted", "A, cap 26"),
              c("unweighted", "unweighted, cap 15"), c("unweighted, cap 15", "A, cap 15"))
# The unweighted invaders at the range ends, where the full run lacks them, and
# the x0.7 and x1.4 ones walked by harness/invader_window.R.
inv0 <- list("long-drought" = f_of("window/full/ld_pin_base.rds"), "long-wet" = f_of("window/runs/win_long-wet_u108.rds"),
             episodic = f_of("window/full/epi_pin_base.rds"))
inner0 <- list("long-drought" = f_of("phase1c/walks/ld_base_inner.rds"), "long-wet" = f_of("phase1c/walks/wet_base_inner.rds"),
               episodic = f_of("phase1c/walks/epi_base_inner.rds"))
J0_of <- function(r, k) {
  v <- readRDS(inv0[[r]])$invaders[[k]]$J
  if (is.null(v) && file.exists(inner0[[r]])) v <- readRDS(inner0[[r]])$invaders[[k]]$J
  v
}
done <- function(f) file.exists(f) && !is.null(readRDS(f)$finished)

cat("== Every quantity of both roles, in eps: the second run of each pair against the first\n")
for (r in names(files)) {
  for (pr in pairs) {
    f <- unlist(files[[r]][pr])
    if (length(f) != 2 || !all(vapply(f, done, TRUE))) next
    x <- lapply(f, readRDS); q <- lapply(x, quantities)
    n <- intersect(names(q[[1]]), names(q[[2]]))
    d <- abs(q[[2]][n] - q[[1]][n]); role <- sub(" .*", "", n); tr <- sub("^(resident|invader) ", "", n)
    nn <- intersect(n, names(nudge))
    cat(sprintf("%-12s %-18s against %-18s %d quantities | resident ln J %+.4f | largest %.4f (%s) | over 0.08: %d, over 0.1: %d | over the 3e-5 nudge's spread: %d of %d | failures: %s\n",
                r, pr[2], pr[1], length(n), q[[2]][["resident ln J"]] - q[[1]][["resident ln J"]], max(d), n[which.max(d)],
                sum(d > 0.08), sum(d > 0.1), sum(d[nn] > nudge[nn]), length(nn),
                if (length(x[[2]]$failures)) paste(names(x[[2]]$failures), collapse = ", ") else "none"))
    for (ro in c("resident", "invader")) {
      s <- role == ro; m <- s & tr %in% main
      if (!any(s)) next
      o <- order(-d[s])[1:3]
      cat(sprintf("   %-8s median %.4f, largest %s; main largest %.4f (%s)\n", ro, median(d[s]),
                  paste(sprintf("%.4f (%s)", d[s][o], tr[s][o]), collapse = ", "), max(d[m]), tr[m][which.max(d[m])]))
    }
  }
}

cat("\n== Every invader walk: J', and its ln J' move against the unweighted run's in eps\n")
skip <- c("stand_run", "stand_gradient", "invader_run", "invader_gradient")
for (r in names(files)) {
  for (k in setdiff(names(files[[r]]), "unweighted")) {
    f <- files[[r]][[k]]
    if (!file.exists(f)) next
    x <- readRDS(f)
    invs <- setdiff(names(x$phases), skip)
    cat(sprintf("%-12s %-18s (plant's replay with gradients%s): stand %s; identical invader %s\n", r, k,
                if (is.null(x$finished)) ", still running" else "",
                if (!is.null(x$failures$stand_run)) "RAISED" else sprintf("J %.8g", x$stand$J),
                if (!is.null(x$failures$invader_run)) "RAISED" else if (is.null(x$invader$J)) "not yet" else
                  sprintf("J' %.8g", x$invader$J)))
    for (inv in invs) {
      J1 <- x$invaders[[inv]]$J; J0 <- J0_of(r, inv)
      cat(sprintf("   %-9s %s%s\n", inv,
                  if (!is.null(x$failures[[inv]])) paste("RAISED:", substr(x$failures[[inv]], 1, 160)) else sprintf("J' %-12.6g", J1),
                  if (!is.null(J1) && !is.null(J0)) sprintf(" ln J' %+.3f, moves %.4f eps", log(J1), abs(log(J1 / J0)) / eps_lnJ) else ""))
    }
  }
}
short <- c("long-drought" = "ld", "long-wet" = "wet", episodic = "epi")
for (r in names(short)) for (h in c("h15", "h20", "h22", "h26", "thin_h15", "base_inner")) {
  f <- f_of(sprintf("phase1c/walks/%s_%s.rds", short[[r]], h))
  if (!file.exists(f)) next
  y <- readRDS(f)
  cat(sprintf("%-12s walks on %s (harness/invader_window.R): stand J %.8g, %d steps\n", r, h, y$stand$J,
              length(y$stand$times)))
  for (inv in names(y$invaders)) {
    v <- y$invaders[[inv]]; J0 <- J0_of(r, inv)
    cat(sprintf("   %-9s %s%s\n", inv,
                if (!is.null(v$error)) paste("RAISED:", substr(v$error, 1, 160)) else sprintf("J' %-12.6g", v$J),
                if (is.null(v$error) && !is.null(J0) && h != "base_inner")
                  sprintf(" ln J' %+.3f, moves %.4f eps", log(v$J), abs(log(v$J / J0)) / eps_lnJ) else ""))
  }
}
