# lnj.R: ln J's error (in eps) of each dry layout under both gates, against each gate's
# own reference, and the share of it on the founders (b < 1) by the per-node sum.
source("/home/user/plant-dev/docs/measurements/schedule-search/round4/AG/lib.R")
lj <- function(x) log(x$stand$J); eJ <- 0.025
r19 <- extrap(c(J = lj(readRDS(REF_FILES$dry[1]))), c(J = lj(readRDS(REF_FILES$dry[2]))))
rAG <- extrap(c(J = lj(ag_run("AG_ref_dry_u215"))), c(J = lj(ag_run("AG_ref_dry_u429"))))
rAG8 <- extrap(c(J = lj(ag_run("AG_ref_dry_u429"))), c(J = lj(ag_run("AG_ref_dry_u857"))))
cat(sprintf("refs: lib19 %.5f; libAG %.5f (u429/u857 %.5f)\n", r19, rAG, rAG8))
L <- list(lib19 = c(a09c = "val_a09_c_dry", a09f = "val_a09_f_dry", insc = "P_insc_dry", insf = "P_insf_dry", midc = "P_mid_dry", midf = "P_midf2_dry", in10 = "P_in10_dry"),
          libAG = c(a09c = "AG_a09c_dry", a09f = "AG_a09f_dry", insc = "AG_insc_dry", insf = "AG_insf_dry", midc = "AG_mid_dry", midf = "AG_midf_dry", in10 = "AG_in10_dry"))
for (g in names(L)) { r <- if (g == "lib19") r19 else rAG; cat(g, ":")
  for (n in names(L[[g]])) { x <- tryCatch(ag_run(L[[g]][[n]]), error = function(e) NULL); if (is.null(x)) next; cat(sprintf("  %s %+.3f", n, (lj(x) - r) / eJ)) }; cat("\n") }
