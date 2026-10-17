# score_ind.R CASE...: the region ranking by indicator 1 (W: own + adjoint-weighted field of the
# omit-one map; U: plain curvature of the per-recruit leaf area; A: own part alone, plant's old
# indicator) against the measured region errors, in |ln J| and in the elasticities' rms.
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/p50/split.R")
DW <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/dwr"
u <- 0.025; r2e <- function(v) sqrt(mean(v[names(v) != "lnJ"]^2, na.rm = TRUE))
fac <- function(t) { k <- suppressWarnings(as.integer(sub("^[A-Za-z_]+", "", t))); if (is.na(k)) 1 else -k^2 / (k^2 - 1) }
measured <- function(cs, c0) {
  ec <- err_run(c0, cs); M <- list(F = -4 / 3 * mv_run(readRDS(file.path(FO, "runs", sprintf("fbis_%s.rds", cs))), c0)[names(ec)])
  rf <- file.path(CL, "runs", sprintf("cl_res_%s.rds", cs)); res <- if (file.exists(rf)) readRDS(rf) else NULL
  if (!is.null(res)) M$C <- mv_run(c0, res)[names(ec)]
  if (!is.null(res)) for (g in c("I4", "O4", "L4", "B")) { f <- file.path(P5, "runs", sprintf("p5_%s_%s.rds", g, cs))
    if (file.exists(f)) M[[sub("4$", "", g)]] <- fac(g) * mv_run(readRDS(f), res)[names(ec)] }
  rest <- ec; for (g in names(M)) rest <- rest - M[[g]]
  if (length(M) <= 2) M$rest <- rest else M$unplaced <- rest
  M }
x_of <- function(nr, b, w) { # per-recruit leaf area at ground, nodes x times (NA before birth)
  ih <- match("height", nr$names); im <- match("mortality", nr$names); p <- length(nr$names)
  X <- matrix(NA, length(b), length(nr$time))
  for (t in seq_along(nr$time)) { s <- nr$state[[t]]; k <- sum(b <= nr$time[t] + 1e-12); if (k < 1) next
    st <- matrix(s[seq_len(p * k)], nrow = p); X[seq_len(k), t] <- (st[ih, ] / nr$a_l1)^(1 / nr$a_l2) * exp(-st[im, ]) * nr$patch_density[seq_len(k)] }
  X }
delta_of <- function(j, b, E, M, X) { # omit-one over-count of node j (rows of X are nodes), per time
  hb <- b[j] - b[j - 1]; ha <- b[j + 1] - b[j]
  bel <- c(E[j - 1] - M[j - 1] / hb, M[j - 1] / hb); abv <- c(E[j] - M[j] / ha, M[j] / ha)
  mom <- bel[2] * hb + abv[2] * ha + sum(abv) * hb; sp2 <- mom / (hb + ha); sp1 <- sum(bel) + sum(abv) - sp2
  (sp1 - bel[1]) * X[j - 1, ] + (sp2 - abv[2]) * X[j + 1, ] - (bel[2] + abv[1]) * X[j, ] }
spear <- function(a, b) if (length(a) >= 3) suppressWarnings(cor(a, b, method = "spearman")) else NA
out <- list()
for (cs in commandArgs(TRUE)) {
  ro <- readRDS(file.path(DW, "sched", sprintf("role_%s.rds", cs))); c0 <- readRDS(run_file(ro$run)); S <- ro$S; n <- length(S)
  ma <- readRDS(file.path(DW, "runs", sprintf("map_o1a_%s.rds", cs))); mb <- readRDS(file.path(DW, "runs", sprintf("map_o1b_%s.rds", cs)))
  J <- c0$stand$J; fld <- rep(0, n); li <- rep(0, n)
  for (m in list(ma, mb)) { fld[m$dropped] <- colSums(m$light + m$soil) / J / u; li[m$dropped] <- colSums(m$light) / J / u }
  guard <- identical(ma$stand$J, J) && identical(mb$stand$J, J)
  st <- c0$stand$nodes$state; E <- st["interval_establishment", ]; Mm <- st["interval_establishment_moment", ]
  X <- x_of(ma$noderec, S, c0$stand$nodes$establishment); W <- c0$stand$nodes$establishment[1:n]
  tot <- colSums(W * X, na.rm = TRUE)
  set_of <- list(F = which(ro$role == "F"), I = which(ro$role %in% c("Ia", "Ib", "Ic")), L = which(ro$role == "L"),
                 O = which(ro$role == "Oi"), C = which(ro$role == "Ci"), B = which(ro$role == "Bi"))
  ind <- t(sapply(names(set_of), function(g) { k <- set_of[[g]]; if (!length(k)) return(c(W = NA, own = NA, field = NA, light = NA, U = NA))
    own <- interp_part(c0, S[-k]) / u; d <- rowSums(sapply(k, function(j) delta_of(j, S, E, Mm, X)), na.rm = TRUE)
    c(W = (own + sum(fld[k])) / 3, own = own / 3, field = sum(fld[k]) / 3, light = sum(li[k]) / 3, U = mean(abs(d) / tot, na.rm = TRUE)) }))
  M <- measured(cs, c0)
  regs <- intersect(names(M), rownames(ind)); if ("rest" %in% names(M)) regs <- c("F", "rest")
  val <- function(g, col) if (g == "rest") { k <- setdiff(rownames(ind), "F"); if (col == "U") sum(ind[k, col], na.rm = TRUE) else sum(ind[k, col], na.rm = TRUE) } else ind[g, col]
  tab <- data.frame(region = regs, meas_lnJ = sapply(regs, function(g) M[[g]]["lnJ"]), meas_rms = sapply(regs, function(g) r2e(M[[g]])),
                    W = sapply(regs, val, "W"), A = sapply(regs, val, "own"), U = sapply(regs, val, "U"))
  sc <- sapply(c("W", "A", "U"), function(k) c(sp_lnJ = spear(abs(tab[[k]]), abs(tab$meas_lnJ)), sp_rms = spear(abs(tab[[k]]), tab$meas_rms),
    top_lnJ = which.max(abs(tab[[k]])) == which.max(abs(tab$meas_lnJ)), top_rms = which.max(abs(tab[[k]])) == which.max(tab$meas_rms)))
  cat(sprintf("== %s (guard J identical %s; unplaced in measured: %s)\n", cs, guard, if (!is.null(M$unplaced)) sprintf("lnJ %+.2f rms %.3f", M$unplaced["lnJ"], r2e(M$unplaced)) else "-"))
  print(format(cbind(round(ind, 3)), digits = 3)); print(format(tab, digits = 3), row.names = FALSE); print(round(sc, 2))
  out[[cs]] <- list(ind = ind, tab = tab, sc = sc, M = M)
}
saveRDS(out, file.path(DW, sprintf("score_ind_%s.rds", paste(names(out), collapse = "_"))))
