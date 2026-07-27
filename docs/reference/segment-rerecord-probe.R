# Does one event segment re-run reproduce the forward pass?
#   rebuilt_abs   -- rebuilt from the stored ODE state alone
#   from_copy_abs -- re-run from a whole copy of the Patch
#   worst_comp    -- which Node component carries the error (see component_names)
# from_copy_abs is exactly 0 for K93/FF16 and NOT for TF24: TF24's Leaf is shared
# through a Strategy pointer, so a Patch copy inherits end-of-run leaf state.
#   NOT_CRAN=true Rscript docs/reference/segment-rerecord-probe.R
#
# NOTE: the node-set columns this driver used to print are gone on purpose. The
# metric was malformed -- it compared the forward pass *entering* a segment against
# the rebuilt patch *leaving* it -- and was retracted as evidence.
pkgload::load_all("plant", quiet = TRUE)
library(odelia)
dlls <- getLoadedDLLs()
Sys.setenv(PKG_CXXFLAGS = paste0("-isystem/home/user/plant-dev/plant/inst/include",
                                 " -I", system.file("include", package = "odelia"),
                                 " -I", system.file("include", package = "BH")))
Sys.setenv(PKG_LIBS = paste(shQuote(dlls[["odelia"]][["path"]]),
                            shQuote(dlls[["plant"]][["path"]])))
Rcpp::sourceCpp("docs/reference/segment-rerecord-probe.cpp")
for (m in c("K93", "FF16", "TF24")) {
  r <- segment_rerecord_probe(m, 20, 20, 10)
  cat(sprintf("\n%s: %d segments over %d ode steps (%.2f steps/segment)\n",
              m, r$segments, r$ode_steps, r$ode_steps / r$segments))
  print(data.frame(segment = r$probed,
                   rebuilt_abs = signif(r$max_abs, 3),
                   from_copy_abs = signif(r$from_copy_abs, 3),
                   worst_comp = r$component_names[r$worst_component + 1L]))
}
