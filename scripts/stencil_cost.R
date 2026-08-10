# Does the FD transport stencil dominate TF24's cost? growth_rate_gradient calls
# growth_rate_given_height at a perturbed height, which for TF24 runs a whole
# extra leaf solve per cohort per RHS evaluation. Richardson extrapolation adds
# more probes, so runtime scaling in probe count prices the stencil directly.
suppressMessages({ library(odelia); pkgload::load_all("plant", quiet = TRUE) })
p0 <- scm_base_parameters("TF24", "TF24_Env"); p0$max_patch_lifetime <- 20
p <- add_strategies(p0, trait_matrix(0.1978791, "lma"))
run <- function(rich, depth = 2) {
  ctrl <- Control()
  ctrl$node_gradient_richardson <- rich
  if (rich) ctrl$node_gradient_richardson_depth <- depth
  t0 <- Sys.time()
  r <- run_scm(p, Environment("TF24"), ctrl, collect = TRUE, refine_schedule = FALSE)
  list(s = as.numeric(Sys.time() - t0, "secs"), off = sum(r$offspring_production),
       steps = nrow(r$steps))
}
a <- run(FALSE)
cat(sprintf("one-sided FD (default): %6.1f s   offspring %.6g\n", a$s, a$off))
for (dp in c(2, 3)) {
  b <- run(TRUE, dp)
  cat(sprintf("Richardson depth %d    : %6.1f s   offspring %.6g   ratio %.2f\n",
              dp, b$s, b$off, b$s / a$s))
}
