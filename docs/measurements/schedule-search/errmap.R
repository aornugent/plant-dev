# Noise-free error, in eps, of chosen quantities at lattice points, per case.
suppressMessages(source("/home/user/plant-dev/harness/schedule/surrogate.R"))
show <- function(case, ks, pts = list(c(16,140), c(32,140), c(32,70), c(64,70), c(32,35), c(64,35))) {
  lib <- load_library(case); ref <- reference(case); STRESS <<- 0
  m <- sapply(pts, function(p) { q <- lookup(lib, p[1], p[2])$q; (q[ks] - ref[ks]) / eps_vec(ks) })
  colnames(m) <- sapply(pts, paste, collapse = "/"); m <- matrix(m, nrow = length(ks), dimnames = list(ks, colnames(m)))
  cat("--", case, "\n"); print(round(m, 2)) }
show("dry", c("TF24_cost_scale", "a_l1", "root_P50", "lnJ"))
show("long-wet", c("a_l1", "a", "lnJ"))
