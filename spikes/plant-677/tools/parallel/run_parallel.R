suppressMessages(library(odelia))
dyn.load(file.path(find.package("plant"), "libs", "plant.so"), local = FALSE)
suppressMessages(library(plant))
Sys.setenv(PKG_CPPFLAGS = "-DXAD_USE_STRONG_INLINE -fvisibility=hidden -fvisibility-inlines-hidden")
Rcpp::sourceCpp(file.path(Sys.getenv("S"), "par", "probe_parallel.cpp"), cacheDir = file.path(Sys.getenv("S"), "par", "cache"), rebuild = TRUE)
p <- scm_base_parameters("FF16"); p$max_patch_lifetime <- 60
p <- add_strategies(p, trait_matrix(0.0825, "lma"), birth_rate = list(1))
scm <- run_scm(p, NULL, Control(node_density_in_birth_date = TRUE))
for (th in c(2, 4)) for (r in 1:3) { v <- probe_parallel(scm$patch, 20L, th); cat(sprintf("threads %d: serial %.3f s, parallel %.3f s, speed-up %.2fx  (statements %d / %d)\n", th, v[1], v[2], v[1]/v[2], v[3], v[4])) }
