# The step-3 spot-check from a directory of run_record.R outputs. A base run is
# one on 108 nodes at a tolerance in TOLS; each other run is checked against the
# base it companions, every quantity in units of its eps
# (docs/measurements/eps.csv), which is held across the bank:
# - a run within 6% of the base's tolerance passes where every move is under
#   eps/6, half of eps/3, since one companion samples the noise once;
# - a run on n nodes at the base's tolerance estimates the 108-node error from
#   the move, if the error falls as the spacing squared, and passes where that
#   estimate is under eps/3.
# It also reports each run's failures, refusals, invader check, census check and
# cost. OUT receives runs.csv (one row per run), checks.csv (one per check and
# role) and moves.csv (every quantity's move).
#
#   RUNS=dir [TOLS=3e-5,1e-5] [OUT=dir] Rscript harness/spot_check.R
runs_dir <- Sys.getenv("RUNS")
base_tols <- as.numeric(strsplit(Sys.getenv("TOLS", "3e-5,1e-5"), ",")[[1]])
out_dir <- Sys.getenv("OUT")
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

is_base <- function(r) r$nodes == 108 & r$shift == 0 & r$tol %in% base_tols
checks <- list()
for (reg in unique(setting$regime)) {
  s <- setting[setting$regime == reg & setting$finished, ]
  bases <- s[is_base(s), ]
  for (k in s$run[!is_base(s)]) {
    c_ <- s[s$run == k, ]
    near <- abs(c_$tol / bases$tol - 1)
    b <- if (c_$nodes == 108) bases[near <= 0.06, ] else bases[near < 1e-12, ]
    if (nrow(b) != 1) next
    kind <- if (c_$nodes != 108) "nodes" else if (c_$shift != 0) "shift" else "tolerance"
    d <- moves(runs[[b$run]], runs[[k]])
    if (kind == "nodes") {
      # The base's error from the move, if it falls as the spacing squared.
      d$over_eps <- d$over_eps / abs((108 / c_$nodes)^2 - 1)
      d$limit <- 1 / 3
    } else {
      d$limit <- 1 / 6
    }
    checks[[k]] <- cbind(regime = reg, base = b$run, companion = k, kind = kind,
                         nodes = c_$nodes, d)
  }
}
all_moves <- do.call(rbind, checks)
runs_table <- merge(setting, do.call(rbind, lapply(names(runs), run_facts)), by = "run")

# The traits step 1 takes curvatures in, with ln J.
main <- c("ln J", "lma", "a_dG2", "hmat", "stem_P50", "rho")

# How many quantities of one check and role exceed the limit and eps, the
# largest, and the largest of the main traits.
check_row <- function(d) {
  d <- d[is.finite(d$over_eps), ]
  top <- d[which.max(d$over_eps), ]
  m <- d[d$trait %in% main, ]
  top_main <- m[which.max(m$over_eps), ]
  data.frame(d[1, c("regime", "base", "companion", "kind", "nodes", "role", "limit")],
             n = nrow(d), n_over_limit = sum(d$over_eps > d$limit),
             n_over_eps = sum(d$over_eps > 1),
             largest = top$trait, largest_over_eps = top$over_eps,
             main_largest = top_main$trait, main_largest_over_eps = top_main$over_eps,
             lnJ_over_eps = c(d$over_eps[d$trait == "ln J"], NA)[1])
}
checks_table <- do.call(rbind, lapply(
  split(all_moves, list(all_moves$companion, all_moves$role), drop = TRUE), check_row))

cat("== runs\n")
print(runs_table, row.names = FALSE, digits = 4)
cat("\n== checks: over_eps is the move over eps, and for a node check the estimated",
    "108-node error over eps\n")
print(checks_table, row.names = FALSE, digits = 3)
if (nzchar(out_dir)) {
  write.csv(runs_table, file.path(out_dir, "runs.csv"), row.names = FALSE)
  write.csv(checks_table, file.path(out_dir, "checks.csv"), row.names = FALSE)
  write.csv(all_moves, file.path(out_dir, "moves.csv"), row.names = FALSE)
}
