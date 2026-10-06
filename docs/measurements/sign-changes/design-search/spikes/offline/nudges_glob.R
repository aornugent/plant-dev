# As nudges.R, for the refinement kept in the mesh (glob m): each nudged mesh is
# refined at theta0, and every replay (the gradient's and the curvatures' at
# theta0 e^{+-r}) runs plain on the refined mesh.
# Usage: Rscript nudges_glob.R <base_tol> <out.rds>
args <- commandArgs(TRUE)
base_tol <- as.numeric(args[1]); out_file <- args[2]
source("toy.R")
th0 <- 1; d <- 1e-6
tols <- base_tol * c(0.95, 0.9667, 0.9833, 1, 1.0167, 1.0333, 1.05)
rs <- c(3e-3, 1e-2, 3e-2)
lnJ <- function(mesh, th) log(replay(mesh, th, "plain")$J)
res <- list()
for (k in seq_along(tols)) {
  mesh0 <- adaptive_mesh(tols[k], th0)
  for (m in c(2L, 3L)) {
    mesh <- refine_mesh(mesh0, th0, m)
    b <- lnJ(mesh, th0)
    g <- (lnJ(mesh, th0 * exp(d)) - lnJ(mesh, th0 * exp(-d))) / (2 * d)
    curv <- vapply(rs, function(r) (lnJ(mesh, th0 * exp(r)) - 2 * b + lnJ(mesh, th0 * exp(-r))) / r^2, 0)
    res[[length(res) + 1]] <- data.frame(tol = tols[k], arm = paste0("glob", m),
      steps = length(mesh0$sizes), refined = mesh$refined, lnJ = b, grad = g,
      c3e3 = curv[1], c1e2 = curv[2], c3e2 = curv[3])
    cat(sprintf("tol %.4g glob%d steps %d refined %d lnJ %.10f grad %.6f curv %.3f %.3f %.3f\n",
                tols[k], m, length(mesh0$sizes), mesh$refined, b, g, curv[1], curv[2], curv[3]))
  }
}
saveRDS(do.call(rbind, res), out_file)
