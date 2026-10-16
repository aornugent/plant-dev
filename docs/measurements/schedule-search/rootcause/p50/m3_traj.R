# m3_traj.R CASE: from the fine run's trajectory (traj_I4), the interior cohorts' survival-
# weighted leaf area (proxy (h/a_l1)^(1/a_l2) * exp(-mortality), per recruit), and how res's
# coarse hats over-count it: at each time, sum_c W~_c x(b_c, t) - sum_f w_f x(b_f, t), with W~
# the coarse hats in the fine basis (split.R), as a share of the stand's founders' leaf area.
# Also the curvature of ln x in birth date inside the interiors, and the soil's top layer.
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/p50/split.R")
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/p50/mk_reg.R", local = TRUE)
cs <- commandArgs(TRUE)[1]; x <- rd5(sprintf("traj_I4_%s", cs)); tr <- x$traj; f <- nodes(x)
R <- regions(cs); lab_iv <- R$lab; Sres <- R$S
fi <- match(round(tr$birth, 8), round(f$b, 8)); w <- f$w[fi]; b <- tr$birth
a_l2 <- 0.306; la <- (tr$height)^(1 / a_l2) * exp(-tr$mortality)  # rows: time, cols: cohorts in [3.5, 25)
# interior cohorts: fine nodes lying inside an interior interval of res (endpoints included)
iv <- which(lab_iv %in% c("Ia", "Ib", "Ic")); inI <- sapply(b, function(z) any(z >= R$lo[iv] - 1e-9 & z <= R$hi[iv] + 1e-9))
bc <- Sres[Sres >= 3.5 & Sres < 25]; inC <- round(b, 8) %in% round(bc, 8)
cat(sprintf("%s: %d cohorts in [3.5, 25) kept, %d inside interiors, %d of them res nodes\n", cs, length(b), sum(inI), sum(inI & inC)))
# over-count per interior interval, summed: for each res interior interval [lo, hi], the hat
# reading of x at its two ends against the fine quadrature of the nodes inside.
over <- sapply(seq_along(tr$time), function(i) { v <- la[i, ]; s <- 0; s_f <- 0
  for (j in iv) { k <- which(b >= R$lo[j] - 1e-9 & b <= R$hi[j] + 1e-9); if (length(k) < 3) next
    bb <- b[k]; vv <- v[k]; ww <- w[k]; ww[1] <- ww[1] / 2; ww[length(ww)] <- ww[length(ww)] / 2  # end nodes shared with the neighbours: half of each
    lin <- vv[1] + (vv[length(vv)] - vv[1]) * (bb - bb[1]) / (bb[length(bb)] - bb[1])
    s <- s + sum(ww * (lin - vv), na.rm = TRUE); s_f <- s_f + sum(ww * vv, na.rm = TRUE) }
  c(over = s, interior = s_f) })
df <- data.frame(yr = floor(tr$time), ov = over["over", ], int = over["interior", ], top = tr$soil[, 1])[tr$time >= 4, ]
tab <- aggregate(. ~ yr, data = df, FUN = mean)
tab$rel <- tab$ov / tab$int
print(format(tab, digits = 3), row.names = FALSE)
# shape: second differences of ln x across birth inside each interior interval at t = b + 1 y and b + 3 y
