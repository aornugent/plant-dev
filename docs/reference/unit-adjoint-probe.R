# Do trait adjoints accumulate across units, and what does a unit's tape cost?
# The design copies a mould Patch per unit. Strategy::ptr is a shared_ptr, so a copy
# SHARES the Strategy -- and field_ptrs() points into it -- so every unit seeds the same
# AD input and adjoints accumulate on one tape by construction. Giving each unit its own
# Strategy (Leaf-fix candidate 1) makes each a DISTINCT input, and then a single read is
# the silently-wrong number. Both arrangements are run here against the same frozen FD.
#   NOT_CRAN=true Rscript docs/reference/unit-adjoint-probe.R
pkgload::load_all("plant", quiet = TRUE)
library(odelia)
dlls <- getLoadedDLLs()
Sys.setenv(PKG_CXXFLAGS = paste0("-isystem/home/user/plant-dev/plant/inst/include",
                                 " -I", system.file("include", package = "odelia"),
                                 " -I", system.file("include", package = "BH")))
Sys.setenv(PKG_LIBS = paste(shQuote(dlls[["odelia"]][["path"]]),
                            shQuote(dlls[["plant"]][["path"]])))
Rcpp::sourceCpp("docs/reference/unit-adjoint-probe.cpp")

# The FD reference must be verified before any ratio is trusted (HANDOFF Part 1). Its
# error here is ROUNDOFF-dominated, so it improves as delta GROWS -- best agreement
# 3.4e-09 at d_rel 1e-3, degrading monotonically to 2.6e-04 at 1e-8. Hence 1e-3 below.
cat("== FD reference check: delta sweep, 2 units at segment 40 ==\n")
for (d in c(1e-3, 1e-4, 1e-5, 1e-6, 1e-7, 1e-8)) {
  r <- unit_adjoint_probe(20, 20, 2, 40, d)
  cat(sprintf("d_rel %.0e   AD %.12g   FD %.12g   rel %.3e\n",
              d, r$shared_adjoint, r$fd, abs(r$shared_adjoint - r$fd) / abs(r$fd)))
}

for (nu in c(2, 4)) {
  r <- unit_adjoint_probe(20, 20, nu, 40, 1e-3)
  cat(sprintf("\n== %d units, starting at segment %d ==\n", r$units, r$first_unit))
  cat(sprintf("Patch COPY shares the Strategy (so shares the AD input): %s\n",
              ifelse(r$copy_shares_strategy == 1, "YES", "no")))
  cat(sprintf("Patch built FRESH from Parameters shares it:              %s\n",
              ifelse(r$fresh_shares_strategy == 1, "YES", "no")))
  cat(sprintf("value                       %.10g\n", r$value))
  cat(sprintf("shared-Strategy adjoint     %.10g\n", r$shared_adjoint))
  cat(sprintf("per-unit adjoints           %s\n",
              paste(signif(r$per_unit_adjoints, 8), collapse = ", ")))
  cat(sprintf("sum of per-unit adjoints    %.10g\n", r$sum_per_unit))
  cat(sprintf("frozen-trajectory FD        %.10g\n", r$fd))
  cat(sprintf("rel |shared - FD|           %.3e\n",
              abs(r$shared_adjoint - r$fd) / abs(r$fd)))
  cat(sprintf("rel |sum - shared|          %.3e\n",
              abs(r$sum_per_unit - r$shared_adjoint) / abs(r$shared_adjoint)))
  cat(sprintf("ONE unit's adjoint alone is %.1f%% of the total -- the silent-wrong number\n",
              100 * r$per_unit_adjoints[length(r$per_unit_adjoints)] / r$sum_per_unit))
  cat(sprintf("tape per unit               %.0f bytes, %.0f ops\n",
              r$tape_bytes_per_unit, r$tape_ops_per_unit))
}
