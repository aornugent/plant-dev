options(width = 220)
suppressMessages(library(odelia))
dyn.load(file.path(find.package("plant"), "libs", "plant.so"), local = FALSE)
suppressMessages(library(plant))
Sys.setenv(PKG_CPPFLAGS = "-DXAD_NO_THREADLOCAL -DXAD_USE_STRONG_INLINE -fvisibility=hidden -fvisibility-inlines-hidden")
Rcpp::sourceCpp(file.path(Sys.getenv("S"), "live", "live5.cpp"), cacheDir = file.path(Sys.getenv("S"), "live", Sys.getenv("CACHE")), rebuild = TRUE)
out <- NULL
for (L in as.numeric(strsplit(Sys.getenv("AGES", "10,20,40,60"), ",")[[1]])) {
  p <- scm_base_parameters("FF16"); p$max_patch_lifetime <- L
  p <- add_strategies(p, trait_matrix(0.0825, "lma"), birth_rate = list(1))
  scm <- run_scm(p, NULL, Control(node_density_in_birth_date = TRUE))
  r <- live_regions(scm$patch); r$L <- L; r$nodes <- scm$patch$species[[1]]$size; out <- rbind(out, r)
}
print(out, row.names = FALSE)
saveRDS(out, file.path(Sys.getenv("S"), "live", paste0("live5_", Sys.getenv("CACHE"), ".rds")))
