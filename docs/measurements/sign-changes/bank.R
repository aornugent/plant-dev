# The eighteenth extension's gates (prereg.txt) from bank.sh's runs.
#   RUNS=dir Rscript bank.R
runs_dir <- Sys.getenv("RUNS")
here <- tryCatch(dirname(normalizePath(sub("^--file=", "",
  grep("^--file=", commandArgs(FALSE), value = TRUE)))), error = function(e) ".")
eps <- read.csv(file.path(here, "..", "eps.csv"))
eps_of <- function(role, trait) {
  e <- eps$eps[eps$role == role & eps$trait == trait & eps$unit != "curvature in lma"]
  if (length(e)) e[1] else NA
}
read_run <- function(tag, kind) {
  f <- file.path(runs_dir, sprintf("%s_%s.rds", tag, kind))
  if (file.exists(f)) readRDS(f) else NULL
}
records <- c(const = "constant", wet = "long-wet", epi = "episodic", dry = "dry",
             ld = "long-drought")
secs <- function(x, phase) if (is.null(x$phases[[phase]])) NA else x$phases[[phase]]$secs

cat("G1, never fails: runs with a failure, or unfinished\n")
for (tag in names(records)) for (kind in c("split", "plain", "nsplit", "nplain", "ref", "up", "down")) {
  x <- read_run(tag, kind)
  if (is.null(x)) { cat(sprintf("  %-5s %-6s missing\n", tag, kind)); next }
  if (length(x$failures) || is.null(x$finished)) {
    cat(sprintf("  %-5s %-6s %s\n", tag, kind,
                if (length(x$failures)) paste(names(x$failures), unlist(x$failures), sep = ": ", collapse = "; ")
                else "unfinished"))
  }
}

cat("\nG2, J' = J, and G3, the sweep against the replays' central difference in lma\n")
cat(sprintf("  %-13s %-12s %-14s %-14s %-11s\n", "record", "J' - J", "sweep", "difference", "gap"))
for (tag in names(records)) {
  s <- read_run(tag, "split"); u <- read_run(tag, "up"); d <- read_run(tag, "down")
  if (is.null(s)) next
  jj <- if (is.null(s$invader$J)) NA else s$invader$J - s$stand$J
  sweep <- if (is.null(s$stand$elasticity)) NA else unname(s$stand$elasticity[["1.lma"]])
  cd <- if (is.null(u) || is.null(d)) NA else
    (log(u$stand$J) - log(d$stand$J)) / (log1p(1e-3) - log1p(-1e-3))
  cat(sprintf("  %-13s %-12.3g %-14.9f %-14.9f %-11.2e\n", records[[tag]], jj, sweep, cd,
              sweep - cd))
}

cat("\nG4, ln J against the reference at 1e-6 (split forward)\n")
cat(sprintf("  %-13s %-16s %-11s %-11s %-11s %-11s\n", "record", "ln J ref", "split",
            "split x1.05", "plain", "plain x1.05"))
for (tag in names(records)) {
  ref <- read_run(tag, "ref")
  if (is.null(ref)) next
  e <- function(kind) {
    x <- read_run(tag, kind)
    if (is.null(x$stand$J)) NA else log(x$stand$J) - log(ref$stand$J)
  }
  cat(sprintf("  %-13s %-16.12f %-11.2e %-11.2e %-11.2e %-11.2e\n", records[[tag]],
              log(ref$stand$J), e("split"), e("nsplit"), e("plain"), e("nplain")))
}

# Every quantity's move from base to nudge, in units of its eps, for both roles.
moves <- function(base, comp) {
  rows <- list()
  for (role in c("stand", "invader")) {
    r <- if (role == "stand") "resident" else "invader"
    a <- base[[role]]; b <- comp[[role]]
    if (is.null(a$elasticity) || is.null(b$elasticity)) next
    tr <- sub("^1\\.", "", names(a$elasticity))
    rows[[role]] <- data.frame(
      role = r, trait = c("ln J", tr),
      move = abs(c(log(b$J), unname(b$elasticity)) - c(log(a$J), unname(a$elasticity))),
      eps = c(eps_of(r, "ln J"), vapply(tr, function(k) eps_of(r, k), 0)))
  }
  if (!length(rows)) return(NULL)
  d <- do.call(rbind, rows)
  d$over_eps <- d$move / d$eps
  d
}
cat("\nG5, the nudge (tol x1.05): entries over eps/6, of those with an eps, and the largest\n")
for (tag in names(records)) for (arm in c("split", "plain")) {
  b <- read_run(tag, arm); n <- read_run(tag, paste0("n", arm))
  if (is.null(b) || is.null(n)) next
  m <- moves(b, n)
  if (is.null(m)) next
  for (r in c("resident", "invader")) {
    k <- m[m$role == r & !is.na(m$eps), ]
    if (!nrow(k)) next
    top <- k[which.max(k$over_eps), ]
    cat(sprintf("  %-13s %-6s %-9s %2d of %2d over eps/6; largest %.3f eps (%s), median %.3f\n",
                records[[tag]], arm, r, sum(k$over_eps > 1 / 6), nrow(k), top$over_eps,
                top$trait, median(k$over_eps)))
  }
}

cat("\nG6, the splits and each phase's time (s) on a shared machine, split against plain\n")
cat(sprintf("  %-13s %-8s %-6s %-15s %-15s %-15s %-15s\n", "record", "splits", "nodes",
            "stand run", "stand gradient", "walk", "walk gradient"))
for (tag in names(records)) {
  s <- read_run(tag, "split"); p <- read_run(tag, "plain")
  if (is.null(s) || is.null(p)) next
  pair <- function(phase) sprintf("%.0f/%.0f", secs(s, phase), secs(p, phase))
  cat(sprintf("  %-13s %-8d %-6d %-15s %-15s %-15s %-15s\n", records[[tag]],
              sum(s$stand$splits), sum(s$stand$splits > 0), pair("stand_run"),
              pair("stand_gradient"), pair("invader_run"), pair("invader_gradient")))
}

cat("\nThe stand's longest step, which a walk takes as it is; the lma x 2 invader's pools are unstable\n")
cat("past 26.1 days, Cash-Karp's limit at their relaxation time (grid-dynamics.md section 8); the\n")
cat("floor caps steps at 15\n")
for (tag in names(records)) for (kind in c("split", "plain")) {
  x <- read_run(tag, kind)
  if (is.null(x$stand$times)) next
  h <- diff(x$stand$times) * 365
  cat(sprintf("  %-13s %-6s %.2f days at year %.3f; %d steps over 26.1 days, %d over 15\n",
              records[[tag]], kind, max(h), x$stand$times[-1][which.max(h)], sum(h > 26.1),
              sum(h > 15)))
}

cat("\nThe invaders at lma x 0.5 and x 2 on the split base: J', and each walk's and gradient's outcome\n")
for (tag in names(records)) {
  s <- read_run(tag, "split")
  if (is.null(s)) next
  for (name in c("lma=0.5", "lma=2")) {
    v <- s$invaders[[name]]
    g <- s$phases[[paste(name, "gradient")]]
    cat(sprintf("  %-13s %-8s J' %-12s gradient %s\n", records[[tag]], name,
                if (is.null(v$J)) "none" else format(v$J, digits = 8),
                if (is.null(g)) "not run" else if (isTRUE(g$ok)) "ok" else "failed"))
  }
}
cat("JOB DONE bank.R\n")
