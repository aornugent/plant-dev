# need.R: on dry, along unit M from u429: what each spacing's edge bias needs cancelled
# (reference - a09 run) against what each inset delivered (inset run - a09 run), both
# gates; with p(d) on lib19 from in3 / in10 / ins12 (c spacing).
source("/home/user/plant-dev/docs/measurements/schedule-search/round4/AG/lib.R")
cs <- "dry"; M <- { p <- quantities(ag_run("P_in10_dry")); b <- quantities(rd_run("a09", "c", cs)); (p - b[names(p)]) }
along <- function(u2, u4, x) { k <- Reduce(intersect, list(names(u2), names(u4), names(x), names(M))); e <- eps_vec(k); m <- M[k] / e; u <- m / sqrt(sum(m^2)); sum(((x[k] - u4[k]) / e) * u) }
for (g in c("lib19", "libAG")) { if (g == "lib19") { f <- REF_FILES[[cs]]; u2 <- quantities(readRDS(f[1])); u4 <- quantities(readRDS(f[2])); nm <- c(c = "val_a09_c_dry", f = "val_a09_f_dry", in3 = "P_in3_dry", in10 = "P_in10_dry", insc = "P_insc_dry", insf = "P_insf_dry") } else {
  u2 <- quantities(ag_run("AG_ref_dry_u215")); u4 <- quantities(ag_run("AG_ref_dry_u429")); nm <- c(c = "AG_a09c_dry", f = "AG_a09f_dry", in10 = "AG_in10_dry", insc = "AG_insc_dry", insf = "AG_insf_dry") }
  v <- sapply(nm, function(n) along(u2, u4, quantities(ag_run(n)))); r <- along(u2, u4, extrap(u2[names(u4)], u4))
  cat(sprintf("%s: ref %+.2f | need c %.2f f %.2f (ratio %.2f) | inset delivers:%s | ins12 c %.2f f %.2f (ratio %.2f)\n", g, r, r - v["c"], r - v["f"], (r - v["c"]) / (r - v["f"]),
    paste(sprintf(" %s %.2f", setdiff(names(v), c("c", "f", "insc", "insf")), v[setdiff(names(v), c("c", "f", "insc", "insf"))] - v["c"]), collapse = ","), v["insc"] - v["c"], v["insf"] - v["f"], (v["insc"] - v["c"]) / (v["insf"] - v["f"]))) }
