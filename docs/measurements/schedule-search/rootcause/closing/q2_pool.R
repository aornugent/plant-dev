# q2_pool.R: per-recruit fate ln nrr against birth date near dry's closing edges, pooled over
# saved runs whose fields differ by sub-eps errors (lib19 class and libS), so the nodes of many
# schedules sample one curve. Per edge, ln nrr(b) - ln nrr at c - 36 d, binned by days before c.
source("/home/user/plant-dev/docs/measurements/schedule-search/rootcause/closing/lib.R")
cs <- "dry"; nms <- c("val_a09_c_dry", "val_a09_f_dry", "P_in3_dry", "P_in10_dry", "P_out10_dry", "P_mid_dry", "P_midf2_dry", "val_insk_c_dry", "val_insk_f_dry",
  "val_ins75_c_dry", "val_ins75_f_dry", "val_insx_x_dry", "val_insx12_x_dry", "P_insc_dry", "P_insf_dry")
pts <- do.call(rbind, lapply(nms, function(n) { f <- tryCatch(run_file(n), error = function(e) NA); if (is.na(f)) return(NULL); x <- readRDS(f)
  data.frame(run = n, b = x$stand$nodes$birth, lnrr = log(x$stand$nodes$nrr)) }))
cat(sprintf("%d runs, %d points\n", length(unique(pts$run)), nrow(pts)))
et <- edge_table(cs); ce <- et[!et$opening & et$b > PIL[[cs]]$b1 & et$spell > 120, ]
for (i in seq_len(nrow(ce))) { c0 <- ce$b[i]; z <- pts[pts$b > c0 - 80 / 365 & pts$b < c0 + 30 / 365, ]; z$x <- (z$b - c0) * 365; z <- z[order(z$x), ]
  u <- unique(round(z$x, 1)); v <- tapply(z$lnrr, round(z$x, 1), median)
  cat(sprintf("edge %.3f (spell %.0f d, gap %.0f d): %s\n", c0, ce$spell[i], ce$gap[i], paste(sprintf("%+.0f:%.3f", as.numeric(names(v)), v), collapse = " "))) }
