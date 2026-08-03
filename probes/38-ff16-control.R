# Control: does the same SCM-vs-IBM offset appear for FF16, where growth depends
# only on size and environment, so the ordinary height-coordinate SCM is valid?
# If the offset is present there too it is a pre-existing, model-independent
# property of comparing plant's SCM with its individual-based solver, not
# something introduced by node_density_in_birth_date.
source("probes/lib.R"); setwd("/home/user/plant-dev")
TEND <- 3.5; AGES <- c(1, 1.5, 2, 2.5, 3)

cfg <- list(
  FF16 = list(env="FF16", trait=trait_matrix(0.0825, "lma")),
  TF24 = list(env="TF24", trait=trait_matrix(0.1978791, "lma")))

run_reg <- function(p, envnm, area, seed, offset = 0.5) {
  set.seed(seed); p$patch_area <- area; p$max_patch_lifetime <- TEND
  dt <- 1/(p$strategies[[1]]$birth_rate_y * area)
  aa <- seq(offset*dt, TEND, by = dt)
  ty  <- plant:::extract_RcppR6_template_types(p, "Parameters")
  obj <- do.call(plant:::StochasticPatchRunner, ty)(p, Environment(envnm), Control())
  sc  <- plant:::NodeSchedule(1); sc$max_time <- TEND; sc$set_times(aa, 1)
  obj$node_schedule <- sc
  tm <- c(); la <- c()
  snap <- function() { sp <- obj$patch$species[[1]]
    tm <<- c(tm, obj$patch$time); la <<- c(la, sp$compute_competition(0)/area) }
  snap(); while (!obj$complete) { obj$run_next(); snap() }
  ok <- !duplicated(tm); approx(tm[ok], la[ok], AGES, rule=2)$y
}

scm_lai <- function(p, envnm, bd) {
  ct <- Control(); ct$node_density_in_birth_date <- bd
  scm <- scm_collect(p, envnm, ct)
  tm <- vapply(seq_along(scm$history), function(k) scm$history[[k]]$time, 0)
  la <- vapply(seq_along(scm$history), function(k)
    scm$history[[k]]$species[[1]]$compute_competition(0), 0)
  vapply(AGES, function(a) la[which.min(abs(tm - a))], 0)
}

for (nm in names(cfg)) {
  cc <- cfg[[nm]]
  p <- add_strategies(scm_base_parameters(nm, paste0(nm,"_Env")), cc$trait)
  cat(sprintf("\n########## %s   birth_rate_y=%g ##########\n", nm, p$strategies[[1]]$birth_rate_y))
  for (bd in c(FALSE, TRUE)) {
    v <- scm_lai(p, cc$env, bd)
    cat(sprintf("SCM  bd=%-5s : %s\n", bd, paste(sprintf("%10.6f", v), collapse=" ")))
    assign(paste0("scm_", nm, "_", bd), v)
    flush.console()
  }
  cat(sprintf("%-14s : %s\n","ages",paste(sprintf("%10.1f", AGES), collapse=" ")))
  for (A in c(8, 16, 32, 64)) {
    ns <- if (A <= 32) 4 else 3
    LL <- t(vapply(seq_len(ns), function(k) run_reg(p, cc$env, A, 4440000+1000*A+k),
                   numeric(length(AGES))))
    cat(sprintf("IBM regular A=%-4g: %s   (n=%d, se %s)\n", A,
        paste(sprintf("%10.6f", colMeans(LL)), collapse=" "), ns,
        paste(sprintf("%.1e", apply(LL,2,sd)/sqrt(ns)), collapse=" ")))
    flush.console()
    assign(paste0("ibm_", nm, "_", A), colMeans(LL))
  }
  v0 <- get(paste0("scm_", nm, "_FALSE")); v1 <- get(paste0("scm_", nm, "_TRUE"))
  i64 <- get(paste0("ibm_", nm, "_64"))
  cat(sprintf("ratio SCM(ht)/IBM64 : %s\n", paste(sprintf("%10.4f", v0/i64), collapse=" ")))
  cat(sprintf("ratio SCM(bd)/IBM64 : %s\n", paste(sprintf("%10.4f", v1/i64), collapse=" ")))
}
