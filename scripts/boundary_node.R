# The inflow boundary node's role in the light field, measured on develop.
# M-b1  the amplitude: what share of the field's optical depth is the boundary term
# M-b2  the clamp:     does max(light, 1e-4) bind over [0, height_0], severing
#                      pr_estab's dependence on the field
library(odelia); pkgload::load_all("/home/user/plant-develop", quiet=TRUE)

p <- scm_base_parameters("TF24", "TF24_Env")
p <- add_strategies(p, trait_matrix(0.1978791, "lma"))
p$max_patch_lifetime <- 105.32
scm <- SCM("TF24", "TF24_Env")(p, Environment("TF24"), Control())
scm$collect <- TRUE
scm$run()
hist <- scm$history
cat(sprintf("patch snapshots: %d\n", length(hist)))

FLOOR <- 1e-4
rec <- list(); k <- 0
for (pa in hist) {
  sp <- pa$species[[1]]
  n <- sp$size; if (n < 1) next
  nodes <- sp$nodes; nn <- sp$new_node
  h0    <- nn$height                    # == height_0, the trapezium's lower limit
  hlast <- nodes[[n]]$height            # smallest real cohort
  # a z-grid over the boundary node's whole region of influence, plus the seedling crown
  zs <- sort(unique(c(seq(0, h0, length.out = 25), seq(0, max(hlast, h0), length.out = 25))))
  A  <- vapply(zs, function(z) pa$compute_competition(z), 0)
  # the boundary term is exactly the last trapezium interval of Species::compute_competition
  bt <- vapply(zs, function(z) {
          f1 <- nodes[[n]]$compute_competition(z); f0 <- nn$compute_competition(z)
          if (n == 1 || f1 > 0) (hlast - h0) * (f1 + f0) / 2 else 0 }, 0)
  L  <- exp(-A)
  crown <- zs <= h0
  k <- k + 1
  rec[[k]] <- data.frame(
    step = k, time = pa$time, n_cohorts = n, height_0 = h0, h_smallest = hlast,
    A_at_0 = A[1], L_at_0 = L[1],
    bshare_max = if (any(A > 0)) max(bt / A, na.rm = TRUE) else 0,
    bshare_at_0 = if (A[1] > 0) bt[1] / A[1] else 0,
    L_min_crown = min(L[crown]), L_max_crown = max(L[crown]),
    floor_binds_everywhere = all(L[crown] <= FLOOR),
    floor_binds_somewhere  = any(L[crown] <= FLOOR))
}
d <- do.call(rbind, rec)
saveRDS(d, "/tmp/claude-0/-home-user-plant-dev/64fc9ab7-27f0-5900-8878-48b74c1efc8a/scratchpad/boundary_node.rds")

cat("=== M-b1  boundary-node amplitude, share of the field's optical depth\n")
cat(sprintf("output steps sampled            %d   (times %.3f .. %.3f)\n", nrow(d), min(d$time), max(d$time)))
cat(sprintf("share at z=0      median %.4g   max %.4g\n", median(d$bshare_at_0), max(d$bshare_at_0)))
cat(sprintf("share over [0,h0] median %.4g   max %.4g\n", median(d$bshare_max), max(d$bshare_max)))
cat(sprintf("steps with share > 1%%           %d / %d\n", sum(d$bshare_max > 0.01), nrow(d)))
cat(sprintf("steps with share > 0.1%%         %d / %d\n", sum(d$bshare_max > 0.001), nrow(d)))
cat("\n=== M-b2  does max(light, 1e-4) bind over the seedling crown [0, height_0]\n")
cat(sprintf("height_0                        %.6f m\n", d$height_0[1]))
cat(sprintf("L over crown: min %.3e   max %.3e   (floor %.0e)\n", min(d$L_min_crown), max(d$L_max_crown), FLOOR))
cat(sprintf("binds EVERYWHERE on the crown   %d / %d  (%.1f%%)\n", sum(d$floor_binds_everywhere), nrow(d), 100*mean(d$floor_binds_everywhere)))
cat(sprintf("binds SOMEWHERE on the crown    %d / %d  (%.1f%%)\n", sum(d$floor_binds_somewhere), nrow(d), 100*mean(d$floor_binds_somewhere)))
cat("\n=== trajectory of both, every 10th step\n")
print(d[seq(1, nrow(d), by = 10), c("step","time","n_cohorts","h_smallest","bshare_max","L_min_crown","floor_binds_everywhere")], row.names = FALSE)
