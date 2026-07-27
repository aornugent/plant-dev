# A1/A2: does the CHAINED state adjoint work in plant, and does a newborn created inside a
# unit carry its adjoint? This is the design's central mechanism; before this probe it had
# only ever run on an odelia toy (in plant, everything was either a whole-run single tape or
# a unit on a FROZEN trajectory where the entering state is a tape constant).
#
#   REFERENCE : one tape over N consecutive units, state flowing naturally
#   CHAINED   : N tapes walked backwards, lambda carried between them
# Agreement on BOTH the trait adjoint and lambda at the first unit is the result.
# The units are chosen to OPEN WITH AN INTRODUCTION, so the newborn is created on tape
# inside the unit -- that is A2.
#   NOT_CRAN=true Rscript docs/reference/chained-adjoint-probe.R
pkgload::load_all("plant", quiet = TRUE)
library(odelia)
dlls <- getLoadedDLLs()
Sys.setenv(PKG_CXXFLAGS = paste0("-isystem/home/user/plant-dev/plant/inst/include",
                                 " -I", system.file("include", package = "odelia"),
                                 " -I", system.file("include", package = "BH")))
Sys.setenv(PKG_LIBS = paste(shQuote(dlls[["odelia"]][["path"]]),
                            shQuote(dlls[["plant"]][["path"]])))
Rcpp::sourceCpp("docs/reference/chained-adjoint-probe.cpp")

cat("== A2 prior question: is a newborn's initial condition stand-dependent here? ==\n")
s <- newborn_state_sensitivity(20, 20, 40, 1e-4)
cat(sprintf("state width %d, species introduced %d\n", s$n_state, s$introduced))
print(data.frame(component = s$component_names,
                 newborn_initial = signif(s$newborn_base, 8),
                 max_move = signif(s$max_move_per_component, 3)))
cat(sprintf("worst movement of the newborn's IC over ALL %d entering-state perturbations: %.3e\n",
            s$n_state, s$worst_move))

cat("\n== A1/A2: chained lambda vs a single-tape reference ==\n")
# kind 0 first, to SHOW the vacuity, then kind 1 which is the real test.
for (cfg in list(list(3, 0), list(3, 1), list(6, 1), list(12, 1))) {
  nu <- cfg[[1]]; kind <- cfg[[2]]
  r <- chained_adjoint_probe(20, 20, nu, 40, TRUE, kind)
  rel_t <- abs(r$chained_trait_adjoint - r$ref_trait_adjoint) / abs(r$ref_trait_adjoint)
  rel_l <- if (r$lambda_scale > 0) r$lambda_worst_abs / r$lambda_scale else NA
  cat(sprintf("\n%d units (%d open with an introduction), width %d, functional %s\n",
              r$units, r$units_with_introduction, r$n_state_first_unit,
              ifelse(kind == 0, "summed height (lambda is TRIVIAL -- weak test)",
                                "density-weighted height")))
  cat(sprintf("  lambda structure: %d/%d nonzero, %d distinct values%s\n",
              r$lambda_nonzero, r$n_state_first_unit, r$lambda_distinct,
              ifelse(r$lambda_distinct <= 2, "  <-- too degenerate to detect much", "")))
  cat(sprintf("  trait adjoint  reference %.12g   chained %.12g   rel %.3e\n",
              r$ref_trait_adjoint, r$chained_trait_adjoint, rel_t))
  cat(sprintf("  lambda at first unit: worst abs %.3e over scale %.3e -> rel %.3e\n",
              r$lambda_worst_abs, r$lambda_scale, rel_l))
  cat(sprintf("  per-unit trait contributions: %s\n",
              paste(signif(r$per_unit_trait, 6), collapse = ", ")))
}
