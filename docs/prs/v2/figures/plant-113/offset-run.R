# plant-113: one run of a stand at one storage_relaxation_offset, on B97.
#   PLANT_LIB=<lib> Rscript offset-run.R <scenario> <offset_days> <out.csv>
# scenario: synthetic (harness/long_drought.R: the synthetic 41-year record,
#   108 introductions, birth date, ode_tol 1e-3, a stop at every rain knot;
#   then an invader at lma x2 on the resident's steps), or one of plant's
#   reference regimes (ladder_reference_regimes(): wet, drought, seasonal,
#   shaded, clamped) on a 10-year one-species stand with the regime's fixture
#   traits, birth rate 1.10, the default schedule (93 introductions), birth
#   date and the default ode_tol 1e-4.
args <- commandArgs(TRUE)
scen <- args[[1]]; offset <- suppressWarnings(as.numeric(args[[2]])); out <- args[[3]]
lib <- Sys.getenv("PLANT_LIB")
if (scen == "synthetic") {
  source("/home/user/plant-dev/harness/long_drought.R")
} else {
  .libPaths(c(lib, .libPaths()))
  suppressMessages({library(odelia); library(plant)})
  source(file.path(lib, "..", "src-helpers", "helper-gradient-ladder.R"))
}
source("/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/v2/probe/load_probe.R")
load_rejection_probe(lib)
cpu <- function(t) sum(t[c("user.self", "sys.self")])
# offset "base": leave the parameter alone (B93 has none).
set_offset <- function(p) {
  if (is.na(offset)) return(p)
  for (i in seq_along(p$strategies))
    p$strategies[[i]]$pars$storage_relaxation_offset <- offset / 365
  p
}
invader <- NA_character_
if (scen == "synthetic") {
  times <- uniform_times(108)
  p <- set_offset(stand_at(times))
  ctrl <- Control(node_density_in_birth_date = TRUE,
                  ode_tol_rel = 1e-3, ode_tol_abs = 1e-3)
  env <- mkenv(); ev <- events(events_default(p), pulse_rows(AK))
} else {
  rg <- Filter(function(r) r$name == scen, ladder_reference_regimes())[[1]]
  lifetime <- 10
  p <- scm_base_parameters("TF24"); p$max_patch_lifetime <- lifetime
  k <- if (is.null(rg$k_I)) 0.5 else rg$k_I
  tr <- c(lma = 0.0825, hmat = 5.13, k_I = k, a_l1 = 5.44, a_l2 = 0.306)
  p <- add_strategies(p, trait_matrix(unname(tr), names(tr)),
                      hyperpar = TF24_hyperpar, birth_rate = list(1.10))
  p <- set_offset(p)
  ctrl <- Control(node_density_in_birth_date = TRUE)
  env <- ladder_environment(rg$rain, rg$amplitude, lifetime); ev <- NULL
}
t0 <- proc.time()
scm <- tryCatch(run_scm(p, env, ctrl, events = ev), error = function(e) conditionMessage(e))
t1 <- cpu(proc.time() - t0)
row <- if (is.character(scm)) {
  data.frame(scenario = scen, offset_days = offset, J = NA, accepted = NA,
             rejected = NA, cpu_s = t1, error = scm, median_step_d = NA, p90_step_d = NA)
} else {
  data.frame(scenario = scen, offset_days = offset,
             J = sum(scm$offspring_production),
             accepted = length(scm$ode_times) - 1,
             rejected = scm_rejections_tf24(scm$.ptr), cpu_s = t1, error = "",
             median_step_d = 365 * median(diff(scm$ode_times)),
             p90_step_d = 365 * unname(quantile(diff(scm$ode_times), 0.9)))
}
if (scen == "synthetic" && !is.character(scm)) {
  t0 <- proc.time()
  invader <- tryCatch({
    scm$run_mutant(set_offset(stand_at(times, "lma", 2)))
    sprintf("J' %.4g", sum(scm$offspring_production))
  }, error = function(e) paste("Error:", substr(conditionMessage(e), 1, 120)))
  row$invader_x2 <- invader
  row$invader_cpu_s <- cpu(proc.time() - t0)
} else {
  row$invader_x2 <- NA; row$invader_cpu_s <- NA
}
row$build <- basename(lib)
print(row)
write.table(row, out, sep = ",", row.names = FALSE, append = file.exists(out),
            col.names = !file.exists(out))
