# m4_fd.R CASE: the pinned central difference at root_P50 x (1 +- 0.01) on the I4 schedule.
# Guard: d ln J / d ln root_P50 from the pair against I4's own elasticity. Then the root_P50
# derivative of the interpolation part (res's hats on the fine fates), in eps, scaled 16/15
# as the region's error, against the region's measured root_P50 error -16/15 (I4 - res).
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/p50/split.R")
cs <- commandArgs(TRUE)[1]; h <- 0.01; fac <- 16 / 15; e <- EPS["root_P50"]
p <- rd5(sprintf("fd_I4p_%s", cs)); m <- rd5(sprintf("fd_I4m_%s", cs)); f <- rd5(sprintf("p5_I4_%s", cs)); co <- rd5(sprintf("cl_res_%s", cs))
el_fd <- (log(p$stand$J) - log(m$stand$J)) / (2 * h); el <- f$stand$elasticity["1.root_P50"]
cat(sprintf("guard: elasticity from the pinned pair %.5f, I4's adjoint %.5f (ratio %.4f)\n", el_fd, el, el_fd / el))
bc <- co$node_times; ip <- interp_part(p, bc); im <- interp_part(m, bc); i0 <- interp_part(f, bc)
d_int <- -fac * (ip - im) / (2 * h) / e
reg <- -fac * mv_run(f, co)["root_P50"]
cat(sprintf("interp part at theta %+.4f eps of ln J (x16/15 %+.3f); its root_P50 derivative as the region's error: %+.3f eps | region root_P50 error %+.3f | field + establishment %+.3f\n",
  i0 / 0.025, -fac * i0 / 0.025, d_int, reg, reg - d_int))
# per-cohort sensitivity s = d ln nrr / d ln root_P50, by birth group
np <- nodes(p); nm <- nodes(m); s <- (log(np$g) - log(nm$g)) / (2 * h); b1 <- PIL[[cs]]$b1
grp <- cut(np$b, c(-1, b1, 10, 17, 25, 99), labels = c("founders", "b1-10", "10-17", "17-25", ">25"))
cat("per-cohort d ln nrr / d ln root_P50, median by birth group:", paste(sprintf("%s %+.3f", levels(grp), tapply(s, grp, median)), collapse = ", "), "\n")
