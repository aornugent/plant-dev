# The PI test's tables, from the driver's OUT and ATTEMPT_LOG files in runs/.
#   Rscript analyse.R table name1 name2 ...      the run table
#   Rscript analyse.R taxonomy name1 [name2 ...] the rejection taxonomy (prereg.txt)
P <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/pi"
J_STAR <- c("long-drought" = 12.6687135, constant = 289.2738962)
DAY <- 1 / 365
NODE <- c("height", "mortality", "fecundity", "area_heartwood", "mass_heartwood",
          "storage", "offspring", "log_density", "mass")

load_run <- function(name) {
  run <- readRDS(file.path(P, "runs", paste0(name, ".rds")))
  att_file <- file.path(P, "runs", paste0("att_", name, ".rds"))
  a <- if (file.exists(att_file)) readRDS(att_file) else NULL
  list(name = name, run = run, a = a)
}

classify <- function(run, a) {
  knots <- sort(unique(run$knots))
  i <- findInterval(a$t0 + 1e-12, knots)
  since <- ifelse(i > 0, (a$t0 - knots[pmax(i, 1)]) / DAY, Inf)
  on_knot <- a$t0 > 0 & since <= 0.001
  rej <- a$rejected == 1
  overshoot <- a$try == 1 & a$h == a$proposal & !is.na(a$f_set) & a$f_set >= 1.5
  stability <- !is.na(a$x_soil) & a$x_soil >= 0.8
  crossing <- !is.na(a$cross_bind) & a$cross_bind == 1
  # Six evaluations an attempt that completes, each of M members.
  M <- ifelse(a$thrown == 1, NA, a$members / 6)
  part <- ifelse(a$thrown == 1, "thrown", ifelse(a$index <= 9 * M, NODE[(a$index - 1) %% 9 + 1],
                 ifelse(a$index - 9 * M <= 5, "soil", "accumulator")))
  empty <- !is.na(part) & part == "storage" & pmin(a$fill_start, a$fill_end) < 0.01
  cls <- ifelse(on_knot, "knot", ifelse(overshoot, "overshoot", ifelse(stability, "stability",
           ifelse(crossing, "crossing", ifelse(empty, "empty pool", "other")))))
  intro <- a$t0 %in% run$by_node$time & a$t0 > 0
  data.frame(rej, on_knot, overshoot, stability, crossing, empty, cls, part, intro,
             members = a$members, try = a$try, f_set = a$f_set, r_set = a$r_set, x_soil = a$x_soil,
             crossed = a$crossed, h = a$h, t0 = a$t0, since)
}

row_of <- function(x) {
  run <- x$run
  Jstar <- J_STAR[[run$regime]]
  out <- data.frame(run = x$name, control = if (is.null(run$control)) "odelia" else run$control,
                    tol = run$tol, accepted = run$attempts[["accepted"]] + run$attempts[["accepted_at_minimum"]],
                    rejected = sum(run$attempts[c("rejected_inaccurate", "rejected_thrown", "rejected_refused")]),
                    thrown = run$attempts[["rejected_thrown"]],
                    on_knots = NA, elsewhere = NA, members = run$counts$members,
                    err = run$J / Jstar - 1, J = run$J)
  if (!is.null(x$a)) {
    d <- classify(run, x$a)
    out$on_knots <- sum(d$rej & d$on_knot)
    out$elsewhere <- sum(d$rej & !d$on_knot)
    stopifnot(sum(!d$rej) == out$accepted, sum(d$rej) == out$rejected)
  }
  out
}

args <- commandArgs(TRUE)
if (length(args) && args[1] == "table") {
  tab <- do.call(rbind, lapply(args[-1], function(n) row_of(load_run(n))))
  tab$err <- sprintf("%+.3g", tab$err)
  tab$J <- sprintf("%.9f", tab$J)
  print(tab, row.names = FALSE)
}
if (length(args) && args[1] == "taxonomy") {
  for (n in args[-1]) {
    x <- load_run(n)
    d <- classify(x$run, x$a)
    r <- d[d$rej, ]
    lev <- c("knot", "overshoot", "stability", "crossing", "empty pool", "other")
    cat(sprintf("\n== %s: %d rejected or thrown, %.4g member evaluations in them (%.1f%% of the run's)\n",
                n, nrow(r), sum(r$members), 100 * sum(r$members) / x$run$counts$members))
    tb <- data.frame(class = lev,
                     count = as.vector(table(factor(r$cls, lev))),
                     member_evals = as.vector(tapply(r$members, factor(r$cls, lev), sum)))
    tb$member_evals[is.na(tb$member_evals)] <- 0
    tb$share <- sprintf("%.1f%%", 100 * tb$count / nrow(r))
    print(tb, row.names = FALSE)
    cat("by binding part within each class:\n")
    print(table(factor(r$cls, lev), r$part))
    cat("overlaps (rejected attempts meeting each test, any order):\n")
    flags <- r[, c("on_knot", "overshoot", "stability", "crossing", "empty")]
    print(crossprod(as.matrix(flags) * 1))
    cat(sprintf("other: at an introduction %d; retries (try > 1) %d; within a day of a knot %d; 1-10 days %d; over 10 days %d; any member crossing in the attempt %d\n",
                sum(r$cls == "other" & r$intro), sum(r$cls == "other" & r$try > 1),
                sum(r$cls == "other" & r$since > 0.001 & r$since <= 1), sum(r$cls == "other" & r$since > 1 & r$since <= 10),
                sum(r$cls == "other" & r$since > 10), sum(r$cls == "other" & !is.na(r$crossed) & r$crossed > 0)))
    o <- r[r$cls == "other", ]
    if (nrow(o)) {
      cat("other, by try and part:\n"); print(table(pmin(o$try, 3), o$part))
      cat("other, first tries: growth factor that set the proposal, 10/50/90%:",
          signif(quantile(o$f_set[o$try == 1], c(.1, .5, .9), na.rm = TRUE), 3),
          "| ratio then:", signif(quantile(o$r_set[o$try == 1], c(.1, .5, .9), na.rm = TRUE), 3), "\n")
    }
  }
}
