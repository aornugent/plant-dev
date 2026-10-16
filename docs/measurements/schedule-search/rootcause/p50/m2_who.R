# m2_who.R CASE TAG: whose fates carry the region's field part: W~ (nrr_coarse - nrr_fine) summed
# by the cohort's birth region (founders < b1, b1-10, 10-17, 17-25, > 25), eps of ln J, scaled.
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/p50/split.R")
a <- commandArgs(TRUE); cs <- a[1]; tg <- a[2]; k <- as.integer(sub("^[A-Za-z]+", "", tg)); fac <- k^2 / (k^2 - 1)
co <- rd5(sprintf("cl_res_%s", cs)); fi <- rd5(sprintf("p5_%s_%s", tg, cs)); c0 <- nodes(co); f <- nodes(fi)
kc <- match(round(c0$b, 8), round(f$b, 8)); W <- hatw(c0$b, f$b, f$w); A <- sum(f$w * f$g); b1 <- PIL[[cs]]$b1
d <- W * (c0$g - f$g[kc]) / A * fac / 0.025; grp <- cut(c0$b, c(-1, b1, 10, 17, 25, 99), labels = c("founders", "b1-10", "10-17", "17-25", ">25"))
share <- tapply(W * c0$g, grp, sum) / sum(W * c0$g)
print(rbind(field_eps = round(tapply(d, grp, sum), 3), share_of_J = round(share, 3)))
dl <- log(c0$g) - log(f$g[kc]); cat("median d ln nrr (coarse - fine) by group:", paste(sprintf("%s %+.4f", levels(grp), tapply(dl, grp, median)), collapse = ", "), "\n")
