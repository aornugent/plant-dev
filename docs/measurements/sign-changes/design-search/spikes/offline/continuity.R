# R3 on the toy: where a treatment's choices change as theta moves on one frozen
# mesh, how far ln J jumps. For sub(m) a choice is whether a node step is
# sub-stepped; for cut, which node steps are cut (and how many cuts). Each change
# found on a coarse scan is bisected to 1e-13 in ln theta, and the jump is the
# change in ln J across it less the smooth slope times the gap.
# Usage: Rscript continuity.R <arm> <m> <out.rds>
args <- commandArgs(TRUE)
arm <- args[1]; m <- as.integer(args[2]); out_file <- args[3]
source("toy.R")
mesh <- adaptive_mesh(1e-4, 1)
run <- function(x) replay(mesh, exp(x), arm, m, log_flips = TRUE)
xs <- seq(-1e-2, 1e-2, length.out = 41)
runs <- lapply(xs, run)
key <- function(r) paste(sort(r$trig), collapse = ",")
keys <- vapply(runs, key, "")
lnJ <- vapply(runs, function(r) log(r$J), 0)
slope <- (lnJ[41] - lnJ[1]) / (xs[41] - xs[1])
jumps <- list()
for (k in which(keys[-1] != keys[-41])) {
  a <- xs[k]; b <- xs[k + 1]; ka <- keys[k]; ra <- runs[[k]]; rb <- runs[[k + 1]]
  while (b - a > 1e-13) {
    c <- 0.5 * (a + b); rc <- run(c)
    if (key(rc) == ka) { a <- c; ra <- rc } else { b <- c; rb <- rc }
  }
  # Local slope from two points either side, a little apart.
  la <- log(run(a - 1e-7)$J); lb <- log(run(b + 1e-7)$J)
  local <- (lb - la) / (b - a + 2e-7)
  jump <- log(rb$J) - log(ra$J) - local * (b - a)
  changed <- setdiff(union(ra$trig, rb$trig), intersect(ra$trig, rb$trig))
  jumps[[length(jumps) + 1]] <- data.frame(at = a, jump = jump,
                                           changed = paste(changed, collapse = " "))
  cat(sprintf("%s m=%d: change at ln theta %.6e, jump %.3e, (step*1000+node) %s\n",
              arm, m, a, jump, paste(changed, collapse = " ")))
}
jumps <- if (length(jumps)) do.call(rbind, jumps) else data.frame()
saveRDS(list(xs = xs, lnJ = lnJ, keys = keys, jumps = jumps), out_file)
cat(sprintf("%s m=%d: %d changes over ln theta in [-1e-2, 1e-2]; largest |jump| %.3e\n",
            arm, m, nrow(jumps), if (nrow(jumps)) max(abs(jumps$jump)) else 0))
