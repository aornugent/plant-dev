# score.R CASE: each region's error in every quantity at the committed spacing, (move to the
# region's coarsening)/3, from B (one sweep over the run's rows at c_g = 1, census merged), A
# (forward and sweep at c_g = 1) and R0 (pinned real coarsening), against R0 and the measured
# region errors (dwr/score_ind's M: F from fbis on c; I, L from p50's ladders on res).
suppressMessages(source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/p50/lib.R"))
SO <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/single"
DW <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/dwr"
cs <- commandArgs(TRUE)[1]; u <- 0.025
rr <- function(nm) { f <- file.path(SO, "runs", paste0(nm, ".rds")); if (file.exists(f)) readRDS(f) }
S <- rr(sprintf("S_%s", cs)); saved <- rd(paste0("val_insk_c_", cs)); dr <- readRDS(file.path(SO, "sched", sprintf("drop_%s.rds", cs)))
J <- S$stand$J
cat(sprintf("== %s: guard J identical %s; trait gradient identical to the saved run %s (max rel %.1e)\n", cs, identical(J, saved$stand$J),
  identical(unname(S$stand$elasticity), unname(saved$stand$elasticity)), max(abs(S$stand$elasticity / saved$stand$elasticity - 1), na.rm = TRUE)))
if (!is.null(S$sweep0_cpu)) cat(sprintf("cost: forward %.0f s, plain sweep %.0f s, map sweep %.0f s (%.2fx)\n", S$stand$cpu, S$sweep0_cpu, S$sweep_cpu, S$sweep_cpu / S$sweep0_cpu))
col <- colSums(S$light + S$soil); names(col) <- dr$drop
pseudo <- function(Jc, grad, theta) list(stand = list(J = Jc, elasticity = ifelse(theta == 0, 1, theta) * grad / Jc))
cosv <- function(a, b) { k <- setdiff(intersect(names(a), names(b)), "lnJ"); k <- k[is.finite(a[k]) & is.finite(b[k])]; sum(a[k] * b[k]) / sqrt(sum(a[k]^2) * sum(b[k]^2)) }
cmp <- function(est, tru) { k <- setdiff(intersect(names(est), names(tru)), "lnJ"); k <- k[is.finite(est[k]) & is.finite(tru[k])]
  c(cos = cosv(est, tru), slope = sum(est[k] * tru[k]) / sum(est[k]^2), worst = max(abs(est[k] - tru[k])), rms_diff = r2(est[k] - tru[k]), rms_true = r2(tru[k]), lnJ_est = unname(est["lnJ"]), lnJ_true = unname(tru["lnJ"])) }
meas <- tryCatch(readRDS(file.path(DW, "score_ind_dry_dry-flat_long-wet_dry-p50_episodic_episodic-lma_long-drought_ld-102_ld-105_wet-adG2.rds"))[[cs]]$M, error = function(e) NULL)
est <- list(); tab <- list()
regs <- c(intersect(c("F", "Ia", "Ib", "Ic"), unique(dr$region)), "I", intersect("L", unique(dr$region)))
for (g in regs) {
  dg <- if (g == "I") dr$drop[dr$region %in% c("Ia", "Ib", "Ic")] else dr$drop[dr$region == g]
  out <- list()
  b <- S$B[[g]]
  if (!is.null(b)) { field <- sum(col[as.character(dg)]); Jc <- J + b$census_gain + field
    out$map <- c(lnJ = log(Jc / J) / u / 3, own = log1p(b$census_gain / J) / u / 3, field = field / J / u / 3)
    out$B <- mv_run(pseudo(Jc, b$gradient, S$theta), S) / 3; out$B["lnJ"] <- out$map["lnJ"] }
  a <- rr(sprintf("A_%s_%s", g, cs))
  if (!is.null(a$stand$gradient)) out$A <- mv_run(pseudo(a$stand$J + a$stand$census_gain, a$stand$gradient, a$theta), S) / 3
  r0 <- rr(sprintf("R0_%s_%s", g, cs))
  if (!is.null(r0$stand$elasticity)) out$R0 <- mv_run(r0, S) / 3
  est[[g]] <- out
  tru <- list(R0 = out$R0, meas = if (!is.null(meas) && g %in% names(meas)) meas[[g]] else NULL)
  for (m in intersect(c("B", "A", "R0"), names(out))) for (t in names(tru)) if (!is.null(tru[[t]]) && !(m == "R0" && t == "R0"))
    tab[[length(tab) + 1]] <- data.frame(region = g, est = m, truth = t, t(round(cmp(out[[m]], tru[[t]]), 3)))
  if (!is.null(out$map)) cat(sprintf("%-3s map: ln J e = %+.3f (own %+.3f, field %+.3f)%s\n", g, out$map["lnJ"], out$map["own"], out$map["field"],
    if (!is.null(b)) sprintf("; B sweep %.0f s", b$cpu) else ""))
  for (m in names(out)) if (m != "map") line(paste(g, m), out[[m]])
  if (!is.null(tru$meas)) line(paste(g, "measured"), tru$meas)
}
tab <- do.call(rbind, tab); print(tab, row.names = FALSE)
if (!is.null(S$B$I) && all(c("Ia", "Ib", "Ic") %in% names(S$B))) { s3 <- est$Ia$B + est$Ib$B + est$Ic$B
  cat(sprintf("additivity: |Ia+Ib+Ic - I| rms / rms(I) = %.3f\n", r2((s3 - est$I$B)[-1]) / r2(est$I$B[-1]))) }
h <- rr(sprintf("Sh_%s", cs)); if (!is.null(h$B$I) && !is.null(S$B$I)) {
  dh <- h$B$I$gradient - S$stand$gradient; d1 <- S$B$I$gradient - S$stand$gradient; k <- is.finite(dh) & is.finite(d1) & d1 != 0
  cat(sprintf("linearity: rms(2 x move(c=0.5) - move(c=1)) / rms(move(c=1)) = %.3f (on gradients, relative per trait)\n",
    r2(((2 * dh - d1) / abs(S$stand$gradient))[k]) / r2((d1 / abs(S$stand$gradient))[k]))) }
saveRDS(list(est = est, tab = tab), file.path(SO, sprintf("score_%s.rds", cs)))
