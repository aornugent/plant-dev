# r0_saved.R: R0. e_c, the founders' F = -4/3 (fbis - c), the closing region C = -(res - c),
# e_res, and rest = e_res - F, per case; and the saved ins75 pair for reference.
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/p50/lib.R")
for (cs in c("dry", "dry-flat", "dry-p50", "long-wet")) { c0 <- rd5(sprintf("val_insk_c_%s", cs)); ec <- err_run(c0, cs)
  F <- -4 / 3 * mv_run(rd5(sprintf("fbis_%s", cs)), c0); C <- -mv_run(rd5(sprintf("cl_res_%s", cs)), c0); er <- err_run(rd5(sprintf("cl_res_%s", cs)), cs)
  cat(sprintf("== %s\n", cs)); line("e_c", ec); line("founders F (on c)", F[names(ec)]); line("closing C", C[names(ec)]); line("e_res", er); line("rest = e_res - F", (er - F[names(er)]))
  for (k in c("val_ins75_c", "val_ins75_f")) { f <- file.path(ADJ, sprintf("%s_%s.rds", k, cs)); if (file.exists(f)) line(paste("e", k), err_run(readRDS(f), cs)) } }
