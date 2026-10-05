# The sweep through split steps (prereg.txt, twelfth extension).
#   OUTD=... Rscript sweep_gates.R
OUTD <- Sys.getenv("OUTD")
run <- function(f) readRDS(file.path(OUTD, paste0(f, ".rds")))
J <- function(f) run(f)$stand$J
secs <- function(f, phase) run(f)$phases[[phase]]$secs
lma_of <- function(e) e[[grep("\\.lma$", names(e))]]

# Elasticity of J in lma by central differences of 1e-6 lma about lma (1 + r),
# against the sweep's.
s4 <- c()
for (r in c(0, 1e-3)) {
  at <- if (r == 0) "grad_t1" else "grad_r3"
  up <- if (r == 0) "cd_1e-6" else "cd_0.001001"
  down <- if (r == 0) "cd_-1e-6" else "cd_0.000999"
  differenced <- (1 + r) * (J(up) - J(down)) / (2e-6 * J(at))
  swept <- lma_of(run(at)$stand$elasticity)
  s4[as.character(r)] <- swept - differenced
  cat(sprintf("r = %g: J %.10f; elasticity in lma: swept %.9f, differenced %.9f, %+.2e (%+.2e of it)\n",
              r, J(at), swept, differenced, swept - differenced, swept / differenced - 1))
}
worst <- max(abs(s4))
cat(sprintf("S4 (within 2e-3 at r = 0 and 1e-3): largest %.2e, %s\n", worst,
            if (worst <= 2e-3) "holds" else "fails"))

held <- lma_of(run("frozen")$stand$elasticity)
routed <- lma_of(run("grad_t1")$stand$elasticity)
cat(sprintf("held cuts: elasticity in lma %.9f against routed %.9f, %+.2e (%+.2e of it)\n",
            held, routed, held - routed, held / routed - 1))

g <- sapply(1:2, function(i) secs(sprintf("grad_t%d", i), "stand_gradient"))
p <- sapply(1:2, function(i) secs(sprintf("plain_t%d", i), "stand_gradient"))
q <- mean(g) / mean(p) - 1
cat(sprintf("S5 (the sweep at most 6%% over plain's): split %s s, plain %s s: %+.1f%%, %s\n",
            paste(sprintf("%.0f", g), collapse = ", "), paste(sprintf("%.0f", p), collapse = ", "),
            100 * q, if (q <= 0.06) "holds" else if (q >= 0.09) "fails" else "neither"))
fw <- sapply(1:2, function(i) secs(sprintf("fwd_t%d", i), "stand_run"))
fb <- sapply(1:2, function(i) secs(sprintf("fwd102_t%d", i), "stand_run"))
cat(sprintf("forward: the build %s s, PLANT-102 %s s: %+.1f%%; J %.10f and %.10f\n",
            paste(sprintf("%.0f", fw), collapse = ", "), paste(sprintf("%.0f", fb), collapse = ", "),
            100 * (mean(fw) / mean(fb) - 1), J("fwd_t1"), J("fwd102_t1")))

es <- run("grad_t1")$stand$elasticity
ep <- run("plain_t1")$stand$elasticity
cat("elasticities, split against plain:\n")
for (n in names(es)) {
  cat(sprintf("  %-28s %+.6f %+.6f %+.2e\n", n, es[[n]], ep[[n]], es[[n]] - ep[[n]]))
}
