# The sensing and making matrices of one case's runs, their SVDs and noise
# floors.  Rscript fit.R <case>
CASE <- commandArgs(TRUE)[1]
HERE <- "/home/a/dev/plant-dev/.claude/worktrees/agent-aff6cbd1ac6c0084f/spikes/field-dimension-066"
RUN_DIR <- file.path("/home/a/.claude/jobs/9d586e52/tmp/d066/runs", CASE)
TRAITS <- c("lma", "rho", "hmat", "K_s", "rooting_depth_max", "vcmax_25")
DELTA <- 0.2
N_POOL <- as.integer(Sys.getenv("N_POOL", "48"))
pool <- local({  # as field_dimension.R draws it
  set.seed(20261023)
  n <- N_POOL - 1
  x <- sapply(TRAITS, function(.) (sample(n) - runif(n)) / n * 0.8 - 0.4)
  rbind(0, x)
})
rd <- function(n) {
  f <- file.path(RUN_DIR, paste0(n, ".rds"))
  if (file.exists(f)) readRDS(f) else list(ok = FALSE, secs = NA)
}
eq <- readRDS(file.path(RUN_DIR, "eq.rds"))
base <- rd("base")
cols <- c("lnb", TRAITS)
plus <- lapply(cols, function(c) rd(paste0(c, "_p")))
minus <- lapply(cols, function(c) rd(paste0(c, "_m")))
ok <- vapply(seq_along(cols), function(i) isTRUE(plus[[i]]$ok) && isTRUE(minus[[i]]$ok), TRUE)
cat("columns missing:", cols[!ok], "\n")
cols <- cols[ok]; plus <- plus[ok]; minus <- minus[ok]
step <- 2 * DELTA

# Sensing: central differences per unit ln, and second differences.
Phi0 <- base$lnR
dPhi <- sapply(seq_along(cols), function(i) (plus[[i]]$lnR - minus[[i]]$lnR) / step)
curv <- sapply(seq_along(cols), function(i) (plus[[i]]$lnR + minus[[i]]$lnR - 2 * Phi0) / 2)
colnames(dPhi) <- colnames(curv) <- cols
# The resident's own F on the full schedule against invader 1 (the resident's
# traits, every third introduction): what the thinned quadrature does to a
# difference.
dF_res <- sapply(seq_along(cols), function(i) (plus[[i]]$F - minus[[i]]$F) / step)
names(dF_res) <- cols

e_null <- rd("null_b")$lnR - Phi0
e_tol <- rd("base_tol")$lnR - Phi0
# The floor is the 95% quantile of the top singular value of noise matrices
# whose every run carries a random combination of the observed error vectors
# (they are near parallel, so the error is one direction, not iid per entry).
sv_floor <- function(E) {
  set.seed(1)
  draws <- replicate(2000, {
    run_err <- function() E %*% rnorm(ncol(E), sd = sqrt(1 / ncol(E)))
    N <- sapply(seq_along(cols), function(i) (run_err() - run_err()) / step)
    svd(N, 0, 0)$d[1]
  })
  unname(quantile(draws, 0.95))
}
floor_jitter <- sv_floor(cbind(e_null))
floor_tol <- sv_floor(cbind(e_null, e_tol))
# An iid floor, if the per-entry errors were independent: sigma (sqrt n + sqrt m).
rms <- function(x) sqrt(mean(x^2))
floor_iid <- sqrt(2) * rms(e_null) / step * (sqrt(nrow(dPhi)) + sqrt(ncol(dPhi)))
sv <- svd(dPhi)
rel <- sv$d / sv$d[1]
dn <- sweep(dPhi, 2, sqrt(colSums(dPhi^2)), "/")
svn <- svd(dn)
svc <- svd(scale(dPhi, center = TRUE, scale = FALSE))
sens <- list(Phi0 = Phi0, dPhi = dPhi, curv = curv, dF_res = dF_res,
             e_null = e_null, e_tol = e_tol, floor_jitter = floor_jitter,
             floor_tol = floor_tol, floor_iid = floor_iid, sv = sv$d, rel = rel,
             U = sv$u, V = sv$v, sv_norm = svn$d, V_norm = svn$v,
             sv_centred = svc$d, V_centred = svc$v, U_centred = svc$u,
             d_above_jitter = sum(sv$d > floor_jitter),
             d_above_tol = sum(sv$d > floor_tol),
             noise_cos = sum(e_null * e_tol) / sqrt(sum(e_null^2) * sum(e_tol^2)))

# Making: the field on a common grid, rows weighted by sqrt(patch density dt).
hgrid <- seq(0, 30, length.out = 61)
field <- function(r) {
  tt <- vapply(r$snaps, `[[`, 0, "time")
  pd <- vapply(r$snaps, `[[`, 0, "patch_density")
  L <- t(vapply(r$snaps, function(s) approx(s$light[, 1], s$light[, 2], hgrid, rule = 2)$y, hgrid))
  W <- t(vapply(r$snaps, `[[`, numeric(5), "soil"))
  list(t = tt, pd = pd, L = L, W = W)
}
F0 <- field(base)
tgrid <- F0$t
wt <- sqrt(F0$pd * c(diff(tgrid), mean(diff(tgrid))))
dF <- lapply(seq_along(cols), function(i) {
  a <- field(plus[[i]]); b <- field(minus[[i]])
  list(L = (a$L - b$L) * wt / step, W = (a$W - b$W) * wt / step)
})
ML <- sapply(dF, function(x) as.vector(x$L))
MW <- sapply(dF, function(x) as.vector(x$W))
colnames(ML) <- colnames(MW) <- cols
a <- field(rd("null_b"))
null_norm <- c(L = sqrt(sum(((a$L - F0$L) * wt)^2)), W = sqrt(sum(((a$W - F0$W) * wt)^2)))
M <- rbind(ML / sqrt(sum(ML^2)), MW / sqrt(sum(MW^2)))
svL <- svd(ML); svW <- svd(MW); svM <- svd(M)
making <- list(hgrid = hgrid, tgrid = tgrid, pd = F0$pd, L0 = F0$L, W0 = F0$W,
               ML = ML, MW = MW, svL = svL$d, svW = svW$d, svM = svM$d,
               VL = svL$v, VW = svW$v, VM = svM$v,
               UL1 = matrix(svL$u[, 1], length(tgrid)), UL2 = matrix(svL$u[, 2], length(tgrid)),
               UW1 = matrix(svW$u[, 1], length(tgrid)), null_norm = null_norm)
runs <- c("base", "null_b", "base_tol", paste0(c("lnb", TRAITS), "_p"), paste0(c("lnb", TRAITS), "_m"))
out <- list(case = CASE, eq = eq, delta = DELTA, traits = TRAITS,
            pool = pool, cols = cols, sensing = sens, making = making,
            secs = sapply(runs, function(n) rd(n)$secs),
            secs_resident = sapply(runs, function(n) { r <- rd(n); if (is.null(r$secs_resident)) NA else r$secs_resident }),
            steps = sapply(runs, function(n) { r <- rd(n); if (is.null(r$steps)) NA else r$steps }))
saveRDS(out, file.path(HERE, sprintf("field_dimension_%s.rds", CASE)))

f6 <- function(x) paste(formatC(x, digits = 3, format = "g"), collapse = "  ")
cat("\n==", CASE, " ln b* =", eq$lnb_star, " slope", eq$slope, " base F", base$F, "\n")
cat("pool ln R' range", f6(range(Phi0)), "; identity: invader 1", Phi0[1], "vs resident", base$F, "\n")
cat("null_b rms", rms(e_null), " max", max(abs(e_null)), " | tol rms", rms(e_tol),
    " (minus its mean)", rms(e_tol - mean(e_tol)), " | cos", sens$noise_cos, "\n")
cat("resident F: null_b", rd("null_b")$F - base$F, " tol", rd("base_tol")$F - base$F, "\n")
cat("floors: jitter", floor_jitter, " jitter+tol", floor_tol, " iid", floor_iid, "\n")
cat("sv:", f6(sv$d), "\n rel:", f6(rel), "\n d above jitter:", sens$d_above_jitter,
    " above jitter+tol:", sens$d_above_tol, "\n")
cat("col-normalised rel:", f6(svn$d / svn$d[1]), "\n")
cat("centred sv:", f6(svc$d), " rel:", f6(svc$d / sv$d[1]), "\n")
cat("nonlinearity |curv| / |slope*DELTA| by column:", f6(sqrt(colSums(curv^2)) / sqrt(colSums((dPhi * DELTA)^2))), "\n")
cat("quadrature: resident dF", f6(dF_res), "\n          invader 1 dPhi", f6(dPhi[1, ]), "\n")
cat("light sv rel:", f6(svL$d / svL$d[1]), "\n")
cat("water sv rel:", f6(svW$d / svW$d[1]), "\n")
cat("joint sv rel:", f6(svM$d / svM$d[1]), "\n")
cat("null-move field norms:", f6(null_norm), " | light col norms", f6(sqrt(colSums(ML^2)) * step),
    " | water", f6(sqrt(colSums(MW^2)) * step), "\n")
cat("sensing right vectors:\n"); print(round(sv$v[, 1:4], 3))
cat("secs:", f6(out$secs), "\n")
