source("/home/user/plant-dev/harness/schedule/candidates.R")
cs <- strsplit(Sys.getenv("CASES", "episodic,episodic-lma"), ",")[[1]]
cands <- list(ladder_f32 = ladder(list(c(16, 140), c(32, 70), c(32, 35), c(64, 17.5))), one_32_35 = one_point(32, 35))
for (st in list(c(16, 70), c(32, 70), c(16, 35), c(32, 35))) for (sh in c(0.3, 0.5, 0.7))
  cands[[sprintf("cr(%d,%s,%.1f)", st[1], format(st[2]), sh)]] <- coarsen_regional(st[1], st[2], sh)
cands[["pilot_led"]] <- pilot_led()
res <- do.call(rbind, lapply(names(cands), function(n) { r <- evaluate(cands[[n]], cs)
  data.frame(alg = n, T = r$T, feasible = r$feasible, worst = max(r$table$worst), paths = paste(r$table$path, collapse = " | ")) }))
print(res[order(!res$feasible, res$T), ], digits = 3, row.names = FALSE, right = FALSE)
