# Whole game for phylloptim#21: Rscript whole_game.R <phylloptim lib> <odelia lib>
args <- commandArgs(TRUE)
here <- dirname(normalizePath(sub("--file=", "", grep("--file=", commandArgs(FALSE), value = TRUE))))
source(file.path(here, "leaf_rows_cpp.R"))
options(width = 100)
ph_lib <- args[1]; od_lib <- args[2]
compile_leaf_rows(ph_lib, od_lib)

# The root integral either side of its last knot (6.89 MPa): the table's G,
# its root_P50 row, and a central difference of the table in root_P50.
G_rows(psi = c(6.5, 7.0, 8.0), P50 = 3.4, c = 2.680147, resolution = 400,
       h = 1e-5)[, c("psi", "G", "row", "fd")]

# Collar intervals 0.13 and 0.05 MPa wide, the second narrower than
# GSS_tol_abs: the collar, its psi_soil row and a central difference of the solve.
collar_rows(psi_soil = c(5.2, 5.6), stem_P50 = 3.4287, root_P50 = 3.4,
            GSS_tol_abs = 0.1, resolution = 400,
            h = 1e-6)[, c("psi_soil", "kind", "collar", "row", "fd")]
