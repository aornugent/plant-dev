# One stand on one rainfall record and an invader with the stand's own traits,
# each with its offspring-production gradient, saving everything a later analysis
# reads. The invader walks the stand's recorded field, so its gradient is the
# selection gradient. Each phase is timed and written as it finishes; one that
# raises is recorded, and the phases that do not need it still run.
#
#   PLANT_LIB=... [REGIME=long-drought] [SEED=...] [TOL=1e-4] [ATOL=1e-4] \
#     [NODES=108] [SHIFT=0] [TIMES=times.rds] [FORWARD=1] [PROGRAM=driver.rds] \
#     [WEIGHT_SOIL=10] [WEIGHT_ACC=10] [WEIGHT=weight.rds] [WEIGHT_MAX=100] \
#     [HMAX=15] [METHOD=ark] [SPLIT=1] [LMA_REL=1e-2] OUT=run.rds \
#     Rscript harness/run_record.R
#
# ATOL is the absolute tolerance over the relative one: 1e-4 ties it as step 2
# decided, and 1 is plant's default. SHIFT moves every introduction after the
# first by that fraction of the node spacing. SEED replaces the regime's own.
# TIMES reads the introductions from a file in place of NODES and SHIFT, and
# FORWARD runs the stand alone, with no gradient and no invader. PROGRAM takes
# the stand's steps from a harness/ark_prototype.R OUT file on the same record and
# introductions, each at the size the driver accepted, in place of plant's control.
# INVADERS walks more invaders after the stand's own, each trait=factor (comma-
# separated) on the stand's introductions, and keeps each one's J and nodes.
# WEIGHT_SOIL and WEIGHT_ACC multiply the soil layers' and the accumulators'
# error levels, WEIGHT is a table of t and weight multiplying every state's from
# t on (harness/ark_prototype.R's), WEIGHT_MAX bounds each state's weight once
# they multiply, and HMAX caps every step at that many days. They need a plant
# with the error weights (state-weights). METHOD names plant's stepper, "ark"
# for the implicit soil chain (ark-soil). Each run keeps the soil's clamp
# tallies on the forward run and on each sweep. SPLIT=1 splits each node's step
# where its net production changes sign (sign-changes), and LMA_REL runs the
# stand, not its invaders, at its own lma (1 + LMA_REL), set after the
# hyperparameterisation has derived the rest, as a gradient's partial moves it.
local({
  here <- tryCatch(dirname(sys.frame(1)$ofile), error = function(e) "harness")
  source(file.path(here, "long_drought.R"))
})
regime <- Sys.getenv("REGIME", SCEN)
stopifnot(regime %in% names(RAIN_SPECS))
seed <- as.integer(Sys.getenv("SEED", RAIN_SPECS[[regime]]$seed))
tol <- as.numeric(Sys.getenv("TOL", "1e-4"))
atol <- as.numeric(Sys.getenv("ATOL", "1e-4"))
nodes <- as.integer(Sys.getenv("NODES", "108"))
shift <- as.numeric(Sys.getenv("SHIFT", "0"))
times_file <- Sys.getenv("TIMES")
forward <- Sys.getenv("FORWARD") == "1"
out_file <- Sys.getenv("OUT")

scen <- sprintf("%s, seed %d", regime, seed)
RAIN_SPECS[[scen]] <- modifyList(RAIN_SPECS[[regime]], list(seed = seed))
rain <- rain_record(scen)
knots <- active_knots(scen)
times <- uniform_times(nodes)
times[-1] <- times[-1] + shift * (times[2] - times[1])
if (nzchar(times_file)) times <- readRDS(times_file)
nodes <- length(times)

p <- scm_base_parameters("TF24")
p$max_patch_lifetime <- LIFETIME
p <- add_strategies(p, trait_matrix(LMA0, "lma"))
lma_rel <- as.numeric(Sys.getenv("LMA_REL", "0"))
if (lma_rel != 0) {
  s <- p$strategies[[1]]
  sp_pars <- s$pars
  sp_pars$lma <- sp_pars$lma * (1 + lma_rel)
  s$pars <- sp_pars
  p$strategies[[1]] <- s
}
p$node_schedule_times <- list(times)
program <- if (nzchar(Sys.getenv("PROGRAM"))) readRDS(Sys.getenv("PROGRAM"))$st
if (!is.null(program)) {
  p$ode_times <- c(0, program$time)
  p$ode_step_sizes <- c(NaN, program$h)
}
ct <- control()
ct$ode_tol_rel <- tol
ct$ode_tol_abs <- atol * tol
ct$node_density_in_birth_date <- TRUE
if (nzchar(Sys.getenv("WEIGHT_SOIL"))) ct$ode_weight_soil <- as.numeric(Sys.getenv("WEIGHT_SOIL"))
if (nzchar(Sys.getenv("WEIGHT_ACC"))) ct$ode_weight_accumulator <- as.numeric(Sys.getenv("WEIGHT_ACC"))
if (nzchar(Sys.getenv("WEIGHT"))) {
  w <- readRDS(Sys.getenv("WEIGHT"))
  ct$ode_weight_times <- w$t
  ct$ode_weight_factors <- w$weight
}
if (nzchar(Sys.getenv("WEIGHT_MAX"))) ct$ode_weight_max <- as.numeric(Sys.getenv("WEIGHT_MAX"))
if (nzchar(Sys.getenv("HMAX"))) ct$ode_step_size_max <- as.numeric(Sys.getenv("HMAX")) / 365
if (nzchar(Sys.getenv("METHOD"))) ct$ode_method <- Sys.getenv("METHOD")
if (Sys.getenv("SPLIT") == "1") ct$ode_split_sign_changes <- TRUE
ev <- events(events_default(p), pulse_rows(sort(unique(knots))))

clock <- function() proc.time()[["elapsed"]]
peak_mb <- function() {
  l <- grep("^VmHWM", readLines("/proc/self/status"), value = TRUE)
  as.numeric(gsub("[^0-9]", "", l)) / 1024
}
out <- list(
  setting = list(regime = regime, seed = seed, spec = RAIN_SPECS[[regime]], tol = tol,
                 tol_abs = ct$ode_tol_abs, nodes = nodes, shift = shift, lma = LMA0,
                 lma_rel = lma_rel, split = Sys.getenv("SPLIT") == "1",
                 lifetime = LIFETIME, program = Sys.getenv("PROGRAM")),
  versions = list(plant = as.character(packageVersion("plant")),
                  odelia = as.character(packageVersion("odelia")),
                  R = R.version.string, lib = Sys.getenv("PLANT_LIB"),
                  host = Sys.info()[["nodename"]]),
  started = format(Sys.time(), tz = "UTC", usetz = TRUE),
  rain = rain, knots = knots, node_times = times, phases = list(), failures = list())
save <- function() if (nzchar(out_file)) saveRDS(out, out_file)

# One phase: its time, the process's peak memory after it, and its message if it
# raised.
phase <- function(name, f) {
  t0 <- clock()
  v <- tryCatch(f(), error = function(e) {
    out$failures[[name]] <<- conditionMessage(e)
    NULL
  })
  out$phases[[name]] <<- list(secs = clock() - t0, peak_mb = peak_mb(), ok = !is.null(v))
  save()
  v
}

# Each node's birth time, establishment weight (the boundary node's last), net
# reproduction ratio, and height and mortality integral at the end, for the
# species the patch holds now.
per_node <- function(scm) {
  sp <- scm$patch$species[[1]]
  state <- matrix(sp$ode_state, ncol = sp$size, dimnames = list(sp$new_node$ode_names))
  list(birth = sp$node_times, establishment = sp$establishment_weights,
       nrr = sp$net_reproduction_ratio_by_node, height = state["height", ],
       mortality = state["mortality", ])
}

# The creation probability averaged over each accepted step: the growth over
# the step of the newest node's establishment integral, the only one still open.
creation_record <- function(scm) {
  rows <- scm$store_trajectory()
  sp <- scm$patch$species[[1]]
  per <- length(sp$ode_state) / sp$size
  at <- which(sp$new_node$ode_names == "interval_establishment")
  len <- lengths(lapply(rows, `[[`, "state"))
  held <- (len - (tail(len, 1) - per * sp$size)) / per
  t <- vapply(rows, `[[`, 0, "time")
  I <- vapply(seq_along(rows), function(i)
    if (held[i] > 0) rows[[i]]$state[per * (held[i] - 1) + at] else NA_real_, 0)
  i <- which(diff(held) == 0 & diff(t) > 0)
  list(start = t[i], end = t[i + 1], rate = (I[i + 1] - I[i]) / (t[i + 1] - t[i]))
}

# The gradient over every trait column, and each as the elasticity d ln J / d ln
# theta, or as d ln J / d theta where the trait's value is zero.
gradient_of <- function(scm, q) {
  g <- stand_gradient(scm, metrics = "offspring_production")
  pars <- q$strategies[[1]]$pars
  grad <- g$gradient["offspring_production", ]
  theta <- vapply(names(grad), function(n) pars[[sub("^1\\.", "", n)]], 0)
  J <- sum(scm$offspring_production)
  list(value = unname(g$value), gradient = grad, theta = theta,
       elasticity = ifelse(theta == 0, 1, theta) * grad / J,
       refusal = g$refusal[["offspring_production"]], control = g$control)
}

# The soil layers at every recorded state: the environment's ten states close the
# patch's state, the five layers ahead of the five accumulators.
soil_record <- function(scm) {
  rows <- scm$store_trajectory()
  list(time = vapply(rows, `[[`, 0, "time"),
       theta = t(vapply(rows, function(r) head(tail(r$state, 10), 5), numeric(5))))
}

# The soil's clamp tallies from one of plant's census readers: the first
# species' row at plant's clamp_site order, moisture floor, potential ceiling,
# positivity.
soil_clamps <- function(reader) tryCatch(
  setNames(reader(scm)[[1]][3:5], c("moisture_floor", "potential_ceiling", "positivity")),
  error = function(e) NA)

scm <- phase("stand_run", function() {
  run_scm(p, mkenv(scen), ct, events = ev, record_trajectory = TRUE)
})
if (!is.null(scm)) {
  out$stand <- list(J = sum(scm$offspring_production), times = scm$ode_times,
                    sizes = scm$ode_step_sizes, attempts = scm$ode_step_attempts,
                    splits = if (!is.null(scm$ode_splits)) scm$ode_splits,
                    split_record = if (!is.null(scm$ode_split_record)) scm$ode_split_record,
                    nodes = per_node(scm), event_log = unclass(scm$event_log),
                    creation = creation_record(scm), soil = soil_record(scm),
                    forward_clamps = soil_clamps(plant:::census_clamp_counts_tf24))
  save()
  g <- if (!forward) phase("stand_gradient", function() gradient_of(scm, p))
  if (!is.null(g)) out$stand <- c(out$stand, g,
                                  list(swept_clamps = soil_clamps(plant:::census_clamp_counts_differentiated_tf24)))
  save()
  if (!forward && isTRUE(phase("invader_run", function() { scm$run_mutant(p); TRUE }))) {
    out$invader <- list(J = sum(scm$offspring_production), nodes = per_node(scm))
    save()
    gi <- phase("invader_gradient", function() gradient_of(scm, p))
    if (!is.null(gi)) out$invader <- c(out$invader, gi,
                                       list(swept_clamps = soil_clamps(plant:::census_clamp_counts_differentiated_tf24)))
    for (inv in strsplit(Sys.getenv("INVADERS", ""), ",")[[1]]) {
      kv <- strsplit(inv, "=")[[1]]
      q <- stand_at(times, kv[1], as.numeric(kv[2]))
      if (isTRUE(phase(inv, function() { scm$run_mutant(q); TRUE }))) {
        out$invaders[[inv]] <- list(J = sum(scm$offspring_production), nodes = per_node(scm))
      }
      save()
    }
  }
}
out$finished <- format(Sys.time(), tz = "UTC", usetz = TRUE)
save()
cat(sprintf("%s, tol %g (abs %g), %d nodes, shift %g: J %s, %d steps; %d failures; %.0f s\n",
            scen, tol, ct$ode_tol_abs, nodes, shift, format(out$stand$J, digits = 10),
            length(out$stand$times), length(out$failures),
            sum(vapply(out$phases, `[[`, 0, "secs"))))
