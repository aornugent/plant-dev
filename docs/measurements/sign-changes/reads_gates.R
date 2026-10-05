# A part reads the rest of the patch at five fractions of the step (prereg.txt,
# thirteenth extension).
#   OUTD=... Rscript reads_gates.R
OUTD <- Sys.getenv("OUTD")
run <- function(f) readRDS(file.path(OUTD, paste0(f, ".rds")))
J <- function(f) run(f)$stand$J
secs <- function(f, phase) run(f)$phases[[phase]]$secs
lma_of <- function(e) e[[grep("\\.lma$", names(e))]]
verdict <- function(holds, fails) if (holds) "holds" else if (fails) "fails" else "neither"

# PREV's arms were first run on a library holding no split (dev/lib_sw, built
# 2026-10-03), and run again on PLANT-103's (dev/p21/lib_sw): fwdprevJ and
# adaptprev_*. Its timed forwards are in reads_timing.sh.
d <- log(J("fwd_t1")) - log(J("fwdprevJ"))
cat(sprintf("R1 (|ln J - ln J_prev| at most 1e-8 on the pinned program): J %.12f against %.12f, %+.2e, %s\n",
            J("fwd_t1"), J("fwdprevJ"), d, verdict(abs(d) <= 1e-8, abs(d) > 1e-7)))

# The previous split's error against the reference at each tolerance (grid-dynamics §18).
err <- c("1e-3" = 1.03e-4, "3e-4" = 2.05e-5)
for (t in names(err)) {
  a <- run(paste0("adapt_", t))
  b <- run(paste0("adaptprev_", t))
  d <- log(a$stand$J) - log(b$stand$J)
  cat(sprintf("R2 at %s (under a tenth of %.2e): J %.10f against %.10f, %+.2e, %s; steps %d against %d\n",
              t, err[[t]], a$stand$J, b$stand$J, d,
              verdict(abs(d) < err[[t]] / 10, abs(d) > err[[t]] / 2),
              length(a$stand$times), length(b$stand$times)))
}

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
            verdict(worst <= 2e-3, worst > 2e-3)))

g <- sapply(1:3, function(i) secs(sprintf("grad_t%d", i), "stand_gradient"))
p <- sapply(1:3, function(i) secs(sprintf("plain_t%d", i), "stand_gradient"))
q <- mean(g) / mean(p) - 1
cat(sprintf("S5 (the sweep at most 6%% over plain's): split %s s, plain %s s: %+.1f%%, %s\n",
            paste(sprintf("%.1f", g), collapse = ", "), paste(sprintf("%.1f", p), collapse = ", "),
            100 * q, verdict(q <= 0.06, q >= 0.09)))

fw <- sapply(1:2, function(i) secs(sprintf("fwd_t%d", i), "stand_run"))
fp <- sapply(1:2, function(i) secs(sprintf("fwdplain_t%d", i), "stand_run"))
f <- mean(fw) / mean(fp) - 1
cat(sprintf("F (the forward at most 4%% over plain's): split %s s, plain %s s: %+.1f%%, %s\n",
            paste(sprintf("%.1f", fw), collapse = ", "), paste(sprintf("%.1f", fp), collapse = ", "),
            100 * f, verdict(f <= 0.04, f > 0.06)))
cat(sprintf("node steps split %d against PREV's %d\n", run("fwd_t1")$stand$splits,
            run("fwdprevJ")$stand$splits))

es <- run("grad_t1")$stand$elasticity
ep <- run("plain_t1")$stand$elasticity
cat("elasticities, split against plain:\n")
for (n in names(es)) {
  cat(sprintf("  %-28s %+.6f %+.6f %+.2e\n", n, es[[n]], ep[[n]], es[[n]] - ep[[n]]))
}
