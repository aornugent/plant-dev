# The unmodified build (PLANT_LIB=rt/lib): the same fixture's values and gradients.
source(file.path(Sys.getenv("CHECKS"), "fixture.R"))
res <- fixture_run()
gr <- stand_gradient(res, metrics = "1.offspring_production")
res$record_trajectory <- TRUE
res$run_mutant(fixture_parameters(1))
gi <- stand_gradient(res, metrics = "1.net_reproduction_ratio")
saveRDS(list(J = res$offspring_production, gr = gr, gi = gi,
             R = res$net_reproduction_ratios),
        file.path(Sys.getenv("CHECKS"), paste0("baseline-", NODES, ".rds")))
