# ARK's arm B (rule A, WEIGHT_MAX=100, 15-day cap) at soil weights 10, 30, 50
# and 100, on long drought and episodic: the gradient run's cost against
# unweighted and bounded Cash-Karp, J's error, each role's median and largest
# distance from 1e-5 (and which quantity), the sweeps' soil clamps, the two
# accuracy readings, and the pick; then C3 for the pick.
#
#   Rscript ark_weights.R
D <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev"
WT <- "/home/user/plant-dev/.claude/worktrees/agent-a12cdeaf09a1e3e8a"
C <- file.path(D, "phase1c/combined")
source(file.path(D, "phase1c/nudge_spread.R"))  # eps, eps_of, quantities
sc <- file.path(WT, "docs/measurements/spot-check")
weights <- c(10, 30, 50, 100)
recs <- list(
  "long-drought" = list(short = "ld", base = file.path(sc, "ld_3e-5.rds"), bnd = file.path(C, "full/bnd_ld.rds"),
                        ref = file.path(WT, "docs/measurements/nudges/ld_1e-5.rds"), jstar = 12.6687135),
  episodic = list(short = "epi", base = file.path(sc, "epi_base.rds"), bnd = file.path(C, "full/bnd_epi.rds"),
                  ref = file.path(D, "phase1c/full/epi_1e-5.rds"), jstar = file.path(D, "window/ref/epi_1e-8_abs.rds")))
run_of <- function(r, w) file.path(C, "full", if (w == 100) sprintf("arkB_%s.rds", recs[[r]]$short) else
  sprintf("arkB_w%d_%s.rds", w, recs[[r]]$short))
done <- function(f) file.exists(f) && !is.null(readRDS(f)$finished)
jstar_of <- function(j) if (is.numeric(j)) j else readRDS(j)$stand$J
rows_of <- function(x) sum(as.numeric(findInterval(head(x$stand$times, -1), sort(x$node_times))))
grad_cost <- function(x) {
  a <- x$stand$attempts; ms <- rows_of(x)
  c(rows = ms, forward = ms * (a[["accepted"]] + a[["rejected_inaccurate"]] + a[["rejected_thrown"]]) / a[["accepted"]])
}
gr <- function(c1, c0) 100 * ((c1[["forward"]] / c0[["forward"]] + 6 * c1[["rows"]] / c0[["rows"]]) / 7 - 1)
clamps <- function(v) if (is.null(v) || all(is.na(v))) "-" else paste(v, collapse = "/")
meets <- list()
for (r in names(recs)) {
  g <- recs[[r]]
  x0 <- readRDS(g$base); xb <- readRDS(g$bnd); c0 <- grad_cost(x0); cb <- grad_cost(xb); Js <- jstar_of(g$jstar)
  qr <- quantities(readRDS(g$ref)); q0 <- quantities(x0)
  cat(sprintf("\n== %s (distances from %s, in eps; sweep clamps are moisture floor/potential ceiling/positivity)\n",
              r, basename(g$ref)))
  cat(sprintf("%-22s %8s %8s %10s | %-38s | %-38s | %-11s | %s\n", "run", "vs CK", "vs bnd", "J/J* - 1",
              "resident: median, largest (quantity)", "invader: median, largest (quantity)", "sweeps", "readings (i) C2, (ii) budget"))
  dist <- function(x) {
    q <- quantities(x); m <- intersect(names(qr), names(q)); d <- abs(q[m] - qr[m])
    lapply(c(resident = "resident", invader = "invader"), function(ro) {
      s <- startsWith(m, paste0(ro, " ")); v <- d[s]
      list(med = median(v), max = max(v), at = sub("^(resident|invader) ", "", m[s][which.max(v)]), n = sum(s))
    })
  }
  d0 <- dist(x0)
  budget <- function(dd) paste(sapply(c("resident", "invader"), function(ro)
    if (dd[[ro]]$max < 1 / 3 && dd[[ro]]$med < 0.02) "pass" else "FAIL"), collapse = "/")
  show <- function(label, x, cc, dd, readings) {
    cat(sprintf("%-22s %+7.1f%% %+7.1f%% %+10.2e | %.4f, %.4f (%-14s) | %.4f, %.4f (%-14s) | %-11s | %s\n",
                label, gr(cc, c0), gr(cc, cb), x$stand$J / Js - 1,
                dd$resident$med, dd$resident$max, dd$resident$at, dd$invader$med, dd$invader$max, dd$invader$at,
                paste(clamps(x$stand$swept_clamps), clamps(x$invader$swept_clamps), sep = " "), readings))
  }
  show("unweighted Cash-Karp", x0, c0, d0, sprintf("(ii) %s", budget(d0)))
  db <- dist(xb)
  show("bounded Cash-Karp", xb, cb, db, sprintf("(ii) %s", budget(db)))
  for (w in weights) {
    f <- run_of(r, w)
    if (!file.exists(f)) { cat(sprintf("%-22s not run\n", sprintf("ARK soil x%d", w))); next }
    x1 <- readRDS(f)
    fin <- !is.null(x1$stand$elasticity) && !is.null(x1$invader$elasticity) &&
      all(is.finite(x1$stand$elasticity)) && all(is.finite(x1$invader$elasticity))
    if (!done(f) || !fin) {
      cat(sprintf("%-22s %s; failures: %s; sweep clamps %s %s\n", sprintf("ARK soil x%d", w),
                  if (!done(f)) "did not finish" else "gradient refused",
                  if (length(x1$failures)) paste(names(x1$failures), collapse = ", ") else "none",
                  clamps(x1$stand$swept_clamps), clamps(x1$invader$swept_clamps)))
      meets[[paste(r, w)]] <- FALSE
      next
    }
    d1 <- dist(x1)
    c2 <- sapply(c("resident", "invader"), function(ro)
      d1[[ro]]$med <= d0[[ro]]$med && d1[[ro]]$max <= d0[[ro]]$max && d1[[ro]]$max < 1 / 3)
    bud <- sapply(c("resident", "invader"), function(ro) d1[[ro]]$max < 1 / 3 && d1[[ro]]$med < 0.02)
    meets[[paste(r, w)]] <- all(bud)
    show(sprintf("ARK soil x%d", w), x1, grad_cost(x1), d1,
         sprintf("(i) %s/%s (ii) %s/%s", ifelse(c2[1], "pass", "FAIL"), ifelse(c2[2], "pass", "FAIL"),
                 ifelse(bud[1], "pass", "FAIL"), ifelse(bud[2], "pass", "FAIL")))
  }
}
ok <- vapply(weights, function(w) isTRUE(meets[[paste("long-drought", w)]]) && isTRUE(meets[[paste("episodic", w)]]), TRUE)
pick <- if (any(ok)) max(weights[ok]) else NA
cat(sprintf("\n== The pick: the largest soil weight meeting the budget reading on both records and both roles: %s\n",
            if (is.na(pick)) "none of 10, 30, 50, 100" else pick))
for (w in weights) cat(sprintf("   x%-3d long drought %s, episodic %s\n", w,
                               if (isTRUE(meets[[paste("long-drought", w)]])) "meets" else "misses",
                               if (isTRUE(meets[[paste("episodic", w)]])) "meets" else "misses"))

if (!is.na(pick)) {
  cat(sprintf("\n== C3 for the pick (soil x%d) on long drought: the +-5%% nudges, each quantity's larger move, in eps/3\n", pick))
  base <- run_of("long-drought", pick)
  nudged <- file.path(C, "full", sprintf("arkB_w%d_ld_%s.rds", pick, c("2.85e-5", "3.15e-5")))
  if (all(vapply(c(base, nudged), done, TRUE))) {
    qb <- quantities(readRDS(base)); nq <- lapply(nudged, function(f) quantities(readRDS(f)))
    n <- Reduce(intersect, c(list(names(qb)), lapply(nq, names)))
    d <- do.call(pmax, lapply(nq, function(q) abs(q[n] - qb[n]))) * 3
    for (f in nudged) { y <- readRDS(f)
      cat(sprintf("   %-24s J %.9f | sweep clamps %s %s | gradient finite %d and %d of 50\n", basename(f), y$stand$J,
                  clamps(y$stand$swept_clamps), clamps(y$invader$swept_clamps),
                  sum(is.finite(y$stand$elasticity)), sum(is.finite(y$invader$elasticity)))) }
    for (ro in c("resident", "invader")) {
      s <- startsWith(n, paste0(ro, " ")); o <- order(-d[s])[1:3]
      cat(sprintf("   %-8s median %.3f, largest %s; over 1: %d -> C3 %s\n", ro, median(d[s]),
                  paste(sprintf("%.3f (%s)", d[s][o], sub("^(resident|invader) ", "", n[s][o])), collapse = ", "),
                  sum(d[s] > 1), if (sum(d[s] > 1) == 0) "pass" else "FAIL"))
    }
  } else cat("   nudges not run yet\n")
}
