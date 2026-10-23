# Central differences of ln R' in strategy parameters, to check the AD
# elasticities of ad.R: each set of parameters is scaled jointly by 1 +- d on
# the invader alone (after add_mutant, so no hyperparameter recomputes them).
#
#   CASE=closed ROWS=1,2 D=1e-5 TAG=closed Rscript fd_pars.R
source("/home/a/dev/plant-dev/.claude/worktrees/agent-a3c3295eb8ad97b06/spikes/break-even/stand.R")
ROWS <- as.integer(strsplit(Sys.getenv("ROWS", "1,2"), ",")[[1]])
D <- as.numeric(Sys.getenv("D", "1e-5"))
TAG <- Sys.getenv("TAG", CASE)
SETS <- list(a_y = "a_y", r_l = "r_l", ay_r = c("a_y", "r_l", "r_b", "r_s", "r_r"))
grid <- expand.grid(sign = c(1, -1), set = names(SETS), row = ROWS,
                    stringsAsFactors = FALSE)
grid <- rbind(data.frame(sign = 0, set = "none", row = ROWS), grid)
m <- variant_traits(grid$row)
scm <- run_resident()
q <- add_mutant(scm$parameters, m, birth_rate = rep(1, nrow(m)))
for (i in seq_len(nrow(grid))) if (grid$set[i] != "none") {
  for (n in SETS[[grid$set[i]]]) {
    q$strategies[[i]]$pars[[n]] <- q$strategies[[i]]$pars[[n]] * (1 + grid$sign[i] * D)
  }
}
q$node_schedule_times <- rep(list(TIMES_INV), nrow(m))
scm$run_mutant(q)
grid$lnR <- log(scm$net_reproduction_ratios)
out <- do.call(rbind, lapply(ROWS, function(r) do.call(rbind, lapply(names(SETS), function(s) {
  g <- grid[grid$row == r & grid$set == s, ]
  data.frame(row = r, set = s,
             elasticity = (g$lnR[g$sign == 1] - g$lnR[g$sign == -1]) / (2 * D))
}))))
print(grid, digits = 10)
print(out)
saveRDS(list(grid = grid, out = out, D = D), file.path(OUTDIR, paste0("fdpars_", TAG, ".rds")))
