# refM.R CASE: the uniform references and each run along M19 (unit vector), measured
# from u429: if u215 -> u429 converges at second order on M the extrapolation sits
# (u429 - u215)/3 beyond u429; a shared component of c and f is the reference's if the
# runs' c/f ratio on M becomes second order against another reference point.
source("/home/user/plant-dev/docs/measurements/schedule-search/round4/AG/lib.R")
cs <- commandArgs(TRUE)[1]; lib <- if (length(commandArgs(TRUE)) > 1) commandArgs(TRUE)[2] else "AG"
q <- function(n) quantities(ag_run(n))
if (lib == "AG") { u2 <- q(sprintf("AG_ref_%s_u215", cs)); u4 <- q(sprintf("AG_ref_%s_u429", cs)); runs <- c(c = sprintf("AG_a09c_%s", cs), f = sprintf("AG_a09f_%s", cs), insc = sprintf("AG_insc_%s", cs), insf = sprintf("AG_insf_%s", cs), mid = sprintf("AG_mid_%s", cs), midf = sprintf("AG_midf_%s", cs), in10 = sprintf("AG_in10_%s", cs))
} else { f <- REF_FILES[[cs]]; u2 <- quantities(readRDS(f[1])); u4 <- quantities(readRDS(f[2])); runs <- c(c = sprintf("val_a09_c_%s", cs), f = sprintf("val_a09_f_%s", cs), insc = sprintf("P_insc_%s", cs), insf = sprintf("P_insf_%s", cs), mid = sprintf("P_mid_%s", cs), midf = sprintf("P_midf2_%s", cs), in10 = sprintf("P_in10_%s", cs)) }
k <- intersect(names(u2), names(u4)); e <- eps_vec(k)
M <- { p <- q(sprintf("P_in10_%s", cs)); b <- quantities(rd_run("a09", "c", cs)); k <- intersect(k, names(p)); (p[k] - b[k]) / eps_vec(k) }; e <- eps_vec(k); u <- M / sqrt(sum(M^2))
on <- function(v) sum(((v[k] - u4[k]) / e) * u)
cat(sprintf("%s (%s): along M from u429: u215 %+.2f, extrapolated ref %+.2f\n", cs, lib, on(u2), on(extrap(u2[k], u4[k]))))
for (r in names(runs)) { x <- tryCatch(q(runs[[r]]), error = function(e) NULL); if (!is.null(x)) cat(sprintf("   %-5s %+.2f", r, on(x))) }; cat("\n")
