# look8.R: in the runs without late knots, which late steps straddle a knot, and do they
# substep the soil?
O <- "/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/schedtest"
suppressMessages(source("/home/user/plant-dev/harness/long_drought.R"))
scen <- "dry, seed 31"; RAIN_SPECS[[scen]] <- modifyList(RAIN_SPECS[["dry"]], list(seed = 31L)); k <- active_knots(scen)
for (n in c("G_out/runs/G_k25_c_dry", "G_out/runs/G_k25w10_c_dry", "G_out/runs/G_w10_c_dry", "adjmap/runs/val_a09_c_dry")) {
  s <- readRDS(file.path(O, paste0(n, ".rds")))$stand; t <- s$times; n1 <- length(t)
  late <- which(t[-n1] >= 25.5); a <- t[late]; b <- t[late + 1]
  nk <- vapply(seq_along(a), function(i) sum(k > a[i] + 1e-9 & k < b[i] - 1e-9), 0)
  sub <- vapply(late + 1, function(i) length(s$substep_ends[[i]]) > 1, TRUE)
  sl <- vapply(late + 1, function(i) any(s$input_slopes[[i]] != 0), TRUE)
  cat(sprintf("%-28s late steps %4d, straddling a knot %.2f (knots inside: mean %.2f), substepped %.2f (straddlers %.2f), median h %.2f d (straddlers %.2f d)\n",
    basename(n), length(a), mean(nk > 0), mean(nk), mean(sub), mean(sub[nk > 0]), median(b - a) * 365, median((b - a)[nk > 0]) * 365)) }
