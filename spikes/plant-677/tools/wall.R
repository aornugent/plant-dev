suppressMessages(library(plant))
tm <- function(expr, n = 5) { e <- substitute(expr); f <- parent.frame(); median(replicate(n, system.time(eval(e, f))[["elapsed"]])) }
p <- scm_base_parameters("FF16"); p$max_patch_lifetime <- 30
p <- add_strategies(p, trait_matrix(0.0825, "lma"), birth_rate = list(1))
ctrl <- Control(node_density_in_birth_date = TRUE)
run <- tm(run_scm(p, NULL, ctrl))
scm <- run_scm(p, NULL, ctrl, record_trajectory = TRUE)
one <- tm(stand_gradient(scm, metrics = names(stand_census(scm))[1]))
all <- tm(stand_gradient(scm), 3)
cat(sprintf("%s run=%.4f one-metric=%.3f (%.1fx) all-%d-metrics=%.3f (%.1fx)\n", Sys.getenv("ARM"), run, one, one/run, length(stand_census(scm)) + length(stand_fitness(scm)), all, all/run))
