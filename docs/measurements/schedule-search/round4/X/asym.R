# asym.R: each class-bisected committed run on dry against a09's committed and check runs
# and the inset's committed run, per gate: nodes, rows cost, rms and worst error.
source("/home/user/plant-dev/docs/measurements/schedule-search/round4/AG/lib.R")
XR <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/X_out/runs"
ld <- function(n) { for (d in c(XR, AGR, file.path(POUT, "runs"), R)) { f <- file.path(d, paste0(n, ".rds")); if (file.exists(f)) return(readRDS(f)) }; NULL }
for (g in c("19", "AG")) { ref <- if (g == "AG") ref_ag("dry") else refq("dry"); cat("gate", g, "\n")
  nm <- if (g == "19") c(a09c = "val_a09_c_dry", a09f = "val_a09_f_dry", insc = "P_insc_dry", bO = "X_a09bO_dry", bC = "X_a09bC_dry", bG = "X_a09bG_dry", bS = "X_a09bS_dry", bI = "X_a09bI_dry", bF = "X_a09bF_dry", nb = "X_a09nb_dry")
        else c(a09c = "AG_a09c_dry", a09f = "AG_a09f_dry", insc = "AG_insc_dry", bO = "AG_a09bO_dry", bC = "AG_a09bC_dry", bG = "AG_a09bG_dry", bS = "AG_a09bS_dry", bI = "AG_a09bI_dry", bF = "AG_a09bF_dry", nb = "AG_a09nb_dry", nq = "AG_a09nq_dry")
  for (n in names(nm)) { x <- ld(nm[[n]]); if (is.null(x) || is.null(x$stand$elasticity)) next; q <- quantities(x); k <- intersect(names(ref), names(q)); er <- (q[k] - ref[k]) / eps_vec(k)
    cat(sprintf("  %-5s n %3d rows-cost %5.0f | rms %.3f worst %.2f (%s) | ln J %+.3f\n", n, length(x$node_times), run_cost(x$stand$rows, TRUE), sqrt(mean(er^2)), max(abs(er)), k[which.max(abs(er))], (log(x$stand$J) - log(1)) * 0)) } }
