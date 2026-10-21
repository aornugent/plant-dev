suppressMessages(library(odelia))
dyn.load(file.path(find.package("plant"), "libs", "plant.so"), local = FALSE)
suppressMessages(library(plant))
Sys.setenv(PKG_CPPFLAGS = "-DXAD_NO_THREADLOCAL -DXAD_USE_STRONG_INLINE")
Rcpp::sourceCpp(file.path(Sys.getenv("S"), "tan", "probe_tangent_vec.cpp"), cacheDir = file.path(Sys.getenv("S"), "tan", "cachev"), rebuild = TRUE)
tm <- function(expr, n = 5) { e <- substitute(expr); f <- parent.frame(); median(replicate(n, system.time(eval(e, f))[["elapsed"]])) }
p <- scm_base_parameters("FF16"); p$max_patch_lifetime <- as.numeric(Sys.getenv("LT", "60"))
p <- add_strategies(p, trait_matrix(0.0825, "lma"), birth_rate = list(1))
ctrl <- Control(node_density_in_birth_date = TRUE)
run <- tm(run_scm(p, NULL, ctrl))
scm <- run_scm(p, NULL, ctrl, record_trajectory = TRUE)
g <- stand_gradient(scm)$gradient
for (w in c(1, 2, 4, 8, 16, 32)) {
  cols <- seq_len(w) - 1L
  r <- tangent_lanes_ff16(scm, cols, w)
  err <- max(abs(r - g[, cols + 1]) / pmax(abs(g[, cols + 1]), 1e-12))
  t <- tm(tangent_lanes_ff16(scm, cols, w), if (w >= 16) 3 else 5)
  cat(sprintf("width %2d: %.3f s = %.1fx forward, %.2fx per trait | worst rel vs reverse %.1e\n", w, t, t / run, t / run / w, err))
}
t_all <- tm(stand_gradient(scm), 3)
cat(sprintf("forward %.4f; reverse all 5 metrics x 32 traits %.3f (%.1fx)\n", run, t_all, t_all / run))
