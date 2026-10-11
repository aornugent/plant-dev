# (A) map's predicted coarsening move against the actual coarse run; (B) the error
# against 4/3 of the actual bisection move; both in eps of ln J.
source("/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/adjmap/lib.R")
Q <- file.path(D, "schedtest/placed2/runs"); NR <- file.path(D, "node_rule/ladder/runs"); P <- file.path(D, "schedtest/placement/runs")
ext <- function(m, f) { a <- log(readRDS(m)$stand$J); b <- log(readRDS(f)$stand$J); b + (b - a) / 3 }
ref <- list(episodic = ext(file.path(NR, "u429_episodic.rds"), file.path(P, "u857_episodic.rds")),
            dry = ext(file.path(NR, "u215_dry.rds"), file.path(NR, "u429_dry.rds")))
for (nm in c("u108e_episodic_p1", "u108e_episodic_p3", "s16_dry_p3")) {
  rec <- sub("^[a-z0-9]+_(.*)_p[0-9]+$", "\\1", nm); x <- run(paste0("ref_", nm))
  C <- file.path(Q, paste0("rc_C_", nm, ".rds")); B <- file.path(Q, paste0("rc_B_", nm, ".rds")); if (!file.exists(B)) next
  b <- nd(x); j <- x$dropped; own <- sum(own_drop(b, j)) / sum(b$w * b$offspring); fld <- sum(x$light + x$soil) / x$stand$J
  lP <- log(x$stand$J); lC <- log(readRDS(C)$stand$J); lB <- log(readRDS(B)$stand$J); e <- 0.025
  cat(sprintf("%s: err %+.3f | (A) C-P actual %+.3f, map %+.3f (own %+.3f field %+.3f) | (B) 4/3 (P-B) %+.3f, (C-P)/3 %+.3f | ratio (C-P)/(P-B) %.2f\n",
    nm, (lP - ref[[rec]]) / e, (lC - lP) / e, (own + fld) / e, own / e, fld / e, 4 / 3 * (lP - lB) / e, (lC - lP) / 3 / e, (lC - lP) / (lP - lB)))
}
