# m1_split.R CASE TAG: the region's ln J move (res -> TAG) split into establishment, field and
# interpolation parts (split.R), in eps of ln J, scaled to the region's error as in r1_score.
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/p50/split.R")
a <- commandArgs(TRUE); cs <- a[1]; tg <- a[2]; k <- as.integer(sub("^[A-Za-z]+", "", tg)); fac <- k^2 / (k^2 - 1)
p <- split(rd5(sprintf("cl_res_%s", cs)), rd5(sprintf("p5_%s_%s", tg, cs)))
cat(sprintf("%s %s: region ln J error (x%.3f, eps): total %+.3f = est %+.3f + field %+.3f + interp %+.3f\n", cs, tg, fac, fac * p["total"] / 0.025, fac * p["est"] / 0.025, fac * p["field"] / 0.025, fac * p["interp"] / 0.025))
