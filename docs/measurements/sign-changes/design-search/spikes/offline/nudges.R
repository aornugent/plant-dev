# Gradient d ln J / d ln theta on each of seven meshes (tol within 5% of the
# base, as R1's nudges), per treatment; and second differences of ln J at r.
# Usage: Rscript nudges.R <base_tol> <out.rds>
args <- commandArgs(TRUE)
base_tol <- as.numeric(args[1])
out_file <- args[2]
source("toy.R")
th0 <- 1
d <- 1e-6
tols <- base_tol * c(0.95, 0.9667, 0.9833, 1, 1.0167, 1.0333, 1.05)
arms <- list(plain = list("plain", 1), sub2 = list("sub", 2), sub3 = list("sub", 3),
             sub4 = list("sub", 4), sub8 = list("sub", 8), cut = list("cut", 1),
             glob2 = list("glob", 2), glob3 = list("glob", 3))
only <- Sys.getenv("ARMS")
if (nzchar(only)) arms <- arms[strsplit(only, ",")[[1]]]
rs <- c(3e-3, 1e-2, 3e-2)
# The refinement kept in the mesh (glob m) replays plain on the refined mesh.
lnJ <- function(mesh, th, a) {
  log(replay(mesh, th, if (a[[1]] == "glob") "plain" else a[[1]], a[[2]])$J)
}
res <- list()
for (k in seq_along(tols)) {
  mesh0 <- adaptive_mesh(tols[k], th0)
  for (an in names(arms)) {
    a <- arms[[an]]
    mesh <- if (a[[1]] == "glob") refine_mesh(mesh0, th0, a[[2]]) else mesh0
    base <- replay(mesh, th0, if (a[[1]] == "glob") "plain" else a[[1]], a[[2]])
    if (a[[1]] == "glob") base$treated <- mesh$refined
    g <- (lnJ(mesh, th0 * exp(d), a) - lnJ(mesh, th0 * exp(-d), a)) / (2 * d)
    curv <- vapply(rs, function(r)
      (lnJ(mesh, th0 * exp(r), a) - 2 * log(base$J) + lnJ(mesh, th0 * exp(-r), a)) / r^2, 0)
    res[[length(res) + 1]] <- data.frame(tol = tols[k], arm = an, steps = length(mesh$sizes),
                                         lnJ = log(base$J), grad = g,
                                         c3e3 = curv[1], c1e2 = curv[2], c3e2 = curv[3],
                                         treated = base$treated, extra = base$extra,
                                         node_steps = base$node_steps,
                                         sign_steps = base$sign_steps)
    cat(sprintf("tol %.4g %-5s steps %d lnJ %.10f grad %.6f curv %.3f %.3f %.3f treated %d\n",
                tols[k], an, length(mesh$sizes), log(base$J), g, curv[1], curv[2], curv[3],
                base$treated))
  }
}
res <- do.call(rbind, res)
# The converged answer: the cut map on a mesh from tol 1e-9, and sub8 on it.
fine <- adaptive_mesh(1e-9, th0)
ref <- list(steps = length(fine$sizes))
for (an in c("cut", "plain")) {
  a <- arms[[an]]
  b <- log(replay(fine, th0, a[[1]], a[[2]])$J)
  ref[[an]] <- c(lnJ = b,
                 grad = (lnJ(fine, th0 * exp(d), a) - lnJ(fine, th0 * exp(-d), a)) / (2 * d),
                 c1e2 = (lnJ(fine, th0 * exp(1e-2), a) - 2 * b + lnJ(fine, th0 * exp(-1e-2), a)) / 1e-4,
                 c3e2 = (lnJ(fine, th0 * exp(3e-2), a) - 2 * b + lnJ(fine, th0 * exp(-3e-2), a)) / 9e-4)
}
saveRDS(list(res = res, ref = ref), out_file)
print(ref)
