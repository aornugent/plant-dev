# The leaf's derivative path called through Rcpp against one phylloptim build:
#   Rscript leaf_rows.R <phylloptim lib> <odelia lib> <label> <out prefix>
# writes <out prefix>_G.csv (the root integral and its root_P50 row against psi)
# and <out prefix>_collar.csv (the collar's bounds and row against psi_soil).
# Built against master (0.10.3) and PHYLLOPTIM-18 (0.10.4, 4026aad), both with
# odelia 0.8.0, the same snippet shows what each refuses.
args <- commandArgs(TRUE)
ph_lib <- args[1]; od_lib <- args[2]; label <- args[3]; out <- args[4]
source(file.path(dirname(normalizePath(sub("--file=", "", grep("--file=", commandArgs(FALSE), value = TRUE)))), "leaf_rows_cpp.R"))
compile_leaf_rows(ph_lib, od_lib)


# plant TF24's root curve (root_P50 3.4 MPa, root_c 2.680147) on plant's 400-knot table.
psi <- sort(unique(c(seq(0.05, 10, by = 0.05), 6.8918 + c(-1e-3, 1e-3))))
g <- G_rows(psi, 3.4, 2.680147, 400, 1e-5)
g$build <- label
write.csv(g, paste0(out, "_G.csv"), row.names = FALSE)

# The stem of test_leaf.cpp's determined fixtures (stem_P50 3.4287), plant's
# GSS_tol_abs (0.1) and table size (400).
ps <- seq(5.0, 5.88, by = 0.004)
cl <- collar_rows(ps, 3.4287, 3.4, 0.1, 400, 1e-6)
cl$build <- label
write.csv(cl, paste0(out, "_collar.csv"), row.names = FALSE)
