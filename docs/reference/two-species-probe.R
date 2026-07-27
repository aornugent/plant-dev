# Two species: what the one-species measurements could not see.
# (A) the separable field is assembled with ONE canopy (patch.h:757-759, species 0's),
#     but eta is a per-strategy trait. How wrong is a source whose eta differs?
# (B) does a two-species segment replay still reproduce, rebuilt and copied? (tie-break
#     determinism across a rebuild -- K93, whose species differ without the eta problem)
# (C) is "species 0 empty, species 1 not" reachable? patch.h:758 would then dereference
#     an empty vector. Counted, never executed.
#
# A two-species FF16 SCM is too fragile to carry (A): eta=2, and eta=4 at birth_rate 20
# over a 20-year lifetime, both trip plant's own non-finite-density guard, and at 12 steps
# the field is still exactly 1.0 everywhere so the comparison is vacuous. (A) is therefore
# done against the exact kernel with no SCM at all, which is also sharper.
#   NOT_CRAN=true Rscript docs/reference/two-species-probe.R
pkgload::load_all("plant", quiet = TRUE)
library(odelia)
dlls <- getLoadedDLLs()
Sys.setenv(PKG_CXXFLAGS = paste0("-isystem/home/user/plant-dev/plant/inst/include",
                                 " -I", system.file("include", package = "odelia"),
                                 " -I", system.file("include", package = "BH")))
Sys.setenv(PKG_LIBS = paste(shQuote(dlls[["odelia"]][["path"]]),
                            shQuote(dlls[["plant"]][["path"]])))
Rcpp::sourceCpp("docs/reference/two-species-probe.cpp")

cat("== (A) one shared query-factor set, a source of a different eta ==\n")
cat("Q(z,H) exact vs the rank-3 value the field computes. H = 10.\n")
for (es in list(c(12, 12), c(12, 10), c(12, 8), c(12, 4))) {
  o <- canopy_mixed_eta_probe(es[1], es[2], 10)
  cat(sprintf("\neta_query %g, eta_source %g: worst |rank3 - exact| = %.4f\n",
              es[1], es[2], o$worst_abs))
  if (es[1] != es[2]) {
    print(data.frame(z = o$z, exact = signif(o$exact, 6),
                     rank3 = signif(o$rank3, 6), abs_err = signif(o$abs_err, 3)))
  }
}

cat("\n== (B) two-species K93 segment replay, and (C) empty-first-species reachability ==\n")
r <- two_species_replay_probe(1.15, 10, 20, 10)
cat(sprintf("%d segments over %d ode steps; segments with species 0 empty while another is not: %d\n",
            r$segments, r$ode_steps, r$empty_first_species_segments))
print(data.frame(segment = r$probed,
                 width_sp0 = r$width_sp0,
                 width_sp1 = r$width_sp1,
                 rebuilt_abs = signif(r$rebuilt_abs, 3),
                 copy_abs = signif(r$copy_abs, 3)))
