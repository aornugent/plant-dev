# Constant rain on its resolved grid: unweighted and bounded Cash-Karp and ARK's
# arms A and B (at 3e-5, and at 1e-5 or nudged where run), against the Cash-Karp
# 1e-5 reference: cost, J's error, each role's median and largest distance (and
# which quantity), the sweeps' soil clamps, the readings (i) C2 and (ii) the
# budget, failures and every walk; then C3 for a nudged ARK arm.
#
#   Rscript const_table.R
D <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev"
WT <- "/home/user/plant-dev/.claude/worktrees/agent-a12cdeaf09a1e3e8a"
C <- file.path(D, "phase1c/combined")
source(file.path(D, "phase1c/nudge_spread.R"))  # eps, eps_of, quantities
eps_lnJ <- eps$eps[eps$role == "resident" & eps$trait == "ln J"]
f_of <- function(k) file.path(C, "full", paste0(k, ".rds"))
JSTAR <- 289.2738962
done <- function(f) file.exists(f) && !is.null(readRDS(f)$finished)
finite <- function(x) !is.null(x$stand$elasticity) && !is.null(x$invader$elasticity) &&
  all(is.finite(x$stand$elasticity)) && all(is.finite(x$invader$elasticity))
rows_of <- function(x) sum(as.numeric(findInterval(head(x$stand$times, -1), sort(x$node_times))))
grad_cost <- function(x) {
  a <- x$stand$attempts; ms <- rows_of(x)
  c(rows = ms, forward = ms * (a[["accepted"]] + a[["rejected_inaccurate"]] + a[["rejected_thrown"]]) / a[["accepted"]],
    accepted = a[["accepted"]], longest = max(diff(x$stand$times)) * 365)
}
gr <- function(c1, c0) 100 * ((c1[["forward"]] / c0[["forward"]] + 6 * c1[["rows"]] / c0[["rows"]]) / 7 - 1)
clamps <- function(v) if (is.null(v) || all(is.na(v))) "-" else paste(v, collapse = "/")
roles <- c("resident", "invader")

cat("== unweighted Cash-Karp with the 15-day cap against the existing no-cap run (creation-grid/const_Gbf16_full)\n")
old <- file.path(WT, "docs/measurements/creation-grid/const_Gbf16_full.rds")
if (done(f_of("const_ck"))) {
  a <- readRDS(old)$stand; b <- readRDS(f_of("const_ck"))$stand
  cat(sprintf("   stand J, times, attempts identical: %s %s %s; elasticities identical: %s\n", identical(a$J, b$J),
              identical(a$times, b$times), identical(a$attempts, b$attempts), identical(a$elasticity, b$elasticity)))
} else cat("   not run yet\n")

need <- c("const_ck", "const_ck_1e-5", "const_bnd")
if (!all(vapply(f_of(need), done, TRUE))) {
  cat("\nbaselines not all finished:", need[!vapply(f_of(need), done, TRUE)], "\n")
} else {
  x0 <- readRDS(f_of("const_ck")); xb <- readRDS(f_of("const_bnd")); xr <- readRDS(f_of("const_ck_1e-5"))
  c0 <- grad_cost(x0); cb <- grad_cost(xb); qr <- quantities(xr)
  dist <- function(x) {
    q <- quantities(x); m <- intersect(names(qr), names(q)); d <- abs(q[m] - qr[m])
    lapply(setNames(roles, roles), function(ro) {
      s <- startsWith(m, paste0(ro, " ")); v <- d[s]
      list(med = median(v), max = max(v), at = sub("^(resident|invader) ", "", m[s][which.max(v)]))
    })
  }
  d0 <- dist(x0)
  cat(sprintf("\n== Constant rain, 150 nodes (distances from const_ck_1e-5, in eps; J* %.7f; sweep clamps moisture floor/potential ceiling/positivity, stand then invader)\n", JSTAR))
  cat(sprintf("%-22s %7s %7s %6s %6s %10s | %-38s | %-38s | %-11s | %s\n", "run", "vs CK", "vs bnd", "steps", "max d",
              "J/J* - 1", "resident: median, largest (quantity)", "invader: median, largest (quantity)", "sweeps", "(i) C2, (ii) budget"))
  runs <- c("unweighted CK" = "const_ck", "CK 1e-5 reference" = "const_ck_1e-5", "bounded CK" = "const_bnd",
            "ARK arm A" = "const_arkA", "ARK arm B" = "const_arkB", "ARK arm A 1e-5" = "const_arkA_1e-5",
            "ARK arm B 1e-5" = "const_arkB_1e-5")
  pass2 <- list()
  for (k in names(runs)) {
    f <- f_of(runs[[k]])
    if (!file.exists(f)) next
    x <- readRDS(f)
    if (is.null(x$stand$times)) { cat(sprintf("%-22s the stand did not run: %s\n", k, paste(unlist(x$failures), collapse = " | "))); next }
    cc <- grad_cost(x)
    lead <- sprintf("%-22s %+6.1f%% %+6.1f%% %6d %6.2f %+10.2e", k, gr(cc, c0), gr(cc, cb), cc[["accepted"]], cc[["longest"]],
                    x$stand$J / JSTAR - 1)
    if (!done(f) || !finite(x)) {
      cat(sprintf("%s | %s; failures: %s; sweep clamps %s %s\n", lead, if (!done(f)) "did not finish" else "gradient refused",
                  if (length(x$failures)) paste(names(x$failures), collapse = ", ") else "none",
                  clamps(x$stand$swept_clamps), clamps(x$invader$swept_clamps)))
      pass2[[k]] <- FALSE
      next
    }
    dd <- dist(x)
    c2 <- sapply(roles, function(ro) dd[[ro]]$med <= d0[[ro]]$med && dd[[ro]]$max <= d0[[ro]]$max && dd[[ro]]$max < 1 / 3)
    bud <- sapply(roles, function(ro) dd[[ro]]$max < 1 / 3 && dd[[ro]]$med < 0.02)
    pass2[[k]] <- all(bud)
    cat(sprintf("%s | %.4f, %.4f (%-16s) | %.4f, %.4f (%-16s) | %-11s | %s\n", lead,
                dd$resident$med, dd$resident$max, dd$resident$at, dd$invader$med, dd$invader$max, dd$invader$at,
                paste(clamps(x$stand$swept_clamps), clamps(x$invader$swept_clamps)),
                if (k == "CK 1e-5 reference") "" else sprintf("(i) %s/%s (ii) %s/%s", ifelse(c2[1], "pass", "FAIL"),
                                                                ifelse(c2[2], "pass", "FAIL"), ifelse(bud[1], "pass", "FAIL"),
                                                                ifelse(bud[2], "pass", "FAIL"))))
  }
  cat("\n== Failures and walks: J', and the ln J' move against unweighted Cash-Karp's walk, in eps\n")
  skip <- c("stand_run", "stand_gradient", "invader_run", "invader_gradient")
  invs <- c("lma=0.5", "lma=0.7", "lma=1.4", "lma=2", "hmat=0.5", "hmat=0.7", "hmat=1.4", "hmat=2")
  for (k in names(runs)) {
    f <- f_of(runs[[k]])
    if (!file.exists(f)) next
    x <- readRDS(f)
    cat(sprintf("%-22s failures: %s\n", k, if (length(x$failures)) paste(names(x$failures), substr(unlist(x$failures), 1, 140),
                                                                       sep = ": ", collapse = " | ") else "none"))
    cat("   ", paste(vapply(invs, function(i) {
      if (!is.null(x$failures[[i]])) return(sprintf("%s RAISED", i))
      J1 <- x$invaders[[i]]$J; J0 <- x0$invaders[[i]]$J
      if (is.null(J1)) return(sprintf("%s -", i))
      sprintf("%s %.4g (%.3f)", i, J1, if (is.null(J0)) NA else abs(log(J1 / J0)) / eps_lnJ)
    }, ""), collapse = "; "), "\n")
  }
  for (arm in c("A", "B")) {
    nud <- f_of(sprintf("const_ark%s_%s", arm, c("2.85e-5", "3.15e-5")))
    if (!all(vapply(nud, done, TRUE))) next
    cat(sprintf("\n== C3 for ARK arm %s on constant: the +-5%% nudges, each quantity's larger move, in eps/3\n", arm))
    qb <- quantities(readRDS(f_of(sprintf("const_ark%s", arm)))); nq <- lapply(nud, function(f) quantities(readRDS(f)))
    n <- Reduce(intersect, c(list(names(qb)), lapply(nq, names)))
    d <- do.call(pmax, lapply(nq, function(q) abs(q[n] - qb[n]))) * 3
    for (f in nud) { y <- readRDS(f)
      cat(sprintf("   %-24s J %.7f | sweep clamps %s %s | gradient finite %d and %d of 50\n", basename(f), y$stand$J,
                  clamps(y$stand$swept_clamps), clamps(y$invader$swept_clamps),
                  sum(is.finite(y$stand$elasticity)), sum(is.finite(y$invader$elasticity)))) }
    for (ro in roles) {
      s <- startsWith(n, paste0(ro, " ")); o <- order(-d[s])[1:3]
      cat(sprintf("   %-8s median %.3f, largest %s; over 1: %d -> C3 %s\n", ro, median(d[s]),
                  paste(sprintf("%.3f (%s)", d[s][o], sub("^(resident|invader) ", "", n[s][o])), collapse = ", "),
                  sum(d[s] > 1), if (sum(d[s] > 1) == 0) "pass" else "FAIL"))
    }
  }
  cat("\n== The decision for ARK\n")
  for (arm in c("A", "B")) {
    k <- paste("ARK arm", arm)
    cat(sprintf("   arm %s at 3e-5: (ii) %s -> %s\n", arm, if (isTRUE(pass2[[k]])) "passes" else "fails",
                if (isTRUE(pass2[[k]])) "its +-5% nudges (C3)" else "run at 1e-5"))
  }
}
