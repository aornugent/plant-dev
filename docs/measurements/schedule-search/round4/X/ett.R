# ett.R: E1, E2: the tighter tolerance around closing edges, the nudge's move and the cost,
# against the same runs without it.
source("/home/user/plant-dev/docs/measurements/schedule-search/round4/AG/lib.R")
XR <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/X_out/runs"
ld <- function(n) { for (d in c(XR, AGR, file.path(POUT, "runs"), R)) { f <- file.path(d, paste0(n, ".rds")); if (file.exists(f)) return(readRDS(f)) }; NULL }
mv <- function(a, b) { if (is.null(a) || is.null(b) || is.null(b$stand$elasticity)) return(NA); qa <- quantities(a); qb <- quantities(b); k <- intersect(names(qa), names(qb)); m <- (qb[k] - qa[k]) / eps_vec(k); c(rms = sqrt(mean(m^2)), max = max(abs(m))) }
sets <- list(E1 = list(base = c("P_ins3c_dry", "X_ins3c_2.85e-4_dry"), ett = c("X_ett_ins3c_3e-4_dry", "X_ett_ins3c_2.85e-4_dry"), ref = "19"),
             E2 = list(base = c("AG_a09c_dry", "AG_a09c105_dry"), ett = c("AG_ett_a09c_1e-4_dry", "AG_ett_a09c_1.05e-4_dry"), ref = "AG"))
for (s in names(sets)) { z <- sets[[s]]; b <- lapply(z$base, ld); e <- lapply(z$ett, ld); ref <- if (z$ref == "AG") ref_ag("dry") else refq("dry")
  err <- function(x) { if (is.null(x) || is.null(x$stand$elasticity)) return(c(NA, NA)); q <- quantities(x); k <- intersect(names(ref), names(q)); r <- (q[k] - ref[k]) / eps_vec(k); c(sqrt(mean(r^2)), max(abs(r))) }
  cat(sprintf("%s: nudge without %.3f (max %.2f), with %.3f (max %.2f) | rows with/without %.3f | error without %.3f/%.2f, with %.3f/%.2f | with vs without (same tol) %.3f\n", s,
    mv(b[[1]], b[[2]])[1], mv(b[[1]], b[[2]])[2], mv(e[[1]], e[[2]])[1], mv(e[[1]], e[[2]])[2], if (!is.null(e[[1]])) e[[1]]$stand$rows / b[[1]]$stand$rows else NA,
    err(b[[1]])[1], err(b[[1]])[2], err(e[[1]])[1], err(e[[1]])[2], mv(b[[1]], e[[1]])[1])) }
