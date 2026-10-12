source("/home/user/plant-dev/harness/schedule/candidates.R")
cs <- strsplit(Sys.getenv("CASES", "episodic,episodic-lma"), ",")[[1]]
grid <- expand.grid(f = c(16, 32, 64), l = c(70, 35, 17.5))
res <- do.call(rbind, lapply(seq_len(nrow(grid)), function(i) { r <- evaluate(one_point(grid$f[i], grid$l[i]), cs)
  data.frame(alg = sprintf("one(%d,%s)", grid$f[i], format(grid$l[i])), T = r$T, feasible = r$feasible, worst = max(r$table$worst)) }))
lads <- list(diag = list(c(8, 140), c(16, 70), c(32, 35), c(64, 17.5)), late_first = list(c(16, 140), c(16, 70), c(32, 35), c(64, 17.5)),
  f32 = list(c(16, 140), c(32, 70), c(32, 35), c(64, 17.5)))
for (n in names(lads)) { r <- evaluate(ladder(lads[[n]]), cs); res <- rbind(res, data.frame(alg = paste0("ladder_", n), T = r$T, feasible = r$feasible, worst = max(r$table$worst))) }
r <- evaluate(regional(), cs); res <- rbind(res, data.frame(alg = "regional", T = r$T, feasible = r$feasible, worst = max(r$table$worst)))
print(res[order(!res$feasible, res$T), ], digits = 3, row.names = FALSE)
