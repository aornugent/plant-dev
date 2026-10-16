# D2's numbers from d2_run.R's outputs: the pinned AD elasticities against the saved
# ones, against central differences of ln J on the same grid at two steps, and the
# grid with step ends at the Determined transitions against the plain one, in eps
# (round4/JT/nudge.R's eps_vec).
# Usage: Rscript d2_score.R <OUTDIR>
suppressMessages(source("/home/user/plant-dev/docs/measurements/schedule-search/round4/AG/lib.R"))
out_dir <- commandArgs(TRUE)[1]
A <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest/adjmap"
TRAITS <- c("lma", "TF24_cost_scale", "stem_c", "a_l1", "root_P50", "a_r1", "R_d_25", "rooting_depth_max")
rd <- function(tag) { f <- file.path(out_dir, sprintf("d2_%s.rds", tag)); if (file.exists(f)) readRDS(f) }
el <- function(x) setNames(unname(x$elasticity), sub("^1\\.", "", names(x$elasticity)))
saved <- readRDS(file.path(A, "runs", "val_ins75_c_long-wet.rds"))$stand
e_saved <- setNames(unname(saved$elasticity), sub("^1\\.", "", names(saved$elasticity)))
plain <- rd("plain_ad"); ends <- rd("ends_ad")
e_plain <- el(plain)
eps <- eps_vec(TRAITS)
cat(sprintf("Pinned replay: J %.15g (saved %.15g, rel %.1e); steps %d identical to the pin %s\n",
            plain$J, saved$J, plain$J / saved$J - 1, plain$steps, plain$times_identical))
d_sv <- e_plain - e_saved[names(e_plain)]
cat(sprintf("Pinned AD vs saved AD over all %d elasticities: max |diff| %.3g (identical: %s)\n",
            length(d_sv), max(abs(d_sv)), identical(unname(e_plain), unname(e_saved[names(e_plain)]))))
cd <- function(prefix, t, d) {
  p <- rd(sprintf("%s_%s_%s_p", prefix, t, d)); m <- rd(sprintf("%s_%s_%s_m", prefix, t, d))
  if (is.null(p) || is.null(m)) return(NA)
  stopifnot(p$times_identical, m$times_identical)
  (p$lnJ - m$lnJ) / (2 * as.numeric(d))
}
tab <- data.frame(trait = TRAITS, eps = eps, ad_saved = e_saved[TRAITS], ad = e_plain[TRAITS],
                  cd3 = vapply(TRAITS, cd, 0, prefix = "cd", d = "1e-3"),
                  cd4 = vapply(TRAITS, cd, 0, prefix = "cd", d = "1e-4"))
tab$ad_cd3_eps <- (tab$ad - tab$cd3) / tab$eps
tab$ad_cd4_eps <- (tab$ad - tab$cd4) / tab$eps
tab$cd3_cd4_eps <- (tab$cd3 - tab$cd4) / tab$eps
if (!is.null(ends)) {
  e_ends <- el(ends)
  tab$ad_ends <- e_ends[TRAITS]
  tab$ends_plain_eps <- (tab$ad_ends - tab$ad) / tab$eps
  tab$cdE3 <- vapply(TRAITS, cd, 0, prefix = "cdE", d = "1e-3")
  tab$adE_cdE3_eps <- (tab$ad_ends - tab$cdE3) / tab$eps
  tab$cdE3_cd3_eps <- (tab$cdE3 - tab$cd3) / tab$eps
}
options(width = 220)
print(tab, digits = 5, row.names = FALSE)
cat(sprintf("\nmax |AD - CD| / eps: delta 1e-3 %.4f, delta 1e-4 %.4f\n",
            max(abs(tab$ad_cd3_eps), na.rm = TRUE), max(abs(tab$ad_cd4_eps), na.rm = TRUE)))
if (!is.null(ends)) {
  q_plain <- c(lnJ = plain$lnJ, e_plain); q_ends <- c(lnJ = ends$lnJ, e_ends)
  k <- names(q_plain)[!names(q_plain) %in% EXCLUDED]
  dall <- (q_ends[k] - q_plain[k]) / eps_vec(k)
  cat(sprintf("ends vs plain: steps %d -> %d, lnJ move %.3g eps; rms over the 8 traits %.4f eps, max %.4f (%s); rms over all %d scored quantities %.4f, max %.4f (%s)\n",
              plain$steps, ends$steps, (ends$lnJ - plain$lnJ) / 0.025,
              sqrt(mean(tab$ends_plain_eps^2)), max(abs(tab$ends_plain_eps)),
              tab$trait[which.max(abs(tab$ends_plain_eps))], length(k), sqrt(mean(dall^2)),
              max(abs(dall)), k[which.max(abs(dall))]))
  cat(sprintf("max |AD - CD| / eps on the ends grid at delta 1e-3: %.4f\n", max(abs(tab$adE_cdE3_eps), na.rm = TRUE)))
  if (!is.null(ends$solved)) {
    ev <- as.data.frame(ends$solved$evals)
    cat(sprintf("ends grid recorded kinds: determined %d, hydraulic-shutdown %d, boundary-root-crit %d; ceiling evaluations %d; census determined %d\n",
                sum(ev$k5), sum(ev$k6), sum(ev$k4), sum(ev$ceiling != 0), ends$operating_points[["determined"]]))
  }
}
saveRDS(tab, file.path(out_dir, "d2_score.rds"))
