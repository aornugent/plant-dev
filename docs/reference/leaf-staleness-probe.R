# Is TF24's inexact segment re-run caused by stale shared Leaf state -- and does it happen on
# the path the DESIGN uses?
#
#   deferred_abs -- replay after the full forward pass  (leaf = end-of-run)
#   inline_abs   -- replay before the forward pass advances past the segment
#                                                        (leaf = entering that segment)
# Both against the same reference: the undisturbed forward pass leaving that segment.
#
# restore_mode selects how the replay is set up (see the .cpp header):
#   0 COPY           advance the Patch copy directly -- the ORIGINAL measurement
#   1 REBUILT        copy, then r_set_state from stored plain values -- THE DESIGN'S UNIT
#   2 REBUILT+STAMPS mode 1 plus set_birth_state, so the stamp drift of v3-facts 4b cannot
#                    be mistaken for a leaf effect
#
# READ THE POSITIVE CONTROL FIRST. Mode 0 on TF24 must still show the deferred/inline split
# (1.84e-13 / 4.99e-11 / 1.30e-08 against exactly 0). If it does not, this probe can no
# longer detect staleness at all and a null mode-1 result is indistinguishable from a broken
# probe -- conclude nothing. FF16 and K93 have no leaf, so both columns must be 0 for them.
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

modes <- c("0 copy (control)", "1 rebuilt (design)", "2 rebuilt+stamps")
rows <- list()
for (mode in 0:2) {
  for (m in c("TF24", "FF16", "K93")) {
    if (mode == 2 && m != "TF24") next   # the stamp variant only adds signal on TF24
    for (seg in c(20L, 40L, 60L)) {
      r <- leaf_staleness_probe(m, 20, 20, seg, mode)
      if (!isTRUE(r$ok)) next
      rows[[length(rows) + 1]] <- data.frame(
        mode = modes[mode + 1L], model = m, segment = r$segment,
        steps = r$steps_in_segment,
        deferred_abs = signif(r$deferred_abs, 3), deferred_worst = r$deferred_worst,
        inline_abs = signif(r$inline_abs, 3), inline_worst = r$inline_worst,
        split = ifelse(is.na(r$deferred_abs) || is.na(r$inline_abs), NA,
                       ifelse(r$deferred_abs == r$inline_abs, "none", "SPLIT")))
      flush(stdout())
    }
  }
}
print(do.call(rbind, rows), row.names = FALSE)

cat("\n== QC-2: the leaf's per-solve fields, before and after r_set_state (TF24) ==\n")
for (seg in c(20L, 40L, 60L)) {
  s <- leaf_state_around_restore(20, 20, seg)
  if (!isTRUE(s$ok)) next
  cat(sprintf("segment %d\n", s$segment))
  print(data.frame(field = names(s$before),
                   before = signif(as.numeric(s$before), 8),
                   after = signif(as.numeric(s$after), 8)), row.names = FALSE)
}
