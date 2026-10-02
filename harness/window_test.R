# What the window rule (harness/window_rule.R) buys and moves, against the
# unweighted runs.
#
# On the driver (harness/ark_prototype.R logs): member evaluations, J - J* and the
# fixed-step lma elasticity, by central differences at 1e-5 on each run's own
# accepted steps (frozen_<run>_<+-1e-5> logs). That moves lma through TF24's
# hyperparameterisation, so it is not the gradient's lma; the resident lma's eps
# is its scale.
#
# On full-gradient runs (harness/run_record.R): ln J and every elasticity of both
# roles in units of eps (docs/measurements/eps.csv), against the unweighted run,
# and the cost in member-steps: the stand's accepted steps, each counting the
# members it carries, scaled by attempts over accepted steps where the stand was
# controlled, plus 7.3 for each accepted one. That is the spot-check's phases on
# PLANT-98 over its forward of 1.22 attempts a step: the stand's sweep 2.7
# forwards, the invader's walk 0.8 (less the resident's re-run, which PLANT-99
# drops) and its sweep 2.5.
#
#   [DRV=dir] [PROGS=dir:dir] [FULL=dir] [REF=dir] [WIN=dir] Rscript harness/window_test.R
#
# PROGS lists more directories holding driver OUT files, for the unweighted
# programs: a weighted program must repeat its unweighted one step for step up to
# the first step its weight scales.
here <- tryCatch(dirname(sys.frame(1)$ofile), error = function(e) "harness")
gd <- file.path(here, "..", "docs", "measurements", "grid-dynamics")
drv_dir <- Sys.getenv("DRV", "drv")
prog_dirs <- c(drv_dir, strsplit(Sys.getenv("PROGS", ""), ":")[[1]])
program_of <- function(f) {
  for (d in prog_dirs) if (file.exists(file.path(d, paste0(f, ".rds")))) return(readRDS(file.path(d, paste0(f, ".rds"))))
  NULL
}
full_dir <- Sys.getenv("FULL", "full")
ref_dir <- Sys.getenv("REF", "ref")
eps <- read.csv(file.path(here, "..", "docs", "measurements", "eps.csv"))
eps <- eps[eps$unit != "curvature in lma", ]
eps_lma <- eps$eps[eps$role == "resident" & eps$trait == "lma"]
eps_lnJ <- eps$eps[eps$role == "resident" & eps$trait == "ln J"]

log_of <- function(f) {
  for (d in c(drv_dir, gd)) if (file.exists(file.path(d, paste0(f, ".log"))))
    return(paste(readLines(file.path(d, paste0(f, ".log"))), collapse = "\n"))
  NULL
}
logged <- function(l, pattern) as.numeric(regmatches(l, regexec(pattern, l))[[1]][2])
J_of <- function(f) { l <- log_of(f); if (is.null(l)) NA else logged(l, "J ([0-9.e+-]+),") }
elasticity <- function(f) {
  u <- 1e-5
  log(J_of(sprintf("frozen_%s_1e-5", f)) / J_of(sprintf("frozen_%s_-1e-5", f))) / (log1p(u) - log1p(-u))
}
# J*: Cash-Karp at 1e-8, long drought's and the constant record's as recorded,
# the others plant's at 1e-8 under its default absolute tolerance (REF), since the
# tied 1e-12 cannot be met.
ref_J <- function(r) {
  known <- c("long-drought" = 12.6687135, constant = 289.2738962)
  if (r %in% names(known)) return(known[[r]])
  f <- file.path(ref_dir, sprintf("%s_1e-8_abs.rds", c("long-wet" = "wet", episodic = "epi", dry = "dry")[[r]]))
  if (file.exists(f) && !is.null(readRDS(f)$stand$J)) readRDS(f)$stand$J else NA
}

cat("== The time weight on the driver, tied 3e-5\n")
drivers <- list(
  "long-drought" = c(base = "tied_3e-5_soil1", late25 = "tied_3e-5_late25", "rule A" = "long-drought_rule",
                     "rule B" = "long-drought_ruleB", "A, thinned" = "long-drought_rule_thin"),
  "long-wet" = c(base = "long-wet_base", "rule A" = "long-wet_rule", "rule B" = "long-wet_ruleB",
                 "A, thinned" = "long-wet_rule_thin"),
  episodic = c(base = "episodic_base", "rule A" = "episodic_rule", "rule B" = "episodic_ruleB",
               "A, thinned" = "episodic_rule_thin"),
  constant = c(base = "ck_const_Gbf16_3e-5", late25 = "ck_const_Gbf16_3e-5_late25", "rule A" = "constant_rule",
               "rule B" = "constant_ruleB"))
for (r in names(drivers)) {
  Js <- ref_J(r)
  base <- NULL
  for (k in names(drivers[[r]])) {
    f <- drivers[[r]][[k]]
    l <- log_of(f)
    if (is.null(l)) next
    v <- c(accepted = logged(l, "([0-9]+) accepted"), members = logged(l, "member evaluations ([0-9]+)"),
           J = J_of(f), e = elasticity(f))
    if (k == "base") base <- v
    same <- ""
    a <- program_of(drivers[[r]][["base"]]); b <- program_of(f)
    if (k != "base" && !is.null(a) && !is.null(b$weight)) {
      n <- min(nrow(a$st), nrow(b$st))
      d <- which(a$st$time[1:n] != b$st$time[1:n] | a$st$h[1:n] != b$st$h[1:n])[1]
      first <- b$weight$t[which(b$weight$weight > 1)[1]]
      same <- sprintf(" | steps as unweighted to t = %.3f, weight from %.2f", b$st$time[d - 1], first)
    }
    cat(sprintf("%-12s %-13s %5d accepted, %.3g member evaluations (%+.1f%%) | J - J* %+.3g | lma %.5f (%+.4f eps) | J moves %+.2e (%.4f eps)%s\n",
                r, k, v[["accepted"]], v[["members"]],
                if (is.null(base)) NA else 100 * (v[["members"]] / base[["members"]] - 1),
                v[["J"]] / Js - 1, v[["e"]], if (is.null(base)) NA else (v[["e"]] - base[["e"]]) / eps_lma,
                if (is.null(base)) NA else v[["J"]] / base[["J"]] - 1,
                if (is.null(base)) NA else abs(log(v[["J"]] / base[["J"]])) / eps_lnJ, same))
  }
}

eps_of <- function(role, trait) {
  e <- eps$eps[eps$role == role & eps$trait == trait]
  if (length(e)) e[1] else NA
}
quantities <- function(x) {
  out <- c()
  for (role in c("stand", "invader")) {
    if (is.null(x[[role]]$elasticity)) next
    r <- if (role == "stand") "resident" else "invader"
    tr <- c("ln J", sub("^1[.]", "", names(x[[role]]$elasticity)))
    v <- c(log(x[[role]]$J), unname(x[[role]]$elasticity)) / vapply(tr, function(t) eps_of(r, t), 0)
    names(v) <- paste(r, tr)
    out <- c(out, v)
  }
  out[is.finite(out)]
}
main <- c("ln J", "lma", "a_dG2", "hmat", "stem_P50", "rho")
small <- c("a_st3", "a_d0", "omega", "a_l1")
cost_of <- function(x, attempts = NULL) {
  ms <- sum(as.numeric(findInterval(head(x$stand$times, -1), sort(x$node_times))))
  a <- if (is.null(attempts)) x$stand$attempts else attempts
  fw <- ms * (a[["accepted"]] + a[["rejected_inaccurate"]] + a[["rejected_thrown"]]) / a[["accepted"]]
  c(forward = fw, full = fw + 7.3 * ms)
}
driver_attempts <- function(f) {
  l <- log_of(f)
  if (is.null(l)) return(NULL)
  c(accepted = logged(l, "accepted=([0-9]+)"), rejected_inaccurate = logged(l, "rejected_inaccurate=([0-9]+)"),
    rejected_thrown = logged(l, "rejected_thrown=([0-9]+)"))
}
cat("\n== Every quantity of both roles, in eps, against the unweighted run: median and\n")
cat("   largest move by role over all quantities, and the largest over the main ones\n")
cat("   (outside the small four); cost against the unweighted run's\n")
sc <- file.path(here, "..", "docs", "measurements", "spot-check")
win <- Sys.getenv("WIN", "runs")
# The unweighted run, the rule's, the driver runs their programs came from, and
# where the unweighted invaders at the range's ends are when not in the first.
pairs <- list(
  "long-drought, the driver's program against plant's own (noise floor)" =
    c(file.path(sc, "ld_3e-5.rds"), "ld_pin_base", NA, "tied_3e-5_soil1", file.path(win, "win_long-drought_u108.rds")),
  "long-drought, time weight (pinned)" = c("ld_pin_base", "ld_pin_rule", "tied_3e-5_soil1", "long-drought_rule", NA),
  "episodic, time weight (pinned)" = c("epi_pin_base", "epi_pin_rule", "episodic_base", "episodic_rule", NA),
  "long-drought, nodes thinned" = c(file.path(sc, "ld_3e-5.rds"), "ld_thin_rule", NA, NA,
                                    file.path(win, "win_long-drought_u108.rds")),
  "long-wet, nodes thinned" = c(file.path(sc, "wet_base.rds"), "wet_thin_rule", NA, NA,
                                file.path(win, "win_long-wet_u108.rds")),
  "long-drought, both (pinned)" = c("ld_pin_base", "ld_pin_rule_thin", "tied_3e-5_soil1", "long-drought_rule_thin", NA))
path_of <- function(k) if (file.exists(k)) k else file.path(full_dir, paste0(k, ".rds"))
for (l in names(pairs)) {
  f <- vapply(pairs[[l]][1:2], path_of, "")
  if (!all(file.exists(f))) next
  x <- lapply(f, readRDS)
  for (i in 1:2) if (length(x[[i]]$failures))
    cat(l, c("unweighted", "rule")[i], "failures:", paste(names(x[[i]]$failures), substr(unlist(x[[i]]$failures), 1, 120),
                                                    collapse = "; "), "\n")
  inv0 <- if (is.na(pairs[[l]][5])) x[[1]] else readRDS(pairs[[l]][5])
  for (k in names(x[[2]]$invaders)) {
    J0 <- inv0$invaders[[k]]$J; J1 <- x[[2]]$invaders[[k]]$J
    if (!is.null(J0) && !is.null(J1))
      cat(sprintf("   invader %-9s ln J' %+.3f, moves %.4f eps\n", k, log(J1), abs(log(J1 / J0)) / eps_lnJ))
  }
  q <- lapply(x, quantities)
  k <- intersect(names(q[[1]]), names(q[[2]]))
  d <- abs(q[[2]][k] - q[[1]][k]); role <- sub(" .*", "", k); tr <- sub("^(resident|invader) ", "", k)
  c1 <- cost_of(x[[1]], driver_attempts(pairs[[l]][3])); c2 <- cost_of(x[[2]], driver_attempts(pairs[[l]][4]))
  cat(sprintf("%-36s %d quantities | cost forward %+.1f%%, full-gradient %+.1f%% | ln J %+.4f eps\n", l, length(k),
              100 * (c2[["forward"]] / c1[["forward"]] - 1), 100 * (c2[["full"]] / c1[["full"]] - 1),
              q[[2]][["resident ln J"]] - q[[1]][["resident ln J"]]))
  for (r in c("resident", "invader")) {
    s <- role == r; m <- s & tr %in% main
    cat(sprintf("   %-8s median %.4f, largest %.4f (%s); main largest %.4f (%s); over eps/10: %d, over eps/3: %d\n", r,
                median(d[s]), max(d[s]), tr[s][which.max(d[s])], max(d[m]), tr[m][which.max(d[m])],
                sum(d[s] > 0.1), sum(d[s] > 1 / 3)))
  }
  ph <- function(y) vapply(c("stand_run", "stand_gradient", "invader_run", "invader_gradient"),
                           function(p) if (is.null(y$phases[[p]])) NA else y$phases[[p]]$secs, 0)
  cat(sprintf("   phase seconds, unweighted / rule: %s\n",
              paste(sprintf("%s %.0f/%.0f", names(ph(x[[1]])), ph(x[[1]]), ph(x[[2]])), collapse = ", ")))
}

cat("\n== Rule B's program walked by the invaders at the range's ends (harness/invader_window.R\n")
cat("   with PROGRAM), against the pinned unweighted run's invaders: ln J' moves in eps\n")
short <- c("long-drought" = "ld", episodic = "epi")
for (r in names(short)) {
  f <- file.path(win, sprintf("walks_%s_ruleB.rds", r))
  b <- path_of(sprintf("%s_pin_base", short[[r]]))
  if (!file.exists(f) || !file.exists(b)) next
  y <- readRDS(f); x0 <- readRDS(b)
  cat(sprintf("%-28s %s\n", basename(f), paste(vapply(names(y$invaders), function(k) {
    v <- y$invaders[[k]]
    if (!is.null(v$error)) return(sprintf("%s raised at t = %s", k, sub(".*time=([0-9]+[.][0-9]+).*", "\\1", v$error)))
    sprintf("%s %.4f", k, abs(log(v$J / x0$invaders[[k]]$J)) / eps_lnJ)
  }, ""), collapse = ", ")))
}
