D <- readRDS("tf24_K_40.rds")
r <- function(a, b, w = rep(1, length(a))) sqrt(sum(w * (a - b)^2)) / sqrt(sum(w * a^2))
# The share of J still to be earned, as a smooth step from 1 before t = 13.4 to 0 after 29.3 (ledger: 1%-99% window).
R <- pmin(1, pmax(0, (29.3 - D$t) / (29.3 - 13.4)))
R[D$t < 13.4] <- 1
for (lab in c("t < 29.3", "t < 25", "13.4 < t < 29.3", "t > 29.3")) {
  sel <- switch(lab, "t < 29.3" = D$t < 29.3, "t < 25" = D$t < 25, "13.4 < t < 29.3" = D$t > 13.4 & D$t < 29.3, "t > 29.3" = D$t > 29.3)
  cat(sprintf("%-16s n=%5d  slope %.3f  quartic+end %.3f  stage quartic %.3f\n", lab, sum(sel), r(D$Kd[sel], D$Kslope[sel]), r(D$Kd[sel], D$Ke[sel]), r(D$Kd[sel], D$Ks[sel])))
}
cat(sprintf("weighted by the share of J still to be earned (all n=%d): slope %.3f  quartic+end %.3f  stage quartic %.3f\n", nrow(D),
            r(D$Kd, D$Kslope, R), r(D$Kd, D$Ke, R), r(D$Kd, D$Ks, R)))
cat(sprintf("crossing steps %d of %d (%.1f%%); crossing node-steps %d\n", length(unique(D$t)), 14838, 100 * length(unique(D$t)) / 14838, nrow(D)))
