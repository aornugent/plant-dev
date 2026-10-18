# loop_run.R: the loop's run(s) for one case, real or under a stress draw, and P5's constant.
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/loop/lib.R")
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/loop/loop.R")
RUNSH <- "/home/user/plant-dev/docs/measurements/schedule-search/rootcause/loop/run.sh"
ep_name <- function(cs, s) sprintf("ep%.3f_%s", s, cs)
# A finished run of exactly this schedule, or NULL.
ep_read <- function(cs, s) { f <- file.path(LO, "runs", paste0(ep_name(cs, s), ".rds")); if (!file.exists(f)) return(NULL)
  x <- readRDS(f); if (is.null(x$finished) || is.null(x$stand$elasticity) || !identical(x$node_times, ep_sched(cs, s))) return(NULL); x }
ep_summary <- function(cs, x) { d <- drop_set(cs, x$node_times); stopifnot(identical(as.integer(x$dropped), as.integer(d$drop)))
  list(q = qv(x), rows = x$stand$rows, map = map_lnJ(x, d$region)[["all"]], cpu = x$stand$cpu + x$sweep_cpu) }
# The real run: from disk when this exact schedule has run, otherwise through run.sh.
real_run <- function(cs, log = NULL) function(s) { x <- ep_read(cs, s)
  if (is.null(x)) { nm <- ep_name(cs, s); prep(cs, ep_sched(cs, s), nm); if (!is.null(log)) cat(sprintf("  launching %s\n", nm), file = log, append = TRUE)
    system2(RUNSH, paste0(nm, "/", cs), env = "P=1"); x <- ep_read(cs, s); if (is.null(x)) stop("run failed: ", nm) }
  ep_summary(cs, x) }
# P5's constant: E6's bank ladder, W_c / S_el of its s = 1.6 run, geometric mean over the bank
# cases other than cs.
sel_scale_of <- function(cs) { el <- setdiff(Q, "lnJ")
  r <- vapply(BANK, function(b) { l <- LAD$L[[b]]; max(abs((l$runs$c$q - l$ref) / EPS)) / sqrt(mean((l$runs$x$q[el] / EPS[el])^2)) }, 0)
  exp(mean(log(r[setdiff(BANK, cs)]))) }
# A stress draw's run(s): truth + perturbation. Stored spacings read their run; any other
# spacing is read linearly in s^2 between the two nearest stored runs (end segments extended),
# plus jitter for the interpolated part (b_loop's meas mode). The map gets N(0, 0.02^2).
stress_run <- function(store, ref, d, noise, cid) {
  ss <- sort(as.numeric(names(store))); err <- lapply(store, function(z) (z$q - ref) / EPS)
  set.seed(7e8 + cid * 1e4 + d); miss <- if (noise == "coord") rnorm(length(Q), 0, 0.025) else 0
  function(s) { set.seed(9e8 + cid * 1e7 + d * 1e4 + round(s * 1000))
    pert <- if (noise == "coord") rnorm(length(Q), 0, 0.04) else rnorm(length(Q), 0, 0.02) + 0.09 * rnorm(1) * M
    k <- which(abs(ss - s) < 1e-6)
    if (length(k)) { z <- store[[sprintf("%.6f", ss[k])]]; e <- err[[sprintf("%.6f", ss[k])]]; mp <- z$map; rows <- z$rows }
    else { i <- findInterval(s, ss); i <- min(max(i, 1), length(ss) - 1); a <- sprintf("%.6f", ss[i]); b <- sprintf("%.6f", ss[i + 1])
      w <- (ss[i + 1]^2 - s^2) / (ss[i + 1]^2 - ss[i]^2)
      e <- w * err[[a]] + (1 - w) * err[[b]] + sqrt(max(0, 1 - w^2 - (1 - w)^2)) * (rnorm(length(Q), 0, 0.02) + 0.09 * rnorm(1) * M)
      mp <- w * store[[a]]$map + (1 - w) * store[[b]]$map
      rows <- exp(log(store[[a]]$rows) + (log(s) - log(ss[i])) * (log(store[[b]]$rows) - log(store[[a]]$rows)) / (log(ss[i + 1]) - log(ss[i]))) }
    list(q = ref + (e + miss + pert) * EPS, rows = rows, map = mp + rnorm(1, 0, 0.02), e = e) } }
# Runs requested, not launched: a missing run is prepared, its job written to REQ, and the
# case's loop stops with class "need_run"; the shell runs the jobs in parallel lanes and the
# drivers start again. The loops are deterministic given their runs, so replaying them from
# the stored runs takes the same path a sequential driver would.
REQ <- Sys.getenv("REQ", file.path(LO, "requests.txt"))
need_run <- function(name, cs) { cat(paste0(name, "/", cs, "\n"), file = REQ, append = TRUE)
  stop(structure(class = c("need_run", "error", "condition"), list(message = paste("need", name), call = NULL))) }
read_run <- function(name, S) { f <- file.path(LO, "runs", paste0(name, ".rds")); if (!file.exists(f)) return(NULL)
  x <- readRDS(f); if (is.null(x$finished) || is.null(x$stand$elasticity) || !identical(x$node_times, S)) return(NULL); x }
ep_request <- function(cs) function(s) { S <- ep_sched(cs, s); nm <- ep_name(cs, s); x <- read_run(nm, S)
  if (is.null(x)) { prep(cs, S, nm); need_run(nm, cs) }; ep_summary(cs, x) }
rb_name <- function(cs, sv) paste0("rb_", cs, "_", paste(sprintf("%.3f", sv[RB_REG]), collapse = "_"))
rb_request <- function(cs) function(sv) { S <- rb_sched(cs, sv); nm <- rb_name(cs, sv); x <- read_run(nm, S)
  if (is.null(x)) { prep(cs, S, nm); need_run(nm, cs) }
  m <- map_by_era(cs, x); mp <- setNames(rep(0, length(RB_REG)), RB_REG); for (g in intersect(names(m), RB_REG)) mp[g] <- m[[g]]
  list(q = qv(x), rows = x$stand$rows, map = c(mp, all = m[["all"]]), region_rows = region_rows(cs, x)) }
