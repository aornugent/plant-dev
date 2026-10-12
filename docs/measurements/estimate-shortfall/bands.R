# When the missed panel's field part arises: per time band, the light and soil parts
# of P - B (map on B, the panel's two bisection nodes dropped) and of C - P (map on P,
# its middle node dropped), in eps of ln J.
x <- list(B = readRDS("bmapB.rds"), P = readRDS("bmapP.rds"))
br <- c(-Inf, x$B$bands, Inf); lab <- sprintf("[%g, %g)", head(br, -1), br[-1])
f <- function(o, k) rowSums(o[[k]]) / o$stand$J / 0.025
d <- data.frame(band = lab, PB_light = f(x$B, "light"), PB_soil = f(x$B, "soil"), CP_light = f(x$P, "light"), CP_soil = f(x$P, "soil"))
d$ratio_soil <- d$CP_soil / d$PB_soil
print(cbind(d[1], round(d[-1], 4)), row.names = FALSE)
cat(sprintf("totals: P-B light %+.4f soil %+.4f | C-P light %+.4f soil %+.4f\n", sum(d$PB_light), sum(d$PB_soil), sum(d$CP_light), sum(d$CP_soil)))
