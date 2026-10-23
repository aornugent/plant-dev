# Shared by the analysis scripts: the logged leaf calls, the resident's
# strategy, a single-leaf evaluation through plant's own Individual, and the
# wet-soil root conductances that weight the layers.
Sys.setenv(PLANT_LIB = "/home/a/.claude/jobs/9d586e52/rlib-leaf")
.libPaths(c("/home/a/.claude/jobs/9d586e52/rlib-leaf", .libPaths()))
suppressMessages(library(odelia))
suppressMessages(library(plant))

TMP <- "/home/a/.claude/jobs/9d586e52/tmp/leaf"
HERE <- "/home/a/dev/plant-dev/.claude/worktrees/agent-a9f1c333a8d4c65ef/spikes/leaf-table"

COLS <- c("time", "lma", "height", "light", "radiation",
          paste0("psi", 1:5), "kmax", "vpd", "ca", "leaf_temp", "PPFD",
          "profit", "shadow", "E", "E_up", paste0("u", 1:5),
          "root_psi", "stem_psi", "kind", "replayed",
          "hmat", "K_s", "rooting_depth_max", "vcmax_25")

read_leaflog <- function(files) {
  do.call(rbind, lapply(files, function(f) {
    n <- file.size(f) / 8
    x <- readBin(f, "double", n)
    m <- matrix(x, ncol = 32, byrow = TRUE)
    colnames(m) <- COLS
    as.data.frame(m)
  }))
}

TRAITS <- c("lma", "rho", "hmat", "K_s", "rooting_depth_max", "vcmax_25")
TRAIT0 <- local({
  d <- scm_base_parameters("TF24")$strategy_default$pars
  v <- vapply(TRAITS, function(n) d[[n]], 0)
  # The closed stand's resident; LMA_SHIFT=0 gives the open stand's.
  v[["lma"]] <- 0.32 * exp(as.numeric(Sys.getenv("LMA_SHIFT", "-1")))
  v
})

tf24_strategy_at <- function(traits = TRAIT0) {
  p <- scm_base_parameters("TF24")
  p <- add_strategies(p, trait_matrix(traits, names(traits)))
  p$strategies[[1]]
}

# One leaf call at (light, psi by layer, height): P per leaf area as the live
# model computes it (profit + shadow cost, umol m^-2 s^-1), and the layer draws.
leaf_eval_factory <- function(s = tf24_strategy_at()) {
  env <- Environment("TF24")
  ind <- Individual("TF24", "TF24_Env")(s)
  function(light, psi, height, time = 0) {
    env$set_fixed_environment(light, height_max = 150)
    env$set_soil_water_state(vapply(psi, function(x) env$soil_moist_from_psi(x), 0))
    env$time <- time
    ind$set_state("height", height)
    ind$compute_rates(env)
    c(P = ind$aux("profit") + ind$aux("shadow_cost"), E = ind$aux("transpiration"),
      root_psi = ind$aux("opt_root_psi"))
  }
}

# Wet-soil layer conductances 1/(r_H + r_V,sum) of the root network at a
# height, per leaf area: the weights that make the supply linear in psi.
root_weights <- function(height, rooting_depth_max = TRAIT0[["rooting_depth_max"]],
                         soil_depths = seq(0.3, 1.5, by = 0.3),
                         a_r1 = 0.07, eta = 0.2,
                         beta_H = 3.4e2, beta_V = 9.4e3) {
  d <- min(height, rooting_depth_max)
  Q <- function(z) if (z > d) 0 else (1 - (z / d)^eta)^2
  q <- vapply(soil_depths, Q, 0)
  carbon <- 83.26 * 0.5 * a_r1 * (c(1, head(q, -1)) - q)
  dz <- diff(c(0, soil_depths))
  rH <- ifelse(carbon > 0, beta_H / (carbon * 2 / 3), Inf)
  rV <- ifelse(carbon > 0, beta_V * dz^2 / (carbon / 3), 0)
  rVs <- cumsum(rV)
  g <- ifelse(carbon > 0, 1 / (rH + rVs), 0)
  g / sum(g)
}

# The second soil number: the layers below the first, weighted by their wet
# conductance. Layer 1 is the first.
deep_psi <- function(h, psi, rdm = TRAIT0[["rooting_depth_max"]]) {
  w <- root_weights(h, rooting_depth_max = rdm)
  if (sum(w[-1]) > 0) sum(w[-1] * psi[-1]) / sum(w[-1]) else psi[1]
}

# The invader pool of field_dimension.R: row 1 the resident, then a Latin
# hypercube in ln-trait over +-0.4.
POOL <- local({
  set.seed(20261023)
  n <- 47
  x <- sapply(TRAITS, function(.) (sample(n) - runif(n)) / n * 0.8 - 0.4)
  rbind(0, x)
})
pool_traits <- function(row) TRAIT0 * exp(POOL[row, ])
