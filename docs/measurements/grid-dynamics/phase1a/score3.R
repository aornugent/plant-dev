# Stage 3: the survivors on the constant record (resolved 150-node grid) and on episodic
# (108 uniform nodes), against each record's CK baseline at 3e-5: rows, forward, a gradient
# run's cost, J - J*, binding components; and, where plant replays exist, the main
# elasticities of both roles against the baseline's on the same record, in units of eps.
#   Rscript score3.R
D <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev"
P <- file.path(D, "phase1a")
W <- "/home/user/plant-dev/.claude/worktrees/agent-a49b34f804b88b2d4"
NODE <- c("height", "mortality", "fecundity", "area_heartwood", "mass_heartwood",
          "storage", "offspring", "log_density", "mass")
ENV <- c(paste0("soil_", 1:5), paste0("accumulator_", 1:5))
rec <- list(constant = list(base = file.path(D, "pi/runs/const_base_3e-5.rds"), jstar = 289.2738962,
                            pbase = file.path(P, "plant/const_base_3e-5.rds"), tag = "const"),
            episodic = list(base = file.path(D, "window/drv/episodic_base.rds"), jstar = 1.978902094,
                            pbase = file.path(D, "window/full/epi_pin_base.rds"), tag = "epi"))
runs <- c("ck10_3e-5", "ck10_1e-4", "ark100_1e-5")
row <- function(name, f, base, jstar) {
  r <- readRDS(f); b <- readRDS(base); st <- r$st
  rows <- sum(as.numeric(st$M)); brows <- sum(as.numeric(b$st$M))
  kind <- ifelse(st$ei <= 9 * st$M, NODE[(st$ei - 1) %% 9 + 1], ENV[pmax(1, st$ei - 9 * st$M)])
  data.frame(run = name, accepted = nrow(st), rows = rows, forward = r$counts$members,
             rows_rel = sprintf("%+.1f%%", 100 * (rows / brows - 1)),
             forward_rel = sprintf("%+.1f%%", 100 * (r$counts$members / b$counts$members - 1)),
             gradient_rel = sprintf("%+.1f%%", 100 * ((r$counts$members / b$counts$members + 6 * rows / brows) / 7 - 1)),
             e_J = sprintf("%+.2e", r$J / jstar - 1),
             bind_soil = sprintf("%.1f%%", 100 * mean(grepl("^soil_", kind))),
             bind_member = sprintf("%.1f%%", 100 * mean(kind %in% NODE)),
             x1 = sprintf("%.1f%%", 100 * mean(st$x_soil > 1)))
}
eps <- read.csv(file.path(W, "docs/measurements/eps.csv"))
eps_of <- function(role, q) eps$eps[eps$role == role & eps$trait == (if (q == "lnJ") "ln J" else q)][1]
RES <- c("lnJ", "lma", "a_dG2", "a_dG1", "d_I", "storage_relaxation_offset", "TF24_cost_scale")
INV <- c("lnJ", "lma", "a_dG2")
pq <- function(f) {
  r <- readRDS(f)
  if (is.null(r$invader$elasticity)) return(NULL)
  es <- r$stand$elasticity; names(es) <- sub("^1\\.", "", names(es))
  ei <- r$invader$elasticity; names(ei) <- sub("^1\\.", "", names(ei))
  rbind(data.frame(role = "resident", q = RES, value = c(log(r$stand$J), es[RES[-1]])),
        data.frame(role = "invader", q = INV, value = c(log(r$invader$J), ei[INV[-1]])))
}
options(width = 200)
for (k in names(rec)) {
  x <- rec[[k]]
  cat(sprintf("\n== %s (J* = %.10g)\n", k, x$jstar))
  out <- row("base_3e-5", x$base, x$base, x$jstar)
  for (v in runs) {
    f <- file.path(P, "runs", sprintf("%s_%s.rds", x$tag, v))
    if (file.exists(f)) out <- rbind(out, row(v, f, x$base, x$jstar))
  }
  print(out, row.names = FALSE)
  # ark100's frozen partial elasticities (THETA_AFTER=1; u 1e-4, d_I 1e-3) on this record.
  U <- c(lma = 1e-4, a_dG1 = 1e-4, a_dG2 = 1e-4, d_I = 1e-3)
  stem <- file.path(P, "frozen", sprintf("%s_ark100_1e-5", x$tag))
  # On the constant record d_I's pair at 1e-3 raised (a pinned step put a near-empty pool
  # below zero), so its pair at 1e-4 stands in where present.
  fz <- function(th) {
    f <- sprintf("%s_%s_%%s.rds", stem, th); u <- U[[th]]
    if (!file.exists(sprintf(f, "-")) && th == "d_I") { f <- sprintf("%s_d_I_u1e-4_%%s.rds", stem); u <- 1e-4 }
    if (!file.exists(sprintf(f, "-"))) return(NA)
    log(readRDS(sprintf(f, "+"))$J / readRDS(sprintf(f, "-"))$J) / (log1p(u) - log1p(-u))
  }
  if (file.exists(sprintf("%s_a_dG2_-.rds", stem)) && file.exists(x$pbase)) {
    E <- vapply(names(U), fz, 0)
    a <- data.frame(role = "resident", q = c("lnJ", names(U)),
                    value = c(log(readRDS(file.path(P, "runs", sprintf("%s_ark100_1e-5.rds", x$tag)))$J), E))
    b <- pq(x$pbase)
    m <- merge(a, b, by = c("role", "q"), suffixes = c("", "_base"))
    m$eps <- mapply(eps_of, m$role, m$q)
    m$diff_eps <- round(abs(m$value - m$value_base) / m$eps, 3)
    cat(sprintf("   ark100_1e-5's frozen elasticities against the baseline's plant ones on %s (|difference| / eps):\n", k))
    print(m[match(c("lnJ", names(U)), m$q), c("role", "q", "value", "value_base", "diff_eps")], row.names = FALSE)
  }
  for (v in runs) {
    f <- file.path(P, "plant", sprintf("%s_%s.rds", x$tag, v))
    if (!file.exists(f) || !file.exists(x$pbase)) next
    a <- pq(f); b <- pq(x$pbase)
    if (is.null(a) || is.null(b)) next
    m <- merge(a, b, by = c("role", "q"), suffixes = c("", "_base"))
    m$eps <- mapply(eps_of, m$role, m$q)
    m$diff_eps <- round(abs(m$value - m$value_base) / m$eps, 3)
    cat(sprintf("   %s's main quantities against the baseline's on %s (|difference| / eps):\n", v, k))
    print(m[order(m$role != "resident", match(m$q, RES)), c("role", "q", "value", "value_base", "diff_eps")], row.names = FALSE)
  }
}
