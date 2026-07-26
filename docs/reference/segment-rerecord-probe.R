# Does one event segment re-run from a stored state reproduce the forward pass, and
# does the rebuilt patch choose the same spline nodes?
#   NOT_CRAN=true Rscript docs/reference/segment-rerecord-probe.R
pkgload::load_all("plant", quiet = TRUE)
library(odelia)
dlls <- getLoadedDLLs()
Sys.setenv(PKG_CXXFLAGS = paste0("-isystem/home/user/plant-dev/plant/inst/include",
                                 " -I", system.file("include", package = "odelia"),
                                 " -I", system.file("include", package = "BH")))
Sys.setenv(PKG_LIBS = paste(shQuote(dlls[["odelia"]][["path"]]),
                            shQuote(dlls[["plant"]][["path"]])))
Rcpp::sourceCpp("docs/reference/segment-rerecord-probe.cpp")
for (m in c("K93", "FF16")) {
  r <- segment_rerecord_probe(m, 20, 20, 10)
  cat(sprintf("\n%s: %d segments over %d ode steps (%.2f steps/segment)\n",
              m, r$segments, r$ode_steps, r$ode_steps / r$segments))
  print(data.frame(segment = r$probed, rebuilt_abs = signif(r$max_abs, 3), from_copy_abs = signif(r$from_copy_abs, 3),
                   fwd_nodes = r$fwd_nodes, rebuilt_nodes = r$reb_nodes,
                   nodes_match = r$nodes_match))
}
