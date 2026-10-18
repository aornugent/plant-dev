# e1_side.R: the same non-smooth part kappa, on stencils that lie wholly inside a spell, by
# distance from the spell's nearest edge: ending within 2h before its closing edge, or
# starting within 2h after its opening edge, against stencils deeper inside (> 2h from both).
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/evidence/layout.R")
E <- readRDS(file.path(SC, "evidence", "e1_corners.rds"))$per
out <- list()
for (cs in unique(E$case)) { p <- pilot_of(cs); ea <- edges_all(cs); op <- ea$b[ea$opening]; cl <- ea$b[!ea$opening]
  for (yy in unique(E$y)) { d <- E[E$case == cs & E$y == yy, ]; h <- median(diff(sort(unique(d$b))))
    side <- vapply(d$b, function(x) { lo <- x - 2 * h; hi <- x + 2 * h
      if (p$shut(x) > 0.5 || x < p$b1) return(NA_character_)
      if (any(c(op, cl) > lo & c(op, cl) < hi)) return(NA_character_)   # stencil crosses an edge
      dc <- min(c(cl[cl >= hi] - hi, Inf)); do <- min(c(lo - op[op <= lo], Inf))
      if (dc < 2 * h) "before_closing" else if (do < 2 * h) "after_opening" else "deep" }, "")
    k <- !is.na(side); bk <- median(d$kap[k & side == "deep"])
    for (s in c("before_closing", "after_opening", "deep")) { z <- d[k & side == s, ]
      out[[length(out) + 1]] <- data.frame(case = cs, y = yy, side = s, n = nrow(z), ratio_d2_d1 = median(abs(z$d2)) / median(abs(z$d1)),
        d1_over_deep = median(abs(z$d1)) / median(abs(d$d1[k & side == "deep"])), kap_over_deep = median(z$kap) / bk) } } }
tab <- do.call(rbind, out); options(width = 200); print(format(tab, digits = 3), row.names = FALSE)
saveRDS(tab, file.path(SC, "evidence", "e1_side.rds"))
