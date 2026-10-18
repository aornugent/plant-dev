# fr_run.R: one case's frontier runs in one process, one SCM at a time. The first run is shared;
# each configuration scale:tol is a level-0 run plus its pinned half replay, saved as it ends.
#   PLANT_LIB=<libNS> Rscript fr_run.R CASE OUTDIR 1:1e-4,0.7:1e-4[,1:3e-4][,1:3e-5:0]
# A third field of 0 skips the replay.
source("/home/user/plant-dev/harness/long_drought.R")
source("/home/user/plant-dev/harness/schedule/refine.R")
WEIGHTS <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/window/rule_A"
CASES <- list(
  dry = list(rec = "dry", trait = c(), weight = "dry"),
  `long-wet` = list(rec = "long-wet", trait = c(), weight = "long-wet"),
  `episodic-lma` = list(rec = "episodic", trait = c(lma = 1.25), weight = "episodic"),
  `dry-flat` = list(rec = "dry-flat", trait = c(), weight = "dry"),
  `epi-adG208` = list(rec = "episodic", trait = c(a_dG2 = 0.8), weight = "episodic"),
  episodic = list(rec = "episodic", trait = c(), weight = "episodic"),
  `dry-lma125` = list(rec = "dry", trait = c(lma = 1.25), weight = "dry"),
  `ld104-p50125` = list(rec = "long-drought", seed = 104, trait = c(root_P50 = 1.25), weight = "long-drought"))
a <- commandArgs(TRUE); cs <- a[1]; out <- a[2]; case <- CASES[[cs]]
cfgs <- lapply(strsplit(strsplit(a[3], ",")[[1]], ":"), as.numeric)
dir.create(out, showWarnings = FALSE, recursive = TRUE)

rec <- case$rec
if (!is.null(case$seed)) { rec <- sprintf("%s, seed %d", case$rec, case$seed)
  RAIN_SPECS[[rec]] <- modifyList(RAIN_SPECS[[case$rec]], list(seed = case$seed)) }
p <- scm_base_parameters("TF24")
p$max_patch_lifetime <- LIFETIME
p <- add_strategies(p, trait_matrix(LMA0, "lma"))
for (n in names(case$trait)) p$strategies[[1]]$pars[[n]] <- p$strategies[[1]]$pars[[n]] * case$trait[[n]]
ctrl_at <- function(tol) { ctrl <- control()
  ctrl$ode_tol_rel <- tol; ctrl$ode_tol_abs <- 1e-8; ctrl$node_density_in_birth_date <- TRUE
  ctrl$ode_tol_factor_soil <- 10
  w <- readRDS(file.path(WEIGHTS, sprintf("weight_%s.rds", case$weight)))
  ctrl$ode_tol_factor_times <- w$t; ctrl$ode_tol_factor_values <- w$weight; ctrl$ode_tol_factor_max <- 100
  ctrl$ode_step_size_max <- 15 / 365; ctrl$ode_split_sign_changes <- TRUE; ctrl$ode_soil_substep_max_uptake <- 0.1
  ctrl }
env <- mkenv(rec)
rows_of <- function(S, t) sum(vapply(S, function(b) sum(head(t, -1) >= b - 1e-12), 0))
summ <- function(x) { q <- tryCatch(judged(x), error = function(e) conditionMessage(e))
  list(q = q, cpu = x$cpu, rows = rows_of(x$node_times, x$stand$times), steps = length(x$stand$times) - 1, nodes = length(x$node_times)) }

ff <- file.path(out, sprintf("%s_first.rds", cs))
first <- if (file.exists(ff)) readRDS(ff) else {
  x <- stand_run(p, env, ctrl_at(1e-4), seq(0, HORIZON, length.out = 100), gradient = FALSE, records = TRUE)
  x$stand$input_slopes <- x$stand$substep_ends <- NULL; saveRDS(x, ff); x }
for (cf in cfgs) {
  scale <- cf[1]; tol <- cf[2]; f <- file.path(out, sprintf("%s_s%g_t%g.rds", cs, scale, tol)); if (file.exists(f)) next
  sch <- schedule_of(first, p$strategies[[1]]$pars, scale); S <- nodes_of(sch, 0); half <- nodes_of(sch, 0, half = TRUE)
  ctrl <- ctrl_at(tol); res <- list(case = cs, scale = scale, tol = tol, schedule = sch, started = format(Sys.time()))
  x <- tryCatch(stand_run(p, env, ctrl, S), error = function(e) conditionMessage(e))
  if (is.character(x)) { res$failed <- x; saveRDS(res, f); next }
  res$run <- summ(x); res$times <- x$stand$times
  r <- if (length(cf) > 2 && cf[3] == 0) "skipped" else
    tryCatch(stand_run(p, env, ctrl, half, base = x), error = function(e) conditionMessage(e))
  if (is.character(r)) res$replay_failed <- r else res$replay <- summ(r)
  res$finished <- format(Sys.time()); saveRDS(res, f)
  cat(sprintf("%s scale %g tol %g: %d nodes, run %.0f s, replay %.0f s\n", cs, scale, tol, length(S),
              sum(x$cpu), if (is.character(r)) NA else sum(r$cpu)))
}
