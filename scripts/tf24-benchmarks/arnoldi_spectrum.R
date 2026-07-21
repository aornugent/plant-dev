# T1 (v2 Oracle response, claim 2): Arnoldi on T', the linearisation of the
# self-consistency map T: a(t) -> u(t) -> members -> a_out(t) at its fixed point a*.
# 9b measured kappa = ||T(a*+d a*) - T(a*)|| / (d||a*||) ~ 10: a directional norm
# along a*. The quantity that decides whether the mean-field fixed point is
# CONDITIONED (whether a continuum J exists and is stable) is the distance of
# spec(T') from +1, since ||(I - T')^{-1}|| governs it. |lambda|~10 far from +1 is
# GOOD conditioning (WR-as-iteration diverges, fixed point still well posed); an
# eigenvalue NEAR +1 is the kill (no mesh converges J).
#
# One sweep = one matvec of T'. We reuse the exact 9b machinery (sweep_soil ->
# overwrite_cached_soil -> run_mutant -> read uptake), hoisting the resident solve
# out of the loop and reusing a single cache object across matvecs (each matvec
# overwrites the FULL soil trajectory, so no residue). Arnoldi (modified
# Gram-Schmidt) on m random-started sweeps -> Hessenberg H -> Ritz values ~ dominant
# spec(T'). Sanity: the directional derivative along a* must reproduce 9b's kappa.
options(pkg.build_extra_flags = FALSE)
suppressMessages({library(odelia); pkgload::load_all("/home/user/plant-dev/plant",
                                                     export_all = TRUE, quiet = TRUE)})
cat("loaded\n"); flush(stdout())
set.seed(1)
datadir <- "/home/user/plant-dev/scripts/tf24-benchmarks/data"
outdir  <- "/home/user/plant-dev/scripts/tf24-benchmarks/results"
b <- readRDS(file.path(datadir, "intense_storms.rds"))
years <- as.numeric(Sys.getenv("ARN_YEARS", "12"))
mA    <- as.integer(Sys.getenv("ARN_M", "22"))     # Arnoldi steps
epsrel<- as.numeric(Sys.getenv("ARN_EPS", "1e-2")) # FD step, matches 9b delta
nG    <- as.integer(Sys.getenv("ARN_NG", "1500"))  # Arnoldi state-grid resolution
nd <- round(years * 365); rain <- b$rain[seq_len(nd)]
times <- (0:(nd - 1)) / 365; tmax <- max(times)
mkenv  <- function() { e <- Environment("TF24")
  e$extrinsic_drivers_set_variable("rainfall", times, rain); e }
base_p <- function() { p <- scm_base_parameters("TF24"); p$max_patch_lifetime <- tmax; p }
CACHE  <- control(ode_method = "rkck", ode_tol_rel = 1e-6, ode_tol_abs = 1e-6,
                  save_RK45_cache = TRUE)
lma_A  <- trait_matrix(0.0825, "lma")

# --- resident solve, a*, and one reusable swept cache (built once) -------------
scm <- run_scm(add_strategies(base_p(), lma_A, birth_rate = 1), mkenv(), CACHE)
st  <- scm$ode_times
scm$set_record_uptake(TRUE)
scm$run_mutant(add_strategies(base_p(), lma_A, birth_rate = 1))
a_star_t <- scm$uptake_times
a_star_l <- scm$uptake_values                    # list over a_star_t of L-vectors
L <- length(a_star_l[[1]])
a_star_st <- lapply(st, function(tt) a_star_l[[which.min(abs(a_star_t - tt))]])
a_star_M  <- do.call(rbind, a_star_st)           # n_st x L on the native grid
cat(sprintf("resident: n_st=%d, L=%d, tmax=%.3f\n", length(st), L, tmax)); flush(stdout())

# Arnoldi state grid G (fixed dimension nG x L), and a* on it.
G <- seq(0, tmax, length.out = nG)
interp_to <- function(t, mat, grid)
  vapply(seq_len(ncol(mat)), function(k) approx(t, mat[, k], grid, rule = 2)$y,
         numeric(length(grid)))
a_star_G <- interp_to(st, a_star_M, G)           # nG x L
nrm_star <- sqrt(sum(a_star_G^2))
h_fd     <- epsrel * nrm_star                    # FD step norm == 9b's delta*||a*||

# reusable swept solver (its soil trajectory is fully overwritten each matvec)
scm2 <- run_scm(add_strategies(base_p(), lma_A, birth_rate = 1), mkenv(), CACHE)
scm2$set_record_uptake(TRUE)

# T applied to a coupling given on G (as nG x L): returns a_out on G (nG x L).
apply_T <- function(aG) {
  aM_st <- interp_to(G, aG, st)                  # back to native grid
  a_in  <- lapply(seq_len(nrow(aM_st)), function(i) aM_st[i, ])
  u <- scm2$sweep_soil(st, a_in, st)
  scm2$overwrite_cached_soil(st, u)
  scm2$run_mutant(add_strategies(base_p(), lma_A, birth_rate = 1))
  interp_to(scm2$uptake_times, do.call(rbind, scm2$uptake_values), G)
}

T0 <- apply_T(a_star_G)                           # base image T(a*)
cat(sprintf("sanity round-trip ||T(a*)-a*||/||a*|| = %.4f\n",
            sqrt(sum((T0 - a_star_G)^2)) / nrm_star)); flush(stdout())

# matvec of T': v (flattened nG*L) -> T'(v) (flattened). FD along v at step h_fd.
NN <- nG * L
matvec <- function(v) {
  vv <- v / sqrt(sum(v^2))                        # apply T' to the unit direction
  aG <- a_star_G + h_fd * matrix(vv, nG, L)
  as.numeric((apply_T(aG) - T0) / h_fd) * sqrt(sum(v^2))  # linear: scale back
}

# --- sanity: directional derivative along a* must reproduce 9b's kappa ---------
kap <- sqrt(sum(matvec(as.numeric(a_star_G))^2)) / nrm_star
cat(sprintf("sanity kappa along a* (expect ~10 from 9b) = %.3f\n", kap)); flush(stdout())

# --- Arnoldi (modified Gram-Schmidt) ------------------------------------------
Q <- matrix(0, NN, mA + 1)
H <- matrix(0, mA + 1, mA)
v1 <- rnorm(NN); Q[, 1] <- v1 / sqrt(sum(v1^2))
for (j in seq_len(mA)) {
  w <- matvec(Q[, j])
  for (i in 1:j) { H[i, j] <- sum(Q[, i] * w); w <- w - H[i, j] * Q[, i] }
  H[j + 1, j] <- sqrt(sum(w^2))
  cat(sprintf("  arnoldi step %2d/%d  h[j+1,j]=%.3e\n", j, mA, H[j + 1, j])); flush(stdout())
  if (H[j + 1, j] < 1e-12) { mA <- j; break }
  Q[, j + 1] <- w / H[j + 1, j]
}
Hm <- H[1:mA, 1:mA, drop = FALSE]
ev <- eigen(Hm, only.values = TRUE)$values
ev <- ev[order(Mod(ev), decreasing = TRUE)]
cat("\n== Ritz values (dominant spec(T')) ==\n")
for (k in seq_along(ev))
  cat(sprintf("  lambda[%2d] = % .4f %+.4fi   |lambda|=%.4f   |lambda-1|=%.4f\n",
              k, Re(ev[k]), Im(ev[k]), Mod(ev[k]), Mod(ev[k] - 1)))
cat(sprintf("\nspectral radius rho(T') = %.4f\n", max(Mod(ev))))
cat(sprintf("min |lambda - 1| over Ritz values = %.4f\n", min(Mod(ev - 1))))
cat(sprintf("=> fixed-point conditioning ||(I-T')^-1|| ~ 1/min|lambda-1| ~ %.2f\n",
            1 / min(Mod(ev - 1))))
saveRDS(list(ev = ev, kappa = kap, H = Hm, years = years, eps = epsrel, nG = nG),
        file.path(outdir, "arnoldi_spectrum.rds"))
cat("ALLDONE\n")
