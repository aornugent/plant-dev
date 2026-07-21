# T4 (v2 Oracle response, claim 5): is the O(M) member block being integrated at
# the FAST block's resolution for no J benefit? Members are 10^2-10^3x slower than
# u, but share u's global step. Test (open-loop, offline, 9a machinery + the
# validated overwrite/replay path): recover the resident soil trajectory u*(t),
# low-pass filter it at a sweep of cutoffs, overwrite the cache, re-advance the
# resident member A as a probe against the filtered field, watch J vs cutoff.
#   J flat up to some cutoff  -> ripple phase J-irrelevant; members can take macro
#                                steps while u is sub-cycled (full-M solves drop
#                                10-100x). Licenses averaged member advance.
#   J cutoff-sensitive        -> members need the texture (leg 3 of the concession
#                                condition holds).
# Caveat (Oracle): open loop ignores feedback; with gain kappa~10 the closed-loop
# change can be larger. A is self-consistent with its own field, so J_0 (A on the
# UNFILTERED swept soil, same overwrite path) reproduces resident J and cancels the
# sweep_soil discretization bias -- the decisive read is J(cutoff)/J_0.
options(pkg.build_extra_flags = FALSE)
suppressMessages({library(odelia); pkgload::load_all("/home/user/plant-dev/plant",
                                                     export_all = TRUE, quiet = TRUE)})
cat("loaded\n"); flush(stdout())
datadir <- "/home/user/plant-dev/scripts/tf24-benchmarks/data"
outdir  <- "/home/user/plant-dev/scripts/tf24-benchmarks/results"
b <- readRDS(file.path(datadir, "intense_storms.rds"))
years <- as.numeric(Sys.getenv("FILT_YEARS", "12"))
nd <- round(years * 365); rain <- b$rain[seq_len(nd)]
times <- (0:(nd - 1)) / 365; tmax <- max(times)
mkenv  <- function() { e <- Environment("TF24")
  e$extrinsic_drivers_set_variable("rainfall", times, rain); e }
base_p <- function() { p <- scm_base_parameters("TF24"); p$max_patch_lifetime <- tmax; p }
CACHE  <- control(ode_method = "rkck", ode_tol_rel = 1e-6, ode_tol_abs = 1e-6,
                  save_RK45_cache = TRUE)
lma_A  <- trait_matrix(0.0825, "lma")
mkstrat <- function() add_strategies(base_p(), lma_A, birth_rate = 1)

# resident A + its coupling a* + its soil trajectory u* = sweep_soil(a*).
scm <- run_scm(mkstrat(), mkenv(), CACHE)
J_res <- sum(scm$offspring_production)
st <- scm$ode_times
scm$set_record_uptake(TRUE); scm$run_mutant(mkstrat())
a_star_t <- scm$uptake_times; a_star_l <- scm$uptake_values
a_star_st <- lapply(st, function(tt) a_star_l[[which.min(abs(a_star_t - tt))]])
u_star <- scm$sweep_soil(st, a_star_st, st)          # list over st of soil-vectors
uM <- do.call(rbind, u_star)                          # n_st x nlayer
nlay <- ncol(uM)
cat(sprintf("resident J=%.6e  n_st=%d  soil layers=%d\n", J_res, length(st), nlay)); flush(stdout())

# FFT low-pass of each soil layer at cutoff f_c (cycles per year): resample to a
# uniform grid, zero Fourier modes above f_c, resample back to st.
NU <- 8192
tu <- seq(0, tmax, length.out = NU)
freqs <- (0:(NU - 1)); freqs <- pmin(freqs, NU - freqs) / tmax   # cycles/year per bin
lowpass <- function(col, fc) {
  yu <- approx(st, col, tu, rule = 2)$y
  Y <- fft(yu); Y[freqs > fc] <- 0
  yf <- Re(fft(Y, inverse = TRUE)) / NU
  approx(tu, yf, st, rule = 2)$y
}
filt_soil <- function(fc) {
  if (!is.finite(fc)) return(u_star)
  fM <- vapply(seq_len(nlay), function(k) lowpass(uM[, k], fc), numeric(nrow(uM)))
  lapply(seq_len(nrow(fM)), function(i) fM[i, ])
}

# J of A advanced against a given soil trajectory (same overwrite/replay path).
J_on_soil <- function(u_list) {
  scm$overwrite_cached_soil(st, u_list)
  scm$run_mutant(mkstrat())
  list(J = sum(scm$offspring_production),
       g = scm$patch$species[[1]]$net_reproduction_ratio_by_node *
           scm$patch$species[[1]]$patch_densities,
       tau = scm$patch$species[[1]]$node_times)
}

base <- J_on_soil(u_star)                              # unfiltered swept-soil baseline
cat(sprintf("baseline J_0 (A on unfiltered swept soil) = %.6e  rel gap vs resident = %.3e\n",
            base$J, abs(base$J - J_res) / J_res)); flush(stdout())

# cutoffs in cycles/year: daily=365, ~2-daily=180, weekly=52, monthly=12, seasonal=4,1
cutoffs <- c(Inf, 730, 365, 180, 52, 12, 4, 1)
cat(sprintf("\n%-8s %-13s %-10s %-s\n", "fc(cyc/yr)", "J", "J/J_0", "note"))
res <- list()
for (fc in cutoffs) {
  r <- J_on_soil(filt_soil(fc))
  res[[as.character(fc)]] <- r
  note <- if (!is.finite(fc)) "no filter (== baseline path)"
          else sprintf("removes texture below ~%.1e yr", 1 / fc)
  cat(sprintf("%-10s %-13.6e %-10.4f %s\n", ifelse(is.finite(fc), sprintf("%g", fc), "Inf"),
              r$J, r$J / base$J, note)); flush(stdout())
}
saveRDS(list(base = base, res = res, cutoffs = cutoffs, J_res = J_res, years = years),
        file.path(outdir, "filtered_field_probe.rds"))
cat("ALLDONE\n")
