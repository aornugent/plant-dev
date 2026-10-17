# e_moved.R: does the run library hold a moved-theta run on a theta0 grid? The three
# trait-moved cases (dry-p50 = dry with root_P50 0.2; wet-adG2 = long-wet with a_dG2 0.25;
# episodic-lma = episodic with lma 0.25) each built their own grid from their own pilot.
# Where the two grids coincide, the moved case's error on it is the error at moved theta
# on the theta0 grid; the ratio to theta0's error sizes the reserve.
PO <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/proxies"
D <- readRDS(file.path(PO, "lad.rds")); L <- D$L; EPS <- D$EPS; Q <- D$Q
er <- function(cs, k) (L[[cs]]$runs[[k]]$q - L[[cs]]$ref) / EPS
for (pr in list(c("dry", "dry-p50"), c("long-wet", "wet-adG2"), c("episodic", "episodic-lma"))) for (k in c("x", "c", "f")) {
  a <- L[[pr[1]]]$runs[[k]]$S; b <- L[[pr[2]]]$runs[[k]]$S
  same <- length(a) == length(b) && max(abs(a - b)) < 1e-9
  shared <- sum(vapply(b, function(s) min(abs(a - s)) < 1e-6, TRUE))
  ea <- er(pr[1], k); eb <- er(pr[2], k)
  cat(sprintf("%-9s vs %-12s %s: nodes %d / %d, shared %d, identical %s | W %.2f / %.2f, rms %.3f / %.3f, cos(err) %.2f, rms diff %.3f\n", pr[1], pr[2], k, length(a), length(b), shared, same,
    max(abs(ea)), max(abs(eb)), sqrt(mean(ea^2)), sqrt(mean(eb^2)), sum(ea * eb) / sqrt(sum(ea^2) * sum(eb^2)), sqrt(mean((ea - eb)^2)))) }
