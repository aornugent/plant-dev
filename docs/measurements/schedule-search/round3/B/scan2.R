source("/home/user/plant-dev/harness/schedule/lattice.R")
A <- file.path(DEV, "schedtest/adjmap/runs")
for (f in c("loc_G0_dry", "hier_dy_dry_p0", "hyb_dy_dry", "map_dry_u215", "ref_th0b_dry_p0", "ref_u108e_dry_p0", "loc_bandB_dry", "loc_bandA_dry", "rcB_s16_dry_p3", "cen_dy_dry")) {
  x <- readRDS(file.path(A, paste0(f, ".rds"))); cat("==", f, "\n"); str(x$setting)
  pe <- pilot_edges("dry"); S <- x$node_times; isE <- vapply(S, function(s) min(abs(pe$edges - s)) < 1e-6, TRUE)
  cat(sprintf("nodes %d, at pilot edges %d of %d edges; dropped %d, of which edges %d; dropped before 25 edges %d\n", length(S), sum(isE), length(pe$edges), length(x$dropped), sum(isE[x$dropped]), sum(isE[x$dropped] & S[x$dropped] < 25))) }
