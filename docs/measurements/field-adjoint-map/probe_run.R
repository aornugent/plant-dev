# The field probe on one coarse schedule against the finer one it nests in.
#
#   bash job.sh MODE TIMES FINE OUT [ORDER] [OPEN]
#
# MODE sweep:  the coarse run, recorded; then the sweep of J with every panel's
#              light and soil coefficient a gradient column (per time band).
# MODE perturb:the coarse run; then the coarse run again with every light
#              coefficient 1, and again with every soil coefficient 1: the
#              defect added to the field outright, so the move in each node's
#              offspring is the response to it in full.
# MODE plain:  the run alone (for a schedule refined in a few panels).
A <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/adjmap"
args <- commandArgs(TRUE)
mode <- args[1]; times_file <- args[2]; fine_file <- args[3]; out_file <- args[4]
order <- if (length(args) >= 5) as.integer(args[5]) else 1L
open <- if (length(args) >= 6) args[6] == "1" else TRUE
libname <- if (length(args) >= 7) args[7] else "lib"
# Panels the perturb mode drives, as an R range ("1:2"); every panel by default.
sel <- if (length(args) >= 8) eval(parse(text = args[8])) else NULL
Sys.setenv(PLANT_LIB = file.path(A, libname))
source(file.path(A, "harness", "long_drought.R"))
source(file.path(A, "probe_setup.R"))
regime <- "long-drought"; seed <- 31L; tol <- 3e-5; atol <- 1e-4
scen <- sprintf("%s, seed %d", regime, seed)
RAIN_SPECS[[scen]] <- modifyList(RAIN_SPECS[[regime]], list(seed = seed))
knots <- active_knots(scen)
times <- readRDS(times_file)
p <- scm_base_parameters("TF24")
p$max_patch_lifetime <- LIFETIME
p <- add_strategies(p, trait_matrix(LMA0, "lma"))
p$node_schedule_times <- list(times)
ct <- control()
ct$ode_tol_rel <- tol
ct$ode_tol_abs <- atol * tol
ct$node_density_in_birth_date <- TRUE
ev <- events(events_default(p), pulse_rows(sort(unique(knots))))
BANDS <- c(0.5, 1, 2, 3, 5, 10, 20)

out <- list(mode = mode, times = times, order = order, open = open, bands = BANDS, sel = sel,
            lib = file.path(A, libname), started = format(Sys.time()))
save <- function() saveRDS(out, out_file)
cpu <- function() { pt <- proc.time(); pt[["user.self"]] + pt[["sys.self"]] }
peak_mb <- function() {
  l <- grep("^VmHWM", readLines("/proc/self/status"), value = TRUE)
  as.numeric(gsub("[^0-9]", "", l)) / 1024
}
new_scm <- function() {
  types <- plant:::extract_RcppR6_template_types(p, "Parameters")
  do.call(plant:::SCM, types)(p, mkenv(scen), ev, ct)
}
run_one <- function(probe = NULL, record = FALSE) {
  scm <- new_scm()
  if (!is.null(probe)) do.call(plant:::field_probe_set_tf24, c(list(scm), probe))
  scm$record_trajectory <- record
  c0 <- cpu(); t0 <- proc.time()[["elapsed"]]
  scm$run()
  list(scm = scm, cpu = cpu() - c0, wall = proc.time()[["elapsed"]] - t0)
}
summary_of <- function(r) list(J = sum(r$scm$offspring_production), steps = length(r$scm$ode_times),
                                nodes = per_node(r$scm), cpu = r$cpu, wall = r$wall, peak_mb = peak_mb(),
                                env = if (isTRUE(r$scm$record_trajectory)) env_record(r$scm))

base <- run_one(record = TRUE)
out$base <- summary_of(base)
out$base$creation <- creation_record(base$scm)
cat(sprintf("base: J %.10f, %d steps, %.0f s cpu\n", out$base$J, out$base$steps, out$base$cpu))
save()
if (mode == "plain") { out$finished <- format(Sys.time()); save(); quit("no") }

fine <- readRDS(fine_file)
drop <- mode == "drop"
if (drop) {
  # TIMES is the finer schedule and FINE the coarser: mark the nodes it lacks.
  at <- ifelse(round(times, 10) %in% round(fine, 10), NaN, times)
  w <- rep(NaN, length(at))
} else {
  at <- fine_at(times, fine)
  w <- fine_weight(out$base$creation, times, at)
}
nb <- length(BANDS) + 1
nc <- length(at) * nb
out$at <- at; out$weight <- w
has_drop <- "drop" %in% names(formals(plant:::field_probe_set_tf24))
stopifnot(has_drop || !drop)
probe <- function(light, soil) {
  on <- if (is.null(sel)) rep(1, length(at)) else as.numeric(seq_along(at) %in% sel)
  q <- list(at = at, weight = w, bands = BANDS, order = order, open = open,
            light = rep(light * on, each = nb), soil = rep(soil * on, each = nb))
  if (has_drop) q$drop <- drop
  q
}
save()

if (mode %in% c("sweep", "drop", "sweep0")) {
  scm <- base$scm
  if (mode != "sweep0") do.call(plant:::field_probe_set_tf24, c(list(scm), probe(0, 0)))
  c0 <- cpu(); t0 <- proc.time()[["elapsed"]]
  g <- plant:::census_trait_gradient_tf24(scm, "offspring_production")
  out$sweep_cpu <- cpu() - c0; out$sweep_wall <- proc.time()[["elapsed"]] - t0
  out$sweep_peak_mb <- peak_mb()
  out$names <- plant:::census_trait_names_tf24(scm)
  out$gradient <- g$gradient[[1]]
  out$refusal <- g$refusal[[1]]
  k <- length(out$gradient) - if (mode == "sweep0") 0 else 2 * nc
  out$traits <- out$gradient[seq_len(k)]
  if (mode != "sweep0") {
    out$light <- matrix(out$gradient[k + seq_len(nc)], nrow = nb)
    out$soil <- matrix(out$gradient[k + nc + seq_len(nc)], nrow = nb)
  }
  J <- out$base$J
  cat(sprintf("sweep: %.0f s cpu; predicted field part light %+.4f%%, soil %+.4f%% of J\n",
              out$sweep_cpu, 100 * sum(out$light) / J, 100 * sum(out$soil) / J))
  save()
}
if (mode == "perturb") {
  for (ch in c("light", "soil")) {
    r <- run_one(probe = if (ch == "light") probe(1, 0) else probe(0, 1), record = TRUE)
    out[[ch]] <- summary_of(r)
    cat(sprintf("source %s: J %.10f (%+.4f%% of base), %d steps, %.0f s cpu\n", ch, out[[ch]]$J,
                100 * (out[[ch]]$J - out$base$J) / out$base$J, out[[ch]]$steps, out[[ch]]$cpu))
    rm(r); gc()
    save()
  }
}
out$finished <- format(Sys.time())
save()
