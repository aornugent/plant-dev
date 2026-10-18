# e1_corners.R: where the per-recruit integrands are not smooth on the references' own
# spacing. Per node of a uniform reference: second differences at h and 2h of y (ln nrr;
# and ln(leaf area x survival) at the run's end) and the non-smooth part
# kappa = |D2h - D2(2h)/4|, classed by the pilot's edges within +-2h.
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/evidence/layout.R")
AR <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/adjmap/runs"
REFS <- list(`flat-al1125` = file.path(SC, "heldout/runs/ref_flat-al1125_u857.rds"),
  `episodic-lma` = file.path(SC, "refine/runs/ref_episodic-lma_u857.rds"),
  `dry-lma125` = file.path(SC, "refine/runs/ref_dry-lma125_u857.rds"),
  `dry-p50` = file.path(AR, "ref_dry-p50_u429.rds"), `wet-hmat125` = file.path(SC, "heldout/runs/ref_wet-hmat125_u429.rds"),
  `ld-105` = file.path(AR, "ref_ld-105_u429.rds"), `epi-adG208` = file.path(SC, "heldout/runs/ref_epi-adG208_u429.rds"))
classify <- function(b, h, ea, b1, shut) {
  op <- ea$b[ea$opening]; cl <- ea$b[!ea$opening]
  vapply(seq_along(b), function(j) { x <- b[j]
    if (any(abs(op - x) <= h / 2)) return("open_centre")
    if (any(abs(op - x) < 2 * h)) return("open_near")
    if (any(abs(cl - x) < 2 * h)) return(if (x < b1 + 2 * h) "b1" else "closing")
    if (x < b1 - 2 * h) return(if (x < 0.25) "founders_start" else "founders")
    if (shut(x) > 0.5) return("gap")
    if (x > 25) "late" else "spell" }, "") }
res <- list(); per <- list()
for (cs in names(REFS)) {
  r <- readRDS(REFS[[cs]])$stand; n <- r$nodes; b <- n$birth; h <- median(diff(b))
  p <- pilot_of(cs); px <- pilot_run(cs); ea <- edges_all(cs, px)
  ys <- list(fate = log(pmax(n$nrr, 1e-300)))
  if (!is.null(n$state)) ys$leaf <- log(n$state["height", ]) / 0.306 - n$state["mortality", ]
  cls <- classify(b, h, ea, p$b1, p$shut); m <- length(b); j <- 3:(m - 2)
  for (nm in names(ys)) { y <- ys[[nm]]
    d1 <- y[j - 1] - 2 * y[j] + y[j + 1]; d2 <- y[j - 2] - 2 * y[j] + y[j + 2]; kap <- abs(d1 - d2 / 4)
    ok <- is.finite(d1) & is.finite(d2) & n$nrr[j] > 1e-12 * max(n$nrr)
    d <- data.frame(case = cs, y = nm, b = b[j], cls = cls[j], d1 = d1, d2 = d2, kap = kap)[ok, ]
    per[[length(per) + 1]] <- d
    base <- median(abs(d$d1[d$cls == "spell"])); bk <- median(d$kap[d$cls == "spell"])
    s <- do.call(rbind, lapply(split(d, d$cls), function(z) data.frame(case = cs, y = nm, h_days = round(h * 365, 1), cls = z$cls[1], n = nrow(z),
      med_abs_d1 = median(abs(z$d1)), ratio_d2_d1 = median(abs(z$d2)) / median(abs(z$d1)), med_kap = median(z$kap),
      kap_over_spell_kap = median(z$kap) / bk, kap_over_spell_d1 = median(z$kap) / base, q90_kap_over_spell_kap = quantile(z$kap, 0.9) / bk)))
    res[[length(res) + 1]] <- s } }
tab <- do.call(rbind, res); options(width = 220); print(format(tab, digits = 3), row.names = FALSE)
saveRDS(list(tab = tab, per = do.call(rbind, per)), file.path(SC, "evidence", "e1_corners.rds"))
