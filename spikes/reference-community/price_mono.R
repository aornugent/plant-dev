# Pricing at a monomorphic root (RUN's step STEP, default the last): invaders in
# the root's recorded field over a 3^k grid at +-GRID_H and the axis points
# +-AXIS around x*, split over PARTS processes (each re-records the root).
# An ESS that is global over this grid has every ln R' <= 0.
#   RUN=closed3b STEP=13 Rscript price_mono.R
source("/home/a/dev/plant-dev/.claude/worktrees/agent-a99c78a1743350c42/spikes/reference-community/common.R")
RUN <- Sys.getenv("RUN", "closed3b")
RUN_DIR <- file.path(TMP, "runs", RUN)
steps <- sort(list.files(RUN_DIR, "^step_[0-9]+\\.rds$"))
STEP <- Sys.getenv("STEP")
root <- readRDS(file.path(RUN_DIR, if (nzchar(STEP)) sprintf("step_%03d.rds", as.integer(STEP)) else tail(steps, 1)))
k <- length(EVOLVE)
x <- drop(root$x)
GRID_H <- as.numeric(Sys.getenv("GRID_H", "0.2"))
AXIS <- as.numeric(strsplit(Sys.getenv("AXIS", "0.05,0.1,0.4"), ",")[[1]])
PARTS <- as.integer(Sys.getenv("PARTS", "5"))
grid <- as.matrix(expand.grid(rep(list(c(-GRID_H, 0, GRID_H)), k)))
axis <- do.call(rbind, lapply(seq_len(k), function(j) do.call(rbind, lapply(AXIS, function(a)
  rbind(replace(numeric(k), j, a), replace(numeric(k), j, -a))))))
pts <- unique(rbind(grid, axis))
pts <- sweep(pts, 2, x, "+")
colnames(pts) <- EVOLVE
OUT <- file.path(RUN_DIR, "price")
dir.create(OUT, showWarnings = FALSE)
part <- function(p) {
  f <- file.path(OUT, sprintf("part_%d.rds", p))
  if (file.exists(f)) return(readRDS(f))
  rows <- seq_len(nrow(pts))[(seq_len(nrow(pts)) - 1) %% PARTS == p - 1]
  r <- record(root$lnb, x, scm_out = TRUE)
  inv <- invade(r$scm, pts[rows, , drop = FALSE], grad = FALSE)
  out <- list(rows = rows, lnR = inv$lnR, F = r$F, secs = inv$secs_run)
  saveRDS(out, f)
  out
}
res <- mclapply(seq_len(PARTS), part, mc.cores = PARTS, mc.preschedule = FALSE)
lnR <- numeric(nrow(pts))
for (r in res) lnR[r$rows] <- r$lnR
d <- sweep(pts, 2, x)
out <- list(run = RUN, lnb = root$lnb, x = x, pts = pts, dx = d, lnR = lnR,
            F = sapply(res, `[[`, "F"), secs = sapply(res, `[[`, "secs"))
saveRDS(out, file.path(HERE, sprintf("price_%s.rds", RUN)))
o <- order(-lnR)
cat(sprintf("%d invaders; max ln R' %.5f; resident-trait invader %.2e\n", length(lnR),
            max(lnR), lnR[which(rowSums(abs(d)) == 0)]))
print(cbind(round(d[head(o, 8), ], 3), lnR = signif(lnR[head(o, 8)], 4)))
