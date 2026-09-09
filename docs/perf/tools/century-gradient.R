# One century gradient on scripts/forward-century-schedule.rds, the fixture
# profile-stand-reverse.R uses, built the same way. MODE=time prints the timed
# ladder call and its four counts; MODE=values prints the whole gradient matrix
# at full precision. The two are separate processes because
# census_trait_gradient is non-const, so a value read after a timed sweep would
# be a value read after a mutation.
suppressMessages(library(odelia))
suppressMessages(library(plant))

mode <- Sys.getenv("MODE", "time")
arm  <- Sys.getenv("ARM", "?")

cat("arm               ", arm, "\n")
cat("mode              ", mode, "\n")
cat("phylloptim_lib    ", dirname(system.file(package = "phylloptim")), "\n")
cat("plant_lib         ", dirname(system.file(package = "plant")), "\n")
cat("odelia_lib        ", dirname(system.file(package = "odelia")), "\n")
cat("phylloptim_ver    ", as.character(packageVersion("phylloptim")), "\n")
cat("odelia_ver        ", as.character(packageVersion("odelia")), "\n")
cat("plant_ver         ", as.character(packageVersion("plant")), "\n")
# Which vulnerability.hpp this arm's plant was compiled against -- the one thing
# that distinguishes the arms, read out of the installed header rather than
# assumed.
hdr <- system.file("include", "phylloptim", "vulnerability.hpp",
                   package = "phylloptim")
cat("policy_in_header  ",
    any(grepl("promote_double", readLines(hdr, warn = FALSE))), "\n")

tr <- c(lma = 0.0825, hmat = 5.13, k_I = 0.5, a_l1 = 5.44, a_l2 = 0.306)
ctrl <- Control(node_density_in_birth_date = TRUE)
p <- scm_base_parameters("TF24")
p <- add_strategies(p, trait_matrix(unname(tr), names(tr)),
                    hyperpar = TF24_hyperpar, birth_rate = list(1.10))
sched <- readRDS("scripts/forward-century-schedule.rds")
p$max_patch_lifetime  <- sched$max_patch_lifetime
p$node_schedule_times <- sched$node_schedule_times
p$ode_times           <- sched$ode_times

args <- list(p, Environment("TF24"), ctrl, refine_schedule = FALSE,
             collect = FALSE, record_trajectory = TRUE)
t_fwd <- system.time(scm <- do.call(run_scm, args))[["elapsed"]]
cat("steps             ", length(scm$ode_times) - 1L, "\n")
cat("forward_s         ", round(t_fwd, 2), "\n")
flush(stdout())

if (mode == "smoke") {
  cat("metric_names      ",
      paste(plant:::census_metric_names_tf24(), collapse = ","), "\n")
  cat("trait_names       ",
      paste(plant:::census_trait_names_tf24(scm), collapse = ","), "\n")
  cat("SMOKE OK\n")
  quit(save = "no")
}

if (mode == "time") {
  t <- system.time(counts <- plant:::ladder_boundary_evaluations_tf24(scm))[["elapsed"]]
  cat("gradient_s        ", round(t, 2), "\n")
  cat("rate_evaluations  ", counts$evaluations, "\n")
  cat("placements        ", counts$placements, "\n")
  cat("swept_ranges      ", counts$ranges, "\n")
  cat("metrics           ", counts$metrics, "\n")
  cat("refusal           ",
      if (nzchar(counts$refusal)) counts$refusal else "none", "\n")
} else {
  t <- system.time(g <- plant:::census_trait_gradient_tf24(scm))[["elapsed"]]
  cat("gradient_s        ", round(t, 2), "\n")
  cat("swept_ranges      ", g$ranges, "\n")
  metrics <- plant:::census_metric_names_tf24()
  traits  <- plant:::census_trait_names_tf24(scm)
  cat("n_metrics         ", length(g$gradient), "\n")
  cat("metric_names      ", paste(metrics, collapse = ","), "\n")
  cat("trait_names       ", paste(traits, collapse = ","), "\n")
  for (m in seq_along(g$gradient)) {
    r <- g$refusal[[m]]
    cat("refusal_metric    ", metrics[m], " ",
        if (is.null(r)) "none" else paste0(r$reason, " [sp ", r$species, "]"),
        "\n", sep = "")
  }
  # ⚠️ identical(NaN, NaN) is TRUE, so the finite count is printed and asserted
  # before any value is compared.
  vals <- unlist(g$gradient)
  cat("n_entries         ", length(vals), "\n")
  cat("n_finite          ", sum(is.finite(vals)), "\n")
  cat("n_nan             ", sum(is.nan(vals)), "\n")
  # One line per entry, tagged, so a diff names the cell that moved.
  for (m in seq_along(g$gradient)) {
    row <- g$gradient[[m]]
    for (j in seq_along(row)) {
      cat(sprintf("G\t%s\t%s\t%.17g\n", metrics[m], traits[j], row[j]))
    }
  }
  # Last, and guarded: this one is not a gradient entry and must not be able
  # to cost the entries above.
  try(cat("at_first_state    ",
          paste(sprintf("%.17g", unlist(g$at_first_state)), collapse = " "),
          "\n"), silent = TRUE)
}
flush(stdout())
