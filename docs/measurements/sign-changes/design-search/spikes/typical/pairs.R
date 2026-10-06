# The 14 pairs at r = 0: where, how wide, at which knots, and their steps.
D <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev"
sp <- readRDS("census.rds")
f <- readRDS(file.path(D, "p21/final2/split_1.rds"))
knots <- sort(unique(f$knots))
pr <- sp[sp$n == 2, ]
near_knot <- function(t) { d <- min(abs(knots - t)); d * 365 }
pr$start_knot_days <- vapply(pr$t, near_knot, 0)
pr$day <- round(pr$t * 365, 2); pr$h_days <- signif(pr$h * 365, 3); pr$node <- pr$p + 1
print(pr[, c("day", "h_days", "node", "share", "u1", "u2", "v0", "v1", "start_knot_days")], row.names = FALSE, digits = 4)
cat("knots on record:", length(knots), "; range of knot spacing (days):", signif(range(diff(knots)) * 365, 3), "\n")
# Steps starting at a knot: how many node steps do they hold?
tt <- f$stand$times; hh <- f$stand$sizes
st <- tt - hh
at_knot <- vapply(st, function(s) min(abs(knots - s)) < 1e-9, TRUE)
cat("steps starting at a knot:", sum(at_knot), "of", length(st), "\n")
# fraction of single cuts in steps starting at a knot
one <- sp$n == 1
sk <- vapply(sp$t, function(s) min(abs(knots - s)) < 1e-9, TRUE)
cat("single cuts in steps starting at a knot:", sum(sk & one), "; pairs in such steps:", sum(sk & !one), "\n")
