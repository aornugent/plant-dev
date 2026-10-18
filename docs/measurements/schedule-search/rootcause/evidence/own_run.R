# own_run.R: guard, then layout D's own part, its drop's estimate, scaling, and the split
# by panel kind (fewer than two interior nodes; intervals the drop never merges).
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/evidence/own_model.R")
res <- list(); pan <- list()
for (cs in names(REFS)) { M <- model_of(cs)
  # guard: exact nested own part of the every-other subset from stored weights
  F <- dens(M$b) * M$nrr; sub <- M$b[seq(1, length(M$b), by = 2)]
  hatw <- function(bc, bf, wf) { W <- numeric(length(bc)); j <- findInterval(bf, bc, rightmost.closed = TRUE); j[j < 1] <- 1; j[j >= length(bc)] <- length(bc) - 1
    t <- pmin(pmax((bf - bc[j]) / (bc[j + 1] - bc[j]), 0), 1); for (f in seq_along(bf)) { W[j[f]] <- W[j[f]] + wf[f] * (1 - t[f]); W[j[f] + 1] <- W[j[f] + 1] + wf[f] * t[f] }; W }
  kc <- match(round(sub, 8), round(M$b, 8)); ex <- log(sum(hatw(sub, M$b, M$w) * F[kc]) / sum(M$w * F)) / u
  mo <- (log(Q_of(M, sub)) - log(Q_of(M, M$b))) / u
  D <- readRDS(file.path(SC, "evidence", sprintf("layoutD_%s.rds", cs)))
  p <- pilot_of(cs); px <- pilot_run(cs); h <- alg$hfun_of(p)
  D2 <- layout_D(cs, 2, p, px, h); D4 <- layout_D(cs, 4, p, px, h); D8 <- layout_D(cs, 8, p, px, h)
  e1 <- own(M, D$S); e2 <- own(M, D2$S); e4 <- own(M, D4$S); e8 <- own(M, D8$S)
  dropS <- setdiff(round(D$S, 10), D$drop); est <- (own(M, dropS) - e1) / 3
  est2 <- (own(M, setdiff(round(D2$S, 10), D2$drop)) - e2) / 3
  # by panel of D
  oi <- own_by_interval(M, D$S); oi$panel <- findInterval(oi$lo, D$breaks); P <- D$panels; P$own <- tapply(oi$err, factor(oi$panel, levels = seq_len(nrow(P))), sum, default = 0)
  # intervals the drop never merges: the last interval of each panel with an even interior count
  unm <- vapply(seq_len(nrow(P)), function(k) { x <- D$member[[k]]; if (length(x) == 0 || length(x) %% 2 == 1) return(0)
    oi$err[which.min(abs(oi$lo - max(x)))] }, 0)
  lt2 <- P$n_interior < 2
  res[[cs]] <- data.frame(case = cs, J_model_over_ref = NA, guard_exact = ex, guard_model = mo, own_D = e1, est_drop = est, read = est / e1,
    own_2rho = e2, read_2rho = est2 / e2, ratio_1_2 = e1 / e2, ratio_2_4 = e2 / e4, ratio_4_8 = e4 / e8,
    abs_share_lt2 = sum(abs(P$own[lt2])) / sum(abs(P$own)), signed_lt2 = sum(P$own[lt2]), abs_share_unmerged = sum(abs(unm)) / sum(abs(P$own)), signed_unmerged = sum(unm),
    founders_panel = P$own[1], rest = sum(P$own[-1]))
  P$case <- cs; P$unmerged <- unm; pan[[cs]] <- P }
tab <- do.call(rbind, res); options(width = 220); print(format(tab, digits = 3), row.names = FALSE)
saveRDS(list(tab = tab, panels = pan), file.path(SC, "evidence", "own_run.rds"))
