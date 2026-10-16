# q0_builds.R: the same schedule on two builds; the offset a build adds (eps units).
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/common.R")
v <- function(nm) qn(nm)[Q] / EPS; r2 <- function(x) sqrt(mean(x^2))
for (cs in ALL) { a <- sprintf("P_insc_%s", cs); b <- sprintf("val_insk_c_%s", cs); if (!all(c(a, b) %in% TAB$name)) next
  x <- v(b) - v(a); cat(sprintf("  S - lib19  %-13s rms %.3f max %.3f lnJ %+.3f\n", cs, r2(x), max(abs(x)), x["lnJ"])) }
for (pr in list(c("AG_a09c_dry", "val_a09_c_dry"), c("AG_a09f_dry", "val_a09_f_dry"), c("AG_ref_dry_u215", "u215_dry"), c("AG_ref_dry_u429", "u429_dry"))) {
  x <- v(pr[1]) - v(pr[2]); cat(sprintf("  AG - lib19 %-17s rms %.3f max %.3f lnJ %+.3f\n", pr[1], r2(x), max(abs(x)), x["lnJ"])) }
x <- REF$AG$dry[Q] / EPS - REF$L19$dry[Q] / EPS; cat(sprintf("  reference AG - lib19 (dry): rms %.3f max %.3f (%s)\n", r2(x), max(abs(x)), names(x)[which.max(abs(x))]))
