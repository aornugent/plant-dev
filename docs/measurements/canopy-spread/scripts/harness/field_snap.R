# The stand's light field at the top of the layer, at chosen introduction times of
# a schedule. Each snapshot is a Patch rebuilt from the recorded trajectory: its
# nodes introduced at their own birth dates (which stamps their birth
# bookkeeping), then the recorded ODE state set. For each snapshot it saves the
# nodes' heights, birth dates, competition at height zero and interval shares,
# the exact lumped field A(z) as plant evaluates it, the spline's knots, and the
# light the spline returns.
#
#   PLANT_LIB=... TIMES=t.rds AT=0.3704,0.7407 OUT=x.rds Rscript field_snap.R
local({
  here <- tryCatch(dirname(sys.frame(1)$ofile), error = function(e) "harness")
  source(file.path(here, "long_drought.R"))
})
regime <- Sys.getenv("REGIME", SCEN)
tol <- as.numeric(Sys.getenv("TOL", "3e-5"))
times <- readRDS(Sys.getenv("TIMES"))
at <- as.numeric(strsplit(Sys.getenv("AT", "0.37037,0.74074,1.48148,2.96296"), ",")[[1]])
scen <- sprintf("%s, seed %d", regime, RAIN_SPECS[[regime]]$seed)
RAIN_SPECS[[scen]] <- RAIN_SPECS[[regime]]

p <- scm_base_parameters("TF24")
p$max_patch_lifetime <- LIFETIME
p <- add_strategies(p, trait_matrix(LMA0, "lma"))
p$node_schedule_times <- list(times)
ct <- control()
ct$ode_tol_rel <- tol
ct$ode_tol_abs <- 1e-4 * tol
ct$node_density_in_birth_date <- TRUE
ev <- events(events_default(p), pulse_rows(sort(unique(active_knots(scen)))))
scm <- run_scm(p, mkenv(scen), ct, events = ev, record_trajectory = TRUE)
J <- sum(scm$offspring_production)
sp_end <- scm$patch$species[[1]]
per <- length(sp_end$ode_state) / sp_end$size
rows <- scm$store_trajectory()
rt <- vapply(rows, `[[`, 0, "time")
len <- lengths(lapply(rows, `[[`, "state"))
env_size <- tail(len, 1) - per * sp_end$size
held <- (len - env_size) / per
types <- plant:::extract_RcppR6_template_types(p, "Parameters")
make_patch <- do.call(plant:::Patch, as.list(types))

snap <- function(ts) {
  born <- times[times < ts - 1e-12]
  k <- max(which(rt <= ts + 1e-12 & held == length(born)))
  pt <- make_patch(p, mkenv(scen), ct)
  for (b in born) { pt$set_time(b); pt$introduce_new_node(1L, b) }
  pt$set_ode_state(rows[[k]]$state, rows[[k]]$time)
  pt$compute_environment()
  sp <- pt$species[[1]]
  nd <- sp$nodes
  nm <- nd[[1]]$ode_names
  st <- t(vapply(nd, function(n) n$ode_state, numeric(length(nm))))
  colnames(st) <- nm
  nn <- sp$new_node
  birth <- c(vapply(nd, function(n) n$introduction_time, 0), nn$introduction_time)
  width <- diff(birth)
  M <- st[, "interval_establishment_moment"]; I <- st[, "interval_establishment"]
  heights <- c(vapply(nd, function(n) n$height, 0), nn$height)
  scale <- c(vapply(nd, function(n) n$compute_competition(0), 0), nn$compute_competition(0))
  z <- seq(0, max(heights), length.out = 2049)
  list(time = pt$time, row_time = rows[[k]]$time,
       state_check = max(abs(pt$ode_state - rows[[k]]$state)),
       birth = birth, height = heights, scale = scale,
       lo = c(0, M / width), hi = c(I - M / width, 0), w = sp$establishment_weights,
       mortality = c(st[, "mortality"], NA), area = pt$get_area,
       z = z, A = vapply(z, pt$compute_competition, 0),
       E_spline = vapply(z, function(zz) pt$environment$get_environment_at_height(zz), 0),
       knots = pt$environment$light_availability$state,
       eta = p$strategies[[1]]$pars$eta, k_I = p$strategies[[1]]$pars$k_I)
}
out <- list(times = times, J = J, snaps = lapply(at, snap))
saveRDS(out, Sys.getenv("OUT"))
cat(sprintf("%d nodes: J %.10g; snapshots at %s\n", length(times), J,
            paste(sprintf("%.4f", vapply(out$snaps, `[[`, 0, "time")), collapse = ", ")))
