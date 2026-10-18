# r5_width.R: the width and height of the curvature rise before each shutting, per zone and per
# case, against three candidates: t_r = o ln(a_st3 a_dG2) from the parameters, t_e (days from c
# until the cohort born at c reaches r = 1/a_dG2, traj map), and L (the drought after c).
# Profiles: G s for root_P50 (dry, long-wet maps), for the storage offset (dry twin), and G
# (ln J's integrand) on the maps and on the res runs (dry, dry-p50, dry-flat, long-wet).
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/closing/lib.R")
Sys.setenv(PLANT_LIB = file.path(dirname(ADJ), "libS")); suppressMessages(library(plant, lib.loc = Sys.getenv("PLANT_LIB")))
wb <- Weibull_Disturbance_Regime(40); dens <- function(t) vapply(t, wb$density, 0)
EV <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/evidence"
W <- 117 / 365; tr0 <- 7 * log(0.8 * 20)
# g profile from |second differences| by days before c (3-d bins), relative to the 30-60 d median
gprof <- function(d, k2, far = c(30, 60)) { ref <- median(k2[d >= far[1] & d <= far[2]]); r <- k2 / ref
  t <- tapply(r, round(d / 3) * 3, median); dk <- as.numeric(names(t)); o <- order(dk); data.frame(d = dk[o], kappa = stats::runmed(as.numeric(t[o]), 3)) }
widths <- function(P) { g <- pmax(1, P$kappa)^(1 / 3); gmax <- max(g[P$d <= 21]); half <- (1 + gmax) / 2
  lastd <- function(th) { k <- which(g >= th & P$d <= 45); if (!length(k)) return(NA); j <- max(k); if (j < nrow(P) && P$d[j + 1] <= 45)
    P$d[j] + (P$d[j + 1] - P$d[j]) * (g[j] - th) / (g[j] - g[j + 1]) else P$d[j] }
  c(W_half = lastd(half), W_on = lastd(1.08), g_max = gmax) }
zones_of <- function(cs, b, ok) { et <- edge_table(cs); b1 <- PIL[[cs]]$b1; ce <- et[!et$opening & et$b > b1 & et$spell > 60, ]; out <- list()
  for (i in seq_len(nrow(ce))) { c0 <- ce$b[i]; k3 <- which(b >= c0 - W - 1e-9 & b <= c0 + 1e-9); if (length(k3) < 30) next
    if (max(diff(c(c0 - W, b[k3], c0))) > 3.5 / 365 || !all(ok[k3])) next; out[[length(out) + 1]] <- list(c0 = c0, k3 = k3, L = ce$gap[i], spell = ce$spell[i]) }
  out }
PZ <- list(); MED <- list()
for (cs in c("dry", "long-wet")) { a <- rd(sprintf("cl_map_%s", cs)); pp <- rd(sprintf("cl_mapp_%s", cs)); b <- a$stand$nodes$birth
  G <- dens(b) * a$stand$nodes$nrr; Y <- list(lnJ = G, root_P50 = G * (log(pp$stand$nodes$nrr) - log(a$stand$nodes$nrr)) / log(1.02))
  if (cs == "dry") { tw <- readRDS(file.path(EV, "runs", "twin_sro_dry.rds")); Y$storage_offset <- G * (log(tw$nrr) - log(a$stand$nodes$nrr)) / log(1.02) }
  ok <- Reduce(`&`, lapply(Y, is.finite)); Z <- zones_of(cs, b, ok)
  for (q in names(Y)) { pooled <- list()
    for (z in Z) { k <- z$k3; d <- (z$c0 - b[k]) * 365; k2 <- abs(diff(Y[[q]][k], differences = 2)); dd <- d[2:(length(d) - 1)]
      P <- gprof(dd, k2); w <- widths(P); PZ[[length(PZ) + 1]] <- data.frame(case = cs, q = q, c0 = z$c0, L = z$L, spell = z$spell, t(w))
      ref <- median(k2[dd >= 30 & dd <= 60]); pooled[[length(pooled) + 1]] <- data.frame(d = round(dd / 3) * 3, r = k2 / ref) }
    pr <- do.call(rbind, pooled); t <- tapply(pr$r, pr$d, median); dk <- as.numeric(names(t)); o <- order(dk)
    P <- data.frame(d = dk[o], kappa = stats::runmed(as.numeric(t[o]), 3)); MED[[paste(cs, q)]] <- data.frame(case = cs, q = q, zones = length(Z), t(widths(P))) } }
PZ <- do.call(rbind, PZ); MED <- do.call(rbind, MED)
cat("median profiles: width and height\n"); print(format(MED, digits = 3), row.names = FALSE)
cat("\nper zone (root_P50, storage offset): spread and rank correlation with the drought length L and the spell\n")
for (q in c("root_P50", "storage_offset", "lnJ")) { z <- PZ[PZ$q == q, ]
  cat(sprintf("%-15s n %2d | W_half median %.1f IQR %.1f-%.1f | g_max median %.2f | rho(W_half, L) %+.2f rho(g_max, L) %+.2f | rho(W_half, spell) %+.2f\n", q, nrow(z),
    median(z$W_half, na.rm = TRUE), quantile(z$W_half, 0.25, na.rm = TRUE), quantile(z$W_half, 0.75, na.rm = TRUE), median(z$g_max),
    cor(z$W_half, z$L, method = "spearman", use = "complete.obs"), cor(z$g_max, z$L, method = "spearman"), cor(z$W_half, z$spell, method = "spearman", use = "complete.obs"))) }
z <- PZ[PZ$q == "root_P50", ]; for (cs in unique(z$case)) { y <- z[z$case == cs, ]
  cat(sprintf("  root_P50 %-8s rho(W_half, L) %+.2f rho(g_max, L) %+.2f | short gaps (< 20 d): W_half %.1f g_max %.2f (n %d) | long gaps (>= 30 d): W_half %.1f g_max %.2f (n %d)\n", cs,
    cor(y$W_half, y$L, method = "spearman", use = "complete.obs"), cor(y$g_max, y$L, method = "spearman"), median(y$W_half[y$L < 20], na.rm = TRUE), median(y$g_max[y$L < 20]), sum(y$L < 20),
    median(y$W_half[y$L >= 30], na.rm = TRUE), median(y$g_max[y$L >= 30]), sum(y$L >= 30))) }
rP <- PZ[PZ$q == "root_P50", ]; cat(sprintf("pooled root_P50: rho(W_half, L) %+.2f, rho(g_max, L) %+.2f\n", cor(rP$W_half, rP$L, method = "spearman", use = "complete.obs"), cor(rP$g_max, rP$L, method = "spearman")))
# t_e from the traj map (dry): hazard h = dm/dtau - d_I, r = -ln(h / a_dG1) / a_dG2
x <- readRDS(file.path(CL, "runs", "traj_map_dry.rds")); et <- edge_table("dry"); TE <- list()
for (kk in names(x$per_edge)) { e <- x$per_edge[[kk]]; c0 <- as.numeric(kk); L <- et$gap[which.min(abs(et$b - c0))]
  for (off in c(-36, -21, -12, -3, 0)) { j <- which(abs(e$birth - (c0 + off / 365)) < 0.6 / 365); if (!length(j)) next; j <- j[1]
    m <- e$mortality[, j]; tau <- x$tau; h <- diff(m) / diff(tau) - 0.01; tm <- tau[-1]; r <- ifelse(h > 0, -log(pmin(h, 5.5) / 5.5) / 20, NA)
    cal <- (e$birth[j] + tm - c0) * 365   # days after c
    first <- function(th) { k <- which(r <= th & cal > -40); if (length(k)) cal[k[1]] else NA }
    TE[[length(TE) + 1]] <- data.frame(edge = c0, L = L, born = off, r_at_c = r[which.min(abs(cal))], t_r03 = first(0.3), t_r015 = first(0.15), t_e = first(0.05)) } }
TE <- do.call(rbind, TE); cat("\ntraj map (dry): days after c at which the cohort's r falls to 0.3, 0.15, 1/a_dG2 = 0.05\n"); print(format(TE, digits = 3), row.names = FALSE)
# res runs: G's curvature on the res grid (non-uniform second divided differences), relative to that at 28 d
RES <- list()
for (cs in c("dry", "dry-p50", "dry-flat", "long-wet")) { a <- rd(sprintf("cl_res_%s", cs)); b <- a$stand$nodes$birth; G <- dens(b) * a$stand$nodes$nrr
  et <- edge_table(cs); b1 <- PIL[[cs]]$b1; ce <- et[!et$opening & et$b > b1 & et$b < 25 & et$spell > 60, ]; prof <- list()
  for (i in seq_len(nrow(ce))) { c0 <- ce$b[i]; off <- c(36, 28, 21, 15.5, 11, 7.5, 4.5, 2, 0); j <- vapply(off, function(o) { k <- which(abs(b - (c0 - o / 365)) < 0.05 / 365); if (length(k)) k[1] else NA_integer_ }, 1L)
    if (anyNA(j)) next; x1 <- b[j]; y <- G[j]; h1 <- diff(x1)[-length(off) + 1]; h2 <- diff(x1)[-1]
    c2 <- abs(2 * ((y[3:9] - y[2:8]) / h2 - (y[2:8] - y[1:7]) / h1) / (h1 + h2)); prof[[length(prof) + 1]] <- c2 / c2[1] }
  if (!length(prof)) next; M <- do.call(rbind, prof); med <- apply(M, 2, median); P <- data.frame(d = off[2:8], kappa = med)[order(off[2:8]), ]
  g <- pmax(1, P$kappa)^(1 / 3); gmax <- max(g); half <- (1 + gmax) / 2; k <- max(which(g >= half)); wh <- if (k < nrow(P)) P$d[k] + (P$d[k + 1] - P$d[k]) * (g[k] - half) / (g[k] - g[k + 1]) else P$d[k]
  RES[[cs]] <- data.frame(case = cs, zones = nrow(M), t(setNames(round(med, 2), paste0("k", off[2:8]))), g_max = gmax, W_half = wh) }
RES <- do.call(rbind, RES); cat("\nres runs: G's curvature relative to 28 d (median over long-spell zones)\n"); print(format(RES, digits = 3), row.names = FALSE)
cat(sprintf("\nt_r = 7 ln(0.8 x 20) = %.1f d; epi-adG208 (a_dG2 16): %.1f d\n", tr0, 7 * log(0.8 * 16)))
saveRDS(list(PZ = PZ, MED = MED, TE = TE, RES = RES), file.path(EV, "r5_width.rds"))
