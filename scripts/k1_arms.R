suppressMessages({library(odelia); pkgload::load_all("/home/user/plant-develop", quiet=TRUE)})
p <- add_strategies(scm_base_parameters("TF24","TF24_Env"), trait_matrix(0.1978791,"lma"))
p$max_patch_lifetime <- 105.32
t0 <- Sys.time()
scm <- run_scm(p, Environment("TF24"), Control(), refine_schedule=FALSE)
cat(sprintf("RESULT arm=%s steps=%d offspring=%.15e secs=%.1f\n",
            Sys.getenv("PLANT_K1_FIX", "unfixed"), length(scm$ode_times),
            scm$offspring_production[1], as.numeric(difftime(Sys.time(), t0, units="secs"))))
