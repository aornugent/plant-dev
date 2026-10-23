# Per-cohort decomposition of a scan: each cohort's share of R' at eps = 0 and
# its d ln R_c / d eps from the +-EPS pair.
#   Rscript cohorts.R scan_closed_r1.rds 1e-5
a <- commandArgs(TRUE)
r <- readRDS(file.path("/home/a/.claude/jobs/9d586e52/tmp/breakeven", a[1]))
e <- as.numeric(if (length(a) > 1) a[2] else "1e-5")
i0 <- which(r$eps == 0)[1]
ip <- which(r$eps == e)[1]; im <- which(r$eps == -e)[1]
c0 <- r$cohorts[[i0]]
contrib <- function(c) c$w * c$pd * c$R_c
tot <- sum(contrib(c0))
cat(sprintf("exp(lnR) %.6g  sum w pd R_c %.6g  sum w R_c %.6g\n",
            exp(r$lnR[i0]), tot, sum(c0$w * c0$R_c)))
d <- data.frame(t = c0$t, share = contrib(c0) / tot,
                dlnRc = (log(r$cohorts[[ip]]$R_c) - log(r$cohorts[[im]]$R_c)) / (2 * e),
                dRc_rel = (contrib(r$cohorts[[ip]]) - contrib(r$cohorts[[im]])) / (2 * e * tot),
                height = c0$height, H = c0$mortality, storage = c0$storage)
print(d, digits = 4)
cat(sprintf("sum of dR_c/R': %.4g   (d lnR' from the scan: %.4g)\n",
            sum(d$dRc_rel), (r$lnR[ip] - r$lnR[im]) / (2 * e)))
