# misread.R CASE CTAG FTAG: per quantity over eps/3, the committed error, the check's,
# the estimate (c - f)/(1 - s), their ratio, and each one's component along M19 (P's
# lib19 in10 move) vs the rest.
source("/home/user/plant-dev/docs/measurements/schedule-search/round4/AG/lib.R")
a <- commandArgs(TRUE); cs <- a[1]; ref <- if (grepl("^AG_", a[2])) ref_ag(cs) else refq(cs); xc <- ag_run(a[2]); xf <- ag_run(a[3])
z <- score_pair(cs, xc, xf, ref); k <- z$k; M <- { p <- quantities(ag_run(sprintf("P_in10_%s", cs))); b <- quantities(rd_run("a09", "c", cs)); (p[k] - b[k]) / eps_vec(k) }
u <- M / sqrt(sum(M^2)); pc <- sum(z$ec * u) * u; pf <- sum(z$ef * u) * u; pe <- sum(z$est * u) * u
big <- pmax(abs(z$ec), abs(z$est)) > 1 / 3
cat(sprintf("%s %s/%s: s %.2f; |M-part| c %.2f f %.2f est %.2f; off-M rms c %.3f f %.3f est %.3f; c/f off-M ratio (rms) %.2f\n", cs, a[2], a[3], z$s, sqrt(sum(pc^2)), sqrt(sum(pf^2)), sqrt(sum(pe^2)), sqrt(mean((z$ec - pc)^2)), sqrt(mean((z$ef - pf)^2)), sqrt(mean((z$est - pe)^2)), sqrt(sum((z$ec - pc)^2) / sum((z$ef - pf)^2))))
d <- data.frame(q = k, c = z$ec, f = z$ef, est = z$est, ratio = z$est / z$ec, c_M = pc, c_off = z$ec - pc, f_M = pf, f_off = z$ef - pf)[big, ]
print(format(d[order(-abs(d$c)), ], digits = 2), row.names = FALSE)
