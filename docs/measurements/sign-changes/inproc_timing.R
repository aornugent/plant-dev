# The split's sweep and plain's in one process, alternating (prereg.txt,
# fifteenth extension).
#   PLANT_LIB=... SPLIT_PROG=... PLAIN_PROG=... OUT=... Rscript inproc_timing.R
source("harness/long_drought.R")
seed <- RAIN_SPECS[[SCEN]]$seed
scen <- sprintf("%s, seed %d", SCEN, seed)
RAIN_SPECS[[scen]] <- modifyList(RAIN_SPECS[[SCEN]], list(seed = seed))
knots <- active_knots(scen)

# The stand of harness/run_record.R at its defaults, on a pinned program.
stand <- function(program, split) {
  p <- scm_base_parameters("TF24")
  p$max_patch_lifetime <- LIFETIME
  p <- add_strategies(p, trait_matrix(LMA0, "lma"))
  p$node_schedule_times <- list(uniform_times(108))
  st <- readRDS(program)$st
  p$ode_times <- c(0, st$time)
  p$ode_step_sizes <- c(NaN, st$h)
  ct <- control()
  ct$ode_tol_rel <- 1e-4
  ct$ode_tol_abs <- 1e-8
  ct$node_density_in_birth_date <- TRUE
  ct$ode_split_sign_changes <- split
  ev <- events(events_default(p), pulse_rows(sort(unique(knots))))
  run_scm(p, mkenv(scen), ct, events = ev, record_trajectory = TRUE)
}
mb <- function(key) {
  l <- grep(paste0("^", key), readLines("/proc/self/status"), value = TRUE)
  as.numeric(gsub("[^0-9]", "", l)) / 1024
}
timed <- function(f) {
  t0 <- proc.time()
  v <- f()
  t <- proc.time() - t0
  list(value = v, secs = t[["elapsed"]], cpu_secs = t[["user.self"]] + t[["sys.self"]],
       rss_mb = mb("VmRSS"), peak_mb = mb("VmHWM"))
}

out <- list(lib = Sys.getenv("PLANT_LIB"), started = format(Sys.time(), tz = "UTC", usetz = TRUE))
runs <- list(split = timed(function() stand(Sys.getenv("SPLIT_PROG"), TRUE)),
             plain = timed(function() stand(Sys.getenv("PLAIN_PROG"), FALSE)))
for (a in names(runs)) {
  out$J[[a]] <- sum(runs[[a]]$value$offspring_production)
  out$forward[[a]] <- runs[[a]][c("secs", "cpu_secs", "rss_mb", "peak_mb")]
}
out$sweeps <- list()
for (i in 1:3) for (a in names(runs)) {
  s <- timed(function() stand_gradient(runs[[a]]$value, metrics = "offspring_production"))
  out$sweeps[[length(out$sweeps) + 1]] <-
    list(arm = a, secs = s$secs, cpu_secs = s$cpu_secs, rss_mb = s$rss_mb,
         peak_mb = s$peak_mb, lma = unname(s$value$gradient["offspring_production", "1.lma"]))
  saveRDS(out, Sys.getenv("OUT"))
}
