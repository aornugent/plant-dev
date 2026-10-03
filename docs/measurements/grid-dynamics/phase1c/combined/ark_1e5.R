# ARK at 1e-5 against ARK at 3e-5, arms A and B, on long drought and episodic:
# cost against unweighted and bounded Cash-Karp at 3e-5, J's error, each role's
# median and largest distance from 1e-5 (and which quantity), the sweeps' soil
# clamps, the readings (i) C2 and (ii) the budget; the 3e-5 to 1e-5 ratio of each
# role's distances and which explanation it supports (H1 kinks ~1.25, H2 order
# ~3); then C3 for an arm meeting (ii) on both records.
#
#   Rscript ark_1e5.R
D <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev"
WT <- "/home/user/plant-dev/.claude/worktrees/agent-a12cdeaf09a1e3e8a"
C <- file.path(D, "phase1c/combined")
source(file.path(D, "phase1c/nudge_spread.R"))  # eps, eps_of, quantities
sc <- file.path(WT, "docs/measurements/spot-check")
recs <- list(
  "long-drought" = list(short = "ld", base = file.path(sc, "ld_3e-5.rds"), bnd = file.path(C, "full/bnd_ld.rds"),
                        ref = file.path(WT, "docs/measurements/nudges/ld_1e-5.rds"), jstar = 12.6687135),
  episodic = list(short = "epi", base = file.path(sc, "epi_base.rds"), bnd = file.path(C, "full/bnd_epi.rds"),
                  ref = file.path(D, "phase1c/full/epi_1e-5.rds"), jstar = file.path(D, "window/ref/epi_1e-8_abs.rds")))
run_of <- function(arm, tol, r) file.path(C, "full", if (tol == "3e-5") sprintf("ark%s_%s.rds", arm, recs[[r]]$short) else
  sprintf("ark%s_1e-5_%s.rds", arm, recs[[r]]$short))
done <- function(f) file.exists(f) && !is.null(readRDS(f)$finished)
finite <- function(x) !is.null(x$stand$elasticity) && !is.null(x$invader$elasticity) &&
  all(is.finite(x$stand$elasticity)) && all(is.finite(x$invader$elasticity))
jstar_of <- function(j) if (is.numeric(j)) j else readRDS(j)$stand$J
rows_of <- function(x) sum(as.numeric(findInterval(head(x$stand$times, -1), sort(x$node_times))))
grad_cost <- function(x) {
  a <- x$stand$attempts; ms <- rows_of(x)
  c(rows = ms, forward = ms * (a[["accepted"]] + a[["rejected_inaccurate"]] + a[["rejected_thrown"]]) / a[["accepted"]])
}
gr <- function(c1, c0) 100 * ((c1[["forward"]] / c0[["forward"]] + 6 * c1[["rows"]] / c0[["rows"]]) / 7 - 1)
clamps <- function(v) if (is.null(v) || all(is.na(v))) "-" else paste(v, collapse = "/")
roles <- c("resident", "invader")
meets <- list(); dists <- list()
for (r in names(recs)) {
  g <- recs[[r]]
  x0 <- readRDS(g$base); xb <- readRDS(g$bnd); c0 <- grad_cost(x0); cb <- grad_cost(xb); Js <- jstar_of(g$jstar)
  qr <- quantities(readRDS(g$ref))
  dist <- function(x) {
    q <- quantities(x); m <- intersect(names(qr), names(q)); d <- abs(q[m] - qr[m])
    lapply(setNames(roles, roles), function(ro) {
      s <- startsWith(m, paste0(ro, " ")); v <- d[s]
      list(med = median(v), max = max(v), at = sub("^(resident|invader) ", "", m[s][which.max(v)]))
    })
  }
  d0 <- dist(x0)
  cat(sprintf("\n== %s (distances from %s, in eps; sweep clamps moisture floor/potential ceiling/positivity, stand then invader)\n",
              r, basename(g$ref)))
  cat(sprintf("%-20s %8s %8s %10s | %-40s | %-40s | %-11s | %s\n", "run", "vs CK", "vs bnd", "J/J* - 1",
              "resident: median, largest (quantity)", "invader: median, largest (quantity)", "sweeps", "(i) C2, (ii) budget"))
  show <- function(label, x, dd, readings) {
    cat(sprintf("%-20s %+7.1f%% %+7.1f%% %+10.2e | %.4f, %.4f (%-16s) | %.4f, %.4f (%-16s) | %-11s | %s\n",
                label, gr(grad_cost(x), c0), gr(grad_cost(x), cb), x$stand$J / Js - 1,
                dd$resident$med, dd$resident$max, dd$resident$at, dd$invader$med, dd$invader$max, dd$invader$at,
                paste(clamps(x$stand$swept_clamps), clamps(x$invader$swept_clamps)), readings))
  }
  show("unweighted CK 3e-5", x0, d0, "")
  show("bounded CK 3e-5", xb, dist(xb), "")
  for (arm in c("A", "B")) for (tol in c("3e-5", "1e-5")) {
    f <- run_of(arm, tol, r); label <- sprintf("ARK arm %s %s", arm, tol)
    if (!file.exists(f)) { cat(sprintf("%-20s not run\n", label)); next }
    x1 <- readRDS(f)
    if (!done(f) || !finite(x1)) {
      cat(sprintf("%-20s %s; failures: %s; sweep clamps %s %s\n", label, if (!done(f)) "did not finish" else "gradient refused",
                  if (length(x1$failures)) paste(names(x1$failures), collapse = ", ") else "none",
                  clamps(x1$stand$swept_clamps), clamps(x1$invader$swept_clamps)))
      if (tol == "1e-5") meets[[paste(arm, r)]] <- FALSE
      next
    }
    d1 <- dist(x1); dists[[paste(arm, tol, r)]] <- d1
    c2 <- sapply(roles, function(ro) d1[[ro]]$med <= d0[[ro]]$med && d1[[ro]]$max <= d0[[ro]]$max && d1[[ro]]$max < 1 / 3)
    bud <- sapply(roles, function(ro) d1[[ro]]$max < 1 / 3 && d1[[ro]]$med < 0.02)
    if (tol == "1e-5") meets[[paste(arm, r)]] <- all(bud)
    show(label, x1, d1, sprintf("(i) %s/%s (ii) %s/%s", ifelse(c2[1], "pass", "FAIL"), ifelse(c2[2], "pass", "FAIL"),
                                ifelse(bud[1], "pass", "FAIL"), ifelse(bud[2], "pass", "FAIL")))
  }
}

# The 1e-5 reference's own spread on long drought: its +-5% nudges (9.5e-6,
# 1.05e-5), each role's median and largest move; a 1e-5 distance at that level
# cannot shrink further.
ndir <- file.path(WT, "docs/measurements/nudges")
q10 <- quantities(readRDS(file.path(ndir, "ld_1e-5.rds")))
nq <- lapply(c("ld_9.5e-6.rds", "ld_1.05e-5.rds"), function(f) quantities(readRDS(file.path(ndir, f))))
n <- Reduce(intersect, c(list(names(q10)), lapply(nq, names)))
spread <- do.call(pmax, lapply(nq, function(q) abs(q[n] - q10[n])))
floor_of <- lapply(setNames(roles, roles), function(ro) { s <- startsWith(n, paste0(ro, " "))
  c(med = median(spread[s]), max = max(spread[s])) })
cat(sprintf("\n== The 3e-5 to 1e-5 ratio of each role's distance from 1e-5 (H2, a smooth order-4 bias: ~3; H1, crossing kinks: ~1.25)\n"))
cat(sprintf("   long drought's 1e-5 reference spread under its own +-5%% nudges: resident median %.4f, largest %.4f; invader median %.4f, largest %.4f\n",
            floor_of$resident[["med"]], floor_of$resident[["max"]], floor_of$invader[["med"]], floor_of$invader[["max"]]))
reading <- function(ratio, d1, fl) {
  if (!is.na(fl) && d1 <= 1.5 * fl) return("at the reference's spread: not read")
  if (ratio >= 2.5) "H2" else if (ratio <= 1.5) "H1" else "mixed"
}
for (r in names(recs)) for (arm in c("A", "B")) {
  a <- dists[[paste(arm, "3e-5", r)]]; b <- dists[[paste(arm, "1e-5", r)]]
  if (is.null(a) || is.null(b)) { cat(sprintf("   %-12s arm %s: not available\n", r, arm)); next }
  for (ro in roles) {
    fl <- if (r == "long-drought") floor_of[[ro]] else c(med = NA, max = NA)
    cat(sprintf("   %-12s arm %s %-8s largest %.4f -> %.4f (ratio %.2f, %s); median %.4f -> %.4f (ratio %.2f, %s)\n",
                r, arm, ro, a[[ro]]$max, b[[ro]]$max, a[[ro]]$max / b[[ro]]$max,
                reading(a[[ro]]$max / b[[ro]]$max, b[[ro]]$max, fl[["max"]]),
                a[[ro]]$med, b[[ro]]$med, a[[ro]]$med / b[[ro]]$med,
                reading(a[[ro]]$med / b[[ro]]$med, b[[ro]]$med, fl[["med"]])))
  }
}

cat("\n== Arms meeting the budget reading (ii) at 1e-5 on both records, and C3 for them on long drought\n")
for (arm in c("A", "B")) {
  ok <- isTRUE(meets[[paste(arm, "long-drought")]]) && isTRUE(meets[[paste(arm, "episodic")]])
  cat(sprintf("   arm %s: long drought %s, episodic %s -> %s\n", arm,
              if (isTRUE(meets[[paste(arm, "long-drought")]])) "meets" else "misses",
              if (isTRUE(meets[[paste(arm, "episodic")]])) "meets" else "misses", if (ok) "nudged" else "not nudged"))
  if (!ok) next
  base <- run_of(arm, "1e-5", "long-drought")
  nudged <- file.path(C, "full", sprintf("ark%s_1e-5_ld_%s.rds", arm, c("9.5e-6", "1.05e-5")))
  if (!all(vapply(c(base, nudged), done, TRUE))) { cat("      nudges not run yet\n"); next }
  qb <- quantities(readRDS(base)); nq <- lapply(nudged, function(f) quantities(readRDS(f)))
  n <- Reduce(intersect, c(list(names(qb)), lapply(nq, names)))
  d <- do.call(pmax, lapply(nq, function(q) abs(q[n] - qb[n])))
  for (f in nudged) { y <- readRDS(f)
    cat(sprintf("      %-26s J %.9f | sweep clamps %s %s | gradient finite %d and %d of 50\n", basename(f), y$stand$J,
                clamps(y$stand$swept_clamps), clamps(y$invader$swept_clamps),
                sum(is.finite(y$stand$elasticity)), sum(is.finite(y$invader$elasticity)))) }
  b1 <- dists[[paste(arm, "1e-5", "long-drought")]]
  for (ro in roles) {
    s <- startsWith(n, paste0(ro, " ")); o <- order(-d[s])[1:3]
    cat(sprintf("      %-8s nudges move: median %.4f, largest %s eps (%.3f eps/3); over eps/3: %d -> C3 %s | its distance from 1e-5: median %.4f, largest %.4f\n",
                ro, median(d[s]), paste(sprintf("%.4f (%s)", d[s][o], sub("^(resident|invader) ", "", n[s][o])), collapse = ", "),
                3 * max(d[s]), sum(d[s] > 1 / 3), if (sum(d[s] > 1 / 3) == 0) "pass" else "FAIL", b1[[ro]]$med, b1[[ro]]$max))
  }
}
