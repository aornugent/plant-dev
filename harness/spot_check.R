# The step-3 spot-check from a directory of run_record.R outputs. Each record's
# base run at TOL on 108 nodes is checked against its companions, every quantity
# in units of its eps (docs/measurements/eps.csv), which is held across the bank:
# - a run at another tolerance passes where every move is under eps/6, half of
#   eps/3, since one companion samples the noise once;
# - a run on 54 nodes passes where every move is under eps: if the error falls as
#   the spacing squared, the 108-node error is a third of the move.
# It also reports each run's failures, refusals, invader check, census check and
# cost, and writes every move to OUT.
#
#   RUNS=dir [TOL=3e-5] [OUT=check.rds] Rscript harness/spot_check.R
runs_dir <- Sys.getenv("RUNS")
base_tol <- as.numeric(Sys.getenv("TOL", "3e-5"))
out_file <- Sys.getenv("OUT")
here <- tryCatch(dirname(sys.frame(1)$ofile), error = function(e) "harness")
eps <- read.csv(file.path(here, "..", "docs", "measurements", "eps.csv"))

runs <- lapply(Sys.glob(file.path(runs_dir, "*.rds")), readRDS)
names(runs) <- sub("\\.rds$", "", basename(Sys.glob(file.path(runs_dir, "*.rds"))))
setting <- do.call(rbind, lapply(names(runs), function(k) {
  s <- runs[[k]]$setting
  data.frame(run = k, regime = s$regime, seed = s$seed, tol = s$tol, nodes = s$nodes,
             shift = s$shift, finished = !is.null(runs[[k]]$finished))
}))

eps_of <- function(role, trait) {
  e <- eps$eps[eps$role == role & eps$trait == trait & eps$unit != "curvature in lma"]
  if (length(e)) e[1] else NA
}

# Every quantity's move from base to companion, over its eps, for both roles.
moves <- function(base, comp) {
  rows <- list()
  for (role in c("stand", "invader")) {
    r <- if (role == "stand") "resident" else "invader"
    a <- base[[role]]; b <- comp[[role]]
    if (is.null(a$elasticity) || is.null(b$elasticity)) next
    tr <- sub("^1\\.", "", names(a$elasticity))
    rows[[role]] <- data.frame(
      role = r, trait = c("ln J", tr),
      base = c(log(a$J), unname(a$elasticity)), companion = c(log(b$J), unname(b$elasticity)),
      eps = c(eps_of(r, "ln J"), vapply(tr, function(k) eps_of(r, k), 0)))
  }
  d <- do.call(rbind, rows)
  d$move <- abs(d$companion - d$base)
  d$over_eps <- d$move / d$eps
  d
}

run_facts <- function(k) {
  x <- runs[[k]]
  data.frame(run = k, failures = length(x$failures),
             refused = if (is.null(x$stand$attempts)) NA else x$stand$attempts[["rejected_refused"]],
             steps = length(x$stand$times),
             invader_J = if (is.null(x$invader$J)) NA else x$invader$J / x$stand$J - 1,
             census = if (is.null(x$stand$value)) NA else x$stand$value / x$stand$J - 1,
             secs = sum(vapply(x$phases, `[[`, 0, "secs")),
             peak_mb = max(vapply(x$phases, `[[`, 0, "peak_mb")))
}

checks <- list()
for (reg in unique(setting$regime)) {
  s <- setting[setting$regime == reg & setting$finished, ]
  base <- s$run[s$tol == base_tol & s$nodes == 108 & s$shift == 0]
  if (length(base) != 1) next
  for (k in setdiff(s$run, base)) {
    c_ <- s[s$run == k, ]
    kind <- if (c_$nodes != 108) "nodes" else if (c_$shift != 0) "shift" else "tolerance"
    d <- moves(runs[[base]], runs[[k]])
    d$limit <- if (kind == "nodes") 1 else 1 / 6
    checks[[k]] <- cbind(regime = reg, base = base, companion = k, kind = kind, d)
  }
}
all_moves <- do.call(rbind, checks)
facts <- do.call(rbind, lapply(names(runs), run_facts))

cat("== runs\n")
print(merge(setting, facts, by = "run"), row.names = FALSE, digits = 4)
cat("\n== checks: quantities with an eps, how many exceed the limit, and the largest\n")
for (k in names(checks)) {
  d <- checks[[k]]; d <- d[is.finite(d$over_eps), ]
  for (r in unique(d$role)) {
    e <- d[d$role == r, ]; top <- e[order(-e$over_eps), ][1:3, ]
    cat(sprintf("%-12s %-9s %-8s: %2d of %2d over %s; largest %s\n", k, e$kind[1], r,
                sum(e$over_eps > e$limit), nrow(e), if (e$limit[1] == 1) "eps" else "eps/6",
                paste(sprintf("%s %.3f", top$trait, top$over_eps), collapse = ", ")))
  }
}
if (nzchar(out_file)) saveRDS(list(setting = setting, facts = facts, moves = all_moves), out_file)
