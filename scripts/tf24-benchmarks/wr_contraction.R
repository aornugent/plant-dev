# Ladder rung 5 (kill-or-fund): the WR/Picard contraction factor of the coupled
# map T: a(t) -> u(t) -> members -> a_out(t), measured near the resident fixed
# point a*(t) on saved fields. One sweep = [hold a; integrate soil (sweep_soil);
# inject swept soil into the replay cache (overwrite_cached_soil); advance members
# against (swept soil, resident light) via run_mutant; read their uptake a_out].
#
# kappa(delta) = ||a_out(delta) - a_out(0)|| / (delta * ||a*||), using the
# discrete operator's own image a_out(0) as reference so sweep_soil's absolute
# discretization bias cancels and only the contraction of the linearised map
# remains. delta=0 doubles as a round-trip sanity check (a_out(0) ~ a*).
# kappa < 1 => WR contracts (fund); kappa >= 1 => diverges (kill). Reported
# global and per window (windowing bounds the loop gain).
options(pkg.build_extra_flags = FALSE)
suppressMessages({library(odelia); pkgload::load_all("/home/user/plant-dev/plant",
                                                     export_all = TRUE, quiet = TRUE)})
cat("loaded\n"); flush(stdout())
datadir <- "/home/user/plant-dev/scripts/tf24-benchmarks/data"
b <- readRDS(file.path(datadir, "intense_storms.rds"))
years <- as.numeric(Sys.getenv("WR_YEARS", "12"))
nd <- round(years * 365); rain <- b$rain[seq_len(nd)]
times <- (0:(nd - 1)) / 365; tmax <- max(times)
mkenv  <- function() { e <- Environment("TF24")
  e$extrinsic_drivers_set_variable("rainfall", times, rain); e }
base_p <- function() { p <- scm_base_parameters("TF24"); p$max_patch_lifetime <- tmax; p }
CACHE  <- control(ode_method = "rkck", ode_tol_rel = 1e-6, ode_tol_abs = 1e-6,
                  save_RK45_cache = TRUE)
lma_A  <- trait_matrix(0.0825, "lma")

# One WR sweep on a fresh resident cache: returns the members' swept uptake
# a_out sampled at the resident accepted-step times, plus a* and that grid.
sweep_once <- function(delta) {
  scm <- run_scm(add_strategies(base_p(), lma_A, birth_rate = 1), mkenv(), CACHE)
  st <- scm$ode_times                      # accepted step times (sample grid)
  # a*(t): resident coupling aggregate, recovered by replaying the resident as a
  # mutant against its own cache with recording on (bit-identical field).
  scm$set_record_uptake(TRUE)
  scm$run_mutant(add_strategies(base_p(), lma_A, birth_rate = 1))
  a_star_t <- scm$uptake_times; a_star <- scm$uptake_values
  a_star_st <- lapply(st, function(tt) a_star[[which.min(abs(a_star_t - tt))]])
  # a_in = (1+delta) * a*; integrate soil against it; inject; advance members.
  scm2 <- run_scm(add_strategies(base_p(), lma_A, birth_rate = 1), mkenv(), CACHE)
  a_in <- lapply(a_star_st, function(v) v * (1 + delta))
  u <- scm2$sweep_soil(st, a_in, st)
  scm2$overwrite_cached_soil(st, u)
  scm2$set_record_uptake(TRUE)
  scm2$run_mutant(add_strategies(base_p(), lma_A, birth_rate = 1))
  list(t = scm2$uptake_times, a = scm2$uptake_values, st = st, a_star = a_star_st)
}

# L2 norm of a (times x layers) series interpolated onto a common grid.
as_mat <- function(vals) do.call(rbind, vals)
interp_to <- function(t, mat, grid)
  vapply(seq_len(ncol(mat)), function(k) approx(t, mat[, k], grid, rule = 2)$y,
         numeric(length(grid)))
l2 <- function(m) sqrt(sum(m^2))

r0 <- sweep_once(0)
G  <- seq(0, tmax, length.out = 4000)
a_star_m <- interp_to(r0$st, as_mat(r0$a_star), G)
out0_m   <- interp_to(r0$t,  as_mat(r0$a),      G)
cat(sprintf("sanity delta=0: ||a_out(0)-a*|| / ||a*|| = %.4f  (round-trip; ~0 good)\n",
            l2(out0_m - a_star_m) / l2(a_star_m))); flush(stdout())

wins <- 6  # per-window kappa
edges <- seq(0, tmax, length.out = wins + 1)
cat(sprintf("\n%-8s %-10s %s\n", "delta", "kappa_glob", "kappa_per_window(6)"))
for (delta in c(1e-3, 1e-2)) {
  rd <- sweep_once(delta)
  outd_m <- interp_to(rd$t, as_mat(rd$a), G)
  denom  <- delta * l2(a_star_m)
  kglob  <- l2(outd_m - out0_m) / denom
  kw <- sapply(seq_len(wins), function(w) {
    sel <- G >= edges[w] & G <= edges[w + 1]
    l2((outd_m - out0_m)[sel, ]) / (delta * l2(a_star_m[sel, ]))
  })
  cat(sprintf("%-8g %-10.3f %s\n", delta, kglob,
              paste(sprintf("%.2f", kw), collapse = " "))); flush(stdout())
}
cat("ALLDONE\n")
