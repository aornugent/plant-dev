# Is the restore path lossy because it drops the birth stamps?
#   plain_*   -- r_set_state alone (state + counts + light spline). THE CURRENT PATH.
#   stamped_* -- the same, plus Species::set_birth_state restoring the three per-node
#                birth stamps (introduction time, patch density, pr_patch_survival).
# Identical in every other respect, so the difference isolates the stamps.
# Compare against segment-rerecord-probe's from_copy_abs (exactly 0 for K93/FF16):
# that is the ceiling this path should reach if the stamps are the whole story.
#   NOT_CRAN=true Rscript docs/reference/restore-stamp-probe.R
pkgload::load_all("plant", quiet = TRUE)
library(odelia)
dlls <- getLoadedDLLs()
Sys.setenv(PKG_CXXFLAGS = paste0("-isystem/home/user/plant-dev/plant/inst/include",
                                 " -I", system.file("include", package = "odelia"),
                                 " -I", system.file("include", package = "BH")))
Sys.setenv(PKG_LIBS = paste(shQuote(dlls[["odelia"]][["path"]]),
                            shQuote(dlls[["plant"]][["path"]])))
Rcpp::sourceCpp("docs/reference/restore-stamp-probe.cpp")
for (m in c("K93", "FF16", "TF24")) {
  r <- restore_stamp_probe(m, 20, 20, 10)
  cat(sprintf("\n%s: %d segments over %d ode steps\n", m, r$segments, r$ode_steps))
  print(data.frame(segment = r$probed,
                   plain_abs = signif(r$plain_abs, 3),
                   plain_rel = signif(r$plain_rel, 3),
                   stamped_abs = signif(r$stamped_abs, 3),
                   stamped_rel = signif(r$stamped_rel, 3),
                   ref_at_abs = signif(r$plain_ref, 3),
                   plain_worst = r$component_names[r$plain_worst + 1L],
                   stamped_worst = r$component_names[r$stamped_worst + 1L]))
}
