# ladder.R: dry's uniform ladder u215 -> u429 -> u857 on libAG, along unit M and off it:
# the order the ladder converges at, and how far the two extrapolated references differ.
source("/home/user/plant-dev/docs/measurements/schedule-search/round4/AG/lib.R")
q <- function(n) quantities(ag_run(n)); u2 <- q("AG_ref_dry_u215"); u4 <- q("AG_ref_dry_u429"); u8 <- q("AG_ref_dry_u857")
M <- { p <- quantities(ag_run("P_in10_dry")); b <- quantities(rd_run("a09", "c", "dry")); p - b[names(p)] }
k <- Reduce(intersect, list(names(u2), names(u4), names(u8), names(M))); e <- eps_vec(k); m <- M[k] / e; u <- m / sqrt(sum(m^2))
d1 <- (u4[k] - u2[k]) / e; d2 <- (u8[k] - u4[k]) / e
cat(sprintf("along M: u215->u429 %+.3f, u429->u857 %+.3f (ratio %.2f; 4 = second order, 2 = first)\n", sum(d1 * u), sum(d2 * u), sum(d1 * u) / sum(d2 * u)))
off1 <- d1 - sum(d1 * u) * u; off2 <- d2 - sum(d2 * u) * u
cat(sprintf("off M rms: %.3f, %.3f (ratio %.2f); ln J: %+.4f, %+.4f (ratio %.2f)\n", sqrt(mean(off1^2)), sqrt(mean(off2^2)), sqrt(sum(off1^2) / sum(off2^2)), d1["lnJ"], d2["lnJ"], d1["lnJ"] / d2["lnJ"]))
r1 <- extrap(u2[k], u4[k]); r2 <- extrap(u4[k], u8[k]); dr <- (r2 - r1) / e
cat(sprintf("ref(429,857) - ref(215,429): along M %+.3f, max %.2f (%s), rms %.3f; own estimate of ref(429,857) max %.2f\n", sum(dr * u), max(abs(dr)), k[which.max(abs(dr))], sqrt(mean(dr^2)), max(abs(d2 / 3))))
