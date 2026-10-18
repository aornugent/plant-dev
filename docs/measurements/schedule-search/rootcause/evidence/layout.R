# layout.R: the design's layout D from a pilot, schedule only. Breakpoints are 0, every
# opening edge and the horizon; rho0 = 1/h of a09's graded build (BG 90, its caps) where
# establishment is open, 0 where it is shut; each panel gets ceiling(s * integral rho0)
# intervals at equal rho0-mass, so closing edges are not nodes. Also the alternate drop
# of each panel's interior nodes, the rows model (steps after each birth, from the
# pilot's own steps) and E6 committed's schedule for comparison.
Sys.setenv(BG = 90, R = 1.6)
suppressMessages(source("/home/user/plant-dev/docs/measurements/schedule-search/round4/P/lib.R"))
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/heldout/cases.R")
SC <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause"
H <- 39.6
BANK <- c("episodic", "dry", "long-wet", "long-drought", "episodic-lma", "dry-flat", "ld-102", "ld-105", "dry-p50", "wet-adG2")
HELD <- names(HO)
pilot_run <- function(cs) readRDS(file.path(RUNS, paste0(case_of(cs)$pilot, ".rds")))$stand
# Every edge of the pilot with its kind (as pilot_edges, all of (0, H)).
edges_all <- function(cs, px = pilot_run(cs)) { cr <- px$creation; op <- cr$rate > 0.01; r <- rle(op); e <- cumsum(r$lengths)
  ed <- cr$end[e][-length(e)]; closing <- op[e][-length(e)]; k <- ed > 0 & ed < H
  data.frame(b = ed[k], opening = !closing[k]) }
# Density of J and of establishment by birth date on a fine grid, from the pilot's creation
# rate and its nodes' fates (log-interpolated).
jdens <- function(px, g) { cr <- px$creation; r <- cr$rate[pmax(1, findInterval(g, cr$start))]
  lf <- approxfun(px$nodes$birth, log(pmax(px$nodes$nrr, 1e-300)), rule = 2)
  list(E = r, J = r * exp(lf(g))) }
E6_c <- function(cs) { f <- if (cs %in% BANK) file.path(POUT, "sched", sprintf("insc_%s.rds", cs)) else file.path(HO_OUT, "sched", sprintf("c_%s.rds", cs))
  if (file.exists(f)) as.numeric(readRDS(f)) else NULL }
rows_model <- function(S, steps) sum(vapply(S, function(b) sum(steps > b), 0))
# Layout D. `late` = FALSE leaves opening edges after `tlate` out of the breakpoints.
layout_D <- function(cs, s = 1, p = pilot_of(cs), px = pilot_run(cs), h = alg$hfun_of(p), late = TRUE, tlate = 25, count = c("intervals", "nodes")) {
  count <- match.arg(count); ea <- edges_all(cs, px); op <- ea$b[ea$opening]; if (!late) op <- op[op <= tlate]
  br <- sort(unique(c(0, op, H))); g <- seq(0, H, length.out = 40001); dg <- diff(g)[1]; gm <- g[-1] - dg / 2
  open <- p$shut(gm) < 0.5; capv <- vapply(gm, function(b) if (b < p$b1) p$b1 / 12 else if (b < 20) 100 / 365 else 280 / 365, 0)
  hv <- vapply(gm, h, 0); rho <- ifelse(open, 1 / pmin(hv, capv), 0); jd <- jdens(px, gm)
  S <- c(); pan <- list(); member <- list()
  for (i in seq_len(length(br) - 1)) { a <- br[i]; b <- br[i + 1]; k <- gm >= a & gm < b
    m <- s * sum(rho[k]) * dg; n <- max(1, ceiling(m - 1e-9)); if (count == "nodes") n <- max(1, ceiling(m - 1e-9) + 1)
    x <- c(); if (n > 1 && m > 0) { cw <- c(0, cumsum(rho[k] * dg)); u <- c(a, gm[k] + dg / 2)
      x <- approx(cw / tail(cw, 1), u, seq(0, 1, length.out = n + 1)[2:n], ties = "ordered")$y }
    S <- c(S, a, x); member[i] <- list(x)
    pan[[i]] <- data.frame(lo = a, hi = b, days = (b - a) * 365, m = m, n_int = n, n_interior = length(x),
      Jsh = sum(jd$J[k]) / sum(jd$J), Esh = sum(jd$E[k]) / sum(jd$E), spell_days = sum(open[k]) * dg * 365) }
  S <- sort(unique(round(S, 10)))
  # the alternate drop: each panel's 1st, 3rd, ... interior node
  drop <- unlist(lapply(member, function(x) if (length(x)) x[seq(1, length(x), by = 2)]))
  list(S = S, panels = do.call(rbind, pan), drop = round(drop, 10), breaks = br, member = member) }
