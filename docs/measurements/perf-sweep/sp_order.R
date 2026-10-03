# Where the light field's prefix form breaks along a recorded forward: at each
# recorded state, are the node heights tallest first (the lumped build's
# condition), and is the newborn no taller than the youngest node (the spread
# build's extra one)? No sweep.
#   PLANT_LIB=... [T=5] [NODES=108] [NOSTOPS=1] [TOL=...] [TOL_ABS=...] OUT=x.rds Rscript sp_order.R
source("/tmp/claude-0/-home-user-plant-dev/4608b090-1484-5285-a934-869426ca2db1/scratchpad/dev/sweep_profile/sp_common.R")
T <- as.numeric(Sys.getenv("T", "5"))
NODES <- as.integer(Sys.getenv("NODES", "108"))
OUT <- Sys.getenv("OUT")
cfg <- config(T, NODES)
cat(lib_tag(), "\n")
cat(sprintf("config: T %g, %d nodes, %d stops, tol %g abs %g\n", cfg$lifetime,
            length(cfg$times), length(cfg$stops), TOL, TOL_ABS))
scm <- build_scm(cfg$times, cfg$lifetime, stops = cfg$stops)
scm$record_trajectory <- TRUE
scm$run()
sp <- scm$patch$species[[1]]
h0 <- sp$new_node$height
per <- length(sp$new_node$ode_names)
env_w <- length(scm$patch$ode_state) - length(sp$ode_state)
rec <- scm$store_trajectory()
o <- do.call(rbind, lapply(rec, function(x) {
  n <- (length(x$state) - env_w) / per
  if (n < 2) return(NULL)
  h <- x$state[per * (seq_len(n) - 1) + 1]
  d <- diff(h)
  data.frame(time = x$time, nodes = n, decreasing = all(d <= 0),
             first_rise = if (any(d > 0)) which(d > 0)[1] else NA_integer_,
             max_rise = max(d), newborn_below = h0 <= h[n], h_last = h[n],
             h_min = min(h), n_near_h0 = sum(abs(h - h0) < 1e-3))
}))
cat(sprintf("J %.9g, %d recorded states with 2+ nodes; seed height %.6f\n",
            sum(scm$offspring_production), nrow(o), h0))
cat(sprintf("heights tallest first at %.2f%%; newborn below the youngest at %.2f%%; both at %.2f%%\n",
            100 * mean(o$decreasing), 100 * mean(o$newborn_below),
            100 * mean(o$decreasing & o$newborn_below)))
bad <- o[!(o$decreasing & o$newborn_below), ]
if (nrow(bad)) {
  cat(sprintf("broken from t = %.4f to %.4f; nodes %d..%d; first rise at node %s; largest rise %.3g m; youngest height %.6f..%.6f; nodes within 1 mm of the seed height %d..%d\n",
              min(bad$time), max(bad$time), min(bad$nodes), max(bad$nodes),
              paste(unique(head(bad$first_rise, 5)), collapse = ","), max(bad$max_rise),
              min(bad$h_last), max(bad$h_last), min(bad$n_near_h0), max(bad$n_near_h0)))
}
if (nzchar(OUT)) saveRDS(list(config = cfg, h0 = h0, order = o), OUT)
cat("SPORDER DONE\n")
