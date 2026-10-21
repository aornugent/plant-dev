options(width = 200)
suppressMessages(library(odelia))
dyn.load(file.path(find.package("plant"), "libs", "plant.so"), local = FALSE)
suppressMessages(library(plant))
Sys.setenv(PKG_CPPFLAGS = "-DXAD_NO_THREADLOCAL -DXAD_USE_STRONG_INLINE -fvisibility=hidden -fvisibility-inlines-hidden")
Rcpp::sourceCpp(file.path(Sys.getenv("S"), "live", "live.cpp"), cacheDir = file.path(Sys.getenv("S"), "live", Sys.getenv("CACHE")))
out <- NULL
for (L in as.numeric(strsplit(Sys.getenv("AGES", "0.5,1,2,4,8"), ",")[[1]])) {
  p <- scm_base_parameters("FF16"); p$max_patch_lifetime <- L
  p <- add_strategies(p, trait_matrix(0.0825, "lma"), birth_rate = list(1))
  scm <- run_scm(p, NULL, Control(node_density_in_birth_date = TRUE))
  r <- live_regions(scm$patch); r$L <- L; out <- rbind(out, r)
}
w <- reshape(out[, c("region", "L", "statements")], idvar = "region", timevar = "L", direction = "wide")
q <- reshape(out[, c("region", "L", "live_parameter_only")], idvar = "region", timevar = "L", direction = "wide"); d <- reshape(out[, c("region", "L", "dead")], idvar = "region", timevar = "L", direction = "wide")
cat("statements by patch age\n"); print(w, row.names = FALSE)
cat("dead by patch age\n"); print(d, row.names = FALSE); cat("live parameter-only\n"); print(q, row.names = FALSE)
