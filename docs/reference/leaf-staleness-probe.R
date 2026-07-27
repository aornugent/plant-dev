# Is TF24's inexact segment re-run caused by stale shared Leaf state?
#
#   deferred_abs -- replay after the full forward pass  (leaf = end-of-run)
#   inline_abs   -- replay before the forward pass advances past the segment
#                                                        (leaf = entering that segment)
# Both against the same reference: the undisturbed forward pass leaving that segment.
#
# If staleness is the cause, inline must be exactly 0 where deferred is not. FF16 and
# K93 are the controls -- they have no leaf, so both columns must be 0 for them.
#   NOT_CRAN=true Rscript docs/reference/leaf-staleness-probe.R
pkgload::load_all("plant", quiet = TRUE)
library(odelia)
dlls <- getLoadedDLLs()
Sys.setenv(PKG_CXXFLAGS = paste0("-isystem/home/user/plant-dev/plant/inst/include",
                                 " -I", system.file("include", package = "odelia"),
                                 " -I", system.file("include", package = "BH")))
Sys.setenv(PKG_LIBS = paste(shQuote(dlls[["odelia"]][["path"]]),
                            shQuote(dlls[["plant"]][["path"]])))
Rcpp::sourceCpp("docs/reference/leaf-staleness-probe.cpp")

rows <- list()
for (m in c("TF24", "FF16", "K93")) {
  for (seg in c(20L, 40L, 60L)) {
    r <- leaf_staleness_probe(m, 20, 20, seg)
    if (!isTRUE(r$ok)) next
    rows[[length(rows) + 1]] <- data.frame(
      model = m, segment = r$segment, steps = r$steps_in_segment,
      deferred_abs = signif(r$deferred_abs, 3), deferred_worst = r$deferred_worst,
      inline_abs = signif(r$inline_abs, 3), inline_worst = r$inline_worst)
    cat(sprintf("%-5s seg %-3d steps=%-3d deferred=%-10.3g (%s)  inline=%-10.3g (%s)\n",
                m, r$segment, r$steps_in_segment, r$deferred_abs, r$deferred_worst,
                r$inline_abs, r$inline_worst))
    flush(stdout())
  }
}
cat("\n")
print(do.call(rbind, rows), row.names = FALSE)
