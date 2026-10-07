# G5 and G6 (prereg.txt, 2026-10-07): the bank with the soil alone, from
# gates.sh bank's runs, against the split's bank references at 1e-6; and the
# cost, from gates.sh cost's timed runs.
#   DEV=... Rscript bank5.R
D <- Sys.getenv("DEV")
G <- file.path(D, "soil_alone", "gates", "runs")
here <- if (nzchar(Sys.getenv("PLANT_DEV"))) Sys.getenv("PLANT_DEV") else "/home/user/plant-dev"
eps <- read.csv(file.path(here, "docs/measurements/eps.csv"))
# Each entry's eps as the bank read it: no floor.
eps_of <- function(role, trait) {
  e <- eps$eps[eps$role == role & eps$trait == trait & eps$unit != "curvature in lma"]
  if (length(e)) e[1] else NA
}
run <- function(name) {
  f <- file.path(G, paste0(name, ".rds"))
  if (file.exists(f)) readRDS(f)
}
records <- c(const = "constant", wet = "long-wet", epi = "episodic", dry = "dry",
             ld = "long-drought")
verdict <- function(ok) if (isTRUE(ok)) "holds" else "FAILS"
finite <- function(x) !is.null(x) && all(is.finite(x))

cat("== G5.1, never fails: each run finished, each gradient finite, each walk ran\n")
for (tag in names(records)) {
  rec <- records[[tag]]
  runs <- c("b5_", "b5up_", "b5down_", "b5n_")
  out <- lapply(paste0(runs, rec), run)
  done <- vapply(out, function(x) !is.null(x$finished) && !length(x$failures), TRUE)
  b <- out[[1]]
  grads <- c(stand = finite(b$stand$gradient), invader = finite(b$invader$gradient),
             vapply(c("lma=0.5", "lma=2"), function(k) finite(b$invaders[[k]]$gradient), TRUE))
  cat(sprintf("   %-13s runs finished %d of 4; gradients finite: %s  %s\n", rec, sum(done),
              paste(sprintf("%s %s", names(grads), grads), collapse = ", "),
              verdict(all(done) && all(grads))))
}

cat("== G5.2, J' = J at the stand's traits; G5.3, the sweep against the replays' central difference\n")
for (tag in names(records)) {
  rec <- records[[tag]]
  b <- run(paste0("b5_", rec)); u <- run(paste0("b5up_", rec)); d <- run(paste0("b5down_", rec))
  if (is.null(b)) next
  cd <- if (is.null(u) || is.null(d)) NA else
    (log(u$stand$J) - log(d$stand$J)) / (log1p(1e-3) - log1p(-1e-3))
  sweep <- unname(b$stand$elasticity[["1.lma"]])
  cat(sprintf("   %-13s J' - J %.3g  %s; sweep %.9f, difference %.9f, gap %.2e  %s\n", rec,
              b$invader$J - b$stand$J, verdict(identical(b$invader$J, b$stand$J)), sweep, cd,
              sweep - cd, verdict(abs(sweep - cd) <= 2e-3)))
}

cat("== G5.4, ln J against the bank's split at 1e-6 (at most 0.01 eps, 2.52e-4)\n")
for (tag in names(records)) {
  rec <- records[[tag]]
  b <- run(paste0("b5_", rec))
  f <- file.path(D, "bank", "runs", sprintf("%s_ref.rds", tag))
  if (is.null(b) || !file.exists(f)) next
  e <- log(b$stand$J) - log(readRDS(f)$stand$J)
  cat(sprintf("   %-13s %+.2e  %s\n", rec, e, verdict(abs(e) <= 0.01 * eps_of("resident", "ln J"))))
}

# Every entry's move from base to nudge, in its eps, for both roles.
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
  d <- do.call(rbind, rows)
  d$over_eps <- d$move / d$eps
  d
}
cat("== G5.5, the nudge (tol x 1.05): entries over eps/6, and the largest\n")
for (tag in names(records)) {
  rec <- records[[tag]]
  b <- run(paste0("b5_", rec)); n <- run(paste0("b5n_", rec))
  if (is.null(b) || is.null(n)) next
  m <- moves(b, n)
  for (r in c("resident", "invader")) {
    k <- m[m$role == r & !is.na(m$eps), ]
    top <- k[which.max(k$over_eps), ]
    held <- sum(k$over_eps > 1 / 6) == 0 || (r == "invader" && rec == "constant")
    cat(sprintf("   %-13s %-9s %2d of %2d over eps/6; largest %.3f eps (%s)  %s\n", rec, r,
                sum(k$over_eps > 1 / 6), nrow(k), top$over_eps, top$trait,
                if (r == "invader" && rec == "constant") "not gated" else verdict(held)))
  }
}

cat("== G5, reported: steps, steps alone, node steps split, rows, and each phase's time (s)\n")
for (tag in names(records)) {
  rec <- records[[tag]]
  b <- run(paste0("b5_", rec))
  if (is.null(b)) next
  s <- b$stand
  n <- length(s$times)
  rows <- sum(vapply(s$times[-n], function(t) sum(b$node_times <= t), 0))
  secs <- vapply(b$phases, function(p) if (is.null(p$secs)) NA else p$secs, 0)
  cat(sprintf("   %-13s %d steps, %d alone, %d node steps split, %.0f rows; %s\n", rec, n - 1,
              sum(lengths(s$alone_steps) > 0), sum(s$splits), rows,
              paste(sprintf("%s %.0f", names(secs), secs), collapse = ", ")))
}

cat("== G6, the cost: each phase's time (s), alone against bnd, timed with nothing else running\n")
pairs <- lapply(1:2, function(k) list(alone = run(paste0("c6a", k)), bnd = run(paste0("c6b", k))))
if (all(vapply(pairs, function(p) !is.null(p$alone) && !is.null(p$bnd), TRUE))) {
  phases <- names(pairs[[1]]$alone$phases)
  for (ph in phases) {
    t <- vapply(pairs, function(p) c(p$alone$phases[[ph]]$secs, p$bnd$phases[[ph]]$secs), c(0, 0))
    cat(sprintf("   %-20s alone %s, bnd %s; alone over bnd %.3f\n", ph,
                paste(sprintf("%.1f", t[1, ]), collapse = " "),
                paste(sprintf("%.1f", t[2, ]), collapse = " "), mean(t[1, ] / t[2, ])))
  }
}
