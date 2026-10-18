# One case's stand at refine_case.R's setting, its R22 node times, and a timed stand_run.
#   PLANT_LIB=<lib> must be set; source after setting CASE.
source("/home/user/plant-dev/harness/long_drought.R")
source("/home/user/plant-dev/harness/schedule/refine.R")
SP <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad"
WEIGHTS <- file.path(SP, "dev/window/rule_A")
CASES <- list(
  dry = list(regime = "dry", trait = c(), weight = "dry"),
  `long-wet` = list(regime = "long-wet", trait = c(), weight = "long-wet"),
  `episodic-lma` = list(regime = "episodic", trait = c(lma = 1.25), weight = "episodic"),
  `dry-flat` = list(regime = "dry-flat", trait = c(), weight = "dry"),
  `epi-adG208` = list(regime = "episodic", trait = c(a_dG2 = 0.8), weight = "episodic"))

case_setup <- function(name) {
  case <- CASES[[name]]
  p <- scm_base_parameters("TF24")
  p$max_patch_lifetime <- LIFETIME
  p <- add_strategies(p, trait_matrix(LMA0, "lma"))
  for (n in names(case$trait)) p$strategies[[1]]$pars[[n]] <- p$strategies[[1]]$pars[[n]] * case$trait[[n]]
  ctrl <- control()
  ctrl$ode_tol_rel <- 1e-4
  ctrl$ode_tol_abs <- 1e-8
  ctrl$node_density_in_birth_date <- TRUE
  ctrl$ode_tol_factor_soil <- 10
  w <- readRDS(file.path(WEIGHTS, sprintf("weight_%s.rds", case$weight)))
  ctrl$ode_tol_factor_times <- w$t
  ctrl$ode_tol_factor_values <- w$weight
  ctrl$ode_tol_factor_max <- 100
  ctrl$ode_step_size_max <- 15 / 365
  ctrl$ode_split_sign_changes <- TRUE
  ctrl$ode_soil_substep_max_uptake <- 0.1
  list(p = p, ctrl = ctrl, env = mkenv(case$regime))
}

# The canonical (R22, libS) loop's schedule for a case: level 0 and its replay.
r22_nodes <- function(name) {
  fit <- readRDS(file.path(SP, "refine/s1", paste0(name, ".rds")))
  list(S = nodes_of(fit$schedule, 0), half = nodes_of(fit$schedule, 0, half = TRUE))
}

status_kb <- function(field) {
  l <- grep(paste0("^", field, ":"), readLines("/proc/self/status"), value = TRUE)
  as.numeric(gsub("[^0-9]", "", l))
}
# Machine-wide busy cores and stolen share between two reads of /proc/stat's cpu line.
cpu_line <- function() as.numeric(strsplit(readLines("/proc/stat", 1), " +")[[1]][2:9])
busy_of <- function(a, b) { d <- b - a; c(busy = 4 * sum(d[c(1:3, 6:8)]) / sum(d), steal = d[8] / sum(d)) }
# Minor and major page faults of this process so far.
faults <- function() as.numeric(strsplit(sub(".*\\) ", "", readLines("/proc/self/stat")), " ")[[1]][c(8, 10)])
rows_of <- function(times, steps) sum(vapply(steps[-length(steps)], function(s) sum(times <= s) + 1, 0))

# stand_run with the step count, rows, wall time and resident set around it.
timed_run <- function(cs, times, base = NULL, gradient = TRUE, records = FALSE, label = "") {
  rss0 <- status_kb("VmRSS"); w0 <- Sys.time(); s0 <- cpu_line(); f0 <- faults(); p0 <- proc.time()
  x <- stand_run(cs$p, cs$env, cs$ctrl, times, base = base, gradient = gradient, records = records)
  x$meta <- list(label = label, steps = length(x$stand$times), rows = rows_of(times, x$stand$times),
                 wall = as.numeric(Sys.time() - w0, units = "secs"), rss_before = rss0, rss_after = status_kb("VmRSS"),
                 hwm = status_kb("VmHWM"), load = readLines("/proc/loadavg"), machine = busy_of(s0, cpu_line()),
                 user_sys = (proc.time() - p0)[c("user.self", "sys.self")], faults = faults() - f0, at = format(Sys.time()))
  m <- x$meta
  cat(sprintf("%-10s n %3d steps %5d rows %7.0f fwd %6.1f s (%5.1f us) sweep %6.1f s (%5.1f us) wall %6.1f busy %.2f sys %.1f minflt %.0f rss %4.0f->%4.0f MiB load %s J %.15g\n",
              label, length(times), m$steps, m$rows, x$cpu[["forward"]], 1e6 * x$cpu[["forward"]] / m$rows,
              x$cpu[["sweep"]], 1e6 * x$cpu[["sweep"]] / m$rows, m$wall, m$machine[["busy"]], m$user_sys[[2]], m$faults[1], m$rss_before / 1024, m$rss_after / 1024,
              substr(m$load, 1, 14), x$stand$J))
  x
}
