# Item 7's gates (prereg.txt here, 2026-10-07): P1 never fails, P2 accuracy, P3
# the nudge, on the window plant's control_window() reads off each pilot.
#   DEV=... Rscript pilot7.R
D <- Sys.getenv("DEV")
O <- file.path(D, "window_pilot")
G <- file.path(D, "soil_alone", "gates", "runs")
here <- if (nzchar(Sys.getenv("PLANT_DEV"))) Sys.getenv("PLANT_DEV") else "/home/user/plant-dev"
eps <- read.csv(file.path(here, "docs/measurements/eps.csv"))
eps_of <- function(role, trait) {
  e <- eps$eps[eps$role == role & eps$trait == trait & eps$unit != "curvature in lma"]
  if (length(e)) e[1] else NA
}
run <- function(dir, name) {
  f <- file.path(dir, paste0(name, ".rds"))
  if (file.exists(f)) readRDS(f)
}
records <- c(const = "constant", wet = "long-wet", epi = "episodic", dry = "dry",
             ld = "long-drought")
walks <- c("lma=0.5", "lma=2", "hmat=0.5", "hmat=2")
verdict <- function(ok) if (isTRUE(ok)) "holds" else "FAILS"
finite <- function(x) !is.null(x) && all(is.finite(x))
rows_of <- function(o) {
  n <- length(o$stand$times)
  sum(vapply(o$stand$times[-n], function(t) sum(o$node_times <= t), 0))
}
# Each entry of both roles, against another run's, in its eps.
moves <- function(a, b) {
  out <- list()
  for (role in c("stand", "invader")) {
    r <- if (role == "stand") "resident" else "invader"
    x <- a[[role]]; y <- b[[role]]
    if (is.null(x$elasticity) || is.null(y$elasticity)) next
    tr <- sub("^1\\.", "", names(x$elasticity))
    out[[role]] <- data.frame(role = r, trait = c("ln J", tr),
      move = abs(c(log(x$J), unname(x$elasticity)) - c(log(y$J), unname(y$elasticity))),
      eps = c(eps_of(r, "ln J"), vapply(tr, function(k) eps_of(r, k), 0)))
  }
  d <- do.call(rbind, out)
  d$over_eps <- d$move / d$eps
  d[!is.na(d$eps), ]
}
# A weight table read as the factor from each of its times on.
factor_at <- function(w, t) w$weight[pmax(findInterval(t, w$t), 1)]

for (tag in names(records)) {
  rec <- records[[tag]]
  p <- run(file.path(O, "runs"), paste0("p7_", rec))
  pn <- run(file.path(O, "runs"), paste0("p7n_", rec))
  b <- run(G, paste0("b5_", rec))
  cat(sprintf("== %s\n", rec))
  if (is.null(p) || is.null(pn)) { cat("   not run yet\n"); next }
  done <- !is.null(p$finished) && !length(p$failures) && !is.null(pn$finished) && !length(pn$failures)
  grads <- c(stand = finite(p$stand$gradient), invader = finite(p$invader$gradient),
             vapply(walks, function(k) finite(p$invaders[[k]]$gradient), TRUE))
  cat(sprintf("   P1: runs finished %s; gradients finite: %s  %s\n", done,
              paste(sprintf("%s %s", names(grads), grads), collapse = ", "),
              verdict(done && all(grads))))
  ref <- file.path(D, "bank", "runs", sprintf("%s_ref.rds", tag))
  eJ <- log(p$stand$J) - log(readRDS(ref)$stand$J)
  m <- moves(p, b)
  # Constant's invader gradient on uniform nodes is the artefact on record.
  if (rec == "constant") m <- m[m$role == "resident", ]
  worst <- m[which.max(m$over_eps), ]
  cat(sprintf("   P2: ln J against the bank's 1e-6 split %+.2e (at most 2.52e-4); against b5 the largest entry %.3f eps (%s %s), %d over eps/3  %s\n",
              eJ, worst$over_eps, worst$role, worst$trait, sum(m$over_eps >= 1 / 3),
              verdict(abs(eJ) <= 0.01 * eps_of("resident", "ln J") && all(m$over_eps < 1 / 3))))
  for (r in c("resident", "invader")) {
    k <- moves(pn, p)
    k <- k[k$role == r, ]
    gated <- !(r == "invader" && rec == "constant")
    cat(sprintf("   P3 %-8s %2d of %2d over eps/6; largest %.3f eps (%s)  %s\n", r,
                sum(k$over_eps > 1 / 6), nrow(k), max(k$over_eps), k$trait[which.max(k$over_eps)],
                if (gated) verdict(sum(k$over_eps > 1 / 6) == 0) else "not gated"))
  }
  w <- readRDS(file.path(O, sprintf("w_%s.rds", rec)))
  wh <- readRDS(file.path(D, "window", "rule_A", sprintf("weight_%s.rds", rec)))
  t <- sort(unique(c(w$t, wh$t)))
  fp <- factor_at(w, t); fh <- factor_at(wh, t)
  open <- fp < 100 & fh < 100
  cat(sprintf("   reported: pilot %.0f rows against p7's %.0f (%.2f); factors against the harness's, largest |ln ratio| %.2f, %.2f where both are under 100; p7's rows against b5's %+.1f%%\n",
              attr(w, "pilot")$rows, rows_of(p), attr(w, "pilot")$rows / rows_of(p),
              max(abs(log(fp / fh))), if (any(open)) max(abs(log(fp[open] / fh[open]))) else NA,
              100 * (rows_of(p) / rows_of(b) - 1)))
}
