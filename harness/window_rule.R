# The windows of both roles on each record, how well each pilot reads them, and
# the rule a pilot sets, from harness/invader_window.R's runs in RUNS:
# win_<record>_u108.rds (win_constant_Gbf16.rds) at 3e-5, and
# pilot_<record>_<nodes>_<tol>.rds.
#
# The rule weights every tolerance by F(t) = 1 / clamp(Ru(t) / R0, r_min, 1) and
# spaces nodes on the 108 lattice by floor(sqrt(F(b))) spacings, where Ru is the
# largest R over the stand and its invaders. A step's error and a node's weigh at
# most R at their time, a step's error goes as its tolerance and a node's as its
# spacing squared, so past R0 neither carries more than R0 of a base one's bound.
# ROLES names the invaders the rule's union takes beside the stand, all of them
# unless set. OUT gets weight_<record>.rds for harness/ark_prototype.R's WEIGHT and
# t_<record>_rule.rds for TIMES.
#
#   [RUNS=dir] [PILOT=u54_1e-3] [R0=0.1] [R_MIN=0.01] [ROLES=lma=0.5,lma=2] \
#     [OUT=dir] Rscript harness/window_rule.R
runs <- Sys.getenv("RUNS", "runs")
pilot <- Sys.getenv("PILOT", "u54_1e-3")
R0 <- as.numeric(Sys.getenv("R0", "0.1"))
r_min <- as.numeric(Sys.getenv("R_MIN", "0.01"))
rule_roles <- if (nzchar(Sys.getenv("ROLES"))) c("stand", strsplit(Sys.getenv("ROLES"), ",")[[1]])
out_dir <- Sys.getenv("OUT")
records <- c("long-drought", "long-wet", "dry", "episodic", "constant")
ref_file <- function(r) file.path(runs, if (r == "constant") "win_constant_Gbf16.rds" else
  sprintf("win_%s_u108.rds", r))
pilot_file <- function(r, k) file.path(runs, if (r == "constant")
  sprintf("pilot_constant_Gb_%s.rds", sub("^u[0-9]+_", "", k)) else sprintf("pilot_%s_%s.rds", r, k))
at <- c(10, 15, 20, 25, 30, 35)

# Each role's R on the sample grid; an invader that raised has none.
roles <- function(x) {
  r <- list(stand = x$stand$R)
  for (k in names(x$invaders)) if (is.null(x$invaders[[k]]$error)) r[[k]] <- x$invaders[[k]]$R
  r[names(r) != "lma=1"]
}
Ru <- function(x) do.call(pmax, roles(x))
# The first sample time at which R falls to p or below.
by <- function(grid, R, p) { i <- which(R <= p)[1]; if (is.na(i)) NA else grid[i] }

cat("== The windows: R(t) and when R falls to 0.99, 0.5, 0.1, 0.01, 1e-3; 3e-5 tied,\n")
cat("   uniform 108 (the constant record on const_Gbf16)\n")
ref <- list()
for (r in records) {
  f <- ref_file(r)
  if (!file.exists(f)) next
  x <- ref[[r]] <- readRDS(f)
  J <- c(stand = x$stand$J, vapply(x$invaders, function(v) if (is.null(v$J)) NA else v$J, 0))
  for (k in names(roles(x))) {
    R <- roles(x)[[k]]
    cat(sprintf("%-12s %-9s J %-10.4g R %s | falls to 0.99/0.5/0.1/0.01/1e-3 at %s\n", r, k, J[[k]],
                paste(sprintf("%7.3g", R[match(at, round(x$grid, 2))]), collapse = " "),
                paste(sprintf("%5.2f", vapply(c(0.99, 0.5, 0.1, 0.01, 1e-3), function(p) by(x$grid, R, p), 0)),
                      collapse = " ")))
  }
  for (k in names(x$invaders)) if (!is.null(x$invaders[[k]]$error))
    cat(sprintf("%-12s %-9s raised: %s\n", r, k, x$invaders[[k]]$error))
  u <- Ru(x)
  lead <- apply(do.call(cbind, roles(x)), 1, which.max)
  cat(sprintf("%-12s %-9s          R %s | falls to 0.99/0.5/0.1/0.01/1e-3 at %s; set after t = 25 by %s\n",
              r, "union", paste(sprintf("%7.3g", u[match(at, round(x$grid, 2))]), collapse = " "),
              paste(sprintf("%5.2f", vapply(c(0.99, 0.5, 0.1, 0.01, 1e-3), function(p) by(x$grid, u, p), 0)),
                    collapse = " "),
              paste(names(table(names(roles(x))[lead[x$grid > 25 & u >= 1e-4]])), collapse = ", ")))
}

cat("\n== Each pilot against the windows: cost in member-steps over the reference's, and\n")
cat("   the largest |R_pilot / R - 1| where R >= 1e-3, with the time it is at; for the\n")
cat("   stand and the union also where the weight reads R, 1e-3 <= R <= R0\n")
for (r in names(ref)) {
  x <- ref[[r]]
  for (k in c("u27_3e-5", "u27_1e-3", "u54_1e-3")) {
    f <- pilot_file(r, k)
    if (!file.exists(f)) next
    y <- readRDS(f)
    err <- function(a, b, top = Inf) {
      s <- b >= 1e-3 & b <= top; e <- abs(a[s] / b[s] - 1); c(max(e), x$grid[s][which.max(e)])
    }
    ry <- roles(y); rx <- roles(x)
    e <- sapply(intersect(names(rx), names(ry)), function(k2) err(ry[[k2]], rx[[k2]]))
    eu <- err(Ru(y), Ru(x))
    ew <- c(err(ry$stand, rx$stand, R0)[1], err(Ru(y), Ru(x), R0)[1])
    cat(sprintf("%-12s %-9s cost %.3f | %s | union %.3f (t %.2f) | where the weight reads R: stand %.3f, union %.3f\n",
                r, if (r == "constant") sub("u27", "Gb", k) else k, y$stand$member_steps / x$stand$member_steps,
                paste(sprintf("%s %.3f (t %.2f)", colnames(e), e[1, ], e[2, ]), collapse = ", "), eu[1], eu[2],
                ew[1], ew[2]))
  }
}

cat("\n== Residents within 10% of theta_0 on the 27-node pilot at 1e-3: when R falls to\n")
cat("   0.5, 0.1, 0.01, 1e-3, and the largest R over theta_0's where theta_0's is 1e-3 to R0\n")
for (r in records) {
  f0 <- pilot_file(r, "u27_1e-3")
  if (!file.exists(f0)) next
  y0 <- readRDS(f0)
  for (s in c("lma=0.9", "lma=1.1", "hmat=0.9", "hmat=1.1")) {
    f <- file.path(runs, sprintf("pilot_%s_u27_1e-3_stand_%s.rds", r, s))
    if (!file.exists(f)) next
    y <- readRDS(f)
    w <- y0$stand$R >= 1e-3 & y0$stand$R <= R0
    cat(sprintf("%-12s %-9s J %-8.4g falls at %s (theta_0: %s) | R / R_theta0 at most %.2f\n", r, s, y$stand$J,
                paste(sprintf("%5.2f", vapply(c(0.5, 0.1, 0.01, 1e-3), function(p) by(y$grid, y$stand$R, p), 0)), collapse = " "),
                paste(sprintf("%5.2f", vapply(c(0.5, 0.1, 0.01, 1e-3), function(p) by(y0$grid, y0$stand$R, p), 0)), collapse = " "),
                max(y$stand$R[w] / y0$stand$R[w])))
  }
}

# The rule from the pilot.
weight_of <- function(R) 1 / pmin(pmax(R / R0, r_min), 1)
U108 <- seq(0, 107 * 40 / 108, length.out = 108)
thinned <- function(grid, F) {
  keep <- 1
  repeat {
    i <- tail(keep, 1)
    k <- floor(sqrt(F[max(1, findInterval(U108[i], grid))]))
    if (i + k > length(U108)) break
    keep <- c(keep, i + k)
  }
  U108[sort(unique(c(keep, length(U108))))]
}
cat(sprintf("\n== The rule from the %s pilot: R0 %g, r_min %g, union of %s\n", pilot, R0, r_min,
            if (is.null(rule_roles)) "every role" else paste(rule_roles, collapse = ", ")))
for (r in records) {
  f <- pilot_file(r, pilot)
  if (!file.exists(f)) next
  y <- readRDS(f)
  ry <- roles(y)
  if (!is.null(rule_roles)) {
    missing <- setdiff(rule_roles, names(ry))
    if (length(missing)) cat(sprintf("%-12s the pilot has no window for %s: it raised\n", r, paste(missing, collapse = ", ")))
    ry <- ry[intersect(rule_roles, names(ry))]
  }
  F <- weight_of(do.call(pmax, ry))
  w <- data.frame(t = c(0, y$grid), weight = c(1, F))
  b <- thinned(y$grid, F)
  starts <- vapply(c(1.0001, 2, 10, 100), function(v) { i <- which(F >= v)[1]; if (is.na(i)) NA else y$grid[i] }, 0)
  cat(sprintf("%-12s weight first above 1, 2, 10, 100 at t = %s | %d nodes, thinned after b = %.2f\n", r,
              paste(sprintf("%.2f", starts), collapse = ", "), length(b), b[which(diff(match(b, U108)) > 1)[1]]))
  # A role is inside what the rule protects where R F stays at most R0 wherever
  # the rule loosens: no loosened step weighs more for it than R0 of a base step.
  if (!is.null(ref[[r]])) {
    rr <- roles(ref[[r]])
    inside <- vapply(rr, function(R) max(c(0, (R * F)[F > 1])) / R0, 0)
    cat(sprintf("%-12s largest R F / R0 where F > 1, on the reference windows: %s\n", "",
                paste(sprintf("%s %.2f", names(inside), inside), collapse = ", ")))
  }
  if (nzchar(out_dir)) {
    dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
    saveRDS(w, file.path(out_dir, sprintf("weight_%s.rds", r)))
    if (r != "constant") saveRDS(b, file.path(out_dir, sprintf("t_%s_rule.rds", r)))
  }
}
