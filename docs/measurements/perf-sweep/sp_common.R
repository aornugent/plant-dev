# The fixture of perf-adjoint.md and perf-rhs-profile.md, loaded from an
# installed library: TF24, one species at lma = 0.32, long drought aligned (a
# zero-depth pulse at every active knot), ode_tol_rel = ode_tol_abs = TOL
# (default 1e-3), birth-date coordinate. PLANT_LIB names the library; odelia
# comes from it through library(), never load_all.
SPD <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/sweep_profile"
# The fixture is the harness's own, read in place; long_drought.R beside this
# file is the copy the first runs used (identical but for a later helper).
HARNESS <- Sys.getenv("SP_HARNESS", "/home/user/plant-dev/harness/long_drought.R")
source(HARNESS)
cat(sprintf("harness %s md5 %s\n", HARNESS, tools::md5sum(HARNESS)))
TOL <- as.numeric(Sys.getenv("TOL", "1e-3"))
# The absolute tolerance; equal to TOL unless set (canopy-spread used 3e-9 with
# TOL 3e-5).
TOL_ABS <- as.numeric(Sys.getenv("TOL_ABS", TOL))

build_scm <- function(times, lifetime = LIFETIME, tol = TOL, stops = AK, tol_abs = TOL_ABS) {
  p <- scm_base_parameters("TF24")
  p$max_patch_lifetime <- lifetime
  p <- add_strategies(p, trait_matrix(LMA0, "lma"))
  p$node_schedule_times <- list(times)
  ct <- control()
  ct$ode_tol_rel <- tol
  ct$ode_tol_abs <- tol_abs
  ct$node_density_in_birth_date <- TRUE
  ev <- if (length(stops) == 0) events_default(p) else
    events(events_default(p), pulse_rows(sort(unique(stops))))
  do.call(plant:::SCM, plant:::extract_RcppR6_template_types(p, "Parameters"))(p, mkenv(SCEN), ev, ct)
}

# perf-rhs-profile's cut: uniform-429 node times and active-knot stops before T,
# max_patch_lifetime = T. T = 0 means the full 40-year run on uniform NODES.
config <- function(T, nodes) {
  # NOSTOPS=1 drops the zero-depth pulses, leaving introductions as the only
  # insertion rows: a check on what the pulses cost the sweep, not the fixture.
  if (Sys.getenv("NOSTOPS") == "1") {
    cfg <- config0(T, nodes)
    cfg$stops <- numeric(0)
    return(cfg)
  }
  config0(T, nodes)
}
config0 <- function(T, nodes) {
  if (T > 0) {
    tt <- uniform_times(429)
    list(lifetime = T, times = tt[tt < T], stops = AK[AK < T])
  } else {
    list(lifetime = LIFETIME, times = uniform_times(nodes), stops = AK)
  }
}

# Rows: the members alive at each accepted step's start, summed over steps.
member_steps <- function(ode_times, node_times) {
  t0 <- ode_times[-length(ode_times)]
  sum(findInterval(t0, node_times))
}

mem_kb <- function() {
  s <- readLines("/proc/self/status")
  g <- function(k) as.numeric(sub("^[^:]+:\\s+([0-9]+) kB$", "\\1",
                                  grep(paste0("^", k, ":"), s, value = TRUE)))
  c(rss = g("VmRSS"), hwm = g("VmHWM"))
}
reset_hwm <- function() tryCatch({ cat("5", file = "/proc/self/clear_refs"); TRUE },
                                 error = function(e) FALSE)
cpu_now <- function() {
  p <- proc.time()
  c(user = p[["user.self"]], sys = p[["sys.self"]], wall = p[["elapsed"]])
}

# One phase: CPU, resident memory before and after, and the phase's own peak.
phase <- function(f) {
  gc(); reset_hwm()
  m0 <- mem_kb(); c0 <- cpu_now()
  v <- f()
  c1 <- cpu_now(); m1 <- mem_kb()
  list(value = v, cpu = c1 - c0, rss0 = m0[["rss"]], rss1 = m1[["rss"]], peak = m1[["hwm"]])
}

lib_tag <- function() {
  sprintf("lib %s, spread %s, plant .so %s", Sys.getenv("PLANT_LIB"),
          Sys.getenv("PLANT_PROBE_SPREAD", "unset"),
          format(file.info(file.path(Sys.getenv("PLANT_LIB"), "plant", "libs", "plant.so"))$mtime))
}
