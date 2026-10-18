# r5_sro2.R: G's rise before each shutting on dry's fate map, at the storage offset's value
# and doubled (twin.R run map_sro2_dry), far window 60-100 d, g_max within 42 d, W read to 80 d.
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/closing/lib.R")
Sys.setenv(PLANT_LIB = file.path(dirname(ADJ), "libS")); suppressMessages(library(plant, lib.loc = Sys.getenv("PLANT_LIB")))
wb <- Weibull_Disturbance_Regime(40); dens <- function(t) vapply(t, wb$density, 0)
EV <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/deep/rootcause/evidence"
a <- rd("cl_map_dry"); x2 <- readRDS(file.path(EV, "r5", "map_sro2_dry.rds")); b <- a$stand$nodes$birth; stopifnot(max(abs(b - x2$birth)) < 1e-12)
Y <- list(base = dens(b) * a$stand$nodes$nrr, offset_x2 = dens(b) * x2$nrr); W <- 117 / 365
et <- edge_table("dry"); b1 <- PIL[["dry"]]$b1; ce <- et[!et$opening & et$b > b1 & et$spell > 60, ]
width <- function(d, kap, gwin, wmax) { g <- pmax(1, kap)^(1 / 3); gmax <- max(g[d <= gwin]); half <- (1 + gmax) / 2
  k <- which(g >= half & d <= wmax); j <- max(k); wh <- if (j < length(d)) d[j] + (d[j + 1] - d[j]) * (g[j] - half) / (g[j] - g[j + 1]) else d[j]
  k <- which(g >= 1.08 & d <= wmax); won <- if (length(k)) d[max(k)] else NA; c(W_half = wh, W_on = won, g_max = gmax) }
out <- list(); prof <- list()
for (far in list(c(30, 60), c(60, 100))) for (q in names(Y)) { pooled <- list(); pz <- list()
  for (c0 in ce$b) { k <- which(b >= c0 - W - 1e-9 & b <= c0 + 1e-9); if (length(k) < 30 || max(diff(c(c0 - W, b[k], c0))) > 3.5 / 365 || !all(is.finite(Y[[q]][k]))) next
    d <- (c0 - b[k]) * 365; k2 <- abs(diff(Y[[q]][k], differences = 2)); dd <- d[2:(length(d) - 1)]; r <- k2 / median(k2[dd >= far[1] & dd <= far[2]])
    pooled[[length(pooled) + 1]] <- data.frame(d = round(dd / 3) * 3, r = r)
    t <- tapply(r, round(dd / 3) * 3, median); dk <- as.numeric(names(t)); o <- order(dk); pz[[length(pz) + 1]] <- width(dk[o], stats::runmed(as.numeric(t[o]), 3), 42, 80) }
  pr <- do.call(rbind, pooled); t <- tapply(pr$r, pr$d, median); dk <- as.numeric(names(t)); o <- order(dk); kap <- stats::runmed(as.numeric(t[o]), 3)
  prof[[paste(q, far[1])]] <- data.frame(q = q, far = far[1], d = dk[o], kappa = kap); pz <- do.call(rbind, pz)
  out[[paste(q, far[1])]] <- data.frame(q = q, far = paste(far, collapse = "-"), zones = length(pooled), t(width(dk[o], kap, 42, 80)), zone_W_half_median = median(pz[, 1]), zone_W_half_IQR = paste(round(quantile(pz[, 1], c(.25, .75)), 1), collapse = "-")) }
tab <- do.call(rbind, out); print(format(tab, digits = 3), row.names = FALSE)
P <- do.call(rbind, prof); P <- P[P$far == 60 & P$d <= 60, ]; print(reshape(P[, c("q", "d", "kappa")], idvar = "d", timevar = "q", direction = "wide"), row.names = FALSE, digits = 3)
cat(sprintf("J base %.6g, offset x2 %.6g\n", a$stand$J, x2$J))
saveRDS(list(tab = tab, prof = do.call(rbind, prof)), file.path(EV, "r5", "r5_sro2.rds"))
