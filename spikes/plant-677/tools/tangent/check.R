suppressMessages(library(odelia))
dyn.load(file.path(find.package("plant"), "libs", "plant.so"), local = FALSE)
suppressMessages(library(plant))
Sys.setenv(PKG_CPPFLAGS = "-DXAD_NO_THREADLOCAL -DXAD_USE_STRONG_INLINE")
Rcpp::sourceCpp(file.path(Sys.getenv("S"), "tan", "probe_tangent_vec.cpp"), cacheDir = file.path(Sys.getenv("S"), "tan", "cachev"))
p <- scm_base_parameters("FF16"); p$max_patch_lifetime <- 60
p <- add_strategies(p, trait_matrix(0.0825, "lma"), birth_rate = list(1))
scm <- run_scm(p, NULL, Control(node_density_in_birth_date = TRUE), record_trajectory = TRUE)
g <- stand_gradient(scm)$gradient
r4 <- tangent_lanes_ff16(scm, 0:3, 4); r1 <- sapply(0:3, function(j) tangent_lanes_ff16(scm, j, 1)[, 1])
print(signif(cbind(reverse = g[, 4], width1 = r1[, 4], width4 = r4[, 4]), 12))
cat("width4 vs width1, max rel:", max(abs(r4 - r1) / abs(r1)), "\n")
print(signif(abs(r4 - g[, 1:4]) / abs(g[, 1:4]), 2))
