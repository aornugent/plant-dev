# Every saved run's tolerance, schedule digest and cost, to find runs of one schedule at
# two tolerances. Writes scan.rds (one row per run) next to this script.
DEV <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev"
OUT <- "/home/user/plant-dev/docs/measurements/schedule-search/round3/A/scan.rds"
fs <- list.files(DEV, "\\.rds$", recursive = TRUE, full.names = TRUE)
fs <- fs[grepl("/runs", fs) & !grepl("/lib", fs)]
row <- function(f) tryCatch({
  x <- readRDS(f)
  if (!is.list(x) || is.null(x$setting$tol) || is.null(x$node_times) || is.null(x$stand$J)) return(NULL)
  env <- x$setting$env; env <- env[setdiff(names(env), "LIB")]
  S <- round(x$node_times, 8)
  data.frame(file = f, name = sub("\\.rds$", "", basename(f)), tol = x$setting$tol, atol = if (is.null(x$setting$atol)) NA else x$setting$atol,
    key = paste(x$mode, x$setting$regime, x$setting$seed, x$setting$lifetime, paste(names(env), env, sep = "=", collapse = ";"), sep = "|"),
    sched = sprintf("%d:%.8f:%.8f", length(S), sum(S), sum(S^2)), n = length(S),
    lib = if (is.null(x$setting$env[["LIB"]])) "" else basename(x$setting$env[["LIB"]]),
    J = x$stand$J, rows = if (is.null(x$stand$rows)) NA else x$stand$rows, cpu = if (is.null(x$stand$cpu)) NA else x$stand$cpu,
    sweep_cpu = if (is.null(x$sweep_cpu)) NA else x$sweep_cpu, steps = length(x$stand$times),
    has_el = !is.null(x$stand$elasticity) && all(is.finite(x$stand$elasticity)), dropped = length(x$dropped))
}, error = function(e) NULL)
tab <- do.call(rbind, lapply(fs, row))
saveRDS(tab, OUT)
cat(nrow(tab), "runs with a tolerance;", length(fs), "files\n")
print(table(tab$tol))
g <- split(tab, paste(tab$key, tab$sched))
multi <- Filter(function(d) length(unique(d$tol)) > 1, g)
cat(length(multi), "schedules run at more than one tolerance\n")
for (d in multi) { d <- d[order(d$tol), ]; cat(sprintf("  %-40s tol %-28s n %d el %s\n", paste(d$name, collapse = ","), paste(d$tol, collapse = ","), d$n[1], paste(d$has_el, collapse = ","))) }
