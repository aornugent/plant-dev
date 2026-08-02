# The FF16 and K93 cross-model tripwire, at the configuration their reference
# numbers belong to: per-model trait AND hyperpar, the default patch lifetime,
# and sum(offspring_production). TF24's configuration is different and mixing
# them has produced a false alarm; see ORCHESTRATOR.md section 11.5.
#
#   Rscript scripts/build/ff16k93.R <plant worktree> [tag]
#
# On plant p3/phase-3 893e8ad5 this prints
#   FF16 19.834058960443031  209 steps
#   K93  0.030538172107758225  240 steps
# FF16 is the discriminating arm: K93 returns the same value under TF24's
# configuration too, so K93 agreeing proves nothing about the configuration.

args <- commandArgs(TRUE)
tree <- args[1]
tag  <- if (length(args) > 1) args[2] else ""
if (is.na(tree)) stop("give the plant worktree as the first argument")

suppressMessages({ library(odelia); pkgload::load_all(tree, quiet = TRUE) })

p <- add_strategies(scm_base_parameters("FF16"), trait_matrix(0.0825, "lma"), hyperpar = FF16_hyperpar)
s <- run_scm(p, Environment("FF16"), Control(), collect = FALSE)
cat(sprintf("%s FF16 %.17g  %d steps\n", tag, sum(s$offspring_production), length(s$ode_times)))

p <- add_strategies(scm_base_parameters("K93"), trait_matrix(0.059, "b_0"), hyperpar = K93_hyperpar)
s <- run_scm(p, Environment("K93"), Control(), collect = FALSE)
cat(sprintf("%s K93  %.17g  %d steps\n", tag, sum(s$offspring_production), length(s$ode_times)))
